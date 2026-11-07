--!strict
--[[
	🎨 GlueLobbyHUD.client.lua — Anti-AI Slop "Manga Chaos Meets Tactile Arcade"
	• ชุดสี Manga Ink & Arcade Pop ตรงตามสเปก 100%
	• ขอบ Comic Outlines (UIStroke 3px) + เงาทึบซ้อนหลัง (Tactile 3D Arcade Offset Shadow)
	• ระบบสปริง Micro-Interactions (Hover 1.06x Back 0.2s / Click Punch 0.9x 0.08s)
	• Top-Left: กรอบโปรไฟล์ขอบรุ้งหมุนได้ + ป้ายเลเวลทอง + หลอด XP ชมพูกาว + ป้าย Gold เด้งได้เปิดร้านค้าทันที
	• Bottom-Center: ด็อกปุ่มต่อสู้คู่ (⚡ ดวลด่วน! 1-Click & ⚔️ เลือกโหมด)
	• Right-Center: แถบเมนูลัดแนวตั้ง (🗃️ คลังการ์ด, 🛒 ร้านค้า, 📜 เควสต์, ⚙️ ตั้งค่า)
	• โมดอลครบชุด:
	  1) 🛒 ร้านซองการ์ดกาว (เขย่าซอง -> ฉีกประกายไฟ -> การ์ด 3 ใบหมุนลอยขึ้นตาม Rarity)
	  2) 🗃️ อัลบั้มคลังการ์ดกาว 26 ใบ (ใบที่มีแสดงสีสดใส + จำนวน x1, x2 / ใบที่ไม่มีแสดงเงาดำ ❓ + หน้าต่างดูรายละเอียด)
	  3) ⚔️ หน้าต่างเลือกโหมด: แท็บบอท 5 ระดับ + แท็บ PvP (จับคู่ 1v1 ได้เงิน & Custom Mode เลือกคนสู้เจาะจง 0 Gold!)
	• Auto HUD Transition: สไลด์เก็บออกนอกจออัตโนมัติเมื่อ GlueInDuel = true และสไลด์กลับพร้อมอัปเดตเหรียญทันที
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ลบ HUD เก่าถ้ามีค้าง
for _, oldName in ipairs({ "GlueLobbyHUD", "FloatHUD" }) do
	local old = playerGui:FindFirstChild(oldName)
	if old then old:Destroy() end
end

local remotes = ReplicatedStorage:WaitForChild("GlueCardRemotes")
local QuickPlay = remotes:WaitForChild("QuickPlay") :: RemoteEvent
local BuyPack = remotes:WaitForChild("BuyPack") :: RemoteFunction
local GetCollection = remotes:WaitForChild("GetCollection") :: RemoteFunction
local ClaimQuest = remotes:WaitForChild("ClaimQuest") :: RemoteFunction
local ProfileChanged = remotes:WaitForChild("ProfileChanged") :: RemoteEvent
local JoinPvPQueue = remotes:WaitForChild("JoinPvPQueue") :: RemoteEvent
local LeavePvPQueue = remotes:WaitForChild("LeavePvPQueue") :: RemoteEvent
local StartPvP = remotes:WaitForChild("StartPvP") :: RemoteEvent
local SendCustomChallenge = remotes:WaitForChild("SendCustomChallenge") :: RemoteEvent
local IncomingCustomChallenge = remotes:WaitForChild("IncomingCustomChallenge") :: RemoteEvent
local RespondCustomChallenge = remotes:WaitForChild("RespondCustomChallenge") :: RemoteEvent

---------------------------------------------------------------------
-- 🎨 1.1 ชุดสี Manga Chaos Arcade Palette (Anti-AI Slop)
---------------------------------------------------------------------
local Palette = {
	InkDeep = Color3.fromRGB(18, 14, 28),
	InkPanel = Color3.fromRGB(28, 24, 46),
	InkLight = Color3.fromRGB(44, 38, 72),
	Gold = Color3.fromRGB(255, 214, 10),
	Slime = Color3.fromRGB(0, 240, 160),
	Magenta = Color3.fromRGB(255, 64, 168),
	Crimson = Color3.fromRGB(255, 59, 86),
	Cyan = Color3.fromRGB(56, 175, 255),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(175, 170, 205),
}

local RarityStyle: { [string]: { color: Color3, label: string, badgeBg: Color3 } } = {
	Common = { color = Color3.fromRGB(190, 198, 215), label = "⚪ COMMON", badgeBg = Color3.fromRGB(65, 70, 88) },
	Rare = { color = Palette.Cyan, label = "🔵 RARE", badgeBg = Color3.fromRGB(20, 75, 140) },
	Legendary = { color = Palette.Gold, label = "🟡 LEGENDARY", badgeBg = Color3.fromRGB(130, 85, 10) },
	Glue = { color = Palette.Magenta, label = "🟣 GLUE RARE", badgeBg = Color3.fromRGB(125, 20, 95) },
}

local RAINBOW_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 59, 86)),
	ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 214, 10)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(0, 240, 160)),
	ColorSequenceKeypoint.new(0.70, Color3.fromRGB(56, 175, 255)),
	ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255, 64, 168)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 59, 86)),
})

-- ตั้งค่าเริ่มต้น
if player:GetAttribute("GlueBGM") == nil then player:SetAttribute("GlueBGM", 1) end
if player:GetAttribute("GlueSFX") == nil then player:SetAttribute("GlueSFX", 1) end
if player:GetAttribute("GlueShake") == nil then player:SetAttribute("GlueShake", true) end

---------------------------------------------------------------------
-- 🔊 ระบบเสียงคลิก Tactile Arcade SFX
---------------------------------------------------------------------
local function playSFX(id: string, pitch: number?, vol: number?)
	if (player:GetAttribute("GlueSFX") or 1) <= 0 then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch or 1
	s.Volume = (vol or 0.45) * (player:GetAttribute("GlueSFX") or 1)
	s.Parent = SoundService
	s:Play()
	task.delay(2, function()
		if s then s:Destroy() end
	end)
end

local function clickSFX()
	playSFX("rbxassetid://6895079853", math.random(96, 106) / 100, 0.4)
end

---------------------------------------------------------------------
-- 🧱 ตัวช่วยสร้าง Tactile Squircle, Comic Outlines & Spring Button
---------------------------------------------------------------------
local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function addStroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- ระบบสปริง Hover 1.06x (Back, 0.2s) & Click/Punch 0.9x (0.08s -> 1.0x)
local function bindTactileSpring(btn: GuiButton, onClick: (() -> ())?)
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.06,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.9,
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)

	if onClick then
		btn.Activated:Connect(function()
			clickSFX()
			TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 0.9,
			}):Play()
			task.delay(0.08, function()
				if scale and scale.Parent then
					TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Scale = 1.0,
					}):Play()
				end
			end)
			onClick()
		end)
	end
end

-- สร้างปุ่มสไตล์เกมตู้ Arcade มีเงา Comic ทึบด้านหลัง
local function createArcadeButton(parent: Instance, text: string, bgColor: Color3, textColor: Color3, size: UDim2, pos: UDim2?): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = size
	if pos then btn.Position = pos end
	btn.BackgroundColor3 = bgColor
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent
	addCorner(btn, 16)
	addStroke(btn, Palette.InkDeep, 3)

	-- แถบไฮไลท์ด้านบนสไตล์ปุ่ม Arcade นูน
	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(1, -12, 0.38, 0)
	shine.Position = UDim2.fromOffset(6, 4)
	shine.BackgroundColor3 = Palette.White
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel = 0
	shine.ZIndex = btn.ZIndex + 1
	shine.Parent = btn
	addCorner(shine, 10)

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = text
	lbl.TextColor3 = textColor
	lbl.TextSize = 20
	lbl.ZIndex = btn.ZIndex + 2
	lbl.Parent = btn
	addStroke(lbl, Palette.InkDeep, 2.2)

	return btn
end

---------------------------------------------------------------------
-- 🖥️ สร้าง ScreenGui หลัก + UIScale Responsive (PC & Mobile)
---------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GlueLobbyHUD"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local rootScale = Instance.new("UIScale")
rootScale.Parent = screenGui

local function updateResponsiveScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local s = math.min(vp.X / 1366, vp.Y / 768)
	rootScale.Scale = math.clamp(s, 0.68, 1.15)
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	updateResponsiveScale()
end

-- State ข้อมูลผู้เล่นฝั่ง Client
local clientState = {
	gold = tonumber(player:GetAttribute("Gold")) or 300,
	wins = tonumber(player:GetAttribute("GlueWins")) or 0,
	losses = tonumber(player:GetAttribute("GlueLosses")) or 0,
	streak = tonumber(player:GetAttribute("GlueStreak")) or 0,
	packsOpened = tonumber(player:GetAttribute("GluePacksOpened")) or 0,
	collection = {} :: { [string]: number },
	allCards = {} :: { any },
	questsClaimed = {} :: { [string]: boolean },
	inQueue = false,
}

