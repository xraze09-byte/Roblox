SIM_GAMES = 500
MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local N = tonumber(SIM_GAMES) or 200
local MAXT = 12000 -- virtual seconds per game

local results = { games = 0, ended = 0, stuck = 0, reasons = {}, winsFirst = 0, winsSecond = 0, turns = 0, violations = {}, errors = {} }
local function viol(seed, msg)
	results.violations[msg] = results.violations[msg] or { n = 0, seed = seed }
	results.violations[msg].n += 1
end

for g = 1, N do
	SIM_SEED, SIM_RNG_N = g, 0
	H.resetCache()
	local Config = H.load(path("ReplicatedStorage/Shared/Config.lua"))
	local Decks = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
	local CardData = H.load(path("ReplicatedStorage/Shared/CardData.lua"))
	local Match = H.load(path("ServerStorage/Modules/Match.lua"))

	local bots = { { IsBot = true, Name = "BotA" }, { IsBot = true, Name = "BotB" } }
	local m = Match.new(bots[1], bots[2], Decks.Starter, Decks.Starter, Decks.Leaders[(g % 3) + 1], Decks.Leaders[((g + 1) % 3) + 1])
	local endedWith
	m.OnEnded = function(_, winner, reason) endedWith = { winner = winner, reason = reason }; return {} end

	local total0 = {}
	for _, b in ipairs(bots) do total0[b] = #m.sides[b].deck end

	local function check()
		for _, b in ipairs(bots) do
			local s = m.sides[b]
			if s.points < 0 then viol(g, "points < 0") end
			if s.points > Config.MAX_BANKED_POINTS then viol(g, "points > MAX_BANKED_POINTS") end
			if #s.field > Config.FIELD_SLOTS then viol(g, "field > FIELD_SLOTS") end
			if #s.hand > Config.MAX_HAND then viol(g, "hand > MAX_HAND") end
			if s.shield < 0 then viol(g, "shield < 0") end
			if s.leaderHP > Config.LEADER_HP + 0 and s.leaderHP > (s.maxHP or Config.LEADER_HP) then viol(g, "leaderHP above max (overheal)") end
			-- card conservation: deck+hand+field+graveyard+gate = initial deck size (tokens excluded by flag)
			local n = #s.deck + #s.hand + #s.field + #s.graveyard + (s.gate and 1 or 0)
			if n < total0[b] and not m.ended then viol(g, "cards lost (fewer than initial)") end
			local seen = {}
			for _, zone in ipairs({ s.deck, s.hand, s.field, s.graveyard }) do
				for _, c in ipairs(zone) do
					if seen[c.Uid] then viol(g, "duplicate Uid across zones") end
					seen[c.Uid] = true
					if zone == s.field and (c.HP or 0) <= 0 then viol(g, "dead card left on field") end
					if (c.ATK or 0) < 0 then viol(g, "negative ATK") end
				end
			end
			if s.gate then if seen[s.gate.Uid] then viol(g, "gate card also in another zone") end end
		end
	end

	local ok, err = pcall(function()
		m:Start()
		local t, lastTurn = 0, 0
		while not m.ended and t < MAXT do
			MOCK.pump(1); t += 1
			check()
		end
		check()
	end)
	if not ok then table.insert(results.errors, "seed " .. g .. ": " .. tostring(err)) end
	for _, e in ipairs(MOCK.taskErrors or {}) do table.insert(results.errors, "seed " .. g .. " task: " .. e) end
	MOCK.taskErrors = {}

	results.games += 1
	if m.ended and endedWith then
		results.ended += 1
		results.reasons[endedWith.reason] = (results.reasons[endedWith.reason] or 0) + 1
		local a, b = m.sides[bots[1]].leaderHP, m.sides[bots[2]].leaderHP
		local w = endedWith.winner
		if m.firstPlayer == w then results.winsFirst += 1 else results.winsSecond += 1 end
		if endedWith.reason == "LEADER_DOWN" or endedWith.reason == "FATIGUE" then
			local wl, ll = m.sides[w].leaderHP, m.sides[m:Opponent(w)].leaderHP
			if not (ll <= 0) then viol(g, "winner declared but loser HP > 0 (" .. endedWith.reason .. ")") end
		end
		results.turns += m.turnToken
	else
		results.stuck += 1
	end
	-- cleanup pending timers between games
	MOCK.pump(Config.TURN_TIME + 5)
end

print(("games=%d ended=%d stuck=%d  firstWins=%d secondWins=%d  avgTurnTokens=%.1f"):format(results.games, results.ended, results.stuck, results.winsFirst, results.winsSecond, results.turns / math.max(1, results.ended)))
for r, n in pairs(results.reasons) do print("  reason", r, n) end
local nv = 0
for msg, v in pairs(results.violations) do nv += 1; print(("VIOLATION x%d (first seed %d): %s"):format(v.n, v.seed, msg)) end
print("distinct violations:", nv)
local shown = {}
for _, e in ipairs(results.errors) do if not shown[e] and #shown < 8 then shown[e] = true; shown[#shown + 1] = e; print("ERR", e) end end
print("total error lines:", #results.errors)
