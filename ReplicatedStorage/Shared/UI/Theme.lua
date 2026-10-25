-- ReplicatedStorage/Shared/UI/Theme
-- พาเลตการ์ตูนสายปั่น: สีจัด คอนทราสต์สูง ขอบดำหนา (PASULOL-style)
local Theme = {}

Theme.Font = Enum.Font.LuckiestGuy      -- หัวเรื่อง / ตัวเลขใหญ่ (ไทยจะ fallback เป็นฟอนต์สำรองของ Roblox)
Theme.FontBody = Enum.Font.FredokaOne   -- เนื้อหา ตัวหนา มน กวนๆ
Theme.FontShout = Enum.Font.Bangers     -- ตะโกน! ป้ายคอมบ้อ แบนเนอร์

Theme.Color = {
	Outline = Color3.fromRGB(18, 10, 28),     -- เส้นขอบการ์ตูน
	Panel   = Color3.fromRGB(255, 247, 214),  -- กระดาษครีม
	CardBg  = Color3.fromRGB(255, 250, 230),
	Table   = Color3.fromRGB(28, 170, 120),   -- สนามเขียวสด
	Yellow  = Color3.fromRGB(255, 236, 40),   -- เหลืองมะนาวเปรี้ยว
	Pink    = Color3.fromRGB(255, 56, 170),   -- ชมพูบานเย็น
	Blue    = Color3.fromRGB(50, 200, 255),   -- ฟ้าสด
	Green   = Color3.fromRGB(96, 255, 110),   -- เขียวสะท้อนแสง
	Red     = Color3.fromRGB(255, 60, 80),
	Orange  = Color3.fromRGB(255, 140, 20),
	Purple  = Color3.fromRGB(150, 70, 255),
	Gray    = Color3.fromRGB(150, 150, 160),
	Ink     = Color3.fromRGB(18, 10, 28),
	Bg      = Color3.fromRGB(40, 12, 80),     -- พื้นหลังม่วงเข้ม ทำให้นีออนเด้ง
}

Theme.Rarity = {
	Common = Color3.fromRGB(190, 200, 215),
	Rare   = Color3.fromRGB(50, 200, 255),
	Epic   = Color3.fromRGB(190, 80, 255),
	Legend = Color3.fromRGB(255, 200, 20),
	Mystic = Color3.fromRGB(255, 70, 190), -- ใช้คู่กับขอบสีรุ้งใน CardView
}
-- เทียร์แสดงบนป้ายการ์ด (Tier 1 = ธรรมดา ... Tier 5 = ลึกลับ)
Theme.Tier = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Mystic = 5 }

Theme.Element = {
	Sati = { Text = "สติ",  Color = Color3.fromRGB(50, 200, 255) },
	Biao = { Text = "เบียว", Color = Color3.fromRGB(255, 70, 90) },
	Muen = { Text = "มึน",  Color = Color3.fromRGB(190, 110, 255) },
	Gawa = { Text = "กาว",  Color = Color3.fromRGB(255, 220, 0) },
}

Theme.Keyword = { Rush = "ใจร้อน", Taunt = "ตัวบัง", Necro = "ขุดศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" }

Theme.Gate = {
	Golden = { Text = "ร่างทองออกแสง x3", Color = Color3.fromRGB(255, 210, 0) },
	Pumped = { Text = "ปั่นติด x1.5",     Color = Color3.fromRGB(96, 255, 110) },
	Normal = { Text = "ธรรมดา x1",        Color = Color3.fromRGB(220, 220, 230) },
	Droopy = { Text = "ย้วย x0.5",        Color = Color3.fromRGB(140, 170, 255) },
	Poop   = { Text = "กลายเป็นก้อนอึ",   Color = Color3.fromRGB(150, 95, 50) },
}

Theme.RarityText = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" }
Theme.TypeText = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" }
-- คำอธิบายคีย์เวิร์ด (ตรงกับ Match.EnterField / CardEffects.OnEnter / CardEffects.OnDeath)
Theme.KeywordDesc = {
	Rush = "ลงสนามแล้วโจมตีได้ทันที ไม่ต้องรอเทิร์นถัดไป",
	Taunt = "ศัตรูต้องโจมตีตัวนี้ก่อน ถึงจะตีตัวอื่นหรือผู้นำได้",
	Necro = "ตอนลงสนาม: ขุดตัวละครจากสุสานของเราสุ่ม 1 ใบ กลับขึ้นมือ (ถ้ามือยังไม่เต็ม)",
	Unlucky = "ตอนตาย: โยนเหรียญ หัว = สุ่มทำดาเมจ 3 ใส่ศัตรู / ก้อย = ผู้นำเราโดนเอง 3",
	Steal = "ตอนลงสนาม: ขโมยพอยต์ที่ศัตรูดองไว้ สูงสุด 2",
}

return Theme