-- ประกาศฟังก์ชันเปิดโมดอลล่วงหน้า
local openModal: (modalName: string) -> ()

---------------------------------------------------------------------
-- 1️⃣ Top-Left: ป้ายโปรไฟล์ & ป้ายเหรียญ Gold
---------------------------------------------------------------------
local topLeftContainer = Instance.new("Frame")
topLeftContainer.Name = "TopLeftHUD"
topLeftContainer.Size = UDim2.fromOffset(540, 96)
topLeftContainer.Position = UDim2.fromOffset(22, 20)
topLeftContainer.BackgroundTransparency = 1
topLeftContainer.Parent = screenGui

-- เงาทึบหลังป้ายโปรไฟล์ (Comic Shadow)
local profileShadow = Instance.new("Frame")
profileShadow.Size = UDim2.fromOffset(310, 86)
profileShadow.Position = UDim2.fromOffset(5, 6)
profileShadow.BackgroundColor3 = Palette.InkDeep
profileShadow.Parent = topLeftContainer
addCorner(profileShadow, 18)

-- กรอบโปรไฟล์หลัก
local profileCard = Instance.new("Frame")
profileCard.Name = "ProfileCard"
profileCard.Size = UDim2.fromOffset(310, 86)
profileCard.BackgroundColor3 = Palette.InkPanel
profileCard.Parent = topLeftContainer
addCorner(profileCard, 18)
addStroke(profileCard, Palette.InkDeep, 3.2)

-- วงกลมอวาตาร์ขอบรุ้งหมุนได้
local avatarRing = Instance.new("Frame")
avatarRing.Size = UDim2.fromOffset(68, 68)
avatarRing.Position = UDim2.fromOffset(10, 9)
avatarRing.BackgroundColor3 = Palette.InkDeep
avatarRing.Parent = profileCard
addCorner(avatarRing, 34)

local avatarStroke = addStroke(avatarRing, Palette.White, 3.5)
local rainbowGrad = Instance.new("UIGradient")
rainbowGrad.Color = RAINBOW_SEQ
rainbowGrad.Parent = avatarStroke

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.fromScale(1, 1)
avatarImg.BackgroundTransparency = 1
avatarImg.Parent = avatarRing
addCorner(avatarImg, 34)

task.spawn(function()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and url then
		avatarImg.Image = url
	end
end)

-- ป้ายเลเวลสีทอง (Sticker Badge เอียง -4 องศา)
local levelBadge = Instance.new("Frame")
levelBadge.Size = UDim2.fromOffset(58, 22)
levelBadge.Position = UDim2.fromOffset(15, 60)
levelBadge.Rotation = -4
levelBadge.BackgroundColor3 = Palette.Gold
levelBadge.ZIndex = 4
levelBadge.Parent = profileCard
addCorner(levelBadge, 8)
addStroke(levelBadge, Palette.InkDeep, 2.5)

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.fromScale(1, 1)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.FredokaOne
levelLabel.Text = "LV.1"
levelLabel.TextColor3 = Palette.InkDeep
levelLabel.TextSize = 14
levelLabel.ZIndex = 5
levelLabel.Parent = levelBadge

-- ชื่อ DisplayName
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.fromOffset(210, 26)
nameLabel.Position = UDim2.fromOffset(88, 10)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.FredokaOne
nameLabel.Text = player.DisplayName
nameLabel.TextColor3 = Palette.White
nameLabel.TextSize = 20
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.Parent = profileCard
addStroke(nameLabel, Palette.InkDeep, 2)

-- สถิติชนะ/สตรีคย่อ
local statSubLabel = Instance.new("TextLabel")
statSubLabel.Size = UDim2.fromOffset(210, 18)
statSubLabel.Position = UDim2.fromOffset(88, 34)
statSubLabel.BackgroundTransparency = 1
statSubLabel.Font = Enum.Font.GothamBold
statSubLabel.Text = "🏆 ชนะ 0  •  🔥 สตรีค 0"
statSubLabel.TextColor3 = Palette.Slime
statSubLabel.TextSize = 13
statSubLabel.TextXAlignment = Enum.TextXAlignment.Left
statSubLabel.Parent = profileCard

-- แถบหลอด XP สีชมพูกาว
local xpBarBg = Instance.new("Frame")
xpBarBg.Size = UDim2.fromOffset(204, 16)
xpBarBg.Position = UDim2.fromOffset(88, 58)
xpBarBg.BackgroundColor3 = Palette.InkDeep
xpBarBg.Parent = profileCard
addCorner(xpBarBg, 8)
addStroke(xpBarBg, Palette.InkLight, 2)

local xpBarFill = Instance.new("Frame")
xpBarFill.Size = UDim2.new(0.35, 0, 1, 0)
xpBarFill.BackgroundColor3 = Palette.Magenta
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarBg
addCorner(xpBarFill, 8)

local xpText = Instance.new("TextLabel")
xpText.Size = UDim2.fromScale(1, 1)
xpText.BackgroundTransparency = 1
xpText.Font = Enum.Font.GothamBold
xpText.Text = "XP 35 / 100"
xpText.TextColor3 = Palette.White
xpText.TextSize = 11
xpText.ZIndex = 3
xpText.Parent = xpBarBg
addStroke(xpText, Palette.InkDeep, 1.5)

-- ป้ายเหรียญ Gold (ติดข้างโปรไฟล์ กดแล้วเปิดร้านค้าทันที + แอนิเมชันเด้งเมื่อได้เงิน)
local goldShadow = Instance.new("Frame")
goldShadow.Size = UDim2.fromOffset(205, 86)
goldShadow.Position = UDim2.fromOffset(329, 6)
goldShadow.BackgroundColor3 = Palette.InkDeep
goldShadow.Parent = topLeftContainer
addCorner(goldShadow, 18)

local goldBtn = Instance.new("TextButton")
goldBtn.Name = "GoldBadgeBtn"
goldBtn.Size = UDim2.fromOffset(205, 86)
goldBtn.Position = UDim2.fromOffset(324, 0)
goldBtn.BackgroundColor3 = Palette.InkPanel
goldBtn.AutoButtonColor = false
goldBtn.Text = ""
goldBtn.Parent = topLeftContainer
addCorner(goldBtn, 18)
addStroke(goldBtn, Palette.Gold, 3)

local goldAmountLabel = Instance.new("TextLabel")
goldAmountLabel.Size = UDim2.new(1, -20, 0, 38)
goldAmountLabel.Position = UDim2.fromOffset(12, 10)
goldAmountLabel.BackgroundTransparency = 1
goldAmountLabel.Font = Enum.Font.FredokaOne
goldAmountLabel.Text = "🪙 300 Gold"
goldAmountLabel.TextColor3 = Palette.Gold
goldAmountLabel.TextSize = 23
goldAmountLabel.TextXAlignment = Enum.TextXAlignment.Left
goldAmountLabel.Parent = goldBtn
addStroke(goldAmountLabel, Palette.InkDeep, 2.5)

local goldHintPill = Instance.new("Frame")
goldHintPill.Size = UDim2.new(1, -24, 0, 26)
goldHintPill.Position = UDim2.fromOffset(12, 50)
goldHintPill.BackgroundColor3 = Palette.Magenta
goldHintPill.Parent = goldBtn
addCorner(goldHintPill, 10)
addStroke(goldHintPill, Palette.InkDeep, 2)

local goldHintLabel = Instance.new("TextLabel")
goldHintLabel.Size = UDim2.fromScale(1, 1)
goldHintLabel.BackgroundTransparency = 1
goldHintLabel.Font = Enum.Font.GothamBold
goldHintLabel.Text = "🛒 แตะเพื่อเปิดร้านค้า"
goldHintLabel.TextColor3 = Palette.White
goldHintLabel.TextSize = 13
goldHintLabel.Parent = goldHintPill
addStroke(goldHintLabel, Palette.InkDeep, 1.5)

bindTactileSpring(goldBtn, function()
	openModal("Shop")
end)

local function bounceGoldBadge()
	local sc = goldBtn:FindFirstChildOfClass("UIScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Parent = goldBtn
	end
	sc.Scale = 1.22
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Scale = 1.0,
	}):Play()
end

---------------------------------------------------------------------
-- 2️⃣ Bottom-Center: ด็อกปุ่มต่อสู้คู่ (Battle Dock)
---------------------------------------------------------------------
local battleDock = Instance.new("Frame")
battleDock.Name = "BattleDock"
battleDock.Size = UDim2.fromOffset(500, 88)
battleDock.AnchorPoint = Vector2.new(0.5, 1)
battleDock.Position = UDim2.new(0.5, 0, 1, -22)
battleDock.BackgroundColor3 = Palette.InkPanel
battleDock.Parent = screenGui
addCorner(battleDock, 20)
addStroke(battleDock, Palette.InkDeep, 3.5)

