-- ServerStorage/Modules/DataService (ModuleScript)
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DEFAULT = { Gems = 100, Wins = 0, Losses = 0, Streak = 0, BestStreak = 0 }
local AUTOSAVE_INTERVAL = 120

local store
pcall(function() store = DataStoreService:GetDataStore("GawaPlayer_v1") end)

local DataService = {}
local profiles = {} -- [player] = { Data = {}, CanSave = bool }

local function key(player) return "u_" .. player.UserId end

local function reconcile(data)
	for k, v in DEFAULT do
		if data[k] == nil then data[k] = v end
	end
	return data
end

local function publish(player, data)
	player:SetAttribute("Gems", data.Gems)
	player:SetAttribute("Streak", data.Streak)
end

function DataService.Load(player)
	if profiles[player] then return end
	local data, success = nil, false
	if store then
		local tries = RunService:IsStudio() and 1 or 3
		for attempt = 1, tries do
			success = pcall(function() data = store:GetAsync(key(player)) end)
			if success then break end
			task.wait(attempt)
		end
	end
	if not player.Parent then return end
	if not success then
		if RunService:IsStudio() then
			warn("[DataService] ใช้ DataStore ไม่ได้ → ใช้ข้อมูลชั่วคราว (ไม่เซฟ) | เปิด Game Settings > Security > Enable Studio Access to API Services")
		else
			player:Kick("โหลดข้อมูลไม่สำเร็จ กรุณาเข้าเกมใหม่อีกครั้ง 🙏")
			return
		end
	end
	local profile = { Data = reconcile(typeof(data) == "table" and data or {}), CanSave = success }
	profiles[player] = profile
	publish(player, profile.Data)
end

local function save(player, profile)
	if not profile.CanSave or not store then return end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function() return profile.Data end)
	end)
	if not ok then warn("[DataService] เซฟไม่สำเร็จ " .. player.Name .. ": " .. tostring(err)) end
end

function DataService.IsLoaded(player)
	return profiles[player] ~= nil
end

function DataService.AddGems(player, amount)
	local profile = profiles[player]
	if not profile then return 0 end
	profile.Data.Gems += amount
	publish(player, profile.Data)
	return amount
end

function DataService.GetStreak(player)
	local profile = profiles[player]
	return profile and profile.Data.Streak or 0
end

function DataService.RecordResult(player, won)
	local profile = profiles[player]
	if not profile then return end
	local d = profile.Data
	if won then
		d.Wins += 1
		d.Streak += 1
		d.BestStreak = math.max(d.BestStreak, d.Streak)
	else
		d.Losses += 1
		d.Streak = 0
	end
	publish(player, d)
end

function DataService.Release(player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then save(player, profile) end
end

function DataService.SaveAll()
	local pending = 0
	for player, profile in profiles do
		pending += 1
		task.spawn(function()
			save(player, profile)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do task.wait(0.1) end
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player, profile in profiles do task.spawn(save, player, profile) end
	end
end)

return DataService