-- หน้าจอต่อสู้สไตล์การ์ตูนปั่นๆ: HUD ผู้นำ, เกจ 5 แต้ม, ปุ่มข้ามเทิร์น/เก็บแต้ม, ชนวนจับเวลา 2 นาที,
-- ช่องเกต RNG, วงซัมมอนเจมใต้ตาข่าย และการ์ดในมือเรียงพัด
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
local HandFan = require(script.Parent:WaitForChild("HandFan"))
local GateRoller = require(script.Parent:WaitForChild("GateRoller"))

local CENTER = Vector2.new(0.5, 0.5)
local CRUNCH_TIME = 15 -- วินาทีสุดท้ายที่ชนวนลุกไฟ

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
	local lastTurnMine = nil
	local views = { hand = {}, myField = {}, oppField = {}, myGate = {} }
	local activeTargets = nil
	local applyGlows, endTurn, exitMatch

	local root = S.new("Frame", { Name = "MatchRoot", BackgroundColor3 = S.C.Felt,
		Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }, { S.pad(10) })
	S.gradient(root, { S.C.Felt, S.C.Bg }, 90)

	-- เส้นเรืองแสงบอกเป้าหมาย (ใช้กับเฟรมโปร่งที่ยังไม่มี UIStroke)
	local function glowStroke(parent)
		local s = S.stroke(S.C.Info, 3, parent)
		s.Name = "Glow"
		s.Transparency = 1
		return s
	end
	-- กล่องที่มีขอบดำอยู่แล้วใส่ UIStroke ซ้อนอีกอันไม่ได้ จึงวางเฟรมโปร่งทับแล้วให้เส้นเรืองแสงอยู่บนนั้นแทน
	local function glowOverlay(parent, radius)
		local f = S.new("Frame", { Name = "GlowFrame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			ZIndex = parent.ZIndex + 2, Parent = parent }, { S.corner(radius or 14) })
		return glowStroke(f)
	end

	ui.board = S.new("Frame", { Name = "BoardZone", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.75), Parent = root })
	ui.boardGlow = glowStroke(ui.board)

	local function band(name, y, h)
		return S.new("Frame", { Name = name, BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), Parent = root })
	end
	local oppBarF = band("OppBar", 0, 0.08)
	local oppBoardF = band("OppBoard", 0.09, 0.25)
	local myBoardF = band("MyBoard", 0.41, 0.25)
	local midF = band("Mid", 0.35, 0.05)
	local myBarF = band("MyBar", 0.67, 0.08)
	local handF = band("Hand", 0.76, 0.24)

	-- ===== แถบผู้นำ: กระดาษครีมขอบดำ + หลอดเลือด + ป้ายโล่ =====
	local function leaderBar(parent, width, color)
		local bar = S.box({ Color = S.C.Panel, Size = UDim2.fromScale(width, 1), Radius = 14, Stroke = 3, Parent = parent })
		local glow = glowStroke(bar)
		local tag = S.box({ Color = color, Position = UDim2.fromScale(0.012, 0.12), Size = UDim2.fromScale(0.3, 0.76), Radius = 10, Stroke = 2.5, Rotation = -1.5, Parent = bar })
		local name = S.text({ Font = S.Font.Heavy, Max = 20, XAlign = "Center", Stroke = 2, Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 1), Parent = tag })
		local hpBack = S.box({ Color = S.C.FeltDark, Position = UDim2.fromScale(0.34, 0.2), Size = UDim2.fromScale(0.3, 0.6), Radius = 8, Stroke = 2.5, Parent = bar })
		local hpFill = S.new("Frame", { BackgroundColor3 = S.C.Bad, Size = UDim2.fromScale(1, 1), Parent = hpBack }, { S.corner(8) })
		S.gradient(hpFill, { S.C.Bad, S.C.Orange }, 0)
		local hpText = S.text({ Font = S.Font.Heavy, Max = 18, XAlign = "Center", Stroke = 2, ZIndex = 2, Parent = hpBack })
		local shieldBox, shield = S.badge({ Text = "", Color = S.C.Info, Max = 14, Position = UDim2.fromScale(0.66, 0.2),
			Size = UDim2.fromScale(0.12, 0.6), Rotation = 3, Parent = bar })
		shieldBox.Visible = false
		local info = S.text({ Font = S.Font.Bold, Max = 13, Color = S.C.InkSoft, XAlign = "Right",
			Position = UDim2.fromScale(0.79, 0.1), Size = UDim2.fromScale(0.19, 0.8), Parent = bar })
		return { Frame = bar, Glow = glow, Name = name, HpFill = hpFill, HpText = hpText, Shield = shield, ShieldBox = shieldBox, Info = info }
	end

	local function addSlot(row)
		local i = #row.Slots + 1
		local slot = S.new("Frame", { Name = "Slot" .. i, BackgroundColor3 = S.C.FeltDark, BackgroundTransparency = 0.3,
			Size = UDim2.fromScale(0.3, 0.96), LayoutOrder = i, Parent = row.Field }, {
			S.corner(10),
			S.new("UIAspectRatioConstraint", { AspectRatio = CardFace.ASPECT,
				AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Height }),
		})
		S.stroke(S.C.InkSoft, 2, slot)
		S.text({ Name = "Empty", Text = "ว่าง", Font = S.Font.Heavy, Color = S.C.InkSoft, Max = 18, XAlign = "Center", Parent = slot })
		row.Slots[i] = slot
	end

	-- ===== แถวสนาม: [ช่องเกต RNG | ช่องตัวละคร 3 ช่อง | ข้อมูล] =====
	local function boardRow(parent)
		local row = { Slots = {} }
		row.Gate = S.box({ Color = S.C.FeltDark, Size = UDim2.fromScale(0.13, 1), Radius = 12, Stroke = 4, StrokeColor = Color3.new(1, 1, 1), Parent = parent })
		S.rainbow(row.Gate:FindFirstChildOfClass("UIStroke"), 90)
		S.gradient(row.Gate, { S.C.Violet, S.C.FeltDark }, 90)
		row.GateGlow = glowStroke(row.Gate)
		S.text({ Text = "เกต RNG", Font = S.Font.Heavy, Color = S.C.Text, Max = 15, XAlign = "Center", Stroke = 2,
			Size = UDim2.fromScale(1, 0.14), Parent = row.Gate })
		row.GateHint = S.text({ Text = "???", Font = S.Font.Heavy, Color = S.C.Accent, Max = 34, XAlign = "Center", Stroke = 2.5,
			Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(1, 0.82), Parent = row.Gate })
		S.pulse(row.GateHint, 0.9, 1.1, 0.9)
		row.GateSlot = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.08, 0.15),
			Size = UDim2.fromScale(0.84, 0.82), Parent = row.Gate })
		row.Field = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.15, 0),
			Size = UDim2.fromScale(0.7, 1), Parent = parent }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		row.FieldGlow = glowStroke(row.Field)
		row.Info = S.text({ Font = S.Font.Bold, Max = 14, Color = S.C.TextDim, XAlign = "Center", Stroke = 1.5,
			Position = UDim2.fromScale(0.87, 0), Size = UDim2.fromScale(0.13, 1), Parent = parent })
		for _ = 1, Config.FIELD_SLOTS do addSlot(row) end
		return row
	end

	ui.opp = leaderBar(oppBarF, 1, S.C.Violet)
	ui.oppRow = boardRow(oppBoardF)
	ui.oppRow.FaceDown = S.box({ Color = S.C.Violet, Size = UDim2.fromScale(1, 1), AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5), Radius = 10, Stroke = 3, Rotation = -4, Parent = ui.oppRow.GateSlot })
	ui.oppRow.FaceDown.Visible = false
	S.new("UIAspectRatioConstraint", { AspectRatio = CardFace.ASPECT, Parent = ui.oppRow.FaceDown })
	S.text({ Text = "คว่ำ", Font = S.Font.Heavy, Max = 20, XAlign = "Center", Stroke = 2, Parent = ui.oppRow.FaceDown })

	-- วงซัมมอนเจมใต้ตาข่าย: อยู่หลังช่องสนามฝั่งเรา หมุนวนตลอด สว่างวาบตอนลงการ์ด
	ui.summon = S.new("Frame", { Name = "SummonCircle", BackgroundColor3 = S.C.Teal, BackgroundTransparency = 0.82,
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 1.25), Parent = myBoardF }, {
		S.corner(999), S.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
	})
	S.rainbow(S.stroke(Color3.new(1, 1, 1), 5, ui.summon), 120)
	S.spin(ui.summon, 25)
	local innerRing = S.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72), Rotation = 45, Parent = ui.summon }, { S.corner(14) })
	S.stroke(S.C.Pink, 3, innerRing).Transparency = 0.25
	S.spin(innerRing, -40)
	local function summonBurst()
		ui.summon.BackgroundTransparency = 0.25
		S.tween(ui.summon, 0.7, { BackgroundTransparency = 0.82 })
		S.bump(ui.summon, 0.3, 0.6)
	end

	ui.myRow = boardRow(myBoardF)
	ui.me = leaderBar(myBarF, 0.5, S.C.Pink)

	-- ===== ตาข่าย + ชนวนจับเวลา 2 นาที (ตรงกลางจอ) =====
	local fuse = S.box({ Color = S.C.FeltDark, Position = UDim2.fromScale(0.2, 0.25), Size = UDim2.fromScale(0.6, 0.5),
		Radius = 999, Stroke = 3, Parent = midF })
	ui.timerFill = S.new("Frame", { BackgroundColor3 = S.C.Accent, Size = UDim2.fromScale(1, 1), Parent = fuse }, { S.corner(999) })
	ui.timerBadge = S.box({ Color = S.C.Ink, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 2.3),
		Radius = 999, Stroke = 4, StrokeColor = S.C.Accent, ZIndex = 3, Parent = midF })
	S.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = ui.timerBadge })
	ui.timerStroke = ui.timerBadge:FindFirstChildOfClass("UIStroke")
	ui.fireGrad = S.rainbow(ui.timerStroke, 400)
	ui.fireGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, S.C.Bad), ColorSequenceKeypoint.new(0.5, S.C.Accent), ColorSequenceKeypoint.new(1, S.C.Orange) })
	ui.fireGrad.Enabled = false
	ui.timerText = S.text({ Font = S.Font.Heavy, Max = 30, XAlign = "Center", Color = S.C.Accent, ZIndex = 4, Parent = ui.timerBadge })

	ui.turnBox, ui.turn = S.badge({ Text = "", Color = S.C.Accent, Font = S.Font.Heavy, Max = 20, Radius = 12,
		Position = UDim2.fromScale(0, 0.05), Size = UDim2.fromScale(0.17, 0.9), Rotation = -2, Parent = midF })
	ui.log = S.text({ Font = S.Font.Bold, Color = S.C.TextDim, Max = 14, Stroke = 1.5, Position = UDim2.fromScale(0.82, 0),
		Size = UDim2.fromScale(0.08, 1), Parent = midF })

	local surrenderArmed = 0
	ui.surrender = S.button({ Text = "ยอมแพ้", Max = 14, Color = S.C.Panel, Edge = 4, Radius = 10, Pad = 3,
		Position = UDim2.fromScale(0.9, 0), Size = UDim2.fromScale(0.1, 1), Parent = midF, OnClick = function(btn)
			if os.clock() - surrenderArmed < 3 then
				surrenderArmed = 0
				btn.Text = "ยอมแพ้"
				Net.fire("Surrender")
			else
				surrenderArmed = os.clock()
				btn.Text = "ยืนยัน?"
				S.setBase(btn, S.C.Bad)
				btn.TextColor3 = S.C.Text
				task.delay(3, function()
					if os.clock() - surrenderArmed >= 2.9 then
						btn.Text = "ยอมแพ้"
						S.setBase(btn, S.C.Panel)
						btn.TextColor3 = S.C.Ink
					end
				end)
			end
		end })

	-- ===== เกจแต้ม 5 ช่องต่อเทิร์น + แต้มสะสม =====
	local gauge = S.box({ Color = S.C.FeltDark, Position = UDim2.fromScale(0.515, 0), Size = UDim2.fromScale(0.25, 1), Radius = 14, Stroke = 3, Parent = myBarF })
	S.text({ Text = "แต้ม", Font = S.Font.Heavy, Color = S.C.Lime, Max = 13, Stroke = 1.5,
		Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.5, 0.3), Parent = gauge })
	ui.bank = S.text({ Text = "", Font = S.Font.Bold, Color = S.C.Accent, Max = 12, Stroke = 1.5, XAlign = "Right",
		Position = UDim2.fromScale(0.3, 0.04), Size = UDim2.fromScale(0.4, 0.3), Parent = gauge })
	local pipRow = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.05, 0.42), Size = UDim2.fromScale(0.64, 0.46), Parent = gauge }, {
		S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0),
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ui.pips = {}
	for i = 1, Config.POINTS_PER_TURN do
		local pip = S.box({ Color = S.C.Bg, Size = UDim2.fromScale(0.17, 1), Radius = 6, Stroke = 2, StrokeColor = S.C.InkSoft, LayoutOrder = i, Parent = pipRow })
		ui.pips[i] = pip
	end
	ui.points = S.text({ Font = S.Font.Heavy, Color = S.C.Lime, Max = 34, XAlign = "Center", Stroke = 2.5,
		Position = UDim2.fromScale(0.7, 0.05), Size = UDim2.fromScale(0.28, 0.9), Parent = gauge })
	local lastPoints = nil
	local function setPoints(pts)
		local perTurn = Config.POINTS_PER_TURN
		for i, pip in ui.pips do
			local lit = i <= pts
			pip.BackgroundColor3 = lit and S.C.Lime or S.C.Bg
			pip:FindFirstChildOfClass("UIStroke").Color = lit and S.C.Ink or S.C.InkSoft
		end
		local banked = pts - perTurn
		ui.bank.Text = banked > 0 and ("สะสม +" .. banked) or ""
		if S.setText(ui.points, pts, 0.4) and lastPoints and pts > lastPoints then
			for i = 1, math.min(pts, perTurn) do task.delay((i - 1) * 0.05, S.bump, ui.pips[i], 0.4) end
		end
		lastPoints = pts
	end

	ui.endBtn = S.button({ Text = "จบเทิร์น", Max = 22, Color = S.C.Accent, TextColor = S.C.Ink, Edge = 6, Radius = 14,
		Position = UDim2.fromScale(0.78, 0), Size = UDim2.fromScale(0.22, 1), Parent = myBarF,
		Debounce = 0.6, OnClick = function() endTurn() end })

	-- การ์ดในมือ: HandFan เป็นคนจัดตำแหน่ง/มุม (ไม่ใช้ UIListLayout)
	ui.hand = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = handF })

	-- ===== หน้าผลแมตช์ =====
	local result = S.new("Frame", { Name = "MatchResult", BackgroundColor3 = S.C.Bg, BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1), Visible = false, Active = true, ZIndex = 30, Parent = overlay })
	local rbox = S.box({ Color = S.C.Panel, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.4),
		Radius = 20, Stroke = 5, Rotation = -1.5, ZIndex = 31, Parent = result })
	S.new("UISizeConstraint", { MinSize = Vector2.new(300, 220), MaxSize = Vector2.new(500, 330), Parent = rbox })
	local rscale = S.new("UIScale", { Parent = rbox })
	ui.resTitle = S.text({ Font = S.Font.Heavy, Max = 56, XAlign = "Center", Stroke = 3.5, Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(0.9, 0.3), ZIndex = 32, Parent = rbox })
	ui.resReason = S.text({ Font = S.Font.Bold, Color = S.C.InkSoft, Max = 17, XAlign = "Center", Position = UDim2.fromScale(0.05, 0.38),
		Size = UDim2.fromScale(0.9, 0.13), ZIndex = 32, Parent = rbox })
	ui.resRewardBox, ui.resReward = S.badge({ Text = "", Color = S.C.Accent, Font = S.Font.Heavy, Max = 20, Radius = 12,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromScale(0.6, 0.15), Rotation = 2, ZIndex = 32, Parent = rbox })
	S.button({ Text = "กลับล็อบบี้", Color = S.C.Pink, TextColor = S.C.Text, AnchorPoint = Vector2.new(0.5, 0), Edge = 6, Radius = 14,
		Position = UDim2.fromScale(0.5, 0.73), Size = UDim2.fromScale(0.55, 0.2), ZIndex = 32, Parent = rbox,
		OnClick = function() exitMatch() end })

	local function setZoneGlow(stroke, mode)
		if not mode then stroke.Transparency = 1 return end
		stroke.Transparency = 0
		stroke.Color = mode == "hover" and S.C.Pink or S.C.Info
		stroke.Thickness = mode == "hover" and 5 or 3.5
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
		lastTurnMine = nil
		lastPoints = nil
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
					local g = CardFace.new(card, { Size = UDim2.fromOffset(96, 133) })
					g.Root.ZIndex = 50
					g.Root.Rotation = -6
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

	-- onNew(view, card) เรียกเมื่อมีการ์ดใหม่โผล่ในโซน หรือการ์ดเดิมเปลี่ยนอาวุธ (ใช้จุดวงซัมมอน)
	local function syncZone(container, list, viewMap, isHand, onNew)
		local alive = {}
		for i, c in list or {} do
			local uid = c.Uid
			alive[uid] = true
			local v = viewMap[uid]
			if not v then
				v = CardFace.new(c, isHand and { Size = UDim2.fromScale(0.16, 0.92) } or {})
				v.Root.LayoutOrder = i
				v.Root.Parent = container
				if isHand then bindHand(v, c) else bindField(v, c) end
				v:PopIn()
				viewMap[uid] = v
				if onNew then onNew(v, c) end
			else
				local weaponChanged = v.Card and v.Card.WeaponName ~= c.WeaponName
				v.Root.LayoutOrder = i
				v:Update(c)
				if weaponChanged and onNew then onNew(v, c) end
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

		-- ป้ายเปลี่ยนเทิร์น
		if lastTurnMine ~= s.isMyTurn then
			if isNewMatch then
				S.banner("สู้!", S.C.Pink, 0.9)
			else
				S.banner(s.isMyTurn and "ตาคุณแล้ว!" or "ตาคู่แข่ง", s.isMyTurn and S.C.Accent or S.C.Violet, 0.9)
			end
			lastTurnMine = s.isMyTurn
		end

		ui.turn.Text = if s.isMyTurn then "ตาคุณ" else "ตาคู่แข่ง"
		ui.turnBox.BackgroundColor3 = s.isMyTurn and S.C.Accent or S.C.Violet
		ui.turn.TextColor3 = s.isMyTurn and S.C.Ink or S.C.Text
		local pts = s.myPoints or 0
		setPoints(pts)
		ui.endBtn:SetAttribute("Disabled", not s.isMyTurn)
		ui.endBtn.Text = (s.isMyTurn and pts > 0) and ("ข้ามเทิร์น\nเก็บ " .. pts .. " แต้ม") or "จบเทิร์น"

		ui.me.Name.Text = s.myLeader
		if S.setText(ui.me.HpText, s.myHP, 0.4) then S.wobble(ui.me.Frame, 0.4) end
		S.tween(ui.me.HpFill, 0.3, { Size = UDim2.fromScale(math.clamp(s.myHP / Config.LEADER_HP, 0, 1), 1) })
		ui.me.ShieldBox.Visible = (s.myShield or 0) > 0
		ui.me.Shield.Text = "โล่ " .. tostring(s.myShield or 0)
		ui.me.Info.Text = ("กอง %d | สุสาน %d"):format(s.myDeck, s.myGrave)

		ui.opp.Name.Text = s.oppLeader
		if S.setText(ui.opp.HpText, s.oppHP, 0.4) then S.wobble(ui.opp.Frame, 0.4) end
		S.tween(ui.opp.HpFill, 0.3, { Size = UDim2.fromScale(math.clamp(s.oppHP / Config.LEADER_HP, 0, 1), 1) })
		ui.opp.ShieldBox.Visible = (s.oppShield or 0) > 0
		ui.opp.Shield.Text = "โล่ " .. tostring(s.oppShield or 0)
		ui.opp.Info.Text = ("มือ %d | กอง %d"):format(s.oppHandCount, s.oppDeck)

		syncZone(ui.hand, s.myHand, views.hand, true)
		HandFan.Layout(ui.hand, views.hand)
		syncZone(ui.myRow.Field, s.myField, views.myField, false, summonBurst)
		syncZone(ui.oppRow.Field, s.oppField, views.oppField, false)

		-- ช่องเกต
		ui.myRow.GateSlot:ClearAllChildren()
		views.myGate = nil
		ui.myRow.GateHint.Visible = not s.myGate
		if s.myGate then
			local v = CardFace.new(s.myGate, {})
			v.Root.Parent = ui.myRow.GateSlot
			views.myGate = v
		end
		ui.oppRow.FaceDown.Visible = s.oppGateFilled
		ui.oppRow.GateHint.Visible = not s.oppGateFilled

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
		if typeof(card) ~= "table" then return end
		task.spawn(GateRoller.Play, overlay, card, outcome, mine)
	end)

	Net.on("MatchEnded", function(won, reason, id, reward)
		if id ~= matchId and matchId ~= nil then return end
		ended = true
		ui.resTitle.Text = won and "ชนะแล้ว!" or "แพ้แล้ว!"
		ui.resTitle.TextColor3 = won and S.C.Good or S.C.Bad
		ui.resReason.Text = reasonText(reason, won)
		local hasReward = reward and reward > 0
		ui.resRewardBox.Visible = hasReward and true or false
		ui.resReward.Text = hasReward and ("+" .. reward .. " เพชร") or ""
		result.Visible = true
		rscale.Scale = 0.4
		S.tween(rscale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		if won then S.confetti(result, nil, 50) end
	end)

	Net.on("Notify", function(text, color)
		S.toast(text, color == "Red" and "bad" or (color == "Green" and "good" or "info"))
	end)

	-- ชนวนจับเวลา: เหลือง -> ส้ม -> แดง และ 15 วิสุดท้ายป้ายเวลาลุกไฟ/สั่น
	RunService.RenderStepped:Connect(function()
		if not state or ended then return end
		local rem = math.max(0, (state.turnEndsAt or 0) - workspace:GetServerTimeNow())
		local frac = math.clamp(rem / Config.TURN_TIME, 0, 1)
		ui.timerFill.Size = UDim2.fromScale(frac, 1)
		ui.timerFill.BackgroundColor3 = frac > 0.5 and S.C.Accent or (frac > 0.2 and S.C.Orange or S.C.Bad)
		local txt = tostring(math.ceil(rem))
		local crunch = rem <= CRUNCH_TIME and rem > 0
		if ui.timerText.Text ~= txt then
			ui.timerText.Text = txt
			if crunch then S.bump(ui.timerText, 0.5) end
		end
		if crunch then
			local t = os.clock()
			ui.fireGrad.Enabled = true
			ui.timerStroke.Color = Color3.new(1, 1, 1)
			ui.timerStroke.Thickness = 6 + math.sin(t * 18) * 2
			ui.timerBadge.BackgroundColor3 = (math.floor(t * 6) % 2 == 0) and S.C.Bad or S.C.Orange
			ui.timerBadge.Rotation = math.sin(t * 28) * 5
			ui.timerText.TextColor3 = S.C.Text
		else
			ui.fireGrad.Enabled = false
			ui.timerStroke.Color = S.C.Accent
			ui.timerStroke.Thickness = 4
			ui.timerBadge.BackgroundColor3 = S.C.Ink
			ui.timerBadge.Rotation = 0
			ui.timerText.TextColor3 = S.C.Accent
		end
	end)
end

return MatchUI
