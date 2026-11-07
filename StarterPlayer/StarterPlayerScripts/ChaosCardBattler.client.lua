--[[
	🃏 กาวการ์ด: ศึกดวลปั่นประสาท  (Chaos Card Battler — สไตล์กาวๆ ปั่นๆ)
	-------------------------------------------------------------------
	วางไว้ที่ : StarterPlayer ▸ StarterPlayerScripts  (LocalScript)
	วิธีเล่น  :
	  • คลิก หรือ ลากการ์ดขึ้นไปบนสนาม = เล่นการ์ด
	  • คลิกมอนสเตอร์ของเราที่ "เรืองเขียว" → คลิกศัตรู/หน้าบอท = โจมตี
	  • Space = จบเทิร์น | Q = ท่าไม้ตายกาว | E = ยั่วบอท | คลิกขวา = ยกเลิก
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
do
	local old = playerGui:FindFirstChild("GlueCardGame")
	if old then old:Destroy() end
end



---------------------------------------------------------------------
-- ⚙️ 1) CONFIG
---------------------------------------------------------------------
local CONFIG = {
	START_LP = 8000,
	MAX_MANA = 10,
	START_HAND = 4,
	MAX_HAND = 7,
	SLOTS = 4,
	DECK_SIZE = 30,
	CRIT_CHANCE = 0.15,
	MISS_CHANCE = 0.07,
	COMBO_BONUS = 0.15,
	GLUE_MAX = 100,
	FATIGUE_DMG = 500,
}


local DEFAULT_BOT = {
	name = "บอทลุงกาว 🤖 Lv.99",
	avatar = "🤖",
	think = 0.9,
	mistake = 0.1,
	lp = 8000,
	cheat = false,
}

local BOT_PROFILES = {
	Easy = { name = "หุ่นฝึกซ้อม (ง่าย) 🤖", avatar = "🤖", think = 1.3, mistake = 0.35, lp = 7000, cheat = false },
	Medium = { name = "บอทลุงกาว 🤖 Lv.99", avatar = "🤖", think = 0.9, mistake = 0.1, lp = 8000, cheat = false },
	Normal = { name = "บอทลุงกาว 🤖 Lv.99", avatar = "🤖", think = 0.9, mistake = 0.1, lp = 8000, cheat = false },
	Hard = { name = "ลุงกาวหัวร้อน 🔥 Lv.150", avatar = "😡", think = 0.6, mistake = 0.0, lp = 9000, cheat = false },
	Hacker = { name = "แฮกเกอร์สายกาว 👾 Lv.999", avatar = "👾", think = 0.4, mistake = 0.0, lp = 10000, cheat = true },
}

local CHAOS_MODES = {
	{ name = "ปกติ", chance = 0.25 },
	{ name = "ปั่น", chance = 0.5 },
	{ name = "กาวสุดขีด", chance = 0.9 },
}

local SIDES = { "player", "enemy" }

local COLORS = {
	panel = Color3.fromRGB(28, 24, 48),
	panel2 = Color3.fromRGB(60, 50, 100),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(195, 190, 225),
	atk = Color3.fromRGB(255, 85, 95),
	hp = Color3.fromRGB(80, 220, 120),
	mana = Color3.fromRGB(70, 170, 255),
	glue = Color3.fromRGB(255, 80, 200),
	gold = Color3.fromRGB(255, 210, 60),
	player = Color3.fromRGB(70, 180, 255),
	enemy = Color3.fromRGB(255, 70, 100),
}

local RARITY = {
	Common = { color = Color3.fromRGB(130, 135, 145), label = "ธรรมดา" },
	Rare = { color = Color3.fromRGB(45, 135, 255), label = "แรร์" },
	Legendary = { color = Color3.fromRGB(255, 190, 40), label = "ตำนาน" },
	Glue = { color = Color3.fromRGB(255, 80, 200), label = "กาว" },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

-- 🔊 เปลี่ยนเป็น rbxassetid ของตัวเองได้ (ถ้าเสียงไหนเล่นไม่ได้ เกมก็ยังรันปกติ)
local SOUNDS = {
	click = "rbxasset://sounds/clickfast.wav",
	hover = "rbxasset://sounds/button.wav",
	draw = "rbxasset://sounds/unsheath.wav",
	summon = "rbxasset://sounds/electronicpingshort.wav",
	swing = "rbxasset://sounds/swordlunge.wav",
	hit = "rbxasset://sounds/swordslash.wav",
	oof = "rbxasset://sounds/uuhhh.mp3",
	boom = "rbxasset://sounds/collide.wav",
	splat = "rbxasset://sounds/splat.wav",
	win = "rbxasset://sounds/victory.wav",
}

local KW_ORDER = { "Taunt", "Rush", "Dodge", "Rebirth", "Explode", "Thief" }
local KW_INFO = {
	Taunt = { icon = "🛡", text = "โล่: ศัตรูต้องตีตัวนี้ก่อน" },
	Rush = { icon = "⚡", text = "ซิ่ง: ตีได้ทันทีที่ลงสนาม" },
	Dodge = { icon = "💨", text = "หลบ: มีโอกาสหลบการโจมตี" },
	Rebirth = { icon = "🔁", text = "ฟื้นชีพ: ตายแล้วฟื้นได้ 1 ครั้ง" },
	Explode = { icon = "💥", text = "ระเบิด: ตายแล้วระเบิดใส่ศัตรูทุกตัว" },
	Thief = { icon = "🦝", text = "ขโมย: ต้นเทิร์นดูด LP ศัตรูมาเป็นของเรา" },
}

local LINES = {
	hurt = { "โอ๊ยยย!", "เจ็บนะเว้ยย 😭", "ไม่นะะะ", "แม่จ๋าาา!", "ขอเวลานอก!", "อ๊ากกก 💀", "เบาๆ หน่อยดิ!" },
	death = { "บินไปดาวอังคาร 🚀", "ลาก่อยยย 👋", "ไปเกิดใหม่นะ", "กลับบ้านไปกินข้าว 🍚", "หลุดเซิร์ฟ 📶", "GG 💀", "ปลิวว~" },
	miss = { "วืดดด! 💨", "ตีลมมม", "มือลั่น! 🤣", "เล็งตรงไหนเนี่ย?", "สะดุดขาตัวเอง!", "ลืมใส่แว่น 👓" },
	crit = { "คริแตก!!", "แรงเกินนน!", "ตีแรงจัด!", "โดนจุดตาย!", "ปั่นสุดแรงเกิด!" },
	taunt = { "ง่อยอะ 😜", "มาดิ๊ เบาไปป่ะ", "555+ ปั่นจัด", "ลุงเล่นเป็นป่าวเนี่ย?", "GG ง่ายๆ", "ไปฝึกมาใหม่นะลุง", "อ่อนนน 🥱" },
	botReply = { "เดี๋ยวเหอะ!! 😡", "หยุดปั่นได้แล้ว!", "ลุงจะฟ้องแม่!", "อย่ามาทำเป็นเก่ง!", "เงียบไปเลย!", "เดี๋ยวโดนรองเท้าแตะ 👡" },
	botThink = { "อืมมม... คิดแป๊บ 🤔", "ลุงขอคิดก่อนนะ", "เดี๋ยวลุงจัดให้", "ฮึ่มมม 😏", "โหลดสมองแป๊บ ⏳" },
	botEnd = { "ตาเธอแล้ว ไปเลย!", "แค่นี้แหละ 😎", "เบื่อแล้ว จบเทิร์น", "หาวว 🥱" },
	poke = { "จิ้มทำไม?", "อย่าจิ้ม!", "บอกว่าอย่าจิ้ม!!", "จะโมโหแล้วนะ 😤", "หยุดดดด!!", "เอาจริงเหรอ!?", "ครั้งสุดท้ายนะ!!" },
	self = { "หล่อสุดในสนาม 😎", "ปั่นต่อไม่รอแล้วนะ", "อย่ากดผมสิ!", "แบตจะหมดแล้ว 🔋" },
	turnPlayer = { "ปั่นให้สุด!", "โชว์ความกาวหน่อย!", "อย่าให้บอทดูถูก!", "ลุยยยย!", "ถึงเวลาเกรียน!" },
	turnEnemy = { "ลุงกำลังคิด... (ช้ามาก)", "บอทโหมดจริงจัง 😤", "ระวังรองเท้าแตะ!", "รอแป๊บ ลุงหาแว่น 👓" },
	win = { "บอทร้องไห้กลับบ้านแล้ว 😭", "กาวระดับเทพ!", "ปั่นจนบอทเอ๋อ 🤪", "ยืนหนึ่งเรื่องความกาว 👑" },
	lose = { "ลุงหัวเราะเยาะแล้ว 🤣", "เดี๋ยวค่อยเอาคืน!", "ไปฝึกกาวมาใหม่นะ", "อายแมวที่บ้านมาก 🐈" },
}

---------------------------------------------------------------------
-- 🧰 2) UTILITIES
---------------------------------------------------------------------
local function pick(t) return t[math.random(1, #t)] end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function otherSide(side) return side == "player" and "enemy" or "player" end

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

local function corner(parent, r)
	return make("UICorner", { CornerRadius = r or UDim.new(0, 10), Parent = parent })
end

local function stroke(parent, color, thick, transp)
	return make("UIStroke", {
		Color = color, Thickness = thick or 2, Transparency = transp or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

local function gradient(parent, c1, c2, rot)
	return make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90, Parent = parent })
end

local function label(props)
	local p = {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = COLORS.text,
		TextScaled = true, Text = "", BorderSizePixel = 0,
	}
	for k, v in pairs(props) do p[k] = v end
	return make("TextLabel", p)
end

local animatedGradients = {}
local function spinGradient(g, speed)
	table.insert(animatedGradients, { g = g, speed = speed or 120 })
	return g
end

local function playSound(name, pitch, volume)
	local id = SOUNDS[name]
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or (0.9 + math.random() * 0.3)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 5)
end

local function centerOf(g) return g.AbsolutePosition + g.AbsoluteSize / 2 end

---------------------------------------------------------------------
-- 🧠 3) STATE
---------------------------------------------------------------------
local State = {
	current = "player", turnCount = 0, busy = false, gameOver = false,
	chaos = 2, selected = nil, uid = 0, suggestEnd = false, sides = {},
	isPvP = false, pvpMatchId = nil, pvpOpponent = nil,
}

local function newSide(name)
	return {
		name = name, lp = CONFIG.START_LP, mana = 0, maxMana = 0, deck = {}, hand = {},
		board = {}, glue = 0, combo = 0, bananas = 0, fatigue = 0, pokes = 0,
	}
end

local function getUnits(side)
	local list = {}
	local s = State.sides[side]
	if not s then return list end
	for i = 1, CONFIG.SLOTS do
		if s.board[i] then table.insert(list, s.board[i]) end
	end
	return list
end

local function getEmptySlot(side)
	local s = State.sides[side]
	for i = 1, CONFIG.SLOTS do
		if not s.board[i] then return i end
	end
	return nil
end

local function randomUnit(side)
	local list = getUnits(side)
	if #list == 0 then return nil end
	return list[math.random(1, #list)]
end

local function canAct()
	return State.current == "player" and not State.busy and not State.gameOver
end

-- forward declarations
local updateUnitUI, refreshInteractivity, showPreview, layoutHand, killUnit, damageUnit
local resetGame, checkGameOver, onUnitClicked, updateHeroUI

---------------------------------------------------------------------
-- 🖼️ 4) GUI LAYOUT
---------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "GlueCardGame", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10, Parent = playerGui,
})

local Main = make("Frame", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = gui })
spinGradient(make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 10, 55)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(75, 15, 85)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 35, 80)),
	}),
	Parent = Main,
}), 6)

local BgLayer = make("Frame", { Name = "BgLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, Parent = Main })
local Shaker = make("Frame", {
	Name = "Shaker",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = Main,
})
local Overlay = make("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = Main })

local function panel(name, pos, size, accent)
	local f = make("Frame", {
		Name = name, Position = pos, Size = size, BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.12, BorderSizePixel = 0, Parent = Shaker,
	})
	corner(f, UDim.new(0, 14))
	stroke(f, accent or COLORS.panel2, 2, 0.2)
	gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(170, 160, 200), 90)
	return f
end

local function makeButton(parent, text, pos, size, c1, c2)
	local b = make("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Position = pos, Size = size, BorderSizePixel = 0, Parent = parent,
	})
	local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = b })
	corner(bg, UDim.new(0, 12))
	local grad = make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = 90, Parent = bg })
	local st = stroke(bg, Color3.new(1, 1, 1), 2, 0.5)
	local txt = label({ Text = text, Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(0.9, 0.62), Position = UDim2.fromScale(0.05, 0.19), ZIndex = 2, Parent = b })
	make("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = txt })
	local sc = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function() tween(sc, 0.12, { Scale = 1.05 }); playSound("hover", 1.8, 0.12) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.08, { Scale = 0.92 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.25, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
	return { button = b, label = txt, grad = grad, stroke = st, bg = bg }
end

local function makeAvatar(parent, emoji, color, pos, size, dominant)
	local av = make("TextButton", {
		Name = "Avatar", Text = emoji, TextScaled = true, Font = Enum.Font.GothamBold, AutoButtonColor = false,
		BackgroundColor3 = color, Position = pos, Size = size, BorderSizePixel = 0, Parent = parent,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = dominant, Parent = av })
	make("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0.12, 0), PaddingRight = UDim.new(0.12, 0), Parent = av })
	corner(av, UDim.new(1, 0))
	stroke(av, Color3.new(1, 1, 1), 3)
	local ring = make("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5), BackgroundTransparency = 1, Visible = false, Parent = av })
	corner(ring, UDim.new(1, 0))
	local ringStroke = stroke(ring, COLORS.atk, 5)
	return av, ring, ringStroke
end

local function buildBar(parent, pos, size, c1, c2, prefix, suffix, maxVal)
	local bg = make("Frame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(15, 12, 25), BorderSizePixel = 0, ClipsDescendants = true, Parent = parent })
	corner(bg, UDim.new(0.4, 0))
	stroke(bg, Color3.new(0, 0, 0), 2, 0.3)
	local ghost = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 245, 210), BorderSizePixel = 0, Parent = bg })
	corner(ghost, UDim.new(0.4, 0))
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bg })
	corner(fill, UDim.new(0.4, 0))
	gradient(fill, c1, c2, 0)
	make("Frame", { Size = UDim2.fromScale(1, 0.4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = fill })
	local text = label({ Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Font = Enum.Font.FredokaOne, ZIndex = 3, Parent = bg })
	make("UIStroke", { Thickness = 1.5, Parent = text })
	local value = Instance.new("NumberValue")
	value.Value = maxVal or 0
	local bar = { bg = bg, fill = fill, ghost = ghost, text = text, value = value, prefix = prefix or "", suffix = suffix or "", max = maxVal or 100 }
	value.Changed:Connect(function(v) text.Text = bar.prefix .. math.floor(v + 0.5) .. bar.suffix end)
	text.Text = bar.prefix .. math.floor(value.Value) .. bar.suffix
	return bar
end

local function setBar(bar, val, maxVal)
	bar.max = maxVal or bar.max
	local ratio = math.clamp(val / bar.max, 0, 1)
	tween(bar.fill, 0.35, { Size = UDim2.fromScale(ratio, 1) }, Enum.EasingStyle.Quart)
	if ratio >= bar.ghost.Size.X.Scale then
		bar.ghost.Size = UDim2.fromScale(ratio, 1)
	else
		task.delay(0.45, function()
			if bar.ghost.Parent then tween(bar.ghost, 0.5, { Size = UDim2.fromScale(ratio, 1) }) end
		end)
	end
	tween(bar.value, 0.5, { Value = val }, Enum.EasingStyle.Quart)
end

-- 📋 Preview (ซ้ายบน)
local PreviewPanel = panel("PreviewPanel", UDim2.fromScale(0.01, 0.02), UDim2.fromScale(0.16, 0.67), COLORS.panel2)
local PreviewHolder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.03), Size = UDim2.fromScale(0.82, 0.55), BackgroundTransparency = 1, Parent = PreviewPanel })
make("UIAspectRatioConstraint", { AspectRatio = 0.72, Parent = PreviewHolder })
local PreviewName = label({ Text = "🃏 กาวการ์ด", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.06), TextColor3 = COLORS.gold, Parent = PreviewPanel })
local PreviewText = label({
	Text = "👆 ชี้เมาส์ที่การ์ดเพื่อดูรายละเอียด", RichText = true, TextWrapped = true, Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = COLORS.sub,
	Position = UDim2.fromScale(0.06, 0.67), Size = UDim2.fromScale(0.88, 0.31), Parent = PreviewPanel,
})
make("UITextSizeConstraint", { MaxTextSize = 18, Parent = PreviewText })

-- 🧍 Player hero (ซ้ายล่าง)
local Hero = {}
local PlayerPanel = panel("PlayerPanel", UDim2.fromScale(0.01, 0.705), UDim2.fromScale(0.16, 0.28), COLORS.player)
do
	local av, ring, ringStroke = makeAvatar(PlayerPanel, "😎", COLORS.player, UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.3, 0.3), Enum.DominantAxis.Width)
	label({ Text = player.DisplayName, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.4, 0.06), Size = UDim2.fromScale(0.56, 0.13), Parent = PlayerPanel })
	local deck = label({ Text = "📚 กองการ์ด: 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.4, 0.21), Size = UDim2.fromScale(0.56, 0.1), Parent = PlayerPanel })
	local lp = buildBar(PlayerPanel, UDim2.fromScale(0.05, 0.4), UDim2.fromScale(0.9, 0.15), Color3.fromRGB(90, 255, 140), Color3.fromRGB(20, 170, 90), "❤ LP ", "", CONFIG.START_LP)
	local row = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.05, 0.59), Size = UDim2.fromScale(0.9, 0.1), Parent = PlayerPanel })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.012, 0), Parent = row })
	local crystals = {}
	for i = 1, CONFIG.MAX_MANA do
		local c = make("Frame", { Size = UDim2.fromScale(0.085, 0.8), Rotation = 45, BackgroundColor3 = Color3.fromRGB(30, 28, 45), BorderSizePixel = 0, LayoutOrder = i, Parent = row })
		make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = c })
		corner(c, UDim.new(0.25, 0))
		stroke(c, Color3.new(1, 1, 1), 1, 0.5)
		make("UIScale", { Parent = c })
		crystals[i] = c
	end
	local manaText = label({ Text = "💧 มานา 0/0", TextColor3 = COLORS.mana, Position = UDim2.fromScale(0.05, 0.71), Size = UDim2.fromScale(0.9, 0.1), Parent = PlayerPanel })
	local glue = buildBar(PlayerPanel, UDim2.fromScale(0.05, 0.84), UDim2.fromScale(0.9, 0.12), Color3.fromRGB(255, 80, 200), Color3.fromRGB(140, 60, 255), "🧪 กาว ", "%", CONFIG.GLUE_MAX)
	Hero.player = { avatar = av, ring = ring, ringStroke = ringStroke, lp = lp, glue = glue, crystals = crystals, manaText = manaText, deck = deck }
