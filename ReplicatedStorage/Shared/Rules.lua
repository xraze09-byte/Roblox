-- ReplicatedStorage/Shared/Rules (ModuleScript)
local Config = require(script.Parent:WaitForChild("Config"))
local Rules = {}

Rules.Beats = { Sati = "Biao", Biao = "Muen", Muen = "Sati" }
Rules.Keywords = { Rush = true, Taunt = true, Necro = true, Unlucky = true, Steal = true }

function Rules.HasKeyword(card, kw)
	return card ~= nil and card.Keywords ~= nil and table.find(card.Keywords, kw) ~= nil
end

function Rules.HasTaunt(field)
	for _, c in field do
		if Rules.HasKeyword(c, "Taunt") then return true end
	end
	return false
end

-- Board = ตัวละคร, Weapon = สวม/ปา, None = ไม่ต้องเลือก, EnemyChar / AllyChar / Ally
function Rules.TargetType(card)
	if card.Type == "Character" then return "Board" end
	if card.Type == "Weapon" then return "Weapon" end
	return (card.Effect and card.Effect.Target) or "None"
end

function Rules.GateCost(card)
	return math.max(0, (card.Cost or 0) - Config.GATE_DISCOUNT)
end

return Rules