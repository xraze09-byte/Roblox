-- การ์ด 1 ใบ สไตล์การ์ตูนลายเส้นมือ: ขอบดำหนา เงาทึบ ป้ายเทียร์ ประกายตามความหายาก
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local CardFace = {}
CardFace.__index = CardFace
CardFace.ASPECT = 0.72

local GLOW = {
	none = { S.C.Ink, 3 }, playable = { S.C.Accent, 4 }, ready = { S.C.Lime, 4.5 },
	target = { S.C.Sky, 4.5 }, hover = { S.C.Accent, 5.5 }, selected = { S.C.Accent, 5 },
}
local ATK_COLOR = S.C.Hot
local HP_COLOR = Color3.fromRGB(70, 210, 110)
local HP_HURT = S.C.Orange

function CardFace.KeywordText(card)
	local out = {}
	if card and typeof(card.Keywords) == "table" then
		for k, v in card.Keywords do
			local kw = typeof(k) == "number" and v or (v and k)
			if typeof(kw) == "string" then table.insert(out, S.Name.Keyword[kw] or kw) end
		end
	end
	return table.concat(out, " / ")
end

function CardFace.TierText(card)
	local t = S.Tier[card and card.Rarity] or 1
	return "T" .. t
end

-- กล่องเล็กขอบดำ (ค่าใช้แต้ม / ATK / HP)
local function badge(parent, color, pos, size, z)
	local f = S.new("Frame", { BackgroundColor3 = color, Position = pos, Size = size, ZIndex = z, Parent = parent }, { S.corner(8) })
	S.outline(f, 2.5)
	return f
end

function CardFace.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardFace)
	local z = opts.ZIndex or 2

	local root = S.new("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", Selectable = false,
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = opts.Size or UDim2.fromScale(1, 1), ZIndex = z,
	})
	if not opts.NoAspect then
		S.new("UIAspectRatioConstraint", {
			AspectRatio = CardFace.ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Height, Parent = root,
		})
	end
	self.Root = root
	self.Scale = S.new("UIScale", { Parent = root })
	-- การ์ดแต่ละใบเอียงไม่เท่ากันนิดหน่อย ให้ดูเหมือนวางมือ
	self.BaseRotation = opts.Tilt and (math.random(-30, 30) / 10) or 0
	root.Rotation = self.BaseRotation

	-- เงาทึบ + ตัวการ์ด
	self.Shadow = S.new("Frame", { Name = "Shadow", BackgroundColor3 = S.C.Shadow, Position = UDim2.fromOffset(4, 5),
		Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = root }, { S.corner(12) })
	local body = S.new("Frame", { Name = "Body", BackgroundColor3 = S.C.Paper, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, ZIndex = z + 1, Parent = root }, { S.corner(12) })
	self.Body = body
	self.Stroke = S.outline(body, 3)
	-- กรอบประกายความหายาก (ขอบที่สอง ด้านใน)
	self.RarityRim = S.new("Frame", { Name = "Rim", BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.02),
		Size = UDim2.fromScale(0.94, 0.96), ZIndex = z + 2, Parent = body }, { S.corner(10) })
	self.RimStroke = S.stroke(S.Rarity.Common, 2, self.RarityRim)
	self.RimStroke.Transparency = 0.2

	-- แถบบน: ค่าใช้แต้ม (ฟองกลม) | ชื่อ
	self.CostBox = S.new("Frame", { BackgroundColor3 = S.C.Accent, Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.26, 0.17), ZIndex = z + 4, Parent = body }, { S.round(),
		S.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	self.CostStroke = S.outline(self.CostBox, 2.5)
	self.Cost = S.text({ Font = S.Font.Heavy, Color = S.C.Ink, XAlign = "Center", Max = 26, ZIndex = z + 5, Parent = self.CostBox })
	self.NameLabel = S.text({ Font = S.Font.Bold, Color = S.C.Ink, Max = 15, YAlign = "Center",
		Position = UDim2.fromScale(0.33, 0.03), Size = UDim2.fromScale(0.64, 0.16), ZIndex = z + 4, Parent = body })

	-- ภาพ (ใช้สีธาตุ + ป้ายเทียร์)
	self.Art = S.new("Frame", { BackgroundColor3 = S.C.InkSoft, Position = UDim2.fromScale(0.07, 0.22),
		Size = UDim2.fromScale(0.86, 0.33), ZIndex = z + 3, Parent = body }, { S.corner(8) })
	S.outline(self.Art, 2.5)
	S.gradient(self.Art, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)
	S.new("Frame", { Name = "Shine", BackgroundColor3 = S.C.White, BackgroundTransparency = 0.7,
		Position = UDim2.fromScale(0.06, 0.08), Size = UDim2.fromScale(0.5, 0.2), ZIndex = z + 4, Parent = self.Art }, { S.round() })
	self.ArtText = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 30, Outline = 2.5, Rotation = -4,
		Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.6), ZIndex = z + 5, Parent = self.Art })
	self.TierTag = S.new("Frame", { BackgroundColor3 = S.Rarity.Common, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 3, 0, -3), Size = UDim2.fromScale(0.34, 0.3), Rotation = 6, ZIndex = z + 6, Parent = self.Art }, { S.corner(6) })
	S.outline(self.TierTag, 2)
	self.Tier = S.text({ Font = S.Font.Heavy, Color = S.C.Ink, XAlign = "Center", Max = 14, ZIndex = z + 7, Parent = self.TierTag })

	-- ประเภท / คำอธิบาย
	self.TypeLine = S.text({ Font = S.Font.Medium, Color = S.C.InkSoft, Max = 11,
		Position = UDim2.fromScale(0.07, 0.57), Size = UDim2.fromScale(0.86, 0.08), ZIndex = z + 3, Parent = body })
	self.Desc = S.text({ Color = S.C.Ink, Max = 11, YAlign = "Top",
		Position = UDim2.fromScale(0.07, 0.66), Size = UDim2.fromScale(0.86, 0.17), ZIndex = z + 3, Parent = body })

	-- แถบล่าง: ATK | สถานะ | HP (ป้ายขอบดำ โผล่ล้ำขอบล่างนิดหน่อย)
	self.AtkBox = badge(body, ATK_COLOR, UDim2.fromScale(0.04, 0.84), UDim2.fromScale(0.3, 0.14), z + 4)
	self.Atk = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 20, Outline = 2, ZIndex = z + 5, Parent = self.AtkBox })
	self.HpBox = badge(body, HP_COLOR, UDim2.fromScale(0.66, 0.84), UDim2.fromScale(0.3, 0.14), z + 4)
	self.Hp = S.text({ Font = S.Font.Heavy, Color = S.C.White, XAlign = "Center", Max = 20, Outline = 2, ZIndex = z + 5, Parent = self.HpBox })
	self.Status = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, XAlign = "Center", Max = 11,
		Position = UDim2.fromScale(0.35, 0.85), Size = UDim2.fromScale(0.3, 0.12), ZIndex = z + 4, Parent = body })
	self.Shade = S.new("Frame", { BackgroundColor3 = S.C.Bg, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = z + 8, Parent = body }, { S.corner(12) })

	self.Glow = "none"
	if card then self:Update(card) end
	return self
