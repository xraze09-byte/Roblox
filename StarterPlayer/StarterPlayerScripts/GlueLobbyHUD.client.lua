--[[
	🏛️ GlueLobbyHUD — สุดยอด HUD รวมระบบครบวงจร
	• ล็อบบี้สไตล์กาวสุดสวย: ขอบรุ้งหมุนได้, เลเวล, แถบ XP, ฉายา, คำคมกวนๆ
	• โปรไฟล์ 3D (ProfilePanel) กดดูของตัวเอง หรือ แตะตัวผู้เล่นอื่นในแมพ (PlayerTap)
	• แผงเลือกโหมดดวล (PlayPanel): บอท 5 ระดับ (Easy, Medium, Hard, Hacker, Mix) + โหมด Tower + PvP 1v1
	• ปุ่มดวลด่วน (QuickPlay): 1-Click ลงโต๊ะสู้บอททันที
	• คลังจัดเด็ค (DeckBuilder), ร้านค้า/ฟาร์ม, เควสต์ประจำวัน
	• หน้าต่างตั้งค่าสีรุ้ง: เสียง BGM, SFX, จอสั่น, หมุนจอ
	• สลับหน้าจออัตโนมัติเมื่อเริ่ม/จบการดวล (GlueInDuel)
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
-- 📦 โมดูลระบบ (โหลดแบบปลอดภัย Failsafe)
---------------------------------------------------------------------
local UIClient = script.Parent:FindFirstChild("UIClient")
local function tryReq(name)
	local m = UIClient and UIClient:FindFirstChild(name)
	if not m then return nil end
	local ok, res = pcall(require, m)
	if ok then return res end
	warn("[GlueHUD] โหลด " .. name .. " ไม่สำเร็จ:", res)
	return nil
end

local ProfilePanel = tryReq("ProfilePanel")
local PlayPanel = tryReq("PlayPanel")
local PlayerTap = tryReq("PlayerTap")
local DeckBuilder = tryReq("DeckBuilder")
local MenuKit = tryReq("MenuKit")
local Net = tryReq("Net")
local MatchUI = tryReq("MatchUI")
local TableCamera = tryReq("TableCamera")

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
	blue = Color3.fromRGB(70, 140, 255),
	purple = Color3.fromRGB(150, 90, 255),
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
	"เปิดโปรไฟล์ 3D ให้ดูแล้วนะ ✨",
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
	task.delay(2.5, function()
		if my ~= toastToken or not f.Parent then return end
		tween(f, 0.25, { Position = UDim2.fromOffset(0, -90) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Debris:AddItem(f, 0.3)
	end)
end

---------------------------------------------------------------------
-- 🧑 1) โปรไฟล์ (ซ้ายบน) + เชื่อมต่อ ProfilePanel
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

local function openMyProfile(fromPoint)
	if ProfilePanel and ProfilePanel.Open then
		ProfilePanel.Open(player.UserId, { From = fromPoint })
	else
		toast(pick(QUIPS), Color3.fromRGB(70, 180, 255))
	end
end

profile.MouseEnter:Connect(function() tween(avatar, 0.3, { Rotation = 10 }, Enum.EasingStyle.Back); hoverSfx() end)
profile.MouseLeave:Connect(function() tween(avatar, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back) end)
profile.Activated:Connect(function()
	click(1.4)
	punch(avatar, 0.7)
	toast(pick(QUIPS), Color3.fromRGB(70, 180, 255))
	task.delay(0.2, function()
		openMyProfile(Vector2.new(160, 60))
	end)
end)

---------------------------------------------------------------------
-- 👁️ ระบบแตะผู้เล่นในฉาก 3D (PlayerTap) -> เปิด ProfilePanel
---------------------------------------------------------------------
if PlayerTap and ProfilePanel then
	task.spawn(function()
		pcall(function()
			PlayerTap.Init(function(userId, screenPoint)
				ProfilePanel.Open(userId, { From = screenPoint })
			end)
		end)
	end)
end

---------------------------------------------------------------------
-- ⚔️ 3) ด็อกปุ่มดวล (กลางล่าง): ดวลด่วน + เลือกโหมด
---------------------------------------------------------------------
local battleDock = make("Frame", {
	Name = "BattleDock", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 220), Size = UDim2.fromOffset(450, 86),
	BackgroundTransparency = 1, Parent = gui,
})
autoScale(battleDock)

-- 3.1 ปุ่มดวลด่วน (QuickPlay)
local quick = make("TextButton", {
	Name = "QuickPlay", Text = "", AutoButtonColor = false,
	Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(240, 86),
	BackgroundTransparency = 1, Parent = battleDock,
})
local qInner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, ClipsDescendants = true, Parent = quick })
corner(qInner, UDim.new(0.5, 0))
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 130, 60), Color3.fromRGB(230, 40, 140)), Rotation = 90, Parent = qInner })
rainbowOn(stroke(qInner, C.white, 4), 220)
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
label({ Text = "สู้บอททันที ไม่ต้องรอ", TextColor3 = Color3.fromRGB(255, 235, 200), Position = UDim2.fromScale(0.1, 0.62), Size = UDim2.fromScale(0.8, 0.26), ZIndex = 2, Parent = qInner })

