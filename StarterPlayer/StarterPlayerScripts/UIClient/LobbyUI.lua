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
local TowerUI = tryRequire("TowerUI")
local DeckBuilder = tryRequire("DeckBuilder")

-- ฟาร์มจริง: เซิร์ฟเวอร์ส่งเวลาเป็น unix (os.time) ส่วน FarmUI ใช้ workspace:GetServerTimeNow() จึงต้องแปลงฐานเวลา
local function openFarm(overlay, wallet, onGems)
	local ok, farms, serverUnix = Net.invoke("GetFarms")
	if not ok then S.toast(Net.message(farms), "bad") return end
	local offset = workspace:GetServerTimeNow() - serverUnix
	local list = {}
	for i, f in farms do
		local c = table.clone(f)
		c.LastClaim = f.LastClaim + offset
		c.Color = ({ S.C.Good, S.C.Info, S.C.Pink })[(i - 1) % 3 + 1]
		list[i] = c
	end
	FarmUI.Open(overlay, { Farms = list, Wallet = wallet or 0, WalletEmoji = "💎",
		OnClaim = function(id)
			local okC, amount = Net.invoke("ClaimFarm", id)
			if okC and onGems then onGems() end
			return okC, okC and amount or Net.message(amount)
		end,
		OnUpgrade = function(id)
			local okU, nf = Net.invoke("UpgradeFarm", id)
			if not okU then return false, Net.message(nf) end
			nf.LastClaim = nf.LastClaim + offset
			if onGems then onGems() end
			return true, nf
		end })
end

local LobbyUI = {}

