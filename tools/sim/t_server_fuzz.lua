MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 11, 0

-- fake DataStore so DataService persists in memory
local store = {}
local DSS = H.game:GetService("DataStoreService")
rawset(DSS, "GetDataStore", function() return {
	GetAsync = function(_, k) return store[k] end,
	UpdateAsync = function(_, k, fn) store[k] = fn(store[k]); return store[k] end,
	SetAsync = function(_, k, v) store[k] = v end } end)

-- fake player Instance (Match treats Instances as humans)
local function mkPlayer(name, uid)
	local p = H.newInstance("Player"); p.Name = name; p.UserId = uid; p.DisplayName = name
	p.Parent = H.game:GetService("Players")
	local ch = H.newInstance("Model"); local hum = H.newInstance("Humanoid"); hum.Parent = ch; ch.Parent = H.newInstance("Workspace")
	p.Character = ch
	return p
end
local Players = H.game:GetService("Players")
rawset(H.game, "BindToClose", function() end)

-- run the real GameServer
local gs = path("ServerScriptService/GameServer.server.lua")
local okGS, errGS = pcall(H.load, gs)
print("GameServer load:", okGS, okGS and "" or errGS)
if not okGS then return end

local Remotes = H.RS:FindFirstChild("Remotes")
rawset(H.newInstance("Player"), "x", 1)
local uidN = 100
local function fresh() uidN += 1; local p = mkPlayer("P" .. uidN, uidN); rawset(p, "Kick", function(self, why) M_KICKED = (M_KICKED or 0) + 1; rawset(self, "_kicked", why) end); Players.PlayerAdded:Fire(p); MOCK.pump(2); return p end
local p1 = fresh()

local findings, seen = {}, {}
local function note(kind, remote, argdesc, err)
	local k = kind .. "|" .. remote .. "|" .. tostring(err):gsub("^[^:]*:%d+: ", "")
	if seen[k] then return end
	seen[k] = true
	findings[#findings + 1] = ("%s  %s(%s)  -> %s"):format(kind, remote, argdesc, tostring(err))
end

local weird = { { "nil", nil }, { "num -1", -1 }, { "num 1e9", 1e9 }, { "NaN", 0/0 }, { "inf", math.huge }, { "empty str", "" },
	{ "long str", string.rep("x", 5000) }, { "table", {} }, { "bool", true }, { "func", function() end }, { "unknown id", "NOPE_ID" },
	{ "nested tbl", { {}, { 1 }, "a" } }, { "str num", "5" } }

local RFs = { "Queue", "GetStats", "GetProfile", "PlayCard", "Attack", "Gacha", "GetFarms", "ClaimFarm", "UpgradeFarm", "SaveDeck", "ClaimQuest" }
for _, name in ipairs(RFs) do
	p1 = fresh()
	local r = Remotes[name]
	local h = r.OnServerInvoke
	if not h then note("NO_HANDLER", name, "", "OnServerInvoke is nil")
	else
		-- 1-arg, 2-arg and 3-arg weird combos
		for _, a in ipairs(weird) do
			local ok, err = pcall(h, p1, a[2])
			if not ok then note("THROWS", name, a[1], err) end
			for _, b in ipairs({ weird[1], weird[2], weird[6], weird[8], weird[11] }) do
				local ok2, err2 = pcall(h, p1, a[2], b[2])
				if not ok2 then note("THROWS", name, a[1] .. "," .. b[1], err2) end
			end
		end
		local ok3, err3 = pcall(h, p1)
		if not ok3 then note("THROWS", name, "(no args)", err3) end
		if p1._kicked then note("KICKED_BY_FUZZ", name, "", p1._kicked) end
	end
end
for _, name in ipairs({ "EndTurn", "Surrender" }) do
	local sig = Remotes[name].OnServerEvent
	for _, a in ipairs(weird) do
		local before = #(MOCK.handlerErrors or {})
		sig:Fire(p1, a[2])
		if #(MOCK.handlerErrors or {}) > before then note("THROWS", name, a[1], MOCK.handlerErrors[#MOCK.handlerErrors]) end
	end
end
MOCK.pump(5)
for _, e in ipairs(MOCK.taskErrors or {}) do note("TASK_ERR", "-", "", e) end
for _, e in ipairs(MOCK.handlerErrors or {}) do note("HANDLER_ERR", "-", "", e) end
print("findings:", #findings)
for _, f in ipairs(findings) do print("  " .. f) end
