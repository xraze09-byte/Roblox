-- ReplicatedStorage/Shared/UI/CardView
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local CardView = {}
CardView.__index = CardView

local CENTER = Vector2.new(0.5, 0.5)
local TYPE_TEXT = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" }
local TYPE_ICON = { Character = "🙂", Spell = "✨", Weapon = "🗡️", Leader = "👑" }

local function hasArt(card)
	return typeof(card.Art) == "string" and card.Art ~= "" and card.Art ~= "rbxassetid://0"
end

local function describe(card)
	if card.Type == "Character" then
		local words = {}
		for _, kw in ipairs(card.Keywords or {}) do
			table.insert(words, Theme.Keyword[kw] or kw)
		end
		if #words > 0 then return table.concat(words, " • ") end
	elseif card.Type == "Weapon" then
		return ("ATK +%d / ปาใส่ %d"):format(card.Bonus or 0, card.Bonus or 0)
	end
	return card.Desc or card.Flavor or ""
end

local function bubble(parent, color, position, anchor)
	local b = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.32, 0.32), Position = position, AnchorPoint = anchor,
		BackgroundColor3 = color, ZIndex = 2, Parent = parent,
	}, {
		UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		UIKit.corner(UDim.new(0.5, 0)),
		UIKit.stroke(nil, 2),
	})
	return UIKit.label({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = b })
end

-- opts: Size, ShowSleep, OnClick(view), OnInspect(view)
function CardView.new(card, opts)
	opts = opts or {}
	local self = setmetatable({}, CardView)
	self.ShowSleep = opts.ShowSleep
	self.RarityColor = Theme.Rarity[card.Rarity] or Theme.Rarity.Common

	local root = UIKit.new("Frame", {
		Name = card.Uid or card.Id or "Card",
		Size = opts.Size or UDim2.fromScale(0.2, 1),
		BackgroundTransparency = 1,
	}, { UIKit.new("UIAspectRatioConstraint", { AspectRatio = 5 / 7 }) })

	local body = UIKit.new("Frame", {
		Name = "Body", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, BackgroundColor3 = Theme.Color.CardBg, Parent = root,
	}, { UIKit.corner(UDim.new(0.08, 0)) })
	body:SetAttribute("BaseSize", body.Size)

	self.Stroke = UIKit.stroke(self.RarityColor, 4)
	self.Stroke.Parent = body
	if card.Rarity == "Mystic" then -- ขอบสีรุ้ง
		UIKit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
			}),
			Parent = self.Stroke,
		})
	end
	self.Gradient = UIKit.new("UIGradient", { -- ร่างทองจากช่องเกต
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 0)),
		Rotation = 45, Enabled = false, Parent = body,
	})

	UIKit.label({
		Text = TYPE_TEXT[card.Type] or "", Font = Theme.FontBody, Color = Theme.Color.Outline, StrokeThickness = 0,
		Size = UDim2.fromScale(0.36, 0.08), Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0), Parent = body,
	})

	local element = Theme.Element[card.Element]
	if element then
		local pill = UIKit.new("Frame", {
			Size = UDim2.fromScale(0.28, 0.09), Position = UDim2.fromScale(0.96, 0.03), AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = element.Color, Parent = body,
		}, { UIKit.corner(UDim.new(0.5, 0)), UIKit.stroke(nil, 2) })
		UIKit.label({ Text = element.Text, Size = UDim2.fromScale(0.9, 0.85), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = pill, StrokeThickness = 1 })
	end

	self.Art = UIKit.new("ImageLabel", {
		Name = "Art", Size = UDim2.fromScale(0.86, 0.46), Position = UDim2.fromScale(0.07, 0.15),
		BackgroundColor3 = Color3.fromRGB(235, 225, 205), ScaleType = Enum.ScaleType.Fit, Parent = body,
	}, { UIKit.corner(UDim.new(0.08, 0)), UIKit.stroke(nil, 2) })
	self.Icon = UIKit.label({ Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = self.Art, StrokeThickness = 0, MaxTextSize = 100 })
	self.Sleep = UIKit.label({ Text = "💤", Size = UDim2.fromScale(0.35, 0.35), Position = UDim2.fromScale(0.98, 0.02), AnchorPoint = Vector2.new(1, 0), Parent = self.Art, StrokeThickness = 0 })

	UIKit.label({
		Text = card.Name or "???", Color = Theme.Color.Outline, StrokeThickness = 0,
		Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.5, 0.63), AnchorPoint = Vector2.new(0.5, 0), Parent = body,
	})
	local desc = UIKit.label({
		Text = describe(card), Font = Theme.FontBody, Color = Color3.fromRGB(90, 80, 70), StrokeThickness = 0,
		Size = UDim2.fromScale(0.56, 0.12), Position = UDim2.fromScale(0.5, 0.75), AnchorPoint = Vector2.new(0.5, 0), Parent = body,
	})
	desc.TextWrapped = true

	self.Cost = bubble(body, Theme.Color.Yellow, UDim2.fromScale(0, 0), Vector2.new(0.25, 0.25))
	if card.Type == "Character" or card.Type == "Leader" then
		self.Atk = bubble(body, Theme.Color.Red, UDim2.fromScale(0, 1), Vector2.new(0.25, 0.75))
		self.Hp = bubble(body, Theme.Color.Green, UDim2.fromScale(1, 1), Vector2.new(0.75, 0.75))
	end

	-- ปุ่มใสคลุมการ์ด: คลิก = เลือก, คลิกขวา/กดค้าง = ซูมดู
	local hit = UIKit.new("TextButton", { Name = "Hitbox", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = body })
	hit.Activated:Connect(function() if opts.OnClick then opts.OnClick(self) end end)
	hit.MouseButton2Click:Connect(function() if opts.OnInspect then opts.OnInspect(self) end end)
	hit.TouchLongPress:Connect(function(_, inputState)
		if inputState == Enum.UserInputState.Begin and opts.OnInspect then opts.OnInspect(self) end
	end)

	self.Frame, self.Body = root, body
	self:Update(card)
	return self
