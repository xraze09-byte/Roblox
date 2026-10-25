local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local S = require(Shared:WaitForChild("UI"):WaitForChild("Style"))
local Net = require(script.Parent:WaitForChild("Net"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))
local Drag = require(script.Parent:WaitForChild("DragController"))
local Inspect = require(script.Parent:WaitForChild("Inspect"))

local OUTCOME = { Golden = "ทองคำ", Pumped = "พลังพุ่ง", Normal = "ปกติ", Droopy = "ห่อเหี่ยว", Poop = "ซวย" }

local function reasonText(reason, won)
	if reason == "LEADER_DOWN" then return won and "ผู้นำคู่แข่งล้ม" or "ผู้นำของคุณล้ม" end
	if reason == "SURRENDER" then return won and "คู่แข่งยอมแพ้" or "คุณยอมแพ้" end
	if reason == "LEFT" then return "คู่แข่งออกจากเกม" end
	if reason == "FATIGUE" then return "การ์ดในกองหมด" end
	if reason == "AFK_LIGHTNING" then return won and "คู่แข่งไม่เล่นหลายเทิร์น" or "คุณไม่ได้เล่นหลายเทิร์น" end
	return tostring(reason or "")
end

local MatchUI = {}

function MatchUI.Build(gui, overlay, cb)
	cb = cb or {}
	Inspect.Init(overlay)

	local ui = {}
	local state, matchId = nil, nil
	local ended = false
	local views = { hand = {}, myField = {}, oppField = {}, myGate = {} }
	local activeTargets = nil
	local applyGlows, endTurn, exitMatch

	local root = S.new("Frame", { Name = "MatchRoot", BackgroundColor3 = S.C.Felt,
		Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }, { S.pad(10) })

	local function glowStroke(parent)
		local s = S.stroke(S.C.Info, 2, parent)
		s.Name = "Glow"
		s.Transparency = 1
		return s
	end

	ui.board = S.new("Frame", { Name = "BoardZone", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.75), Parent = root })
	ui.boardGlow = glowStroke(ui.board)

	local function band(name, y, h)
		return S.new("Frame", { Name = name, BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), Parent = root })
	end
	local oppBarF = band("OppBar", 0, 0.08)
	local oppBoardF = band("OppBoard", 0.09, 0.25)
	local midF = band("Mid", 0.35, 0.05)
	local myBoardF = band("MyBoard", 0.41, 0.25)
	local myBarF = band("MyBar", 0.67, 0.08)
	local handF = band("Hand", 0.76, 0.24)

	local function leaderBar(parent, width)
		local bar = S.new("Frame", { BackgroundColor3 = S.C.FeltDark, Size = UDim2.fromScale(width, 1), Parent = parent }, { S.corner(4) })
		local glow = glowStroke(bar)
		local name = S.text({ Font = S.Font.Bold, Max = 18, Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.32, 0.8), Parent = bar })
		local hpBack = S.new("Frame", { BackgroundColor3 = S.C.Bg, Position = UDim2.fromScale(0.36, 0.22),
			Size = UDim2.fromScale(0.3, 0.56), Parent = bar }, { S.corner(3) })
		local hpFill = S.new("Frame", { BackgroundColor3 = S.C.Bad, Size = UDim2.fromScale(1, 1), Parent = hpBack }, { S.corner(3) })
		local hpText = S.text({ Font = S.Font.Bold, Max = 14, XAlign = "Center", ZIndex = 2, Parent = hpBack })
		local shield = S.text({ Font = S.Font.Medium, Max = 14, Color = S.C.Info, XAlign = "Center",
			Position = UDim2.fromScale(0.67, 0.1), Size = UDim2.fromScale(0.1, 0.8), Parent = bar })
		local info = S.text({ Max = 13, Color = S.C.TextDim, XAlign = "Right",
			Position = UDim2.fromScale(0.78, 0.1), Size = UDim2.fromScale(0.2, 0.8), Parent = bar })
		return { Frame = bar, Glow = glow, Name = name, HpFill = hpFill, HpText = hpText, Shield = shield, Info = info }
	end

	local function addSlot(row)
		local i = #row.Slots + 1
		local slot = S.new("Frame", { Name = "Slot" .. i, BackgroundColor3 = S.C.FeltDark, BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(0.3, 0.96), LayoutOrder = i, Parent = row.Field }, {
			S.corner(5),
			S.new("UIAspectRatioConstraint", { AspectRatio = CardFace.ASPECT,
				AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Height }),
		})
		S.stroke(S.C.Line, 1, slot)
		S.text({ Name = "Empty", Text = "ว่าง", Color = S.C.Line, Max = 14, XAlign = "Center", Parent = slot })
		row.Slots[i] = slot
	end

	local function boardRow(parent)
		local row = { Slots = {} }
		row.Gate = S.new("Frame", { BackgroundColor3 = S.C.FeltDark, Size = UDim2.fromScale(0.13, 1), Parent = parent }, { S.corner(4) })
		row.GateGlow = glowStroke(row.Gate)
		S.text({ Text = "เกต", Font = S.Font.Bold, Color = S.C.TextDim, Max = 13, XAlign = "Center",
			Size = UDim2.fromScale(1, 0.13), Parent = row.Gate })
		row.GateSlot = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.08, 0.15),
			Size = UDim2.fromScale(0.84, 0.82), Parent = row.Gate })
		row.Field = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.15, 0),
			Size = UDim2.fromScale(0.7, 1), Parent = parent }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		row.FieldGlow = glowStroke(row.Field)
		row.Info = S.text({ Max = 13, Color = S.C.TextDim, XAlign = "Center",
			Position = UDim2.fromScale(0.87, 0), Size = UDim2.fromScale(0.13, 1), Parent = parent })
		for _ = 1, Config.FIELD_SLOTS do addSlot(row) end
		return row
	end

	ui.opp = leaderBar(oppBarF, 1)
	ui.oppRow = boardRow(oppBoardF)
	ui.oppRow.FaceDown = S.new("Frame", { BackgroundColor3 = S.C.Panel2, Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, Parent = ui.oppRow.GateSlot }, {
		S.corner(5), S.new("UIAspectRatioConstraint", { AspectRatio = CardFace.ASPECT }),
	})
	S.text({ Text = "คว่ำ", Color = S.C.TextDim, Max = 13, XAlign = "Center", Parent = ui.oppRow.FaceDown })
	ui.myRow = boardRow(myBoardF)
	ui.me = leaderBar(myBarF, 0.6)

	ui.turn = S.text({ Font = S.Font.Heavy, Max = 20, Size = UDim2.fromScale(0.2, 1), Parent = midF })
	local timerBack = S.new("Frame", { BackgroundColor3 = S.C.FeltDark, Position = UDim2.fromScale(0.22, 0.3),
		Size = UDim2.fromScale(0.36, 0.4), Parent = midF }, { S.corner(3) })
	ui.timerFill = S.new("Frame", { BackgroundColor3 = S.C.Accent, Size = UDim2.fromScale(1, 1), Parent = timerBack }, { S.corner(3) })
	ui.timerText = S.text({ Font = S.Font.Bold, Max = 16, Position = UDim2.fromScale(0.59, 0), Size = UDim2.fromScale(0.07, 1), Parent = midF })
	ui.log = S.text({ Color = S.C.TextDim, Max = 14, Position = UDim2.fromScale(0.67, 0), Size = UDim2.fromScale(0.21, 1), Parent = midF })
	
	local surrenderArmed = 0
	ui.surrender = S.button({ Text = "ยอมแพ้", Max = 13, Color = S.C.Panel, Position = UDim2.fromScale(0.89, 0.08),
		Size = UDim2.fromScale(0.11, 0.84), Parent = midF, OnClick = function(btn)
			if os.clock() - surrenderArmed < 3 then
				surrenderArmed = 0
				btn.Text = "ยอมแพ้"
				Net.fire("Surrender")
			else
				surrenderArmed = os.clock()
				btn.Text = "ยืนยัน?"
				task.delay(3, function()
					if os.clock() - surrenderArmed >= 2.9 then btn.Text = "ยอมแพ้" end
				end)
			end
		end })

	local pts = S.new("Frame", { BackgroundColor3 = S.C.FeltDark, Position = UDim2.fromScale(0.615, 0),
		Size = UDim2.fromScale(0.165, 1), Parent = myBarF }, { S.corner(4) })
	S.text({ Text = "แต้ม", Color = S.C.TextDim, Max = 12, XAlign = "Center", Size = UDim2.fromScale(1, 0.38), Parent = pts })
	ui.points = S.text({ Font = S.Font.Heavy, Color = S.C.Accent, Max = 24, XAlign = "Center",
		Position = UDim2.fromScale(0, 0.36), Size = UDim2.fromScale(1, 0.6), Parent = pts })
	ui.endBtn = S.button({ Text = "จบเทิร์น", Max = 20, Color = S.C.Accent, TextColor = S.C.Ink,
		Position = UDim2.fromScale(0.795, 0), Size = UDim2.fromScale(0.205, 1), Parent = myBarF,
		Debounce = 0.6, OnClick = function() endTurn() end })

	ui.hand = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = handF }, {
		S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local result = S.new("Frame", { Name = "MatchResult", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1), Visible = false, Active = true, ZIndex = 30, Parent = overlay })
	local rbox = S.new("Frame", { BackgroundColor3 = S.C.Panel, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.34, 0.36), ZIndex = 31, Parent = result }, {
		S.corner(6), S.new("UISizeConstraint", { MinSize = Vector2.new(280, 200), MaxSize = Vector2.new(460, 300) }),
	})
	S.stroke(S.C.Line, 1, rbox)
	ui.resTitle = S.text({ Font = S.Font.Heavy, Max = 40, XAlign = "Center", Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, 0.28), ZIndex = 32, Parent = rbox })
	ui.resReason = S.text({ Color = S.C.TextDim, Max = 16, XAlign = "Center", Position = UDim2.fromScale(0.05, 0.38),
		Size = UDim2.fromScale(0.9, 0.14), ZIndex = 32, Parent = rbox })
	ui.resReward = S.text({ Font = S.Font.Bold, Color = S.C.Accent, Max = 20, XAlign = "Center",
		Position = UDim2.fromScale(0.05, 0.53), Size = UDim2.fromScale(0.9, 0.14), ZIndex = 32, Parent = rbox })
	S.button({ Text = "กลับล็อบบี้", Color = S.C.Accent, TextColor = S.C.Ink, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.5, 0.17), ZIndex = 32, Parent = rbox,
		OnClick = function() exitMatch() end })

	local function setZoneGlow(stroke, mode)
		if not mode then stroke.Transparency = 1 return end
		stroke.Transparency = 0
		stroke.Color = mode == "hover" and S.C.Accent or S.C.Info
		stroke.Thickness = mode == "hover" and 3 or 2
	end

	local function markTargets(hover)
		for _, t in activeTargets or {} do
			local mode = t == hover and "hover" or "target"
			if t.View then t.View:SetGlow(mode) elseif t.Glow then setZoneGlow(t.Glow, mode) end
		end
	end

	local function clearTargets()
		for _, t in activeTargets or {} do
			if t.Glow then setZoneGlow(t.Glow, nil) end
		end
		activeTargets = nil
		applyGlows()
	end

	local function addChars(t, list, map)
		for _, c in list or {} do
			local v = map[c.Uid]
			if v then table.insert(t, { Gui = v.Root, View = v, Value = c.Uid }) end
		end
	end

	local function playTargets(card)
		local t = {}
		if card.Type == "Character" then
			if #state.myField < Config.FIELD_SLOTS then
				table.insert(t, { Gui = ui.myRow.Field, Glow = ui.myRow.FieldGlow, Value = "Field" })
			end
			if not state.myGate then
				table.insert(t, { Gui = ui.myRow.Gate, Glow = ui.myRow.GateGlow, Value = "Gate" })
			end
		elseif card.Type == "Weapon" then
			addChars(t, state.myField, views.myField)
			addChars(t, state.oppField, views.oppField)
			table.insert(t, { Gui = ui.opp.Frame, Glow = ui.opp.Glow, Value = "LEADER" })
		else
			local kind = Rules.TargetType(card)
			if kind == "EnemyChar" then
				addChars(t, state.oppField, views.oppField)
			elseif kind == "AllyChar" then
				addChars(t, state.myField, views.myField)
			elseif kind == "Ally" then
				addChars(t, state.myField, views.myField)
				table.insert(t, { Gui = ui.me.Frame, Glow = ui.me.Glow, Value = "MY_LEADER" })
			else
				table.insert(t, { Gui = ui.board, Glow = ui.boardGlow })
			end
		end
		return t
	end

	local function attackTargets()
		local t = {}
		local taunt = Rules.HasTaunt(state.oppField)
		if taunt then
			for _, c in state.oppField do
				if Rules.HasKeyword(c, "Taunt") then
					local v = views.oppField[c.Uid]
					if v then table.insert(t, { Gui = v.Root, View = v, Value = c.Uid }) end
				end
			end
		else
			addChars(t, state.oppField, views.oppField)
			table.insert(t, { Gui = ui.opp.Frame, Glow = ui.opp.Glow, Value = "LEADER" })
		end
		return t
	end

	applyGlows = function()
		if not state or not state.isMyTurn then
			for _, v in views.hand do v:SetGlow("none") end
			for _, v in views.myField do v:SetGlow("none") end
			return
		end
		local pts = state.myPoints or 0
		for _, c in state.myHand do
			local v = views.hand[c.Uid]
			if v then
				local afford = (c.Cost or 0) <= pts
				v:SetGlow(afford and "playable" or "none")
				v:SetCostWarning(not afford)
			end
		end
		for _, c in state.myField do
			local v = views.myField[c.Uid]
			if v then
				v:SetGlow(c.CanAttack and "ready" or "none")
			end
		end
	end

	function endTurn()
		if not state or not state.isMyTurn or ended then return end
		Net.fire("EndTurn")
	end

	exitMatch = function()
		result.Visible = false
		root.Visible = false
		ended = false
		state = nil
		matchId = nil -- ไม่งั้นแมตช์ถัดไปจะถูกเมินเพราะ matchId ไม่ตรง
		if cb.OnExit then cb.OnExit() end
	end

	-- ผูกปุ่มการ์ดในมือ (รองรับทั้งแตะเพื่อดู และลากเพื่อเล่น)
	local function bindHand(faceCard, card)
		faceCard.Root.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not state or not state.isMyTurn or ended then
				if input.UserInputType == Enum.UserInputType.MouseButton1 then Inspect.Show(card) end
				return
			end
			Drag.Begin(input, {
				Source = card.Uid,
				CanStart = function() return (card.Cost or 0) <= (state.myPoints or 0) end,
				Ghost = function()
					local g = CardFace.new(card, { Size = UDim2.fromOffset(88, 122) })
					g.Root.ZIndex = 50
					return g.Root
				end,
				Targets = function()
					activeTargets = playTargets(card)
					markTargets(nil)
					return activeTargets
				end,
				OnHover = markTargets,
				OnEnd = clearTargets,
				OnDrop = function(target)
					if not target then return end
					local val = target.Value
					local ok, err = Net.invoke("PlayCard", card.Uid, val) -- val: Field/Gate/LEADER/MY_LEADER/Uid หรือ nil (เวทไม่ต้องเลือกเป้า)
					if not ok then S.toast(Net.message(err), "bad") end
				end,
				OnTap = function() Inspect.Show(card) end,
			})
		end)
	end

	-- ผูกปุ่มตัวละครในสนาม (ลากเพื่อโจมตี)
	local function bindField(faceCard, card)
		faceCard.Root.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not state or not state.isMyTurn or ended or not card.CanAttack then
				if input.UserInputType == Enum.UserInputType.MouseButton1 then Inspect.Show(card) end
				return
			end
			Drag.Begin(input, {
				Source = card.Uid,
				Arrow = true,
				CanStart = function() return card.CanAttack == true end,
				Targets = function()
					activeTargets = attackTargets()
					markTargets(nil)
					return activeTargets
				end,
				OnHover = markTargets,
				OnEnd = clearTargets,
				OnDrop = function(target)
					if not target then return end
					local ok, err = Net.invoke("Attack", card.Uid, target.Value)
					if not ok then S.toast(Net.message(err), "bad") end
				end,
				OnTap = function() Inspect.Show(card) end,
			})
		end)
	end

	local function syncZone(container, list, viewMap, isHand)
		local alive = {}
		for _, c in list or {} do
			local uid = c.Uid
			alive[uid] = true
			local v = viewMap[uid]
			if not v then
				v = CardFace.new(c, {})
				v.Root.Parent = container
				if isHand then bindHand(v, c) else bindField(v, c) end
				v:PopIn()
				viewMap[uid] = v
			else
				v:Update(c)
			end
		end
		for uid, v in viewMap do
			if not alive[uid] then
				v:Destroy()
				viewMap[uid] = nil
			end
		end
	end

	local function render(s)
		state = s
		local isNewMatch = matchId == nil
		matchId = s.matchId
		root.Visible = true
		-- เรียกทุกครั้งที่เริ่มแมตช์ใหม่ (เดิมตั้ง cb.OnStart = nil ทำให้แมตช์ที่ 2 ไม่ซ่อนล็อบบี้)
		if isNewMatch and cb.OnStart then cb.OnStart() end

		ui.turn.Text = if s.isMyTurn then "เทิร์นของคุณ" else "ตาคู่แข่ง"
		ui.turn.TextColor3 = s.isMyTurn and S.C.Accent or S.C.TextDim
		ui.points.Text = tostring(s.myPoints or 0)
		ui.endBtn:SetAttribute("Disabled", not s.isMyTurn)

		ui.me.Name.Text = s.myLeader
		ui.me.HpText.Text = tostring(s.myHP)
		ui.me.HpFill.Size = UDim2.fromScale(math.clamp(s.myHP / Config.LEADER_HP, 0, 1), 1)
		ui.me.Shield.Text = (s.myShield and s.myShield > 0) and ("โล่ " .. s.myShield) or ""
		ui.me.Info.Text = ("กอง %d | สุสาน %d"):format(s.myDeck, s.myGrave)

		ui.opp.Name.Text = s.oppLeader
		ui.opp.HpText.Text = tostring(s.oppHP)
		ui.opp.HpFill.Size = UDim2.fromScale(math.clamp(s.oppHP / Config.LEADER_HP, 0, 1), 1)
		ui.opp.Shield.Text = (s.oppShield and s.oppShield > 0) and ("โล่ " .. s.oppShield) or ""
		ui.opp.Info.Text = ("มือ %d | กอง %d"):format(s.oppHandCount, s.oppDeck)

		syncZone(ui.hand, s.myHand, views.hand, true)
		syncZone(ui.myRow.Field, s.myField, views.myField, false)
		syncZone(ui.oppRow.Field, s.oppField, views.oppField, false)

		-- ช่องเกต
		ui.myRow.GateSlot:ClearAllChildren()
		views.myGate = nil
		if s.myGate then
			local v = CardFace.new(s.myGate, {})
			v.Root.Parent = ui.myRow.GateSlot
			views.myGate = v
		end
		ui.oppRow.FaceDown.Visible = s.oppGateFilled

		applyGlows()
	end

	Net.on("StateUpdate", function(s)
		if ended then return end -- StateUpdate ที่ถูก defer อาจมาหลัง MatchEnded: ห้ามวาดทับหน้าผลลัพธ์
		if typeof(s) ~= "table" then return end
		-- แมตช์ใหม่: matchId ยังเป็น nil (หลัง exitMatch) ให้รับ id แรกที่เข้ามา
		if matchId ~= nil and s.matchId ~= matchId then return end
		render(s)
	end)

	Net.on("GateRolled", function(mine, card, outcome)
		local name = S.clean(card.Name)
		local outName = OUTCOME[outcome] or outcome
		S.toast(("เกต: %s ออกผล [%s]"):format(name, outName), mine and "good" or "info")
	end)

	Net.on("MatchEnded", function(won, reason, id, reward)
		if id ~= matchId and matchId ~= nil then return end
		ended = true
		ui.resTitle.Text = won and "ชนะแล้ว!" or "แพ้แล้ว!"
		ui.resTitle.TextColor3 = won and S.C.Good or S.C.Bad
		ui.resReason.Text = reasonText(reason, won)
		ui.resReward.Text = reward and reward > 0 and ("ได้รับ +" .. reward .. " เพชร") or ""
		result.Visible = true
	end)

	Net.on("Notify", function(text, color)
		S.toast(text, color == "Red" and "bad" or (color == "Green" and "good" or "info"))
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not state or ended then return end
		local rem = math.max(0, (state.turnEndsAt or 0) - workspace:GetServerTimeNow())
		ui.timerText.Text = math.ceil(rem)
		ui.timerFill.Size = UDim2.fromScale(math.clamp(rem / Config.TURN_TIME, 0, 1), 1)
	end)
end

return MatchUI