local qTarget, qHover, quickCD = 1, false, 0
quick.MouseEnter:Connect(function() qHover = true; qTarget = 1.06; hoverSfx() end)
quick.MouseLeave:Connect(function() qHover = false; qTarget = 1 end)
quick.MouseButton1Down:Connect(function() qTarget = 0.9 end)
quick.MouseButton1Up:Connect(function() qTarget = qHover and 1.06 or 1 end)

quick.Activated:Connect(function()
	qTarget = qHover and 1.06 or 1
	if os.clock() < quickCD then
		toast("⏳ ใจเย็นๆ กำลังจัดโต๊ะอยู่", C.sub)
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		toast("💀 ตัวละครยังไม่พร้อม", C.sub)
		return
	end
	
	-- ลอง QuickPlay ผ่าน GlueCardRemotes
	local folder = ReplicatedStorage:FindFirstChild("GlueCardRemotes")
	local remote = folder and folder:FindFirstChild("QuickPlay")
	if remote then
		quickCD = os.clock() + 3
		click(1.2)
		qTitle.Text = "⏳ กำลังจัดโต๊ะ..."
		remote:FireServer()
		task.delay(3, function() qTitle.Text = "⚡ ดวลด่วน!" end)
		return
	end
	
	-- Fallback: ลองเริ่มผ่าน GameServer Queue
	if Net then
		quickCD = os.clock() + 3
		click(1.2)
		qTitle.Text = "⏳ เริ่มบอท..."
		local ok, status = Net.invokeLocked("queue", "Queue", "Bot", 1)
		if ok then
			toast("⚔️ กำลังเริ่มดวลกับบอท!", C.gold)
		else
			toast("⚠️ ข้อผิดพลาด: " .. tostring(status), C.glue)
		end
		task.delay(3, function() qTitle.Text = "⚡ ดวลด่วน!" end)
		return
	end

	toast("⚠️ เซิร์ฟเวอร์ยังไม่เปิดระบบ", C.glue)
end)

-- 3.2 ปุ่มเลือกโหมด (PlayPanel)
local modeBtn = make("TextButton", {
	Name = "ModeSelect", Text = "", AutoButtonColor = false,
	Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(200, 86),
	BackgroundTransparency = 1, Parent = battleDock,
})
local mInner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, ClipsDescendants = true, Parent = modeBtn })
corner(mInner, UDim.new(0.5, 0))
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(60, 110, 255), Color3.fromRGB(150, 60, 240)), Rotation = 90, Parent = mInner })
rainbowOn(stroke(mInner, C.white, 3.5), 180)
local mScale = make("UIScale", { Parent = mInner })

