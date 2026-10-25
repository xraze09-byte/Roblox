local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

	-- แท็บซ้าย: เมนูเลือกโหมด/ระบบต่างๆ
	local menuF = S.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.24, 1),
		ScrollBarThickness = 4, Parent = content }, {
		S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- หน้าต่างขวา: แสดงเนื้อหาตามเมนูที่เลือก
	local panel = S.new("Frame", { BackgroundColor3 = S.C.Panel,
		Position = UDim2.fromScale(0.26, 0), Size = UDim2.fromScale(0.74, 1), Parent = content }, {
		S.corner(6), S.pad(14),
	})
	S.stroke(S.C.Line, 1, panel)

	local function clearPanel()
		for _, c in panel:GetChildren() do
			if not c:IsA("UIConstraint") and c.Name ~= "UIPadding" and c.Name ~= "UIStroke" and c.Name ~= "UICorner" then
				c:Destroy()
			end
		end
	end

	local panels = {}

	-- 1) หน้าต่อสู้ (Queue)
	panels.Battle = function()
		clearPanel()
		S.text({ Font = S.Font.Bold, Text = "เลือกผู้นำและโหมดต่อสู้", Max = 20, Size = UDim2.new(1, 0, 0, 30), Parent = panel })

		local leadersF = S.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.new(1, 0, 0, 110), Parent = panel }, {
			S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		for i, id in Decks.Leaders do
			local c = CardData[id]
			S.button({ Text = (c and c.Name or id), Max = 14, Color = (leaderIndex == i and S.C.Accent or S.C.Panel2),
				TextColor = (leaderIndex == i and S.C.Ink or S.C.Text), Size = UDim2.fromOffset(140, 100), Parent = leadersF,
				OnClick = function() leaderIndex = i; panels.Battle() end })
		end

		S.text({ Text = queueMode and ("กำลังค้นหาคู่แข่ง... (" .. queueElapsed .. "s)") or "พร้อมรบ",
			Font = S.Font.Bold, Max = 16, XAlign = "Center", Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 30), Parent = panel })

		S.button({ Text = "จับคู่ PvP", Max = 18, Color = S.C.Good, TextColor = S.C.Paper,
			Position = UDim2.fromScale(0.1, 0.65), Size = UDim2.fromScale(0.38, 0.14), Parent = panel,
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

		S.button({ Text = "ซ้อมกับบอท", Max = 18, Color = S.C.Info, TextColor = S.C.Paper,
			Position = UDim2.fromScale(0.52, 0.65), Size = UDim2.fromScale(0.38, 0.14), Parent = panel,
			OnClick = function()
				local ok, res = Net.invoke("Queue", "Bot", Decks.Leaders[leaderIndex])
				if not ok then S.toast(Net.message(res), "bad") end
			end })
	end

	-- 2) หน้าจัดการเด็ค
	panels.Deck = function()
		clearPanel()
		S.text({ Font = S.Font.Bold, Text = ("จัดเด็คการ์ดของคุณ (ต้องครบ %d ใบ)"):format(DeckRules.Size), Max = 20, Size = UDim2.new(1, 0, 0, 30), Parent = panel })

		local currentDeck = profile and profile.Deck or Decks.Starter
		local grid = S.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.fromScale(1, 0.75), ScrollBarThickness = 6, Parent = panel }, {
			S.new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 112), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		for _, id in currentDeck do
			local c = CardData[id]
			if c then
				local v = CardFace.new(c, { Size = UDim2.fromScale(1, 1) })
				v.Root.Parent = grid
			end
		end

		S.button({ Text = "บันทึกเด็ค", Max = 16, Color = S.C.Accent, TextColor = S.C.Ink,
			Position = UDim2.fromScale(0.3, 0.88), Size = UDim2.fromScale(0.4, 0.1), Parent = panel,
			OnClick = function()
				local ok, err = Net.invoke("SaveDeck", currentDeck)
				if ok then S.toast("บันทึกเด็คสำเร็จ", "good") else S.toast(Net.message(err), "bad") end
			end })
	end

	-- 3) หน้ากาชา
	panels.Gacha = function()
		clearPanel()
		S.text({ Font = S.Font.Bold, Text = "สุ่มการ์ด (ตู้สุ่มประจำวัน)", Max = 20, Size = UDim2.new(1, 0, 0, 30), Parent = panel })

		S.text({ Text = "ราคา: 50 เพชร / ครั้ง หรือ 450 เพชร / 10 ครั้ง", Color = S.C.TextDim, Max = 14,
			Position = UDim2.fromScale(0, 0.12), Size = UDim2.new(1, 0, 0, 24), Parent = panel })

		local resBox = S.new("ScrollingFrame", { BackgroundColor3 = S.C.Panel2, Position = UDim2.fromScale(0, 0.22),
			Size = UDim2.fromScale(1, 0.55), ScrollBarThickness = 6, Parent = panel }, {
			S.corner(4), S.pad(10),
			S.new("UIGridLayout", { CellSize = UDim2.fromOffset(76, 106), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		S.button({ Text = "สุ่ม 1 ครั้ง (50 เพชร)", Max = 16, Color = S.C.Accent, TextColor = S.C.Ink,
			Position = UDim2.fromScale(0.05, 0.84), Size = UDim2.fromScale(0.42, 0.12), Parent = panel,
			OnClick = function()
				local ok, res = Net.invoke("Gacha", 1)
				if not ok then S.toast(Net.message(res), "bad") else
					resBox:ClearAllChildren()
					for _, item in res do
						local c = CardData[item.Id]
						if c then
							local v = CardFace.new(c, { Size = UDim2.fromScale(1, 1) })
							v.Root.Parent = resBox
						end
					end
					S.toast("สุ่มสำเร็จ!", "good")
				end
			end })

		S.button({ Text = "สุ่ม 10 ครั้ง (450 เพชร)", Max = 16, Color = S.C.Good, TextColor = S.C.Paper,
			Position = UDim2.fromScale(0.53, 0.84), Size = UDim2.fromScale(0.42, 0.12), Parent = panel,
			OnClick = function()
				local ok, res = Net.invoke("Gacha", 10)
				if not ok then S.toast(Net.message(res), "bad") else
					resBox:ClearAllChildren()
					for _, item in res do
						local c = CardData[item.Id]
						if c then
							local v = CardFace.new(c, { Size = UDim2.fromScale(1, 1) })
							v.Root.Parent = resBox
						end
					end
					S.toast("สุ่ม 10 ครั้งสำเร็จ!", "good")
				end
			end })
	end

	-- 4) หน้าเควสต์
	panels.Quests = function()
		clearPanel()
		S.text({ Font = S.Font.Bold, Text = "เควสต์ประจำวัน", Max = 20, Size = UDim2.new(1, 0, 0, 30), Parent = panel })

		local listF = S.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.12),
			Size = UDim2.fromScale(1, 0.85), ScrollBarThickness = 6, Parent = panel }, {
			S.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		local quests = profile and profile.Quests and profile.Quests.List or {}
		for _, q in quests do
			local row = S.new("Frame", { BackgroundColor3 = S.C.Panel2, Size = UDim2.new(1, 0, 0, 54), Parent = listF }, { S.corner(4), S.pad(8) })
			S.text({ Font = S.Font.Bold, Text = q.Text, Max = 15, Size = UDim2.fromScale(0.6, 0.5), Parent = row })
			S.text({ Text = ("ความคืบหน้า: %d / %d"):format(q.Progress, q.Goal), Color = S.C.TextDim, Max = 13,
				Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(0.6, 0.4), Parent = row })

			if q.Claimed then
				S.text({ Text = "รับแล้ว", Color = S.C.Good, Font = S.Font.Bold, Max = 14, XAlign = "Right", Size = UDim2.fromScale(0.35, 1), Parent = row })
			elseif q.Progress >= q.Goal then
				S.button({ Text = "รับ " .. q.Reward .. " เพชร", Max = 14, Color = S.C.Accent, TextColor = S.C.Ink,
					Position = UDim2.fromScale(0.68, 0.1), Size = UDim2.fromScale(0.3, 0.8), Parent = row,
					OnClick = function()
						local ok, res = Net.invoke("ClaimQuest", q.Id)
						if ok then S.toast("รับรางวัลสำเร็จ +" .. res .. " เพชร", "good"); LobbyUI.Refresh() else S.toast(Net.message(res), "bad") end
					end })
			else
				S.text({ Text = "รางวัล " .. q.Reward, Color = S.C.TextDim, Max = 14, XAlign = "Right", Size = UDim2.fromScale(0.35, 1), Parent = row })
			end
		end
	end

	-- 5) หน้าสถิติ
	panels.Stats = function()
		clearPanel()
		S.text({ Font = S.Font.Bold, Text = "สถิติผู้เล่น", Max = 20, Size = UDim2.new(1, 0, 0, 30), Parent = panel })
		local st = stats or Net.invoke("GetStats") or {}
		local listF = S.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.12),
			Size = UDim2.fromScale(1, 0.85), ScrollBarThickness = 6, Parent = panel }, {
			S.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for k, v in st do
			local row = S.new("Frame", { BackgroundColor3 = S.C.Panel2, Size = UDim2.new(1, 0, 0, 36), Parent = listF }, { S.corner(3), S.pad(6) })
			S.text({ Text = tostring(k), Max = 14, Size = UDim2.fromScale(0.6, 1), Parent = row })
			S.text({ Font = S.Font.Bold, Text = tostring(v), Max = 14, XAlign = "Right", Size = UDim2.fromScale(0.38, 1), Parent = row })
		end
	end

	local tabs = {
		{ Id = "Battle", Text = "ต่อสู้" },
		{ Id = "Deck", Text = "จัดเด็ค" },
		{ Id = "Gacha", Text = "สุ่มกาชา" },
		{ Id = "Quests", Text = "เควสต์" },
		{ Id = "Stats", Text = "สถิติ" },
	}

	for _, tab in tabs do
		S.button({ Text = tab.Text, Max = 16, Color = S.C.Panel2, Size = UDim2.new(1, 0, 0, 44), Parent = menuF,
			OnClick = function() panels[tab.Id]() end })
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