-- ReplicatedStorage/Shared/UI/UIKit
-- ชุดเครื่องมือ UI การ์ตูนกลาง: ปุ่มเด้ง กรอบขอบดำ ฟอนต์คอมมิค เอฟเฟกต์กาชา (ใช้ร่วมกับ Theme)
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Settings)

local UIKit = {}
UIKit.Settings = { Voice = true, VFX = true, Tomato = true }
Settings.Changed:Connect(function(k, v) if k == "Effects" then UIKit.Settings.VFX = v end end)
UIKit.toastParent = nil

local CENTER = Vector2.new(0.5, 0.5)
local OUTLINE = 3
local SHADOW = 5

function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
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
	return UIKit.new("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

function UIKit.stroke(color, thickness)
	return UIKit.new("UIStroke", {
		Color = color or Theme.Color.Outline,
		Thickness = thickness or OUTLINE,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- เงาทึบแบบการ์ตูน: ต้องเป็น "พี่น้อง" ของเป้าหมาย (ZIndexBehavior.Sibling ทำให้ลูกอยู่บนพ่อเสมอ)
function UIKit.shadow(target, offset)
	offset = offset or SHADOW
	local sh = UIKit.new("Frame", {
		Name = target.Name .. "_Shadow", BackgroundColor3 = Theme.Color.Outline,
		AnchorPoint = target.AnchorPoint, ZIndex = math.max(target.ZIndex - 1, 0), Parent = target.Parent,
	})
	local corner = target:FindFirstChildOfClass("UICorner")
	UIKit.corner(corner and corner.CornerRadius).Parent = sh
	local function sync()
		sh.Position = target.Position + UDim2.fromOffset(offset, offset)
		sh.Size = target.Size
		sh.Visible = target.Visible
		sh.Rotation = target.Rotation
	end
	for _, prop in { "Position", "Size", "Visible", "Rotation" } do
		target:GetPropertyChangedSignal(prop):Connect(sync)
	end
	target.AncestryChanged:Connect(function() if not target.Parent then sh:Destroy() end end)
	sync()
	return sh
end

function UIKit.tween(inst, time, props, style, direction)
	time = time / (Settings.Get("AnimSpeed") or 1)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UIKit.sfx(name, pitch)
	local folder = SoundService:FindFirstChild("SFX")
	local sound = folder and folder:FindFirstChild(name)
	if not sound then return end
	local s = sound:Clone()
	s.PlaybackSpeed = pitch or (0.92 + math.random() * 0.16)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end

-- ตัวหนังสือมีขอบดำ อ่านออกบนพื้นสีจัด
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
		Rotation = p.Rotation or 0,
		ZIndex = p.ZIndex or 1,
		Parent = p.Parent,
	}, {
		UIKit.new("UIStroke", { Thickness = p.StrokeThickness or 2.5, Color = Theme.Color.Outline, LineJoinMode = Enum.LineJoinMode.Round }),
		UIKit.new("UITextSizeConstraint", { MaxTextSize = p.MaxTextSize or 40 }),
	})
	return lbl
end

local function scaleOf(gui)
	local s = gui:FindFirstChild("FxScale")
	if not s then s = UIKit.new("UIScale", { Name = "FxScale", Parent = gui }) end
	return s
end

-- ปุ่มเด้งดึ๋ง: ขอบดำหนา เงาทึบ ขยาย+เอียงตอนชี้ ยุบลงไปทับเงาตอนกด
function UIKit.button(p)
	local base = p.Color or Theme.Color.Yellow
	local btn = UIKit.new("TextButton", {
		Name = p.Name or "Button",
		Size = p.Size or UDim2.fromScale(0.2, 0.1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = p.ZIndex or 1,
		Parent = p.Parent,
	})
	local z = btn.ZIndex
	local shadow = UIKit.new("Frame", { Name = "Shadow", BackgroundColor3 = Theme.Color.Outline,
		Position = UDim2.fromOffset(SHADOW, SHADOW), Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = btn }, { UIKit.corner() })
	local body = UIKit.new("Frame", { Name = "Body", BackgroundColor3 = base, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = btn },
		{ UIKit.corner(), UIKit.stroke(nil, OUTLINE) })
	UIKit.new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72,
		Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.28), ZIndex = z + 2, Parent = body }, { UIKit.corner() })
	local label = UIKit.label({
		Text = p.Text, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, Parent = body, MaxTextSize = p.MaxTextSize, ZIndex = z + 3,
		Color = p.TextColor or Theme.Color.Panel,
	})
	local scale = scaleOf(btn)
	local baseRot = p.Rotation or 0
	btn.Rotation = baseRot
	btn:SetAttribute("BaseColor", base)

	local function paint()
		local c = btn:GetAttribute("BaseColor") or base
		if btn:GetAttribute("Disabled") then
			body.BackgroundColor3 = Theme.Color.Gray
			shadow.Visible = false
			body.Position = UDim2.fromOffset(SHADOW, SHADOW)
			label.TextTransparency = 0.35
		else
			body.BackgroundColor3 = c
			shadow.Visible = true
			body.Position = UDim2.new()
			label.TextTransparency = 0
		end
	end
	btn:GetAttributeChangedSignal("Disabled"):Connect(paint)
	btn:GetAttributeChangedSignal("BaseColor"):Connect(paint)

	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") then return end
		UIKit.tween(scale, 0.1, { Scale = 1.07 }, Enum.EasingStyle.Back)
		UIKit.tween(btn, 0.1, { Rotation = baseRot + (math.random() < 0.5 and -2.5 or 2.5) })
	end)
	btn.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1 })
		UIKit.tween(btn, 0.12, { Rotation = baseRot })
		if not btn:GetAttribute("Disabled") then body.Position = UDim2.new() shadow.Visible = true end
	end)
	btn.MouseButton1Down:Connect(function()
		if btn:GetAttribute("Disabled") then return end
		body.Position = UDim2.fromOffset(SHADOW, SHADOW)
		shadow.Visible = false
		UIKit.tween(scale, 0.05, { Scale = 0.92 })
	end)
	btn.MouseButton1Up:Connect(function()
		if btn:GetAttribute("Disabled") then return end
		body.Position = UDim2.new()
		shadow.Visible = true
		UIKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then UIKit.shake(btn) UIKit.sfx("Nope") return end
		UIKit.sfx("Click")
		if p.OnClick then p.OnClick() end
	end)
	paint()
	return btn, label
