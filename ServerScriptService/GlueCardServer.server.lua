--[[
	🃏 GlueCardServer — เซิร์ฟเวอร์หลักของระบบดวลการ์ดกาว (Chaos Card Battler)
	• คุมโต๊ะดวล 3D (GlueDuelTable) + ระบบดวลด่วน (QuickPlay)
	• ระบบความยากของบอท: Easy, Normal/Medium, Hard, Hacker, Mix, Tower
	• บันทึกข้อมูลถาวร (DataService + leaderstats): Gold, Wins, Losses, Streaks, Collection
	• ระบบร้านค้าซื้อซองการ์ดกาว (BuyPack Gacha)
	• เซิร์ฟเวอร์ Remotes รองรับ Profile / Leaderboard
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

---------------------------------------------------------------------
-- ⚙️ ค่าคอนฟิกเซิร์ฟเวอร์
---------------------------------------------------------------------
local CONFIG = {
	TABLE_TAG = "GlueDuelTable",
	PROMPT_RANGE = 14,
	MAX_TABLE_DISTANCE = 40,
	MIN_WIN_SECONDS = 25,      -- ความเร็วต่ำสุดในการชนะ
	MIN_WIN_TURNS = 4,
	MIN_LOSE_SECONDS = 15,
	SECONDS_PER_TURN = 1.0,
	MAX_TURNS = 300,
	MAX_REWARDS_PER_HOUR = 25,
	PACK_COST_GOLD = 100,
}

local BOT_DIFFICULTIES = {
	Easy = {
		name = "หุ่นฝึกซ้อม (ง่าย)",
		avatar = "🤖",
		thinkTime = 1.3,
		mistakeChance = 0.35,
		winGold = 60,
		loseGold = 20,
	},
	Medium = {
		name = "บอทลุงกาว 🤖",
		avatar = "🤖",
		thinkTime = 0.9,
		mistakeChance = 0.1,
		winGold = 100,
		loseGold = 25,
	},
	Normal = {
		name = "บอทลุงกาว 🤖",
		avatar = "🤖",
		thinkTime = 0.9,
		mistakeChance = 0.1,
		winGold = 100,
		loseGold = 25,
	},
	Hard = {
		name = "ลุงกาวหัวร้อน 🔥",
		avatar = "😡",
		thinkTime = 0.6,
		mistakeChance = 0.0,
		winGold = 160,
		loseGold = 35,
	},
	Hacker = {
		name = "แฮกเกอร์สายกาว 👾",
		avatar = "👾",
		thinkTime = 0.4,
		mistakeChance = 0.0,
		cheatMana = 1,
		winGold = 250,
		loseGold = 45,
	},
	Mix = {
		name = "สุ่มระดับความกาว 🎲",
		avatar = "🎲",
		bonusGold = 50,
	},
	Tower = {
		name = "หอคอยแห่งความกาว 🗼",
		avatar = "🗼",
		winGold = 120,
		loseGold = 30,
	},
}

-- รายชื่อการ์ดสำหรับสุ่มเปิดซอง
local CHAOS_CARDS = {
	Common = {
		{ id = "chicken", name = "ไก่ย่างอมตะ", emoji = "🐔", cost = 1, atk = 500, hp = 500 },
		{ id = "cat", name = "แมวส้มจอมป่วน", emoji = "🐈", cost = 1, atk = 700, hp = 300 },
		{ id = "dog", name = "หมาวัดตัวตึง", emoji = "🐕", cost = 2, atk = 500, hp = 1500 },
		{ id = "frog", name = "กบร้องเพลงลูกทุ่ง", emoji = "🐸", cost = 2, atk = 400, hp = 800 },
		{ id = "dino", name = "ไดโนแขนสั้น", emoji = "🦖", cost = 4, atk = 2000, hp = 1600 },
		{ id = "banana", name = "เปลือกกล้วย", emoji = "🍌", cost = 1, kind = "Spell" },
		{ id = "mookata", name = "หมูกระทะฟื้นพลัง", emoji = "🥓", cost = 2, kind = "Spell" },
		{ id = "coffee", name = "กาแฟ 3 แก้ว", emoji = "☕", cost = 1, kind = "Spell" },
		{ id = "gluetube", name = "กาวตราช้าง", emoji = "🧪", cost = 0, kind = "Spell" },
	},
	Rare = {
		{ id = "uncle", name = "ลุงวินซิ่งนรก", emoji = "🛵", cost = 3, atk = 1200, hp = 800 },
		{ id = "raccoon", name = "แรคคูนขโมยหมูปิ้ง", emoji = "🦝", cost = 2, atk = 600, hp = 900 },
		{ id = "monkey", name = "ลิงขโมยมือถือ", emoji = "🐒", cost = 3, atk = 900, hp = 700 },
		{ id = "durian", name = "ทุเรียนพลีชีพ", emoji = "🍈", cost = 3, atk = 800, hp = 1000 },
		{ id = "ninja", name = "นินจาหนีหนี้", emoji = "🥷", cost = 3, atk = 1100, hp = 700 },
		{ id = "zombie", name = "ซอมบี้มนุษย์เงินเดือน", emoji = "🧟", cost = 4, atk = 1200, hp = 1300 },
		{ id = "slipper", name = "รองเท้าแตะแม่", emoji = "👡", cost = 2, kind = "Spell" },
		{ id = "bomb", name = "ระเบิดปลาร้า", emoji = "💣", cost = 4, kind = "Spell" },
		{ id = "momcall", name = "เสียงแม่เรียก", emoji = "📢", cost = 3, kind = "Spell" },
		{ id = "lag", name = "เน็ตหลุด", emoji = "📶", cost = 3, kind = "Spell" },
	},
	Legendary = {
		{ id = "grandma", name = "ยายรองเท้าแตะ", emoji = "👵", cost = 4, atk = 1300, hp = 1600 },
		{ id = "wizard", name = "พ่อมดไลฟ์สด", emoji = "🧙", cost = 5, atk = 1500, hp = 1500 },
		{ id = "buffalo", name = "ควายบึ้กพลังช้าง", emoji = "🐃", cost = 6, atk = 2500, hp = 2500 },
	},
	Glue = {
		{ id = "clown", name = "ตัวตลกหัวร้อน", emoji = "🤡", cost = 3, atk = 1000, hp = 1000 },
		{ id = "duck", name = "เป็ดยางพิฆาต", emoji = "🦆", cost = 1, atk = 100, hp = 100 },
		{ id = "dragon", name = "มังกรกาวพันปี", emoji = "🐉", cost = 7, atk = 3000, hp = 3000 },
		{ id = "dice", name = "ลูกเต๋ากาว", emoji = "🎲", cost = 2, kind = "Spell" },
	},
}

---------------------------------------------------------------------
-- 📡 1) Remotes จัดการ
---------------------------------------------------------------------
-- โฟลเดอร์ GlueCardRemotes
local glueFolder = ReplicatedStorage:FindFirstChild("GlueCardRemotes") or Instance.new("Folder")
glueFolder.Name = "GlueCardRemotes"

local function glueRemote(className, name)
	local r = glueFolder:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = glueFolder
	return r
end

local OpenTable = glueRemote("RemoteEvent", "OpenTable")
local LeaveTable = glueRemote("RemoteEvent", "LeaveTable")
local NewMatch = glueRemote("RemoteFunction", "NewMatch")
local ReportResult = glueRemote("RemoteFunction", "ReportResult")
local QuickPlay = glueRemote("RemoteEvent", "QuickPlay")
local BuyPack = glueRemote("RemoteFunction", "BuyPack")
local GetCollection = glueRemote("RemoteFunction", "GetCollection")
glueFolder.Parent = ReplicatedStorage

-- โฟลเดอร์ Remotes ทั่วไป (สำหรับ UI ระบบโปรไฟล์ / แจ้งเตือน)
local mainFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
mainFolder.Name = "Remotes"

local function mainRemote(className, name)
	local r = mainFolder:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = mainFolder
	return r
end

local GetPublicProfile = mainRemote("RemoteFunction", "GetPublicProfile")
local GetProfile = mainRemote("RemoteFunction", "GetProfile")
local SaveDeck = mainRemote("RemoteFunction", "SaveDeck")
local ProfileChanged = mainRemote("RemoteEvent", "ProfileChanged")
local NotificationRE = mainRemote("RemoteEvent", "Notification")
mainFolder.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- 💾 2) DataService & Leaderstats
---------------------------------------------------------------------
local DataService
do
	local modules = ServerStorage:FindFirstChild("Modules")
	local mod = modules and modules:FindFirstChild("DataService")
	if mod then
		local ok, res = pcall(require, mod)
		if ok then DataService = res else warn("[GlueCardServer] require DataService ไม่สำเร็จ:", res) end
	end
