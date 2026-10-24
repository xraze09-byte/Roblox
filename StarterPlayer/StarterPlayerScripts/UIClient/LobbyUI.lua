-- ไฟล์ลูกของ UIClient: LobbyUI (ModuleScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIFolder = Shared:WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local CardView = require(UIFolder:WaitForChild("CardView"))
local CardData = require(Shared:WaitForChild("CardData"))

local player = Players.LocalPlayer
local CENTER = Vector2.new(0.5, 0.5)
local LobbyUI = {}

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

local function buildCollection(content)
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

	local ids = {}
	for id in pairs(CardData) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return (CardData[a].Cost or 0) < (CardData[b].Cost or 0) end)
	for i, id in ipairs(ids) do
		local card = table.clone(CardData[id])
		card.Id = id
		local view = CardView.new(card, { Size = UDim2.fromScale(1, 1) })
		view.Frame.LayoutOrder = i
		view.Frame.Parent = scroller
	end
end

local function buildSettings(content)
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0.04, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = content,
	})
	local items = {
		{ Key = "Voice", Text = "เสียงพากย์กาวๆ" },
		{ Key = "VFX", Text = "เอฟเฟกต์เวอร์วัง" },
		{ Key = "Tomato", Text = "ให้คนดูปามะเขือเทศใส่จอ" },
	}
	for i, item in ipairs(items) do
		local btn, label
		local function refresh()
			local on = UIKit.Settings[item.Key]
			label.Text = item.Text .. (on and " : เปิด ✅" or " : ปิด ❌")
			UIKit.setColor(btn, on and Theme.Color.Green or Theme.Color.Gray)
		end
		btn, label = UIKit.button({
			Size = UDim2.fromScale(0.8, 0.15), Parent = content,
			OnClick = function()
				UIKit.Settings[item.Key] = not UIKit.Settings[item.Key]
				refresh()
			end,
		})
		btn.LayoutOrder = i
		refresh()
	end
end

local MENU = {
	{ Text = "🃏 เด็ค",      Title = "จัดเด็ค",       Color = Theme.Color.Blue,   Build = soon },
	{ Text = "🎰 กาชา",      Title = "วงซัมมอน",      Color = Theme.Color.Pink,   Build = soon },
	{ Text = "📜 เควสต์",    Title = "ภารกิจ",        Color = Theme.Color.Green,  Build = soon },
	{ Text = "📖 สมุดการ์ด", Title = "สมุดสะสมการ์ด", Color = Theme.Color.Yellow, Build = buildCollection },
	{ Text = "⚙️ ตั้งค่า",    Title = "ตั้งค่า",        Color = Theme.Color.Gray,   Build = buildSettings },
}

function LobbyUI.Build(hud, overlay)
	-- ตัวนับเพชร (อยู่กลางบน เพื่อไม่ให้ทับปุ่มเมนูของ Roblox)
	local gemBox = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.2, 0.07), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.Blue, Parent = hud,
	}, { UIKit.corner(), UIKit.stroke() })
	local gemLabel = UIKit.label({ Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = gemBox })
	local function refreshGems()
		gemLabel.Text = "💎 " .. comma(player:GetAttribute("Gems") or 0)
	end
	player:GetAttributeChangedSignal("Gems"):Connect(function()
		refreshGems()
		UIKit.jelly(gemBox, 0.2)
	end)
	refreshGems()

	-- เมนูขวามือ
	local menu = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.15, 0.62), Position = UDim2.fromScale(0.98, 0.55), AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1, Parent = hud,
	}, {
		UIKit.new("UIListLayout", {
			Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	for i, item in ipairs(MENU) do
		local panel
		local btn = UIKit.button({
			Text = item.Text, Color = item.Color, Size = UDim2.fromScale(1, 0.18), Parent = menu,
			OnClick = function()
				if not panel then -- สร้างหน้าต่างตอนเปิดครั้งแรก
					panel = UIKit.panel(overlay, item.Title, item.Color)
					item.Build(panel.Content)
				end
				panel.Open()
			end,
		})
		btn.LayoutOrder = i
	end
end

return LobbyUI