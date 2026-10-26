MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 5, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.player; me.UserId = 1; me.Name = "Alice"; me.DisplayName = "Alice"; me.Parent = Players
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
local trace = {}
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
end
for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
	rawset(R[n], "InvokeServer", function(self, ...)
		local a = table.pack(...)
		local r = table.pack(R[n].OnServerInvoke(me, ...))
		if n == "PlayCard" or n == "Attack" then trace[#trace + 1] = ("%s(%s) -> %s,%s"):format(n, tostring(a[1]):sub(1, 8) .. "," .. tostring(a[2]), tostring(r[1]), tostring(r[2])) end
		return table.unpack(r, 1, r.n)
	end)
end
for _, n in ipairs({ "EndTurn", "Surrender" }) do rawset(R[n], "FireServer", function(self, ...) trace[#trace + 1] = "FIRE " .. n; R[n].OnServerEvent:Fire(me, ...) end) end
Players.PlayerAdded:Fire(me); MOCK.pump(4)
local MatchUI = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/MatchUI.lua"))
local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
MatchUI.Build(gui, overlay, {})
local lastState; R.StateUpdate.OnClientEvent:Connect(function(s) lastState = s end)
MOCK.pump(1.5); print("queue", R.Queue.OnServerInvoke(me, "Bot", "LEADER_LUNG")); MOCK.pump(2)
-- wait for our turn
for _ = 1, 100 do MOCK.pump(0.5); if lastState and lastState.isMyTurn then break end end
local s = lastState
print("my turn:", s.isMyTurn, "pts", s.myPoints, "hand", #s.myHand, "field", #s.myField)
local function btns() local o = {} for _, root in ipairs({ gui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" then o[#o + 1] = d end end end return o end
local function text(b) local t = tostring(b.Text or ""); if t == "" then for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then return c.Text end end end return t end
-- tap the first affordable character card
local card
for _, c in ipairs(s.myHand) do if c.Cost <= s.myPoints and c.Type == "Character" then card = c break end end
print("trying card:", card and card.Name, "cost", card and card.Cost)
local cb; for _, b in ipairs(btns()) do if text(b) == card.Name then cb = b break end end
print("card button found:", cb ~= nil)
cb.Activated:Fire(); MOCK.pump(0.4)
local all = {}
for _, b in ipairs(btns()) do all[#all + 1] = text(b) end
print("ALL buttons after tapping card:", table.concat(all, " | "):gsub("\n", " "))
local plus = {}
for _, b in ipairs(btns()) do if text(b):find("ลงที่นี่") then plus[#plus + 1] = b end end
print("'+' buttons after selecting card:", #plus)
for i, b in ipairs(plus) do print("  plus#" .. i, "visible=" .. tostring(b.Visible), "parent=" .. tostring(b.Parent and b.Parent.Name)) end
if plus[1] then plus[1].Activated:Fire(); MOCK.pump(0.6) end
print("trace:"); for _, l in ipairs(trace) do print("   " .. l) end
print("state after: field=" .. #lastState.myField .. " hand=" .. #lastState.myHand .. " pts=" .. lastState.myPoints)
for _, e in ipairs(MOCK.handlerErrors or {}) do print("HANDLER ERR:", e) end
for _, e in ipairs(MOCK.taskErrors or {}) do print("TASK ERR:", e) end
for _, w in ipairs(MOCK.warnings or {}) do print("WARN:", w) end
