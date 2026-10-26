MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 77, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.newInstance("Player"); me.UserId = 9; me.Name = "G"; me.DisplayName = "G"; me.Parent = Players
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
rawset(Players, "LocalPlayer", me)
-- hook Match.Start so we can stack the human's hand/points deterministically
local MatchMod = H.load(path("ServerStorage/Modules/Match.lua"))
local CardData = H.load(path("ReplicatedStorage/Shared/CardData.lua"))
local rigHand
local origStart = MatchMod.Start
local MATCHES = {}
MatchMod.Start = function(self) MATCHES[#MATCHES + 1] = self; origStart(self); if rigHand then rigHand(self) end end
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
end
local rejected = {}
for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
	rawset(R[n], "InvokeServer", function(self, ...)
		local r = table.pack(R[n].OnServerInvoke(me, ...))
		if (n == "PlayCard" or n == "Attack") then rejected[#rejected + 1] = n .. "->" .. tostring(r[1]) .. "," .. tostring(r[2]) end
		return table.unpack(r, 1, r.n)
	end)
end
for _, n in ipairs({ "EndTurn", "Surrender" }) do rawset(R[n], "FireServer", function(self, ...) R[n].OnServerEvent:Fire(me, ...) end) end
Players.PlayerAdded:Fire(me); MOCK.pump(4)

local MatchUI = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/MatchUI.lua"))
local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
MatchUI.Build(gui, overlay, {})
local lastState, gateRolls, ended = nil, {}, false
R.StateUpdate.OnClientEvent:Connect(function(s) lastState = s end)
R.GateRolled.OnClientEvent:Connect(function(mine, card, outcome) gateRolls[#gateRolls + 1] = { mine, card and card.Name, outcome } end)
R.MatchEnded.OnClientEvent:Connect(function() ended = true end)

-- stack: human always moves first, with 15 points, a cheap character and a weapon in hand
rigHand = function(m)
	local human
	for _, p in ipairs(m.players) do if p == me then human = p end end
	local side = m.sides[human]
	local function pull(pred)
		for i, c in ipairs(side.deck) do if pred(c) then table.remove(side.deck, i); table.insert(side.hand, c); return c end end
	end
	-- make room, then add what we need (keeps card count constant: hand cards go to deck bottom)
	while #side.hand > 2 do table.insert(side.deck, 1, table.remove(side.hand)) end
	pull(function(c) return c.Type == "Character" and c.Cost <= 2 end)
	pull(function(c) return c.Type == "Weapon" end)
	side.points = 15
end
MOCK.pump(1.5)
print("queue:", R.Queue.OnServerInvoke(me, "Bot", "LEADER_LUNG"))
MOCK.pump(3)

local function btns() local o = {} for _, root in ipairs({ gui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" and d.Visible ~= false then o[#o + 1] = d end end end return o end
local function text(b) local t = tostring(b.Text or ""); if t == "" then for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then return c.Text end end end return t end
local function find(p) for _, b in ipairs(btns()) do if p(text(b), b) then return b end end end
local function tap(b) b.Activated:Fire(); MOCK.pump(0.3) end
local problems = {}
local function bad(m) problems[#problems + 1] = m end

for _ = 1, 60 do MOCK.pump(0.5); if lastState and lastState.isMyTurn then break end end
local s = lastState
print("hand:"); for _, c in ipairs(s.myHand) do print("   ", c.Type, c.Name, "cost", c.Cost) end
-- 1) put a cheap character in the GATE through the UI
local gateCard
for _, c in ipairs(s.myHand) do if c.Type == "Character" then gateCard = c break end end
local cb = find(function(t) return t == gateCard.Name end); tap(cb)
local gb = find(function(t) return t:find("ลงเกต") end)
if not gb then bad("no 'ลงเกต' button after selecting a character") else
	tap(gb)
	if not lastState.myGate then bad("gate card not in state after UI gate play") end
	print("gate occupied:", lastState.myGate and lastState.myGate.Name, "| pts left", lastState.myPoints)
	local expected = 15 - math.max(0, gateCard.Cost - 1)
	if lastState.myPoints ~= expected then bad(("gate cost wrong: pts %d expected %d"):format(lastState.myPoints, expected)) end
	local g = find(function(t) return t:find("เทิร์นหน้าสุ่ม") end)
	local txt = {}
	for _, d in ipairs(gui:GetDescendants()) do if d.ClassName == "TextLabel" and tostring(d.Text):find("เทิร์นหน้าสุ่ม") then txt[#txt + 1] = d.Text end end
	if #txt == 0 then bad("gate waiting label '⏳ เทิร์นหน้าสุ่ม!' not shown") end
end
-- 2) put a second character on the field, then equip the weapon on it
local second
for _, c in ipairs(lastState.myHand) do if c.Type == "Character" and c.Uid ~= gateCard.Uid then second = c break end end
if second then
	tap(find(function(t) return t == second.Name end))
	local fb = find(function(t) return t:find("ลงสนาม") end)
	if fb then tap(fb) else bad("no 'ลงสนาม' for second character") end
end
local weapon
for _, c in ipairs(lastState.myHand) do if c.Type == "Weapon" then weapon = c break end end
if weapon and second then
	tap(find(function(t) return t == weapon.Name end))
	local hint = {}
	for _, d in ipairs(gui:GetDescendants()) do if d.ClassName == "TextLabel" and tostring(d.Text):find("สวม") then hint[#hint + 1] = d.Text end end
	print("weapon hint shown:", hint[1])
	local mineCard = find(function(t) return t == second.Name end)
	if mineCard then tap(mineCard) end
	local fld = lastState.myField[1]
	print("equipped? weapon on field card:", fld and (fld.WeaponName or fld.Weapon))
	if not (fld and (fld.WeaponName or fld.Weapon)) then bad("weapon did not attach after tapping weapon then own card") end
else
	bad("no weapon/second character to test (rig failed)")
end
-- 3) end turn through UI, let bot play, come back: gate must roll
local eb = find(function(t, b) return t:find("จบเทิร์น") or t:find("ข้าม") or t:find("⏳") end)
if eb then tap(eb) end
for _ = 1, 200 do MOCK.pump(0.5); if #gateRolls > 0 and lastState and lastState.isMyTurn then break end; if ended then break end end
print("gate rolls received by client:", #gateRolls, gateRolls[1] and (tostring(gateRolls[1][2]) .. " -> " .. tostring(gateRolls[1][3])) or "")
if #gateRolls == 0 then bad("gate never rolled on next own turn") end
if lastState and lastState.myGate then bad("gate still occupied after roll") end
local onField = 0; if lastState then onField = #lastState.myField end
print("field after gate resolved:", onField)

for _, e in ipairs(MOCK.handlerErrors or {}) do bad("handler err: " .. tostring(e)) end
for _, e in ipairs(MOCK.taskErrors or {}) do bad("task err: " .. tostring(e)) end
print("server replies:"); for _, r in ipairs(rejected) do print("   " .. r) end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
for i, w in ipairs(MOCK.warnings or {}) do print("WARN " .. i .. ": " .. tostring(w)) end