end

function UIKit.setColor(btn, color)
	btn:SetAttribute("BaseColor", color)
end

function UIKit.setDisabled(btn, disabled)
	if btn:GetAttribute("BaseColor") == nil then
		local body = btn:FindFirstChild("Body")
		btn:SetAttribute("BaseColor", body and body.BackgroundColor3 or btn.BackgroundColor3)
	end
	btn:SetAttribute("Disabled", disabled)
end

function UIKit.shake(gui)
	task.spawn(function()
		for _, r in { -8, 8, -5, 5, -2, 0 } do
			if not gui.Parent then return end
			gui.Rotation = r
			task.wait(0.04)
		end
	end)
end

-- เด้งโป่งแล้วหดกลับ (ตัวเลข/ข้อความเปลี่ยน)
function UIKit.punch(gui, amount)
	local s = scaleOf(gui)
	s.Scale = 1 + (amount or 0.3)
	UIKit.tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
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

-- โยกไปมาเบาๆ ตลอดเวลา
function UIKit.wobble(gui, deg, period)
	deg, period = deg or 3, period or 1.2
	local base = gui.Rotation
	task.spawn(function()
		local dir = 1
		while gui.Parent do
			UIKit.tween(gui, period, { Rotation = base + deg * dir }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			dir = -dir
			task.wait(period)
		end
	end)
end

-- ตัวเลขดาเมจลอยขึ้น (ตัวใหญ่ ขอบดำ เอียง)
function UIKit.popup(parent, text, color)
	local pop = UIKit.label({
		Text = text, Color = color or Theme.Color.Red, Size = UDim2.fromScale(1.2, 0.35),
		Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = CENTER, Parent = parent,
		MaxTextSize = 64, StrokeThickness = 3, Font = Theme.FontShout, Rotation = math.random(-12, 12),
	})
	pop.ZIndex = 20
	UIKit.punch(pop, 0.5)
	UIKit.tween(pop, 0.9, { Position = UDim2.fromScale(0.5, -0.3), TextTransparency = 1 })
	UIKit.tween(pop:FindFirstChildOfClass("UIStroke"), 0.9, { Transparency = 1 })
	task.delay(0.9, function() pop:Destroy() end)
end

-- ประกายกาชา (เพชรเล็กๆ กระเด็นออกจากกลาง) ใช้ตอนเปิดได้เทียร์สูง
function UIKit.sparkle(parent, color, count)
	if not UIKit.Settings.VFX then return end
	for _ = 1, count or 14 do
		local size = math.random(6, 14)
		local sp = UIKit.new("Frame", {
			BackgroundColor3 = color or Theme.Color.Yellow, AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
			Rotation = 45, ZIndex = (parent.ZIndex or 1) + 30, Parent = parent,
		}, { UIKit.corner(UDim.new(0, 2)), UIKit.stroke(nil, 1.5) })
		local ang = math.random() * math.pi * 2
		local dist = 0.25 + math.random() * 0.55
		UIKit.tween(sp, 0.55 + math.random() * 0.3, {
			Position = UDim2.fromScale(0.5 + math.cos(ang) * dist, 0.5 + math.sin(ang) * dist),
			Rotation = 45 + math.random(-180, 180), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2),
		})
		task.delay(0.9, function() sp:Destroy() end)
	end
