-- แผงดูรายละเอียดการ์ด (ชี้เมาส์ หรือแตะ)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))

local Inspect = {}
local panel, face, keywords, flavor

function Inspect.Init(parent)
	if panel then return end
	panel = S.new("TextButton", {
		Name = "Inspect", AutoButtonColor = false, Text = "", BackgroundColor3 = S.C.Panel,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromScale(0.2, 0.6), Visible = false, ZIndex = 40, Parent = parent,
	}, { S.corner(6), S.pad(10), S.new("UISizeConstraint", { MinSize = Vector2.new(170, 250), MaxSize = Vector2.new(300, 470) }) })
	S.stroke(S.C.Line, 1, panel)
	local holder = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.66), Parent = panel })
	face = CardFace.new(nil, {})
	face.Root.Active = false
	face.Root.Parent = holder
	keywords = S.text({ Font = S.Font.Bold, Color = S.C.Accent, Max = 13,
		Position = UDim2.fromScale(0, 0.69), Size = UDim2.fromScale(1, 0.08), Parent = panel })
	flavor = S.text({ Color = S.C.TextDim, Max = 12, YAlign = "Top",
		Position = UDim2.fromScale(0, 0.79), Size = UDim2.fromScale(1, 0.21), Parent = panel })
	panel.Activated:Connect(Inspect.Hide)
end

function Inspect.Show(card)
	if not panel or not card then return end
	face:Update(card)
	face:SetStatus("", false)
	keywords.Text = CardFace.KeywordText(card)
	flavor.Text = S.clean(card.Flavor or card.Desc or "")
	panel.Visible = true
end

function Inspect.Hide()
	if panel then panel.Visible = false end
end

return Inspect