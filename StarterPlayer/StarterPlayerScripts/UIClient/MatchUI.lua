-- ============================================================
-- StarterPlayer > StarterPlayerScripts > UIClient > MatchUI (ModuleScript)
-- UI v2 "PASULOL": แตะการ์ด → แตะเป้าหมาย (PC/มือถือ)
-- API เดิม: MatchUI.Build(gui, overlay, { OnStart, OnExit })
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local CardData = require(Shared:WaitForChild("CardData"))
local Net = require(script.Parent:WaitForChild("Net"))
local Perf = require(Shared:WaitForChild("UI"):WaitForChild("Perf"))

local MatchUI = {}

-- ───── ธีม ─────
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
	Ink = rgb(14, 10, 24), White = rgb(255, 255, 255), Paper = rgb(255, 251, 236),
	Bg = rgb(255, 238, 200), OppZone = rgb(255, 205, 225), MyZone = rgb(200, 232, 255),
	Yellow = rgb(255, 228, 0), Lime = rgb(198, 255, 0), Pink = rgb(255, 36, 168),
	Blue = rgb(0, 170, 255), Green = rgb(36, 200, 100), Orange = rgb(255, 128, 0),
	Red = rgb(255, 48, 72), Purple = rgb(148, 56, 255), Gray = rgb(150, 146, 170),
	Gold = rgb(255, 196, 0), Brown = rgb(130, 82, 40),
}
local LOG_COLOR = { Red = rgb(220, 30, 60), Blue = rgb(0, 130, 210), Green = rgb(20, 150, 70),
	Yellow = rgb(190, 130, 0), Pink = rgb(210, 20, 140) }

local FONT = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold
local FONT_NUM = Enum.Font.FredokaOne
local CARD_RATIO = 0.72

local ELEM = {
	Sati = { name = "สติ", icon = "🧘", color = C.Blue },
	Biao = { name = "เบียว", icon = "😈", color = C.Pink },
	Muen = { name = "มึน", icon = "😵", color = C.Orange },
	Gawa = { name = "กาว", icon = "🌀", color = C.Lime },
}
local TYPE_COLOR = { Spell = C.Purple, Weapon = C.Brown, Leader = C.Gold }
local TYPE_ICON = { Character = "🙂", Spell = "✨", Weapon = "🗡️", Leader = "👑" }
local KW = {
	Rush = { "⚡", "บุก", "ลงสนามแล้วตีได้ทันที" },
	Taunt = { "🛡️", "ยั่ว", "ศัตรูต้องตีตัวนี้ก่อน" },
	Necro = { "⚰️", "ขุดศพ", "ลงสนามแล้วขุดตัวละครจากช่องตายขึ้นมือ" },
	Unlucky = { "🪙", "ดวงซวย", "ตายแล้วโยนเหรียญ: หัว=ศัตรูโดน 3 / ก้อย=ผู้นำเราโดน 3" },
	Steal = { "🦹", "ขโมย", "ลงสนามแล้วขโมยพอยต์ที่ศัตรูดองไว้ 2" },
}
local GATE = {
	Golden = { icon = "🌟", title = "🌟 ร่างทอง!", sub = "ATK/HP ×3", color = C.Gold },
	Pumped = { icon = "💪", title = "💪 ปั๊มพลัง!", sub = "ATK/HP ×1.5", color = C.Green },
	Normal = { icon = "😐", title = "😐 ธรรมดา", sub = "×1", color = C.White },
	Droopy = { icon = "🫠", title = "🫠 ย้วย...", sub = "ATK/HP ×0.5", color = C.Blue },
	Poop = { icon = "💩", title = "💩 ก้อนอึ!!", sub = "HP 1 / ATK 0", color = C.Brown },
}
local GATE_ORDER = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }
local ART = {
	KAI_CHON = "🐓", MAEW_SOM = "🐈", LOOKCHIN = "🍡", PA_MOUTH = "🗣️", PILLOW_THIEF = "🦹",
	BIAO_KID = "😎", WIN_MOTO = "🛵", GUARD = "💂", TEACHER = "📏", KARAOKE = "🎤",
	MOOKATA = "🥘", SOMTAM_KING = "🦀",
	SHIELD_POT = "🛡️", SLIME = "🟢", SLAP = "👋", BALM = "💚", MYSTERY_BOX = "🎁",
	MOM_CALL = "📣", RICE_BOMB = "💣",
	SLIPPER = "👡", BROOM = "🧹", SPATULA = "🍳", FROZEN_FISH = "🐟", BROKEN_UMBRELLA = "☂️",
}
local DEATH = { "🍜 กลายเป็นก๋วยเตี๋ยว!", "💥 ตู้มมม!", "👾 แตกเป็นพิกเซล", "😭 อ๊ากกก!", "🧻 ปลิวไปกับลม" }
local REASON = {
	LEADER_DOWN = "ผู้นำล้มคาสนาม", FATIGUE = "การ์ดหมดกองจนหมดแรง",
	SURRENDER = "มีคนยอมแพ้", AFK_LIGHTNING = "โดนฟ้าผ่าเพราะ AFK ⚡",
}
local EXTRA_ERR = {
	CANNOT_ATTACK = "ตัวนี้ตีไม่ได้ตอนนี้", TAUNT = "ต้องตีตัวที่มี 🛡️ยั่ว ก่อน!",
	NEED_TARGET = "ต้องเลือกเป้าหมายก่อน",
}
local HELP = table.concat({
	"<b>วิธีเล่น</b>",
	"• แตะการ์ดในมือ → แตะช่อง/เป้าหมายที่เรืองแสง",
	"• แตะตัวละครขอบเขียว → แตะศัตรูเพื่อตี",
	"• ไม่ลงการ์ด/ไม่ตีแล้วกดข้าม = ดองพอยต์ (ลงโล่ 0 แต้มได้)",
	"• ช่องเกต: ถูกลง 1 แต้ม เทิร์นหน้าสุ่มตั้งแต่ ×3 ถึง 💩",
	"",
	"<b>ธาตุ</b> (มีผลทั้งตอนตีและตอนสวน)",
	"🧘สติ ▶ 😈เบียว ▶ 😵มึน ▶ 🧘สติ  (+2)",
	"🌀กาว ชนะทุกธาตุ (+1)",
	"❄️ ตัวที่โดนแช่แข็ง ตีและสวนไม่ได้",
}, "\n")

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
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function clear(container)
	for _, ch in container:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end
