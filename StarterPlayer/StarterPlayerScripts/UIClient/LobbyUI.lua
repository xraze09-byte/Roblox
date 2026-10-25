-- ไฟล์ลูกของ UIClient: LobbyUI (ModuleScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIFolder = Shared:WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local CardView = require(UIFolder:WaitForChild("CardView"))
local CardInspector = require(UIFolder:WaitForChild("CardInspector"))
local SettingsPanel = require(script.Parent:WaitForChild("SettingsPanel"))
local StatsPanel = require(script.Parent:WaitForChild("StatsPanel"))
local CardData = require(Shared:WaitForChild("CardData"))
local Decks = require(Shared:WaitForChild("Decks"))
local QueueRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Queue")
local StatsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetStats")

local player = Players.LocalPlayer
local CENTER = Vector2.new(0.5, 0.5)
local LobbyUI = {}

local QUEUE_ERR = {
	IN_MATCH = "คุณอยู่ในแมตช์อยู่แล้ว",
	BAD_LEADER = "ผู้นำไม่ถูกต้อง",
	DATA_LOADING = "กำลังโหลดข้อมูล รอแป๊บ...",
	SLOW_DOWN = "ใจเย็นๆ กดรัวไปแล้ว",
	SERVER_ERROR = "เซิร์ฟเวอร์กาว ลองใหม่อีกที",
}

local leaderIndex = 1
local searching = false
local busy = false
local ui = {}

local function comma(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

local function soon(content)
	UIKit.label({
		Text = "🚧 กำลังก่อสร้าง... ช่างกาวกำลังรีบ", Color = Theme.Color.Outline, StrokeThickness = 0,
		Size = UDim2.fromScale(0.8, 0.15), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = CENTER, Parent = content,
	})
end

local function buildCardGrid(content, ids)
	local scroller = UIKit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = content,
	})
	local grid = UIKit.new("UIGridLayout", {
		CellPadding = UDim2.new(0.02, 0, 0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller,
	})
	local function resize()
		local w = scroller.AbsoluteSize.X * 0.18
		grid.CellSize = UDim2.fromOffset(w, w * 1.4)
	end
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local cards = {}
	for _, id in ipairs(ids) do
		local data = CardData[id]
		if data then
			local card = table.clone(data)
			card.Id = id
			table.insert(cards, card)
		end
	end
	for i, card in ipairs(cards) do
		local view = CardView.new(card, {
			Size = UDim2.fromScale(1, 1), InspectList = cards, InspectIndex = i,
			OnClick = function() CardInspector.Open(card, cards, i) end,
		})
		view.Frame.LayoutOrder = i
		view.Frame.Parent = scroller
	end
end

local function allCardIds()
	local ids = {}
	for id in pairs(CardData) do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local ca, cb = CardData[a].Cost or 0, CardData[b].Cost or 0
		if ca ~= cb then return ca < cb end
		return a < b
	end)
	return ids
end

local function buildSettings(content)
	SettingsPanel.Build(content)
end

local MENU = {
	{ Text = "🃏 เด็ค", Title = "เด็คเริ่มต้น (ยังแก้ไขไม่ได้)", Color = Theme.Color.Blue,
		Build = function(c) buildCardGrid(c, Decks.Starter) end },
	{ Text = "🎰 กาชา", Title = "วงซัมมอน", Color = Theme.Color.Pink, Build = soon },
	{ Text = "📜 เควสต์", Title = "ภารกิจ", Color = Theme.Color.Green, Build = soon },
	{ Text = "📖 สมุดการ์ด", Title = "สมุดสะสมการ์ด", Color = Theme.Color.Yellow,
		Build = function(c) buildCardGrid(c, allCardIds()) end },
	{ Text = "📊 สถิติ", Title = "สถิติของคุณ", Color = Theme.Color.Blue, Stats = true,
		Build = function(c) return StatsPanel.Build(c, function() return StatsRemote:InvokeServer() end) end },
	{ Text = "⚙️ ตั้งค่า", Title = "ตั้งค่า", Color = Theme.Color.Gray, Build = buildSettings },
}

local function refreshPlay()
	if not ui.pvpBtn then return end
	local leader = CardData[Decks.Leaders[leaderIndex]]
	ui.leaderLabel.Text = ("👑 ผู้นำ: %s  🔄"):format(leader.Name)
	ui.leaderDesc.Text = leader.Desc or ""
	ui.pvpLabel.Text = searching and "❌ ยกเลิกหาคู่" or "⚔️ หาคู่ PvP"
	UIKit.setColor(ui.pvpBtn, searching and Theme.Color.Red or Theme.Color.Pink)
	ui.searchText.Visible = searching
end