end

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
		g.Value = player:GetAttribute("Gold") or 500
		g.Parent = ls
	end
	local w = ls:FindFirstChild("Wins")
	if not w then
		w = Instance.new("IntValue")
		w.Name = "Wins"
		w.Value = player:GetAttribute("GlueWins") or 0
		w.Parent = ls
	end
	return ls, g, w
end

local function syncPlayerStats(player)
	if not player or not player.Parent then return end
	local data = DataService and DataService.GetData(player)
	local gold = (data and data.Gold) or player:GetAttribute("Gold") or 500
	local wins = (data and data.Wins) or player:GetAttribute("GlueWins") or 0
	local losses = (data and data.Losses) or 0
	local streak = (data and data.Streak) or player:GetAttribute("Streak") or 0

	player:SetAttribute("Gold", gold)
	player:SetAttribute("GlueWins", wins)
	player:SetAttribute("GlueMatches", wins + losses)
	player:SetAttribute("Streak", streak)

	local _, g, w = ensureLeaderstats(player)
	if g then g.Value = gold end
	if w then w.Value = wins end
end

local function onPlayerJoined(player)
	ensureLeaderstats(player)
	if DataService then
		task.spawn(function()
			DataService.Load(player)
			syncPlayerStats(player)
		end)
	end
end

