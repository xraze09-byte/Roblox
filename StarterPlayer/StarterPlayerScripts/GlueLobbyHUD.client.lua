--[[
	🏛️ GlueLobbyHUD — โปรไฟล์ • ดวลด่วน • เมนูลัด • ตั้งค่า
	วางที่: StarterPlayer ▸ StarterPlayerScripts (LocalScript)
	• ซ่อนตัวเองอัตโนมัติตอนนั่งโต๊ะดวล (Attribute "GlueInDuel")
	• สคริปต์อื่นลงทะเบียนเปิดหน้าต่างได้ เช่น
	    _G.GlueMenu = _G.GlueMenu or {}
	    _G.GlueMenu.deck = function() DeckBuilder.Open() end
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
do
	local old = playerGui:FindFirstChild("GlueLobbyHUD")
	if old then old:Destroy() end
end

---------------------------------------------------------------------
-- ⚙️ ค่าพื้นฐาน
---------------------------------------------------------------------
local DEFAULTS = { GlueBGM = 1, GlueSFX = 1, GlueShake = true, GlueRotate = true }
for k, v in pairs(DEFAULTS) do
	if player:GetAttribute(k) == nil then player:SetAttribute(k, v) end
end

local C = {
	panel = Color3.fromRGB(28, 24, 48),
	sub = Color3.fromRGB(195, 190, 225),
	gold = Color3.fromRGB(255, 210, 60),
	glue = Color3.fromRGB(255, 80, 200),
	on = Color3.fromRGB(80, 220, 120),
	off = Color3.fromRGB(70, 65, 95),
	dark = Color3.fromRGB(15, 12, 25),
	white = Color3.new(1, 1, 1),
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

local RANKS = {
	{ wins = 0, name = "มือใหม่หัดกาว 🐣", color = Color3.fromRGB(130, 135, 145) },
	{ wins = 3, name = "เด็กปั่นประจำซอย 🛵", color = Color3.fromRGB(45, 135, 255) },
	{ wins = 10, name = "เซียนกาวตราช้าง 🧪", color = Color3.fromRGB(255, 80, 200) },
	{ wins = 25, name = "จอมปั่นแห่งจักรวาล 🌀", color = Color3.fromRGB(255, 190, 40) },
	{ wins = 50, name = "เทพเจ้าแห่งความกาว 👑", rainbow = true },
}

local QUIPS = {
	"วันนี้กาวหรือยัง? 🧪", "หล่อสุดในเซิร์ฟ 😎", "ลุงกาวรออยู่ที่โต๊ะนะ 🤖",
	"อย่าจิ้มโปรไฟล์บ่อย เดี๋ยวช้ำ 😣", "ไปดวลได้แล้ว! 🃏", "แบตจะหมดแล้ว 🔋",
}

local MENU = {
	{ id = "deck", icon = "🗃️", text = "คลังการ์ด", color = Color3.fromRGB(70, 140, 255) },
	{ id = "shop", icon = "🛒", text = "ร้านค้า", color = Color3.fromRGB(255, 170, 40) },
	{ id = "quest", icon = "📜", text = "เควสต์", color = Color3.fromRGB(80, 200, 120) },
	{ id = "settings", icon = "⚙️", text = "ตั้งค่า", color = Color3.fromRGB(150, 110, 230) },
}

---------------------------------------------------------------------
-- 🧰 Helpers
---------------------------------------------------------------------
local function pick(t) return t[math.random(1, #t)] end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function make(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function corner(p, r) return make("UICorner", { CornerRadius = r or UDim.new(0, 12), Parent = p }) end

local function stroke(p, color, thick, transp)
	return make("UIStroke", { Color = color, Thickness = thick or 2, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end

local function label(props)
	local p = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.white, TextScaled = true, Text = "", BorderSizePixel = 0 }
	for k, v in pairs(props) do p[k] = v end
	return make("TextLabel", p)
end

local spinning = {}
local function rainbowOn(st, speed)
	local g = make("UIGradient", { Color = RAINBOW, Parent = st })
	table.insert(spinning, { g = g, speed = speed or 150 })
	return g
end

local function sfx(id, pitch, vol)
	local mul = player:GetAttribute("GlueSFX") or 1
	if mul <= 0 then return end
	local s = make("Sound", { SoundId = id, Volume = (vol or 0.4) * mul, PlaybackSpeed = pitch or 1, Parent = SoundService })
	s:Play()
	Debris:AddItem(s, 3)
end
local function click(p) sfx("rbxasset://sounds/clickfast.wav", p or 1, 0.4) end
local function hoverSfx() sfx("rbxasset://sounds/button.wav", 1.8, 0.12) end

local function punch(obj, amt)
	local sc = obj:FindFirstChild("Punch") or make("UIScale", { Name = "Punch", Parent = obj })
	sc.Scale = amt or 1.25
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

---------------------------------------------------------------------
-- 🖥️ Root + ย่อ/ขยายตามขนาดจอ
---------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "GlueLobbyHUD", ResetOnSpawn = false, IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = playerGui,
})

local scales = {}
local function autoScale(obj)
	local s = make("UIScale", { Parent = obj })
	table.insert(scales, s)
	return s
end
local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local k = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.65, 1.25)
	for _, s in ipairs(scales) do s.Scale = k end
end

---------------------------------------------------------------------
-- 🍞 Toast แจ้งเตือน
---------------------------------------------------------------------
local toastHolder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(460, 54), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
autoScale(toastHolder)
local toastToken = 0
local function toast(text, color)
	toastToken += 1
	local my = toastToken
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local f = make("Frame", { Position = UDim2.fromOffset(0, -90), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel, ZIndex = 50, Parent = toastHolder })
	corner(f, UDim.new(0.5, 0))
	stroke(f, color or C.glue, 2.5)
	label({ Text = text, Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.6), ZIndex = 51, Parent = f })
	tween(f, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if my ~= toastToken or not f.Parent then return end
		tween(f, 0.25, { Position = UDim2.fromOffset(0, -90) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Debris:AddItem(f, 0.3)
	end)
end

---------------------------------------------------------------------
-- 🧑 1) โปรไฟล์ (ซ้ายบน)
---------------------------------------------------------------------
local profile = make("TextButton", {
	Name = "Profile", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(-420, 12),
	Size = UDim2.fromOffset(320, 100), BackgroundColor3 = C.panel, BackgroundTransparency = 0.08, Parent = gui,
})
corner(profile, UDim.new(0, 20))
stroke(profile, C.glue, 2.5, 0.2)
make("UIGradient", { Color = ColorSequence.new(C.white, Color3.fromRGB(170, 160, 200)), Rotation = 90, Parent = profile })
autoScale(profile)

local avatar = make("ImageLabel", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = Color3.fromRGB(70, 180, 255), Image = "", ZIndex = 2, Parent = profile })
corner(avatar, UDim.new(1, 0))
rainbowOn(stroke(avatar, C.white, 3.5), 200)

local lvBadge = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(80, 80), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.gold, ZIndex = 3, Parent = profile })
corner(lvBadge, UDim.new(1, 0))
stroke(lvBadge, C.white, 2)
local lvText = label({ Text = "1", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(70, 35, 0), Position = UDim2.fromScale(0.15, 0.15), Size = UDim2.fromScale(0.7, 0.7), ZIndex = 4, Parent = lvBadge })