local function queue(mode)
	if busy then return end
	busy = true
	task.spawn(function()
		local ok, success, result = pcall(function()
			return QueueRemote:InvokeServer(mode, Decks.Leaders[leaderIndex])
		end)
		busy = false
		if not ok then
			UIKit.toast("เน็ตกาว ลองใหม่อีกที 📶", Theme.Color.Red)
		elseif not success then
			UIKit.toast(QUEUE_ERR[result] or "เข้าคิวไม่สำเร็จ", Theme.Color.Red)
		else
			searching = result == "WAITING"
		end
		refreshPlay()
	end)
end

function LobbyUI.ResetQueue()
	searching = false
	refreshPlay()
end

function LobbyUI.Build(hud, overlay)
	-- เพชร + ชนะติดกัน
	local gemBox = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.2, 0.07), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.Blue, Parent = hud,
	}, { UIKit.corner(), UIKit.stroke() })
	local gemLabel = UIKit.label({ Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = gemBox })
	local streakLabel = UIKit.label({
		Size = UDim2.fromScale(0.2, 0.04), Position = UDim2.fromScale(0.5, 0.1), AnchorPoint = Vector2.new(0.5, 0), Parent = hud,
	})
	local function refreshStats()
		gemLabel.Text = "💎 " .. comma(player:GetAttribute("Gems") or 0)
		local streak = player:GetAttribute("Streak") or 0
		streakLabel.Text = streak > 0 and ("🔥 ชนะติด %d (ค่าหัว %d)"):format(streak, streak * 10) or ""
	end
	player:GetAttributeChangedSignal("Gems"):Connect(function()
		refreshStats()
		UIKit.jelly(gemBox, 0.2)
	end)
	player:GetAttributeChangedSignal("Streak"):Connect(refreshStats)
	refreshStats()

	-- เมนูล่าง (dock)
	local menu = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.13), Position = UDim2.fromScale(0.5, 0.97), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Color.Outline, BackgroundTransparency = 0.35, Parent = hud,
	}, {
		UIKit.corner(UDim.new(0.3, 0)),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0) }),
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromScale(0.15, 1), CellPadding = UDim2.fromScale(0.012, 0),
			FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	for i, item in ipairs(MENU) do
		local panel, panelApi
		local btn = UIKit.button({
			Text = item.Text, Color = item.Color, Size = UDim2.fromScale(1, 1), Parent = menu,
			OnClick = function()
				if not panel then
					panel = UIKit.panel(overlay, item.Title, item.Color)
					panelApi = item.Build(panel.Content)
				elseif item.Stats and panelApi then
					panelApi.Refresh()
				end
				panel.Open()
			end,
		})
		btn.LayoutOrder = i
	end

	-- ส่วนเริ่มเล่น
	local play = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.42, 0.26), Position = UDim2.fromScale(0.5, 0.83), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1, Parent = hud,
	})
	ui.searchText = UIKit.label({
		Text = "⏳ กำลังหาคู่... (รอคนอื่นกดหาคู่)", Size = UDim2.fromScale(1, 0.14),
		Position = UDim2.fromScale(0, -0.17), Parent = play,
	})
	ui.leaderBtn, ui.leaderLabel = UIKit.button({
		Color = Theme.Color.Panel, Size = UDim2.fromScale(1, 0.24), Parent = play,
		OnClick = function()
			if searching then UIKit.toast("ยกเลิกหาคู่ก่อน แล้วค่อยเปลี่ยนผู้นำ") return end
			leaderIndex = leaderIndex % #Decks.Leaders + 1
			refreshPlay()
		end,
	})
	ui.leaderDesc = UIKit.label({ Font = Theme.FontBody, Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.27), Parent = play })
	local peek = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = ui.leaderDesc })
	peek.Activated:Connect(function()
		local leaders = {}
		for i, id in ipairs(Decks.Leaders) do
			local c = table.clone(CardData[id])
			c.Id = id
			leaders[i] = c
		end
		CardInspector.Open(leaders[leaderIndex], leaders, leaderIndex)
	end)
	UIKit.button({
		Text = "🤖 ซ้อมกับบอท", Color = Theme.Color.Green, Size = UDim2.fromScale(0.48, 0.42),
		Position = UDim2.fromScale(0, 0.45), Parent = play, OnClick = function() queue("Bot") end,
	})
	ui.pvpBtn, ui.pvpLabel = UIKit.button({
		Color = Theme.Color.Pink, Size = UDim2.fromScale(0.48, 0.42), Position = UDim2.fromScale(0.52, 0.45), Parent = play,
		OnClick = function() queue(searching and "Cancel" or "PvP") end,
	})
	refreshPlay()
end

return LobbyUI
