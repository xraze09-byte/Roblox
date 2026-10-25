local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Decks = require(Shared:WaitForChild("Decks"))
local DeckRules = require(Shared:WaitForChild("DeckRules"))
local CardData = require(Shared:WaitForChild("CardData"))
local S = require(Shared:WaitForChild("UI"):WaitForChild("Style"))
local Net = require(script.Parent:WaitForChild("Net"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))
local Inspect = require(script.Parent:WaitForChild("Inspect"))
-- หน้าจอใหม่ (โหมดตัวอย่าง): โหลดแบบ pcall เพื่อไม่ให้ล็อบบี้พังถ้าไฟล์ใดมีปัญหา
local function tryRequire(name)
	local inst = script.Parent:FindFirstChild(name)
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	if not ok then warn("[LobbyUI] โหลด " .. name .. " ไม่ได้: " .. tostring(mod)) return nil end
	return mod
end
local BountyBoard = tryRequire("BountyBoard")
local TournamentBracket = tryRequire("TournamentBracket")
local FarmUI = tryRequire("FarmUI")

local LobbyUI = {}

local TAB_COLOR = { Battle = S.C.Bad, Deck = S.C.Info, Gacha = S.C.Pink, Quests = S.C.Good, Stats = S.C.Violet, Fun = S.C.Teal }
local TABS = {
	{ Id = "Battle", Text = "ต่อสู้" }, { Id = "Deck", Text = "เด็ค" }, { Id = "Gacha", Text = "กาชา" },
	{ Id = "Quests", Text = "เควสต์" }, { Id = "Stats", Text = "สถิติ" }, { Id = "Fun", Text = "สนุก" },
}
-- สีประจำผู้นำ (เดิมทุกใบเป็นสีเทาเหมือนกันหมด)
local LEADER_STYLE = {
	LEADER_LUNG = { Color = S.C.Accent, Tag = "ลุง" },
	LEADER_PA = { Color = S.C.Pink, Tag = "ป้า" },
	LEADER_KID = { Color = S.C.Teal, Tag = "เด็ก" },
}
local STAT_NAMES = {
	Matches = "แมตช์ทั้งหมด", Wins = "ชนะ", Losses = "แพ้", Draws = "เสมอ", Surrenders = "ยอมแพ้",
	MatchesPvP = "แมตช์ PvP", MatchesBot = "แมตช์บอท", WinsPvP = "ชนะ PvP", WinsBot = "ชนะบอท",
	LossesPvP = "แพ้ PvP", LossesBot = "แพ้บอท", GemsEarned = "เพชรที่ได้รับ", BestGemsOneMatch = "เพชรสูงสุดต่อแมตช์",
	PlaySec = "เวลาเล่นรวม (วิ)", LongestMatchSec = "แมตช์ที่นานที่สุด (วิ)", ShortestWinSec = "ชนะเร็วที่สุด (วิ)",
	BountyEarned = "ค่าหัวที่ได้รับ",
}