local nameL = label({ Text = player.DisplayName, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(102, 10), Size = UDim2.fromOffset(206, 28), Parent = profile })
make("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = nameL })

local rankPill = make("Frame", { Position = UDim2.fromOffset(102, 42), Size = UDim2.fromOffset(206, 24), BackgroundColor3 = C.white, Parent = profile })
corner(rankPill, UDim.new(0.5, 0))
local rankGrad = make("UIGradient", { Rotation = 90, Parent = rankPill })
local rankText = label({ Text = "", Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.9, 0.76), Parent = rankPill })
make("UIStroke", { Thickness = 1.2, Parent = rankText })

local xpBg = make("Frame", { Position = UDim2.fromOffset(102, 72), Size = UDim2.fromOffset(206, 18), BackgroundColor3 = C.dark, ClipsDescendants = true, Parent = profile })
corner(xpBg, UDim.new(0.5, 0))
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.white, Parent = xpBg })
corner(xpFill, UDim.new(0.5, 0))
make("UIGradient", { Color = ColorSequence.new(C.glue, Color3.fromRGB(140, 60, 255)), Parent = xpFill })
local xpText = label({ Text = "", Font = Enum.Font.FredokaOne, Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.8), ZIndex = 2, Parent = xpBg })
make("UIStroke", { Thickness = 1.2, Parent = xpText })

task.spawn(function()
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	if ok then avatar.Image = img end
end)

