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

	REWARD_WIN_PVP = 30,
	REWARD_LOSE_PVP = 5,
	REWARD_WIN_BOT = 10,
	BOUNTY_PER_STREAK = 10,

	-- เด็ค: จำนวนสูงสุดต่อใบตามความหายาก (คลังเก็บได้เท่านี้ด้วย)
	MAX_COPIES = { Common = 2, Rare = 2, Epic = 1, Legend = 1, Mystic = 1 },

	-- กาชา
	GACHA_COST_1 = 50,
	GACHA_COST_10 = 450,
	GACHA_RATES = { Common = 68, Rare = 24, Epic = 7, Legend = 1 },
	GACHA_EPIC_PITY = 10,   -- ภายใน 10 ครั้งได้ Epic ขึ้นไปแน่นอน
	GACHA_LEGEND_PITY = 60,
	GACHA_DUPE_REFUND = { Common = 5, Rare = 15, Epic = 40, Legend = 100 },
}