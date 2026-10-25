-- จำกัดความถี่ + กันคำสั่งซ้อน + เตะคนที่สแปม
local Players = game:GetService("Players")

local Guard = {}
local CAPACITY = 10      -- ส่งติดกันได้สูงสุด
local REFILL = 5         -- เติมโควตาต่อวินาที
local STRIKE_WINDOW = 10
local STRIKE_KICK = 120  -- ถูกปฏิเสธเกินนี้ภายใน 10 วิ = สแปม

local state = {}

local function get(player)
	local s = state[player]
	if not s then
		local now = os.clock()
		s = { tokens = CAPACITY, last = now, gaps = {}, busy = {}, strikes = 0, windowStart = now }
		state[player] = s
	end
	return s
end

local function strike(player, s, now)
	if now - s.windowStart > STRIKE_WINDOW then
		s.windowStart, s.strikes = now, 0
	end
	s.strikes += 1
	if s.strikes == STRIKE_KICK then
		warn(("[Guard] %s ส่งคำสั่งถี่ผิดปกติ ถูกเตะออก"):format(player.Name))
		player:Kick("ส่งคำสั่งถี่เกินไป กรุณาเข้าเกมใหม่")
	end
end

function Guard.Allow(player, action, minGap)
	local s = get(player)
	local now = os.clock()
	s.tokens = math.min(CAPACITY, s.tokens + (now - s.last) * REFILL)
	s.last = now
	local prev = s.gaps[action]
	if s.tokens < 1 or (prev and now - prev < (minGap or 0)) then
		strike(player, s, now)
		return false
	end
	s.tokens -= 1
	s.gaps[action] = now
	return true
end

-- คำสั่งกลุ่มเดียวกันที่ยังไม่เสร็จ จะถูกปฏิเสธทันที
function Guard.Run(player, lockKey, fn, ...)
	local s = get(player)
	if s.busy[lockKey] then return false, "BUSY" end
	s.busy[lockKey] = true
	local res = table.pack(pcall(fn, ...))
	s.busy[lockKey] = nil
	if not res[1] then
		warn(("[Guard] %s error: %s"):format(lockKey, tostring(res[2])))
		return false, "SERVER_ERROR"
	end
	return table.unpack(res, 2, res.n)
end

Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

return Guard