-- ป้ายสติกเกอร์คาดบน Battle Dock
local dockRibbon = Instance.new("Frame")
dockRibbon.Size = UDim2.fromOffset(170, 24)
dockRibbon.AnchorPoint = Vector2.new(0.5, 0.5)
dockRibbon.Position = UDim2.new(0.5, 0, 0, 0)
dockRibbon.Rotation = -2
dockRibbon.BackgroundColor3 = Palette.Gold
dockRibbon.ZIndex = 5
dockRibbon.Parent = battleDock
addCorner(dockRibbon, 8)
addStroke(dockRibbon, Palette.InkDeep, 2.5)

local dockRibbonText = Instance.new("TextLabel")
dockRibbonText.Size = UDim2.fromScale(1, 1)
dockRibbonText.BackgroundTransparency = 1
dockRibbonText.Font = Enum.Font.FredokaOne
dockRibbonText.Text = "🕹️ CHAOS ARCADE DOCK"
dockRibbonText.TextColor3 = Palette.InkDeep
dockRibbonText.TextSize = 13
dockRibbonText.ZIndex = 6
dockRibbonText.Parent = dockRibbon

-- ปุ่ม 1: ⚡ ดวลด่วน! (ปุ่มแคปซูลไฟวิ่งสลับสี 1-Click)
local quickDuelBtn = createArcadeButton(
	battleDock,
	"⚡ ดวลด่วน!",
	Palette.Slime,
	Palette.White,
	UDim2.fromOffset(230, 62),
	UDim2.fromOffset(14, 14)
)
local quickGrad = Instance.new("UIGradient")
quickGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Palette.Slime),
	ColorSequenceKeypoint.new(0.5, Palette.Cyan),
	ColorSequenceKeypoint.new(1, Palette.Slime),
})
quickGrad.Parent = quickDuelBtn

bindTactileSpring(quickDuelBtn, function()
	QuickPlay:FireServer({ difficulty = "Medium", mode = "Bot" })
end)

-- ปุ่ม 2: ⚔️ เลือกโหมด (เปิดหน้าต่างเลือกความยากบอท 5 ระดับ + PvP 1v1 + Custom Mode)
local selectModeBtn = createArcadeButton(
	battleDock,
	"⚔️ เลือกโหมด",
	Palette.Magenta,
	Palette.White,
	UDim2.fromOffset(230, 62),
	UDim2.fromOffset(256, 14)
)
bindTactileSpring(selectModeBtn, function()
	openModal("Play")
end)

---------------------------------------------------------------------
-- 3️⃣ Right-Center: แถบเมนูลัดแนวตั้ง (Vertical Quick Bar 4 ปุ่ม)
---------------------------------------------------------------------
local quickBar = Instance.new("Frame")
quickBar.Name = "VerticalQuickBar"
quickBar.Size = UDim2.fromOffset(104, 348)
quickBar.AnchorPoint = Vector2.new(1, 0.5)
quickBar.Position = UDim2.new(1, -20, 0.5, 0)
quickBar.BackgroundColor3 = Palette.InkPanel
quickBar.Parent = screenGui
addCorner(quickBar, 20)
addStroke(quickBar, Palette.InkDeep, 3.5)

local quickList = Instance.new("UIListLayout")
quickList.Padding = UDim.new(0, 10)
quickList.HorizontalAlignment = Enum.HorizontalAlignment.Center
quickList.VerticalAlignment = Enum.VerticalAlignment.Center
quickList.Parent = quickBar

local quickItems = {
	{ id = "Album", icon = "🗃️", title = "คลังการ์ด", color = Palette.Cyan },
	{ id = "Shop", icon = "🛒", title = "ร้านค้า", color = Palette.Gold },
	{ id = "Quests", icon = "📜", title = "เควสต์", color = Palette.Slime },
	{ id = "Settings", icon = "⚙️", title = "ตั้งค่า", color = Palette.Magenta },
}

for _, item in ipairs(quickItems) do
	local qBtn = Instance.new("TextButton")
	qBtn.Name = item.id .. "Btn"
	qBtn.Size = UDim2.fromOffset(84, 72)
	qBtn.BackgroundColor3 = Palette.InkLight
	qBtn.AutoButtonColor = false
	qBtn.Text = ""
	qBtn.Parent = quickBar
	addCorner(qBtn, 16)
	addStroke(qBtn, item.color, 2.8)

	local ico = Instance.new("TextLabel")
	ico.Size = UDim2.new(1, 0, 0, 38)
	ico.Position = UDim2.fromOffset(0, 6)
	ico.BackgroundTransparency = 1
	ico.Font = Enum.Font.FredokaOne
	ico.Text = item.icon
	ico.TextSize = 28
	ico.Parent = qBtn

	local cap = Instance.new("TextLabel")
	cap.Size = UDim2.new(1, 0, 0, 22)
	cap.Position = UDim2.fromOffset(0, 44)
	cap.BackgroundTransparency = 1
	cap.Font = Enum.Font.FredokaOne
	cap.Text = item.title
	cap.TextColor3 = Palette.White
	cap.TextSize = 14
	cap.Parent = qBtn
	addStroke(cap, Palette.InkDeep, 1.8)

	bindTactileSpring(qBtn, function()
		openModal(item.id)
	end)
end

---------------------------------------------------------------------
-- 🪟 ระบบจัดการหน้าต่างโมดอลพิเศษ (Modals Container)
---------------------------------------------------------------------
local modalBackdrop = Instance.new("Frame")
modalBackdrop.Name = "ModalBackdrop"
modalBackdrop.Size = UDim2.fromScale(1, 1)
modalBackdrop.BackgroundColor3 = Palette.InkDeep
modalBackdrop.BackgroundTransparency = 0.35
modalBackdrop.Visible = false
modalBackdrop.ZIndex = 20
modalBackdrop.Parent = screenGui

local modals: { [string]: Frame } = {}

local function closeAllModals()
	modalBackdrop.Visible = false
	for _, m in pairs(modals) do
		m.Visible = false
	end
end

local function createModalWindow(name: string, titleText: string, accentColor: Color3, width: number, height: number): Frame
	local win = Instance.new("Frame")
	win.Name = name .. "Modal"
	win.Size = UDim2.fromOffset(width, height)
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.BackgroundColor3 = Palette.InkPanel
	win.Visible = false
	win.ZIndex = 22
	win.Parent = modalBackdrop
	addCorner(win, 20)
	addStroke(win, accentColor, 3.5)

	local winScale = Instance.new("UIScale")
	winScale.Parent = win

	-- แถบหัวข้อสไตล์มังงะเอียงเล็กน้อย
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -28, 0, 54)
	header.Position = UDim2.fromOffset(14, 12)
	header.BackgroundColor3 = Palette.InkDeep
	header.ZIndex = 23
	header.Parent = win
	addCorner(header, 14)
	addStroke(header, accentColor, 2.5)

	local hTitle = Instance.new("TextLabel")
	hTitle.Size = UDim2.new(1, -70, 1, 0)
	hTitle.Position = UDim2.fromOffset(18, 0)
	hTitle.BackgroundTransparency = 1
	hTitle.Font = Enum.Font.FredokaOne
	hTitle.Text = titleText
	hTitle.TextColor3 = Palette.White
	hTitle.TextSize = 24
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.ZIndex = 24
	hTitle.Parent = header
	addStroke(hTitle, Palette.InkDeep, 2)

	local closeBtn = createArcadeButton(header, "✖", Palette.Crimson, Palette.White, UDim2.fromOffset(44, 40), UDim2.new(1, -50, 0, 7))
	closeBtn.ZIndex = 25
	bindTactileSpring(closeBtn, function()
		closeAllModals()
	end)

	modals[name] = win
	return win
end

---------------------------------------------------------------------
-- 🛒 โมดอล 1: ร้านค้าซองการ์ดกาว (Shop Gacha Modal)
---------------------------------------------------------------------
local shopModal = createModalWindow("Shop", "🛒 ร้านซองการ์ดกาว (Chaos Card Pack)", Palette.Gold, 760, 500)

-- กรอบแสดงซองการ์ดตรงกลาง
local packStage = Instance.new("Frame")
packStage.Size = UDim2.new(1, -36, 0, 320)
packStage.Position = UDim2.fromOffset(18, 78)
packStage.BackgroundColor3 = Palette.InkDeep
packStage.ZIndex = 23
packStage.Parent = shopModal
addCorner(packStage, 18)
addStroke(packStage, Palette.InkLight, 2.5)

-- ตัวซองการ์ดก่อนฉีก
local packBox = Instance.new("Frame")
packBox.Size = UDim2.fromOffset(190, 250)
packBox.AnchorPoint = Vector2.new(0.5, 0.5)
packBox.Position = UDim2.fromScale(0.5, 0.5)
packBox.BackgroundColor3 = Palette.Magenta
packBox.ZIndex = 25
packBox.Parent = packStage
addCorner(packBox, 18)
addStroke(packBox, Palette.Gold, 3.5)

