-- StarterPlayer/StarterPlayerScripts/UIClient/CardFace.lua
-- v2: ดีไซน์ตามหลักเกมการ์ด • API เดิมครบ
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local CardFace = {}
CardFace.__index = CardFace
CardFace.ASPECT = 0.72

local WHITE = Color3.new(1, 1, 1)
local CENTER = Vector2.new(0.5, 0.5)
local COL = {
	Cost    = S.C.Info,                       -- ปรับให้ตรงกับสีแต้มใน HUD ได้
	Atk     = Color3.fromRGB(214, 64, 52),
	Hp      = Color3.fromRGB(46, 168, 92),
	HpHurt  = Color3.fromRGB(232, 122, 36),
	Dur     = Color3.fromRGB(118, 128, 142),  -- ความทนทานอาวุธ
	Ribbon  = S.C.InkSoft,
	TextBox = S.C.Paper:Lerp(S.C.Ink, 0.07),
	Weapon  = Color3.fromRGB(88, 94, 102),
	Spell   = Color3.fromRGB(62, 82, 112),
}
-- { สี, ความหนา } เขียว = เล่น/โจมตีได้, ฟ้า = เป้าหมาย, เหลือง = โฟกัส
local GLOW = {
	playable = { S.C.Good, 3 },
	ready    = { S.C.Good, 4 },
	target   = { S.C.Info, 4 },
	hover    = { S.C.Accent, 4 },
	selected = { S.C.Accent, 5 },
}

local function corner(parent, r)
	return S.new("UICorner", { CornerRadius = r or UDim.new(0.08, 0), Parent = parent })
end

local function box(parent, color, pos, size, z, props)
	local f = S.new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0,
		Position = pos, Size = size, ZIndex = z or 3, Parent = parent })
	if props then for k, v in pairs(props) do f[k] = v end end
	return f
end

local function text(parent, p)
	local l = S.text({ Font = p.Font or S.Font.Bold, Color = p.Color or S.C.Ink, XAlign = p.XAlign,
		YAlign = p.YAlign, Max = p.Max, Position = p.Position or UDim2.new(),
		Size = p.Size or UDim2.fromScale(1, 1), Parent = parent })
	l.ZIndex = p.ZIndex or (parent.ZIndex + 1)
	if p.Outline then S.stroke(S.C.Ink, p.Outline, l) end
	return l
end

-- เหรียญตัวเลขกลม (แต้ม / ATK / HP)
local function gem(parent, color, pos, anchor, z)
	local f = box(parent, color, pos, UDim2.fromScale(0.27, 0.2), z, { AnchorPoint = anchor })
	S.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = f })
	corner(f, UDim.new(1, 0))
	local st = S.stroke(S.C.Ink, 2, f)
	S.new("UIGradient", { Rotation = 90, Parent = f, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190)) })
	local t = text(f, { Font = S.Font.Heavy, Color = WHITE, XAlign = "Center", Max = 24, Outline = 1.5,
		Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.9) })
	return f, t, st
end