local TAB_COLOR = { Battle = S.C.Bad, Deck = S.C.Info, Gacha = S.C.Pink, Quests = S.C.Good, Stats = S.C.Violet, Fun = S.C.Teal }
local TABS = {
	{ Id = "Deck", Text = "เด็ค" }, { Id = "Gacha", Text = "กาชา" },
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

	-- ===== เลย์เอาต์ลอย: ไม่มีพื้นหลังทึบ ไม่มีกรอบรวม =====
	-- ชิ้นลอยอิสระ: กล่องเพชร (ขวาบน) / ปุ่มเมนู (ซ้ายกลาง) / ปุ่มต่อสู้ (ล่างกลาง)
	-- หน้าต่างเนื้อหา (panel) เปิดเฉพาะตอนกดเมนู และปิดได้ จอส่วนใหญ่จึงโล่ง
	local root = S.new("Frame", { Name = "LobbyRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = hud })

	local gemBox = S.new("Frame", { Name = "GemBox", BackgroundColor3 = S.C.Panel, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(150, 38), ZIndex = 5, Parent = root }, { S.corner(8) })
	S.stroke(S.C.Accent, 1.5, gemBox)
	local gemLabel = S.text({ Font = S.Font.Bold, Color = S.C.Accent, Max = 18, XAlign = "Center", ZIndex = 6, Parent = gemBox })

	local menu = S.new("Frame", { Name = "Menu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(120, 5 * 42), ZIndex = 5, Parent = root }, {
		S.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- หน้าต่างเนื้อหา: ซ่อนเป็นค่าเริ่มต้น เปิดเมื่อกดเมนู
	local panel = S.new("Frame", { Name = "Panel", BackgroundColor3 = S.C.Panel, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.54, 0.54), Size = UDim2.fromScale(0.62, 0.78), Visible = false, ZIndex = 10, Parent = root },
		{ S.corner(10), S.pad(10), S.new("UISizeConstraint", { MinSize = Vector2.new(320, 180), MaxSize = Vector2.new(900, 640) }) })
	S.stroke(S.C.Violet, 2, panel)
	S.button({ Name = "Close", Text = "X", Max = 18, Color = S.C.Bad, TextColor = S.C.Paper,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(34, 34), ZIndex = 20, Parent = panel,
		OnClick = function() if LobbyUI._close then LobbyUI._close() end end })

	-- ===== หน้า: Frame แนวตั้ง [หัวเรื่อง | เนื้อหา] =====
	local page = nil
	local function newPage(title)
		if page then page:Destroy() end
		page = S.new("Frame", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = panel }, {
			S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local hdr = S.header(page, title, TAB_COLOR[currentTab], 1)
		hdr.Size = UDim2.new(1, -44, 0, 34) -- เว้นที่ปุ่มปิด
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

	local battleDock -- ปุ่มต่อสู้ลอยล่างกลาง (สร้างด้านล่าง)
	local function closePanel()
		panel.Visible = false
		if page then page:Destroy() page = nil end
		currentTab = "Battle"
		paintTabs()
		if battleDock then battleDock.Visible = true end
	end
	LobbyUI._close = closePanel

	local function open(id)
		-- กดแท็บเดิมซ้ำ = ปิดหน้าต่าง
		if id == currentTab and panel.Visible then closePanel() return end
		currentTab = id
		paintTabs()
		panel.Visible = true
		if battleDock then battleDock.Visible = false end
		if panels[id] then panels[id]() end
	end

	for i, tab in TABS do
		tabButtons[tab.Id] = S.button({ Text = tab.Text, Max = 16, Color = S.C.Panel2, LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 36), ZIndex = 6, Parent = menu, OnClick = function() open(tab.Id) end })
	end

	local function refreshIfOpen(id)
		if currentTab == id and panel.Visible then panels[id]() end
	end

	-- ===== 1) ต่อสู้: ปุ่มลอยล่างกลาง (ไม่มีกรอบรวม ไม่มีหน้าต่าง) =====
	battleDock = S.new("Frame", { Name = "BattleDock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(460, 112), ZIndex = 5, Parent = root })

	local leaderRow = S.new("Frame", { Name = "Leaders", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), ZIndex = 5,
		Parent = battleDock }, {
		S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local leaderBtns = {}
	local function paintLeaders()
		for i, b in leaderBtns do
			local st = LEADER_STYLE[Decks.Leaders[i]] or { Color = S.C.Accent }
			local picked = i == leaderIndex
			S.setBase(b, picked and st.Color or S.C.Panel2)
			b.TextColor3 = picked and S.C.Ink or S.C.Text
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Thickness = picked and 3 or 1.5 end
		end
	end
	for i, id in Decks.Leaders do
		local card = CardData[id] or {}
		leaderBtns[i] = S.button({ Text = card.Name or id, Max = 15, LayoutOrder = i, Color = S.C.Panel2,
			Size = UDim2.new(0, 140, 1, 0), ZIndex = 6, Parent = leaderRow,
			OnClick = function() leaderIndex = i; paintLeaders() end })
		leaderBtns[i].MouseEnter:Connect(function() Inspect.Show(card) end)
		leaderBtns[i].MouseLeave:Connect(Inspect.Hide)
	end
	paintLeaders()

	local modeRow = S.new("Frame", { Name = "Modes", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 56),
		Size = UDim2.new(1, 0, 0, 52), ZIndex = 5, Parent = battleDock }, {
		S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local pvpBtn
	local function paintQueue()
		pvpBtn.Text = queueMode and ("ยกเลิก (" .. queueElapsed .. " วิ)") or "จับคู่ PvP"
		S.setBase(pvpBtn, queueMode and S.C.Bad or S.C.Good)
	end
	pvpBtn = S.button({ Text = "จับคู่ PvP", Max = 18, LayoutOrder = 1, Color = S.C.Good, TextColor = S.C.Paper,
		Size = UDim2.new(0, 200, 1, 0), ZIndex = 6, Parent = modeRow,
		OnClick = function()
			if queueMode then
				Net.invoke("Queue", "Cancel")
				queueMode = nil
				paintQueue()
			else
				local ok, res = Net.invoke("Queue", "PvP", Decks.Leaders[leaderIndex])
				if ok then queueMode, queueElapsed = "PvP", 0; paintQueue()
				else S.toast(Net.message(res), "bad") end
			end
		end })
	S.button({ Text = "ซ้อมกับบอท", Max = 18, LayoutOrder = 2, Color = S.C.Violet, TextColor = S.C.Paper,
		Size = UDim2.new(0, 200, 1, 0), ZIndex = 6, Parent = modeRow,
		OnClick = function()
			local ok, res = Net.invoke("Queue", "Bot", Decks.Leaders[leaderIndex])
			if not ok then S.toast(Net.message(res), "bad") end
		end })
	-- ให้ dock ย่อตามความกว้างจอเล็ก
	S.new("UISizeConstraint", { MaxSize = Vector2.new(460, 112), Parent = battleDock })
	battleDock.Size = UDim2.new(0.9, 0, 0, 112)
	panels.Battle = function() paintLeaders(); paintQueue() end
	local function dockScale(short)
		leaderRow.Size = UDim2.new(1, 0, 0, short and 32 or 48)
		modeRow.Position = UDim2.new(0, 0, 0, short and 38 or 56)
		modeRow.Size = UDim2.new(1, 0, 0, short and 36 or 52)
		battleDock.Size = UDim2.new(0.9, 0, 0, short and 78 or 112)
		battleDock.Position = UDim2.new(0.5, 0, 1, short and -6 or -12)
	end

	-- ===== ปรับตามขนาดจอ =====
	-- จอสูง >= 480: เมนูเรียงแนวตั้งซ้ายกลาง / จอเตี้ย: เมนูเรียงแนวนอนใต้แถบบน (ซ้ายไปขวา) ไม่ชน dock และไม่ล้นจอ
	local menuLayout = menu:FindFirstChildOfClass("UIListLayout")
	local function layoutLobby()
		local h = root.AbsoluteSize.Y
		if h <= 0 then return end
		local short = h < 480
		if short == LobbyUI._short then return end
		LobbyUI._short = short
		if short then
			menuLayout.FillDirection = Enum.FillDirection.Horizontal
			menu.AnchorPoint = Vector2.new(0, 0)
			menu.Position = UDim2.new(0, 12, 0, 12)
			menu.Size = UDim2.new(1, -180, 0, 34) -- เว้นที่กล่องเพชรขวาบน
			for _, b in tabButtons do b.Size = UDim2.new(0, 84, 1, 0) end
			dockScale(true)
		else
			menuLayout.FillDirection = Enum.FillDirection.Vertical
			menu.AnchorPoint = Vector2.new(0, 0.5)
			menu.Position = UDim2.new(0, 12, 0.5, 0)
			menu.Size = UDim2.fromOffset(120, 5 * 42)
			for _, b in tabButtons do b.Size = UDim2.new(1, 0, 0, 36) end
			dockScale(false)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLobby)

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
		local holder = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 1, -(DeckBuilder and 100 or 48)), Parent = c })
		cardGrid(holder, profile and profile.Deck or Decks.Starter)
		if DeckBuilder and profile then
			-- ตัวจัดเด็คใหม่ ใช้ SaveDeck เดิมของเซิร์ฟเวอร์ (คืนค่า ok, ข้อความ)
			S.button({ Text = "จัดเด็ค (แบบใหม่)", Max = 16, LayoutOrder = 2, Color = S.C.Pink, TextColor = S.C.Paper,
				Size = UDim2.new(1, 0, 0, 40), Parent = c, OnClick = function()
					DeckBuilder.Open(overlay, { Cards = CardData, Owned = profile.Collection, Deck = profile.Deck,
						Message = Net.message,
						OnSave = function(ids)
							local ok, err = Net.invoke("SaveDeck", ids)
							return ok, err
						end })
				end })
		end
		S.button({ Text = "บันทึกเด็ค", Max = 16, LayoutOrder = 3, Color = S.C.Info, TextColor = S.C.Paper,
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
			{ Text = "หอคอย", Color = S.C.Violet, Mod = TowerUI },
			{ Text = "ประกาศจับ (Bounty)", Color = S.C.Accent, Mod = BountyBoard },
			{ Text = "ทัวร์นาเมนต์", Color = S.C.Info, Mod = TournamentBracket },
			{ Text = "ฟาร์ม", Color = S.C.Good, Mod = FarmUI, Open = function() openFarm(overlay, profile and profile.Gems, LobbyUI.Refresh) end },
		}
		for i, e in entries do
			S.button({ Text = e.Text, Max = 18, Color = e.Color, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 48), Parent = list,
				OnClick = function()
					if not e.Mod then S.toast("หน้านี้ยังโหลดไม่ได้", "bad") return end
					local ok, err = pcall(e.Open or function() return e.Mod.Open(overlay) end)
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
		if panel.Visible or currentTab == "Battle" then panels[currentTab]() end
	end

	function LobbyUI.ResetQueue() queueMode = nil; panels.Battle() end

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
				panels.Battle()
			end
		end
	end)

	paintTabs()
	layoutLobby()
	task.spawn(LobbyUI.Refresh)
end

return LobbyUI
