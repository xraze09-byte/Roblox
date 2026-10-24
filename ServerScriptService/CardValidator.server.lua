-- ServerScriptService/CardValidator (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Cards = require(Shared.CardData)
local Decks = require(Shared.Decks)

local SPELL_KINDS = { Shield = true, Slime = true, Damage = true, Heal = true, Buff = true, Mystery = true, Bomb = true }
local TARGETS = { None = true, EnemyChar = true, AllyChar = true, Ally = true }
local ABILITIES = { Reroll = true, LuckyPoop = true, ExtraPoints = true }
local ELEMENTS = { Sati = true, Biao = true, Muen = true, Gawa = true }

local problems = 0
local function bad(msg)
	problems += 1
	warn("[CardValidator] ❌ " .. msg)
end

for id, c in Cards do
	local name = tostring(c.Name or id)
	local cost = c.Cost or 0
	if typeof(c.Cost) ~= "number" or c.Cost < 0 then bad(name .. ": ไม่มีค่าพอยต์ (Cost)") end

	if c.Type == "Character" then
		local keywords = c.Keywords or {}
		local budget = cost * 3 + 2
		local used = (c.ATK or 0) + (c.HP or 0) + #keywords * Config.KEYWORD_COST
		if used > budget then
			bad(("%s: โกง ใช้ %d/%d แต้ม"):format(name, used, budget))
		elseif used < budget then
			print(("[CardValidator] ℹ️ %s: อ่อนไป ใช้ %d/%d แต้ม"):format(name, used, budget))
		end
		if (c.HP or 0) <= 0 then bad(name .. ": HP ต้องมากกว่า 0") end
		if not ELEMENTS[c.Element] then bad(name .. ": ธาตุไม่ถูกต้อง") end
		for _, kw in keywords do
			if not Rules.Keywords[kw] then bad(name .. ": ไม่รู้จักคีย์เวิร์ด " .. tostring(kw)) end
		end
	elseif c.Type == "Spell" then
		local e = c.Effect
		if typeof(e) ~= "table" or not SPELL_KINDS[e.Kind] then
			bad(name .. ": Effect.Kind ไม่ถูกต้อง")
		else
			if not TARGETS[e.Target or "None"] then bad(name .. ": Effect.Target ไม่ถูกต้อง") end
			local value, budget = e.Value or 0, cost * 2
			if (e.Kind == "Damage" or e.Kind == "Heal") and value > budget then
				bad(("%s: แรงเกิน %d (ควร ≤ %d)"):format(name, value, budget))
			elseif e.Kind == "Buff" and value * 2 > budget then
				bad(("%s: บัฟแรงเกิน"):format(name))
			elseif e.Kind == "Shield" and (cost ~= 0 or value > 3) then
				bad(name .. ": โล่ต้องใช้ 0 พอยต์ และกันได้ไม่เกิน 3")
			end
		end
	elseif c.Type == "Weapon" then
		local budget = cost * 2 - (c.Freeze and 2 or 0)
		if (c.Bonus or 0) > budget then bad(("%s: อาวุธแรงเกิน %d (ควร ≤ %d)"):format(name, c.Bonus or 0, budget)) end
	elseif c.Type == "Leader" then
		if not ABILITIES[c.Ability] then bad(name .. ": สกิลผู้นำไม่ถูกต้อง") end
	else
		bad(name .. ": ประเภทการ์ดไม่ถูกต้อง " .. tostring(c.Type))
	end
end

local counts, shields = {}, 0
for _, id in Decks.Starter do
	local c = Cards[id]
	if not c then
		bad("เด็คเริ่มต้นมีการ์ดที่ไม่มีอยู่จริง: " .. tostring(id))
	else
		counts[c.Type] = (counts[c.Type] or 0) + 1
		if c.Effect and c.Effect.Kind == "Shield" then shields += 1 end
	end
end
for cardType, need in Config.DECK_COMPOSITION do
	if (counts[cardType] or 0) ~= need then
		bad(("เด็คเริ่มต้น: %s มี %d ใบ (ต้องมี %d)"):format(cardType, counts[cardType] or 0, need))
	end
end
if shields > Config.MAX_SHIELDS_IN_DECK then bad("เด็คเริ่มต้นมีโล่เกิน " .. Config.MAX_SHIELDS_IN_DECK .. " ใบ") end
for _, id in Decks.Leaders do
	if not (Cards[id] and Cards[id].Type == "Leader") then bad("ผู้นำไม่ถูกต้อง: " .. tostring(id)) end
end

if problems == 0 then
	print("[CardValidator] ✅ การ์ดและเด็คถูกต้องทั้งหมด")
else
	warn(("[CardValidator] เจอปัญหา %d จุด แก้ก่อนเปิดเกม"):format(problems))
end