end

function CardView:Update(card)
	self.Card = card
	self.Cost.Text = tostring(card.Cost or 0)
	if self.Atk then
		self.Atk.Text = tostring(card.ATK or 0)
		self.Hp.Text = tostring(math.max(card.HP or 0, 0))
	end
	local art = hasArt(card)
	self.Art.Image = art and card.Art or ""
	self.Icon.Text = TYPE_ICON[card.Type] or "❓"
	self.Icon.Visible = not art
	self.Sleep.Visible = self.ShowSleep == true and card.Type == "Character" and not card.CanAttack

	self.Gradient.Enabled = card.GateResult == "Golden"
	if card.GateResult == "Poop" then
		self.BaseBg = Color3.fromRGB(150, 100, 60)
		self.Art.Image = ""
		self.Icon.Text = "💩"
		self.Icon.Visible = true
	else
		self.BaseBg = Theme.Color.CardBg
	end
	self.Body.BackgroundColor3 = self.BaseBg
end

-- โดนตี: หน้าบิด + ย้วย + ตัวเลขดาเมจ
function CardView:Hit(damage)
	UIKit.sfx("Hit")
	UIKit.popup(self.Frame, "-" .. damage)
	if not UIKit.Settings.VFX then return end
	if typeof(self.Card.HitArt) == "string" then -- ถ้ามีภาพหน้าโดนตี ให้สลับภาพชั่วคราว
		self.Art.Image = self.Card.HitArt
		task.delay(0.7, function()
			if self.Art.Parent then self:Update(self.Card) end
		end)
	end
	UIKit.jelly(self.Art, -0.4) -- ภาพยืดเบี้ยว
	UIKit.jelly(self.Body, 0.35)
	UIKit.shake(self.Body)
	self.Body.BackgroundColor3 = Theme.Color.Red
	UIKit.tween(self.Body, 0.4, { BackgroundColor3 = self.BaseBg })
end

local DEATH_STYLES = {
	function(self) -- หมุนติ้วหายไป
		UIKit.tween(self.Body, 0.5, { Rotation = 720, Size = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end,
	function(self) -- ระเบิดเป็นชามก๋วยเตี๋ยว
		UIKit.popup(self.Frame, "🍜💥", Theme.Color.Yellow)
		UIKit.jelly(self.Body, 0.6)
		task.delay(0.15, function() self.Body.Visible = false end)
	end,
	function(self) -- กระเด็นหลุดจอ
		UIKit.tween(self.Body, 0.5, { Position = UDim2.fromScale(2.5, 3), Rotation = 200 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end,
}

function CardView:Die()
	UIKit.sfx("Death")
	if UIKit.Settings.VFX then
		DEATH_STYLES[math.random(#DEATH_STYLES)](self)
	end
	task.delay(0.6, function() self.Frame:Destroy() end)
end

function CardView:Remove()
	self.Frame:Destroy()
end

function CardView:PopIn()
	self.Body.Size = UDim2.fromScale(0.1, 0.1)
	UIKit.tween(self.Body, 0.35, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
end

function CardView:SetSelected(on)
	self.Stroke.Color = on and Theme.Color.Yellow or self.RarityColor
	self.Stroke.Thickness = on and 6 or 4
	UIKit.tween(self.Body, 0.15, { Position = UDim2.fromScale(0.5, on and 0.42 or 0.5) })
end

function CardView:SetTarget(on)
	self.Stroke.Color = on and Theme.Color.Red or self.RarityColor
	self.Stroke.Thickness = on and 6 or 4
end

function CardView:Lunge()
	UIKit.tween(self.Body, 0.12, { Position = UDim2.fromScale(0.5, 0.2) }).Completed:Once(function()
		UIKit.tween(self.Body, 0.25, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	end)
end

-- หลังการ์ด (ไพ่ศัตรู / ช่องเกตศัตรู)
function CardView.back(size)
	local root = UIKit.new("Frame", { Size = size or UDim2.fromScale(0.18, 1), BackgroundTransparency = 1 }, {
		UIKit.new("UIAspectRatioConstraint", { AspectRatio = 5 / 7 }),
	})
	local body = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root }, {
		UIKit.corner(UDim.new(0.08, 0)),
		UIKit.stroke(nil, 3),
		UIKit.new("UIGradient", { Color = ColorSequence.new(Theme.Color.Pink, Theme.Color.Yellow), Rotation = 45 }),
	})
	UIKit.label({ Text = "?", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = body, MaxTextSize = 80 })
	return root
end

return CardView