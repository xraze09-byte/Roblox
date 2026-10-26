UIPLAY_SEEDS = 40
MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local SEEDS = tonumber(UIPLAY_SEEDS) or 6
local report = { games = 0, ended = 0, reasons = {}, problems = {}, actions = { field = 0, gate = 0, spell = 0, weapon = 0, attackCard = 0, attackLeader = 0, skip = 0, endturn = 0 }, rejected = {} }
local function bad(seed, m) report.problems[m] = report.problems[m] or { n = 0, seed = seed }; report.problems[m].n += 1 end

local function runSeed(seed)
	SIM_SEED, SIM_RNG_N = seed * 13, 0
	H.resetCache()
	local store = {}
	rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
	rawset(H.game, "BindToClose", function() end)
	local Players = H.game:GetService("Players")
	local me = H.newInstance("Player"); me.UserId = 1000 + seed; me.Name = "P" .. seed; me.DisplayName = "P" .. seed; me.Parent = Players
	rawset(me, "Kick", function() end)
	local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
	-- client LocalPlayer is this player
	rawset(Players, "LocalPlayer", me)
	local okgs, e = pcall(H.load, path("ServerScriptService/GameServer.server.lua"))
	if not okgs then print("GameServer load fail", e) return end
	local R = H.RS.Remotes
	for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
		rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
	end
	local last_rej
	for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
		rawset(R[n], "InvokeServer", function(self, ...)
			local r = table.pack(R[n].OnServerInvoke(me, ...))
			if (n == "PlayCard" or n == "Attack") and r[1] ~= true then
				local k = n .. ":" .. tostring(r[2]); report.rejected[k] = (report.rejected[k] or 0) + 1
			end
			return table.unpack(r, 1, r.n)
		end)
	end
	for _, n in ipairs({ "EndTurn", "Surrender" }) do rawset(R[n], "FireServer", function(self, ...) R[n].OnServerEvent:Fire(me, ...) end) end
	Players.PlayerAdded:Fire(me); MOCK.pump(4)

	local MatchUI = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/MatchUI.lua"))
	local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
	local okb, eb = pcall(MatchUI.Build, gui, overlay, {})
	if not okb then bad(seed, "Build: " .. tostring(eb)) return end
	do
		local lastState, ended, endReason = nil, false, nil
		R.StateUpdate.OnClientEvent:Connect(function(s) lastState = s end)
		R.MatchEnded.OnClientEvent:Connect(function(won, reason) ended = true; endReason = reason end)
		local function btns() local o = {} for _, root in ipairs({ gui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" and d.Visible ~= false then o[#o + 1] = d end end end return o end
		local function text(b) local t = tostring(b.Text or ""); if t == "" then for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then return c.Text end end end return t end
		local function find(p) for _, b in ipairs(btns()) do if p(text(b), b) then return b end end end
		local function tap(b) local ok, e = pcall(function() b.Activated:Fire() end); if not ok then bad(seed, "tap error: " .. tostring(e)) end MOCK.pump(0.25) end

		MOCK.pump(1.5)
		local qok = R.Queue.OnServerInvoke(me, "Bot", "LEADER_" .. ({ "LUNG", "PA", "KID" })[seed % 3 + 1])
		if not qok then bad(seed, "queue refused") return end
		report.games += 1
		local errs0, terr0 = #(MOCK.handlerErrors or {}), 0
		for step = 1, 1500 do
			MOCK.pump(0.5)
			if ended then break end
			local s = lastState
			if s and s.isMyTurn then
				local did = false
				-- try each hand card until one is accepted
				for _, c in ipairs(table.clone(s.myHand or {})) do
					local s2 = lastState
					if c.Cost <= s2.myPoints or (c.Cost - 1 <= s2.myPoints) then
						local cb = find(function(t) return t == c.Name end)
						if cb then
							tap(cb)
							if c.Type == "Character" then
								local slot = find(function(t) return t:find("ลงที่นี่") end)
								local fieldBtn = find(function(t) return t:find("ลงสนาม") end)
								if slot then tap(slot); report.actions.field += 1; did = true
								elseif fieldBtn then tap(fieldBtn); report.actions.field += 1; did = true end
							elseif c.Type == "Weapon" then
								local tgt = find(function(t, b) return t:find("ใส่") or t:find("สวม") or t:find("ลงที่นี่") end)
								if tgt then tap(tgt); report.actions.weapon += 1; did = true end
							else
								local nowBtn = find(function(t) return t:find("ใช้") or t:find("ร่าย") end)
								if nowBtn then tap(nowBtn); report.actions.spell += 1; did = true end
							end
							-- clear selection if nothing happened
							local cancel = find(function(t) return t == "✖" end)
							if cancel then tap(cancel) end
							if did then break end
						end
					end
				end
				-- attack with ready creatures
				local s3 = lastState
				for _, f in ipairs(table.clone(s3.myField or {})) do
					if f.CanAttack and (f.ATK or 0) > 0 and not f.Frozen then
						local fb = find(function(t) return t == f.Name end)
						if fb then
							tap(fb)
							local lastS = lastState
							local oppCard = lastS.oppField and lastS.oppField[1]
							local tb
							if oppCard then tb = find(function(t) return t == oppCard.Name end); if tb then tap(tb); report.actions.attackCard += 1 end
							else
								local lbs = {}
								for _, b in ipairs(btns()) do local t = text(b); if t:find("🧓") or t:find("🙂") or t:find("👵") or t:find("•") then lbs[#lbs + 1] = b end end
								if lbs[1] then tap(lbs[1]); report.actions.attackLeader += 1 end
							end
							local cancel = find(function(t) return t == "✖" end); if cancel then tap(cancel) end
						end
					end
				end
				-- end the turn
				local eb2 = find(function(t, b) return (t:find("ข้าม") or t:find("จบเทิร์น") or t:find("⏳")) and not b:GetAttribute("Disabled") end)
				if eb2 then tap(eb2); report.actions.endturn += 1 end
			end
			if #(MOCK.handlerErrors or {}) > errs0 then bad(seed, "UI handler error: " .. tostring(MOCK.handlerErrors[#MOCK.handlerErrors])); errs0 = #MOCK.handlerErrors end
			if #(MOCK.taskErrors or {}) > terr0 then bad(seed, "task error: " .. tostring(MOCK.taskErrors[#MOCK.taskErrors])); terr0 = #MOCK.taskErrors end
			-- screen vs server consistency
			if lastState then
				local st = lastState
				if st.myHP == nil or st.oppHP == nil then bad(seed, "state missing HP") end
				if #(st.myField or {}) > 3 then bad(seed, "state >3 field") end
			end
		end
		if ended then report.ended += 1; report.reasons[endReason or "?"] = (report.reasons[endReason or "?"] or 0) + 1
		else bad(seed, "match did not end in budget") end
		MOCK.handlerErrors, MOCK.taskErrors = {}, {}
	end

end
for seed = 1, SEEDS do runSeed(seed) end
print(("games=%d ended=%d"):format(report.games, report.ended))
for r, n in pairs(report.reasons) do print("  end reason", r, n) end
local a = report.actions
print(("UI actions: field=%d gate=%d spell=%d weapon=%d attackCard=%d attackLeader=%d endturn=%d"):format(a.field, a.gate, a.spell, a.weapon, a.attackCard, a.attackLeader, a.endturn))
for k, n in pairs(report.rejected) do print("  server rejected", k, n) end
local np = 0
for m, v in pairs(report.problems) do np += 1; print(("PROBLEM x%d (seed %d): %s"):format(v.n, v.seed, m)) end
print("distinct problems:", np)
