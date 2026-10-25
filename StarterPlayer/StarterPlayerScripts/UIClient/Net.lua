local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}
local locks = {}

local function remote(name) return Remotes:WaitForChild(name, 10) end

-- ส่งได้ทีละคำสั่งต่อกลุ่ม: ถ้ายังไม่ตอบกลับ จะไม่ส่งซ้ำ
function Net.invokeLocked(lock, name, ...)
	if locks[lock] then return false, "BUSY" end
	local r = remote(name)
	if not r then return false, "NET_ERROR" end
	locks[lock] = true
	local res = table.pack(pcall(r.InvokeServer, r, ...))
	locks[lock] = nil
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
	BUSY = "กำลังทำคำสั่งก่อนหน้า", SLOW_DOWN = "กดเร็วเกินไป รอสักครู่",
	NET_ERROR = "เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ", SERVER_ERROR = "เซิร์ฟเวอร์ขัดข้อง ลองอีกครั้ง",
	NO_MATCH = "ไม่ได้อยู่ในแมตช์", MATCH_OVER = "แมตช์จบแล้ว", NOT_YOUR_TURN = "ยังไม่ถึงตาคุณ",
	INVALID_CARD = "ใช้การ์ดใบนี้ไม่ได้", INVALID_TARGET = "เป้าหมายไม่ถูกต้อง",
	GATE_OCCUPIED = "ช่องเกตมีการ์ดอยู่แล้ว", FIELD_FULL = "สนามเต็มแล้ว",
	NOT_ENOUGH_POINTS = "แต้มไม่พอ", NO_POINTS = "แต้มไม่พอ",
	NOT_ENOUGH_GEMS = "เพชรไม่พอ", DATA_LOADING = "กำลังโหลดข้อมูล ลองใหม่อีกครั้ง",
	IN_MATCH = "อยู่ในแมตช์แล้ว", BAD_LEADER = "เลือกผู้นำไม่ถูกต้อง", BAD_MODE = "โหมดไม่ถูกต้อง",
	NOT_DONE = "เควสต์ยังไม่สำเร็จ", ALREADY_CLAIMED = "รับรางวัลไปแล้ว", BAD_QUEST = "ไม่พบเควสต์",
	BAD_COUNT = "จำนวนครั้งไม่ถูกต้อง", EMPTY_POOL = "ตู้สุ่มยังไม่มีการ์ด",
}

function Net.message(code)
	if typeof(code) == "string" and code:find("[^%w_]") then return code end -- ข้อความไทยจากเซิร์ฟเวอร์
	return Net.Errors[code] or ("ทำไม่ได้ (" .. tostring(code) .. ")")
end

return Net