-- StarterPlayerScripts/UIClient/Juice.lua
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Juice = {}
Juice.Font = Enum.Font.FredokaOne

local function tw(obj, t, style, dir, props)
	local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end
Juice.tween = tw

local function scaleOf(gui)
	local s = gui:FindFirstChild("JuiceScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "JuiceScale"
		s.Parent = gui
	end
	return s
end
Juice.scaleOf = scaleOf

-- ===== ย้วยลอยไปมา (idle) — loop เดียวคุมทุกปุ่ม =====
local wobblers = {}
function Juice.wobble(gui, opts)
	opts = opts or {}
	wobblers[gui] = {
		base = gui.Position, amp = opts.Amp or 4, rot = opts.Rot or 4,
		speed = opts.Speed or 2, phase = math.random() * math.pi * 2,
	}
	gui.Destroying:Once(function() wobblers[gui] = nil end)
end
function Juice.unwobble(gui)
	local w = wobblers[gui]
	if w then gui.Position = w.base; gui.Rotation = 0 end
	wobblers[gui] = nil
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for gui, w in wobblers do
		if gui.Visible then
			gui.Position = w.base + UDim2.fromOffset(0, math.sin(t * w.speed + w.phase) * w.amp)
			gui.Rotation = math.sin(t * w.speed * 0.7 + w.phase) * w.rot
		end
	end
end)

-- ===== เด้ง / ยุบ =====
local tokens = setmetatable({}, { __mode = "k" })
local function bump(gui) local n = (tokens[gui] or 0) + 1; tokens[gui] = n; return n end

function Juice.squish(gui)
	local s = scaleOf(gui)
	s.Scale = 0.78
	tw(s, 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, { Scale = 1 })
end
function Juice.hover(gui, on)
	tw(scaleOf(gui), 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = on and 1.1 or 1 })
end
function Juice.bind(btn)
	btn.MouseEnter:Connect(function() Juice.hover(btn, true) end)
	btn.MouseLeave:Connect(function() Juice.hover(btn, false) end)
	btn.MouseButton1Down:Connect(function() Juice.squish(btn) end)
end
function Juice.popIn(gui, delay)
	local s, tok = scaleOf(gui), bump(gui)
	s.Scale = 0
	gui.Visible = true
	task.delay(delay or 0, function()
		if tokens[gui] ~= tok then return end
		tw(s, 0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	end)
end
function Juice.popOut(gui, done)
	local s, tok = scaleOf(gui), bump(gui)
	tw(s, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In, { Scale = 0 }).Completed:Once(function()
		if tokens[gui] ~= tok then return end
		gui.Visible = false
		if done then done() end
	end)
end
function Juice.slam(gui) -- การ์ดกระแทกลงสนาม
	local s = scaleOf(gui)
	s.Scale = 1.5
	tw(s, 0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, { Scale = 1 })
end
function Juice.shake(gui, power) -- ใช้ Rotation จะได้ไม่ตีกับ Layout/Wobble
	power = power or 10
	task.spawn(function()
		for i = 1, 6 do
			gui.Rotation = (i % 2 == 0 and 1 or -1) * power * (1 - i / 7)
			task.wait(0.035)
		end
		gui.Rotation = 0
	end)
end

-- ===== เอฟเฟกต์ระเบิด 2D ตรงกลาง GuiObject =====
function Juice.burstOn(target, text, color)
	local screen = target:FindFirstAncestorWhichIsA("LayerCollector")
	if not screen then return end
	color = color or Color3.fromRGB(255, 220, 60)
	local c = target.AbsolutePosition + target.AbsoluteSize / 2 - screen.AbsolutePosition

	local fx = Instance.new("Frame")
	fx.Name = "JuiceFX"
	fx.BackgroundTransparency = 1
	fx.Size = UDim2.fromOffset(0, 0)
	fx.Position = UDim2.fromOffset(c.X, c.Y)
	fx.ZIndex = 50
	fx.Parent = screen

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromOffset(20, 20)
	ring.ZIndex = 50
	ring.Parent = fx
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Color = color; rs.Thickness = 6; rs.Parent = ring
	tw(ring, 0.35, nil, nil, { Size = UDim2.fromOffset(190, 190) })
	tw(rs, 0.35, nil, nil, { Transparency = 1, Thickness = 1 })

	for i = 1, 10 do
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Size = UDim2.fromOffset(12, 12)
		p.Rotation = math.random(0, 90)
		p.BorderSizePixel = 0
		p.BackgroundColor3 = (i % 2 == 0) and color or Color3.new(1, 1, 1)
		p.ZIndex = 51
		p.Parent = fx
		local a, d = (i / 10) * math.pi * 2 + math.random() * 0.5, math.random(70, 130)
		tw(p, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			Position = UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d),
			Rotation = p.Rotation + math.random(180, 540),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 4),
		})
	end

	if text then
		local lb = Instance.new("TextLabel")
		lb.AnchorPoint = Vector2.new(0.5, 0.5)
		lb.BackgroundTransparency = 1
		lb.Size = UDim2.fromOffset(240, 70)
		lb.Font = Juice.Font
		lb.TextScaled = true
		lb.Text = text
		lb.TextColor3 = color
		lb.Rotation = math.random(-12, 12)
		lb.ZIndex = 52
		lb.Parent = fx
		local st = Instance.new("UIStroke")
		st.Thickness = 4; st.Color = Color3.new(0, 0, 0); st.Parent = lb
		local sc = scaleOf(lb); sc.Scale = 0
		tw(sc, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1.3 })
		task.delay(0.3, function()
			tw(lb, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = UDim2.fromOffset(0, -60), TextTransparency = 1 })
			tw(st, 0.4, nil, nil, { Transparency = 1 })
		end)
	end
	task.delay(0.9, function() fx:Destroy() end)
end

return Juice