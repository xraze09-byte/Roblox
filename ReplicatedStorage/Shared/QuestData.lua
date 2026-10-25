return {
	DAILY_COUNT = 3,
	Pool = {
		{ Id = "PLAY_3",    Text = "เล่นให้ครบ 3 แมตช์",          Event = "MatchPlayed", Goal = 3,  Reward = 40 },
		{ Id = "WIN_2",     Text = "ชนะ 2 แมตช์",                 Event = "MatchWon",    Goal = 2,  Reward = 60 },
		{ Id = "PVP_WIN_1", Text = "ชนะผู้เล่นจริง 1 ครั้ง",          Event = "PvPWon",      Goal = 1,  Reward = 80 },
		{ Id = "CARDS_15",  Text = "ลงการ์ด 15 ใบ",               Event = "CardPlayed",  Goal = 15, Reward = 40 },
		{ Id = "SPELL_6",   Text = "ใช้การ์ดเวท 6 ใบ",             Event = "SpellPlayed", Goal = 6,  Reward = 40 },
		{ Id = "GATE_3",    Text = "วางการ์ดลงช่องเกต 3 ครั้ง",      Event = "GatePlayed",  Goal = 3,  Reward = 50 },
		{ Id = "ATTACK_20", Text = "สั่งโจมตี 20 ครั้ง",             Event = "Attack",      Goal = 20, Reward = 40 },
		{ Id = "PULL_1",    Text = "สุ่มกาชา 1 ครั้ง",              Event = "GachaPull",   Goal = 1,  Reward = 20 },
	},
}
