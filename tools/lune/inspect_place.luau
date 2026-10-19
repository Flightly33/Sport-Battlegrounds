--[[ Prints the script tree of a built place and counts parts (sanity check of the Rojo build). ]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "SportsBattlegrounds.rbxl"))
local function walk(inst, depth)
	if inst:IsA("LuaSourceContainer") or inst:IsA("Folder") and depth < 4 then
		print(string.rep("  ", depth) .. inst.ClassName .. " " .. inst.Name)
	end
	for _, c in inst:GetChildren() do
		if not (c:IsA("BasePart") or c.Name == "Stadium") then
			walk(c, depth + 1)
		end
	end
end
for _, service in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	walk(game:GetService(service), 0)
end
local stadium = game:GetService("Workspace"):FindFirstChild("Stadium")
local parts = 0
if stadium then
	for _, d in stadium:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
end
print("Workspace.Stadium parts:", parts)
print("Players.CharacterAutoLoads:", game:GetService("Players").CharacterAutoLoads)
local lighting = game:GetService("Lighting")
print("Lighting:", lighting.Technology, lighting.ClockTime, #lighting:GetChildren(), "effects")
