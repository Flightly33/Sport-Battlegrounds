local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
--[[
	Offline animation preview: evaluates the real animator modules on an approximate R15 rig and writes
	every part's CFrame to JSON, which blender/preview_poses.py renders as contact sheets.

	lune run tools/lune/preview_anim.luau <out.json> [case ...]
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Loader = require("./loader")
local RigSpec = require("./rig_spec")

local Rig = Loader.Require("ReplicatedStorage.Shared.Anim.Rig")
local Pose = Loader.Require("ReplicatedStorage.Shared.Anim.Pose")
local Locomotion = Loader.Require("ReplicatedStorage.Shared.Anim.Locomotion")
local Styles = Loader.Require("ReplicatedStorage.Shared.Anim.Styles")
local Props = Loader.Require("ReplicatedStorage.Shared.Props")

local outPath = process.args[1] or "blender/out/preview/poses.json"
local wanted = {}
for i = 2, #process.args do
	wanted[process.args[i]] = true
end

local COLORS = {
	Head = { 1, 0.85, 0.6 },
	UpperTorso = { 0.2, 0.45, 0.9 },
	LowerTorso = { 0.15, 0.3, 0.7 },
	RightUpperArm = { 0.95, 0.35, 0.3 },
	RightLowerArm = { 0.95, 0.55, 0.4 },
	RightHand = { 1, 0.8, 0.6 },
	LeftUpperArm = { 0.3, 0.8, 0.4 },
	LeftLowerArm = { 0.45, 0.9, 0.5 },
	LeftHand = { 1, 0.8, 0.6 },
	RightUpperLeg = { 0.85, 0.25, 0.25 },
	RightLowerLeg = { 0.95, 0.4, 0.35 },
	RightFoot = { 0.3, 0.1, 0.1 },
	LeftUpperLeg = { 0.2, 0.65, 0.3 },
	LeftLowerLeg = { 0.3, 0.75, 0.4 },
	LeftFoot = { 0.1, 0.3, 0.1 },
}

local fakeCharacter = {
	FindFirstChildOfClass = function()
		return { HipHeight = RigSpec.HipHeight }
	end,
	FindFirstChild = function()
		return nil
	end,
}

local function buildRig(classId: string)
	local spec = table.clone(RigSpec.Spec)
	local info = Props.Info[classId]
	if info then
		spec.Prop = { Part0 = info.Part0, Part1 = "SB_PropHandle", C0 = info.RestC0(fakeCharacter :: any), C1 = CFrame.identity }
	end
	return Rig.FromSpec(spec), info
end

local function cfList(cf)
	return { cf:GetComponents() }
end

local function frame(rig, info, resolved, label)
	local transforms = {}
	for name, l in resolved do
		local joint = rig.Joints[name]
		if joint then
			transforms[name] = Rig.ToTransform(joint, l)
		end
	end
	local root = CFrame.new(0, RigSpec.HipHeight + 1, 0)
	local world = Rig.SolveWorld(rig, transforms, root)
	local parts = {}
	for name, cf in world do
		local size = RigSpec.Sizes[name]
		if size then
			table.insert(parts, { name = name, cf = cfList(cf), size = { size.X, size.Y, size.Z }, color = COLORS[name] or { 0.7, 0.7, 0.7 }, shape = "Block" })
		end
	end
	local handle = world.SB_PropHandle
	if handle and info then
		for _, p in info.Build(CFrame.identity) do
			local c = p.Color
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local shape = if mesh then "Ball" else p.Shape.Name
			table.insert(parts, { name = p.Name, cf = cfList(handle * p.CFrame), size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { c.R, c.G, c.B }, shape = shape })
		end
	end
	return { label = label, parts = parts }
end

local cases = {}

-- Locomotion: run the real Advance() loop at a given local velocity, sample frames over one cycle.
local function locomotionCase(name: string, styleName: string, velocity: Vector3, grounded: boolean, samples: number, span: number?)
	table.insert(cases, function()
		local style = Styles[styleName]
		local rig, info = buildRig(styleName)
		local state = Locomotion.NewState()
		local dt = 1 / 60
		for _ = 1, 120 do
			Locomotion.Advance(style, state, dt, velocity, grounded)
			Locomotion.Evaluate(style, state)
		end
		local frames = {}
		local total = span or 1
		-- Sample evenly over one gait cycle (or `span` seconds when idle)
		local freqProbe = state.Phase
		local steps = 0
		local frameEvery = math.max(1, math.floor((if velocity.Magnitude > 1 then 0.5 else total) * 60 / samples))
		while #frames < samples and steps < 6000 do
			Locomotion.Advance(style, state, dt, velocity, grounded)
			local pose = Locomotion.Evaluate(style, state)
			steps += 1
			if steps % frameEvery == 0 then
				local resolved = Pose.Resolve(rig, pose)
				table.insert(frames, frame(rig, info, resolved, string.format("%s t=%.2f ph=%.2f", name, state.Time, state.Phase)))
			end
		end
		local _ = freqProbe
		return { name = name, frames = frames }
	end)
end

-- Clip: sample a clip layered over the idle pose.
local function clipCase(name: string, styleName: string, clip, samples: number)
	table.insert(cases, function()
		local style = Styles[styleName]
		local rig, info = buildRig(styleName)
		local state = Locomotion.NewState()
		local frames = {}
		for i = 0, samples - 1 do
			local t = clip.Length * i / math.max(1, samples - 1)
			local base = Pose.Resolve(rig, Locomotion.Evaluate(style, state))
			local over = Pose.Resolve(rig, Pose.Sample(clip, t))
			Pose.Blend(base, over, clip.Channels, 1)
			table.insert(frames, frame(rig, info, base, string.format("%s t=%.2f", name, t)))
		end
		return { name = name, frames = frames }
	end)
end

for _, styleName in { "Soccer", "Basketball", "Football", "Baseball" } do
	locomotionCase(styleName .. "_Idle", styleName, Vector3.zero, true, 4, 3)
	locomotionCase(styleName .. "_Walk", styleName, Vector3.new(0, 0, -16), true, 8)
	locomotionCase(styleName .. "_Run", styleName, Vector3.new(0, 0, -28), true, 8)
end
locomotionCase("Soccer_Strafe", "Soccer", Vector3.new(16, 0, 0), true, 6)
locomotionCase("Soccer_Back", "Soccer", Vector3.new(0, 0, 16), true, 6)
locomotionCase("Soccer_Jump", "Soccer", Vector3.new(0, 30, 0), false, 2)
locomotionCase("Soccer_Fall", "Soccer", Vector3.new(0, -30, 0), false, 2)

-- Clip libraries register their clips here so every clip can be previewed by name.
local okClips, Clips = pcall(Loader.Require, "ReplicatedStorage.Shared.Anim.Clips")
if okClips and Clips then
	for clipName, entry in Clips.All do
		clipCase("Clip_" .. clipName, entry.Style, entry.Clip, entry.Samples or 8)
	end
end

local out = {}
for _, make in cases do
	local result = make()
	if next(wanted) == nil or wanted[result.name] then
		table.insert(out, result)
	end
end
local dir = string.match(outPath, "^(.*)/[^/]*$")
if dir and not fs.isDir(dir) then
	fs.writeDir(dir)
end
fs.writeFile(outPath, serde.encode("json", out))
print(string.format("wrote %d cases to %s", #out, outPath))
