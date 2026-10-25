-- ReplicatedStorage/Shared/UI/Style
-- ธีมการ์ตูนสายปั่น (PASULOL-style): สีจัดคอนทราสต์สูง ขอบดำหนา เงาดรอปชาโดว์ ตัวหนังสือเด้งดึ๋ง
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Style = {}

local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end

-- ฟอนต์หนา มน กวนๆ (ตัวอักษรไทยจะใช้ฟอนต์สำรองของ Roblox โดยอัตโนมัติ)
Style.Font = {
	Regular = font("FredokaOne", Enum.Font.GothamBold),
	Medium = font("FredokaOne", Enum.Font.GothamBold),
	Bold = font("LuckiestGuy", Enum.Font.GothamBlack),
	Heavy = font("Bangers", Enum.Font.GothamBlack),
}

-- พาเลตหลัก (คีย์เดิมคงไว้ให้โมดูลอื่นใช้ต่อได้ เปลี่ยนแค่ค่าสี)
Style.C = {
	Bg = Color3.fromRGB(40, 12, 80),        Panel = Color3.fromRGB(92, 40, 170),
	Panel2 = Color3.fromRGB(124, 64, 214),  Line = Color3.fromRGB(18, 10, 28),
	Felt = Color3.fromRGB(28, 170, 120),    FeltDark = Color3.fromRGB(14, 110, 80),
	Paper = Color3.fromRGB(255, 247, 214),  Ink = Color3.fromRGB(18, 10, 28),
	InkSoft = Color3.fromRGB(96, 70, 120),  Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(226, 210, 255), Accent = Color3.fromRGB(255, 236, 40),
	Good = Color3.fromRGB(96, 255, 110),    Bad = Color3.fromRGB(255, 60, 80),
	Info = Color3.fromRGB(50, 200, 255),
	Pink = Color3.fromRGB(255, 56, 170),    Violet = Color3.fromRGB(150, 70, 255),
	Teal = Color3.fromRGB(40, 240, 220),
	-- สีใหม่สำหรับธีมปั่น
	Lime = Color3.fromRGB(190, 255, 40),    Orange = Color3.fromRGB(255, 140, 20),
	Sky = Color3.fromRGB(80, 220, 255),     Hot = Color3.fromRGB(255, 40, 120),
	Shadow = Color3.fromRGB(18, 10, 28),    White = Color3.fromRGB(255, 255, 255),
}
Style.Rarity = {
	Common = Color3.fromRGB(190, 200, 215), Rare = Color3.fromRGB(50, 200, 255),
	Epic = Color3.fromRGB(190, 80, 255), Legend = Color3.fromRGB(255, 200, 20), Mystic = Color3.fromRGB(255, 70, 190),
}
Style.Tier = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }
Style.Element = {
	Sati = Color3.fromRGB(50, 200, 255), Biao = Color3.fromRGB(255, 70, 90),
	Muen = Color3.fromRGB(190, 110, 255), Gawa = Color3.fromRGB(255, 220, 0),
}
Style.Name = {
	Type = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" },
	Element = { Sati = "สติ", Biao = "เบียว", Muen = "มึน", Gawa = "กาว" },
	Rarity = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" },
	Keyword = { Rush = "ใจร้อน", Taunt = "ตัวบัง", Necro = "ขุดศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" },
}
Style.OUTLINE = 3 -- ความหนาเส้นขอบการ์ตูนมาตรฐาน
Style.SHADOW = 5  -- ระยะเงาดรอปชาโดว์

-- ===== พื้นฐาน =====
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
function Style.round() return Style.new("UICorner", { CornerRadius = UDim.new(1, 0) }) end
function Style.pad(px, py)
	local ux, uy = UDim.new(0, px), UDim.new(0, py or px)
	return Style.new("UIPadding", { PaddingTop = uy, PaddingBottom = uy, PaddingLeft = ux, PaddingRight = ux })
