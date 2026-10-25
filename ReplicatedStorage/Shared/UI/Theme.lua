-- ReplicatedStorage/Shared/UI/Theme.lua
-- PASULOL palette: นีออนจัดจ้าน + ขอบดำหนา + เงาการ์ตูน
local Theme = {}
local rgb = Color3.fromRGB

Theme.Font     = Enum.Font.LuckiestGuy -- หัวข้อ/ตัวเลข อ้วนกลมกวนๆ
Theme.FontAlt  = Enum.Font.Bangers     -- คอมมิคเอียง (POW! / WANTED)
Theme.FontBody = Enum.Font.FredokaOne  -- เนื้อหาอ่านง่าย
Theme.FontThai = Enum.Font.GothamBlack -- ข้อความไทย (ฟอนต์คอมมิคไม่มี glyph ไทย)

Theme.Color = {
	Outline = rgb(14, 10, 24), Ink = rgb(14, 10, 24), Shadow = rgb(0, 0, 0), White = rgb(255, 255, 255),
	Panel = rgb(255, 244, 205), CardBg = rgb(255, 251, 236),
	Table = rgb(44, 18, 96), TableDark = rgb(24, 8, 56),
	Yellow = rgb(255, 228, 0), Lime = rgb(198, 255, 0), Pink = rgb(255, 36, 168),
	Blue = rgb(0, 196, 255), Green = rgb(36, 255, 122), Orange = rgb(255, 128, 0),
	Red = rgb(255, 48, 72), Purple = rgb(148, 56, 255), Gray = rgb(150, 146, 170), Brown = rgb(130, 82, 40),
}
local C = Theme.Color

function Theme.seq(...)
	local cols, kps = { ... }, {}
	for i, c in ipairs(cols) do kps[i] = ColorSequenceKeypoint.new((i - 1) / (#cols - 1), c) end
	return ColorSequence.new(kps)
end

Theme.Rarity      = { Common = rgb(175, 185, 205), Rare = C.Blue, Epic = C.Purple, Legend = C.Yellow, Mystic = C.Pink }
Theme.RarityTier  = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }
Theme.RarityLabel = { Common = "T1 ธรรมดา", Rare = "T2 แรร์", Epic = "T3 เอพิค", Legend = "T4 ตำนาน", Mystic = "T5 มิสติก" }
Theme.RarityGlow  = {
	Common = Theme.seq(Theme.Rarity.Common, Theme.Rarity.Common),
	Rare   = Theme.seq(C.Blue, C.White, C.Blue),
	Epic   = Theme.seq(C.Purple, C.Pink, C.White, C.Purple),
	Legend = Theme.seq(C.Yellow, C.Orange, C.White, C.Yellow),
	Mystic = Theme.seq(C.Pink, C.Yellow, C.Lime, C.Blue, C.Purple, C.Pink),
}

-- รูปแบบตารางเหมือนเดิม {Text, Color}: CardView / CardInspector อ่าน .Text และ .Color
Theme.Element = {
	Sati = { Text = "สติ",  Color = C.Blue },
	Biao = { Text = "เบียว", Color = C.Red },
	Muen = { Text = "มึน",  Color = C.Purple },
	Gawa = { Text = "กาว",  Color = C.Lime },
}

-- GateRoller / CardInspector อ่าน Theme.Gate[id].Text และ .Color จึงคงรูปแบบตาราง
-- (ถ้าอยากได้เฉพาะสี ใช้ Theme.GateColor[id])
Theme.GateColor = { Golden = rgb(255, 200, 0), Pumped = C.Green, Normal = C.Blue, Droopy = C.Orange, Poop = C.Brown }
Theme.GateInfo = {
	Golden = { Text = "ทองคำ!! x3",   Kind = "Win",  Emoji = "👑" },
	Pumped = { Text = "ปั๊มกล้าม x1.5", Kind = "Win",  Emoji = "💪" },
	Normal = { Text = "ปกติ... x1",    Kind = "Meh",  Emoji = "😐" },
	Droopy = { Text = "เหี่ยว x0.5",    Kind = "Fail", Emoji = "🥀" },
	Poop   = { Text = "เกลือ!! อึ!!",   Kind = "Fail", Emoji = "💩" },
}
Theme.Gate = {}
for id, info in pairs(Theme.GateInfo) do
	Theme.Gate[id] = { Text = info.Emoji .. " " .. info.Text, Color = Theme.GateColor[id], Kind = info.Kind, Emoji = info.Emoji }
end

Theme.FontTh = Theme.FontThai -- alias กันโค้ดเก่าที่เรียกชื่อสั้น

Theme.TypeColor = { Character = C.Pink, Weapon = C.Orange, Spell = C.Blue, Leader = C.Yellow }
Theme.TypeLabel = { Character = "ตัวละคร", Weapon = "อาวุธ", Spell = "สกิล", Leader = "ผู้นำ" }
-- คีย์เดิมที่ CardView / CardInspector ยังอ่านอยู่ (ห้ามลบ)
Theme.RarityText = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" }
Theme.TypeText = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" }
Theme.Keyword = { Rush = "ใจร้อน", Taunt = "ตัวบัง", Necro = "ขุดศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" }
Theme.KeywordDesc = {
	Rush = "ลงสนามแล้วโจมตีได้ทันที ไม่ต้องรอเทิร์นถัดไป",
	Taunt = "ศัตรูต้องโจมตีตัวนี้ก่อน ถึงจะตีตัวอื่นหรือผู้นำได้",
	Necro = "ตอนลงสนาม: ขุดตัวละครจากสุสานของเราสุ่ม 1 ใบ กลับขึ้นมือ (ถ้ามือยังไม่เต็ม)",
	Unlucky = "ตอนตาย: โยนเหรียญ หัว = สุ่มทำดาเมจ 3 ใส่ศัตรู / ก้อย = ผู้นำเราโดนเอง 3",
	Steal = "ตอนลงสนาม: ขโมยพอยต์ที่ศัตรูดองไว้ สูงสุด 2",
}

Theme.Stroke, Theme.ShadowOffset, Theme.Radius, Theme.Tilt = 3, 6, 14, -3
return Theme