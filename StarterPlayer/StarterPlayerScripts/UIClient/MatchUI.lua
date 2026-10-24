-- ไฟล์ลูกของ UIClient: MatchUI (ModuleScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIFolder = Shared:WaitForChild("UI")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(UIFolder:WaitForChild("Theme"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local CardView = require(UIFolder:WaitForChild("CardView"))
local GateRoller = require(script.Parent:WaitForChild("GateRoller"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local CENTER = Vector2.new(0.5, 0.5)

local ERR = {
	NOT_YOUR_TURN = "ยังไม่ถึงตาคุณ ใจเย็นๆ",
	NOT_ENOUGH_POINTS = "พอยต์ไม่พอ! ลองดองไว้ก่อน",
	FIELD_FULL = "สนามเต็มแล้ว!",
	GATE_OCCUPIED = "ช่องเกตมีการ์ดอยู่แล้ว!",
	CANNOT_ATTACK = "ตัวนี้ยังตีไม่ได้ (หลับอยู่ 💤)",
	TAUNT = "ต้องตีตัวบังก่อน! 🛡️",
	INVALID_CARD = "ใช้การ์ดใบนี้ไม่ได้",
	INVALID_TARGET = "ตีเป้าหมายนี้ไม่ได้",
}
local REASON = {
	LEADER_DOWN = "ผู้นำล้มคว่ำ 💥",
	FATIGUE = "การ์ดหมดกองจนหมดแรง 😵",
	AFK_LIGHTNING = "AFK จนโดนฟ้าผ่า ⚡",
	LEFT = "อีกฝั่งหนีออกจากเกม 🏃",
}
local CARD_SIZE = {
	hand = UDim2.fromScale(0.19, 1),
	myField = UDim2.fromScale(0.3, 0.95),
	oppField = UDim2.fromScale(0.3, 0.95),
	myGate = UDim2.fromScale(0.95, 0.8),
}

local MatchUI = {}
local gui, overlay, callbacks
local ui = {}
local views = { hand = {}, myField = {}, oppField = {}, myGate = {} }
local state, selected, endedMatchId
local busy = false

local function hasKeyword(card, kw)
	return card.Keywords ~= nil and table.find(card.Keywords, kw) ~= nil
end

-- ─────────── ส่วนประกอบหน้าจอ ───────────
local function zone(name, position, size, opts)
	opts = opts or {}
	return UIKit.new("Frame", {
		Name = name, Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = opts.Transparency or 0.82, Parent = gui,
	}, {
		UIKit.corner(UDim.new(0.1, 0)),
		UIKit.new("UIListLayout", {
			FillDirection = opts.Vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = opts.Padding or UDim.new(0.02, 0),
		}),
	})
end

local function gateZone(position)
	local z = zone("Gate", position, UDim2.fromScale(0.11, 0.22), { Vertical = true })
	local lbl = UIKit.label({ Text = "🎲 ช่องเกต", Size = UDim2.fromScale(1, 0.15), Parent = z })
	lbl.LayoutOrder = 0
	return z
end

local function pileLabel(position)
	return UIKit.label({ Font = Theme.FontBody, Size = UDim2.fromScale(0.15, 0.05), Position = position, AnchorPoint = CENTER, Parent = gui })
end

local function leaderBar(position, anchor, isOpp)
	local props = {
		Position = position, AnchorPoint = anchor, Size = UDim2.fromScale(0.2, 0.09),
		BackgroundColor3 = Theme.Color.Panel, Parent = gui,
	}
	if isOpp then props.Text = ""; props.AutoButtonColor = false end
	local stroke = UIKit.stroke(nil, 4)
	local root = UIKit.new(isOpp and "TextButton" or "Frame", props, { UIKit.corner(), stroke })
	local name = UIKit.label({
		Color = Theme.Color.Outline, StrokeThickness = 0, AlignX = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.9, 0.4), Position = UDim2.fromScale(0.05, 0.06), Parent = root,
	})
	local track = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.9, 0.38), Position = UDim2.fromScale(0.05, 0.52),
		BackgroundColor3 = Color3.fromRGB(60, 40, 40), Parent = root,
	}, { UIKit.corner(UDim.new(0.5, 0)) })
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Green, Parent = track }, { UIKit.corner(UDim.new(0.5, 0)) })
	local hp = UIKit.label({ Parent = track })
	return { Root = root, Stroke = stroke, Name = name, Fill = fill, HP = hp }