end

-- 🤖 Enemy hero (บน)
local EnemyPanel = panel("EnemyPanel", UDim2.fromScale(0.18, 0.015), UDim2.fromScale(0.64, 0.125), COLORS.enemy)
do
	local av, ring, ringStroke = makeAvatar(EnemyPanel, "🤖", COLORS.enemy, UDim2.fromScale(0.008, 0.08), UDim2.fromScale(0.2, 0.84), Enum.DominantAxis.Height)
	local nameL = label({ Text = "บอทลุงกาว 🤖 Lv.99", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.105, 0.08), Size = UDim2.fromScale(0.4, 0.28), Parent = EnemyPanel })
	local lp = buildBar(EnemyPanel, UDim2.fromScale(0.105, 0.45), UDim2.fromScale(0.5, 0.36), Color3.fromRGB(255, 90, 110), Color3.fromRGB(180, 20, 60), "❤ LP ", "", CONFIG.START_LP)
	local info = label({ Text = "", TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.64, 0.08), Size = UDim2.fromScale(0.34, 0.36), Parent = EnemyPanel })
	local glue = buildBar(EnemyPanel, UDim2.fromScale(0.64, 0.52), UDim2.fromScale(0.34, 0.3), Color3.fromRGB(255, 80, 200), Color3.fromRGB(140, 60, 255), "🧪 กาวบอท ", "%", CONFIG.GLUE_MAX)
	Hero.enemy = { avatar = av, ring = ring, ringStroke = ringStroke, lp = lp, glue = glue, info = info, nameLabel = nameL }
end

-- 🟥🟦 Boards
local BoardFrame, BananaLabel = {}, {}
local SlotFrames = { player = {}, enemy = {} }
local SlotGlow = { player = {}, enemy = {} }


---------------------------------------------------------------------
-- 🟥🟦 BOARDS (ส่วนที่ 2 — วางแทน buildBoard เดิมที่ถูกตัด)
---------------------------------------------------------------------
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
State.gameId = 0

local tryPlayCard, botTurn

local function buildBoard(side, pos)
	local f = make("Frame", {
		Name = side .. "Board", Position = pos, Size = UDim2.fromScale(0.64, 0.25),
		BackgroundColor3 = side == "player" and Color3.fromRGB(30, 60, 110) or Color3.fromRGB(110, 30, 50),
		BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 1, Parent = Shaker,
	})
	corner(f, UDim.new(0, 18))
	stroke(f, side == "player" and COLORS.player or COLORS.enemy, 2, 0.5)
	label({ Text = side == "player" and "ฝั่งคุณ 😎" or "ฝั่งบอท 🤖", Font = Enum.Font.GothamBlack, TextTransparency = 0.85, Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.25, 0.35), Parent = f })
	BananaLabel[side] = label({ Text = "", Visible = false, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.12, 0.16), Position = UDim2.fromScale(0.01, 0.03), ZIndex = 5, Parent = f })
	for i = 1, CONFIG.SLOTS do
		local x = 0.5 + (i - (CONFIG.SLOTS + 1) / 2) * 0.21
		local slot = make("Frame", {
			Name = "Slot" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.2, 0.88), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.93, BorderSizePixel = 0, ZIndex = 2, Parent = f,
		})
		make("UIAspectRatioConstraint", { AspectRatio = 0.72, DominantAxis = Enum.DominantAxis.Height, Parent = slot })
		corner(slot, UDim.new(0.08, 0))
		stroke(slot, Color3.new(1, 1, 1), 2, 0.75)
		label({ Text = "+", TextTransparency = 0.85, Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.25, 0.35), Parent = slot })
		local glow = make("Frame", {
			Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 16, 1, 16), BackgroundColor3 = COLORS.hp, BackgroundTransparency = 0.4,
			BorderSizePixel = 0, Visible = false, ZIndex = 0, Parent = slot,
		})
		corner(glow, UDim.new(0.1, 0))
		SlotFrames[side][i] = slot
		SlotGlow[side][i] = glow
	end
	BoardFrame[side] = f
end
buildBoard("enemy", UDim2.fromScale(0.18, 0.15))
buildBoard("player", UDim2.fromScale(0.18, 0.47))

local CenterHint = label({ Text = "", Font = Enum.Font.GothamBold, TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.2, 0.408), Size = UDim2.fromScale(0.6, 0.05), Parent = Shaker })
make("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = CenterHint })

local HandFrame = make("Frame", { Name = "Hand", Position = UDim2.fromScale(0.18, 0.735), Size = UDim2.fromScale(0.64, 0.255), BackgroundTransparency = 1, ZIndex = 4, Parent = Shaker })

-- 🎛️ แผงขวา
local SidePanel = panel("SidePanel", UDim2.fromScale(0.83, 0.02), UDim2.fromScale(0.16, 0.96), COLORS.panel2)
local TurnLabel = label({ Text = "เทิร์น 0", Font = Enum.Font.GothamBlack, TextColor3 = COLORS.gold, Position = UDim2.fromScale(0.05, 0.015), Size = UDim2.fromScale(0.9, 0.05), Parent = SidePanel })
local EndBtn = makeButton(SidePanel, "⏭ จบเทิร์น [Space]", UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.88, 0.08), Color3.fromRGB(255, 200, 70), Color3.fromRGB(235, 110, 30))
local UltBtn = makeButton(SidePanel, "🧪 กาว 0%", UDim2.fromScale(0.06, 0.175), UDim2.fromScale(0.88, 0.07), Color3.fromRGB(255, 80, 200), Color3.fromRGB(140, 60, 255))
local TauntBtn = makeButton(SidePanel, "😜 ยั่วบอท [E]", UDim2.fromScale(0.06, 0.255), UDim2.fromScale(0.88, 0.06), Color3.fromRGB(90, 220, 130), Color3.fromRGB(30, 150, 90))
local ChaosBtn = makeButton(SidePanel, "🌀 โหมด: " .. CHAOS_MODES[State.chaos].name, UDim2.fromScale(0.06, 0.325), UDim2.fromScale(0.88, 0.06), Color3.fromRGB(90, 160, 255), Color3.fromRGB(60, 70, 200))
label({ Text = "📜 บันทึกการต่อสู้", Font = Enum.Font.GothamBlack, TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.05, 0.4), Size = UDim2.fromScale(0.9, 0.035), Parent = SidePanel })
local LogFrame = make("ScrollingFrame", {
	Position = UDim2.fromScale(0.05, 0.44), Size = UDim2.fromScale(0.9, 0.43), BackgroundColor3 = Color3.fromRGB(10, 8, 20),
	BackgroundTransparency = 0.4, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = SidePanel,
})
corner(LogFrame, UDim.new(0, 8))
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = LogFrame })
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = LogFrame })
label({
	Text = "🖱 คลิก/ลากการ์ด = เล่น\n⚔ คลิกตัวเรืองเขียว → คลิกเป้า\n🖱 คลิกขวา = ยกเลิก • Q = ท่าไม้ตาย",
	TextWrapped = true, Font = Enum.Font.GothamMedium, TextColor3 = COLORS.sub,
	Position = UDim2.fromScale(0.05, 0.885), Size = UDim2.fromScale(0.9, 0.1), Parent = SidePanel,
})

local logCount = 0
local function addLog(text, color)
	logCount += 1
	local l = label({
		Text = text, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or COLORS.sub, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = logCount, TextTransparency = 1, Parent = LogFrame,
	})
	tween(l, 0.3, { TextTransparency = 0 })
	local items = {}
	for _, c in ipairs(LogFrame:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(items, c) end
	end
	if #items > 40 then
		table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		items[1]:Destroy()
	end
	task.delay(0.05, function()
		LogFrame.CanvasPosition = Vector2.new(0, math.max(0, LogFrame.AbsoluteCanvasSize.Y - LogFrame.AbsoluteWindowSize.Y))
	end)
end

-- แฟลชจอ + ขอบจอแดงตอนเลือดน้อย
local FlashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 80, Parent = Overlay })
local Vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 70, Parent = Overlay })
local VignetteEdges = {}
for _, e in ipairs({
	{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.12), 90 },
	{ UDim2.fromScale(0, 0.88), UDim2.fromScale(1, 0.12), -90 },
	{ UDim2.fromScale(0, 0), UDim2.fromScale(0.07, 1), 0 },
	{ UDim2.fromScale(0.93, 0), UDim2.fromScale(0.07, 1), 180 },
}) do
	local f = make("Frame", { Position = e[1], Size = e[2], BackgroundColor3 = Color3.fromRGB(255, 0, 50), BorderSizePixel = 0, Parent = Vignette })
	make("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0, 1), Parent = f })
	table.insert(VignetteEdges, f)
end

---------------------------------------------------------------------
-- ✨ 5) FX
---------------------------------------------------------------------
local function px(n) return n * math.max(Main.AbsoluteSize.Y, 400) / 800 end
local function toOverlay(p) return p - Overlay.AbsolutePosition end
local function who(side) return side == "player" and "คุณ" or "บอท" end

local function fadeOut(obj, t)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		tween(obj, t, { TextTransparency = 1 })
	else
		tween(obj, t, { BackgroundTransparency = 1 })
	end
	for _, d in ipairs(obj:GetChildren()) do
		if d:IsA("UIStroke") then tween(d, t, { Transparency = 1 }) end
	end
end

local function popText(absPos, text, color, scale, rise)
	local p = toOverlay(absPos)
	local h = px(46) * (scale or 1)
	local l = label({
		Text = text, TextColor3 = color or COLORS.text, Font = Enum.Font.FredokaOne, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(h * 6, h), Rotation = math.random(-10, 10), ZIndex = 60, Parent = Overlay,
	})
	make("UIStroke", { Thickness = 3, Parent = l })
	local sc = make("UIScale", { Scale = 0.2, Parent = l })
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(l, 1.1, { Position = UDim2.fromOffset(p.X + math.random(-30, 30), p.Y - px(rise or 70)) })
	task.delay(0.75, function() if l.Parent then fadeOut(l, 0.35) end end)
	Debris:AddItem(l, 1.2)
end

local function burst(absPos, items, count, spread)
	local p = toOverlay(absPos)
	for _ = 1, count do
		local item = items[math.random(1, #items)]
		local obj
		if typeof(item) == "Color3" then
			obj = make("Frame", { BackgroundColor3 = item, BorderSizePixel = 0, Size = UDim2.fromOffset(px(10), px(10)) })
			corner(obj, UDim.new(0.3, 0))
		else
			obj = label({ Text = item, Size = UDim2.fromOffset(px(28), px(28)) })
		end
		obj.AnchorPoint = Vector2.new(0.5, 0.5)
		obj.Position = UDim2.fromOffset(p.X, p.Y)
		obj.Rotation = math.random(0, 360)
		obj.ZIndex = 55
		obj.Parent = Overlay
		local ang = math.random() * math.pi * 2
		local dist = px((spread or 120) * (0.4 + math.random() * 0.8))
		local t = 0.5 + math.random() * 0.4
		tween(obj, t, { Position = UDim2.fromOffset(p.X + math.cos(ang) * dist, p.Y + math.sin(ang) * dist), Rotation = obj.Rotation + math.random(-360, 360) }, Enum.EasingStyle.Quart)
		task.delay(t * 0.6, function() if obj.Parent then fadeOut(obj, t * 0.4) end end)
		Debris:AddItem(obj, t + 0.2)
	end
end

local function shockwave(absPos, color, size)
	local p = toOverlay(absPos)
	local r = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(px(20), px(20)), BackgroundTransparency = 1, ZIndex = 54, Parent = Overlay })
	corner(r, UDim.new(1, 0))
	local st = stroke(r, color or Color3.new(1, 1, 1), px(6), 0)
	tween(r, 0.45, { Size = UDim2.fromOffset(px(size or 220), px(size or 220)) }, Enum.EasingStyle.Quart)
	tween(st, 0.45, { Transparency = 1, Thickness = 1 })
	Debris:AddItem(r, 0.6)
end

local shakeMag, shakeTime = 0, 0
local function shake(mag, dur)
	shakeMag = math.max(shakeMag, mag)
	shakeTime = math.max(shakeTime, dur or 0.3)
end

local function flash(color, alpha, dur)
	FlashFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	FlashFrame.BackgroundTransparency = alpha or 0.5
	tween(FlashFrame, dur or 0.35, { BackgroundTransparency = 1 })
end

