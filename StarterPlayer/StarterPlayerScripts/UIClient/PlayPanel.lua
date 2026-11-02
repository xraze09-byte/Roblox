-- UIClient/PlayPanel.lua
-- [Bot | PvP] tabs, list on the left, details + Play on the right. 1v1 only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("MenuKit"))
local C = Kit.C

local PlayPanel = {}

local LISTS = {
	Bot = {
		{ Id = "BotEasy",   Level = "Easy",   Text = "ง่าย",     Color = C.Lime,   Desc = "บอทมือใหม่ คิดช้า ชอบพลาด เหมาะกับลองเด็คใหม่" },
		{ Id = "BotMedium", Level = "Medium", Text = "ปานกลาง", Color = C.Yellow, Desc = "บอทซ้อมมาตรฐาน เล่นตรง ๆ ไม่มีลูกเล่น" },
		{ Id = "BotHard",   Level = "Hard",   Text = "ยาก",      Color = C.Orange, Desc = "แลกการ์ดเก่ง และรู้จังหวะปิดเกม" },
		{ Id = "BotHacker", Level = "Hacker", Text = "แฮกเกอร์", Color = C.Red,    Desc = "ฉลาดเท่าบอทยาก แถมโกงได้แต้ม +1 ทุกเทิร์น!" },
		{ Id = "BotMix",    Level = "Mix",    Text = "สุ่มบอท",  Color = C.Pink,   Desc = "สุ่มระดับใหม่ทุกแมตช์ ชนะได้โบนัสเพิ่ม" },
		{ Id = "Tower",                       Text = "หอคอย",    Color = C.Blue,   Desc = "ไต่หอคอยทีละชั้น บอสเก่งขึ้นเรื่อย ๆ" },
	},
	PvP = {
		{ Id = "PvP", Text = "ดวลไม่จำกัด", Color = C.Pink,
			Desc = "Unlimited Duel: จับคู่ผู้เล่นจริงแบบ 1v1 เล่นกี่รอบก็ได้ ไม่มีค่าเข้า" },
	},
}

local state = { Tab = "Bot", Pick = { Bot = "BotMedium", PvP = "PvP" } }

local function find(tab, id)
	for _, it in LISTS[tab] do
		if it.Id == id then return it end
	end
	return LISTS[tab][1]
end

local function rewardText(item, api)
	if item.Id == "PvP" then
		return ("ชนะ +%d เพชร • แพ้ +%d • ล่าค่าหัว +%d/สตรีค"):format(
			Config.REWARD_WIN_PVP, Config.REWARD_LOSE_PVP, Config.BOUNTY_PER_STREAK)
	elseif item.Id == "Tower" then
		local f = api.TowerFloor and api.TowerFloor() or 1
		return ("ชั้น %d • ชนะ +%d เพชร"):format(f, Config.TOWER_REWARD_BASE + f * Config.TOWER_REWARD_PER_FLOOR)
	elseif item.Level == "Mix" then
		return ("รางวัลตามระดับที่สุ่มได้ +%d โบนัส"):format(Config.BOT_MIX_BONUS or 0)
	end
	local lv = Config.BOT_LEVELS and Config.BOT_LEVELS[item.Level]
	return ("ชนะ +%d เพชร"):format(lv and lv.Reward or Config.REWARD_WIN_BOT)
end

local function row(parent, order)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 40)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

-- api: StartMode(mode), TogglePvP(), IsQueuing(), LeaderName(), NextLeader(), TowerFloor()
function PlayPanel.Open(api)
	local w = Kit.open({ Title = "เล่น", Color = C.Red })
	local body = w.Body

	local left = Kit.scroll(body, { Size = UDim2.new(0.38, -6, 1, -54) })

	local right = Instance.new("Frame")
	right.BackgroundColor3 = C.Dark
	right.Position = UDim2.new(0.38, 6, 0, 0)
	right.Size = UDim2.new(0.62, -6, 1, -54)
	right.Parent = body
	Kit.corner(right)
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do pad[k] = UDim.new(0, 10) end
	pad.Parent = right
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = right

	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.new(0, 0, 1, -46)
	bottom.Size = UDim2.new(1, 0, 0, 46)
	bottom.Parent = body

	local playBtn = Kit.button(bottom, "เล่น!", C.Red, nil, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.32, 0, 1, 0), TextColor3 = C.White,
	})

	local renderList, renderDetail

	renderDetail = function()
		Kit.clear(right)
		local item = find(state.Tab, state.Pick[state.Tab])
		Kit.label(right, item.Text, item.Color, {
			Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left }, 36)
		Kit.label(right, item.Desc, C.White, {
			Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left }, 20)
		Kit.label(right, rewardText(item, api), C.Yellow, {
			Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left }, 20)

		-- Mode: 1v1 only for now
		local mode = row(right, 4)
		Kit.label(mode, "โหมด", C.Gray, { Size = UDim2.new(0.28, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
		Kit.button(mode, "1v1", C.Yellow, nil, { Position = UDim2.fromScale(0.28, 0), Size = UDim2.new(0.25, 0, 1, 0) })

		-- Leader picker
		local lead = row(right, 5)
		Kit.label(lead, "ผู้นำ", C.Gray, { Size = UDim2.new(0.28, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
		Kit.button(lead, api.LeaderName() .. "  ▶", C.Lime, function(b)
			api.NextLeader()
			b.Text = api.LeaderName() .. "  ▶"
		end, { Position = UDim2.fromScale(0.28, 0), Size = UDim2.new(0.72, 0, 1, 0) })

		local queuing = state.Tab == "PvP" and api.IsQueuing()
		playBtn.Text = queuing and "ยกเลิกหา" or "เล่น!"
		playBtn.BackgroundColor3 = queuing and C.Gray or C.Red
	end

	renderList = function()
		Kit.clear(left)
		for i, it in LISTS[state.Tab] do
			local on = it.Id == state.Pick[state.Tab]
			Kit.button(left, it.Text, on and it.Color or C.Dark, function()
				state.Pick[state.Tab] = it.Id
				renderList(); renderDetail()
			end, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = i, TextColor3 = on and C.Ink or C.White })
		end
	end

	local tabBar, selectTab = Kit.tabs(bottom, {
		{ Id = "Bot", Text = "บอท", Color = C.Lime },
		{ Id = "PvP", Text = "PvP", Color = C.Pink },
	}, function(id)
		state.Tab = id
		renderList(); renderDetail()
	end)
	tabBar.Size = UDim2.new(0.45, 0, 1, 0)

	playBtn.Activated:Connect(function()
		local item = find(state.Tab, state.Pick[state.Tab])
		Kit.close() -- close first so FloatHUD toasts are visible
		if item.Id == "PvP" then api.TogglePvP() else api.StartMode(item.Id) end
	end)

	selectTab(state.Tab)
end

return PlayPanel