end

function CardFace:Update(card)
	local first = self.Card == nil
	self.Card = card
	local t = card.Type
	local rarityColor = S.Rarity[card.Rarity] or S.Rarity.Common
	S.setText(self.Cost, card.Cost or 0, not first)
	self.NameLabel.Text = card.Name or card.Id or "?"
	self.RimStroke.Color = rarityColor
	self.TierTag.BackgroundColor3 = rarityColor
	self.Tier.Text = CardFace.TierText(card)
	local typeName = S.Name.Type[t] or t or ""
	local rarity = S.Name.Rarity[card.Rarity] or ""
	self.TypeLine.Text = rarity ~= "" and (typeName .. " / " .. rarity) or typeName

	local desc
	if t == "Character" then
		self.Art.BackgroundColor3 = S.Element[card.Element] or S.C.InkSoft
		self.ArtText.Text = S.Name.Element[card.Element] or card.Element or ""
		self.AtkBox.Visible, self.HpBox.Visible = true, true
		S.setText(self.Atk, card.ATK or 0, not first)
		local hp = card.HP or 0
		S.setText(self.Hp, hp, not first)
		self.HpBox.BackgroundColor3 = (card.MaxHP and hp < card.MaxHP) and HP_HURT or HP_COLOR
		local lines = {}
		local kw = CardFace.KeywordText(card)
		if kw ~= "" then table.insert(lines, kw) end
		if card.WeaponName then
			table.insert(lines, ("ถือ %s (%s)"):format(card.WeaponName, tostring(card.WeaponDur or "-")))
		end
		desc = table.concat(lines, "\n")
		if self.LastHP and hp < self.LastHP then self:Hurt(self.LastHP - hp) end
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
		self.Art.BackgroundColor3 = S.C.Violet
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
	self.CostBox.BackgroundColor3 = on and S.C.Bad or S.C.Accent
	self.Cost.TextColor3 = on and S.C.White or S.C.Ink
end

function CardFace:SetLift(on)
	if self.Lifted == on then return end
	self.Lifted = on
	TweenService:Create(self.Scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = on and 1.08 or 1 }):Play()
	TweenService:Create(self.Root, TweenInfo.new(0.12), { Rotation = on and 0 or self.BaseRotation }):Play()
end

-- โผล่มาแบบเด้งดึ๋ง + ประกายถ้าเทียร์สูง
function CardFace:PopIn()
	self.Scale.Scale = 0.6
	TweenService:Create(self.Scale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local tier = S.Tier[self.Card and self.Card.Rarity] or 1
	if tier >= 3 then
		S.sparkle(self.Root, S.Rarity[self.Card.Rarity], 6 + tier * 3, 0.9)
		S.sfx(tier >= 4 and "Jackpot" or "Sparkle")
	end
end

-- โดนตี: สั่น + กระพริบแดง + ตัวเลขลอย
function CardFace:Hurt(amount)
	self.Stroke.Color, self.Stroke.Thickness = S.C.Bad, 5
	S.jiggle(self.Root, 10)
	if amount and amount > 0 then
		local pop = S.shout({ Text = "-" .. amount, Color = S.C.Bad, Max = 40, Rotation = math.random(-15, 15),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(1.4, 0.4),
			ZIndex = self.Root.ZIndex + 20, Parent = self.Root })
		S.punch(pop, 0.6)
		S.tween(pop, 0.8, { Position = UDim2.fromScale(0.5, -0.3), TextTransparency = 1 })
		task.delay(0.8, function() pop:Destroy() end)
	end
	local token = (self.FlashToken or 0) + 1
	self.FlashToken = token
	task.delay(0.35, function()
		if self.FlashToken == token and self.Root.Parent then
			self:SetGlow(self.Glow)
			self.Root.Rotation = self.Lifted and 0 or self.BaseRotation
		end
	end)
end

function CardFace:Flash() self:Hurt() end

function CardFace:Destroy()
	local root = self.Root
	TweenService:Create(self.Scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.delay(0.16, function() root:Destroy() end)
end

return CardFace
