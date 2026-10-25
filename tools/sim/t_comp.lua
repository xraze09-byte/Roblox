MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end end
local N = 1000
local function run(label, mutate)
	local first = 0
	for g = 1, N do
		SIM_SEED, SIM_RNG_N = g * 31 + 7, 0
		H.resetCache()
		local Decks = H.load(path("ReplicatedStorage/Shared/Decks.lua"))
		local Match = H.load(path("ServerStorage/Modules/Match.lua"))
		local a, b = { IsBot = true, Name = "A" }, { IsBot = true, Name = "B" }
		local m = Match.new(a, b, Decks.Starter, Decks.Starter, "LEADER_LUNG", "LEADER_LUNG")
		local w; m.OnEnded = function(_, winner) w = winner; return {} end
		mutate(m)
		for _ = 1, 12000 do if m.ended then break end MOCK.pump(1) end
		if w == m.firstPlayer then first += 1 end
		MOCK.pump(130)
	end
	print(("%-44s first-player win rate: %.1f%%"):format(label, 100 * first / N))
end
run("baseline", function(m) m:Start() end)
-- B: second player starts with +1 card
run("second player +1 starting card", function(m)
	local orig = m.StartTurn
	m.StartTurn = function(self, p)
		if not self.firstPlayer then
			self.firstPlayer = p
			local other = self:Opponent(p)
			self:Draw(self.sides[other], 1)
			self.firstPlayer = nil
		end
		return orig(self, p)
	end
	m:Start()
end)
-- C: second player gets +2 bonus points on their first turn
run("second player +2 points on first turn", function(m)
	local orig = m.StartTurn
	m.StartTurn = function(self, p)
		if not self.firstPlayer then self.firstPlayer = p; self.sides[self:Opponent(p)].bonusPoints = 2 end
		return orig(self, p)
	end
	m:Start()
end)
-- D: first player skips their first draw
run("first player skips first-turn draw", function(m)
	local orig = m.StartTurn
	local d = m.Draw
	m.StartTurn = function(self, p)
		if not self.firstPlayer then
			self.firstPlayer = p
			local s = self.sides[p]
			local realDraw = self.Draw
			self.Draw = function(me, side, c) if side == s and not me._skipped then me._skipped = true; return false end me.Draw = realDraw; return realDraw(me, side, c) end
		end
		return orig(self, p)
	end
	m:Start()
end)
