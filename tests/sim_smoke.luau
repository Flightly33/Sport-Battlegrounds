--[[
	End-to-end smoke test in the simulator (tools/sim): boots the real server and client scripts, then
	plays every move of every character against the training dummies, gets hit by a bot, uses the
	evasive, awakens, dies and respawns. Fails on any runtime error, and on anything a player would
	notice: a move that doesn't animate the body, a dash or lunge that doesn't move the character, a
	dash that leaves the arena or ignores its cooldown, knockback that doesn't push.

	Characters are built like current Roblox avatars (AnimationConstraint joints); SIM_RIG=motor6d
	tests the legacy Motor6D rig instead.

	rojo sourcemap default.project.json -o sourcemap.json && lune run tests/sim_smoke.luau
]]
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local World = require("../tools/sim/World")
local Sim = require("../tools/sim/Instance")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local root = process.cwd
if string.sub(root, -1) ~= "/" then
	root ..= "/"
end
local quick = process.args[1] == "quick"
local only = if process.args[1] and process.args[1] ~= "quick" then string.split(process.args[1], ",") else nil

World.TraceDeaths = true
World.Digest = process.env.SIM_DIGEST ~= nil
World.RigKind = process.env.SIM_RIG or "constraint"
local world = World.new(root)
local game = world.Game
local RS = world.Services.ReplicatedStorage
local SSS = world.Services.ServerScriptService

local server = world:Context("server", true, nil)
print("== booting server")
server.Run(SSS:WaitForChild("Server"))
world:Run(2.5)

local player = world:AddPlayer("Tester", 1, true)
local bot = world:AddPlayer("Bot", 2, false)
local client = world:Context("client", false, player)
-- Keep the simulator fast: a token crowd (the real one is up to 10,000 fans)
local ClientConfig = client.Require(RS:WaitForChild("Shared"):WaitForChild("Config"))
ClientConfig.Crowd.DefaultDensity.Desktop = 0.01
ClientConfig.Crowd.ConfettiRate = 0.5
if process.env.SIM_ASSETS then
	-- Pretend every Blender-pack asset is uploaded so each FX hook runs
	local ClientAssets = client.Require(RS:WaitForChild("Shared"):WaitForChild("AssetIds"))
	for _, group in { ClientAssets.Meshes, ClientAssets.Textures } do
		for name in group do
			group[name] = "1"
		end
	end
end
print("== booting client")
client.Run(world.Services.StarterPlayer.StarterPlayerScripts:WaitForChild("Client"))
world:Run(4)

local Shared = RS:WaitForChild("Shared")
local Characters = server.Require(Shared:WaitForChild("Characters"))
local CombatService = server.Require(SSS.Server:WaitForChild("CombatService"))
local SkinService = server.Require(SSS.Server:WaitForChild("SkinService"))
local MoveService = server.Require(SSS.Server:WaitForChild("MoveService"))
local Props = server.Require(Shared:WaitForChild("Props"))
local Controller = client.Require(world.Services.StarterPlayer.StarterPlayerScripts.Client:WaitForChild("Controller"))
local ClientRemotes = client.Require(Shared:WaitForChild("Remotes"))

