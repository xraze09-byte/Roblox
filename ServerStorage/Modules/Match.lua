local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GateRNG = require(ServerStorage.Modules.GateRNG)
local Remotes = ReplicatedStorage.Remotes

local Match = {}
Match.__index = Match

local function shuffle(t)
	local rng = Random.new()
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function newSide(deckCards, leader)
	return {
		deck = shuffle(table.clone(deckCards)), -- 24 ใบ (ไม่รวมผู้นำ)
		hand = {}, field = {}, graveyard = {},
		gate = nil, leader = leader,
		leaderHP = Config.LEADER_HP,
		points = 0, banking = false, spentThisTurn = false,
		afk = 0, fatigue = 0,
	}
end

function Match.new(p1, p2, deck1, deck2, leader1, leader2)
	local self = setmetatable({}, Match)
	self.players = { p1, p2 }
	self.sides = { [p1] = newSide(deck1, leader1), [p2] = newSide(deck2, leader2) }
	self.turnToken = 0
	self.ended = false
	return self
end

function Match:Opponent(player)
	return self.players[1] == player and self.players[2] or self.players[1]
end

function Match:StartTurn(player)
	if self.ended then return end
	self.current = player
	self.turnToken += 1
	local token = self.turnToken
	local side = self.sides[player]

	-- พอยต์: ถ้าเทิร์นที่แล้วไม่ได้ Skip พอยต์ที่เหลือจะหาย
	if not side.banking then side.points = 0 end
	side.points = math.min(side.points + Config.POINTS_PER_TURN, Config.MAX_BANKED_POINTS)
	side.banking, side.spentThisTurn = false, false

	-- ช่องเกต: ย้ายการ์ดลงสนามแล้วสุ่มผล
	if side.gate and #side.field < Config.FIELD_SLOTS then
		local card = side.gate
		side.gate = nil
		local outcome = GateRNG.Roll()
		GateRNG.Apply(card, outcome)
		card.CanAttack = true
		table.insert(side.field, card)
		Remotes.GateRolled:FireAllClients(player.UserId, card, outcome.id)
	end

	-- จั่ว: 2 ใบ แต่มือต้องไม่เกิน 5 (ถ้ามี 4 ใบจะได้จั่วแค่ 1 ใบ)
	local wanted = math.min(Config.DRAW_PER_TURN, Config.MAX_HAND - #side.hand)
	local drawCount = math.min(wanted, #side.deck)
	for _ = 1, drawCount do
		table.insert(side.hand, table.remove(side.deck))
	end
	if drawCount < wanted then -- กองหมด = Fatigue
		side.fatigue += 1
		side.leaderHP -= side.fatigue
		if side.leaderHP <= 0 then return self:EndMatch(self:Opponent(player), "FATIGUE") end
	end

	-- การ์ดในสนามโจมตีได้แล้ว
	for _, c in side.field do c.CanAttack = true end

	-- ตัวจับเวลา 2 นาที
	task.delay(Config.TURN_TIME, function()
		if self.turnToken ~= token or self.ended then return end
		side.afk += 1
		if side.afk > Config.AFK_LIMIT then
			self:EndMatch(self:Opponent(player), "AFK_LIGHTNING")
		else
			self:EndTurn(player, true)
		end
	end)

	self:Broadcast()
end

function Match:PlayCard(player, handIndex, target)
	if self.ended or self.current ~= player then return false, "NOT_YOUR_TURN" end
	local side = self.sides[player]
	local card = side.hand[handIndex]
	if not card then return false, "INVALID_CARD" end

	local cost = card.Cost
	if card.Type == "Character" and target == "Gate" then
		cost = math.max(0, cost - Config.GATE_DISCOUNT)
	end
	if cost > side.points then return false, "NOT_ENOUGH_POINTS" end

	if card.Type == "Character" then
		if target == "Gate" then
			if side.gate then return false, "GATE_OCCUPIED" end
			side.gate = card
		else
			if #side.field >= Config.FIELD_SLOTS then return false, "FIELD_FULL" end
			card.CanAttack = false
			table.insert(side.field, card)
		end
	end
	-- TODO: Spell / Weapon / Shield ให้แยกไปทำใน CardEffects module

	table.remove(side.hand, handIndex)
	side.points -= cost
	if cost > 0 then side.spentThisTurn = true end -- โล่ 0 พอยต์ไม่ทำให้เสียสิทธิ์ดอง
	side.afk = 0
	self:Broadcast()
	return true
end

function Match:EndTurn(player, timedOut)
	if self.ended or self.current ~= player then return end
	local side = self.sides[player]
	if not timedOut then side.afk = 0 end
	side.banking = not side.spentThisTurn -- ไม่ได้ใช้พอยต์ = ดองพอยต์ไว้
	self:StartTurn(self:Opponent(player))
end

function Match:EndMatch(winner, reason)
	self.ended = true
	Remotes.MatchEnded:FireAllClients(winner.UserId, reason)
	-- TODO: แจกเพชร, คำนวณค่าหัว, อัปเดต Leaderboard
end

function Match:Broadcast()
	-- ส่งสถานะแยกให้แต่ละคน (ห้ามส่งไพ่ในมือของอีกฝั่งไปให้ดู)
	for _, p in self.players do
		local me, opp = self.sides[p], self.sides[self:Opponent(p)]
		Remotes.StateUpdate:FireClient(p, {
			myHand = me.hand, myField = me.field, myGate = me.gate,
			myPoints = me.points, myHP = me.leaderHP,
			oppHandCount = #opp.hand, oppField = opp.field,
			oppGateFilled = opp.gate ~= nil, oppHP = opp.leaderHP,
			isMyTurn = self.current == p,
		})
	end
end

return Match