local function esc(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function findIn(list, uid)
	if not list then return nil end
	for _, c in list do if c.Uid == uid then return c end end
	return nil
end
local function errMsg(code) return EXTRA_ERR[code] or Net.message(code) end

local function chunkyButton(parent, label, color, onClick)
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, Font = FONT,
		Text = label, TextScaled = true, TextColor3 = C.Ink }, parent)
	corner(b, 14); outline(b, 4); maxText(b, 26)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	local sc = new("UIScale", {}, b)
	b.MouseButton1Down:Connect(function() tween(sc, 0.06, { Scale = 0.9 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(sc, 0.1, { Scale = 1 }) end)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

-- tween วนไม่รู้จบ: ยกเลิกเมื่อ GUI ถูกลบ (render สร้างการ์ดใหม่ทุกครั้ง) และข้ามเมื่อกราฟิก Low
local function loopTween(owner, inst, info, goal)
	if Perf.Name() == "Low" then return end
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	owner.Destroying:Once(function() tw:Cancel() end)
end

local function wobble(g)
	if not g or not g.Parent then return end
	g.Rotation = (math.random(0, 1) == 0 and -1 or 1) * math.random(8, 16)
	tween(g, 0.6, { Rotation = 0 }, Enum.EasingStyle.Elastic)
end
local function squash(art)
	if not art or not art.Parent then return end
	local s = art.Size
	art.Size = UDim2.new(s.X.Scale * 1.6, 0, s.Y.Scale * 0.5, 0)
	tween(art, 0.7, { Size = s }, Enum.EasingStyle.Elastic)
	if art:IsA("TextLabel") then
		local old = art.Text
		art.Text = "😵"
		task.delay(0.6, function() if art.Parent then art.Text = old end end)
	end
end

-- ============================================================
function MatchUI.Build(gui, overlay, cb)
	cb = cb or {}
	pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
	gui.Enabled = true

	local state, sel = nil, nil
	local targets, fieldViews = {}, {}
	local inspectedUid, inspectedCard = nil, nil
	local currentId, closedId = nil, nil
	local ended, endPending = false, false
	local logLines = {}
	local render, act -- forward

	-- ───── โครง ─────
	-- โปร่งใส: ให้เห็นโต๊ะ 3D (CardTable) ที่กล้องแพนไปหา ไม่มีพื้นหลังทึบ/กราเดียนต์บังฉาก
	local root = new("Frame", { Name = "MatchRoot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	local bgBtn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, root)

	local function zone(color, pos, title)
		local z = new("Frame", { BackgroundColor3 = color, Position = pos, Size = UDim2.fromScale(0.71, 0.27) }, root)
		corner(z, 18); outline(z, 4)
		local t = text(z, { Text = title, Font = FONT, TextColor3 = C.White, Position = UDim2.fromScale(0.01, 0.01),
			Size = UDim2.fromScale(0.2, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
		textStroke(t, 2)
		local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.96, 0.84) }, z)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.015, 0), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		return row
	end
	local oppRow = zone(C.OppZone, UDim2.fromScale(0.015, 0.13), "สนามศัตรู")
	local myRow = zone(C.MyZone, UDim2.fromScale(0.015, 0.465), "สนามเรา")

	-- แถบกลาง
	local mid = new("Frame", { BackgroundColor3 = C.Paper, Position = UDim2.fromScale(0.015, 0.405), Size = UDim2.fromScale(0.71, 0.055) }, root)
	corner(mid, 12); outline(mid, 3)
	local midLbl = maxText(text(mid, { Font = FONT_BODY, Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.96, 0.8) }), 20)

	-- แถบบน
	local top = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.015, 0.012), Size = UDim2.fromScale(0.97, 0.105) }, root)

	local function leaderPanel(parent, pos, size)
		local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = C.Paper, Position = pos, Size = size }, parent)
		corner(b, 16)
		local st = outline(b, 4)
		local emoji = text(b, { Text = "🙂", Position = UDim2.fromScale(0.02, 0.08), Size = UDim2.fromScale(0.24, 0.84) })
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, emoji)
		local name = maxText(text(b, { Font = FONT_BODY, Position = UDim2.fromScale(0.28, 0.06), Size = UDim2.fromScale(0.7, 0.28),
			TextXAlignment = Enum.TextXAlignment.Left }), 20)
		local barBg = new("Frame", { BackgroundColor3 = rgb(70, 40, 70), Position = UDim2.fromScale(0.28, 0.4), Size = UDim2.fromScale(0.68, 0.28) }, b)
		corner(barBg, 8); outline(barBg, 3)
		local bar = new("Frame", { BackgroundColor3 = C.Green, Size = UDim2.fromScale(1, 1) }, barBg)
		corner(bar, 8)
		local hp = text(barBg, { Font = FONT_NUM, TextColor3 = C.White })
		textStroke(hp, 2)
		local sub = maxText(text(b, { Font = FONT_BODY, Position = UDim2.fromScale(0.28, 0.72), Size = UDim2.fromScale(0.7, 0.24),
			TextXAlignment = Enum.TextXAlignment.Left }), 16)
		local tag = new("Frame", { BackgroundColor3 = C.Red, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0, 0),
			Size = UDim2.fromScale(0.36, 0.42), Visible = false }, b)
		corner(tag, 10); outline(tag, 3)
		local tagL = text(tag, { Font = FONT_NUM, TextColor3 = C.White })
		textStroke(tagL, 2)
		return { btn = b, stroke = st, emoji = emoji, name = name, bar = bar, hp = hp, sub = sub, tag = tag, tagL = tagL }
	end

	local oppL = leaderPanel(top, UDim2.fromScale(0, 0), UDim2.fromScale(0.42, 1))
	local timerBox = new("Frame", { BackgroundColor3 = C.Yellow, Position = UDim2.fromScale(0.435, 0), Size = UDim2.fromScale(0.17, 1) }, top)
	corner(timerBox, 16); outline(timerBox, 4)
	local timerLbl = text(timerBox, { Font = FONT_NUM, Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.55), Text = "⏱ 2:00" })
	local turnLbl = maxText(text(timerBox, { Font = FONT_BODY, Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.35) }), 18)
	local oppStats = new("Frame", { BackgroundColor3 = C.Paper, Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 1) }, top)
	corner(oppStats, 16); outline(oppStats, 4)
	local oppStatsLbl = maxText(text(oppStats, { Font = FONT_BODY, Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.92, 0.8) }), 20)

	-- แผงข้อมูล + บันทึก
	local info = new("Frame", { BackgroundColor3 = C.Paper, Position = UDim2.fromScale(0.735, 0.13), Size = UDim2.fromScale(0.25, 0.39) }, root)
	corner(info, 16); outline(info, 4)
	local infoLbl = maxText(text(info, { Font = FONT_BODY, RichText = true, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.92) }), 18)
	local logBox = new("Frame", { BackgroundColor3 = C.White, Position = UDim2.fromScale(0.735, 0.53), Size = UDim2.fromScale(0.25, 0.205) }, root)
	corner(logBox, 16); outline(logBox, 4)
	local logLbl = maxText(text(logBox, { Font = FONT_BODY, RichText = true, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.9) }), 15)

	-- ด้านล่าง
	local myL = leaderPanel(root, UDim2.fromScale(0.015, 0.75), UDim2.fromScale(0.18, 0.235))
	local hand = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.205, 0.755), Size = UDim2.fromScale(0.555, 0.23) }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }, hand)

	local controls = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.77, 0.75), Size = UDim2.fromScale(0.215, 0.235) }, root)
	local ptsBox = new("Frame", { BackgroundColor3 = C.Yellow, Size = UDim2.fromScale(1, 0.34) }, controls)
	corner(ptsBox, 16); outline(ptsBox, 4)
	local ptsLbl = text(ptsBox, { Font = FONT_NUM, Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.62) })
	local ptsSub = maxText(text(ptsBox, { Font = FONT_BODY, Position = UDim2.fromScale(0.05, 0.64), Size = UDim2.fromScale(0.9, 0.32) }), 14)
	local endBtn = chunkyButton(controls, "⏳", C.Gray)
	endBtn.Position = UDim2.fromScale(0, 0.38); endBtn.Size = UDim2.fromScale(1, 0.4)
	local surrBtn = chunkyButton(controls, "🏳️ ยอมแพ้", rgb(255, 150, 160))
	surrBtn.Position = UDim2.fromScale(0, 0.82); surrBtn.Size = UDim2.fromScale(1, 0.18)

	local actionBar = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.37, 0.748), Size = UDim2.fromScale(0.5, 0.06), Visible = false, ZIndex = 20 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }, actionBar)

	local fx = new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 }, root)

	-- ───── เอฟเฟกต์ ─────
	local function toast(msg, color)
		local box = new("Frame", { BackgroundColor3 = color or C.Red, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.37, 0.135), Size = UDim2.fromScale(0.4, 0.055) }, fx)
		corner(box, 12); outline(box, 3)
		local l = text(box, { Text = msg, Font = FONT_BODY, TextColor3 = C.White, Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.94, 0.8) })
		textStroke(l, 2)
		wobble(box)
		task.delay(1.8, function()
			if box.Parent then
				tween(box, 0.25, { BackgroundTransparency = 1 })
				tween(l, 0.25, { TextTransparency = 1 })
				task.wait(0.27)
				box:Destroy()
			end
		end)
	end

	local function popAt(pos, size, msg, color, big)
		local base = fx.AbsolutePosition
		local l = text(fx, { Text = msg, TextColor3 = color, Font = FONT_NUM, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(big and 170 or 100, big and 64 or 44),
			Position = UDim2.fromOffset(pos.X - base.X + size.X / 2, pos.Y - base.Y + size.Y / 2),
			Rotation = math.random(-14, 14) })
		local st = textStroke(l, 3)
		local sc = new("UIScale", { Scale = 0.3 }, l)
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(l, 1.1, { Position = l.Position - UDim2.fromOffset(0, 70), TextTransparency = 1 })
		tween(st, 1.1, { Transparency = 1 })
		task.delay(1.15, function() l:Destroy() end)
	end

	local function banner(msg, color)
		local l = text(fx, { Text = msg, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.3, 0.43), Size = UDim2.fromScale(0.5, 0.12), Rotation = -6 })
		textStroke(l, 4)
		tween(l, 0.35, { Position = UDim2.fromScale(0.37, 0.43) }, Enum.EasingStyle.Back)
		task.delay(1.1, function()
			tween(l, 0.3, { Position = UDim2.fromScale(1.3, 0.43) })
			task.wait(0.32)
			l:Destroy()
		end)
	end

	local function pushLog(msg, color)
		local col = LOG_COLOR[color] or C.Ink
		table.insert(logLines, 1, ("<font color=\"#%s\">%s</font>"):format(col:ToHex(), esc(msg)))
		while #logLines > 7 do table.remove(logLines) end
		logLbl.Text = table.concat(logLines, "\n")
	end

	-- ───── คำอธิบายการ์ด ─────
	local function describe(card)
		if not card then return HELP end
		local L = {}
		local icon = (card.Form == "Poop" and "💩") or card.Emoji or ART[card.Id] or TYPE_ICON[card.Type] or "❓"
		table.insert(L, ("<b>%s %s</b>"):format(icon, esc(card.Name or "?")))
		if card.Type == "Character" then
			local e = ELEM[card.Element]
			table.insert(L, ("ตัวละคร • %s • ⚡%d (ลงเกต ⚡%d)"):format(e and (e.icon .. e.name) or "-", card.Cost or 0, Rules.GateCost(card)))
			table.insert(L, ("⚔️ ATK %d    ❤️ HP %d/%d"):format(card.ATK or 0, card.HP or 0, card.MaxHP or card.HP or 0))
			for _, kw in card.Keywords or {} do
				local k = KW[kw]
				if k then table.insert(L, ("%s <b>%s</b>: %s"):format(k[1], k[2], k[3])) end
			end
			if card.WeaponName then
				table.insert(L, ("🗡️ ถือ %s (+%d, เหลือ %d ครั้ง)%s"):format(esc(card.WeaponName), card.WeaponBonus or 0,
					card.WeaponDur or 0, card.WeaponFreeze and " ❄️" or ""))
			end
			if card.Frozen then table.insert(L, "❄️ โดนแช่แข็ง: ตีและสวนกลับไม่ได้") end
			if card.Slime then table.insert(L, "🟢 เหยียบสไลม์: ตีครั้งหน้ามีโอกาสพลาดครึ่งต่อครึ่ง") end
			if card.GateResult and GATE[card.GateResult] then
				local g = GATE[card.GateResult]
				table.insert(L, ("🎲 ผลเกต: %s (%s)"):format(g.title, g.sub))
			end
		elseif card.Type == "Spell" then
			table.insert(L, ("เวท • ⚡%d"):format(card.Cost or 0))
		elseif card.Type == "Weapon" then
			table.insert(L, ("อาวุธ • ⚡%d • แตะตัวเรา=สวม / แตะศัตรู=ปา"):format(card.Cost or 0))
		elseif card.Type == "Leader" then
			table.insert(L, ("ผู้นำ • ❤️ %d"):format(Config.LEADER_HP))
		end
		if card.Desc then table.insert(L, "📜 " .. esc(card.Desc)) end
		if card.Flavor then table.insert(L, ("<i>“%s”</i>"):format(esc(card.Flavor))) end
		return table.concat(L, "\n")
	end

	local function inspect(card)
		inspectedUid = card and card.Uid or nil
		inspectedCard = card
	end

	local function clearSel()
		sel = nil
		render(false)
	end
	bgBtn.Activated:Connect(function()
		inspect(nil)
		clearSel()
	end)

	-- ───── การ์ด ─────
	local function bubble(f, label, color, pos, anchor)
		local b = new("Frame", { BackgroundColor3 = color, Position = pos, AnchorPoint = anchor,
			Size = UDim2.fromScale(0.34, 0.34), ZIndex = 3 }, f)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
		corner(b); outline(b, 3)
		local l = text(b, { Text = label, Font = FONT_NUM, TextColor3 = C.White, ZIndex = 4,
			Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.8, 0.8) })
		textStroke(l, 2)
		return b, l
	end

	local function buildCard(parent, card, o)
		o = o or {}
		local isChar = card.Type == "Character"
		local poop = card.Form == "Poop"
		local elem = isChar and ELEM[card.Element] or nil
		local head = (elem and elem.color) or TYPE_COLOR[card.Type] or C.Gray

		local f = new("TextButton", { Name = "Card", AutoButtonColor = false, Text = "",
			BackgroundColor3 = poop and rgb(214, 170, 120) or C.Paper,
			Size = UDim2.fromScale(1, 1), LayoutOrder = o.order or 0 }, parent)
		new("UIAspectRatioConstraint", { AspectRatio = CARD_RATIO }, f)
		corner(f, 10)
		local st = outline(f, Rules.HasKeyword(card, "Taunt") and 5 or 3)
		local sc = new("UIScale", { Scale = 1 }, f)

		local h = new("Frame", { BackgroundColor3 = head, Size = UDim2.fromScale(1, 0.2) }, f)
		corner(h, 10)
		maxText(text(h, { Text = card.Name or "?", Font = FONT_BODY,
			Position = UDim2.fromScale(o.showCost and 0.3 or 0.06, 0.12),
			Size = UDim2.fromScale(o.showCost and 0.66 or 0.88, 0.76) }), 16)

		local art
		if card.Art and not poop then
			art = new("ImageLabel", { BackgroundTransparency = 1, Image = card.Art, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.86, 0.4) }, f)
		else
			art = text(f, { Text = poop and "💩" or ART[card.Id] or TYPE_ICON[card.Type] or "❓",
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.86, 0.4) })
		end
		if card.GateResult == "Golden" then
			st.Color = C.Gold; st.Thickness = 5
			f.BackgroundColor3 = rgb(255, 240, 150)
		end

		if isChar then
			local icons = {}
			for _, kw in card.Keywords or {} do
				if KW[kw] then table.insert(icons, KW[kw][1]) end
			end
			maxText(text(f, { Text = (elem and (elem.icon .. elem.name) or "") .. " " .. table.concat(icons, ""),
				Font = FONT_BODY, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.92, 0.11) }), 14)
			bubble(f, tostring(card.ATK or 0), C.Red, UDim2.fromScale(0, 1), Vector2.new(0.25, 0.75))
			local _, hpL = bubble(f, tostring(card.HP or 0), C.Green, UDim2.fromScale(1, 1), Vector2.new(0.75, 0.75))
			if (card.HP or 0) < (card.MaxHP or card.HP or 0) then hpL.TextColor3 = C.Yellow end
		else
			maxText(text(f, { Text = card.Desc or "", Font = FONT_BODY, TextWrapped = true,
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.67), Size = UDim2.fromScale(0.9, 0.3) }), 13)
		end
		if o.showCost then
			bubble(f, tostring(card.Cost or 0), C.Blue, UDim2.fromScale(0, 0), Vector2.new(0.3, 0.3))
		end

		local chips = {}
		if card.WeaponName then table.insert(chips, ("🗡️%d"):format(card.WeaponDur or 0)) end
		if card.Frozen then table.insert(chips, "❄️") end
		if card.Slime then table.insert(chips, "🟢") end
		if card.GateResult and GATE[card.GateResult] then table.insert(chips, GATE[card.GateResult].icon) end
		if #chips > 0 then
			local chip = new("Frame", { BackgroundColor3 = C.White, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1.04, 0.17), Size = UDim2.fromScale(0.62, 0.13), ZIndex = 4 }, f)
			corner(chip, 8); outline(chip, 2)
			text(chip, { Text = table.concat(chips, " "), Font = FONT_NUM, ZIndex = 5 })
		end

		if card.Frozen then
			corner(new("Frame", { BackgroundColor3 = C.Blue, BackgroundTransparency = 0.65, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, f), 10)
		end
		if o.dim then
			corner(new("Frame", { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, f), 10)
		end

		if o.selected then
			st.Color = C.Yellow; st.Thickness = 6; sc.Scale = 1.08
		elseif o.target then
			local col = o.target.ally and C.Green or C.Red
			st.Color = col; st.Thickness = 6
			local tg = new("Frame", { BackgroundColor3 = col, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, o.target.sub and 0.34 or 0.24), ZIndex = 7 }, f)
			corner(tg, 10); outline(tg, 3)
			local tl = text(tg, { Text = "🎯 " .. (o.target.label or ""), Font = FONT_NUM, TextColor3 = C.White, ZIndex = 8,
				Size = UDim2.fromScale(1, o.target.sub and 0.6 or 1) })
			textStroke(tl, 2)
			if o.target.sub then
				local sl = text(tg, { Text = o.target.sub, Font = FONT_BODY, TextColor3 = C.White, ZIndex = 8,
					Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.4) })
				textStroke(sl, 2)
			end
			loopTween(f, sc, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 })
		elseif o.ready then
			st.Color = C.Lime; st.Thickness = 5
			loopTween(f, st, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 })
		elseif o.playable then
			st.Color = rgb(60, 200, 0); st.Thickness = 4
		end

		f.Activated:Connect(function() if o.onClick then o.onClick() end end)
		return { frame = f, art = art, hp = card.HP or 0 }
	end

	-- ───── ตรรกะการเลือก ─────
	local function canPlay(c)
		local s = state
		if not s or not s.isMyTurn or ended then return false end
		if c.Type == "Character" then
			local fieldOk = c.Cost <= s.myPoints and Rules.FieldFree(#s.myField, s.myGate ~= nil)
			local gateOk = Rules.GateCost(c) <= s.myPoints and s.myGate == nil and #s.myField < Config.FIELD_SLOTS
			return fieldOk or gateOk
		end
		return c.Cost <= s.myPoints
	end

	local function computeTargets()
		local t, s = {}, state
		if not s or not sel or not s.isMyTurn or ended then return t end
		if sel.kind == "attacker" then
			local a = findIn(s.myField, sel.uid)
			if not a then return t end
			local taunt = Rules.HasTaunt(s.oppField)
			for _, c in s.oppField do
				if not taunt or Rules.HasKeyword(c, "Taunt") then
					local dmg, counter = Rules.CombatPreview(a, c)
					t[c.Uid] = { label = ("-%d"):format(dmg),
						sub = c.Frozen and "❄️ สวนไม่ได้" or (counter > 0 and ("โดนสวน %d"):format(counter) or nil) }
				end
			end
			if not taunt then t.LEADER = { label = ("-%d"):format(a.ATK or 0) } end
			return t
		end
		local card = findIn(s.myHand, sel.uid)
		if not card then return t end
		if card.Type == "Character" then
			if card.Cost <= s.myPoints and Rules.FieldFree(#s.myField, s.myGate ~= nil) then t.Field = {} end
			if Rules.GateCost(card) <= s.myPoints and s.myGate == nil and #s.myField < Config.FIELD_SLOTS then t.Gate = {} end
			return t
		end
		if card.Cost > s.myPoints then return t end
		if card.Type == "Weapon" then
			local b = card.Bonus or 0
			for _, c in s.myField do t[c.Uid] = { label = ("+%d ATK"):format(b), ally = true } end
			for _, c in s.oppField do t[c.Uid] = { label = ("-%d"):format(b) } end
			t.LEADER = { label = ("-%d"):format(b) }
			return t
		end
		local tt = Rules.TargetType(card)
		local kind = card.Effect and card.Effect.Kind
		local v = card.Effect and card.Effect.Value or 0
		if tt == "None" then
			t.NOW = {}
		elseif tt == "EnemyChar" then
			for _, c in s.oppField do t[c.Uid] = { label = kind == "Damage" and ("-%d"):format(v) or "" } end
		elseif tt == "AllyChar" then
			for _, c in s.myField do t[c.Uid] = { label = ("+%d"):format(v), ally = true } end
		elseif tt == "Ally" then
			for _, c in s.myField do t[c.Uid] = { label = ("+%d"):format(v), ally = true } end
			t.MY_LEADER = { label = ("+%d"):format(v), ally = true }
		end
		return t
	end

	act = function(key)
		if not sel or ended then return end
		local cur = sel
		sel = nil
		render(false)
		local ok, err
		if cur.kind == "attacker" then
			ok, err = Net.invoke("Attack", cur.uid, key)
		else
			ok, err = Net.invoke("PlayCard", cur.uid, key ~= "NOW" and key or nil)
		end
		if not ok then toast(errMsg(err), C.Red) end
	end

	local function onFieldClick(c, mine)
		if targets[c.Uid] then act(c.Uid) return end
		inspect(c)
		local s = state
		if mine and s.isMyTurn and not ended then
			if c.CanAttack and (c.ATK or 0) > 0 and not c.Frozen then
				if sel and sel.kind == "attacker" and sel.uid == c.Uid then sel = nil
				else sel = { kind = "attacker", uid = c.Uid } end
			elseif c.Frozen then
				toast("❄️ ตัวนี้โดนแช่แข็งอยู่", C.Blue)
			elseif (c.ATK or 0) <= 0 then
				toast("ATK 0 ตีไม่ได้ 💩", C.Orange)
			else
				toast("😴 ตีไปแล้ว หรือเพิ่งลงสนาม (ไม่มี ⚡บุก)", C.Orange)
			end
		end
		render(false)
	end

	local function onHandClick(c)
		inspect(c)
		if state.isMyTurn and not ended then
			if sel and sel.kind == "hand" and sel.uid == c.Uid then sel = nil
			else sel = { kind = "hand", uid = c.Uid } end
		end
		render(false)
	end

	-- ───── ส่วนแสดงผล ─────
	local function setLeader(p, name, leaderId, hp, shield, extra)
		local ld = CardData[leaderId]
		p.emoji.Text = (ld and ld.Emoji) or "🙂"
		p.name.Text = name
		local frac = math.clamp(hp / Config.LEADER_HP, 0, 1)
		tween(p.bar, 0.3, { Size = UDim2.fromScale(frac, 1) })
		p.bar.BackgroundColor3 = frac > 0.5 and C.Green or (frac > 0.25 and C.Orange or C.Red)
		p.hp.Text = ("❤️ %d/%d%s"):format(hp, Config.LEADER_HP, shield > 0 and ("   🛡️%d"):format(shield) or "")
		p.sub.Text = extra
	end

	local function markLeader(p, tinfo, ally)
		if tinfo then
			p.stroke.Color = ally and C.Green or C.Red
			p.stroke.Thickness = 6
			p.tag.BackgroundColor3 = ally and C.Green or C.Red
			p.tag.Visible = true
			p.tagL.Text = "🎯 " .. (tinfo.label or "")
		else
			p.stroke.Color = C.Ink
			p.stroke.Thickness = 4
			p.tag.Visible = false
		end
	end

	local function emptySlot(row, order, mine, reserved)
		local e = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = C.White,
			BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), LayoutOrder = order }, row)
		new("UIAspectRatioConstraint", { AspectRatio = CARD_RATIO }, e)
		corner(e, 10)
		local st = outline(e, 3)
		st.Transparency = 0.5
		local t = maxText(text(e, { Text = reserved and "🔒\nจองให้เกต" or "+", Font = FONT_BODY, TextColor3 = C.Gray,
			Position = UDim2.fromScale(0.1, 0.3), Size = UDim2.fromScale(0.8, 0.4) }), 22)
		if mine and targets.Field and not reserved then
			st.Color = C.Lime; st.Thickness = 6; st.Transparency = 0
			e.BackgroundTransparency = 0.2
			t.Text = "🃏\nลงที่นี่"; t.TextColor3 = C.Ink
			e.Activated:Connect(function() act("Field") end)
		else
			e.Activated:Connect(clearSel)
		end
	end

	local function gateBox(row, mine)
		local s = state
		local g = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = rgb(70, 30, 120),
			Size = UDim2.fromScale(1, 1), LayoutOrder = 10 }, row)
		new("UIAspectRatioConstraint", { AspectRatio = CARD_RATIO }, g)
		corner(g, 12)
		local st = outline(g, 4)
		local title = text(g, { Text = "🎲 เกต", Position = UDim2.fromScale(0, 0.02), Size = UDim2.fromScale(1, 0.15), TextColor3 = C.Yellow })
		textStroke(title, 2)
		local holder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.08, 0.19), Size = UDim2.fromScale(0.84, 0.78) }, g)
		if mine and s.myGate then
			local gc = s.myGate
			local v = buildCard(holder, gc, { onClick = function()
				if targets.Gate then act("Gate") else inspect(gc); render(false) end
			end })
			local wait = text(v.frame, { Text = "⏳ เทิร์นหน้าสุ่ม!", Font = FONT_BODY, TextColor3 = C.Yellow, ZIndex = 9,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.18) })
			textStroke(wait, 2)
		elseif not mine and s.oppGateFilled then
			text(holder, { Text = "❓" })
		else
			maxText(text(holder, { Text = mine and "ว่าง\n(ถูกลง 1 แต้ม)" or "ว่าง", Font = FONT_BODY, TextColor3 = C.White }), 18)
		end
		if mine and targets.Gate then
			st.Color = C.Lime; st.Thickness = 6
			loopTween(g, st, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.5 })
			g.Activated:Connect(function() act("Gate") end)
		else
			g.Activated:Connect(clearSel)
		end
	end

	local function renderRow(row, list, mine)
		clear(row)
		local s = state
		local gateFilled = (mine and s.myGate ~= nil) or (not mine and s.oppGateFilled == true)
		for i = 1, Config.FIELD_SLOTS do
			local c = list[i]
			if c then
				local ready = mine and s.isMyTurn and not ended and c.CanAttack and (c.ATK or 0) > 0 and not c.Frozen
				fieldViews[c.Uid] = buildCard(row, c, {
					order = i, target = targets[c.Uid], ready = ready,
					selected = sel ~= nil and sel.kind == "attacker" and sel.uid == c.Uid,
					onClick = function() onFieldClick(c, mine) end,
				})
			else
				emptySlot(row, i, mine, gateFilled and i == Config.FIELD_SLOTS)
			end
		end
		new("Frame", { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.6, Size = UDim2.new(0, 4, 0.8, 0), LayoutOrder = 5 }, row)
		gateBox(row, mine)
	end

	local function renderHand()
		clear(hand)
		local s = state
		for i, c in s.myHand do
			local can = canPlay(c)
			buildCard(hand, c, {
				order = i, showCost = true,
				dim = s.isMyTurn and not ended and not can,
				playable = s.isMyTurn and can,
				selected = sel ~= nil and sel.kind == "hand" and sel.uid == c.Uid,
				onClick = function() onHandClick(c) end,
			})
		end
		if #s.myHand == 0 then
			maxText(text(hand, { Text = "(มือว่างเปล่า 🫥)", Font = FONT_BODY, TextColor3 = C.Gray, Size = UDim2.fromScale(0.5, 0.4) }), 24)
		end
	end

	local function renderActionBar()
		clear(actionBar)
		local s = state
		if not sel or not s.isMyTurn or ended then actionBar.Visible = false return end
		actionBar.Visible = true
		local items = {}
		if sel.kind == "attacker" then
			table.insert(items, { hint = Rules.HasTaunt(s.oppField) and "🎯 ต้องตีตัว 🛡️ยั่ว ก่อน!" or "🎯 แตะศัตรูหรือผู้นำเพื่อตี" })
		else
			local c = findIn(s.myHand, sel.uid)
			if c and c.Type == "Character" then
				if targets.Field then
					table.insert(items, { btn = ("🃏 ลงสนาม ⚡%d"):format(c.Cost), color = C.Lime, fn = function() act("Field") end })
				end
				if targets.Gate then
					table.insert(items, { btn = ("🎲 ลงเกต ⚡%d"):format(Rules.GateCost(c)), color = C.Pink, fn = function() act("Gate") end })
				end
				if not targets.Field and not targets.Gate then
					local reason = (Rules.GateCost(c) > s.myPoints) and ("แต้มไม่พอ (ต้องใช้ ⚡%d)"):format(Rules.GateCost(c))
						or "สนามเต็ม (ช่องสุดท้ายจองให้เกต)"
					table.insert(items, { hint = reason })
				end
			elseif c then
				if c.Cost > s.myPoints then
					table.insert(items, { hint = ("แต้มไม่พอ (ต้องใช้ ⚡%d)"):format(c.Cost) })
				elseif targets.NOW then
					table.insert(items, { btn = ("✨ ใช้เลย ⚡%d"):format(c.Cost), color = C.Yellow, fn = function() act("NOW") end })
				elseif next(targets) == nil then
					table.insert(items, { hint = "ไม่มีเป้าหมายให้ใช้ตอนนี้" })
				elseif c.Type == "Weapon" then
					table.insert(items, { hint = "🗡️ แตะตัวเรา=สวม / แตะศัตรู=ปา" })
				else
					table.insert(items, { hint = "🎯 แตะเป้าหมายที่เรืองแสง" })
				end
			end
		end
		table.insert(items, { btn = "✖", color = C.Gray, small = true, fn = clearSel })
		local n = #items
		local small = 0.12
		local rest = (1 - small - 0.02 * (n - 1)) / math.max(1, n - 1)
		for i, it in items do
			local w = it.small and small or rest
			if it.hint then
				local hf = new("Frame", { BackgroundColor3 = C.Paper, Size = UDim2.fromScale(w, 1), LayoutOrder = i }, actionBar)
				corner(hf, 12); outline(hf, 3)
				maxText(text(hf, { Text = it.hint, Font = FONT_BODY, Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.94, 0.8) }), 20)
			else
				local b = chunkyButton(actionBar, it.btn, it.color, it.fn)
				b.Size = UDim2.fromScale(w, 1)
				b.LayoutOrder = i
			end
		end
	end

	local function renderStatus()
		local s = state
		setLeader(oppL, s.oppLeader or "ศัตรู", s.oppLeaderId, s.oppHP or 0, s.oppShield or 0,
			("🂠 มือ %d • 📚 %d • ⚰️ %d"):format(s.oppHandCount or 0, s.oppDeck or 0, s.oppGrave or 0))
		setLeader(myL, s.myLeader or "คุณ", s.myLeaderId, s.myHP or 0, s.myShield or 0,
			("📚 %d • ⚰️ %d"):format(s.myDeck or 0, s.myGrave or 0))
		markLeader(oppL, targets.LEADER, false)
		markLeader(myL, targets.MY_LEADER, true)

		oppStatsLbl.Text = ("%s\n%s"):format(
			(s.oppBank or 0) > 0 and ("💰 ศัตรูดองไว้ %d แต้ม!"):format(s.oppBank) or "💰 ศัตรูไม่ได้ดอง",
			s.oppGateFilled and "🎲 มีการ์ดในเกต! ระวัง" or "🎲 เกตศัตรูว่าง")

		turnLbl.Text = ended and "จบเกม" or (s.isMyTurn and "🔥 ตาคุณ!" or "⏳ ตาศัตรู")
		timerBox.BackgroundColor3 = s.isMyTurn and C.Yellow or C.Gray

		local bombs = {}
		for _, b in s.bombs or {} do table.insert(bombs, ("💣%d"):format(b)) end
		midLbl.Text = ("เทิร์น %d   |   🧘สติ▶😈เบียว▶😵มึน▶🧘  🌀กาว▶ทุกธาตุ%s"):format(
			s.turn or 0, #bombs > 0 and ("   |   ระเบิดอีก: " .. table.concat(bombs, " ")) or "")

		ptsLbl.Text = ("⚡ %d"):format(s.myPoints or 0)
		local acted = s.myActed
		if acted == nil then acted = s.mySpent end
		ptsSub.Text = acted and "จบเทิร์นแล้วแต้มที่เหลือหาย"
			or ("ข้ามตอนนี้ = ดองไว้ (สูงสุด %d)"):format(Config.MAX_BANKED_POINTS)
		if ended then
			endBtn.Text, endBtn.BackgroundColor3 = "จบเกม", C.Gray
		elseif not s.isMyTurn then
			endBtn.Text, endBtn.BackgroundColor3 = "⏳ รอศัตรู...", C.Gray
		elseif endPending then
			endBtn.Text, endBtn.BackgroundColor3 = "...", C.Gray
		elseif not acted then
			endBtn.Text, endBtn.BackgroundColor3 = "💰 ข้าม (ดองพอยต์)", C.Pink
		else
			endBtn.Text, endBtn.BackgroundColor3 = "✅ จบเทิร์น", C.Lime
		end
	end

	local function renderInfo()
		local s = state
		local card = nil
		if inspectedUid then
			card = findIn(s.myHand, inspectedUid) or findIn(s.myField, inspectedUid) or findIn(s.oppField, inspectedUid)
			if not card and s.myGate and s.myGate.Uid == inspectedUid then card = s.myGate end
		end
		infoLbl.Text = describe(card or inspectedCard)
	end

	local function snapshot()
		local snap = {}
		for uid, v in fieldViews do
			if v.frame and v.frame.Parent then
				snap[uid] = { pos = v.frame.AbsolutePosition, size = v.frame.AbsoluteSize, hp = v.hp }
			end
		end
		return snap
	end

	local function playDiffFx(prev, prevState)
		RunService.RenderStepped:Wait()
		if not state then return end
		for uid, old in prev do
			local v = fieldViews[uid]
			if v and v.frame.Parent then
				local d = v.hp - old.hp
				if d < 0 then
					popAt(v.frame.AbsolutePosition, v.frame.AbsoluteSize, tostring(d), C.Red, true)
					wobble(v.frame)
					squash(v.art)
				elseif d > 0 then
					popAt(v.frame.AbsolutePosition, v.frame.AbsoluteSize, "+" .. d, C.Green, false)
				end
			elseif not v then
				popAt(old.pos, old.size, DEATH[math.random(#DEATH)], C.Purple, true)
			end
		end
		if prevState then
			local function leaderFx(p, before, after)
				if not before or not after or before == after then return end
				local d = after - before
				popAt(p.btn.AbsolutePosition, p.btn.AbsoluteSize, (d > 0 and "+" or "") .. d, d > 0 and C.Green or C.Red, true)
				if d < 0 then wobble(p.btn) end
			end
			leaderFx(myL, prevState.myHP, state.myHP)
			leaderFx(oppL, prevState.oppHP, state.oppHP)
		end
	end

	render = function(isNew, prevState)
		local s = state
		if not s then return end
		local prev = isNew and snapshot() or nil
		if sel then
			local list = sel.kind == "attacker" and s.myField or s.myHand
			if not s.isMyTurn or ended or not findIn(list, sel.uid) then sel = nil end
		end
		targets = computeTargets()
		fieldViews = {}
		renderRow(oppRow, s.oppField or {}, false)
		renderRow(myRow, s.myField or {}, true)
		renderHand()
		renderStatus()
		renderActionBar()
		renderInfo()
		if prev then task.spawn(playDiffFx, prev, prevState) end
	end

	-- ───── ป็อปอัปเกต / จบเกม ─────
	local function gatePopup(mine, card, outcomeId)
		local res = GATE[outcomeId] or GATE.Normal
		local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.37, 0.43),
			Size = UDim2.fromScale(0.42, 0.3), BackgroundColor3 = C.Purple }, fx)
		corner(box, 20); outline(box, 5)
		local sc = new("UIScale", { Scale = 0.2 }, box)
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local title = text(box, { Text = mine and "🎲 เกตของคุณกำลังสุ่ม!" or "🎲 เกตศัตรูกำลังสุ่ม!", TextColor3 = C.White,
			Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.2) })
		textStroke(title, 2)
		local roll = text(box, { TextColor3 = C.Yellow, Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.9, 0.4) })
		textStroke(roll, 3)
		local sub = text(box, { Text = card and card.Name or "?", Font = FONT_BODY, TextColor3 = C.White,
			Position = UDim2.fromScale(0.05, 0.74), Size = UDim2.fromScale(0.9, 0.2) })
		textStroke(sub, 2)
		for i = 1, 16 do
			roll.Text = GATE[GATE_ORDER[(i % #GATE_ORDER) + 1]].title
			task.wait(0.05 + i * 0.008)
		end
		roll.Text = res.title
		roll.TextColor3 = res.color
		sub.Text = ("%s → %s"):format(card and card.Name or "?", res.sub)
		wobble(box)
		task.wait(1.8)
		tween(sc, 0.2, { Scale = 0 })
		task.wait(0.22)
		box:Destroy()
	end

	local function exitMatch()
		Perf.SetMatch(false)
		closedId = currentId
		root.Visible = false
		state, sel = nil, nil
		clear(fx)
		if cb.OnExit then task.spawn(cb.OnExit) end
	end

	local function endPopup(won, reason, reward)
		local dim = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1) }, fx)
		local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.42, 0.45), BackgroundColor3 = won and C.Yellow or rgb(200, 196, 220) }, dim)
		corner(box, 24); outline(box, 6)
		local sc = new("UIScale", { Scale = 0.2 }, box)
		tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		local t = text(box, { Text = won and "🏆 ชนะแล้ววว!" or "🤡 แพ้ซะงั้น", TextColor3 = won and C.White or C.Ink,
			Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.3) })
		if won then textStroke(t, 4) end
		maxText(text(box, { Text = REASON[reason] or tostring(reason), Font = FONT_BODY,
			Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.15) }), 26)
		maxText(text(box, { Text = ("+%d 💎"):format(reward or 0), Font = FONT_NUM, TextColor3 = C.Purple,
			Position = UDim2.fromScale(0.05, 0.53), Size = UDim2.fromScale(0.9, 0.17) }), 40)
		local b = chunkyButton(box, "🏠 กลับล็อบบี้", C.Lime, function() exitMatch() end)
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.fromScale(0.5, 0.75)
		b.Size = UDim2.fromScale(0.6, 0.18)
		wobble(box)
	end

	-- ───── ปุ่มควบคุม ─────
	oppL.btn.Activated:Connect(function()
		if targets.LEADER then act("LEADER") return end
		if state then inspect(CardData[state.oppLeaderId]); render(false) end
	end)
	myL.btn.Activated:Connect(function()
		if targets.MY_LEADER then act("MY_LEADER") return end
		if state then inspect(CardData[state.myLeaderId]); render(false) end
	end)
	endBtn.Activated:Connect(function()
		if not state or not state.isMyTurn or ended or endPending then return end
		endPending = true
		sel = nil
		Net.fire("EndTurn")
		render(false)
		task.delay(2, function() -- เซิร์ฟเวอร์ไม่ตอบ (เช่นกดเร็วเกิน) -> ปลดล็อกปุ่ม
			if endPending then
				endPending = false
				if state then render(false) end
			end
		end)
	end)
	local surrArmed = false
	surrBtn.Activated:Connect(function()
		if not state or ended then return end
		if not surrArmed then
			surrArmed = true
			surrBtn.Text = "แน่ใจนะ? กดอีกที"
			task.delay(3, function() surrArmed = false; surrBtn.Text = "🏳️ ยอมแพ้" end)
			return
		end
		Net.fire("Surrender")
	end)

	RunService.Heartbeat:Connect(function()
		if not state or not root.Visible then return end
		local left = math.max(0, math.floor((state.turnEndsAt or 0) - workspace:GetServerTimeNow()))
		timerLbl.Text = ("⏱ %d:%02d"):format(left // 60, left % 60)
		timerLbl.TextColor3 = (left <= 15 and state.isMyTurn) and C.Red or C.Ink
	end)

	-- ───── เน็ตเวิร์ก ─────
	Net.on("StateUpdate", function(s)
		if typeof(s) ~= "table" or s.matchId == closedId then return end
		if s.matchId ~= currentId then
			currentId = s.matchId
			ended, endPending = false, false
			sel, state = nil, nil
			inspect(nil)
			logLines = {}
			logLbl.Text = ""
			clear(fx)
			root.Visible = true
			Perf.SetMatch(true)
			if cb.OnStart then task.spawn(cb.OnStart) end
		end
		local prevState = state
		state = s
		endPending = false
		render(true, prevState)
		if not ended and (prevState == nil or prevState.isMyTurn ~= s.isMyTurn) then
			banner(s.isMyTurn and "🔥 ตาคุณแล้ว!" or "😈 ตาศัตรู...", s.isMyTurn and C.Yellow or C.Pink)
		end
	end)

	Net.on("Notify", function(msg, color)
		if root.Visible and typeof(msg) == "string" then pushLog(msg, color) end
	end)

	Net.on("GateRolled", function(mine, card, outcomeId)
		if root.Visible then task.spawn(gatePopup, mine, card, outcomeId) end
	end)

	Net.on("MatchEnded", function(won, reason, id, reward)
		if id ~= currentId then return end
		ended = true
		Perf.SetMatch(false)
		sel = nil
		if state then render(false) end
		task.delay(0.8, function() endPopup(won, reason, reward) end)
	end)
end

return MatchUI