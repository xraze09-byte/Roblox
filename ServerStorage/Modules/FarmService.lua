-- ฟาร์ม: เซิร์ฟเวอร์เป็นคนคำนวณทุกอย่างจากเวลาเซิร์ฟเวอร์ ไคลเอนต์ส่งมาแค่ id ของฟาร์ม
-- data.Farms[id] = { Level = n, LastClaim = unix วินาที }
local FarmService = {}

local MAX_LEVEL = 10

-- ผลิตเป็นเพชรทั้งหมด (สกุลเงินเดียวที่เกมมี) ค่าต่ำมากเพื่อไม่ให้ทำลายสมดุลกาชา
FarmService.Defs = {
	GlueGarden = { Name = "สวนกาว", Emoji = "🌻", Rate = 1, Cap = 20, UpgradeBase = 40 },
	GemMine = { Name = "เหมืองเจม", Emoji = "💎", Rate = 2, Cap = 30, UpgradeBase = 80 },
	MemePond = { Name = "บ่อเลี้ยงมีม", Emoji = "🐸", Rate = 1, Cap = 40, UpgradeBase = 60 },
}
FarmService.Order = { "GlueGarden", "GemMine", "MemePond" }

FarmService.Clock = os.time -- ทดสอบแทนที่ได้
local function now() return FarmService.Clock() end

local function stateOf(data, id)
	if typeof(data.Farms) ~= "table" then data.Farms = {} end
	local f = data.Farms[id]
	if typeof(f) ~= "table" then
		f = { Level = 1, LastClaim = now() }
		data.Farms[id] = f
	end
	f.Level = math.clamp(math.floor(tonumber(f.Level) or 1), 1, MAX_LEVEL)
	f.LastClaim = math.min(tonumber(f.LastClaim) or now(), now()) -- เวลาในอนาคต (ข้อมูลเสีย) ไม่ให้นับ
	return f
end

local function rateOf(def, level) return def.Rate * level end           -- ต่อนาที
local function capOf(def, level) return def.Cap * level end
local function upgradeCost(def, level) return def.UpgradeBase * level end

local function stored(def, f)
	local minutes = math.max(0, now() - f.LastClaim) / 60
	return math.min(capOf(def, f.Level), math.floor(minutes * rateOf(def, f.Level)))
end

local function view(id, def, f)
	return {
		Id = id, Name = def.Name, Emoji = def.Emoji, Level = f.Level,
		Rate = rateOf(def, f.Level), Cap = capOf(def, f.Level), LastClaim = f.LastClaim,
		UpgradeCost = f.Level < MAX_LEVEL and upgradeCost(def, f.Level) or nil,
	}
end

-- เวลาเป็น unix วินาที (ไคลเอนต์ใช้ serverNow เทียบ)
function FarmService.List(data)
	local out = {}
	for _, id in FarmService.Order do
		table.insert(out, view(id, FarmService.Defs[id], stateOf(data, id)))
	end
	return out, now()
end

-- คืน ok, จำนวนเพชรที่ได้ | ok=false, รหัสข้อผิดพลาด
function FarmService.Claim(data, id)
	local def = typeof(id) == "string" and FarmService.Defs[id]
	if not def then return false, "BAD_FARM" end
	local f = stateOf(data, id)
	local amount = stored(def, f)
	if amount < 1 then return false, "NOTHING_TO_CLAIM" end
	-- เก็บเฉพาะส่วนที่จ่ายจริง เศษนาทีที่เหลือไม่หาย
	local paidMinutes = amount / rateOf(def, f.Level)
	f.LastClaim = math.min(now(), f.LastClaim + math.ceil(paidMinutes * 60))
	if amount >= capOf(def, f.Level) then f.LastClaim = now() end -- เต็มแล้ว ส่วนเกินทิ้ง
	data.Gems += amount
	return true, amount
end

-- คืน ok, ข้อมูลฟาร์มใหม่ | ok=false, รหัสข้อผิดพลาด
function FarmService.Upgrade(data, id)
	local def = typeof(id) == "string" and FarmService.Defs[id]
	if not def then return false, "BAD_FARM" end
	local f = stateOf(data, id)
	if f.Level >= MAX_LEVEL then return false, "MAX_LEVEL" end
	local cost = upgradeCost(def, f.Level)
	if (data.Gems or 0) < cost then return false, "NOT_ENOUGH_GEMS" end
	-- จ่ายของที่สะสมไว้ก่อนอัปเกรด ไม่งั้นอัตราใหม่จะคิดย้อนหลังให้เวลาเดิม
	local pending = stored(def, f)
	data.Gems -= cost
	if pending > 0 then data.Gems += pending end
	f.Level += 1
	f.LastClaim = now()
	return true, view(id, def, f)
end

return FarmService
