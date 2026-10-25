-- ReplicatedStorage/Shared/UI/Style
-- ธีม "กาวระเบิด" (PASULOL-style): สีนีออนตัดกันแรง ขอบดำหนาแบบการ์ตูน เงาตกแบบคอมิกยุคเก่า
-- ตัวหนังสืออ้วน เอียงนิดๆ เด้งดึ๋งทุกครั้งที่เปลี่ยน ปุ่มยุบลงเงาเวลากด
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Settings = require(script.Parent:WaitForChild("Settings"))

local Style = {}

local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end

-- ตัวอักษรไทยจะใช้ฟอนต์สำรองของ Roblox อัตโนมัติ ส่วนตัวเลข/อังกฤษจะได้ฟอนต์การ์ตูน
Style.Font = {
	Regular = font("FredokaOne", Enum.Font.GothamBold),
	Medium = font("FredokaOne", Enum.Font.GothamBold),
	Bold = font("FredokaOne", Enum.Font.GothamBlack),
	Heavy = font("LuckiestGuy", font("FredokaOne", Enum.Font.GothamBlack)),
	Comic = font("Bangers", font("LuckiestGuy", Enum.Font.GothamBlack)),
}

-- ===== พาเลตต์ =====
-- คีย์เดิมยังอยู่ครบ (โค้ดเก่าใช้ได้ต่อ) แต่ค่าถูกเปลี่ยนเป็นสีจัดจ้านทั้งหมด
Style.C = {
	Bg = Color3.fromRGB(58, 16, 118),        -- องุ่นเข้ม (พื้นหลังหลัก)
	Panel = Color3.fromRGB(112, 44, 224),    -- ม่วงไฟฟ้า
	Panel2 = Color3.fromRGB(146, 86, 255),   -- ม่วงอ่อน
	Line = Color3.fromRGB(18, 10, 30),       -- เส้นขอบ = หมึกดำ
	Felt = Color3.fromRGB(0, 168, 196),      -- โต๊ะการ์ด ฟ้าสด
	FeltDark = Color3.fromRGB(0, 102, 150),
	Paper = Color3.fromRGB(255, 249, 222),
	Ink = Color3.fromRGB(18, 10, 30),
	InkSoft = Color3.fromRGB(86, 64, 112),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(255, 236, 140), -- เหลืองนวล (แทนเทาซีดๆ แบบเดิม)
	Accent = Color3.fromRGB(255, 228, 0),    -- เหลืองมะนาว
	Good = Color3.fromRGB(64, 240, 96),      -- เขียวสะท้อนแสง
	Bad = Color3.fromRGB(255, 48, 84),
	Info = Color3.fromRGB(0, 204, 255),      -- ฟ้าสด
	Pink = Color3.fromRGB(255, 44, 168),     -- ชมพูบานเย็น
	Violet = Color3.fromRGB(168, 80, 255),
	Teal = Color3.fromRGB(0, 236, 200),
	Orange = Color3.fromRGB(255, 132, 0),
	White = Color3.new(1, 1, 1),
}
Style.Rarity = {
	Common = Color3.fromRGB(205, 205, 222), Rare = Color3.fromRGB(0, 196, 255),
	Epic = Color3.fromRGB(196, 72, 255), Legend = Color3.fromRGB(255, 204, 0), Mystic = Color3.fromRGB(255, 44, 168),
}
-- เทียร์ 1 ถึงสูงสุด ใช้ทำป้ายบนการ์ด
Style.Tier = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }
Style.MaxTier = 5
Style.Element = {
	Sati = Color3.fromRGB(0, 184, 255), Biao = Color3.fromRGB(255, 60, 70),
	Muen = Color3.fromRGB(176, 90, 255), Gawa = Color3.fromRGB(255, 196, 0),
}
Style.Name = {
	Type = { Character = "ตัวละคร", Spell = "ความสามารถ", Weapon = "อาวุธ", Leader = "ผู้นำ" },
	Element = { Sati = "สติ", Biao = "เบียว", Muen = "มึน", Gawa = "กาว" },
	Rarity = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" },
	Keyword = { Rush = "บุก", Taunt = "ยั่วยุ", Necro = "ปลุกศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" },
}

local function isLight(c)
	return (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) > 0.55
