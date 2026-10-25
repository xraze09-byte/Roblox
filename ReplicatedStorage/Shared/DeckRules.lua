-- ReplicatedStorage/Shared/DeckRules (ModuleScript) ใช้ทั้งเซิร์ฟเวอร์และไคลเอนต์
local Shared = script.Parent
local Config = require(Shared:WaitForChild("Config"))
local CardData = require(Shared:WaitForChild("CardData"))

local DeckRules = {}
DeckRules.TypeName = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" }

DeckRules.Size = 0
for _, n in Config.DECK_COMPOSITION do DeckRules.Size += n end

function DeckRules.MaxCopies(card)
	return (card and Config.MAX_COPIES[card.Rarity]) or 1
end

function DeckRules.IsShield(card)
	return card.Type == "Spell" and typeof(card.Effect) == "table" and card.Effect.Kind == "Shield"
end

function DeckRules.Count(ids)
	local byId, byType, shields = {}, { Character = 0, Spell = 0, Weapon = 0 }, 0
	for _, id in ids do
		local c = CardData[id]
		if typeof(c) == "table" then
			byId[id] = (byId[id] or 0) + 1
			byType[c.Type] = (byType[c.Type] or 0) + 1
			if DeckRules.IsShield(c) then shields += 1 end
		end
	end
	return byId, byType, shields
end

-- คืน true หรือ false, ข้อความภาษาไทย
function DeckRules.Validate(ids, collection)
	if typeof(ids) ~= "table" then return false, "ข้อมูลเด็คไม่ถูกต้อง" end
	local n = #ids
	if n ~= DeckRules.Size then
		return false, ("เด็คต้องมี %d ใบ (ตอนนี้ %d)"):format(DeckRules.Size, n)
	end
	local keys = 0
	for _ in ids do keys += 1 end
	if keys ~= n then return false, "ข้อมูลเด็คไม่ถูกต้อง" end
	for i = 1, n do
		local id = ids[i]
		local c = typeof(id) == "string" and CardData[id]
		if typeof(c) ~= "table" or c.Type == "Leader" then return false, "มีการ์ดที่ใช้ไม่ได้ในเด็ค" end
	end
	local byId, byType, shields = DeckRules.Count(ids)
	for id, count in byId do
		local c = CardData[id]
		local cap = DeckRules.MaxCopies(c)
		if count > cap then return false, ("%s ใส่ได้สูงสุด %d ใบ"):format(c.Name, cap) end
		if collection and count > (collection[id] or 0) then return false, ("มี %s ไม่พอ"):format(c.Name) end
	end
	for t, need in Config.DECK_COMPOSITION do
		if (byType[t] or 0) ~= need then
			return false, ("ต้องมี%s %d ใบ"):format(DeckRules.TypeName[t] or t, need)
		end
	end
	if shields > Config.MAX_SHIELDS_IN_DECK then
		return false, ("การ์ดโล่ใส่ได้ไม่เกิน %d ใบ"):format(Config.MAX_SHIELDS_IN_DECK)
	end
	return true
end

return DeckRules