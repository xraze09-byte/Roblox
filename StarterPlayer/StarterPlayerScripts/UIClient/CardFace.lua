-- การ์ด 1 ใบ สไตล์การ์ตูน: ขอบดำหนา + เส้นร่างซ้อนแบบวาดมือ + ป้ายเทียร์ + แสงวิ้งตามความหายาก
-- โครงแถบแนวตั้งเหมือนเดิม (ค่าแต้ม | ชื่อ / ภาพ / ประเภท / คำอธิบาย / ATK-สถานะ-HP) ข้อความไม่ทับกัน
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local CardFace = {}
CardFace.__index = CardFace
CardFace.ASPECT = 0.72

local GLOW = {
	none = { S.C.Ink, 3 }, playable = { S.C.Accent, 4 }, ready = { S.C.Good, 4.5 },
	target = { S.C.Info, 4.5 }, hover = { S.C.Pink, 5.5 }, selected = { S.C.Accent, 5 },
}
local ATK_COLOR = Color3.fromRGB(255, 96, 40)
local HP_COLOR = Color3.fromRGB(40, 200, 90)
local HURT_COLOR = Color3.fromRGB(255, 150, 40)

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

local function box(parent, color, pos, size, radius)
	local f = S.new("Frame", { BackgroundColor3 = color, Position = pos, Size = size, ZIndex = 3, Parent = parent },
		{ S.corner(radius or 6) })
	S.stroke(S.C.Ink, 2, f)
	return f
end