end

local function setLeader(bar, name, hp)
	local max = Config.LEADER_HP
	bar.Name.Text = name or "ผู้นำ"
	bar.HP.Text = ("❤ %d/%d"):format(math.max(hp, 0), max)
	bar.Fill.BackgroundColor3 = hp <= 10 and Theme.Color.Red or Theme.Color.Green
	UIKit.tween(bar.Fill, 0.4, { Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1) })
	if bar.Value and hp < bar.Value then
		UIKit.shake(bar.Root)
		UIKit.popup(bar.Root, "-" .. (bar.Value - hp))
		UIKit.sfx("Hit")
	end
	bar.Value = hp
end

local function banner(text, color)
	local b = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.6, 0.12), Position = UDim2.fromScale(-0.5, 0.45), AnchorPoint = CENTER,
		BackgroundColor3 = color or Theme.Color.Yellow, Rotation = -4, Parent = overlay,
	}, { UIKit.corner(), UIKit.stroke(nil, 4) })
	UIKit.label({ Text = text, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = b, MaxTextSize = 60 })
	UIKit.tween(b, 0.35, { Position = UDim2.fromScale(0.5, 0.45) }, Enum.EasingStyle.Back)
	task.delay(1.2, function()
		UIKit.tween(b, 0.3, { Position = UDim2.fromScale(1.5, 0.45) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.35)
		b:Destroy()
	end)
end

-- ─────────── การโต้ตอบ ───────────
local function call(remote, ...)
	if busy then return end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local ok, success, err = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		busy = false
		if not ok then
			UIKit.toast("เน็ตกาว ลองใหม่อีกที 📶", Theme.Color.Red)
		elseif not success then
			UIKit.toast(ERR[err] or "ทำแบบนี้ไม่ได้นะ", Theme.Color.Red)
		end
	end)
end

