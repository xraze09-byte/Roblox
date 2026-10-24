-- ReplicatedStorage/Shared/CardData (ModuleScript)
-- ใส่ Art = "rbxassetid://..." หลังอัปโหลดภาพ (ถ้าไม่ใส่จะแสดงอีโมจิแทน)
local Config = require(script.Parent:WaitForChild("Config"))

local function char(name, cost, atk, hp, element, rarity, keywords, flavor)
	return { Name = name, Type = "Character", Cost = cost, ATK = atk, HP = hp, Element = element,
		Rarity = rarity, Keywords = keywords or {}, Flavor = flavor }
end
local function spell(name, cost, rarity, effect, desc, flavor)
	return { Name = name, Type = "Spell", Cost = cost, Rarity = rarity, Effect = effect, Desc = desc, Flavor = flavor }
end
local function weapon(name, cost, rarity, bonus, freeze, desc, flavor)
	return { Name = name, Type = "Weapon", Cost = cost, Rarity = rarity, Bonus = bonus, Durability = 2,
		Freeze = freeze or nil, Desc = desc, Flavor = flavor }
end
local function leader(name, ability, desc, flavor)
	return { Name = name, Type = "Leader", Cost = 0, ATK = 0, HP = Config.LEADER_HP, Rarity = "Legend",
		Ability = ability, Desc = desc, Flavor = flavor }
end

