-- StarterPlayerScripts/UIClient/SettingsPanel (ModuleScript)
-- ใส่ลงใน UIKit.panel(...).Content ได้ทั้งล็อบบี้และในแมตช์
local UI = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local UIKit = require(UI:WaitForChild("UIKit"))
local Settings = require(UI:WaitForChild("Settings"))

local SettingsPanel = {}
local SPEEDS = { 0.5, 1, 1.5, 2 }
local ROW_H = 58

local function pill(parent, text, x, width, color)
	return UIKit.new("TextButton", {
		Text = text, Font = Theme.Font, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color, Size = UDim2.new(width, 0, 0.7, 0),
		Position = UDim2.fromScale(x, 0.5), AnchorPoint = Vector2.new(1, 0.5), Parent = parent,
	}, {
		UIKit.corner(UDim.new(0.5, 0)),
		UIKit.new("UIStroke", { Thickness = 2, Color = Theme.Color.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
	})
end

local function row(list, order, title)
	local r = UIKit.new("Frame", {
		Name = "Row", LayoutOrder = order, Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Parent = list,
	}, { UIKit.corner(UDim.new(0.3, 0)) })
	UIKit.new("TextLabel", {
		Text = title, Font = Theme.FontBody, TextScaled = true, TextColor3 = Theme.Color.Outline,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.55, 0.5), Position = UDim2.fromScale(0.04, 0.5),
		AnchorPoint = Vector2.new(0, 0.5), Parent = r,
	})
	return r
end

local function toggle(list, order, title, key)
	local b = pill(row(list, order, title), "", 0.96, 0.22, Theme.Color.Green)
	local function refresh()
		local on = Settings.Get(key)
		b.Text = on and "เปิด" or "ปิด"
		b.BackgroundColor3 = on and Theme.Color.Green or Theme.Color.Gray
	end
	b.Activated:Connect(function() Settings.Set(key, not Settings.Get(key)) refresh() UIKit.sfx("Click") end)
	refresh()
end

-- opts.OnSurrender = ฟังก์ชันยอมแพ้ (ใส่เฉพาะในแมตช์)
-- คืนค่า ScrollingFrame กลับไป ถ้าจะใส่ของเพิ่มให้ตั้ง LayoutOrder ตั้งแต่ 20 ขึ้นไป
function SettingsPanel.Build(content, opts)
	opts = opts or {}
	local list = UIKit.new("ScrollingFrame", {
		Name = "SettingsList", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content,
	}, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4) }),
	})

	-- เสียง: − 70% +
	local vr = row(list, 1, "🔊 เสียงเอฟเฟกต์")
	local plus = pill(vr, "+", 0.96, 0.09, Theme.Color.Blue)
	local value = UIKit.new("TextLabel", {
		Font = Theme.Font, TextScaled = true, TextColor3 = Theme.Color.Outline, BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.14, 0.5), Position = UDim2.fromScale(0.855, 0.5), AnchorPoint = Vector2.new(1, 0.5), Parent = vr,
	})
	local minus = pill(vr, "−", 0.705, 0.09, Theme.Color.Blue)
	local function refreshVol() value.Text = math.floor(Settings.Get("Sfx") * 100 + 0.5) .. "%" end
	local function step(d)
		Settings.Set("Sfx", math.clamp((math.floor(Settings.Get("Sfx") * 10 + 0.5) + d) / 10, 0, 1))
		refreshVol() UIKit.sfx("Click")
	end
	plus.Activated:Connect(function() step(1) end)
	minus.Activated:Connect(function() step(-1) end)
	refreshVol()

	-- ความเร็วแอนิเมชัน: กดวน 0.5x → 1x → 1.5x → 2x
	local sb = pill(row(list, 2, "⏩ ความเร็วแอนิเมชัน"), "", 0.96, 0.22, Theme.Color.Blue)
	local function refreshSpeed() sb.Text = Settings.Get("AnimSpeed") .. "x" end
	sb.Activated:Connect(function()
		local i = table.find(SPEEDS, Settings.Get("AnimSpeed")) or 2
		Settings.Set("AnimSpeed", SPEEDS[i % #SPEEDS + 1])
		refreshSpeed() UIKit.sfx("Click")
	end)
	refreshSpeed()

	toggle(list, 3, "✨ แสงและประกาย", "Effects")
	toggle(list, 4, "💥 ตัวเลขลอย", "DamageNumbers")
	toggle(list, 5, "🎯 ลูกศรเล็งเป้า", "TargetArrow")

	if opts.OnSurrender then
		local b = pill(row(list, 10, "🏳️ ยอมแพ้แมตช์นี้"), "ยอมแพ้", 0.96, 0.32, Theme.Color.Red)
		local armed = false
		b.Activated:Connect(function()
			if not armed then -- กดสองครั้งเพื่อกันกดพลาด
				armed = true
				b.Text = "กดอีกครั้ง"
				task.delay(3, function() if armed then armed = false b.Text = "ยอมแพ้" end end)
				return
			end
			armed = false
			b.Text = "ยอมแพ้"
			opts.OnSurrender()
		end)
	end
	return list
end

return SettingsPanel