local function clearSelection()
	if selected and selected.view.Frame.Parent then
		selected.view:SetSelected(false)
	end
	selected = nil
	for _, v in pairs(views.oppField) do v:SetTarget(false) end
	ui.oppLeader.Stroke.Color = Theme.Color.Outline
	for _, child in ipairs(ui.actions:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	ui.actions.Visible = false
end

local function actionButton(text, color, width, disabled, onClick)
	local btn = UIKit.button({ Text = text, Color = color, Size = UDim2.fromScale(width, 1), Parent = ui.actions, OnClick = onClick })
	btn.LayoutOrder = #ui.actions:GetChildren()
	if disabled then UIKit.setDisabled(btn, true) end
end

local function playCard(uid, target)
	for i, c in ipairs(state.myHand) do
		if c.Uid == uid then
			UIKit.sfx("PlayCard")
			clearSelection()
			call(Remotes.PlayCard, i, target)
			return
		end
	end
end

local function doAttack(targetUid)
	if not selected or selected.zone ~= "myField" then return end
	local attacker = selected.view
	clearSelection()
	attacker:Lunge()
	UIKit.sfx("Swing")
	call(Remotes.Attack, attacker.Card.Uid, targetUid)
end

local function selectHand(view)
	clearSelection()
	local card = view.Card
	local myTurn = state.isMyTurn
	selected = { zone = "hand", view = view }
	view:SetSelected(true)
	if card.Type == "Character" then
		local gateCost = math.max(0, card.Cost - Config.GATE_DISCOUNT)
		actionButton(("ลงสนาม ⚡%d"):format(card.Cost), Theme.Color.Yellow, 0.32,
			not myTurn or #state.myField >= Config.FIELD_SLOTS or card.Cost > state.myPoints,
			function() playCard(card.Uid, "Field") end)
		actionButton(("ลงเกต 🎲 ⚡%d"):format(gateCost), Theme.Color.Pink, 0.32,
			not myTurn or state.myGate ~= nil or gateCost > state.myPoints,
			function() playCard(card.Uid, "Gate") end)
	else
		actionButton(("ใช้การ์ด ⚡%d"):format(card.Cost), Theme.Color.Blue, 0.4,
			not myTurn or card.Cost > state.myPoints,
			function() playCard(card.Uid, "Field") end)
	end
	actionButton("ยกเลิก", Theme.Color.Gray, 0.2, false, clearSelection)
	ui.actions.Visible = true
end

local function selectAttacker(view)
	clearSelection()
	selected = { zone = "myField", view = view }
	view:SetSelected(true)
	local tauntUp = false
	for _, c in ipairs(state.oppField) do
		if hasKeyword(c, "Taunt") then tauntUp = true break end
	end
	for _, v in pairs(views.oppField) do
		v:SetTarget(not tauntUp or hasKeyword(v.Card, "Taunt"))
	end
	if not tauntUp then ui.oppLeader.Stroke.Color = Theme.Color.Red end
	local hint = UIKit.label({ Text = tauntUp and "มีตัวบัง! ต้องตีมันก่อน 🛡️" or "เลือกเป้าหมายเลย 👊", Size = UDim2.fromScale(0.5, 1), Parent = ui.actions })
	hint.LayoutOrder = 0
	actionButton("ยกเลิก", Theme.Color.Gray, 0.2, false, clearSelection)
	ui.actions.Visible = true
end

local function onCardClick(zoneName, view)
	if not state or busy then return end
	if zoneName == "hand" then
		if selected and selected.view == view then clearSelection() else selectHand(view) end
	elseif zoneName == "myField" then
		if selected and selected.view == view then clearSelection() return end
		if not state.isMyTurn then UIKit.toast(ERR.NOT_YOUR_TURN) return end
		if not view.Card.CanAttack or (view.Card.ATK or 0) <= 0 then
			UIKit.shake(view.Body)
			UIKit.toast(ERR.CANNOT_ATTACK)
			return
		end
		selectAttacker(view)
	elseif zoneName == "oppField" then
		doAttack(view.Card.Uid)
	end
end

-- ซูมดูการ์ด (คลิกขวาบน PC / กดค้างบนมือถือ)
local function inspect(card)
	local dim = UIKit.new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4,
		Text = "", AutoButtonColor = false, Parent = overlay,
	})
	local close = function() dim:Destroy() end
	dim.Activated:Connect(close)
	local big = CardView.new(card, { Size = UDim2.fromScale(0.5, 0.7), OnClick = close })
	big.Frame.AnchorPoint = CENTER
	big.Frame.Position = UDim2.fromScale(0.5, 0.45)
	big.Frame.Parent = dim
	big:PopIn()
	UIKit.label({
		Text = card.Flavor or "", Font = Theme.FontBody, Size = UDim2.fromScale(0.7, 0.07),
		Position = UDim2.fromScale(0.5, 0.88), AnchorPoint = CENTER, Parent = dim,
	})
end

local function endTurn()
	if not state or not state.isMyTurn or busy then return end
	clearSelection()
	UIKit.setDisabled(ui.endBtn, true)
	Remotes.EndTurn:FireServer()
end