local packGrad = Instance.new("UIGradient")
packGrad.Color = RAINBOW_SEQ
packGrad.Rotation = 45
packGrad.Parent = packBox

local packArt = Instance.new("TextLabel")
packArt.Size = UDim2.fromScale(1, 0.65)
packArt.BackgroundTransparency = 1
packArt.Font = Enum.Font.FredokaOne
packArt.Text = "🃏✨"
packArt.TextSize = 68
packArt.ZIndex = 26
packArt.Parent = packBox

local packTitle = Instance.new("TextLabel")
packTitle.Size = UDim2.new(1, -12, 0, 54)
packTitle.Position = UDim2.new(0, 6, 0.62, 0)
packTitle.BackgroundTransparency = 1
packTitle.Font = Enum.Font.FredokaOne
packTitle.Text = "CHAOS PACK\nการันตีการ์ดกาว 3 ใบ!"
packTitle.TextColor3 = Palette.White
packTitle.TextSize = 18
packTitle.ZIndex = 26
packTitle.Parent = packBox
addStroke(packTitle, Palette.InkDeep, 2.2)

-- โซนแสดงการ์ด 3 ใบที่เปิดได้
local revealedContainer = Instance.new("Frame")
revealedContainer.Size = UDim2.fromScale(1, 1)
revealedContainer.BackgroundTransparency = 1
revealedContainer.Visible = false
revealedContainer.ZIndex = 27
revealedContainer.Parent = packStage

local revLayout = Instance.new("UIListLayout")
revLayout.FillDirection = Enum.FillDirection.Horizontal
revLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
revLayout.VerticalAlignment = Enum.VerticalAlignment.Center
revLayout.Padding = UDim.new(0, 22)
revLayout.Parent = revealedContainer

local shopStatusLabel = Instance.new("TextLabel")
shopStatusLabel.Size = UDim2.fromOffset(420, 34)
shopStatusLabel.Position = UDim2.fromOffset(24, 418)
shopStatusLabel.BackgroundTransparency = 1
shopStatusLabel.Font = Enum.Font.GothamBold
shopStatusLabel.Text = "⚪ Common 60%  |  🔵 Rare 28%  |  🟡 Legendary 9%  |  🟣 Glue 3%"
shopStatusLabel.TextColor3 = Palette.Muted
shopStatusLabel.TextSize = 14
shopStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
shopStatusLabel.ZIndex = 24
shopStatusLabel.Parent = shopModal

local buyPackBtn = createArcadeButton(
	shopModal,
	"✨ เปิดซอง (100 Gold)",
	Palette.Gold,
	Palette.InkDeep,
	UDim2.fromOffset(260, 62),
	UDim2.new(1, -280, 1, -80)
)
buyPackBtn.ZIndex = 25

