--[[
	CharacterService: spawns every player as an R15 character built from their own avatar, gives it the
	class prop and cosmetics, and handles class switching and respawns.

	Characters are spawned manually (Players.CharacterAutoLoads = false) with
	Players:CreateHumanoidModelFromDescription(..., R15), so the game is R15 whatever the place's avatar
	settings are - the procedural animations need elbows and knees.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Props = require(Shared.Props)
local Remotes = require(Shared.Remotes)
local Rig = require(Shared.Anim.Rig)
local StadiumLayout = require(Shared.Stadium.Layout)

local AwakenVFX = require(script.Parent.AwakenVFX)
local CombatService = require(script.Parent.CombatService)

local CharacterService = {}

local notify = Remotes.Event("Notify")

local descriptions: { [Player]: HumanoidDescription } = {}
local reported: { [Player]: boolean } = {}
local fightersFolder: Folder

local function getDescription(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		-- A fresh copy each spawn: building a character can take the description over, and it goes
		-- when that character is destroyed
		return cached:Clone()
	end
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
	end)
	local description = if ok and result then result else Instance.new("HumanoidDescription")
	-- Keep the avatar's look but not its animation packs (the game animates everyone itself)
	description.IdleAnimation = 0
	description.WalkAnimation = 0
	description.RunAnimation = 0
	description.JumpAnimation = 0
	description.FallAnimation = 0
	description.ClimbAnimation = 0
	description.SwimAnimation = 0
	descriptions[player] = description
	return description:Clone()
end

-- A spawn point on the pitch, as far as possible from everyone else.
local function spawnCFrame(): CFrame
	local others: { Vector3 } = {}
	for _, fighter in CombatService.Fighters do
		if fighter.Alive then
			table.insert(others, fighter.Root.Position)
		end
	end
	local best, bestScore = Vector3.zero, -math.huge
	for _ = 1, 12 do
		local candidate = StadiumLayout.RandomSpawn(Random.new())
		local score = math.huge
		for _, p in others do
			score = math.min(score, (p - candidate).Magnitude)
		end
		score += math.random() * 8
		if score > bestScore then
			best, bestScore = candidate, score
		end
	end
	local lookAt = Vector3.new(0, best.Y, 0)
	if (lookAt - best).Magnitude < 1 then
		lookAt = best + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(best, lookAt)
end

local function configureHumanoid(humanoid: Humanoid)
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoJumpEnabled = false
end

function CharacterService.Spawn(player: Player)
	if not player.Parent then
		return
	end
	local classId = (player:GetAttribute("Class") :: string?) or Characters.Default
	local description = getDescription(player)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Always)
	end)
	if not ok or not model then
		warn("[CharacterService] couldn't build", player.Name, model)
		model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end
	model.Name = player.Name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	configureHumanoid(humanoid)
	-- The animator drives the joints; a stray Animator could fight it
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	-- Kinematic joints for the animator, and the attachment dashes and knockback push on
	Rig.Prepare(model)
	model:PivotTo(spawnCFrame())
	model.Parent = fightersFolder
	player.Character = model
	if not reported[player] then
		-- The stadium is sized in Roblox units (Stadium/Layout); this shows how big real avatars come out
		reported[player] = true
		print(string.format("[CharacterService] %s spawned %.1f studs tall (about %.2f m at Roblox's 0.28 m per stud)", player.Name, model:GetExtentsSize().Y, model:GetExtentsSize().Y * 0.28))
	end

	Props.Attach(model, classId)
	CombatService.Register(model, player, classId)
	AwakenVFX.Attach(model)
	humanoid.Died:Connect(function()
		task.delay(Config.Player.RespawnTime, function()
			if player.Parent and player.Character == model then
				CharacterService.Respawn(player)
			end
		end)
	end)
end

-- Replaces the player's character with a fresh one. Never leaves them without one: a failed spawn is
-- logged and the watchdog in Init tries again.
local respawning: { [Player]: boolean } = {}
function CharacterService.Respawn(player: Player)
	if respawning[player] then
		return
	end
	respawning[player] = true
	local old = player.Character
	local ok, err = pcall(function()
		CharacterService.Spawn(player)
	end)
	if not ok then
		warn("[CharacterService] respawn failed for", player.Name, err)
	elseif old and old ~= player.Character then
		old:Destroy()
	end
	respawning[player] = nil
end

-- Class switch from the character menu. Out of combat it happens on the spot; in combat you have to wait.
local function onSelect(player: Player, classId: unknown)
	if typeof(classId) ~= "string" or not Characters.Get(classId) then
		return
	end
	local fighter = CombatService.ForPlayer(player)
	player:SetAttribute("Class", classId)
	if not fighter or not fighter.Alive then
		return -- used on the next spawn
	end
	if fighter.Class == classId then
		return
	end
	local t = CombatService.Now()
	if t - fighter.LastCombat < 6 then
		notify:FireClient(player, "You can't switch in combat - you'll be " .. classId .. " when you respawn.")
		return
	end
	CombatService.SetClass(fighter, classId)
	Props.Attach(fighter.Model, classId)
end

function CharacterService.Init()
	fightersFolder = Instance.new("Folder")
	fightersFolder.Name = "Fighters"
	fightersFolder.Parent = workspace

	Remotes.Event("SelectCharacter").OnServerEvent:Connect(onSelect)

	local function onPlayer(player: Player)
		if player:GetAttribute("Class") == nil then
			player:SetAttribute("Class", Characters.Default)
		end
		task.spawn(CharacterService.Spawn, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
		reported[player] = nil
		local character = player.Character
		if character then
			character:Destroy()
		end
	end)

	-- Anyone who falls out of the arena respawns, and anyone left dead or without a character is brought
	-- back (in case a respawn was missed)
	local deadSince: { [Player]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local alive = character and character.Parent and humanoid and humanoid.Health > 0
				if alive then
					deadSince[player] = nil
				else
					deadSince[player] = deadSince[player] or os.clock()
					if os.clock() - deadSince[player] > Config.Player.RespawnTime + 2 then
						deadSince[player] = nil
						task.spawn(CharacterService.Respawn, player)
					end
				end
			end
			for _, fighter in CombatService.Fighters do
				if fighter.Alive and fighter.Root.Position.Y < Config.Arena.FloorY - 60 then
					fighter.Humanoid.Health = 0
				end
			end
		end
	end)
end

function CharacterService.FightersFolder(): Folder
	return fightersFolder
end

return CharacterService
