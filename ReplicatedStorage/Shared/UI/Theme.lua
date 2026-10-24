-- ReplicatedStorage/Shared/UI/Theme
local Theme = {}

Theme.Font = Enum.Font.FredokaOne -- ฟอนต์การ์ตูนตัวหนา (ตัวอักษรไทยจะใช้ฟอนต์สำรองของ Roblox แทน)
Theme.FontBody = Enum.Font.GothamBold

Theme.Color = {
	Outline = Color3.fromRGB(25, 20, 30),
	Panel   = Color3.fromRGB(255, 250, 235),
	CardBg  = Color3.fromRGB(255, 248, 225),
	Table   = Color3.fromRGB(60, 140, 90),
	Yellow  = Color3.fromRGB(255, 214, 10),
	Pink    = Color3.fromRGB(255, 105, 180),
	Blue    = Color3.fromRGB(80, 170, 255),
	Green   = Color3.fromRGB(90, 210, 110),
	Red     = Color3.fromRGB(255, 70, 70),
	Gray    = Color3.fromRGB(150, 150, 160),
}

Theme.Rarity = {
	Common = Color3.fromRGB(160, 160, 170),
	Rare   = Color3.fromRGB(70, 160, 255),
	Epic   = Color3.fromRGB(170, 90, 255),
	Legend = Color3.fromRGB(255, 190, 30),
	Mystic = Color3.fromRGB(255, 255, 255), -- ใช้คู่กับขอบสีรุ้งใน CardView
}

Theme.Element = {
	Sati = { Text = "สติ",  Color = Color3.fromRGB(80, 200, 255) },
	Biao = { Text = "เบียว", Color = Color3.fromRGB(255, 90, 90) },
	Muen = { Text = "มึน",  Color = Color3.fromRGB(180, 120, 255) },
	Gawa = { Text = "กาว",  Color = Color3.fromRGB(255, 200, 0) },
}

Theme.Keyword = { Rush = "ใจร้อน", Taunt = "ตัวบัง", Necro = "ขุดศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" }

Theme.Gate = {
	Golden = { Text = "✨ ร่างทองออกแสง x3 ✨", Color = Color3.fromRGB(255, 200, 0) },
	Pumped = { Text = "💪 ปั่นติด x1.5",       Color = Color3.fromRGB(90, 210, 110) },
	Normal = { Text = "😐 ธรรมดา x1",         Color = Color3.fromRGB(200, 200, 200) },
	Droopy = { Text = "😵 ย้วย x0.5",          Color = Color3.fromRGB(150, 170, 255) },
	Poop   = { Text = "💩 กลายเป็นก้อนอึ",     Color = Color3.fromRGB(140, 90, 50) },
}

return Theme