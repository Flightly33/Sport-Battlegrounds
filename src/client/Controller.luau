--[[
	Controller: the local player's input, movement and combat state.

	- Keyboard / mouse / gamepad bindings (Config.Keys) and the mobile buttons (UI calls Action()).
	- Starts moves instantly (MoveRunner owner mode) and tells the server; rolls back on rejection.
	- M1 chain (with the Soccer RNG leg), uppercut / downslam variants, input buffering.
	- Walk / run / block / stun speeds, knockback and grabs sent by the server.
	- Aim: the direction you face, with a little aim assist towards the nearest enemy in front.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Common = require(Shared.Characters.Common)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local Clips = require(Shared.Anim.Clips)
local Rig = require(Shared.Anim.Rig)

local Animator = require(script.Parent.Animator)
local MoveRunner = require(script.Parent.MoveRunner)

type Move = Characters.Move

local Controller = {}

Controller.CooldownStarted = Signal.new() -- (moveId, seconds)
Controller.MoveUsed = Signal.new() -- (move)
Controller.MenuRequested = Signal.new()
Controller.LastReason = "" -- why the last Use() didn't start (debugging)

local player = Players.LocalPlayer :: Player
local moveRequest = Remotes.Event("MoveRequest")
local blockRequest = Remotes.Event("BlockRequest")

local token = 0
local cooldowns: { [string]: number } = {}
local busyUntil = 0
local busyMove: Move? = nil
local m1Step = 0
local lastM1 = 0
local m1ReadyAt = 0
local running = false
local runHeld = false
local lastForwardTap = 0
local blockHeld = false
local blocking = false
local spaceHeld = false
local m1Held = false
local buffered: { Slot: string, Expires: number }? = nil
local follow: { Root: BasePart, Offset: CFrame, Until: number, Track: Animator.Track? }? = nil
local knockbackVelocity: LinearVelocity? = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function attr(character: Model, name: string): number
	return (character:GetAttribute(name) :: number?) or 0
end

function Controller.CooldownRemaining(moveId: string): number
	local ready = cooldowns[moveId]
	return if ready then math.max(0, ready - os.clock()) else 0
end

function Controller.IsBusy(): boolean
	return os.clock() < busyUntil
end

--------------------------------------------------------------------------------
-- Aim
--------------------------------------------------------------------------------
local function computeAim(root: BasePart, assistRange: number, assistCone: number): Vector3
	local base = root.CFrame.LookVector
	-- With shift-lock (or the camera locked behind you) aim where the camera looks
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 1e-3 then
				base = flat.Unit
			end
		end
	end
	-- Aim assist: snap to the closest living fighter inside a cone in front of you
	local best: BasePart? = nil
	local bestScore = math.huge
	local cosLimit = math.cos(math.rad(assistCone))
	for _, folderName in { "Fighters", "Dummies" } do
		local f = workspace:FindFirstChild(folderName)
		if f then
			for _, model in f:GetChildren() do
				if model ~= player.Character and model:IsA("Model") then
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					local r = model:FindFirstChild("HumanoidRootPart")
					if humanoid and humanoid.Health > 0 and r and r:IsA("BasePart") then
						local offset = r.Position - root.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						local distance = offset.Magnitude
						if distance < assistRange and flat.Magnitude > 0.5 and flat.Unit:Dot(base) > cosLimit then
							local score = distance * (2 - flat.Unit:Dot(base))
							if score < bestScore then
								best, bestScore = r, score
							end
						end
					end
				end
			end
		end
	end
	if best then
		local offset = best.Position - root.Position
		return offset.Unit
	end
	return base
end

--------------------------------------------------------------------------------
-- Starting moves
--------------------------------------------------------------------------------
local function dashMove(humanoid: Humanoid, root: BasePart): (Move, string)
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.2 then
		return Common.DashFront, "F"
	end
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local f = dir:Dot(look)
	local r = dir:Dot(right)
	if math.abs(f) >= math.abs(r) then
		return if f > 0 then Common.DashFront else Common.DashBack, if f > 0 then "F" else "B"
	end
	return Common.DashSide, if r > 0 then "R" else "L"
end

local function setBlocking(on: boolean)
	if blocking == on then
		return
	end
	blocking = on
	blockRequest:FireServer(on)
end

-- Tries to use the move in a slot ("M1", "1".."4", "Awaken", "Dash"). Returns true if it started.
function Controller.Use(slot: string): boolean
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then
		Controller.LastReason = "no character"
		return false
	end
	local now = serverNow()
	local stunned = attr(character, "StunUntil") > now
	local knocked = attr(character, "KnockdownUntil") > now
	local classId = (character:GetAttribute("Class") :: string?) or Characters.Default
	local awakened = character:GetAttribute("Awakened") == true
	local move: Move? = nil
	local variant = ""

	if slot == "Dash" then
		if stunned or knocked or follow then
			local meter = (player:GetAttribute("Evasive") :: number?) or 0
			if meter < Config.Evasive.Cost then
				Controller.LastReason = "evasive meter not full"
				return false
			end
			move = Common.Evasive
		else
			move, variant = dashMove(humanoid, root)
		end
	else
		if stunned or knocked or follow then
			Controller.LastReason = "stunned"
			return false
		end
		if slot == "Awaken" then
			if awakened or ((player:GetAttribute("Awaken") :: number?) or 0) < 99.5 then
				Controller.LastReason = "awakening meter not full"
				return false
			end
		end
		move = Characters.MoveFor(classId, slot, awakened)
	end
	if not move then
		Controller.LastReason = "no move for slot"
		return false
	end
	local moveSlot: string = move.Slot
	local clock = os.clock()
	local evasive = moveSlot == "Evasive"
	if clock < busyUntil and not evasive then
		-- Buffer the press so it fires as soon as the current move ends
		buffered = { Slot = slot, Expires = busyUntil + 0.2 }
		Controller.LastReason = "busy (buffered)"
		return false
	end
	if Controller.CooldownRemaining(move.Id) > 0 then
		Controller.LastReason = "cooldown"
		return false
	end
	if moveSlot == "M1" then
		if clock < m1ReadyAt then
			Controller.LastReason = "m1 cooldown"
			return false
		end
		if clock - lastM1 > Config.Combat.ComboResetTime or m1Step >= 4 then
			m1Step = 0
		end
		m1Step += 1
		lastM1 = clock
		local leg = if math.random() < 0.5 then "L" else "R"
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		if m1Step == 4 and spaceHeld then
			variant = "U" .. leg
		elseif m1Step == 4 and airborne then
			variant = "D" .. leg
		else
			variant = tostring(m1Step) .. leg
		end
		if m1Step >= 4 then
			m1ReadyAt = clock + Config.Combat.ComboEndCooldown
		end
	end

	token += 1
	local aim = if moveSlot == "M1"
		then computeAim(root, 14, 60)
		elseif moveSlot == "Dash" or moveSlot == "Evasive" then root.CFrame.LookVector
		else computeAim(root, 90, 32)
	busyUntil = clock + move.Busy
	busyMove = move
	if move.Cooldown > 0 then
		cooldowns[move.Id] = clock + move.Cooldown
		Controller.CooldownStarted:Fire(move.Id, move.Cooldown)
	end
	if moveSlot == "Dash" then
		for _, id in { "Dash_Front", "Dash_Side", "Dash_Back" } do
			local cd = if id == move.Id then move.Cooldown else Config.Dash.Cooldown
			cooldowns[id] = math.max(cooldowns[id] or 0, clock + cd)
		end
	end
	if blocking then
		setBlocking(false)
	end
	running = running and moveSlot == "Dash"
	-- Tell the server first: remotes arrive in order, so hits from the move's first frame can't beat it
	moveRequest:FireServer(token, move.Id, aim, variant)
	MoveRunner.Start(character, move.Id, token, aim, variant, true)
	Controller.MoveUsed:Fire(move)
	return true
end

--------------------------------------------------------------------------------
-- Server messages
--------------------------------------------------------------------------------
local function onKnockback(velocity: Vector3, duration: number, _knockdown: number)
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then
		return
	end
	MoveRunner.CancelAll(character)
	busyUntil = 0
	if knockbackVelocity then
		knockbackVelocity:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SB_Knockback"
	lv.Attachment0 = Rig.MotionAttachment(root)
	lv.MaxForce = 1e7
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	knockbackVelocity = lv
	if velocity.Y > 5 then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	task.delay(duration, function()
		if knockbackVelocity == lv then
			knockbackVelocity = nil
		end
		lv:Destroy()
		-- Keep some of the momentum after the push ends
		if root.Parent then
			root.AssemblyLinearVelocity = velocity * 0.35 + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, velocity.Y * 0.35), 0)
		end
	end)
