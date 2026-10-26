-- ============================================================
-- StarterPlayer > StarterPlayerScripts > UIClient > LobbyUI (ModuleScript)
-- ล็อบบี้ v2 "PASULOL": แถบบน + เมนูซ้าย + หน้าต่างเนื้อหาเดียว
-- API เดิม: LobbyUI.Build(hud, overlay) / LobbyUI.Refresh() / LobbyUI.ResetQueue()
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Decks = require(Shared:WaitForChild("Decks"))
local DeckRules = require(Shared:WaitForChild("DeckRules"))
local CardData = require(Shared:WaitForChild("CardData"))
local Net = require(script.Parent:WaitForChild("Net"))

local function tryRequire(name)
	local inst = script.Parent:FindFirstChild(name)
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	if not ok then
		warn("[LobbyUI] โหลด " .. name .. " ไม่ได้: " .. tostring(mod))
		return nil
	end
	return mod
end
local DeckBuilder = tryRequire("DeckBuilder")
local FarmUI = tryRequire("FarmUI")
local Inspect = tryRequire("Inspect") -- เผื่อ DeckBuilder ยังเรียกใช้

local LobbyUI = {}

-- ───── ธีม (ชุดเดียวกับ MatchUI) ─────
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
	Ink = rgb(14, 10, 24), White = rgb(255, 255, 255), Paper = rgb(255, 251, 236),
	Bg = rgb(255, 238, 200), Yellow = rgb(255, 228, 0), Lime = rgb(198, 255, 0),
	Pink = rgb(255, 36, 168), Blue = rgb(0, 170, 255), Green = rgb(36, 200, 100),
	Orange = rgb(255, 128, 0), Red = rgb(255, 48, 72), Purple = rgb(148, 56, 255),
	Gray = rgb(150, 146, 170), Gold = rgb(255, 196, 0), Brown = rgb(130, 82, 40),
	Soft = rgb(240, 236, 250),
}
local FONT, FONT_BODY, FONT_NUM = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.FredokaOne
local LEFT, RIGHT, TOP = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextYAlignment.Top
local CARD_RATIO = 0.72

local ELEM = {
	Sati = { name = "สติ", icon = "🧘", color = C.Blue },
	Biao = { name = "เบียว", icon = "😈", color = C.Pink },
	Muen = { name = "มึน", icon = "😵", color = C.Orange },
	Gawa = { name = "กาว", icon = "🌀", color = C.Lime },
}
local TYPE_COLOR = { Spell = C.Purple, Weapon = C.Brown, Leader = C.Gold }
local TYPE_ICON = { Character = "🙂", Spell = "✨", Weapon = "🗡️", Leader = "👑" }
local TYPE_ORDER = { Character = 1, Spell = 2, Weapon = 3, Leader = 4 }
local KW = { Rush = "⚡บุก", Taunt = "🛡️ยั่ว", Necro = "⚰️ขุดศพ", Unlucky = "🪙ดวงซวย", Steal = "🦹ขโมย" }
local RARITY = {
	Common = { name = "ธรรมดา", color = rgb(150, 150, 165) },
	Rare = { name = "แรร์", color = C.Blue },
	Epic = { name = "เอพิก", color = C.Purple },
	Legend = { name = "ตำนาน", color = C.Gold },
	Mystic = { name = "ลึกลับ", color = C.Pink },
}
local RARITY_RANK = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }
local ART = {
	KAI_CHON = "🐓", MAEW_SOM = "🐈", LOOKCHIN = "🍡", PA_MOUTH = "🗣️", PILLOW_THIEF = "🦹",
	BIAO_KID = "😎", WIN_MOTO = "🛵", GUARD = "💂", TEACHER = "📏", KARAOKE = "🎤",
	MOOKATA = "🥘", SOMTAM_KING = "🦀",
	SHIELD_POT = "🛡️", SLIME = "🟢", SLAP = "👋", BALM = "💚", MYSTERY_BOX = "🎁",
	MOM_CALL = "📣", RICE_BOMB = "💣",
	SLIPPER = "👡", BROOM = "🧹", SPATULA = "🍳", FROZEN_FISH = "🐟", BROKEN_UMBRELLA = "☂️",
}
local TABS = {
	{ Id = "Battle", Text = "⚔️ ต่อสู้", Color = C.Red },
	{ Id = "Deck", Text = "🃏 เด็ค", Color = C.Blue },
	{ Id = "Gacha", Text = "🎰 กาชา", Color = C.Pink },
	{ Id = "Quests", Text = "📜 เควสต์", Color = C.Green },
	{ Id = "Stats", Text = "📊 สถิติ", Color = C.Purple },
	{ Id = "Modes", Text = "🗼 โหมดอื่น", Color = C.Orange },
}
local STAT_ORDER = {
	{ "Matches", "แมตช์ทั้งหมด" }, { "Wins", "ชนะ" }, { "Losses", "แพ้" }, { "Surrenders", "ยอมแพ้" },
	{ "WinsPvP", "ชนะ PvP" }, { "LossesPvP", "แพ้ PvP" }, { "WinsBot", "ชนะบอท/หอคอย" },
	{ "GemsEarned", "เพชรที่ได้รับ" }, { "BestGemsOneMatch", "เพชรสูงสุดต่อแมตช์" }, { "BountyEarned", "ค่าหัวที่ได้รับ" },
	{ "CardsPlayed", "ลงการ์ด" }, { "Attacks", "สั่งตี" }, { "KillsMade", "ฆ่าการ์ดศัตรู" }, { "CardsLost", "การ์ดเราตาย" },
	{ "DamageToLeader", "ดาเมจใส่ผู้นำศัตรู" }, { "DamageTaken", "ดาเมจที่โดน" },
	{ "GateRolls", "สุ่มเกต" }, { "GateGolden", "ได้ร่างทอง 🌟" }, { "GatePoop", "ได้ก้อนอึ 💩" },
	{ "TurnsSkipped", "ข้ามเทิร์นดองพอยต์" }, { "PointsBanked", "พอยต์ที่ดองรวม" },
	{ "AttacksMissed", "ตีพลาดเพราะสไลม์" }, { "PlaySec", "เวลาเล่นรวม (วินาที)" },
	{ "LongestMatchSec", "แมตช์นานสุด (วินาที)" }, { "ShortestWinSec", "ชนะเร็วสุด (วินาที)" },
}
local TOWER_MAX = Config.TOWER_MAX_FLOOR or 30
local function towerReward(floor)
	return (Config.TOWER_REWARD_BASE or 10) + floor * (Config.TOWER_REWARD_PER_FLOOR or 5)
