-- โหมดทดสอบ: ผู้เล่นคนที่ 2 เข้ามา = จับคู่กัน, ถ้าอยู่คนเดียวนาน 5 วิ = สู้กับบอท
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CardData = require(game:GetService("ReplicatedStorage").Shared.CardData)
local Match = require(ServerStorage.Modules.Match)
local MatchRegistry = require(ServerStorage.Modules.MatchRegistry)

local WAIT_FOR_HUMAN = 5

local function buildTestDeck()
	local ids = {}
	for id, c in CardData do
		if c.Type ~= "Leader" then table.insert(ids, id) end
	end
	table.sort(ids)
	local deck = {}
	for i = 1, 24 do
		table.insert(deck, Match.MakeCard(ids[(i - 1) % #ids + 1]))
	end
	return deck
end

-- บอทเป็นตารางธรรมดา (Match ข้ามการยิง Remote ให้บอท)
local function newBot()
	return { Name = "BotKitty", UserId = -1, IsBot = true }
end

local function botLoop(match, bot)
	task.spawn(function()
		local lastToken = -1
		while not match.ended do
			task.wait(0.5)
			if match.current == bot and match.turnToken ~= lastToken then
				lastToken = match.turnToken
				task.wait(1.5)
				local side = match.sides[bot]
				for _ = 1, 5 do
					if match.ended or match.current ~= bot then break end
					local played = false
					for i, card in side.hand do
						if card.Type == "Character" and card.Cost <= side.points and #side.field < 3 then
							if match:PlayCard(bot, i, "Field") then
								played = true
								task.wait(0.8)
								break
							end
						end
					end
					if not played then break end
				end
				-- โจมตีผู้นำผู้เล่นถ้าไม่มีตัวบัง
				local opp = match:Opponent(bot)
				for _, c in table.clone(side.field) do
					if match.ended or match.current ~= bot then break end
					if c.CanAttack and (c.ATK or 0) > 0 then
						local target = "LEADER"
						for _, oc in match.sides[opp].field do
							if oc.Keywords and table.find(oc.Keywords, "Taunt") then target = oc.Uid break end
						end
						match:Attack(bot, c.Uid, target)
						task.wait(0.8)
					end
				end
				if not match.ended and match.current == bot then
					match:EndTurn(bot, false)
				end
			end
		end
	end)
end

local function start(a, b)
	local isBotMatch = typeof(b) == "table"
	local m = Match.new(a, b, buildTestDeck(), buildTestDeck(),
		{ Name = "ลุงกาวผู้ยิ่งใหญ่" }, { Name = isBotMatch and "แมวบอท" or "ป้าดวงเฮง" })
	MatchRegistry.Set(a, m)
	if not isBotMatch then MatchRegistry.Set(b, m) else botLoop(m, b) end
	task.wait(2) -- รอให้ UI ฝั่งผู้เล่นโหลดเสร็จ
	m:StartTurn(a)
end

local waiting
local function onJoin(p)
	if waiting and waiting.Parent and waiting ~= p then
		local a = waiting
		waiting = nil
		task.spawn(start, a, p)
	else
		waiting = p
		task.delay(WAIT_FOR_HUMAN, function()
			if waiting == p and p.Parent and not MatchRegistry.Get(p) then
				waiting = nil
				start(p, newBot())
			end
		end)
	end
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do onJoin(p) end

Players.PlayerRemoving:Connect(function(p)
	if waiting == p then waiting = nil end
	local m = MatchRegistry.Get(p)
	if m and not m.ended then m:EndMatch(m:Opponent(p), "LEFT") end
	MatchRegistry.Set(p, nil)
end)
