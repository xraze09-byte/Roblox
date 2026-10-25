-- ServerStorage/Modules/StatsService (ModuleScript)
-- สถิติผู้เล่น: ตลอดชีพ + รายวัน (เวลาไทย) | เก็บใน DataService profile.Data.Stats / Data.Daily
-- ทุกค่านับที่เซิร์ฟเวอร์เท่านั้น ไม่เชื่อค่าจาก client
local StatsService = {}

local DAY_OFFSET = 7 * 3600 -- "วันนี้" ตามเวลาไทย (UTC+7)
local KEEP_DAYS = 14
local MAX_TOP = 150         -- เพดานชนิดการ์ดต่อ bucket (เกมมี 27 ใบ รองรับขยายถึง 150 ใบ ข้อมูลเต็มสุดราว 20KB ต่อ bucket)

-- ───── โครงสร้างค่าเริ่มต้น (ฟิลด์ใหม่ที่ขาดจะถูกเติมให้อัตโนมัติ) ─────
-- ตัวนับทั้งหมดเป็นจำนวนเต็ม ยกเว้นที่ระบุหน่วยเป็นวินาที
local COUNTERS = {
	-- คิว
	"QueuePvP", "QueueBot", "QueueCancel", "QueueMatched", "QueueWaitSec", "QueueWaitCount",
	-- แมตช์
	"Matches", "MatchesPvP", "MatchesBot",
	"Wins", "Losses", "Draws",
	"WinsPvP", "LossesPvP", "DrawsPvP",
	"WinsBot", "LossesBot", "DrawsBot",
	"WinsGoingFirst", "MatchesGoingFirst",
	"Surrenders", "Disconnects", "AfkLosses", "OpponentLeft",
	-- เวลา (วินาที)
	"PlaySec", "WinSec", "LossSec", "LongestMatchSec", "ShortestWinSec",
	-- เทิร์น
	"Turns", "TurnsSkipped", "TurnsTimedOut", "PointsBanked",
	-- การ์ด
	"CardsPlayed", "CharactersPlayed", "SpellsPlayed", "WeaponsPlayed",
	"PlayedToField", "PlayedToGate", "PointsSpent",
	"CardsDrawn", "FatigueTurns", "FatigueDamage",
	-- ช่องเกต
	"GateRolls", "GateGolden", "GatePumped", "GateNormal", "GateDroopy", "GatePoop",
	-- การต่อสู้
	"Attacks", "AttacksAtLeader", "AttacksAtCard", "AttacksMissed",
	"DamageToLeader", "DamageToCards", "DamageTaken", "HealDone", "ShieldGained",
	"KillsMade", "CardsLost", "WeaponsEquipped", "WeaponsThrown",
	"ElementBonus", "ElementPenalty",
	-- ผลตอบแทน
	"GemsEarned", "BountyEarned", "BestGemsOneMatch",
}

local function newBucket()
	local b = { Cards = {}, Leaders = {} }
	for _, k in ipairs(COUNTERS) do b[k] = 0 end
	return b
end

local function fill(b)
	for _, k in ipairs(COUNTERS) do
		if typeof(b[k]) ~= "number" then b[k] = 0 end
	end
	if typeof(b.Cards) ~= "table" then b.Cards = {} end
	if typeof(b.Leaders) ~= "table" then b.Leaders = {} end
	return b
end

-- ───── วันที่ ─────
function StatsService.DayKey(t)
	return os.date("!%Y-%m-%d", (t or os.time()) + DAY_OFFSET)
end