end

local function onFollow(attackerRoot: BasePart, offset: CFrame, duration: number)
	local character = getCharacter()
	if not character or not attackerRoot then
		return
	end
	MoveRunner.CancelAll(character)
	if follow and follow.Track then
		follow.Track:Stop()
	end
	follow = {
		Root = attackerRoot,
		Offset = offset,
		Until = os.clock() + duration,
		Track = Animator.Play(character, Clips.Common.Grabbed),
	}
end

--------------------------------------------------------------------------------
-- Per frame
--------------------------------------------------------------------------------
local function update()
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then
		return
	end
	local now = serverNow()
	local clock = os.clock()
	local stunned = attr(character, "StunUntil") > now
	local knocked = attr(character, "KnockdownUntil") > now
	local awakened = character:GetAttribute("Awakened") == true
	local busy = clock < busyUntil

	if follow then
		if clock > follow.Until or not follow.Root.Parent then
			if follow.Track then
				follow.Track:Stop()
			end
			follow = nil
		else
			root.CFrame = follow.Root.CFrame * follow.Offset
			root.AssemblyLinearVelocity = follow.Root.AssemblyLinearVelocity
		end
	end

	-- Running: double-tap forward or hold the run key; stops when you stop moving
	local moving = humanoid.MoveDirection.Magnitude > 0.15
	if runHeld and moving then
		running = true
	elseif not moving then
		running = false
	end

	local speed = if running then Config.Player.RunSpeed else Config.Player.WalkSpeed
	if awakened then
		speed *= Config.Awakening.SpeedMultiplier
	end
	if busy then
		speed = 5
	end
	if blocking then
		speed = Config.Player.BlockWalkSpeed
	end
	if stunned then
		speed = Config.Player.StunWalkSpeed
	end
	if knocked or follow then
		speed = 0
	end
	humanoid.WalkSpeed = speed
	local grounded = not (stunned or knocked or blocking or busy or follow ~= nil)
	humanoid.JumpPower = if grounded then Config.Player.JumpPower else 0
	humanoid.AutoRotate = not (busy or stunned or knocked or follow ~= nil)

	-- Block: hold to block whenever you're able to
	local canBlock = blockHeld and not busy and not stunned and not knocked and follow == nil
	if canBlock ~= blocking then
		setBlocking(canBlock)
	end

	-- Buffered press / held M1
	if not busy then
		if buffered and clock <= buffered.Expires then
			local slot = buffered.Slot
			buffered = nil
			Controller.Use(slot)
		elseif m1Held then
			Controller.Use("M1")
		end
	end
	if busyMove and not busy then
		busyMove = nil
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
-- Generic action entry point (keyboard, gamepad and the mobile buttons all end up here).
function Controller.Action(action: string, down: boolean)
	if action == "Block" then
		blockHeld = down
	elseif action == "Run" then
		if down then
			running = not running
		end
	elseif action == "RunHold" then
		runHeld = down
		if not down then
			running = false
		end
	elseif action == "Jump" then
		spaceHeld = down
	elseif action == "M1" then
		m1Held = down
		if down then
			Controller.Use("M1")
		end
	elseif down then
		if action == "Move1" then
			Controller.Use("1")
		elseif action == "Move2" then
			Controller.Use("2")
		elseif action == "Move3" then
			Controller.Use("3")
		elseif action == "Move4" then
			Controller.Use("4")
		elseif action == "Awaken" then
			Controller.Use("Awaken")
		elseif action == "Dash" then
			Controller.Use("Dash")
		elseif action == "CharacterMenu" then
			Controller.MenuRequested:Fire()
		end
	end
