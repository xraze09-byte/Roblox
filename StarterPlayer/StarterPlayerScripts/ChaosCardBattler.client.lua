--!strict
--[[
	⚔️ ChaosCardBattler.client.lua — หน้าจอสนามประลอง Gawa Card Battle
	• สไตล์ Manga Chaos Meets Tactile Arcade (Anti-AI Slop)
	• กระดานประลอง 3 ช่องต่อฝั่ง:
	  - ฝั่งเรา: สีน้ำเงินอาร์เคด Color3.fromRGB(30, 60, 110)
	  - ฝั่งศัตรู: สีแดงคอมมิก Color3.fromRGB(110, 30, 50)
	  - แสงออร่าเรืองเมื่อการ์ดพร้อมโจมตี
	• สถานะฮีโร่:
	  - หลอดเลือด 8,000 LP พร้อม Ghost Chip Damage (หลอดสีขาวลดตามหลัง)
	  - คริสตัลมานา 10 เม็ด (รูปข้าวหลามตัดเรืองแสงฟ้า)
	  - หลอดกาวไม้ตาย (🧪 Glue Gauge 0–100%) เต็ม 100% ปุ่มอัลติสว่างวาบพร้อมยิงลำแสงกาว
	• ความมีมและความปั่นในสนาม:
	  - ตัวเลขดาเมจลอยขึ้นแบบ Punch Pop พร้อมสุ่มมุมเอียง
	  - บอลลูนคำพูดกวนประสาท (Speech Bubbles) บนหัวอวาตาร์
	  - คลิกจิ้มหัวอวาตาร์คู่ต่อสู้เพื่อกวนประสาท (Poke) ได้จนคู่ต่อสู้โมโห
	  - แบนเนอร์มังงะเปิดเทิร์นขนาดใหญ่: "ตาคุณแล้ว! 😎" / "ตาของคู่ต่อสู้ ⚔️"
	• รองรับครบทั้ง PvE บอท 5 ระดับ + Real PvP 1v1 + Custom Mode (0 Gold)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("GlueCardGame")
if oldGui then oldGui:Destroy() end

local remotes = ReplicatedStorage:WaitForChild("GlueCardRemotes")
local OpenTable = remotes:WaitForChild("OpenTable") :: RemoteEvent
local LeaveTable = remotes:WaitForChild("LeaveTable") :: RemoteEvent
local NewMatch = remotes:WaitForChild("NewMatch") :: RemoteFunction
local ReportResult = remotes:WaitForChild("ReportResult") :: RemoteFunction
local StartPvP = remotes:WaitForChild("StartPvP") :: RemoteEvent
local PvPAction = remotes:WaitForChild("PvPAction") :: RemoteEvent
local PvPActionRelay = remotes:WaitForChild("PvPActionRelay") :: RemoteEvent
local PvPMatchEnd = remotes:WaitForChild("PvPMatchEnd") :: RemoteEvent

---------------------------------------------------------------------
-- 🎨 ชุดสี Manga Chaos Arcade
---------------------------------------------------------------------
local Palette = {
	InkDeep = Color3.fromRGB(18, 14, 28),
	InkPanel = Color3.fromRGB(28, 24, 46),
	BoardMe = Color3.fromRGB(30, 60, 110),
	BoardEnemy = Color3.fromRGB(110, 30, 50),
	Gold = Color3.fromRGB(255, 214, 10),
	Slime = Color3.fromRGB(0, 240, 160),
	Magenta = Color3.fromRGB(255, 64, 168),
	Crimson = Color3.fromRGB(255, 59, 86),
	Cyan = Color3.fromRGB(56, 175, 255),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(175, 170, 205),
}

---------------------------------------------------------------------
-- 🃏 ข้อมูลการ์ดกาวทั้ง 26 ใบพร้อมความสามารถครบ 100%
---------------------------------------------------------------------
export type CardTemplate = {
	id: string,
	name: string,
	emoji: string,
	rarity: string,
	cardType: "Monster" | "Spell",
	cost: number,
	atk: number,
	hp: number,
	desc: string,
	rush: boolean?,
	taunt: boolean?,
	rebirth: boolean?,
	dodge: number?,
	missChance: number?,
}

local CARD_POOL: { CardTemplate } = {
	-- 17 Monsters
	{ id = "chicken", name = "ไก่ย่างอมตะ", emoji = "🐔", rarity = "Common", cardType = "Monster", cost = 2, atk = 700, hp = 800, desc = "ตายแล้วฟื้นคืนชีพ 1 ครั้ง", rebirth = true },
	{ id = "cat", name = "แมวส้มจอมป่วน", emoji = "🐈", rarity = "Common", cardType = "Monster", cost = 2, atk = 900, hp = 700, desc = "ซิ่ง! ตีได้ทันทีที่ลงสนาม", rush = true },
	{ id = "dog", name = "หมาวัดตัวตึง", emoji = "🐕", rarity = "Common", cardType = "Monster", cost = 3, atk = 800, hp = 1500, desc = "โล่! ศัตรูต้องตีตัวนี้ก่อน", taunt = true },
	{ id = "frog", name = "กบร้องเพลงลูกทุ่ง", emoji = "🐸", rarity = "Common", cardType = "Monster", cost = 3, atk = 800, hp = 1000, desc = "ลงสนาม: เรียกลูกอ๊อดวัยซนมาช่วย" },
	{ id = "uncle", name = "ลุงวินซิ่งนรก", emoji = "🛵", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1400, hp = 1100, desc = "ซิ่งพุ่งชนทันที!", rush = true },
	{ id = "raccoon", name = "แรคคูนขโมยหมูปิ้ง", emoji = "🦝", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1000, hp = 1200, desc = "ต้นเทิร์นดูด 300 LP จากศัตรู" },
	{ id = "monkey", name = "ลิงขโมยมือถือ", emoji = "🐒", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1100, hp = 1000, desc = "ดูด LP + หลบหลีก 25%", dodge = 0.25 },
	{ id = "durian", name = "ทุเรียนพลีชีพ", emoji = "🍈", rarity = "Rare", cardType = "Monster", cost = 3, atk = 900, hp = 1100, desc = "ตายแล้วระเบิดกลิ่น 600 ทุกตัว" },
	{ id = "ninja", name = "นินจาหนีหนี้", emoji = "🥷", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1500, hp = 1000, desc = "หลบการโจมตีเก่ง 40%", dodge = 0.40 },
	{ id = "zombie", name = "ซอมบี้มนุษย์เงินเดือน", emoji = "🧟", rarity = "Common", cardType = "Monster", cost = 4, atk = 1100, hp = 1400, desc = "ฟื้นชีพมาทำงานต่อ", rebirth = true },
	{ id = "dino", name = "ไดโนแขนสั้น", emoji = "🦖", rarity = "Legendary", cardType = "Monster", cost = 5, atk = 2300, hp = 1800, desc = "ตีแรงแต่โอกาสวืด 25%", missChance = 0.25 },
	{ id = "grandma", name = "ยายรองเท้าแตะ", emoji = "👵", rarity = "Legendary", cardType = "Monster", cost = 4, atk = 1300, hp = 1400, desc = "ลงสนาม: ปารองเท้าแตะ 700" },
	{ id = "wizard", name = "พ่อมดไลฟ์สด", emoji = "🧙", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1100, hp = 1200, desc = "ลงสนาม: จั่วการ์ดเพิ่ม 2 ใบ" },
	{ id = "buffalo", name = "ควายบึ้กพลังช้าง", emoji = "🐃", rarity = "Legendary", cardType = "Monster", cost = 6, atk = 2000, hp = 2400, desc = "โล่ + ซิ่ง วิ่งชนแหลก", rush = true, taunt = true },
	{ id = "clown", name = "ตัวตลกหัวร้อน", emoji = "🤡", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1200, hp = 1200, desc = "ลงสนาม: สลับ ATK/HP ศัตรู" },
	{ id = "duck", name = "เป็ดยางพิฆาต", emoji = "🦆", rarity = "Common", cardType = "Monster", cost = 2, atk = 800, hp = 700, desc = "หลบ 30% + ตายระเบิด 450", dodge = 0.30 },
	{ id = "dragon", name = "มังกรกาวพันปี", emoji = "🐉", rarity = "Glue", cardType = "Monster", cost = 7, atk = 2500, hp = 2500, desc = "ลงสนาม: เติมหลอดกาว +50%!", rush = true },
	-- 9 Spells
	{ id = "banana", name = "เปลือกกล้วย", emoji = "🍌", rarity = "Common", cardType = "Spell", cost = 2, atk = 0, hp = 0, desc = "กับดัก: ศัตรูตีครั้งถัดไปลื่นล้ม!" },
	{ id = "slipper", name = "รองเท้าแตะแม่", emoji = "👡", rarity = "Rare", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ปาใส่ตัวเก่งสุดศัตรู 1,500 ดาเมจ" },
	{ id = "bomb", name = "ระเบิดปลาร้า", emoji = "💣", rarity = "Rare", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ดาเมจ 800 ใส่มอนศัตรูทุกตัว" },
	{ id = "dice", name = "ลูกเต๋ากาว", emoji = "🎲", rarity = "Glue", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "ทอยเต๋า 1-6 สุ่มผลสุดปั่น!" },
	{ id = "mookata", name = "หมูกระทะฟื้นพลัง", emoji = "🥓", rarity = "Common", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "ฟื้น 1,500 LP และฮีลมอนเราทุกตัว" },
	{ id = "momcall", name = "เสียงแม่เรียก", emoji = "📢", rarity = "Rare", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "สั่งมอนศัตรูกลับบ้าน (ขึ้นมือ)" },
	{ id = "coffee", name = "กาแฟ 3 แก้ว", emoji = "☕", rarity = "Legendary", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "มอนเราทุกตัว ATK +300 และตีซ้ำได้" },
	{ id = "lag", name = "เน็ตหลุด", emoji = "📶", rarity = "Legendary", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "แช่แข็งมอนศัตรูทุกตัว 1 เทิร์น" },
	{ id = "gluetube", name = "กาวตราช้าง", emoji = "🧪", rarity = "Glue", cardType = "Spell", cost = 2, atk = 0, hp = 0, desc = "เติมหลอดกาว +35% และจั่ว 1 ใบ" },
}

local CARD_BY_ID: { [string]: CardTemplate } = {}
for _, c in ipairs(CARD_POOL) do
	CARD_BY_ID[c.id] = c
end
-- โทเคนพิเศษสำหรับกบและลูกเต๋ากาว
CARD_BY_ID["tadpole"] = { id = "tadpole", name = "ลูกอ๊อดวัยซน", emoji = "🫧", rarity = "Common", cardType = "Monster", cost = 1, atk = 500, hp = 500, desc = "ลูกสมุนของกบร้องเพลงลูกทุ่ง", rush = true }
CARD_BY_ID["unicorn"] = { id = "unicorn", name = "ยูนิคอร์นสายรุ้ง", emoji = "🦄", rarity = "Glue", cardType = "Monster", cost = 5, atk = 2200, hp = 2000, desc = "เสกจากลูกเต๋ากาวหน้า 6!", rush = true }

---------------------------------------------------------------------
-- 🔊 ตัวช่วยสร้าง UI & เสียง
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

local function bindSpring(btn: GuiButton, onClick: () -> ())
	local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
	btn.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	end)
	btn.Activated:Connect(function()
		playSFX("rbxassetid://6895079853", 1.02, 0.4)
		TweenService:Create(sc, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
		task.delay(0.08, function()
			if sc and sc.Parent then
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
			end
		end)
		onClick()
	end)
end

---------------------------------------------------------------------
-- 🖥️ สร้างหน้าจอสนามประลอง (Chaos Battle Screen)
---------------------------------------------------------------------
local battleGui = Instance.new("ScreenGui")
battleGui.Name = "GlueCardGame"
battleGui.IgnoreGuiInset = true
battleGui.ResetOnSpawn = false
battleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
battleGui.DisplayOrder = 10
battleGui.Enabled = false
battleGui.Parent = playerGui

local battleScale = Instance.new("UIScale")
battleScale.Parent = battleGui

local function syncScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	battleScale.Scale = math.clamp(math.min(vp.X / 1366, vp.Y / 768), 0.65, 1.15)
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(syncScale)
	syncScale()
end

local rootFrame = Instance.new("Frame")
rootFrame.Size = UDim2.fromScale(1, 1)
rootFrame.BackgroundColor3 = Palette.InkDeep
rootFrame.BackgroundTransparency = 0.22
rootFrame.Parent = battleGui

-- ฟังก์ชันเขย่าหน้าจอ (Screen Shake)
local function shakeScreen(intensity: number)
	if player:GetAttribute("GlueShake") == false then return end
	task.spawn(function()
		for i = 1, 6 do
			rootFrame.Position = UDim2.fromOffset(math.random(-intensity, intensity), math.random(-intensity, intensity))
			task.wait(0.03)
		end
		rootFrame.Position = UDim2.fromOffset(0, 0)
	end)
end

-- ตัวเลขดาเมจลอยขึ้นแบบ Punch Pop พร้อมสุ่มมุมเอียง
local function spawnPunchPopText(worldPos: UDim2, text: string, color: Color3)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(260, 54)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = worldPos
	lbl.Rotation = math.random(-14, 14)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextSize = 34
	lbl.ZIndex = 60
	lbl.Parent = rootFrame
	addStroke(lbl, Palette.InkDeep, 3)

	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = lbl

	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.18 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = worldPos - UDim2.fromOffset(0, 68),
		TextTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		if lbl then lbl:Destroy() end
	end)
end

---------------------------------------------------------------------
-- 🦸 แผงสถานะฮีโร่ (Hero Status: 8,000 LP + Ghost Chip Damage + 10 Mana Crystals)
---------------------------------------------------------------------
type HeroBarUI = {
	panel: Frame,
	avatarBtn: ImageButton,
	nameLabel: TextLabel,
	lpLabel: TextLabel,
	ghostBar: Frame,
	hpBar: Frame,
	manaGems: { Frame },
	bubble: Frame,
	bubbleText: TextLabel,
}

local function createHeroStatusBar(isMe: boolean): HeroBarUI
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(470, 94)
	panel.Position = isMe and UDim2.new(0, 24, 1, -116) or UDim2.fromOffset(24, 18)
	panel.BackgroundColor3 = Palette.InkPanel
	panel.ZIndex = 15
	panel.Parent = rootFrame
	addCorner(panel, 18)
	addStroke(panel, isMe and Palette.Slime or Palette.Crimson, 3.2)

	local avatarBtn = Instance.new("ImageButton")
	avatarBtn.Size = UDim2.fromOffset(72, 72)
	avatarBtn.Position = UDim2.fromOffset(12, 11)
	avatarBtn.BackgroundColor3 = Palette.InkDeep
	avatarBtn.AutoButtonColor = false
	avatarBtn.ZIndex = 16
	avatarBtn.Parent = panel
	addCorner(avatarBtn, 36)
	addStroke(avatarBtn, isMe and Palette.Slime or Palette.Crimson, 3)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromOffset(210, 24)
	nameLabel.Position = UDim2.fromOffset(96, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = isMe and player.DisplayName or "🤖 บอทลุงกาว"
	nameLabel.TextColor3 = Palette.White
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 16
	nameLabel.Parent = panel
	addStroke(nameLabel, Palette.InkDeep, 2)

	local lpLabel = Instance.new("TextLabel")
	lpLabel.Size = UDim2.fromOffset(150, 24)
	lpLabel.Position = UDim2.fromOffset(304, 8)
	lpLabel.BackgroundTransparency = 1
	lpLabel.Font = Enum.Font.FredokaOne
	lpLabel.Text = "8000 / 8000 LP"
	lpLabel.TextColor3 = Palette.Gold
	lpLabel.TextSize = 17
	lpLabel.TextXAlignment = Enum.TextXAlignment.Right
	lpLabel.ZIndex = 16
	lpLabel.Parent = panel
	addStroke(lpLabel, Palette.InkDeep, 2)

	-- หลอดเลือด LP พร้อม Ghost Chip Damage สีขาวลดตามหลัง
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.fromOffset(358, 22)
	barBg.Position = UDim2.fromOffset(96, 35)
	barBg.BackgroundColor3 = Palette.InkDeep
	barBg.ClipsDescendants = true
	barBg.ZIndex = 16
	barBg.Parent = panel
	addCorner(barBg, 10)
	addStroke(barBg, Palette.InkDeep, 2.5)

	local ghostBar = Instance.new("Frame")
	ghostBar.Size = UDim2.fromScale(1, 1)
	ghostBar.BackgroundColor3 = Palette.White
	ghostBar.BorderSizePixel = 0
	ghostBar.ZIndex = 17
	ghostBar.Parent = barBg
	addCorner(ghostBar, 10)

	local hpBar = Instance.new("Frame")
	hpBar.Size = UDim2.fromScale(1, 1)
	hpBar.BackgroundColor3 = isMe and Palette.Slime or Palette.Crimson
	hpBar.BorderSizePixel = 0
	hpBar.ZIndex = 18
	hpBar.Parent = barBg
	addCorner(hpBar, 10)

	-- คริสตัลมานา 10 เม็ด (รูปข้าวหลามตัดเรืองแสงฟ้า)
	local manaRow = Instance.new("Frame")
	manaRow.Size = UDim2.fromOffset(358, 24)
	manaRow.Position = UDim2.fromOffset(96, 63)
	manaRow.BackgroundTransparency = 1
	manaRow.ZIndex = 16
	manaRow.Parent = panel

	local manaGems: { Frame } = {}
	for i = 1, 10 do
		local gem = Instance.new("Frame")
		gem.Size = UDim2.fromOffset(16, 16)
		gem.Position = UDim2.fromOffset((i - 1) * 32 + 6, 4)
		gem.Rotation = 45
		gem.BackgroundColor3 = Palette.Cyan
		gem.ZIndex = 17
		gem.Parent = manaRow
		addCorner(gem, 4)
		addStroke(gem, Palette.InkDeep, 2)
		table.insert(manaGems, gem)
	end

	-- บอลลูนคำพูดกวนประสาท (Speech Bubble)
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(230, 44)
	bubble.Position = isMe and UDim2.fromOffset(20, -52) or UDim2.fromOffset(480, 18)
	bubble.Rotation = isMe and -2 or 2
	bubble.BackgroundColor3 = Palette.White
	bubble.Visible = false
	bubble.ZIndex = 35
	bubble.Parent = panel
	addCorner(bubble, 14)
	addStroke(bubble, Palette.InkDeep, 2.8)

	local bubbleText = Instance.new("TextLabel")
	bubbleText.Size = UDim2.new(1, -16, 1, 0)
	bubbleText.Position = UDim2.fromOffset(8, 0)
	bubbleText.BackgroundTransparency = 1
	bubbleText.Font = Enum.Font.FredokaOne
	bubbleText.Text = "กาวจัดปลัดบอก! 😎"
	bubbleText.TextColor3 = Palette.InkDeep
	bubbleText.TextSize = 15
	bubbleText.TextWrapped = true
	bubbleText.ZIndex = 36
	bubbleText.Parent = bubble

	return {
		panel = panel,
		avatarBtn = avatarBtn,
		nameLabel = nameLabel,
		lpLabel = lpLabel,
		ghostBar = ghostBar,
		hpBar = hpBar,
		manaGems = manaGems,
		bubble = bubble,
		bubbleText = bubbleText,
	}
end

local myHeroUI = createHeroStatusBar(true)
local enemyHeroUI = createHeroStatusBar(false)

task.spawn(function()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and url then
		myHeroUI.avatarBtn.Image = url
	end
end)

local function showSpeechBubble(heroUI: HeroBarUI, msg: string)
	heroUI.bubbleText.Text = msg
	heroUI.bubble.Visible = true
	local sc = heroUI.bubble:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", heroUI.bubble)
	sc.Scale = 0.4
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	task.delay(2.4, function()
		if heroUI.bubbleText.Text == msg then
			heroUI.bubble.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- 🧪 หลอดกาวไม้ตาย (Glue Gauge 0–100%) + ปุ่มจบเทิร์น + ปุ่มออกจากโต๊ะ
---------------------------------------------------------------------
local rightActionPanel = Instance.new("Frame")
rightActionPanel.Size = UDim2.fromOffset(220, 260)
rightActionPanel.AnchorPoint = Vector2.new(1, 0.5)
rightActionPanel.Position = UDim2.new(1, -22, 0.5, 0)
rightActionPanel.BackgroundColor3 = Palette.InkPanel
rightActionPanel.ZIndex = 18
rightActionPanel.Parent = rootFrame
addCorner(rightActionPanel, 20)
addStroke(rightActionPanel, Palette.InkDeep, 3.2)

local glueGaugeBg = Instance.new("Frame")
glueGaugeBg.Size = UDim2.new(1, -28, 0, 28)
glueGaugeBg.Position = UDim2.fromOffset(14, 16)
glueGaugeBg.BackgroundColor3 = Palette.InkDeep
glueGaugeBg.ZIndex = 19
glueGaugeBg.Parent = rightActionPanel
addCorner(glueGaugeBg, 10)
addStroke(glueGaugeBg, Palette.Magenta, 2.2)

local glueGaugeFill = Instance.new("Frame")
glueGaugeFill.Size = UDim2.fromScale(0, 1)
glueGaugeFill.BackgroundColor3 = Palette.Magenta
glueGaugeFill.BorderSizePixel = 0
glueGaugeFill.ZIndex = 20
glueGaugeFill.Parent = glueGaugeBg
addCorner(glueGaugeFill, 10)

local glueGaugeLabel = Instance.new("TextLabel")
glueGaugeLabel.Size = UDim2.fromScale(1, 1)
glueGaugeLabel.BackgroundTransparency = 1
glueGaugeLabel.Font = Enum.Font.FredokaOne
glueGaugeLabel.Text = "🧪 กาว 0%"
glueGaugeLabel.TextColor3 = Palette.White
glueGaugeLabel.TextSize = 15
glueGaugeLabel.ZIndex = 21
glueGaugeLabel.Parent = glueGaugeBg
addStroke(glueGaugeLabel, Palette.InkDeep, 1.8)

local function makeActionBtn(text: string, color: Color3, yPos: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -28, 0, 54)
	b.Position = UDim2.fromOffset(14, yPos)
	b.BackgroundColor3 = color
	b.AutoButtonColor = false
	b.Font = Enum.Font.FredokaOne
	b.Text = text
	b.TextColor3 = Palette.White
	b.TextSize = 19
	b.ZIndex = 20
	b.Parent = rightActionPanel
	addCorner(b, 14)
	addStroke(b, Palette.InkDeep, 2.8)
	return b
end

local ultBtn = makeActionBtn("🧪 อัลติกาว (เต็ม 100%)", Palette.InkDeep, 56)
local endTurnBtn = makeActionBtn("⏭️ จบเทิร์น [Space]", Palette.Slime, 122)
local forfeitBtn = makeActionBtn("🚪 ออกจากโต๊ะ", Palette.Crimson, 188)

---------------------------------------------------------------------
-- 🏟️ กระดานประลอง 3 ช่องต่อฝั่ง (ฝั่งเรา น้ำเงิน 30,60,110 / ศัตรู แดง 110,30,50)
---------------------------------------------------------------------
local boardContainer = Instance.new("Frame")
boardContainer.Size = UDim2.fromOffset(660, 380)
boardContainer.AnchorPoint = Vector2.new(0.5, 0.5)
boardContainer.Position = UDim2.new(0.5, -20, 0.44, 0)
boardContainer.BackgroundTransparency = 1
boardContainer.ZIndex = 12
boardContainer.Parent = rootFrame

local enemySlotsUI: { TextButton } = {}
local mySlotsUI: { TextButton } = {}

for i = 1, 3 do
	-- ช่องฝั่งศัตรู: สีแดงคอมมิก Color3.fromRGB(110, 30, 50)
	local eSlot = Instance.new("TextButton")
	eSlot.Name = "EnemySlot_" .. i
	eSlot.Size = UDim2.fromOffset(195, 172)
	eSlot.Position = UDim2.fromOffset((i - 1) * 222 + 12, 6)
	eSlot.BackgroundColor3 = Palette.BoardEnemy
	eSlot.AutoButtonColor = false
	eSlot.Text = ""
	eSlot.ZIndex = 13
	eSlot.Parent = boardContainer
	addCorner(eSlot, 16)
	addStroke(eSlot, Palette.Crimson, 3)
	enemySlotsUI[i] = eSlot

	-- ช่องฝั่งเรา: สีน้ำเงินอาร์เคด Color3.fromRGB(30, 60, 110)
	local mSlot = Instance.new("TextButton")
	mSlot.Name = "MySlot_" .. i
	mSlot.Size = UDim2.fromOffset(195, 172)
	mSlot.Position = UDim2.fromOffset((i - 1) * 222 + 12, 198)
	mSlot.BackgroundColor3 = Palette.BoardMe
	mSlot.AutoButtonColor = false
	mSlot.Text = ""
	mSlot.ZIndex = 13
	mSlot.Parent = boardContainer
	addCorner(mSlot, 16)
	addStroke(mSlot, Palette.Cyan, 3)
	mySlotsUI[i] = mSlot
end

-- แผงการ์ดบนมือเราด้านล่าง
local handBar = Instance.new("Frame")
handBar.Size = UDim2.fromOffset(760, 175)
handBar.AnchorPoint = Vector2.new(0.5, 1)
handBar.Position = UDim2.new(0.5, 80, 1, -12)
handBar.BackgroundTransparency = 1
handBar.ZIndex = 22
handBar.Parent = rootFrame

local handLayout = Instance.new("UIListLayout")
handLayout.FillDirection = Enum.FillDirection.Horizontal
handLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
handLayout.VerticalAlignment = Enum.VerticalAlignment.Center
handLayout.Padding = UDim.new(0, 10)
handLayout.Parent = handBar

-- แบนเนอร์มังงะเปิดเทิร์นขนาดใหญ่
local turnBanner = Instance.new("Frame")
turnBanner.Size = UDim2.fromOffset(540, 84)
turnBanner.AnchorPoint = Vector2.new(0.5, 0.5)
turnBanner.Position = UDim2.fromScale(0.5, 0.45)
turnBanner.Rotation = -3
turnBanner.BackgroundColor3 = Palette.InkPanel
turnBanner.Visible = false
turnBanner.ZIndex = 55
turnBanner.Parent = rootFrame
addCorner(turnBanner, 18)
local turnBannerStroke = addStroke(turnBanner, Palette.Gold, 4)

local turnBannerText = Instance.new("TextLabel")
turnBannerText.Size = UDim2.fromScale(1, 1)
turnBannerText.BackgroundTransparency = 1
turnBannerText.Font = Enum.Font.FredokaOne
turnBannerText.Text = "ตาคุณแล้ว! 😎"
turnBannerText.TextColor3 = Palette.Gold
turnBannerText.TextSize = 36
turnBannerText.ZIndex = 56
turnBannerText.Parent = turnBanner
addStroke(turnBannerText, Palette.InkDeep, 3)

local function showTurnBanner(text: string, color: Color3)
	turnBannerText.Text = text
	turnBannerText.TextColor3 = color
	turnBannerStroke.Color = color
	turnBanner.Visible = true
	local sc = turnBanner:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", turnBanner)
	sc.Scale = 0.25
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	task.delay(1.15, function()
		turnBanner.Visible = false
	end)
end

---------------------------------------------------------------------
-- ⚙️ ระบบสถานะการดวล (Match State & Logic)
---------------------------------------------------------------------
type BoardUnit = {
	id: string,
	name: string,
	emoji: string,
	atk: number,
	hp: number,
	maxHp: number,
	canAttack: boolean,
	frozen: boolean,
	taunt: boolean,
	rebirth: boolean,
	dodge: number,
	missChance: number,
}

local matchState = {
	active = false,
	matchId = "",
	isPvP = false,
	isCustom = false,
	myTurn = true,
	myLP = 8000,
	enemyLP = 8000,
	myMana = 3,
	myMaxMana = 3,
	enemyMana = 3,
	enemyMaxMana = 3,
	myGlue = 0,
	myBananaTrap = false,
	enemyBananaTrap = false,
	myBoard = { nil, nil, nil } :: { BoardUnit? },
	enemyBoard = { nil, nil, nil } :: { BoardUnit? },
	myHand = {} :: { CardTemplate },
	selectedSlot = nil :: number?,
	pokeCount = 0,
	botThinkTime = 0.9,
	botMistakeChance = 0.15,
	botCheatMana = 0,
}

local renderAll: () -> ()
local checkGameOver: () -> boolean

local function updateHeroBarVisual(ui: HeroBarUI, lp: number, mana: number, maxMana: number)
	local ratio = math.clamp(lp / 8000, 0, 1)
	ui.lpLabel.Text = string.format("%d / 8000 LP", math.max(0, lp))
	TweenService:Create(ui.hpBar, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
	-- Ghost Chip Damage สีขาวลดตามหลังอย่างนุ่มนวล
	task.delay(0.32, function()
		TweenService:Create(ui.ghostBar, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(ratio, 1),
		}):Play()
	end)

	for i = 1, 10 do
		local gem = ui.manaGems[i]
		if i <= mana then
			gem.BackgroundColor3 = Palette.Cyan
			gem.BackgroundTransparency = 0
		elseif i <= maxMana then
			gem.BackgroundColor3 = Palette.InkDeep
			gem.BackgroundTransparency = 0.2
		else
			gem.BackgroundColor3 = Palette.InkDeep
			gem.BackgroundTransparency = 0.65
		end
	end
end

local function addGlue(amount: number)
	matchState.myGlue = math.clamp(matchState.myGlue + amount, 0, 100)
	glueGaugeLabel.Text = string.format("🧪 กาว %d%%", matchState.myGlue)
	TweenService:Create(glueGaugeFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(matchState.myGlue / 100, 1),
	}):Play()
	if matchState.myGlue >= 100 then
		ultBtn.BackgroundColor3 = Palette.Magenta
		ultBtn.Text = "💥 ปล่อยอัลติกาว! [พร้อม]"
	else
		ultBtn.BackgroundColor3 = Palette.InkDeep
		ultBtn.Text = "🧪 อัลติกาว (เต็ม 100%)"
	end
end

local function drawCards(count: number)
	for _ = 1, count do
		if #matchState.myHand < 6 then
			local template = CARD_POOL[math.random(1, #CARD_POOL)]
			table.insert(matchState.myHand, template)
		end
	end
end

-- ตรวจสอบการตายและเอฟเฟกต์ Rebirth / ทุเรียน / เป็ดยาง
local function handleUnitDeaths(board: { BoardUnit? }, isMyBoard: boolean)
	for i = 1, 3 do
		local u = board[i]
		if u and u.hp <= 0 then
			if u.rebirth then
				u.rebirth = false
				u.hp = math.floor(u.maxHp * 0.5)
				spawnPunchPopText(UDim2.fromScale(0.5, isMyBoard and 0.62 or 0.28), "🐔 ฟื้นชีพอมตะ!", Palette.Gold)
			else
				local deadId = u.id
				board[i] = nil
				if deadId == "durian" or deadId == "duck" then
					local dmg = (deadId == "durian") and 600 or 450
					local targetBoard = isMyBoard and matchState.enemyBoard or matchState.myBoard
					for j = 1, 3 do
						local enemyU = targetBoard[j]
						if enemyU then
							enemyU.hp -= dmg
						end
					end
					spawnPunchPopText(UDim2.fromScale(0.5, 0.44), (deadId == "durian") and "🍈 ทุเรียนระเบิด -600!" or "🦆 เป็ดยางระเบิด -450!", Palette.Gold)
				end
			end
		end
	end
end

-- จบเกมและส่งผลไปเซิร์ฟเวอร์
local function finishMatch(won: boolean, customMsg: string?)
	if not matchState.active then return end
	matchState.active = false

	showTurnBanner(won and "🏆 ชัยชนะสุดกาว!!" or "💀 พ่ายแพ้ศึกสายกาว...", won and Palette.Gold or Palette.Crimson)
	playSFX(won and "rbxassetid://9119713951" or "rbxassetid://6895079853", won and 1.15 or 0.75, 0.6)

	task.spawn(function()
		pcall(function()
			ReportResult:InvokeServer(matchState.matchId, { won = won, turns = 5 })
		end)
	end)

	task.delay(2.2, function()
		battleGui.Enabled = false
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
		end
	end)
end

checkGameOver = function(): boolean
	if not matchState.active then return true end
	if matchState.enemyLP <= 0 then
		finishMatch(true)
		return true
	elseif matchState.myLP <= 0 then
		finishMatch(false)
		return true
	end
	return false
end

-- สั่งมอนสเตอร์ช่อง mySlot โจมตี
local function executeMyAttack(mySlotIdx: number, targetEnemySlot: number?)
	if not matchState.active or not matchState.myTurn then return end
	local attacker = matchState.myBoard[mySlotIdx]
	if not attacker or not attacker.canAttack or attacker.frozen then return end

	-- ตรวจกับดักเปลือกกล้วยของศัตรู
	if matchState.enemyBananaTrap then
		matchState.enemyBananaTrap = false
		attacker.canAttack = false
		attacker.hp -= 600
		spawnPunchPopText(UDim2.fromScale(0.5, 0.56), "🍌 ลื่นเปลือกกล้วย! -600", Palette.Gold)
		showSpeechBubble(enemyHeroUI, "ฮ่าๆๆ ลื่นกล้วยหัวทิ่ม! 🍌😂")
		handleUnitDeaths(matchState.myBoard, true)
		renderAll()
		return
	end

	-- ตรวจโล่ Taunt ของศัตรู
	local tauntSlot: number? = nil
	for i = 1, 3 do
		local eu = matchState.enemyBoard[i]
		if eu and eu.taunt then
			tauntSlot = i
			break
		end
	end
	if tauntSlot and targetEnemySlot ~= tauntSlot then
		targetEnemySlot = tauntSlot
	end

	-- โอกาสตีวืดของไดโนแขนสั้น
	if attacker.missChance > 0 and math.random() < attacker.missChance then
		attacker.canAttack = false
		matchState.selectedSlot = nil
		spawnPunchPopText(UDim2.fromScale(0.5, 0.34), "🦖 แขนสั้นตีวืด! MISS!", Palette.Muted)
		showSpeechBubble(enemyHeroUI, "แขนสั้นก็งี้แหละน้า~ 😜")
		renderAll()
		return
	end

	attacker.canAttack = false
	matchState.selectedSlot = nil
	addGlue(20)

	local targetUnit = targetEnemySlot and matchState.enemyBoard[targetEnemySlot] or nil
	if targetUnit then
		if targetUnit.dodge > 0 and math.random() < targetUnit.dodge then
			spawnPunchPopText(UDim2.fromScale(0.5, 0.30), "💨 พริ้วจัด! หลบได้!", Palette.Cyan)
		else
			targetUnit.hp -= attacker.atk
			attacker.hp -= math.floor(targetUnit.atk * 0.5)
			if attacker.id == "monkey" then
				matchState.myLP = math.min(8000, matchState.myLP + 250)
				matchState.enemyLP -= 250
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.30), string.format("💥 -%d!", attacker.atk), Palette.Crimson)
			shakeScreen(6)
		end
	else
		-- โจมตีเข้าตัวฮีโร่ศัตรูโดยตรง
		matchState.enemyLP -= attacker.atk
		spawnPunchPopText(UDim2.fromScale(0.35, 0.12), string.format("💥 -%d LP!", attacker.atk), Palette.Crimson)
		showSpeechBubble(enemyHeroUI, "โอ๊ย! ตีหน้ากันเลยเหรอ! 💢")
		shakeScreen(9)
	end

	if matchState.isPvP then
		PvPAction:FireServer({
			action = "Attack",
			attackerSlot = mySlotIdx,
			targetSlot = targetEnemySlot,
			damage = attacker.atk,
		})
	end

	handleUnitDeaths(matchState.enemyBoard, false)
	handleUnitDeaths(matchState.myBoard, true)
	renderAll()
	checkGameOver()
end

-- เล่นการ์ดจากมือ
local function playCardFromHand(handIndex: number)
	if not matchState.active or not matchState.myTurn then return end
	local card = matchState.myHand[handIndex]
	if not card then return end
	if matchState.myMana < card.cost then
		spawnPunchPopText(UDim2.fromScale(0.5, 0.78), "💧 มานาไม่พอ!", Palette.Cyan)
		return
	end

	if card.cardType == "Monster" then
		local freeSlot: number? = nil
		for i = 1, 3 do
			if matchState.myBoard[i] == nil then
				freeSlot = i
				break
			end
		end
		if not freeSlot then
			spawnPunchPopText(UDim2.fromScale(0.5, 0.65), "⚠️ ช่องมอนสเตอร์เต็มแล้ว!", Palette.Gold)
			return
		end

		matchState.myMana -= card.cost
		table.remove(matchState.myHand, handIndex)

		local newUnit: BoardUnit = {
			id = card.id,
			name = card.name,
			emoji = card.emoji,
			atk = card.atk,
			hp = card.hp,
			maxHp = card.hp,
			canAttack = (card.rush == true),
			frozen = false,
			taunt = (card.taunt == true),
			rebirth = (card.rebirth == true),
			dodge = card.dodge or 0,
			missChance = card.missChance or 0,
		}
		matchState.myBoard[freeSlot] = newUnit
		addGlue(15)

		-- เอฟเฟกต์เมื่อลงสนาม (Battlecry)
		if card.id == "frog" then
			for i = 1, 3 do
				if matchState.myBoard[i] == nil then
					local tad = CARD_BY_ID["tadpole"]
					matchState.myBoard[i] = {
						id = tad.id, name = tad.name, emoji = tad.emoji,
						atk = tad.atk, hp = tad.hp, maxHp = tad.hp,
						canAttack = true, frozen = false, taunt = false, rebirth = false, dodge = 0, missChance = 0,
					}
					break
				end
			end
		elseif card.id == "grandma" then
			matchState.enemyLP -= 700
			spawnPunchPopText(UDim2.fromScale(0.45, 0.16), "👵 ยายปาแตะ -700!", Palette.Gold)
		elseif card.id == "wizard" then
			drawCards(2)
			spawnPunchPopText(UDim2.fromScale(0.5, 0.62), "🧙 ไลฟ์สดจั่ว +2 ใบ!", Palette.Cyan)
		elseif card.id == "clown" then
			for i = 1, 3 do
				local eu = matchState.enemyBoard[i]
				if eu then
					eu.atk, eu.hp = eu.hp, eu.atk
					eu.maxHp = math.max(eu.maxHp, eu.hp)
				end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.34), "🤡 สลับ ATK/HP ศัตรู!", Palette.Magenta)
		elseif card.id == "dragon" then
			addGlue(50)
			spawnPunchPopText(UDim2.fromScale(0.5, 0.52), "🐉 มังกรกาว +50% GLUE!", Palette.Magenta)
		end

		if matchState.isPvP then
			PvPAction:FireServer({
				action = "PlayCard",
				cardId = card.id,
				slot = freeSlot,
			})
		end
	else
		-- การ์ดเวทมนตร์ทั้ง 9 ใบ
		matchState.myMana -= card.cost
		table.remove(matchState.myHand, handIndex)
		addGlue(20)

		if card.id == "banana" then
			matchState.myBananaTrap = true
			spawnPunchPopText(UDim2.fromScale(0.5, 0.54), "🍌 วางกับดักเปลือกกล้วย!", Palette.Gold)
		elseif card.id == "slipper" then
			local bestSlot: number? = nil
			local bestAtk = -1
			for i = 1, 3 do
				local eu = matchState.enemyBoard[i]
				if eu and eu.atk > bestAtk then
					bestAtk = eu.atk
					bestSlot = i
				end
			end
			if bestSlot and matchState.enemyBoard[bestSlot] then
				(matchState.enemyBoard[bestSlot] :: BoardUnit).hp -= 1500
			else
				matchState.enemyLP -= 1500
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.28), "👡 รองเท้าแตะแม่ -1500!", Palette.Crimson)
			shakeScreen(8)
		elseif card.id == "bomb" then
			for i = 1, 3 do
				local eu = matchState.enemyBoard[i]
				if eu then eu.hp -= 800 end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.28), "💣 ระเบิดปลาร้า -800 ทุกตัว!", Palette.Gold)
			shakeScreen(9)
		elseif card.id == "dice" then
			local roll = math.random(1, 6)
			if roll == 1 then
				matchState.myLP -= 500
				spawnPunchPopText(UDim2.fromScale(0.5, 0.65), "🎲 ทอยได้ 1! เจ็บเอง -500!", Palette.Crimson)
			elseif roll <= 4 then
				matchState.enemyLP -= 1000
				spawnPunchPopText(UDim2.fromScale(0.5, 0.28), string.format("🎲 ทอยได้ %d! ศัตรู -1000 LP!", roll), Palette.Gold)
			else
				for i = 1, 3 do
					if matchState.myBoard[i] == nil then
						local uni = CARD_BY_ID["unicorn"]
						matchState.myBoard[i] = {
							id = uni.id, name = uni.name, emoji = uni.emoji,
							atk = uni.atk, hp = uni.hp, maxHp = uni.hp,
							canAttack = true, frozen = false, taunt = false, rebirth = false, dodge = 0, missChance = 0,
						}
						break
					end
				end
				spawnPunchPopText(UDim2.fromScale(0.5, 0.52), "🎲 หน้า 6! เสกยูนิคอร์นสายรุ้ง 🦄!", Palette.Magenta)
			end
		elseif card.id == "mookata" then
			matchState.myLP = math.min(8000, matchState.myLP + 1500)
			for i = 1, 3 do
				local mu = matchState.myBoard[i]
				if mu then mu.hp = math.min(mu.maxHp + 600, mu.hp + 600) end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.65), "🥓 หมูกระทะฟื้นพลัง +1500 LP!", Palette.Slime)
		elseif card.id == "momcall" then
			for i = 1, 3 do
				if matchState.enemyBoard[i] then
					matchState.enemyBoard[i] = nil
					break
				end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.28), "📢 แม่เรียกกลับบ้าน!", Palette.Cyan)
		elseif card.id == "coffee" then
			for i = 1, 3 do
				local mu = matchState.myBoard[i]
				if mu then
					mu.atk += 300
					mu.canAttack = true
				end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.56), "☕ ดีดกาแฟ! ATK+300 & ตีซ้ำ!", Palette.Gold)
		elseif card.id == "lag" then
			for i = 1, 3 do
				local eu = matchState.enemyBoard[i]
				if eu then eu.frozen = true end
			end
			spawnPunchPopText(UDim2.fromScale(0.5, 0.28), "📶 ปิง 999ms! แช่แข็งศัตรูทุกตัว!", Palette.Cyan)
		elseif card.id == "gluetube" then
			addGlue(35)
			drawCards(1)
			spawnPunchPopText(UDim2.fromScale(0.5, 0.58), "🧪 กาวตราช้าง +35% & จั่ว 1 ใบ!", Palette.Magenta)
		end

		if matchState.isPvP then
			PvPAction:FireServer({
				action = "Spell",
				cardId = card.id,
			})
		end
	end

	handleUnitDeaths(matchState.enemyBoard, false)
	handleUnitDeaths(matchState.myBoard, true)
	renderAll()
	checkGameOver()
