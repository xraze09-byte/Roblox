local GateRNG = {}

local OUTCOMES = {
	{ id = "Golden", weight = 5,  mult = 3   },
	{ id = "Pumped", weight = 20, mult = 1.5 },
	{ id = "Normal", weight = 45, mult = 1   },
	{ id = "Droopy", weight = 20, mult = 0.5 },
	{ id = "Poop",   weight = 10, mult = 0   },
}
local rng = Random.new()

function GateRNG.Roll()
	local total = 0
	for _, o in OUTCOMES do total += o.weight end
	local r = rng:NextNumber(0, total)
	for _, o in OUTCOMES do
		r -= o.weight
		if r <= 0 then return o end
	end
	return OUTCOMES[#OUTCOMES]
end

function GateRNG.Apply(card, outcome)
	if outcome.id == "Poop" then
		card.HP, card.ATK, card.Form = 1, 0, "Poop"
	else
		card.HP = math.max(1, math.floor(card.HP * outcome.mult))
		card.ATK = math.floor(card.ATK * outcome.mult)
	end
	card.GateResult = outcome.id
end

return GateRNG