end

local KEY_ACTIONS: { [Enum.KeyCode]: string } = {}
for action: string, key: any in Config.Keys :: any do
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		KEY_ACTIONS[key :: Enum.KeyCode] = if action == "Run" then "RunHold" else action
	end
end
for action: string, key: any in Config.GamepadKeys :: any do
	KEY_ACTIONS[key :: Enum.KeyCode] = action
end
KEY_ACTIONS[Enum.KeyCode.Space] = "Jump"
KEY_ACTIONS[Enum.KeyCode.ButtonA] = "Jump"

local function onInput(input: InputObject, processed: boolean, down: boolean)
	if processed and down then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Controller.Action("M1", down)
		return
	end
	local action = KEY_ACTIONS[input.KeyCode]
	if action then
		Controller.Action(action, down)
	end
	-- Double-tap W to run
	if down and input.KeyCode == Enum.KeyCode.W then
		local clock = os.clock()
		if clock - lastForwardTap < Config.Player.DoubleTapWindow then
			running = true
		end
		lastForwardTap = clock
	end
end

function Controller.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		onInput(input, processed, true)
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		onInput(input, processed, false)
	end)
	RunService.PreSimulation:Connect(update)

	Remotes.Event("Knockback").OnClientEvent:Connect(onKnockback)
	Remotes.Event("Follow").OnClientEvent:Connect(onFollow)
	Remotes.Event("MoveRejected").OnClientEvent:Connect(function(rejected: number, moveId: string, reason: string)
		local character = player.Character
		if character then
			MoveRunner.Cancel(character, rejected, "the server refused it (" .. tostring(reason) .. ")")
		end
		if rejected == token then
			busyUntil = 0
		end
		local move = Characters.Move(moveId)
		if move and move.Slot == "M1" then
			m1Step = 0
		end
	end)
	Remotes.Event("Cooldown").OnClientEvent:Connect(function(moveId: string, remaining: number)
		cooldowns[moveId] = os.clock() + remaining
		if remaining > 0 then
			Controller.CooldownStarted:Fire(moveId, remaining)
		end
	end)

	local function onCharacter(character: Model)
		busyUntil = 0
		m1Step = 0
		follow = nil
		blocking = false
		cooldowns = {}
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
		-- Getting stunned interrupts your own move (unless it has hyper armor)
		character:GetAttributeChangedSignal("StunUntil"):Connect(function()
			if attr(character, "StunUntil") > serverNow() then
				MoveRunner.CancelAll(character)
				local move = busyMove
				if not move or not move.HyperArmor then
					busyUntil = 0
				end
			end
		end)
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return Controller