-- ลายทางเฉียงบนช่องภาพ (UIGradient แบบขั้นบันได ไม่ต้องใช้ภาพ)
local function stripes(parent)
	local f = S.new("Frame", { Name = "Stripes", BackgroundColor3 = S.C.White, BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = parent }, { S.corner(6) })
	local kps, n = {}, 6
	for i = 0, n - 1 do
		local a, b = i / n, (i + 0.5) / n
		table.insert(kps, NumberSequenceKeypoint.new(a, 0.82))
		table.insert(kps, NumberSequenceKeypoint.new(math.min(b - 0.001, 1), 0.82))
		table.insert(kps, NumberSequenceKeypoint.new(b, 1))
		table.insert(kps, NumberSequenceKeypoint.new(math.min((i + 1) / n - 0.001, 1), 1))
	end
	kps[#kps] = NumberSequenceKeypoint.new(1, 1)
	S.new("UIGradient", { Rotation = 35, Transparency = NumberSequence.new(kps), Parent = f })
	return f
end

function CardFace.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardFace)
	local root = S.new("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", Selectable = false,
		BackgroundColor3 = S.C.Paper, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = opts.Size or UDim2.fromScale(1, 1),
		ClipsDescendants = false, ZIndex = 2,
	}, { S.corner(9) })
	if not opts.NoAspect then
		S.new("UIAspectRatioConstraint", {
			AspectRatio = CardFace.ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Height, Parent = root,
		})
	end
	self.Root = root
	self.Stroke = S.stroke(S.C.Ink, 3, root)
	-- เส้นขอบรุ้งหมุนวนสำหรับเทียร์สูง (เปิด/ปิดใน Update)
	self.RainbowGrad = S.new("UIGradient", { Enabled = false, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, S.C.Pink), ColorSequenceKeypoint.new(0.25, S.C.Accent),
		ColorSequenceKeypoint.new(0.5, S.C.Good), ColorSequenceKeypoint.new(0.75, S.C.Info),
		ColorSequenceKeypoint.new(1, S.C.Pink),
	}), Parent = self.Stroke })
	self.Scale = S.new("UIScale", { Parent = root })

	-- กรอบในสีเทียร์ + เส้นร่างซ้อนเอียง (ลุคเส้นมือ)
	self.TierBand = S.new("Frame", { Name = "TierBand", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 2, Parent = root }, { S.corner(7) })
	self.TierStroke = S.stroke(S.Rarity.Common, 2.5, self.TierBand)
	local sketch = S.new("Frame", { Name = "Sketch", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 2, 1, 2), Rotation = 1.1, ZIndex = 2, Parent = root },
		{ S.corner(10) })
	local sk = S.stroke(S.C.Ink, 2, sketch)
	sk.Transparency = 0.45

	-- แถบบน: ค่าใช้แต้ม (เหรียญกลม) | ชื่อ
	self.CostBox = S.new("Frame", { BackgroundColor3 = S.C.Accent, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.13, 0.085), Size = UDim2.fromScale(0.27, 0.19), ZIndex = 6, Parent = root },
		{ S.round(), S.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	self.CostStroke = S.stroke(S.C.Ink, 2.5, self.CostBox)
	self.Cost = S.text({ Font = S.Font.Heavy, Color = S.C.Ink, XAlign = "Center", Max = 24, Stroke = false,
		ZIndex = 7, Parent = self.CostBox })
	self.NameLabel = S.text({ Font = S.Font.Bold, Color = S.C.Ink, Max = 15, Stroke = false, Tilt = -1.5,
		Position = UDim2.fromScale(0.29, 0.035), Size = UDim2.fromScale(0.52, 0.14), ZIndex = 4, Parent = root })
	-- ป้ายเทียร์ (T1 ถึง T5)
	self.TierTag, self.TierLabel = S.sticker({ Name = "TierTag", Text = "T1", Color = S.Rarity.Common,
		Position = UDim2.fromScale(0.88, 0.09), Size = UDim2.fromScale(0.26, 0.11), Tilt = 9, Max = 14, Stroke = 2,
		ZIndex = 6, Parent = root })

	-- ภาพ (สีธาตุ + ลายทางเฉียง)
	self.Art = box(root, S.C.InkSoft, UDim2.fromScale(0.07, 0.2), UDim2.fromScale(0.86, 0.35))
	self.Art.ClipsDescendants = true
	stripes(self.Art)
	self.ArtText = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 30, Tilt = -7,
		Position = UDim2.fromScale(0.05, 0.18), Size = UDim2.fromScale(0.9, 0.64), ZIndex = 5, Parent = self.Art })
	self.FX = S.new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 6, Parent = self.Art })

	-- ประเภท / คำอธิบาย
	self.TypeLine = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, Max = 11, Stroke = false,
		Position = UDim2.fromScale(0.07, 0.565), Size = UDim2.fromScale(0.86, 0.08), ZIndex = 4, Parent = root })
	self.Desc = S.text({ Color = S.C.Ink, Max = 11, YAlign = "Top", Stroke = false,
		Position = UDim2.fromScale(0.07, 0.65), Size = UDim2.fromScale(0.86, 0.18), ZIndex = 4, Parent = root })
	-- แถบล่าง: ATK | สถานะ | HP
	self.AtkBox = box(root, ATK_COLOR, UDim2.fromScale(0.04, 0.84), UDim2.fromScale(0.3, 0.14), 8)
	self.Atk = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 20, ZIndex = 4, Parent = self.AtkBox })
	self.HpBox = box(root, HP_COLOR, UDim2.fromScale(0.66, 0.84), UDim2.fromScale(0.3, 0.14), 8)
	self.Hp = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 20, ZIndex = 4, Parent = self.HpBox })
	self.Status = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, XAlign = "Center", Max = 11, Stroke = false,
		Position = UDim2.fromScale(0.35, 0.85), Size = UDim2.fromScale(0.3, 0.12), ZIndex = 4, Parent = root })
	self.Shade = S.new("Frame", { BackgroundColor3 = S.C.Ink, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = root }, { S.corner(9) })

	self.Glow = "none"
	if card then self:Update(card) end
	return self
end

-- แสงวิ้งตามเทียร์: T3 ประกายดาว, T4+ ขอบรุ้งหมุนวน
function CardFace:ApplyRarity(rarity)
	if self.RarityShown == rarity then return end
	self.RarityShown = rarity
	local color = S.Rarity[rarity] or S.Rarity.Common
	local tier = S.Tier[rarity] or 1
	self.TierStroke.Color = color
	self.TierStroke.Thickness = tier >= 3 and 3.5 or 2.5
	self.TierTag.BackgroundColor3 = color
	self.TierLabel.Text = "T" .. tier
	self.TierLabel.TextColor3 = S.on(color)
	self.CostStroke.Color = tier >= 3 and color or S.C.Ink
	self.FX:ClearAllChildren()
	if tier >= 3 then S.sparkles(self.FX, S.C.White, tier + 1, 7) end
	local rainbow = tier >= 4 and S.effectsOn()
	self.RainbowGrad.Enabled = rainbow and self.Glow == "none"
	if rainbow and not self.RainbowConn then
		self.RainbowConn = S.animate(self.Root, function(_, t)
			self.RainbowGrad.Rotation = (t * 120) % 360
		end)
	end
