-- ReplicatedStorage/Shared/UI/CardView
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local Settings = require(script.Parent.Settings)
local Perf = require(script.Parent:WaitForChild("Perf"))
local TweenService = game:GetService("TweenService")
local function Inspector() return require(script.Parent.CardInspector) end -- require ตอนใช้ เลี่ยง require วนกัน

local SHINY = { Epic = 0.7, Legend = 0.5, Mystic = 0.35 } -- ค่ายิ่งน้อย แสงยิ่งแรง
local function addShine(art, strength)
	local shine = UIKit.new("Frame", {
		Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3, Parent = art,
	}, { UIKit.corner(UDim.new(0.08, 0)) })
	local g = UIKit.new("UIGradient", {
		Rotation = 25, Offset = Vector2.new(-1, 0), Parent = shine,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, strength),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local tw = TweenService:Create(g, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.5 + math.random()), { Offset = Vector2.new(1, 0) })
	tw:Play()
	shine.Visible = Settings.Get("Effects")
	local c = Settings.Changed:Connect(function(k, v) if k == "Effects" then shine.Visible = v end end)
	shine.Destroying:Once(function() tw:Cancel() c:Disconnect() end)
end

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
	self.Shadow = UIKit.new("Frame", {
		Name = "Shadow", Size = UDim2.fromScale(0.96, 0.96), Position = UDim2.fromScale(0.52, 0.535),
		AnchorPoint = CENTER, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
		ZIndex = 0, Parent = root,
	}, { UIKit.corner(UDim.new(0.08, 0)) })

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
	self.Status = UIKit.label({
		Text = "", Size = UDim2.fromScale(0.95, 0.24), Position = UDim2.fromScale(0.5, 0.98),
		AnchorPoint = Vector2.new(0.5, 1), Parent = self.Art, StrokeThickness = 1,
	})
	if SHINY[card.Rarity] and Perf.allowShine(card.Rarity) then addShine(self.Art, SHINY[card.Rarity]) end

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

	-- opts: Static (ไม่ให้เปิดดู), NoHover, InspectList, InspectIndex
	local hit = UIKit.new("TextButton", { Name = "Hitbox", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = body })
	local function doInspect()
		if opts.Static then return end
		if opts.OnInspect then opts.OnInspect(self)
		else Inspector().Open(self.Card, opts.InspectList, opts.InspectIndex) end
	end
	local longPressed = false
	hit.Activated:Connect(function()
		if longPressed then longPressed = false return end -- กันกดค้างแล้วไปเลือกการ์ดซ้อน
		if opts.OnClick then opts.OnClick(self) end
	end)
	hit.MouseButton2Click:Connect(doInspect)
	hit.TouchLongPress:Connect(function(_, inputState)
		if inputState == Enum.UserInputState.Begin then longPressed = true doInspect() end
	end)
	if not opts.Static then
		Inspector().Track(hit, doInspect)
		if not opts.NoHover then
			local hover = UIKit.new("UIScale", { Parent = body })
			hit.MouseEnter:Connect(function() UIKit.tween(hover, 0.12, { Scale = 1.06 }) root.ZIndex = 10 end)
			hit.MouseLeave:Connect(function() UIKit.tween(hover, 0.12, { Scale = 1 }) root.ZIndex = 1 end)
		end
	end

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
	local status = {}
	if card.Frozen then table.insert(status, "❄️") end
	if card.Slime then table.insert(status, "🟢") end
	if card.WeaponName then table.insert(status, "🗡️" .. tostring(card.WeaponDur or 0)) end
	self.Status.Text = table.concat(status, " ")

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
	if not UIKit.effectsOn() then return end
	if typeof(self.Card.HitArt) == "string" then -- ถ้ามีภาพหน้าโดนตี ให้สลับภาพชั่วคราว
		self.Art.Image = self.Card.HitArt
		task.delay(0.7, function()
			if self.Art.Parent then self:Update(self.Card) end
		end)
	end
	UIKit.jelly(self.Art, -0.4) -- ภาพยืดเบี้ยว
	UIKit.jelly(self.Body, 0.35)
	if Perf.get("shake") then UIKit.shake(self.Body) end
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
	if self.Dead then return end -- กันเรียกซ้ำ
	self.Dead = true
	if self.Shadow then self.Shadow.Visible = false end
	UIKit.sfx("Death")
	local mode = UIKit.effectsOn() and Perf.get("death") or "none"
	if mode == "full" then DEATH_STYLES[math.random(#DEATH_STYLES)](self)
	elseif mode == "simple" then DEATH_STYLES[1](self) end
	task.delay(mode == "none" and 0 or 0.6, function() self.Frame:Destroy() end)
end

function CardView:Remove()
	self.Frame:Destroy()
end

function CardView:PopIn()
	self.Body.Size = UDim2.fromScale(0.1, 0.1)
	UIKit.tween(self.Body, 0.35, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
end

-- บั๊กเดิม: Lunge ดึงการ์ดที่เลือกอยู่กลับไปตำแหน่งปกติ, SetTarget(false) ลบขอบเหลืองของการ์ดที่เลือก
function CardView:_paintStroke()
	if self.Targeted then
		self.Stroke.Color, self.Stroke.Thickness = Theme.Color.Red, 6
	elseif self.Selected then
		self.Stroke.Color, self.Stroke.Thickness = Theme.Color.Yellow, 6
	else
		self.Stroke.Color, self.Stroke.Thickness = self.RarityColor, 4
	end
end
function CardView:_rest() return UDim2.fromScale(0.5, self.Selected and 0.42 or 0.5) end

function CardView:SetSelected(on)
	self.Selected = on and true or false
	self:_paintStroke()
	UIKit.tween(self.Body, 0.15, { Position = self:_rest() })
end

function CardView:SetTarget(on)
	self.Targeted = on and true or false
	self:_paintStroke()
end

function CardView:Lunge()
	UIKit.tween(self.Body, 0.12, { Position = UDim2.fromScale(0.5, 0.2) }).Completed:Once(function()
		if self.Body.Parent then UIKit.tween(self.Body, 0.25, { Position = self:_rest() }, Enum.EasingStyle.Back) end
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