-- ReplicatedStorage/Shared/UI/Settings (ModuleScript)
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Settings = {}
local values = {
	Sfx = 1,              -- 0–1
	AnimSpeed = 1,        -- 0.5 / 1 / 1.5 / 2
	Effects = true,       -- แสงวิ้งบนการ์ด + ประกายพื้นหลัง
	DamageNumbers = true,
	TargetArrow = true,
	Quality = "Auto",     -- ใหม่: "Auto" | "High" | "Balanced" | "Low"
}
local changed = Instance.new("BindableEvent")
Settings.Changed = changed.Event

local function applySfx(v)
	local folder = SoundService:FindFirstChild("SFX")
	if not folder then return end
	for _, s in ipairs(folder:GetDescendants()) do
		if s:IsA("Sound") then
			if s:GetAttribute("BaseVolume") == nil then s:SetAttribute("BaseVolume", s.Volume) end
			s.Volume = s:GetAttribute("BaseVolume") * v
		end
	end
end

function Settings.Get(key) return values[key] end

function Settings.Set(key, value)
	if values[key] == value then return end
	values[key] = value
	if key == "Sfx" and RunService:IsClient() then applySfx(value) end
	changed:Fire(key, value)
end

return Settings