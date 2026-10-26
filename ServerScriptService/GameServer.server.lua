local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

-- 0) ลบสคริปต์เก่าที่ค้าง
do
	local function purge(parent, name)
		local old = parent and parent:FindFirstChild(name)
		if old then
			warn(("[GameServer] พบ %s เก่าค้างอยู่ ลบทิ้งให้แล้ว"):format(name))
			old:Destroy()
		end
	end
	purge(ServerScriptService, "MatchHandler")
	purge(ServerScriptService, "MatchService")
	purge(ServerStorage:FindFirstChild("Modules"), "MatchRegistry")
end

-- 1) Remotes
local REMOTES = {
	RemoteFunction = { "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" },
	RemoteEvent = { "EndTurn", "Surrender", "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" },
}
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
end
for className, names in REMOTES do
	for _, name in names do
		local existing = Remotes:FindFirstChild(name)
		if existing and not existing:IsA(className) then existing:Destroy() existing = nil end
		if not existing then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = Remotes
		end
	end
end
for _, child in Remotes:GetChildren() do
	local keep = false
	for _, names in REMOTES do
		if table.find(names, child.Name) then keep = true break end
	end
	if not keep then child:Destroy() end
end
Remotes.Parent = ReplicatedStorage

-- 2) โมดูล
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardData = require(Shared.CardData)
local Decks = require(Shared.Decks)
local DeckRules = require(Shared.DeckRules)
local Modules = ServerStorage:WaitForChild("Modules")
local Match = require(Modules.Match)
local DataService = require(Modules.DataService)
local Stats = require(Modules.StatsService)
local Guard = require(Modules.Guard)
local GachaService = require(Modules.GachaService)
local QuestService = require(Modules.QuestService)
local FarmService = require(Modules.FarmService)

-- 2.1) รวม Broadcast ให้เหลือครั้งเดียวต่อรอบ (ตัวการหลักที่ทำให้แลกตอนกดรัว)
do
	local rawBroadcast = Match.Broadcast
	Match.Broadcast = function(self)
		if self._broadcastQueued then return end
		self._broadcastQueued = true
		task.defer(function()
			self._broadcastQueued = false
			local ok, err = pcall(rawBroadcast, self)
			if not ok then warn("[GameServer] Broadcast error: " .. tostring(err)) end
		end)
	end
end

local ActiveMatches = {}
local waiting = nil

local function isId(v) return typeof(v) == "string" and #v > 0 and #v <= 64 end
local function isLeader(id)
	local c = isId(id) and CardData[id]
	return c and c.Type == "Leader"
end

local function lockMovement(player, locked)
	if typeof(player) ~= "Instance" then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed = locked and 0 or StarterPlayer.CharacterWalkSpeed
	hum.JumpHeight = locked and 0 or StarterPlayer.CharacterJumpHeight
	hum.JumpPower = locked and 0 or StarterPlayer.CharacterJumpPower
end

-- 3) โปรไฟล์ / เควสต์
local function snapshot(player)
	local data = DataService.GetData(player)
	if not data then return nil end
	QuestService.Ensure(data, player.UserId)
	return {
		Gems = data.Gems, Collection = table.clone(data.Collection), Deck = table.clone(data.Deck),
		Pity = table.clone(data.Pity), Quests = QuestService.View(data),
		TowerFloor = data.TowerFloor or 1,
	}
end

local pushPending = {}
local function pushProfile(player)
	if typeof(player) ~= "Instance" or pushPending[player] then return end
	pushPending[player] = true
	task.delay(0.2, function()
		pushPending[player] = nil
		if player.Parent then
			local snap = snapshot(player)
			if snap then Remotes.ProfileChanged:FireClient(player, snap) end
		end
	end)
end
DataService.OnChanged = pushProfile

local function trackQuest(player, event, amount)
	if typeof(player) ~= "Instance" then return end
	local data = DataService.GetData(player)
	if data and QuestService.Track(data, player.UserId, event, amount or 1) then pushProfile(player) end
end

local function deckFor(player)
	if typeof(player) ~= "Instance" then return Decks.Starter end
	local data = DataService.GetData(player)
	if data and DeckRules.Validate(data.Deck, data.Collection) then return table.clone(data.Deck) end
	return Decks.Starter
end

