-- StarterPlayer/StarterPlayerScripts/UIClient/BountyBoard.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local PAPER, WOOD = Color3.fromRGB(244, 226, 178), Color3.fromRGB(150, 96, 52)
local BountyBoard = {}

local function fmt(n)
	local s = tostring(math.floor(n or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

local SAMPLE = {
	{ Name = "เจ้าเป็ดสายฟาด", Emoji = "🦆", Bounty = 1500000, Crime = "ลงโล่ฝาหม้อ 40 เทิร์นติด" },
	{ Name = "ลุงกบเกลือ", Emoji = "🐸", Bounty = 820000, Crime = "เปิดเกตได้อึ 9 รอบรวด" },
	{ Name = "หินโมอายเงียบ", Emoji = "🗿", Bounty = 640000, Crime = "AFK แต่ดันชนะ" },
	{ Name = "ตัวตลกลืมตา", Emoji = "🤡", Bounty = 300000, Crime = "กด SKIP ตอนเหลือ 5 พอยต์" },
	{ Name = "แมวส้มสายปั่น", Emoji = "🐱", Bounty = 125000, Crime = "นอนทับปุ่มยอมแพ้" },
	{ Name = "ไก่ทอดซีอิ๊ว", Emoji = "🍗", Bounty = 50000, Crime = "อร่อยเกินไป" },
}

-- opts = { Entries = {{Name, Emoji, Bounty, Crime, IsMe}}, Me = {Bounty, Rank}, OnHunt = function(entry) end }
function BountyBoard.Open(parent, opts)
	opts = opts or {}
	local list = table.clone(opts.Entries or SAMPLE)
	table.sort(list, function(a, b) return (a.Bounty or 0) > (b.Bounty or 0) end)

	local panel = UIKit.panel(parent, "ประกาศจับ!!", C.Orange)
	panel.BackgroundColor3 = WOOD
	local grid = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -28, 1, opts.Me and -130 or -76),
		Position = UDim2.new(0, 14, 0, 56), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10, Parent = panel }, {
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 268), CellPadding = UDim2.fromOffset(22, 26), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18) }) })

	for rank, e in ipairs(list) do
		local holder, face = UIKit.comicBox({ Parent = grid, Color = PAPER, Tilt = math.random(-40, 40) / 10, ShadowOffset = 5, LayoutOrder = rank })
		local z = face.ZIndex
		UIKit.new("Frame", { BackgroundColor3 = C.Red, Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = CENTER, ZIndex = z + 5, Parent = holder }, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(C.Outline, 2) })
		UIKit.label({ Text = "WANTED", Font = Theme.FontAlt, Color = C.Brown, StrokeThickness = 2, Size = UDim2.fromScale(0.9, 0.15),
			Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 40, ZIndex = z + 1, Parent = face })
		local pic = UIKit.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 248, 225), Size = UDim2.fromScale(0.7, 0.36),
			Position = UDim2.fromScale(0.5, 0.2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = z + 1, Parent = face },
			{ UIKit.stroke(C.Brown, 3) })
		UIKit.label({ Text = e.Emoji or "😈", StrokeThickness = 0, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = CENTER, MaxTextSize = 80, ZIndex = z + 2, Parent = pic })
		UIKit.label({ Text = e.Name or "???", Size = UDim2.fromScale(0.92, 0.1), Position = UDim2.fromScale(0.5, 0.58),
			AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 20, ZIndex = z + 1, Parent = face })
		UIKit.label({ Text = "ค่าหัว " .. fmt(e.Bounty) .. " 🍌", Color = C.Yellow, Size = UDim2.fromScale(0.92, 0.1),
			Position = UDim2.fromScale(0.5, 0.68), AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 20, ZIndex = z + 1, Parent = face })
		UIKit.label({ Text = "ข้อหา: " .. (e.Crime or "กาวเกินพิกัด"), Color = C.Ink, StrokeThickness = 0, Wrap = true,
			Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 14, ZIndex = z + 1, Parent = face })
		if not e.IsMe then
			UIKit.button({ Parent = holder, Text = "ล่า!", Color = C.Red, Size = UDim2.fromOffset(88, 40), Position = UDim2.new(0.5, 0, 1, 4),
				AnchorPoint = CENTER, Tilt = -4, Lip = 5, MaxTextSize = 24, ZIndex = z + 6, Debounce = 1,
				OnClick = function() if opts.OnHunt then opts.OnHunt(e) end end })
		else
			UIKit.badge(holder, "นี่คุณเอง!", C.Pink, { Size = UDim2.fromOffset(110, 32), Position = UDim2.new(0.5, 0, 1, 4), AnchorPoint = CENTER, ZIndex = z + 6 })
		end
		if rank == 1 then
			FX.rarityGlow(holder, "Legend")
			UIKit.badge(holder, "เบอร์ 1", C.Yellow, { Size = UDim2.fromOffset(84, 30), Position = UDim2.new(1, 6, 0, 8), AnchorPoint = Vector2.new(1, 0.5), Tilt = 12, ZIndex = z + 6 })
		elseif rank <= 3 then
			FX.rarityGlow(holder, "Epic", { Sparkles = false })
		end
	end

	if opts.Me then
		local _, bar = UIKit.comicBox({ Parent = panel, Size = UDim2.new(1, -40, 0, 50), Position = UDim2.new(0.5, 0, 1, -16),
			AnchorPoint = Vector2.new(0.5, 1), Color = C.Pink, Tilt = -1 })
		UIKit.label({ Text = string.format("ค่าหัวคุณ: %s 🍌  (อันดับ #%s)", fmt(opts.Me.Bounty), tostring(opts.Me.Rank or "-")),
			Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, MaxTextSize = 26, Parent = bar })
	end
	return panel
end

return BountyBoard