local mTitle = label({ Text = "⚔️ เลือกโหมด", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.5), ZIndex = 2, Parent = mInner })
make("UIStroke", { Thickness = 2, Parent = mTitle })
label({ Text = "บอท 5 ระดับ • PvP 1v1", TextColor3 = Color3.fromRGB(225, 230, 255), Position = UDim2.fromScale(0.06, 0.62), Size = UDim2.fromScale(0.88, 0.26), ZIndex = 2, Parent = mInner })

local mTarget, mHover = 1, false
modeBtn.MouseEnter:Connect(function() mHover = true; mTarget = 1.06; hoverSfx() end)
modeBtn.MouseLeave:Connect(function() mHover = false; mTarget = 1 end)
modeBtn.MouseButton1Down:Connect(function() mTarget = 0.9 end)
modeBtn.MouseButton1Up:Connect(function() mTarget = mHover and 1.06 or 1 end)

-- Adapter เชื่อมต่อ PlayPanel
local Decks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Decks"))
local leaderIndex = 1
local queueMode = nil

local function leaderId()
	local l = Decks.Leaders and Decks.Leaders[leaderIndex]
	return l and l.Id or 1
end

local function leaderName()
	local l = Decks.Leaders and Decks.Leaders[leaderIndex]
	return l and l.Name or "หัวหน้า"
end

local function startMode(mode)
	if player:GetAttribute("GlueInDuel") == true then return end
	if MenuKit and MenuKit.close then MenuKit.close() end
	
	if Net then
		local lid = leaderId()
		local ok, status = Net.invokeLocked("queue", "Queue", mode, lid)
		if not ok then
			toast("❌ " .. tostring(status), C.glue)
			return
		end
		if mode == "PvP" then
			queueMode = "PvP"
			toast("🔍 กำลังค้นหาคู่ต่อสู้ 1v1...", Color3.fromRGB(70, 180, 255))
		else
			queueMode = nil
			toast("⚔️ กำลังเริ่มดวล (" .. tostring(mode) .. ")", C.gold)
		end
	else
		toast("⚠️ ไม่พบ Net Remote", C.glue)
	end
end

local function togglePvP()
	if queueMode == "PvP" then
		if MenuKit and MenuKit.close then MenuKit.close() end
		if Net then
			local ok = Net.invokeLocked("queue", "Queue", "Cancel")
			if ok then
				queueMode = nil
				toast("ยกเลิกการหาคู่ต่อสู้แล้ว", C.sub)
			end
		end
	else
		startMode("PvP")
	end
end

local playApi = {
	StartMode = startMode,
	TogglePvP = togglePvP,
	IsQueuing = function() return queueMode == "PvP" end,
	LeaderName = leaderName,
	NextLeader = function()
		local n = #(Decks.Leaders or {})
		if n > 0 then leaderIndex = ((leaderIndex or 1) % n) + 1 end
	end,
	TowerFloor = function()
		return player:GetAttribute("TowerFloor") or 1
	end,
}

modeBtn.Activated:Connect(function()
	click()
	mTarget = mHover and 1.06 or 1
	if PlayPanel and PlayPanel.Open then
		PlayPanel.Open(playApi)
	else
		toast("🚧 หน้าต่างเลือกโหมดกำลังโหลด...", C.gold)
	end
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

-- เชื่อมต่อระบบให้กับ _G.GlueMenu
_G.GlueMenu.deck = function()
	if DeckBuilder and DeckBuilder.Open then
		local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))
		local profileData = Net and Net.invoke("GetProfile")
		DeckBuilder.Open(gui, {
			Cards = CardData,
			Owned = (profileData and profileData.Collection) or {},
			Deck = (profileData and profileData.Deck) or {},
			OnSave = function(ids)
				if Net then return Net.invoke("SaveDeck", ids) end
				return true
			end,
		})
	else
		toast("🗃️ คลังการ์ดกำลังโหลด...", C.sub)
	end
