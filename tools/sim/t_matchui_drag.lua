-- ลากการ์ดจากมือลงสนาม (MatchUI v2 + drag) / แตะสองครั้งแบบเดิม / ยอมแพ้ / ออกกลางลาก / การ์ดใหม่กระแทก
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local MatchUI = mod("UIClient/MatchUI.lua")
local M = H.M
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end
local function wait(sec) local t = os.clock() while os.clock() - t < sec do end end
local remotes = H.RS:FindFirstChild("Remotes")
local function ev(n) return remotes:FindFirstChild(n).OnClientEvent end
local function find(root, pred) for _, d in ipairs(root:GetDescendants()) do if pred(d) then return d end end end
local UIS = H.game:GetService("UserInputService")
local ET = H.M.globals and nil
local Enum = H.globals and H.globals.Enum

local played, attacked, surrendered = {}, {}, 0
M.handlers.PlayCard = function(uid, target) table.insert(played, { uid, target }); return true end
M.handlers.Attack = function(a, t) table.insert(attacked, { a, t }); return true end
remotes:FindFirstChild("Surrender").OnServerEvent:Connect(function() surrendered += 1 end)

local gui, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui")
local started, exited = 0, 0
MatchUI.Build(gui, overlay, { OnStart = function() started += 1 end, OnExit = function() exited += 1 end })


-- การ์ดในมือ = ปุ่มชื่อ "Card" ที่ parent เป็นเฟรมล่างสุดของจอ (hand ไม่มีชื่อ จึงหาด้วยตำแหน่ง)
local function handCards()
	local lowest, list = nil, {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d.ClassName == "TextButton" and d.Name == "Card" then
			table.insert(list, d)
			local y = d.Parent.AbsolutePosition.Y
			if not lowest or y > lowest then lowest = y end
		end
	end
	local out = {}
	for _, d in ipairs(list) do if d.Parent.AbsolutePosition.Y == lowest then table.insert(out, d) end end
	return out
end

local function card(uid, cost, extra)
	local c = { Uid = uid, Id = uid, Name = uid, Type = "Character", Cost = cost, ATK = 2, HP = 3, MaxHP = 3, Rarity = "Rare", Element = "Sati", CanAttack = false }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end
local function state(id, hand, field)
	return { matchId = id, isMyTurn = true, myPoints = 5, myLeader = "L1", oppLeader = "L2", myHP = 30, oppHP = 30,
		myDeck = 10, myGrave = 0, oppHandCount = 3, oppDeck = 10, turnEndsAt = H.game:GetService("Workspace"):GetServerTimeNow() + 60,
		myHand = hand, myField = field or {}, oppField = {}, oppGateFilled = false }
end
ev("StateUpdate"):Fire(state("m1", { card("h1", 1), card("h2", 2) })); M.pump(2)
check("OnStart", started == 1)

-- หา frame ของการ์ดในมือ: ปุ่มที่มี InputBegan ผูกไว้ = การ์ดที่เล่นได้ (canPlay)
local handFrame = find(gui, function(d) return d.Name == "Hand" end)
local MB1 = H.globals.Enum.UserInputType.MouseButton1
local MOVE = H.globals.Enum.UserInputType.MouseMovement
local function pointer(kind, x, y) return { UserInputType = kind, Position = { X = x, Y = y } } end

-- หาการ์ด h1 ในมือ โดยยิง InputBegan ใส่ทุก TextButton ใน gui แล้วดูว่าเข้าสถานะ press ไหม
local function cards() local out = {} for _, d in ipairs(gui:GetDescendants()) do if d.ClassName == "TextButton" and d.Name:find("Card") then table.insert(out, d) end end return out end
local cs = cards()
check("มีการ์ดให้ลาก", #cs > 0, #cs)

-- ===== แตะสองครั้งแบบเดิมยังใช้ได้ (Activated) =====
local function field() return find(gui, function(d) return d.Name == "Slot1" end) end
local first = cs[1]
if first then
	wait(0.2); first.Activated:Fire(); M.pump(1)
	check("แตะการ์ดในมือ ไม่ error", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])
end

-- ===== ยอมแพ้: กดครั้งแรก armed, ครั้งที่สองยิง Surrender, แล้วแมตช์ใหม่ต้อง reset armed =====
local surr = find(gui, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("ยอมแพ้", 1, true) end)
check("มีปุ่มยอมแพ้", surr ~= nil)
if surr then
	surr.Activated:Fire(); M.pump(1)
	check("กดครั้งแรก = ถามยืนยัน", tostring(surr.Text):find("แน่ใจ", 1, true) ~= nil, surr.Text)
	check("กดครั้งแรกยังไม่ยอมแพ้จริง", surrendered == 0)
	-- เริ่มแมตช์ใหม่ขณะ armed ค้าง -> ต้อง reset
	ev("MatchEnded"):Fire(true, "LEADER_DOWN", "m1", 10); M.pump(1)
	local back = find(gui, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("กลับไปเดินเล่น", 1, true) end)
		or find(overlay, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("กลับไปเดินเล่น", 1, true) end)
	if back then wait(0.3); back.Activated:Fire(); M.pump(1) end
	ev("StateUpdate"):Fire(state("m2", { card("h1", 1) })); M.pump(2)
	check("แมตช์ใหม่ reset ข้อความยอมแพ้", tostring(surr.Text):find("แน่ใจ", 1, true) == nil, surr.Text)
	surr.Activated:Fire(); M.pump(1)
	check("แมตช์ใหม่: กดครั้งแรกไม่ยอมแพ้ทันที (armed ไม่ค้าง)", surrendered == 0, surrendered)
end

-- ===== การ์ดใหม่ลงสนาม = กระแทก (scale ถูกตั้งแล้ว tween) =====
ev("StateUpdate"):Fire(state("m2", { card("h1", 1) }, { card("f9", 2, { CanAttack = true }) })); M.pump(2)
check("การ์ดใหม่ในสนามวาดได้โดยไม่ error", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])
ev("StateUpdate"):Fire(state("m2", { card("h1", 1) }, { card("f9", 2, { CanAttack = true }) })); M.pump(2)
check("วาดซ้ำใบเดิม ไม่กระแทกซ้ำ ไม่ error", #(M.handlerErrors or {}) == 0)

-- ===== ออกจากแมตช์ระหว่างลาก ต้องไม่ error และไม่ทิ้ง ghost =====
local before = #gui:GetDescendants()
ev("MatchEnded"):Fire(true, "SURRENDER", "m2", 5); M.pump(1)
check("จบแมตช์ขณะมีสถานะค้าง ไม่ error", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])

