-- ServerScriptService/GameServer (Script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- 0) ลบสคริปต์เก่าที่ Rojo ไม่ได้ลบให้ (ถ้าค้างอยู่ จะแย่งรับ Remote กับสคริปต์นี้)
do
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local function purge(parent, name)
		local old = parent and parent:FindFirstChild(name)
		if old then
			warn(("[GameServer] พบ %s เก่าค้างอยู่ ลบทิ้งให้แล้ว (ลบออกจาก Studio ด้วยเพื่อไม่ให้เตือนซ้ำ)"):format(name))
			old:Destroy()
		end
	end
	purge(ServerScriptService, "MatchHandler")
	purge(ServerScriptService, "MatchService")
	purge(ServerStorage:FindFirstChild("Modules"), "MatchRegistry")
end

-- 1) สร้าง Remotes อัตโนมัติ (ต้องทำก่อน require Match)
local REMOTES = {
	RemoteFunction = { "PlayCard", "Attack", "Queue", "GetStats" },
	RemoteEvent = { "EndTurn", "Surrender", "StateUpdate", "GateRolled", "MatchEnded", "Notify" },
}
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
end
for className, names in REMOTES do
	for _, name in names do
		local existing = Remotes:FindFirstChild(name)
		if existing and not existing:IsA(className) then
			existing:Destroy()
			existing = nil
		end
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

-- 2) โหลดโมดูล
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardData = require(Shared.CardData)
local Decks = require(Shared.Decks)
local Modules = ServerStorage:WaitForChild("Modules")
local Match = require(Modules.Match)
local DataService = require(Modules.DataService)
local Stats = require(Modules.StatsService)

local ActiveMatches = {} -- [player] = match
local waiting = nil      -- { player, leader }
local lastCall = {}

local function allow(player, action, gap)
	local now = os.clock()
	local t = lastCall[player]
	if not t then
		t = {}
		lastCall[player] = t
	end
	if t[action] and now - t[action] < (gap or 0.1) then return false end
	t[action] = now
	return true
end

local function isId(v)
	return typeof(v) == "string" and #v > 0 and #v <= 64
end

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

-- 3) จบแมตช์: แจกเพชร, บันทึกชนะติดกัน และค่าหัว
-- บันทึกสถิติแมตช์ของผู้เล่นหนึ่งคน (won: true/false/nil = เสมอ)
-- reason: LEADER_DOWN | FATIGUE | AFK_LIGHTNING | LEFT | SURRENDER
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

	-- ได้เล่นก่อนหรือไม่ (ผู้เล่นคนแรกที่ได้เทิร์น)
	if m.firstPlayer then
		if m.firstPlayer == player then
			Stats.Add(data, "MatchesGoingFirst")
			if won == true then Stats.Add(data, "WinsGoingFirst") end
		end
	end

	-- สาเหตุที่จบ (นับให้ฝั่งที่เป็นต้นเหตุเท่านั้น)
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
		if bounty > 0 then m:Notify(("💰 ล้มคนติดค่าหัวได้! โบนัส %d เพชร"):format(bounty), "Yellow") end
	elseif typeof(winner) == "Instance" then
		rewards[winner] = DataService.AddGems(winner, Config.REWARD_WIN_BOT)
	end

	-- สถิติ: บอทไม่มีโปรไฟล์ จึงถูกข้ามใน recordMatchStats เอง
	-- (กติกาปัจจุบันไม่มีเสมอ: CheckWinner ตัดสินผู้ชนะเสมอ จึงไม่เรียกด้วย won=nil)
	for _, p in m.players do
		if typeof(p) == "Instance" then
			local isWinner = p == winner
			local ok, err = pcall(recordMatchStats, m, p, isWinner, reason, rewards[p],
				isWinner and bounty or 0)
			if not ok then warn("[GameServer] บันทึกสถิติไม่สำเร็จ: " .. tostring(err)) end
		end
	end
	return rewards
end

local function startMatch(p1, leader1, p2, leader2, mode)
	local ok, m = pcall(Match.new, p1, p2, Decks.Starter, Decks.Starter, leader1, leader2)
	if not ok then
		warn("[GameServer] สร้างแมตช์ไม่สำเร็จ: " .. tostring(m))
		return false
	end
	m.Mode = mode
	m.OnEnded = onMatchEnded
	m.GetData = DataService.GetData
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

