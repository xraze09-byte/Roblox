-- ReplicatedStorage/Shared/UI/FX.lua  (ใช้ฝั่ง Client เท่านั้น)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UIKit = require(script.Parent.UIKit)
local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local FX = {}

-- ตัวหมุนรวม: RenderStepped เส้นเดียวทั้งเกม
local spinners, spinConn = {}, nil
function FX.spin(inst, degPerSec)
	spinners[inst] = degPerSec or 90
	if not spinConn then
		spinConn = RunService.RenderStepped:Connect(function(dt)
			local any = false
			for i, sp in pairs(spinners) do
				if i.Parent then any = true; i.Rotation = (i.Rotation + sp * dt) % 360 else spinners[i] = nil end
			end
			if not any then spinConn:Disconnect(); spinConn = nil end
		end)
	end
	return function() spinners[inst] = nil end
end

local function diamond(parent, color, size, z)
	return UIKit.new("Frame", { Name = "Spark", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = CENTER, Size = size,
		Rotation = 45, ZIndex = z or 70, Parent = parent }, { UIKit.new("UIStroke", { Color = C.White, Thickness = 1.5 }) })
end

function FX.sparkles(parent, color, count, origin)
	if not parent or not UIKit.effectsOn() then return end
	origin = origin or Vector2.new(0.5, 0.5)
	for i = 1, count or 12 do
		local sz = math.random(6, 16)
		local d = diamond(parent, (i % 3 == 0) and C.White or (color or C.Yellow), UDim2.fromOffset(sz, sz))
		d.Position = UDim2.fromScale(origin.X, origin.Y)
		local a, dist, dur = math.random() * math.pi * 2, 0.25 + math.random() * 0.45, 0.5 + math.random() * 0.4
		UIKit.tween(d, dur, { Position = UDim2.fromScale(origin.X + math.cos(a) * dist, origin.Y + math.sin(a) * dist),
			Rotation = 45 + math.random(-180, 180), Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
		Debris:AddItem(d, UIKit.dur(dur) + 0.1)
	end
end

function FX.ambientSparkles(parent, color, every)
	color = color or C.Yellow
	local alive = true
	task.spawn(function()
		while alive and parent.Parent do
			if UIKit.effectsOn() then
				local sz = math.random(5, 12)
				local d = diamond(parent, math.random() < 0.4 and C.White or color, UDim2.fromOffset(sz, sz), 30)
				d.Position = UDim2.fromScale(math.random(), math.random())
				local s = UIKit.getScale(d)
				s.Scale = 0
				UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				task.delay(UIKit.dur(0.4), function() if d.Parent then UIKit.tween(s, 0.35, { Scale = 0 }) end end)
				Debris:AddItem(d, UIKit.dur(0.8) + 0.2)
			end
			task.wait(every or 0.25)
		end
	end)
	return function() alive = false end
end

function FX.flash(parent, color)
	local f = UIKit.new("Frame", { BackgroundColor3 = color or C.White, BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 1), ZIndex = 400, Parent = parent })
	UIKit.tween(f, 0.35, { BackgroundTransparency = 1 })
	Debris:AddItem(f, UIKit.dur(0.4))
end

function FX.shockwave(parent, color)
	local r = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4), ZIndex = 60, Parent = parent }, { UIKit.corner(UDim.new(1, 0)) })
	local st = UIKit.new("UIStroke", { Color = color or C.White, Thickness = 10, Parent = r })
	UIKit.tween(r, 0.5, { Size = UDim2.fromScale(1.7, 1.7) }, Enum.EasingStyle.Quart)
	UIKit.tween(st, 0.5, { Thickness = 0, Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(r, UIKit.dur(0.55))
end

-- กรอบเส้นวาดมือ 2 ชั้น + line boil (เส้นสั่นแบบการ์ตูนวาดมือ)
local boilers = setmetatable({}, { __mode = "k" })
task.spawn(function()
	while true do
		task.wait(0.16)
		if UIKit.effectsOn() then
			for h in pairs(boilers) do
				if h.Parent then
					for i, ch in ipairs(h:GetChildren()) do ch.Rotation = (i == 1 and -0.8 or 0.7) + (math.random() - 0.5) * 0.9 end
				else boilers[h] = nil end
			end
		end
	end
end)

function FX.sketchFrame(gui, color, z)
	local old = gui:FindFirstChild("Sketch")
	if old then old:Destroy() end
	local h = UIKit.new("Frame", { Name = "Sketch", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 45, Parent = gui })
	for i, cfg in ipairs({ { r = -0.8, x = -2, y = 1, t = 2.5 }, { r = 0.7, x = 2, y = -1, t = 1.5 } }) do
		UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.new(0.5, cfg.x, 0.5, cfg.y),
			Size = UDim2.new(1, 2 * i, 1, -2 * i), Rotation = cfg.r, ZIndex = h.ZIndex, Parent = h }, {
			UIKit.corner(Theme.Radius - i * 2),
			UIKit.new("UIStroke", { Color = color or C.Outline, Thickness = cfg.t, Transparency = 0.15 * i }),
		})
	end
	boilers[h] = true
	return h
