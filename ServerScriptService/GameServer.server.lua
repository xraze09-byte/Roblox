-- ServerScriptService/GameServer (Script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- 1) สร้าง Remotes อัตโนมัติ (ต้องทำก่อน require Match)
local REMOTES = {
	RemoteFunction = { "PlayCard", "Attack", "Queue" },
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
Remotes.Parent = ReplicatedStorage

-- 2) โหลดโมดูล
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CardData = require(Shared.CardData)
local Decks = require(Shared.Decks)
local Modules = ServerStorage:WaitForChild("Modules")
local Match = require(Modules.Match)
local DataService = require(Modules.DataService)

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
local function onMatchEnded(m, winner, _reason)
	for _, p in m.players do
		if ActiveMatches[p] == m then ActiveMatches[p] = nil end
		lockMovement(p, false)
	end
	local rewards = {}
	local loser = m:Opponent(winner)
	if m.Mode == "PvP" then
		local bounty = DataService.GetStreak(loser) * Config.BOUNTY_PER_STREAK
		DataService.RecordResult(winner, true)
		DataService.RecordResult(loser, false)
		rewards[winner] = DataService.AddGems(winner, Config.REWARD_WIN_PVP + bounty)
		rewards[loser] = DataService.AddGems(loser, Config.REWARD_LOSE_PVP)
		if bounty > 0 then m:Notify(("💰 ล้มคนติดค่าหัวได้! โบนัส %d เพชร"):format(bounty), "Yellow") end
	elseif typeof(winner) == "Instance" then
		rewards[winner] = DataService.AddGems(winner, Config.REWARD_WIN_BOT)
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
		if waiting and waiting.player == player then waiting = nil end
		return true, "CANCELLED"
	end
	if ActiveMatches[player] then return false, "IN_MATCH" end
	if mode ~= "Bot" and mode ~= "PvP" then return false, "BAD_MODE" end
	if not isLeader(leaderId) then return false, "BAD_LEADER" end
	if not DataService.IsLoaded(player) then return false, "DATA_LOADING" end

	if mode == "Bot" then
		if waiting and waiting.player == player then waiting = nil end
		local bot = { Name = "หุ่นกระบอกโง่ๆ 🤖", IsBot = true }
		local botLeader = Decks.Leaders[math.random(#Decks.Leaders)]
		if not startMatch(player, leaderId, bot, botLeader, "Bot") then return false, "SERVER_ERROR" end
		return true, "STARTED"
	end

	local other = waiting
	if other and other.player ~= player and other.player.Parent and not ActiveMatches[other.player] then
		waiting = nil
		if not startMatch(other.player, other.leader, player, leaderId, "PvP") then return false, "SERVER_ERROR" end
		return true, "STARTED"
	end
	waiting = { player = player, leader = leaderId }
	return true, "WAITING"
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