local function punch(g, amt)
	if not g or not g.Parent then return end
	local sc = g:FindFirstChild("PunchScale") or make("UIScale", { Name = "PunchScale", Parent = g })
	sc.Scale = amt or 1.35
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function banner(text, sub, color, hold)
	local band = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.7, 0.44), Size = UDim2.fromScale(1.2, 0.14),
		Rotation = -3, BackgroundColor3 = color or COLORS.glue, BorderSizePixel = 0, ZIndex = 75, Parent = Overlay,
	})
	gradient(band, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130), 90)
	local t = label({ Text = text, Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.2, 0.06), Size = UDim2.fromScale(0.6, 0.6), Parent = band })
	make("UIStroke", { Thickness = 3, Parent = t })
	local s = label({ Text = sub or "", Position = UDim2.fromScale(0.2, 0.66), Size = UDim2.fromScale(0.6, 0.28), Parent = band })
	make("UIStroke", { Thickness = 2, Parent = s })
	tween(band, 0.4, { Position = UDim2.fromScale(0.5, 0.44) }, Enum.EasingStyle.Back)
	task.delay(0.4 + (hold or 0.8), function()
		tween(band, 0.3, { Position = UDim2.fromScale(1.7, 0.44) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Debris:AddItem(band, 0.35)
	end)
end

local function speech(anchor, text, color, below)
	if not anchor or not anchor.Parent then return end
	local p = toOverlay(centerOf(anchor))
	local off = anchor.AbsoluteSize.Y / 2 + px(8)
	local b = make("Frame", {
		AnchorPoint = Vector2.new(0.5, below and 0 or 1),
		Position = UDim2.fromOffset(p.X, below and (p.Y + off) or (p.Y - off)),
		Size = UDim2.fromOffset(px(230), px(46)), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 65, Parent = Overlay,
	})
	corner(b, UDim.new(0.4, 0))
	stroke(b, color or Color3.new(0, 0, 0), 3)
	label({ Text = text, TextColor3 = Color3.fromRGB(30, 30, 40), Font = Enum.Font.GothamBlack, Size = UDim2.fromScale(0.92, 0.7), Position = UDim2.fromScale(0.04, 0.15), Parent = b })
	local sc = make("UIScale", { Scale = 0, Parent = b })
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		if b.Parent then
			tween(sc, 0.2, { Scale = 0 })
			Debris:AddItem(b, 0.25)
		end
	end)
end

local function rain(emoji, count)
	local W, H = Overlay.AbsoluteSize.X, Overlay.AbsoluteSize.Y
	for _ = 1, count do
		task.delay(math.random() * 0.8, function()
			local x = math.random() * W
			local s = px(math.random(30, 55))
			local l = label({ Text = emoji, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, -s), Size = UDim2.fromOffset(s, s), Rotation = math.random(0, 360), ZIndex = 57, Parent = Overlay })
			local t = 1 + math.random() * 0.8
			tween(l, t, { Position = UDim2.fromOffset(x + math.random(-60, 60), H + s), Rotation = l.Rotation + math.random(-200, 200) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(l, t + 0.1)
		end)
	end
end

local function projectile(fromAbs, toAbs, emoji, t, big)
	local a, b = toOverlay(fromAbs), toOverlay(toAbs)
	local s = px(big and 90 or 55)
	local p = label({ Text = emoji, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(s, s), ZIndex = 58, Parent = Overlay })
	tween(p, t, { Position = UDim2.fromOffset(b.X, b.Y), Rotation = 540 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(t)
	p:Destroy()
	shockwave(toAbs, Color3.new(1, 1, 1), 160)
end

local function pointerPos(input)
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation()
end

---------------------------------------------------------------------
-- 🎴 6) CARD VISUAL + PREVIEW
---------------------------------------------------------------------
local shineGradients = {}

local function toSet(list)
	local s = {}
	for _, k in ipairs(list or {}) do s[k] = true end
	return s
end

local function kwIcons(set)
	local t = {}
	for _, k in ipairs(KW_ORDER) do
		if set[k] then table.insert(t, KW_INFO[k].icon) end
	end
	return table.concat(t, " ")
end

local function subText(def, set)
	if def.kind == "Spell" then return "✨ การ์ดเวท" end
	local k = kwIcons(set)
	return k ~= "" and k or ("• " .. RARITY[def.rarity].label .. " •")
end

local function buildCardVisual(parent, def, opts)
	opts = opts or {}
	local rar = RARITY[def.rarity] or RARITY.Common
	local isSpell = def.kind == "Spell"
	local root = make("TextButton", {
		Name = "Card", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = opts.pos or UDim2.fromScale(0.5, 0.5),
		Size = opts.size or UDim2.fromScale(1, 1), ZIndex = opts.z or 3, Active = opts.active ~= false, Parent = parent,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 0.72, DominantAxis = Enum.DominantAxis.Height, Parent = root })
	corner(root, UDim.new(0.08, 0))
	local top = isSpell and Color3.fromRGB(170, 110, 255) or rar.color:Lerp(Color3.new(1, 1, 1), 0.2)
	local bottom = isSpell and Color3.fromRGB(45, 20, 90) or Color3.fromRGB(25, 20, 40):Lerp(rar.color, 0.3)
	gradient(root, top, bottom, 90)

	local border = stroke(root, rar.color, 3)
	if def.rarity == "Glue" then
		border.Color = Color3.new(1, 1, 1)
		spinGradient(make("UIGradient", { Color = RAINBOW, Parent = border }), 220)
	elseif def.rarity == "Legendary" then
		border.Color = Color3.new(1, 1, 1)
		spinGradient(make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, COLORS.gold),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, COLORS.gold),
			}),
			Parent = border,
		}), 160)
	end

	local art = make("Frame", {
		Position = UDim2.fromScale(0.08, 0.13), Size = UDim2.fromScale(0.84, 0.5), BackgroundColor3 = Color3.fromRGB(10, 8, 20),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = root,
	})
	corner(art, UDim.new(0.1, 0))
	local emoji = label({ Text = def.emoji, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 3, Parent = art })
	if def.rarity ~= "Common" then
		local shine = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = art })
		local g = make("UIGradient", {
			Rotation = 20, Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = shine,
		})
		table.insert(shineGradients, { g = g, phase = math.random() * 3 })
	end

	local cost = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.1, 0.06), Size = UDim2.fromScale(0.32, 0.32),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = root,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = cost })
	corner(cost, UDim.new(1, 0))
	stroke(cost, Color3.new(1, 1, 1), 2)
	gradient(cost, Color3.fromRGB(120, 200, 255), Color3.fromRGB(30, 90, 220), 90)
	local costText = label({ Text = tostring(def.cost), Font = Enum.Font.FredokaOne, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 7, Parent = cost })
	make("UIStroke", { Thickness = 1.5, Parent = costText })

	local name = label({ Text = def.name, Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.05, 0.65), Size = UDim2.fromScale(0.9, 0.11), ZIndex = 3, Parent = root })
	make("UIStroke", { Thickness = 1.2, Parent = name })
	local sub = label({ Text = subText(def, toSet(def.kw)), TextColor3 = Color3.fromRGB(255, 240, 180), Position = UDim2.fromScale(0.05, 0.77), Size = UDim2.fromScale(0.9, 0.08), ZIndex = 3, Parent = root })

	local atkL, hpL
	if not isSpell then
		local function badge(x, color, text)
			local b = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.93), Size = UDim2.fromScale(0.46, 0.15),
				BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6, Parent = root,
			})
			corner(b, UDim.new(0.4, 0))
			stroke(b, Color3.new(1, 1, 1), 1.5, 0.2)
			local l = label({ Text = text, Font = Enum.Font.FredokaOne, Size = UDim2.fromScale(0.9, 0.85), Position = UDim2.fromScale(0.05, 0.075), ZIndex = 7, Parent = b })
			make("UIStroke", { Thickness = 1.2, Parent = l })
			return l
		end
		atkL = badge(0.22, COLORS.atk, "⚔" .. def.atk)
		hpL = badge(0.78, Color3.fromRGB(40, 170, 90), "❤" .. def.hp)
	end

	local frozen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 220, 255), BackgroundTransparency = 0.45, Visible = false, ZIndex = 18, Parent = root })
	corner(frozen, UDim.new(0.08, 0))
	label({ Text = "🧊", Size = UDim2.fromScale(0.6, 0.4), Position = UDim2.fromScale(0.2, 0.3), ZIndex = 19, Parent = frozen })
	local dim = make("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20, Parent = root })
	corner(dim, UDim.new(0.08, 0))

	local sc = make("UIScale", { Parent = root })
	return { root = root, atk = atkL, hp = hpL, sub = sub, dim = dim, frozen = frozen, scale = sc, border = border, emoji = emoji }
end

local previewKey
showPreview = function(def, unit)
	local key = unit and ("u" .. unit.uid .. ":" .. unit.atk .. ":" .. unit.hp .. ":" .. unit.frozen) or def.id
	if previewKey == key then return end
	previewKey = key
	for _, c in ipairs(PreviewHolder:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local v = buildCardVisual(PreviewHolder, def, { active = false })
	local set = unit and unit.kw or toSet(def.kw)
	if unit then
		v.atk.Text = "⚔" .. unit.atk
		v.hp.Text = "❤" .. math.max(0, unit.hp)
		v.sub.Text = subText(def, set)
		v.frozen.Visible = unit.frozen > 0
	end
	v.scale.Scale = 0.85
	tween(v.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	PreviewName.Text = def.emoji .. " " .. def.name
	local rar = RARITY[def.rarity]
	local lines = {
		string.format('<font color="#%s"><b>[%s]</b></font> %s • 💧%d', rar.color:ToHex(), rar.label, def.kind == "Spell" and "เวท" or "มอนสเตอร์", def.cost),
	}
	if def.kind ~= "Spell" then
		local a, h = unit and unit.atk or def.atk, unit and unit.hp or def.hp
		table.insert(lines, string.format("⚔ %d   ❤ %d%s", a, math.max(0, h), unit and ("/" .. unit.maxHp) or ""))
	end
	for _, k in ipairs(KW_ORDER) do
		if set[k] then table.insert(lines, '<font color="#FFE27A">' .. KW_INFO[k].icon .. " " .. KW_INFO[k].text .. "</font>") end
	end
	if unit and unit.frozen > 0 then table.insert(lines, '<font color="#8FE3FF">🧊 โดนแช่แข็งอยู่</font>') end
	table.insert(lines, "<i>" .. def.desc .. "</i>")
	PreviewText.Text = table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- 🧍 7) HERO UI
---------------------------------------------------------------------
local lastShown = { player = {}, enemy = {} }
updateHeroUI = function()
	for _, side in ipairs(SIDES) do
		local s, h = State.sides[side], Hero[side]
		if s then
			local last = lastShown[side]
			if last.lp ~= s.lp then last.lp = s.lp; setBar(h.lp, s.lp, CONFIG.START_LP) end
			if last.glue ~= s.glue then last.glue = s.glue; setBar(h.glue, s.glue, CONFIG.GLUE_MAX) end
			if h.crystals then
				for i, c in ipairs(h.crystals) do
					local st = i <= s.mana and "full" or (i <= s.maxMana and "used" or "locked")
					if c:GetAttribute("st") ~= st then
						c:SetAttribute("st", st)
						local color = st == "full" and COLORS.mana or (st == "used" and Color3.fromRGB(40, 60, 110) or Color3.fromRGB(30, 28, 45))
						tween(c, 0.25, { BackgroundColor3 = color })
						local sc = c:FindFirstChildOfClass("UIScale")
						if sc then sc.Scale = 1.6; tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end
					end
				end
				h.manaText.Text = string.format("💧 มานา %d/%d", s.mana, s.maxMana)
				h.deck.Text = "📚 กองการ์ด: " .. #s.deck
			end
			if h.info then
				h.info.Text = string.format("🃏 %d  📚 %d  💧 %d/%d", #s.hand, #s.deck, s.mana, s.maxMana)
			end
			BananaLabel[side].Visible = s.bananas > 0
			BananaLabel[side].Text = "🍌 x" .. s.bananas
		end
	end
	local ps = State.sides.player
	Vignette.Visible = ps ~= nil and ps.lp <= 2500 and not State.gameOver
end

---------------------------------------------------------------------
-- ⚙️ 8) CORE: กาว / LP / มือ / มอนสเตอร์
---------------------------------------------------------------------
local function allUnits()
	local t = getUnits("player")
	for _, u in ipairs(getUnits("enemy")) do table.insert(t, u) end
	return t
end

local function heroPos(side) return centerOf(Hero[side].avatar) end

local function unitPos(unit)
	if unit.ui and unit.ui.root.Parent then return centerOf(unit.ui.root) end
	return centerOf(SlotFrames[unit.side][unit.slot])
end

local function addGlue(side, amt)
	local s = State.sides[side]
	if not s or State.gameOver then return end
	local before = s.glue
	s.glue = math.clamp(s.glue + amt, 0, CONFIG.GLUE_MAX)
	if s.glue >= CONFIG.GLUE_MAX and before < CONFIG.GLUE_MAX then
		popText(heroPos(side), "🧪 กาวเต็มหลอด!", COLORS.glue, 1.1)
		if side == "player" then addLog("🧪 หลอดกาวเต็ม! กด Q ปล่อยท่าไม้ตาย", COLORS.glue) end
	end
	updateHeroUI()
end

local function damageHero(side, amount, opts)
	opts = opts or {}
	local s = State.sides[side]
	if not s or amount <= 0 or State.gameOver then return end
	amount = math.floor(amount)
	s.lp = math.max(0, s.lp - amount)
	local av = Hero[side].avatar
	local pos = centerOf(av)
	popText(pos, (opts.crit and "💥 " or "-") .. amount, opts.crit and COLORS.gold or COLORS.atk, opts.crit and 1.6 or 1.2)
	burst(pos, { COLORS.atk, Color3.new(1, 1, 1), "💢" }, 10, 120)
	task.spawn(function()
		for i = 1, 6 do
			av.Rotation = (i % 2 == 0 and 1 or -1) * (14 - i * 2)
			task.wait(0.04)
		end
		av.Rotation = 0
	end)
	av.BackgroundColor3 = Color3.new(1, 1, 1)
	tween(av, 0.35, { BackgroundColor3 = side == "player" and COLORS.player or COLORS.enemy })
	shake(amount >= 1500 and 16 or 8, 0.3)
	if side == "player" then flash(COLORS.atk, 0.75, 0.3) end
	if side == "enemy" and math.random() < 0.35 then speech(av, pick(LINES.hurt), COLORS.enemy, true) end
	updateHeroUI()
	checkGameOver()
end

local function healHero(side, amount)
	local s = State.sides[side]
	if not s or State.gameOver then return end
	s.lp = math.min(CONFIG.START_LP, s.lp + amount)
	local pos = heroPos(side)
	popText(pos, "+" .. amount, COLORS.hp, 1.1)
	burst(pos, { "💚", "✨" }, 6, 80)
	updateHeroUI()
end

-- ✋ มือการ์ด
local dragInfo, hoveredCard

layoutHand = function()
	local ps = State.sides.player
	if not ps then return end
	local hand = ps.hand
	local n = #hand
	local spacing = math.min(0.15, 0.85 / math.max(n, 1))
	for i, card in ipairs(hand) do
		local v = card.ui
		if v and not (dragInfo and dragInfo.moved and dragInfo.card == card) then
			if v.root.Parent ~= HandFrame then
				v.root.Parent = HandFrame
				v.root.Size = UDim2.fromScale(0.2, 0.82)
			end
			local off = i - (n + 1) / 2
			local hovered = hoveredCard == card
			local y = hovered and 0.3 or (0.55 + off * off * 0.012)
			tween(v.root, 0.25, { Position = UDim2.fromScale(0.5 + off * spacing, y), Rotation = hovered and 0 or off * 3.5 }, Enum.EasingStyle.Back)
			tween(v.scale, 0.25, { Scale = hovered and 1.25 or 1 }, Enum.EasingStyle.Back)
			v.root.ZIndex = hovered and 40 or (3 + i)
		end
	end
end

local function createHandCard(card, animate)
	local v = buildCardVisual(HandFrame, card.def, { size = UDim2.fromScale(0.2, 0.82) })
	card.ui = v
	if animate then
		local p = centerOf(Hero.player.deck) - HandFrame.AbsolutePosition
		v.root.Position = UDim2.fromOffset(p.X, p.Y)
		v.root.Rotation = -90
		v.scale.Scale = 0.3
		playSound("draw", 1.2, 0.35)
	end
	v.root.MouseEnter:Connect(function()
		if dragInfo and dragInfo.moved then return end
		hoveredCard = card
		showPreview(card.def)
		layoutHand()
		playSound("hover", 2, 0.08)
	end)
	v.root.MouseLeave:Connect(function()
		if hoveredCard == card then
			hoveredCard = nil
			layoutHand()
		end
	end)
	v.root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not canAct() then return end
			dragInfo = { card = card, start = pointerPos(input), moved = false }
		end
	end)
	layoutHand()
end

local function drawCard(side)
	local s = State.sides[side]
	if not s or State.gameOver then return nil end
	if #s.deck == 0 then
		s.fatigue += 1
		local dmg = CONFIG.FATIGUE_DMG * s.fatigue
		popText(heroPos(side), "📭 การ์ดหมดกอง!", COLORS.sub, 1)
		addLog("📭 " .. who(side) .. "การ์ดหมด! โดนความเหนื่อย " .. dmg, COLORS.atk)
		damageHero(side, dmg)
		return nil
	end
	local def = table.remove(s.deck)
	if #s.hand >= CONFIG.MAX_HAND then
		popText(heroPos(side), "🔥 มือเต็ม! " .. def.emoji .. " ไหม้", COLORS.atk, 0.9)
		addLog("🔥 มือ" .. who(side) .. "เต็ม " .. def.name .. " ไหม้เป็นจุณ", COLORS.atk)
		updateHeroUI()
		return nil
	end
	State.uid += 1
	local card = { uid = State.uid, def = def }
	table.insert(s.hand, card)
	if side == "player" then createHandCard(card, true) end
	updateHeroUI()
	return card
end

-- 👾 มอนสเตอร์บนสนาม
local function createUnitUI(unit)
	local v = buildCardVisual(SlotFrames[unit.side][unit.slot], unit.card)
	unit.ui = v
	v.root.MouseEnter:Connect(function()
		showPreview(unit.card, unit)
		if not unit.dead and State.selected ~= unit then tween(v.scale, 0.12, { Scale = 1.06 }) end
	end)
	v.root.MouseLeave:Connect(function()
		if not unit.dead and State.selected ~= unit then tween(v.scale, 0.12, { Scale = 1 }) end
	end)
	v.root.Activated:Connect(function() onUnitClicked(unit) end)
	updateUnitUI(unit)
	return v
end

updateUnitUI = function(unit)
	local v = unit.ui
	if not v or not v.atk then return end
	v.atk.Text = "⚔" .. unit.atk
	v.hp.Text = "❤" .. math.max(0, unit.hp)
	v.atk.TextColor3 = unit.atk > unit.card.atk and Color3.fromRGB(160, 255, 160)
		or (unit.atk < unit.card.atk and Color3.fromRGB(255, 200, 200) or Color3.new(1, 1, 1))
	v.hp.TextColor3 = unit.hp < unit.maxHp and Color3.fromRGB(255, 190, 190)
		or (unit.maxHp > unit.card.hp and Color3.fromRGB(160, 255, 160) or Color3.new(1, 1, 1))
	v.sub.Text = subText(unit.card, unit.kw)
	v.frozen.Visible = unit.frozen > 0
	previewKey = nil
end

local function summonUnit(side, def, slot)
	local s = State.sides[side]
	slot = slot or getEmptySlot(side)
	if not slot or State.gameOver then return nil end
	State.uid += 1
	local kw = toSet(def.kw)
	local unit = {
		uid = State.uid, card = def, side = side, slot = slot, atk = def.atk, hp = def.hp, maxHp = def.hp,
		kw = kw, attacksLeft = kw.Rush and 1 or 0, frozen = 0, dead = false,
	}
	s.board[slot] = unit
	local v = createUnitUI(unit)
	v.scale.Scale = 2.2
	v.root.Rotation = math.random(-25, 25)
	tween(v.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(v.root, 0.25, { Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.25, function()
		local p = centerOf(SlotFrames[side][slot])
		shockwave(p, RARITY[def.rarity].color, 260)
		burst(p, { "✨", "⭐", RARITY[def.rarity].color, Color3.new(1, 1, 1) }, def.rarity == "Common" and 8 or 16, 140)
		shake(def.cost >= 5 and 14 or 6, 0.25)
		playSound("summon", 1 + math.random() * 0.3, 0.45)
		if v.root.Parent then
			v.scale.Scale = 0.9
			tween(v.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if def.rarity == "Glue" or def.rarity == "Legendary" then flash(RARITY[def.rarity].color, 0.7, 0.4) end
	end)
	return unit
end

killUnit = function(unit)
	if unit.dead then return end
	local s = State.sides[unit.side]
	local pos = unitPos(unit)
	if unit.kw.Rebirth then
		unit.kw.Rebirth = nil
		unit.hp = math.max(100, math.floor(unit.maxHp / 200) * 100)
		popText(pos, "🔁 ฟื้นแล้วโว้ย!", COLORS.hp, 1.2)
		burst(pos, { "✨", "🔁", "💚" }, 12, 110)
		shockwave(pos, COLORS.hp, 240)
		if unit.ui then
			unit.ui.root.Rotation = 0
			tween(unit.ui.root, 0.5, { Rotation = 360 }, Enum.EasingStyle.Back)
			task.delay(0.5, function() if unit.ui and unit.ui.root.Parent then unit.ui.root.Rotation = 0 end end)
			speech(unit.ui.root, "ยังไม่ตายโว้ยย! 💪", COLORS.hp)
		end
		addLog("🔁 " .. unit.card.emoji .. " " .. unit.card.name .. " ฟื้นคืนชีพ!", COLORS.hp)
		updateUnitUI(unit)
		return
	end

	unit.dead = true
	s.board[unit.slot] = nil
	addLog("💀 " .. unit.card.emoji .. " " .. unit.card.name .. ": " .. pick(LINES.death), COLORS.sub)
	popText(pos, pick(LINES.death), Color3.new(1, 1, 1), 0.8, 110)
	local v = unit.ui
	if v and v.root.Parent then
		local size = v.root.AbsoluteSize
		local p = toOverlay(pos)
		local cg = make("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, ZIndex = 50, Parent = Overlay })
		v.root.Parent = cg
		v.root.Position = UDim2.fromScale(0.5, 0.5)
		v.root.Rotation = 0
		v.scale.Scale = 1
		local dir = math.random() < 0.5 and -1 or 1
		tween(cg, 0.9, { Position = UDim2.fromOffset(p.X + dir * px(260), p.Y - px(420)), Rotation = dir * 720, GroupTransparency = 1 })
		Debris:AddItem(cg, 1)
	end
	burst(pos, { "💀", "⭐", "💨" }, 10, 120)
	shake(8, 0.25)
	playSound("oof", 0.9 + math.random() * 0.4, 0.5)
	addGlue(otherSide(unit.side), 15)

	if unit.kw.Explode then
		shockwave(pos, Color3.fromRGB(255, 140, 40), 420)
		flash(Color3.fromRGB(255, 150, 50), 0.5, 0.4)
		popText(pos, "💥 ตูมมม!", Color3.fromRGB(255, 150, 40), 1.5)
		playSound("boom", 0.9, 0.7)
		shake(18, 0.4)
		addLog("💥 " .. unit.card.name .. " ระเบิดใส่ศัตรูทุกตัว 600!", Color3.fromRGB(255, 150, 40))
		for _, f in ipairs(getUnits(otherSide(unit.side))) do damageUnit(f, 600) end
	end
	refreshInteractivity()
end

damageUnit = function(unit, amount, opts)
	opts = opts or {}
	if unit.dead or amount <= 0 then return end
	amount = math.floor(amount)
	unit.hp -= amount
	local pos = unitPos(unit)
	if opts.crit then
		popText(pos, "💥" .. amount .. "!", COLORS.gold, 1.4)
	else
		popText(pos, "-" .. amount, COLORS.atk, 1)
	end
	local v = unit.ui
	if v and v.root.Parent then
		local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, ZIndex = 25, Parent = v.root })
		corner(f, UDim.new(0.08, 0))
		tween(f, 0.3, { BackgroundTransparency = 1 })
		Debris:AddItem(f, 0.35)
		task.spawn(function()
			for i = 1, 4 do
				if not v.root.Parent or unit.dead then break end
				v.root.Rotation = (i % 2 == 0 and 1 or -1) * (8 - i * 2)
				task.wait(0.04)
			end
			if v.root.Parent and not unit.dead then v.root.Rotation = 0 end
		end)
		if v.hp then punch(v.hp.Parent) end
	end
	burst(pos, { COLORS.atk, Color3.fromRGB(255, 200, 80), Color3.new(1, 1, 1) }, 8, 70)
	updateUnitUI(unit)
	if unit.hp <= 0 then
		killUnit(unit)
	elseif math.random() < 0.3 and unit.ui then
		speech(unit.ui.root, pick(LINES.hurt), COLORS.atk)
	end
end

local function buffUnit(unit, da, dh)
	if unit.dead then return end
	unit.atk = math.max(0, unit.atk + da)
	unit.maxHp += dh
	unit.hp += dh
	local txt = dh == 0 and ("+" .. da .. " ⚔") or string.format("+%d/+%d", da, dh)
	popText(unitPos(unit), txt, COLORS.hp, 0.9)
	if unit.ui and unit.ui.atk then
		punch(unit.ui.atk.Parent)
		punch(unit.ui.hp.Parent)
	end
	burst(unitPos(unit), { "⬆️", "✨" }, 5, 60)
	updateUnitUI(unit)
end

local function freezeUnit(u)
	if u.dead then return end
	u.frozen = math.max(u.frozen, 1)
	if State.current == u.side then u.attacksLeft = 0 end
	popText(unitPos(u), "🧊 ค้าง!", Color3.fromRGB(150, 230, 255), 0.9)
	burst(unitPos(u), { "❄️", "🧊" }, 6, 70)
	updateUnitUI(u)
end

local function bounceUnit(unit)
	if unit.dead then return end
	unit.dead = true
	local s = State.sides[unit.side]
	s.board[unit.slot] = nil
	local pos = unitPos(unit)
	popText(pos, "🏃 กลับบ้านนน!", COLORS.sub, 1)
	local v = unit.ui
	if v and v.root.Parent then
		local size = v.root.AbsoluteSize
		local p = toOverlay(pos)
		v.root.Parent = Overlay
		v.root.Size = UDim2.fromOffset(size.X, size.Y)
		v.root.Position = UDim2.fromOffset(p.X, p.Y)
		v.root.ZIndex = 50
		local dest = toOverlay(heroPos(unit.side))
		tween(v.root, 0.5, { Position = UDim2.fromOffset(dest.X, dest.Y), Rotation = 360 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(v.scale, 0.5, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(v.root, 0.55)
	end
	if not unit.card.token and #s.hand < CONFIG.MAX_HAND then
		State.uid += 1
		local card = { uid = State.uid, def = unit.card }
		table.insert(s.hand, card)
		if unit.side == "player" then task.delay(0.5, function() if table.find(s.hand, card) then createHandCard(card, true) end end) end
	end
	addLog("📢 " .. unit.card.emoji .. " " .. unit.card.name .. " โดนแม่เรียกกลับบ้าน", COLORS.sub)
	updateHeroUI()
	refreshInteractivity()
end

---------------------------------------------------------------------
-- 🃏 9) การ์ดทั้งหมด (26 ใบ + การ์ดเรียก 2 ใบ)
---------------------------------------------------------------------
local CARDS, CARD_LIST = {}, {}
local function addCard(def)
	def.kind = def.kind or "Monster"
	def.weight = def.weight or 2
	def.atk = def.atk or 0
	def.hp = def.hp or 0
	CARDS[def.id] = def
	if not def.token then table.insert(CARD_LIST, def) end
end

-- 👾 มอนสเตอร์
addCard({ id = "chicken", name = "ไก่ย่างอมตะ", emoji = "🐔", cost = 1, atk = 500, hp = 500, rarity = "Common", kw = { "Rebirth" }, weight = 3,
	desc = "ย่างกี่รอบก็ยังลุกขึ้นมาขันได้" })
addCard({ id = "cat", name = "แมวส้มจอมป่วน", emoji = "🐈", cost = 1, atk = 700, hp = 300, rarity = "Common", kw = { "Rush" }, weight = 3,
	desc = "วิ่งมาตบหน้าแล้ววิ่งหนี นิสัยแมวส้มแท้ๆ" })
addCard({ id = "dog", name = "หมาวัดตัวตึง", emoji = "🐕", cost = 2, atk = 500, hp = 1500, rarity = "Common", kw = { "Taunt" }, weight = 3,
	desc = "นอนขวางทาง ใครจะผ่านต้องข้ามศพมันก่อน" })
addCard({ id = "frog", name = "กบร้องเพลงลูกทุ่ง", emoji = "🐸", cost = 2, atk = 400, hp = 800, rarity = "Common", weight = 3,
	desc = "ลงสนาม: เรียกลูกอ๊อด 🐟 มาช่วย 1 ตัว",
	onPlay = function(u)
		local slot = getEmptySlot(u.side)
		if slot then
			speech(u.ui.root, "ลูกจ๋าาา มาช่วยพ่อ! 🎤", COLORS.hp)
			summonUnit(u.side, CARDS.tadpole, slot)
		end
	end })
addCard({ id = "tadpole", token = true, name = "ลูกอ๊อดวัยซน", emoji = "🐟", cost = 0, atk = 300, hp = 300, rarity = "Common",
	desc = "ตัวเล็กแต่ใจใหญ่ (การ์ดเรียก)" })
addCard({ id = "uncle", name = "ลุงวินซิ่งนรก", emoji = "🛵", cost = 3, atk = 1200, hp = 800, rarity = "Rare", kw = { "Rush" },
	desc = "ซิ่งมาตั้งแต่ยังไม่ทันลงสนาม" })
addCard({ id = "raccoon", name = "แรคคูนขโมยหมูปิ้ง", emoji = "🦝", cost = 2, atk = 600, hp = 900, rarity = "Rare", kw = { "Thief" },
	desc = "ต้นเทิร์นแอบดูด LP ศัตรู 300 มาเป็นของเรา" })
addCard({ id = "monkey", name = "ลิงขโมยมือถือ", emoji = "🐒", cost = 3, atk = 900, hp = 700, rarity = "Rare", kw = { "Thief", "Dodge" },
	desc = "ฉกแล้วปีนต้นไม้หนี จับไม่ได้ไล่ไม่ทัน" })
addCard({ id = "durian", name = "ทุเรียนพลีชีพ", emoji = "🍈", cost = 3, atk = 800, hp = 1000, rarity = "Rare", kw = { "Explode" },
	desc = "ตายเมื่อไหร่ กลิ่นจะระเบิดใส่ศัตรูทุกตัว 600" })
addCard({ id = "ninja", name = "นินจาหนีหนี้", emoji = "🥷", cost = 3, atk = 1100, hp = 700, rarity = "Rare", kw = { "Dodge" },
	desc = "หลบเก่งเพราะฝึกหนีเจ้าหนี้มาทั้งชีวิต" })
addCard({ id = "zombie", name = "ซอมบี้มนุษย์เงินเดือน", emoji = "🧟", cost = 4, atk = 1200, hp = 1300, rarity = "Rare", kw = { "Rebirth" },
	desc = "ตายแล้วยังต้องลุกมาทำงานต่อ" })
addCard({ id = "dino", name = "ไดโนแขนสั้น", emoji = "🦖", cost = 4, atk = 2000, hp = 1600, rarity = "Common", missBonus = 0.25,
	desc = "แรงเยอะแต่แขนสั้น โอกาสตีวืด +25%" })
addCard({ id = "grandma", name = "ยายรองเท้าแตะ", emoji = "👵", cost = 4, atk = 1300, hp = 1600, rarity = "Legendary", kw = { "Taunt" },
	desc = "ลงสนาม: ปารองเท้าแตะใส่ศัตรูสุ่ม 700",
	onPlay = function(u)
		local foe = otherSide(u.side)
		local t = randomUnit(foe)
		speech(u.ui.root, "ไอ้หลานเวรรร!! 👡", COLORS.gold)
		projectile(unitPos(u), t and unitPos(t) or heroPos(foe), "👡", 0.35, true)
		playSound("splat")
		if t then damageUnit(t, 700) else damageHero(foe, 700) end
	end })
addCard({ id = "wizard", name = "พ่อมดไลฟ์สด", emoji = "🧙", cost = 5, atk = 1500, hp = 1500, rarity = "Legendary",
	desc = "ลงสนาม: กดไลก์กดแชร์ จั่วการ์ด 2 ใบ",
	onPlay = function(u)
		speech(u.ui.root, "กดไลก์ กดแชร์ กดกระดิ่ง 🔔", COLORS.gold)
		for _ = 1, 2 do drawCard(u.side); task.wait(0.25) end
	end })
addCard({ id = "buffalo", name = "ควายบึ้กพลังช้าง", emoji = "🐃", cost = 6, atk = 2500, hp = 2500, rarity = "Legendary", kw = { "Rush" },
	desc = "วิ่งชนทุกอย่างที่ขวางหน้า ไม่เบรกไม่สน" })
addCard({ id = "clown", name = "ตัวตลกหัวร้อน", emoji = "🤡", cost = 3, atk = 1000, hp = 1000, rarity = "Glue",
	desc = "ลงสนาม: สลับ ATK กับ HP ของศัตรูสุ่ม 1 ตัว",
	onPlay = function(u)
		local t = randomUnit(otherSide(u.side))
		if not t then speech(u.ui.root, "ไม่มีใครให้แกล้ง เซ็ง 😑", COLORS.sub); return end
		projectile(unitPos(u), unitPos(t), "🤡", 0.35)
		local a = t.atk
		t.atk = t.hp
		t.hp = math.max(100, a)
		t.maxHp = math.max(t.maxHp, t.hp)
		popText(unitPos(t), "🤡 สลับ ATK/HP!", COLORS.glue, 1.1)
		updateUnitUI(t)
	end })
addCard({ id = "duck", name = "เป็ดยางพิฆาต", emoji = "🦆", cost = 1, atk = 100, hp = 100, rarity = "Glue", kw = { "Dodge", "Explode" },
	desc = "ตัวเล็กแต่โคตรกวน ตายแล้วยังระเบิดใส่อีก" })
addCard({ id = "dragon", name = "มังกรกาวพันปี", emoji = "🐉", cost = 7, atk = 3000, hp = 3000, rarity = "Glue", kw = { "Taunt" },
	desc = "ลงสนาม: เติมหลอดกาว +50 สั่นสะเทือนทั้งจักรวาล",
	onPlay = function(u)
		speech(u.ui.root, "กาวพันปี ตื่นแล้วโว้ยย!! 🐉", COLORS.glue)
		shake(20, 0.6)
		flash(COLORS.glue, 0.5, 0.5)
		rain("✨", 15)
		addGlue(u.side, 50)
	end })
addCard({ id = "unicorn", token = true, name = "ยูนิคอร์นกาว", emoji = "🦄", cost = 0, atk = 2000, hp = 2000, rarity = "Glue", kw = { "Taunt" },
	desc = "ได้มาจากการทอยเต๋าได้ 6 (การ์ดเรียก)" })

-- ✨ เวท
addCard({ id = "banana", kind = "Spell", name = "เปลือกกล้วย", emoji = "🍌", cost = 1, rarity = "Common", weight = 3,
	desc = "วางกับดัก: ศัตรูที่โจมตีครั้งถัดไปจะลื่นล้ม ตีพลาด + เจ็บ 300",
	ai = function(side) return State.sides[side].bananas < 2 end,
	spell = function(side)
		local s = State.sides[side]
		s.bananas += 1
		local p = centerOf(BoardFrame[side])
		burst(p, { "🍌" }, 10, 200)
		popText(p, "🍌 วางกับดักแล้ว แหะๆ", COLORS.gold, 1)
		updateHeroUI()
	end })
addCard({ id = "slipper", kind = "Spell", name = "รองเท้าแตะแม่", emoji = "👡", cost = 2, rarity = "Rare",
	desc = "ปาใส่มอนศัตรูที่ ATK สูงสุด 1500 (ไม่มีมอน ปาใส่หน้า 800)",
	spell = function(side)
		local foe = otherSide(side)
		local best
		for _, u in ipairs(getUnits(foe)) do
			if not best or u.atk > best.atk then best = u end
		end
		projectile(heroPos(side), best and unitPos(best) or heroPos(foe), "👡", 0.4, true)
		playSound("splat")
		popText((best and unitPos(best) or heroPos(foe)) - Vector2.new(0, px(50)), "เพี๊ยะ!!", COLORS.gold, 1.4)
		if best then damageUnit(best, 1500) else damageHero(foe, 800) end
	end })
addCard({ id = "bomb", kind = "Spell", name = "ระเบิดปลาร้า", emoji = "💣", cost = 4, rarity = "Rare",
	desc = "ดาเมจ 800 ใส่มอนสเตอร์ศัตรูทุกตัว กลิ่นติดทนนาน",
	ai = function(side) return #getUnits(otherSide(side)) >= 2 end,
	spell = function(side)
		local foe = otherSide(side)
		local p = centerOf(BoardFrame[foe])
		projectile(heroPos(side), p, "💣", 0.45, true)
		flash(Color3.fromRGB(255, 170, 60), 0.4, 0.5)
		shockwave(p, Color3.fromRGB(255, 140, 40), 700)
		burst(p, { "💥", "🔥", "🐟" }, 20, 300)
		shake(22, 0.5)
		playSound("boom", 0.8, 0.8)
		for _, u in ipairs(getUnits(foe)) do damageUnit(u, 800) end
	end })
addCard({ id = "dice", kind = "Spell", name = "ลูกเต๋ากาว", emoji = "🎲", cost = 2, rarity = "Glue",
	desc = "ทอยเต๋า! 1=ซวยเอง 2=จั่ว 3=ฮีล 4=ตีศัตรูหมด 5=บัฟ 6=ยูนิคอร์น",
	spell = function(side)
		local foe = otherSide(side)
		local center = centerOf(Main)
		local c = toOverlay(center)
		local d = label({ Text = "🎲", Font = Enum.Font.FredokaOne, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(px(260), px(130)), ZIndex = 70, Parent = Overlay })
		make("UIStroke", { Thickness = 4, Parent = d })
		for i = 1, 12 do
			d.Text = "🎲 " .. math.random(1, 6)
			d.Rotation = math.random(-30, 30)
			playSound("click", 1 + i * 0.05, 0.25)
			task.wait(0.06 + i * 0.008)
		end
		local roll = math.random(1, 6)
		d.Text = "🎲 " .. roll
		d.Rotation = 0
		punch(d, 1.6)
		shockwave(center, COLORS.gold, 400)
		task.wait(0.5)
		d:Destroy()
		addLog("🎲 ทอยได้ " .. roll .. "!", COLORS.gold)
		if roll == 1 then
			popText(center, "ดวงซวย! โดนเอง 1000 🤣", COLORS.atk, 1.2)
			damageHero(side, 1000)
		elseif roll == 2 then
			popText(center, "จั่ว 2 ใบ!", COLORS.mana, 1.2)
			drawCard(side); task.wait(0.2); drawCard(side)
		elseif roll == 3 then
			popText(center, "ฮีล 2000!", COLORS.hp, 1.2)
			healHero(side, 2000)
		elseif roll == 4 then
			popText(center, "ตีศัตรูทุกตัว 700!", COLORS.atk, 1.2)
			local foes = getUnits(foe)
			if #foes == 0 then damageHero(foe, 700) end
			for _, u in ipairs(foes) do damageUnit(u, 700) end
		elseif roll == 5 then
			popText(center, "มอนเราทุกตัว +500 ATK!", COLORS.hp, 1.2)
			for _, u in ipairs(getUnits(side)) do buffUnit(u, 500, 0) end
		else
			popText(center, "🦄 แจ็คพอตกาว!!!", COLORS.glue, 1.5)
			rain("🦄", 12)
			local slot = getEmptySlot(side)
			if slot then summonUnit(side, CARDS.unicorn, slot) else healHero(side, 1500) end
		end
	end })
addCard({ id = "mookata", kind = "Spell", name = "หมูกระทะฟื้นพลัง", emoji = "🥓", cost = 2, rarity = "Common",
	desc = "ฟื้น LP 1500 และมอนเราทุกตัวฟื้นเลือด 500",
	ai = function(side) return State.sides[side].lp <= CONFIG.START_LP - 1500 end,
	spell = function(side)
		rain("🥓", 12)
		healHero(side, 1500)
		for _, u in ipairs(getUnits(side)) do
			local amt = math.min(500, u.maxHp - u.hp)
			if amt > 0 then u.hp += amt; popText(unitPos(u), "+" .. amt, COLORS.hp, 0.8); updateUnitUI(u) end
		end
	end })
addCard({ id = "momcall", kind = "Spell", name = "เสียงแม่เรียก", emoji = "📢", cost = 3, rarity = "Rare",
	desc = "มอนศัตรูสุ่ม 1 ตัวต้องกลับบ้านทันที (กลับขึ้นมือ)",
	ai = function(side) return #getUnits(otherSide(side)) > 0 end,
	spell = function(side)
		local t = randomUnit(otherSide(side))
		if not t then return end
		popText(unitPos(t) - Vector2.new(0, px(60)), "📢 กลับบ้านเดี๋ยวนี้!!", COLORS.gold, 1.1)
		shake(10, 0.3)
		task.wait(0.4)
		bounceUnit(t)
	end })
addCard({ id = "coffee", kind = "Spell", name = "กาแฟ 3 แก้ว", emoji = "☕", cost = 1, rarity = "Common",
	desc = "มอนเราทุกตัว ATK +300 และตีได้อีกครั้ง",
	ai = function(side) return #getUnits(side) > 0 end,
	spell = function(side)
		for _, u in ipairs(getUnits(side)) do
			buffUnit(u, 300, 0)
			if u.frozen <= 0 then u.attacksLeft = 1 end
			if u.ui then speech(u.ui.root, "ตาสว่าง!! ☕", COLORS.gold) end
		end
	end })
addCard({ id = "lag", kind = "Spell", name = "เน็ตหลุด", emoji = "📶", cost = 3, rarity = "Rare",
	desc = "มอนศัตรูทุกตัวค้าง (แช่แข็ง) 1 เทิร์น",
	ai = function(side) return #getUnits(otherSide(side)) > 0 end,
	spell = function(side)
		for _ = 1, 6 do flash(Color3.fromHSV(math.random(), 1, 1), 0.75, 0.08); task.wait(0.05) end
		shake(12, 0.3)
		for _, u in ipairs(getUnits(otherSide(side))) do freezeUnit(u) end
	end })
addCard({ id = "gluetube", kind = "Spell", name = "กาวตราช้าง", emoji = "🧪", cost = 0, rarity = "Common",
	desc = "เติมหลอดกาว +35 และจั่วการ์ด 1 ใบ",
	spell = function(side)
		burst(heroPos(side), { "🧪", COLORS.glue }, 12, 140)
		addGlue(side, 35)
		drawCard(side)
	end })

---------------------------------------------------------------------
-- 🎮 10) เล่นการ์ด + โจมตี
---------------------------------------------------------------------
local function canAttack(u)
	return u and not u.dead and u.attacksLeft > 0 and u.frozen <= 0 and u.atk > 0
end

local function hasTaunt(side)
	for _, u in ipairs(getUnits(side)) do
		if u.kw.Taunt then return true end
	end
	return false
end

local function isValidTarget(att, target)
	local foe = otherSide(att.side)
	if target == "hero" then return not hasTaunt(foe) end
	if target.dead or target.side ~= foe then return false end
	return (not hasTaunt(foe)) or target.kw.Taunt == true
end

refreshInteractivity = function()
	local myTurn = canAct()
	local sel = State.selected
	if sel and (sel.dead or not canAttack(sel) or not myTurn) then State.selected = nil; sel = nil end
	local anyAction = false
	for _, side in ipairs(SIDES) do
		for i = 1, CONFIG.SLOTS do
			local glow = SlotGlow[side][i]
			local u = State.sides[side] and State.sides[side].board[i]
			local color
			if u then
				if side == "player" then
					if sel == u then
						color = COLORS.gold
					elseif myTurn and canAttack(u) then
						color = COLORS.hp
						anyAction = true
					end
					if u.ui and sel ~= u then tween(u.ui.scale, 0.15, { Scale = 1 }) end
				elseif sel and isValidTarget(sel, u) then
					color = COLORS.atk
				end
			end
			glow.Visible = color ~= nil
			if color then glow.BackgroundColor3 = color end
		end
	end
	Hero.enemy.ring.Visible = sel ~= nil and isValidTarget(sel, "hero")

	local ps = State.sides.player
	if ps then
		for _, c in ipairs(ps.hand) do
			local playable = myTurn and c.def.cost <= ps.mana and (c.def.kind == "Spell" or getEmptySlot("player") ~= nil)
			if playable then anyAction = true end
			if c.ui then c.ui.dim.Visible = not playable end
		end
		UltBtn.label.Text = ps.glue >= CONFIG.GLUE_MAX and "🧪 ท่าไม้ตาย! [Q]" or ("🧪 กาว " .. math.floor(ps.glue) .. "%")
		if myTurn and ps.glue >= CONFIG.GLUE_MAX then anyAction = true end
	end
	State.suggestEnd = myTurn and not anyAction
	EndBtn.label.Text = (State.current == "player") and "⏭ จบเทิร์น [Space]" or "⏳ รอบอทคิด..."

	if State.gameOver then
		CenterHint.Text = ""
	elseif State.current ~= "player" then
		CenterHint.Text = "🤖 บอทลุงกาวกำลังคิด... (ช้ามาก)"
	elseif sel then
		CenterHint.Text = "🎯 เลือกเป้าหมาย! (มอนแดง หรือ หน้าบอท) • คลิกขวายกเลิก"
	elseif State.suggestEnd then
		CenterHint.Text = "✅ ไม่มีอะไรให้ทำแล้ว กด Space จบเทิร์นเลย!"
	else
		CenterHint.Text = "👆 ลากการ์ดขึ้นสนาม • คลิกตัวเรืองเขียวเพื่อตี"
	end
end

local function flyGhost(def, fromAbs, toAbs, height, t, keep)
	local a, b = toOverlay(fromAbs), toOverlay(toAbs)
	local v = buildCardVisual(Overlay, def, { active = false, z = 45, size = UDim2.fromOffset(height * 0.72, height), pos = UDim2.fromOffset(a.X, a.Y) })
	v.scale.Scale = 0.6
	v.root.Rotation = math.random(-30, 30)
	tween(v.root, t, { Position = UDim2.fromOffset(b.X, b.Y), Rotation = 0 }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	tween(v.scale, t, { Scale = 1.15 }, Enum.EasingStyle.Quart)
	playSound("swing", 1.5, 0.3)
	task.wait(t)
	if keep then return v end
	v.root:Destroy()
	return nil
end

local function playCard(side, card)
	local s = State.sides[side]
	local def = card.def
	local idx = table.find(s.hand, card)
	if not idx or s.mana < def.cost or State.gameOver then return false end
	if def.kind == "Monster" and not getEmptySlot(side) then return false end
	State.busy = true
	s.mana -= def.cost
	table.remove(s.hand, idx)
	if hoveredCard == card then hoveredCard = nil end
	updateHeroUI()
	refreshInteractivity()

	local startPos
	if card.ui then
		startPos = centerOf(card.ui.root)
		card.ui.root:Destroy()
		card.ui = nil
	else
		startPos = heroPos(side)
	end
	layoutHand()
	addLog(string.format("%s %sเล่น %s %s", side == "player" and "😎" or "🤖", who(side), def.emoji, def.name), side == "player" and COLORS.player or COLORS.enemy)

	if def.kind == "Monster" then
		local slot = getEmptySlot(side)
		local slotFrame = SlotFrames[side][slot]
		flyGhost(def, startPos, centerOf(slotFrame), slotFrame.AbsoluteSize.Y, 0.35)
		local unit = summonUnit(side, def, slot)
		task.wait(0.35)
		if unit and def.onPlay and not State.gameOver then
			def.onPlay(unit)
			task.wait(0.4)
		end
	else
		local center = centerOf(Main)
		local ghost = flyGhost(def, startPos, center, Main.AbsoluteSize.Y * 0.38, 0.35, true)
		flash(Color3.fromRGB(200, 150, 255), 0.6, 0.4)
		shockwave(center, Color3.fromRGB(200, 150, 255), 520)
		burst(center, { "✨", "⭐", COLORS.glue }, 14, 220)
		playSound("summon", 1.4, 0.5)
		task.wait(0.45)
		if ghost then
			tween(ghost.scale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			tween(ghost.root, 0.3, { Rotation = 360 })
			Debris:AddItem(ghost.root, 0.35)
		end
		task.wait(0.2)
		if not State.gameOver then def.spell(side) end
		task.wait(0.3)
	end
	addGlue(side, 5)
	if side == "player" and State.isPvP then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
		local pvpAction = folder and folder:FindFirstChild("PvPAction")
		if pvpAction then
			pvpAction:FireServer(State.pvpMatchId, "PlayCard", {
				slot = card.slot,
				cardId = def.id,
				isSpell = (def.kind == "Spell"),
			})
		end
	end
	State.busy = false
	refreshInteractivity()
	checkGameOver()
	return true
end

tryPlayCard = function(card)
	if not canAct() then layoutHand(); return end
	local s = State.sides.player
	local def = card.def
	local v = card.ui
	if def.cost > s.mana then
		if v then
			popText(centerOf(v.root), "มานาไม่พอ! 💧", COLORS.mana, 0.9)
			task.spawn(function()
				for i = 1, 5 do v.root.Rotation = (i % 2 == 0 and 1 or -1) * 8; task.wait(0.04) end
				layoutHand()
			end)
		end
		if math.random() < 0.5 then speech(Hero.enemy.avatar, "มานาไม่พอ 555+ 🤣", COLORS.enemy, true) end
		layoutHand()
		return
	end
	if def.kind == "Monster" and not getEmptySlot("player") then
		popText(centerOf(BoardFrame.player), "สนามเต็มแล้ว! 🈵", COLORS.gold, 1)
		layoutHand()
		return
	end
	task.spawn(playCard, "player", card)
end

local function performAttack(attacker, target)
	if State.gameOver or not canAttack(attacker) or not isValidTarget(attacker, target) then return end
	State.busy = true
	State.selected = nil
	refreshInteractivity()
	local side, foe = attacker.side, otherSide(attacker.side)
	local s, fs = State.sides[side], State.sides[foe]
	attacker.attacksLeft -= 1

	if side == "player" and State.isPvP then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
		local pvpAction = folder and folder:FindFirstChild("PvPAction")
		if pvpAction then
			pvpAction:FireServer(State.pvpMatchId, "Attack", {
				attackerSlot = attacker.slot,
				targetType = (target == "hero") and "hero" or "unit",
				targetSlot = (target ~= "hero") and target.slot or nil,
			})
		end
	end
	local v = attacker.ui
	local board, slotFrame = BoardFrame[side], SlotFrames[side][attacker.slot]
	board.ZIndex, slotFrame.ZIndex = 6, 6

	local fromC = centerOf(v.root)
	local toC = target == "hero" and heroPos(foe) or unitPos(target)
	local delta = toC - fromC

	-- ง้าง
	playSound("swing")
	tween(v.root, 0.22, { Position = UDim2.new(0.5, -delta.X * 0.12, 0.5, -delta.Y * 0.12), Rotation = delta.X >= 0 and -12 or 12 })
	tween(v.scale, 0.22, { Scale = 1.2 })
	task.wait(0.24)

	local slipped = fs.bananas > 0
	if slipped then fs.bananas -= 1; updateHeroUI() end

	-- พุ่ง
	local frac = slipped and 0.45 or 0.85
	tween(v.root, 0.14, { Position = UDim2.new(0.5, delta.X * frac, 0.5, delta.Y * frac), Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.14)
	local impact = fromC + delta * frac
	local targetName = target == "hero" and ("หน้า" .. who(foe)) or (target.card.emoji .. " " .. target.card.name)

	if slipped then
		popText(impact, "🍌 ลื่นนน!", COLORS.gold, 1.3)
		playSound("splat")
		burst(impact, { "🍌", "💫" }, 8, 100)
		tween(v.root, 0.5, { Rotation = 540 })
		task.wait(0.5)
		if v.root.Parent then v.root.Rotation = 0 end
		addLog("🍌 " .. attacker.card.name .. " เหยียบเปลือกกล้วยล้มหน้าคะมำ!", COLORS.gold)
		damageUnit(attacker, 300)
	elseif math.random() < CONFIG.MISS_CHANCE + (attacker.card.missBonus or 0) then
		popText(impact, pick(LINES.miss), COLORS.sub, 1.1)
		burst(impact, { "💨" }, 5, 60)
		addLog("💨 " .. attacker.card.name .. " ตีวืด!", COLORS.sub)
	elseif target ~= "hero" and target.kw.Dodge and math.random() < 0.35 then
		local tv = target.ui
		if tv and tv.root.Parent then
			tween(tv.root, 0.12, { Position = UDim2.new(0.5, tv.root.AbsoluteSize.X * 0.6, 0.5, 0), Rotation = 15 })
			task.delay(0.35, function()
				if tv.root.Parent and not target.dead then tween(tv.root, 0.25, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }, Enum.EasingStyle.Back) end
			end)
			speech(tv.root, "ไม่โดนหรอก แบร่ 😝", Color3.fromRGB(150, 230, 255))
		end
		popText(toC, "💨 หลบได้!", Color3.fromRGB(150, 230, 255), 1.1)
		addLog("💨 " .. target.card.name .. " หลบได้!", Color3.fromRGB(150, 230, 255))
	else
		local crit = math.random() < CONFIG.CRIT_CHANCE
		local dmg = math.floor(attacker.atk * (1 + s.combo * CONFIG.COMBO_BONUS) * (crit and 2 or 1))
		s.combo += 1
		playSound("hit", crit and 0.8 or 1)
		shockwave(impact, crit and COLORS.gold or Color3.new(1, 1, 1), crit and 340 or 200)
		burst(impact, { "💥", "⭐", COLORS.gold }, crit and 16 or 8, crit and 180 or 110)
		shake(crit and 16 or 7, 0.3)
		if crit then
			flash(COLORS.gold, 0.6, 0.3)
			popText(impact - Vector2.new(0, px(70)), pick(LINES.crit), COLORS.gold, 1.2)
		end
		if s.combo >= 2 then popText(impact + Vector2.new(px(90), -px(30)), "COMBO x" .. s.combo .. "!", COLORS.glue, 1) end
		addGlue(side, crit and 18 or 10)
		addGlue(foe, 6)
		addLog(string.format("⚔ %s ตี %s %d%s", attacker.card.name, targetName, dmg, crit and " (คริ!)" or ""), side == "player" and COLORS.player or COLORS.enemy)
		if target == "hero" then
			damageHero(foe, dmg, { crit = crit })
		else
			local counter = target.atk
			damageUnit(target, dmg, { crit = crit })
			if counter > 0 and not attacker.dead then damageUnit(attacker, counter) end
		end
	end

	if not attacker.dead and v.root.Parent then
		tween(v.root, 0.3, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }, Enum.EasingStyle.Back)
		tween(v.scale, 0.3, { Scale = 1 })
	end
	task.wait(0.35)
	board.ZIndex, slotFrame.ZIndex = 1, 2
	State.busy = false
	refreshInteractivity()
	checkGameOver()
end

onUnitClicked = function(unit)
	if unit.dead then return end
	if not canAct() then
		if unit.side == "player" and unit.ui then speech(unit.ui.root, "รอก่อนน ยังไม่ใช่ตาเรา ⏳", COLORS.sub) end
		return
	end
	if unit.side == "player" then
		if State.selected == unit then
			State.selected = nil
		elseif canAttack(unit) then
			State.selected = unit
			playSound("click")
			tween(unit.ui.scale, 0.15, { Scale = 1.12 }, Enum.EasingStyle.Back)
		else
			local msg = unit.frozen > 0 and "แข็งอยู่ ขยับไม่ได้ 🥶" or (unit.attacksLeft <= 0 and "เหนื่อยแล้ว ขอนอนก่อน 😴" or "ตีไม่ได้ง่ะ 🥲")
			speech(unit.ui.root, msg, COLORS.sub)
		end
		refreshInteractivity()
	else
		if State.selected then
			if isValidTarget(State.selected, unit) then
				task.spawn(performAttack, State.selected, unit)
			else
				popText(unitPos(unit), "🛡 ต้องตีตัวโล่ก่อน!", COLORS.gold, 0.9)
			end
		elseif unit.ui then
			speech(unit.ui.root, pick(LINES.taunt), COLORS.enemy)
		end
	end
end

---------------------------------------------------------------------
-- 🧪 11) ท่าไม้ตายกาว
---------------------------------------------------------------------
local function ultCutscene(side, ult)
	local dark = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 84, Parent = Overlay })
	tween(dark, 0.25, { BackgroundTransparency = 0.35 })
	local band = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1.7, 0.45), Size = UDim2.fromScale(1.3, 0.24),
		Rotation = -6, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 85, Parent = Overlay,
	})
	make("UIGradient", {
		Color = side == "player" and ColorSequence.new(COLORS.player, COLORS.glue) or ColorSequence.new(COLORS.enemy, Color3.fromRGB(120, 0, 60)),
		Parent = band,
	})
	local e = label({ Text = ult.emoji, Position = UDim2.fromScale(0.2, 0.08), Size = UDim2.fromScale(0.1, 0.84), Parent = band })
	make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = e })
	local n = label({ Text = "ท่าไม้ตาย: " .. ult.name .. "!!", Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.32, 0.1), Size = UDim2.fromScale(0.48, 0.48), Parent = band })
	make("UIStroke", { Thickness = 3, Parent = n })
	local d = label({ Text = (side == "player" and "😎 คุณ" or "🤖 บอท") .. " • " .. ult.desc, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.32, 0.62), Size = UDim2.fromScale(0.48, 0.26), Parent = band })
	make("UIStroke", { Thickness = 2, Parent = d })
	tween(band, 0.35, { Position = UDim2.fromScale(0.5, 0.45) }, Enum.EasingStyle.Back)
	playSound("boom", 1.3, 0.6)
	task.wait(0.3)
	flash(COLORS.glue, 0.4, 0.5)
	shake(10, 0.4)
	punch(e, 1.8)
	task.wait(1.1)
	tween(band, 0.3, { Position = UDim2.fromScale(-0.7, 0.45) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(dark, 0.3, { BackgroundTransparency = 1 })
	Debris:AddItem(band, 0.35)
	Debris:AddItem(dark, 0.35)
	task.wait(0.3)
end

local ULTS = {
	{ name = "ตบโต๊ะพลิกกระดาน", emoji = "🤚", desc = "ดาเมจ 1200 ใส่มอนศัตรูทุกตัว (ไม่มีมอน = ตบหน้า 1000)",
		run = function(side)
			local foe = otherSide(side)
			tween(Shaker, 0.12, { Rotation = 7 }); task.wait(0.12)
			tween(Shaker, 0.12, { Rotation = -7 }); task.wait(0.12)
			tween(Shaker, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
			shake(28, 0.6)
			playSound("boom", 0.8, 0.8)
			local units = getUnits(foe)
			if #units == 0 then damageHero(foe, 1000) end
			for _, u in ipairs(units) do damageUnit(u, 1200) end
			task.wait(0.4)
		end },
	{ name = "ฝนดาวตก", emoji = "☄️", desc = "ดาวตก 6 ลูก ลูกละ 500 สุ่มใส่ศัตรู",
		run = function(side)
			local foe = otherSide(side)
			for _ = 1, 6 do
				if State.gameOver then break end
				local targets = getUnits(foe)
				local t = (#targets > 0 and math.random() < 0.65) and targets[math.random(1, #targets)] or "hero"
				local to = t == "hero" and heroPos(foe) or unitPos(t)
				local from = Vector2.new(to.X + px(math.random(-300, 300)), Overlay.AbsolutePosition.Y - px(80))
				projectile(from, to, "☄️", 0.3, true)
				playSound("boom", 1 + math.random() * 0.4, 0.5)
				shake(10, 0.2)
				burst(to, { "🔥", "💥", COLORS.gold }, 8, 120)
				if t == "hero" then damageHero(foe, 500) else damageUnit(t, 500) end
				task.wait(0.12)
			end
		end },
	{ name = "โหมดแลค", emoji = "📶", desc = "มอนศัตรูทุกตัวค้าง 1 เทิร์น และโดน 300",
		run = function(side)
			local foe = otherSide(side)
			shake(30, 0.6)
			for _ = 1, 10 do flash(Color3.fromHSV(math.random(), 1, 1), 0.7, 0.08); task.wait(0.05) end
			popText(centerOf(BoardFrame[foe]), "⚠️ PING 999ms ⚠️", COLORS.atk, 1.5)
			for _, u in ipairs(getUnits(foe)) do
				freezeUnit(u)
				damageUnit(u, 300)
			end
			task.wait(0.4)
		end },
	{ name = "ปาร์ตี้หมูกระทะ", emoji = "🥓", desc = "ฟื้น 2500 LP และมอนเราทุกตัว +400/+400",
		run = function(side)
			rain("🥓", 20)
			rain("🍖", 10)
			healHero(side, 2500)
			for _, u in ipairs(getUnits(side)) do buffUnit(u, 400, 400) end
			task.wait(0.6)
		end },
	{ name = "เติมเกมหมดตัว", emoji = "💸", desc = "จั่ว 3 ใบ และเติมมานาเต็มหลอด",
		run = function(side)
			rain("💸", 25)
			local s = State.sides[side]
			s.mana = math.max(s.mana, s.maxMana)
			updateHeroUI()
			for _ = 1, 3 do drawCard(side); task.wait(0.25) end
		end },
}

local function useUltimate(side)
	local s = State.sides[side]
	if not s or s.glue < CONFIG.GLUE_MAX or State.gameOver then return false end
	State.busy = true
	State.selected = nil
	s.glue = 0
	updateHeroUI()
	refreshInteractivity()
	local ult = pick(ULTS)
	addLog("🧪 " .. who(side) .. "ใช้ท่าไม้ตาย " .. ult.emoji .. " " .. ult.name .. "!!", COLORS.glue)
	ultCutscene(side, ult)
	if not State.gameOver then ult.run(side) end
	task.wait(0.4)
	State.busy = false
	refreshInteractivity()
	checkGameOver()
	return true
end

local function tryUlt()
	local s = State.sides.player
	if not s or not canAct() then return end
	if s.glue < CONFIG.GLUE_MAX then
		popText(centerOf(UltBtn.button), "กาวยังไม่เต็ม! " .. math.floor(s.glue) .. "%", COLORS.glue, 0.8)
		return
	end
	if State.isPvP then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
		local pvpAction = folder and folder:FindFirstChild("PvPAction")
		if pvpAction then
			pvpAction:FireServer(State.pvpMatchId, "Ult", {})
		end
	end
	task.spawn(useUltimate, "player")
end

---------------------------------------------------------------------
-- 🌀 12) เหตุการณ์ปั่นๆ (สุ่มทุกเทิร์น)
---------------------------------------------------------------------
local EVENTS = {
	{ emoji = "🥓", name = "ฝนตกเป็นหมูกระทะ", desc = "ทั้งสองฝั่งฟื้น 800 LP", run = function()
		rain("🥓", 22); rain("🍖", 8)
		task.wait(0.8)
		healHero("player", 800); healHero("enemy", 800)
	end },
	{ emoji = "🐈", name = "แมวเดินทับคีย์บอร์ด", desc = "มอนสุ่ม 1 ตัวโดนแก้ ATK มั่วๆ", run = function()
		local all = allUnits()
		if #all == 0 then popText(centerOf(Main), "...แต่ไม่มีใครบนสนาม 🐈💤", COLORS.sub, 1); return end
		local u = pick(all)
		local p = unitPos(u)
		projectile(Vector2.new(Overlay.AbsolutePosition.X - px(50), p.Y), p, "🐈", 0.5, true)
		u.atk = math.random(1, 30) * 100
		popText(unitPos(u), "ATK = " .. u.atk .. " ⌨️", COLORS.gold, 1.2)
		if u.ui and u.ui.atk then punch(u.ui.atk.Parent) end
		updateUnitUI(u)
	end },
	{ emoji = "🙃", name = "จักรวาลกลับหัว", desc = "ATK กับ HP ของทุกตัวสลับกัน!", run = function()
		tween(Shaker, 0.6, { Rotation = 180 }, Enum.EasingStyle.Back)
		task.wait(1)
		for _, u in ipairs(allUnits()) do
			local a = u.atk
			u.atk = math.max(0, u.hp)
			u.hp = math.max(100, a)
			u.maxHp = math.max(u.maxHp, u.hp)
			updateUnitUI(u)
		end
		task.wait(0.5)
		tween(Shaker, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)
		task.wait(0.6)
		for _, u in ipairs(allUnits()) do popText(unitPos(u), "🔄", COLORS.glue, 1) end
	end },
	{ emoji = "📶", name = "Wi-Fi บ้านลุงล่ม", desc = "ฝั่งที่เล่นอยู่ว่างจัด ได้มานา +2", run = function(side)
		local s = State.sides[side]
		s.mana = math.min(CONFIG.MAX_MANA, s.mana + 2)
		popText(heroPos(side), "+2 💧", COLORS.mana, 1.2)
		updateHeroUI()
	end },
	{ emoji = "🍚", name = "แม่เรียกกินข้าว", desc = "มอนทุกตัวกินอิ่ม ฟื้นเลือดเต็ม", run = function()
		rain("🍚", 15)
		for _, u in ipairs(allUnits()) do
			if u.hp < u.maxHp then
				popText(unitPos(u), "+" .. (u.maxHp - u.hp), COLORS.hp, 0.9)
				u.hp = u.maxHp
				updateUnitUI(u)
			end
		end
	end },
	{ emoji = "🛵", name = "ลุงวินขับผ่ากลางสนาม", desc = "ชนมอนสุ่ม 1000 (ไม่มีมอน = ชนหน้าคนเล่น 500)", run = function(side)
		local all = allUnits()
		local x0 = Overlay.AbsolutePosition.X - px(80)
		if #all > 0 then
			local u = pick(all)
			local p = unitPos(u)
			projectile(Vector2.new(x0, p.Y), p, "🛵", 0.45, true)
			playSound("boom")
			damageUnit(u, 1000)
		else
			local p = heroPos(side)
			projectile(Vector2.new(x0, p.Y), p, "🛵", 0.45, true)
			damageHero(side, 500)
		end
	end },
	{ emoji = "🌋", name = "แผ่นดินไหวกาว", desc = "มอนสเตอร์ทุกตัวโดน 300", run = function()
		shake(22, 1)
		playSound("boom", 0.6, 0.7)
		task.wait(0.5)
		for _, u in ipairs(allUnits()) do damageUnit(u, 300) end
	end },
	{ emoji = "🕊", name = "นกพิราบส่งการ์ด", desc = "ทั้งสองฝั่งจั่วการ์ด 1 ใบ", run = function()
		rain("🕊", 6)
		drawCard("player"); drawCard("enemy")
	end },
	{ emoji = "🌀", name = "พายุกาวถล่ม", desc = "หลอดกาวทั้งสองฝั่ง +30", run = function()
		rain("🧪", 15)
		addGlue("player", 30); addGlue("enemy", 30)
	end },
	{ emoji = "🦟", name = "ยุงบุกสนาม", desc = "ทั้งสองฝั่งโดนกัด เสีย 300 LP", run = function()
		rain("🦟", 30)
		task.wait(0.8)
		damageHero("player", 300); damageHero("enemy", 300)
	end },
	{ emoji = "☀️", name = "พระอาทิตย์ขึ้นสองดวง", desc = "ร้อนจนหัวร้อน มอนทุกตัว ATK +300", run = function()
		flash(Color3.fromRGB(255, 220, 100), 0.4, 0.8)
		for _, u in ipairs(allUnits()) do buffUnit(u, 300, 0) end
	end },
	{ emoji = "🐸", name = "ฝนตกเป็นกบ", desc = "ลูกอ๊อดมาเกิดฝั่งละ 1 ตัว", run = function()
		rain("🐸", 18)
		task.wait(0.6)
		for _, sd in ipairs(SIDES) do
			local slot = getEmptySlot(sd)
			if slot then summonUnit(sd, CARDS.tadpole, slot) end
		end
	end },
}

local function eventCard(ev)
	local c = toOverlay(centerOf(Main))
	local box = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromScale(0.36, 0.3), BackgroundColor3 = COLORS.panel, ZIndex = 76, Parent = Overlay })
	make("UIAspectRatioConstraint", { AspectRatio = 1.8, Parent = box })
	corner(box, UDim.new(0.1, 0))
	local st = stroke(box, Color3.new(1, 1, 1), 4)
	spinGradient(make("UIGradient", { Color = RAINBOW, Parent = st }), 300)
	label({ Text = "🌀 เหตุการณ์ปั่น! 🌀", TextColor3 = COLORS.glue, Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.14), Parent = box })
	local e = label({ Text = ev.emoji, Position = UDim2.fromScale(0.35, 0.2), Size = UDim2.fromScale(0.3, 0.35), Parent = box })
	label({ Text = ev.name, Font = Enum.Font.GothamBlack, TextColor3 = COLORS.gold, Position = UDim2.fromScale(0.05, 0.57), Size = UDim2.fromScale(0.9, 0.16), Parent = box })
	label({ Text = ev.desc, TextColor3 = COLORS.sub, Font = Enum.Font.GothamMedium, Position = UDim2.fromScale(0.05, 0.76), Size = UDim2.fromScale(0.9, 0.14), Parent = box })
	local sc = make("UIScale", { Scale = 0, Parent = box })
	box.Rotation = -180
	tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(box, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	playSound("summon", 0.7, 0.5)
	task.wait(0.5)
	punch(e, 1.5)
	task.wait(1.2)
	tween(sc, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Debris:AddItem(box, 0.3)
	task.wait(0.25)
end

local function runChaos(side)
	local ev = pick(EVENTS)
	addLog("🌀 เหตุการณ์ปั่น: " .. ev.emoji .. " " .. ev.name, COLORS.glue)
	eventCard(ev)
	if not State.gameOver then ev.run(side) end
	task.wait(0.5)
end

---------------------------------------------------------------------
-- 🔄 13) ระบบเทิร์น + บอท
---------------------------------------------------------------------
local function setTurnLabel()
	TurnLabel.Text = string.format("เทิร์น %d • %s", State.turnCount, State.current == "player" and "ตาคุณ 😎" or "ตาบอท 🤖")
end

local function startTurn(side)
	if State.gameOver then return end
	local gid = State.gameId
	State.current = side
	State.turnCount += 1
	State.selected = nil
	State.busy = true
	local s = State.sides[side]
	s.maxMana = math.min(CONFIG.MAX_MANA, s.maxMana + 1)
	s.mana = s.maxMana
	s.combo = 0
	for _, u in ipairs(getUnits(side)) do
		u.attacksLeft = u.frozen > 0 and 0 or 1
		updateUnitUI(u)
	end
	setTurnLabel()
	updateHeroUI()
	refreshInteractivity()
	if side == "player" then
		banner("ตาคุณแล้ว! 😎", pick(LINES.turnPlayer), COLORS.player)
	else
		local foeName = State.isPvP and (State.pvpOpponent and State.pvpOpponent.DisplayName or "คู่ต่อสู้") or (State.currentBot and State.currentBot.name or "บอทลุงกาว 🤖")
		banner("ตาของ " .. foeName, pick(LINES.turnEnemy), COLORS.enemy)
	end
	playSound("summon", side == "player" and 1.2 or 0.8, 0.4)
	task.wait(1.1)
	if State.gameId ~= gid or State.gameOver then return end

	for _, u in ipairs(getUnits(side)) do
		if u.kw.Thief and not State.gameOver then
			local foe = otherSide(side)
			projectile(heroPos(foe), unitPos(u), "💰", 0.35)
			addLog("🦝 " .. u.card.name .. " ขโมย LP 300!", COLORS.gold)
			damageHero(foe, 300)
			healHero(side, 300)
		end
	end
	if State.gameId ~= gid or State.gameOver then return end

	drawCard(side)
	task.wait(0.3)
	if State.turnCount > 2 and math.random() < CHAOS_MODES[State.chaos].chance then
		runChaos(side)
	end
	if State.gameId ~= gid or State.gameOver then return end
	State.busy = false
	refreshInteractivity()
	if side == "enemy" and not State.isPvP then task.spawn(botTurn, gid) end
end

local function finishTurn(side)
	if State.gameOver then return end
	State.busy = true
	State.selected = nil
	for _, u in ipairs(getUnits(side)) do
		if u.frozen > 0 then u.frozen -= 1; updateUnitUI(u) end
	end
	if side == "player" and State.isPvP then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
		local pvpAction = folder and folder:FindFirstChild("PvPAction")
		if pvpAction then
			pvpAction:FireServer(State.pvpMatchId, "EndTurn", {})
		end
	end
	refreshInteractivity()
	task.wait(0.2)
	startTurn(otherSide(side))
end

local function botChooseTarget(att)
	local foes = getUnits("player")
	local taunts = {}
	for _, u in ipairs(foes) do
		if u.kw.Taunt then table.insert(taunts, u) end
	end
	if #taunts > 0 then
		table.sort(taunts, function(a, b) return a.hp < b.hp end)
		return taunts[1]
	end
	local total = 0
	for _, u in ipairs(getUnits("enemy")) do
		if canAttack(u) then total += u.atk end
	end
	if State.sides.player.lp <= total then return "hero" end
	local best, bestScore
	for _, u in ipairs(foes) do
		if att.atk >= u.hp then
			local score = u.atk + (att.hp > u.atk and 1000 or 0)
			if not bestScore or score > bestScore then best, bestScore = u, score end
		end
	end
	if best and (bestScore >= 1000 or best.atk >= 1500) then return best end
	if #foes > 0 and math.random() < 0.15 then return pick(foes) end -- บอทกาว ตีมั่ว
	return "hero"
end

botTurn = function(gid)
	local function alive()
		return State.gameId == gid and not State.gameOver and State.current == "enemy"
	end
	local s = State.sides.enemy
	local bot = State.currentBot or DEFAULT_BOT
	speech(Hero.enemy.avatar, pick(LINES.botThink), COLORS.enemy, true)
	task.wait(bot.think or 0.9)
	if not alive() then return end

	-- แฮกเกอร์โกงมานา +1
	if bot.cheat then
		s.mana = math.min(CONFIG.MAX_MANA, s.mana + 1)
		popText(heroPos("enemy"), "💻 แฮกมานา +1!", COLORS.gold, 1)
		task.wait(0.2)
	end

	if s.glue >= CONFIG.GLUE_MAX then useUltimate("enemy"); task.wait(0.4) end

	for _ = 1, 10 do
		if not alive() then return end
		local options = {}
		for _, c in ipairs(s.hand) do
			local d = c.def
			if d.cost <= s.mana then
				if d.kind == "Monster" then
					if getEmptySlot("enemy") then table.insert(options, c) end
				elseif not d.ai or d.ai("enemy") then
					table.insert(options, c)
				end
			end
		end
		if #options == 0 then break end
		if bot.mistake and math.random() < bot.mistake then
			shuffle(options)
		else
			table.sort(options, function(a, b) return a.def.cost > b.def.cost end)
		end
		if not playCard("enemy", options[1]) then break end
		task.wait(bot.think and (bot.think * 0.5) or 0.5)
	end

	for _ = 1, 12 do
		if not alive() then return end
		local attacker
		for _, u in ipairs(getUnits("enemy")) do
			if canAttack(u) then attacker = u; break end
		end
		if not attacker then break end
		local target = botChooseTarget(attacker)
		if bot.mistake and math.random() < bot.mistake then
			local foes = getUnits("player")
			if #foes > 0 then target = pick(foes) end
		end
		if target and isValidTarget(attacker, target) then
			performAttack(attacker, target)
			task.wait(0.35)
		else
			attacker.attacksLeft = 0
		end
	end

	if alive() and s.glue >= CONFIG.GLUE_MAX then useUltimate("enemy") end
	if not alive() then return end
	speech(Hero.enemy.avatar, pick(LINES.botEnd), COLORS.enemy, true)
	task.wait(0.6)
	if alive() then finishTurn("enemy") end
end

---------------------------------------------------------------------
-- 😜 14) ยั่ว / จิ้ม / จบเกม / รีเซ็ต
---------------------------------------------------------------------
local function pokeBot()
	if State.gameOver then return end
	local s = State.sides.enemy
	if not s then return end
	s.pokes += 1
	local av = Hero.enemy.avatar
	playSound("click", 1.5)
	punch(av, 0.75)
	if s.pokes >= 8 then
		s.pokes = 0
		av.Text = "😡"
		speech(av, "พอแล้วววว!! 🤬💢", COLORS.enemy, true)
		flash(COLORS.enemy, 0.6, 0.4)
		shake(12, 0.4)
		popText(heroPos("enemy"), "ความดันขึ้น! 🩸", COLORS.atk, 1.2)
		addLog("😡 บอทโมโหจนความดันขึ้น เสีย 500 LP", COLORS.glue)
		damageHero("enemy", 500)
		task.delay(2, function() if av.Text == "😡" then av.Text = "🤖" end end)
	else
		speech(av, LINES.poke[math.min(s.pokes, #LINES.poke)], COLORS.enemy, true)
	end
end

local tauntCD = 0
local function tauntBot()
	if State.gameOver or os.clock() < tauntCD then return end
	tauntCD = os.clock() + 2.5
	local line = pick(LINES.taunt)
	speech(Hero.player.avatar, line, COLORS.player)
	burst(heroPos("player"), { "😜", "🤪", "💅" }, 6, 90)
	playSound("hover", 0.7, 0.3)
	addGlue("player", 3)
	if State.isPvP then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
		local pvpAction = folder and folder:FindFirstChild("PvPAction")
		if pvpAction then
			pvpAction:FireServer(State.pvpMatchId, "Taunt", { text = line })
		end
	else
		task.delay(1.1, function()
			if State.gameOver then return end
			local av = Hero.enemy.avatar
			speech(av, pick(LINES.botReply), COLORS.enemy, true)
			av.Text = "😤"
			punch(av, 1.3)
			addGlue("enemy", 4)
			task.delay(1.5, function() if av.Text == "😤" then av.Text = "🤖" end end)
		end)
	end
end

local GameOverFrame
local function showGameOver(win)
	if GameOverFrame then GameOverFrame:Destroy() end
	refreshInteractivity()
	updateHeroUI()
	GameOverFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Active = true, ZIndex = 90, Parent = Overlay })
	tween(GameOverFrame, 0.5, { BackgroundTransparency = 0.35 })
	local box = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = COLORS.panel, Parent = GameOverFrame })
	make("UIAspectRatioConstraint", { AspectRatio = 1.6, Parent = box })
	corner(box, UDim.new(0.08, 0))
	local st = stroke(box, Color3.new(1, 1, 1), 5)
	if win then spinGradient(make("UIGradient", { Color = RAINBOW, Parent = st }), 250) else st.Color = COLORS.enemy end
	local title = label({ Text = win and "🏆 ชนะแล้วว!! 🏆" or "💀 แพ้ซะแล้ว 💀", Font = Enum.Font.GothamBlack, TextColor3 = win and COLORS.gold or COLORS.atk, Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.25), Parent = box })
	make("UIStroke", { Thickness = 3, Parent = title })
	label({ Text = pick(win and LINES.win or LINES.lose), Position = UDim2.fromScale(0.05, 0.36), Size = UDim2.fromScale(0.9, 0.12), Parent = box })
	label({ Text = string.format("เทิร์นทั้งหมด %d • LP คุณ %d • LP บอท %d", State.turnCount, State.sides.player.lp, State.sides.enemy.lp), TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.05, 0.51), Size = UDim2.fromScale(0.9, 0.08), Parent = box })
	local again = makeButton(box, "🔁 เล่นอีกรอบ", UDim2.fromScale(0.05, 0.7), UDim2.fromScale(0.43, 0.2), Color3.fromRGB(90, 220, 130), Color3.fromRGB(30, 150, 90))
	again.button.Activated:Connect(function()
		if State.onRematch then State.onRematch() else resetGame() end
	end)
	local quit = makeButton(box, "🚪 ออกจากโต๊ะ", UDim2.fromScale(0.52, 0.7), UDim2.fromScale(0.43, 0.2), Color3.fromRGB(255, 120, 120), Color3.fromRGB(190, 40, 80))
	quit.button.Activated:Connect(function()
		if State.onQuit then State.onQuit() end
	end)
	local rewardLabel = label({ Text = "⏳ กำลังส่งผลไปเซิร์ฟเวอร์...", TextColor3 = COLORS.gold, Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.08), Parent = box })
	if State.onGameOver then task.spawn(State.onGameOver, win, rewardLabel) end
	local sc = make("UIScale", { Scale = 0, Parent = box })
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	if win then
		playSound("win", 1, 0.6)
		rain("🎉", 20); rain("🏆", 8)
		task.spawn(function()
			for _ = 1, 10 do
				if not GameOverFrame or not GameOverFrame.Parent then break end
				local p = Overlay.AbsolutePosition + Vector2.new(math.random() * Overlay.AbsoluteSize.X, math.random() * Overlay.AbsoluteSize.Y * 0.5)
				burst(p, { "🎉", "🎊", "⭐", COLORS.gold, COLORS.glue }, 14, 250)
				shockwave(p, Color3.fromHSV(math.random(), 0.8, 1), 300)
				task.wait(0.35)
			end
		end)
	else
		playSound("oof", 0.6, 0.6)
		rain("😭", 15)
		Hero.enemy.avatar.Text = "🤣"
		speech(Hero.enemy.avatar, "555+ อ่อนนน 🤣", COLORS.enemy, true)
	end
