--[[
	Writes the crowd (as the client builds it) to JSON for blender/preview_stadium.py.
	lune run tools/lune/preview_crowd.luau <out.json> [fans]
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Loader = require("./loader")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local CrowdLayout = Loader.Require("ReplicatedStorage.Shared.Stadium.CrowdLayout")

local out = process.args[1] or "blender/out/preview/crowd.json"
local count = tonumber(process.args[2]) or 4200
local fans = CrowdLayout.Generate(count, 2026)
local parts = {}
for i, fan in fans do
	local base = CFrame.lookAt(fan.Position, fan.Position + fan.Facing)
	local body = CrowdLayout.BodySize(fan.Scale)
	local head = CrowdLayout.HeadSize(fan.Scale)
	local c = fan.Color
	table.insert(parts, { cf = { (base * CFrame.new(0, body.Y / 2, 0)):GetComponents() }, size = { body.X, body.Y, body.Z }, color = { c.R, c.G, c.B }, material = "SmoothPlastic", shape = "Block" })
	local skin = if i % 3 == 0 then { 0.43, 0.29, 0.22 } elseif i % 3 == 1 then { 0.92, 0.76, 0.63 } else { 0.75, 0.55, 0.39 }
	table.insert(parts, { cf = { (base * CFrame.new(0, body.Y + head.Y * 0.45, 0)):GetComponents() }, size = { head.X, head.Y, head.Z }, color = skin, material = "SmoothPlastic", shape = "Ball" })
end
fs.writeFile(out, serde.encode("json", parts))
print(string.format("%d fans (%d parts) -> %s", #fans, #parts, out))