-- ───── เตรียมข้อมูลในโปรไฟล์ (เรียกจาก DataService.reconcile) ─────
function StatsService.Reconcile(data)
	if typeof(data.Stats) ~= "table" then data.Stats = {} end
	fill(data.Stats)
	if typeof(data.Daily) ~= "table" then data.Daily = {} end
	for _, b in pairs(data.Daily) do fill(b) end

	-- ย้ายค่าเก่า (Wins/Losses/BestStreak ที่นับก่อนมีระบบนี้) เข้าสถิติตลอดชีพครั้งเดียว
	if not data.StatsMigrated then
		data.StatsMigrated = true
		local s = data.Stats
		s.WinsPvP = math.max(s.WinsPvP, data.Wins or 0)
		s.LossesPvP = math.max(s.LossesPvP, data.Losses or 0)
		s.Wins = math.max(s.Wins, data.Wins or 0)
		s.Losses = math.max(s.Losses, data.Losses or 0)
		s.MatchesPvP = math.max(s.MatchesPvP, s.WinsPvP + s.LossesPvP + s.DrawsPvP)
		s.Matches = math.max(s.Matches, s.MatchesPvP)
	end

	-- ตัดวันเก่า เหลือ KEEP_DAYS วันล่าสุด
	local keys = {}
	for k in pairs(data.Daily) do table.insert(keys, k) end
	table.sort(keys, function(a, b) return a > b end)
	for i = KEEP_DAYS + 1, #keys do data.Daily[keys[i]] = nil end
	return data
end

local function today(data)
	local k = StatsService.DayKey()
	local b = data.Daily[k]
	if not b then
		b = newBucket()
		data.Daily[k] = b
	end
	return b, k
end

local function bumpCard(bucket, id, field, n)
	if typeof(id) ~= "string" then return end
	local c = bucket.Cards[id]
	if not c then
		-- กันบวม: ถ้าเต็มแล้วและเป็นการ์ดใหม่ ให้ข้าม
		local count = 0
		for _ in pairs(bucket.Cards) do count = count + 1 end
		if count >= MAX_TOP then return end
		c = { Played = 0, Field = 0, Gate = 0, Kills = 0, Deaths = 0, Damage = 0 }
		bucket.Cards[id] = c
	end
	c[field] = (c[field] or 0) + (n or 1)
end

-- ───── API หลัก ─────
-- ctx: { data = profile.Data } หรือ nil ถ้าโหลดไม่เสร็จ
-- Add(data, "Wins", 1) บวกทั้งตลอดชีพและวันนี้
function StatsService.Add(data, key, n)
	if not data or not data.Stats then return end
	n = n or 1
	data.Stats[key] = (data.Stats[key] or 0) + n
	local d = today(data)
	d[key] = (d[key] or 0) + n
end

-- ตั้งค่าเป็นค่าสูงสุด (เช่น แมตช์ที่ยาวที่สุด)
function StatsService.Max(data, key, value)
	if not data or not data.Stats then return end
	if value > (data.Stats[key] or 0) then data.Stats[key] = value end
	local d = today(data)
	if value > (d[key] or 0) then d[key] = value end
end

-- ตั้งค่าเป็นค่าต่ำสุดที่ > 0 (เช่น ชนะเร็วสุด) 0 = ยังไม่มี
function StatsService.Min(data, key, value)
	if not data or not data.Stats then return end
	local cur = data.Stats[key] or 0
	if cur == 0 or value < cur then data.Stats[key] = value end
	local d = today(data)
	local dc = d[key] or 0
	if dc == 0 or value < dc then d[key] = value end
end

function StatsService.Card(data, id, field, n)
	if not data or not data.Stats then return end
	bumpCard(data.Stats, id, field, n)
	bumpCard((today(data)), id, field, n)
end

function StatsService.Leader(data, leaderId, field)
	if not data or not data.Stats or typeof(leaderId) ~= "string" then return end
	for _, b in ipairs({ data.Stats, (today(data)) }) do
		local l = b.Leaders[leaderId]
		if not l then
			l = { Matches = 0, Wins = 0, Losses = 0, Draws = 0 }
			b.Leaders[leaderId] = l
		end
		l[field] = (l[field] or 0) + 1
	end
end

-- ───── ตัวช่วยสรุปผล ─────
local function topCard(cards, field)
	local bestId, best = nil, 0
	for id, c in pairs(cards) do
		if (c[field] or 0) > best then bestId, best = id, c[field] end
	end
	return bestId, best
end

local function topLeader(leaders)
	local bestId, best = nil, 0
	for id, l in pairs(leaders) do
		if (l.Matches or 0) > best then bestId, best = id, l.Matches end
	end
	return bestId, best
end

local function rate(a, b)
	if b <= 0 then return 0 end
	return math.floor(a / b * 1000 + 0.5) / 10 -- ทศนิยม 1 ตำแหน่ง (เปอร์เซ็นต์)
end