local lastPray = 0
local function pray()
	if os.clock() - lastPray < 5 then UIKit.toast("พระท่านพักอยู่ รออีกแป๊บ 🙏") return end
	lastPray = os.clock()
	UIKit.sfx("Pray")
	local beam = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 240, 150), BackgroundTransparency = 1, Parent = overlay,
	}, {
		UIKit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) }),
		}),
	})
	UIKit.label({ Text = "🙏 สาธุ~ ขอให้เกตออกทอง", Size = UDim2.fromScale(0.8, 0.12), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = CENTER, Parent = beam })
	UIKit.tween(beam, 0.4, { BackgroundTransparency = 0.3 })
	task.delay(2, function()
		beam:Destroy()
	end)
end

-- ─────────── วาดสถานะเกม ───────────
local function sync(container, cards, map, zoneName)
	local alive = {}
	for i, card in ipairs(cards) do
		alive[card.Uid] = true
		local view = map[card.Uid]
		if view then
			local oldHP = view.Card.HP
			view:Update(card)
			if oldHP and card.HP and card.HP < oldHP then view:Hit(oldHP - card.HP) end
		else
			view = CardView.new(card, {
				Size = CARD_SIZE[zoneName],
				ShowSleep = zoneName == "myField" or zoneName == "oppField",
				OnClick = function(v) onCardClick(zoneName, v) end,
				OnInspect = function(v) inspect(v.Card) end,
			})
			view.Frame.Parent = container
			view:PopIn()
			map[card.Uid] = view
		end
		view.Frame.LayoutOrder = i
	end
	for uid, view in pairs(map) do
		if not alive[uid] then
			map[uid] = nil
			if zoneName == "hand" or zoneName == "myGate" then view:Remove() else view:Die() end
		end
	end
end