local function onPlayerLeaving(player)
	if DataService then
		DataService.Release(player)
	end
end

Players.PlayerAdded:Connect(onPlayerJoined)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerJoined, p) end
Players.PlayerRemoving:Connect(onPlayerLeaving)

game:BindToClose(function()
	if DataService then
		DataService.SaveAll()
	end
end)

local function grantReward(player, gold, won, turns)
	if DataService and type(DataService.RecordResult) == "function" then
		pcall(DataService.RecordResult, player, won)
	end

	if DataService and type(DataService.AddGold) == "function" then
		local ok, err = pcall(DataService.AddGold, player, gold)
		if ok then
			syncPlayerStats(player)
			return true
		end
		warn("[GlueCardServer] AddGold error:", err)
		return false
	end

	-- สำรองกรณีไม่มี DataService
	local curGold = (player:GetAttribute("Gold") or 500) + gold
	player:SetAttribute("Gold", curGold)
	if won then
		player:SetAttribute("GlueWins", (player:GetAttribute("GlueWins") or 0) + 1)
	end
	local _, g, w = ensureLeaderstats(player)
	if g then g.Value = curGold end
	if w and won then w.Value += 1 end
	return true
end

---------------------------------------------------------------------
-- 🪑 3) Session & แมตช์
---------------------------------------------------------------------
local sessions = {}   -- [player] = { tbl, matchId, startedAt, difficulty, mode, isMix }
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
	sessions[player] = { tbl = tbl, difficulty = "Medium", mode = "Table" }
	OpenTable:FireClient(player, tbl, { difficulty = "Medium", mode = "Table" })
