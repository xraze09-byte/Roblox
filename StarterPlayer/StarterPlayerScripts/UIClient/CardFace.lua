-- การ์ด 1 ใบ สไตล์การ์ตูนลายเส้นมือ: ขอบดำหนา กรอบภาพเอียง ป้ายเทียร์ แสงวิบวับตามความหายาก
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local CardFace = {}
CardFace.__index = CardFace
CardFace.ASPECT = 0.72

local GLOW = {
	none = { S.C.Ink, 3 }, playable = { S.C.Accent, 4 }, ready = { S.C.Good, 4.5 },
	target = { S.C.Info, 4.5 }, hover = { S.C.Pink, 5.5 }, selected = { S.C.Pink, 5 },
}
local TYPE_ART = { Weapon = S.C.Orange, Spell = S.C.Teal, Leader = S.C.Pink }
local TYPE_LABEL = { Weapon = "อาวุธ", Spell = "เวท", Leader = "ผู้นำ" }

function CardFace.KeywordText(card)
	local out = {}
	if card and typeof(card.Keywords) == "table" then
		for k, v in card.Keywords do
			local kw = typeof(k) == "number" and v or (v and k)
			if typeof(kw) == "string" then table.insert(out, S.Name.Keyword[kw] or kw) end
		end
	end
	return table.concat(out, " · ")
end

local function statBox(parent, color, pos, rot)
	local f = S.box({ Color = color, Position = pos, Size = UDim2.fromScale(0.3, 0.13), Radius = 8, Stroke = 2, Rotation = rot, Parent = parent })
	local lbl = S.text({ Font = S.Font.Heavy, Color = S.C.Text, XAlign = "Center", Max = 20, Stroke = 2, Parent = f })
	return f, lbl
end

function CardFace.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardFace)
	local root = S.new("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", Selectable = false,
		BackgroundColor3 = S.C.Paper, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = opts.Size or UDim2.fromScale(1, 1),
		ClipsDescendants = false, ZIndex = 2,
	}, { S.corner(10) })
	if not opts.NoAspect then
		S.new("UIAspectRatioConstraint", {
			AspectRatio = CardFace.ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Height, Parent = root,
		})
	end
	self.Root = root
	self.Stroke = S.stroke(S.C.Ink, 3, root)
	self.Scale = S.new("UIScale", { Parent = root })
	-- ลายกระดาษ: ไล่สีครีมอ่อนๆ ให้ดูมีมิติ
	S.gradient(root, { S.C.Paper, S.C.Panel2:Lerp(S.C.Paper, 0.55) }, 90)

	-- แถบบน: เหรียญค่าแต้ม | ชื่อ | ป้ายเทียร์
	self.CostBox = S.box({ Color = S.C.Ink, Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.24, 0.15),
		Radius = 999, Stroke = 2.5, StrokeColor = S.C.Accent, Parent = root })
	self.CostStroke = self.CostBox:FindFirstChildOfClass("UIStroke")
	self.Cost = S.text({ Font = S.Font.Heavy, Color = S.C.Accent, XAlign = "Center", Max = 22, Parent = self.CostBox })
	self.NameLabel = S.text({ Font = S.Font.Bold, Color = S.C.Ink, Max = 15,
		Position = UDim2.fromScale(0.31, 0.03), Size = UDim2.fromScale(0.46, 0.15), Parent = root })
	self.TierBox, self.Tier = S.badge({ Text = "T1", Color = S.Rarity.Common, Max = 12, Stroke = 2,
		Position = UDim2.fromScale(0.79, 0.045), Size = UDim2.fromScale(0.18, 0.11), Rotation = 6, Parent = root })

	-- กรอบภาพเอียงๆ (ใช้สีธาตุ) + แสงรุ้งเมื่อเป็นระดับสูง
	self.Art = S.box({ Color = S.C.InkSoft, Position = UDim2.fromScale(0.06, 0.21), Size = UDim2.fromScale(0.88, 0.34),
		Radius = 8, Stroke = 2.5, Rotation = -2, Parent = root })
	self.ArtStroke = self.Art:FindFirstChildOfClass("UIStroke")
	self.ArtText = S.text({ Font = S.Font.Heavy, Color = S.C.Text, XAlign = "Center", Max = 30, Stroke = 2.5,
		Position = UDim2.fromScale(0.05, 0.15), Size = UDim2.fromScale(0.9, 0.7), Parent = self.Art })
	-- ประเภท / คำอธิบาย
	self.TypeLine = S.text({ Font = S.Font.Medium, Color = S.C.InkSoft, Max = 11,
		Position = UDim2.fromScale(0.06, 0.58), Size = UDim2.fromScale(0.88, 0.08), Parent = root })
	self.Desc = S.text({ Color = S.C.Ink, Max = 11, YAlign = "Top",
		Position = UDim2.fromScale(0.06, 0.67), Size = UDim2.fromScale(0.88, 0.16), Parent = root })
	-- แถบล่าง: ATK | สถานะ | HP
	self.AtkBox, self.Atk = statBox(root, S.C.Bad, UDim2.fromScale(0.03, 0.845), -4)
	self.HpBox, self.Hp = statBox(root, S.C.Good, UDim2.fromScale(0.67, 0.845), 4)
	self.Status = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, XAlign = "Center", Max = 11,
		Position = UDim2.fromScale(0.34, 0.85), Size = UDim2.fromScale(0.32, 0.12), Parent = root })
	self.Shade = S.new("Frame", { BackgroundColor3 = S.C.Bg, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = root }, { S.corner(10) })

	self.Glow = "none"
	if card then self:Update(card) end
	return self