-- Which named sounds the client plays (the sim can't hear them, but it can see what was asked for)
local ClientSound = client.Require(world.Services.StarterPlayer.StarterPlayerScripts.Client:WaitForChild("Sound"))
local soundsPlayed: { [string]: number } = {}
local realPlay, realStart = ClientSound.Play, ClientSound.Start
ClientSound.Play = function(name, ...)
	soundsPlayed[name] = (soundsPlayed[name] or 0) + 1
	return realPlay(name, ...)
end
ClientSound.Start = function(name, ...)
	soundsPlayed[name] = (soundsPlayed[name] or 0) + 1
	return realStart(name, ...)
end

local ServerRemotes = server.Require(Shared:WaitForChild("Remotes"))
ServerRemotes.Event("HitRequest").OnServerEvent:Connect(function(_p, token, hitName, targets)
	print(string.format("[test] HitRequest token=%s hit=%s targets=%d", tostring(token), tostring(hitName), #targets))
end)
local requests: { string } = {} -- every move the player started, in order
ServerRemotes.Event("MoveRequest").OnServerEvent:Connect(function(_p, token, moveId)
	print(string.format("[test] MoveRequest token=%s %s", tostring(token), tostring(moveId)))
	table.insert(requests, moveId)
end)
-- Count confirmed hits per move on the client
local hits: { [string]: number } = {}
ClientRemotes.Event("HitConfirmed").OnClientEvent:Connect(function(hit)
	local key = hit.Move .. "." .. hit.Hit
	hits[key] = (hits[key] or 0) + 1
end)

local function check(ok: boolean, message: string)
	if not ok then
		table.insert(world.Errors, "CHECK FAILED: " .. message)
		print("[test] CHECK FAILED: " .. message)
	end
end

check(player.Character ~= nil, "player has a character")
check(world.Services.Workspace:FindFirstChild("Stadium") ~= nil, "stadium was built")
local dummies = world.Services.Workspace:FindFirstChild("Dummies")
check(dummies ~= nil and #dummies:GetChildren() >= 4, "dummies spawned")
local playerGui = player:FindFirstChild("PlayerGui")
check(playerGui ~= nil and playerGui:FindFirstChild("SportsHUD") ~= nil, "HUD built")
local crowd = world.Services.Workspace:FindFirstChild("Crowd")
check(crowd ~= nil and #crowd:GetChildren() > 50, "crowd built (" .. tostring(crowd and #crowd:GetChildren()) .. " parts)")

local function fighterOfPlayer(p)
	return CombatService.ForPlayer(p)
end

local ServerConfig = server.Require(Shared:WaitForChild("Config"))
local Layout = server.Require(Shared:WaitForChild("Stadium"):WaitForChild("Layout"))

--------------------------------------------------------------------------------
-- Probes: what a player would actually see - joints turning, the character moving
--------------------------------------------------------------------------------
local function jointsOf(character)
	local list = {}
	for _, d in character:GetDescendants() do
		local c = d.ClassName
		if (c == "AnimationConstraint" or c == "Motor6D") and d.Name ~= "SB_Prop" then
			table.insert(list, d)
		end
	end
	return list
end

-- Rotation angle of a CFrame in degrees (0..180; ToAxisAngle may report a small turn as ~360).
local function turn(cf): number
	local _, angle = cf:ToAxisAngle()
	angle = math.abs(angle) % (2 * math.pi)
	if angle > math.pi then
		angle = 2 * math.pi - angle
	end
	return math.deg(angle)
end

-- Largest joint rotation away from the rest pose right now (degrees).
local function poseAmount(character): number
	local best = 0
	for _, j in jointsOf(character) do
		best = math.max(best, turn(j.Transform))
	end
	return best
end

-- Measures one move: the most any joint turned away from the pose it started in, and how far the
-- root travelled (horizontally and up) from where it started.
local probe: any = nil
local function startProbe(label: string)
	local character = player.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local joints = jointsOf(character)
	local base = {}
	for _, j in joints do
		base[j] = j.Transform
	end
	probe = { Label = label, Joints = joints, Base = base, Root = rootPart, Start = rootPart.Position, MaxAngle = 0, Joint = "-", MaxH = 0, MaxV = 0, Final = rootPart.Position }
	return probe
end
table.insert(world.FrameHooks, function()
	local p = probe
	if not p then
		return
	end
	for _, j in p.Joints do
		local angle = turn(p.Base[j]:Inverse() * j.Transform)
		if angle > p.MaxAngle then
			p.MaxAngle, p.Joint = angle, j.Name
		end
	end
	local d = p.Root.Position - p.Start
	p.MaxH = math.max(p.MaxH, Vector3.new(d.X, 0, d.Z).Magnitude)
	p.MaxV = math.max(p.MaxV, d.Y)
	p.Final = p.Root.Position
end)
local function stopProbe()
	local p = probe
	probe = nil
	return p
end

local animSeen: { [string]: number } = {} -- move id -> largest joint rotation seen (degrees)
local animJoint: { [string]: string } = {}

-- Rest pose check: a live idle has some joint well away from the T-pose / bind pose.
world:Run(0.5)
check(poseAmount(player.Character) > 3, string.format("player idle is animated (largest joint rotation %.1f deg)", poseAmount(player.Character)))
do
	local best = 0
	for _, d in dummies:GetChildren() do
		best = math.max(best, poseAmount(d))
	end
	check(best > 0.5, string.format("training dummies are animated (largest joint rotation %.1f deg)", best))
end

-- Where each dummy stood when the test started (by name: dummies are rebuilt when they respawn)
local dummyHome: { [string]: any } = {}
for _, d in dummies:GetChildren() do
	dummyHome[d.Name] = d:FindFirstChild("HumanoidRootPart").CFrame
end

-- Clears anything still moving a model: knockback velocities, grab welds, vertical speed.
local function settle(model)
	for _, x in model:GetDescendants() do
		if x.ClassName == "LinearVelocity" or (x.ClassName == "Weld" and x.Name == "SB_Grab") then
			x:Destroy()
		end
	end
	world.Vertical[model] = 0
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Every dummy back home, standing, full health and free to be hit.
local function resetDummies()
	for _, d in dummies:GetChildren() do
		local h = d:FindFirstChildOfClass("Humanoid")
		local f = CombatService.Get(d)
		if h and h.Health > 0 and f then
			h.Health = h.MaxHealth
			f.StunUntil = 0
			f.KnockdownUntil = 0
			f.InvulnUntil = 0
			settle(d)
			local home = dummyHome[d.Name]
			if home then
				d:PivotTo(home)
			end
		end
	end
end

local function faceDummy(index: number, distance: number)
	resetDummies()
	local character = player.Character
	local dummy = dummies:GetChildren()[index]
	if not character or not dummy then
		return
	end
	settle(character)
	local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")
	local target = dummyRoot.Position
	local from = target + Vector3.new(-distance, 0, 0)
	character:PivotTo(CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z)))
end

local function switchClass(classId: string)
	local fighter = fighterOfPlayer(player)
	player:SetAttribute("Class", classId)
	CombatService.SetClass(fighter, classId)
	Props.Attach(fighter.Model, classId, SkinService.Equipped(player, classId))
	fighter.LastCombat = 0
end

local function waitFree(extra: number?)
	-- wait until the local player is no longer busy
	local deadline = world:Now() + 4
	while Controller.IsBusy() and world:Now() < deadline do
		world:Run(0.1)
	end
	world:Run(extra or 0.25)
end

local MoveRunner = client.Require(world.Services.StarterPlayer.StarterPlayerScripts.Client:WaitForChild("MoveRunner"))
local function use(slot: string, settle: number?)
	local before = #requests
	local p = startProbe(slot)
	local ok = Controller.Use(slot)
	if process.env.SIM_TRACE then
		world:Run(0.05)
		local c = player.Character
		local n = 0
		for _, ctx in MoveRunner.Active(c) do
			n += 1
			print(string.format("[trace] %s active=%s cancelled=%s stun=%s now=%s", ctx.Move.Id, tostring(not ctx.Finished), tostring(ctx.Cancelled), tostring(c:GetAttribute("StunUntil")), tostring(world:Now() + 1000)))
		end
		print("[trace] use", slot, ok, "active contexts", n)
	end
	if not ok then
		print(string.format("[test] Use(%s) did not start: %s", slot, Controller.LastReason))
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		print("   character:", c, c and c.Parent, "health:", h and h.Health, "root:", c and c:FindFirstChild("HumanoidRootPart"))
	end
	waitFree(settle)
	stopProbe()
	if #requests > before then
		local id = requests[#requests]
		if p.MaxAngle > (animSeen[id] or -1) then
			animSeen[id] = p.MaxAngle
			animJoint[id] = p.Joint
		end
	end
	return ok, p
end

do
	faceDummy(1, 5)
	world:Run(0.2)
	local character = player.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local params = { FilterType = roblox.Enum.RaycastFilterType.Include, FilterDescendantsInstances = { dummies } }
	local found = world:QueryBox(rootPart.CFrame * CFrame.new(0, 0, -3.4), Vector3.new(5.5, 6, 6), params)
	local d1 = dummies:GetChildren()[1]
	print("[test] probe: player", rootPart.Position, "look", rootPart.CFrame.LookVector, "dummy", d1:FindFirstChild("HumanoidRootPart").Position, "found", #found)
end

if process.env.SIM_TRACE then
	local original = world.QueryBox
	world.QueryBox = function(w, cf, size, params)
		local found = original(w, cf, size, params)
		if math.abs(size.Y - 3.5) < 0.01 then
			local d = dummies:GetChildren()[1]
			print("[slidebox]", cf.Position, "found", #found, "player", player.Character.HumanoidRootPart.Position)
		end
		return found
	end
end
local function landedCount(moveId: string): number
	local n = 0
	for k, count in hits do
		if string.sub(k, 1, #moveId + 1) == moveId .. "." then
			n += count
		end
	end
	return n
end

local function moveFor(classId: string, slot: string, awakened: boolean)
	for _, move in Characters.Moves do
		if move.Class == classId and move.Slot == slot and (move.Awakened == true) == awakened then
			return move
		end
	end
	return nil
end

-- Lets a move go again right away (server and client cooldowns), keeping the player awakened if needed.
local function readyFor(move)
	local fighter = fighterOfPlayer(player)
	fighter.Cooldowns[move.Id] = 0
	fighter.BusyUntil = 0
	fighter.InvulnUntil = 0
	ServerRemotes.Event("Cooldown"):FireClient(player, move.Id, 0)
	if move.Awakened and not CombatService.IsAwakened(fighter) then
		CombatService.StartAwakening(fighter)
	end
	world:Run(0.2)
end

-- A counter only fires when someone hits you: the bot swings at the player during the window.
local function botAttack()
	local playerFighter = fighterOfPlayer(player)
	local botFighter = fighterOfPlayer(bot)
	if not (playerFighter and botFighter) then
		return
	end
	local root = playerFighter.Root
	bot.Character:PivotTo(CFrame.lookAt((root.CFrame * CFrame.new(0, 0, -5)).Position, root.Position))
	botFighter.InvulnUntil = 0
	botFighter.BusyUntil = 0
	botFighter.M1ReadyAt = 0
	local move = Characters.Move("Soccer_M1")
	if MoveService.Start(botFighter, move, 9000 + math.random(1, 999), root.Position - botFighter.Root.Position, "1") then
		local _, active = next(botFighter.Active)
		CombatService.ApplyHit(botFighter, playerFighter, active, "Hit1", move.Hits.Hit1, root.Position)
	end
end

-- Plays one move against a dummy. It should land from a sensible spacing (projectiles from range,
-- everything else up close); other distances are only tried if it doesn't.
local function tryMove(classId: string, slot: string, awakened: boolean)
	local move = moveFor(classId, slot, awakened)
	if not move or not next(move.Hits) then
		return
	end
	-- Ranged only if every hit is a projectile (a melee swing that launches one still starts up close)
	local projectile = true
	for _, hit in move.Hits do
		if not hit.Projectile then
			projectile = false
		end
	end
	local distances = if projectile then { 12, 6, 20 } else { 6, 10, 16 }
	for attempt, distance in distances do
		readyFor(move)
		faceDummy(tonumber(slot) % 3 + 1, distance)
		local before = landedCount(move.Id)
		if move.Counter then
			local p = startProbe(slot)
			Controller.Use(slot)
			world:Run(0.25)
			botAttack()
			waitFree(1.0)
			stopProbe()
			animSeen[move.Id] = math.max(animSeen[move.Id] or 0, p.MaxAngle)
			animJoint[move.Id] = p.Joint
		else
			use(slot, 1.0)
		end
		world:Run(if move.Ultimate then 3.5 else 0.8)
		if landedCount(move.Id) > before then
			if attempt > 1 then
				print(string.format("[test] %s landed from %d studs (attempt %d)", move.Id, distance, attempt))
			end
			return
		end
	end
end

--------------------------------------------------------------------------------
-- Movement: every move that should carry the character does, measured on open ground
--------------------------------------------------------------------------------
-- Minimum travel (studs) for moves that displace their user: H = horizontal, V = upward.
local MOVERS: { [string]: { H: number?, V: number? } } = {
	Soccer_DribbleDash = { H = 15 },
	Soccer_BicycleKick = { V = 4 },
	Soccer_Volley = { V = 1.5 },
	Basketball_AnkleBreaker = { H = 3 },
	Basketball_SlamDunk = { V = 4 },
	Basketball_FastBreak = { H = 20 },
	Basketball_CrossoverCombo = { H = 1.5 },
	Basketball_Supernova = { V = 15 },
	Football_StiffArm = { H = 4 },
	Football_BlitzTackle = { H = 15 },
	Football_TouchdownSpike = { V = 3 },
	Football_MeteorSack = { H = 10 },
	Baseball_StolenBase = { H = 12 },
}
local moverResults: { [string]: any } = {}

-- West half of the pitch, facing the west goal: clear of the dummies (east) and the noob (centre).
local function openGround()
	local pos = Vector3.new(-Layout.PITCH_HALF_X * 0.4, 3, Layout.PITCH_HALF_Z * 0.4)
	return CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0))
end

local function placePlayer(cf)
	local character = player.Character
	settle(character)
	character:PivotTo(cf)
	world:Run(0.1)
end

-- Distance inside the arena wall (negative = outside), from the barrier's rounded rectangle.
local function insideArena(position): number
	local r = Layout.CORNER_RADIUS
	local qx = math.abs(position.X) - (Layout.BARRIER_HALF_X - r)
	local qz = math.abs(position.Z) - (Layout.BARRIER_HALF_Z - r)
	local outside = Vector3.new(math.max(qx, 0), 0, math.max(qz, 0)).Magnitude + math.min(math.max(qx, qz), 0) - r
	return -outside
end

local function movementPass(classId: string, awakened: boolean)
	local ids = {}
	for id in MOVERS do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local move = Characters.Move(id)
		if move and move.Class == classId and (move.Awakened == true) == awakened then
			readyFor(move)
			placePlayer(openGround())
			local _, p = use(move.Slot, 0.4)
			local need = MOVERS[id]
			moverResults[id] = p
			if need.H then
				check(p.MaxH >= need.H, string.format("%s moves its user (%.1f of %.1f studs)", id, p.MaxH, need.H))
			end
			if need.V then
				check(p.MaxV >= need.V, string.format("%s lifts its user (%.1f of %.1f studs up)", id, p.MaxV, need.V))
			end
		end
	end
end

local classes = only or (if quick then { "Soccer" } else { "Soccer", "Basketball", "Football", "Baseball" })
for _, classId in classes do
	print("== " .. classId)
	switchClass(classId)
	world:Run(0.5)
	local fighter = fighterOfPlayer(player)
	fighter.InvulnUntil = 0
	-- M1 chain on dummy 1
	faceDummy(1, 5)
	for _ = 1, 4 do
		use("M1", 0.05)
	end
	world:Run(1.5)
	-- Moves 1-4
	for slot = 1, 4 do
		tryMove(classId, tostring(slot), false)
	end
	movementPass(classId, false)
	-- Dash
	use("Dash", 0.2)
	-- Awaken (Studio start: meter full) and the awakened moves
	player:SetAttribute("Awaken", 100)
	faceDummy(2, 8)
	use("Awaken", 0.5)
	world:Run(1.5)
	check(player.Character:GetAttribute("Awakened") == true, classId .. " awakened")
	for slot = 1, 4 do
		tryMove(classId, tostring(slot), true)
	end
	movementPass(classId, true)
	CombatService.EndAwakening(fighter)
	world:Run(0.5)
end

print("== sky, skins, ambience")
do
	-- Sky: a helicopter and at least one blimp on a pass, with their billboards written
	local sky = world.Services.Workspace:FindFirstChild("SB_Sky")
	check(sky ~= nil, "sky folder built")
	local heli = sky and sky:FindFirstChild("Helicopter")
	check(heli ~= nil and heli:FindFirstChild("Body") ~= nil, "helicopter built")
	if heli then
		local height = heli.Body.Position.Y
		check(height > 180 and height < 260, string.format("helicopter flies above the roof (%.0f studs up)", height))
		local pool = sky:FindFirstChild("SpotPool")
		check(pool ~= nil and math.abs(pool.Position.Y - ServerConfig.Arena.FloorY) < 1, "searchlight lands on the grass")
	end
	local shown = 0
	for _, child in (sky and sky:GetChildren()) or {} do
		if string.sub(child.Name, 1, 5) == "Blimp" then
			shown += 1
			local panel = child:FindFirstChild("Billboard", true)
			local title = panel and panel:FindFirstChild("Title", true)
			check(title ~= nil and title.Text ~= "", "blimp billboard has text")
		end
	end
	check(shown >= 1, "a blimp is on a pass")

	-- Skins: everybody wears the cosmic ball while the gamepasses aren't live
	local classBefore = player:GetAttribute("Class")
	local me = fighterOfPlayer(player)
	me.LastCombat = -1000
	ClientRemotes.Event("SelectCharacter"):FireServer("Soccer")
	world:Run(0.3)
	check(player.Character:GetAttribute("BallSkin") == "CosmicBall", "Soccer player wears the cosmic ball")
	check(player:GetAttribute("Skins") == "CosmicBall", "skins are granted automatically")
	check(player.Character:FindFirstChild("Star1", true) ~= nil, "the cosmic ball is built on the character")
	-- ...and the skin follows the class menu: off the ball when you leave Soccer, back on when you return
	me.LastCombat = -1000
	ClientRemotes.Event("SelectCharacter"):FireServer("Basketball")
	world:Run(0.3)
	check(player.Character:GetAttribute("BallSkin") == nil, "the soccer skin comes off when switching to Basketball")
	me.LastCombat = -1000
	ClientRemotes.Event("SelectCharacter"):FireServer("Soccer")
	world:Run(0.3)
	check(player.Character:GetAttribute("BallSkin") == "CosmicBall", "the skin is back after switching to Soccer")
	me.LastCombat = -1000
	ClientRemotes.Event("SelectCharacter"):FireServer(classBefore)
	world:Run(0.3)
	ServerConfig.Shop.GrantAllSkins = false
	local paying = world:AddPlayer("Shopper", 3, false)
	world:Run(2)
	check(paying:GetAttribute("Skins") == "", "without GrantAllSkins and a gamepass, nothing is owned")
	check(paying.Character ~= nil and paying.Character:GetAttribute("BallSkin") == nil, "an unowned skin is not worn")
	ServerConfig.Shop.GrantAllSkins = true
	local plain = Props.BuildBall("Soccer", true)
	local cosmic = Props.BuildBall("Soccer", true, "CosmicBall")
	check(plain:FindFirstChild("Star1") == nil and cosmic:FindFirstChild("Star1") ~= nil, "BuildBall applies the skin")
	check(Props.BuildBall("Basketball", true, "CosmicBall"):FindFirstChild("Star1") == nil, "a soccer skin leaves other balls alone")

	-- Sounds: a hand-picked id plays as given; one that failed to load falls back instead of going silent
	world:Run(1)
	check(ClientSound.Resolve("Soccer_M1_1") == "rbxassetid://114637695466966", "Soccer_M1_1 plays its own id")
	local fallback = ClientSound.Resolve("Soccer_M1_2") -- 130907980308479 never loads in the sim
	check(fallback ~= nil and fallback ~= "rbxassetid://130907980308479", "a sound that fails to load falls back (" .. tostring(fallback) .. ")")

	-- Ambience: quiet mid-pitch, louder against the wall
	local ambience = world.Services.SoundService:FindFirstChild("Loop_CrowdAmbience")
	check(ambience ~= nil, "crowd ambience loop exists")
	if ambience then
		local audio = ServerConfig.Audio
		placePlayer(CFrame.new(0, 3, 0))
		world:Run(3)
		local middle = ambience.Volume
		check(math.abs(middle - audio.AmbienceVolume) < 0.01, string.format("ambience is quiet mid-pitch (%.3f)", middle))
		placePlayer(CFrame.new(Layout.BARRIER_HALF_X - 6, 3, 0))
		world:Run(3)
		local atWall = ambience.Volume
		check(atWall > middle + 0.1 and math.abs(atWall - audio.AmbienceWallVolume) < 0.03, string.format("ambience swells at the wall (%.3f vs %.3f)", atWall, middle))
	end
end

print("== aiming")
do
	-- The camera looks east at a dummy while the character faces north: with AimWithCamera the Light
	-- Kick goes east and lands; without it, it flies north and misses.
	switchClass("Soccer")
	local ClientConfig = client.Require(Shared:WaitForChild("Config"))
	local function throwKick(): number
		faceDummy(1, 50)
		world:Run(0.2)
		local character = player.Character
		local at = character.HumanoidRootPart.Position
		character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
		world.Camera.CameraType = roblox.Enum.CameraType.Scriptable
		world.Camera.CFrame = CFrame.lookAt(at + Vector3.new(-14, 5, 0), at + Vector3.new(30, 0, 0))
		world:Run(4.2) -- cooldown from the last Light Kick
		local before = hits["Soccer_LightKick.Ball"] or 0
		use("1", 1.2)
		world.Camera.CameraType = roblox.Enum.CameraType.Custom
		return (hits["Soccer_LightKick.Ball"] or 0) - before
	end
	ClientConfig.Combat.AimWithCamera = false
	check(throwKick() == 0, "without AimWithCamera the kick leaves where the character faces (and misses)")
	ClientConfig.Combat.AimWithCamera = true
	check(throwKick() >= 1, "with AimWithCamera the kick goes where the camera looks")
end

print("== input")
do
	-- The real input path: Roblox input events -> Controller, not Controller.Use called directly
	local Enum = roblox.Enum
	local UIS = world.Services.UserInputService
	local function send(kind: string, input: any, processed: boolean)
		Sim.Fire(UIS, kind, input, processed)
	end
	local function tapKey(code: any, processed: boolean?)
		local input = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }
		send("InputBegan", input, processed == true)
		send("InputEnded", input, false) -- released straight away: a tap, not a hold
	end
	local function mouse(down: boolean, processed: boolean)
		send(if down then "InputBegan" else "InputEnded", { UserInputType = Enum.UserInputType.MouseButton1 }, processed)
	end
	switchClass("Soccer")
	faceDummy(1, 12)
	world:Run(5) -- cooldowns from the earlier tests

	local before = #requests
	tapKey(Enum.KeyCode.Two)
	world:Run(0.1)
	check(requests[#requests] == "Soccer_LightningShot" and #requests == before + 1, "tapping 2 starts Lightning Shot")
	waitFree(1.5)

	before = #requests
	tapKey(Enum.KeyCode.One, true) -- "processed" by some other Roblox script: a move key still counts
	world:Run(0.1)
	check(requests[#requests] == "Soccer_LightKick" and #requests == before + 1, "a tap on 1 works even if Roblox marked the key as processed")
	waitFree(1)

	before = #requests
	mouse(true, true) -- a click that landed on a button belongs to the UI
	mouse(false, false)
	world:Run(0.1)
	check(#requests == before, "a click on UI doesn't throw an M1")
	mouse(true, false)
	mouse(false, false)
	world:Run(0.1)
	check(#requests == before + 1 and requests[#requests] == "Soccer_M1", "a plain click throws an M1")
	waitFree(1.5)

	-- Clicking a hotbar slot uses the move
	local slotFrame
	for _, d in player.PlayerGui:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text == "4" and d.Parent.ClassName == "Frame" and d.Parent.Active then
			slotFrame = d.Parent
		end
	end
	check(slotFrame ~= nil, "hotbar slots are clickable")
	if slotFrame then
		before = #requests
		Sim.Fire(slotFrame, "InputBegan", { UserInputType = Enum.UserInputType.MouseButton1 })
		world:Run(0.1)
		check(requests[#requests] == "Soccer_BicycleKick" and #requests == before + 1, "clicking slot 4 uses Thunder Bicycle Kick")
		waitFree(1.5)
	end
end

print("== dashes")
do
	local dash = ServerConfig.Dash
	local front = dash.Distance or dash.Speed * dash.Duration
	local side = dash.SideDistance or front
	local back = dash.BackDistance or front
	local function ready()
		for _, id in { "Dash_Front", "Dash_Side", "Dash_Back" } do
			readyFor(Characters.Move(id))
		end
	end
	-- input(rootCFrame) -> movement input; way(rootCFrame) -> the direction the dash should go
	local function dashTest(label: string, distance: number, input, way)
		ready()
		placePlayer(openGround())
		local start = player.Character:FindFirstChild("HumanoidRootPart").CFrame
		world.InputMove = input(start)
		local ok, p = use("Dash", 0.3)
		world.InputMove = Vector3.zero
		check(ok, label .. " dash started")
		local moved = p.Final - p.Start
		moved = Vector3.new(moved.X, 0, moved.Z)
		print(string.format("[test] %s dash: %.1f studs (configured %.1f)", label, p.MaxH, distance))
		check(p.MaxH >= distance * 0.75, string.format("%s dash travels (%.1f of %.1f studs)", label, p.MaxH, distance))
		check(moved.Magnitude > 0.5 and moved.Unit:Dot(way(start)) > 0.8, label .. " dash goes the right way")
		return p
	end
	dashTest("front", front, function()
		return Vector3.zero
	end, function(cf)
		return cf.LookVector
	end)
	-- Straight after a dash, the next one is on cooldown
	local again = Controller.Use("Dash")
	check(not again and Controller.LastReason == "cooldown", "dash respects its cooldown (" .. tostring(Controller.LastReason) .. ")")
	dashTest("right", side, function(cf)
		return cf.RightVector
	end, function(cf)
		return cf.RightVector
	end)
	dashTest("back", back, function(cf)
		return -cf.LookVector
	end, function(cf)
		return -cf.LookVector
	end)
	-- Dashing at the arena wall stops inside it
	ready()
	local x = Layout.BARRIER_HALF_X - 6
	placePlayer(CFrame.lookAt(Vector3.new(x, 3, 0), Vector3.new(x + 10, 3, 0)))
	use("Dash", 0.5)
	world:Run(0.3)
	local inside = insideArena(player.Character:FindFirstChild("HumanoidRootPart").Position)
	print(string.format("[test] dash at the wall stopped %.1f studs inside it", inside))
	check(inside >= 1, string.format("dash stops at the arena wall (%.1f studs inside)", inside))

	-- Dashing into an enemy stops on them and throws the class's strike
	for _, classId in classes do
		switchClass(classId)
		ready()
		faceDummy(1, 10)
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		local before = { Catch = hits["Dash_Front.Catch"] or 0, Strike = hits["Dash_Front.Strike"] or 0 }
		local start = root.Position
		use("Dash", 1.2)
		local caught = (hits["Dash_Front.Catch"] or 0) > before.Catch
		local struck = (hits["Dash_Front.Strike"] or 0) > before.Strike
		local travelled = (root.Position - start) * Vector3.new(1, 0, 1)
		print(string.format("[test] %s dash into a dummy: caught=%s struck=%s, stopped after %.1f studs", classId, tostring(caught), tostring(struck), travelled.Magnitude))
		check(caught and struck, classId .. " dash strikes the enemy it runs into")
		check(travelled.Magnitude < 14, classId .. " dash stops at the enemy instead of running through")
	end
end

print("== knockback on a dummy")
do
	resetDummies()
	local botFighter = fighterOfPlayer(bot)
	local dummy = dummies:GetChildren()[2]
	local victim = CombatService.Get(dummy)
	if botFighter and victim then
		botFighter.InvulnUntil = 0
		botFighter.BusyUntil = 0
		botFighter.M1ReadyAt = 0
		bot.Character:PivotTo(CFrame.lookAt(victim.Root.Position - Vector3.new(4, 0, 0), victim.Root.Position))
		local move = Characters.Move("Soccer_M1")
		local token = 7001
		check(MoveService.Start(botFighter, move, token, Vector3.new(1, 0, 0), "4R") == true, "bot finisher accepted")
		local before = victim.Root.Position
		CombatService.ApplyHit(botFighter, victim, botFighter.Active[token], "Hit4", move.Hits.Hit4, victim.Root.Position)
		world:Run(0.4)
		local d = victim.Root.Position - before
		check(Vector3.new(d.X, 0, d.Z).Magnitude >= 3, string.format("knockback pushes a dummy (%.1f studs)", Vector3.new(d.X, 0, d.Z).Magnitude))
	else
		check(false, "bot and dummy exist for the knockback test")
	end
end

print("== getting hit, evasive")
do
	local playerFighter = fighterOfPlayer(player)
	playerFighter.InvulnUntil = 0
	local botFighter = fighterOfPlayer(bot)
	if botFighter and playerFighter then
		botFighter.InvulnUntil = 0
		botFighter.BusyUntil = 0
		botFighter.M1ReadyAt = 0
		placePlayer(openGround())
		local move = Characters.Move("Soccer_M1")
		local ok = MoveService.Start(botFighter, move, 1, Vector3.new(0, 0, -1), "4R")
		check(ok == true, "bot move accepted")
		local active = botFighter.Active[1]
		local before = playerFighter.Root.Position
		CombatService.ApplyHit(botFighter, playerFighter, active, "Hit4", move.Hits.Hit4, playerFighter.Root.Position)
		world:Run(0.4)
		local d = playerFighter.Root.Position - before
		check(Vector3.new(d.X, 0, d.Z).Magnitude >= 3, string.format("knockback pushes the player (%.1f studs)", Vector3.new(d.X, 0, d.Z).Magnitude))
		check((player.Character:GetAttribute("StunUntil") or 0) > world:Now() + 1000, "stunned after being hit")
		player:SetAttribute("Evasive", 100)
		local evaded = use("Dash", 0.3)
		check(evaded, "evasive used while stunned")
		world:Run(1)
	else
		check(false, "bot fighter exists")
	end
end

print("== KO and respawn")
do
	local dummy = dummies:GetChildren()[1]
	dummy:FindFirstChildOfClass("Humanoid").Health = 0
	local character = player.Character
	character:FindFirstChildOfClass("Humanoid").Health = 0
	world:Run(5.5)
	check(player.Character ~= character, "player respawned")
	check(#dummies:GetChildren() >= 4, "dummy respawned")
end

-- Report
print("\n== confirmed hits")
local keys = {}
for k in hits do
	table.insert(keys, k)
end
table.sort(keys)
for _, k in keys do
	print(string.format("  %-40s %d", k, hits[k]))
end
-- Every move the player used must visibly animate the body
print("\n== animation (largest joint rotation away from the starting pose)")
local animIds = {}
for id in animSeen do
	table.insert(animIds, id)
end
table.sort(animIds)
for _, id in animIds do
	print(string.format("  %-32s %6.1f deg  %s", id, animSeen[id], animJoint[id] or "-"))
	check(animSeen[id] >= 25, string.format("%s animates the body (largest joint rotation %.1f deg)", id, animSeen[id]))
end
local testedClasses = { Common = true }
for _, c in classes do
	testedClasses[c] = true
end
for id, move in Characters.Moves do
	if testedClasses[move.Class] and animSeen[id] == nil and not (move.Class == "Common" and only ~= nil) then
		check(false, id .. " was never played")
	end
end
print("\n== movement (horizontal / upward travel)")
local moverIds = {}
for id in moverResults do
	table.insert(moverIds, id)
end
table.sort(moverIds)
for _, id in moverIds do
	local p = moverResults[id]
	print(string.format("  %-32s H %5.1f  V %5.1f", id, p.MaxH, p.MaxV))
end

-- Every damaging move should have landed at least once
local missing = {}
for id, move in Characters.Moves do
	local class = move.Class
	local tested = false
	for _, c in classes do
		if c == class then
			tested = true
		end
	end
	if tested and next(move.Hits) and move.Slot ~= "Awaken" then
		local landed = false
		for k in hits do
			if string.sub(k, 1, #id + 1) == id .. "." then
				landed = true
			end
		end
		if not landed then
			table.insert(missing, id)
		end
	end
end
table.sort(missing)
print("\nmoves that never landed a hit: " .. (if #missing > 0 then table.concat(missing, ", ") else "none"))

local uniqueWarnings = {}
for _, w in world.Warnings do
	uniqueWarnings[w] = (uniqueWarnings[w] or 0) + 1
end
-- The animator and the move runner only warn about real problems (a missing mark, a body it can't
-- animate, a script error)
for w in uniqueWarnings do
	if string.find(w, "[Animator]", 1, true) or string.find(w, "[MoveRunner]", 1, true) then
		check(false, "warning: " .. w)
	end
end
print("\n== sounds")
do
	local expected = {
		"Soccer_M1_1", "Soccer_M1_2", "Soccer_M1_3", "Soccer_M1_4", "Soccer_LightKick", "Soccer_LightKickHit", "Soccer_LightningShot",
		"Soccer_DashRun", "Soccer_DashKick", "Soccer_DashLightning", "Soccer_BicycleLeap", "Soccer_BicycleImpact",
		"Soccer_BicycleLightning", "Soccer_AwakenIntro", "Soccer_AwakenElectricity", "Soccer_AwakenTheme",
	}
	if only == nil or table.find(only, "Soccer") then
		for _, name in expected do
			check((soundsPlayed[name] or 0) > 0, "Soccer sound played: " .. name)
		end
	end
	local stray = {}
	for _, s in world.Services.SoundService:GetChildren() do
		if s.ClassName == "Sound" and s.Name == "Soccer_AwakenTheme" then
			table.insert(stray, s)
		end
	end
	check(#stray == 0, "the awakening theme is gone once the awakening ends")
end

print("\n== warnings")
for w, n in uniqueWarnings do
	print(string.format("  (%dx) %s", n, w))
end
print("\n== server log (last 40)")
for i = math.max(1, #world.Log - 40), #world.Log do
	print("  " .. world.Log[i])
end
print(string.format("\n%d error(s)", #world.Errors))
local _ = game
local _s = Sim
local _t = task
if #world.Errors > 0 then
	process.exit(1)
end
process.exit(0)
