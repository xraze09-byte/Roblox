MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 31, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.newInstance("Player"); me.UserId = 55; me.Name = "L"; me.DisplayName = "L"; me.Parent = Players
rawset(me, "Kick", function() end)
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch; me.Character = ch
rawset(Players, "LocalPlayer", me)
assert(pcall(H.load, path("ServerScriptService/GameServer.server.lua")))
local R = H.RS.Remotes
for _, n in ipairs({ "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }) do
	rawset(R[n], "FireClient", function(self, plr, ...) if plr == me then R[n].OnClientEvent:Fire(...) end end)
end
local calls = {}
for _, n in ipairs({ "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }) do
	rawset(R[n], "InvokeServer", function(self, ...)
		local r = table.pack(R[n].OnServerInvoke(me, ...))
		calls[#calls + 1] = n .. "(" .. tostring((...)) .. ")->" .. tostring(r[1]) .. "," .. tostring(r[2])
		return table.unpack(r, 1, r.n)
	end)
end
for _, n in ipairs({ "EndTurn", "Surrender" }) do rawset(R[n], "FireServer", function(self, ...) R[n].OnServerEvent:Fire(me, ...) end) end
Players.PlayerAdded:Fire(me); MOCK.pump(4)

local FloatHUD = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/FloatHUD.lua"))
local hudGui, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui")
rawset(hudGui, "Enabled", true)
local problems, seenErr = {}, 0
local function bad(m) if #problems < 30 then problems[#problems + 1] = m end end
local okB, eB = pcall(FloatHUD.Build, hudGui, overlay, { OnModal = function() end })
print("FloatHUD.Build:", okB, okB and "" or eB)
if not okB then return end
MOCK.pump(3)
local function allBtns()
	local o = {}
	for _, root in ipairs({ hudGui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" then o[#o + 1] = d end end end
	return o
end
local function label(b)
	local t = tostring(b.Text or "")
	if t == "" then local parts = {} for _, c in ipairs(b:GetDescendants()) do if c.ClassName == "TextLabel" and c.Text ~= "" then parts[#parts + 1] = c.Text end end return table.concat(parts, " ") end
	return t
end
local function tap(b) local ok, e = pcall(function() b.Activated:Fire() end); if not ok then bad("tap error on [" .. label(b):sub(1, 30) .. "]: " .. tostring(e)) end MOCK.pump(0.4) end
local function errsNow()
	local n = #(MOCK.handlerErrors or {}) + #(MOCK.taskErrors or {})
	if n > seenErr then
		local e = (MOCK.handlerErrors or {})[#(MOCK.handlerErrors or {})] or (MOCK.taskErrors or {})[#(MOCK.taskErrors or {})]
		bad("runtime error: " .. tostring(e)); seenErr = n
	end
end
local function visibleBtns()
	local o = {}
	for _, b in ipairs(allBtns()) do
		local vis = true; local p = b
		while p do if p.Visible == false then vis = false break end p = p.Parent end
		if vis then o[#o + 1] = b end
	end
	return o
end
local function popupCount() local n = 0 for _, d in ipairs(overlay:GetDescendants()) do if d.Name and tostring(d.Name):find("Popup") then n += 1 end end for _, d in ipairs(hudGui:GetDescendants()) do if d.Name and tostring(d.Name):find("Popup") then n += 1 end end return n end

local fabs = {}
for _, b in ipairs(allBtns()) do if tostring(b.Name):find("^Fab_") then fabs[#fabs + 1] = b end end
print("FABs found:", #fabs)
for _, f in ipairs(fabs) do print("   ", f.Name) end

-- open each FAB, list what appears, tap every row inside, then dismiss
for _, f in ipairs(fabs) do
	local before = #visibleBtns()
	tap(f); errsNow()
	local after = visibleBtns()
	local names = {}
	for _, b in ipairs(after) do local t = label(b); if t ~= "" and not tostring(b.Name):find("^Fab_") and b.Name ~= "ClickAway" then names[#names + 1] = t:gsub("\n", " "):sub(1, 22) end end
	print(("%-10s opened -> %d buttons: %s"):format(f.Name, #after - before, table.concat(names, " | "):sub(1, 220)))
	-- tap rows one by one (each may open a sub-popup); skip anything that would start a match
	for _, b in ipairs(after) do
		local t = label(b)
		if t ~= "" and not tostring(b.Name):find("^Fab_") and b.Name ~= "ClickAway" and not t:find("ยอมแพ้") then
			tap(b); errsNow()
		end
	end
	local ca = nil
	for _, b in ipairs(allBtns()) do if b.Name == "ClickAway" and b.Visible then ca = b end end
	if ca then tap(ca); errsNow() end
end
print("popups left open after all taps:", popupCount())

-- Battle: start Bot match from the lobby
for _, b in ipairs(allBtns()) do if b.Name == "Fab_Battle" then tap(b) end end
local startBtn
for _, b in ipairs(visibleBtns()) do local t = label(b); if t:find("ซ้อม") or t:find("บอท") then startBtn = b end end
print("Battle menu has bot button:", startBtn ~= nil, startBtn and label(startBtn):gsub("\n", " ") or "")
if startBtn then tap(startBtn); MOCK.pump(3) end
print("server calls:"); for i = math.max(1, #calls - 12), #calls do print("   " .. calls[i]) end
errsNow()
for _, w in ipairs(MOCK.warnings or {}) do print("WARN: " .. w) end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