end
Style.isLight = isLight

-- สีตัวหนังสือที่อ่านออกบนพื้นสีนั้นๆ
function Style.on(bg)
	return isLight(bg) and Style.C.Ink or Style.C.Text
end

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
function Style.pad(px)
	local u = UDim.new(0, px)
	return Style.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

-- ขอบการ์ตูน: หนาขั้นต่ำ 2 พิกเซล มุมมน
function Style.stroke(color, thickness, parent)
	return Style.new("UIStroke", {
		Color = color or Style.C.Ink, Thickness = math.max(thickness or 3, 2),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

-- ขอบรอบตัวหนังสือ (ทำให้ตัวขาว/เหลืองเด้งออกจากพื้นหลังสีจัด)
function Style.textStroke(label, thickness)
	local s = label:FindFirstChild("InkOutline")
	if not s then
		s = Style.new("UIStroke", { Name = "InkOutline", Color = Style.C.Ink,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	end
	s.Thickness = thickness or 2
	return s
end

function Style.text(p)
	local color = p.Color or Style.C.Text
	local lbl = Style.new("TextLabel", {
		Name = p.Name or "Text", BackgroundTransparency = 1, Text = p.Text or "",
		Font = p.Font or Style.Font.Regular, TextColor3 = color,
		TextScaled = true, TextWrapped = p.Wrap ~= false,
		TextXAlignment = Enum.TextXAlignment[p.XAlign or "Left"],
		TextYAlignment = Enum.TextYAlignment[p.YAlign or "Center"],
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, ZIndex = p.ZIndex or 1,
		Rotation = p.Tilt or 0, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = p.Min or 6, Parent = lbl })
	-- ตัวหนังสือสีอ่อนได้ขอบดำอัตโนมัติ (ส่ง Stroke = false เพื่อปิด)
	if p.Stroke == true or (p.Stroke ~= false and isLight(color)) then
		Style.textStroke(lbl, p.StrokeThickness or ((p.Max or 18) >= 22 and 2.5 or 1.6))
	end
	return lbl
end

-- ===== แอนิเมชัน =====
function Style.speed()
	return Settings.Get("AnimSpeed") or 1
end

function Style.effectsOn()
	return Settings.Get("Effects") ~= false
end

function Style.tween(inst, time, props, easing, direction)
	local t = TweenService:Create(inst, TweenInfo.new(time / Style.speed(),
		easing or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function Style.scaleOf(gui)
	local s = gui:FindFirstChild("PopScale")
	if not s then s = Style.new("UIScale", { Name = "PopScale", Parent = gui }) end
	return s
end

-- เด้งดึ๋ง: ขยายพรวดแล้วสปริงกลับ
function Style.pop(gui, amount)
	local s = Style.scaleOf(gui)
	s.Scale = 1 + (amount or 0.25)
	Style.tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
end

-- โผล่จากศูนย์แบบสปริง
function Style.popIn(gui, delayTime)
	local s = Style.scaleOf(gui)
	s.Scale = 0
	task.delay(delayTime or 0, function()
		if gui.Parent then Style.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back) end
	end)
end

-- ส่ายไปมาแบบเยลลี่
function Style.jiggle(gui, power)
	local base = gui:GetAttribute("BaseRot")
	if base == nil then
		base = gui.Rotation
		gui:SetAttribute("BaseRot", base)
	end
	power = power or 8
	task.spawn(function()
		for _, k in { 1, -0.8, 0.6, -0.4, 0.2, 0 } do
			if not gui.Parent then return end
			gui.Rotation = base + k * power
			task.wait(0.045 / Style.speed())
		end
	end)
end

-- เปลี่ยนตัวหนังสือแล้วเด้ง (เฉพาะตอนค่าเปลี่ยนจริง)
function Style.bounceText(label, text, amount)
	text = tostring(text)
	if label.Text == text then return end
	label.Text = text
	Style.pop(label, amount or 0.35)
end

-- วนเรียกฟังก์ชันทุกเฟรมจนกว่า gui จะถูกลบ  fn(gui, elapsed, dt)
function Style.animate(gui, fn)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		fn(gui, os.clock() - t0, dt)
	end)
	gui.Destroying:Connect(function() conn:Disconnect() end)
	return conn
end

-- หมุนวนต่อเนื่อง (องศา/วินาที)
function Style.spin(gui, degPerSec)
	return Style.animate(gui, function(g, _, dt)
		g.Rotation = (g.Rotation + degPerSec * dt * Style.speed()) % 360
	end)
end

-- พิมพ์ดีด: ใช้ MaxVisibleGraphemes เพื่อให้ตัวอักษรไทย (สระ/วรรณยุกต์) ไม่ขาด
function Style.typewriter(label, text, cps, onDone)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(text) or #text
	local token = (label:GetAttribute("TypeToken") or 0) + 1
	label:SetAttribute("TypeToken", token)
	task.spawn(function()
		local shown = 0
		while shown < total do
			if label:GetAttribute("TypeToken") ~= token or not label.Parent then return end
			shown += 1
			label.MaxVisibleGraphemes = shown
			if shown % 3 == 0 then Style.sfx("Blip") end
			task.wait(1 / ((cps or 40) * Style.speed()))
		end
		label.MaxVisibleGraphemes = -1
		if onDone then onDone() end
	end)
	return function()
		label:SetAttribute("TypeToken", token + 1)
		label.MaxVisibleGraphemes = -1
	end
end

-- ===== เสียงกวนๆ =====
-- ถ้ามี SoundService.SFX.<ชื่อ> จะใช้ไฟล์นั้น ไม่งั้นใช้เสียงพื้นฐานที่มากับ Roblox แล้วบิดพิตช์ให้ปั่นๆ
local FALLBACK_SFX = {
	Click = { "rbxasset://sounds/button.wav", 1.15 },
	Hover = { "rbxasset://sounds/clickfast.wav", 1.6 },
	Boing = { "rbxasset://sounds/electronicpingshort.wav", 0.55 },
	Swap = { "rbxasset://sounds/swoosh.wav", 1.4 },
	Blip = { "rbxasset://sounds/clickfast.wav", 2.2 },
	Tick = { "rbxasset://sounds/clickfast.wav", 1.2 },
	Reveal = { "rbxasset://sounds/electronicpingshort.wav", 1 },
	Jackpot = { "rbxasset://sounds/victory.wav", 1.2 },
	Fart = { "rbxasset://sounds/electronicpingshort.wav", 0.3 },
	Summon = { "rbxasset://sounds/swoosh.wav", 0.8 },
	Draw = { "rbxasset://sounds/swoosh.wav", 1.8 },
	Error = { "rbxasset://sounds/electronicpingshort.wav", 0.4 },
	Win = { "rbxasset://sounds/victory.wav", 1 },
}
local sfxCache = {}
function Style.sfx(name)
	local vol = Settings.Get("Sfx") or 1
	if vol <= 0 then return end
	local folder = SoundService:FindFirstChild("SFX")
	local custom = folder and folder:FindFirstChild(name)
	if custom and custom:IsA("Sound") then
		SoundService:PlayLocalSound(custom)
		return
	end
	local spec = FALLBACK_SFX[name]
	if not spec or not RunService:IsClient() then return end
	local s = sfxCache[name]
	if not s then
		s = Style.new("Sound", { Name = "GawaSFX_" .. name, SoundId = spec[1], Parent = SoundService })
		sfxCache[name] = s
	end
	s.Volume = 0.5 * vol
	s.PlaybackSpeed = spec[2] * (0.92 + math.random() * 0.16) -- พิตช์ไม่ซ้ำกันทุกครั้ง
	SoundService:PlayLocalSound(s)
end

-- ===== กล่องการ์ตูนมีเงาตก =====
-- คืน holder (ใช้จัดวาง/ใส่ใน layout) และ face (ใส่ของข้างใน)
function Style.panel(p)
	local depth = p.Depth or 5
	local radius = p.Radius or 12
	local z = p.ZIndex or 1
	local holder = Style.new("Frame", {
		Name = p.Name or "ComicPanel", BackgroundTransparency = 1,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		Rotation = p.Tilt or 0, ZIndex = z, Parent = p.Parent,
	})
	Style.new("Frame", { Name = "Shadow", BackgroundColor3 = Style.C.Ink, BackgroundTransparency = p.ShadowAlpha or 0,
		Position = UDim2.fromOffset(depth, depth), Size = UDim2.new(1, -depth, 1, -depth), ZIndex = z, Parent = holder },
		{ Style.corner(radius) })
	local face = Style.new("Frame", { Name = "Face", BackgroundColor3 = p.Color or Style.C.Panel,
		Size = UDim2.new(1, -depth, 1, -depth), ZIndex = z, ClipsDescendants = p.Clip == true, Parent = holder },
		{ Style.corner(radius) })
	Style.stroke(Style.C.Ink, p.Stroke or 3, face)
	if p.Pad then Style.pad(p.Pad).Parent = face end
	return holder, face
end

-- ===== ปุ่มการ์ตูน 3 มิติ =====
-- โครงสร้าง: TextButton (โปร่งใส รับอินพุต) > Shadow + Face > Label
-- btn.Text / btn.TextColor3 ยังตั้งได้ตามเดิม ระบบจะคัดลอกไปที่ Label ให้เอง
function Style.button(p)
	local base = p.Color or Style.C.Panel2
	local depth = p.Depth or 4
	local radius = p.Radius or 12
	local btn = Style.new("TextButton", {
		Name = p.Name or "Button", AutoButtonColor = false, Text = p.Text or "",
		Font = p.Font or Style.Font.Bold, TextColor3 = p.TextColor or Style.on(base),
		TextTransparency = 1, BackgroundTransparency = 1,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Parent = p.Parent,
	})
	local z = btn.ZIndex
	local shadow = Style.new("Frame", { Name = "Shadow", BackgroundColor3 = Style.C.Ink,
		Position = UDim2.fromOffset(0, depth), Size = UDim2.new(1, 0, 1, -depth), ZIndex = z, Parent = btn },
		{ Style.corner(radius) })
	local face = Style.new("Frame", { Name = "Face", BackgroundColor3 = base,
		Size = UDim2.new(1, 0, 1, -depth), ZIndex = z, Parent = btn }, { Style.corner(radius) })
	Style.stroke(Style.C.Ink, p.Stroke or 3, face)
	Style.stroke(Style.C.Ink, p.Stroke or 3, shadow)
	local shine = Style.new("Frame", { Name = "Shine", BackgroundColor3 = Style.C.White, BackgroundTransparency = 0.72,
		Position = UDim2.new(0, 5, 0, 3), Size = UDim2.new(1, -10, 0.34, 0), ZIndex = z, Parent = face },
		{ Style.corner(radius) })
	local label = Style.new("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = btn.Text,
		Font = btn.Font, TextColor3 = btn.TextColor3, TextScaled = true, TextWrapped = true,
		Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = face }, {
		Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = 6 }),
		Style.pad(p.Pad or 6),
	})
	local outline = Style.textStroke(label, (p.Max or 18) >= 22 and 2.5 or 1.8)
	local function syncText()
		label.Text = btn.Text
		label.TextColor3 = btn.TextColor3
		label.Font = btn.Font
		outline.Enabled = isLight(btn.TextColor3)
	end
	btn:GetPropertyChangedSignal("Text"):Connect(syncText)
	btn:GetPropertyChangedSignal("TextColor3"):Connect(syncText)
	btn:GetPropertyChangedSignal("Font"):Connect(syncText)
	syncText()

	local scale = Style.new("UIScale", { Name = "HoverScale", Parent = btn })
	local hovered, pressed = false, false
	local function paint()
		local c = btn:GetAttribute("Base") or base
		local off = btn:GetAttribute("Disabled")
		if off then
			face.BackgroundColor3 = c:Lerp(Color3.fromRGB(120, 110, 140), 0.7)
			label.TextTransparency = 0.4
			shine.Visible = false
		else
			face.BackgroundColor3 = hovered and c:Lerp(Style.C.White, 0.15) or c
			label.TextTransparency = 0
			shine.Visible = true
		end
		local sink = (pressed and not off) and math.floor(depth * 0.8) or 0
		face.Position = UDim2.fromOffset(0, sink)
	end
	btn:SetAttribute("Base", base)
	btn.MouseEnter:Connect(function()
		hovered = true
		paint()
		if not btn:GetAttribute("Disabled") then
			Style.tween(scale, 0.25, { Scale = 1.06 }, Enum.EasingStyle.Back)
			Style.tween(btn, 0.25, { Rotation = p.HoverTilt or -1.5 }, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseLeave:Connect(function()
		hovered, pressed = false, false
		paint()
		Style.tween(scale, 0.2, { Scale = 1 })
		Style.tween(btn, 0.2, { Rotation = 0 })
	end)
	btn.MouseButton1Down:Connect(function() pressed = true paint() end)
	btn.MouseButton1Up:Connect(function() pressed = false paint() end)
	btn:GetAttributeChangedSignal("Disabled"):Connect(paint)
	btn:GetAttributeChangedSignal("Base"):Connect(paint)
	local last = 0
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			Style.jiggle(btn, 6)
			Style.sfx("Error")
			return
		end
		local now = os.clock()
		if now - last < (p.Debounce or 0.25) then return end -- กันกดรัวฝั่งไคลเอนต์
		last = now
		pressed = false
		paint()
		Style.pop(face, 0.12)
		Style.sfx(p.Sfx or "Click")
		if p.OnClick then p.OnClick(btn) end
	end)
	paint()
	return btn
end

function Style.setEnabled(btn, on) btn:SetAttribute("Disabled", not on) end
function Style.setBase(btn, color) btn:SetAttribute("Base", color) end

-- ป้ายสติกเกอร์เอียงๆ (เช่น ป้ายเทียร์ NEW! HOT!)
function Style.sticker(p)
	local color = p.Color or Style.C.Accent
	local tag = Style.new("Frame", { Name = p.Name or "Sticker", BackgroundColor3 = color,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromOffset(60, 24),
		AnchorPoint = p.AnchorPoint or Vector2.new(0.5, 0.5), Rotation = p.Tilt or -6,
		ZIndex = p.ZIndex or 3, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent }, { Style.corner(p.Radius or 6) })
	Style.stroke(Style.C.Ink, p.Stroke or 2.5, tag)
	local lbl = Style.text({ Name = "Label", Font = p.Font or Style.Font.Heavy, Text = p.Text or "",
		Color = p.TextColor or Style.on(color), Max = p.Max or 16, XAlign = "Center",
		Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.88, 0.9), ZIndex = (p.ZIndex or 3) + 1, Parent = tag })
	return tag, lbl
end

-- ===== เอฟเฟกต์ =====
-- ประกายดาว 4 แฉกวิบวับ (แสงกาชา) วนจนกว่า parent จะถูกลบ
function Style.sparkles(parent, color, count, z)
	if not Style.effectsOn() then return end
	color = color or Style.C.White
	for i = 1, count or 5 do
		local size = math.random(10, 18)
		local star = Style.new("Frame", { Name = "Sparkle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.random(), math.random()), Size = UDim2.fromOffset(size, size),
			ZIndex = z or 8, Parent = parent })
		for _, rot in { 0, 90 } do
			Style.new("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rot,
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.22, 0, 1, 0), ZIndex = z or 8, Parent = star },
				{ Style.round() })
		end
		local phase = i * 1.37
		local scale = Style.new("UIScale", { Parent = star })
		Style.animate(star, function(g, t)
			local k = math.sin((t * 2.4 + phase) * Style.speed())
			scale.Scale = math.max(0, k)
			g.Rotation = t * 90
			if k < -0.95 then g.Position = UDim2.fromScale(math.random(), math.random()) end
		end)
	end
