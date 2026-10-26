-- Net: ล็อกกันซ้อน / timeout ปลดล็อก / ผลลัพธ์ผ่านปกติ
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local Net = mod("UIClient/Net.lua"); local M = H.M; local T = H.globals.task
local fails = 0
local function check(n, c, x) print((c and "ok   " or "FAIL ") .. n .. (x ~= nil and ("  " .. tostring(x)) or "")) if not c then fails += 1 end end

-- 1) ปกติ: คืนค่าหลายตัวได้
M.handlers.GetProfile = function() T.wait(0.2); return true, "A", 7 end
local r1; T.spawn(function() r1 = table.pack(Net.invoke("GetProfile")) end); M.pump(1)
check("ผลลัพธ์ผ่านปกติ", r1 and r1[1] == true and r1[2] == "A" and r1[3] == 7)

-- 2) ซ้อนกัน: ตัวที่ 2-3 ต้องโดน BUSY และ handler ถูกเรียกครั้งเดียว
local calls, res = 0, {}
M.handlers.GetProfile = function() calls += 1; T.wait(0.3); return "ok" end
for i = 1, 3 do T.spawn(function() res[i] = table.pack(Net.invoke("GetProfile")) end) end
M.pump(1)
check("ซ้อน 3 ครั้ง handler ถูกเรียก 1 ครั้ง", calls == 1, calls)
check("ตัวที่ 2 ได้ BUSY", res[2] and res[2][1] == false and res[2][2] == "BUSY", res[2] and res[2][2])
check("ตัวที่ 3 ได้ BUSY", res[3] and res[3][2] == "BUSY")
check("ตัวแรกได้ผลปกติ", res[1] and res[1][1] == "ok")
check("เสร็จแล้วปลดล็อก", Net.busy("GetProfile") == false)

-- 3) เซิร์ฟเวอร์ไม่ตอบ: ต้อง timeout ที่ 15 วิ และปลดล็อก
M.handlers.GetProfile = function() T.wait(999); return "never" end
local r3; T.spawn(function() r3 = table.pack(Net.invoke("GetProfile")) end)
M.pump(5)
check("ยังรออยู่ที่ 5 วิ (ล็อกอยู่)", r3 == nil and Net.busy("GetProfile") == true)
M.pump(12)
check("หลัง 15 วิได้ TIMEOUT", r3 and r3[1] == false and r3[2] == "TIMEOUT", r3 and tostring(r3[2]))
check("timeout แล้วปลดล็อก", Net.busy("GetProfile") == false)
check("ข้อความ TIMEOUT เป็นไทย", Net.message("TIMEOUT"):find("ตอบช้า", 1, true) ~= nil)

-- 4) หลัง timeout เรียกใหม่ได้
M.handlers.GetProfile = function() return "again" end
local r4; T.spawn(function() r4 = table.pack(Net.invoke("GetProfile")) end); M.pump(1)
check("หลัง timeout เรียกใหม่ได้", r4 and r4[1] == "again")

-- 5) handler error: ต้องไม่ปล่อยล็อกค้าง
M.handlers.GetProfile = function() error("boom") end
local r5; T.spawn(function() r5 = table.pack(Net.invoke("GetProfile")) end); M.pump(1)
check("handler พัง -> NET_ERROR", r5 and r5[1] == false and r5[2] == "NET_ERROR", r5 and tostring(r5[2]))
check("handler พังแล้วไม่ล็อกค้าง", Net.busy("GetProfile") == false)

check("message(nil) ไม่ error", Net.message(nil) ~= nil)
print(fails == 0 and "NET PASS" or ("NET FAIL " .. fails))