end

-- ออร่าตามเทียร์: T2 ขอบสี, T3+ ขอบรุ้งหมุน, T4+ ประกายวิบวับ
local ambient = setmetatable({}, { __mode = "k" })
function FX.rarityGlow(gui, rarity, opts)
	opts = opts or {}
	local old = gui:FindFirstChild("RarityGlow")
	if old then old:Destroy() end
	if ambient[gui] then ambient[gui](); ambient[gui] = nil end
	local tier = Theme.RarityTier[rarity] or 1
	if tier < 2 then return end
	local ring = UIKit.new("Frame", { Name = "RarityGlow", BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8), ZIndex = 50, Parent = gui }, { UIKit.corner(Theme.Radius + 4) })
	local st = UIKit.new("UIStroke", { Thickness = 2 + tier, Color = C.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
	local g = UIKit.new("UIGradient", { Color = Theme.RarityGlow[rarity] or Theme.RarityGlow.Rare, Parent = st })
	if tier >= 3 then
		FX.spin(g, 60 * tier)
		TweenService:Create(st, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.45 }):Play()
	end
	if tier >= 4 and opts.Sparkles ~= false then
		ambient[gui] = FX.ambientSparkles(gui, Theme.Rarity[rarity], tier == 5 and 0.12 or 0.22)
	end
	return ring
end

-- วงซัมมอนเจม (วงกลม/วงรีก็ได้) คืน { Root, SetActive, Burst, Destroy }
function FX.summonCircle(parent, p)
	p = p or {}
	local color = p.Color or C.Pink
	local root = UIKit.new("Frame", { Name = "SummonCircle", BackgroundTransparency = 1, AnchorPoint = CENTER,
		Position = p.Position or UDim2.fromScale(0.5, 0.5), Size = p.Size or UDim2.fromScale(0.5, 0.5), ZIndex = p.ZIndex or 1, Parent = parent })
	if p.Square then UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = root }) end
	local z = root.ZIndex
	local function ellipse(name, sc, thick, seq, speed, fillT)
		local e = UIKit.new("Frame", { Name = name, BackgroundColor3 = color, BackgroundTransparency = fillT or 1, AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sc, sc), ZIndex = z, Parent = root }, { UIKit.corner(UDim.new(1, 0)) })
		local st
		if thick then
			st = UIKit.new("UIStroke", { Thickness = thick, Color = C.White, Parent = e })
			FX.spin(UIKit.new("UIGradient", { Color = seq, Parent = st }), speed)
		end
		return e, st
	end
	local glow = ellipse("Glow", 0.95, nil, nil, nil, 0.8)
	local _, outer = ellipse("Outer", 1, 6, Theme.seq(color, C.White, C.Blue, color), 140)
	ellipse("Inner", 0.72, 3, Theme.seq(C.Yellow, color, C.White, C.Yellow), -220)

	local star = UIKit.new("Frame", { Name = "Star", BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5), ZIndex = z, Parent = root }, { UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	for _, r in ipairs({ 0, 45 }) do
		UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72),
			Rotation = r, ZIndex = z, Parent = star }, { UIKit.new("UIStroke", { Color = color, Thickness = 2.5, Transparency = 0.2 }) })
	end
	FX.spin(star, -40)

	local gems, palette = {}, { C.Pink, C.Blue, C.Lime, C.Yellow }
	for i = 1, 8 do
		gems[i] = UIKit.new("Frame", { Name = "Gem", BackgroundColor3 = palette[(i - 1) % 4 + 1], BorderSizePixel = 0, AnchorPoint = CENTER,
			Size = UDim2.fromScale(0.12, 0.12), Rotation = 45, ZIndex = z, Parent = root },
			{ UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }), UIKit.stroke(C.Outline, 2) })
	end
	local t0 = os.clock()
	local orbit = RunService.RenderStepped:Connect(function()
		local t = UIKit.effectsOn() and (os.clock() - t0) * 1.2 or 0
		for i, g in ipairs(gems) do
			local a = t + (i - 1) / #gems * math.pi * 2
			g.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5)
		end
	end)
	root.Destroying:Connect(function() orbit:Disconnect() end)

	local obj = { Root = root }
	function obj:SetActive(on)
		UIKit.tween(glow, 0.3, { BackgroundTransparency = on and 0.5 or 0.85 })
		UIKit.tween(outer, 0.3, { Transparency = on and 0 or 0.45 })
	end
	function obj:Burst(c)
		c = c or color
		UIKit.sfx("Summon", 0.1)
		local s = UIKit.getScale(root)
		s.Scale = 1.25
		UIKit.tween(s, 0.6, { Scale = 1 }, Enum.EasingStyle.Elastic)
		glow.BackgroundColor3, glow.BackgroundTransparency = c, 0.1
		UIKit.tween(glow, 0.6, { BackgroundTransparency = 0.75 })
		FX.shockwave(root, c)
		FX.sparkles(root, c, 18)
	end
	function obj:Destroy() root:Destroy() end
	obj:SetActive(false)
	return obj