function CardFace.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardFace)

	local root = S.new("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", Selectable = false,
		BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size or UDim2.fromScale(1, 1), ZIndex = 2,
	})
	if not opts.NoAspect then
		S.new("UIAspectRatioConstraint", { AspectRatio = CardFace.ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Height, Parent = root })
	end
	self.Root = root

	-- ไฟเรืองแสงรอบการ์ด (อยู่นอก Body จึงไม่ถูกตัดขอบ)
	self.Halo = box(root, WHITE, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 8, 1, 8), 1,
		{ Name = "Halo", AnchorPoint = CENTER, BackgroundTransparency = 1, Visible = false })
	corner(self.Halo, UDim.new(0.09, 0))
	self.HaloStroke = S.stroke(S.C.Good, 4, self.Halo)

	-- ตัวการ์ด: สีพื้น = สีความหายาก (กลายเป็นกรอบ)
	local body = box(root, S.C.InkSoft, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 2,
		{ Name = "Body", AnchorPoint = CENTER, ClipsDescendants = true })
	corner(body, UDim.new(0.07, 0))
	S.new("UIGradient", { Rotation = 90, Parent = body, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)) })
	self.Body = body
	self.Stroke = S.stroke(S.C.Ink, 1.5, body)
	self.Scale = S.new("UIScale", { Name = "FaceScale", Parent = body }) -- แยกจากสเกลของ HandFan

	local paper = box(body, S.C.Paper, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.94), 3, { Name = "Paper" })
	corner(paper, UDim.new(0.06, 0))

	-- แถบชื่อ
	local banner = box(body, S.C.Ink, UDim2.fromScale(0.27, 0.045), UDim2.fromScale(0.69, 0.12), 4)
	corner(banner, UDim.new(0.3, 0))
	self.NameLabel = text(banner, { Font = S.Font.Bold, Color = S.C.Paper, XAlign = "Center", Max = 15,
		Position = UDim2.fromScale(0.06, 0.08), Size = UDim2.fromScale(0.88, 0.84) })

	-- ช่องภาพ
	self.Art = box(body, S.C.InkSoft, UDim2.fromScale(0.07, 0.18), UDim2.fromScale(0.86, 0.37), 4)
	corner(self.Art, UDim.new(0.08, 0))
	S.stroke(S.C.Ink, 1.5, self.Art)
	S.new("UIGradient", { Rotation = 90, Parent = self.Art, Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 150, 150)) })
	self.ArtImage = S.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop, Visible = false, ZIndex = 5, Parent = self.Art })
	corner(self.ArtImage, UDim.new(0.08, 0))
	self.ArtEmoji = text(self.Art, { Font = S.Font.Heavy, Color = S.C.Paper, XAlign = "Center", Max = 44, Outline = 2,
		Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.8, 0.66) })
	self.ArtText = text(self.Art, { Font = S.Font.Bold, Color = S.C.Paper, XAlign = "Center", Max = 11, Outline = 1,
		Position = UDim2.fromScale(0.2, 0.78), Size = UDim2.fromScale(0.6, 0.18) })

	-- ริบบิ้นประเภท + อัญมณีความหายาก
	local ribbon = box(body, COL.Ribbon, UDim2.fromScale(0.1, 0.565), UDim2.fromScale(0.8, 0.075), 4)
	corner(ribbon, UDim.new(0.5, 0))
	self.TypeLine = text(ribbon, { Font = S.Font.Medium, Color = S.C.Paper, XAlign = "Center", Max = 11,
		Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.78, 0.8) })
	self.Gem = box(ribbon, WHITE, UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.7, 0.7), 5,
		{ AnchorPoint = CENTER, Rotation = 45 })
	S.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = self.Gem })
	S.stroke(S.C.Ink, 1, self.Gem)

	-- กล่องข้อความ
	local tb = box(body, COL.TextBox, UDim2.fromScale(0.07, 0.655), UDim2.fromScale(0.86, 0.19), 4)
	corner(tb, UDim.new(0.12, 0))
	self.Desc = text(tb, { Font = S.Font.Regular, Color = S.C.Ink, XAlign = "Center", YAlign = "Top", Max = 11,
		Position = UDim2.fromScale(0.08, 0.06), Size = UDim2.fromScale(0.84, 0.88) })

	self.Status = text(body, { Font = S.Font.Bold, Color = S.C.InkSoft, XAlign = "Center", Max = 11,
		Position = UDim2.fromScale(0.3, 0.86), Size = UDim2.fromScale(0.4, 0.11), ZIndex = 6 })

	-- ตัวเลข: แต้มซ้ายบน • ATK ซ้ายล่าง • HP ขวาล่าง
	self.CostBox, self.Cost, self.CostStroke = gem(body, COL.Cost, UDim2.fromScale(0.02, 0.015), Vector2.zero, 7)
	self.AtkBox, self.Atk = gem(body, COL.Atk, UDim2.fromScale(0.02, 0.985), Vector2.new(0, 1), 7)
	self.HpBox, self.Hp = gem(body, COL.Hp, UDim2.fromScale(0.98, 0.985), Vector2.new(1, 1), 7)

	-- ชั้นทับ: แฟลชโดนตี / มืดลงเมื่อใช้ไม่ได้
	self.Hurt = box(body, S.C.Bad, UDim2.new(), UDim2.fromScale(1, 1), 18, { BackgroundTransparency = 1 })
	self.Shade = box(body, S.C.Bg, UDim2.new(), UDim2.fromScale(1, 1), 20, { BackgroundTransparency = 1 })

	self.Glow = "none"
	if card then self:Update(card) end
	return self
end

