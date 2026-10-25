-- การ์ด 1 ใบ: แบ่งแถบแนวตั้งชัดเจน ข้อความไม่ทับกัน
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local CardFace = {}
CardFace.__index = CardFace
CardFace.ASPECT = 0.72

local GLOW = {
	none = { S.C.Ink, 1 }, playable = { S.C.Accent, 2 }, ready = { S.C.Good, 2.5 },
	target = { S.C.Info, 2.5 }, hover = { S.C.Accent, 3.5 }, selected = { S.C.Accent, 3 },
}

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

local function box(parent, color, pos, size)
	return S.new("Frame", { BackgroundColor3 = color, Position = pos, Size = size, Parent = parent }, { S.corner(3) })
end

function CardFace.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardFace)
	local root = S.new("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", Selectable = false,
		BackgroundColor3 = S.C.Paper, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = opts.Size or UDim2.fromScale(1, 1),
		ClipsDescendants = true, ZIndex = 2,
	}, { S.corner(5) })
	if not opts.NoAspect then
		S.new("UIAspectRatioConstraint", {
			AspectRatio = CardFace.ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Height, Parent = root,
		})
	end
	self.Root = root
	self.Stroke = S.stroke(S.C.Ink, 1, root)
	self.Scale = S.new("UIScale", { Parent = root })

	-- แถบบน: ค่าใช้แต้ม | ชื่อ
	self.CostBox = box(root, S.C.Ink, UDim2.fromScale(0.05, 0.035), UDim2.fromScale(0.24, 0.15))
	self.CostStroke = S.stroke(S.C.Ink, 1.5, self.CostBox)
	self.Cost = S.text({ Font = S.Font.Heavy, Color = S.C.Paper, XAlign = "Center", Max = 22, Parent = self.CostBox })
	self.NameLabel = S.text({ Font = S.Font.Bold, Color = S.C.Ink, Max = 15,
		Position = UDim2.fromScale(0.33, 0.035), Size = UDim2.fromScale(0.62, 0.15), Parent = root })
	-- ภาพ (ใช้สีธาตุ)
	self.Art = box(root, S.C.InkSoft, UDim2.fromScale(0.05, 0.21), UDim2.fromScale(0.9, 0.34))
	self.ArtText = S.text({ Font = S.Font.Heavy, Color = S.C.Paper, XAlign = "Center", Max = 28,
		Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.6), Parent = self.Art })
	-- ประเภท / คำอธิบาย
	self.TypeLine = S.text({ Font = S.Font.Medium, Color = S.C.InkSoft, Max = 11,
		Position = UDim2.fromScale(0.05, 0.57), Size = UDim2.fromScale(0.9, 0.08), Parent = root })
	self.Desc = S.text({ Color = S.C.Ink, Max = 11, YAlign = "Top",
		Position = UDim2.fromScale(0.05, 0.66), Size = UDim2.fromScale(0.9, 0.17), Parent = root })
	-- แถบล่าง: ATK | สถานะ | HP
	self.AtkBox = box(root, Color3.fromRGB(160, 70, 55), UDim2.fromScale(0.05, 0.85), UDim2.fromScale(0.28, 0.12))
	self.Atk = S.text({ Font = S.Font.Heavy, Color = S.C.Paper, XAlign = "Center", Max = 18, Parent = self.AtkBox })
	self.HpBox = box(root, Color3.fromRGB(70, 120, 80), UDim2.fromScale(0.67, 0.85), UDim2.fromScale(0.28, 0.12))
	self.Hp = S.text({ Font = S.Font.Heavy, Color = S.C.Paper, XAlign = "Center", Max = 18, Parent = self.HpBox })
	self.Status = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, XAlign = "Center", Max = 11,
		Position = UDim2.fromScale(0.34, 0.85), Size = UDim2.fromScale(0.32, 0.12), Parent = root })
	self.Shade = S.new("Frame", { BackgroundColor3 = S.C.Bg, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = root })

	self.Glow = "none"
	if card then self:Update(card) end
	return self
end

function CardFace:Update(card)
	self.Card = card
	local t = card.Type
	self.Cost.Text = tostring(card.Cost or 0)
	self.NameLabel.Text = card.Name or card.Id or "?"
	self.CostStroke.Color = S.Rarity[card.Rarity] or S.C.Ink
	local typeName = S.Name.Type[t] or t or ""
	local rarity = S.Name.Rarity[card.Rarity] or ""
	self.TypeLine.Text = rarity ~= "" and (typeName .. " · " .. rarity) or typeName

	local desc
	if t == "Character" then
		self.Art.BackgroundColor3 = S.Element[card.Element] or S.C.InkSoft
		self.ArtText.Text = S.Name.Element[card.Element] or card.Element or ""
		self.AtkBox.Visible, self.HpBox.Visible = true, true
		self.Atk.Text = tostring(card.ATK or 0)
		local hp = card.HP or 0
		self.Hp.Text = tostring(hp)
		self.HpBox.BackgroundColor3 = (card.MaxHP and hp < card.MaxHP)
			and Color3.fromRGB(165, 105, 50) or Color3.fromRGB(70, 120, 80)
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
		self.Art.BackgroundColor3 = Color3.fromRGB(88, 94, 102)
		self.ArtText.Text = "อาวุธ"
		local hasBonus = typeof(card.Bonus) == "number"
		self.AtkBox.Visible = hasBonus
		self.Atk.Text = hasBonus and ("+" .. card.Bonus) or ""
		self.HpBox.Visible = card.Durability ~= nil
		self.Hp.Text = tostring(card.Durability or "")
		desc = card.Desc or ""
	else
		self.Art.BackgroundColor3 = Color3.fromRGB(62, 82, 112)
		self.ArtText.Text = S.Name.Type[t] or ""
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
end

function CardFace:SetLift(on)
	if self.Lifted == on then return end
	self.Lifted = on
	self.Root.ZIndex = on and 3 or 2
	TweenService:Create(self.Scale, TweenInfo.new(0.1), { Scale = on and 1.06 or 1 }):Play()
end

function CardFace:PopIn()
	self.Scale.Scale = 0.85
	TweenService:Create(self.Scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function CardFace:Flash()
	self.Stroke.Color, self.Stroke.Thickness = S.C.Bad, 3
	local token = (self.FlashToken or 0) + 1
	self.FlashToken = token
	task.delay(0.3, function()
		if self.FlashToken == token and self.Root.Parent then self:SetGlow(self.Glow) end
	end)
end

function CardFace:Destroy() self.Root:Destroy() end

return CardFace