return {
	-- ตัวละคร (ATK + HP + คีย์เวิร์ด×2 = พอยต์×3 + 2)
	KAI_CHON     = char("ไก่ชนเดือด", 1, 2, 3, "Muen", "Common", nil, "ขันตีสี่ทุกวัน ไม่สนว่าใครจะนอน"),
	MAEW_SOM     = char("แมวส้มนักเลง", 1, 2, 1, "Biao", "Common", { "Rush" }, "แมวส้มทุกตัวใช้สมองร่วมกันหนึ่งก้อน"),
	LOOKCHIN     = char("ลูกชิ้นกลิ้งได้", 2, 3, 5, "Sati", "Common", nil, "หลุดจากไม้แล้วไม่เคยหันหลังกลับ"),
	PA_MOUTH     = char("ป้าข้างบ้านเม้าท์มอย", 2, 1, 5, "Sati", "Rare", { "Taunt" }, "รู้ทุกเรื่องในซอย ยกเว้นเรื่องตัวเอง"),
	PILLOW_THIEF = char("จอมโจรขโมยหมอน", 2, 3, 3, "Muen", "Rare", { "Steal" }, "ขโมยได้ทุกอย่าง ยกเว้นเวลานอน"),
	BIAO_KID     = char("เด็กเบียวตาซ้ายเรืองแสง", 3, 6, 5, "Biao", "Rare", nil, "ผนึกพลังไว้ในผ้าพันแผล (จริงๆ แค่ตาแดง)"),
	WIN_MOTO     = char("วินมอไซค์สายฟ้า", 3, 5, 4, "Muen", "Rare", { "Rush" }, "ซอยแคบแค่ไหนก็แซงได้"),
	GUARD        = char("ยามหน้าหมู่บ้าน", 3, 2, 7, "Sati", "Common", { "Taunt" }, "หลับตาแต่ไม่ได้หลับ (หลับ)"),
	TEACHER      = char("ครูฝ่ายปกครองไม้เรียว", 4, 5, 7, "Sati", "Epic", { "Necro" }, "เรียกชื่อเต็มเมื่อไหร่ ศพยังต้องลุก"),
	KARAOKE      = char("นักร้องคาราโอเกะเสียงหลง", 4, 6, 6, "Muen", "Epic", { "Unlucky" }, "ร้องผิดคีย์ทั้งเพลง แต่มั่นใจเต็มร้อย"),
	MOOKATA      = char("หมูกระทะเดือดพล่าน", 5, 9, 8, "Gawa", "Rare", nil, "เติมน้ำซุปไม่ทัน ก็ไหม้ทั้งกระทะ"),
	SOMTAM_KING  = char("ราชาส้มตำปูม้า", 8, 11, 11, "Gawa", "Legend", { "Rush", "Taunt" }, "เผ็ดสิบเม็ด ไม่ใส่ก็ร้องไห้"),

	-- เวท
	SHIELD_POT  = spell("โล่ฝาหม้อ", 0, "Common", { Kind = "Shield", Value = 3, Target = "None" }, "กันดาเมจที่เข้าผู้นำ 3", "กันได้ทุกอย่าง ยกเว้นเสียงบ่น"),
	SLIME       = spell("สไลม์ลื่น", 1, "Common", { Kind = "Slime", Target = "EnemyChar" }, "ศัตรู 1 ตัว ตีพลาด 50% ครั้งหน้า", "ใครทำหกไว้ตรงนี้!"),
	SLAP        = spell("ตบหน้าบิด", 2, "Common", { Kind = "Damage", Value = 4, Target = "EnemyChar" }, "ดาเมจ 4 ใส่ตัวละครศัตรู", "เพี๊ยะ!"),
	BALM        = spell("ยาหม่องวิเศษ", 2, "Common", { Kind = "Heal", Value = 4, Target = "Ally" }, "ฮีล 4 ให้ผู้นำหรือตัวละครเรา", "ทาได้ทุกโรค ยกเว้นขี้เกียจ"),
	MYSTERY_BOX = spell("กล่องสุ่มปริศนา", 2, "Rare", { Kind = "Mystery", Value = 6, Target = "None" }, "สุ่ม: ดาเมจ 6 / จั่ว 2 / ไม่มีอะไร", "เขย่าแล้วมีเสียงหัวเราะ"),
	MOM_CALL    = spell("ปลุกด้วยเสียงแม่", 3, "Rare", { Kind = "Buff", Value = 3, Target = "AllyChar" }, "ตัวละครเรา ATK +3 HP +3", "ตื่นได้แล้ว! เจ็ดโมงแล้ว!"),
	RICE_BOMB   = spell("ระเบิดหม้อหุงข้าว", 5, "Epic", { Kind = "Bomb", Value = 5, Delay = 2, Target = "None" }, "อีก 2 เทิร์น ดาเมจ 5 ทุกตัวในสนาม", "ลืมกดอุ่น เลยกดระเบิดแทน"),

	-- อาวุธ (สวมใช้ตีได้ 2 ครั้ง)
	SLIPPER         = weapon("รองเท้าแตะคู่ใจ", 1, "Common", 2, false, "สวม: ATK +2 / ปา: ดาเมจ 2", "อาวุธประจำตระกูลแม่ทุกบ้าน"),
	BROOM           = weapon("ไม้กวาดทางมะพร้าว", 2, "Common", 4, false, "สวม: ATK +4 / ปา: ดาเมจ 4", "กวาดบ้านก็ได้ กวาดศัตรูก็ดี"),
	SPATULA         = weapon("ตะหลิวป้า", 3, "Rare", 6, false, "สวม: ATK +6 / ปา: ดาเมจ 6", "ผ่านการผัดกะเพรามาหมื่นจาน"),
	FROZEN_FISH     = weapon("ปลาทูแช่แข็ง", 3, "Rare", 4, true, "ATK +4 / ดาเมจ 4 + แช่แข็ง", "แข็งกว่าใจแฟนเก่า"),
	BROKEN_UMBRELLA = weapon("ร่มเทพเจ้า (ร่มหัก)", 4, "Epic", 8, false, "สวม: ATK +8 / ปา: ดาเมจ 8", "หักตั้งแต่ซื้อ แต่ยังศักดิ์สิทธิ์"),

	-- ผู้นำ
	LEADER_LUNG = leader("ลุงกาวผู้ยิ่งใหญ่", "Reroll", "เกตออกย้วย/อึครั้งแรก สุ่มใหม่ให้ 1 ครั้ง", "กาวมาตั้งแต่ยุคเทปคาสเซ็ต"),
	LEADER_PA   = leader("ป้าดวงเฮง", "LuckyPoop", "เกตออกก้อนอึครั้งแรก เปลี่ยนเป็นธรรมดา", "เดินตกท่อทีไร เจอแบงก์ร้อยทุกที"),
	LEADER_KID  = leader("เด็กหลังห้อง", "ExtraPoints", "เทิร์นแรกได้พอยต์เพิ่ม 2", "หลับทั้งคาบ แต่ตื่นทันเช็กชื่อ"),
}