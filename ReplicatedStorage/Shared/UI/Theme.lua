-- ReplicatedStorage/Shared/UI/Theme
-- พาเลตต์ "กาวระเบิด": ใช้ค่าเดียวกับ Style.C เพื่อให้ทุกหน้าจอสีตรงกัน
local Style = require(script.Parent:WaitForChild("Style"))
local C = Style.C

local Theme = {}

Theme.Font = Style.Font.Heavy       -- หัวเรื่อง/ตัวเลขใหญ่ (การ์ตูนอ้วน)
Theme.FontBody = Style.Font.Bold    -- เนื้อความ
Theme.FontComic = Style.Font.Comic  -- ตัวเอียงแบบคอมิก

Theme.Color = {
	Outline = C.Ink,
	Panel   = C.Panel,
	CardBg  = C.Paper,
	Table   = C.Felt,
	Yellow  = C.Accent,
	Pink    = C.Pink,
	Blue    = C.Info,
	Green   = C.Good,
	Red     = C.Bad,
	Orange  = C.Orange,
	Violet  = C.Violet,
	Gray    = Color3.fromRGB(140, 128, 160),
	Text    = C.Text,
	Ink     = C.Ink,
}

Theme.Rarity = Style.Rarity
Theme.Tier = Style.Tier

Theme.Element = {
	Sati = { Text = "สติ",  Color = Style.Element.Sati },
	Biao = { Text = "เบียว", Color = Style.Element.Biao },
	Muen = { Text = "มึน",  Color = Style.Element.Muen },
	Gawa = { Text = "กาว",  Color = Style.Element.Gawa },
}

Theme.Keyword = { Rush = "ใจร้อน", Taunt = "ตัวบัง", Necro = "ขุดศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" }

-- ผลช่องเกต (ไม่มีอีโมจิ เพราะฟอนต์การ์ตูนแสดงไม่ได้) Short = ป้ายสั้นบนวงล้อ
Theme.Gate = {
	Golden = { Text = "ร่างทองออกแสง x3",  Short = "JACKPOT x3", Color = Color3.fromRGB(255, 214, 0), Good = true },
	Pumped = { Text = "ปั่นติด x1.5",       Short = "ปั่นติด x1.5", Color = C.Good, Good = true },
	Normal = { Text = "ธรรมดา x1",         Short = "เฉยๆ x1", Color = Color3.fromRGB(220, 220, 235) },
	Droopy = { Text = "ย้วย x0.5",          Short = "ย้วย x0.5", Color = Color3.fromRGB(130, 160, 255) },
	Poop   = { Text = "กลายเป็นก้อนอึ",     Short = "เกลือ!!", Color = Color3.fromRGB(150, 92, 40) },
}
Theme.GateOrder = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }

Theme.RarityText = Style.Name.Rarity
Theme.TypeText = Style.Name.Type
-- คำอธิบายคีย์เวิร์ด (ตรงกับ Match.EnterField / CardEffects.OnEnter / CardEffects.OnDeath)
Theme.KeywordDesc = {
	Rush = "ลงสนามแล้วโจมตีได้ทันที ไม่ต้องรอเทิร์นถัดไป",
	Taunt = "ศัตรูต้องโจมตีตัวนี้ก่อน ถึงจะตีตัวอื่นหรือผู้นำได้",
	Necro = "ตอนลงสนาม: ขุดตัวละครจากสุสานของเราสุ่ม 1 ใบ กลับขึ้นมือ (ถ้ามือยังไม่เต็ม)",
	Unlucky = "ตอนตาย: โยนเหรียญ หัว = สุ่มทำดาเมจ 3 ใส่ศัตรู / ก้อย = ผู้นำเราโดนเอง 3",
	Steal = "ตอนลงสนาม: ขโมยพอยต์ที่ศัตรูดองไว้ สูงสุด 2",
}

return Theme
