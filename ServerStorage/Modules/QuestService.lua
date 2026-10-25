local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestData"))

local QuestService = {}
local byId = {}
for _, q in QuestData.Pool do byId[q.Id] = q end

local function today() return math.floor(os.time() / 86400) end -- รีเซ็ตเที่ยงคืน UTC (07:00 ไทย)

function QuestService.Ensure(data, userId)
	if typeof(data.Quests) ~= "table" then data.Quests = { Day = 0, List = {} } end
	local q, day = data.Quests, today()
	if q.Day == day and typeof(q.List) == "table" and #q.List > 0 then return false end
	local rng = Random.new(day * 7919 + (userId % 100000))
	local ids = {}
	for _, def in QuestData.Pool do table.insert(ids, def.Id) end
	local list = {}
	for i = 1, math.min(QuestData.DAILY_COUNT, #ids) do
		local j = rng:NextInteger(i, #ids)
		ids[i], ids[j] = ids[j], ids[i]
		table.insert(list, { Id = ids[i], Progress = 0, Claimed = false })
	end
	q.Day, q.List = day, list
	return true
end

function QuestService.Track(data, userId, event, amount)
	QuestService.Ensure(data, userId)
	local changed = false
	for _, e in data.Quests.List do
		local def = byId[e.Id]
		if def and def.Event == event and not e.Claimed and (e.Progress or 0) < def.Goal then
			e.Progress = math.min(def.Goal, (e.Progress or 0) + (amount or 1))
			changed = true
		end
	end
	return changed
end

function QuestService.Claim(data, userId, questId)
	QuestService.Ensure(data, userId)
	for _, e in data.Quests.List do
		if e.Id == questId then
			local def = byId[e.Id]
			if not def then return false, "BAD_QUEST" end
			if e.Claimed then return false, "ALREADY_CLAIMED" end
			if (e.Progress or 0) < def.Goal then return false, "NOT_DONE" end
			e.Claimed = true
			data.Gems += def.Reward
			return true, def.Reward
		end
	end
	return false, "BAD_QUEST"
end

function QuestService.View(data)
	local list = {}
	for _, e in data.Quests.List do
		local def = byId[e.Id]
		if def then
			table.insert(list, { Id = e.Id, Text = def.Text, Goal = def.Goal, Reward = def.Reward,
				Progress = e.Progress or 0, Claimed = e.Claimed == true })
		end
	end
	return { List = list, ResetIn = (today() + 1) * 86400 - os.time() }
end

return QuestService