end
function Style.stroke(color, thickness, parent)
	return Style.new("UIStroke", {
		Color = color or Style.C.Ink, Thickness = thickness or Style.OUTLINE,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end
-- เส้นขอบการ์ตูนดำหนา
function Style.outline(parent, thickness) return Style.stroke(Style.C.Ink, thickness or Style.OUTLINE, parent) end
-- ขอบตัวอักษรดำ (ใช้กับ TextLabel ให้อ่านออกบนพื้นสีจัด)
function Style.textOutline(label, thickness)
	return Style.new("UIStroke", { Color = Style.C.Ink, Thickness = thickness or 2,
		LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
end
function Style.gradient(parent, c1, c2, rotation)
	return Style.new("UIGradient", {
		Color = ColorSequence.new(c1, c2), Rotation = rotation or 90, Parent = parent,
	})
end
function Style.list(p)
	return Style.new("UIListLayout", {
		FillDirection = p and p.Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, p and p.Gap or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment[p and p.HAlign or "Left"],
		VerticalAlignment = Enum.VerticalAlignment[p and p.VAlign or "Top"],
		Parent = p and p.Parent,
	})
end

-- ===== ทวีน / เสียง =====
local SPEED = 1
function Style.setSpeed(mult) SPEED = math.max(mult or 1, 0.1) end
function Style.tween(inst, time, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time / SPEED, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
function Style.sfx(name, pitch)
	local folder = SoundService:FindFirstChild("SFX")
	local sound = folder and folder:FindFirstChild(name)
	if not sound then return end
	local s = sound:Clone()
	s.PlaybackSpeed = pitch or (0.92 + math.random() * 0.16) -- สุ่มพิทช์นิดหน่อยให้กวนๆ ไม่ซ้ำ
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end

-- ===== อนิเมชั่นกวนๆ =====
local function scaleOf(gui)
	local s = gui:FindFirstChild("FxScale")
	if not s then s = Style.new("UIScale", { Name = "FxScale", Parent = gui }) end
	return s
end
-- เด้งดึ๋ง: โป่งแล้วหดกลับ (ใช้ตอนตัวเลข/ข้อความเปลี่ยน)
function Style.punch(gui, amount, time)
	local s = scaleOf(gui)
	s.Scale = 1 + (amount or 0.3)
	Style.tween(s, time or 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
end
-- สั่นส่ายซ้ายขวา
function Style.jiggle(gui, deg)
	deg = deg or 8
	task.spawn(function()
		for _, r in { -deg, deg, -deg * 0.6, deg * 0.6, -deg * 0.25, 0 } do
			if not gui.Parent then return end
			gui.Rotation = r
			task.wait(0.035)
		end
	end)
end
-- ย้วย: บีบแบนแล้วเด้งกลับ (เจลลี่)
function Style.jelly(gui, amount)
	local s = scaleOf(gui)
	s.Scale = 1 - (amount or 0.2)
	Style.tween(s, 0.6, { Scale = 1 }, Enum.EasingStyle.Elastic)
end
-- โยกไปมาเบาๆ ตลอดเวลา (ป้าย/สติ๊กเกอร์)
function Style.wobble(gui, deg, period)
	deg, period = deg or 3, period or 1.2
	local base = gui.Rotation
	task.spawn(function()
		local dir = 1
		while gui.Parent do
			Style.tween(gui, period, { Rotation = base + deg * dir }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			dir = -dir
			task.wait(period / SPEED)
		end
	end)
end
-- เต้นตุบๆ (ใช้กับปุ่มสำคัญ / ไฟเตือน)
function Style.pulse(gui, amount, period)
	local s = scaleOf(gui)
	task.spawn(function()
		while gui.Parent do
			Style.tween(s, (period or 0.6) / 2, { Scale = 1 + (amount or 0.06) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait((period or 0.6) / 2 / SPEED)
			Style.tween(s, (period or 0.6) / 2, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait((period or 0.6) / 2 / SPEED)
		end
	end)
end
-- ตั้งข้อความพร้อมเด้ง (ถ้าเปลี่ยนจริง)
function Style.setText(label, text, punch)
	text = tostring(text)
	if label.Text == text then return end
	label.Text = text
	if punch ~= false then Style.punch(label, 0.35, 0.4) end
end

-- ประกายกาชา: เพชรเล็กๆ กระเด็นออกจากกลาง
function Style.sparkle(parent, color, count, spread)
	count, spread = count or 12, spread or 0.6
	for _ = 1, count do
		local size = math.random(6, 14)
		local sp = Style.new("Frame", {
			BackgroundColor3 = color or Style.C.Accent, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
			Rotation = 45, ZIndex = (parent.ZIndex or 1) + 30, Parent = parent,
		}, { Style.corner(2) })
		Style.stroke(Style.C.Ink, 1.5, sp)
		local ang = math.random() * math.pi * 2
		local dist = (0.3 + math.random() * 0.7) * spread
		Style.tween(sp, 0.55 + math.random() * 0.3, {
			Position = UDim2.fromScale(0.5 + math.cos(ang) * dist, 0.5 + math.sin(ang) * dist),
			Rotation = 45 + math.random(-180, 180), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.9, function() sp:Destroy() end)
	end
end
-- ฝนสี่เหลี่ยม (คอนเฟตติ) ตกจากด้านบน
function Style.confetti(parent, count)
	local colors = { Style.C.Accent, Style.C.Pink, Style.C.Sky, Style.C.Lime, Style.C.Orange }
	for _ = 1, count or 30 do
		local x = math.random()
		local c = Style.new("Frame", {
			BackgroundColor3 = colors[math.random(#colors)], Position = UDim2.fromScale(x, -0.05),
			Size = UDim2.fromOffset(math.random(8, 16), math.random(8, 16)), Rotation = math.random(360),
			ZIndex = 60, Parent = parent,
		}, { Style.corner(2) })
		Style.stroke(Style.C.Ink, 1.5, c)
		Style.tween(c, 1.2 + math.random() * 1.2, {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.25, 1.1), Rotation = math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(2.6, function() c:Destroy() end)
	end
end
-- ไฟลุก: เปลวเล็กๆ ลอยขึ้นจากขอบล่างของ parent (ใช้กับนาฬิกาใกล้หมดเวลา)
function Style.ember(parent)
	local x = 0.1 + math.random() * 0.8
	local size = math.random(6, 12)
	local e = Style.new("Frame", {
		BackgroundColor3 = math.random() < 0.5 and Style.C.Orange or Style.C.Accent, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(x, 1.05), Size = UDim2.fromOffset(size, size * 1.6),
		ZIndex = (parent.ZIndex or 1) + 5, Parent = parent,
	}, { Style.round() })
	Style.tween(e, 0.5 + math.random() * 0.3, {
		Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, -0.5),
		Size = UDim2.fromOffset(2, 4), BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.9, function() e:Destroy() end)
end

-- ===== ข้อความ =====
function Style.text(p)
	local lbl = Style.new("TextLabel", {
		Name = p.Name or "Text", BackgroundTransparency = 1, Text = p.Text or "",
		Font = p.Font or Style.Font.Regular, TextColor3 = p.Color or Style.C.Text,
		TextScaled = true, TextWrapped = p.Wrap ~= false, Rotation = p.Rotation or 0,
		TextXAlignment = Enum.TextXAlignment[p.XAlign or "Left"],
		TextYAlignment = Enum.TextYAlignment[p.YAlign or "Center"],
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, ZIndex = p.ZIndex or 1,
		LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = p.Min or 6, Parent = lbl })
	if p.Outline then Style.textOutline(lbl, p.Outline == true and 2 or p.Outline) end
	return lbl
end
-- หัวเรื่องแบบตะโกน (ตัวใหญ่ ขอบดำ เอียงนิดๆ)
function Style.shout(p)
	p.Font = p.Font or Style.Font.Heavy
	p.Outline = p.Outline or 3
	p.XAlign = p.XAlign or "Center"
	p.Rotation = p.Rotation or -2
	return Style.text(p)
end

-- ===== ปุ่มการ์ตูน: ขอบดำหนา + เงาทึบ + เด้งตอนชี้ + ยุบตอนกด =====
-- โครงสร้าง: Button(โปร่ง) > Shadow, Body(สี+ขอบ) > Label
function Style.button(p)
	local base = p.Color or Style.C.Accent
	local radius = p.Radius or 12
	local btn = Style.new("TextButton", {
		Name = p.Name or "Button", AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Rotation = p.Rotation or 0, Parent = p.Parent,
	})
	local z = btn.ZIndex
	local sh = Style.SHADOW
	local shadow = Style.new("Frame", { Name = "Shadow", BackgroundColor3 = Style.C.Shadow,
		Position = UDim2.fromOffset(sh, sh), Size = UDim2.new(1, 0, 1, 0), ZIndex = z, Parent = btn }, { Style.corner(radius) })
	local body = Style.new("Frame", { Name = "Body", BackgroundColor3 = base, Size = UDim2.new(1, 0, 1, 0), ZIndex = z + 1, Parent = btn },
		{ Style.corner(radius), Style.pad(p.Pad or 6, 2) })
	Style.outline(body, p.Outline or Style.OUTLINE)
	-- ไฮไลต์มันวาวด้านบน (สไตล์สติ๊กเกอร์)
	Style.new("Frame", { Name = "Shine", BackgroundColor3 = Style.C.White, BackgroundTransparency = 0.72,
		Position = UDim2.new(0.06, 0, 0.1, 0), Size = UDim2.new(0.88, 0, 0.28, 0), ZIndex = z + 2, Parent = body }, { Style.corner(radius) })
	local label = Style.text({ Name = "Label", Text = p.Text or "", Font = p.Font or Style.Font.Bold,
		Color = p.TextColor or Style.C.Ink, Max = p.Max or 18, XAlign = "Center", ZIndex = z + 3, Parent = body,
		Outline = p.TextOutline })
	local scale = Style.new("UIScale", { Name = "FxScale", Parent = btn })

	local hovered, pressed = false, false
	local function paint()
		local c = btn:GetAttribute("Base") or base
		local disabled = btn:GetAttribute("Disabled")
		if disabled then
			body.BackgroundColor3 = c:Lerp(Color3.fromRGB(120, 120, 130), 0.7)
			label.TextTransparency = 0.4
			shadow.Visible = false
			body.Position = UDim2.fromOffset(sh, sh)
		else
			body.BackgroundColor3 = hovered and c:Lerp(Style.C.White, 0.15) or c
			label.TextTransparency = 0
			shadow.Visible = not pressed
			body.Position = pressed and UDim2.fromOffset(sh, sh) or UDim2.new()
		end
	end
	btn:SetAttribute("Base", base)
	btn.MouseEnter:Connect(function()
		hovered = true paint()
		if not btn:GetAttribute("Disabled") then
			Style.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
			Style.tween(btn, 0.12, { Rotation = (p.Rotation or 0) + (math.random() < 0.5 and -2 or 2) })
		end
	end)
	btn.MouseLeave:Connect(function()
		hovered, pressed = false, false paint()
		Style.tween(scale, 0.15, { Scale = 1 })
		Style.tween(btn, 0.15, { Rotation = p.Rotation or 0 })
	end)
	btn.MouseButton1Down:Connect(function() pressed = true paint() Style.tween(scale, 0.06, { Scale = 0.94 }) end)
	btn.MouseButton1Up:Connect(function() pressed = false paint() Style.tween(scale, 0.3, { Scale = hovered and 1.06 or 1 }, Enum.EasingStyle.Back) end)
	btn:GetAttributeChangedSignal("Disabled"):Connect(paint)
	btn:GetAttributeChangedSignal("Base"):Connect(paint)
	local last = 0
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then Style.jiggle(btn, 5) Style.sfx("Nope") return end
		local now = os.clock()
		if now - last < (p.Debounce or 0.25) then return end -- กันกดรัวฝั่งไคลเอนต์
		last = now
		Style.sfx(p.Sfx or "Click")
		if p.OnClick then p.OnClick(btn) end
	end)
	paint()
	return btn
end

function Style.setEnabled(btn, on) btn:SetAttribute("Disabled", not on) end
function Style.setBase(btn, color) btn:SetAttribute("Base", color) end
function Style.buttonLabel(btn)
	local body = btn:FindFirstChild("Body")
	return body and body:FindFirstChild("Label")
end
function Style.setButtonText(btn, text, color)
	local lbl = Style.buttonLabel(btn)
	if not lbl then return end
	Style.setText(lbl, text)
	if color then lbl.TextColor3 = color end
end

-- ===== กล่องการ์ตูน: พื้นสี + ขอบดำ + เงา (ใช้เป็นแผง/การ์ด/ป้าย) =====
-- คืน (wrapper, body): wrapper ใช้วางเลย์เอาต์ body ใช้ใส่ของ
function Style.box(p)
	local radius = p.Radius or 14
	local wrap = Style.new("Frame", { Name = p.Name or "Box", BackgroundTransparency = 1,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Rotation = p.Rotation or 0, Visible = p.Visible ~= false, Parent = p.Parent })
	local z = wrap.ZIndex
	local sh = p.Shadow or Style.SHADOW
	if sh > 0 then
		Style.new("Frame", { Name = "Shadow", BackgroundColor3 = Style.C.Shadow, Position = UDim2.fromOffset(sh, sh),
			Size = UDim2.new(1, 0, 1, 0), ZIndex = z, Parent = wrap }, { Style.corner(radius) })
	end
	local body = Style.new("Frame", { Name = "Body", BackgroundColor3 = p.Color or Style.C.Paper,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = z + 1, Active = p.Active, Parent = wrap }, { Style.corner(radius) })
	Style.outline(body, p.Outline or Style.OUTLINE)
	if p.Pad then Style.pad(p.Pad).Parent = body end
	return wrap, body
end

-- ป้ายสติ๊กเกอร์ (ตัวหนังสือบนพื้นสี เอียงนิดๆ)
function Style.sticker(p)
	local wrap, body = Style.box({ Name = p.Name or "Sticker", Color = p.Color or Style.C.Pink, Radius = p.Radius or 10,
		Position = p.Position, Size = p.Size, AnchorPoint = p.AnchorPoint, LayoutOrder = p.LayoutOrder,
		ZIndex = p.ZIndex, Rotation = p.Rotation or -3, Parent = p.Parent, Shadow = p.Shadow })
	local lbl = Style.text({ Text = p.Text or "", Font = p.Font or Style.Font.Heavy, Color = p.TextColor or Style.C.Ink,
		Max = p.Max or 20, XAlign = "Center", ZIndex = body.ZIndex + 1, Parent = body, Outline = p.TextOutline })
	Style.pad(6, 2).Parent = body
	return wrap, lbl
end

-- ===== หน้าจอ / สกรอลล์ =====
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
function Style.scroll(p)
	local f = Style.new("ScrollingFrame", {
		Name = p.Name or "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		ScrollBarThickness = 8, ScrollBarImageColor3 = Style.C.Accent, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	local layout = p.Layout
	if not layout then
		layout = Style.new("UIListLayout", { Padding = UDim.new(0, p.Gap or 8), SortOrder = Enum.SortOrder.LayoutOrder })
	end
	layout.Parent = f
	local function fit()
		f.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (p.Extra or 12))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	fit()
	return f, layout
end

function Style.fill(gui)
	pcall(function()
		local flex = Instance.new("UIFlexItem")
		flex.FlexMode = Enum.UIFlexMode.Fill
		flex.Parent = gui
	end)
end

-- แถบหัวเรื่องแบบสติ๊กเกอร์เอียง
function Style.header(parent, text, color, order)
	local wrap, lbl = Style.sticker({ Text = text, Color = color or Style.C.Pink, TextColor = Style.C.Ink, Max = 24,
		Size = UDim2.new(1, -12, 0, 42), LayoutOrder = order or 0, Rotation = -1.2, Parent = parent })
	wrap.Name = "Header"
	return wrap, lbl
end

-- แถบพลัง (HP / ความคืบหน้า) ขอบดำ มีไฮไลต์
function Style.bar(p)
	local wrap, body = Style.box({ Name = p.Name or "Bar", Color = p.Back or Style.C.Ink, Radius = p.Radius or 999,
		Position = p.Position, Size = p.Size, AnchorPoint = p.AnchorPoint, LayoutOrder = p.LayoutOrder,
		ZIndex = p.ZIndex, Parent = p.Parent, Shadow = p.Shadow or 3 })
	body.ClipsDescendants = true
	local fill = Style.new("Frame", { Name = "Fill", BackgroundColor3 = p.Color or Style.C.Good,
		Size = UDim2.fromScale(p.Value or 1, 1), ZIndex = body.ZIndex + 1, Parent = body }, { Style.corner(p.Radius or 999) })
	Style.new("Frame", { Name = "Shine", BackgroundColor3 = Style.C.White, BackgroundTransparency = 0.65,
		Position = UDim2.new(0.03, 0, 0.12, 0), Size = UDim2.new(0.94, 0, 0.3, 0), ZIndex = body.ZIndex + 2, Parent = fill }, { Style.round() })
	local label = Style.text({ Font = Style.Font.Bold, Max = p.Max or 16, XAlign = "Center", Color = Style.C.White,
		Outline = 2, ZIndex = body.ZIndex + 3, Parent = body })
	local api = { Root = wrap, Fill = fill, Label = label }
	function api:Set(v, text)
		v = math.clamp(v or 0, 0, 1)
		Style.tween(fill, 0.35, { Size = UDim2.fromScale(v, 1) }, Enum.EasingStyle.Back)
		if text ~= nil then Style.setText(label, text) end
	end
	return api
end

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

-- ===== Toast: ป้ายสติ๊กเกอร์เด้งลงมาจากบน ซ้อนกันสูงสุด 3 อัน =====
Style.toastParent = nil
local holder, seq, lastText, lastAt = nil, 0, nil, 0
local KIND = { info = Style.C.Sky, good = Style.C.Lime, bad = Style.C.Hot, gold = Style.C.Accent }
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
			Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0.46, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50, Parent = parent,
		}, {
			Style.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center }),
			Style.new("UISizeConstraint", { MaxSize = Vector2.new(520, 9999) }),
		})
	end
	local items = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #items >= 3 do table.remove(items, 1):Destroy() end
	seq += 1
	local wrap, lbl = Style.sticker({ Text = text, Color = KIND[kind or "info"] or KIND.info, Max = 18,
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = seq, ZIndex = 50, Parent = holder,
		Rotation = math.random(-25, 25) / 10, TextColor = kind == "bad" and Style.C.White or Style.C.Ink,
		TextOutline = kind == "bad" and 2 or nil })
	Style.punch(wrap, 0.25, 0.5)
	if kind == "bad" then Style.jiggle(lbl, 4) end
	Style.sfx(kind == "bad" and "Nope" or "Pop")
	task.delay(2.6, function()
		if not wrap.Parent then return end
		Style.tween(wrap:FindFirstChild("FxScale") or scaleOf(wrap), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.2)
		if wrap.Parent then wrap:Destroy() end
	end)
end

-- พื้นหลังลายจุดฮาล์ฟโทน (คอมิค) ให้แผงดูไม่โล่ง
function Style.dots(parent, color, step, size)
	step, size = step or 26, size or 5
	local layer = Style.new("Frame", { Name = "Dots", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = parent.ZIndex or 1, Parent = parent }, {
		Style.new("UIGridLayout", { CellSize = UDim2.fromOffset(size, size), CellPadding = UDim2.fromOffset(step - size, step - size) }),
	})
	layer.ClipsDescendants = true
	local function refill()
		for _, c in layer:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		local n = math.ceil(layer.AbsoluteSize.X / step + 1) * math.ceil(layer.AbsoluteSize.Y / step + 1)
		n = math.min(n, 600)
		for _ = 1, n do
			Style.new("Frame", { BackgroundColor3 = color or Style.C.Ink, BackgroundTransparency = 0.82, Parent = layer }, { Style.round() })
		end
	end
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(refill)
	task.defer(refill)
	return layer
end

return Style
