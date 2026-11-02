-- ReplicatedStorage/Shared/Config (ModuleScript)
return {
	DECK_COMPOSITION = { Character = 12, Spell = 7, Weapon = 5 }, -- ตัวละคร+เวท+อาวุธ = 24 ใบ (ผู้นำเลือกแยก)
	MAX_SHIELDS_IN_DECK = 2,
	STARTING_HAND = 3,
	POINTS_PER_TURN = 5,
	MAX_BANKED_POINTS = 15,
	DRAW_PER_TURN = 2,
	FIRST_PLAYER_SKIPS_DRAW = true, -- ผู้เล่นคนแรกไม่จั่วในเทิร์นแรก (บาลานซ์: ชนะ ~70% -> ~51%)
	SECOND_PLAYER_BONUS_POINTS = 1, -- ผู้เล่นคนที่สองได้พอยต์เพิ่มในเทิร์นแรก
	MAX_HAND = 5,
	FIELD_SLOTS = 3,
	TURN_TIME = 120,
	AFK_LIMIT = 2,
	LEADER_HP = 30,
	GATE_DISCOUNT = 1,
	KEYWORD_COST = 2,

	-- หอคอย (PvE)
	TOWER_MAX_FLOOR = 30,
	TOWER_SHIELD_PER_FLOOR = 2, -- บอสได้เกราะผู้นำเพิ่มชั้นละ 2
	TOWER_BUFF_EVERY = 4,       -- ทุก 4 ชั้น ตัวละครบอส ATK/HP +1
	TOWER_REWARD_BASE = 10,
	TOWER_REWARD_PER_FLOOR = 5,

	REWARD_WIN_PVP = 30,
	REWARD_LOSE_PVP = 5,
	REWARD_WIN_BOT = 10,
	BOT_LEVELS = {
		Easy   = { Name = "หุ่นฝึกหัด",    Reward = 5 },
		Medium = { Name = "หุ่นฝึกซ้อม",   Reward = 10 },
		Hard   = { Name = "นักสู้เหล็ก",    Reward = 20 },
		Hacker = { Name = "แฮกเกอร์ 404",  Reward = 35 },
	},
	BOT_MIX_BONUS = 5,

	BOUNTY_PER_STREAK = 10,
	PVP_MIN_TURNS_FOR_REWARD = 3,
	PVP_REPEAT_WINDOW_SEC = 600,
	PVP_REPEAT_REWARD_MULT = 0.25,
	PVP_DAILY_GEM_CAP = 500,

	-- เด็ค: จำนวนสูงสุดต่อใบตามความหายาก (คลังเก็บได้เท่านี้ด้วย)
	MAX_COPIES = { Common = 2, Rare = 2, Epic = 1, Legend = 1, Mystic = 1 },

	-- กาชา
	GACHA_COST_1 = 50,
	GACHA_COST_10 = 450,
	GACHA_RATES = { Common = 68, Rare = 24, Epic = 7, Legend = 1 },
	GACHA_EPIC_PITY = 10,   -- ภายใน 10 ครั้งได้ Epic ขึ้นไปแน่นอน
	GACHA_LEGEND_PITY = 60,
	GACHA_DUPE_REFUND = { Common = 5, Rare = 15, Epic = 40, Legend = 100 },

	-- กาวการ์ด (Chaos Card Battler)
	GLUE_CARD = {
		WIN_GOLD = 100,
		LOSE_GOLD = 20,
		MIN_WIN_SECONDS = 60,
		MIN_WIN_TURNS = 6,
		MIN_LOSE_SECONDS = 30,
		SECONDS_PER_TURN = 1.5,
		MAX_TURNS = 300,
		MAX_REWARDS_PER_HOUR = 15,
	},
}