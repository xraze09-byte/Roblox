-- ServerStorage/Modules/BotAI (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local BotAI = {}
local THINK_TIME = 0.9
local rng = Random.new()

local function stillMyTurn(match, bot, token)
	return not match.ended and match.current == bot and match.turnToken == token
end

local function strongest(field, filter)
	local best
	for _, c in field do
		if (not filter or filter(c)) and (not best or c.ATK > best.ATK) then best = c end
	end
	return best
end

local function chooseBoard(me)
	local fieldFree = #me.field < Config.FIELD_SLOTS
	if me.gate == nil and (not fieldFree or rng:NextNumber() < 0.25) then return "Gate", true end
	if fieldFree then return "Field", true end
	return nil, false
end

local function chooseSpell(me, opp, card)
	local tt = Rules.TargetType(card)
	if tt == "None" then
		if card.Effect and card.Effect.Kind == "Bomb" then return nil, #opp.field > #me.field end
		return nil, true
	elseif tt == "EnemyChar" then
		local t = strongest(opp.field)
		return t and t.Uid, t ~= nil
	elseif tt == "AllyChar" then
		local t = strongest(me.field)
		return t and t.Uid, t ~= nil
	elseif tt == "Ally" then
		return "MY_LEADER", me.leaderHP <= Config.LEADER_HP - 4
	elseif tt == "Weapon" then
		local t = strongest(me.field, function(c) return c.CanAttack and not c.WeaponName end)
		if t then return t.Uid, true end
		return "LEADER", true
	end
	return nil, false
end

local function playPhase(match, bot, token)
	for _ = 1, 12 do
		if not stillMyTurn(match, bot, token) then return end
		local me = match.sides[bot]
		local opp = match:OtherSide(me)
		local hand = table.clone(me.hand)
		table.sort(hand, function(a, b) return a.Cost > b.Cost end)
		local played = false
		for _, card in hand do
			if card.Cost <= me.points then
				local target, ok
				if card.Type == "Character" then
					target, ok = chooseBoard(me)
				else
					target, ok = chooseSpell(me, opp, card)
				end
				if ok and match:PlayCard(bot, card.Uid, target) then
					played = true
					break
				end
			end
		end
		if not played then return end
		task.wait(THINK_TIME)
	end
end

local function pickTarget(attacker, opp)
	if Rules.HasTaunt(opp.field) then
		for _, c in opp.field do
			if Rules.HasKeyword(c, "Taunt") then return c.Uid end
		end
	end
	for _, c in opp.field do
		if c.HP <= attacker.ATK and c.ATK < attacker.HP then return c.Uid end
	end
	return "LEADER"
end

local function attackPhase(match, bot, token)
	local tried = {}
	for _ = 1, 12 do
		if not stillMyTurn(match, bot, token) then return end
		local me = match.sides[bot]
		local attacker
		for _, c in me.field do
			if c.CanAttack and c.ATK > 0 and not tried[c.Uid] then attacker = c break end
		end
		if not attacker then return end
		tried[attacker.Uid] = true
		match:Attack(bot, attacker.Uid, pickTarget(attacker, match:OtherSide(me)))
		task.wait(THINK_TIME)
	end
end

function BotAI.TakeTurn(match, bot, token)
	task.wait(1.5)
	local ok, err = pcall(function()
		playPhase(match, bot, token)
		attackPhase(match, bot, token)
	end)
	if not ok then warn("[BotAI] " .. tostring(err)) end
	if stillMyTurn(match, bot, token) then match:EndTurn(bot, false) end
end

return BotAI