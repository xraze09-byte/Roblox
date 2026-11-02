-- UIClient/MenuKit.lua
-- Big centered menu windows (Play, Profile, Settings) + small UI helpers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local Kit = {}

local C = {
	Red = Color3.fromRGB(255, 70, 100), Pink = Color3.fromRGB(255, 90, 200), Lime = Color3.fromRGB(150, 255, 90),
	Orange = Color3.fromRGB(255, 150, 40), Yellow = Color3.fromRGB(255, 220, 60), Blue = Color3.fromRGB(80, 170, 255),
	Purple = Color3.fromRGB(150, 90, 255), Panel = Color3.fromRGB(58, 24, 130), Ink = Color3.fromRGB(25, 10, 45),
	White = Color3.new(1, 1, 1), Gray = Color3.fromRGB(150, 150, 170), Dark = Color3.fromRGB(38, 14, 88),
}
Kit.C = C

function Kit.corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0, 12); c.Parent = p
	return c
end

function Kit.stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or C.Ink; s.Thickness = th or 3; s.Parent = p
	return s
end

function Kit.label(parent, text, color, props, maxSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Juice.Font
	l.TextScaled = true
	l.TextColor3 = color or C.White
	l.Text = text or ""
	l.Size = UDim2.new(1, 0, 0, 24)
	for k, v in props or {} do l[k] = v end
	local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = maxSize or 26; tc.Parent = l
	l.Parent = parent
	return l
end

function Kit.button(parent, text, color, onClick, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color or C.Yellow
	b.Font = Juice.Font
	b.TextScaled = true
	b.TextColor3 = C.Ink
	b.Text = text or ""
	b.Size = UDim2.new(1, 0, 0, 44)
	for k, v in props or {} do b[k] = v end
	b.Parent = parent
	Kit.corner(b); Kit.stroke(b, C.Ink, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 24; tc.Parent = b
	Juice.bind(b)
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Disabled") then return end
			onClick(b)
		end)
	end
	return b
end

function Kit.setDisabled(b, off)
	b:SetAttribute("Disabled", off and true or nil)
	b.BackgroundTransparency = off and 0.55 or 0
	b.TextTransparency = off and 0.4 or 0
end

function Kit.clear(f)
	for _, ch in f:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end

function Kit.scroll(parent, props)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do s[k] = v end
	s.Parent = parent
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = s
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 4), UDim.new(0, 10), UDim.new(0, 4)
	pad.Parent = s
	return s
end

-- items = { {Id, Text, Color, Locked} }  -> returns bar, select(id)
function Kit.tabs(parent, items, onSelect)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 38)
	bar.Parent = parent
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.Padding = UDim.new(0, 6)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = bar

	local buttons = {}
	local function select(id)
		for _, it in items do
			local b = buttons[it.Id]
			local on = it.Id == id
			b.BackgroundColor3 = on and (it.Color or C.Yellow) or C.Dark
			b.TextColor3 = on and C.Ink or C.White
		end
		onSelect(id)
	end
	for i, it in items do
		local b = Kit.button(bar, it.Locked and ("🔒" .. it.Text) or it.Text, C.Dark, function()
			select(it.Id)
		end, { Size = UDim2.new(1 / #items, -6, 1, 0), LayoutOrder = i, TextColor3 = C.White })
		if it.Locked then Kit.setDisabled(b, true) end
		buttons[it.Id] = b
	end
	return bar, select
end

-- ===== Modal window =====
local gui, current

local function getGui()
	if gui and gui.Parent then return gui end
	gui = Instance.new("ScreenGui")
	gui.Name = "MenuModal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Kit.isOpen() return current ~= nil end

function Kit.close()
	local w = current
	if not w then return end
	current = nil
	if w.OnClose then pcall(w.OnClose) end
	w.Root:Destroy()
end

-- opts: Title, Color, MaxSize (Vector2), From (Vector2 screen point -> "grow" animation), OnClose
function Kit.open(opts)
	Kit.close()
	local g = getGui()

	local root = Instance.new("TextButton")
	root.Name = "Backdrop"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = g
	root.Activated:Connect(Kit.close)

	-- TextButton so taps inside the window don't fall through to the backdrop
	local win = Instance.new("TextButton")
	win.Name = "Window"
	win.Text = ""
	win.AutoButtonColor = false
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromScale(0.9, 0.84)
	win.BackgroundColor3 = C.Panel
	win.Parent = root
	Kit.corner(win, UDim.new(0, 18)); Kit.stroke(win, opts.Color or C.Yellow, 4)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = opts.MaxSize or Vector2.new(880, 540)
	lim.Parent = win

	local title = Kit.label(win, opts.Title or "", opts.Color or C.Yellow, {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 30)

	local close = Instance.new("TextButton")
	close.AutoButtonColor = false
	close.Text = ""
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = C.Red
	close.Parent = win
	Kit.corner(close, UDim.new(1, 0)); Kit.stroke(close, C.Ink, 2)
	Icons.image("Close", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
	}, close)
	Juice.bind(close)
	close.Activated:Connect(Kit.close)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, 50)
	body.Size = UDim2.new(1, -24, 1, -62)
	body.Parent = win

	if opts.From then
		-- "grow" out of the tapped point (sketch: other player's profile)
		local sc = Instance.new("UIScale"); sc.Scale = 0.05; sc.Parent = win
		win.Position = UDim2.fromOffset(opts.From.X, opts.From.Y)
		local ti = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(win, ti, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		TweenService:Create(sc, ti, { Scale = 1 }):Play()
	else
		Juice.popIn(win)
	end

	current = { Root = root, Win = win, Body = body, Title = title, OnClose = opts.OnClose }
	return current
end

return Kit