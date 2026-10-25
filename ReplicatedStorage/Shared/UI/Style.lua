-- ธีมการ์ตูนปั่นๆ (PASULOL vibe): สีจัดคอนทราสต์สูง ขอบดำหนา ปุ่มนูน 3 มิติ ตัวหนังสือเด้งดึ๋ง
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Style = {}

local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end

-- ฟอนต์หนากลมแบบการ์ตูน (ตัวไทยจะใช้ฟอนต์สำรองของ Roblox โดยอัตโนมัติ)
Style.Font = {
	Regular = font("FredokaOne", Enum.Font.GothamBold),
	Medium = font("FredokaOne", Enum.Font.GothamBold),
	Bold = font("FredokaOne", Enum.Font.GothamBlack),
	Heavy = font("Bangers", Enum.Font.GothamBlack),
}

local WHITE = Color3.new(1, 1, 1)

Style.C = {
	Bg = Color3.fromRGB(26, 14, 52),
	Panel = Color3.fromRGB(255, 250, 230),
	Panel2 = Color3.fromRGB(255, 232, 150),
	Line = Color3.fromRGB(18, 10, 26),
	Felt = Color3.fromRGB(48, 22, 92),
	FeltDark = Color3.fromRGB(30, 12, 60),
	Paper = Color3.fromRGB(255, 252, 240),
	Ink = Color3.fromRGB(18, 10, 26),
	InkSoft = Color3.fromRGB(104, 76, 128),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(222, 204, 255),
	Accent = Color3.fromRGB(255, 232, 0),   -- เหลืองมะนาว
	Good = Color3.fromRGB(84, 255, 112),    -- เขียวสะท้อนแสง
	Bad = Color3.fromRGB(255, 52, 96),
	Info = Color3.fromRGB(36, 204, 255),    -- ฟ้าสด
	Pink = Color3.fromRGB(255, 56, 176),    -- ชมพูบานเย็น
	Violet = Color3.fromRGB(156, 72, 255),
	Teal = Color3.fromRGB(0, 236, 204),
	Lime = Color3.fromRGB(196, 255, 40),
	Orange = Color3.fromRGB(255, 142, 20),
	Brown = Color3.fromRGB(130, 82, 46),
}
Style.Rarity = {
	Common = Color3.fromRGB(176, 176, 190), Rare = Color3.fromRGB(40, 170, 255),
	Epic = Color3.fromRGB(186, 86, 255), Legend = Color3.fromRGB(255, 196, 0), Mystic = Color3.fromRGB(255, 70, 160),
}
Style.Tier = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }
Style.Element = {
	Sati = Color3.fromRGB(40, 170, 255), Biao = Color3.fromRGB(255, 70, 70),
	Muen = Color3.fromRGB(170, 100, 255), Gawa = Color3.fromRGB(255, 190, 0),
}
Style.Name = {
	Type = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" },
	Element = { Sati = "สติ", Biao = "เบียว", Muen = "มึน", Gawa = "กาว" },
	Rarity = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" },
	Keyword = { Rush = "บุก", Taunt = "ยั่วยุ", Necro = "ปลุกศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" },
}
Style.RAINBOW = {
	Color3.fromRGB(255, 60, 90), Color3.fromRGB(255, 200, 0), Color3.fromRGB(80, 255, 120),
	Color3.fromRGB(40, 210, 255), Color3.fromRGB(180, 80, 255), Color3.fromRGB(255, 60, 90),
}

