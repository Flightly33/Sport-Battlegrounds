--[[
	Moves every fighter shares: the four dashes and the evasive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared.Anim.Clips)
local Config = require(Shared.Config)

local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)

type Ctx = MoveRunner.Ctx

local function dash(ctx: Ctx)
	local root = ctx.Root
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local v = ctx.Variant
	local dash = Config.Dash
	local dir, clip, distance
	if v == "B" then
		dir, clip, distance = -look, Clips.Common.DashBack, dash.BackDistance
	elseif v == "L" then
		dir, clip, distance = -right, Clips.Common.DashLeft, dash.SideDistance
	elseif v == "R" then
		dir, clip, distance = right, Clips.Common.DashRight, dash.SideDistance
	else
		dir, clip, distance = look, Clips.Common.DashFront, dash.Distance
	end
	ctx:Play(clip)
	-- Eased dash (snappy start, soft stop), stopped by walls and the arena edge - see Client/Motion
	ctx:Dash(dir, distance, dash.Duration, dash.Carry)
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	FX.Afterimage(ctx.Character, ctx.Palette.Primary, 0.22, Enum.Material.ForceField)
	FX.Smoke(feet, Color3.fromRGB(200, 195, 185), 6, 1.2, 0.6, 2)
	FX.Ring(CFrame.lookAt(root.Position, root.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), ctx.Palette.Core, 1, 3.5, 0.2, 0.25, 12)
	Sound.Play("Whoosh", root.Position, 0.8)
	if ctx.IsOwner then
		CameraFX.SpeedLines(Config.Dash.Duration + 0.05, ctx.Palette.Core)
	end
	ctx:Wait(Config.Dash.Duration)
	FX.Afterimage(ctx.Character, ctx.Palette.Primary, 0.18, Enum.Material.ForceField)
	ctx:Wait(0.05)
end

local function evasive(ctx: Ctx)
	local root = ctx.Root
	ctx:Play(Clips.Common.Evasive)
	ctx:Velocity(-root.CFrame.LookVector * 55 + Vector3.new(0, 30, 0), 0.22)
	FX.Flash(root.Position, Color3.new(1, 1, 1), 8, 0.2)
	FX.Shell(root.Position, ctx.Palette.Primary, 1, 9, 0.3)
	FX.Ring(CFrame.new(root.Position - Vector3.new(0, 2.5, 0)), Color3.new(1, 1, 1), 1, 10, 0.3, 0.6)
	FX.Afterimage(ctx.Character, Color3.new(1, 1, 1), 0.3)
	FX.Popup(root.Position + Vector3.new(0, 3, 0), "EVASIVE", Color3.new(1, 1, 1), 1)
	Sound.Play("Whoosh", root.Position, 0.6)
	ctx:Wait(0.36)
end

return {
	Dash_Front = { Run = dash },
	Dash_Side = { Run = dash },
	Dash_Back = { Run = dash },
	Evasive = { Run = evasive },
} :: { [string]: MoveRunner.MoveScript }