end

_G.GlueMenu.play = function()
	if PlayPanel and PlayPanel.Open then
		PlayPanel.Open(playApi)
	end
end

_G.GlueMenu.profile = function()
	openMyProfile(Vector2.new(160, 60))
end

_G.GlueMenu.shop = function()
	local FarmUI = tryReq("FarmUI")
	if FarmUI and FarmUI.Open then
		FarmUI.Open(gui)
	else
		toast("🛒 ร้านค้า: เตรียมเปิดให้บริการเร็วๆ นี้!", C.gold)
	end
end

_G.GlueMenu.quest = function()
	local profileData = Net and Net.invoke("GetProfile")
	local quests = profileData and profileData.Quests
	if quests and #quests > 0 then
		local q = quests[1]
		toast("📜 เควสต์: " .. tostring(q.Text or q.Id) .. (" (%d/%d)"):format(q.Progress or 0, q.Goal or 1), C.on)
	else
		toast("📜 เควสต์ประจำวัน: ชนะการดวลเพื่อรับเหรียญรางวัล!", C.on)
	end
end

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
			toast("🚧 " .. m.text .. " กำลังโหลด...", C.gold)
		end
	end)
end

local function refreshQuestDot()
	if questDot then questDot.Visible = player:GetAttribute("GlueQuestReady") == true end
end
player:GetAttributeChangedSignal("GlueQuestReady"):Connect(refreshQuestDot)
refreshQuestDot()

---------------------------------------------------------------------
-- ⚙️ 29) หน้าต่างตั้งค่าสีรุ้ง
---------------------------------------------------------------------
local dim = make("TextButton", { Name = "SettingsDim", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 420), BackgroundTransparency = 1, ZIndex = 31, Parent = dim })
autoScale(holder)
local win = make("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel, ZIndex = 31, Parent = holder })
corner(win, UDim.new(0, 22))
rainbowOn(stroke(win, C.white, 4), 120)
local pop = make("UIScale", { Parent = win })

local titleL = label({ Text = "⚙️ ตั้งค่าความกาว", Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(24, 16), Size = UDim2.fromOffset(300, 32), TextXAlignment = Enum.TextXAlignment.Left, Parent = win })
make("UIStroke", { Thickness = 1.5, Parent = titleL })
local closeBtn = make("TextButton", { Text = "✕", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C.white, AutoButtonColor = false, Position = UDim2.new(1, -48, 0, 16), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(230, 60, 80), Parent = win })
corner(closeBtn, UDim.new(1, 0))

local function makeToggle(y, text, attr, onToggle)
	local row = make("Frame", { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(392, 44), BackgroundTransparency = 1, Parent = win })
	label({ Text = text, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(0.75, 0.7), Parent = row })
	local tBtn = make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.new(1, -64, 0.5, -16), Size = UDim2.fromOffset(64, 32), BackgroundColor3 = C.off, Parent = row })
	corner(tBtn, UDim.new(1, 0))
	local knob = make("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.white, Parent = tBtn })
	corner(knob, UDim.new(1, 0))
	local function sync()
		local val = player:GetAttribute(attr) ~= false
		tween(tBtn, 0.25, { BackgroundColor3 = val and C.on or C.off })
		tween(knob, 0.25, { Position = val and UDim2.fromOffset(36, 4) or UDim2.fromOffset(4, 4) }, Enum.EasingStyle.Back)
	end
	tBtn.Activated:Connect(function()
		local val = player:GetAttribute(attr) ~= false
		player:SetAttribute(attr, not val)
		click(val and 0.9 or 1.2)
		punch(tBtn, 1.2)
		sync()
		if onToggle then onToggle(not val) end
	end)
	sync()
end

local function demoShake()
	local cam = workspace.CurrentCamera
	if not cam then return end
	task.spawn(function()
		for _ = 1, 8 do
			cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(math.random(-3, 3)))
			RunService.RenderStepped:Wait()
		end
	end)
