-- ReplicatedStorage/Shared/UI/UIKit
-- ชุดชิ้นส่วนกลางสไตล์การ์ตูน "กาวระเบิด" ที่ใช้ร่วมกันทั้งเกม
-- (ปุ่ม 3 มิติยุบได้, กรอบการ์ดลายเส้นมือ, ป้ายเทียร์, ตัวหนังสือคอมิกขอบดำ, เอฟเฟกต์ปั่นๆ)
-- ตัวจริงอยู่ใน Style: UIKit เป็น API เดิมที่ห่อไว้ให้โค้ดเก่าใช้ต่อได้
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Settings)
local Style = require(script.Parent.Style)

local UIKit = {}
UIKit.Settings = { Voice = true, VFX = true, Tomato = true }
Settings.Changed:Connect(function(k, v) if k == "Effects" then UIKit.Settings.VFX = v end end)
UIKit.toastParent = nil
UIKit.Font = Style.Font
UIKit.Color = Style.C

local CENTER = Vector2.new(0.5, 0.5)

function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UIKit.corner(radius)
	return UIKit.new("UICorner", { CornerRadius = radius or UDim.new(0.2, 0) })
end

function UIKit.stroke(color, thickness)
	return UIKit.new("UIStroke", {
		Color = color or Theme.Color.Outline,
		Thickness = thickness or 3,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

UIKit.tween = Style.tween
UIKit.sfx = Style.sfx
UIKit.pop = Style.pop
UIKit.jiggle = Style.jiggle
UIKit.bounceText = Style.bounceText
UIKit.sparkles = Style.sparkles
UIKit.burst = Style.burst
UIKit.sunburst = Style.sunburst
UIKit.typewriter = Style.typewriter
UIKit.sticker = Style.sticker

-- ตัวหนังสือคอมิก: อ้วน ขอบดำหนา (Tilt = เอียงองศา)
function UIKit.label(p)
	local lbl = UIKit.new("TextLabel", {
		Name = p.Name or "Label",
		BackgroundTransparency = 1,
		Font = p.Font or Theme.Font,
		Text = p.Text or "",
		TextColor3 = p.Color or Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Center,
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		Rotation = p.Tilt or 0,
		Parent = p.Parent,
	}, {
		UIKit.new("UIStroke", { Thickness = p.StrokeThickness or 2.5, Color = Theme.Color.Outline,
			LineJoinMode = Enum.LineJoinMode.Round }),
		UIKit.new("UITextSizeConstraint", { MaxTextSize = p.MaxTextSize or 40 }),
	})
	return lbl
end

-- ปุ่มการ์ตูน 3 มิติ (ยุบลงเงาตอนกด เด้งตอนชี้) คืน (ปุ่ม, ตัวหนังสือ)
function UIKit.button(p)
	local btn = Style.button({
		Name = p.Name, Text = p.Text, Color = p.Color or Theme.Color.Yellow, Font = Theme.Font,
		Size = p.Size or UDim2.fromScale(0.2, 0.1), Position = p.Position, AnchorPoint = p.AnchorPoint,
		Parent = p.Parent, Max = p.MaxTextSize or 28, Sfx = p.Sfx,
		OnClick = p.OnClick and function() p.OnClick() end or nil,
	})
	return btn, btn.Face.Label
end

function UIKit.setColor(btn, color)
	Style.setBase(btn, color)
end

function UIKit.setDisabled(btn, disabled)
	btn:SetAttribute("Disabled", disabled)
end

function UIKit.shake(gui)
	Style.jiggle(gui, 9)
end

-- เอฟเฟกต์ย้วย: บีบแบนแล้วเด้งกลับ (ค่าติดลบ = ยืดสูง)
function UIKit.jelly(gui, amount)
	local base = gui:GetAttribute("BaseSize")
	if not base then
		base = gui.Size
		gui:SetAttribute("BaseSize", base)
	end
	amount = amount or 0.25
	gui.Size = UDim2.new(base.X.Scale * (1 + amount), base.X.Offset, base.Y.Scale * (1 - amount), base.Y.Offset)
	UIKit.tween(gui, 0.7, { Size = base }, Enum.EasingStyle.Elastic)
end

-- กรอบการ์ดลายเส้นมือ: ขอบดำหนา + เส้นร่างซ้อนเอียงนิดๆ + แถบสีเทียร์
function UIKit.cardFrame(parent, rarity, props)
	props = props or {}
	local color = Theme.Rarity[rarity] or Theme.Rarity.Common
	local frame = UIKit.new("Frame", {
		Name = props.Name or "CardFrame", BackgroundColor3 = Theme.Color.CardBg,
		Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, Parent = parent,
	}, { UIKit.corner(UDim.new(0, 10)), UIKit.stroke(Theme.Color.Outline, 3.5) })
	local band = UIKit.new("Frame", { Name = "TierBand", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = frame },
		{ UIKit.corner(UDim.new(0, 8)), UIKit.stroke(color, 3) })
	UIKit.new("Frame", { Name = "Sketch", BackgroundTransparency = 1, AnchorPoint = CENTER, Rotation = 1.2,
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -3, 1, -3), Parent = frame },
		{ UIKit.corner(UDim.new(0, 10)), UIKit.stroke(Theme.Color.Outline, 1.5) })
	local tier = Theme.Tier[rarity] or 1
	Style.sticker({ Text = "T" .. tier, Color = color, Size = UDim2.fromScale(0.28, 0.12),
		Position = UDim2.fromScale(0.86, 0.04), Tilt = 10, Max = 18, ZIndex = 6, Parent = frame })
	if tier >= 3 then Style.sparkles(frame, Color3.new(1, 1, 1), tier + 1, 7) end
	return frame, band
end

-- ตัวเลขดาเมจลอยขึ้น
function UIKit.popup(parent, text, color)
	local pop = UIKit.label({
		Text = text, Color = color or Theme.Color.Red, Size = UDim2.fromScale(1.2, 0.35),
		Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = CENTER, Parent = parent,
		MaxTextSize = 64, StrokeThickness = 3.5, Tilt = math.random(-12, 12),
	})
	pop.ZIndex = 20
	Style.pop(pop, 0.6)
	UIKit.tween(pop, 0.9, { Position = UDim2.fromScale(0.5, -0.3), TextTransparency = 1 })
	UIKit.tween(pop:FindFirstChildOfClass("UIStroke"), 0.9, { Transparency = 1 })
	task.delay(0.9, function() pop:Destroy() end)
end

-- ฝนของกาวๆ (ส่งข้อความ/อีโมจิ หรือ nil = เศษกระดาษสี)
function UIKit.rain(parent, emoji, count)
	if not Style.effectsOn() then return end
	local colors = { Theme.Color.Yellow, Theme.Color.Pink, Theme.Color.Blue, Theme.Color.Green }
	for _ = 1, count or 20 do
		local x = math.random()
		local drop
		if emoji then
			drop = UIKit.label({
				Text = emoji, Size = UDim2.fromScale(0.05, 0.08), Position = UDim2.fromScale(x, -0.1),
				Parent = parent, StrokeThickness = 0, MaxTextSize = 80,
			})
		else
			drop = UIKit.new("Frame", { BackgroundColor3 = colors[math.random(#colors)],
				Size = UDim2.fromOffset(math.random(10, 16), math.random(10, 16)), Position = UDim2.fromScale(x, -0.1),
				Parent = parent }, { UIKit.stroke(Theme.Color.Outline, 2) })
		end
		drop.ZIndex = 45
		UIKit.tween(drop, 1 + math.random(), {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.3, 1.15),
			Rotation = math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(2.2, function() drop:Destroy() end)
	end
end

function UIKit.toast(text, color)
	if UIKit.toastParent and not Style.toastParent then Style.toastParent = UIKit.toastParent end
	if not Style.toastParent then warn(text) return end
	local kind = "info"
	if color == Theme.Color.Red then kind = "bad" elseif color == Theme.Color.Green then kind = "good" end
	Style.toast(text, kind)
end

-- หน้าต่างป๊อปอัปการ์ตูน (ใช้ทำหน้า ตั้งค่า / สถิติ)
function UIKit.panel(parent, title, color)
	local dim = UIKit.new("Frame", {
		Name = "Panel_" .. title, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.35, Active = true, Visible = false, Parent = parent,
	})
	local holder, box = Style.panel({ Color = Theme.Color.Panel, Depth = 8, Radius = 18, Stroke = 4,
		Size = UDim2.fromScale(0.72, 0.78), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = CENTER, Parent = dim })
	box.Active = true
	Style.halftone(box, Theme.Color.Ink, 0.9, 8)
	local scale = UIKit.new("UIScale", { Parent = holder })
	local _, header = Style.panel({ Color = color or Theme.Color.Pink, Depth = 5, Radius = 12, Tilt = -2,
		Size = UDim2.fromScale(0.5, 0.12), Position = UDim2.fromScale(0.5, 0), AnchorPoint = CENTER, ZIndex = 3, Parent = holder })
	UIKit.label({ Text = title, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, Parent = header }).ZIndex = 4
	local content = UIKit.new("Frame", {
		Name = "Content", Size = UDim2.fromScale(0.94, 0.82), Position = UDim2.fromScale(0.03, 0.12),
		BackgroundTransparency = 1, ZIndex = 2, Parent = box,
	})

	local panel = { Root = dim, Content = content }
	function panel.Open()
		dim.Visible = true
		scale.Scale = 0.5
		holder.Rotation = -6
		UIKit.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(holder, 0.5, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		Style.sfx("Boing")
	end
	function panel.Close()
		dim.Visible = false
	end
	local close = UIKit.button({
		Text = "X", Color = Theme.Color.Red, Size = UDim2.fromScale(0.08, 0.1),
		Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0.6, 0.4), Parent = holder, OnClick = panel.Close,
	})
	close.ZIndex = 5
	UIKit.new("UIAspectRatioConstraint", { Parent = close })
	return panel
end

return UIKit
