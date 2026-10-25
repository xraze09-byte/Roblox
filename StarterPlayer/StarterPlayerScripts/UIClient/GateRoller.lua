-- StarterPlayer/StarterPlayerScripts/UIClient/GateRoller.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)
local CardView = require(Shared.UI.CardView)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local ORDER = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }
local GateRoller = {}

local function pause(t) task.wait(UIKit.dur(t)) end

local function cardVisual(parent, card)
	local holder = UIKit.new("Frame", { Name = "GateCard", BackgroundTransparency = 1, AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 1.3), Size = UDim2.fromScale(0.14, 0.3), ZIndex = 320, Parent = parent },
		{ UIKit.new("UIAspectRatioConstraint", { AspectRatio = 0.72 }) })
	local ok, view = pcall(function() return card and CardView.new(card, {}) end)
	local g = ok and view and (typeof(view) == "Instance" and view or view.Root)
	if g then
		g.AnchorPoint, g.Position, g.Size = CENTER, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
		g.Parent = holder
	else -- การ์ดที่ไม่เห็นหน้า (เช่น ฝั่งศัตรู) แสดงเป็นหลังการ์ดเครื่องหมาย ?
		local _, face = UIKit.comicBox({ Parent = holder, Color = C.Purple, ZIndex = 320 })
		UIKit.label({ Text = "?", Font = Theme.FontAlt, Color = C.Yellow, MaxTextSize = 120, ZIndex = 322, Parent = face })
	end
	return holder
end

local function sunburst(parent)
	local r = UIKit.new("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.6, 1.6), ZIndex = 301, Parent = parent }, { UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	for i = 0, 11 do
		UIKit.new("Frame", { BackgroundColor3 = C.Yellow, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.07, 0, 1, 0), Rotation = i * 15, ZIndex = 301, Parent = r })
	end
	FX.spin(r, 25)
	return r
end

local function run(parent, card, outcomeId, isMine)
	local info = Theme.GateInfo[outcomeId] or Theme.GateInfo.Normal
	local color = Theme.GateColor[outcomeId] or C.Blue

	local root = UIKit.new("Frame", { Name = "GateRoll", BackgroundColor3 = C.TableDark, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = parent })
	UIKit.tween(root, 0.25, { BackgroundTransparency = 0.25 })
	sunburst(root)
	local head = UIKit.title({ Parent = root, Text = isMine and "เกตของเรา!!" or "เกตฝั่งศัตรู!!", Color = isMine and C.Lime or C.Pink,
		Size = UDim2.fromScale(0.6, 0.12), Position = UDim2.fromScale(0.5, 0.1), AnchorPoint = CENTER, ZIndex = 330 })
	UIKit.bounceText(head, nil, 0.5)

	local portal = FX.summonCircle(root, { Size = UDim2.fromScale(0.36, 0.36), Position = UDim2.fromScale(0.5, 0.45),
		Square = true, Color = C.Purple, ZIndex = 305 })
	portal:SetActive(true)
	UIKit.sfx("PortalOpen", 0.1)

	-- 1) การ์ดลอยขึ้นมา แล้วหมุนตัวหายเข้าไปในประตู
	local cardH = cardVisual(root, card)
	UIKit.tween(cardH, 0.45, { Position = UDim2.fromScale(0.5, 0.45) }, Enum.EasingStyle.Back)
	pause(0.6)
	UIKit.tween(cardH, 0.4, { Rotation = 360 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UIKit.tween(UIKit.getScale(cardH), 0.4, { Scale = 0.1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	pause(0.4)
	cardH.Visible = false
	portal:Burst(C.Purple)

	-- 2) วงล้อสล็อต หมุนเร็วแล้วค่อยๆ ช้าลง
	local reelHolder, reel = UIKit.comicBox({ Parent = root, Size = UDim2.fromScale(0.36, 0.11), Position = UDim2.fromScale(0.5, 0.76),
		AnchorPoint = CENTER, Color = C.White, Tilt = -2, ZIndex = 330 })
	local reelLabel = UIKit.label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, MaxTextSize = 44, ZIndex = 332, Parent = reel })
	local steps, start = 16 + math.random(0, 5), math.random(1, #ORDER)
	for i = 1, steps do
		local id = (i == steps) and outcomeId or ORDER[(start + i) % #ORDER + 1]
		local gi = Theme.GateInfo[id] or info
		reel.BackgroundColor3 = Theme.GateColor[id] or C.Blue
		UIKit.bounceText(reelLabel, gi.Emoji .. " " .. gi.Text, 0.15)
		UIKit.sfx("Tick", 0.3)
		if i > steps - 3 then UIKit.shake(reelHolder, 5) end
		pause(0.04 + (i / steps) ^ 3 * 0.42)
	end

	-- 3) เผยผล
	local verdict, vColor
	if info.Kind == "Win" then
		verdict, vColor = "เปิดติด!!!", C.Yellow
		FX.flash(root, color); FX.shockwave(reelHolder, color); FX.sparkles(root, color, 30)
		UIKit.rain(root, info.Emoji, 22)
		UIKit.sfx("GateWin")
	elseif info.Kind == "Fail" then
		verdict, vColor = "เกลือ!!!", C.Orange
		FX.flash(root, C.Red); UIKit.shake(root, 22); UIKit.shake(reelHolder, 14)
		UIKit.rain(root, info.Emoji, 18)
		UIKit.sfx("GateFail")
	else
		verdict, vColor = "เฉยๆ อะ...", C.Gray
		UIKit.sfx("Boing")
		local weed = UIKit.label({ Text = "🌾", StrokeThickness = 0, Size = UDim2.fromOffset(64, 64),
			Position = UDim2.fromScale(-0.1, 0.62), ZIndex = 335, Parent = root })
		UIKit.tween(weed, 1.4, { Position = UDim2.fromScale(1.1, 0.62), Rotation = 720 }, Enum.EasingStyle.Linear)
	end
	local vFront = UIKit.title({ Parent = root, Text = verdict, Color = vColor, Size = UDim2.fromScale(0.7, 0.18),
		Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = CENTER, Tilt = info.Kind == "Fail" and 6 or -6, MaxTextSize = 110, ZIndex = 340 })
	UIKit.bounceText(vFront, nil, 0.8)
	UIKit.jelly(reelHolder, 0.35)
	pause(1.5)

	-- 4) ปิดฉาก
	UIKit.tween(root, 0.3, { BackgroundTransparency = 1 })
	for _, ch in ipairs(root:GetChildren()) do
		if ch:IsA("GuiObject") then
			UIKit.tween(UIKit.getScale(ch), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
	end
	pause(0.32)
	root:Destroy()
end

function GateRoller.Play(parent, card, outcomeId, isMine, onDone)
	if not parent then if onDone then onDone() end return end
	task.spawn(function()
		local ok, err = pcall(run, parent, card, outcomeId, isMine)
		if not ok then warn("[GateRoller]", err) end
		if onDone then onDone() end
	end)
end

return GateRoller