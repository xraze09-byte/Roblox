-- StarterPlayer/StarterPlayerScripts/UIClient/TowerUI.lua
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local TowerUI = {}
local FLOOR_H = 124

local function sampleFloors()
	local names = { "ห้องเก็บถุงเท้า", "ชั้นแมวนอนทับคีย์บอร์ด", "โถงเสียงไวไฟหลุด", "ห้องรอคิวห้องน้ำ",
		"ลานกาวลอยฟ้า", "ห้องประชุมที่ควรเป็นอีเมล", "ครัวมาม่าตอนตีสาม", "ระเบียงคนลืมรหัส" }
	local bosses = { "🦆", "🐸", "🗿", "🤡" }
	local floors = {}
	for i = 1, 20 do
		local boss = i % 5 == 0
		floors[i] = { Name = names[(i - 1) % #names + 1], Boss = boss and bosses[i // 5] or nil,
			Reward = boss and ("💎 x" .. i * 10) or ("🪙 x" .. i * 50) }
	end
	return floors
end

local function loop(inst, t, props)
	TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props):Play()
end

-- opts = { Floors = {{Name, Boss, Reward}}, Current = ชั้นที่ยังไม่ผ่าน, OnChallenge = function(i, floor) end }
function TowerUI.Open(parent, opts)
	opts = opts or {}
	local floors = opts.Floors or sampleFloors()
	local n, current = #floors, opts.Current or 1
	local panel = UIKit.panel(parent, "หอคอยแห่งความกาว", C.Purple)

	local scroll = UIKit.new("ScrollingFrame", { BackgroundColor3 = C.Blue, BorderSizePixel = 0, Size = UDim2.new(1, -28, 1, -70),
		Position = UDim2.new(0, 14, 0, 56), CanvasSize = UDim2.fromOffset(0, n * FLOOR_H + 80), ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Yellow, Parent = panel }, {
		UIKit.corner(12), UIKit.stroke(C.Outline, 3),
		UIKit.new("UIGradient", { Rotation = 90, Color = Theme.seq(C.Purple, C.Pink, C.Blue) }) })
	UIKit.new("Frame", { Name = "Rope", BackgroundColor3 = C.Brown, BorderSizePixel = 0, Size = UDim2.new(0, 14, 0, n * FLOOR_H),
		Position = UDim2.new(0.5, -7, 0, 40), ZIndex = 1, Parent = scroll }, { UIKit.stroke(C.Outline, 2) })

	for i = 1, n do
		local f = floors[i]
		local y, boss = (n - i) * FLOOR_H + 40, f.Boss ~= nil
		local state = i < current and "Clear" or i == current and "Now" or "Lock"
		local color = state == "Clear" and C.Green or state == "Now" and C.Yellow or C.Gray
		if boss and state ~= "Clear" then color = state == "Now" and C.Red or C.Gray:Lerp(C.Red, 0.35) end

		local holder, face = UIKit.comicBox({ Parent = scroll, Size = UDim2.new(boss and 0.66 or 0.52, 0, 0, FLOOR_H - 28),
			Position = UDim2.new(i % 2 == 0 and 0.58 or 0.42, 0, 0, y), AnchorPoint = Vector2.new(0.5, 0), Color = color,
			Tilt = (i % 2 == 0) and 2 or -2, ZIndex = 3 })
		local z = face.ZIndex
		UIKit.label({ Text = "ชั้น " .. i, Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.04, 0.08),
			AlignX = Enum.TextXAlignment.Left, MaxTextSize = 30, ZIndex = z + 1, Parent = face })
		UIKit.label({ Text = f.Name, Size = UDim2.fromScale(0.62, 0.3), Position = UDim2.fromScale(0.04, 0.5),
			AlignX = Enum.TextXAlignment.Left, MaxTextSize = 20, ZIndex = z + 1, Parent = face })
		UIKit.label({ Text = "รางวัล " .. tostring(f.Reward or "-"), Color = C.Yellow, Size = UDim2.fromScale(0.5, 0.22),
			Position = UDim2.fromScale(0.04, 0.78), AlignX = Enum.TextXAlignment.Left, MaxTextSize = 16, ZIndex = z + 1, Parent = face })

		if boss then
			local b = UIKit.label({ Text = f.Boss, StrokeThickness = 0, Size = UDim2.fromOffset(84, 84), Position = UDim2.new(1, -10, 0.5, -10),
				AnchorPoint = Vector2.new(1, 0.5), Tilt = -14, MaxTextSize = 80, ZIndex = z + 2, Parent = holder })
			loop(b, 0.45, { Rotation = 14 })
			loop(b, 0.7, { Position = b.Position - UDim2.fromOffset(0, 12) })
			UIKit.badge(holder, "BOSS!", C.Red, { Size = UDim2.fromOffset(86, 30), Position = UDim2.new(0.5, 0, 0, -8),
				AnchorPoint = CENTER, Tilt = -6, ZIndex = z + 3 })
		end

		if state == "Now" then
			local btn = UIKit.button({ Parent = holder, Text = "ปีน!!", Color = C.Pink, Size = UDim2.fromOffset(110, 52),
				Position = UDim2.new(1, boss and -100 or -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Tilt = 4, ZIndex = z + 4,
				Debounce = 1, OnClick = function() if opts.OnChallenge then opts.OnChallenge(i, f) end end })
			loop(UIKit.getScale(btn), 0.5, { Scale = 1.08 })
			FX.rarityGlow(holder, boss and "Mystic" or "Legend")
		else
			UIKit.label({ Text = state == "Clear" and "✔" or "🔒", StrokeThickness = state == "Clear" and 3 or 0,
				Color = C.White, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, boss and -100 or -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5), MaxTextSize = 40, ZIndex = z + 2, Parent = holder })
		end
	end

	task.defer(function()
		scroll.CanvasPosition = Vector2.new(0, math.max(0, (n - current) * FLOOR_H - scroll.AbsoluteSize.Y / 2 + 100))
	end)
	return panel
end

return TowerUI