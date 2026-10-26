-- Lobby v2: ทุกแท็บวาดได้, เครือข่ายล้มเหลวไม่ทำให้พัง, คิว PvP/ยกเลิก, หอคอย, ปิดหน้าต่างเมื่อเริ่มแมตช์
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local LobbyUI, Config = mod("UIClient/LobbyUI.lua"), mod("Shared/Config.lua")
local M = H.M
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end
local function wait(sec) local t = os.clock() while os.clock() - t < sec do end end
local function find(root, pred) for _, d in ipairs(root:GetDescendants()) do if pred(d) then return d end end end
local function btn(root, txt) return find(root, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find(txt, 1, true) end) end
local function click(b) wait(0.3); b.Activated:Fire() end

local profile = { Gems = 120, Collection = { KAI_CHON = 2 }, Deck = {}, Pity = { Epic = 0, Legend = 0 },
	Quests = { List = { { Id = "q1", Text = "ชนะ 1 ครั้ง", Progress = 1, Goal = 1, Claimed = false, Reward = 10 } }, ResetIn = 3600 }, TowerFloor = 1 }
local calls, queueReply = {}, "WAITING"
M.handlers.GetProfile = function() return profile end
M.handlers.GetStats = function() return { Wins = 3, Losses = 1, GateRolls = 4, Matches = 4 } end
M.handlers.Queue = function(mode, leader) table.insert(calls, mode); if mode == "PvP" then return true, queueReply end if mode == "Cancel" then return true, "CANCELLED" end return true, "STARTED" end
M.handlers.GetFarms = function() return true, {}, nil end -- serverUnix = nil (บั๊ก #8 เดิม)

local hud, overlay = H.newInstance("Frame"), H.newInstance("Frame")
local ok, err = pcall(LobbyUI.Build, hud, overlay)
check("Build", ok, not ok and err or nil)
if not ok then return end
M.pump(3)
local root = find(hud, function(d) return d.Name == "LobbyRoot" end)
check("LobbyRoot", root ~= nil)

-- ทุกแท็บวาดได้ ไม่ขึ้นข้อความ "หน้านี้โหลดไม่สำเร็จ"
local TABS = { "ต่อสู้", "เด็ค", "กาชา", "เควสต์", "สถิติ", "โหมดอื่น" }
local nav = find(root, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("ต่อสู้", 1, true) end).Parent
for _, t in ipairs(TABS) do
	local b = find(nav, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find(t, 1, true) end)
	check("tab button " .. t, b ~= nil)
	if b then
		click(b); M.pump(1)
		local broke = find(root, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("โหลดไม่สำเร็จ", 1, true) end)
		check("tab " .. t .. " renders without error", broke == nil)
	end
end
check("no handler errors after tour", not (M.handlerErrors and #M.handlerErrors > 0), M.handlerErrors and M.handlerErrors[1])

-- สถิติแปลเป็นไทย (ไม่มีชื่อดิบ GateRolls)
click(find(nav, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("สถิติ", 1, true) end)); M.pump(2)
check("stats: no raw key 'GateRolls'", find(root, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("GateRolls", 1, true) end) == nil)

-- ป้ายเควสต์
local badge = find(root, function(d) return d.ClassName == "Frame" and d.Visible == true and d.ZIndex == 5 end)
check("quest badge visible when claimable", badge ~= nil)

-- PvP queue + ยกเลิก + ResetQueue
click(find(nav, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("ต่อสู้", 1, true) end)); M.pump(1)
local pvp = btn(root, "PvP")
check("PvP button exists", pvp ~= nil)
if pvp then
	click(pvp); M.pump(2)
	check("Queue PvP invoked", calls[#calls] == "PvP")
	local chip = find(root, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("หาคู่", 1, true) end)
	check("name chip shows waiting timer", chip ~= nil, chip and chip.Text)
	M.pump(3)
	chip = find(root, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("หาคู่", 1, true) end)
	check("timer counts up", chip ~= nil and not tostring(chip.Text):find(" 0 วิ", 1, true), chip and chip.Text)
	if chip then click(chip); M.pump(1) end
	check("tap name chip cancels queue", calls[#calls] == "Cancel", calls[#calls])
end

-- หอคอย: ปุ่มแท็บโหมดอื่น + ปุ่มแท็บต่อสู้ เรียก Queue("Tower") และไม่ค้างหลังตอบ
click(find(nav, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("โหมดอื่น", 1, true) end)); M.pump(1)
local tower = btn(root, "ท้าบอสชั้น")
check("tower button on Modes tab (floor 1, +15)", tower ~= nil and tostring(tower.Text):find("ชั้น 1", 1, true) ~= nil and tostring(tower.Text):find("+15", 1, true) ~= nil, tower and tower.Text)
if tower then
	click(tower); M.pump(2)
	check("Queue Tower invoked", calls[#calls] == "Tower", calls[#calls])
	click(tower); M.pump(2)
	local towers = 0 for _, c in ipairs(calls) do if c == "Tower" then towers += 1 end end
	check("Tower button usable again (not stuck)", towers == 2, towers)
end
-- ชั้นสูงขึ้นหลังชนะ: ProfileChanged ส่ง TowerFloor=2 -> ปุ่มต้องบอกชั้น 2 / รางวัล +20
profile.TowerFloor = 2
H.RS.Remotes.ProfileChanged.OnClientEvent:Fire(profile); M.pump(1)
local tower2 = btn(root, "ท้าบอสชั้น")
check("after win: shows floor 2 (+20)", tower2 ~= nil and tostring(tower2.Text):find("ชั้น 2", 1, true) ~= nil and tostring(tower2.Text):find("+20", 1, true) ~= nil, tower2 and tower2.Text)
profile.TowerFloor = Config.TOWER_MAX_FLOOR + 1
H.RS.Remotes.ProfileChanged.OnClientEvent:Fire(profile); M.pump(1)
check("beyond max floor does not error", not (M.handlerErrors and #M.handlerErrors > 0), M.handlerErrors and M.handlerErrors[1])

-- ResetQueue ปิดหน้าต่าง + ล้างคิว (ตอนเริ่มแมตช์)
check("ResetQueue exists", type(LobbyUI.ResetQueue) == "function")
local okR, eR = pcall(LobbyUI.ResetQueue)
check("ResetQueue runs", okR, eR)

-- โปรไฟล์ล้มเหลว (DATA_LOADING) แล้ว Refresh ลองใหม่จนสำเร็จ
local n = 0
M.handlers.GetProfile = function() n += 1 if n < 3 then return nil end return profile end
LobbyUI.Refresh(); M.pump(10)
check("Refresh retries until profile loads", n >= 3, n)

-- Config/server contract
check("Config has tower constants", Config.TOWER_MAX_FLOOR == 30 and Config.TOWER_REWARD_BASE == 10)
print(fails == 0 and "LOBBY_V2 PASS" or ("LOBBY_V2 FAIL " .. fails))