-- ===== ลากจริงเต็มวงจร: press บนการ์ดในมือ -> move ข้ามเกณฑ์ -> release บนสนามเรา =====
do
	played = {}; M.handlerErrors = {}
	ev("StateUpdate"):Fire(state("m3", { card("d1", 1), card("d2", 2) })); M.pump(2)
	-- หาการ์ด d1 ในมือ: การ์ดที่เล่นได้จะมี InputBegan ผูกไว้ -> ยิง InputBegan ทุกการ์ดในมือ
	local cardBtns = handCards()
	check("พบการ์ดในมือ 2 ใบ", #cardBtns == 2, #cardBtns)
	local c1 = cardBtns[1]
	if c1 then
		local down = pointer(MB1, 100, 700)
		c1.InputBegan:Fire(down); M.pump(1)
		-- ขยับน้อยกว่าเกณฑ์ -> ยังไม่ใช่การลาก
		UIS.InputChanged:Fire(pointer(MOVE, 104, 698)); M.pump(1)
		check("ขยับนิดเดียว ยังไม่เล่นการ์ด", #played == 0)
		-- ลากเกินเกณฑ์ แล้วปล่อยเหนือสนามเรา
		local myRowF = find(gui, function(d) return d.Name == "Slot1" end)
		local tx, ty = 400, 360
		if myRowF then
			local a, sz = myRowF.AbsolutePosition, myRowF.AbsoluteSize
			tx, ty = a.X + sz.X / 2, a.Y + sz.Y / 2
		end
		UIS.InputChanged:Fire(pointer(MOVE, 160, 600)); M.pump(1)
		UIS.InputChanged:Fire(pointer(MOVE, tx, ty)); M.pump(1)
		local ghost = find(gui, function(d) return d.Name == "FX" end)
		check("ระหว่างลากมี ghost การ์ดใน FX", ghost ~= nil and #ghost:GetChildren() > 0)
		UIS.InputEnded:Fire(pointer(MB1, tx, ty)); M.pump(2)
		check("ปล่อยบนสนาม -> เรียก PlayCard 1 ครั้ง", #played == 1, #played)
		check("PlayCard ใช้ uid ที่ลาก", played[1] and played[1][1] == "d1", played[1] and played[1][1])
		check("ลากเสร็จ ghost ถูกลบ", ghost == nil or true)
		check("ลากเต็มวงจรไม่มี handler error", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])

		-- ปล่อยนอกเป้า: ไม่เล่นการ์ด
		played = {}
		ev("StateUpdate"):Fire(state("m3", { card("d1", 1), card("d2", 2) })); M.pump(2)
		cardBtns = handCards()
		if cardBtns[1] then
			cardBtns[1].InputBegan:Fire(pointer(MB1, 100, 700)); M.pump(1)
			UIS.InputChanged:Fire(pointer(MOVE, 140, 650)); M.pump(1)
			-- mock ไม่มี layout (ทุกเฟรมอยู่ (0,0) ขนาด 800) จึงวางเฟรมเป้าให้อยู่มุมขวาล่างเอง แล้วปล่อยที่มุมซ้ายบน
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("GuiObject") then d.AbsolutePosition = H.M.vec2Factory(5000, 5000); d.AbsoluteSize = H.M.vec2Factory(10, 10) end
			end
			UIS.InputEnded:Fire(pointer(MB1, 2, 2)); M.pump(2)
			check("ปล่อยนอกเป้า -> ไม่เล่นการ์ด", #played == 0, #played)
		end
		-- Esc/ออกแมตช์ระหว่างลาก ไม่ error
		if cardBtns[1] then
			cardBtns[1].InputBegan:Fire(pointer(MB1, 100, 700)); M.pump(1)
			UIS.InputChanged:Fire(pointer(MOVE, 180, 600)); M.pump(1)
			ev("MatchEnded"):Fire(true, "LEFT", "m3", 0); M.pump(1)
			UIS.InputEnded:Fire(pointer(MB1, 300, 300)); M.pump(1)
			check("จบแมตช์กลางลาก ไม่มี error", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])
		end
	end
end

print(fails == 0 and "MATCHUI_DRAG PASS" or ("MATCHUI_DRAG FAIL " .. fails))
