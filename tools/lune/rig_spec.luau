local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
--[[
	Approximation of the default R15 (block) rig, for offline pose previews only. In game the animator
	reads the real joints from each avatar.
]]
local spec = {
	Root = { Part0 = "HumanoidRootPart", Part1 = "LowerTorso", C0 = CFrame.new(0, -1, 0), C1 = CFrame.new(0, -0.2, 0) },
	Waist = { Part0 = "LowerTorso", Part1 = "UpperTorso", C0 = CFrame.new(0, 0.2, 0), C1 = CFrame.new(0, -0.8, 0) },
	Neck = { Part0 = "UpperTorso", Part1 = "Head", C0 = CFrame.new(0, 0.8, 0), C1 = CFrame.new(0, -0.5, 0) },
	RightShoulder = { Part0 = "UpperTorso", Part1 = "RightUpperArm", C0 = CFrame.new(1, 0.56, 0), C1 = CFrame.new(-0.5, 0.42, 0) },
	RightElbow = { Part0 = "RightUpperArm", Part1 = "RightLowerArm", C0 = CFrame.new(0, -0.42, 0), C1 = CFrame.new(0, 0.35, 0) },
	RightWrist = { Part0 = "RightLowerArm", Part1 = "RightHand", C0 = CFrame.new(0, -0.5, 0), C1 = CFrame.new(0, 0.12, 0) },
	LeftShoulder = { Part0 = "UpperTorso", Part1 = "LeftUpperArm", C0 = CFrame.new(-1, 0.56, 0), C1 = CFrame.new(0.5, 0.42, 0) },
	LeftElbow = { Part0 = "LeftUpperArm", Part1 = "LeftLowerArm", C0 = CFrame.new(0, -0.42, 0), C1 = CFrame.new(0, 0.35, 0) },
	LeftWrist = { Part0 = "LeftLowerArm", Part1 = "LeftHand", C0 = CFrame.new(0, -0.5, 0), C1 = CFrame.new(0, 0.12, 0) },
	RightHip = { Part0 = "LowerTorso", Part1 = "RightUpperLeg", C0 = CFrame.new(0.5, -0.2, 0), C1 = CFrame.new(0, 0.42, 0) },
	RightKnee = { Part0 = "RightUpperLeg", Part1 = "RightLowerLeg", C0 = CFrame.new(0, -0.42, 0), C1 = CFrame.new(0, 0.42, 0) },
	RightAnkle = { Part0 = "RightLowerLeg", Part1 = "RightFoot", C0 = CFrame.new(0, -0.5, 0), C1 = CFrame.new(0, 0.09, 0) },
	LeftHip = { Part0 = "LowerTorso", Part1 = "LeftUpperLeg", C0 = CFrame.new(-0.5, -0.2, 0), C1 = CFrame.new(0, 0.42, 0) },
	LeftKnee = { Part0 = "LeftUpperLeg", Part1 = "LeftLowerLeg", C0 = CFrame.new(0, -0.42, 0), C1 = CFrame.new(0, 0.42, 0) },
	LeftAnkle = { Part0 = "LeftLowerLeg", Part1 = "LeftFoot", C0 = CFrame.new(0, -0.5, 0), C1 = CFrame.new(0, 0.09, 0) },
}

local sizes = {
	LowerTorso = Vector3.new(2, 0.4, 1),
	UpperTorso = Vector3.new(2, 1.6, 1),
	Head = Vector3.new(1.2, 1.2, 1.2),
	RightUpperArm = Vector3.new(1, 1.2, 1),
	RightLowerArm = Vector3.new(1, 1.05, 1),
	RightHand = Vector3.new(1, 0.3, 1),
	LeftUpperArm = Vector3.new(1, 1.2, 1),
	LeftLowerArm = Vector3.new(1, 1.05, 1),
	LeftHand = Vector3.new(1, 0.3, 1),
	RightUpperLeg = Vector3.new(1, 1.2, 1),
	RightLowerLeg = Vector3.new(1, 1.15, 1),
	RightFoot = Vector3.new(1, 0.3, 1),
	LeftUpperLeg = Vector3.new(1, 1.2, 1),
	LeftLowerLeg = Vector3.new(1, 1.15, 1),
	LeftFoot = Vector3.new(1, 0.3, 1),
}

return { Spec = spec, Sizes = sizes, HipHeight = 2 }