-- ===== ตัวช่วยสร้าง Instance =====
function Style.new(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
	local parent
	for k, v in props or {} do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

function Style.corner(r) return Style.new("UICorner", { CornerRadius = UDim.new(0, r or 10) }) end
function Style.pad(px)
	local u = UDim.new(0, px)
	return Style.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end
-- เส้นขอบการ์ตูน (ดำหนา มุมมน)
function Style.stroke(color, thickness, parent)
	return Style.new("UIStroke", {
		Color = color or Style.C.Ink, Thickness = thickness or 3, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end
function Style.gradient(parent, colors, rotation)
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return Style.new("UIGradient", { Color = ColorSequence.new(keys), Rotation = rotation or 0, Parent = parent })
end
local function luminance(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
function Style.textStroke(label, thickness)
	return Style.new("UIStroke", { Color = Style.C.Ink, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
end

-- ===== ลูปอนิเมชันกลาง (หมุน / เต้น / สีรุ้ง) =====
-- เก็บแบบ weak key: อินสแตนซ์ที่ถูก Destroy แล้วจะหลุดออกไปเอง ฟังก์ชันห้ามจับตัวอินสแตนซ์ไว้ใน closure
local animated = setmetatable({}, { __mode = "k" })
local function animate(inst, fn) animated[inst] = fn end
if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for inst, fn in animated do
			if inst:IsDescendantOf(game) then
				local ok = pcall(fn, inst, dt, t)
				if not ok then animated[inst] = nil end
			end
		end
	end)
end

function Style.spin(gui, degPerSec)
	local speed = degPerSec or 40
	animate(gui, function(inst, dt) inst.Rotation = (inst.Rotation + speed * dt) % 360 end)
	return gui
end
function Style.rainbow(parent, speed)
	local g = Style.gradient(parent, Style.RAINBOW, 0)
	Style.spin(g, speed or 120)
	return g
end
local function scaleOf(gui)
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then s = Style.new("UIScale", { Parent = gui }) end
	return s
end
function Style.pulse(gui, lo, hi, period)
	local s = scaleOf(gui)
	local a, b, p = lo or 0.96, hi or 1.04, period or 1.2
	animate(s, function(inst, _, t) inst.Scale = a + (b - a) * (0.5 + 0.5 * math.sin(t * math.pi * 2 / p)) end)
	return s
end
function Style.stopAnim(inst) animated[inst] = nil end

-- เด้งดึ๋งครั้งเดียว (ใช้ตอนตัวเลขเปลี่ยน / กดปุ่ม)
function Style.bump(gui, amount, time)
	local s = scaleOf(gui)
	if animated[s] then return end
	s.Scale = 1 + (amount or 0.25)
	TweenService:Create(s, TweenInfo.new(time or 0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
-- สั่นซ้ายขวารอบมุมเดิม (ไม่รีเซ็ตมุมของการ์ดที่เอียงอยู่แล้ว)
function Style.wobble(gui, strength)
	local k = strength or 1
	local base = gui.Rotation
	task.spawn(function()
		for _, r in { -8, 8, -5, 5, -2, 0 } do
			if not gui.Parent then return end
			gui.Rotation = base + r * k
			task.wait(0.04)
		end
	end)
end
-- เปลี่ยนข้อความแล้วเด้ง (ถ้าข้อความเปลี่ยนจริง)
function Style.setText(label, text, amount)
	text = tostring(text)
	if label.Text == text then return false end
	label.Text = text
	Style.bump(label, amount or 0.35)
	return true
end
function Style.tween(inst, time, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- ===== ข้อความ =====
function Style.text(p)
	local lbl = Style.new("TextLabel", {
		Name = p.Name or "Text", BackgroundTransparency = 1, Text = p.Text or "",
		Font = p.Font or Style.Font.Regular, TextColor3 = p.Color or Style.C.Text,
		TextScaled = true, TextWrapped = p.Wrap ~= false,
		TextXAlignment = Enum.TextXAlignment[p.XAlign or "Left"],
		TextYAlignment = Enum.TextYAlignment[p.YAlign or "Center"],
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, ZIndex = p.ZIndex or 1, Rotation = p.Rotation or 0,
		LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = p.Min or 6, Parent = lbl })
	if p.Stroke then Style.textStroke(lbl, p.Stroke) end
	return lbl
end

-- ===== กล่อง/แผงกระดาษขอบดำ =====
function Style.box(p)
	local color = p.Color or Style.C.Panel
	local f = Style.new("Frame", {
		Name = p.Name or "Box", BackgroundColor3 = color, BackgroundTransparency = p.Transparency or 0,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Rotation = p.Rotation or 0, Parent = p.Parent,
	}, { Style.corner(p.Radius or 12) })
	Style.stroke(p.StrokeColor or Style.C.Ink, p.Stroke or 3, f)
	if p.Pad then Style.pad(p.Pad).Parent = f end
	return f
end

-- ป้ายเล็ก (pill) มีขอบดำ ใช้บอกเทียร์/โล่/จำนวน
function Style.badge(p)
	local color = p.Color or Style.C.Accent
	local light = luminance(color) > 0.6
	local f = Style.box({ Name = p.Name or "Badge", Color = color, Radius = p.Radius or 999, Stroke = p.Stroke or 2,
		Position = p.Position, Size = p.Size or UDim2.fromOffset(44, 22), AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.LayoutOrder, ZIndex = p.ZIndex, Rotation = p.Rotation, Parent = p.Parent })
	local lbl = Style.text({ Text = p.Text or "", Font = p.Font or Style.Font.Bold, Color = p.TextColor or (light and Style.C.Ink or Style.C.Text),
		Max = p.Max or 14, XAlign = "Center", Stroke = (not light) and 1.5 or nil, ZIndex = (p.ZIndex or 1) + 1,
		Position = UDim2.fromScale(0.08, 0), Size = UDim2.fromScale(0.84, 1), Parent = f })
	return f, lbl
end

-- ===== ปุ่มนูน 3 มิติแบบการ์ตูน: หน้าปุ่มสีสด ก้นปุ่มสีเข้ม กดแล้วยุบ ชี้แล้วพอง =====
function Style.button(p)
	local base = p.Color or Style.C.Accent
	local edge = p.Edge or 5
	local radius = p.Radius or 12
	local btn = Style.new("TextButton", {
		Name = p.Name or "Button", AutoButtonColor = false, Text = p.Text or "", TextTransparency = 1,
		Font = p.Font or Style.Font.Heavy, TextColor3 = p.TextColor or Style.C.Ink,
		BackgroundColor3 = base:Lerp(Style.C.Ink, 0.55),
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Parent = p.Parent,
	}, { Style.corner(radius) })
	local z = btn.ZIndex
	Style.stroke(Style.C.Ink, p.Stroke or 3, btn)
	local face = Style.new("Frame", { Name = "Face", BackgroundColor3 = base, Size = UDim2.new(1, 0, 1, -edge), ZIndex = z, Parent = btn },
		{ Style.corner(radius), Style.pad(p.Pad or 6) })
	Style.stroke(Style.C.Ink, p.Stroke or 3, face)
	local label = Style.new("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = btn.Text,
		Font = btn.Font, TextColor3 = btn.TextColor3, TextScaled = true, TextWrapped = true, ZIndex = z + 1, Parent = face,
	}, { Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 20, MinTextSize = 6 }) })
	local tstroke = Style.textStroke(label, 2)
	local function paintText()
		label.Text = btn.Text
		label.TextColor3 = btn.TextColor3
		tstroke.Enabled = luminance(btn.TextColor3) > 0.6
	end
	btn:GetPropertyChangedSignal("Text"):Connect(paintText)
	btn:GetPropertyChangedSignal("TextColor3"):Connect(paintText)

	local scale = Style.new("UIScale", { Parent = btn })
	local hovered, pressed = false, false
	local function paint()
		local c = btn:GetAttribute("Base") or base
		local disabled = btn:GetAttribute("Disabled")
		local fill = disabled and Color3.fromRGB(150, 146, 160) or (hovered and c:Lerp(WHITE, 0.18) or c)
		face.BackgroundColor3 = fill
		btn.BackgroundColor3 = fill:Lerp(Style.C.Ink, 0.55)
		label.TextTransparency = disabled and 0.4 or 0
		face.Position = (pressed and not disabled) and UDim2.fromOffset(0, edge) or UDim2.new()
	end
	btn:SetAttribute("Base", base)
	btn.MouseEnter:Connect(function()
		hovered = true
		paint()
		if not btn:GetAttribute("Disabled") then Style.tween(scale, 0.1, { Scale = 1.05 }) end
	end)
	btn.MouseLeave:Connect(function()
		hovered, pressed = false, false
		paint()
		Style.tween(scale, 0.12, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function() pressed = true paint() end)
	btn.MouseButton1Up:Connect(function()
		pressed = false
		paint()
		Style.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn:GetAttributeChangedSignal("Disabled"):Connect(paint)
	btn:GetAttributeChangedSignal("Base"):Connect(paint)
	local last = 0
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then Style.wobble(btn, 0.5) return end
		local now = os.clock()
		if now - last < (p.Debounce or 0.25) then return end -- กันกดรัวฝั่งไคลเอนต์
		last = now
		Style.bump(btn, 0.08, 0.3)
		if p.OnClick then p.OnClick(btn) end
	end)
	paintText()
	paint()
	return btn
end

function Style.setEnabled(btn, on) btn:SetAttribute("Disabled", not on) end
function Style.setBase(btn, color) btn:SetAttribute("Base", color) end

-- ตัดอีโมจิออกจากข้อความที่มาจากเซิร์ฟเวอร์
function Style.clean(text)
	text = tostring(text or "")
	local ok, out = pcall(function()
		local parts = {}
		for _, cp in utf8.codes(text) do
			local emoji = cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF)
				or (cp >= 0x2B00 and cp <= 0x2BFF) or cp == 0xFE0F or cp == 0x200D
			if not emoji then table.insert(parts, utf8.char(cp)) end
		end
		return table.concat(parts)
	end)
	if not ok then return text end
	return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Style.screen(name, order, parent)
	local g = Style.new("ScreenGui", {
		Name = name, DisplayOrder = order, ResetOnSpawn = false,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	pcall(function() g.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets end)
	g.Parent = parent
	return g
end

-- ScrollingFrame ที่ขนาด canvas คำนวณเองจากเนื้อหา
-- (AutomaticCanvasSize + UIListLayout มีบัคที่รู้กัน: canvas เหลือ 0 แล้วเนื้อหาหายหมด)
function Style.scroll(p)
	local f = Style.new("ScrollingFrame", {
		Name = p.Name or "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		ScrollBarThickness = 8, ScrollBarImageColor3 = Style.C.Pink, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	local layout = p.Layout
	if not layout then
		layout = Style.new("UIListLayout", { Padding = UDim.new(0, p.Gap or 8), SortOrder = Enum.SortOrder.LayoutOrder })
	end
	layout.Parent = f
	local function fit()
		f.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (p.Extra or 8))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	fit()
	return f, layout
end

-- ให้ลูกตัวนี้กินพื้นที่ที่เหลือใน UIListLayout (ถ้าเวอร์ชัน Studio ไม่รู้จัก UIFlexItem จะข้ามไปเฉยๆ)
function Style.fill(gui)
	pcall(function()
		local flex = Instance.new("UIFlexItem")
		flex.FlexMode = Enum.UIFlexMode.Fill
		flex.Parent = gui
	end)
end

-- ริบบิ้นหัวเรื่อง: สีจัด เอียงนิดๆ ตัวหนังสือขาวขอบดำ
function Style.header(parent, text, color, order)
	local bar = Style.box({ Name = "Header", Color = color or Style.C.Pink, Radius = 10, Stroke = 3,
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order or 0, Parent = parent })
	Style.pad(4).Parent = bar
	Style.text({ Font = Style.Font.Heavy, Text = text, Color = Style.C.Text, Max = 26, Stroke = 2.5, Rotation = -1.5, Parent = bar,
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0) })
	return bar
end

-- แถบเล็กๆ สลับสีแบบตาข่าย/เทปกั้น
function Style.stripes(parent, count, a, b)
	local holder = Style.new("Frame", { Name = "Stripes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent }, {
		Style.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, count do
		Style.new("Frame", { BackgroundColor3 = (i % 2 == 0) and (a or Style.C.Accent) or (b or Style.C.Ink),
			Size = UDim2.fromScale(1 / count, 1), LayoutOrder = i, Parent = holder })
	end
	return holder
end

-- กระดาษสี่เหลี่ยมโปรยลงมา (ใช้ตอนชนะ / เกตออกทอง)
function Style.confetti(parent, colors, count)
	colors = colors or { Style.C.Accent, Style.C.Pink, Style.C.Info, Style.C.Lime, Style.C.Orange }
	for _ = 1, count or 30 do
		local x = math.random()
		local piece = Style.new("Frame", {
			BackgroundColor3 = colors[math.random(#colors)], AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, -0.05), Size = UDim2.fromOffset(math.random(8, 16), math.random(8, 16)),
			Rotation = math.random(0, 360), ZIndex = 60, Parent = parent,
		}, { Style.corner(2) })
		Style.stroke(Style.C.Ink, 1.5, piece)
		Style.tween(piece, 1.2 + math.random(), {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.3, 1.1), Rotation = math.random(-720, 720),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(2.4, function() piece:Destroy() end)
	end
end

-- ===== Toast: กล่องสีจัดเด้งลงมาจากด้านบน ซ้อนกันสูงสุด 3 อัน =====
Style.toastParent = nil
local holder, seq, lastText, lastAt = nil, 0, nil, 0
local KIND = { info = Style.C.Info, good = Style.C.Good, bad = Style.C.Bad }
function Style.toast(text, kind)
	local parent = Style.toastParent
	if not parent then return end
	text = Style.clean(text)
	if text == "" then return end
	if text == lastText and os.clock() - lastAt < 0.6 then return end
	lastText, lastAt = text, os.clock()
	if not holder or not holder.Parent then
		holder = Style.new("Frame", {
			Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.42, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50, Parent = parent,
		}, {
			Style.new("UIListLayout", {
				Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Style.new("UISizeConstraint", { MaxSize = Vector2.new(460, 9999) }),
		})
	end
	local items = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #items >= 3 do table.remove(items, 1):Destroy() end
	seq += 1
	local color = KIND[kind or "info"] or KIND.info
	local f = Style.box({ Color = color, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = seq, ZIndex = 50,
		Rotation = math.random(-2, 2), Parent = holder })
	Style.text({ Text = text, Font = Style.Font.Bold, Max = 17, XAlign = "Center", Stroke = 2, Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0), ZIndex = 51, Parent = f })
	Style.bump(f, 0.2)
	task.delay(2.6, function() if f.Parent then f:Destroy() end end)
end

-- ===== ป้ายใหญ่กลางจอ (เปลี่ยนเทิร์น / ผลเกต) =====
function Style.banner(text, color, hold)
	local parent = Style.toastParent
	if not parent then return end
	local f = Style.box({ Color = color or Style.C.Accent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.5, 0.14), Radius = 16, Stroke = 4, Rotation = -3, ZIndex = 70, Parent = parent })
	Style.new("UISizeConstraint", { MinSize = Vector2.new(240, 60), MaxSize = Vector2.new(620, 120), Parent = f })
	Style.text({ Text = text, Font = Style.Font.Heavy, Max = 54, XAlign = "Center", Stroke = 3.5, ZIndex = 71,
		Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 1), Parent = f })
	local s = Style.new("UIScale", { Scale = 0, Parent = f })
	Style.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(hold or 1.1, function()
		if not f.Parent then return end
		Style.tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.25)
		f:Destroy()
	end)
	return f
end

return Style
