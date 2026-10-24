-- ไฟล์ลูกของ UIClient: MatchUI (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIFolder = Shared:WaitForChild("UI")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Theme = require(UIFolder:WaitForChild("Theme"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local CardView = require(UIFolder:WaitForChild("CardView"))
local GateRoller = require(script.Parent:WaitForChild("GateRoller"))

local RemoteFolder = ReplicatedStorage:WaitForChild("Remotes")
local R = {}
for _, name in { "PlayCard", "Attack", "EndTurn", "Surrender", "StateUpdate", "GateRolled", "MatchEnded", "Notify" } do
	R[name] = RemoteFolder:WaitForChild(name)
end

local CENTER = Vector2.new(0.5, 0.5)
local ERR = {
	NOT_YOUR_TURN = "ยังไม่ถึงตาคุณ ใจเย็นๆ",
	NOT_ENOUGH_POINTS = "พอยต์ไม่พอ! ลองดองไว้ก่อน",
	FIELD_FULL = "สนามเต็มแล้ว!",
	GATE_OCCUPIED = "ช่องเกตมีการ์ดอยู่แล้ว!",
	CANNOT_ATTACK = "ตัวนี้ยังตีไม่ได้ (หลับอยู่ 💤)",
	TAUNT = "ต้องตีตัวบังก่อน! 🛡️",
	INVALID_CARD = "ใช้การ์ดใบนี้ไม่ได้",
	INVALID_TARGET = "เลือกเป้าหมายนี้ไม่ได้",
	NEED_TARGET = "ต้องเลือกเป้าหมายก่อน",
	MATCH_OVER = "แมตช์จบไปแล้ว",
	NO_MATCH = "ไม่ได้อยู่ในแมตช์",
	SLOW_DOWN = "กดรัวไป ใจเย็นๆ",
	SERVER_ERROR = "เซิร์ฟเวอร์กาว ลองใหม่อีกที",
}
local REASON = {
	LEADER_DOWN = "ผู้นำล้มคว่ำ 💥",
	FATIGUE = "การ์ดหมดกองจนหมดแรง 😵",
	AFK_LIGHTNING = "AFK จนโดนฟ้าผ่า ⚡",
	LEFT = "อีกฝั่งหนีออกจากเกม 🏃",
	SURRENDER = "มีคนยอมแพ้ 🏳️",
}
local TARGET_RULES = {
	EnemyChar = { oppField = true },
	AllyChar = { myField = true },
	Ally = { myField = true, myLeader = true },
	Weapon = { myField = true, oppField = true, oppLeader = true },
}
local TARGET_HINT = {
	EnemyChar = "เลือกตัวละครศัตรู 🎯",
	AllyChar = "เลือกตัวละครฝั่งเรา 💪",
	Ally = "เลือกตัวละครเราหรือผู้นำเรา 💚",
	Weapon = "แตะตัวเรา = สวม / แตะศัตรู = ปาใส่ 🗡️",
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
local logCounter = 0

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
	return UIKit.label({ Font = Theme.FontBody, Size = UDim2.fromScale(0.17, 0.045), Position = position, AnchorPoint = CENTER, Parent = gui })
end

local function leaderBar(position, anchor)
	local stroke = UIKit.stroke(nil, 4)
	local root = UIKit.new("TextButton", {
		Position = position, AnchorPoint = anchor, Size = UDim2.fromScale(0.2, 0.09),
		BackgroundColor3 = Theme.Color.Panel, Text = "", AutoButtonColor = false, Parent = gui,
	}, { UIKit.corner(), stroke })
	local name = UIKit.label({
		Color = Theme.Color.Outline, StrokeThickness = 0, AlignX = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.68, 0.4), Position = UDim2.fromScale(0.05, 0.06), Parent = root,
	})
	local shield = UIKit.label({
		Size = UDim2.fromScale(0.25, 0.4), Position = UDim2.fromScale(0.95, 0.06), AnchorPoint = Vector2.new(1, 0), Parent = root,
	})
	local track = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.9, 0.38), Position = UDim2.fromScale(0.05, 0.52),
		BackgroundColor3 = Color3.fromRGB(60, 40, 40), Parent = root,
	}, { UIKit.corner(UDim.new(0.5, 0)) })
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Green, Parent = track }, { UIKit.corner(UDim.new(0.5, 0)) })
	local hp = UIKit.label({ Parent = track })
	return { Root = root, Stroke = stroke, Name = name, Shield = shield, Fill = fill, HP = hp }
