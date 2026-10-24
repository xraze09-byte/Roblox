-- ServerStorage/Modules/Match (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local CardData = require(Shared.CardData)
local Modules = ServerStorage:WaitForChild("Modules")
local GateRNG = require(Modules.GateRNG)
local CardEffects = require(Modules.CardEffects)
local BotAI = require(Modules.BotAI)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Match = {}
Match.__index = Match
local rng = Random.new()

local function isPlayer(p)
	return typeof(p) == "Instance" and p.Parent ~= nil
end

local function send(remote, p, ...)
	if isPlayer(p) then remote:FireClient(p, ...) end
end

local function findByUid(list, uid)
	for i, c in list do
		if c.Uid == uid then return c, i end
	end
	return nil
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function Match.MakeCard(id)
	local data = CardData[id]
	assert(data, "ไม่พบการ์ด " .. tostring(id))
	local card = table.clone(data)
	if data.Keywords then card.Keywords = table.clone(data.Keywords) end
	if data.Effect then card.Effect = table.clone(data.Effect) end
	card.Id = id
	card.Uid = HttpService:GenerateGUID(false)
	card.MaxHP = card.HP
	return card
end

local function newSide(player, deckIds, leaderId)
	local leader = CardData[leaderId]
	assert(leader and leader.Type == "Leader", "ผู้นำไม่ถูกต้อง: " .. tostring(leaderId))
	local deck = {}
	for _, id in deckIds do table.insert(deck, Match.MakeCard(id)) end
	return {
		player = player,
		name = typeof(player) == "Instance" and player.DisplayName or player.Name,
		deck = shuffle(deck), hand = {}, field = {}, graveyard = {}, gate = nil,
		leader = { Id = leaderId, Name = leader.Name, Ability = leader.Ability },
		leaderHP = Config.LEADER_HP, shield = 0,
		points = 0, bonusPoints = leader.Ability == "ExtraPoints" and 2 or 0,
		banking = false, spentThisTurn = false, abilityUsed = false,
		afk = 0, fatigue = 0,
	}
end

function Match.new(p1, p2, deck1, deck2, leader1, leader2)
	local self = setmetatable({}, Match)
	self.id = HttpService:GenerateGUID(false)
	self.players = { p1, p2 }
	self.sides = { [p1] = newSide(p1, deck1, leader1), [p2] = newSide(p2, deck2, leader2) }
	self.bombs = {}
	self.turnToken = 0
	self.ended = false
	return self
end

-- ───── ตัวช่วย ─────
function Match:Opponent(player)
	return self.players[1] == player and self.players[2] or self.players[1]
end

function Match:OtherSide(side)
	return self.sides[self:Opponent(side.player)]
end

function Match:Notify(text, color)
	for _, p in self.players do send(Remotes.Notify, p, text, color) end
end

function Match:Spend(side, cost)
	side.points -= cost
	if cost > 0 then side.spentThisTurn = true end
end

function Match:Draw(side, count)
	local fatigued = false
	local wanted = math.min(count, Config.MAX_HAND - #side.hand)
	for _ = 1, wanted do
		local card = table.remove(side.deck)
		if card then
			table.insert(side.hand, card)
		else
			side.fatigue += 1
			side.leaderHP -= side.fatigue
			fatigued = true
			self:Notify(("😵 %s การ์ดหมดกอง! เสีย HP %d"):format(side.name, side.fatigue), "Red")
		end
	end
	return fatigued
end

function Match:DamageLeader(side, amount)
	if amount <= 0 then return end
	local absorbed = math.min(side.shield, amount)
	side.shield -= absorbed
	side.leaderHP -= amount - absorbed
	if absorbed > 0 then self:Notify(("🛡️ โล่ฝาหม้อกันไว้ %d"):format(absorbed), "Blue") end
end

function Match:EnterField(side, card, canAttack)
	card.CanAttack = canAttack
	table.insert(side.field, card)
	CardEffects.OnEnter(self, side, card)
end

function Match:RollGate(side)
	local outcome = GateRNG.Roll()
	local ability = side.leader.Ability
	if not side.abilityUsed then
		if ability == "Reroll" and (outcome.id == "Poop" or outcome.id == "Droopy") then
			side.abilityUsed = true
			self:Notify("🔄 ลุงกาวไม่ยอมรับผล! สุ่มใหม่!", "Yellow")
			outcome = GateRNG.Roll()
		elseif ability == "LuckyPoop" and outcome.id == "Poop" then
			side.abilityUsed = true
			self:Notify("🍀 ป้าดวงเฮงปัดอึทิ้ง! กลายเป็นธรรมดา", "Green")
			outcome = GateRNG.Get("Normal")
		end
	end
	return outcome
end

function Match:TickBombs()
	for i = #self.bombs, 1, -1 do
		local b = self.bombs[i]
		b.turns -= 1
		if b.turns <= 0 then
			table.remove(self.bombs, i)
			self:Notify(("💣💥 หม้อหุงข้าวระเบิด! ทุกตัวในสนามโดน %d"):format(b.damage), "Red")
			for _, p in self.players do
				for _, c in self.sides[p].field do c.HP -= b.damage end
			end
		end
	end
end

function Match:ElementBonus(attacker, target)
	if attacker.Element == "Gawa" then
		if rng:NextInteger(0, 1) == 1 then
			self:Notify("🪙 ธาตุกาวออกหัว! ATK +2", "Yellow")
			return 2
		end
		self:Notify("🪙 ธาตุกาวออกก้อย... ATK -2")
		return -2
	end
	if Rules.Beats[attacker.Element] and Rules.Beats[attacker.Element] == target.Element then
		self:Notify("⚡ ธาตุชนะทาง! ATK +2", "Yellow")
		return 2
	end
	return 0
end

function Match:WearWeapon(card)
	if not card.WeaponName then return end
	card.WeaponDur -= 1
	if card.WeaponDur <= 0 then
		card.ATK = math.max(0, card.ATK - (card.WeaponBonus or 0))
		self:Notify(("💔 %s ของ %s พังแล้ว"):format(card.WeaponName, card.Name))
		card.WeaponName, card.WeaponBonus, card.WeaponDur, card.WeaponFreeze = nil, nil, nil, nil
	end
end

-- ย้ายการ์ดที่ตายลงช่องตาย (วนซ้ำเผื่อดวงซวยทำให้มีตัวตายต่อ)
function Match:Settle()
	for _ = 1, 20 do
		local died = false
		for _, p in self.players do
			local side = self.sides[p]
			for i = #side.field, 1, -1 do
				local c = side.field[i]
				if c.HP <= 0 then
					died = true
					table.remove(side.field, i)
					table.insert(side.graveyard, c)
					CardEffects.OnDeath(self, side, c)
				end
			end
		end
		if not died then return end
	end
end

function Match:CheckWinner()
	local a, b = self.players[1], self.players[2]
	local aDead, bDead = self.sides[a].leaderHP <= 0, self.sides[b].leaderHP <= 0
	if aDead and bDead then return self.current end
	if aDead then return b end
	if bDead then return a end
	return nil
end

-- ปิดท้ายทุกการกระทำ: เก็บศพ → ส่งข้อมูล → ตัดสินผล
function Match:Commit(reason)
	if self.ended then return end
	self:Settle()
	self:Broadcast()
	local winner = self:CheckWinner()
	if winner then self:EndMatch(winner, reason or "LEADER_DOWN") end
end

-- ───── ลำดับเทิร์น ─────
function Match:Start()
	for _, p in self.players do
		self:Draw(self.sides[p], Config.STARTING_HAND)
	end
	self:StartTurn(self.players[rng:NextInteger(1, 2)])
end

function Match:StartTurn(player)
	if self.ended then return end
	self.current = player
	self.turnToken += 1
	local token = self.turnToken
	self.turnEndsAt = workspace:GetServerTimeNow() + Config.TURN_TIME
	local side = self.sides[player]

	-- พอยต์ (ถ้าเทิร์นก่อนไม่ได้ดองไว้ พอยต์ที่เหลือจะหาย)
	if not side.banking then side.points = 0 end
	side.points = math.min(side.points + Config.POINTS_PER_TURN + side.bonusPoints, Config.MAX_BANKED_POINTS)
	side.bonusPoints = 0
	side.banking, side.spentThisTurn = false, false

	self:TickBombs()

	for _, c in side.field do
		c.CanAttack = not c.Frozen
	end

	if side.gate and #side.field < Config.FIELD_SLOTS then
		local card = side.gate
		side.gate = nil
		local outcome = self:RollGate(side)
		GateRNG.Apply(card, outcome)
		for _, p in self.players do
			send(Remotes.GateRolled, p, p == player, card, outcome.id)
		end
		self:EnterField(side, card, true)
	elseif side.gate then
		self:Notify("🎲 สนามเต็ม! การ์ดในช่องเกตต้องรอก่อน")
	end

	local fatigued = self:Draw(side, Config.DRAW_PER_TURN)
	self:Commit(fatigued and "FATIGUE" or nil)
	if self.ended then return end

	task.delay(Config.TURN_TIME, function()
		if self.ended or self.turnToken ~= token then return end
		side.afk += 1
		if side.afk > Config.AFK_LIMIT then
			self:Notify(("⚡ ฟ้าผ่า %s เพราะ AFK!"):format(side.name), "Red")
			self:EndMatch(self:Opponent(player), "AFK_LIGHTNING")
		else
			self:EndTurn(player, true)
		end
	end)

	if typeof(player) == "table" and player.IsBot then
		task.defer(BotAI.TakeTurn, self, player, token)
	end
end

function Match:PlayCard(player, uid, target)
	if self.ended then return false, "MATCH_OVER" end
	if self.current ~= player then return false, "NOT_YOUR_TURN" end
	local me = self.sides[player]
	local card, index = findByUid(me.hand, uid)
	if not card then return false, "INVALID_CARD" end

	if card.Type == "Character" then
		if target ~= "Field" and target ~= "Gate" then return false, "INVALID_TARGET" end
		local toGate = target == "Gate"
		local cost = toGate and Rules.GateCost(card) or card.Cost
		if cost > me.points then return false, "NOT_ENOUGH_POINTS" end
		if toGate and me.gate then return false, "GATE_OCCUPIED" end
		if not toGate and #me.field >= Config.FIELD_SLOTS then return false, "FIELD_FULL" end
		table.remove(me.hand, index)
		self:Spend(me, cost)
		if toGate then
			card.CanAttack = false
			me.gate = card
			self:Notify(("🎲 %s ลงการ์ดในช่องเกต! เทิร์นหน้ามาลุ้นกัน"):format(me.name), "Pink")
		else
			self:Notify(("🃏 %s ลง %s"):format(me.name, card.Name))
			self:EnterField(me, card, Rules.HasKeyword(card, "Rush"))
		end
	elseif card.Type == "Spell" or card.Type == "Weapon" then
		if card.Cost > me.points then return false, "NOT_ENOUGH_POINTS" end
		local resolve, err = CardEffects.Prepare(self, me, card, target)
		if not resolve then return false, err end
		table.remove(me.hand, index)
		self:Spend(me, card.Cost)
		table.insert(me.graveyard, card)
		self:Notify(("✨ %s ใช้ %s"):format(me.name, card.Name))
		resolve()
	else
		return false, "INVALID_CARD"
	end

	me.afk = 0
	self:Commit()
	return true
end

function Match:Attack(player, attackerUid, targetUid)
	if self.ended then return false, "MATCH_OVER" end
	if self.current ~= player then return false, "NOT_YOUR_TURN" end
	local me = self.sides[player]
	local opp = self:OtherSide(me)
	local attacker = findByUid(me.field, attackerUid)
	if not attacker or not attacker.CanAttack or attacker.ATK <= 0 then return false, "CANNOT_ATTACK" end

	local tauntUp = Rules.HasTaunt(opp.field)
	local target = nil
	if targetUid == "LEADER" then
		if tauntUp then return false, "TAUNT" end
	else
		target = findByUid(opp.field, targetUid)
		if not target then return false, "INVALID_TARGET" end
		if tauntUp and not Rules.HasKeyword(target, "Taunt") then return false, "TAUNT" end
	end

	attacker.CanAttack = false
	me.afk = 0

	if attacker.Slime then
		attacker.Slime = nil
		if rng:NextNumber() < 0.5 then
			self:Notify(("🟢 %s ลื่นสไลม์ ตีพลาด!"):format(attacker.Name), "Green")
			self:Commit()
			return true
		end
	end

	if target then
		local dmg = math.max(0, attacker.ATK + self:ElementBonus(attacker, target))
		target.HP -= dmg
		attacker.HP -= target.ATK
		if attacker.WeaponFreeze and target.HP > 0 then
			target.Frozen = true
			self:Notify(("❄️ %s โดนแช่แข็ง!"):format(target.Name), "Blue")
		end
	else
		self:DamageLeader(opp, attacker.ATK)
	end

	self:WearWeapon(attacker)
	self:Commit()
	return true
end

function Match:EndTurn(player, timedOut)
	if self.ended or self.current ~= player then return false, "NOT_YOUR_TURN" end
	local side = self.sides[player]
	if not timedOut then side.afk = 0 end
	side.banking = not side.spentThisTurn
	if side.banking then self:Notify(("💰 %s ดองพอยต์ไว้!"):format(side.name), "Pink") end
	for _, c in side.field do
		c.Slime = nil
		c.Frozen = nil
	end
	self:StartTurn(self:Opponent(player))
	return true
end

function Match:Surrender(player)
	if self.ended then return false end
	self:EndMatch(self:Opponent(player), "SURRENDER")
	return true
end

function Match:EndMatch(winner, reason)
	if self.ended then return end
	self.ended = true
	self.turnToken += 1
	local rewards = {}
	if self.OnEnded then
		local ok, result = pcall(self.OnEnded, self, winner, reason)
		if not ok then
			warn("[Match] OnEnded error: " .. tostring(result))
		elseif typeof(result) == "table" then
			rewards = result
		end
	end
	for _, p in self.players do
		send(Remotes.MatchEnded, p, p == winner, reason, self.id, rewards[p] or 0)
	end
end

-- ส่งข้อมูลแยกให้แต่ละคน (ไม่ส่งไพ่ในมือ, กองการ์ด หรือการ์ดในช่องเกตของอีกฝั่ง)
function Match:Broadcast()
	local bombs = {}
	for _, b in self.bombs do table.insert(bombs, b.turns) end
	for _, p in self.players do
		if isPlayer(p) then
			local me, opp = self.sides[p], self.sides[self:Opponent(p)]
			Remotes.StateUpdate:FireClient(p, {
				matchId = self.id,
				isMyTurn = self.current == p,
				turnEndsAt = self.turnEndsAt,
				bombs = bombs,
				myHand = me.hand, myField = me.field, myGate = me.gate,
				myPoints = me.points, mySpent = me.spentThisTurn,
				myHP = me.leaderHP, myShield = me.shield,
				myLeader = me.name .. " • " .. me.leader.Name,
				myDeck = #me.deck, myGrave = #me.graveyard,
				oppField = opp.field, oppGateFilled = opp.gate ~= nil,
				oppHandCount = #opp.hand, oppHP = opp.leaderHP, oppShield = opp.shield,
				oppLeader = opp.name .. " • " .. opp.leader.Name,
				oppDeck = #opp.deck, oppGrave = #opp.graveyard,
				oppBank = opp.banking and opp.points or 0,
			})
		end
	end
end

return Match