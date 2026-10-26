-- ระบบ UI ลอย: FloatHUD (ปุ่มลอย/เมนูวงกลม/คิว), เมนู ☰ -> LobbyUI หน้าเดิม, ปุ่มกลับ, WorldPrompts, Juice
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local FloatHUD, WorldPrompts, Juice = mod("UIClient/FloatHUD.lua"), mod("UIClient/WorldPrompts.lua"), mod("UIClient/Juice.lua")
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

local hud, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui") -- ชนิดเดียวกับ init.client จริง

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
check("เมนูวงกลม: หอคอยแสดงชั้นจากโปรไฟล์ (2)", btn(hud, "หอคอย ชั้น 2") ~= nil)
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
H.RS.Remotes.ProfileChanged.OnClientEvent:Fire({ Gems = 999, Deck = {}, Collection = {}, TowerFloor = 3, Quests = profile.Quests }); M.pump(2) -- เซิร์ฟเวอร์ส่งโปรไฟล์เต็มเสมอ
check("ProfileChanged อัปเดตเพชร", find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("999", 1, true) end) ~= nil)

-- ===== เมนู ☰ -> เควสต์/สถิติ/ฟาร์มเป็น popup (ไม่มี LobbyUI แล้ว) =====
M.handlers.ClaimQuest = function(id) return true, 10 end
M.handlers.GetFarms = function() return true, { { Id = "f1", Name = "ฟาร์มแรก", Level = 1, Rate = 2, Cap = 100, LastClaim = 0, UpgradeCost = 50 } }, 600 end
M.handlers.ClaimFarm = function() return true, 20 end
M.handlers.GetStats = function() return { Total = { Matches = 4, Wins = 3, Losses = 1, Derived = { WinRate = 75 } }, Today = {}, Streak = 2, BestStreak = 3 } end
click(fab(hud, "More")); M.pump(1)
check("เมนู ☰: เควสต์", btn(hud, "เควสต์") ~= nil)
check("เมนู ☰: สถิติ", btn(hud, "สถิติ") ~= nil)
check("เมนู ☰: ฟาร์ม", btn(hud, "ฟาร์ม") ~= nil)
check("ปุ่มเมนู มีตัวเลขแจ้งเตือนเควสต์ที่รับได้", find(fab(hud, "More"), function(d) return d.Name == "Badge" and d.Visible end) ~= nil)
click(btn(hud, "เควสต์")); M.pump(2)
check("popup เควสต์แสดงเควสต์เดิม", find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("ชนะ 1 ครั้ง", 1, true) end) ~= nil)
local claim = btn(hud, "รับ")
check("ปุ่มรับรางวัลเควสต์ที่สำเร็จแล้ว", claim ~= nil)
if claim then click(claim); M.pump(2) end
check("รับแล้วเปลี่ยนเป็น 'รับแล้ว'", find(hud, function(d) return d.ClassName == "TextButton" and tostring(d.Text):find("รับแล้ว", 1, true) end) ~= nil)
-- ☰ เป็นสวิตช์: กดตอน popup ของมันเปิดอยู่ = ปิด (ครั้งที่ 1) แล้วกดอีกครั้ง = เปิดเมนูใหม่ (ครั้งที่ 2)
click(fab(hud, "More")); M.pump(1.2)
check("กด ☰ ตอน popup เปิดอยู่ = ปิด popup", find(hud, function(d) return d.Name == "FloatPanel" end) == nil)
click(fab(hud, "More")); M.pump(1)
check("เมนู ☰ เปิดซ้ำได้หลังปิด popup", btn(hud, "สถิติ") ~= nil)
click(btn(hud, "สถิติ")); M.pump(2)
check("popup สถิติแสดงอัตราชนะ 75%", find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("75.0%", 1, true) end) ~= nil)
click(fab(hud, "More")); M.pump(1.2) -- ปิด popup สถิติ
click(fab(hud, "More")); M.pump(1)
check("เมนู ☰ เปิดได้อีกรอบ (ฟาร์ม)", btn(hud, "ฟาร์ม") ~= nil)
click(btn(hud, "ฟาร์ม")); M.pump(2)
check("popup ฟาร์มแสดงฟาร์ม", find(hud, function(d) return d.ClassName == "TextLabel" and tostring(d.Text):find("ฟาร์มแรก", 1, true) end) ~= nil)
check("ไม่มี handler error ในชุด popup", #(M.handlerErrors or {}) == 0, (M.handlerErrors or {})[1])

-- เข้าแมตช์: ปุ่มลอยต้องถูกซ่อน และกลับมาเมื่อออก
FloatHUD.EnterMatch(); M.pump(1)
check("EnterMatch ซ่อน HUD", hud.Enabled == false)
FloatHUD.ExitMatch(); M.pump(1)
check("ExitMatch คืน HUD", hud.Enabled == true)


-- ===== บั๊กที่รายงาน: #4 คลิกในกล่อง popup ไม่ปิดเอง =====
click(fab(hud, "Gacha")); M.pump(1)
local panel = find(hud, function(d) return d.Name == "FloatPanel" end)
check("#4 popup เป็น TextButton (กินคลิก ไม่ทะลุไป ClickAway)", panel ~= nil and panel.ClassName == "TextButton", panel and panel.ClassName)
local away = find(hud, function(d) return d.Name == "ClickAway" end)
check("#4 คลิกในกล่อง ไม่ทำให้กล่องปิด", (function() if panel then panel.Activated:Fire() end M.pump(1); return find(hud, function(d) return d.Name == "FloatPanel" end) ~= nil end)())
if away then away.Activated:Fire(); M.pump(1) end
M.pump(2)
check("#4 คลิกที่ว่างนอกกล่อง = ปิด", find(hud, function(d) return d.Name == "FloatPanel" and d.Visible end) == nil)

-- ===== #7 ตอบ STARTED ต้องไม่ขึ้น 'กำลังหา' / ตอบ WAITING ต้องขึ้น =====
local replyMode = "STARTED"
M.handlers.Queue = function(mode) table.insert(calls, mode); if mode == "Cancel" then return true, "CANCELLED" end return true, replyMode end
click(fab(hud, "Battle")); M.pump(1); click(btn(hud, "PvP")); M.pump(2)
check("#7 ตอบ STARTED -> ปุ่มสู้ไม่ขึ้น 'กำลังหา'", find(fab(hud, "Battle"), function(d) return tostring(d.Text):find("กำลังหา", 1, true) end) == nil)
replyMode = "WAITING"
click(fab(hud, "Battle")); M.pump(1); click(btn(hud, "PvP")); M.pump(2)
check("#7 ตอบ WAITING -> ขึ้น 'กำลังหา'", find(fab(hud, "Battle"), function(d) return tostring(d.Text):find("กำลังหา", 1, true) end) ~= nil)
click(fab(hud, "Battle")); M.pump(1)
local cancel2 = btn(hud, "ยกเลิก"); if cancel2 then click(cancel2); M.pump(2) end

-- ===== #8 เปิดหน้าจัดเด็ค: ปุ่มลอยถูกซ่อน + ปุ่มในฉากถูกปิด =====
local modalLog = {}
FloatHUD.Build(hud, overlay, { OnModal = function(open) table.insert(modalLog, open) end }); M.pump(3)
click(fab(hud, "Deck")); M.pump(1)
local edit = btn(hud, "จัดเด็ค")
if edit then click(edit); M.pump(2) end
check("#8 มีปุ่มจัดเด็คให้กด", edit ~= nil)
check("#8 เปิดจัดเด็คแล้วแจ้ง OnModal(true) (ปิดปุ่มในฉาก)", modalLog[#modalLog] == true, tostring(modalLog[#modalLog]))
check("#8 เปิดจัดเด็คแล้ว HUD ถูกซ่อน", hud.Enabled == false, tostring(hud.Enabled))

-- ===== #9 Refresh ซ้อนกันไม่ได้ =====
local getProfileCalls = 0
-- เครือข่ายจริง yield (InvokeServer ต้องรอ) จึงจำลองด้วย task.wait ใน handler
M.handlers.GetProfile = function() getProfileCalls += 1; H.globals.task.wait(0.3); return profile end
M.pump(3) -- ให้ Refresh ที่ค้างจาก Build จบก่อน
getProfileCalls = 0
FloatHUD.Refresh(); FloatHUD.Refresh(); FloatHUD.Refresh(); M.pump(3)
check("#9 Refresh 3 ครั้งติดกัน ยิง GetProfile ไม่เกิน 1 ครั้ง", getProfileCalls <= 1, getProfileCalls)

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