-- ✏️ ถ้า DataService มีเลเวลจริง ให้แทนสูตรนี้ด้วย Attribute จากเซิร์ฟเวอร์
local function computeLevel()
	local wins = player:GetAttribute("GlueWins") or 0
	local matches = player:GetAttribute("GlueMatches") or 0
	local xp = wins * 30 + matches * 10
	local lv, need = 1, 50
	while xp >= need do
		xp -= need
		lv += 1
		need = 50 + lv * 25
	end
	return lv, xp, need, wins
end

local function rankFor(wins)
	local r = RANKS[1]
	for _, x in ipairs(RANKS) do
		if wins >= x.wins then r = x end
	end
	return r
end

local rankRainbow, lastLevel = false, nil
local function refreshProfile()
	local lv, xp, need, wins = computeLevel()
	lvText.Text = tostring(lv)
	tween(xpFill, 0.5, { Size = UDim2.fromScale(xp / need, 1) }, Enum.EasingStyle.Quart)
	xpText.Text = string.format("XP %d/%d • ชนะ %d", xp, need, wins)
	local r = rankFor(wins)
	rankText.Text = r.name
	rankRainbow = r.rainbow == true
	rankGrad.Color = r.rainbow and RAINBOW or ColorSequence.new(r.color, r.color:Lerp(C.dark, 0.35))
	if not rankRainbow then rankGrad.Rotation = 90 end
	if lastLevel and lv > lastLevel then
		toast("🎉 เลเวลอัป! Lv." .. lv .. " ความกาวเพิ่มขึ้น!", C.gold)
		punch(lvBadge, 1.9)
		sfx("rbxasset://sounds/electronicpingshort.wav", 1.3, 0.5)
	end
	lastLevel = lv
end
player:GetAttributeChangedSignal("GlueWins"):Connect(refreshProfile)
player:GetAttributeChangedSignal("GlueMatches"):Connect(refreshProfile)
refreshProfile()

profile.MouseEnter:Connect(function() tween(avatar, 0.3, { Rotation = 10 }, Enum.EasingStyle.Back); hoverSfx() end)
profile.MouseLeave:Connect(function() tween(avatar, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back) end)
profile.Activated:Connect(function()
	click(1.4)
	punch(avatar, 0.7)
	toast(pick(QUIPS), Color3.fromRGB(70, 180, 255))
end)

---------------------------------------------------------------------
-- ⚡ 3) ปุ่มดวลด่วน (กลางล่าง)
---------------------------------------------------------------------
local quick = make("TextButton", {
	Name = "QuickPlay", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 220), Size = UDim2.fromOffset(280, 86), BackgroundTransparency = 1, Parent = gui,
})
autoScale(quick)
local qInner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, ClipsDescendants = true, Parent = quick })
corner(qInner, UDim.new(0.5, 0))
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 130, 60), Color3.fromRGB(230, 40, 140)), Rotation = 90, Parent = qInner })
rainbowOn(stroke(qInner, C.white, 5), 220)
local qScale = make("UIScale", { Parent = qInner })

local shine = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, ZIndex = 1, Parent = qInner })
corner(shine, UDim.new(0.5, 0))
local shineGrad = make("UIGradient", {
	Rotation = 20, Offset = Vector2.new(-1, 0),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = shine,
})
local qTitle = label({ Text = "⚡ ดวลด่วน!", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.5), ZIndex = 2, Parent = qInner })
make("UIStroke", { Thickness = 2, Parent = qTitle })
label({ Text = "สู้บอทลุงกาวทันที ไม่ต้องเดิน", TextColor3 = Color3.fromRGB(255, 235, 200), Position = UDim2.fromScale(0.1, 0.62), Size = UDim2.fromScale(0.8, 0.26), ZIndex = 2, Parent = qInner })

