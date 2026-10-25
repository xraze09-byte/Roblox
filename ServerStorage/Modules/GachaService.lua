local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardData = require(Shared.CardData)
local DeckRules = require(Shared.DeckRules)

local GachaService = {}
local rng = Random.new()
local ORDER = { "Legend", "Epic", "Rare", "Common" }
local TIER = { Common = 1, Rare = 2, Epic = 3, Legend = 4 }

local pool = { Common = {}, Rare = {}, Epic = {}, Legend = {} }
for id, c in CardData do
	if typeof(c) == "table" and c.Type and c.Type ~= "Leader" then
		local r = c.Rarity == "Mystic" and "Legend" or c.Rarity
		if pool[r] then table.insert(pool[r], id) end
	end
end
for _, list in pool do table.sort(list) end

local function rollRarity(pity)
	local rates = Config.GACHA_RATES
	if pity.Legend >= Config.GACHA_LEGEND_PITY then return "Legend" end
	if pity.Epic >= Config.GACHA_EPIC_PITY then
		local total = rates.Epic + rates.Legend
		return (rng:NextNumber() * total < rates.Legend) and "Legend" or "Epic"
	end
	local total = 0
	for _, r in ORDER do total += rates[r] or 0 end
	local x = rng:NextNumber() * total
	for _, r in ORDER do
		x -= rates[r] or 0
		if x < 0 then return r end
	end
	return "Common"
end

-- ถ้าระดับนั้นไม่มีการ์ด ให้ลดระดับลง (ถ้าไม่มีเลยค่อยขยับขึ้น)
local function pick(rarity)
	local start = table.find(ORDER, rarity) or #ORDER
	for i = start, #ORDER do
		local list = pool[ORDER[i]]
		if #list > 0 then return list[rng:NextInteger(1, #list)], ORDER[i] end
	end
	for i = start - 1, 1, -1 do
		local list = pool[ORDER[i]]
		if #list > 0 then return list[rng:NextInteger(1, #list)], ORDER[i] end
	end
	return nil
end

-- ทั้งหมดทำงานแบบไม่ yield จึงหักเพชรซ้ำซ้อนไม่ได้
function GachaService.Pull(data, count)
	if count ~= 1 and count ~= 10 then return false, "BAD_COUNT" end
	local cost = count == 10 and Config.GACHA_COST_10 or Config.GACHA_COST_1
	if (data.Gems or 0) < cost then return false, "NOT_ENOUGH_GEMS" end
	data.Gems -= cost

	local results, refund = {}, 0
	for _ = 1, count do
		data.Pity.Epic += 1
		data.Pity.Legend += 1
		local id, rarity = pick(rollRarity(data.Pity))
		if not id then break end
		if TIER[rarity] >= 3 then data.Pity.Epic = 0 end
		if rarity == "Legend" then data.Pity.Legend = 0 end

		local owned = data.Collection[id] or 0
		if owned >= DeckRules.MaxCopies(CardData[id]) then
			local back = Config.GACHA_DUPE_REFUND[rarity] or 0
			refund += back
			table.insert(results, { Id = id, Rarity = rarity, Refund = back })
		else
			data.Collection[id] = owned + 1
			table.insert(results, { Id = id, Rarity = rarity, New = owned == 0 })
		end
	end
	if #results == 0 then
		data.Gems += cost
		return false, "EMPTY_POOL"
	end
	data.Gems += refund
	return true, results
end

return GachaService