local function guarded(player, method, ...)
	local m = ActiveMatches[player]
	if not m or m.ended then return false, "NO_MATCH" end
	local ok, a, b = pcall(m[method], m, player, ...)
	if not ok then
		warn(("[GameServer] %s error: %s"):format(method, tostring(a)))
		return false, "SERVER_ERROR"
	end
	if a ~= true then
		warn(("[GameServer] %s ปฏิเสธ %s: %s"):format(method, player.Name, tostring(b)))
	end
	return a == true, b
end

-- 4) Remotes
Remotes.Queue.OnServerInvoke = function(player, mode, leaderId)
	if not allow(player, "Queue", 0.5) then return false, "SLOW_DOWN" end
	if mode == "Cancel" then
		if waiting and waiting.player == player then
			waiting = nil
			Stats.Add(DataService.GetData(player), "QueueCancel")
		end
		return true, "CANCELLED"
	end
	if ActiveMatches[player] then return false, "IN_MATCH" end
	if mode ~= "Bot" and mode ~= "PvP" then return false, "BAD_MODE" end
	if not isLeader(leaderId) then return false, "BAD_LEADER" end
	if not DataService.IsLoaded(player) then return false, "DATA_LOADING" end

	if mode == "Bot" then
		if waiting and waiting.player == player then waiting = nil end
		Stats.Add(DataService.GetData(player), "QueueBot")
		local bot = { Name = "หุ่นกระบอกโง่ๆ 🤖", IsBot = true }
		local botLeader = Decks.Leaders[math.random(#Decks.Leaders)]
		if not startMatch(player, leaderId, bot, botLeader, "Bot") then return false, "SERVER_ERROR" end
		return true, "STARTED"
	end

	Stats.Add(DataService.GetData(player), "QueuePvP")
	local other = waiting
	if other and other.player ~= player and other.player.Parent and not ActiveMatches[other.player] then
		waiting = nil
		if not startMatch(other.player, other.leader, player, leaderId, "PvP") then return false, "SERVER_ERROR" end
		-- คนที่รออยู่ก่อน: นับเวลารอ | คนที่เพิ่งเข้า: จับคู่ได้ทันที (รอ 0 วินาที)
		local waited = math.max(0, math.floor(os.clock() - (other.since or os.clock())))
		local d1, d2 = DataService.GetData(other.player), DataService.GetData(player)
		Stats.Add(d1, "QueueMatched") Stats.Add(d1, "QueueWaitSec", waited) Stats.Add(d1, "QueueWaitCount")
		Stats.Add(d2, "QueueMatched") Stats.Add(d2, "QueueWaitCount")
		return true, "STARTED"
	end
	waiting = { player = player, leader = leaderId, since = os.clock() }
	return true, "WAITING"
end

Remotes.GetStats.OnServerInvoke = function(player)
	if not allow(player, "GetStats", 1) then return nil end
	return DataService.GetStats(player)
end

Remotes.PlayCard.OnServerInvoke = function(player, uid, target)
	if not allow(player, "PlayCard") then return false, "SLOW_DOWN" end
	if not isId(uid) then return false, "INVALID_CARD" end
	if target ~= nil and not isId(target) then return false, "INVALID_TARGET" end
	return guarded(player, "PlayCard", uid, target)
end

Remotes.Attack.OnServerInvoke = function(player, attackerUid, targetUid)
	if not allow(player, "Attack") then return false, "SLOW_DOWN" end
	if not isId(attackerUid) or not isId(targetUid) then return false, "INVALID_TARGET" end
	return guarded(player, "Attack", attackerUid, targetUid)
end

Remotes.EndTurn.OnServerEvent:Connect(function(player)
	if allow(player, "EndTurn", 0.3) then guarded(player, "EndTurn", false) end
end)

Remotes.Surrender.OnServerEvent:Connect(function(player)
	if allow(player, "Surrender", 1) then guarded(player, "Surrender") end
end)

-- 5) เข้า/ออกเกม (จบแมตช์ก่อน แล้วค่อยเซฟข้อมูล)
Players.PlayerAdded:Connect(DataService.Load)
for _, p in Players:GetPlayers() do task.spawn(DataService.Load, p) end

Players.PlayerRemoving:Connect(function(p)
	if waiting and waiting.player == p then waiting = nil end
	local m = ActiveMatches[p]
	if m and not m.ended then pcall(m.EndMatch, m, m:Opponent(p), "LEFT") end
	ActiveMatches[p] = nil
	lastCall[p] = nil
	DataService.Release(p)
end)

game:BindToClose(DataService.SaveAll)