local qTarget, qHover, quickCD = 1, false, 0
quick.MouseEnter:Connect(function() qHover = true; qTarget = 1.08; hoverSfx() end)
quick.MouseLeave:Connect(function() qHover = false; qTarget = 1 end)
quick.MouseButton1Down:Connect(function() qTarget = 0.9 end)
quick.MouseButton1Up:Connect(function() qTarget = qHover and 1.08 or 1 end)
quick.Activated:Connect(function()
	qTarget = qHover and 1.08 or 1
	if os.clock() < quickCD then
		toast("⏳ ใจเย็นๆ ลุงกำลังจัดโต๊ะอยู่", C.sub)
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		toast("💀 ตายอยู่ ดวลไม่ได้นะ", C.sub)
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("GlueCardRemotes")
	local remote = folder and folder:FindFirstChild("QuickPlay")
	if not remote then
		toast("⚠️ เซิร์ฟเวอร์ยังไม่เปิดระบบดวลด่วน", C.glue)
		return
	end
	quickCD = os.clock() + 3
	click(1.2)
	qTitle.Text = "⏳ กำลังจัดโต๊ะ..."
	remote:FireServer()
	task.delay(3, function() qTitle.Text = "⚡ ดวลด่วน!" end)
end)

---------------------------------------------------------------------
-- 📋 6) เมนูลัด (ขวากลาง)
---------------------------------------------------------------------
local menu = make("Frame", {
	Name = "MenuBar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 220, 0.5, 0),
	Size = UDim2.fromOffset(96, #MENU * 86 + 14), BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, Parent = gui,
})
corner(menu, UDim.new(0, 20))
stroke(menu, Color3.fromRGB(60, 50, 100), 2, 0.2)
autoScale(menu)
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })

_G.GlueMenu = _G.GlueMenu or {}
local openSettings, closeSettings
local questDot

for i, m in ipairs(MENU) do
	local b = make("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(78, 80), BackgroundTransparency = 1, LayoutOrder = i, Parent = menu })
	local inner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = m.color, Parent = b })
	corner(inner, UDim.new(0, 16))
	stroke(inner, C.white, 2, 0.4)
	make("UIGradient", { Color = ColorSequence.new(C.white, Color3.fromRGB(150, 150, 170)), Rotation = 90, Parent = inner })
	local icon = label({ Text = m.icon, Position = UDim2.fromScale(0.2, 0.06), Size = UDim2.fromScale(0.6, 0.56), Parent = inner })
	local t = label({ Text = m.text, Position = UDim2.fromScale(0.04, 0.66), Size = UDim2.fromScale(0.92, 0.26), Parent = inner })
	make("UIStroke", { Thickness = 1.5, Parent = t })
	local sc = make("UIScale", { Parent = inner })

	if m.id == "quest" then
		questDot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(255, 50, 70), ZIndex = 3, Visible = false, Parent = inner })
		corner(questDot, UDim.new(1, 0))
		stroke(questDot, C.white, 2)
		label({ Text = "!", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.2, 0.15), Size = UDim2.fromScale(0.6, 0.7), ZIndex = 4, Parent = questDot })
	end

	b.MouseEnter:Connect(function()
		tween(sc, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back)
		tween(icon, 0.4, { Rotation = m.id == "settings" and 180 or 12 }, Enum.EasingStyle.Back)
		hoverSfx()
	end)
	b.MouseLeave:Connect(function()
		tween(sc, 0.15, { Scale = 1 })
		tween(icon, 0.3, { Rotation = 0 })
	end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.08, { Scale = 0.9 }) end)
	b.Activated:Connect(function()
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		click()
		if m.id == "settings" then
			openSettings()
		elseif type(_G.GlueMenu[m.id]) == "function" then
			local ok, err = pcall(_G.GlueMenu[m.id])
			if not ok then warn("[GlueHUD] เปิด " .. m.id .. " ไม่สำเร็จ:", err) end
		else
			punch(icon, 1.6)
			toast("🚧 " .. m.text .. " กำลังสร้าง... ลุงกาวยังโค้ดไม่เสร็จ 😅", C.gold)
		end
	end)
end

local function refreshQuestDot()
	if questDot then questDot.Visible = player:GetAttribute("GlueQuestReady") == true end
end
player:GetAttributeChangedSignal("GlueQuestReady"):Connect(refreshQuestDot)
refreshQuestDot()

