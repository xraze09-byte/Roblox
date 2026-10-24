-- การ์ดทดสอบ 10 ใบ (Type: Character / Spell / Weapon / Leader)
local CardData = {}

CardData.Cards = {
	{ Id = "c01", Name = "ลูกแมวเริ่มต้น", Type = "Character", Cost = 1, ATK = 1, HP = 2 },
	{ Id = "c02", Name = "หนูนักสู้",       Type = "Character", Cost = 2, ATK = 2, HP = 2 },
	{ Id = "c03", Name = "หมาป่าหนุ่ม",     Type = "Character", Cost = 3, ATK = 3, HP = 3 },
	{ Id = "c04", Name = "หมีเกราะหนา",     Type = "Character", Cost = 4, ATK = 3, HP = 5 },
	{ Id = "c05", Name = "มังกรน้อย",       Type = "Character", Cost = 5, ATK = 5, HP = 4 },
	{ Id = "c06", Name = "นักรบกบ",         Type = "Character", Cost = 2, ATK = 1, HP = 4 },
	{ Id = "c07", Name = "ลูกไฟ",           Type = "Spell",     Cost = 2, ATK = 0, HP = 0 },
	{ Id = "c08", Name = "น้ำพุฟื้นฟู",     Type = "Spell",     Cost = 3, ATK = 0, HP = 0 },
	{ Id = "c09", Name = "ดาบสนิม",         Type = "Weapon",    Cost = 1, ATK = 2, HP = 0 },
	{ Id = "c10", Name = "ผู้นำแห่งกาวา",   Type = "Leader",    Cost = 0, ATK = 0, HP = 30 },
}

local byId = {}
for _, c in CardData.Cards do byId[c.Id] = c end

function CardData.Get(id)
	return byId[id] and table.clone(byId[id]) or nil
end

-- สร้างเด็คทดสอบ 24 ใบ (ไม่รวมผู้นำ) โดยเน้นตัวละคร
function CardData.BuildTestDeck()
	local pool = { "c01","c02","c03","c04","c05","c06","c07","c08","c09" }
	local weights = { 3,3,3,2,1,3,3,2,4 } -- รวม 24
	local deck = {}
	for i, id in pool do
		for _ = 1, weights[i] do
			table.insert(deck, CardData.Get(id))
		end
	end
	return deck
end

function CardData.GetLeader()
	return CardData.Get("c10")
end

return CardData