end

-- ปาคอนเฟตติระเบิดออกจากกลาง (ครั้งเดียว)
function Style.burst(parent, colors, count, z)
	if not Style.effectsOn() then return end
	colors = colors or { Style.C.Accent, Style.C.Pink, Style.C.Info, Style.C.Good }
	for _ = 1, count or 18 do
		local bit = Style.new("Frame", { BackgroundColor3 = colors[math.random(#colors)], AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.random(8, 14), math.random(8, 14)),
			Rotation = math.random(0, 360), ZIndex = z or 40, Parent = parent })
		Style.stroke(Style.C.Ink, 2, bit)
		local a = math.random() * math.pi * 2
		local d = 0.25 + math.random() * 0.35
		Style.tween(bit, 0.7 + math.random() * 0.4, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d),
			Rotation = bit.Rotation + math.random(-540, 540), BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quart)
		task.delay(1.2, function() bit:Destroy() end)
	end
end

-- แสงแฉกหมุนเป็นวง (พื้นหลังสไตล์การ์ตูนญี่ปุ่น/มีม)
function Style.sunburst(parent, color, rays, alpha, z)
	local holder = Style.new("Frame", { Name = "Sunburst", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.4, 2.4), ZIndex = z or 1, Parent = parent },
		{ Style.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }) })
	rays = rays or 12
	for i = 1, rays do
		local ray = Style.new("Frame", { BackgroundColor3 = color or Style.C.White, BackgroundTransparency = alpha or 0.85,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0.08, 0), Rotation = (180 / rays) * i, ZIndex = z or 1, Parent = holder })
		-- แฉกจางตรงกลาง เข้มที่ปลาย
		Style.new("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.4),
			NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.55, 0.4), NumberSequenceKeypoint.new(1, 0),
		}), Parent = ray })
	end
	if Style.effectsOn() then Style.spin(holder, 6) end
	return holder