local openingPack = false
bindTactileSpring(buyPackBtn, function()
	if openingPack then return end
	openingPack = true

	revealedContainer.Visible = false
	for _, ch in ipairs(revealedContainer:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	packBox.Visible = true
	packBox.Rotation = 0

	local res = BuyPack:InvokeServer()
	if not res or not res.ok then
		shopStatusLabel.Text = "❌ " .. tostring(res and res.reason or "เปิดซองไม่สำเร็จ")
		shopStatusLabel.TextColor3 = Palette.Crimson
		openingPack = false
		return
	end

	-- แอนิเมชันซองการ์ดสั่นและฉีกออกเป็นประกายไฟ
	shopStatusLabel.Text = "💥 กำลังฉีกซองการ์ดกาว..."
	shopStatusLabel.TextColor3 = Palette.Gold
	local packScale = packBox:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", packBox)
	for i = 1, 8 do
		packBox.Rotation = (i % 2 == 0) and 9 or -9
		packScale.Scale = 1 + (i * 0.03)
		playSFX("rbxassetid://9119713951", 0.9 + (i * 0.06), 0.35)
		task.wait(0.055)
	end
	packBox.Rotation = 0
	packScale.Scale = 1.0
	packBox.Visible = false
	revealedContainer.Visible = true

	-- เผยการ์ด 3 ใบหมุนลอยขึ้นมาทีละใบตาม Rarity
	for idx, card in ipairs(res.cards) do
		local rInfo = RarityStyle[card.rarity] or RarityStyle.Common
		local cardFrame = Instance.new("Frame")
		cardFrame.Size = UDim2.fromOffset(200, 275)
		cardFrame.BackgroundColor3 = Palette.InkPanel
		cardFrame.Rotation = -18
		cardFrame.ZIndex = 28
		cardFrame.Parent = revealedContainer
		addCorner(cardFrame, 16)
		local cStroke = addStroke(cardFrame, rInfo.color, 3.5)

		if card.rarity == "Glue" then
			local rg = Instance.new("UIGradient")
			rg.Color = RAINBOW_SEQ
			rg.Parent = cStroke
		end

		local cScale = Instance.new("UIScale")
		cScale.Scale = 0.1
		cScale.Parent = cardFrame

		-- ป้ายสติกเกอร์ Rarity เอียง
		local rBadge = Instance.new("Frame")
		rBadge.Size = UDim2.fromOffset(132, 24)
		rBadge.Position = UDim2.fromOffset(34, -8)
		rBadge.Rotation = 3
		rBadge.BackgroundColor3 = rInfo.badgeBg
		rBadge.ZIndex = 30
		rBadge.Parent = cardFrame
		addCorner(rBadge, 8)
		addStroke(rBadge, rInfo.color, 2)

		local rTxt = Instance.new("TextLabel")
		rTxt.Size = UDim2.fromScale(1, 1)
		rTxt.BackgroundTransparency = 1
		rTxt.Font = Enum.Font.FredokaOne
		rTxt.Text = rInfo.label
		rTxt.TextColor3 = Palette.White
		rTxt.TextSize = 13
		rTxt.ZIndex = 31
		rTxt.Parent = rBadge

		local emo = Instance.new("TextLabel")
		emo.Size = UDim2.new(1, 0, 0, 88)
		emo.Position = UDim2.fromOffset(0, 26)
		emo.BackgroundTransparency = 1
		emo.Font = Enum.Font.FredokaOne
		emo.Text = card.emoji
		emo.TextSize = 62
		emo.ZIndex = 29
		emo.Parent = cardFrame

		local cname = Instance.new("TextLabel")
		cname.Size = UDim2.new(1, -16, 0, 28)
		cname.Position = UDim2.fromOffset(8, 118)
		cname.BackgroundTransparency = 1
		cname.Font = Enum.Font.FredokaOne
		cname.Text = card.name
		cname.TextColor3 = Palette.White
		cname.TextSize = 18
		cname.ZIndex = 29
		cname.Parent = cardFrame
		addStroke(cname, Palette.InkDeep, 2)

		local cdesc = Instance.new("TextLabel")
		cdesc.Size = UDim2.new(1, -20, 0, 68)
		cdesc.Position = UDim2.fromOffset(10, 148)
		cdesc.BackgroundTransparency = 1
		cdesc.Font = Enum.Font.GothamMedium
		cdesc.Text = card.desc
		cdesc.TextColor3 = Palette.Muted
		cdesc.TextSize = 12
		cdesc.TextWrapped = true
		cdesc.ZIndex = 29
		cdesc.Parent = cardFrame

		local statLine = Instance.new("TextLabel")
		statLine.Size = UDim2.new(1, -16, 0, 28)
		statLine.Position = UDim2.fromOffset(8, 232)
		statLine.BackgroundTransparency = 1
		statLine.Font = Enum.Font.FredokaOne
		statLine.Text = (card.cardType == "Monster")
			and string.format("💧%d   ⚔ %d   ❤ %d", card.cost, card.atk, card.hp)
			or string.format("💧%d   ✨ การ์ดเวทมนตร์", card.cost)
		statLine.TextColor3 = Palette.Gold
		statLine.TextSize = 15
		statLine.ZIndex = 29
		statLine.Parent = cardFrame
		addStroke(statLine, Palette.InkDeep, 1.8)

		playSFX("rbxassetid://6895079853", 1.0 + (idx * 0.15), 0.5)
		TweenService:Create(cScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
		TweenService:Create(cardFrame, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = (idx == 2) and 0 or ((idx == 1) and -3 or 3),
		}):Play()
		task.wait(0.18)
	end

	shopStatusLabel.Text = "🎉 ได้รับการ์ดใหม่ 3 ใบเข้าคลังเรียบร้อย!"
	shopStatusLabel.TextColor3 = Palette.Slime
	openingPack = false
end)

---------------------------------------------------------------------
-- 🗃️ โมดอล 2: อัลบั้มคลังการ์ดกาวทั้ง 26 ใบ (Chaos Card Album)
---------------------------------------------------------------------
local albumModal = createModalWindow("Album", "🗃️ อัลบั้มคลังการ์ดกาว (26 ใบ)", Palette.Cyan, 880, 540)

local albumScroll = Instance.new("ScrollingFrame")
albumScroll.Size = UDim2.new(0.64, -24, 1, -92)
albumScroll.Position = UDim2.fromOffset(16, 76)
albumScroll.BackgroundColor3 = Palette.InkDeep
albumScroll.ScrollBarThickness = 8
albumScroll.ScrollBarImageColor3 = Palette.Cyan
albumScroll.ZIndex = 23
albumScroll.Parent = albumModal
addCorner(albumScroll, 16)
addStroke(albumScroll, Palette.InkLight, 2)

local albumPad = Instance.new("UIPadding")
albumPad.PaddingTop = UDim.new(0, 12)
albumPad.PaddingBottom = UDim.new(0, 12)
albumPad.PaddingLeft = UDim.new(0, 12)
albumPad.PaddingRight = UDim.new(0, 12)
albumPad.Parent = albumScroll

local albumGrid = Instance.new("UIGridLayout")
albumGrid.CellSize = UDim2.fromOffset(122, 156)
albumGrid.CellPadding = UDim2.fromOffset(10, 10)
albumGrid.SortOrder = Enum.SortOrder.LayoutOrder
albumGrid.Parent = albumScroll

-- แผงดูรายละเอียดการ์ดด้านขวา (Card Inspector)
local inspectPanel = Instance.new("Frame")
inspectPanel.Size = UDim2.new(0.36, -20, 1, -92)
inspectPanel.Position = UDim2.new(0.64, 4, 0, 76)
inspectPanel.BackgroundColor3 = Palette.InkDeep
inspectPanel.ZIndex = 23
inspectPanel.Parent = albumModal
addCorner(inspectPanel, 16)
addStroke(inspectPanel, Palette.Gold, 2.8)

local inspectEmoji = Instance.new("TextLabel")
inspectEmoji.Size = UDim2.new(1, 0, 0, 110)
inspectEmoji.Position = UDim2.fromOffset(0, 18)
inspectEmoji.BackgroundTransparency = 1
inspectEmoji.Font = Enum.Font.FredokaOne
inspectEmoji.Text = "🃏"
inspectEmoji.TextSize = 76
inspectEmoji.ZIndex = 24
inspectEmoji.Parent = inspectPanel

local inspectName = Instance.new("TextLabel")
inspectName.Size = UDim2.new(1, -20, 0, 34)
inspectName.Position = UDim2.fromOffset(10, 132)
inspectName.BackgroundTransparency = 1
inspectName.Font = Enum.Font.FredokaOne
inspectName.Text = "แตะการ์ดเพื่อดูข้อมูล"
inspectName.TextColor3 = Palette.Gold
inspectName.TextSize = 22
inspectName.ZIndex = 24
inspectName.Parent = inspectPanel
addStroke(inspectName, Palette.InkDeep, 2)

local inspectStats = Instance.new("TextLabel")
inspectStats.Size = UDim2.new(1, -20, 0, 32)
inspectStats.Position = UDim2.fromOffset(10, 170)
inspectStats.BackgroundTransparency = 1
inspectStats.Font = Enum.Font.FredokaOne
inspectStats.Text = "💧 -   ⚔ -   ❤ -"
inspectStats.TextColor3 = Palette.Cyan
inspectStats.TextSize = 18
inspectStats.ZIndex = 24
inspectStats.Parent = inspectPanel

local inspectDesc = Instance.new("TextLabel")
inspectDesc.Size = UDim2.new(1, -28, 0, 160)
inspectDesc.Position = UDim2.fromOffset(14, 212)
inspectDesc.BackgroundTransparency = 1
inspectDesc.Font = Enum.Font.GothamMedium
inspectDesc.Text = "สะสมการ์ดกาวให้ครบทั้ง 26 ใบจากการเปิดซองในร้านค้า!"
inspectDesc.TextColor3 = Palette.White
inspectDesc.TextSize = 15
inspectDesc.TextWrapped = true
inspectDesc.TextYAlignment = Enum.TextYAlignment.Top
inspectDesc.ZIndex = 24
inspectDesc.Parent = inspectPanel

local function refreshAlbumGrid()
	for _, ch in ipairs(albumScroll:GetChildren()) do
		if ch:IsA("GuiButton") then ch:Destroy() end
	end

	local ownedTypes = 0
	for idx, c in ipairs(clientState.allCards) do
		local count = clientState.collection[c.id] or 0
		local owned = count > 0
		if owned then ownedTypes += 1 end
		local rInfo = RarityStyle[c.rarity] or RarityStyle.Common

		local cell = Instance.new("TextButton")
		cell.LayoutOrder = idx
		cell.BackgroundColor3 = owned and Palette.InkPanel or Color3.fromRGB(14, 12, 22)
		cell.AutoButtonColor = false
		cell.Text = ""
		cell.ZIndex = 24
		cell.Parent = albumScroll
		addCorner(cell, 14)
		addStroke(cell, owned and rInfo.color or Palette.InkLight, 2.5)

		-- ป้ายจำนวน x1, x2 หรือ ❓
		local cntBadge = Instance.new("Frame")
		cntBadge.Size = UDim2.fromOffset(42, 22)
		cntBadge.Position = UDim2.new(1, -46, 0, 6)
		cntBadge.Rotation = 4
		cntBadge.BackgroundColor3 = owned and Palette.Gold or Palette.InkLight
		cntBadge.ZIndex = 26
		cntBadge.Parent = cell
		addCorner(cntBadge, 7)
		addStroke(cntBadge, Palette.InkDeep, 2)

		local cntText = Instance.new("TextLabel")
		cntText.Size = UDim2.fromScale(1, 1)
		cntText.BackgroundTransparency = 1
		cntText.Font = Enum.Font.FredokaOne
		cntText.Text = owned and ("x" .. tostring(count)) or "❓"
		cntText.TextColor3 = owned and Palette.InkDeep or Palette.Muted
		cntText.TextSize = 13
		cntText.ZIndex = 27
		cntText.Parent = cntBadge

		local emo = Instance.new("TextLabel")
		emo.Size = UDim2.new(1, 0, 0, 66)
		emo.Position = UDim2.fromOffset(0, 24)
		emo.BackgroundTransparency = 1
		emo.Font = Enum.Font.FredokaOne
		emo.Text = owned and c.emoji or "❓"
		emo.TextColor3 = owned and Palette.White or Color3.fromRGB(45, 40, 65)
		emo.TextSize = 44
		emo.ZIndex = 25
		emo.Parent = cell

		local nm = Instance.new("TextLabel")
		nm.Size = UDim2.new(1, -10, 0, 36)
		nm.Position = UDim2.fromOffset(5, 94)
		nm.BackgroundTransparency = 1
		nm.Font = Enum.Font.FredokaOne
		nm.Text = owned and c.name or "❓ ยังไม่มี"
		nm.TextColor3 = owned and Palette.White or Palette.Muted
		nm.TextSize = 14
		nm.TextWrapped = true
		nm.ZIndex = 25
		nm.Parent = cell
		addStroke(nm, Palette.InkDeep, 1.5)

		bindTactileSpring(cell, function()
			inspectEmoji.Text = owned and c.emoji or "❓"
			inspectName.Text = string.format("%s (%s)", c.name, c.rarity)
			inspectStats.Text = (c.cardType == "Monster")
				and string.format("💧 มานา %d  |  ⚔ ATK %d  |  ❤ HP %d", c.cost, c.atk, c.hp)
				or string.format("💧 มานา %d  |  ✨ การ์ดเวทมนตร์", c.cost)
			inspectDesc.Text = c.desc .. (owned and string.format("\n\n📦 มีในคลัง: x%d ใบ", count) or "\n\n🔒 ยังไม่มีการ์ดใบนี้ เปิดซองในร้านค้าเพื่อสะสม!")
		end)
	end

	albumScroll.CanvasSize = UDim2.fromOffset(0, math.ceil(#clientState.allCards / 4) * 168 + 24)
end

---------------------------------------------------------------------
-- ⚔️ โมดอล 3: หน้าต่างเลือกโหมด (PlayPanel: Bot 5 ระดับ + PvP Queue + Custom PvP 0 Gold)
---------------------------------------------------------------------
local playModal = createModalWindow("Play", "⚔️ เลือกโหมดประลองการ์ดกาว", Palette.Magenta, 820, 520)

-- ปุ่มสลับแท็บ: แท็บบอท vs แท็บ PvP
local tabBotBtn = createArcadeButton(playModal, "🤖 ซ้อมบอท (5 ระดับ)", Palette.Cyan, Palette.White, UDim2.fromOffset(370, 48), UDim2.fromOffset(18, 76))
tabBotBtn.ZIndex = 24
local tabPvPBtn = createArcadeButton(playModal, "🌐 ดวลคนจริง PvP 1v1 & Custom", Palette.InkLight, Palette.White, UDim2.fromOffset(396, 48), UDim2.fromOffset(404, 76))
tabPvPBtn.ZIndex = 24

local botTabFrame = Instance.new("Frame")
botTabFrame.Size = UDim2.new(1, -36, 1, -148)
botTabFrame.Position = UDim2.fromOffset(18, 134)
botTabFrame.BackgroundTransparency = 1
botTabFrame.ZIndex = 24
botTabFrame.Parent = playModal

local pvpTabFrame = Instance.new("Frame")
pvpTabFrame.Size = UDim2.new(1, -36, 1, -148)
pvpTabFrame.Position = UDim2.fromOffset(18, 134)
pvpTabFrame.BackgroundTransparency = 1
pvpTabFrame.Visible = false
pvpTabFrame.ZIndex = 24
pvpTabFrame.Parent = playModal

local botLayout = Instance.new("UIListLayout")
botLayout.Padding = UDim.new(0, 10)
botLayout.Parent = botTabFrame

local botModes = {
	{ id = "Easy", title = "🟢 Easy — หุ่นฝึกซ้อม", desc = "คิดช้า (1.3s) มีโอกาส 35% เล่นพลาด เหมาะสำหรับมือใหม่", reward = "+60 Gold", color = Palette.Slime },
	{ id = "Medium", title = "🟡 Medium — บอทลุงกาว", desc = "บอทมาตรฐานสายกาว ตัดสินใจสมดุล", reward = "+100 Gold", color = Palette.Gold },
	{ id = "Hard", title = "🟠 Hard — ลุงกาวหัวร้อน", desc = "ตัดสินใจไว (0.6s) เลือกการ์ดและเป้าที่ดีที่สุดเสมอ", reward = "+160 Gold", color = Color3.fromRGB(255, 140, 40) },
	{ id = "Hacker", title = "🔴 Hacker — แฮกเกอร์สายกาว", desc = "คิดไวสุด (0.4s) แอบโกงมานา +1 ทุกเทิร์น ท้าทายขั้นสุด!", reward = "+250 Gold", color = Palette.Crimson },
	{ id = "Mix", title = "🎲 Mix — สุ่มบอทลุ้นโชค", desc = "สุ่มเจอทุกระดับความยาก ชนะรับโบนัสพิเศษเพิ่มอีก +50G!", reward = "โบนัส +50G", color = Palette.Magenta },
}

for _, bm in ipairs(botModes) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundColor3 = Palette.InkDeep
	row.ZIndex = 24
	row.Parent = botTabFrame
	addCorner(row, 14)
	addStroke(row, bm.color, 2.5)

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.fromOffset(480, 28)
	tLbl.Position = UDim2.fromOffset(16, 6)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.Text = bm.title
	tLbl.TextColor3 = Palette.White
	tLbl.TextSize = 19
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.ZIndex = 25
	tLbl.Parent = row

	local dLbl = Instance.new("TextLabel")
	dLbl.Size = UDim2.fromOffset(500, 22)
	dLbl.Position = UDim2.fromOffset(16, 34)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.GothamMedium
	dLbl.Text = bm.desc
	dLbl.TextColor3 = Palette.Muted
	dLbl.TextSize = 13
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.ZIndex = 25
	dLbl.Parent = row

	local startBtn = createArcadeButton(row, "ลุยเลย! (" .. bm.reward .. ")", bm.color, Palette.InkDeep, UDim2.fromOffset(210, 46), UDim2.new(1, -222, 0, 9))
	startBtn.ZIndex = 26
	bindTactileSpring(startBtn, function()
		closeAllModals()
		QuickPlay:FireServer({ difficulty = bm.id, mode = "Bot" })
	end)
end

-- แท็บ PvP: ฝั่งซ้าย = Ranked Queue 1v1 (+150G) | ฝั่งขวา = Custom Mode เลือกคนสู้เจาะจง (0 Gold)
local rankedBox = Instance.new("Frame")
rankedBox.Size = UDim2.new(0.46, -8, 1, 0)
rankedBox.BackgroundColor3 = Palette.InkDeep
rankedBox.ZIndex = 24
rankedBox.Parent = pvpTabFrame
addCorner(rankedBox, 16)
addStroke(rankedBox, Palette.Gold, 2.8)

local rankedTitle = Instance.new("TextLabel")
rankedTitle.Size = UDim2.new(1, -24, 0, 36)
rankedTitle.Position = UDim2.fromOffset(12, 16)
rankedTitle.BackgroundTransparency = 1
rankedTitle.Font = Enum.Font.FredokaOne
rankedTitle.Text = "🏆 จับคู่ดวล 1v1 (Ranked)"
rankedTitle.TextColor3 = Palette.Gold
rankedTitle.TextSize = 22
rankedTitle.ZIndex = 25
rankedTitle.Parent = rankedBox

local rankedDesc = Instance.new("TextLabel")
rankedDesc.Size = UDim2.new(1, -28, 0, 90)
rankedDesc.Position = UDim2.fromOffset(14, 58)
rankedDesc.BackgroundTransparency = 1
rankedDesc.Font = Enum.Font.GothamMedium
rankedDesc.Text = "• สุ่มจับคู่ผู้เล่นในคิวแบบ Real-time\n• ชนะรับ +150 Gold 🪙\n• แพ้รับรางวัลปลอบใจ +40 Gold\n• ออกกลางคันปรับแพ้บายทันที!"
rankedDesc.TextColor3 = Palette.White
rankedDesc.TextSize = 14
rankedDesc.TextXAlignment = Enum.TextXAlignment.Left
rankedDesc.TextWrapped = true
rankedDesc.ZIndex = 25
rankedDesc.Parent = rankedBox

local queueStatusLabel = Instance.new("TextLabel")
queueStatusLabel.Size = UDim2.new(1, -24, 0, 32)
queueStatusLabel.Position = UDim2.fromOffset(12, 190)
queueStatusLabel.BackgroundTransparency = 1
queueStatusLabel.Font = Enum.Font.FredokaOne
queueStatusLabel.Text = "สถานะ: พร้อมค้นหาคู่ต่อสู้"
queueStatusLabel.TextColor3 = Palette.Slime
queueStatusLabel.TextSize = 17
queueStatusLabel.ZIndex = 25
queueStatusLabel.Parent = rankedBox

local queueToggleBtn = createArcadeButton(rankedBox, "🔍 ค้นหาคู่ต่อสู้ 1v1", Palette.Slime, Palette.InkDeep, UDim2.new(1, -32, 0, 58), UDim2.new(0, 16, 1, -78))
queueToggleBtn.ZIndex = 26

bindTactileSpring(queueToggleBtn, function()
	clientState.inQueue = not clientState.inQueue
	local lbl = queueToggleBtn:FindFirstChild("Label") :: TextLabel?
	if clientState.inQueue then
		JoinPvPQueue:FireServer()
		queueStatusLabel.Text = "⏳ กำลังรอคู่ต่อสู้ในคิว..."
		queueStatusLabel.TextColor3 = Palette.Gold
		queueToggleBtn.BackgroundColor3 = Palette.Crimson
		if lbl then lbl.Text = "✖ ยกเลิกการค้นหา" end
	else
		LeavePvPQueue:FireServer()
		queueStatusLabel.Text = "สถานะ: พร้อมค้นหาคู่ต่อสู้"
		queueStatusLabel.TextColor3 = Palette.Slime
		queueToggleBtn.BackgroundColor3 = Palette.Slime
		if lbl then lbl.Text = "🔍 ค้นหาคู่ต่อสู้ 1v1" end
	end
end)

-- ฝั่งขวา: Custom Mode (เลือกคนท้าดวลเจาะจง - 0 Gold)
local customBox = Instance.new("Frame")
customBox.Size = UDim2.new(0.54, -8, 1, 0)
customBox.Position = UDim2.new(0.46, 8, 0, 0)
customBox.BackgroundColor3 = Palette.InkDeep
customBox.ZIndex = 24
customBox.Parent = pvpTabFrame
addCorner(customBox, 16)
addStroke(customBox, Palette.Cyan, 2.8)

local customHeader = Instance.new("TextLabel")
customHeader.Size = UDim2.new(1, -24, 0, 32)
customHeader.Position = UDim2.fromOffset(12, 12)
customHeader.BackgroundTransparency = 1
customHeader.Font = Enum.Font.FredokaOne
customHeader.Text = "🎯 โหมดเจาะจงเลือกคนสู้ (Custom 0 Gold)"
customHeader.TextColor3 = Palette.Cyan
customHeader.TextSize = 19
customHeader.TextXAlignment = Enum.TextXAlignment.Left
customHeader.ZIndex = 25
customHeader.Parent = customBox

local customSub = Instance.new("TextLabel")
customSub.Size = UDim2.new(1, -24, 0, 22)
customSub.Position = UDim2.fromOffset(12, 42)
customSub.BackgroundTransparency = 1
customSub.Font = Enum.Font.GothamMedium
customSub.Text = "เลือกผู้เล่นในเซิร์ฟเวอร์เพื่อท้าดวลตัวต่อตัว (ไม่เสีย/ไม่ได้ Gold)"
customSub.TextColor3 = Palette.Muted
customSub.TextSize = 12
customSub.TextXAlignment = Enum.TextXAlignment.Left
customSub.ZIndex = 25
customSub.Parent = customBox

local customPlayerScroll = Instance.new("ScrollingFrame")
customPlayerScroll.Size = UDim2.new(1, -24, 1, -80)
customPlayerScroll.Position = UDim2.fromOffset(12, 68)
customPlayerScroll.BackgroundColor3 = Palette.InkPanel
customPlayerScroll.ScrollBarThickness = 6
customPlayerScroll.ZIndex = 25
customPlayerScroll.Parent = customBox
addCorner(customPlayerScroll, 12)

local customListLayout = Instance.new("UIListLayout")
customListLayout.Padding = UDim.new(0, 8)
customListLayout.Parent = customPlayerScroll

local customPad = Instance.new("UIPadding")
customPad.PaddingTop = UDim.new(0, 8)
customPad.PaddingLeft = UDim.new(0, 8)
customPad.PaddingRight = UDim.new(0, 8)
customPad.Parent = customPlayerScroll

local function refreshCustomPlayerList()
	for _, ch in ipairs(customPlayerScroll:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end

	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			count += 1
			local item = Instance.new("Frame")
			item.Size = UDim2.new(1, 0, 0, 52)
			item.BackgroundColor3 = Palette.InkDeep
			item.ZIndex = 26
			item.Parent = customPlayerScroll
			addCorner(item, 10)
			addStroke(item, Palette.InkLight, 2)

			local pName = Instance.new("TextLabel")
			pName.Size = UDim2.new(1, -150, 1, 0)
			pName.Position = UDim2.fromOffset(12, 0)
			pName.BackgroundTransparency = 1
			pName.Font = Enum.Font.FredokaOne
			pName.Text = "👤 " .. other.DisplayName
			pName.TextColor3 = Palette.White
			pName.TextSize = 16
			pName.TextXAlignment = Enum.TextXAlignment.Left
			pName.ZIndex = 27
			pName.Parent = item

			local busy = other:GetAttribute("GlueInDuel") == true
			local chBtn = createArcadeButton(
				item,
				busy and "กำลังดวลอยู่" or "⚔️ ท้าดวล (0G)",
				busy and Palette.InkLight or Palette.Cyan,
				Palette.White,
				UDim2.fromOffset(130, 38),
				UDim2.new(1, -138, 0, 7)
			)
			chBtn.ZIndex = 27
			bindTactileSpring(chBtn, function()
				if other:GetAttribute("GlueInDuel") == true then return end
				SendCustomChallenge:FireServer(other.UserId)
				local lbl = chBtn:FindFirstChild("Label") :: TextLabel?
				if lbl then lbl.Text = "✅ ส่งคำท้าแล้ว!" end
			end)
		end
	end

	if count == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 80)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.FredokaOne
		empty.Text = "ยังไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์\nชวนเพื่อนเข้ามาท้าดวล Custom ได้เลย!"
		empty.TextColor3 = Palette.Muted
		empty.TextSize = 15
		empty.ZIndex = 26
		empty.Parent = customPlayerScroll
	end
end

bindTactileSpring(tabBotBtn, function()
	botTabFrame.Visible = true
	pvpTabFrame.Visible = false
	tabBotBtn.BackgroundColor3 = Palette.Cyan
	tabPvPBtn.BackgroundColor3 = Palette.InkLight
end)

bindTactileSpring(tabPvPBtn, function()
	botTabFrame.Visible = false
	pvpTabFrame.Visible = true
	tabBotBtn.BackgroundColor3 = Palette.InkLight
	tabPvPBtn.BackgroundColor3 = Palette.Magenta
	refreshCustomPlayerList()
end)

---------------------------------------------------------------------
-- 📜 โมดอล 4 & 5: เควสต์ (Quests) & ตั้งค่า (Settings)
---------------------------------------------------------------------
local questsModal = createModalWindow("Quests", "📜 ภารกิจสายกาวประจำวัน", Palette.Slime, 680, 440)
local questsListFrame = Instance.new("Frame")
questsListFrame.Size = UDim2.new(1, -36, 1, -92)
questsListFrame.Position = UDim2.fromOffset(18, 76)
questsListFrame.BackgroundTransparency = 1
questsListFrame.ZIndex = 23
questsListFrame.Parent = questsModal

local qLayout = Instance.new("UIListLayout")
qLayout.Padding = UDim.new(0, 12)
qLayout.Parent = questsListFrame

local questItemsUI = {
	{ id = "first_win", title = "🥇 ชนะการดวลครั้งแรก", desc = "ชนะบอทหรือ PvP อย่างน้อย 1 แมตช์", reward = 150 },
	{ id = "win_3", title = "🔥 จอมยุทธ์สายกาว", desc = "สะสมชัยชนะครบ 3 แมตช์", reward = 300 },
	{ id = "open_pack", title = "✨ นักสุ่มกาชาหน้าใหม่", desc = "เปิดซองการ์ดกาวในร้านค้า 1 ครั้ง", reward = 120 },
	{ id = "collector_10", title = "🗃️ นักสะสมการ์ดในตำนาน", desc = "สะสมการ์ดกาวไม่ซ้ำกันครบ 10 แบบ", reward = 250 },
}

local function refreshQuestsUI()
	for _, ch in ipairs(questsListFrame:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	for _, q in ipairs(questItemsUI) do
		local claimed = clientState.questsClaimed[q.id] == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 74)
		row.BackgroundColor3 = Palette.InkDeep
		row.ZIndex = 24
		row.Parent = questsListFrame
		addCorner(row, 14)
		addStroke(row, claimed and Palette.InkLight or Palette.Slime, 2.5)

		local qt = Instance.new("TextLabel")
		qt.Size = UDim2.fromOffset(420, 28)
		qt.Position = UDim2.fromOffset(16, 10)
		qt.BackgroundTransparency = 1
		qt.Font = Enum.Font.FredokaOne
		qt.Text = q.title
		qt.TextColor3 = Palette.White
		qt.TextSize = 19
		qt.TextXAlignment = Enum.TextXAlignment.Left
		qt.ZIndex = 25
		qt.Parent = row

		local qd = Instance.new("TextLabel")
		qd.Size = UDim2.fromOffset(420, 22)
		qd.Position = UDim2.fromOffset(16, 40)
		qd.BackgroundTransparency = 1
		qd.Font = Enum.Font.GothamMedium
		qd.Text = q.desc
		qd.TextColor3 = Palette.Muted
		qd.TextSize = 13
		qd.TextXAlignment = Enum.TextXAlignment.Left
		qd.ZIndex = 25
		qd.Parent = row

		local cBtn = createArcadeButton(
			row,
			claimed and "✅ รับแล้ว" or ("🪙 รับ +" .. tostring(q.reward) .. "G"),
			claimed and Palette.InkLight or Palette.Gold,
			claimed and Palette.Muted or Palette.InkDeep,
			UDim2.fromOffset(170, 48),
			UDim2.new(1, -184, 0, 13)
		)
		cBtn.ZIndex = 26
		bindTactileSpring(cBtn, function()
			if claimed then return end
			local res = ClaimQuest:InvokeServer(q.id)
			if res and res.ok then
				clientState.questsClaimed = res.questsClaimed or clientState.questsClaimed
				refreshQuestsUI()
			end
		end)
	end
end

local settingsModal = createModalWindow("Settings", "⚙️ ตั้งค่าระบบเกม", Palette.Magenta, 540, 360)
local settingsList = Instance.new("Frame")
settingsList.Size = UDim2.new(1, -36, 1, -92)
settingsList.Position = UDim2.fromOffset(18, 76)
settingsList.BackgroundTransparency = 1
settingsList.ZIndex = 23
settingsList.Parent = settingsModal

local sLayout = Instance.new("UIListLayout")
sLayout.Padding = UDim.new(0, 14)
sLayout.Parent = settingsList

local settingConfigs = {
	{ attr = "GlueSFX", label = "🔊 เสียงเอฟเฟกต์ (SFX)", isNumber = true },
	{ attr = "GlueBGM", label = "🎵 เสียงเพลงประกอบ (BGM)", isNumber = true },
	{ attr = "GlueShake", label = "💥 เอฟเฟกต์จอสั่น (Screen Shake)", isNumber = false },
}

for _, sc in ipairs(settingConfigs) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 68)
	row.BackgroundColor3 = Palette.InkDeep
	row.ZIndex = 24
	row.Parent = settingsList
	addCorner(row, 14)
	addStroke(row, Palette.InkLight, 2.5)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(300, 68)
	lbl.Position = UDim2.fromOffset(18, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = sc.label
	lbl.TextColor3 = Palette.White
	lbl.TextSize = 18
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 25
	lbl.Parent = row

	local toggleBtn = createArcadeButton(row, "เปิด (ON)", Palette.Slime, Palette.InkDeep, UDim2.fromOffset(150, 46), UDim2.new(1, -166, 0, 11))
	toggleBtn.ZIndex = 26

	local function syncToggleVisual()
		local val = player:GetAttribute(sc.attr)
		local isOn = (sc.isNumber and (tonumber(val) or 1) > 0) or (not sc.isNumber and val == true)
		toggleBtn.BackgroundColor3 = isOn and Palette.Slime or Palette.Crimson
		local t = toggleBtn:FindFirstChild("Label") :: TextLabel?
		if t then
			t.Text = isOn and "✅ เปิด (ON)" or "❌ ปิด (OFF)"
			t.TextColor3 = isOn and Palette.InkDeep or Palette.White
		end
	end
	syncToggleVisual()

	bindTactileSpring(toggleBtn, function()
		local val = player:GetAttribute(sc.attr)
		if sc.isNumber then
			player:SetAttribute(sc.attr, ((tonumber(val) or 1) > 0) and 0 or 1)
		else
			player:SetAttribute(sc.attr, not (val == true))
		end
		syncToggleVisual()
	end)
end

---------------------------------------------------------------------
-- 🔔 แบนเนอร์รับคำท้าดวล Custom Mode แบบ Real-time
---------------------------------------------------------------------
local invitePopup = Instance.new("Frame")
invitePopup.Size = UDim2.fromOffset(420, 150)
invitePopup.AnchorPoint = Vector2.new(0.5, 0)
invitePopup.Position = UDim2.new(0.5, 0, 0, -180)
invitePopup.BackgroundColor3 = Palette.InkPanel
invitePopup.Visible = false
invitePopup.ZIndex = 40
invitePopup.Parent = screenGui
addCorner(invitePopup, 18)
addStroke(invitePopup, Palette.Cyan, 3.5)

local inviteTitle = Instance.new("TextLabel")
inviteTitle.Size = UDim2.new(1, -24, 0, 64)
inviteTitle.Position = UDim2.fromOffset(12, 12)
inviteTitle.BackgroundTransparency = 1
inviteTitle.Font = Enum.Font.FredokaOne
inviteTitle.Text = "⚔️ มีผู้เล่นท้าดวล Custom Mode (0 Gold)!"
inviteTitle.TextColor3 = Palette.Gold
inviteTitle.TextSize = 18
inviteTitle.TextWrapped = true
inviteTitle.ZIndex = 41
inviteTitle.Parent = invitePopup

local acceptInviteBtn = createArcadeButton(invitePopup, "✅ รับคำท้า (0G)", Palette.Slime, Palette.InkDeep, UDim2.fromOffset(185, 48), UDim2.fromOffset(16, 86))
acceptInviteBtn.ZIndex = 42
local declineInviteBtn = createArcadeButton(invitePopup, "❌ ปฏิเสธ", Palette.Crimson, Palette.White, UDim2.fromOffset(185, 48), UDim2.fromOffset(218, 86))
declineInviteBtn.ZIndex = 42

bindTactileSpring(acceptInviteBtn, function()
	invitePopup.Visible = false
	RespondCustomChallenge:FireServer({ accepted = true })
end)

bindTactileSpring(declineInviteBtn, function()
	invitePopup.Visible = false
	RespondCustomChallenge:FireServer({ accepted = false })
end)

IncomingCustomChallenge.OnClientEvent:Connect(function(data: any)
	if player:GetAttribute("GlueInDuel") == true then return end
	inviteTitle.Text = string.format("🎯 %s ท้าดวลคุณในโหมด Custom (0 Gold)!", tostring(data and data.challengerName or "ผู้เล่น"))
	invitePopup.Position = UDim2.new(0.5, 0, 0, -160)
	invitePopup.Visible = true
	playSFX("rbxassetid://9119713951", 1.15, 0.5)
	TweenService:Create(invitePopup, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 22),
	}):Play()
end)

---------------------------------------------------------------------
-- 🔄 ฟังก์ชันเปิดหน้าต่างโมดอล & ซิงก์ข้อมูลผู้เล่น
---------------------------------------------------------------------
openModal = function(modalName: string)
	closeAllModals()
	local target = modals[modalName]
	if not target then return end

	if modalName == "Album" or modalName == "Quests" then
		local ok, data = pcall(function()
			return GetCollection:InvokeServer()
		end)
		if ok and type(data) == "table" then
			clientState.collection = data.collection or clientState.collection
			clientState.allCards = data.allCards or clientState.allCards
			clientState.questsClaimed = data.questsClaimed or clientState.questsClaimed
		end
		if modalName == "Album" then
			refreshAlbumGrid()
		else
			refreshQuestsUI()
		end
	elseif modalName == "Play" then
		refreshCustomPlayerList()
	end

	modalBackdrop.Visible = true
	target.Visible = true
	local sc = target:FindFirstChildOfClass("UIScale")
	if sc then
		sc.Scale = 0.85
		TweenService:Create(sc, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end
end

local function updateHUDStats(newGold: number?)
	local oldGold = clientState.gold
	clientState.gold = tonumber(newGold or player:GetAttribute("Gold")) or clientState.gold
	clientState.wins = tonumber(player:GetAttribute("GlueWins")) or clientState.wins
	clientState.losses = tonumber(player:GetAttribute("GlueLosses")) or clientState.losses
	clientState.streak = tonumber(player:GetAttribute("GlueStreak")) or clientState.streak

	goldAmountLabel.Text = string.format("🪙 %d Gold", clientState.gold)
	statSubLabel.Text = string.format("🏆 ชนะ %d  •  🔥 สตรีค %d", clientState.wins, clientState.streak)

	local totalMatches = clientState.wins + clientState.losses
	local xpTotal = (clientState.wins * 45) + (totalMatches * 15)
	local lv = math.floor(xpTotal / 100) + 1
	local xpCur = xpTotal % 100
	levelLabel.Text = "LV." .. tostring(lv)
	xpText.Text = string.format("XP %d / 100", xpCur)
	TweenService:Create(xpBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(math.clamp(xpCur / 100, 0.08, 1), 0, 1, 0),
	}):Play()

	if clientState.gold ~= oldGold then
		bounceGoldBadge()
	end
end

ProfileChanged.OnClientEvent:Connect(function(data: any)
	if type(data) == "table" then
		if data.Collection then clientState.collection = data.Collection end
		if data.QuestsClaimed then clientState.questsClaimed = data.QuestsClaimed end
		updateHUDStats(data.Gold)
	end
end)

player:GetAttributeChangedSignal("Gold"):Connect(function()
	updateHUDStats()
end)
player:GetAttributeChangedSignal("GlueWins"):Connect(function()
	updateHUDStats()
end)

---------------------------------------------------------------------
-- 4️⃣ Auto HUD Transition (เลื่อนเก็บเมื่อเข้าดวล GlueInDuel = true)
---------------------------------------------------------------------
local function syncDuelTransition()
	local inDuel = player:GetAttribute("GlueInDuel") == true
	if inDuel then
		closeAllModals()
		invitePopup.Visible = false
		clientState.inQueue = false
		TweenService:Create(topLeftContainer, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(22, -140),
		}):Play()
		TweenService:Create(battleDock, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 130),
		}):Play()
		TweenService:Create(quickBar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 140, 0.5, 0),
		}):Play()
	else
		updateHUDStats()
		TweenService:Create(topLeftContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(22, 20),
		}):Play()
		TweenService:Create(battleDock, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -22),
		}):Play()
		TweenService:Create(quickBar, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -20, 0.5, 0),
		}):Play()
	end
end

player:GetAttributeChangedSignal("GlueInDuel"):Connect(syncDuelTransition)
StartPvP.OnClientEvent:Connect(function()
	closeAllModals()
end)

-- หมุนขอบรุ้งอวาตาร์และปุ่มดวลด่วนตลอดเวลา
RunService.RenderStepped:Connect(function(dt: number)
	rainbowGrad.Rotation = (rainbowGrad.Rotation + dt * 95) % 360
	quickGrad.Rotation = (quickGrad.Rotation + dt * 120) % 360
end)

-- โหลดข้อมูลคลังการ์ดเริ่มต้น
task.spawn(function()
	local ok, data = pcall(function()
		return GetCollection:InvokeServer()
	end)
	if ok and type(data) == "table" then
		clientState.collection = data.collection or {}
		clientState.allCards = data.allCards or {}
		clientState.questsClaimed = data.questsClaimed or {}
		updateHUDStats(data.gold)
	else
		updateHUDStats()
	end
end)