-- สร้างแมตช์ทดสอบกับบอทเมื่อผู้เล่นเข้าเกม
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CardData = require(ReplicatedStorage.Shared.CardData)
local Match = require(ServerStorage.Modules.Match)
local MatchRegistry = require(ServerStorage.Modules.MatchRegistry)

-- บอทเป็นตารางจำลองผู้เล่น (Match ข้าม FireClient ถ้า IsBot = true)
local function newBot()
	return { Name = "BotKitty", UserId = -1, IsBot = true }
end

local function botTurnLoop(match, bot)
	task.spawn(function()
		local lastToken = -1
		while not match.ended do
			task.wait(0.5)
			if match.current == bot and match.turnToken ~= lastToken then
				lastToken = match.turnToken
				task.wait(1.5)
				local side = match.sides[bot]
				-- เล่นการ์ดตัวละครที่จ่ายไหวลงสนาม
				local guard = 0
				while guard < 5 and not match.ended and match.current == bot do
					guard += 1
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
				if not match.ended and match.current == bot then
					match:EndTurn(bot, false)
				end
			end
		end
	end)
end

local function startMatch(player)
	if MatchRegistry.Get(player) then return end
	local bot = newBot()
	local match = Match.new(player, bot, CardData.BuildTestDeck(), CardData.BuildTestDeck(),
		CardData.GetLeader(), CardData.GetLeader())
	MatchRegistry.Set(player, match)
	botTurnLoop(match, bot)
	task.wait(1) -- รอให้ไคลเอนต์โหลด UI
	match:StartTurn(player)
end

Players.PlayerAdded:Connect(function(p) task.spawn(startMatch, p) end)
for _, p in Players:GetPlayers() do task.spawn(startMatch, p) end

Players.PlayerRemoving:Connect(function(p)
	local m = MatchRegistry.Get(p)
	if m then m.ended = true end
	MatchRegistry.Set(p, nil)
end)