end

-- ลายจุดฮาล์ฟโทนแบบหนังสือการ์ตูน (ใช้ UIGridLayout ไม่ต้องมีภาพ)
function Style.halftone(parent, color, alpha, cell, z)
	local grid = Style.new("Frame", { Name = "Halftone", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, ZIndex = z or 1, Parent = parent }, {
		Style.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell or 10, cell or 10),
			CellPadding = UDim2.fromOffset(cell or 10, cell or 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _ = 1, 180 do
		Style.new("Frame", { BackgroundColor3 = color or Style.C.Ink, BackgroundTransparency = alpha or 0.85,
			ZIndex = z or 1, Parent = grid }, { Style.round() })
	end
	return grid
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
		ScrollBarThickness = 8, ScrollBarImageColor3 = Style.C.Accent, CanvasSize = UDim2.new(),
		ScrollingDirection = p.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	local layout = p.Layout
	if not layout then
		layout = Style.new("UIListLayout", { Padding = UDim.new(0, p.Gap or 8), SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = p.Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical })
	end
	layout.Parent = f
	local function fit()
		local s = layout.AbsoluteContentSize
		if p.Horizontal then
			f.CanvasSize = UDim2.fromOffset(s.X + (p.Extra or 8), 0)
		else
			f.CanvasSize = UDim2.fromOffset(0, s.Y + (p.Extra or 8))
		end
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

-- แถบหัวเรื่องแบบป้ายการ์ตูน: เงาตก + ตัวหนังสือเอียง + ดาวประดับ
function Style.header(parent, text, color, order)
	color = color or Style.C.Violet
	local holder, face = Style.panel({ Name = "Header", Color = color, Depth = 4, Radius = 10,
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order or 0, Parent = parent })
	Style.text({ Font = Style.Font.Heavy, Text = text, Color = Style.on(color),
		Max = 22, Tilt = -1.5, Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -60, 1, -4), Parent = face })
	local star = Style.new("Frame", { BackgroundColor3 = Style.C.Accent, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(18, 18), Rotation = 45, ZIndex = 2, Parent = face },
		{ Style.corner(3) })
	Style.stroke(Style.C.Ink, 2, star)
	if Style.effectsOn() then Style.spin(star, 60) end
	return holder, face
end

-- Toast: ฟองคำพูดการ์ตูน ซ้อนกันเป็นแถว ไม่ทับกัน สูงสุด 3 อัน
Style.toastParent = nil
local holder, seq, lastText, lastAt = nil, 0, nil, 0
local KIND = { info = Style.C.Panel2, good = Style.C.Good, bad = Style.C.Bad }
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
	local box, face = Style.panel({ Name = "Toast", Color = color, Depth = 4, Radius = 14,
		Size = UDim2.new(1, 0, 0, 40), ZIndex = 50, Parent = holder })
	box.LayoutOrder = seq
	Style.text({ Font = Style.Font.Bold, Text = text, Max = 17, XAlign = "Center", Color = Style.on(color),
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 51, Parent = face })
	Style.popIn(box)
	Style.jiggle(box, kind == "bad" and 5 or 2)
	if kind == "bad" then Style.sfx("Error") end
	task.delay(2.6, function() if box.Parent then box:Destroy() end end)
end

return Style