-- 4) สถิติ / จบแมตช์
local function recordMatchStats(m, player, won, reason, gems, bounty)
	local data = DataService.GetData(player)
	if not data then return end
	local mode = m.Mode == "PvP" and "PvP" or "Bot"
	local sec = math.max(0, math.floor(os.clock() - (m.startedAt or os.clock())))
	local side = m.sides[player]
	local outcome = won == true and "Win" or (won == false and "Loss" or "Draw")

	Stats.Add(data, "Matches")
	Stats.Add(data, "Matches" .. mode)
	Stats.Add(data, outcome .. "s")
	Stats.Add(data, outcome .. "s" .. mode)
	Stats.Add(data, "PlaySec", sec)
	Stats.Max(data, "LongestMatchSec", sec)
	if won == true then
		Stats.Add(data, "WinSec", sec)
		Stats.Min(data, "ShortestWinSec", math.max(sec, 1))
	elseif won == false then
		Stats.Add(data, "LossSec", sec)
	end
	if m.firstPlayer == player then
		Stats.Add(data, "MatchesGoingFirst")
		if won == true then Stats.Add(data, "WinsGoingFirst") end
	end
	if won == false then
		if reason == "SURRENDER" then Stats.Add(data, "Surrenders")
		elseif reason == "AFK_LIGHTNING" then Stats.Add(data, "AfkLosses")
		elseif reason == "LEFT" then Stats.Add(data, "Disconnects") end
	elseif won == true and reason == "LEFT" then
		Stats.Add(data, "OpponentLeft")
	end
	if side then
		Stats.Leader(data, side.leader.Id, "Matches")
		Stats.Leader(data, side.leader.Id, outcome .. "s")
	end
	if gems and gems > 0 then
		Stats.Add(data, "GemsEarned", gems)
		Stats.Max(data, "BestGemsOneMatch", gems)
	end
	if bounty and bounty > 0 then Stats.Add(data, "BountyEarned", bounty) end
end

local function onMatchEnded(m, winner, reason)
	for _, p in m.players do
		if ActiveMatches[p] == m then ActiveMatches[p] = nil end
		lockMovement(p, false)
	end
	local rewards = {}
	local loser = m:Opponent(winner)
	local bounty = 0
	if m.Mode == "PvP" then
		bounty = DataService.GetStreak(loser) * Config.BOUNTY_PER_STREAK
		DataService.RecordResult(winner, true)
		DataService.RecordResult(loser, false)
		rewards[winner] = DataService.AddGems(winner, Config.REWARD_WIN_PVP + bounty)
		rewards[loser] = DataService.AddGems(loser, Config.REWARD_LOSE_PVP)
		if bounty > 0 then m:Notify(("ล้มคนติดค่าหัวได้ โบนัส %d เพชร"):format(bounty), "Yellow") end
	elseif m.Mode == "Tower" then
		if typeof(winner) == "Instance" then
			local floor = m.TowerFloor or 1
			rewards[winner] = DataService.AddGems(winner, Config.TOWER_REWARD_BASE + floor * Config.TOWER_REWARD_PER_FLOOR)
			local data = DataService.GetData(winner)
			if data and (data.TowerFloor or 1) <= floor then
				data.TowerFloor = math.min(floor + 1, Config.TOWER_MAX_FLOOR + 1)
				DataService.Touch(winner)
			end
			m:Notify(("🗼 พิชิตชั้น %d สำเร็จ!"):format(floor), "Yellow")
		end
	elseif typeof(winner) == "Instance" then
		rewards[winner] = DataService.AddGems(winner, Config.REWARD_WIN_BOT)
	end
	for _, p in m.players do
		if typeof(p) == "Instance" then
			local isWinner = p == winner
			local ok, err = pcall(recordMatchStats, m, p, isWinner, reason, rewards[p], isWinner and bounty or 0)
			if not ok then warn("[GameServer] บันทึกสถิติไม่สำเร็จ: " .. tostring(err)) end
			trackQuest(p, "MatchPlayed")
			if isWinner then
				trackQuest(p, "MatchWon")
				if m.Mode == "PvP" then trackQuest(p, "PvPWon") end
			end
		end
	end
	return rewards
end

local function startMatch(p1, leader1, p2, leader2, mode, setup)
	local ok, m = pcall(Match.new, p1, p2, deckFor(p1), deckFor(p2), leader1, leader2)
	if not ok then
		warn("[GameServer] สร้างแมตช์ไม่สำเร็จ: " .. tostring(m))
		return false
	end
	m.Mode = mode
	m.OnEnded = onMatchEnded
	m.GetData = DataService.GetData
	if setup then -- ตั้งค่าเพิ่มก่อนเริ่ม (เช่นบัฟบอสหอคอย) ต้องทำก่อน m:Start เพราะ Start จั่วการ์ด
		local okSetup, setupErr = pcall(setup, m)
		if not okSetup then warn("[GameServer] ตั้งค่าแมตช์ไม่สำเร็จ: " .. tostring(setupErr)) end
	end
	for _, p in m.players do
		if typeof(p) == "Instance" then
			ActiveMatches[p] = m
			lockMovement(p, true)
		end
	end
	local started, err = pcall(m.Start, m)
	if not started then
		warn("[GameServer] เริ่มแมตช์ไม่สำเร็จ: " .. tostring(err))
		m.ended = true
		for _, p in m.players do
			if ActiveMatches[p] == m then ActiveMatches[p] = nil end
			lockMovement(p, false)
		end
		return false
	end
	return true
