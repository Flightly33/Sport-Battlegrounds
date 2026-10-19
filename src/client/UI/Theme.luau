--[[
	Theme: shared look for the HUD and menus - dark glass panels, sporty italic headings.
]]

local Theme = {}

Theme.Heading = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
Theme.Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
Theme.Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

Theme.PanelColor = Color3.fromRGB(14, 16, 26)
Theme.PanelLight = Color3.fromRGB(32, 36, 52)
Theme.Text = Color3.fromRGB(245, 247, 255)
Theme.Muted = Color3.fromRGB(160, 168, 190)
Theme.Health = Color3.fromRGB(90, 230, 120)
Theme.Danger = Color3.fromRGB(255, 70, 70)
Theme.Gold = Color3.fromRGB(255, 210, 70)

function Theme.Corner(radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	return c
end

function Theme.Stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function Theme.TextStroke(thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thickness or 2
	s.Transparency = 0.2
	return s
end

function Theme.Panel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Theme.PanelColor
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	Theme.Corner(10).Parent = f
	Theme.Stroke(Color3.fromRGB(255, 255, 255), 1, 0.85).Parent = f
	f.Parent = parent
	return f
end

function Theme.Label(parent: Instance, text: string, size: UDim2, position: UDim2, font: Font?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextColor3 = color or Theme.Text
	l.FontFace = font or Theme.Bold
	l.TextScaled = true
	l.Parent = parent
	return l
end

return Theme