end

checkGameOver = function()
	if State.gameOver then return true end
	local p, e = State.sides.player, State.sides.enemy
	if not p or not e then return false end
	if p.lp <= 0 or e.lp <= 0 then
		State.gameOver = true
		State.selected = nil
		local win = e.lp <= 0 and p.lp > 0
		local gid = State.gameId
		addLog(win and "🏆 คุณชนะ!!" or "💀 แพ้ซะแล้ว...", win and COLORS.gold or COLORS.atk)
		if State.isPvP then
			local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
			local pvpAction = folder and folder:FindFirstChild("PvPAction")
			if pvpAction then
				pvpAction:FireServer(State.pvpMatchId, win and "Victory" or "Surrender", {})
			end
		end
		task.delay(0.8, function()
			if State.gameId == gid then showGameOver(win) end
		end)
		return true
	end
	return false
end

local function buildDeck()
	local pool = {}
	for _, def in ipairs(CARD_LIST) do
		for _ = 1, def.weight do table.insert(pool, def) end
	end
	shuffle(pool)
	local deck = {}
	for i = 1, CONFIG.DECK_SIZE do deck[i] = pool[((i - 1) % #pool) + 1] end
	return shuffle(deck)
end

resetGame = function()
	State.gameId += 1
	if GameOverFrame then GameOverFrame:Destroy(); GameOverFrame = nil end
	for _, side in ipairs(SIDES) do
		local s = State.sides[side]
		if s then
			for i = 1, CONFIG.SLOTS do
				local u = s.board[i]
				if u and u.ui then u.ui.root:Destroy() end
			end
			for _, c in ipairs(s.hand) do
				if c.ui then c.ui.root:Destroy() end
			end
		end
	end
	Shaker.Rotation = 0
	dragInfo, hoveredCard, previewKey = nil, nil, nil
	State.current = "player"
	State.turnCount = 0
	State.busy = true
	State.gameOver = false
	State.selected = nil
	for _, side in ipairs(SIDES) do
		State.sides[side] = newSide(side)
		State.sides[side].deck = buildDeck()
	end
	lastShown = { player = {}, enemy = {} }
	local curBot = State.currentBot or DEFAULT_BOT; Hero.enemy.avatar.Text = curBot.avatar or "🤖"; if Hero.enemy.nameLabel then Hero.enemy.nameLabel.Text = curBot.name or "บอทลุงกาว 🤖 Lv.99" end
	setTurnLabel()
	updateHeroUI()
	refreshInteractivity()
	addLog("🎮 เกมใหม่เริ่มแล้ว! โหมด: " .. CHAOS_MODES[State.chaos].name, COLORS.gold)

	local gid = State.gameId
	task.spawn(function()
		local curBot = State.currentBot or DEFAULT_BOT; banner("🃏 กาวการ์ด!", "โหมด " .. CHAOS_MODES[State.chaos].name .. " • " .. (curBot.name or "ดวลเดือด"), COLORS.glue, 1.2)
		task.wait(1.7)
		for _ = 1, CONFIG.START_HAND do
			if State.gameId ~= gid then return end
			drawCard("player")
			drawCard("enemy")
			task.wait(0.18)
		end
		drawCard("enemy")
		task.wait(0.4)
		if State.gameId == gid then startTurn("player") end
	end)
end

---------------------------------------------------------------------
-- 🖱️ 15) INPUT
---------------------------------------------------------------------
EndBtn.button.Activated:Connect(function()
	if canAct() then
		playSound("click")
		task.spawn(finishTurn, "player")
	end
end)
UltBtn.button.Activated:Connect(tryUlt)
TauntBtn.button.Activated:Connect(tauntBot)
ChaosBtn.button.Activated:Connect(function()
	State.chaos = State.chaos % #CHAOS_MODES + 1
	ChaosBtn.label.Text = "🌀 โหมด: " .. CHAOS_MODES[State.chaos].name
	addLog("🌀 เปลี่ยนเป็นโหมด " .. CHAOS_MODES[State.chaos].name .. " (เหตุการณ์ปั่น " .. math.floor(CHAOS_MODES[State.chaos].chance * 100) .. "%)", COLORS.glue)
end)

EnemyPanel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if State.selected and canAct() then
			if isValidTarget(State.selected, "hero") then
				task.spawn(performAttack, State.selected, "hero")
			else
				popText(heroPos("enemy"), "🛡 มีตัวโล่ขวางอยู่!", COLORS.gold, 0.9)
			end
			return
		end
		pokeBot()
	end
end)