local function derive(b)
	local decided = b.Wins + b.Losses
	local out = {
		WinRate = rate(b.Wins, decided),
		WinRatePvP = rate(b.WinsPvP, b.WinsPvP + b.LossesPvP),
		WinRateBot = rate(b.WinsBot, b.WinsBot + b.LossesBot),
		AvgMatchSec = b.Matches > 0 and math.floor(b.PlaySec / b.Matches) or 0,
		AvgQueueWaitSec = b.QueueWaitCount > 0 and math.floor(b.QueueWaitSec / b.QueueWaitCount) or 0,
		CardsPerMatch = b.Matches > 0 and math.floor(b.CardsPlayed / b.Matches * 10 + 0.5) / 10 or 0,
		GoingFirstWinRate = rate(b.WinsGoingFirst, b.MatchesGoingFirst),
		GoldenRate = rate(b.GateGolden, b.GateRolls),
		PoopRate = rate(b.GatePoop, b.GateRolls),
	}
	out.TopPlayedCard, out.TopPlayedCount = topCard(b.Cards, "Played")
	out.TopKillCard, out.TopKillCount = topCard(b.Cards, "Kills")
	out.TopLeader, out.TopLeaderMatches = topLeader(b.Leaders)
	return out
end

-- สำเนาที่ปลอดภัยส่งให้ client (ตารางล้วน ไม่มี reference กลับ)
local function export(b)
	local copy = { Cards = {}, Leaders = {} }
	for _, k in ipairs(COUNTERS) do copy[k] = b[k] or 0 end
	for id, c in pairs(b.Cards) do copy.Cards[id] = table.clone(c) end
	for id, l in pairs(b.Leaders) do copy.Leaders[id] = table.clone(l) end
	copy.Derived = derive(b)
	return copy
end

-- รวมหลายวันเป็น bucket เดียว (สำหรับ "7 วันล่าสุด")
local function merge(buckets)
	local sum = newBucket()
	for _, b in ipairs(buckets) do
		for _, k in ipairs(COUNTERS) do
			if k == "LongestMatchSec" or k == "BestGemsOneMatch" then
				sum[k] = math.max(sum[k], b[k] or 0)
			elseif k == "ShortestWinSec" then
				local v = b[k] or 0
				if v > 0 and (sum[k] == 0 or v < sum[k]) then sum[k] = v end
			else
				sum[k] = sum[k] + (b[k] or 0)
			end
		end
		for id, c in pairs(b.Cards) do
			local t = sum.Cards[id]
			if not t then
				t = { Played = 0, Field = 0, Gate = 0, Kills = 0, Deaths = 0, Damage = 0 }
				sum.Cards[id] = t
			end
			for f, v in pairs(c) do t[f] = (t[f] or 0) + v end
		end
		for id, l in pairs(b.Leaders) do
			local t = sum.Leaders[id]
			if not t then
				t = { Matches = 0, Wins = 0, Losses = 0, Draws = 0 }
				sum.Leaders[id] = t
			end
			for f, v in pairs(l) do t[f] = (t[f] or 0) + v end
		end
	end
	return sum
end

-- { Today = {...}, Week = {...}, Total = {...}, Days = {...}, DayKey = "..." }
function StatsService.Snapshot(data)
	if not data or not data.Stats then return nil end
	local dayKey = StatsService.DayKey()
	local todayBucket = data.Daily[dayKey] or newBucket()

	local week = {}
	for i = 0, 6 do
		local b = data.Daily[StatsService.DayKey(os.time() - i * 86400)]
		if b then table.insert(week, b) end
	end

	local days = {}
	for i = 6, 0, -1 do
		local k = StatsService.DayKey(os.time() - i * 86400)
		local b = data.Daily[k]
		table.insert(days, {
			Day = k,
			Matches = b and b.Matches or 0,
			Wins = b and b.Wins or 0,
			Losses = b and b.Losses or 0,
			PlaySec = b and b.PlaySec or 0,
		})
	end

	return {
		DayKey = dayKey,
		Today = export(todayBucket),
		Week = export(merge(week)),
		Total = export(data.Stats),
		Days = days,
		Streak = data.Streak or 0,
		BestStreak = data.BestStreak or 0,
	}
end

return StatsService
