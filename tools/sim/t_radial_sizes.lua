MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
SIM_SEED, SIM_RNG_N = 8, 0
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
rawset(H.game, "BindToClose", function() end)
local Players = H.game:GetService("Players")
local me = H.newInstance("Player"); me.UserId = 77; me.Name = "R"; me.DisplayName = "R"; me.Parent = Players
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
Players.PlayerAdded:Fire(me); MOCK.pump(4)
local FloatHUD = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/FloatHUD.lua"))
local sizes = { {0,0}, {1024,0}, {1024,40}, {1024,70}, {1024,72}, {1024,73}, {1920,1080}, {1280,720}, {1024,410}, {1024,300}, {980,310}, {844,390}, {667,375}, {568,320}, {400,200}, {300,120} }
local total = 0
for _, sz in ipairs(sizes) do
	local VW, VH = sz[1], sz[2]
	local hudGui, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui")
	hudGui.AbsoluteSize = H.globals.Vector2.new(VW, VH)
	FloatHUD.Build(hudGui, overlay, { OnModal = function() end }); MOCK.pump(1)
	MOCK.taskErrors, MOCK.handlerErrors = {}, {}
	print("  [probe] hud.AbsoluteSize=" .. tostring(hudGui.AbsoluteSize.X) .. "x" .. tostring(hudGui.AbsoluteSize.Y))
	local errs = {}
	local function allBtns() local o = {} for _, root in ipairs({ hudGui, overlay }) do for _, d in ipairs(root:GetDescendants()) do if d.ClassName == "TextButton" then o[#o + 1] = d end end end return o end
	for _, fabName in ipairs({ "Fab_Battle", "Fab_More", "Fab_Deck", "Fab_Gacha" }) do
		for _, b in ipairs(allBtns()) do
			if b.Name == fabName then
				local ok, e = pcall(function() b.Activated:Fire() end)
				if not ok then errs[#errs + 1] = fabName .. ": " .. tostring(e) end
				MOCK.pump(0.3)
				-- close
				for _, c in ipairs(allBtns()) do if c.Name == "ClickAway" and c.Visible then pcall(function() c.Activated:Fire() end) end end
			end
		end
	end
	for _, e in ipairs(MOCK.handlerErrors or {}) do errs[#errs + 1] = "handler: " .. tostring(e) end
	for _, e in ipairs(MOCK.taskErrors or {}) do errs[#errs + 1] = "task: " .. tostring(e) end
	local uniq, seen = {}, {}
	for _, e in ipairs(errs) do local k = e:gsub("^.-FloatHUD.lua:", "FloatHUD:"); if not seen[k] then seen[k] = true; uniq[#uniq + 1] = k end end
	total += #uniq
	print(("%4dx%-4d %s"):format(VW, VH, #uniq == 0 and "ok" or table.concat(uniq, " | "):sub(1, 150)))
end
print("RADIAL_SIZES errors:", total)