Hero.enemy.avatar.Activated:Connect(function()
	if State.selected and canAct() then
		if isValidTarget(State.selected, "hero") then
			task.spawn(performAttack, State.selected, "hero")
		else
			popText(heroPos("enemy"), "🛡 มีตัวโล่ขวางอยู่!", COLORS.gold, 0.9)
		end
		return
	end
	pokeBot()
end)
Hero.player.avatar.Activated:Connect(function()
	speech(Hero.player.avatar, pick(LINES.self), COLORS.player)
	burst(heroPos("player"), { "😎", "✨" }, 5, 70)
	punch(Hero.player.avatar, 0.8)
end)

-- ลากการ์ด
UserInputService.InputChanged:Connect(function(input)
	if not dragInfo then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local pos = pointerPos(input)
	local v = dragInfo.card.ui
	if not v then dragInfo = nil; return end
	if not dragInfo.moved and (pos - dragInfo.start).Magnitude > 12 then
		dragInfo.moved = true
		hoveredCard = nil
		local h = HandFrame.AbsoluteSize.Y * 0.82
		v.root.Parent = Overlay
		v.root.Size = UDim2.fromOffset(h * 0.72, h)
		v.root.Rotation = 0
		v.root.ZIndex = 60
		tween(v.scale, 0.15, { Scale = 1.1 })
		layoutHand()
	end
	if dragInfo.moved then
		local p = toOverlay(pos)
		local dx = p.X - v.root.Position.X.Offset
		v.root.Position = UDim2.fromOffset(p.X, p.Y)
		v.root.Rotation = math.clamp(dx * 0.6, -20, 20)
		local over = pos.Y < HandFrame.AbsolutePosition.Y
		local st = BoardFrame.player:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = over and 0 or 0.5
			st.Thickness = over and 4 or 2
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not dragInfo then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local info = dragInfo
	dragInfo = nil
	local st = BoardFrame.player:FindFirstChildOfClass("UIStroke")
	if st then st.Transparency = 0.5; st.Thickness = 2 end
	local pos = pointerPos(input)
	if not info.moved or pos.Y < HandFrame.AbsolutePosition.Y then
		tryPlayCard(info.card)
	else
		layoutHand()
	end
end)