end

---------------------------------------------------------------------
-- 🤖 ระบบ AI บอท (ปิดอัตโนมัติในโหมด PvP)
---------------------------------------------------------------------
local function runBotTurn()
	if not matchState.active or matchState.isPvP then return end
	showTurnBanner("ตาของคู่ต่อสู้ ⚔️", Palette.Crimson)

	task.wait(matchState.botThinkTime)
	if not matchState.active then return end

	matchState.enemyMaxMana = math.min(10, matchState.enemyMaxMana + 1 + matchState.botCheatMana)
	matchState.enemyMana = matchState.enemyMaxMana

	-- บอทลงมอนสเตอร์ในช่องว่าง
	for i = 1, 3 do
		if matchState.enemyBoard[i] == nil and matchState.enemyMana >= 2 then
			local mPool = {}
			for _, c in ipairs(CARD_POOL) do
				if c.cardType == "Monster" and c.cost <= matchState.enemyMana then
					table.insert(mPool, c)
				end
			end
			if #mPool > 0 then
				local pick = mPool[math.random(1, #mPool)]
				matchState.enemyMana -= pick.cost
				matchState.enemyBoard[i] = {
					id = pick.id, name = pick.name, emoji = pick.emoji,
					atk = pick.atk, hp = pick.hp, maxHp = pick.hp,
					canAttack = true, frozen = false, taunt = (pick.taunt == true),
					rebirth = (pick.rebirth == true), dodge = pick.dodge or 0, missChance = pick.missChance or 0,
				}
				renderAll()
				task.wait(matchState.botThinkTime * 0.65)
			end
		end
	end

	-- บอทสั่งมอนสเตอร์โจมตี
	for i = 1, 3 do
		if not matchState.active then return end
		local eu = matchState.enemyBoard[i]
		if eu and not eu.frozen then
			if matchState.myBananaTrap then
				matchState.myBananaTrap = false
				eu.hp -= 600
				spawnPunchPopText(UDim2.fromScale(0.5, 0.32), "🍌 ศัตรูลื่นเปลือกกล้วย -600!", Palette.Gold)
				handleUnitDeaths(matchState.enemyBoard, false)
				renderAll()
			elseif math.random() > matchState.botMistakeChance then
				local targetSlot: number? = nil
				for j = 1, 3 do
					if matchState.myBoard[j] then
						targetSlot = j
						break
					end
				end
				if targetSlot and matchState.myBoard[targetSlot] then
					local myU = matchState.myBoard[targetSlot] :: BoardUnit
					myU.hp -= eu.atk
					spawnPunchPopText(UDim2.fromScale(0.5, 0.58), string.format("💥 -%d!", eu.atk), Palette.Crimson)
				else
					matchState.myLP -= eu.atk
					spawnPunchPopText(UDim2.fromScale(0.35, 0.85), string.format("💥 -%d LP!", eu.atk), Palette.Crimson)
					showSpeechBubble(myHeroUI, "โอ๊ย! เจ็บจี๊ดดด! 😵")
				end
				shakeScreen(6)
				handleUnitDeaths(matchState.myBoard, true)
				renderAll()
				if checkGameOver() then return end
				task.wait(matchState.botThinkTime * 0.6)
			end
		elseif eu and eu.frozen then
			eu.frozen = false
		end
	end

	-- สลับเข้าเทิร์นผู้เล่น
	matchState.myTurn = true
	matchState.myMaxMana = math.min(10, matchState.myMaxMana + 1)
	matchState.myMana = matchState.myMaxMana
	drawCards(1)

	for i = 1, 3 do
		local mu = matchState.myBoard[i]
		if mu then
			mu.canAttack = true
			mu.frozen = false
			if mu.id == "raccoon" then
				matchState.enemyLP -= 300
				matchState.myLP = math.min(8000, matchState.myLP + 300)
				spawnPunchPopText(UDim2.fromScale(0.5, 0.56), "🦝 แรคคูนดูด 300 LP!", Palette.Slime)
			end
		end
	end

	showTurnBanner("ตาคุณแล้ว! 😎", Palette.Gold)
	renderAll()
	checkGameOver()
end

---------------------------------------------------------------------
-- 🎨 ฟังก์ชันวาดกระดานและการ์ดบนมือ (Render All)
---------------------------------------------------------------------
local function renderSlotUnit(slotBtn: TextButton, unit: BoardUnit?, isMine: boolean, slotIndex: number)
	for _, ch in ipairs(slotBtn:GetChildren()) do
		if ch:IsA("Frame") or ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end

	local stroke = slotBtn:FindFirstChildOfClass("UIStroke")
	if stroke then
		if isMine and matchState.selectedSlot == slotIndex then
			stroke.Color = Palette.Gold
			stroke.Thickness = 4.2
		elseif isMine and unit and unit.canAttack and matchState.myTurn then
			stroke.Color = Palette.Slime -- แสงออร่าเรืองเมื่อการ์ดพร้อมโจมตี
			stroke.Thickness = 3.5
		else
			stroke.Color = isMine and Palette.Cyan or Palette.Crimson
			stroke.Thickness = 2.8
		end
	end

	if not unit then
		local emptyHint = Instance.new("TextLabel")
		emptyHint.Size = UDim2.fromScale(1, 1)
		emptyHint.BackgroundTransparency = 1
		emptyHint.Font = Enum.Font.FredokaOne
		emptyHint.Text = isMine and ("ช่องเรา #" .. slotIndex) or ("ช่องศัตรู #" .. slotIndex)
		emptyHint.TextColor3 = Palette.White
		emptyHint.TextTransparency = 0.72
		emptyHint.TextSize = 16
		emptyHint.ZIndex = 14
		emptyHint.Parent = slotBtn
		return
	end

	local emo = Instance.new("TextLabel")
	emo.Size = UDim2.new(1, 0, 0, 74)
	emo.Position = UDim2.fromOffset(0, 10)
	emo.BackgroundTransparency = 1
	emo.Font = Enum.Font.FredokaOne
	emo.Text = unit.emoji .. (unit.frozen and "❄️" or "") .. (unit.taunt and "🛡️" or "")
	emo.TextSize = 52
	emo.ZIndex = 15
	emo.Parent = slotBtn

	local nm = Instance.new("TextLabel")
	nm.Size = UDim2.new(1, -12, 0, 26)
	nm.Position = UDim2.fromOffset(6, 86)
	nm.BackgroundTransparency = 1
	nm.Font = Enum.Font.FredokaOne
	nm.Text = unit.name
	nm.TextColor3 = Palette.White
	nm.TextSize = 16
	nm.ZIndex = 15
	nm.Parent = slotBtn
	addStroke(nm, Palette.InkDeep, 2)

	local statPill = Instance.new("Frame")
	statPill.Size = UDim2.new(1, -20, 0, 34)
	statPill.Position = UDim2.fromOffset(10, 124)
	statPill.BackgroundColor3 = Palette.InkDeep
	statPill.ZIndex = 15
	statPill.Parent = slotBtn
	addCorner(statPill, 10)
	addStroke(statPill, (isMine and unit.canAttack) and Palette.Slime or Palette.InkPanel, 2)

	local statTxt = Instance.new("TextLabel")
	statTxt.Size = UDim2.fromScale(1, 1)
	statTxt.BackgroundTransparency = 1
	statTxt.Font = Enum.Font.FredokaOne
	statTxt.Text = string.format("⚔ %d   ❤ %d", unit.atk, unit.hp)
	statTxt.TextColor3 = Palette.Gold
	statTxt.TextSize = 16
	statTxt.ZIndex = 16
	statTxt.Parent = statPill
end

renderAll = function()
	updateHeroBarVisual(myHeroUI, matchState.myLP, matchState.myMana, matchState.myMaxMana)
	updateHeroBarVisual(enemyHeroUI, matchState.enemyLP, matchState.enemyMana, matchState.enemyMaxMana)

	for i = 1, 3 do
		renderSlotUnit(mySlotsUI[i], matchState.myBoard[i], true, i)
		renderSlotUnit(enemySlotsUI[i], matchState.enemyBoard[i], false, i)
	end

	-- วาดการ์ดบนมือ
	for _, ch in ipairs(handBar:GetChildren()) do
		if ch:IsA("GuiButton") then ch:Destroy() end
	end

	for idx, c in ipairs(matchState.myHand) do
		local canAfford = matchState.myTurn and (matchState.myMana >= c.cost)
		local cardBtn = Instance.new("TextButton")
		cardBtn.Size = UDim2.fromOffset(118, 162)
		cardBtn.BackgroundColor3 = Palette.InkPanel
		cardBtn.AutoButtonColor = false
		cardBtn.Text = ""
		cardBtn.ZIndex = 25
		cardBtn.Parent = handBar
		addCorner(cardBtn, 14)
		addStroke(cardBtn, canAfford and Palette.Slime or Palette.InkDeep, 3)

		-- เม็ดมานาตรงมุมการ์ด
		local costGem = Instance.new("Frame")
		costGem.Size = UDim2.fromOffset(26, 26)
		costGem.Position = UDim2.fromOffset(6, 6)
		costGem.Rotation = 45
		costGem.BackgroundColor3 = Palette.Cyan
		costGem.ZIndex = 27
		costGem.Parent = cardBtn
		addCorner(costGem, 6)
		addStroke(costGem, Palette.InkDeep, 2)

		local costTxt = Instance.new("TextLabel")
		costTxt.Size = UDim2.fromScale(1, 1)
		costTxt.Rotation = -45
		costTxt.BackgroundTransparency = 1
		costTxt.Font = Enum.Font.FredokaOne
		costTxt.Text = tostring(c.cost)
		costTxt.TextColor3 = Palette.InkDeep
		costTxt.TextSize = 15
		costTxt.ZIndex = 28
		costTxt.Parent = costGem

		local emo = Instance.new("TextLabel")
		emo.Size = UDim2.new(1, 0, 0, 56)
		emo.Position = UDim2.fromOffset(0, 22)
		emo.BackgroundTransparency = 1
		emo.Font = Enum.Font.FredokaOne
		emo.Text = c.emoji
		emo.TextSize = 40
		emo.ZIndex = 26
		emo.Parent = cardBtn

		local nm = Instance.new("TextLabel")
		nm.Size = UDim2.new(1, -8, 0, 22)
		nm.Position = UDim2.fromOffset(4, 80)
		nm.BackgroundTransparency = 1
		nm.Font = Enum.Font.FredokaOne
		nm.Text = c.name
		nm.TextColor3 = Palette.White
		nm.TextSize = 13
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		nm.ZIndex = 26
		nm.Parent = cardBtn
		addStroke(nm, Palette.InkDeep, 1.5)

		local ds = Instance.new("TextLabel")
		ds.Size = UDim2.new(1, -10, 0, 32)
		ds.Position = UDim2.fromOffset(5, 102)
		ds.BackgroundTransparency = 1
		ds.Font = Enum.Font.GothamMedium
		ds.Text = c.desc
		ds.TextColor3 = Palette.Muted
		ds.TextSize = 10
		ds.TextWrapped = true
		ds.ZIndex = 26
		ds.Parent = cardBtn

		local st = Instance.new("TextLabel")
		st.Size = UDim2.new(1, -8, 0, 22)
		st.Position = UDim2.fromOffset(4, 136)
		st.BackgroundTransparency = 1
		st.Font = Enum.Font.FredokaOne
		st.Text = (c.cardType == "Monster") and string.format("⚔%d  ❤%d", c.atk, c.hp) or "✨ เวทมนตร์"
		st.TextColor3 = Palette.Gold
		st.TextSize = 13
		st.ZIndex = 26
		st.Parent = cardBtn

		bindSpring(cardBtn, function()
			playCardFromHand(idx)
		end)
	end
end

---------------------------------------------------------------------
-- 👆 อีเวนต์คลิกกระดาน, ปุ่มอัลติกาว, จบเทิร์น และจิ้มหัวกวนประสาท (Poke)
---------------------------------------------------------------------
for i = 1, 3 do
	bindSpring(mySlotsUI[i], function()
		if not matchState.active or not matchState.myTurn then return end
		local u = matchState.myBoard[i]
		if u and u.canAttack and not u.frozen then
			matchState.selectedSlot = i
			-- ถ้าศัตรูไม่มีมอนสเตอร์บนสนาม ตีเข้าหน้าศัตรูทันที!
			local hasEnemy = false
			for j = 1, 3 do
				if matchState.enemyBoard[j] ~= nil then
					hasEnemy = true
					break
				end
			end
			if not hasEnemy then
				executeMyAttack(i, nil)
			else
				renderAll()
			end
		end
	end)

	bindSpring(enemySlotsUI[i], function()
		if not matchState.active or not matchState.myTurn then return end
		if matchState.selectedSlot then
			executeMyAttack(matchState.selectedSlot, i)
		end
	end)
end

-- จิ้มหัวอวาตาร์คู่ต่อสู้เพื่อกวนประสาท (Poke) จนโมโห!
bindSpring(enemyHeroUI.avatarBtn, function()
	if not matchState.active then return end
	if matchState.myTurn and matchState.selectedSlot then
		executeMyAttack(matchState.selectedSlot, nil)
		return
	end

	matchState.pokeCount += 1
	local angryLines = {
		"เฮ้ย! จิ้มหัวทำไมเนี่ย!? 😠",
		"หยุดจิ้มเดี๋ยวนี้เลยนะเฟ้ย! 💢",
		"จิ้มอีกทีมีเรื่องแน่!! 🤬🔥",
		"ว๊ากกก หัวร้อนแล้วโว้ยยย!! 🌋💥",
	}
	local line = angryLines[math.min(#angryLines, matchState.pokeCount)]
	showSpeechBubble(enemyHeroUI, line)
	spawnPunchPopText(UDim2.fromOffset(110, 75), "👉 จิ้มหัวปั่นประสาท!", Palette.Magenta)
	if matchState.isPvP then
		PvPAction:FireServer({ action = "Taunt", text = "👉 จิ้มหัวกวนประสาท 1 ที! 😜" })
	end
end)

-- ปุ่มปล่อยท่าไม้ตายอัลติกาว (เต็ม 100%)
bindSpring(ultBtn, function()
	if not matchState.active or not matchState.myTurn or matchState.myGlue < 100 then return end
	addGlue(-100)
	matchState.enemyLP -= 1800
	for i = 1, 3 do
		local eu = matchState.enemyBoard[i]
		if eu then eu.hp -= 1000 end
	end
	spawnPunchPopText(UDim2.fromScale(0.5, 0.32), "🧪💥 ลำแสงมหาเวทย์กาวตราช้าง -1800!!", Palette.Magenta)
	showSpeechBubble(myHeroUI, "รับไปซะ!! มหาเวทย์กาวพันปี!! 🧪🌈")
	shakeScreen(14)

	if matchState.isPvP then
		PvPAction:FireServer({ action = "Ult" })
	end

	handleUnitDeaths(matchState.enemyBoard, false)
	renderAll()
	checkGameOver()
end)

-- ปุ่มจบเทิร์น
bindSpring(endTurnBtn, function()
	if not matchState.active or not matchState.myTurn then return end
	matchState.myTurn = false
	matchState.selectedSlot = nil
	renderAll()

	if matchState.isPvP then
		showTurnBanner("ตาของคู่ต่อสู้ ⚔️", Palette.Crimson)
		PvPAction:FireServer({ action = "EndTurn" })
	else
		task.spawn(runBotTurn)
	end
end)

-- ปุ่มออกจากโต๊ะ (Forfeit)
bindSpring(forfeitBtn, function()
	if not matchState.active then return end
	matchState.active = false
	LeaveTable:FireServer()
	battleGui.Enabled = false
	local cam = workspace.CurrentCamera
	if cam then cam.CameraType = Enum.CameraType.Custom end
end)

---------------------------------------------------------------------
-- 🚀 เริ่มต้นแมตช์ (PvE Bot & Real PvP 1v1 / Custom Mode)
---------------------------------------------------------------------
local function focusTableCamera(tableModel: Model?)
	local cam = workspace.CurrentCamera
	if not cam or not tableModel then return end
	local camPt = tableModel:FindFirstChild("CameraPoint")
	if camPt and camPt:IsA("BasePart") then
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = camPt.CFrame,
		}):Play()
	end
end

local function resetMatchState(goFirst: boolean)
	matchState.active = true
	matchState.myTurn = goFirst
	matchState.myLP = 8000
	matchState.enemyLP = 8000
	matchState.myMana = 3
	matchState.myMaxMana = 3
	matchState.enemyMana = 3
	matchState.enemyMaxMana = 3
	matchState.myGlue = 0
	matchState.myBananaTrap = false
	matchState.enemyBananaTrap = false
	matchState.myBoard = { nil, nil, nil }
	matchState.enemyBoard = { nil, nil, nil }
	matchState.myHand = {}
	matchState.selectedSlot = nil
	matchState.pokeCount = 0
	addGlue(0)
	drawCards(4)
end

-- เปิดโต๊ะสู้บอท (PvE)
OpenTable.OnClientEvent:Connect(function(tableModel: Model?, options: any)
	local reqDiff = (type(options) == "table" and options.difficulty) or "Medium"
	local ok, matchInfo = pcall(function()
		return NewMatch:InvokeServer(reqDiff)
	end)
	if not ok or type(matchInfo) ~= "table" then return end

	matchState.matchId = tostring(matchInfo.matchId or "")
	matchState.isPvP = false
	matchState.isCustom = false
	matchState.botThinkTime = tonumber(matchInfo.thinkTime) or 0.9
	matchState.botMistakeChance = tonumber(matchInfo.mistakeChance) or 0.15
	matchState.botCheatMana = tonumber(matchInfo.cheatMana) or 0

	enemyHeroUI.nameLabel.Text = tostring(matchInfo.botName or "🤖 บอทลุงกาว")
	enemyHeroUI.avatarBtn.Image = "rbxassetid://6031094678"

	resetMatchState(true)
	battleGui.Enabled = true
	focusTableCamera(tableModel)
	renderAll()
	showTurnBanner("ตาคุณแล้ว! 😎", Palette.Gold)
end)

-- เริ่มแมตช์คนจริง PvP 1v1 หรือ Custom Mode (0 Gold)
StartPvP.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" then return end
	matchState.matchId = tostring(data.matchId or "")
	matchState.isPvP = true
	matchState.isCustom = (data.isCustom == true)

	local oppName = tostring(data.opponentName or "คู่ต่อสู้")
	enemyHeroUI.nameLabel.Text = matchState.isCustom and ("🎯 " .. oppName .. " (Custom 0G)") or ("⚔️ " .. oppName)

	local oppId = tonumber(data.opponentUserId)
	if oppId and oppId > 0 then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(oppId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and url then
				enemyHeroUI.avatarBtn.Image = url
			end
		end)
	end

	local goFirst = (data.goFirst == true)
	resetMatchState(goFirst)
	battleGui.Enabled = true
	focusTableCamera(data.tableModel)
	renderAll()
	showTurnBanner(goFirst and "ตาคุณแล้ว! 😎" or "ตาของคู่ต่อสู้ ⚔️", goFirst and Palette.Gold or Palette.Crimson)
end)

-- รับคำสั่ง Real-time จากคู่ต่อสู้ผ่าน Server Relay
PvPActionRelay.OnClientEvent:Connect(function(actionData: any)
	if not matchState.active or not matchState.isPvP or type(actionData) ~= "table" then return end
	local act = actionData.action

	if act == "PlayCard" then
		local tmpl = CARD_BY_ID[tostring(actionData.cardId or "")]
		local slot = tonumber(actionData.slot) or 1
		if tmpl then
			matchState.enemyMana = math.max(0, matchState.enemyMana - tmpl.cost)
			matchState.enemyBoard[slot] = {
				id = tmpl.id, name = tmpl.name, emoji = tmpl.emoji,
				atk = tmpl.atk, hp = tmpl.hp, maxHp = tmpl.hp,
				canAttack = true, frozen = false, taunt = (tmpl.taunt == true),
				rebirth = (tmpl.rebirth == true), dodge = tmpl.dodge or 0, missChance = tmpl.missChance or 0,
			}
			spawnPunchPopText(UDim2.fromScale(0.5, 0.28), string.format("🃏 ศัตรูลง %s!", tmpl.name), Palette.Crimson)
		end
	elseif act == "Attack" then
		local dmg = tonumber(actionData.damage) or 800
		local tSlot = tonumber(actionData.targetSlot)
		if tSlot and matchState.myBoard[tSlot] then
			(matchState.myBoard[tSlot] :: BoardUnit).hp -= dmg
		else
			matchState.myLP -= dmg
		end
		spawnPunchPopText(UDim2.fromScale(0.5, 0.60), string.format("💥 โดนโจมตี -%d!", dmg), Palette.Crimson)
		shakeScreen(8)
		handleUnitDeaths(matchState.myBoard, true)
	elseif act == "Spell" then
		local cid = tostring(actionData.cardId or "")
		if cid == "bomb" then
			for i = 1, 3 do
				local mu = matchState.myBoard[i]
				if mu then mu.hp -= 800 end
			end
		elseif cid == "slipper" then
			matchState.myLP -= 1500
		elseif cid == "lag" then
			for i = 1, 3 do
				local mu = matchState.myBoard[i]
				if mu then mu.frozen = true end
			end
		end
		handleUnitDeaths(matchState.myBoard, true)
	elseif act == "Ult" then
		matchState.myLP -= 1800
		for i = 1, 3 do
			local mu = matchState.myBoard[i]
			if mu then mu.hp -= 1000 end
		end
		spawnPunchPopText(UDim2.fromScale(0.5, 0.52), "🧪💥 โดนอัลติกาวศัตรู -1800!", Palette.Magenta)
		shakeScreen(14)
		handleUnitDeaths(matchState.myBoard, true)
	elseif act == "Taunt" then
		showSpeechBubble(enemyHeroUI, tostring(actionData.text or "กาวจัดปลัดบอก! 😜"))
	elseif act == "EndTurn" then
		matchState.myTurn = true
		matchState.myMaxMana = math.min(10, matchState.myMaxMana + 1)
		matchState.myMana = matchState.myMaxMana
		drawCards(1)
		for i = 1, 3 do
			local mu = matchState.myBoard[i]
			if mu then
				mu.canAttack = true
				mu.frozen = false
			end
		end
		showTurnBanner("ตาคุณแล้ว! 😎", Palette.Gold)
	end

	renderAll()
	checkGameOver()
end)

-- รับผลจบแมตช์ PvP หรือคู่ต่อสู้หลุด/ยอมแพ้
PvPMatchEnd.OnClientEvent:Connect(function(data: any)
	if not matchState.active then return end
	matchState.active = false
	local won = type(data) == "table" and data.won == true
	local msg = (type(data) == "table" and tostring(data.reason or "")) or ""
	showTurnBanner(won and ("🏆 " .. msg) or ("💀 " .. msg), won and Palette.Gold or Palette.Crimson)
	task.delay(2.4, function()
		battleGui.Enabled = false
		local cam = workspace.CurrentCamera
		if cam then cam.CameraType = Enum.CameraType.Custom end
	end)
end)