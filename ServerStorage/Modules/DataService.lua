local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatsService = require(ServerStorage:WaitForChild("Modules"):WaitForChild("StatsService"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decks = require(Shared:WaitForChild("Decks"))
local DeckRules = require(Shared:WaitForChild("DeckRules"))

local DEFAULT = {
	Gems = 100, Wins = 0, Losses = 0, Streak = 0, BestStreak = 0,
	Collection = {}, Deck = {}, Pity = { Epic = 0, Legend = 0 },
	Quests = { Day = 0, List = {} }, Farms = {},
}
local AUTOSAVE_INTERVAL = 120

local store
pcall(function() store = DataStoreService:GetDataStore("GawaPlayer_v1") end)

local DataService = {}
DataService.OnChanged = nil -- GameServer ตั้งให้ (ส่งโปรไฟล์ใหม่ไปไคลเอนต์)
local profiles = {}

local function key(player) return "u_" .. player.UserId end

local function deepCopy(v)
	if typeof(v) ~= "table" then return v end
	local t = {}
	for k, x in v do t[k] = deepCopy(x) end
	return t
end

local function reconcile(data)
	for k, v in DEFAULT do
		if data[k] == nil then data[k] = deepCopy(v) end -- ก๊อปใหม่ทุกครั้ง ไม่ใช้ตารางร่วมกัน
	end
	if typeof(data.Collection) ~= "table" then data.Collection = {} end
	if typeof(data.Deck) ~= "table" then data.Deck = {} end
	if typeof(data.Pity) ~= "table" then data.Pity = {} end
	data.Pity.Epic = tonumber(data.Pity.Epic) or 0
	data.Pity.Legend = tonumber(data.Pity.Legend) or 0
	if typeof(data.Quests) ~= "table" then data.Quests = { Day = 0, List = {} } end
	if typeof(data.Farms) ~= "table" then data.Farms = {} end
	if next(data.Collection) == nil then
		for _, id in Decks.Starter do data.Collection[id] = (data.Collection[id] or 0) + 1 end
	end
	if not DeckRules.Validate(data.Deck, data.Collection) then
		data.Deck = table.clone(Decks.Starter)
	end
	StatsService.Reconcile(data)
	return data
end

local function publish(player, data)
	player:SetAttribute("Gems", data.Gems)
	player:SetAttribute("Streak", data.Streak)
end

local function changed(player)
	local profile = profiles[player]
	if not profile then return end
	publish(player, profile.Data)
	if DataService.OnChanged then task.spawn(DataService.OnChanged, player) end
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
			warn("[DataService] ใช้ DataStore ไม่ได้ ใช้ข้อมูลชั่วคราว (ไม่เซฟ) | เปิด Game Settings > Security > Enable Studio Access to API Services")
		else
			player:Kick("โหลดข้อมูลไม่สำเร็จ กรุณาเข้าเกมใหม่อีกครั้ง")
			return
		end
	end
	local profile = { Data = reconcile(typeof(data) == "table" and data or {}), CanSave = success }
	profiles[player] = profile
	changed(player)
end

local function save(player, profile)
	if not profile.CanSave or not store then return end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function() return profile.Data end)
	end)
	if not ok then warn("[DataService] เซฟไม่สำเร็จ " .. player.Name .. ": " .. tostring(err)) end
end

function DataService.IsLoaded(player) return profiles[player] ~= nil end
function DataService.Touch(player) changed(player) end

function DataService.AddGems(player, amount)
	local profile = profiles[player]
	if not profile then return 0 end
	profile.Data.Gems += amount
	changed(player)
	return amount
end

function DataService.GetData(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.GetStats(player)
	local profile = profiles[player]
	return profile and StatsService.Snapshot(profile.Data) or nil
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