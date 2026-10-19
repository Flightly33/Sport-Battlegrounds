local roblox = require("@lune/roblox")
local db = roblox.getReflectionDatabase()
local function has(className, prop)
	local c = db:GetClass(className)
	while c do
		if c.Properties[prop] then return true, c.Properties[prop].Scriptability end
		c = c.Superclass and db:GetClass(c.Superclass)
	end
	return false
end
for _, q in {
	{"BasePart","Position"},{"BasePart","AssemblyLinearVelocity"},{"BasePart","LocalTransparencyModifier"},{"BasePart","CFrame"},{"BasePart","Color"},
	{"Humanoid","Health"},{"Humanoid","MoveDirection"},{"Humanoid","FloorMaterial"},{"Humanoid","WalkSpeed"},{"Humanoid","AutoRotate"},
	{"Attachment","WorldPosition"},{"Motor6D","Transform"},{"Camera","CFrame"},{"Camera","FieldOfView"},{"ScreenGui","AbsoluteSize"},
	{"GuiObject","AbsoluteSize"},{"Player","Character"},{"Player","UserId"},{"Player","DisplayName"},{"Model","PrimaryPart"},
	{"LinearVelocity","VectorVelocity"},{"Trail","Enabled"},{"SurfaceGui","Brightness"},{"UserInputService","MouseBehavior"},{"Sound","PlaybackSpeed"},
	{"Highlight","Adornee"},{"BillboardGui","StudsOffsetWorldSpace"},{"Workspace","Gravity"},{"Workspace","CurrentCamera"},{"Instance","Archivable"},
} do
	print(q[1], q[2], has(q[1], q[2]))
end