end

function CardFace:Update(card)
	self.Card = card
	local t = card.Type
	self.Cost.Text = tostring(card.Cost or 0)
	self.NameLabel.Text = card.Name or card.Id or "?"
	self:ApplyRarity(card.Rarity or "Common")
	local typeName = S.Name.Type[t] or t or ""
	local rarity = S.Name.Rarity[card.Rarity] or ""
	self.TypeLine.Text = rarity ~= "" and (typeName .. " · " .. rarity) or typeName

	local desc
	if t == "Character" then
		self.Art.BackgroundColor3 = S.Element[card.Element] or S.C.InkSoft
		self.ArtText.Text = S.Name.Element[card.Element] or card.Element or ""
		self.AtkBox.Visible, self.HpBox.Visible = true, true
		S.bounceText(self.Atk, card.ATK or 0)
		local hp = card.HP or 0
		S.bounceText(self.Hp, hp)
		self.HpBox.BackgroundColor3 = (card.MaxHP and hp < card.MaxHP) and HURT_COLOR or HP_COLOR
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
		self.Art.BackgroundColor3 = Color3.fromRGB(120, 130, 150)
		self.ArtText.Text = "อาวุธ"
		local hasBonus = typeof(card.Bonus) == "number"
		self.AtkBox.Visible = hasBonus
		self.Atk.Text = hasBonus and ("+" .. card.Bonus) or ""
		self.HpBox.Visible = card.Durability ~= nil
		self.Hp.Text = tostring(card.Durability or "")
		desc = card.Desc or ""
	else
		local shield = typeof(card.Effect) == "table" and card.Effect.Kind == "Shield"
		self.Art.BackgroundColor3 = shield and S.C.Info or S.C.Pink
		self.ArtText.Text = shield and "โล่ 0 แต้ม" or (S.Name.Type[t] or "")
		self.AtkBox.Visible, self.HpBox.Visible = false, false
		desc = card.Desc or ""
	end
	self.Desc.Text = S.clean(desc)
end

function CardFace:SetGlow(kind)
	self.Glow = kind or "none"
	local g = GLOW[self.Glow] or GLOW.none
	self.Stroke.Color, self.Stroke.Thickness = g[1], g[2]
	self.RainbowGrad.Enabled = self.Glow == "none" and self.RainbowConn ~= nil
end

function CardFace:SetStatus(text, dim)
	self.Status.Text = text or ""
	self.Shade.BackgroundTransparency = dim and 0.55 or 1
end

function CardFace:SetCostWarning(on)
	self.CostBox.BackgroundColor3 = on and S.C.Bad or S.C.Accent
	self.Cost.TextColor3 = on and S.C.White or S.C.Ink
end

function CardFace:SetLift(on)
	if self.Lifted == on then return end
	self.Lifted = on
	self.Root.ZIndex = on and 3 or 2
	TweenService:Create(self.Scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = on and 1.08 or 1 }):Play()
end

-- ลงสนาม/เข้ามือ: เด้งดึ๋งจากเล็กแบบสปริง
function CardFace:PopIn()
	self.Scale.Scale = 0.4
	self.Root.Rotation = math.random(-14, 14)
	local speed = S.speed()
	TweenService:Create(self.Scale, TweenInfo.new(0.45 / speed, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(self.Root, TweenInfo.new(0.6 / speed, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
end

function CardFace:Flash()
	self.Stroke.Color, self.Stroke.Thickness = S.C.Bad, 6
	S.jiggle(self.Root, 7)
	local token = (self.FlashToken or 0) + 1
	self.FlashToken = token
	task.delay(0.3, function()
		if self.FlashToken == token and self.Root.Parent then self:SetGlow(self.Glow) end
	end)
end

function CardFace:Destroy() self.Root:Destroy() end

return CardFace
