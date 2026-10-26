MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = (BRIDGE_SEED or 5), 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.player
me.UserId = 1; me.Name = "Alice"; me.DisplayName = "Alice"; me.Parent = H.game:GetService("Players")
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
end
for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
	rawset(R[n], "InvokeServer", function(self, ...) return R[n].OnServerInvoke(me, ...) end)
end
for _, n in ipairs({ "EndTurn", "Surrender" }) do
	rawset(R[n], "FireServer", function(self, ...) R[n].OnServerEvent:Fire(me, ...) end)
end
Players.PlayerAdded:Fire(me); MOCK.pump(4)
print('profile loaded:', R.GetProfile.OnServerInvoke(me) ~= nil)

local MatchUI = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/MatchUI.lua"))
local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
local started = 0
local okB, errB = pcall(MatchUI.Build, gui, overlay, { OnStart = function() started += 1 end, OnExit = function() end })
print("MatchUI.Build:", okB, okB and "" or errB)
if not okB then return end

local problems = {}
local function bad(m) if #problems < 25 then problems[#problems + 1] = m end end
local function allButtons()
	local out = {}
	for _, root in ipairs({ gui, overlay }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d.ClassName == "TextButton" or d.ClassName == "ImageButton" then out[#out + 1] = d end
		end
	end
	return out
end
local function textOf(b)
	local t = tostring(b.Text or "")
	if t == "" then for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then return c.Text end end end
	return t
end
local function press(btn)
	local ok, e = pcall(function() btn.Activated:Fire() end)
	if not ok then bad("press error: " .. tostring(e)) end
	MOCK.pump(0.3)
end

MOCK.pump(1.5)
MOCK.pump(1.5)
local ok, why = R.Queue.OnServerInvoke(me, "Bot", "LEADER_LUNG")
print("queue:", ok, why)
MOCK.pump(2)
print("OnStart fired:", started)

local presses, endedSeen = 0, false
local stats = { cardsPlayed = 0, attacks = 0, endTurns = 0, rejected = 0, toasts = {} }
R.MatchEnded.OnClientEvent:Connect(function(won, reason) endedSeen = true; print("MatchEnded ->", won, reason) end)
local errs0 = #(MOCK.handlerErrors or {})
local function findBtn(pred) for _, b in ipairs(allButtons()) do if b.Visible ~= false and pred(b, textOf(b)) then return b end end end
local function serverState() return nil end
local lastState
R.StateUpdate.OnClientEvent:Connect(function(s) lastState = s end)
for step = 1, 900 do
	MOCK.pump(0.6)
	if endedSeen then break end
	local s = lastState
	if s and s.isMyTurn then
		-- 1) play affordable cards by tapping them then tapping the field/gate
		for _, c in ipairs(table.clone(s.myHand or {})) do
			if c.Cost <= s.myPoints and c.Type == "Character" and #s.myField < 3 then
				local cb = findBtn(function(b, t) return t == c.Name end)
				if cb then
					press(cb)
					local target = findBtn(function(b, t) return t == "+" end)
					if target then press(target); stats.cardsPlayed += 1 else stats.rejected += 1 end
					break
				end
			end
		end
		-- 2) attack with ready creatures: tap own card, then tap enemy leader
		s = lastState
		for _, f in ipairs(table.clone(s.myField or {})) do
			if f.CanAttack and f.ATK > 0 then
				local fb = findBtn(function(b, t) return t == f.Name end)
				if fb then
					press(fb)
					local leader = findBtn(function(b, t) return t == "🙂" or t:find("•") end)
					-- enemy leader button is the first leader button
					local lb = {}
					for _, b in ipairs(allButtons()) do if b.Visible ~= false and (textOf(b) == "🙂" or textOf(b):find("🧓")) then lb[#lb + 1] = b end end
					if lb[1] then press(lb[1]); stats.attacks += 1 end
				end
			end
		end
		-- 3) end turn
		local eb = findBtn(function(b, t) return (t:find("จบ") or t:find("⏳")) and not b:GetAttribute("Disabled") end)
		if eb then press(eb); stats.endTurns += 1 end
	end
	if #(MOCK.handlerErrors or {}) > errs0 then bad("UI handler error: " .. tostring(MOCK.handlerErrors[#MOCK.handlerErrors])); errs0 = #MOCK.handlerErrors end
	if #(MOCK.taskErrors or {}) > 0 then bad("task error: " .. tostring(MOCK.taskErrors[1])); MOCK.taskErrors = {} end
end
print(("cards played via UI=%d  attacks via UI=%d  end-turns=%d  rejected-taps=%d"):format(stats.cardsPlayed, stats.attacks, stats.endTurns, stats.rejected))
print("ended:", endedSeen)
local ev = {}
for _, b in ipairs(allButtons()) do
	local tx = textOf(b)
	if tx:find("⏳") or tx:find("จบ") or tx:find("รอ") then ev[#ev + 1] = ("[%s] vis=%s dis=%s"):format(tx, tostring(b.Visible), tostring(b:GetAttribute("Disabled"))) end
end
print("end-turn candidates:", table.concat(ev, " ; "))
print("last state: isMyTurn=" .. tostring(lastState and lastState.isMyTurn) .. " pts=" .. tostring(lastState and lastState.myPoints) .. " hand=" .. tostring(lastState and #lastState.myHand) .. " field=" .. tostring(lastState and #lastState.myField))
local names = {}
for _, b in ipairs(allButtons()) do names[#names + 1] = textOf(b) end
print("buttons (" .. #names .. "):", table.concat(names, " | "):sub(1, 400))
print("problems:", #problems)
for _, p in ipairs(problems) do print("  - " .. p) end
for _, w in ipairs(MOCK.warnings or {}) do print("  warn: " .. w) end
