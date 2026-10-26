MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 3, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.player; me.UserId = 5; me.Name = "I"; me.DisplayName = "I"; me.Parent = Players
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
-- NO CardTable in workspace and TableCamera.Enter will wait 5s for it -> camera never "arrives" in time
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
end
for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
	rawset(R[n], "InvokeServer", function(self, ...) return R[n].OnServerInvoke(me, ...) end)
end
for _, n in ipairs({ "EndTurn", "Surrender" }) do rawset(R[n], "FireServer", function(self, ...) R[n].OnServerEvent:Fire(me, ...) end) end
Players.PlayerAdded:Fire(me); MOCK.pump(4)
-- run the REAL client entry script
local pg = me.PlayerGui
-- init.client uses script:WaitForChild("FloatHUD"): in Rojo the sibling files are children of the script, so reparent them for the test
local initInst = path("StarterPlayer/StarterPlayerScripts/UIClient/init.client.lua")
local folder = initInst.Parent
for _, c in ipairs(folder:GetChildren()) do if c ~= initInst then c.Parent = initInst end end
local ok, err = pcall(H.load, initInst)
print("init.client load:", ok, ok and "" or err)
local function gui(name) return pg:FindFirstChild(name) end
local mg = gui("MatchUI")
print("MatchUI ScreenGui found:", mg ~= nil, "Enabled=", mg and mg.Enabled)
MOCK.pump(1.5)
print("queue:", R.Queue.OnServerInvoke(me, "Bot", "LEADER_LUNG"))
MOCK.pump(0.5)
print("t+0.5s after match start: MatchUI.Enabled=", mg.Enabled, "(hidden while camera flies)")
MOCK.pump(4.0)
print("t+4.5s: MatchUI.Enabled=", mg.Enabled, "(must be true even if camera never arrived)")
local problems = {}
if mg.Enabled ~= true then problems[#problems + 1] = "MatchUI stayed hidden: player would see only the table" end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