end

-- ───── ตัวช่วยสร้าง UI ─────
local function new(class, props, parent)
	local o = Instance.new(class)
	if props then for k, v in props do o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, o) return o end
local function outline(o, th, col)
	return new("UIStroke", { Thickness = th or 3, Color = col or C.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function textStroke(o, th) return new("UIStroke", { Thickness = th or 2, Color = C.Ink }, o) end
local function maxText(o, n) new("UITextSizeConstraint", { MaxTextSize = n }, o) return o end
local function text(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = C.Ink,
		TextScaled = true, Size = UDim2.fromScale(1, 1), Text = "" }, parent)
	if props then for k, v in props do l[k] = v end end
	return l
end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function esc(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function fmtNum(v)
	if math.floor(v) == v then return tostring(v) end
	return ("%.1f"):format(v)
end
local function wobble(g)
	if not g or not g.Parent then return end
	g.Rotation = (math.random(0, 1) == 0 and -1 or 1) * math.random(6, 12)
	tween(g, 0.6, { Rotation = 0 }, Enum.EasingStyle.Elastic)
end
local function chunkyButton(parent, label, color, onClick)
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, Font = FONT,
		Text = label, TextScaled = true, TextColor3 = C.Ink }, parent)
	corner(b, 14); outline(b, 4); maxText(b, 26)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	local sc = new("UIScale", {}, b)
	b.MouseButton1Down:Connect(function() tween(sc, 0.06, { Scale = 0.92 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(sc, 0.1, { Scale = 1 }) end)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

local function describe(card)
	if not card then return "แตะการ์ดเพื่อดูรายละเอียด 👆" end
	local rar = RARITY[card.Rarity] or RARITY.Common
	local L = { ("<b>%s %s</b>  <font color=\"#%s\">[%s]</font>"):format(
		card.Emoji or ART[card.Id] or TYPE_ICON[card.Type] or "❓", esc(card.Name or "?"), rar.color:ToHex(), rar.name) }
	if card.Type == "Character" then
		local e = ELEM[card.Element]
		local kws = {}
		for _, kw in card.Keywords or {} do
			if KW[kw] then table.insert(kws, KW[kw]) end
		end
		table.insert(L, ("⚡%d • %s • ⚔️ %d / ❤️ %d%s"):format(card.Cost or 0, e and (e.icon .. e.name) or "-",
			card.ATK or 0, card.HP or 0, #kws > 0 and (" • " .. table.concat(kws, " ")) or ""))
	elseif card.Type == "Weapon" then
		table.insert(L, ("⚡%d • อาวุธ +%d ATK • ใช้ได้ %d ครั้ง%s"):format(card.Cost or 0, card.Bonus or 0,
			card.Durability or 0, card.Freeze and " • ❄️แช่แข็ง" or ""))
	elseif card.Type == "Spell" then
		table.insert(L, ("⚡%d • เวท"):format(card.Cost or 0))
	end
	if card.Desc then table.insert(L, esc(card.Desc)) end
	if card.Flavor then table.insert(L, ("<i>“%s”</i>"):format(esc(card.Flavor))) end
	return table.concat(L, "\n")
end

-- ============================================================
function LobbyUI.Build(hud, overlay)
	pcall(function() hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
	if Inspect and Inspect.Init then pcall(Inspect.Init, overlay) end
	local player = Players.LocalPlayer

	local profile, stats = nil, nil
	local leaderIndex, queueMode, queueElapsed = 1, nil, 0
	local currentTab = "Battle"
	local windows, scrollMemo, pages, tabButtons = {}, {}, {}, {}
	local pvpBtn = nil
	local lastPull, pulling, revealNext, starting = {}, false, false, false
	local render, openTab -- forward

	-- ───── โครงหลัก ─────
	local root = new("Frame", { Name = "LobbyRoot", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Bg }, hud)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 245, 215), rgb(255, 214, 160)) }, root)

	-- แถบบน
	local top = new("Frame", { BackgroundColor3 = C.Paper, Position = UDim2.fromScale(0.015, 0.02),
		Size = UDim2.fromScale(0.97, 0.11) }, root)
	corner(top, 18); outline(top, 4)
	local logo = text(top, { Text = "🌀 GAWA CARD BATTLE", TextColor3 = C.Pink, TextXAlignment = LEFT,
		Position = UDim2.fromScale(0.015, 0.14), Size = UDim2.fromScale(0.36, 0.72) })
	textStroke(logo, 2)
	local nameChip = chunkyButton(top, "", C.Yellow)
	nameChip.Position = UDim2.fromScale(0.39, 0.14)
	nameChip.Size = UDim2.fromScale(0.37, 0.72)
	local gemChip = new("Frame", { BackgroundColor3 = C.Lime, Position = UDim2.fromScale(0.775, 0.14),
		Size = UDim2.fromScale(0.21, 0.72) }, top)
	corner(gemChip, 14); outline(gemChip, 4)
	local gemLbl = text(gemChip, { Text = "💎 ...", Font = FONT_NUM,
		Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8) })

	-- เมนูซ้าย
	local nav = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.015, 0.15),
		Size = UDim2.fromScale(0.185, 0.83) }, root)
	new("UIListLayout", { Padding = UDim.new(0.022, 0), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	local questBadge, questBadgeLbl
	for i, tab in TABS do
		local b = chunkyButton(nav, tab.Text, C.White, function() openTab(tab.Id) end)
		b.Size = UDim2.fromScale(1, 0.148)
		b.LayoutOrder = i
		if tab.Id == "Quests" then
			questBadge = new("Frame", { BackgroundColor3 = C.Red, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.97, 0.05), Size = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = 5 }, b)
			new("UIAspectRatioConstraint", { AspectRatio = 1 }, questBadge)
			corner(questBadge); outline(questBadge, 3)
			questBadgeLbl = text(questBadge, { Font = FONT_NUM, TextColor3 = C.White, ZIndex = 6 })
		end
		tabButtons[tab.Id] = b
	end

	-- หน้าต่างเนื้อหา
	local content = new("Frame", { BackgroundColor3 = C.Paper, Position = UDim2.fromScale(0.215, 0.15),
		Size = UDim2.fromScale(0.77, 0.83) }, root)
	corner(content, 20); outline(content, 4)
	local headBar = new("Frame", { BackgroundColor3 = C.Red, Position = UDim2.fromScale(0.015, 0.025),
		Size = UDim2.fromScale(0.97, 0.1) }, content)
	corner(headBar, 14); outline(headBar, 3)
	local headLbl = text(headBar, { TextColor3 = C.White, TextXAlignment = LEFT,
		Position = UDim2.fromScale(0.02, 0.12), Size = UDim2.fromScale(0.96, 0.76) })
	textStroke(headLbl, 3)
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.015, 0.145),
		Size = UDim2.fromScale(0.97, 0.835) }, content)

	-- ───── ตัวช่วยในหน้า ─────
	local lastToast = nil
	local function toast(msg, color)
		if lastToast and lastToast.Parent then lastToast:Destroy() end
		local box = new("Frame", { BackgroundColor3 = color or C.Red, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.6, 0.16), Size = UDim2.fromScale(0.46, 0.07), ZIndex = 50 }, root)
		lastToast = box
		corner(box, 14); outline(box, 3)
		local l = text(box, { Text = tostring(msg), Font = FONT_BODY, TextColor3 = C.White, ZIndex = 51,
			Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.94, 0.76) })
		textStroke(l, 2)
		wobble(box)
		task.delay(2.4, function()
			if box.Parent then box:Destroy() end
		end)
	end

	local function setHead(title, color)
		headLbl.Text = title
		headBar.BackgroundColor3 = color
	end
	local function label(parent, txt, props, maxSize)
		local l = text(parent, { Text = txt, Font = FONT_BODY })
		if props then for k, v in props do l[k] = v end end
		return maxText(l, maxSize or 22)
	end
	local function box(parent, color, props)
		local f = new("Frame", props, parent)
		f.BackgroundColor3 = color
		corner(f, 14); outline(f, 3)
		return f
	end
	local function hRow(parent, props, pad)
		local f = new("Frame", { BackgroundTransparency = 1 }, parent)
		for k, v in props do f[k] = v end
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(pad or 0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder }, f)
		return f
	end
	local function makeScroll(parent, props, key)
		local sf = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
			ScrollBarImageColor3 = C.Ink, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, Size = UDim2.fromScale(1, 1) }, parent)
		if props then for k, v in props do sf[k] = v end end
		if key then
			task.delay(0.05, function()
				if not sf.Parent then return end
				if scrollMemo[key] then sf.CanvasPosition = scrollMemo[key] end
				sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function() scrollMemo[key] = sf.CanvasPosition end)
			end)
		end
		return sf
	end
	local function cardGrid(parent, props, key)
		local sf = makeScroll(parent, props, key)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) }, sf)
		local gap = 8
		local layout = new("UIGridLayout", { CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder }, sf)
		local function fit()
			local w = sf.AbsoluteSize.X - 16
			if w <= 0 then return end
			local cols = math.clamp(math.floor(w / 115), 3, 9)
			local cw = math.floor((w - gap * (cols - 1)) / cols)
			layout.CellSize = UDim2.fromOffset(cw, math.floor(cw / CARD_RATIO))
		end
		sf:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
		task.defer(fit)
		return sf
	end

	local function bubble(parent, txt, color, pos, anchor)
		local b = new("Frame", { BackgroundColor3 = color, Position = pos, AnchorPoint = anchor,
			Size = UDim2.fromScale(0.3, 0.3), ZIndex = 3 }, parent)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
		corner(b); outline(b, 2)
		local l = text(b, { Text = txt, Font = FONT_NUM, TextColor3 = C.White, ZIndex = 4,
			Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76) })
		textStroke(l, 1.5)
		return b
	end

	local function miniCard(parent, card, o)
		o = o or {}
		local isChar = card.Type == "Character"
		local elem = isChar and ELEM[card.Element] or nil
		local rank = RARITY_RANK[card.Rarity] or 1
		local rar = RARITY[card.Rarity] or RARITY.Common
		local f = new("TextButton", { AutoButtonColor = false, Text = "", Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = rank >= 4 and rgb(255, 244, 170) or C.White, LayoutOrder = o.order or 0 }, parent)
		corner(f, 10)
		outline(f, rank >= 3 and 4 or 3, rank >= 3 and rar.color or C.Ink)
		local head = new("Frame", { BackgroundColor3 = (elem and elem.color) or TYPE_COLOR[card.Type] or C.Gray,
			Size = UDim2.fromScale(1, 0.2) }, f)
		corner(head, 10)
		maxText(text(head, { Text = card.Name or "?", Font = FONT_BODY,
			Position = UDim2.fromScale(0.26, 0.1), Size = UDim2.fromScale(0.7, 0.8) }), 14)
		text(f, { Text = card.Emoji or ART[card.Id] or TYPE_ICON[card.Type] or "❓", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.34) })
		local rs = new("Frame", { BackgroundColor3 = rar.color, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.62, 0.1) }, f)
		corner(rs, 6)
		textStroke(maxText(text(rs, { Text = rar.name, Font = FONT_BODY, TextColor3 = C.White }), 12), 1)
		bubble(f, tostring(card.Cost or 0), C.Blue, UDim2.fromScale(0, 0), Vector2.new(0.25, 0.25))
		if isChar then
			bubble(f, tostring(card.ATK or 0), C.Red, UDim2.fromScale(0, 1), Vector2.new(0.2, 0.8))
			bubble(f, tostring(card.HP or 0), C.Green, UDim2.fromScale(1, 1), Vector2.new(0.8, 0.8))
		else
			maxText(text(f, { Text = card.Type == "Weapon" and ("🗡️ +%d"):format(card.Bonus or 0) or "✨ เวท",
				Font = FONT_BODY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.96),
				Size = UDim2.fromScale(0.9, 0.16) }), 14)
		end
		if o.count and o.count > 1 then
			local cb = new("Frame", { BackgroundColor3 = C.Yellow, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1.04, 0.16), Size = UDim2.fromScale(0.36, 0.13), ZIndex = 5 }, f)
			corner(cb, 8); outline(cb, 2)
			text(cb, { Text = "x" .. o.count, Font = FONT_NUM, ZIndex = 6 })
		end
		if o.onClick then f.Activated:Connect(o.onClick) end
		return f
	end

	-- ───── หน้าต่างซ้อน (จัดเด็ค/ฟาร์ม): จำไว้เพื่อปิดตอนเริ่มแมตช์ ─────
	local function closeWindows()
		for _, w in windows do
			if typeof(w) == "Instance" and w.Parent then w:Destroy() end
		end
		table.clear(windows)
		if Inspect and Inspect.Hide then pcall(Inspect.Hide) end
	end
	local function openWindow(name, fn)
		local before = {}
		for _, ch in overlay:GetChildren() do before[ch] = true end
		local ok, err = pcall(fn)
		for _, ch in overlay:GetChildren() do
			if not before[ch] then table.insert(windows, ch) end
		end
		if not ok then
			warn("[LobbyUI] เปิด " .. name .. " ไม่ได้: " .. tostring(err))
			toast("เปิดหน้า" .. name .. "ไม่ได้ 😵")
		end
	end

	-- ───── สถานะผู้เล่น ─────
	local function deckStatus()
		if not profile or typeof(profile.Deck) ~= "table" then return false, "กำลังโหลด" end
		local ok, valid, why = pcall(DeckRules.Validate, profile.Deck, profile.Collection)
		if not ok then return false, "ตรวจเด็คไม่ได้" end
		if valid then return true end
		return false, typeof(why) == "string" and Net.message(why) or "ยังไม่ครบ"
	end
	local function towerFloor()
		local f = (profile and tonumber(profile.TowerFloor)) or 1
		return math.clamp(f, 1, TOWER_MAX), f > TOWER_MAX
	end
	local function titleFor()
		if typeof(stats) ~= "table" then return "มือใหม่หัดกาว 🐣" end
		local w, l = tonumber(stats.Wins) or 0, tonumber(stats.Losses) or 0
		if w >= 50 then return "เทพทรู 👑" end
		if l >= w + 10 then return "ราชาเกลือ 🧂" end
		if (tonumber(stats.GatePoop) or 0) >= 5 then return "คนดวงกุด 💩" end
		if w >= 10 then return "นักกาวตัวจริง 🌀" end
		return "มือใหม่หัดกาว 🐣"
	end
	local function updateTop()
		gemLbl.Text = "💎 " .. (profile and tostring(profile.Gems or 0) or "...")
		if queueMode then
			nameChip.Text = ("⏳ หาคู่ PvP... %d วิ (แตะยกเลิก)"):format(queueElapsed)
			nameChip.BackgroundColor3 = C.Pink
		else
			nameChip.Text = ("😎 %s • %s"):format(player.DisplayName, titleFor())
			nameChip.BackgroundColor3 = C.Yellow
		end
		local n = 0
		local list = profile and profile.Quests and profile.Quests.List
		if typeof(list) == "table" then
			for _, q in list do
				if not q.Claimed and (q.Progress or 0) >= (q.Goal or 1) then n += 1 end
			end
		end
		questBadge.Visible = n > 0
		questBadgeLbl.Text = tostring(n)
	end
	local function paintTabs()
		for _, tab in TABS do
			local b = tabButtons[tab.Id]
			local on = tab.Id == currentTab
			b.BackgroundColor3 = on and tab.Color or C.White
			b.TextColor3 = on and C.White or C.Ink
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then st.Thickness = on and 6 or 4 end
		end
	end
	local function paintPvp()
		if not pvpBtn or not pvpBtn.Parent then return end
		if queueMode == "PvP" then
			pvpBtn.Text = ("⏳ กำลังหาคู่... %d วิ\nแตะเพื่อยกเลิก"):format(queueElapsed)
			pvpBtn.BackgroundColor3 = C.Gray
		else
			pvpBtn.Text = ("⚔️ จับคู่ PvP\nชนะ +%d 💎"):format(Config.REWARD_WIN_PVP or 0)
			pvpBtn.BackgroundColor3 = C.Pink
		end
	end

	local function setProfile(p)
		if typeof(p) ~= "table" then return end
		local oldGems = profile and profile.Gems
		profile = p
		updateTop()
		if oldGems and p.Gems and p.Gems ~= oldGems then wobble(gemChip) end
		if currentTab ~= "Gacha" then render() end -- กาชาไม่วาดใหม่ กันแอนิเมชันเปิดการ์ดสะดุด
	end
	local function refreshProfile()
		local p = Net.invoke("GetProfile")
		if typeof(p) == "table" then setProfile(p) return true end
		return false
	end
	local function refreshStats()
		local st = Net.invoke("GetStats")
		if typeof(st) == "table" then
			stats = st
			updateTop()
			if currentTab == "Stats" then render() end
		end
	end

	-- ───── คิว / เริ่มเกม ─────
	local function leaderId() return Decks.Leaders[leaderIndex] end
	local function cancelQueue()
		if not queueMode then return end
		queueMode = nil
		paintPvp(); updateTop()
		task.spawn(Net.invoke, "Queue", "Cancel")
		toast("ยกเลิกการหาคู่แล้ว", C.Gray)
	end
	local function startMode(mode)
		if starting then return end
		if not profile then toast("กำลังโหลดข้อมูล รอแป๊บนึง...", C.Orange) return end
		starting = true
		queueMode = nil -- เซิร์ฟเวอร์ล้างคิว PvP ให้เองเมื่อเริ่มโหมดอื่น
		paintPvp(); updateTop()
		toast(mode == "Tower" and "🗼 กำลังขึ้นหอคอย..." or "🤖 กำลังเรียกหุ่นฝึกซ้อม...", C.Blue)
		local ok, res = Net.invoke("Queue", mode, leaderId())
		starting = false
		if not ok then toast(Net.message(res)) end
	end
	local function togglePvP()
		if queueMode == "PvP" then cancelQueue() return end
		if not profile then toast("กำลังโหลดข้อมูล รอแป๊บนึง...", C.Orange) return end
		local ok, res = Net.invoke("Queue", "PvP", leaderId())
		if not ok then toast(Net.message(res)) return end
		if res == "WAITING" then
			queueMode, queueElapsed = "PvP", 0
			paintPvp(); updateTop()
			toast("⏳ เข้าคิวแล้ว ไปเปิดแท็บอื่นรอได้", C.Blue)
		end
	end
	nameChip.Activated:Connect(function()
		if queueMode then cancelQueue() end
	end)

	-- ───── การกระทำ ─────
	local function openDeckBuilder()
		if not DeckBuilder then toast("ไม่พบหน้าจัดเด็ค") return end
		if not profile then toast("กำลังโหลดข้อมูล รอแป๊บนึง...", C.Orange) return end
		openWindow("จัดเด็ค", function()
			DeckBuilder.Open(overlay, { Cards = CardData, Owned = profile.Collection, Deck = profile.Deck,
				Message = Net.message,
				OnSave = function(ids)
					local ok, err = Net.invoke("SaveDeck", ids)
					if ok then task.spawn(refreshProfile) end
					return ok, err
				end })
		end)
	end

	local function openFarm()
		local ok, farms, serverUnix = Net.invoke("GetFarms")
		if not ok then toast(Net.message(farms)) return end
		local offset = workspace:GetServerTimeNow() - (tonumber(serverUnix) or os.time())
		local list = {}
		for i, f in farms do
			local c = table.clone(f)
			c.LastClaim = (f.LastClaim or 0) + offset
			c.Color = ({ C.Green, C.Blue, C.Pink })[(i - 1) % 3 + 1]
			list[i] = c
		end
		FarmUI.Open(overlay, { Farms = list, Wallet = profile and profile.Gems or 0, WalletEmoji = "💎",
			OnClaim = function(id)
				local okC, amount = Net.invoke("ClaimFarm", id)
				if okC then task.spawn(refreshProfile) end
				return okC, okC and amount or Net.message(amount)
			end,
			OnUpgrade = function(id)
				local okU, nf = Net.invoke("UpgradeFarm", id)
				if not okU then return false, Net.message(nf) end
				nf.LastClaim = (nf.LastClaim or 0) + offset
				task.spawn(refreshProfile)
				return true, nf
			end })
	end

	local function pull(count)
		if pulling then return end
		local cost = count == 1 and Config.GACHA_COST_1 or Config.GACHA_COST_10
		if profile and (profile.Gems or 0) < cost then
			toast(("เพชรไม่พอ ต้องใช้ %d 💎"):format(cost))
			return
		end
		pulling = true
		local ok, res = Net.invoke("Gacha", count)
		pulling = false
		if not ok then toast(Net.message(res)) return end
		local got = {}
		if typeof(res) == "table" then
			for _, item in res do
				local id = typeof(item) == "table" and item.Id or item
				if CardData[id] then table.insert(got, id) end
			end
		end
		lastPull = got
		revealNext = true
		if currentTab == "Gacha" then render() end
	end

	local function claimQuest(id)
		local ok, res = Net.invoke("ClaimQuest", id)
		if ok then
			toast(("🎉 ได้รับ %s 💎"):format(tostring(res)), C.Green)
			task.spawn(refreshProfile)
		else
			toast(Net.message(res))
		end
	end

	-- ───── หน้า: ต่อสู้ ─────
	pages.Battle = function()
		setHead("⚔️ ลงสนาม! เลือกผู้นำ แล้วเลือกโหมด", C.Red)
		label(body, "① เลือกผู้นำ (ตัวแทนคุณในสนาม)", { TextXAlignment = LEFT, Size = UDim2.fromScale(1, 0.07) })
		local n = #Decks.Leaders
		local w = (1 - 0.02 * (n - 1)) / math.max(1, n)
		local row = hRow(body, { Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.42) }, 0.02)
		for i, id in Decks.Leaders do
			local ld = CardData[id] or {}
			local picked = i == leaderIndex
			local b = new("TextButton", { AutoButtonColor = false, Text = "", LayoutOrder = i,
				BackgroundColor3 = picked and C.Yellow or C.White, Size = UDim2.fromScale(w, 1) }, row)
			corner(b, 16); outline(b, picked and 6 or 3)
			text(b, { Text = ld.Emoji or "🙂", Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.36) })
			label(b, ld.Name or id, { Font = FONT, Position = UDim2.fromScale(0.05, 0.42), Size = UDim2.fromScale(0.9, 0.14) }, 24)
			label(b, ld.Desc or "", { TextWrapped = true, Position = UDim2.fromScale(0.06, 0.57),
				Size = UDim2.fromScale(0.88, 0.24) }, 15)
			local tag = new("Frame", { BackgroundColor3 = picked and C.Green or C.Soft, AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.96), Size = UDim2.fromScale(0.8, 0.13) }, b)
			corner(tag, 10); outline(tag, 2)
			label(tag, picked and "✅ เลือกแล้ว" or "แตะเพื่อเลือก", { TextColor3 = picked and C.White or C.Gray }, 16)
			b.Activated:Connect(function()
				if leaderIndex ~= i then
					leaderIndex = i
					render()
				end
			end)
		end

		label(body, "② เลือกโหมด", { TextXAlignment = LEFT, Position = UDim2.fromScale(0, 0.52), Size = UDim2.fromScale(1, 0.07) })
		local modes = hRow(body, { Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.29) }, 0.02)
		local function modeBtn(order, txt, color, fn)
			local b = chunkyButton(modes, txt, color, fn)
			b.Size = UDim2.fromScale(0.32, 1)
			b.LayoutOrder = order
			return b
		end
		modeBtn(1, ("🤖 ซ้อมกับบอท\nชนะ +%d 💎"):format(Config.REWARD_WIN_BOT or 0), C.Lime, function() startMode("Bot") end)
		pvpBtn = modeBtn(2, "", C.Pink, togglePvP)
		paintPvp()
		local floor, cleared = towerFloor()
		modeBtn(3, ("🗼 หอคอย ชั้น %d%s\nชนะ +%d 💎"):format(floor, cleared and " (ซ้ำ)" or "", towerReward(floor)),
			C.Orange, function() startMode("Tower") end)

		local ok, why = deckStatus()
		label(body, ok and "🃏 ใช้เด็คของคุณ (ผ่านกติกาแล้ว)"
			or ("⚠️ เด็คยังไม่ผ่านกติกา: %s → ระบบจะใช้เด็คเริ่มต้นแทน"):format(why or "-"),
			{ TextColor3 = ok and C.Green or C.Orange, Position = UDim2.fromScale(0, 0.91), Size = UDim2.fromScale(1, 0.08) }, 18)
	end

	-- ───── หน้า: เด็ค ─────
	pages.Deck = function()
		setHead("🃏 เด็คของคุณ", C.Blue)
		local ids = (profile and profile.Deck) or Decks.Starter
		local counts, order = {}, {}
		local n = { Character = 0, Spell = 0, Weapon = 0 }
		for _, id in ids do
			local c = CardData[id]
			if c then
				if not counts[id] then
					counts[id] = 0
					table.insert(order, id)
				end
				counts[id] += 1
				if n[c.Type] then n[c.Type] += 1 end
			end
		end
		table.sort(order, function(a, b)
			local ca, cb = CardData[a], CardData[b]
			local ta, tb = TYPE_ORDER[ca.Type] or 9, TYPE_ORDER[cb.Type] or 9
			if ta ~= tb then return ta < tb end
			if (ca.Cost or 0) ~= (cb.Cost or 0) then return (ca.Cost or 0) < (cb.Cost or 0) end
			return a < b
		end)

		local comp = Config.DECK_COMPOSITION or {}
		local chips = hRow(body, { Size = UDim2.fromScale(1, 0.1) }, 0.015)
		local function chip(ord, txt, good)
			local f = box(chips, good and rgb(210, 255, 200) or rgb(255, 225, 190),
				{ Size = UDim2.fromScale(0.235, 1), LayoutOrder = ord })
			label(f, txt, { Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.92, 0.8) }, 20)
		end
		chip(1, ("🙂 ตัวละคร %d/%d"):format(n.Character, comp.Character or 0), n.Character == comp.Character)
		chip(2, ("✨ เวท %d/%d"):format(n.Spell, comp.Spell or 0), n.Spell == comp.Spell)
		chip(3, ("🗡️ อาวุธ %d/%d"):format(n.Weapon, comp.Weapon or 0), n.Weapon == comp.Weapon)
		local ok = deckStatus()
		chip(4, ok and "✅ พร้อมใช้" or "⚠️ ยังไม่ผ่านกติกา", ok)

		local info = box(body, C.White, { Position = UDim2.fromScale(0, 0.82), Size = UDim2.fromScale(0.66, 0.18) })
		local infoLbl = label(info, describe(nil), { RichText = true, TextWrapped = true, TextXAlignment = LEFT,
			TextYAlignment = TOP, Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.84) }, 16)
		local grid = cardGrid(body, { Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(1, 0.68) }, "Deck")
		for i, id in order do
			local c = CardData[id]
			miniCard(grid, c, { order = i, count = counts[id], onClick = function() infoLbl.Text = describe(c) end })
		end
		local edit = chunkyButton(body, DeckBuilder and "✏️ จัดเด็ค" or "🚧 จัดเด็คยังไม่พร้อม", C.Yellow, openDeckBuilder)
		edit.Position = UDim2.fromScale(0.68, 0.82)
		edit.Size = UDim2.fromScale(0.32, 0.18)
	end

	-- ───── หน้า: กาชา ─────
	pages.Gacha = function()
		setHead("🎰 ตู้กาชาเกลือ (สุ่มการ์ด)", C.Pink)
		local left = box(body, C.Yellow, { Size = UDim2.fromScale(0.32, 1) })
		text(left, { Text = "🎰", Position = UDim2.fromScale(0.1, 0.02), Size = UDim2.fromScale(0.8, 0.2) })
		local lines = { "<b>เรทสุ่ม</b>" }
		for _, r in { "Legend", "Epic", "Rare", "Common" } do
			local v = Config.GACHA_RATES and Config.GACHA_RATES[r]
			if v then
				table.insert(lines, ("<font color=\"#%s\">■</font> %s %s%%"):format(RARITY[r].color:ToHex(), RARITY[r].name, tostring(v)))
			end
		end
		table.insert(lines, ("การันตีเอพิกขึ้นไปใน %d ครั้ง"):format(Config.GACHA_EPIC_PITY or 10))
		table.insert(lines, ("การันตีตำนานใน %d ครั้ง"):format(Config.GACHA_LEGEND_PITY or 60))
		label(left, table.concat(lines, "\n"), { RichText = true, TextWrapped = true, TextYAlignment = TOP,
			Position = UDim2.fromScale(0.07, 0.24), Size = UDim2.fromScale(0.86, 0.44) }, 18)
		local b1 = chunkyButton(left, ("สุ่ม 1 ครั้ง\n💎 %d"):format(Config.GACHA_COST_1), C.Pink, function() pull(1) end)
		b1.Position = UDim2.fromScale(0.07, 0.7); b1.Size = UDim2.fromScale(0.86, 0.13)
		local b10 = chunkyButton(left, ("สุ่ม 10 ครั้ง\n💎 %d"):format(Config.GACHA_COST_10), C.Lime, function() pull(10) end)
		b10.Position = UDim2.fromScale(0.07, 0.85); b10.Size = UDim2.fromScale(0.86, 0.13)

		local right = box(body, C.White, { Position = UDim2.fromScale(0.34, 0), Size = UDim2.fromScale(0.66, 1) })
		if #lastPull == 0 then
			label(right, "กดสุ่มเลย! เกลือรออยู่ 🧂", { TextColor3 = C.Gray,
				Position = UDim2.fromScale(0.1, 0.4), Size = UDim2.fromScale(0.8, 0.15) }, 28)
			return
		end
		local info = label(right, describe(nil), { RichText = true, TextWrapped = true, TextXAlignment = LEFT,
			TextYAlignment = TOP, Position = UDim2.fromScale(0.03, 0.83), Size = UDim2.fromScale(0.94, 0.15) }, 16)
		local grid = cardGrid(right, { Position = UDim2.fromScale(0.02, 0.03), Size = UDim2.fromScale(0.96, 0.78) })
		local views, list = {}, lastPull
		for i, id in list do
			local c = CardData[id]
			views[i] = miniCard(grid, c, { order = i, onClick = function() info.Text = describe(c) end })
		end
		if not revealNext then return end
		revealNext = false
		for _, f in views do new("UIScale", { Scale = 0 }, f) end
		task.spawn(function()
			local best = 1
			for i, f in views do
				if not f.Parent then return end
				local rank = RARITY_RANK[CardData[list[i]].Rarity] or 1
				best = math.max(best, rank)
				tween(f:FindFirstChildOfClass("UIScale"), 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				if rank >= 3 then wobble(f) end
				task.wait(rank >= 3 and 0.35 or 0.09)
			end
			if best <= 1 then toast("🧂 เกลือล้วน! ตู้หัวเราะใส่หน้า 555+", C.Gray)
			elseif best == 2 then toast("😏 ได้แรร์... ก็ยังดีกว่าเกลือ", C.Blue)
			elseif best == 3 then toast("✨ เอพิก! ดวงเริ่มมาแล้ว", C.Purple)
			else toast("🌟 ตำนาน!! ใครเติมกาวให้เนี่ย", C.Gold) end
		end)
	end

	-- ───── หน้า: เควสต์ ─────
	pages.Quests = function()
		setHead("📜 เควสต์ประจำวัน", C.Green)
		local list = makeScroll(body, nil, "Quests")
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, list)
		local quests = profile and profile.Quests and profile.Quests.List
		if typeof(quests) ~= "table" or #quests == 0 then
			label(list, "กำลังโหลดเควสต์...", { TextColor3 = C.Gray, Size = UDim2.new(1, 0, 0, 40) })
			return
		end
		for i, q in quests do
			local goal = math.max(1, tonumber(q.Goal) or 1)
			local prog = math.clamp(tonumber(q.Progress) or 0, 0, goal)
			local done = prog >= goal
			local bg = q.Claimed and rgb(228, 226, 236) or (done and rgb(214, 255, 196) or C.White)
			local row = box(list, bg, { LayoutOrder = i, Size = UDim2.new(1, -16, 0, 74) })
			text(row, { Text = q.Claimed and "✅" or (done and "🎁" or "📜"),
				Position = UDim2.fromScale(0.01, 0.12), Size = UDim2.fromScale(0.07, 0.76) })
			label(row, tostring(q.Text or q.Id), { TextXAlignment = LEFT,
				Position = UDim2.fromScale(0.09, 0.08), Size = UDim2.fromScale(0.56, 0.42) }, 20)
			local barBg = new("Frame", { BackgroundColor3 = rgb(70, 40, 70), Position = UDim2.fromScale(0.09, 0.58),
				Size = UDim2.fromScale(0.56, 0.28) }, row)
			corner(barBg, 8); outline(barBg, 2)
			corner(new("Frame", { BackgroundColor3 = done and C.Green or C.Blue, Size = UDim2.fromScale(prog / goal, 1) }, barBg), 8)
			textStroke(text(barBg, { Text = ("%s/%s"):format(fmtNum(prog), fmtNum(goal)), Font = FONT_NUM, TextColor3 = C.White }), 1.5)
			local rightPos, rightSize = UDim2.fromScale(0.68, 0.15), UDim2.fromScale(0.3, 0.7)
			if q.Claimed then
				label(row, "รับแล้ว ✅", { TextColor3 = C.Gray, Position = rightPos, Size = rightSize }, 20)
			elseif done then
				local b = chunkyButton(row, ("🎁 รับ %s 💎"):format(tostring(q.Reward or 0)), C.Lime, function() claimQuest(q.Id) end)
				b.Position = rightPos; b.Size = rightSize
				wobble(b)
			else
				label(row, ("รางวัล %s 💎"):format(tostring(q.Reward or 0)), { TextColor3 = C.Purple,
					Position = rightPos, Size = rightSize }, 20)
			end
		end
	end

	-- ───── หน้า: สถิติ ─────
	pages.Stats = function()
		setHead("📊 สถิติของคุณ", C.Purple)
		if typeof(stats) ~= "table" then
			label(body, "กำลังโหลดสถิติ...", { TextColor3 = C.Gray, Size = UDim2.fromScale(1, 0.1) })
			return
		end
		local w, l = tonumber(stats.Wins) or 0, tonumber(stats.Losses) or 0
		local rate = (w + l) > 0 and math.floor(w / (w + l) * 100 + 0.5) or 0
		local row = hRow(body, { Size = UDim2.fromScale(1, 0.24) }, 0.02)
		local function big(ord, icon, value, name, color)
			local f = box(row, color, { Size = UDim2.fromScale(0.235, 1), LayoutOrder = ord })
			text(f, { Text = icon, Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.34) })
			textStroke(text(f, { Text = value, Font = FONT_NUM, TextColor3 = C.White,
				Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.34) }), 2)
			label(f, name, { Position = UDim2.fromScale(0.05, 0.74), Size = UDim2.fromScale(0.9, 0.2) }, 16)
		end
		big(1, "🏆", fmtNum(w), "ชนะ", C.Yellow)
		big(2, "🤡", fmtNum(l), "แพ้", C.Pink)
		big(3, "📈", rate .. "%", "อัตราชนะ", C.Blue)
		big(4, "💎", fmtNum(math.floor(tonumber(stats.GemsEarned) or 0)), "เพชรที่ได้", C.Lime)

		local list = makeScroll(body, { Position = UDim2.fromScale(0, 0.27), Size = UDim2.fromScale(1, 0.73) }, "Stats")
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
		local i = 0
		for _, entry in STAT_ORDER do
			local v = stats[entry[1]]
			if typeof(v) == "number" then
				i += 1
				local r = new("Frame", { BackgroundColor3 = i % 2 == 0 and C.Soft or C.White, LayoutOrder = i,
					Size = UDim2.new(1, -16, 0, 34) }, list)
				corner(r, 8)
				label(r, entry[2], { TextXAlignment = LEFT, Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.65, 0.7) }, 17)
				label(r, fmtNum(v), { Font = FONT_NUM, TextColor3 = C.Purple, TextXAlignment = RIGHT,
					Position = UDim2.fromScale(0.68, 0.15), Size = UDim2.fromScale(0.29, 0.7) }, 18)
			end
		end
		if i == 0 then
			label(list, "ยังไม่มีสถิติ ลองเล่นสักแมตช์!", { TextColor3 = C.Gray, Size = UDim2.new(1, 0, 0, 40) })
		end
	end

	-- ───── หน้า: โหมดอื่น ─────
	pages.Modes = function()
		setHead("🗼 โหมดอื่น ๆ", C.Orange)
		local function tile(pos, color, icon, title, desc, btnText, fn)
			local f = box(body, color, { Position = pos, Size = UDim2.fromScale(0.49, 0.48) })
			text(f, { Text = icon, Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.24, 0.5) })
			textStroke(text(f, { Text = title, TextColor3 = C.White, TextXAlignment = LEFT,
				Position = UDim2.fromScale(0.3, 0.06), Size = UDim2.fromScale(0.67, 0.2) }), 2)
			label(f, desc, { TextWrapped = true, TextXAlignment = LEFT, TextYAlignment = TOP,
				Position = UDim2.fromScale(0.3, 0.29), Size = UDim2.fromScale(0.67, 0.34) }, 15)
			if fn then
				local b = chunkyButton(f, btnText, C.White, fn)
				b.Position = UDim2.fromScale(0.05, 0.68); b.Size = UDim2.fromScale(0.9, 0.26)
			else
				local s = box(f, C.Soft, { Position = UDim2.fromScale(0.05, 0.68), Size = UDim2.fromScale(0.9, 0.26) })
				label(s, btnText, { TextColor3 = C.Gray }, 20)
			end
		end
		local floor, cleared = towerFloor()
		tile(UDim2.fromScale(0, 0), C.Orange, "🗼", ("หอคอย ชั้น %d/%d"):format(floor, TOWER_MAX),
			cleared and "พิชิตครบทุกชั้นแล้ว! ท้าชั้นบนสุดซ้ำได้"
				or "สู้บอสทีละชั้น ยิ่งสูงบอสยิ่งมีเกราะหนาและการ์ดแรงขึ้น",
			("⚔️ ท้าบอสชั้น %d (+%d 💎)"):format(floor, towerReward(floor)), function() startMode("Tower") end)
		tile(UDim2.fromScale(0.51, 0), C.Green, "🌾", "ฟาร์มเพชร", "เก็บเพชรที่งอกเองตามเวลา อัปเกรดให้งอกเร็วขึ้น",
			FarmUI and "🌾 เปิดฟาร์ม" or "🚧 ยังไม่พร้อม",
			FarmUI and function() openWindow("ฟาร์ม", openFarm) end or nil)
		tile(UDim2.fromScale(0, 0.52), C.Pink, "💰", "ค่าหัว (Bounty)",
			"ชนะ PvP ติดกันค่าหัวจะพุ่ง ใครล้มคนค่าหัวสูงได้ รับเพชรโบนัส",
			"⚔️ ไปล่าค่าหัวใน PvP", function() openTab("Battle") end)
		tile(UDim2.fromScale(0.51, 0.52), C.Blue, "🏆", "ทัวร์นาเมนต์",
			"แข่งแบบแพ้คัดออก 10 คน (ยังไม่เปิดให้เล่น)", "🚧 เร็ว ๆ นี้", nil)
	end

	-- ───── วาดหน้า ─────
	render = function()
		body:ClearAllChildren()
		pvpBtn = nil
		local fn = pages[currentTab]
		if not fn then return end
		local ok, err = pcall(fn)
		if not ok then
			warn("[LobbyUI] หน้า " .. currentTab .. " พัง: " .. tostring(err))
			body:ClearAllChildren()
			label(body, "😵 หน้านี้โหลดไม่สำเร็จ ลองกดเมนูอีกครั้ง", { TextColor3 = C.Red, Size = UDim2.fromScale(1, 0.15) })
		end
	end
	openTab = function(id)
		currentTab = id
		paintTabs()
		render()
		if id == "Stats" then task.spawn(refreshStats) end
	end

	-- ───── เน็ตเวิร์ก / ลูป ─────
	Net.on("ProfileChanged", setProfile)

	task.spawn(function()
		while root.Parent do
			task.wait(1)
			if queueMode then
				queueElapsed += 1
				paintPvp(); updateTop()
			end
		end
	end)

	function LobbyUI.Refresh()
		task.spawn(function()
			for _ = 1, 20 do -- ข้อมูลยังโหลดไม่เสร็จ → ลองใหม่
				if refreshProfile() then break end
				task.wait(1.5)
			end
			refreshStats()
		end)
	end

	function LobbyUI.ResetQueue() -- ถูกเรียกตอนเริ่มแมตช์
		queueMode = nil
		closeWindows()
		paintPvp(); updateTop()
	end

	paintTabs(); updateTop(); render()
	LobbyUI.Refresh()
end

return LobbyUI