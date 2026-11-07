--!strict
--[[
	🃏 GlueCardServer.server.lua
	ระบบเซิร์ฟเวอร์หลัก Gawa Card Battle (Complete Edition)
	• DataStoreService ("GawaPlayer_v1") + Autosave 120s + BindToClose + leaderstats
	• กาชาเปิดซอง (BuyPack 100 Gold -> 3 ใบ: Common 60%, Rare 28%, Legendary 9%, Glue 3%)
	• ระบบ PvE บอท 5 ระดับ (Easy, Medium, Hard, Hacker, Mix)
	• ระบบ Real PvP 1v1 Queue (+150G ชนะ / +40G ปลอบใจ)
	• ระบบ Custom PvP 1v1 เลือกคนท้าดวลเจาะจง (0 Gold ไม่เสีย/ไม่ได้เหรียญ)
	• Server Action Relay (PlayCard, Attack, Spell, Ult, EndTurn, Taunt) + Forfeit Protection
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------
-- 📡 สร้างโฟลเดอร์ GlueCardRemotes และ Remote ทั้งหมด
---------------------------------------------------------------------
local glueFolder = ReplicatedStorage:FindFirstChild("GlueCardRemotes") :: Folder
if not glueFolder then
	glueFolder = Instance.new("Folder")
	glueFolder.Name = "GlueCardRemotes"
	glueFolder.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string): any
	local existing = glueFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = glueFolder
	return inst
end

-- Core Match & Economy Remotes
local OpenTable = ensureRemote("RemoteEvent", "OpenTable") :: RemoteEvent
local LeaveTable = ensureRemote("RemoteEvent", "LeaveTable") :: RemoteEvent
local QuickPlay = ensureRemote("RemoteEvent", "QuickPlay") :: RemoteEvent
local ProfileChanged = ensureRemote("RemoteEvent", "ProfileChanged") :: RemoteEvent
local NewMatch = ensureRemote("RemoteFunction", "NewMatch") :: RemoteFunction
local ReportResult = ensureRemote("RemoteFunction", "ReportResult") :: RemoteFunction
local BuyPack = ensureRemote("RemoteFunction", "BuyPack") :: RemoteFunction
local GetCollection = ensureRemote("RemoteFunction", "GetCollection") :: RemoteFunction
local ClaimQuest = ensureRemote("RemoteFunction", "ClaimQuest") :: RemoteFunction

-- PvP Queue & Relay Remotes
local JoinPvPQueue = ensureRemote("RemoteEvent", "JoinPvPQueue") :: RemoteEvent
local LeavePvPQueue = ensureRemote("RemoteEvent", "LeavePvPQueue") :: RemoteEvent
local StartPvP = ensureRemote("RemoteEvent", "StartPvP") :: RemoteEvent
local PvPAction = ensureRemote("RemoteEvent", "PvPAction") :: RemoteEvent
local PvPActionRelay = ensureRemote("RemoteEvent", "PvPActionRelay") :: RemoteEvent
local PvPMatchEnd = ensureRemote("RemoteEvent", "PvPMatchEnd") :: RemoteEvent

-- Custom PvP Direct Challenge Remotes (โหมดเจาะจง 0 Gold)
local SendCustomChallenge = ensureRemote("RemoteEvent", "SendCustomChallenge") :: RemoteEvent
local IncomingCustomChallenge = ensureRemote("RemoteEvent", "IncomingCustomChallenge") :: RemoteEvent
local RespondCustomChallenge = ensureRemote("RemoteEvent", "RespondCustomChallenge") :: RemoteEvent

---------------------------------------------------------------------
-- 🃏 ฐานข้อมูลการ์ดกาวทั้ง 26 ใบ (Chaos Card Pool)
---------------------------------------------------------------------
export type CardDef = {
	id: string,
	name: string,
	emoji: string,
	rarity: string,
	cardType: string,
	cost: number,
	atk: number,
	hp: number,
	desc: string,
}

local ALL_CARDS: { CardDef } = {
	-- Monsters (17 ใบ)
	{ id = "chicken", name = "ไก่ย่างอมตะ", emoji = "🐔", rarity = "Common", cardType = "Monster", cost = 2, atk = 700, hp = 800, desc = "ฟื้นชีพ (Rebirth): ตายแล้วลุกขึ้นมาใหม่ด้วยเลือด 50% 1 ครั้ง" },
	{ id = "cat", name = "แมวส้มจอมป่วน", emoji = "🐈", rarity = "Common", cardType = "Monster", cost = 2, atk = 900, hp = 700, desc = "ซิ่ง (Rush): โจมตีได้ทันทีในเทิร์นที่ลงสนาม!" },
	{ id = "dog", name = "หมาวัดตัวตึง", emoji = "🐕", rarity = "Common", cardType = "Monster", cost = 3, atk = 800, hp = 1500, desc = "โล่ (Taunt): บังคับให้ศัตรูต้องตีเจ้าตูบตัวนี้ก่อน" },
	{ id = "frog", name = "กบร้องเพลงลูกทุ่ง", emoji = "🐸", rarity = "Common", cardType = "Monster", cost = 3, atk = 800, hp = 1000, desc = "ลงสนาม: เรียกลูกอ๊อดวัยซน (500/500) ลงช่องว่างข้างๆ" },
	{ id = "uncle", name = "ลุงวินซิ่งนรก", emoji = "🛵", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1400, hp = 1100, desc = "ซิ่ง (Rush): บิดหมดปลอก พุ่งชนได้ทันทีที่ลงสนาม" },
	{ id = "raccoon", name = "แรคคูนขโมยหมูปิ้ง", emoji = "🦝", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1000, hp = 1200, desc = "ต้นเทิร์นเรา: ดูด 300 LP จากฮีโร่ศัตรูมาเพิ่มให้เรา" },
	{ id = "monkey", name = "ลิงขโมยมือถือ", emoji = "🐒", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1100, hp = 1000, desc = "ซิ่งดูด LP 250 เมื่อโจมตี + มีโอกาสหลบหลีก (Dodge 25%)" },
	{ id = "durian", name = "ทุเรียนพลีชีพ", emoji = "🍈", rarity = "Rare", cardType = "Monster", cost = 3, atk = 900, hp = 1100, desc = "พลีชีพ: เมื่อตาย ระเบิดกลิ่นทุเรียนใส่ศัตรูทุกตัว 600 ดาเมจ!" },
	{ id = "ninja", name = "นินจาหนีหนี้", emoji = "🥷", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1500, hp = 1000, desc = "หลบเก่งจัด: มีโอกาส 40% หลบการโจมตีแบบไร้รอยขีดข่วน" },
	{ id = "zombie", name = "ซอมบี้มนุษย์เงินเดือน", emoji = "🧟", rarity = "Common", cardType = "Monster", cost = 4, atk = 1100, hp = 1400, desc = "ฟื้นชีพ (Rebirth): ตายไม่ได้เพราะยังผ่อนรถไม่หมด!" },
	{ id = "dino", name = "ไดโนแขนสั้น", emoji = "🦖", rarity = "Legendary", cardType = "Monster", cost = 5, atk = 2300, hp = 1800, desc = "พลังตบมหาศาล แต่แขนสั้นจัด มีโอกาสตีวืด 25%" },
	{ id = "grandma", name = "ยายรองเท้าแตะ", emoji = "👵", rarity = "Legendary", cardType = "Monster", cost = 4, atk = 1300, hp = 1400, desc = "ลงสนาม: ปารองเท้าแตะใส่ศัตรูแบบสุ่ม 700 ดาเมจทันที" },
	{ id = "wizard", name = "พ่อมดไลฟ์สด", emoji = "🧙", rarity = "Rare", cardType = "Monster", cost = 4, atk = 1100, hp = 1200, desc = "ลงสนาม: กดกระดิ่งไลฟ์สด จั่วการ์ดเพิ่ม 2 ใบทันที!" },
	{ id = "buffalo", name = "ควายบึ้กพลังช้าง", emoji = "🐃", rarity = "Legendary", cardType = "Monster", cost = 6, atk = 2000, hp = 2400, desc = "โล่ (Taunt) + ซิ่ง (Rush): วิ่งชนแหลก ถึกทนทานสุดในรุ่น" },
	{ id = "clown", name = "ตัวตลกหัวร้อน", emoji = "🤡", rarity = "Rare", cardType = "Monster", cost = 3, atk = 1200, hp = 1200, desc = "ลงสนาม: สลับค่า ATK กับ HP ของมอนสเตอร์ศัตรูทุกตัว!" },
	{ id = "duck", name = "เป็ดยางพิฆาต", emoji = "🦆", rarity = "Common", cardType = "Monster", cost = 2, atk = 800, hp = 700, desc = "หลบหลีก 30% และเมื่อตายระเบิดเสียงก๊าบใส่ศัตรูทุกตัว 450" },
	{ id = "dragon", name = "มังกรกาวพันปี", emoji = "🐉", rarity = "Glue", cardType = "Monster", cost = 7, atk = 2500, hp = 2500, desc = "บอสใหญ่สายกาว! ลงสนามปุ๊บ เติมหลอดกาว +50% ทันที!" },

	-- Spells (9 ใบ)
	{ id = "banana", name = "เปลือกกล้วย", emoji = "🍌", rarity = "Common", cardType = "Spell", cost = 2, atk = 0, hp = 0, desc = "วางกับดัก: ศัตรูที่สั่งโจมตีครั้งถัดไปจะลื่นล้มหัวฟาด 600 ดาเมจและอดตี!" },
	{ id = "slipper", name = "รองเท้าแตะแม่", emoji = "👡", rarity = "Rare", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ปาแม่นราวจับวาง! ทำดาเมจ 1,500 ใส่มอนสเตอร์ศัตรูที่ ATK สูงสุด" },
	{ id = "bomb", name = "ระเบิดปลาร้า", emoji = "💣", rarity = "Rare", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ไหปลาร้าแตก! ทำดาเมจ 800 ใส่มอนสเตอร์ศัตรูทุกตัวบนสนาม" },
	{ id = "dice", name = "ลูกเต๋ากาว", emoji = "🎲", rarity = "Glue", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "ทอยเต๋า 1-6 สุ่มผลสุดปั่น (1=เจ็บเอง 500, 6=เสกยูนิคอร์น 2200/2000!)" },
	{ id = "mookata", name = "หมูกระทะฟื้นพลัง", emoji = "🥓", rarity = "Common", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "เยียวยาทุกสิ่ง: ฟื้น 1,500 LP ฮีโร่เรา และฮีลมอนสเตอร์เราทุกตัว +600" },
	{ id = "momcall", name = "เสียงแม่เรียก", emoji = "📢", rarity = "Rare", cardType = "Spell", cost = 3, atk = 0, hp = 0, desc = "แม่เรียกกินข้าว! ดีดมอนสเตอร์ศัตรูที่เก่งที่สุดกลับขึ้นมือ" },
	{ id = "coffee", name = "กาแฟ 3 แก้ว", emoji = "☕", rarity = "Legendary", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ดีดจัด! มอนสเตอร์เราทุกตัว ATK +300 และพร้อมโจมตีอีกครั้ง" },
	{ id = "lag", name = "เน็ตหลุด", emoji = "📶", rarity = "Legendary", cardType = "Spell", cost = 4, atk = 0, hp = 0, desc = "ปิง 999ms! แช่แข็งมอนสเตอร์ศัตรูทุกตัว ห้ามโจมตี 1 เทิร์น" },
	{ id = "gluetube", name = "กาวตราช้าง", emoji = "🧪", rarity = "Glue", cardType = "Spell", cost = 2, atk = 0, hp = 0, desc = "เติมหลอดกาวไม้ตาย +35% ทันที และจั่วการ์ดเพิ่ม 1 ใบ" },
}

local CARDS_BY_RARITY: { [string]: { CardDef } } = {
	Common = {},
	Rare = {},
	Legendary = {},
	Glue = {},
}
for _, c in ipairs(ALL_CARDS) do
	table.insert(CARDS_BY_RARITY[c.rarity], c)
end

---------------------------------------------------------------------
-- 🤖 ตั้งค่าบอท 5 ระดับความยาก (PvE Bot Difficulties)
---------------------------------------------------------------------
local BOT_DIFFICULTIES: { [string]: { name: string, thinkTime: number, mistakeChance: number, reward: number, cheatMana: number } } = {
	Easy = { name = "🟢 หุ่นฝึกซ้อม", thinkTime = 1.3, mistakeChance = 0.35, reward = 60, cheatMana = 0 },
	Medium = { name = "🟡 บอทลุงกาว", thinkTime = 0.9, mistakeChance = 0.15, reward = 100, cheatMana = 0 },
	Normal = { name = "🟡 บอทลุงกาว", thinkTime = 0.9, mistakeChance = 0.15, reward = 100, cheatMana = 0 },
	Hard = { name = "🟠 ลุงกาวหัวร้อน", thinkTime = 0.6, mistakeChance = 0.0, reward = 160, cheatMana = 0 },
	Hacker = { name = "🔴 แฮกเกอร์สายกาว", thinkTime = 0.4, mistakeChance = 0.0, reward = 250, cheatMana = 1 },
}

---------------------------------------------------------------------
-- 💾 ระบบข้อมูลผู้เล่นถาวร (DataStore "GawaPlayer_v1")
---------------------------------------------------------------------
export type PlayerProfile = {
	Gold: number,
	Wins: number,
	Losses: number,
	Streak: number,
	BestStreak: number,
	PacksOpened: number,
	Collection: { [string]: number },
	QuestsClaimed: { [string]: boolean },
}

local playerStore: DataStore? = nil
pcall(function()
	playerStore = DataStoreService:GetDataStore("GawaPlayer_v1")
end)

local profiles: { [number]: PlayerProfile } = {}

local function defaultProfile(): PlayerProfile
	return {
		Gold = 300, -- เงินเริ่มต้นเปิดซองได้ทันที 3 ซอง!
		Wins = 0,
		Losses = 0,
		Streak = 0,
		BestStreak = 0,
		PacksOpened = 0,
		Collection = {
			chicken = 2,
			cat = 2,
			dog = 2,
			frog = 1,
			banana = 2,
			mookata = 1,
			gluetube = 1,
		},
		QuestsClaimed = {},
	}
end

local function reconcileProfile(raw: any): PlayerProfile
	local def = defaultProfile()
	if type(raw) ~= "table" then
		return def
	end
	def.Gold = tonumber(raw.Gold) or def.Gold
	def.Wins = tonumber(raw.Wins) or 0
	def.Losses = tonumber(raw.Losses) or 0
	def.Streak = tonumber(raw.Streak) or 0
	def.BestStreak = tonumber(raw.BestStreak) or 0
	def.PacksOpened = tonumber(raw.PacksOpened) or 0
	if type(raw.Collection) == "table" then
		def.Collection = {}
		for k, v in pairs(raw.Collection) do
			if type(k) == "string" and tonumber(v) and tonumber(v) > 0 then
				def.Collection[k] = math.floor(tonumber(v) :: number)
			end
		end
	end
	if type(raw.QuestsClaimed) == "table" then
		for k, v in pairs(raw.QuestsClaimed) do
			def.QuestsClaimed[tostring(k)] = (v == true)
		end
	end
	return def
end

local function syncPlayerStats(player: Player)
	local prof = profiles[player.UserId]
	if not prof then return end

	local ls = player:FindFirstChild("leaderstats") :: Folder
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local goldVal = ls:FindFirstChild("Gold") :: IntValue
	if not goldVal then
		goldVal = Instance.new("IntValue")
		goldVal.Name = "Gold"
		goldVal.Parent = ls
	end
	local winsVal = ls:FindFirstChild("Wins") :: IntValue
	if not winsVal then
		winsVal = Instance.new("IntValue")
		winsVal.Name = "Wins"
		winsVal.Parent = ls
	end

	goldVal.Value = prof.Gold
	winsVal.Value = prof.Wins

	player:SetAttribute("Gold", prof.Gold)
	player:SetAttribute("GlueWins", prof.Wins)
	player:SetAttribute("GlueLosses", prof.Losses)
	player:SetAttribute("GlueMatches", prof.Wins + prof.Losses)
	player:SetAttribute("GlueStreak", prof.Streak)
	player:SetAttribute("GluePacksOpened", prof.PacksOpened)

	ProfileChanged:FireClient(player, {
		Gold = prof.Gold,
		Wins = prof.Wins,
		Losses = prof.Losses,
		Streak = prof.Streak,
		PacksOpened = prof.PacksOpened,
		Collection = prof.Collection,
		QuestsClaimed = prof.QuestsClaimed,
	})
end

local function loadProfile(player: Player)
	local loaded: any = nil
	if playerStore then
		local ok, res = pcall(function()
			return (playerStore :: DataStore):GetAsync("Player_" .. tostring(player.UserId))
		end)
		if ok then
			loaded = res
		end
	end
	profiles[player.UserId] = reconcileProfile(loaded)
	if player:GetAttribute("GlueInDuel") == nil then
		player:SetAttribute("GlueInDuel", false)
	end
	syncPlayerStats(player)
end

local function saveProfile(player: Player)
	local prof = profiles[player.UserId]
	if not prof or not playerStore then return end
	pcall(function()
		(playerStore :: DataStore):SetAsync("Player_" .. tostring(player.UserId), prof)
	end)
end

local function saveAllProfiles()
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(saveProfile, plr)
	end
end

-- Autosave ทุก 120 วินาที
task.spawn(function()
	while true do
		task.wait(120)
		saveAllProfiles()
	end
end)

if not RunService:IsStudio() then
	game:BindToClose(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			saveProfile(plr)
		end
	end)
end

---------------------------------------------------------------------
-- 🛒 ระบบเปิดซองกาชา (BuyPack: 100 Gold -> 3 Cards)
-- Common 60%, Rare 28%, Legendary 9%, Glue 3%
---------------------------------------------------------------------
local function rollOneCard(): CardDef
	local r = math.random(1, 100)
	local rarity = "Common"
	if r <= 3 then
		rarity = "Glue"
	elseif r <= 12 then
		rarity = "Legendary"
	elseif r <= 40 then
		rarity = "Rare"
	else
		rarity = "Common"
	end
	local pool = CARDS_BY_RARITY[rarity]
	if not pool or #pool == 0 then
		pool = ALL_CARDS
	end
	return pool[math.random(1, #pool)]
end

BuyPack.OnServerInvoke = function(player: Player)
	local prof = profiles[player.UserId]
	if not prof then
		return { ok = false, reason = "ข้อมูลผู้เล่นยังโหลดไม่เสร็จ" }
	end
	if prof.Gold < 100 then
		return { ok = false, reason = "Gold ไม่พอ! ต้องใช้ 100 Gold 🪙" }
	end

	prof.Gold -= 100
	prof.PacksOpened += 1

	local pulled = {}
	for i = 1, 3 do
		local c = rollOneCard()
		prof.Collection[c.id] = (prof.Collection[c.id] or 0) + 1
		table.insert(pulled, {
			id = c.id,
			name = c.name,
			emoji = c.emoji,
			rarity = c.rarity,
			cardType = c.cardType,
			cost = c.cost,
			atk = c.atk,
			hp = c.hp,
			desc = c.desc,
			count = prof.Collection[c.id],
		})
	end

	syncPlayerStats(player)
	return {
		ok = true,
		gold = prof.Gold,
		cards = pulled,
		collection = prof.Collection,
	}
end

GetCollection.OnServerInvoke = function(player: Player)
	local prof = profiles[player.UserId]
	if not prof then
		prof = defaultProfile()
		profiles[player.UserId] = prof
	end
	return {
		collection = prof.Collection,
		allCards = ALL_CARDS,
		gold = prof.Gold,
		wins = prof.Wins,
		losses = prof.Losses,
		streak = prof.Streak,
		packsOpened = prof.PacksOpened,
		questsClaimed = prof.QuestsClaimed,
	}
end

---------------------------------------------------------------------
-- 📜 ระบบเควสต์กาวประจำวัน (ClaimQuest)
---------------------------------------------------------------------
local QUEST_DEFS: { [string]: { reward: number, check: (PlayerProfile) -> boolean } } = {
	first_win = {
		reward = 150,
		check = function(p) return p.Wins >= 1 end,
	},
	win_3 = {
		reward = 300,
		check = function(p) return p.Wins >= 3 end,
	},
	open_pack = {
		reward = 120,
		check = function(p) return p.PacksOpened >= 1 end,
	},
	collector_10 = {
		reward = 250,
		check = function(p)
			local unique = 0
			for _, cnt in pairs(p.Collection) do
				if cnt > 0 then unique += 1 end
			end
			return unique >= 10
		end,
	},
}

ClaimQuest.OnServerInvoke = function(player: Player, questId: any)
	local qid = tostring(questId or "")
	local def = QUEST_DEFS[qid]
	local prof = profiles[player.UserId]
	if not def or not prof then
		return { ok = false, reason = "ไม่พบเควสต์นี้" }
	end
	if prof.QuestsClaimed[qid] then
		return { ok = false, reason = "รับรางวัลเควสต์นี้ไปแล้ว!" }
	end
	if not def.check(prof) then
		return { ok = false, reason = "ยังไม่ผ่านเงื่อนไขเควสต์!" }
	end
	prof.QuestsClaimed[qid] = true
	prof.Gold += def.reward
	syncPlayerStats(player)
	return { ok = true, reward = def.reward, gold = prof.Gold, questsClaimed = prof.QuestsClaimed }
end

---------------------------------------------------------------------
-- ⚔️ ระบบจัดการแมตช์ PvE บอท & Real PvP 1v1 + Custom Mode
---------------------------------------------------------------------
type ActiveBotMatch = {
	matchId: string,
	difficulty: string,
	actualDiff: string,
	isMix: boolean,
	startTime: number,
}

type ActivePvPMatch = {
	matchId: string,
	p1: Player,
	p2: Player,
	turnUserId: number,
	isCustom: boolean, -- true = โหมดเจาะจง 0 Gold
	startTime: number,
}

local botSessions: { [number]: ActiveBotMatch } = {}
local pvpQueue: { Player } = {}
local pvpMatchesByPlayer: { [number]: ActivePvPMatch } = {}
local pendingChallenges: { [number]: { challenger: Player, timestamp: number } } = {}

local function removeFromQueue(player: Player)
	for i = #pvpQueue, 1, -1 do
		if pvpQueue[i] == player then
			table.remove(pvpQueue, i)
		end
	end
end

local function findNearestDuelTable(player: Player): Model?
	local tagged = CollectionService:GetTagged("GlueDuelTable")
	if #tagged > 0 then
		return tagged[1] :: Model
	end
	local t = workspace:FindFirstChild("CardTable")
	if t and t:IsA("Model") then
		return t
	end
	return nil
end

-- เริ่มแมตช์บอท (NewMatch)
NewMatch.OnServerInvoke = function(player: Player, requestedDiff: any)
	removeFromQueue(player)
	local diffKey = tostring(requestedDiff or "Medium")
	local isMix = (diffKey == "Mix")
	local actualKey = diffKey
	if isMix then
		local pool = { "Easy", "Medium", "Hard", "Hacker" }
		actualKey = pool[math.random(1, #pool)]
	end
	if not BOT_DIFFICULTIES[actualKey] then
		actualKey = "Medium"
	end

	local botCfg = BOT_DIFFICULTIES[actualKey]
	local matchId = HttpService:GenerateGUID(false)
	botSessions[player.UserId] = {
		matchId = matchId,
		difficulty = diffKey,
		actualDiff = actualKey,
		isMix = isMix,
		startTime = os.clock(),
	}
	player:SetAttribute("GlueInDuel", true)

	local totalReward = botCfg.reward + (isMix and 50 or 0)
	return {
		matchId = matchId,
		difficulty = diffKey,
		actualDifficulty = actualKey,
		botName = botCfg.name .. (isMix and " (🎲Mix)" or ""),
		thinkTime = botCfg.thinkTime,
		mistakeChance = botCfg.mistakeChance,
		cheatMana = botCfg.cheatMana,
		reward = totalReward,
		isMix = isMix,
	}
end

-- ส่งผลการดวล (ReportResult)
ReportResult.OnServerInvoke = function(player: Player, matchId: any, payload: any)
	local prof = profiles[player.UserId]
	if not prof then
		return { ok = false }
	end
	local won = type(payload) == "table" and payload.won == true

	-- กรณีจบจาก PvP
	local pvp = pvpMatchesByPlayer[player.UserId]
	if pvp and pvp.matchId == tostring(matchId) then
		local other = (pvp.p1 == player) and pvp.p2 or pvp.p1
		pvpMatchesByPlayer[pvp.p1.UserId] = nil
		pvpMatchesByPlayer[pvp.p2.UserId] = nil
		pvp.p1:SetAttribute("GlueInDuel", false)
		pvp.p2:SetAttribute("GlueInDuel", false)

		local winGold = pvp.isCustom and 0 or 150
		local loseGold = pvp.isCustom and 0 or 40

		local winner = won and player or other
		local loser = won and other or player

		local winProf = profiles[winner.UserId]
		if winProf then
			winProf.Gold += winGold
			winProf.Wins += 1
			winProf.Streak += 1
			if winProf.Streak > winProf.BestStreak then
				winProf.BestStreak = winProf.Streak
			end
			syncPlayerStats(winner)
		end

		local loseProf = profiles[loser.UserId]
		if loseProf then
			loseProf.Gold += loseGold
			loseProf.Losses += 1
			loseProf.Streak = 0
			syncPlayerStats(loser)
		end

		PvPMatchEnd:FireClient(winner, {
			won = true,
			goldEarned = winGold,
			isCustom = pvp.isCustom,
			reason = pvp.isCustom and "ชนะศึกสายกาว Custom Mode! (0 Gold)" or "ชนะดวล PvP 1v1!",
		})
		PvPMatchEnd:FireClient(loser, {
			won = false,
			goldEarned = loseGold,
			isCustom = pvp.isCustom,
			reason = pvp.isCustom and "พ่ายแพ้ในโหมด Custom (0 Gold)" or "พ่ายแพ้ศึก PvP (รับค่าปลอบใจ)",
		})

		return {
			ok = true,
			goldEarned = won and winGold or loseGold,
			totalGold = prof.Gold,
			isCustom = pvp.isCustom,
		}
	end

	-- กรณีจบจากบอท PvE
	local session = botSessions[player.UserId]
	botSessions[player.UserId] = nil
	player:SetAttribute("GlueInDuel", false)

	if not session or session.matchId ~= tostring(matchId) then
		return { ok = false }
	end

	local botCfg = BOT_DIFFICULTIES[session.actualDiff] or BOT_DIFFICULTIES.Medium
	local goldEarned = 0
	if won then
		goldEarned = botCfg.reward + (session.isMix and 50 or 0)
		prof.Gold += goldEarned
		prof.Wins += 1
		prof.Streak += 1
		if prof.Streak > prof.BestStreak then
			prof.BestStreak = prof.Streak
		end
	else
		goldEarned = 20 -- รางวัลปลอบใจสู้บอท
		prof.Gold += goldEarned
		prof.Losses += 1
		prof.Streak = 0
	end

	syncPlayerStats(player)
	return {
		ok = true,
		won = won,
		goldEarned = goldEarned,
		totalGold = prof.Gold,
		wins = prof.Wins,
		streak = prof.Streak,
	}
end

-- ดวลด่วน 1-Click (QuickPlay)
QuickPlay.OnServerEvent:Connect(function(player: Player, options: any)
	if player:GetAttribute("GlueInDuel") == true then return end
	local diff = "Medium"
	if type(options) == "table" and type(options.difficulty) == "string" then
		diff = options.difficulty
	end
	local tableModel = findNearestDuelTable(player)
	OpenTable:FireClient(player, tableModel, {
		difficulty = diff,
		mode = "Bot",
	})
end)

---------------------------------------------------------------------
-- 🌐 ระบบจับคู่ PvP 1v1 (Queue) & Custom PvP (เลือกคนสู้ 0 Gold)
---------------------------------------------------------------------
local function launchPvPMatch(p1: Player, p2: Player, isCustom: boolean)
	removeFromQueue(p1)
	removeFromQueue(p2)
	botSessions[p1.UserId] = nil
	botSessions[p2.UserId] = nil

	local matchId = HttpService:GenerateGUID(false)
	local p1First = (math.random(1, 2) == 1)
	local firstUserId = p1First and p1.UserId or p2.UserId

	local matchData: ActivePvPMatch = {
		matchId = matchId,
		p1 = p1,
		p2 = p2,
		turnUserId = firstUserId,
		isCustom = isCustom,
		startTime = os.clock(),
	}

	pvpMatchesByPlayer[p1.UserId] = matchData
	pvpMatchesByPlayer[p2.UserId] = matchData

	p1:SetAttribute("GlueInDuel", true)
	p2:SetAttribute("GlueInDuel", true)

	local tableModel = findNearestDuelTable(p1)

	StartPvP:FireClient(p1, {
		matchId = matchId,
		yourSide = "player",
		foeSide = "enemy",
		isFirst = p1First,
		goFirst = p1First,
		turnTime = 45,
		opponent = {
			UserId = p2.UserId,
			DisplayName = p2.DisplayName,
			Name = p2.Name,
		},
		opponentUserId = p2.UserId,
		opponentName = p2.DisplayName,
		isCustom = isCustom,
		tableModel = tableModel,
	})

	StartPvP:FireClient(p2, {
		matchId = matchId,
		yourSide = "player",
		foeSide = "enemy",
		isFirst = not p1First,
		goFirst = not p1First,
		turnTime = 45,
		opponent = {
			UserId = p1.UserId,
			DisplayName = p1.DisplayName,
			Name = p1.Name,
		},
		opponentUserId = p1.UserId,
		opponentName = p1.DisplayName,
		isCustom = isCustom,
		tableModel = tableModel,
	})
end

JoinPvPQueue.OnServerEvent:Connect(function(player: Player)
	if player:GetAttribute("GlueInDuel") == true then return end
	removeFromQueue(player)
	table.insert(pvpQueue, player)

	if #pvpQueue >= 2 then
		local p1 = table.remove(pvpQueue, 1) :: Player
		local p2 = table.remove(pvpQueue, 1) :: Player
		if p1 and p2 and p1.Parent == Players and p2.Parent == Players and p1 ~= p2 then
			launchPvPMatch(p1, p2, false)
		elseif p1 and p1.Parent == Players then
			table.insert(pvpQueue, p1)
		elseif p2 and p2.Parent == Players then
			table.insert(pvpQueue, p2)
		end
	end
end)

LeavePvPQueue.OnServerEvent:Connect(function(player: Player)
	removeFromQueue(player)
end)

-- ระบบท้าดวลแบบเจาะจงตัวผู้เล่น (Custom Mode - 0 Gold)
SendCustomChallenge.OnServerEvent:Connect(function(challenger: Player, targetUserId: any)
	local tid = tonumber(targetUserId)
	if not tid or tid == challenger.UserId then return end
	if challenger:GetAttribute("GlueInDuel") == true then return end

	local targetPlayer = Players:GetPlayerByUserId(tid)
	if not targetPlayer or targetPlayer:GetAttribute("GlueInDuel") == true then
		return
	end

	pendingChallenges[targetPlayer.UserId] = {
		challenger = challenger,
		timestamp = os.clock(),
	}

	IncomingCustomChallenge:FireClient(targetPlayer, {
		challengerUserId = challenger.UserId,
		challengerName = challenger.DisplayName,
	})
end)

RespondCustomChallenge.OnServerEvent:Connect(function(targetPlayer: Player, payload: any)
	local challenge = pendingChallenges[targetPlayer.UserId]
	pendingChallenges[targetPlayer.UserId] = nil
	if not challenge then return end

	local accepted = type(payload) == "table" and payload.accepted == true
	local challenger = challenge.challenger
	if not accepted then return end
	if not challenger or challenger.Parent ~= Players then return end
	if challenger:GetAttribute("GlueInDuel") == true or targetPlayer:GetAttribute("GlueInDuel") == true then
		return
	end

	-- เริ่มแมตช์ Custom Mode (isCustom = true -> ไม่ได้รับ Gold)
	launchPvPMatch(challenger, targetPlayer, true)
end)

-- Server Action Relay (ส่งต่อคำสั่ง Real-time ระหว่าง Player A <-> Player B)
PvPAction.OnServerEvent:Connect(function(player: Player, arg1: any, arg2: any, arg3: any)
	local pvp = pvpMatchesByPlayer[player.UserId]
	if not pvp then return end

	local opponent = (pvp.p1 == player) and pvp.p2 or pvp.p1
	if not opponent or opponent.Parent ~= Players then return end

	local matchId: string = ""
	local actionType: string = ""
	local payload: any = {}

	if type(arg1) == "string" and type(arg2) == "string" then
		-- Called as: FireServer(matchId, actionType, data)
		matchId = arg1
		actionType = arg2
		payload = (type(arg3) == "table") and arg3 or {}
	elseif type(arg1) == "table" then
		-- Called as: FireServer(actionTable)
		payload = arg1
		actionType = tostring(payload.action or payload.actionType or "")
		matchId = tostring(payload.matchId or "")
	else
		return
	end

	if actionType == "EndTurn" then
		pvp.turnUserId = opponent.UserId
	elseif actionType == "Surrender" then
		handlePlayerForfeitOrLeave(player, "คู่ต่อสู้ยอมแพ้การดวล")
		return
	elseif actionType == "Victory" then
		handlePlayerForfeitOrLeave(opponent, "ชนะการดวล 1v1!")
		return
	end

	-- ส่งต่อให้คู่ต่อสู้ทั้งสองรูปแบบ (argument แยก และแบบ table) เพื่อให้ Client ทุกแบบรับได้แน่นอน
	PvPActionRelay:FireClient(opponent, matchId, actionType, payload)
	local tblPayload = {
		action = actionType,
		actionType = actionType,
		matchId = matchId,
		data = payload,
		slot = payload.slot,
		cardId = payload.cardId,
		isSpell = payload.isSpell,
		attackerSlot = payload.attackerSlot,
		targetType = payload.targetType,
		targetSlot = payload.targetSlot,
		text = payload.text,
	}
	PvPActionRelay:FireClient(opponent, tblPayload)
end)

-- ระบบตรวจจับการยอมแพ้ / ออกจากโต๊ะ / เน็ตหลุด (Forfeit Protection)
local function handlePlayerForfeitOrLeave(player: Player, reasonText: string)
	removeFromQueue(player)
	botSessions[player.UserId] = nil
	player:SetAttribute("GlueInDuel", false)

	local pvp = pvpMatchesByPlayer[player.UserId]
	if pvp then
		local survivor = (pvp.p1 == player) and pvp.p2 or pvp.p1
		pvpMatchesByPlayer[pvp.p1.UserId] = nil
		pvpMatchesByPlayer[pvp.p2.UserId] = nil

		if survivor and survivor.Parent == Players then
			survivor:SetAttribute("GlueInDuel", false)
			local rewardGold = pvp.isCustom and 0 or 150
			local survProf = profiles[survivor.UserId]
			if survProf then
				survProf.Gold += rewardGold
				survProf.Wins += 1
				survProf.Streak += 1
				if survProf.Streak > survProf.BestStreak then
					survProf.BestStreak = survProf.Streak
				end
				syncPlayerStats(survivor)
			end
			PvPMatchEnd:FireClient(survivor, {
				won = true,
				forfeit = true,
				goldEarned = rewardGold,
				isCustom = pvp.isCustom,
				reason = reasonText,
			})
		end
	end
end

LeaveTable.OnServerEvent:Connect(function(player: Player)
	handlePlayerForfeitOrLeave(player, "คู่ต่อสู้กดยอมแพ้ออกจากโต๊ะ! 🏳️")
end)

Players.PlayerAdded:Connect(loadProfile)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, plr)
end

Players.PlayerRemoving:Connect(function(player: Player)
	handlePlayerForfeitOrLeave(player, "คู่ต่อสู้เน็ตหลุดออกจากเกม! ชนะบายทันที 🏆")
	saveProfile(player)
	profiles[player.UserId] = nil
end)