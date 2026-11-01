--[[
	🃏 GlueCardServer — ระบบโต๊ะดวล + รับผลแมตช์ + แจกรางวัล
	วางที่: ServerScriptService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local ConfigModule = Shared and Shared:FindFirstChild("Config")
local GlobalConfig = ConfigModule and require(ConfigModule)
local GLUE_CONFIG = GlobalConfig and GlobalConfig.GLUE_CARD

local CONFIG = {
	TABLE_TAG = "GlueDuelTable",
	PROMPT_RANGE = 12,
	MAX_TABLE_DISTANCE = 35,
	MIN_WIN_SECONDS = GLUE_CONFIG and GLUE_CONFIG.MIN_WIN_SECONDS or 60,      -- ชนะเร็วกว่านี้ = ไม่ให้รางวัล
	MIN_WIN_TURNS = 6,
	MIN_LOSE_SECONDS = 30,     -- กันกดแพ้รัวๆ เพื่อฟาร์มรางวัลปลอบใจ
	SECONDS_PER_TURN = 1.5,    -- แต่ละเทิร์นมีแอนิเมชัน ใช้เวลาน้อยกว่านี้ไม่ได้
	MAX_TURNS = 300,
	WIN_GOLD = GLUE_CONFIG and GLUE_CONFIG.WIN_GOLD or 100,
	LOSE_GOLD = GLUE_CONFIG and GLUE_CONFIG.LOSE_GOLD or 20,
	MAX_REWARDS_PER_HOUR = 15,
}

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local folder = ReplicatedStorage:FindFirstChild("GlueCardRemotes") or Instance.new("Folder")
folder.Name = "GlueCardRemotes"
local function remote(className, name)
	local r = folder:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end
local OpenTable = remote("RemoteEvent", "OpenTable")
local LeaveTable = remote("RemoteEvent", "LeaveTable")
local NewMatch = remote("RemoteFunction", "NewMatch")
local ReportResult = remote("RemoteFunction", "ReportResult")
local QuickPlay = remote("RemoteEvent", "QuickPlay")
folder.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- 💾 เชื่อม DataService
---------------------------------------------------------------------
local DataService
do
	local modules = ServerStorage:FindFirstChild("Modules")
	local mod = modules and modules:FindFirstChild("DataService")
	if mod then
		local ok, res = pcall(require, mod)
		if ok then DataService = res else warn("[GlueCard] require DataService ไม่สำเร็จ:", res) end
	end
end

-- สร้าง / ซิงค์ leaderstats สำหรับแสดงผลคะแนน Gold บนหน้าจอ
local function ensureLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local g = ls:FindFirstChild("Gold")
	if not g then
		g = Instance.new("IntValue")
		g.Name = "Gold"
		g.Value = player:GetAttribute("Gold") or 0
		g.Parent = ls
	end
	return ls, g
end

Players.PlayerAdded:Connect(ensureLeaderstats)
for _, p in ipairs(Players:GetPlayers()) do ensureLeaderstats(p) end

local function grantReward(player, gold, won, turns)
	if DataService and type(DataService.RecordResult) == "function" then
		pcall(DataService.RecordResult, player, won)
	end

	if DataService and type(DataService.AddGold) == "function" then
		local ok, err = pcall(DataService.AddGold, player, gold)
		if ok then
			local _, g = ensureLeaderstats(player)
			g.Value = player:GetAttribute("Gold") or g.Value
			return true
		end
		warn("[GlueCard] AddGold error:", err)
		return false
	end

	-- สำรองไว้เทสต์: เพิ่มใน leaderstats
	local _, g = ensureLeaderstats(player)
	g.Value += gold
	return true
end

---------------------------------------------------------------------
-- 🪑 Session
---------------------------------------------------------------------
local sessions = {}   -- [player] = { tbl, matchId, startedAt }
local rewardLog = {}  -- [userId] = { เวลาที่รับรางวัล }

local function distanceTo(player, tbl)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not tbl or not tbl.Parent then return math.huge end
	return (hrp.Position - tbl:GetPivot().Position).Magnitude
end

local function takeRewardSlot(player)
	local now = os.time()
	local fresh = {}
	for _, t in ipairs(rewardLog[player.UserId] or {}) do
		if now - t < 3600 then table.insert(fresh, t) end
	end
	rewardLog[player.UserId] = fresh
	if #fresh >= CONFIG.MAX_REWARDS_PER_HOUR then return false end
	table.insert(fresh, now)
	return true
end

local function onTableTriggered(player, tbl)
	if distanceTo(player, tbl) > CONFIG.MAX_TABLE_DISTANCE then return end
	sessions[player] = { tbl = tbl } -- ถ้ามีแมตช์ค้างอยู่ จะถูกยกเลิก (ไม่ได้รางวัล)
	OpenTable:FireClient(player, tbl)
end

NewMatch.OnServerInvoke = function(player)
	local s = sessions[player]
	if not s then return nil end
	if not s.quick and distanceTo(player, s.tbl) > CONFIG.MAX_TABLE_DISTANCE then
		sessions[player] = nil
		return nil
	end
	s.matchId = HttpService:GenerateGUID(false)
	s.startedAt = os.clock()
	return s.matchId
end

ReportResult.OnServerInvoke = function(player, matchId, data)
	if type(matchId) ~= "string" or #matchId > 64 or type(data) ~= "table" then
		return { ok = false, reason = "ข้อมูลไม่ถูกต้อง" }
	end
	local s = sessions[player]
	if not s or not s.matchId or s.matchId ~= matchId then
		return { ok = false, reason = "ไม่พบแมตช์นี้ (หรือส่งผลไปแล้ว)" }
	end
	local duration = os.clock() - s.startedAt
	s.matchId, s.startedAt = nil, nil -- ✅ ใช้รหัสแมตช์ได้ครั้งเดียว

	local won = data.won == true
	local turns = tonumber(data.turns)
	if not turns or turns ~= turns or turns % 1 ~= 0 or turns < 1 or turns > CONFIG.MAX_TURNS then
		return { ok = false, reason = "ข้อมูลเทิร์นผิดปกติ" }
	end
	if duration < turns * CONFIG.SECONDS_PER_TURN then
		warn(("[GlueCard] %s เวลาไม่สัมพันธ์กับเทิร์น: %d เทิร์น %.0f วิ"):format(player.Name, turns, duration))
		return { ok = true, gold = 0, reason = "ข้อมูลแมตช์แปลกๆ ระบบไม่นับรางวัล 🤨" }
	end
	if won and (turns < CONFIG.MIN_WIN_TURNS or duration < CONFIG.MIN_WIN_SECONDS) then
		return { ok = true, gold = 0, reason = "ชนะไวเกินไป ระบบไม่นับรางวัล 🤨" }
	end
	if not won and duration < CONFIG.MIN_LOSE_SECONDS then
		return { ok = true, gold = 0, reason = "แพ้ไวไป ไม่ได้รางวัลปลอบใจ 😅" }
	end
	player:SetAttribute("GlueMatches", (player:GetAttribute("GlueMatches") or 0) + 1)
	if won then player:SetAttribute("GlueWins", (player:GetAttribute("GlueWins") or 0) + 1) end
	if not takeRewardSlot(player) then
		return { ok = true, gold = 0, reason = "รับรางวัลครบโควตาชั่วโมงนี้แล้ว พักก่อนนะ ☕" }
	end

	local gold = won and CONFIG.WIN_GOLD or CONFIG.LOSE_GOLD
	if not grantReward(player, gold, won, turns) then
		return { ok = false, reason = "บันทึกข้อมูลไม่สำเร็จ" }
	end
	return { ok = true, gold = gold, won = won }
end

LeaveTable.OnServerEvent:Connect(function(player)
	sessions[player] = nil
end)
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

---------------------------------------------------------------------
-- 🪑 ใส่ ProximityPrompt ให้ทุกโต๊ะที่มี Tag "GlueDuelTable"
---------------------------------------------------------------------
local function promptPart(tbl)
	if tbl:IsA("BasePart") then return tbl end
	if tbl:IsA("Model") then return tbl.PrimaryPart or tbl:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function setupTable(tbl)
	if tbl:FindFirstChild("GlueDuelPrompt", true) then return end
	local part = promptPart(tbl)
	if not part then
		warn("[GlueCard] โต๊ะไม่มี BasePart ให้ติด Prompt:", tbl:GetFullName())
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GlueDuelPrompt"
	prompt.ActionText = "ดวลกาวการ์ด 🃏"
	prompt.ObjectText = "โต๊ะบอทลุงกาว"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = CONFIG.PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		onTableTriggered(player, tbl)
	end)
end

for _, t in ipairs(CollectionService:GetTagged(CONFIG.TABLE_TAG)) do setupTable(t) end
CollectionService:GetInstanceAddedSignal(CONFIG.TABLE_TAG):Connect(setupTable)

---------------------------------------------------------------------
-- ⚡ ดวลด่วน (ไม่ต้องเดินไปโต๊ะ)
---------------------------------------------------------------------
local quickCD = {}
QuickPlay.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if quickCD[player] and now - quickCD[player] < 3 then return end
	quickCD[player] = now
	local s = sessions[player]
	if s and s.matchId then return end -- กำลังดวลอยู่
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	sessions[player] = { quick = true }
	OpenTable:FireClient(player, nil)
end)
Players.PlayerRemoving:Connect(function(player)
	quickCD[player] = nil
end)
