-- ReplicatedStorage/Shared/UI/Perf.lua
-- ระดับกราฟิก: นอกแมตช์ = High, ในแมตช์ = Balanced, FPS ตกต่อเนื่อง = Low อัตโนมัติ
local RunService = game:GetService("RunService")

local UI = script.Parent
local Settings = require(UI:WaitForChild("Settings"))
local themeMod = UI:FindFirstChild("Theme") or UI.Parent:FindFirstChild("Theme")
local Theme = themeMod and require(themeMod) or {}

local Perf = {}
Perf.PROFILES = {
	High     = { spinHz = 60, shineTier = 2,  pulse = true,  ambient = true,  sparkle = 1,    shake = true,  death = "full",   hudHz = 60 },
	Balanced = { spinHz = 24, shineTier = 4,  pulse = false, ambient = false, sparkle = 0.5,  shake = true,  death = "simple", hudHz = 20 },
	Low      = { spinHz = 0,  shineTier = 99, pulse = false, ambient = false, sparkle = 0.25, shake = false, death = "none",   hudHz = 0 },
}

local changed = Instance.new("BindableEvent")
Perf.Changed = changed.Event
Perf.inMatch = false

local current, autoLow, drops = "High", false, 0

local function resolve()
	local q = Settings.Get("Quality") or "Auto"
	if q ~= "Auto" and Perf.PROFILES[q] then return q end
	if not Perf.inMatch then return "High" end
	return autoLow and "Low" or "Balanced"
end

local function refresh()
	local name = resolve()
	if name ~= current then
		current = name
		changed:Fire(name)
	end
end

function Perf.Name() return current end
function Perf.get(key) return Perf.PROFILES[current][key] end

-- ปรับจำนวนอนุภาคตามระดับกราฟิก
function Perf.count(n)
	local k = Perf.get("sparkle")
	if k <= 0 then return 0 end
	return math.max(1, math.floor((n or 0) * k + 0.5))
end

function Perf.allowShine(rarity)
	local tiers = Theme.RarityTier or {}
	return (tiers[rarity] or 1) >= Perf.get("shineTier")
end

function Perf.SetMatch(on)
	on = on == true
	if Perf.inMatch == on then return end
	Perf.inMatch, autoLow, drops = on, false, 0
	refresh()
end

Settings.Changed:Connect(function(key)
	if key == "Quality" then refresh() end
end)

if RunService:IsClient() then
	local fps, lowT, highT = 60, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if dt > 0.5 then return end -- ข้ามช่วงย่อจอ/สลับแท็บ
		fps += (1 / math.max(dt, 1 / 240) - fps) * 0.05
		if not Perf.inMatch then return end
		if fps < 40 then lowT += dt; highT = 0
		elseif fps > 55 then highT += dt; lowT = 0 end
		if not autoLow and lowT > 3 then
			autoLow, drops, lowT = true, drops + 1, 0
			refresh()
		elseif autoLow and drops < 2 and highT > 8 then -- ตกครั้งที่ 2 = ล็อก Low ทั้งแมตช์
			autoLow, highT = false, 0
			refresh()
		end
	end)
end

refresh()
return Perf