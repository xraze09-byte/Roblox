-- ระบบ UI ลอย: FloatHUD (ปุ่มลอย/เมนูวงกลม/คิว), เมนู ☰ -> LobbyUI หน้าเดิม, ปุ่มกลับ, WorldPrompts, Juice
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local FloatHUD, LobbyUI, WorldPrompts, Juice = mod("UIClient/FloatHUD.lua"), mod("UIClient/LobbyUI.lua"), mod("UIClient/WorldPrompts.lua"), mod("UIClient/Juice.lua")
local M = H.M
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end
local function wait(sec) local t = os.clock() while os.clock() - t < sec do end end
local function find(root, pred) for _, d in ipairs(root:GetDescendants()) do if pred(d) then return d end end end
local function fab(root, id) return find(root, function(d) return d.Name == "Fab_" .. id end) end
local function btn(root, txt) return find(root, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find(txt, 1, true) end) end
local function click(b) wait(0.3); b.Activated:Fire() end

local profile = { Gems = 120, Collection = { KAI_CHON = 2 }, Deck = {}, Pity = { Epic = 0, Legend = 0 },
	Quests = { List = { { Id = "q1", Text = "ชนะ 1 ครั้ง", Progress = 1, Goal = 1, Claimed = false, Reward = 10 } }, ResetIn = 3600 }, TowerFloor = 2 }
local calls, gachaCalls = {}, 0
M.handlers.GetProfile = function() return profile end
M.handlers.GetStats = function() return { Wins = 3, Losses = 1, Matches = 4 } end
M.handlers.Queue = function(mode) table.insert(calls, mode); if mode == "PvP" then return true, "WAITING" end if mode == "Cancel" then return true, "CANCELLED" end return true, "STARTED" end
M.handlers.Gacha = function(n) gachaCalls += 1; local r = {} for i = 1, n do r[i] = { Id = "KAI_CHON", Rarity = "Common", New = i == 1 } end return true, r end
M.handlers.GetFarms = function() return true, {}, nil end

local hud, menu, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui"), H.newInstance("ScreenGui") -- ชนิดเดียวกับ init.client จริง

-- ===== FloatHUD =====
local ok, err = pcall(FloatHUD.Build, hud, overlay)
check("FloatHUD.Build", ok, not ok and err or nil)
if not ok then return end
M.pump(3)
for _, id in ipairs({ "Battle", "More", "Deck", "Gacha" }) do check("ปุ่มลอย " .. id, fab(hud, id) ~= nil) end
local gems = find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("120", 1, true) end)
check("แสดงเพชร 120 จากโปรไฟล์", gems ~= nil)

-- เมนูวงกลมของปุ่มสู้
click(fab(hud, "Battle")); M.pump(1)
check("เมนูวงกลม: ซ้อมบอท", btn(hud, "ซ้อมบอท") ~= nil)
check("เมนูวงกลม: PvP", btn(hud, "PvP") ~= nil)
check("เมนูวงกลม: หอคอยแสดงชั้นจากโปรไฟล์ (2)", btn(hud, "หอคอย 2") ~= nil)
click(btn(hud, "PvP")); M.pump(2)
check("กด PvP แล้วเรียก Queue PvP", calls[#calls] == "PvP", calls[#calls])
local battle = fab(hud, "Battle")
check("ระหว่างหาคู่ปุ่มสู้เปลี่ยนเป็น 'กำลังหา...'", find(battle, function(d) return tostring(d.Text):find("กำลังหา", 1, true) end) ~= nil)
click(battle); M.pump(1)
local cancel = btn(hud, "ยกเลิก")
check("เปิดเมนูอีกครั้งมีปุ่มยกเลิกหา", cancel ~= nil)
if cancel then click(cancel); M.pump(2) end
check("ยกเลิกแล้วเรียก Queue Cancel", calls[#calls] == "Cancel", calls[#calls])

-- กาชา
click(fab(hud, "Gacha")); M.pump(1)
local one = btn(hud, "สุ่ม 1")
check("กาชา: ปุ่มสุ่ม 1 ครั้ง", one ~= nil)
if one then click(one); M.pump(2) end
check("สุ่มแล้วเรียก Gacha 1 ครั้ง", gachaCalls == 1, gachaCalls)

-- บอท: ส่งลีดเดอร์ไปด้วย
click(fab(hud, "Battle")); M.pump(1)
click(btn(hud, "ซ้อมบอท")); M.pump(2)
check("ซ้อมบอทเรียก Queue Bot", calls[#calls] == "Bot", calls[#calls])

-- ProfileChanged อัปเดตเพชร
H.RS.Remotes.ProfileChanged.OnClientEvent:Fire({ Gems = 999, Deck = {}, Collection = {}, TowerFloor = 3 }); M.pump(2)
check("ProfileChanged อัปเดตเพชร", find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("999", 1, true) end) ~= nil)

-- ===== เมนู ☰ -> LobbyUI (หน้าเดิมต้องไม่หาย) =====
local closed = 0
local okL, errL = pcall(LobbyUI.Build, menu, overlay)
check("LobbyUI.Build (เมนูเต็ม)", okL, not okL and errL or nil)
LobbyUI.OnClose = function() closed += 1 end
M.pump(2)
for _, tab in ipairs({ "Quests", "Stats", "Modes" }) do
	LobbyUI.OpenTab(tab); M.pump(2)
	local root = find(menu, function(d) return d.Name == "LobbyRoot" end)
	local broke = root and find(root, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("โหลดไม่สำเร็จ", 1, true) end)
	check("OpenTab " .. tab .. " วาดได้", root ~= nil and broke == nil)
end
LobbyUI.OpenTab("Quests"); M.pump(2)
check("หน้าเควสต์ยังมีเควสต์เดิม", find(menu, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("ชนะ 1 ครั้ง", 1, true) end) ~= nil)
local back = btn(menu, "กลับ")
check("มีปุ่มกลับ", back ~= nil)
if back then click(back); M.pump(1) end
check("กดกลับเรียก OnClose", closed == 1, closed)

-- ===== WorldPrompts =====
local CS = H.game:GetService("CollectionService")
local part = H.newInstance("Part"); part.Name = "Head"; part.Position = H.M.vec3 and H.M.vec3(0, 0, 0) or part.Position
part:SetAttribute("Action", "Bot"); part:SetAttribute("Label", "ซ้อมบอท")
local got
local okW, errW = pcall(WorldPrompts.Start, function(a) got = a end)
check("WorldPrompts.Start", okW, not okW and errW or nil)
CS:AddTag(part, "FloatSpot"); M.pump(1)
local pgui = H.player:FindFirstChild("PlayerGui")
local bb = pgui and find(pgui, function(d) return d.Name == "Spot_Bot" end)
check("สร้างป้ายเหนือหัว NPC ใน PlayerGui", bb ~= nil)
local okE = pcall(WorldPrompts.SetEnabled, false); check("SetEnabled(false) ไม่พัง", okE)
check("ปิดแล้วป้ายถูกซ่อน", bb == nil or bb.Enabled == false)
pcall(WorldPrompts.SetEnabled, true)

-- ===== Juice =====
local f = H.newInstance("Frame")
local okJ = pcall(function() Juice.squish(f); Juice.shake(f); Juice.slam(f); Juice.popIn(f); Juice.hover(f, true) end)
check("Juice squish/shake/slam/popIn/hover ไม่พัง", okJ)
check("Juice.scaleOf สร้าง UIScale ครั้งเดียว", Juice.scaleOf(f) == Juice.scaleOf(f))

print(fails == 0 and "FLOAT PASS" or ("FLOAT FAIL " .. fails))