end

local function demoRotate()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local orig = cam.CFrame
	tween(cam, 0.2, { CFrame = orig * CFrame.Angles(0, 0, math.rad(12)) }, Enum.EasingStyle.Back)
	task.delay(0.22, function() tween(cam, 0.3, { CFrame = orig }, Enum.EasingStyle.Back) end)
end

local activeSlider = nil
local function makeSlider(y, text, attr)
	local row = make("Frame", { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(392, 54), BackgroundTransparency = 1, Parent = win })
	local nameLbl = label({ Text = text, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.7, 0.45), Parent = row })
	local valLbl = label({ Text = "100%", Font = Enum.Font.FredokaOne, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.7, 0), Size = UDim2.fromScale(0.3, 0.45), Parent = row })
	local track = make("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = C.dark, Parent = row })
	corner(track, UDim.new(1, 0))
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.glue, Parent = track })
	corner(fill, UDim.new(1, 0))
	make("UIGradient", { Color = ColorSequence.new(C.glue, Color3.fromRGB(120, 60, 255)), Parent = fill })
	local thumb = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = C.white, Parent = track })
	corner(thumb, UDim.new(1, 0))
	stroke(thumb, C.panel, 2)
	local function setVal(v, fire)
		v = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		thumb.Position = UDim2.fromScale(v, 0.5)
		valLbl.Text = string.format("%d%%", math.round(v * 100))
		if fire then player:SetAttribute(attr, v) end
	end
	setVal(player:GetAttribute(attr) or 1, false)
	local dragging = false
	local function update(input)
		local x = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setVal(x, true)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			activeSlider = track
			punch(thumb, 1.4)
			update(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then click(0.9) end
			dragging = false
			if activeSlider == track then activeSlider = nil end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
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
-- 🃏 รองรับ MatchUI สำหรับ GameServer
---------------------------------------------------------------------
local matchGui = playerGui:FindFirstChild("MatchUI") or make("ScreenGui", {
	Name = "MatchUI", ResetOnSpawn = false, DisplayOrder = 15, Parent = playerGui,
})
if MatchUI and MatchUI.Build then
	pcall(function()
		MatchUI.Build(matchGui, gui, {
			OnStart = function()
				player:SetAttribute("GlueInDuel", true)
				if TableCamera and TableCamera.Enter then
					TableCamera.Enter()
				end
			end,
			OnExit = function()
				if TableCamera and TableCamera.Exit then
					TableCamera.Exit()
				end
				player:SetAttribute("GlueInDuel", false)
				refreshProfile()
			end,
		})
	end)
end

---------------------------------------------------------------------
-- 🎬 Intro + ซ่อนตอนดวล
---------------------------------------------------------------------
local HOME = {
	{ obj = profile, home = UDim2.fromOffset(12, 12), away = UDim2.fromOffset(-420, 12) },
	{ obj = menu, home = UDim2.new(1, -12, 0.5, 0), away = UDim2.new(1, 220, 0.5, 0) },
	{ obj = battleDock, home = UDim2.new(0.5, 0, 1, -16), away = UDim2.new(0.5, 0, 1, 220) },
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
		if MenuKit and MenuKit.close then MenuKit.close() end
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
local clock, qCur, mCur = 0, 1, 1
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
	
	-- อนิเมชันปุ่มดวลด่วน
	qCur += (qTarget - qCur) * math.min(1, dt * 14)
	qScale.Scale = qCur + math.sin(clock * 4) * 0.02
	
	-- อนิเมชันปุ่มเลือกโหมด
	mCur += (mTarget - mCur) * math.min(1, dt * 14)
	mScale.Scale = mCur + math.sin(clock * 4 + 1) * 0.02
	
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
