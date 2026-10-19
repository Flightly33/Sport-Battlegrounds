--[[
	AwakenVFX: the Soccer awakening's aura, built from Studio-made effect templates.

	Templates (made in Studio, looked up in ReplicatedStorage.VFXAssets, then ReplicatedStorage):
		vfx_Rig     a rig whose body parts hold the effects. Each part's Attachments, ParticleEmitters,
		            Beams and Sounds are copied onto the matching body part of every character, disabled.
		            Emitters inside a folder named "Transformation" are the one-off burst; everything
		            else is the looping aura. On the HumanoidRootPart, a "TransformSounds" folder plays
		            at the burst and an "AuraSound" loops while awakened.
		GroundVFX   effects for a ring under the feet, following the character.
	To keep them in the project, export both from Studio as .rbxm files into assets/ (it builds into
	ReplicatedStorage.VFXAssets).

	The effects switch on at the awakening clip's Burst mark (the climax) and off when the awakening
	ends or the character dies. Only Soccer characters light up (AWAKEN_CLASS).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared.Anim.Clips)

local CombatService = require(script.Parent.CombatService)

local AwakenVFX = {}

local AWAKEN_CLASS = "Soccer"
local BURST_LENGTH = 0.75 -- seconds the Transformation emitters run for
local BURST_DELAY = Clips.Soccer.Awaken.Marks.Burst or 1.2

local warned = false
local function template(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("VFXAssets")
	local found = (assets and assets:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name)
	if not found and name == "vfx_Rig" and not warned then
		warned = true
		warn("[AwakenVFX] no vfx_Rig in ReplicatedStorage.VFXAssets or ReplicatedStorage; the Soccer awakening aura is off")
	end
	return found
end

local function isEffect(v: Instance): boolean
	return v:IsA("ParticleEmitter") or v:IsA("Beam")
end

local function disableAll(root: Instance)
	if isEffect(root) then
		(root :: any).Enabled = false
	end
	for _, v in root:GetDescendants() do
		if isEffect(v) then
			(v :: any).Enabled = false
		end
	end
end

local function inBurst(v: Instance): boolean
	local parent = v.Parent
	return parent ~= nil and parent.Parent ~= nil and parent.Parent.Name == "Transformation"
end

-- Copies the template effects onto a freshly spawned character (all disabled).
local function copyRig(character: Model)
	local rig = template("vfx_Rig")
	if not rig then
		return
	end
	for _, source in rig:GetChildren() do
		local target = if source:IsA("BasePart") then character:FindFirstChild(source.Name) else nil
		if target then
			for _, obj in source:GetChildren() do
				local keep = obj:IsA("Attachment")
					or isEffect(obj)
					or obj:IsA("Sound")
					or (obj:IsA("Folder") and (obj:FindFirstChildOfClass("Attachment") ~= nil or obj:FindFirstChildOfClass("Sound") ~= nil))
				if keep then
					local clone = obj:Clone()
					disableAll(clone)
					clone.Parent = target
				end
			end
		end
	end
end

-- A ring of effects at the feet, welded to the root so it follows without a per-frame update.
local function addGround(character: Model)
	local ground = template("GroundVFX")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not ground or not root or not humanoid then
		return
	end
	local part = Instance.new("Part")
	part.Name = "GroundVFX"
	part.Size = Vector3.one
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local drop = root.Size.Y / 2 + humanoid.HipHeight
	part.CFrame = CFrame.new(root.Position - Vector3.new(0, drop, 0))
	local attachment = Instance.new("Attachment")
	attachment.Name = "GroundAttachment"
	attachment.Parent = part
	for _, v in ground:GetChildren() do
		local clone = v:Clone()
		disableAll(clone)
		clone.Parent = attachment
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

local function setAura(character: Model, on: boolean)
	for _, v in character:GetDescendants() do
		if isEffect(v) then
			if inBurst(v) then
				if on then
					(v :: any).Enabled = true
					task.delay(BURST_LENGTH, function()
						(v :: any).Enabled = false
					end)
				end
			else
				(v :: any).Enabled = on
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local transformSounds = root:FindFirstChild("TransformSounds")
	local auraSound = root:FindFirstChild("AuraSound")
	if on and transformSounds then
		for _, sound in transformSounds:GetChildren() do
			if sound:IsA("Sound") then
				sound:Play()
			end
		end
	end
	if auraSound and auraSound:IsA("Sound") then
		if on then
			auraSound.Looped = true
			auraSound:Play()
		else
			auraSound:Stop()
		end
	end
end

-- Called by CharacterService for every spawned character.
function AwakenVFX.Attach(character: Model)
	copyRig(character)
	addGround(character)
	local lit = false
	local stamp = 0
	character:GetAttributeChangedSignal("Awakened"):Connect(function()
		stamp += 1
		local mine = stamp
		if character:GetAttribute("Awakened") then
			local fighter = CombatService.Get(character)
			if not fighter or fighter.Class ~= AWAKEN_CLASS then
				return
			end
			-- Light up on the transformation's climax, not the moment the button is pressed
			task.delay(BURST_DELAY, function()
				if mine == stamp and character.Parent and character:GetAttribute("Awakened") then
					lit = true
					setAura(character, true)
				end
			end)
		elseif lit then
			lit = false
			setAura(character, false)
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			stamp += 1
			if lit then
				lit = false
				setAura(character, false)
			end
		end)
	end
end

return AwakenVFX