end

-- คำสั่งในแมตช์: ล็อก "match" ต่อผู้เล่น (ไม่ warn ตอนถูกปฏิเสธ เพราะทำให้เซิร์ฟช้าเวลาโดนสแปม)
local function guarded(player, method, ...)
	local m = ActiveMatches[player]
	if not m or m.ended then return false, "NO_MATCH" end
	local a, b = Guard.Run(player, "match", m[method], m, player, ...)
	return a == true, b
end

-- 5) Remotes
local function queueImpl(player, mode, leaderId)
	if mode == "Cancel" then
		if waiting and waiting.player == player then
			waiting = nil
			Stats.Add(DataService.GetData(player), "QueueCancel")
		end
		return true, "CANCELLED"
	end
	if ActiveMatches[player] then return false, "IN_MATCH" end
	if mode ~= "Bot" and mode ~= "PvP" and mode ~= "Tower" then return false, "BAD_MODE" end
	if not isLeader(leaderId) then return false, "BAD_LEADER" end
	if not DataService.IsLoaded(player) then return false, "DATA_LOADING" end

	if mode == "Tower" then
		if waiting and waiting.player == player then waiting = nil end
		local data = DataService.GetData(player)
		local floor = math.clamp(tonumber(data and data.TowerFloor) or 1, 1, Config.TOWER_MAX_FLOOR)
		local bot = { Name = ("🗼 บอสชั้น %d"):format(floor), IsBot = true }
		local botLeader = Decks.Leaders[(floor - 1) % #Decks.Leaders + 1]
		local ok = startMatch(player, leaderId, bot, botLeader, "Tower", function(m)
			m.TowerFloor = floor
			local side = m.sides[bot]
			side.shield += (floor - 1) * Config.TOWER_SHIELD_PER_FLOOR
			local buff = math.floor((floor - 1) / Config.TOWER_BUFF_EVERY)
			if buff > 0 then
				for _, c in side.deck do
					if c.Type == "Character" then
						c.ATK += buff
						c.HP += buff
						c.MaxHP = c.HP
					end
				end
			end
		end)
		if not ok then return false, "SERVER_ERROR" end
		return true, "STARTED"
	end

	if mode == "Bot" then
		if waiting and waiting.player == player then waiting = nil end
		Stats.Add(DataService.GetData(player), "QueueBot")
		local bot = { Name = "หุ่นฝึกซ้อม", IsBot = true }
		local botLeader = Decks.Leaders[math.random(#Decks.Leaders)]
		if not startMatch(player, leaderId, bot, botLeader, "Bot") then return false, "SERVER_ERROR" end
		return true, "STARTED"
	end

	Stats.Add(DataService.GetData(player), "QueuePvP")
	local other = waiting
	if other and other.player ~= player and other.player.Parent and not ActiveMatches[other.player] then
		waiting = nil
		if not startMatch(other.player, other.leader, player, leaderId, "PvP") then return false, "SERVER_ERROR" end
		local waited = math.max(0, math.floor(os.clock() - (other.since or os.clock())))
		local d1, d2 = DataService.GetData(other.player), DataService.GetData(player)
		Stats.Add(d1, "QueueMatched") Stats.Add(d1, "QueueWaitSec", waited) Stats.Add(d1, "QueueWaitCount")
		Stats.Add(d2, "QueueMatched") Stats.Add(d2, "QueueWaitCount")
		return true, "STARTED"
	end
	waiting = { player = player, leader = leaderId, since = os.clock() }
	return true, "WAITING"
end

Remotes.Queue.OnServerInvoke = function(player, mode, leaderId)
	if not Guard.Allow(player, "Queue", 0.5) then return false, "SLOW_DOWN" end
	return Guard.Run(player, "queue", queueImpl, player, mode, leaderId)
end

Remotes.GetStats.OnServerInvoke = function(player)
	if not Guard.Allow(player, "GetStats", 1) then return nil end
	return DataService.GetStats(player)
end

Remotes.GetProfile.OnServerInvoke = function(player)
	if not Guard.Allow(player, "GetProfile", 0.5) then return nil end
	return snapshot(player)
end

Remotes.PlayCard.OnServerInvoke = function(player, uid, target)
	if not Guard.Allow(player, "PlayCard", 0.12) then return false, "SLOW_DOWN" end
	if not isId(uid) then return false, "INVALID_CARD" end
	if target ~= nil and not isId(target) then return false, "INVALID_TARGET" end
	local m = ActiveMatches[player]
	local cardType
	local side = m and m.sides and m.sides[player]
	if side then
		for _, c in side.hand do
			if c.Uid == uid then cardType = c.Type break end
		end
	end
	local ok, code = guarded(player, "PlayCard", uid, target)
	if ok then
		trackQuest(player, "CardPlayed")
		if cardType == "Spell" then trackQuest(player, "SpellPlayed") end
		if target == "Gate" then trackQuest(player, "GatePlayed") end
	end
	return ok, code
end

Remotes.Attack.OnServerInvoke = function(player, attackerUid, targetUid)
	if not Guard.Allow(player, "Attack", 0.12) then return false, "SLOW_DOWN" end
	if not isId(attackerUid) or not isId(targetUid) then return false, "INVALID_TARGET" end
	local ok, code = guarded(player, "Attack", attackerUid, targetUid)
	if ok then trackQuest(player, "Attack") end
	return ok, code
end

Remotes.EndTurn.OnServerEvent:Connect(function(player)
	if Guard.Allow(player, "EndTurn", 0.4) then guarded(player, "EndTurn", false) end
end)

Remotes.Surrender.OnServerEvent:Connect(function(player)
	if Guard.Allow(player, "Surrender", 1) then guarded(player, "Surrender") end
end)

Remotes.Gacha.OnServerInvoke = function(player, count)
	if not Guard.Allow(player, "Gacha", 0.6) then return false, "SLOW_DOWN" end
	if count ~= 1 and count ~= 10 then return false, "BAD_COUNT" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	local ok, res = Guard.Run(player, "profile", GachaService.Pull, data, count)
	if ok then
		QuestService.Track(data, player.UserId, "GachaPull", count)
		DataService.Touch(player)
	end
	return ok, res
end

-- ===== ฟาร์ม =====
Remotes.GetFarms.OnServerInvoke = function(player)
	if not Guard.Allow(player, "GetFarms", 0.5) then return false, "SLOW_DOWN" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	return true, FarmService.List(data)
end

Remotes.ClaimFarm.OnServerInvoke = function(player, id)
	if not Guard.Allow(player, "ClaimFarm", 0.5) then return false, "SLOW_DOWN" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	local ok, res = FarmService.Claim(data, id)
	if ok then DataService.Touch(player) end
	return ok, res
end

Remotes.UpgradeFarm.OnServerInvoke = function(player, id)
	if not Guard.Allow(player, "UpgradeFarm", 0.5) then return false, "SLOW_DOWN" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	local ok, res = FarmService.Upgrade(data, id)
	if ok then DataService.Touch(player) end
	return ok, res
end

Remotes.SaveDeck.OnServerInvoke = function(player, ids)
	if not Guard.Allow(player, "SaveDeck", 1) then return false, "SLOW_DOWN" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	if typeof(ids) ~= "table" or #ids > 64 then return false, "ข้อมูลเด็คไม่ถูกต้อง" end
	local clean = {}
	for i = 1, #ids do clean[i] = ids[i] end
	local ok, err = DeckRules.Validate(clean, data.Collection)
	if not ok then return false, err end
	data.Deck = clean
	pushProfile(player)
	return true
end

Remotes.ClaimQuest.OnServerInvoke = function(player, questId)
	if not Guard.Allow(player, "ClaimQuest", 0.3) then return false, "SLOW_DOWN" end
	if not isId(questId) then return false, "BAD_QUEST" end
	local data = DataService.GetData(player)
	if not data then return false, "DATA_LOADING" end
	local ok, res = QuestService.Claim(data, player.UserId, questId)
	if ok then DataService.Touch(player) end
	return ok, res
end

-- 6) เข้า/ออกเกม
Players.PlayerAdded:Connect(DataService.Load)
for _, p in Players:GetPlayers() do task.spawn(DataService.Load, p) end

Players.PlayerRemoving:Connect(function(p)
	if waiting and waiting.player == p then waiting = nil end
	local m = ActiveMatches[p]
	if m and not m.ended then pcall(m.EndMatch, m, m:Opponent(p), "LEFT") end
	ActiveMatches[p] = nil
	pushPending[p] = nil
	DataService.Release(p)
end)

game:BindToClose(DataService.SaveAll)