local function fanHand()
	local list = {}
	for _, v in pairs(views.hand) do table.insert(list, v) end
	table.sort(list, function(a, b) return a.Frame.LayoutOrder < b.Frame.LayoutOrder end)
	for i, v in ipairs(list) do
		v.Frame.Rotation = (i - (#list + 1) / 2) * 4
	end
end

local function render(s)
	local first = state == nil
	state = s
	if first then
		gui.Enabled = true
		if callbacks.OnStart then callbacks.OnStart() end
		banner(s.isMyTurn and "เริ่มแมตช์! คุณเริ่มก่อน 🔥" or "เริ่มแมตช์! ศัตรูเริ่มก่อน 😈", Theme.Color.Pink)
	elseif s.isMyTurn ~= ui.lastTurn then
		banner(s.isMyTurn and "ตาคุณแล้ว! 🔥" or "ตาศัตรู 😈", s.isMyTurn and Theme.Color.Yellow or Theme.Color.Blue)
	end
	ui.lastTurn = s.isMyTurn

	clearSelection()
	sync(ui.oppField, s.oppField, views.oppField, "oppField")
	sync(ui.myField, s.myField, views.myField, "myField")
	sync(ui.myGate, s.myGate and { s.myGate } or {}, views.myGate, "myGate")
	sync(ui.hand, s.myHand, views.hand, "hand")
	fanHand()

	ui.oppGateBack.Visible = s.oppGateFilled == true
	for _, child in ipairs(ui.oppHand:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for i = 1, s.oppHandCount or 0 do
		local back = CardView.back(UDim2.fromScale(0.18, 1))
		back.LayoutOrder = i
		back.Parent = ui.oppHand
	end

	setLeader(ui.myLeader, s.myLeader, s.myHP)
	setLeader(ui.oppLeader, s.oppLeader, s.oppHP)
	ui.myPile.Text = ("🂠 %d   💀 %d"):format(s.myDeck or 0, s.myGrave or 0)
	ui.oppPile.Text = ("🂠 %d   💀 %d"):format(s.oppDeck or 0, s.oppGrave or 0)

	local pointsText = "⚡" .. s.myPoints
	if ui.points.Text ~= pointsText then UIKit.jelly(ui.pointsBubble, 0.3) end
	ui.points.Text = pointsText

	if s.isMyTurn then
		ui.endLabel.Text = s.mySpent and "จบเทิร์น ▶" or "ข้าม (ดองพอยต์) 💰"
		UIKit.setColor(ui.endBtn, s.mySpent and Theme.Color.Yellow or Theme.Color.Pink)
		UIKit.setDisabled(ui.endBtn, false)
	else
		ui.endLabel.Text = "รอศัตรู... ⏳"
		UIKit.setDisabled(ui.endBtn, true)
	end
end

local function reset()
	for _, map in pairs(views) do
		for uid, view in pairs(map) do
			view.Frame:Destroy()
			map[uid] = nil
		end
	end
	state, selected, ui.lastTurn = nil, nil, nil
	ui.myLeader.Value, ui.oppLeader.Value = nil, nil
	gui.Enabled = false
end

local function showResult(won, reason)
	local dim = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3, Active = true, Parent = overlay,
	})
	UIKit.sfx(won and "Win" or "Lose")
	UIKit.rain(dim, won and "🏆" or "🧂", 30)
	local title = UIKit.label({
		Text = won and "ชนะ! 🏆" or "แพ้... เกลือเต็มปาก 🧂", Color = won and Theme.Color.Yellow or Theme.Color.Gray,
		Size = UDim2.fromScale(0.8, 0.2), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = CENTER,
		Parent = dim, MaxTextSize = 120, StrokeThickness = 5,
	})
	UIKit.jelly(title, 0.5)
	UIKit.label({ Text = REASON[reason] or tostring(reason or ""), Size = UDim2.fromScale(0.6, 0.07), Position = UDim2.fromScale(0.5, 0.47), AnchorPoint = CENTER, Parent = dim })
	UIKit.button({
		Text = "กลับล็อบบี้", Color = Theme.Color.Green, Size = UDim2.fromScale(0.25, 0.1),
		Position = UDim2.fromScale(0.5, 0.65), AnchorPoint = CENTER, Parent = dim,
		OnClick = function()
			dim:Destroy()
			reset()
			if callbacks.OnExit then callbacks.OnExit() end
		end,
	})
end

local function updateTimer()
	if not state or not state.turnEndsAt or not gui.Enabled then return end
	local left = math.max(0, math.ceil(state.turnEndsAt - workspace:GetServerTimeNow()))
	ui.timerFill.Size = UDim2.fromScale(left / Config.TURN_TIME, 1)
	ui.timerFill.BackgroundColor3 = left <= 20 and Theme.Color.Red or Theme.Color.Yellow
	ui.timerText.Text = ("%s %d:%02d"):format(state.isMyTurn and "ตาคุณ" or "ตาศัตรู", left // 60, left % 60)
end

local NUM_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
}
local function onKey(input, processed)
	if processed or not state or not gui.Enabled then return end
	if input.KeyCode == Enum.KeyCode.Return then
		endTurn()
	elseif input.KeyCode == Enum.KeyCode.X then
		clearSelection()
	elseif NUM_KEYS[input.KeyCode] then
		local card = state.myHand[NUM_KEYS[input.KeyCode]]
		local view = card and views.hand[card.Uid]
		if view then selectHand(view) end
	end
end

-- ─────────── สร้างหน้าจอ ───────────
function MatchUI.Build(matchGui, overlayGui, cb)
	gui, overlay, callbacks = matchGui, overlayGui, cb or {}
	gui.Enabled = false

	UIKit.new("Frame", { Name = "TableBg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Table, Parent = gui }, {
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) }),
	})

	-- ฝั่งศัตรู
	ui.oppLeader = leaderBar(UDim2.fromScale(0.98, 0.02), Vector2.new(1, 0), true)
	ui.oppLeader.Root.Activated:Connect(function() doAttack("LEADER") end)
	ui.oppHand = zone("OppHand", UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.3, 0.1), { Transparency = 1 })
	ui.oppField = zone("OppField", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(0.62, 0.22))
	ui.oppGate = gateZone(UDim2.fromScale(0.89, 0.13))
	ui.oppGateBack = CardView.back(UDim2.fromScale(0.95, 0.8))
	ui.oppGateBack.LayoutOrder = 1
	ui.oppGateBack.Visible = false
	ui.oppGateBack.Parent = ui.oppGate
	ui.oppPile = pileLabel(UDim2.fromScale(0.1, 0.24))

	-- ตัวจับเวลา
	local track = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.025), Position = UDim2.fromScale(0.5, 0.365), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(30, 60, 40), Parent = gui,
	}, { UIKit.corner(UDim.new(0.5, 0)) })
	ui.timerFill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Yellow, Parent = track }, { UIKit.corner(UDim.new(0.5, 0)) })
	ui.timerText = UIKit.label({ Size = UDim2.fromScale(0.3, 1.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = track })

	-- ฝั่งเรา
	ui.myField = zone("MyField", UDim2.fromScale(0.5, 0.40), UDim2.fromScale(0.62, 0.22))
	ui.myGate = gateZone(UDim2.fromScale(0.89, 0.40))
	ui.myPile = pileLabel(UDim2.fromScale(0.1, 0.51))
	ui.actions = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.56, 0.06), Position = UDim2.fromScale(0.5, 0.635), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.02, 0),
		}),
	})
	ui.hand = zone("Hand", UDim2.fromScale(0.5, 0.71), UDim2.fromScale(0.56, 0.28), { Transparency = 1, Padding = UDim.new(-0.01, 0) })
	ui.myLeader = leaderBar(UDim2.fromScale(0.02, 0.97), Vector2.new(0, 1), false)

	UIKit.button({
		Text = "🙏 สวดมนต์", Color = Theme.Color.Panel, Size = UDim2.fromScale(0.13, 0.08),
		Position = UDim2.fromScale(0.02, 0.86), AnchorPoint = Vector2.new(0, 1), Parent = gui, OnClick = pray,
	})

	ui.pointsBubble = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.11, 0.11), Position = UDim2.fromScale(0.895, 0.72), AnchorPoint = CENTER,
		BackgroundColor3 = Theme.Color.Yellow, Parent = gui,
	}, { UIKit.new("UIAspectRatioConstraint", {}), UIKit.corner(UDim.new(0.5, 0)), UIKit.stroke(nil, 4) })
	ui.points = UIKit.label({ Text = "⚡0", Size = UDim2.fromScale(0.8, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = ui.pointsBubble })
	UIKit.label({
		Text = ("พอยต์ (ดองได้ถึง %d)"):format(Config.MAX_BANKED_POINTS), Font = Theme.FontBody,
		Size = UDim2.fromScale(0.17, 0.03), Position = UDim2.fromScale(0.895, 0.79), AnchorPoint = Vector2.new(0.5, 0), Parent = gui,
	})
	ui.endBtn, ui.endLabel = UIKit.button({
		Text = "จบเทิร์น", Size = UDim2.fromScale(0.17, 0.1), Position = UDim2.fromScale(0.98, 0.97),
		AnchorPoint = Vector2.new(1, 1), Parent = gui, OnClick = endTurn,
	})

	-- รับข้อมูลจากเซิร์ฟเวอร์
	Remotes.StateUpdate.OnClientEvent:Connect(function(s)
		if s.matchId and s.matchId == endedMatchId then return end
		render(s)
	end)
	Remotes.GateRolled.OnClientEvent:Connect(function(userId, card, outcomeId)
		if state then GateRoller.Play(overlay, card, outcomeId, userId == player.UserId) end
	end)
	Remotes.MatchEnded.OnClientEvent:Connect(function(winnerId, reason, matchId)
		endedMatchId = matchId
		clearSelection()
		showResult(winnerId == player.UserId, reason)
	end)
	RunService.Heartbeat:Connect(updateTimer)
	UserInputService.InputBegan:Connect(onKey)
end

return MatchUI