---------------------------------------------------------------------
-- ⚙️ 29) หน้าต่างตั้งค่า
---------------------------------------------------------------------
local dim = make("TextButton", { Name = "SettingsDim", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 420), BackgroundTransparency = 1, ZIndex = 31, Parent = dim })
autoScale(holder)
local win = make("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel, ZIndex = 31, Parent = holder })
corner(win, UDim.new(0, 22))
rainbowOn(stroke(win, C.white, 4), 120)
local pop = make("UIScale", { Parent = win })

local titleL = label({ Text = "⚙️ ตั้งค่าความกาว", Font = Enum.Font.GothamBlack, TextColor3 = C.gold, Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(330, 34), Parent = win })
make("UIStroke", { Thickness = 2, Parent = titleL })
label({ Text = "ค่าจะรีเซ็ตเมื่อออกจากเกม", Font = Enum.Font.GothamMedium, TextColor3 = C.sub, Position = UDim2.fromOffset(24, 48), Size = UDim2.fromOffset(330, 18), Parent = win })

local closeBtn = make("TextButton", { Text = "✖", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C.white, AutoButtonColor = false, Position = UDim2.fromOffset(380, 14), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.fromRGB(220, 60, 90), Parent = win })
corner(closeBtn, UDim.new(1, 0))
stroke(closeBtn, C.white, 2)
make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), PaddingLeft = UDim.new(0.2, 0), PaddingRight = UDim.new(0.2, 0), Parent = closeBtn })
closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.3, { Rotation = 90 }, Enum.EasingStyle.Back) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back) end)

-- 🎚️ Slider
local activeSlider
local function makeSlider(y, title, attr)
	label({ Text = title, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(300, 26), Parent = win })
	local pct = label({ Text = "100%", Font = Enum.Font.FredokaOne, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(340, y), Size = UDim2.fromOffset(76, 26), Parent = win })
	local track = make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(24, y + 36), Size = UDim2.fromOffset(392, 14), BackgroundColor3 = C.dark, Parent = win })
	corner(track, UDim.new(0.5, 0))
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, Parent = track })
	corner(fill, UDim.new(0.5, 0))
	make("UIGradient", { Color = ColorSequence.new(C.glue, Color3.fromRGB(140, 60, 255)), Parent = fill })
	local knob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.white, ZIndex = 2, Parent = track })
	corner(knob, UDim.new(1, 0))
	stroke(knob, C.glue, 3)
	local kScale = make("UIScale", { Parent = knob })

	local function render()
		local v = player:GetAttribute(attr) or 1
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		pct.Text = math.floor(v * 100 + 0.5) .. "%"
		pct.Text = v <= 0 and "ปิด 🔇" or pct.Text
	end
	player:GetAttributeChangedSignal(attr):Connect(render)
	render()

	local function setFromX(x)
		local v = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
		v = math.clamp(math.floor(v * 20 + 0.5) / 20, 0, 1)
		if player:GetAttribute(attr) ~= v then player:SetAttribute(attr, v) end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSlider = { setFromX = setFromX, kScale = kScale, attr = attr }
			setFromX(input.Position.X)
			tween(kScale, 0.15, { Scale = 1.3 }, Enum.EasingStyle.Back)
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeSlider.setFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if activeSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		tween(activeSlider.kScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		if activeSlider.attr == "GlueSFX" then click(1.3) end -- ลองเสียงที่ระดับใหม่
		activeSlider = nil
	end
end)

-- 🔘 Toggle
local function demoShake()
	task.spawn(function()
		for i = 1, 8 do
			win.Position = UDim2.new(0.5, math.random(-8, 8), 0.5, math.random(-8, 8))
			task.wait(0.03)
		end
		win.Position = UDim2.fromScale(0.5, 0.5)
	end)
end
local function demoRotate()
	win.Rotation = 0
	tween(win, 0.6, { Rotation = 360 }, Enum.EasingStyle.Back)
	task.delay(0.65, function() win.Rotation = 0 end)
end