end

function CardFace:Update(card)
	self.Card = card
	local t = card.Type
	local rarityColor = S.Rarity[card.Rarity] or S.Rarity.Common
	self.Cost.Text = tostring(card.Cost or 0)
	self.NameLabel.Text = card.Name or card.Id or "?"
	self.CostStroke.Color = rarityColor
	self.TierBox.BackgroundColor3 = rarityColor
	self.Tier.Text = "T" .. (S.Tier[card.Rarity] or 1)
	local typeName = S.Name.Type[t] or t or ""
	local rarity = S.Name.Rarity[card.Rarity] or ""
	self.TypeLine.Text = rarity ~= "" and (typeName .. " · " .. rarity) or typeName

	-- แสงความหายาก: ตำนานขอบทอง ลึกลับขอบรุ้งหมุน
	local old = self.ArtStroke:FindFirstChildOfClass("UIGradient")
	if old then old:Destroy() end
	if card.Rarity == "Mystic" then
		S.rainbow(self.ArtStroke, 160)
		self.ArtStroke.Color = Color3.new(1, 1, 1)
	elseif card.Rarity == "Legend" then
		S.rainbow(self.ArtStroke, 90).Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, S.C.Accent), ColorSequenceKeypoint.new(0.5, S.C.Orange), ColorSequenceKeypoint.new(1, S.C.Accent) })
		self.ArtStroke.Color = Color3.new(1, 1, 1)
	else
		self.ArtStroke.Color = S.C.Ink
	end

	local desc
	if t == "Character" then
		self.Art.BackgroundColor3 = S.Element[card.Element] or S.C.InkSoft
		self.ArtText.Text = S.Name.Element[card.Element] or card.Element or ""
		self.AtkBox.Visible, self.HpBox.Visible = true, true
		self.Atk.Text = tostring(card.ATK or 0)
		local hp = card.HP or 0
		self.Hp.Text = tostring(hp)
		self.HpBox.BackgroundColor3 = (card.MaxHP and hp < card.MaxHP) and S.C.Orange or S.C.Good
		local lines = {}
		local kw = CardFace.KeywordText(card)
		if kw ~= "" then table.insert(lines, kw) end
		if card.WeaponName then
			table.insert(lines, ("ถือ %s (%s)"):format(card.WeaponName, tostring(card.WeaponDur or "-")))
		end
		desc = table.concat(lines, "\n")
		if self.LastHP and hp < self.LastHP then self:Flash() end
		self.LastHP = hp
	elseif t == "Weapon" then
		self.Art.BackgroundColor3 = TYPE_ART.Weapon
		self.ArtText.Text = TYPE_LABEL.Weapon
		local hasBonus = typeof(card.Bonus) == "number"
		self.AtkBox.Visible = hasBonus
		self.Atk.Text = hasBonus and ("+" .. card.Bonus) or ""
		self.HpBox.Visible = card.Durability ~= nil
		self.HpBox.BackgroundColor3 = S.C.Info
		self.Hp.Text = tostring(card.Durability or "")
		desc = card.Desc or ""
	else
		self.Art.BackgroundColor3 = TYPE_ART[t] or S.C.Violet
		self.ArtText.Text = TYPE_LABEL[t] or S.Name.Type[t] or ""
		self.AtkBox.Visible, self.HpBox.Visible = false, false
		desc = card.Desc or ""
	end
	self.Desc.Text = S.clean(desc)
end

function CardFace:SetGlow(kind)
	self.Glow = kind or "none"
	local g = GLOW[self.Glow] or GLOW.none
	self.Stroke.Color, self.Stroke.Thickness = g[1], g[2]
end

function CardFace:SetStatus(text, dim)
	self.Status.Text = text or ""
	self.Shade.BackgroundTransparency = dim and 0.55 or 1
end

function CardFace:SetCostWarning(on)
	self.CostBox.BackgroundColor3 = on and S.C.Bad or S.C.Ink
	self.Cost.TextColor3 = on and S.C.Text or S.C.Accent
end

function CardFace:SetLift(on)
	if self.Lifted == on then return end
	self.Lifted = on
	self.Root.ZIndex = on and 3 or 2
	TweenService:Create(self.Scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = on and 1.08 or 1 }):Play()
end

-- โผล่มาแบบเด้งดึ๋งเหมือนโดนโยนลงโต๊ะ (ไม่แตะ Rotation เพราะ HandFan เป็นคนคุมมุมการ์ดในมือ)
function CardFace:PopIn()
	self.Scale.Scale = 0.5
	TweenService:Create(self.Scale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function CardFace:Flash()
	self.Stroke.Color, self.Stroke.Thickness = S.C.Bad, 5
	S.wobble(self.Root)
	local token = (self.FlashToken or 0) + 1
	self.FlashToken = token
	task.delay(0.3, function()
		if self.FlashToken == token and self.Root.Parent then self:SetGlow(self.Glow) end
	end)
end

function CardFace:Destroy() self.Root:Destroy() end

return CardFace
