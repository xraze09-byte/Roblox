-- ตรรกะหอคอย (ฝั่งเซิร์ฟเวอร์): ทำซ้ำ setup ของ GameServer บน Match จริง
MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end
local Config = H.load(path("ReplicatedStorage/Shared/Config.lua"))
local DS_SRC
for inst, info in pairs(H.sources) do if info.path == "ServerStorage/Modules/DataService.lua" then DS_SRC = info.src end end
check("DataService DEFAULT has TowerFloor = 1 (persisted)", DS_SRC:find("TowerFloor = 1", 1, true) ~= nil)
local GS_SRC
for inst, info in pairs(H.sources) do if info.path == "ServerScriptService/GameServer.server.lua" then GS_SRC = info.src end end
check("snapshot sends TowerFloor", GS_SRC:find("TowerFloor = data.TowerFloor or 1", 1, true) ~= nil)
check("startMatch runs setup before m:Start", GS_SRC:find("pcall(setup, m)", 1, true) < GS_SRC:find("pcall(m.Start, m)", 1, true))
check("BAD_MODE allows Tower", GS_SRC:find('mode ~= "Tower"', 1, true) ~= nil)

-- เลียนแบบ setup ใน GameServer
for _, floor in ipairs({ 1, 2, 5, 9, 30 }) do
	H.resetCache()
	local Match = H.load(path("ServerStorage/Modules/Match.lua"))
	local Decks = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
	local Cfg = H.load(path("ReplicatedStorage/Shared/Config.lua"))
	local p = { Name = "P", IsBot = true }
	local bot = { Name = "Boss" .. floor, IsBot = true }
	local botLeader = Decks.Leaders[(floor - 1) % #Decks.Leaders + 1]
	local m = Match.new(p, bot, Decks.Starter, Decks.Starter, Decks.Leaders[1], botLeader)
	local base = {}
	for _, c in ipairs(m.sides[bot].deck) do if c.Type == "Character" then base[c.Uid] = { c.ATK, c.HP } end end
	m.TowerFloor = floor
	local side = m.sides[bot]
	side.shield += (floor - 1) * Cfg.TOWER_SHIELD_PER_FLOOR
	local buff = math.floor((floor - 1) / Cfg.TOWER_BUFF_EVERY)
	if buff > 0 then
		for _, c in side.deck do
			if c.Type == "Character" then c.ATK += buff; c.HP += buff; c.MaxHP = c.HP end
		end
	end
	local okBuff = true
	for _, c in ipairs(side.deck) do
		if c.Type == "Character" and (c.ATK ~= base[c.Uid][1] + buff or c.HP ~= base[c.Uid][2] + buff or c.MaxHP ~= c.HP) then okBuff = false end
	end
	check(("floor %d: shield %d, buff +%d applied to all boss characters"):format(floor, side.shield, buff), okBuff and side.shield == (floor - 1) * 2)
	-- แมตช์นี้เล่นจนจบได้ (ผู้เล่น vs บอสบัฟ) ไม่ crash
	m.OnEnded = function() return {} end
	local ok = pcall(function() m:Start(); local t = 0 while not m.ended and t < 12000 do MOCK.pump(1) t += 1 end end)
	check(("floor %d: match plays to the end"):format(floor), ok and m.ended == true)
end

-- รางวัล: สูตร + ชั้นสูงสุด + ชั้นเดิมไม่ถอยหลัง
local function reward(floor) return Config.TOWER_REWARD_BASE + floor * Config.TOWER_REWARD_PER_FLOOR end
check("floor 1 reward = 15 gems", reward(1) == 15)
check("floor 30 reward = 160 gems", reward(30) == 160)
local function advance(cur, beat) if cur <= beat then return math.min(beat + 1, Config.TOWER_MAX_FLOOR + 1) end return cur end
check("beat floor 1 -> floor 2", advance(1, 1) == 2)
check("replaying cleared floor 1 doesn't go back from 5", advance(5, 1) == 5)
check("beating last floor -> MAX+1 (no overflow)", advance(30, 30) == 31)
check("Queue clamps floor to MAX (so floor 31 plays 30)", math.clamp(31, 1, Config.TOWER_MAX_FLOOR) == 30)
print(fails == 0 and "TOWER PASS" or ("TOWER FAIL " .. fails))
