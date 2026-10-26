-- กติกาการต่อสู้/เทิร์น v2: ธาตุ, สวนกลับ, แช่แข็ง, ดองพอยต์, ช่องเกตจองที่
MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local Rules = H.load(path("ReplicatedStorage/Shared/Rules.lua"))
local Config = H.load(path("ReplicatedStorage/Shared/Config.lua"))
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end

-- ───── Rules ล้วน ๆ ─────
check("Sati beats Biao +2", Rules.ElementBonus("Sati", "Biao") == 2)
check("Biao beats Muen +2", Rules.ElementBonus("Biao", "Muen") == 2)
check("Muen beats Sati +2", Rules.ElementBonus("Muen", "Sati") == 2)
check("Biao vs Sati 0 (loses)", Rules.ElementBonus("Biao", "Sati") == 0)
check("Gawa vs any +1 (deterministic)", Rules.ElementBonus("Gawa", "Sati") == 1 and Rules.ElementBonus("Gawa", "Muen") == 1)
check("Gawa vs Gawa 0", Rules.ElementBonus("Gawa", "Gawa") == 0)
check("nil element 0", Rules.ElementBonus(nil, "Sati") == 0 and Rules.ElementBonus("Sati", nil) == 0)
local d, c = Rules.CombatPreview({ ATK = 3, Element = "Sati" }, { ATK = 2, Element = "Biao" })
check("Preview: dmg 3+2, counter 2 (Biao loses to Sati: no counter bonus)", d == 5 and c == 2, d .. "/" .. c)
d, c = Rules.CombatPreview({ ATK = 3, Element = "Biao" }, { ATK = 2, Element = "Sati" })
check("Preview: defender with element advantage gets counter bonus", d == 3 and c == 4, d .. "/" .. c)
d, c = Rules.CombatPreview({ ATK = 3 }, { ATK = 2, Frozen = true })
check("Preview: frozen target no counter", c == 0 and d == 3)
d, c = Rules.CombatPreview({ ATK = 3 }, { ATK = 0 })
check("Preview: ATK 0 target no counter", c == 0)
check("FieldFree reserves gate slot", Rules.FieldFree(2, true) == false and Rules.FieldFree(2, false) == true and Rules.FieldFree(1, true) == true)

-- ───── Match จริง ─────
local Decks = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
local Match = H.load(path("ServerStorage/Modules/Match.lua"))
local function fresh()
	H.resetCache()
	Match = H.load(path("ServerStorage/Modules/Match.lua"))
	local Dk = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
	local a, b = { IsBot = true, Name = "A" }, { IsBot = true, Name = "B" }
	local m = Match.new(a, b, Dk.Starter, Dk.Starter, Dk.Leaders[1], Dk.Leaders[2])
	m.OnEnded = function() return {} end
	-- ไม่ start (กันบอทเล่นเอง) ตั้งสถานะมือ
	for _, p in ipairs(m.players) do m.sides[p].hand, m.sides[p].field = {}, {} end
	m.firstPlayer = a; m.current = a; m.turnToken = 1
	m.turnEndsAt = 1e9
	return m, a, b
end
local function ch(m, side, o)
	local c = Match.MakeCard("KAI_CHON")
	for k, v in pairs(o or {}) do c[k] = v end
	c.MaxHP = c.MaxHP or c.HP; c.CanAttack = true
	table.insert(side.field, c)
	return c
end

-- ธาตุกาว: ตีแล้วดาเมจคงที่ ไม่สุ่ม
do
	local seen = {}
	for i = 1, 30 do
		local m, a, b = fresh()
		local sa, sb = m.sides[a], m.sides[b]
		local at = ch(m, sa, { ATK = 3, HP = 9, Element = "Gawa" })
		local df = ch(m, sb, { ATK = 0, HP = 9, Element = "Sati" })
		m:Attack(a, at.Uid, df.Uid)
		seen[df.HP] = true
	end
	local n = 0 for _ in pairs(seen) do n += 1 end
	check("Gawa damage deterministic over 30 trials", n == 1 and seen[5] == true, n)
end