function CardFace:Update(card)
	self.Card = card
	local t = card.Type
	local rarityColor = S.Rarity[card.Rarity] or S.C.InkSoft
	self.Body.BackgroundColor3 = rarityColor
	self.Gem.BackgroundColor3 = rarityColor

	self.Cost.Text = tostring(card.Cost or 0)
	self.NameLabel.Text = card.Name or card.Id or "?"
	local typeName = S.Name.Type[t] or t or ""
	local rarity = S.Name.Rarity[card.Rarity] or ""
	self.TypeLine.Text = rarity ~= "" and (typeName .. " · " .. rarity) or typeName

	local art = typeof(card.Art) == "string" and card.Art:match("^rbxassetid://") and card.Art or nil
	self.ArtImage.Image = art or ""
	self.ArtImage.Visible = art ~= nil
	local emoji = typeof(card.Emoji) == "string" and card.Emoji or ""

	local desc, artName = "", ""
	if t == "Character" then
		self.Art.BackgroundColor3 = S.Element[card.Element] or S.C.InkSoft
		artName = S.Name.Element[card.Element] or card.Element or ""
		self.AtkBox.Visible, self.HpBox.Visible = true, true
		self.Atk.Text = tostring(card.ATK or 0)
		local hp = card.HP or 0
		self.Hp.Text = tostring(hp)
		self.HpBox.BackgroundColor3 = (card.MaxHP and hp < card.MaxHP) and COL.HpHurt or COL.Hp
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
		self.Art.BackgroundColor3 = COL.Weapon
		artName = "อาวุธ"
		local hasBonus = typeof(card.Bonus) == "number"
		self.AtkBox.Visible = hasBonus
		self.Atk.Text = hasBonus and ("+" .. card.Bonus) or ""
		self.HpBox.Visible = card.Durability ~= nil
		self.HpBox.BackgroundColor3 = COL.Dur
		self.Hp.Text = tostring(card.Durability or "")
		desc = card.Desc or ""
	else
		self.Art.BackgroundColor3 = COL.Spell
		artName = S.Name.Type[t] or ""
		self.AtkBox.Visible, self.HpBox.Visible = false, false
		desc = card.Desc or ""
	end

	-- ไม่มีข้อความกฎ → แสดง Flavor สีจาง
	local flavor = false
	if desc == "" and typeof(card.Flavor) == "string" then desc, flavor = card.Flavor, true end
	self.Desc.Text = S.clean(desc)
	self.Desc.TextColor3 = flavor and S.C.InkSoft or S.C.Ink

	self.ArtEmoji.Text = emoji ~= "" and emoji or artName
	self.ArtEmoji.Visible = not self.ArtImage.Visible
	self.ArtText.Text = artName
	self.ArtText.Visible = emoji ~= "" and artName ~= ""
end

function CardFace:_paintGlow(color, thick)
	if color then
		self.Halo.Visible = true
		self.HaloStroke.Color, self.HaloStroke.Thickness = color, thick
		self.Stroke.Color, self.Stroke.Thickness = color, 2
	else
		self.Halo.Visible = false
		self.Stroke.Color, self.Stroke.Thickness = S.C.Ink, 1.5
	end
end

function CardFace:SetGlow(kind)
	self.Glow = kind or "none"
	if self.Flashing then return end
	local g = GLOW[self.Glow]
	self:_paintGlow(g and g[1], g and g[2])
end

function CardFace:SetStatus(text, dim)
	self.Status.Text = text or ""
	self.Shade.BackgroundTransparency = dim and 0.55 or 1
end

function CardFace:SetCostWarning(on)
	self.CostBox.BackgroundColor3 = on and S.C.Bad or COL.Cost
end

function CardFace:SetLift(on)
	if self.Lifted == on then return end
	self.Lifted = on
	self.Root.ZIndex = on and 3 or 2
	TweenService:Create(self.Scale, TweenInfo.new(0.1), { Scale = on and 1.06 or 1 }):Play()
end

function CardFace:PopIn()
	self.Scale.Scale = 0.85
	TweenService:Create(self.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function CardFace:Flash()
	local token = (self.FlashToken or 0) + 1
	self.FlashToken, self.Flashing = token, true
	self:_paintGlow(S.C.Bad, 4)
	self.Hurt.BackgroundTransparency = 0.45
	TweenService:Create(self.Hurt, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	task.delay(0.3, function()
		if self.FlashToken ~= token then return end
		self.Flashing = false -- เดิมถ้าการ์ดหลุด parent ชั่วคราว ไฟเรืองแสงจะค้างแดง
		self:SetGlow(self.Glow)
	end)
end

function CardFace:Destroy()
	self.Destroyed = true
	self.Root:Destroy()
end

-- ข้อความคีย์เวิร์ด (ตัวเดิมของโปรเจกต์)
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

return CardFace