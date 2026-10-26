-- StarterPlayerScripts/UIClient/Net.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}
local locks = {}
local TIMEOUT = 15

local function remote(name)
	local r = Remotes:WaitForChild(name, 10)
	if not r then warn("[Net] ไม่พบ Remote: " .. tostring(name)) end
	return r
end

-- InvokeServer แบบมีเวลาหมด: เซิร์ฟเวอร์ค้าง/หลุด ปุ่มจะไม่ล็อกตลอดไป
local function invokeTimeout(r, ...)
	local thread = coroutine.running()
	local args = table.pack(...)
	local done, waiting, result = false, false, nil
	local function finish(res)
		if done then return end
		done, result = true, res
		if waiting then task.spawn(thread, res) end
	end
	task.spawn(function()
		finish(table.pack(pcall(r.InvokeServer, r, table.unpack(args, 1, args.n))))
	end)
	task.delay(TIMEOUT, finish, false)
	if done then return result end
	waiting = true
	return coroutine.yield()
end

function Net.invokeLocked(lock, name, ...)
	if locks[lock] then return false, "BUSY" end
	local r = remote(name)
	if not r then return false, "NET_ERROR" end
	locks[lock] = true
	local res = invokeTimeout(r, ...)
	locks[lock] = nil
	if res == false then
		warn("[Net] " .. name .. ": หมดเวลา")
		return false, "TIMEOUT"
	end
	if not res[1] then
		warn("[Net] " .. name .. ": " .. tostring(res[2]))
		return false, "NET_ERROR"
	end
	return table.unpack(res, 2, res.n)
end

function Net.invoke(name, ...) return Net.invokeLocked(name, name, ...) end
function Net.busy(lock) return locks[lock] == true end
function Net.fire(name, ...)
	local r = remote(name)
	if r then r:FireServer(...) end
end
function Net.on(name, fn)
	local r = remote(name)
	if r then return r.OnClientEvent:Connect(fn) end
	return nil
end

Net.Errors = {
	BUSY = "กำลังทำคำสั่งก่อนหน้า", SLOW_DOWN = "กดเร็วเกินไป รอสักครู่", TIMEOUT = "เซิร์ฟเวอร์ตอบช้า ลองใหม่อีกครั้ง",
	NET_ERROR = "เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ", SERVER_ERROR = "เซิร์ฟเวอร์ขัดข้อง ลองอีกครั้ง",
	NO_MATCH = "ไม่ได้อยู่ในแมตช์", MATCH_OVER = "แมตช์จบแล้ว", NOT_YOUR_TURN = "ยังไม่ถึงตาคุณ",
	INVALID_CARD = "ใช้การ์ดใบนี้ไม่ได้", INVALID_TARGET = "เป้าหมายไม่ถูกต้อง",
	GATE_OCCUPIED = "ช่องเกตมีการ์ดอยู่แล้ว", FIELD_FULL = "สนามเต็มแล้ว",
	NOT_ENOUGH_POINTS = "แต้มไม่พอ", NO_POINTS = "แต้มไม่พอ",
	NOT_ENOUGH_GEMS = "เพชรไม่พอ", DATA_LOADING = "กำลังโหลดข้อมูล ลองใหม่อีกครั้ง",
	IN_MATCH = "อยู่ในแมตช์แล้ว", BAD_LEADER = "เลือกผู้นำไม่ถูกต้อง", BAD_MODE = "โหมดไม่ถูกต้อง",
	NOT_DONE = "เควสต์ยังไม่สำเร็จ", ALREADY_CLAIMED = "รับรางวัลไปแล้ว", BAD_QUEST = "ไม่พบเควสต์",
	BAD_COUNT = "จำนวนครั้งไม่ถูกต้อง", EMPTY_POOL = "ตู้สุ่มยังไม่มีการ์ด",
	BAD_FARM = "ไม่พบฟาร์มนี้", NOTHING_TO_CLAIM = "ยังไม่มีของให้เก็บ", MAX_LEVEL = "เลเวลสูงสุดแล้ว",
}

function Net.message(code)
	if code == nil then return "ทำไม่ได้ ลองใหม่อีกครั้ง" end
	if typeof(code) == "string" and code:find("[^%w_]") then return code end -- ข้อความไทยจากเซิร์ฟเวอร์
	return Net.Errors[code] or ("ทำไม่ได้ (" .. tostring(code) .. ")")
end

return Net