-- คีย์ลัด (Space ถูกดักไว้ ตัวละครจะได้ไม่กระโดด)
ContextActionService:BindAction("GlueEndTurn", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and canAct() then
		task.spawn(finishTurn, "player")
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Space)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if State.selected then
			State.selected = nil
			refreshInteractivity()
			playSound("click", 0.7)
		end
		return
	end
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		tryUlt()
	elseif input.KeyCode == Enum.KeyCode.E then
		tauntBot()
	end
end)

---------------------------------------------------------------------
-- 🎞️ 16) RENDER LOOP + พื้นหลังอีโมจิลอย
---------------------------------------------------------------------
local clock, wasShaking, lastUltReady = 0, false, nil
local ULT_NORMAL = ColorSequence.new(Color3.fromRGB(255, 80, 200), Color3.fromRGB(140, 60, 255))

RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	clock += dt
	for i = #animatedGradients, 1, -1 do
		local a = animatedGradients[i]
		if a.g.Parent == nil then
			table.remove(animatedGradients, i)
		else
			a.g.Rotation = (a.g.Rotation + a.speed * dt) % 360
		end
	end
	for i = #shineGradients, 1, -1 do
		local sg = shineGradients[i]
		if sg.g.Parent == nil then
			table.remove(shineGradients, i)
		else
			local t = (clock + sg.phase) % 3
			sg.g.Offset = Vector2.new(t < 1.2 and (-1 + t / 1.2 * 2) or 1, 0)
		end
	end

	if shakeTime > 0 then
		shakeTime -= dt
		local m = shakeMag * math.clamp(shakeTime / 0.25, 0, 1)
		Shaker.Position = UDim2.new(0.5, (math.random() * 2 - 1) * m, 0.5, (math.random() * 2 - 1) * m)
		wasShaking = true
	elseif wasShaking then
		wasShaking = false
		shakeMag = 0
		Shaker.Position = UDim2.fromScale(0.5, 0.5)
	end

	local pulse = (math.sin(clock * 6) + 1) / 2
	for _, side in ipairs(SIDES) do
		for i = 1, CONFIG.SLOTS do
			local g = SlotGlow[side][i]
			if g.Visible then g.BackgroundTransparency = 0.25 + pulse * 0.4 end
		end
	end
	Hero.enemy.ringStroke.Transparency = pulse * 0.6
	if Vignette.Visible then
		for _, e in ipairs(VignetteEdges) do e.BackgroundTransparency = 0.2 + pulse * 0.5 end
	end

	EndBtn.stroke.Thickness = State.suggestEnd and (2 + pulse * 4) or 2
	EndBtn.stroke.Transparency = State.suggestEnd and 0 or 0.5

	local ps = State.sides.player
	local ready = ps ~= nil and ps.glue >= CONFIG.GLUE_MAX
	if ready ~= lastUltReady then
		lastUltReady = ready
		UltBtn.grad.Color = ready and RAINBOW or ULT_NORMAL
		UltBtn.grad.Rotation = 90
	end
	if ready then
		UltBtn.grad.Rotation = (UltBtn.grad.Rotation + dt * 200) % 360
		UltBtn.stroke.Thickness = 2 + pulse * 4
		UltBtn.stroke.Transparency = 0
	else
		UltBtn.stroke.Thickness = 2
		UltBtn.stroke.Transparency = 0.5
	end