end

-- ฝนสัญลักษณ์/ข้อความ (ใช้ตอนช่องเกตออกทอง/อึ หรือตอนชนะ)
function UIKit.rain(parent, emoji, count)
	if not UIKit.Settings.VFX then return end
	for _ = 1, count or 20 do
		local x = math.random()
		local drop = UIKit.label({
			Text = emoji, Size = UDim2.fromScale(0.05, 0.08), Position = UDim2.fromScale(x, -0.1),
			Parent = parent, StrokeThickness = 0, MaxTextSize = 80,
		})
		UIKit.tween(drop, 1 + math.random(), {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.3, 1.15),
			Rotation = math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(2.2, function() drop:Destroy() end)
	end
end

function UIKit.toast(text, color)
	local parent = UIKit.toastParent
	if not parent then warn(text) return end
	local box = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.4, 0.07), Position = UDim2.fromScale(0.5, -0.1), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = color or Theme.Color.Pink, ZIndex = 50, Rotation = math.random(-2, 2), Parent = parent,
	}, { UIKit.corner(), UIKit.stroke() })
	UIKit.label({ Text = text, Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = box, ZIndex = 51 })
	UIKit.tween(box, 0.35, { Position = UDim2.fromScale(0.5, 0.1) }, Enum.EasingStyle.Back)
	task.delay(2, function()
		UIKit.tween(box, 0.3, { Position = UDim2.fromScale(0.5, -0.1) })
		task.wait(0.3)
		box:Destroy()
	end)
end

-- หน้าต่างป๊อปอัป (ใช้ทำหน้า เด็ค / กาชา / ตั้งค่า)
function UIKit.panel(parent, title, color)
	local dim = UIKit.new("Frame", {
		Name = "Panel_" .. title, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Bg,
		BackgroundTransparency = 0.4, Active = true, Visible = false, Parent = parent,
	})
	local box = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.72, 0.78), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = CENTER,
		BackgroundColor3 = Theme.Color.Panel, Active = true, ZIndex = 2, Parent = dim,
	}, { UIKit.corner(UDim.new(0, 18)), UIKit.stroke(nil, 4) })
	UIKit.shadow(box, 8)
	local scale = UIKit.new("UIScale", { Parent = box })
	local header = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.5, 0.12), Position = UDim2.fromScale(0.5, 0), AnchorPoint = CENTER,
		BackgroundColor3 = color or Theme.Color.Pink, Rotation = -2, ZIndex = 4, Parent = box,
	}, { UIKit.corner(), UIKit.stroke(nil, 4) })
	UIKit.label({ Text = title, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = header, ZIndex = 5, Font = Theme.FontShout })
	local content = UIKit.new("Frame", {
		Name = "Content", Size = UDim2.fromScale(0.94, 0.82), Position = UDim2.fromScale(0.03, 0.12),
		BackgroundTransparency = 1, ZIndex = 3, Parent = box,
	})

	local panel = { Root = dim, Content = content }
	function panel.Open()
		dim.Visible = true
		scale.Scale = 0.6
		UIKit.sfx("Pop")
		UIKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	function panel.Close()
		dim.Visible = false
	end
	local close = UIKit.button({
		Text = "X", Color = Theme.Color.Red, Size = UDim2.fromScale(0.08, 0.1), ZIndex = 6,
		Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0.6, 0.4), Parent = box, OnClick = panel.Close,
	})
	UIKit.new("UIAspectRatioConstraint", { Parent = close })
	return panel
end

return UIKit