function LobbyUI.Build(hud, overlay)
	Inspect.Init(overlay)
	local profile, stats = nil, nil
	local leaderIndex, queueMode, queueElapsed = 1, nil, 0
	local currentTab = "Battle"
	local panels = {}
	local statusLabel = nil

	-- ===== พื้นหลังทึบเต็มจอ =====
	local backdrop = S.new("Frame", { Name = "Backdrop", BackgroundColor3 = S.C.Bg, Size = UDim2.fromScale(1, 1), Parent = hud })
	S.new("Frame", { Name = "BandTop", BackgroundColor3 = S.C.Violet, BackgroundTransparency = 0.8,
		Size = UDim2.fromScale(1, 0.4), Parent = backdrop })
	S.new("Frame", { Name = "BandBottom", BackgroundColor3 = S.C.Pink, BackgroundTransparency = 0.88,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.3), Parent = backdrop })

	-- ===== โครงหลัก: คอลัมน์แนวตั้ง [แถบบน | เนื้อหา(กินที่เหลือ)] =====
	local root = S.new("Frame", { Name = "LobbyRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = backdrop }, {
		S.pad(12),
		S.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local topBar = S.new("Frame", { Name = "TopBar", BackgroundColor3 = S.C.Panel, LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 46), Parent = root }, { S.corner(8), S.pad(6) })
	S.stroke(S.C.Violet, 1.5, topBar)
	S.text({ Font = S.Font.Heavy, Text = "GAWA CARDS", Color = S.C.Accent, Max = 26,
		Size = UDim2.new(0.5, 0, 1, 0), Parent = topBar })
	local gemBox = S.new("Frame", { BackgroundColor3 = S.C.Ink, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 150, 1, 0), Parent = topBar }, { S.corner(6) })
	S.stroke(S.C.Accent, 1.5, gemBox)
	local gemLabel = S.text({ Font = S.Font.Bold, Color = S.C.Accent, Max = 18, XAlign = "Center", Parent = gemBox })

	-- แถวเนื้อหา: [เมนูซ้าย | แผงขวา(กินที่เหลือ)] เรียงแนวนอน
	local body = S.new("Frame", { Name = "Body", BackgroundTransparency = 1, LayoutOrder = 2,
		Size = UDim2.new(1, 0, 1, -56), Parent = root }, {
		S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local menu = S.new("Frame", { Name = "Menu", BackgroundTransparency = 1, LayoutOrder = 1,
		Size = UDim2.new(0, 140, 1, 0), Parent = body }, {
		S.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local panel = S.new("Frame", { Name = "Panel", BackgroundColor3 = S.C.Panel, LayoutOrder = 2,
		Size = UDim2.new(1, -150, 1, 0), Parent = body }, { S.corner(8), S.pad(10) })
	S.stroke(S.C.Violet, 2, panel)

	-- ===== หน้า: Frame แนวตั้ง [หัวเรื่อง | เนื้อหา] =====
	local page = nil
	local function newPage(title)
		if page then page:Destroy() end
		page = S.new("Frame", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = panel }, {
			S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		S.header(page, title, TAB_COLOR[currentTab], 1)
		local content = S.new("Frame", { Name = "Content", BackgroundTransparency = 1, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 1, -42), Parent = page })
		return content
	end

	local tabButtons = {}
	local function paintTabs()
		for id, btn in tabButtons do
			local on = id == currentTab
			S.setBase(btn, on and TAB_COLOR[id] or S.C.Panel2)
			btn.TextColor3 = on and S.C.Paper or S.C.TextDim
		end
	end

	local function open(id)
		currentTab = id
		paintTabs()
		if panels[id] then panels[id]() end
	end

	for i, tab in TABS do
		tabButtons[tab.Id] = S.button({ Text = tab.Text, Max = 16, Color = S.C.Panel2, LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 36), Parent = menu, OnClick = function() open(tab.Id) end })
	end

	local function refreshIfOpen(id)
		if currentTab == id then panels[id]() end
	end

	-- ===== 1) ต่อสู้ =====
	panels.Battle = function()
		local c = newPage("เลือกผู้นำและโหมดต่อสู้")
		S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })

		-- การ์ดผู้นำ 3 ใบ เรียงแนวนอน
		local row = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 1, -(22 + 52 + 16)), Parent = c }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, id in Decks.Leaders do
			local card = CardData[id] or {}
			local st = LEADER_STYLE[id] or { Color = S.C.Accent }
			local picked = i == leaderIndex
			local tile = S.new("TextButton", { AutoButtonColor = false, Text = "", LayoutOrder = i,
				BackgroundColor3 = picked and st.Color or S.C.Panel2, Size = UDim2.new(0.31, 0, 1, 0), Parent = row },
				{ S.corner(8), S.pad(6) })
			S.stroke(picked and S.C.Paper or st.Color, picked and 3 or 1.5, tile)
			-- เนื้อหาในการ์ดปรับตามความสูงจริง: เตี้ยก็เหลือแค่ชื่อ ไม่ให้ตัวหนังสือทับกัน
			local nameL = S.text({ Name = "Name", Font = S.Font.Heavy, Text = card.Name or id,
				Color = picked and S.C.Ink or S.C.Text, Max = 16, XAlign = "Center", Size = UDim2.fromScale(1, 1), Parent = tile })
			local descL = S.text({ Name = "Desc", Text = S.clean(card.Desc or ""),
				Color = picked and S.C.Ink or S.C.TextDim, Max = 12, XAlign = "Center", YAlign = "Top",
				Position = UDim2.fromScale(0, 0.36), Size = UDim2.fromScale(1, 0.46), Parent = tile })
			local hpL = S.text({ Name = "HP", Font = S.Font.Bold, Text = "HP " .. tostring(card.HP or Config.LEADER_HP),
				Color = picked and S.C.Ink or st.Color, Max = 14, XAlign = "Center",
				Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.16), Parent = tile })
			local function layoutTile()
				local h = tile.AbsoluteSize.Y
				local roomy = h >= 110
				descL.Visible, hpL.Visible = roomy, roomy
				nameL.Size = roomy and UDim2.fromScale(1, 0.34) or UDim2.fromScale(1, 1)
			end
			tile:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTile)
			task.defer(layoutTile)
			tile.Activated:Connect(function()
				if leaderIndex ~= i then leaderIndex = i; panels.Battle() end
			end)
		end

		-- สถานะ
		statusLabel = S.text({ Font = S.Font.Bold, LayoutOrder = 2, Max = 15, XAlign = "Center",
			Text = queueMode and ("กำลังค้นหาคู่แข่ง... " .. queueElapsed .. " วิ") or "พร้อมรบ",
			Color = queueMode and S.C.Accent or S.C.Teal, Size = UDim2.new(1, 0, 0, 22), Parent = c })

		-- ปุ่มโหมด
		local btns = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 52), Parent = c }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		S.button({ Text = queueMode and "ยกเลิกการจับคู่" or "จับคู่ PvP", Max = 18, LayoutOrder = 1,
			Color = queueMode and S.C.Bad or S.C.Good, TextColor = S.C.Paper, Size = UDim2.new(0.47, 0, 1, 0), Parent = btns,
			OnClick = function()
				if queueMode then
					Net.invoke("Queue", "Cancel")
					queueMode = nil
					panels.Battle()
				else
					local ok, res = Net.invoke("Queue", "PvP", Decks.Leaders[leaderIndex])
					if ok then queueMode, queueElapsed = "PvP", 0; panels.Battle()
					else S.toast(Net.message(res), "bad") end
				end
			end })
		S.button({ Text = "ซ้อมกับบอท", Max = 18, LayoutOrder = 2, Color = S.C.Violet, TextColor = S.C.Paper,
			Size = UDim2.new(0.47, 0, 1, 0), Parent = btns,
			OnClick = function()
				local ok, res = Net.invoke("Queue", "Bot", Decks.Leaders[leaderIndex])
				if not ok then S.toast(Net.message(res), "bad") end
			end })
	end

	-- ===== การ์ดเป็นตาราง =====
	local function cardGrid(parent, ids, order)
		local grid = S.scroll({ Parent = parent, LayoutOrder = order or 1, Size = UDim2.fromScale(1, 1),
			Layout = S.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 108), CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, id in ids do
			local c = CardData[id]
			if c then
				local v = CardFace.new(c, { Size = UDim2.fromScale(1, 1), NoAspect = true })
				v.Root.LayoutOrder = i
				v.Root.Parent = grid
				v.Root.MouseEnter:Connect(function() Inspect.Show(c) end)
				v.Root.MouseLeave:Connect(Inspect.Hide)
			end
		end
		return grid
	end

	-- ===== 2) เด็ค =====
	panels.Deck = function()
		local c = newPage(("เด็คของคุณ (%d ใบ)"):format(DeckRules.Size))
		S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
		local holder = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 1, -48), Parent = c })
		cardGrid(holder, profile and profile.Deck or Decks.Starter)
		S.button({ Text = "บันทึกเด็ค", Max = 16, LayoutOrder = 2, Color = S.C.Info, TextColor = S.C.Paper,
			Size = UDim2.new(0.4, 0, 0, 38), Parent = c,
			OnClick = function()
				local ok, err = Net.invoke("SaveDeck", profile and profile.Deck or Decks.Starter)
				if ok then S.toast("บันทึกเด็คสำเร็จ", "good") else S.toast(Net.message(err), "bad") end
			end })
	end

	-- ===== 3) กาชา =====
	local lastPull = {}
	panels.Gacha = function()
		local c = newPage("สุ่มการ์ด")
		S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
		S.text({ Text = ("ราคา %d เพชร ต่อครั้ง หรือ %d เพชร ต่อ 10 ครั้ง"):format(Config.GACHA_COST_1, Config.GACHA_COST_10),
			Color = S.C.TextDim, Max = 14, XAlign = "Center", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), Parent = c })
		local holder = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 1, -100), Parent = c })
		if #lastPull > 0 then cardGrid(holder, lastPull)
		else S.text({ Text = "กดปุ่มด้านล่างเพื่อสุ่มการ์ด", Color = S.C.TextDim, Max = 16, XAlign = "Center", Parent = holder }) end

		local function pull(n)
			local ok, res = Net.invoke("Gacha", n)
			if not ok then S.toast(Net.message(res), "bad") return end
			lastPull = {}
			for _, item in res do table.insert(lastPull, item.Id) end
			S.toast(n == 1 and "สุ่มสำเร็จ" or "สุ่ม 10 ครั้งสำเร็จ", "good")
			refreshIfOpen("Gacha")
		end
		local btns = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 46), Parent = c }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		S.button({ Text = ("สุ่ม 1 ครั้ง (%d)"):format(Config.GACHA_COST_1), Max = 16, LayoutOrder = 1,
			Color = S.C.Pink, TextColor = S.C.Paper, Size = UDim2.new(0.47, 0, 1, 0), Parent = btns, OnClick = function() pull(1) end })
		S.button({ Text = ("สุ่ม 10 ครั้ง (%d)"):format(Config.GACHA_COST_10), Max = 16, LayoutOrder = 2,
			Color = S.C.Accent, TextColor = S.C.Ink, Size = UDim2.new(0.47, 0, 1, 0), Parent = btns, OnClick = function() pull(10) end })
	end

	-- ===== 4) เควสต์ =====
	panels.Quests = function()
		local c = newPage("เควสต์ประจำวัน")
		local list = S.scroll({ Parent = c, Size = UDim2.fromScale(1, 1), Gap = 8 })
		local quests = profile and profile.Quests and profile.Quests.List or {}
		if #quests == 0 then
			S.text({ Text = "กำลังโหลดเควสต์...", Color = S.C.TextDim, Max = 15, Size = UDim2.new(1, 0, 0, 30), Parent = list })
		end
		for i, q in quests do
			local done = q.Progress >= q.Goal
			local row = S.new("Frame", { BackgroundColor3 = S.C.Panel2, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 62), Parent = list },
				{ S.corner(6), S.pad(8) })
			S.stroke(q.Claimed and S.C.Line or (done and S.C.Good or S.C.Violet), 1.5, row)
			S.text({ Font = S.Font.Bold, Text = q.Text, Max = 15, Size = UDim2.fromScale(0.62, 0.5), Parent = row })
			-- แถบความคืบหน้า
			local barBack = S.new("Frame", { BackgroundColor3 = S.C.Bg, Position = UDim2.fromScale(0, 0.62),
				Size = UDim2.fromScale(0.6, 0.26), Parent = row }, { S.corner(4) })
			S.new("Frame", { BackgroundColor3 = done and S.C.Good or S.C.Info,
				Size = UDim2.fromScale(math.clamp(q.Progress / q.Goal, 0, 1), 1), Parent = barBack }, { S.corner(4) })
			S.text({ Font = S.Font.Bold, Text = q.Progress .. "/" .. q.Goal, Max = 12, XAlign = "Center", ZIndex = 2, Parent = barBack })
			if q.Claimed then
				S.text({ Text = "รับแล้ว", Color = S.C.TextDim, Font = S.Font.Bold, Max = 14, XAlign = "Center",
					Position = UDim2.fromScale(0.66, 0), Size = UDim2.fromScale(0.34, 1), Parent = row })
			elseif done then
				S.button({ Text = "รับ " .. q.Reward .. " เพชร", Max = 14, Color = S.C.Good, TextColor = S.C.Paper,
					Position = UDim2.fromScale(0.66, 0.05), Size = UDim2.fromScale(0.34, 0.9), Parent = row,
					OnClick = function()
						local ok, res = Net.invoke("ClaimQuest", q.Id)
						if ok then S.toast("ได้รับ " .. res .. " เพชร", "good"); LobbyUI.Refresh()
						else S.toast(Net.message(res), "bad") end
					end })
			else
				S.text({ Text = q.Reward .. " เพชร", Color = S.C.Accent, Font = S.Font.Bold, Max = 15, XAlign = "Center",
					Position = UDim2.fromScale(0.66, 0), Size = UDim2.fromScale(0.34, 1), Parent = row })
			end
		end
	end

	-- ===== 5) สถิติ =====
	panels.Stats = function()
		local c = newPage("สถิติผู้เล่น")
		local list = S.scroll({ Parent = c, Size = UDim2.fromScale(1, 1), Gap = 5 })
		local st = stats
		if typeof(st) ~= "table" then
			S.text({ Text = "กำลังโหลดสถิติ...", Color = S.C.TextDim, Max = 15, Size = UDim2.new(1, 0, 0, 30), Parent = list })
			return
		end
		local keys = {}
		for k, v in st do
			if typeof(v) == "number" or typeof(v) == "string" then table.insert(keys, tostring(k)) end
		end
		table.sort(keys)
		for i, k in keys do
			local row = S.new("Frame", { BackgroundColor3 = (i % 2 == 0) and S.C.Panel2 or S.C.Bg, LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 30), Parent = list }, { S.corner(4), S.pad(5) })
			S.text({ Text = STAT_NAMES[k] or k, Max = 14, Size = UDim2.fromScale(0.62, 1), Parent = row })
			S.text({ Font = S.Font.Bold, Text = tostring(st[k]), Color = S.C.Accent, Max = 14, XAlign = "Right",
				Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 1), Parent = row })
		end
	end

	-- ===== 6) สนุก: หน้าจอใหม่ (ตอนนี้เป็นข้อมูลตัวอย่าง ยังไม่ต่อเซิร์ฟเวอร์) =====
	panels.Fun = function()
		local c = newPage("โหมดสนุก (ตัวอย่าง)")
		local list = S.scroll({ Parent = c, Size = UDim2.fromScale(1, 1), Gap = 8 })
		local entries = {
			{ Text = "ประกาศจับ (Bounty)", Color = S.C.Accent, Mod = BountyBoard },
			{ Text = "ทัวร์นาเมนต์", Color = S.C.Info, Mod = TournamentBracket },
			{ Text = "ฟาร์ม", Color = S.C.Good, Mod = FarmUI },
		}
		for i, e in entries do
			S.button({ Text = e.Text, Max = 18, Color = e.Color, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 48), Parent = list,
				OnClick = function()
					if not e.Mod then S.toast("หน้านี้ยังโหลดไม่ได้", "bad") return end
					local ok, err = pcall(e.Mod.Open, overlay)
					if not ok then warn("[LobbyUI] เปิด " .. e.Text .. " ไม่ได้: " .. tostring(err)); S.toast("เปิดหน้านี้ไม่ได้", "bad") end
				end })
		end
	end

	-- ===== ข้อมูลโปรไฟล์ =====
	function LobbyUI.Refresh()
		local ok, res = pcall(function() return Net.invoke("GetProfile") end)
		if ok and typeof(res) == "table" then
			profile = res
			gemLabel.Text = (profile.Gems or 0) .. " เพชร"
		end
		local okS, st = pcall(function() return Net.invoke("GetStats") end)
		if okS and typeof(st) == "table" then stats = st end
		panels[currentTab]()
	end

	function LobbyUI.ResetQueue() queueMode = nil end

	Net.on("ProfileChanged", function(p)
		if typeof(p) ~= "table" then return end
		profile = p
		gemLabel.Text = (profile.Gems or 0) .. " เพชร"
		if currentTab == "Quests" or currentTab == "Deck" then panels[currentTab]() end
	end)

	-- นับเวลารอจับคู่
	task.spawn(function()
		while task.wait(1) do
			if queueMode then
				queueElapsed += 1
				if currentTab == "Battle" and statusLabel and statusLabel.Parent then
					statusLabel.Text = "กำลังค้นหาคู่แข่ง... " .. queueElapsed .. " วิ"
				end
			end
		end
	end)

	open("Battle")
	task.spawn(LobbyUI.Refresh)
end

return LobbyUI