end

local function setLeader(bar, name, hp, shield)
	local max = Config.LEADER_HP
	bar.Name.Text = name or "ผู้นำ"
	bar.Shield.Text = (shield or 0) > 0 and ("🛡%d"):format(shield) or ""
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

local function pushLog(text, colorName)
	logCounter += 1
	local entry = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 0.18), BackgroundColor3 = Theme.Color[colorName] or Theme.Color.Panel,
		LayoutOrder = logCounter, Parent = ui.log,
	}, { UIKit.corner(), UIKit.stroke(nil, 2) })
	UIKit.label({
		Text = text, Font = Theme.FontBody, Color = Theme.Color.Outline, StrokeThickness = 0,
		Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = entry,
	})
	local entries = {}
	for _, child in ui.log:GetChildren() do
		if child:IsA("Frame") then table.insert(entries, child) end
	end
	table.sort(entries, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #entries > 5 do table.remove(entries, 1):Destroy() end
	task.delay(5, function()
		if entry.Parent then entry:Destroy() end
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
			warn("[MatchUI] InvokeServer error: " .. tostring(success))
			UIKit.toast("เน็ตกาว ลองใหม่อีกที 📶", Theme.Color.Red)
		elseif not success then
			-- แสดงรหัสดิบเพื่อหาสาเหตุ (ถ้าไม่มีรหัสแปลว่าเซิร์ฟเวอร์ไม่ได้ตอบมาตามรูปแบบ)
			warn(("[MatchUI] %s ถูกปฏิเสธ: success=%s err=%s"):format(remote.Name, tostring(success), tostring(err)))
			UIKit.toast(ERR[err] or ("ทำแบบนี้ไม่ได้ [" .. tostring(err) .. "]"), Theme.Color.Red)
		end
	end)
end

local function clearSelection()
	if selected and selected.view.Frame.Parent then selected.view:SetSelected(false) end
	selected = nil
	for _, map in { views.myField, views.oppField } do
		for _, v in pairs(map) do v:SetTarget(false) end
	end
	ui.myLeader.Stroke.Color = Theme.Color.Outline
	ui.oppLeader.Stroke.Color = Theme.Color.Outline
	for _, child in ui.actions:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	ui.actions.Visible = false
end

local function actionButton(text, color, width, disabled, onClick)
	local btn = UIKit.button({ Text = text, Color = color, Size = UDim2.fromScale(width, 1), Parent = ui.actions, OnClick = onClick })
	btn.LayoutOrder = #ui.actions:GetChildren()
	if disabled then UIKit.setDisabled(btn, true) end
end

local function hint(text)
	local lbl = UIKit.label({ Text = text, Size = UDim2.fromScale(0.5, 1), Parent = ui.actions })
	lbl.LayoutOrder = 0
end

local function highlight(rule)
	local count = 0
	for zoneName, map in { myField = views.myField, oppField = views.oppField } do
		for _, v in pairs(map) do
			local ok = rule[zoneName] == true
			v:SetTarget(ok)
			if ok then count += 1 end
		end
	end
	ui.myLeader.Stroke.Color = rule.myLeader and Theme.Color.Red or Theme.Color.Outline
	ui.oppLeader.Stroke.Color = rule.oppLeader and Theme.Color.Red or Theme.Color.Outline
	if rule.myLeader then count += 1 end
	if rule.oppLeader then count += 1 end
	return count
end

local function playCard(uid, target)
	UIKit.sfx("PlayCard")
	clearSelection()
	call(R.PlayCard, uid, target)
end

local function doAttack(targetUid)
	if not selected or selected.mode ~= "attack" then return end
	local attacker = selected.view
	clearSelection()
	attacker:Lunge()
	UIKit.sfx("Swing")
	call(R.Attack, attacker.Card.Uid, targetUid)
end

local function selectHand(view)
	clearSelection()
	local card = view.Card
	local myTurn = state.isMyTurn
	local tt = Rules.TargetType(card)
	selected = { mode = "hand", view = view }
	view:SetSelected(true)

	if tt == "Board" then
		local gateCost = Rules.GateCost(card)
		actionButton(("ลงสนาม ⚡%d"):format(card.Cost), Theme.Color.Yellow, 0.32,
			not myTurn or #state.myField >= Config.FIELD_SLOTS or card.Cost > state.myPoints,
			function() playCard(card.Uid, "Field") end)
		actionButton(("ลงเกต 🎲 ⚡%d"):format(gateCost), Theme.Color.Pink, 0.32,
			not myTurn or state.myGate ~= nil or gateCost > state.myPoints,
			function() playCard(card.Uid, "Gate") end)
	elseif tt == "None" then
		actionButton(("ใช้การ์ด ⚡%d"):format(card.Cost), Theme.Color.Blue, 0.4,
			not myTurn or card.Cost > state.myPoints,
			function() playCard(card.Uid, nil) end)
	elseif myTurn and card.Cost <= state.myPoints then
		selected.mode = "target"
		selected.rule = TARGET_RULES[tt] or {}
		local count = highlight(selected.rule)
		hint(count > 0 and (TARGET_HINT[tt] or "เลือกเป้าหมาย") or "ไม่มีเป้าหมายให้เลือก 😅")
	else
		actionButton(("ใช้การ์ด ⚡%d"):format(card.Cost), Theme.Color.Blue, 0.4, true, nil)
	end
	actionButton("ยกเลิก", Theme.Color.Gray, 0.2, false, clearSelection)
	ui.actions.Visible = true
end

local function selectAttacker(view)
	clearSelection()
	selected = { mode = "attack", view = view }
	view:SetSelected(true)
	local tauntUp = Rules.HasTaunt(state.oppField)
	for _, v in pairs(views.oppField) do
		v:SetTarget(not tauntUp or Rules.HasKeyword(v.Card, "Taunt"))
	end
	ui.oppLeader.Stroke.Color = tauntUp and Theme.Color.Outline or Theme.Color.Red
	hint(tauntUp and "มีตัวบัง! ต้องตีมันก่อน 🛡️" or "เลือกเป้าหมายเลย 👊")
	actionButton("ยกเลิก", Theme.Color.Gray, 0.2, false, clearSelection)
	ui.actions.Visible = true
end

local function onCardClick(zoneName, view)
	if not state or busy then return end
	if zoneName == "hand" then
		if selected and selected.view == view then clearSelection() else selectHand(view) end
		return
	end
	if selected and selected.mode == "target" then
		if selected.rule[zoneName] then
			playCard(selected.view.Card.Uid, view.Card.Uid)
		else
			UIKit.toast(ERR.INVALID_TARGET, Theme.Color.Red)
		end
		return
	end
	if selected and selected.mode == "attack" and zoneName == "oppField" then
		doAttack(view.Card.Uid)
		return
	end
	if zoneName == "myField" then
		if selected and selected.view == view then clearSelection() return end
		if not state.isMyTurn then UIKit.toast(ERR.NOT_YOUR_TURN) return end
		if not view.Card.CanAttack or (view.Card.ATK or 0) <= 0 then
			UIKit.shake(view.Body)
			UIKit.toast(view.Card.Frozen and "แข็งเป็นน้ำแข็งอยู่ ❄️" or ERR.CANNOT_ATTACK)
			return
		end
		selectAttacker(view)
	end
end

local function onLeaderClick(which)
	if not state or busy or not selected then return end
	if selected.mode == "target" then
		if selected.rule[which] then
			playCard(selected.view.Card.Uid, which == "myLeader" and "MY_LEADER" or "LEADER")
		else
			UIKit.toast(ERR.INVALID_TARGET, Theme.Color.Red)
		end
	elseif selected.mode == "attack" and which == "oppLeader" then
		doAttack("LEADER")
	end
end

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
	R.EndTurn:FireServer()
	task.delay(2, function() -- กันปุ่มค้าง ถ้าเซิร์ฟเวอร์ไม่ตอบ
		if state and state.isMyTurn then UIKit.setDisabled(ui.endBtn, false) end
	end)
end

local surrenderArmed = 0
local function surrender()
	if not state then return end
	if os.clock() - surrenderArmed > 3 then
		surrenderArmed = os.clock()
		UIKit.toast("กดอีกครั้งภายใน 3 วิ เพื่อยืนยันยอมแพ้ 🏳️")
		return
	end
	R.Surrender:FireServer()
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
	task.delay(2, function() beam:Destroy() end)
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
	local keepUid = selected and selected.mode ~= "attack" and selected.view.Card.Uid
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
	for _, child in ui.oppHand:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	for i = 1, s.oppHandCount or 0 do
		local back = CardView.back(UDim2.fromScale(0.18, 1))
		back.LayoutOrder = i
		back.Parent = ui.oppHand
	end

	setLeader(ui.myLeader, s.myLeader, s.myHP, s.myShield)
	setLeader(ui.oppLeader, s.oppLeader, s.oppHP, s.oppShield)
	ui.myPile.Text = ("🂠 %d   💀 %d"):format(s.myDeck or 0, s.myGrave or 0)
	ui.oppPile.Text = ("🂠 %d   💀 %d%s"):format(s.oppDeck or 0, s.oppGrave or 0,
		(s.oppBank or 0) > 0 and ("   💰ดอง %d"):format(s.oppBank) or "")
	ui.bombText = (s.bombs and #s.bombs > 0) and ("   💣 " .. table.concat(s.bombs, ", ")) or ""

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

	if keepUid and views.hand[keepUid] then selectHand(views.hand[keepUid]) end
end

local function reset()
	for _, map in pairs(views) do
		for uid, view in pairs(map) do
			view.Frame:Destroy()
			map[uid] = nil
		end
	end
	for _, child in ui.log:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	state, selected, ui.lastTurn = nil, nil, nil
	ui.myLeader.Value, ui.oppLeader.Value = nil, nil
	ui.resultOpen = false
	gui.Enabled = false
end

local function showResult(won, reason, gems)
	if ui.resultOpen then return end
	ui.resultOpen = true
	local dim = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3, Active = true, Parent = overlay,
	})
	UIKit.sfx(won and "Win" or "Lose")
	UIKit.rain(dim, won and "🏆" or "🧂", 30)
	local title = UIKit.label({
		Text = won and "ชนะ! 🏆" or "แพ้... เกลือเต็มปาก 🧂", Color = won and Theme.Color.Yellow or Theme.Color.Gray,
		Size = UDim2.fromScale(0.8, 0.2), Position = UDim2.fromScale(0.5, 0.28), AnchorPoint = CENTER,
		Parent = dim, MaxTextSize = 120, StrokeThickness = 5,
	})
	UIKit.jelly(title, 0.5)
	UIKit.label({ Text = REASON[reason] or tostring(reason or ""), Size = UDim2.fromScale(0.6, 0.07), Position = UDim2.fromScale(0.5, 0.44), AnchorPoint = CENTER, Parent = dim })
	UIKit.label({ Text = ("+%d 💎"):format(gems or 0), Color = Theme.Color.Blue, Size = UDim2.fromScale(0.4, 0.08), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = CENTER, Parent = dim })
	UIKit.button({
		Text = "กลับล็อบบี้", Color = Theme.Color.Green, Size = UDim2.fromScale(0.25, 0.1),
		Position = UDim2.fromScale(0.5, 0.68), AnchorPoint = CENTER, Parent = dim,
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
	ui.timerText.Text = ("%s %d:%02d%s"):format(state.isMyTurn and "ตาคุณ" or "ตาศัตรู", left // 60, left % 60, ui.bombText or "")
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

	UIKit.new("Frame", {
		Name = "TableBg", Size = UDim2.new(1, 0, 1, 200), Position = UDim2.fromOffset(0, -100),
		BackgroundColor3 = Theme.Color.Table, Active = true, ZIndex = 0, Parent = gui,
	}, {
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) }),
	})

	-- ฝั่งศัตรู
	ui.oppLeader = leaderBar(UDim2.fromScale(0.98, 0.02), Vector2.new(1, 0))
	ui.oppLeader.Root.Activated:Connect(function() onLeaderClick("oppLeader") end)
	ui.oppHand = zone("OppHand", UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.3, 0.1), { Transparency = 1 })
	ui.oppField = zone("OppField", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(0.62, 0.22))
	ui.oppGate = gateZone(UDim2.fromScale(0.89, 0.13))
	ui.oppGateBack = CardView.back(UDim2.fromScale(0.95, 0.8))
	ui.oppGateBack.LayoutOrder = 1
	ui.oppGateBack.Visible = false
	ui.oppGateBack.Parent = ui.oppGate
	ui.oppPile = pileLabel(UDim2.fromScale(0.1, 0.15))

	UIKit.button({
		Text = "🏳️ ยอมแพ้", Color = Theme.Color.Gray, Size = UDim2.fromScale(0.1, 0.06),
		Position = UDim2.fromScale(0.01, 0.02), Parent = gui, OnClick = surrender,
	})

	-- ประวัติเหตุการณ์
	ui.log = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.17, 0.27), Position = UDim2.fromScale(0.01, 0.2),
		BackgroundTransparency = 1, Parent = gui,
	}, {
		UIKit.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.02, 0),
		}),
	})

	-- ตัวจับเวลา
	local track = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.025), Position = UDim2.fromScale(0.5, 0.365), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(30, 60, 40), Parent = gui,
	}, { UIKit.corner(UDim.new(0.5, 0)) })
	ui.timerFill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Yellow, Parent = track }, { UIKit.corner(UDim.new(0.5, 0)) })
	ui.timerText = UIKit.label({ Size = UDim2.fromScale(0.5, 1.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = track })

	-- ฝั่งเรา
	ui.myField = zone("MyField", UDim2.fromScale(0.5, 0.40), UDim2.fromScale(0.62, 0.22))
	ui.myGate = gateZone(UDim2.fromScale(0.89, 0.40))
	ui.myPile = pileLabel(UDim2.fromScale(0.1, 0.52))
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
	ui.myLeader = leaderBar(UDim2.fromScale(0.02, 0.97), Vector2.new(0, 1))
	ui.myLeader.Root.Activated:Connect(function() onLeaderClick("myLeader") end)

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
	R.StateUpdate.OnClientEvent:Connect(function(s)
		if typeof(s) ~= "table" or (s.matchId and s.matchId == endedMatchId) then return end
		render(s)
	end)
	R.GateRolled.OnClientEvent:Connect(function(isMine, card, outcomeId)
		if state then GateRoller.Play(overlay, card, outcomeId, isMine) end
	end)
	R.Notify.OnClientEvent:Connect(function(text, color)
		if state then pushLog(tostring(text), color) end
	end)
	R.MatchEnded.OnClientEvent:Connect(function(won, reason, matchId, gems)
		endedMatchId = matchId
		if state then clearSelection() end
		showResult(won, reason, gems)
	end)
	RunService.Heartbeat:Connect(updateTimer)
	UserInputService.InputBegan:Connect(onKey)
end

return MatchUI