end

NewMatch.OnServerInvoke = function(player, options)
	local s = sessions[player]
	if not s then return nil end
	if not s.quick and distanceTo(player, s.tbl) > CONFIG.MAX_TABLE_DISTANCE then
		sessions[player] = nil
		return nil
	end
	
	if typeof(options) == "table" then
		if options.difficulty then s.difficulty = options.difficulty end
		if options.mode then s.mode = options.mode end
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
	local chosenDiff = s.difficulty or "Medium"
	local isMix = s.isMix == true
	local mode = s.mode or "Normal"
	s.matchId, s.startedAt = nil, nil -- ใช้รหัสแมตช์ได้ครั้งเดียว

	local won = data.won == true
	local turns = tonumber(data.turns)
	if not turns or turns ~= turns or turns % 1 ~= 0 or turns < 1 or turns > CONFIG.MAX_TURNS then
		return { ok = false, reason = "ข้อมูลเทิร์นผิดปกติ" }
	end
	if duration < turns * CONFIG.SECONDS_PER_TURN then
		warn(("[GlueCardServer] %s เวลาไม่สัมพันธ์กับเทิร์น: %d เทิร์น %.0f วิ"):format(player.Name, turns, duration))
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

	-- คำนวณรางวัลตามระดับความยาก
	local diffInfo = BOT_DIFFICULTIES[chosenDiff] or BOT_DIFFICULTIES.Normal
	local gold = won and (diffInfo.winGold or 100) or (diffInfo.loseGold or 25)
	if isMix and won then
		gold += (BOT_DIFFICULTIES.Mix.bonusGold or 50)
	end

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
-- 🪑 4) ติด ProximityPrompt ให้โต๊ะ GlueDuelTable
---------------------------------------------------------------------
local function promptPart(tbl)
	if tbl:IsA("BasePart") then return tbl end
	if tbl:IsA("Model") then return tbl.PrimaryPart or tbl:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function setupTable(tbl)
	if tbl:FindFirstChild("GlueDuelPrompt", true) then return end
	local part = promptPart(tbl)
	if not part then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GlueDuelPrompt"
	prompt.ActionText = "ดวลกาวการ์ด 🃏"
	prompt.ObjectText = "โต๊ะประลองการ์ดกาว"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
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
-- ⚡ 5) ดวลด่วน (QuickPlay) + เลือกระดับความยาก
---------------------------------------------------------------------
local quickCD = {}
QuickPlay.OnServerEvent:Connect(function(player, options)
	local now = os.clock()
	if quickCD[player] and now - quickCD[player] < 2 then return end
	quickCD[player] = now

	local s = sessions[player]
	if s and s.matchId then return end -- กำลังดวลอยู่
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local req = typeof(options) == "table" and options or {}
	local diff = req.difficulty or "Medium"
	local mode = req.mode or "Quick"
	local isMix = false

	if diff == "Mix" or mode == "BotMix" then
		local pool = { "Easy", "Medium", "Hard", "Hacker" }
		diff = pool[math.random(1, #pool)]
		isMix = true
	end

	sessions[player] = {
		quick = true,
		difficulty = diff,
		mode = mode,
		isMix = isMix,
	}

	OpenTable:FireClient(player, nil, {
		difficulty = diff,
		mode = mode,
		isMix = isMix,
		chaos = req.chaos,
	})
end)
Players.PlayerRemoving:Connect(function(player)
	quickCD[player] = nil
end)

---------------------------------------------------------------------
-- 🛒 6) ร้านค้าซื้อซองการ์ดกาว (BuyPack Gacha)
---------------------------------------------------------------------
local function pullOneCard()
	local roll = math.random(1, 100)
	local tier
	if roll <= 3 then
		tier = "Glue"
	elseif roll <= 12 then
		tier = "Legendary"
	elseif roll <= 40 then
		tier = "Rare"
	else
		tier = "Common"
	end
	local list = CHAOS_CARDS[tier] or CHAOS_CARDS.Common
	local item = list[math.random(1, #list)]
	return {
		id = item.id,
		name = item.name,
		emoji = item.emoji,
		rarity = tier,
		kind = item.kind or "Monster",
		atk = item.atk,
		hp = item.hp,
		cost = item.cost,
	}
end

BuyPack.OnServerInvoke = function(player)
	local data = DataService and DataService.GetData(player)
	local currentGold = (data and data.Gold) or player:GetAttribute("Gold") or 0
	if currentGold < CONFIG.PACK_COST_GOLD then
		return { ok = false, reason = "เหรียญ Gold ไม่พอ (ต้องใช้ " .. CONFIG.PACK_COST_GOLD .. " Gold)" }
	end

	-- หักเงิน
	if DataService and type(DataService.AddGold) == "function" then
		DataService.AddGold(player, -CONFIG.PACK_COST_GOLD)
	else
		player:SetAttribute("Gold", currentGold - CONFIG.PACK_COST_GOLD)
	end

	-- สุ่มการ์ด 3 ใบต่อซอง
	local pulled = {}
	for _ = 1, 3 do
		local c = pullOneCard()
		table.insert(pulled, c)
		if data then
			data.Collection = data.Collection or {}
			data.Collection[c.id] = (data.Collection[c.id] or 0) + 1
		end
	end

	if DataService then
		DataService.Touch(player)
	end
	syncPlayerStats(player)

	return {
		ok = true,
		cards = pulled,
		newGold = (data and data.Gold) or player:GetAttribute("Gold") or 0,
	}
end

GetCollection.OnServerInvoke = function(player)
	local data = DataService and DataService.GetData(player)
	return {
		ok = true,
		collection = (data and data.Collection) or {},
		gold = (data and data.Gold) or player:GetAttribute("Gold") or 0,
	}
end

---------------------------------------------------------------------
-- 👤 7) ข้อมูลโปรไฟล์สาธารณะ (GetPublicProfile)
---------------------------------------------------------------------
local function buildPublicProfile(targetPlayer)
	if not targetPlayer then return nil end
	local data = DataService and DataService.GetData(targetPlayer)
	local wins = (data and data.Wins) or targetPlayer:GetAttribute("GlueWins") or 0
	local losses = (data and data.Losses) or 0
	local streak = (data and data.Streak) or targetPlayer:GetAttribute("Streak") or 0
	local gold = (data and data.Gold) or targetPlayer:GetAttribute("Gold") or 0

	return {
		UserId = targetPlayer.UserId,
		Name = targetPlayer.Name,
		DisplayName = targetPlayer.DisplayName,
		Wins = wins,
		Losses = losses,
		Matches = wins + losses,
		Streak = streak,
		BestStreak = (data and data.BestStreak) or streak,
		Gold = gold,
		Collection = (data and data.Collection) or {},
		Deck = (data and data.Deck) or {},
		TowerFloor = targetPlayer:GetAttribute("TowerFloor") or 1,
	}
end

GetPublicProfile.OnServerInvoke = function(player, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId) or player
	local prof = buildPublicProfile(target)
	if not prof then return false, "NOT_FOUND" end
	return true, prof
end

GetProfile.OnServerInvoke = function(player)
	local prof = buildPublicProfile(player)
	if not prof then return false, "NOT_FOUND" end
	return true, prof
end

SaveDeck.OnServerInvoke = function(player, ids)
	local data = DataService and DataService.GetData(player)
	if data and typeof(ids) == "table" then
		data.Deck = ids
		DataService.Touch(player)
		return true
	end
	return true
end

print("[GlueCardServer] ✅ ระบบดวลการ์ดกาว + ความยากบอท + ระบบเหรียญ Gold พร้อมทำงาน!")