end)

local BG_EMOJI = { "🃏", "🧪", "🤪", "🐔", "🍌", "💥", "🎲", "🐈", "🛵", "👡", "🥓", "✨", "🦆", "🤡" }
task.spawn(function()
	while gui.Parent do
		if not gui.Enabled then task.wait(1) continue end
		local x = math.random()
		local s = px(math.random(28, 60))
		local e = label({
			Text = pick(BG_EMOJI), TextTransparency = 0.75, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 1.1, 0), Size = UDim2.fromOffset(s, s), Rotation = math.random(-30, 30), Parent = BgLayer,
		})
		local dur = math.random(10, 18)
		tween(e, dur, { Position = UDim2.new(x + (math.random() - 0.5) * 0.2, 0, -0.15, 0), Rotation = e.Rotation + math.random(-180, 180) }, Enum.EasingStyle.Linear)
		Debris:AddItem(e, dur)
		task.wait(0.6)
	end
end)

---------------------------------------------------------------------
-- 🚀 START!
---------------------------------------------------------------------
---------------------------------------------------------------------
-- 🏛️ 17) LOBBY FLOW: เดินไปโต๊ะ → กด E → ซูมกล้อง → ดวล → ส่งผลให้เซิร์ฟเวอร์
---------------------------------------------------------------------
gui.Enabled = false
State.gameOver = true   -- กันปุ่ม Q/E ทำงานตอนยังไม่ได้นั่งโต๊ะ
State.busy = true
ContextActionService:UnbindAction("GlueEndTurn") -- ปล่อย Space ให้กระโดดได้ตามปกติ

