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

local LobbyUI = {}

function LobbyUI.Build(hud, overlay)
	Inspect.Init(overlay)
	local profile = nil
	local stats = nil
	local leaderIndex = 1
	local queueMode = nil
	local queueElapsed = 0

	local root = S.new("Frame", { Name = "LobbyRoot", BackgroundColor3 = S.C.Bg,
		Size = UDim2.fromScale(1, 1), Parent = hud }, { S.pad(14) })

	-- แถบบน: ชื่อเกม + แสดงเพชร
	local topBar = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.08), Parent = root })
	S.text({ Font = S.Font.Heavy, Text = "GAWA CARDS", Max = 26, Size = UDim2.fromScale(0.4, 1), Parent = topBar })
	
	local gemBox = S.new("Frame", { BackgroundColor3 = S.C.Panel, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(130, 36), Parent = topBar }, { S.corner(4) })
	S.stroke(S.C.Line, 1, gemBox)
	local gemLabel = S.text({ Font = S.Font.Bold, Color = S.C.Accent, Max = 16, XAlign = "Center", Parent = gemBox })

	-- เนื้อหาหลักตรงกลาง
	local content = S.new("Frame", { BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.09), Size = UDim2.fromScale(1, 0.9), Parent = root })

	-- แท็บซ้าย: เมนูเลือกโหมด/ระบบต่างๆ (เลื่อนได้ ไม่ล้นจอ)
	local menuF = S.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.22, 1),
		ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = content }, {
		S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- หน้าต่างขวา: ทุกหน้าสร้างเป็น "page" ที่เรียงเนื้อหาลงมาเป็นแถว จึงไม่มีทางซ้อนกัน
	local panel = S.new("Frame", { BackgroundColor3 = S.C.Panel,
		Position = UDim2.fromScale(0.235, 0), Size = UDim2.fromScale(0.765, 1), Parent = content }, {
		S.corner(6), S.pad(14),
	})
	S.stroke(S.C.Line, 1, panel)

	local page = nil
	local tabButtons = {}
	local ROW = 8

	-- สร้างหน้าใหม่: คืน (page, title) โดย page เป็น Frame ที่ใช้ UIListLayout แนวตั้ง
	local function newPage(titleText)
		if page then page:Destroy() end
		page = S.new("Frame", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = panel }, {
			S.new("UIListLayout", { Padding = UDim.new(0, ROW), SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		S.text({ Font = S.Font.Bold, Text = titleText, Max = 20, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), Parent = page })
		return page
	end

	-- กล่องเลื่อนที่กินพื้นที่ที่เหลือ (ใช้ UIFlexItem ไม่ได้ทุกเวอร์ชัน จึงกำหนดสัดส่วนเอง)
	local function scroller(parent, order, heightScale, layout)
		local f = S.new("ScrollingFrame", { BackgroundTransparency = 1, LayoutOrder = order,
			Size = UDim2.new(1, 0, heightScale, -40), ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent })
		if layout then layout.Parent = f end
		return f
	end

	local function show(tabId)
		for id, btn in tabButtons do
			S.setBase(btn, id == tabId and S.C.Accent or S.C.Panel2)
			btn.TextColor3 = id == tabId and S.C.Ink or S.C.Text
		end
	end

	local panels = {}

	local function fillCards(box, items)
		box:ClearAllChildren()
		S.new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 112), CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
		for _, id in items do
			local c = CardData[id]
			if c then
				local v = CardFace.new(c, { Size = UDim2.fromScale(1, 1) })
				v.Root.Parent = box
			end
		end
	end

	-- 1) หน้าต่อสู้
	panels.Battle = function()
		show("Battle")
		local pg = newPage("เลือกผู้นำและโหมดต่อสู้")

		local leadersF = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 100), Parent = pg }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, id in Decks.Leaders do
			local c = CardData[id]
			S.button({ Text = (c and c.Name or id), Max = 14, LayoutOrder = i,
				Color = (leaderIndex == i and S.C.Accent or S.C.Panel2),
				TextColor = (leaderIndex == i and S.C.Ink or S.C.Text),
				Size = UDim2.new(0.3, 0, 1, 0), Parent = leadersF,
				OnClick = function() leaderIndex = i; panels.Battle() end })
		end

		S.text({ Text = queueMode and ("กำลังค้นหาคู่แข่ง... (" .. queueElapsed .. " วิ)") or "พร้อมรบ",
			Font = S.Font.Bold, Max = 16, XAlign = "Center", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 28), Parent = pg })

		local btns = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 56), Parent = pg }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		S.button({ Text = queueMode and "ยกเลิกการจับคู่" or "จับคู่ PvP", Max = 18, LayoutOrder = 1,
			Color = queueMode and S.C.Bad or S.C.Good, TextColor = S.C.Paper, Size = UDim2.new(0.4, 0, 1, 0), Parent = btns,
			OnClick = function()
				if queueMode then
					Net.invoke("Queue", "Cancel")
					queueMode = nil
					panels.Battle()
				else
					local ok, res = Net.invoke("Queue", "PvP", Decks.Leaders[leaderIndex])
					if ok then queueMode = "PvP"; queueElapsed = 0; panels.Battle() else S.toast(Net.message(res), "bad") end
				end
			end })
		S.button({ Text = "ซ้อมกับบอท", Max = 18, LayoutOrder = 2, Color = S.C.Info, TextColor = S.C.Paper,
			Size = UDim2.new(0.4, 0, 1, 0), Parent = btns,
			OnClick = function()
				local ok, res = Net.invoke("Queue", "Bot", Decks.Leaders[leaderIndex])
				if not ok then S.toast(Net.message(res), "bad") end
			end })
	end

	-- 2) หน้าจัดเด็ค
	panels.Deck = function()
		show("Deck")
		local pg = newPage(("เด็คของคุณ (ต้องครบ %d ใบ)"):format(DeckRules.Size))
		local currentDeck = profile and profile.Deck or Decks.Starter
		local grid = scroller(pg, 2, 0.8)
		fillCards(grid, currentDeck)
		S.button({ Text = "บันทึกเด็ค", Max = 16, LayoutOrder = 3, Color = S.C.Accent, TextColor = S.C.Ink,
			Size = UDim2.new(0.4, 0, 0, 36), Parent = pg,
			OnClick = function()
				local ok, err = Net.invoke("SaveDeck", currentDeck)
				if ok then S.toast("บันทึกเด็คสำเร็จ", "good") else S.toast(Net.message(err), "bad") end
			end })
	end

	-- 3) หน้ากาชา
	panels.Gacha = function()
		show("Gacha")
		local pg = newPage("สุ่มการ์ด")
		S.text({ Text = ("ราคา: %d เพชร / ครั้ง หรือ %d เพชร / 10 ครั้ง"):format(Config.GACHA_COST_1, Config.GACHA_COST_10),
			Color = S.C.TextDim, Max = 14, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), Parent = pg })

		local resBox = scroller(pg, 3, 0.6)

		local function pull(n)
			local ok, res = Net.invoke("Gacha", n)
			if not ok then S.toast(Net.message(res), "bad") return end
			local ids = {}
			for _, item in res do table.insert(ids, item.Id) end
			fillCards(resBox, ids)
			S.toast(n == 1 and "สุ่มสำเร็จ" or "สุ่ม 10 ครั้งสำเร็จ", "good")
		end

		local btns = S.new("Frame", { BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 48), Parent = pg }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		S.button({ Text = ("สุ่ม 1 ครั้ง (%d)"):format(Config.GACHA_COST_1), Max = 16, LayoutOrder = 1,
			Color = S.C.Accent, TextColor = S.C.Ink, Size = UDim2.new(0.42, 0, 1, 0), Parent = btns,
			OnClick = function() pull(1) end })
		S.button({ Text = ("สุ่ม 10 ครั้ง (%d)"):format(Config.GACHA_COST_10), Max = 16, LayoutOrder = 2,
			Color = S.C.Good, TextColor = S.C.Paper, Size = UDim2.new(0.42, 0, 1, 0), Parent = btns,
			OnClick = function() pull(10) end })
	end

	-- 4) หน้าเควสต์
	panels.Quests = function()
		show("Quests")
		local pg = newPage("เควสต์ประจำวัน")
		local list = scroller(pg, 2, 0.88, S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }))
		local quests = profile and profile.Quests and profile.Quests.List or {}
		if #quests == 0 then
			S.text({ Text = "กำลังโหลดเควสต์...", Color = S.C.TextDim, Max = 15, Size = UDim2.new(1, 0, 0, 30), Parent = list })
		end
		for i, q in quests do
			local row = S.new("Frame", { BackgroundColor3 = S.C.Panel2, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), Parent = list },
				{ S.corner(4), S.pad(8) })
			S.text({ Font = S.Font.Bold, Text = q.Text, Max = 15, Size = UDim2.fromScale(0.62, 0.5), Parent = row })
			S.text({ Text = ("ความคืบหน้า %d / %d"):format(q.Progress, q.Goal), Color = S.C.TextDim, Max = 13,
				Position = UDim2.fromScale(0, 0.52), Size = UDim2.fromScale(0.62, 0.48), Parent = row })
			if q.Claimed then
				S.text({ Text = "รับแล้ว", Color = S.C.Good, Font = S.Font.Bold, Max = 14, XAlign = "Right",
					Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.35, 1), Parent = row })
			elseif q.Progress >= q.Goal then
				S.button({ Text = "รับ " .. q.Reward .. " เพชร", Max = 14, Color = S.C.Accent, TextColor = S.C.Ink,
					Position = UDim2.fromScale(0.66, 0.05), Size = UDim2.fromScale(0.34, 0.9), Parent = row,
					OnClick = function()
						local ok, res = Net.invoke("ClaimQuest", q.Id)
						if ok then S.toast("รับรางวัลสำเร็จ +" .. res .. " เพชร", "good"); LobbyUI.Refresh()
						else S.toast(Net.message(res), "bad") end
					end })
			else
				S.text({ Text = "รางวัล " .. q.Reward, Color = S.C.TextDim, Max = 14, XAlign = "Right",
					Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.35, 1), Parent = row })
			end
		end
	end

	-- 5) หน้าสถิติ
	panels.Stats = function()
		show("Stats")
		local pg = newPage("สถิติผู้เล่น")
		local st = stats or Net.invoke("GetStats") or {}
		local list = scroller(pg, 2, 0.88, S.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }))
		local keys = {}
		for k in st do table.insert(keys, tostring(k)) end
		table.sort(keys)
		for i, k in keys do
			local v = st[k]
			local row = S.new("Frame", { BackgroundColor3 = S.C.Panel2, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 34) },
				{ S.corner(3), S.pad(6) })
			row.Parent = list
			S.text({ Text = k, Max = 14, Size = UDim2.fromScale(0.6, 1), Parent = row })
			S.text({ Font = S.Font.Bold, Text = typeof(v) == "table" and "..." or tostring(v), Max = 14, XAlign = "Right",
				Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.4, 1), Parent = row })
		end
	end

	local tabs = {
		{ Id = "Battle", Text = "ต่อสู้" }, { Id = "Deck", Text = "เด็ค" }, { Id = "Gacha", Text = "กาชา" },
		{ Id = "Quests", Text = "เควสต์" }, { Id = "Stats", Text = "สถิติ" },
	}
	for i, tab in tabs do
		tabButtons[tab.Id] = S.button({ Text = tab.Text, Max = 16, Color = S.C.Panel2, LayoutOrder = i,
			Size = UDim2.new(1, -6, 0, 44), Parent = menuF, OnClick = function() panels[tab.Id]() end })
	end

	function LobbyUI.Refresh()
		local ok, res = pcall(function() return Net.invoke("GetProfile") end)
		if ok and typeof(res) == "table" then
			profile = res
			gemLabel.Text = (profile.Gems or 0) .. " เพชร"
		end
		stats = Net.invoke("GetStats")
	end

	function LobbyUI.ResetQueue()
		queueMode = nil
	end

	Net.on("ProfileChanged", function(p)
		profile = p
		gemLabel.Text = (profile.Gems or 0) .. " เพชร"
	end)

	panels.Battle()
	LobbyUI.Refresh()
end

return LobbyUI