-- สวนกลับมีธาตุ + แช่แข็งสวนไม่ได้
do
	local m, a, b = fresh()
	local sa, sb = m.sides[a], m.sides[b]
	local at = ch(m, sa, { ATK = 2, HP = 10, Element = "Biao" })
	local df = ch(m, sb, { ATK = 3, HP = 10, Element = "Sati" }) -- Sati beats Biao: สวน 3+2
	m:Attack(a, at.Uid, df.Uid)
	check("counter includes element bonus", at.HP == 5, at.HP)
	local m2, a2, b2 = fresh()
	local at2 = ch(m2, m2.sides[a2], { ATK = 2, HP = 10 })
	local df2 = ch(m2, m2.sides[b2], { ATK = 4, HP = 10, Frozen = true })
	m2:Attack(a2, at2.Uid, df2.Uid)
	check("frozen defender cannot counter", at2.HP == 10 and df2.HP == 8, at2.HP .. "/" .. df2.HP)
	local m3, a3 = fresh()
	local fz = ch(m3, m3.sides[a3], { ATK = 3, HP = 5, Frozen = true })
	local ok, err = m3:Attack(a3, fz.Uid, "LEADER")
	check("frozen attacker cannot attack", ok == false and err == "CANNOT_ATTACK", err)
	local dead = ch(m3, m3.sides[a3], { ATK = 3, HP = 0 })
	local ok2, err2 = m3:Attack(a3, dead.Uid, "LEADER")
	check("HP<=0 attacker rejected", ok2 == false and err2 == "CANNOT_ATTACK", err2)
end

-- ดองพอยต์: ข้ามจริงเท่านั้น
do
	local m, a, b = fresh()
	local sa = m.sides[a]; sa.points = 5
	m:EndTurn(a)
	check("idle EndTurn banks points", sa.banking == true)
	local m2, a2 = fresh()
	local s2 = m2.sides[a2]; s2.points = 5
	local c2 = ch(m2, s2, { ATK = 2, HP = 5 })
	m2:Attack(a2, c2.Uid, "LEADER")
	m2:EndTurn(a2)
	check("attacking then EndTurn does NOT bank", s2.banking == false)
	local m3, a3 = fresh()
	local s3 = m3.sides[a3]; s3.points = 5
	local card = Match.MakeCard("KAI_CHON"); card.Cost = 1; table.insert(s3.hand, card)
	m3:PlayCard(a3, card.Uid, "Field")
	m3:EndTurn(a3)
	check("playing a card then EndTurn does NOT bank", s3.banking == false)
end

-- ช่องเกต: การ์ดเกตไม่มีทางค้าง
do
	local m, a = fresh()
	local s = m.sides[a]; s.points = 15
	local c1, c2, c3 = Match.MakeCard("KAI_CHON"), Match.MakeCard("KAI_CHON"), Match.MakeCard("KAI_CHON")
	c1.Cost, c2.Cost, c3.Cost = 1, 1, 1
	for _, c in ipairs({ c1, c2, c3 }) do table.insert(s.hand, c) end
	check("gate play ok", m:PlayCard(a, c1.Uid, "Gate") == true and s.gate ~= nil)
	check("field #1 ok", m:PlayCard(a, c2.Uid, "Field") == true)
	check("field #2 ok", m:PlayCard(a, c3.Uid, "Field") == true and #s.field == 2)
	local c4 = Match.MakeCard("KAI_CHON"); c4.Cost = 1; table.insert(s.hand, c4)
	local ok, err = m:PlayCard(a, c4.Uid, "Field")
	check("3rd field slot reserved for gate card", ok == false and err == "FIELD_FULL", err)
end

-- ผู้นำตายพร้อมกัน/เช็ก HP ไม่ crash ทั้งแมตช์บอท 200 เกม
do
	local bad = 0
	for g = 1, 200 do
		SIM_SEED, SIM_RNG_N = g, 0
		H.resetCache()
		Match = H.load(path("ServerStorage/Modules/Match.lua"))
		local Dk = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
		local m = Match.new({ IsBot = true, Name = "A" }, { IsBot = true, Name = "B" }, Dk.Starter, Dk.Starter, Dk.Leaders[(g % 3) + 1], Dk.Leaders[((g + 1) % 3) + 1])
		m.OnEnded = function() return {} end
		local ok = pcall(function() m:Start(); local t = 0 while not m.ended and t < 12000 do MOCK.pump(1) t += 1 end end)
		if not ok or not m.ended then bad += 1 end
		for _, p in ipairs(m.players) do
			if #m.sides[p].field + (m.sides[p].gate and 1 or 0) > Config.FIELD_SLOTS then bad += 1 end
		end
	end
	check("200 bot games: all end, gate+field never exceed slots", bad == 0, bad)
end
print(fails == 0 and "RULES PASS" or ("RULES FAIL " .. fails))
