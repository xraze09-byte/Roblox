TEST_MODE = 'Tower'
MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 21, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local p = H.newInstance("Player"); p.Name = "Alice"; p.UserId = 1; p.DisplayName = "Alice"; p.Parent = Players
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; p.Character = ch
rawset(p, "Kick", function() end)
-- hook the SAME Match module instance GameServer will load: load first, patch, then GameServer reuses cache
local Match = H.load(path("ServerStorage/Modules/Match.lua"))
local origEnded
local seen = {}
local origStart = Match.Start
local armed = true
Match.Start = function(self)
	origStart(self)
	if armed then local o = self:Opponent(p); self.sides[o].leaderHP = 1; self.sides[o].shield = 0; self.RIGGED = true end
end
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
local inbox = {}
for _, n in ipairs({ "StateUpdate", "MatchEnded" }) do rawset(R[n], "FireClient", function(_, plr, ...) inbox[#inbox + 1] = { n, ... } end) end
Players.PlayerAdded:Fire(p); MOCK.pump(3)
local function lastOf(n) for i = #inbox, 1, -1 do if inbox[i][1] == n then return inbox[i] end end end
local function call(name, ...) MOCK.pump(1.2); return R[name].OnServerInvoke(p, ...) end
local g0 = call("GetProfile").Gems
local MODE = TEST_MODE or "Bot"
local cfg = H.load(path("ReplicatedStorage/Shared/Config.lua"))
local f0 = call("GetProfile").TowerFloor
print("queue:", call("Queue", MODE, "LEADER_LUNG"))
for i = 1, 300 do
	MOCK.pump(0.5)
	if lastOf("MatchEnded") then break end
	local st = lastOf("StateUpdate"); st = st and st[3] or (st and st[2])
	local s = lastOf("StateUpdate"); s = s and s[2]
	if s and s.isMyTurn then
		for _, c in ipairs(table.clone(s.myHand)) do
			if c.Cost <= s.myPoints and c.Type == "Character" and #s.myField < 3 then if R.PlayCard.OnServerInvoke(p, c.Uid, "Field") then break end end
		end
		s = lastOf("StateUpdate")[2]
		for _, f in ipairs(table.clone(s.myField)) do if f.CanAttack and f.ATK > 0 then R.Attack.OnServerInvoke(p, f.Uid, "LEADER"); MOCK.pump(0.2) end end
		R.EndTurn.OnServerEvent:Fire(p)
	end
end
local me = lastOf("MatchEnded")
print("MatchEnded payload:", me and table.concat({ tostring(me[2]), tostring(me[3]), tostring(me[4]), tostring(me[5]), tostring(me[6]) }, " | "))
MOCK.pump(2)
local pr = call("GetProfile")
print("mode", MODE, "| gems:", g0, "->", pr.Gems, "| floor:", f0, "->", pr.TowerFloor)
if MODE == "Tower" then print("expected gems +" .. (cfg.TOWER_REWARD_BASE + f0 * cfg.TOWER_REWARD_PER_FLOOR) .. ", floor +1") else print("expected gems +" .. cfg.REWARD_WIN_BOT) end
