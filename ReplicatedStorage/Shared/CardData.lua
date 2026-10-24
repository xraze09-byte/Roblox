-- ฐานข้อมูลการ์ดทดสอบ: CardData[id] = { ... }
-- ช่องที่ UI ใช้: Name, Type, Cost, ATK, HP, Rarity, Element, Keywords, Desc, Flavor, Art, HitArt
local CardData = {
	c01 = { Name = "ลูกแมวเริ่มต้น", Type = "Character", Cost = 1, ATK = 1, HP = 2, Rarity = "Common", Element = "Sati",
		Flavor = "เหมียว... แปลว่าหิว" },
	c02 = { Name = "หนูนักสู้", Type = "Character", Cost = 2, ATK = 2, HP = 2, Rarity = "Common", Element = "Biao",
		Keywords = { "Rush" }, Flavor = "ตัวเล็กแต่ใจร้อน" },
	c03 = { Name = "หมาป่าหนุ่ม", Type = "Character", Cost = 3, ATK = 3, HP = 3, Rarity = "Rare", Element = "Muen",
		Flavor = "หอนทีไรข้างบ้านตื่น" },
	c04 = { Name = "หมีเกราะหนา", Type = "Character", Cost = 4, ATK = 3, HP = 5, Rarity = "Rare", Element = "Gawa",
		Keywords = { "Taunt" }, Flavor = "ตีเข้ามาสิ ถ้าเจ็บมือ" },
	c05 = { Name = "มังกรน้อย", Type = "Character", Cost = 5, ATK = 5, HP = 4, Rarity = "Epic", Element = "Biao",
		Flavor = "พ่นไฟได้ แต่พ่นแล้วไอ" },
	c06 = { Name = "นักรบกบ", Type = "Character", Cost = 2, ATK = 1, HP = 4, Rarity = "Common", Element = "Sati",
		Keywords = { "Taunt" }, Flavor = "กระโดดมาบังให้" },
	c07 = { Name = "ลูกไฟ", Type = "Spell", Cost = 2, Rarity = "Common", Element = "Biao",
		Desc = "ทำดาเมจใส่การ์ด 1 ใบ (ยังไม่เปิดใช้)" },
	c08 = { Name = "น้ำพุฟื้นฟู", Type = "Spell", Cost = 3, Rarity = "Rare", Element = "Sati",
		Desc = "ฟื้น HP ผู้นำ (ยังไม่เปิดใช้)" },
	c09 = { Name = "ดาบสนิม", Type = "Weapon", Cost = 1, Bonus = 2, Rarity = "Common", Element = "Gawa",
		Flavor = "สนิมเยอะ แต่ยังบาดได้" },
	c10 = { Name = "ผู้นำแห่งกาวา", Type = "Leader", Cost = 0, ATK = 0, HP = 30, Rarity = "Legend", Element = "Gawa" },
}

return CardData