end

-- ไฟลุก (ใช้ที่นาฬิกา) ตั้งความแรง 0..1
function FX.flames(parent, z)
	local root = UIKit.new("Frame", { Name = "Flames", BackgroundTransparency = 1, Size = UDim2.fromScale(1.3, 1.6),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.05), ZIndex = z or 1, Parent = parent })
	local obj = { Root = root, Intensity = 0 }
	task.spawn(function()
		while root.Parent do
			local k = obj.Intensity
			if k > 0 and UIKit.effectsOn() then
				local sz = math.random(14, 26) * (0.7 + k * 0.6)
				local f = UIKit.new("Frame", { BackgroundColor3 = C.Yellow, BorderSizePixel = 0, AnchorPoint = CENTER, Size = UDim2.fromOffset(sz, sz),
					Position = UDim2.new(math.random() * 0.8 + 0.1, 0, 1, 0), Rotation = 45, ZIndex = root.ZIndex, Parent = root }, {
					UIKit.corner(UDim.new(0.3, 0)),
					UIKit.new("UIGradient", { Rotation = -45, Color = Theme.seq(C.White, C.Yellow, C.Orange, C.Red) }),
				})
				local d = 0.5 + math.random() * 0.35
				UIKit.tween(f, d, { Position = f.Position - UDim2.fromScale((math.random() - 0.5) * 0.15, 0.55 + k * 0.4),
					Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 0.6, Rotation = 45 + math.random(-60, 60) })
				Debris:AddItem(f, UIKit.dur(d) + 0.05)
				task.wait(0.09 - k * 0.06)
			else
				task.wait(0.2)
			end
		end
	end)
	function obj:SetIntensity(x) self.Intensity = math.clamp(x, 0, 1) end
	function obj:Destroy() root:Destroy() end
	return obj
end

return FX