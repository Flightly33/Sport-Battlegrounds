--[[
	Bakes the stadium into map/Stadium.rbxm (included in the place by default.project.json), and
	optionally writes a JSON part list for blender/preview_stadium.py.

	lune run tools/lune/bake_stadium.luau [preview.json]
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Loader = require("./loader")

local Builder = Loader.Require("ReplicatedStorage.Shared.Stadium.Builder")
local stadium = Builder.Build()

local counts = {}
local total = 0
for _, d in stadium:GetDescendants() do
	if d:IsA("BasePart") then
		total += 1
		local top = d
		while top.Parent and top.Parent ~= stadium do
			top = top.Parent
		end
		counts[top.Name] = (counts[top.Name] or 0) + 1
	end
end
local names = {}
for name in counts do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	print(string.format("  %-12s %5d parts", name, counts[name]))
end
print(string.format("  %-12s %5d parts", "TOTAL", total))

fs.writeFile("map/Stadium.rbxm", roblox.serializeModel({ stadium }))
print("wrote map/Stadium.rbxm")

local previewPath = process.args[1]
if previewPath then
	local parts = {}
	for _, d in stadium:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local c = d.Color
			local shape = if d:IsA("Part") then d.Shape.Name else "Block"
			table.insert(parts, {
				cf = { d.CFrame:GetComponents() },
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				color = { c.R, c.G, c.B },
				material = d.Material.Name,
				shape = shape,
				transparency = d.Transparency,
			})
		end
	end
	fs.writeFile(previewPath, serde.encode("json", parts))
	print("wrote", previewPath, #parts, "parts")
end
