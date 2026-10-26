MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 21, 0
local store = {}
local DSS = H.game:GetService("DataStoreService")
rawset(DSS, "GetDataStore", function() return {
	GetAsync = function(_, k) return store[k] end,
	UpdateAsync = function(_, k, fn) store[k] = fn(store[k]); return store[k] end,
	SetAsync = function(_, k, v) store[k] = v end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local function mk(name, uid)
	local p = H.newInstance("Player"); p.Name = name; p.UserId = uid; p.DisplayName = name; p.Parent = Players
	local ch = H.newInstance("Model"); local hum = H.newInstance("Humanoid"); hum.Parent = ch; p.Character = ch
	rawset(p, "Kick", function(self, why) rawset(self, "_kicked", why) end)
	return p
end
local MatchMod = H.load(path("ServerStorage/Modules/Match.lua"))
local rig = nil
ALLM = {}
local origStart0 = MatchMod.Start
MatchMod.Start = function(self) ALLM[#ALLM + 1] = self; origStart0(self); if rig then rig(self) end end
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
local problems, ok_n = {}, 0
local function bad(m) problems[#problems + 1] = m end

-- capture everything sent to each client
local inbox = {}
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(_, plr, ...) inbox[plr] = inbox[plr] or {}; table.insert(inbox[plr], { n, ... }) end)
end
local function call(name, plr, ...)
	MOCK.pump(1.2)
	return R[name].OnServerInvoke(plr, ...)
end
local function last(plr, name) local t = inbox[plr] or {}; for i = #t, 1, -1 do if t[i][1] == name then return t[i] end end end
local function count(plr, name) local c = 0; for _, e in ipairs(inbox[plr] or {}) do if e[1] == name then c += 1 end end return c end

local function join(name, uid) local p = mk(name, uid); Players.PlayerAdded:Fire(p); MOCK.pump(2); return p end

-- play a whole match as a human against whatever opponent: greedy legal moves through REAL remotes
local function playOut(plr, label, maxSteps)
	local ended = false
	local steps, guard = 0, 0
	while steps < (maxSteps or 800) do
		steps += 1
		MOCK.pump(0.4)
		if last(plr, "MatchEnded") and count(plr, "MatchEnded") > (plr._endedSeen or 0) then ended = true break end
		local st = last(plr, "StateUpdate"); st = st and st[2]
		if st and st.isMyTurn then
			-- snapshot sanity on EVERY state the client would render
			if st.myPoints < 0 then bad(label .. ": client got negative points") end
			if #st.myField > 3 then bad(label .. ": client got >3 field cards") end
			if #st.myHand > 5 then bad(label .. ": client got >5 hand cards") end
			if st.myHP == nil or st.oppHP == nil then bad(label .. ": missing HP in state") end
			-- try to play affordable cards
			for _, c in ipairs(table.clone(st.myHand)) do
				if c.Cost <= st.myPoints and c.Type == "Character" and #st.myField < 3 then
					local ok, why = R.PlayCard.OnServerInvoke(plr, c.Uid, "Field")
					if ok then break end
				end
			end
			st = last(plr, "StateUpdate")[2]
			for _, f in ipairs(table.clone(st.myField)) do
				if f.CanAttack and f.ATK > 0 then
					local tgt = "LEADER"
					for _, e in ipairs(st.oppField) do tgt = e.Uid break end
					R.Attack.OnServerInvoke(plr, f.Uid, tgt)
					MOCK.pump(0.15)
				end
			end
			R.EndTurn.OnServerEvent:Fire(plr)
			MOCK.pump(0.3)
		end
	end
	plr._endedSeen = count(plr, "MatchEnded")
	return ended
end

local function scenario(name, fn)
	local before = #problems
	local okc, err = pcall(fn)
	if not okc then bad(name .. ": CRASH " .. tostring(err)) end
	for _, e in ipairs(MOCK.taskErrors or {}) do bad(name .. ": task error " .. e) end
	MOCK.taskErrors = {}
	for _, e in ipairs(MOCK.handlerErrors or {}) do bad(name .. ": handler error " .. e) end
	MOCK.handlerErrors = {}
	print((#problems == before and "ok   " or "FAIL ") .. name)
end

local A = join("Alice", 1)
scenario("profile loads with starter collection + 24-card deck", function()
	local pr = call('GetProfile', A)
	if not pr then bad("GetProfile nil") return end
	local n = 0; for _ in pairs(pr.Deck) do n += 1 end
	if n ~= 24 then bad("deck size " .. n) end
	if (pr.Gems or -1) < 0 then bad("gems < 0") end
end)

scenario("Bot match: start -> play -> end -> rewards", function()
	local gems0 = call('GetProfile', A).Gems
	MOCK.pump(1)
	local ok, why = call('Queue', A, "Bot", "LEADER_LUNG")
	if not ok or why ~= "STARTED" then bad("queue Bot -> " .. tostring(ok) .. "," .. tostring(why)) return end
	MOCK.pump(1)
	if not last(A, "StateUpdate") then bad("no StateUpdate after STARTED") return end
	local ended = playOut(A, "bot", 900)
	if not ended then bad("bot match never ended") return end
	local me = last(A, "MatchEnded")
	MOCK.pump(1)
	local gems1 = call('GetProfile', A).Gems
	print("      result won=" .. tostring(me[2]) .. " reason=" .. tostring(me[3]) .. " reward=" .. tostring(me[5]) .. " gems " .. gems0 .. "->" .. gems1)
	if me[2] and gems1 <= gems0 then bad("won but gems did not increase") end
end)

scenario("second Bot match right after (no stuck state)", function()
	MOCK.pump(3)
	local ok, why = call('Queue', A, "Bot", "LEADER_PA")
	if not ok then bad("2nd queue refused: " .. tostring(why)) return end
	if not playOut(A, "bot2", 900) then bad("2nd match never ended") end
end)

scenario("Tower match", function()
	MOCK.pump(3)
	local ok, why = call('Queue', A, "Tower", "LEADER_KID")
	if not ok then bad("tower queue: " .. tostring(why)) return end
	if not playOut(A, "tower", 900) then bad("tower never ended") end
	local pr = call('GetProfile', A)
	print("      TowerFloor now " .. tostring(pr.TowerFloor))
end)

scenario("surrender ends match and frees player", function()
	MOCK.pump(3)
	local ok = call('Queue', A, "Bot", "LEADER_LUNG")
	if not ok then bad("queue") return end
	MOCK.pump(2)
	R.Surrender.OnServerEvent:Fire(A); MOCK.pump(1)
	local me = last(A, "MatchEnded")
	if not me or me[3] ~= "SURRENDER" then bad("no SURRENDER MatchEnded") end
	MOCK.pump(3)
	local ok2, why2 = call('Queue', A, "Bot", "LEADER_LUNG")
	if not ok2 then bad("cannot queue after surrender: " .. tostring(why2)) end
	R.Surrender.OnServerEvent:Fire(A); MOCK.pump(1)
end)

scenario("PvP: two players matched, both get state, one surrenders", function()
	local B = join("Bob", 2)
	MOCK.pump(3)
	local ok1, w1 = call('Queue', A, "PvP", "LEADER_LUNG")
	local ok2, w2 = call('Queue', B, "PvP", "LEADER_PA")
	if w1 ~= "WAITING" or w2 ~= "STARTED" then bad("pvp pairing: " .. tostring(w1) .. "/" .. tostring(w2)) return end
	MOCK.pump(2)
	local sa, sb = last(A, "StateUpdate"), last(B, "StateUpdate")
	if not sa or not sb then bad("a PvP player got no state") return end
	if sa[2].isMyTurn == sb[2].isMyTurn then bad("both or neither think it's their turn") end
	if sa[2].oppHandCount == nil then bad("opp hand count missing") end
	if sa[2].oppHand or sa[2].oppDeckList then bad("LEAK: opponent hidden info sent to client") end
	R.Surrender.OnServerEvent:Fire(B); MOCK.pump(1)
	if not (last(A, "MatchEnded") and last(A, "MatchEnded")[2] == true) then bad("winner A not told they won") end
	MOCK.pump(3)
end)

scenario("leave mid-match: opponent wins, no crash", function()
	local C = join("Cara", 3); local D = join("Dan", 4)
	MOCK.pump(3)
	call('Queue', C, "PvP", "LEADER_LUNG"); call('Queue', D, "PvP", "LEADER_PA")
	MOCK.pump(2)
	rawset(C, "_gone", true); C.Parent = nil
	Players.PlayerRemoving:Fire(C); MOCK.pump(2)
	local me = last(D, "MatchEnded")
	if not me or me[2] ~= true then bad("remaining player not awarded win on LEFT") end
end)

scenario("SaveDeck / Gacha / Quest / Farm happy paths", function()
	local pr = call('GetProfile', A)
	local ids = {}
	for id, k in pairs(pr.Deck) do ids[#ids + 1] = id end
	local deckList = {}
	for _, id in ipairs(H.load(path("ReplicatedStorage/Shared/Decks.lua")).Starter) do deckList[#deckList + 1] = id end
	local ok, why = call('SaveDeck', A, deckList)
	if not ok then bad("SaveDeck starter rejected: " .. tostring(why)) end
	local ok2, why2 = call('SaveDeck', A, { "KAI_CHON" })
	if ok2 then bad("SaveDeck accepted a 1-card deck") end
	MOCK.pump(1)
	local g = call('Gacha', A, 1)
	print("      gacha(1) ->", tostring(g), "(gems " .. tostring(call('GetProfile', A).Gems) .. ")")
	local f = call('GetFarms', A)
	if f == nil then bad("GetFarms nil") end
	local q = call('ClaimQuest', A, "nonexistent")
	if q == true then bad("ClaimQuest accepted a nonexistent quest") end
end)


-- ─── forced-win checks: rigged so the human wins, through the real server ───
local function matchOf(plr)
	-- ActiveMatches is a GameServer local; recover the Match via the bot/opponent held in StateUpdate? use debug: find via upvalue-free trick
	return nil
end
local function winBy(plr, mode, leader, riggedFn)
	rig = function(m)
		-- make the human win fast: opponent leader to 1 HP and human gets a ready attacker
		local opp = m:Opponent(plr)
		m.sides[opp].leaderHP = 1
		m.sides[opp].shield = 0
	end
	plr._endedSeen = count(plr, "MatchEnded")
	local qok, qwhy = call('Queue', plr, mode, leader)
	rig = nil
	if not qok then print("      queue refused:", tostring(qwhy)); return nil end
	-- human attacks leader on their turn; let bot turns pass
	for _ = 1, 400 do
		MOCK.pump(0.5)
		local st = last(plr, "StateUpdate"); st = st and st[2]
		if last(plr, "MatchEnded") and count(plr, "MatchEnded") > (plr._endedSeen or 0) then break end
		if st and st.isMyTurn then
			for _, c in ipairs(table.clone(st.myHand)) do
				if c.Cost <= st.myPoints and c.Type == "Character" and #st.myField < 3 then
					if R.PlayCard.OnServerInvoke(plr, c.Uid, "Field") then break end
				end
			end
			st = last(plr, "StateUpdate")[2]
			for _, f in ipairs(table.clone(st.myField)) do
				if f.CanAttack and f.ATK > 0 then R.Attack.OnServerInvoke(plr, f.Uid, "LEADER"); MOCK.pump(0.2) end
			end
			R.EndTurn.OnServerEvent:Fire(plr)
		end
	end
	plr._endedSeen = count(plr, "MatchEnded")
	if count(plr, "MatchEnded") <= (plr._endedSeen or 0) then
		local s = last(plr, "StateUpdate"); s = s and s[2]
		print("      A.Parent=" .. tostring(plr.Parent and plr.Parent.Name) .. " totalMatchEnded=" .. count(plr, "MatchEnded") .. " seen=" .. tostring(plr._endedSeen))
		local mm = ALLM[#ALLM]; print("      SERVER match: ended=" .. tostring(mm and mm.ended) .. " current=" .. tostring(mm and mm.current and mm.current.Name) .. " mode=" .. tostring(mm and mm.Mode) .. " hpA=" .. tostring(mm and mm.sides[mm.players[1]].leaderHP) .. " hpB=" .. tostring(mm and mm.sides[mm.players[2]].leaderHP))
		print("      STUCK state: isMyTurn=" .. tostring(s and s.isMyTurn) .. " myHP=" .. tostring(s and s.myHP) .. " oppHP=" .. tostring(s and s.oppHP)
			.. " pts=" .. tostring(s and s.myPoints) .. " hand=" .. tostring(s and #s.myHand) .. " field=" .. tostring(s and #s.myField) .. " oppField=" .. tostring(s and #s.oppField)
			.. " matchId=" .. tostring(s and s.matchId) .. " virtualT=" .. tostring(MOCK.clock()))
		return nil
	end
	return last(plr, "MatchEnded")
end

scenario("forced WIN vs Bot: pays REWARD_WIN_BOT, counts stats + quests", function()
	MOCK.pump(3)
	local cfg = H.load(path("ReplicatedStorage/Shared/Config.lua"))
	local g0 = call('GetProfile', A).Gems
	local me = winBy(A, "Bot", "LEADER_LUNG")
	print("      DEBUG ended payload:", me and table.concat({ tostring(me[2]), tostring(me[3]), tostring(me[5]) }, " | ") or "nil", "| queue Bot ok? gems g0=" .. g0)
	if not me then bad("never ended") return end
	if me[2] ~= true then bad("rigged win not a win: " .. tostring(me[3])) return end
	MOCK.pump(1)
	local g1 = call('GetProfile', A).Gems
	if g1 - g0 ~= cfg.REWARD_WIN_BOT then bad(("bot win paid %d, expected %d"):format(g1 - g0, cfg.REWARD_WIN_BOT)) end
	local st = call('GetStats', A)
	if not st then bad("GetStats nil") end
end)

scenario("forced WIN in Tower: floor advances once, pays formula", function()
	MOCK.pump(3)
	local cfg = H.load(path("ReplicatedStorage/Shared/Config.lua"))
	local pr0 = call('GetProfile', A)
	local f0, g0 = pr0.TowerFloor, pr0.Gems
	local me = winBy(A, "Tower", "LEADER_KID")
	if not me or me[2] ~= true then bad("tower rigged win failed") return end
	MOCK.pump(1)
	local pr1 = call('GetProfile', A)
	if pr1.TowerFloor ~= f0 + 1 then bad(("floor %d -> %d (expected +1)"):format(f0, pr1.TowerFloor)) end
	local expect = cfg.TOWER_REWARD_BASE + f0 * cfg.TOWER_REWARD_PER_FLOOR
	if pr1.Gems - g0 ~= expect then bad(("tower paid %d expected %d"):format(pr1.Gems - g0, expect)) end
end)

scenario("PvP win: winner +REWARD_WIN_PVP(+bounty), loser +REWARD_LOSE_PVP, streak tracked", function()
	local cfg = H.load(path("ReplicatedStorage/Shared/Config.lua"))
	local W, L = join("Wes", 7), join("Lia", 8)
	MOCK.pump(3)
	local gw0, gl0 = call('GetProfile', W).Gems, call('GetProfile', L).Gems
	call('Queue', W, "PvP", "LEADER_LUNG"); call('Queue', L, "PvP", "LEADER_PA")
	MOCK.pump(2)
	R.Surrender.OnServerEvent:Fire(L); MOCK.pump(2)
	local gw1, gl1 = call('GetProfile', W).Gems, call('GetProfile', L).Gems
	if gw1 - gw0 ~= cfg.REWARD_WIN_PVP then bad(("pvp winner paid %d expected %d"):format(gw1 - gw0, cfg.REWARD_WIN_PVP)) end
	if gl1 - gl0 ~= cfg.REWARD_LOSE_PVP then bad(("pvp loser paid %d expected %d"):format(gl1 - gl0, cfg.REWARD_LOSE_PVP)) end
	-- second win => bounty on loser's streak? loser has streak 0 => no bounty. Winner now has streak 1; Lia beats Wes => bounty
	MOCK.pump(3)
	call('Queue', W, "PvP", "LEADER_LUNG"); call('Queue', L, "PvP", "LEADER_PA"); MOCK.pump(2)
	local gl2 = call('GetProfile', L).Gems
	R.Surrender.OnServerEvent:Fire(W); MOCK.pump(2)
	local gl3 = call('GetProfile', L).Gems
	local expect = cfg.REWARD_WIN_PVP + 1 * cfg.BOUNTY_PER_STREAK
	if gl3 - gl2 ~= expect then bad(("bounty win paid %d expected %d (win + streak bounty)"):format(gl3 - gl2, expect)) end
end)

scenario("data persists: leave and rejoin keeps gems + tower floor", function()
	local before = call('GetProfile', A)
	Players.PlayerRemoving:Fire(A); MOCK.pump(2)
	A.Parent = nil
	local A2 = join("Alice", 1)
	MOCK.pump(3)
	local after = call('GetProfile', A2)
	if not after then bad("no profile after rejoin") return end
	if after.Gems ~= before.Gems then bad(("gems %d -> %d after rejoin"):format(before.Gems, after.Gems)) end
	if after.TowerFloor ~= before.TowerFloor then bad(("floor %d -> %d after rejoin"):format(before.TowerFloor, after.TowerFloor)) end
end)

print("problems:", #problems)
for _, p in ipairs(problems) do print("  - " .. p) end
