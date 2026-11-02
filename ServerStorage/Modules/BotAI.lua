local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local BotAI = {}
local rng = Random.new()

-- match.BotLevel is set by GameServer. Tower / old "Bot" matches have none -> Medium (same as before).
local LEVELS = {
	Easy   = { Think = 1.3,  Skip = 0.3, Sloppy = 0.5, Smart = false, Bonus = 0 },
	Medium = { Think = 0.9,  Skip = 0,   Sloppy = 0,   Smart = false, Bonus = 0 },
	Hard   = { Think = 0.75, Skip = 0,   Sloppy = 0,   Smart = true,  Bonus = 0 },
	Hacker = { Think = 0.5,  Skip = 0,   Sloppy = 0,   Smart = true,  Bonus = 1 }, -- cheats: +1 point/turn
}
local function levelOf(match) return LEVELS[match.BotLevel] or LEVELS.Medium end

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
	local gateOk = me.gate == nil and #me.field < Config.FIELD_SLOTS
	local fieldOk = Rules.FieldFree(#me.field, me.gate ~= nil)
	if gateOk and (not fieldOk or rng:NextNumber() < 0.25) then return "Gate", true end
	if fieldOk then return "Field", true end
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

local function playPhase(match, bot, token, L)
	for _ = 1, 12 do
		if not stillMyTurn(match, bot, token) then return end
		if L.Skip > 0 and rng:NextNumber() < L.Skip then return end -- Easy: sometimes stops early
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
		task.wait(L.Think)
	end
end

local function pickTarget(attacker, me, opp, L)
	-- Taunt always first (Smart: the weakest taunt)
	local taunts = {}
	for _, c in opp.field do
		if Rules.HasKeyword(c, "Taunt") then table.insert(taunts, c) end
	end
	if #taunts > 0 then
		if L.Smart then table.sort(taunts, function(a, b) return a.HP < b.HP end) end
		return taunts[1].Uid
	end

	-- Easy: random swings
	if L.Sloppy > 0 and rng:NextNumber() < L.Sloppy then
		if #opp.field > 0 and rng:NextNumber() < 0.5 then
			return opp.field[rng:NextInteger(1, #opp.field)].Uid
		end
		return "LEADER"
	end

	if L.Smart then
		-- Lethal check: everything to the face if it kills
		local total = 0
		for _, c in me.field do
			if c.CanAttack and c.ATK > 0 then total += c.ATK end
		end
		if total >= opp.leaderHP then return "LEADER" end

		-- Best value trade: kill something, prefer surviving and high-ATK targets
		local best, bestScore
		for _, c in opp.field do
			if c.HP <= attacker.ATK then
				local survive = c.ATK < attacker.HP
				if survive or c.ATK >= attacker.ATK then
					local score = c.ATK * 2 + c.HP + (survive and 10 or 0)
					if not bestScore or score > bestScore then best, bestScore = c, score end
				end
			end
		end
		return best and best.Uid or "LEADER"
	end

	-- Medium (original behaviour)
	for _, c in opp.field do
		if c.HP <= attacker.ATK and c.ATK < attacker.HP then return c.Uid end
	end
	return "LEADER"
end

local function attackPhase(match, bot, token, L)
	local tried = {}
	for _ = 1, 12 do
		if not stillMyTurn(match, bot, token) then return end
		local me = match.sides[bot]
		local attacker
		for _, c in me.field do
			if c.CanAttack and c.ATK > 0 and not tried[c.Uid]
				and (not attacker or (L.Smart and c.ATK > attacker.ATK)) then
				attacker = c
			end
		end
		if not attacker then return end
		tried[attacker.Uid] = true
		match:Attack(bot, attacker.Uid, pickTarget(attacker, me, match:OtherSide(me), L))
		task.wait(L.Think)
	end
end

function BotAI.TakeTurn(match, bot, token)
	local L = levelOf(match)
	task.wait(1.5)
	local ok, err = pcall(function()
		if L.Bonus > 0 and stillMyTurn(match, bot, token) then
			local me = match.sides[bot]
			if me and me.points then
				me.points = math.min(me.points + L.Bonus, Config.MAX_BANKED_POINTS)
			end
		end
		playPhase(match, bot, token, L)
		attackPhase(match, bot, token, L)
	end)
	if not ok then warn("[BotAI] " .. tostring(err)) end
	if stillMyTurn(match, bot, token) then match:EndTurn(bot, false) end
end

return BotAI