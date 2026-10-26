MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 41, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.newInstance("Player"); me.UserId = 66; me.Name = "D"; me.DisplayName = "D"; me.Parent = Players
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
rawset(Players, "LocalPlayer", me)
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
local FloatHUD = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/FloatHUD.lua"))
local hudGui, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui")
FloatHUD.Build(hudGui, overlay, { OnModal = function() end }); MOCK.pump(4)

local function texts(root) local o = {} for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextLabel" or d.ClassName == "TextButton" then local t = tostring(d.Text or ""); if t ~= "" then o[#o + 1] = t end end end return o end
local function has(root, s) for _, t in ipairs(texts(root)) do if t:find(s, 1, true) then return true, t end end return false end
local problems = {}
local function bad(m) problems[#problems + 1] = m end

local prof = R.GetProfile.OnServerInvoke(me)
local ok1, gtxt = has(hudGui, "💎")
print("gems label:", gtxt, "| server gems:", prof.Gems)
if not tostring(gtxt):find(tostring(prof.Gems), 1, true) then bad(("gems label '%s' does not show server value %s"):format(tostring(gtxt), tostring(prof.Gems))) end

-- spend gems via gacha and make sure label follows ProfileChanged
local function find(p) for _, root in ipairs({ hudGui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" and p(tostring(d.Text or ""), d) then return d end end end end
local function lbl(b) local parts = {} for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then parts[#parts + 1] = c.Text end end return tostring(b.Text or "") .. table.concat(parts, " ") end
local function findL(p) for _, root in ipairs({ hudGui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" and p(lbl(d), d) then return d end end end end
local gacha = findL(function(t, b) return b.Name == "Fab_Gacha" end); gacha.Activated:Fire(); MOCK.pump(0.5)
local one = findL(function(t) return t:find("สุ่ม 1") end)
if not one then bad("no 'สุ่ม 1 ครั้ง' button in gacha popup") else
	MOCK.pump(2); one.Activated:Fire(); MOCK.pump(3)
	local prof2 = R.GetProfile.OnServerInvoke(me)
	local _, g2 = has(hudGui, "💎")
	print("after gacha: label:", g2, "| server gems:", prof2.Gems)
	if prof2.Gems >= prof.Gems then bad("gacha did not cost gems") end
	if not tostring(g2):find(tostring(prof2.Gems), 1, true) then bad(("gems label stale after gacha: '%s' vs %s"):format(tostring(g2), tostring(prof2.Gems))) end
end
-- collection count in the deck popup equals server collection
for _, root in ipairs({ hudGui, overlay }) do
	for _, d in ipairs(root:GetDescendants()) do if d.Name == "Popup" then d:Destroy() end end
end
local ca = findL(function(t, b) return b.Name == "ClickAway" end); if ca and ca.Visible then ca.Activated:Fire() end
MOCK.pump(0.5)
local deckFab = findL(function(t, b) return b.Name == "Fab_Deck" end); deckFab.Activated:Fire(); MOCK.pump(0.6)
local all = table.concat(texts(overlay), " ¦ ") .. " ¦ " .. table.concat(texts(hudGui), " ¦ ")
print("deck popup text:", (all:gsub("\n", " ")):sub(1, 300))
local edit = findL(function(t) return t:find("จัดเด็ค") end)
if edit then edit.Activated:Fire(); MOCK.pump(1.5) else bad("no 'จัดเด็ค' button in deck popup") end
local sv = findL(function(t) return t:find("เซฟเด็ค") end)
print("deck builder opened, save button:", sv ~= nil, sv and ("disabled=" .. tostring(sv:GetAttribute("Disabled"))) or "")
if not sv then bad("deck builder did not show Save button") end
for _, e in ipairs(MOCK.handlerErrors or {}) do bad("handler err: " .. tostring(e)) end
for _, e in ipairs(MOCK.taskErrors or {}) do bad("task err: " .. tostring(e)) end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
