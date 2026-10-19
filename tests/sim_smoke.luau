--[[
	End-to-end smoke test in the simulator (tools/sim): boots the real server and client scripts, then
	plays every move of every character against the training dummies, gets hit by a bot, uses the
	evasive, awakens, dies and respawns. Fails on any runtime error.

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
-- Keep the simulator fast: a token crowd (the real one is 6,700 fans)
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
local MoveService = server.Require(SSS.Server:WaitForChild("MoveService"))
local Props = server.Require(Shared:WaitForChild("Props"))
local Controller = client.Require(world.Services.StarterPlayer.StarterPlayerScripts.Client:WaitForChild("Controller"))
local ClientRemotes = client.Require(Shared:WaitForChild("Remotes"))

local ServerRemotes = server.Require(Shared:WaitForChild("Remotes"))
ServerRemotes.Event("HitRequest").OnServerEvent:Connect(function(_p, token, hitName, targets)
	print(string.format("[test] HitRequest token=%s hit=%s targets=%d", tostring(token), tostring(hitName), #targets))
end)
ServerRemotes.Event("MoveRequest").OnServerEvent:Connect(function(_p, token, moveId)
	print(string.format("[test] MoveRequest token=%s %s", tostring(token), tostring(moveId)))
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

local function resetDummies()
	for _, d in dummies:GetChildren() do
		local h = d:FindFirstChildOfClass("Humanoid")
		local f = CombatService.Get(d)
		if h and h.Health > 0 and f then
			h.Health = h.MaxHealth
			f.StunUntil = 0
			f.KnockdownUntil = 0
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
	local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")
	local target = dummyRoot.Position
	local from = target + Vector3.new(-distance, 0, 0)
	character:PivotTo(CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z)))
end

local function switchClass(classId: string)
	local fighter = fighterOfPlayer(player)
	player:SetAttribute("Class", classId)
	CombatService.SetClass(fighter, classId)
	Props.Attach(fighter.Model, classId)
	fighter.LastCombat = 0
end

local function waitFree(extra: number?)
	-- wait until the local player is no longer busy
	local deadline = os.clock() + 4
	while Controller.IsBusy() and os.clock() < deadline do
		world:Run(0.1)
	end
	world:Run(extra or 0.25)
end

local MoveRunner = client.Require(world.Services.StarterPlayer.StarterPlayerScripts.Client:WaitForChild("MoveRunner"))
local function use(slot: string, settle: number?)
	local ok = Controller.Use(slot)
	if process.env.SIM_TRACE then
		world:Run(0.05)
		local c = player.Character
		local n = 0
		for _, ctx in MoveRunner.Active(c) do
			n += 1
			print(string.format("[trace] %s active=%s cancelled=%s stun=%s now=%s", ctx.Move.Id, tostring(not ctx.Finished), tostring(ctx.Cancelled), tostring(c:GetAttribute("StunUntil")), tostring(os.clock() + 1000)))
		end
		print("[trace] use", slot, ok, "active contexts", n)
	end
	if not ok then
		print(string.format("[test] Use(%s) did not start: %s", slot, Controller.LastReason))
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		print("   character:", c, c and c.Parent, "health:", h and h.Health, "root:", c and c:FindFirstChild("HumanoidRootPart"))
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		print("   character:", c, c and c.Parent, "health:", h and h.Health, "root:", c and c:FindFirstChild("HumanoidRootPart"))
	end
	waitFree(settle)
	return ok
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
	-- Moves 1-4 (re-aim before each; dummies get knocked around)
	for slot = 1, 4 do
		faceDummy(slot % 3 + 1, if slot == 2 then 12 else 6)
		use(tostring(slot), 0.8)
		world:Run(0.6)
	end
	-- Dash
	use("Dash", 0.2)
	-- Awaken (Studio start: meter full) and the awakened moves
	player:SetAttribute("Awaken", 100)
	faceDummy(2, 8)
	use("Awaken", 0.5)
	world:Run(1.5)
	check(player.Character:GetAttribute("Awakened") == true, classId .. " awakened")
	for slot = 1, 4 do
		faceDummy(slot % 3 + 1, if slot == 1 then 20 else 7)
		use(tostring(slot), 1.0)
		world:Run(if slot == 4 then 3.5 else 0.8)
	end
	CombatService.EndAwakening(fighter)
	world:Run(0.5)
end

print("== getting hit, evasive")
do
	local playerFighter = fighterOfPlayer(player)
	playerFighter.InvulnUntil = 0
	local botFighter = fighterOfPlayer(bot)
	if botFighter and playerFighter then
		botFighter.InvulnUntil = 0
		local move = Characters.Move("Soccer_M1")
		local ok = MoveService.Start(botFighter, move, 1, Vector3.new(0, 0, -1), "4R")
		check(ok == true, "bot move accepted")
		local active = botFighter.Active[1]
		CombatService.ApplyHit(botFighter, playerFighter, active, "Hit4", move.Hits.Hit4, playerFighter.Root.Position)
		world:Run(0.4)
		check((player.Character:GetAttribute("StunUntil") or 0) > os.clock() + 1000, "stunned after being hit")
		player:SetAttribute("Evasive", 100)
		local evaded = Controller.Use("Dash")
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