do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local Remotes = ReplicatedStorage:WaitForChild("GlueCardRemotes")
	local BGM_ID = "" -- 🎵 ใส่ "rbxassetid://xxxx" ของเพลงที่ต้องการ (เว้นว่าง = ไม่มีเพลง)

	local Lobby = { open = false, busy = false, reporting = false, matchId = nil, diedConn = nil }

		-- จอดำตอนเปลี่ยนฉาก
	local fadeGui = make("ScreenGui", { Name = "GlueCardFade", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = playerGui })
	local fade = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = fadeGui })
	local function fadeTo(alpha, t)
		tween(fade, t, { BackgroundTransparency = alpha })
		task.wait(t)
	end

	-- 🎵 เพลงพื้นหลัง
	local bgm = make("Sound", { Name = "GlueCardBGM", SoundId = BGM_ID, Looped = true, Volume = 0, Parent = SoundService })
	local function setMusic(on)
		if BGM_ID == "" then return end
		if on then
			bgm.Volume = 0
			bgm:Play()
			tween(bgm, 1, { Volume = 0.35 })
		else
			tween(bgm, 0.6, { Volume = 0 })
			task.delay(0.6, function() if not Lobby.open then bgm:Stop() end end)
		end
	end

	-- 🔒 ล็อกการเดิน + ผูก Space กับการจบเทิร์นเฉพาะตอนอยู่ที่โต๊ะ
	local function getControls()
		local ps = player:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if not pm then return nil end
		local ok, mod = pcall(require, pm)
		return ok and mod and mod:GetControls() or nil
	end

	local function setLocked(locked)
		local controls = getControls()
		if controls then
			if locked then controls:Disable() else controls:Enable() end
		end
		ProximityPromptService.Enabled = not locked
		if locked then
			ContextActionService:BindAction("GlueEndTurn", function(_, inputState)
				if inputState == Enum.UserInputState.Begin and canAct() then
					task.spawn(finishTurn, "player")
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Space)
		else
			ContextActionService:UnbindAction("GlueEndTurn")
		end

		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				if locked then
					hum.WalkSpeed = 0
					hum.JumpPower = 0
					hum.JumpHeight = 0
				else
					hum.WalkSpeed = 16
					hum.JumpPower = 50
					hum.JumpHeight = 7.2
				end
			end
		end
	end

	-- 🎥 กล้องซูมเข้าโต๊ะ (รองรับ CameraPoint ของโต๊ะ CardTableBuilder และ BoundingBox)
	local function cameraEnter(tbl)
		if not tbl or not tbl.Parent then return end
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable

		local camPoint = tbl:FindFirstChild("CameraPoint", true)
		local goal
		if camPoint and camPoint:IsA("BasePart") then
			goal = camPoint.CFrame
		else
			local top, width
			if tbl:IsA("Model") then
				local cf, size = tbl:GetBoundingBox()
				top, width = cf.Position + Vector3.new(0, size.Y / 2, 0), math.max(size.X, size.Z)
			else
				top, width = tbl.Position + Vector3.new(0, tbl.Size.Y / 2, 0), math.max(tbl.Size.X, tbl.Size.Z)
			end
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local dir = hrp and (hrp.Position - top) * Vector3.new(1, 0, 1) or Vector3.new(0, 0, 1)
			if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
			local dist = math.max(width, 4)
			goal = CFrame.lookAt(top + dir.Unit * dist * 0.6 + Vector3.new(0, dist * 0.9, 0), top)
		end

		local tw = TweenService:Create(cam, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { CFrame = goal })
		tw:Play()
		tw.Completed:Wait()
	end

	local function startMatch(options)
		local ok, matchId = pcall(function() return Remotes.NewMatch:InvokeServer(options) end)
		if not ok or type(matchId) ~= "string" then return false end
		Lobby.matchId = matchId
		resetGame()
		return true
	end

	local function closeTable(force)
		if not Lobby.open or (Lobby.busy and not force) then return end
		Lobby.busy = true
		Lobby.open = false
		player:SetAttribute("GlueInDuel", false)
		if State.isPvP then
			local folder = game:GetService("ReplicatedStorage"):FindFirstChild("GlueCardRemotes")
			local pvpAction = folder and folder:FindFirstChild("PvPAction")
			if pvpAction then pvpAction:FireServer(State.pvpMatchId, "Surrender", {}) end
		end
		State.isPvP = false
		State.pvpMatchId = nil
		State.pvpOpponent = nil
		local thumb = Hero.enemy.avatar:FindFirstChild("Thumb")
		if thumb then thumb:Destroy() end
		Remotes.LeaveTable:FireServer()
		fadeTo(0, 0.3)
		State.gameId += 1
		State.gameOver, State.busy, State.selected = true, true, nil
		if GameOverFrame then GameOverFrame:Destroy(); GameOverFrame = nil end
		Vignette.Visible = false
		Shaker.Rotation = 0
		gui.Enabled = false
		Lobby.matchId = nil
		if Lobby.diedConn then Lobby.diedConn:Disconnect(); Lobby.diedConn = nil end
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		setLocked(false)
		setMusic(false)
		fadeTo(1, 0.4)
		Lobby.busy = false
	end

	local function openTable(tbl, options)
		if Lobby.open or Lobby.busy then return end
		Lobby.busy = true
		player:SetAttribute("GlueInDuel", true)
		options = options or {}
		State.lastOptions = options
		local diff = options.difficulty or "Medium"
		State.currentBot = BOT_PROFILES[diff] or BOT_PROFILES.Normal
		if options.chaos and CHAOS_MODES[options.chaos] then
			State.chaos = options.chaos
		end
		setLocked(true)
		cameraEnter(tbl)
		fadeTo(0, 0.25)
		gui.Enabled = true
		Lobby.open = true
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			Lobby.diedConn = hum.Died:Connect(function() task.spawn(closeTable, true) end)
		end
		setMusic(true)
		local ok = startMatch(options)
		fadeTo(1, 0.4)
		Lobby.busy = false
		if not ok then
			popText(centerOf(Main), "⚠️ ต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่นะ", COLORS.atk, 1.2)
			task.wait(1.5)
			closeTable()
		end
	end

	-- 📤 ส่งผลแมตช์ + โชว์รางวัล
	State.onGameOver = function(win, rewardLabel)
		local matchId = Lobby.matchId
		Lobby.matchId = nil
		if not matchId then
			rewardLabel.Text = "⚠️ แมตช์นี้ไม่ได้ลงทะเบียนกับเซิร์ฟเวอร์"
			return
		end
		Lobby.reporting = true
		local ok, res = pcall(function()
			return Remotes.ReportResult:InvokeServer(matchId, { won = win, turns = State.turnCount })
		end)
		Lobby.reporting = false
		if not rewardLabel.Parent then return end
		if not ok or type(res) ~= "table" then
			rewardLabel.Text = "⚠️ ส่งผลไม่สำเร็จ (เน็ตหลุด?)"
		elseif type(res.gold) == "number" and res.gold > 0 then
			local counter = Instance.new("NumberValue")
			counter.Changed:Connect(function(v)
				if rewardLabel.Parent then rewardLabel.Text = "💰 ได้รับ +" .. math.floor(v) .. " Gold!" end
			end)
			tween(counter, 1, { Value = res.gold }, Enum.EasingStyle.Quart)
			Debris:AddItem(counter, 1.5)
			burst(centerOf(rewardLabel), { "💰", "🪙", COLORS.gold }, 18, 180)
			punch(rewardLabel, 1.4)
			playSound("summon", 1.6, 0.5)
		else
			rewardLabel.Text = "😅 " .. tostring(res.reason or "รอบนี้ไม่ได้รางวัล")
		end
	end

	State.onRematch = function()
		if Lobby.busy then return end
		if Lobby.reporting then
			popText(centerOf(Main), "⏳ รอส่งผลแป๊บนึง...", COLORS.sub, 1)
			return
		end
		Lobby.busy = true
		local ok = startMatch(State.lastOptions)
		Lobby.busy = false
		if not ok then popText(centerOf(Main), "⚠️ เริ่มแมตช์ใหม่ไม่ได้", COLORS.atk, 1.1) end
	end

	State.onQuit = function()
		if Lobby.reporting then
			popText(centerOf(Main), "⏳ รอส่งผลแป๊บนึง...", COLORS.sub, 1)
			return
		end
		task.spawn(closeTable)
	end

	-- 🚪 ปุ่มออกระหว่างเกม (กด 2 ครั้ง = ยอมแพ้)
	LogFrame.Size = UDim2.fromScale(0.9, 0.37)
	local exitBtn = makeButton(SidePanel, "🚪 ออกจากโต๊ะ", UDim2.fromScale(0.06, 0.82), UDim2.fromScale(0.88, 0.055), Color3.fromRGB(255, 120, 120), Color3.fromRGB(190, 40, 80))
	local confirmUntil = 0
	exitBtn.button.Activated:Connect(function()
		if State.gameOver or os.clock() < confirmUntil then
			State.onQuit()
			return
		end
		confirmUntil = os.clock() + 2.5
		exitBtn.label.Text = "⚠️ กดอีกที = ยอมแพ้"
		speech(Hero.enemy.avatar, "จะหนีเหรอ? ไก่อ่อนนน 🐔", COLORS.enemy, true)
		task.delay(2.5, function() exitBtn.label.Text = "🚪 ออกจากโต๊ะ" end)
	end)


	-- ⚔️ PvP Handlers
	local function startPvPGame(data)
		if Lobby.busy then return end
		Lobby.busy = true
		State.isPvP = true
		State.pvpMatchId = data.matchId
		local opp = data.opponent or {
			UserId = data.opponentUserId or 0,
			DisplayName = data.opponentName or "คู่ต่อสู้",
			Name = data.opponentName or "คู่ต่อสู้",
		}
		State.pvpOpponent = opp
		player:SetAttribute("GlueInDuel", true)
		setLocked(true)
		fadeTo(0, 0.25)
		gui.Enabled = true
		Lobby.open = true

		-- ตั้งค่าอวาตาร์คู่ต่อสู้
		if Hero.enemy.nameLabel then
			Hero.enemy.nameLabel.Text = (opp.DisplayName or "คู่ต่อสู้") .. " ⚔️"
		end
		task.spawn(function()
			if opp.UserId and opp.UserId > 0 then
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, opp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if ok and img then
					Hero.enemy.avatar.Text = ""
					local imgLabel = Hero.enemy.avatar:FindFirstChild("Thumb") or make("ImageLabel", {
						Name = "Thumb", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = Hero.enemy.avatar,
					})
					corner(imgLabel, UDim.new(1, 0))
					imgLabel.Image = img
				end
			end
		end)

		resetGame()

		local isFirst = (data.isFirst ~= nil) and data.isFirst or (data.goFirst == true)
		if isFirst then
			State.current = "player"
			State.busy = false
			banner("⚔️ ดวลสด 1v1!", "คุณได้เริ่มก่อน! ลุยยย!", COLORS.gold, 1.4)
		else
			State.current = "enemy"
			State.busy = true
			banner("⚔️ ดวลสด 1v1!", (opp.DisplayName or "คู่ต่อสู้") .. " ได้เริ่มก่อน!", COLORS.enemy, 1.4)
		end

		refreshInteractivity()
		fadeTo(1, 0.4)
		Lobby.busy = false
	end

	local function onPvPActionReceived(matchId, actionType, data)
		if not State.isPvP or State.pvpMatchId ~= matchId or State.gameOver then return end

		if actionType == "PlayCard" then
			local def = CARDS[data.cardId]
			if def then
				if data.isSpell then
					if def.spell then def.spell("enemy") end
				else
					summonUnit("enemy", def, data.slot or getEmptySlot("enemy") or 1)
				end
				updateHeroUI()
			end
		elseif actionType == "Attack" then
			local attacker = State.sides.enemy.board[data.attackerSlot]
			local target = (data.targetType == "hero") and "hero" or (data.targetSlot and State.sides.player.board[data.targetSlot])
			if attacker and target then
				task.spawn(performAttack, attacker, target)
			end
		elseif actionType == "Ult" then
			task.spawn(useUltimate, "enemy")
		elseif actionType == "EndTurn" then
			task.spawn(startTurn, "player")
		elseif actionType == "Taunt" then
			speech(Hero.enemy.avatar, data.text or "555+ ปั่นจัด", COLORS.enemy, true)
			burst(heroPos("enemy"), { "😜", "🔥" }, 6, 80)
		end
	end

	local function onPvPMatchEndReceived(res)
		State.gameOver = true
		State.busy = true
		local won = res.won == true
		if won then
			banner("🏆 ชนะการดวล!", (res.reason or "คุณชนะการดวล 1v1!") .. " รับ +" .. (res.gold or 150) .. " Gold", COLORS.gold, 3.5)
			burst(centerOf(Main), { "👑", "✨", "💰" }, 30, 250)
			playSound("win", 1, 0.8)
		else
			banner("💀 พ่ายแพ้!", (res.reason or "แพ้การดวล") .. " รับ +" .. (res.gold or 40) .. " Gold", COLORS.atk, 3.5)
			playSound("oof", 1, 0.8)
		end
		task.delay(4, function()
			closeTable(true)
		end)
	end

	Remotes.OpenTable.OnClientEvent:Connect(function(tbl, options)
		task.spawn(openTable, typeof(tbl) == "Instance" and tbl or nil, typeof(options) == "table" and options or {})
	end)

	local startPvPRemote = Remotes:FindFirstChild("StartPvP")
	if startPvPRemote then
		startPvPRemote.OnClientEvent:Connect(function(data)
			task.spawn(startPvPGame, data)
		end)
	end

	local pvpRelayRemote = Remotes:FindFirstChild("PvPActionRelay")
	if pvpRelayRemote then
		pvpRelayRemote.OnClientEvent:Connect(function(matchId, actionType, data)
			task.spawn(onPvPActionReceived, matchId, actionType, data)
		end)
	end

	local pvpEndRemote = Remotes:FindFirstChild("PvPMatchEnd")
	if pvpEndRemote then
		pvpEndRemote.OnClientEvent:Connect(function(res)
			task.spawn(onPvPMatchEndReceived, res)
		end)
	end

end

---------------------------------------------------------------------
-- 📱 18) ตั้งค่า • ซ่อน/โชว์ HUD • หลังการ์ดบอท • กดค้างดูการ์ด
---------------------------------------------------------------------
do
	local function opt(name, default)
		local v = player:GetAttribute(name)
		if v == nil then return default end
		return v
	end

	-- ⚙️ ใช้ค่าจากหน้าต่างตั้งค่า (ห่อฟังก์ชันเดิม ทุกจุดในเกมได้ผลทันที)
	local baseShake, baseSound, baseTween = shake, playSound, tween
	shake = function(mag, dur)
		if opt("GlueShake", true) then baseShake(mag, dur) end
	end
	playSound = function(name, pitch, volume)
		local mul = opt("GlueSFX", 1)
		if mul > 0 then baseSound(name, pitch, (volume or 0.5) * mul) end
	end
	tween = function(obj, t, props, style, dir)
		if obj == Shaker and props.Rotation ~= nil and not opt("GlueRotate", true) then
			props = table.clone(props)
			props.Rotation = nil
			Shaker.Rotation = 0
		end
		return baseTween(obj, t, props, style, dir)
	end

	-- 🎵 คุมเสียงเพลงผ่าน SoundGroup
	local bgmGroup = make("SoundGroup", { Name = "GlueBGMGroup", Volume = opt("GlueBGM", 1), Parent = SoundService })
	local bgmSound = SoundService:FindFirstChild("GlueCardBGM")
	if bgmSound then bgmSound.SoundGroup = bgmGroup end
	player:GetAttributeChangedSignal("GlueBGM"):Connect(function()
		bgmGroup.Volume = opt("GlueBGM", 1)
	end)

	-- 🔍 ซูมดูการ์ดเต็มจอ (มือถือกดค้าง / PC คลิกค้าง)
	local zoomFrame
	local function closeZoom()
		if not zoomFrame then return end
		local z = zoomFrame
		zoomFrame = nil
		tween(z, 0.2, { BackgroundTransparency = 1 })
		for _, c in ipairs(z:GetChildren()) do
			if c:IsA("GuiObject") then c.Visible = false end
		end
		Debris:AddItem(z, 0.25)
	end

	local function openZoom(def, unit)
		closeZoom()
		local z = make("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 86, Parent = Overlay })
		zoomFrame = z
		tween(z, 0.2, { BackgroundTransparency = 0.3 })
		z.Activated:Connect(closeZoom)
		local v = buildCardVisual(z, def, { active = false, pos = UDim2.fromScale(0.32, 0.48), size = UDim2.fromScale(0.5, 0.62) })
		if unit and v.atk then
			v.atk.Text = "⚔" .. unit.atk
			v.hp.Text = "❤" .. math.max(0, unit.hp)
			v.frozen.Visible = unit.frozen > 0
		end
		showPreview(def, unit)
		local info = label({
			RichText = true, TextWrapped = true, Font = Enum.Font.GothamMedium,
			Text = "<b>" .. PreviewName.Text .. "</b>\n" .. PreviewText.Text,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.42, 0.56), Parent = z,
		})
		make("UITextSizeConstraint", { MaxTextSize = 30, Parent = info })
		label({ Text = "👆 แตะที่ไหนก็ได้เพื่อปิด", TextColor3 = COLORS.sub, Position = UDim2.fromScale(0.3, 0.88), Size = UDim2.fromScale(0.4, 0.05), Parent = z })
		v.scale.Scale = 0.3
		v.root.Rotation = -15
		tween(v.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(v.root, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
		playSound("hover", 1.4, 0.25)
	end

	-- กดการ์ดในมือค้าง 0.45 วิ โดยไม่ลาก = ซูมดู (ไม่เล่นการ์ด)
	local pressInfo, pressStart = nil, 0
	RunService.Heartbeat:Connect(function()
		if dragInfo ~= pressInfo then
			pressInfo, pressStart = dragInfo, os.clock()
		end
		if pressInfo and not pressInfo.moved and os.clock() - pressStart > 0.45 then
			local card = pressInfo.card
			dragInfo, pressInfo = nil, nil
			hoveredCard = nil
			layoutHand()
			openZoom(card.def)
		end
	end)

	-- แตะมอนสเตอร์บนสนาม = อัปเดตแผงพรีวิวด้วย (มือถือไม่มี hover)
	local baseUnitClicked = onUnitClicked
	onUnitClicked = function(unit)
		if not unit.dead then showPreview(unit.card, unit) end
		baseUnitClicked(unit)
	end

	-- 🂠 หลังการ์ดบนมือบอท
	for _, c in ipairs(EnemyPanel:GetChildren()) do
		if c:IsA("TextLabel") and c.Text:find("บอทลุงกาว") then c.Size = UDim2.fromScale(0.25, 0.28) end
	end
	local backsFrame = make("Frame", { Name = "EnemyHandBacks", BackgroundTransparency = 1, Position = UDim2.fromScale(0.36, 0.03), Size = UDim2.fromScale(0.26, 0.4), Parent = EnemyPanel })
	local backs, lastBacks = {}, -1

	local function makeBack()
		local b = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.95), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = backsFrame })
		make("UIAspectRatioConstraint", { AspectRatio = 0.72, DominantAxis = Enum.DominantAxis.Height, Parent = b })
		corner(b, UDim.new(0.15, 0))
		stroke(b, Color3.new(1, 1, 1), 1.5, 0.2)
		gradient(b, Color3.fromRGB(220, 70, 170), Color3.fromRGB(70, 30, 140), 45)
		label({ Text = "🧪", Size = UDim2.fromScale(0.7, 0.5), Position = UDim2.fromScale(0.15, 0.25), Parent = b })
		make("UIScale", { Name = "Pop", Scale = 0, Parent = b })
		return b
	end

	local function layoutBacks()
		local s = State.sides.enemy
		local n = s and #s.hand or 0
		if n == lastBacks then return end
		lastBacks = n
		while #backs < n do
			local b = makeBack()
			table.insert(backs, b)
			tween(b.Pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		while #backs > n do
			local b = table.remove(backs)
			tween(b, 0.35, { Position = b.Position + UDim2.fromScale(0, 1.6), Rotation = 40 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(b.Pop, 0.35, { Scale = 0.3 })
			Debris:AddItem(b, 0.4)
		end
		local spacing = math.min(0.14, 0.9 / math.max(n, 1))
		for i, b in ipairs(backs) do
			local off = i - (n + 1) / 2
			b.ZIndex = 2 + i
			tween(b, 0.25, { Position = UDim2.fromScale(0.5 + off * spacing, 0.5 + math.abs(off) * 0.04), Rotation = off * 6 }, Enum.EasingStyle.Back)
		end
	end

	local baseHeroUI = updateHeroUI
	updateHeroUI = function()
		baseHeroUI()
		layoutBacks()
	end

	-- 🏛️ บอก HUD ว่ากำลังดวลอยู่หรือไม่
	local function syncDuel()
		player:SetAttribute("GlueInDuel", gui.Enabled)
		if not gui.Enabled then closeZoom() end
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(syncDuel)
	syncDuel()
end