local function makeToggle(y, title, attr, demo)
	label({ Text = title, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, y + 4), Size = UDim2.fromOffset(300, 26), Parent = win })
	local sw = make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(346, y), Size = UDim2.fromOffset(70, 34), BackgroundColor3 = C.on, Parent = win })
	corner(sw, UDim.new(0.5, 0))
	stroke(sw, C.white, 2, 0.3)
	local knob = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -31, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.white, Parent = sw })
	corner(knob, UDim.new(1, 0))
	local function render()
		local on = player:GetAttribute(attr) ~= false
		tween(sw, 0.2, { BackgroundColor3 = on and C.on or C.off })
		tween(knob, 0.25, { Position = on and UDim2.new(1, -31, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
	end
	player:GetAttributeChangedSignal(attr):Connect(render)
	render()
	sw.Activated:Connect(function()
		local turnOn = player:GetAttribute(attr) == false
		player:SetAttribute(attr, turnOn)
		click(turnOn and 1.3 or 0.8)
		if turnOn and demo then demo() end
	end)
end

makeSlider(78, "🎵 เพลงพื้นหลัง", "GlueBGM")
makeSlider(148, "🔊 เสียงเอฟเฟกต์", "GlueSFX")
makeToggle(222, "📳 จอสั่นตอนโดนตี", "GlueShake", demoShake)
makeToggle(274, "🙃 หมุนจอ (ปิดถ้าเวียนหัว)", "GlueRotate", demoRotate)

local resetBtn = make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(110, 342), Size = UDim2.fromOffset(220, 50), BackgroundColor3 = C.white, Parent = win })
corner(resetBtn, UDim.new(0.5, 0))
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(90, 160, 255), Color3.fromRGB(60, 70, 200)), Rotation = 90, Parent = resetBtn })
local resetL = label({ Text = "🔁 ค่าเริ่มต้น", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.1, 0.2), Size = UDim2.fromScale(0.8, 0.6), Parent = resetBtn })
make("UIStroke", { Thickness = 1.5, Parent = resetL })
resetBtn.Activated:Connect(function()
	for k, v in pairs(DEFAULTS) do player:SetAttribute(k, v) end
	click(1.1)
	punch(resetBtn, 1.15)
	toast("✅ คืนค่าเริ่มต้นแล้ว", C.on)
end)

local settingsOpen = false
openSettings = function()
	if settingsOpen then return end
	settingsOpen = true
	dim.Visible = true
	dim.BackgroundTransparency = 1
	tween(dim, 0.25, { BackgroundTransparency = 0.45 })
	pop.Scale = 0
	win.Rotation = -10
	tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(win, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
	sfx("rbxasset://sounds/electronicpingshort.wav", 1.2, 0.3)
end
closeSettings = function()
	if not settingsOpen then return end
	settingsOpen = false
	activeSlider = nil
	tween(dim, 0.2, { BackgroundTransparency = 1 })
	tween(pop, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.22, function()
		if not settingsOpen then dim.Visible = false end
	end)
end
dim.Activated:Connect(closeSettings)
closeBtn.Activated:Connect(function() click(0.8); closeSettings() end)

---------------------------------------------------------------------
-- 🎬 Intro + ซ่อนตอนดวล
---------------------------------------------------------------------
local HOME = {
	{ obj = profile, home = UDim2.fromOffset(12, 12), away = UDim2.fromOffset(-420, 12) },
	{ obj = menu, home = UDim2.new(1, -12, 0.5, 0), away = UDim2.new(1, 220, 0.5, 0) },
	{ obj = quick, home = UDim2.new(0.5, 0, 1, -16), away = UDim2.new(0.5, 0, 1, 220) },
}
local function intro()
	for i, h in ipairs(HOME) do
		h.obj.Position = h.away
		task.delay((i - 1) * 0.1, function()
			tween(h.obj, 0.6, { Position = h.home }, Enum.EasingStyle.Back)
		end)
	end
end

local function syncDuel()
	local inDuel = player:GetAttribute("GlueInDuel") == true
	if inDuel then
		closeSettings()
		gui.Enabled = false
	elseif not gui.Enabled then
		gui.Enabled = true
		refreshProfile()
		intro()
	end
end
player:GetAttributeChangedSignal("GlueInDuel"):Connect(syncDuel)

---------------------------------------------------------------------
-- 🎞️ Render loop
---------------------------------------------------------------------
local clock, qCur = 0, 1
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	clock += dt
	for i = #spinning, 1, -1 do
		local s = spinning[i]
		if s.g.Parent == nil then
			table.remove(spinning, i)
		else
			s.g.Rotation = (s.g.Rotation + s.speed * dt) % 360
		end
	end
	if rankRainbow then rankGrad.Rotation = (rankGrad.Rotation + 120 * dt) % 360 end
	qCur += (qTarget - qCur) * math.min(1, dt * 14)
	qScale.Scale = qCur + math.sin(clock * 4) * 0.03
	local t = clock % 2.5
	shineGrad.Offset = Vector2.new(t < 0.8 and (-1 + t / 0.8 * 2) or 1, 0)
	if questDot and questDot.Visible then
		questDot.Position = UDim2.new(1, -6, 0, 6 - math.abs(math.sin(clock * 5)) * 8)
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

gui.Enabled = player:GetAttribute("GlueInDuel") ~= true
if gui.Enabled then intro() end
