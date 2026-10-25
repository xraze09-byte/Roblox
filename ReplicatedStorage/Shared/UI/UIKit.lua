-- ReplicatedStorage/Shared/UI/UIKit.lua
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Theme = require(script.Parent.Theme)
local okS, Settings = pcall(require, script.Parent.Settings)
if not okS then Settings = nil end

local UIKit = {}
UIKit.Theme = Theme
-- คงไว้ให้โค้ดเดิมใช้ต่อ: CardView อ่าน UIKit.Settings.VFX, init.client ตั้ง UIKit.toastParent
UIKit.Settings = { Voice = true, VFX = true, Tomato = true }
UIKit.toastParent = nil
if Settings and Settings.Changed then
	UIKit.Settings.VFX = Settings.Get("Effects") ~= false
	Settings.Changed:Connect(function(k, v) if k == "Effects" then UIKit.Settings.VFX = v ~= false end end)
end
local C = Theme.Color
local CENTER = Vector2.new(0.5, 0.5)
UIKit.CENTER = CENTER

local function setting(key, default)
	if Settings and Settings.Get then
		local ok, v = pcall(Settings.Get, key)
		if ok and v ~= nil then return v end
	end
	return default
end
UIKit.setting = setting
function UIKit.effectsOn() return setting("Effects", true) ~= false end
function UIKit.dur(t) return t / math.max(tonumber(setting("AnimSpeed", 1)) or 1, 0.1) end

function UIKit.fontFor(text, preferred)
	if type(text) == "string" and (text:find("\224\184") or text:find("\224\185")) then return Theme.FontThai end
	return preferred or Theme.Font
end

function UIKit.new(className, props, children)
	local inst, parent = Instance.new(className), nil
	for k, v in pairs(props or {}) do if k == "Parent" then parent = v else inst[k] = v end end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

function UIKit.corner(radius)
	return UIKit.new("UICorner", { CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or Theme.Radius) })
end

function UIKit.stroke(color, thickness)
	return UIKit.new("UIStroke", { Color = color or C.Outline, Thickness = thickness or Theme.Stroke, LineJoinMode = Enum.LineJoinMode.Round })
end

function UIKit.tween(inst, time, props, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(UIKit.dur(time or 0.25), style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UIKit.getScale(gui)
	local s = gui:FindFirstChild("KitScale") or gui:FindFirstChildOfClass("UIScale")
	if not s then s = UIKit.new("UIScale", { Name = "KitScale", Parent = gui }) end
	return s
end

-- jitter = สุ่ม pitch ±% ให้เสียงไม่ซ้ำซาก
function UIKit.sfx(name, jitter)
	local folder = SoundService:FindFirstChild("SFX")
	local src = folder and folder:FindFirstChild(name)
	local vol = tonumber(setting("Sfx", 1)) or 1
	if not src or vol <= 0 then return end
	local s = src:Clone()
	s.Volume = src.Volume * vol
	if jitter then s.PlaybackSpeed = src.PlaybackSpeed * (1 + (math.random() * 2 - 1) * jitter) end
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, math.max(s.TimeLength, 3) + 0.5)
end

function UIKit.label(p)
	local text = p.Text or ""
	local lbl = UIKit.new("TextLabel", {
		Name = p.Name or "Label", BackgroundTransparency = 1, Font = p.Font or UIKit.fontFor(text),
		Text = text, TextColor3 = p.Color or C.White, TextScaled = true, TextWrapped = p.Wrap == true,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Center, TextYAlignment = p.AlignY or Enum.TextYAlignment.Center,
		Size = p.Size or UDim2.fromScale(1, 1), Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero, Rotation = p.Tilt or 0,
		ZIndex = p.ZIndex or 1, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	}, {
		UIKit.new("UIStroke", { Thickness = p.StrokeThickness or 3, Color = p.StrokeColor or C.Outline, LineJoinMode = Enum.LineJoinMode.Round }),
		UIKit.new("UITextSizeConstraint", { MaxTextSize = p.MaxTextSize or 40, MinTextSize = p.MinTextSize or 1 }),
	})
	if not p.Font then lbl:SetAttribute("AutoFont", Theme.Font.Name) end
	if p.Gradient then UIKit.new("UIGradient", { Color = p.Gradient, Rotation = 90, Parent = lbl }) end
	return lbl
end

function UIKit.setText(lbl, text)
	text = tostring(text)
	lbl.Text = text
	local auto = lbl:GetAttribute("AutoFont")
	if auto then lbl.Font = UIKit.fontFor(text, Enum.Font[auto]) end
	if lbl.Name == "Front" and lbl.Parent then
		local sh = lbl.Parent:FindFirstChild("Shadow")
		if sh and sh:IsA("TextLabel") then sh.Text, sh.Font = text, lbl.Font end
	end
end

-- หัวข้อตัวใหญ่มีเงาดำเยื้อง (คืนค่า front, holder, shadow)
function UIKit.title(p)
	local holder = UIKit.new("Frame", {
		Name = p.Name or "Title", BackgroundTransparency = 1, Size = p.Size or UDim2.fromScale(1, 0.15),
		Position = p.Position or UDim2.new(), AnchorPoint = p.AnchorPoint or Vector2.zero,
		Rotation = p.Tilt or Theme.Tilt, ZIndex = p.ZIndex or 1, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	local off, z = p.ShadowOffset or 5, holder.ZIndex
	local shadow = UIKit.label({ Name = "Shadow", Text = p.Text, Font = p.Font, Color = C.Outline, StrokeThickness = p.StrokeThickness or 4,
		MaxTextSize = p.MaxTextSize or 72, Position = UDim2.fromOffset(off, off), ZIndex = z, Parent = holder })
	local front = UIKit.label({ Name = "Front", Text = p.Text, Font = p.Font, Color = p.Color or C.Yellow, Gradient = p.Gradient,
		StrokeThickness = p.StrokeThickness or 4, MaxTextSize = p.MaxTextSize or 72, ZIndex = z + 1, Parent = holder })
	return front, holder, shadow
end

-- ตัวหนังสือเด้งดึ๋ง + บิดนิดๆ
function UIKit.bounceText(lbl, text, amount)
	if text ~= nil then UIKit.setText(lbl, text) end
	local target = (lbl.Name == "Front" and lbl.Parent) or lbl
	local s = UIKit.getScale(target)
	s.Scale = 1 + (amount or 0.35)
	UIKit.tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
	local base = target:GetAttribute("BaseRot")
	if base == nil then base = target.Rotation; target:SetAttribute("BaseRot", base) end
	target.Rotation = base + (math.random() < 0.5 and -8 or 8)
	UIKit.tween(target, 0.4, { Rotation = base }, Enum.EasingStyle.Elastic)
end

function UIKit.countTo(lbl, from, to, duration, fmt)
	fmt = fmt or "%d"
	local nv = Instance.new("NumberValue")
	nv.Value = from
	nv.Changed:Connect(function(v) if lbl.Parent then lbl.Text = string.format(fmt, math.floor(v + 0.5)) end end)
	local t = UIKit.tween(nv, duration or 0.5, { Value = to })
	t.Completed:Connect(function()
		nv:Destroy()
		if lbl.Parent then UIKit.bounceText(lbl, string.format(fmt, math.floor(to + 0.5)), 0.25) end
	end)
	return t
end

-- กล่องการ์ตูน: เงาดำทึบเยื้อง + ขอบหนา (คืน holder, face)
function UIKit.comicBox(p)
	local off = p.ShadowOffset or Theme.ShadowOffset
	local holder = UIKit.new("Frame", {
		Name = p.Name or "ComicBox", BackgroundTransparency = 1, Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(), AnchorPoint = p.AnchorPoint or Vector2.zero, Rotation = p.Tilt or 0,
		ZIndex = p.ZIndex or 1, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	local z = holder.ZIndex
	UIKit.new("Frame", { Name = "Shadow", BackgroundColor3 = C.Shadow, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(off, off), ZIndex = z, Parent = holder }, { UIKit.corner(p.Radius) })
	local face = UIKit.new("Frame", { Name = "Face", BackgroundColor3 = p.Color or C.Panel, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = z + 1, ClipsDescendants = p.Clip or false, Parent = holder },
		{ UIKit.corner(p.Radius), UIKit.stroke(C.Outline, p.StrokeThickness or Theme.Stroke) })
	return holder, face
end

-- ปุ่มนูน 3D แบบเกมมือถือ: หน้าปุ่มยุบลงตอนกด
function UIKit.button(p)
	local color, lip = p.Color or C.Yellow, p.Lip or 6
	local btn = UIKit.new("TextButton", {
		Name = p.Name or "Button", Size = p.Size or UDim2.fromScale(0.2, 0.1), Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero, BackgroundColor3 = C.Outline, AutoButtonColor = false, Text = "",
		Rotation = p.Tilt or 0, ZIndex = p.ZIndex or 1, LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	}, { UIKit.corner(p.Radius) })
	local st = UIKit.stroke(C.Outline, p.StrokeThickness or 3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = btn
	btn:SetAttribute("BaseColor", color)

	local face = UIKit.new("Frame", { Name = "Face", BackgroundColor3 = color, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -lip), ZIndex = btn.ZIndex, Parent = btn }, {
		UIKit.corner(p.Radius),
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }),
	})
	UIKit.new("Frame", { Name = "Gloss", BackgroundColor3 = C.White, BackgroundTransparency = 0.55, BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0.2, 0), Position = UDim2.new(0, 8, 0, 4), ZIndex = btn.ZIndex, Parent = face },
		{ UIKit.corner(UDim.new(1, 0)) })
	local label = UIKit.label({ Name = "Label", Text = p.Text, Font = p.Font, Color = p.TextColor or C.White,
		Size = UDim2.fromScale(0.88, 0.78), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		MaxTextSize = p.MaxTextSize, Tilt = p.TextTilt or -2, ZIndex = btn.ZIndex, Parent = face })

	local scale, pressed, busy = UIKit.getScale(btn), false, false
	local function press(on)
		pressed = on
		UIKit.tween(face, 0.06, { Position = UDim2.fromOffset(0, on and lip - 1 or 0) })
	end
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") then return end
		UIKit.tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
		UIKit.sfx("Hover", 0.15)
	end)
	btn.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.15, { Scale = 1 })
		if pressed then press(false) end
	end)
	btn.MouseButton1Down:Connect(function() if not btn:GetAttribute("Disabled") then press(true) end end)
	btn.MouseButton1Up:Connect(function() if pressed then press(false) end end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then UIKit.shake(btn); UIKit.sfx("Honk", 0.1) return end
		if busy then return end
		UIKit.sfx("Click", 0.12)
		UIKit.jelly(btn, 0.12)
		if p.OnClick then
			if p.Debounce then
				busy = true
				local ok, err = pcall(p.OnClick, btn)
				if not ok then warn("[UIKit.button] OnClick error: " .. tostring(err)) end
				task.wait(UIKit.dur(p.Debounce == true and 0.35 or p.Debounce))
				busy = false
			else
				p.OnClick(btn)
			end
		end
	end)
	return btn, label
end

function UIKit.setColor(btn, color)
	local face = btn:FindFirstChild("Face")
	if not face then btn.BackgroundColor3 = color return end
	btn:SetAttribute("BaseColor", color)
	if not btn:GetAttribute("Disabled") then UIKit.tween(face, 0.15, { BackgroundColor3 = color }) end
end

function UIKit.setDisabled(btn, disabled)
	btn:SetAttribute("Disabled", disabled and true or nil)
	local face = btn:FindFirstChild("Face")
	if not face then return end
	local base = btn:GetAttribute("BaseColor") or C.Yellow
	face.BackgroundColor3 = disabled and base:Lerp(C.Gray, 0.75) or base
	local lbl = face:FindFirstChild("Label")
	if lbl then lbl.TextTransparency = disabled and 0.35 or 0 end
end

function UIKit.shake(gui, power)
	if gui:GetAttribute("Shaking") then return end
	gui:SetAttribute("Shaking", true)
	local origin, rot, k = gui.Position, gui.Rotation, power or 7
	task.spawn(function()
		for i = 1, 7 do
			if not gui.Parent then return end
			local f = k * (1 - i / 8)
			gui.Position = origin + UDim2.fromOffset((math.random() * 2 - 1) * f, (math.random() * 2 - 1) * f * 0.5)
			gui.Rotation = rot + (math.random() * 2 - 1) * f * 0.6
			task.wait(0.03)
		end
		gui.Position, gui.Rotation = origin, rot
		gui:SetAttribute("Shaking", nil)
	end)
end

function UIKit.jelly(gui, amount)
	local s = UIKit.getScale(gui)
	s.Scale = 1 + (amount or 0.15)
	UIKit.tween(s, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic)
end

-- ตัวเลขดาเมจ/คำอุทานเด้งขึ้นแล้วจางหาย
function UIKit.popup(parent, text, color)
	if not parent then return end
	text = tostring(text)
	local lbl = UIKit.label({ Name = "Popup", Text = text, Font = UIKit.fontFor(text, Theme.FontAlt), Color = color or C.Yellow,
		StrokeThickness = 4, MaxTextSize = 64, Size = UDim2.fromScale(1.3, 0.4), AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.45), Tilt = (math.random() - 0.5) * 20, ZIndex = 60, Parent = parent })
	local s = UIKit.getScale(lbl)
	s.Scale = 0.2
	UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.tween(lbl, 0.9, { Position = lbl.Position - UDim2.fromScale(0, 0.45) })
	task.delay(UIKit.dur(0.55), function()
		if not lbl.Parent then return end
		UIKit.tween(lbl, 0.35, { TextTransparency = 1 })
		local st = lbl:FindFirstChildOfClass("UIStroke")
		if st then UIKit.tween(st, 0.35, { Transparency = 1 }) end
	end)
	Debris:AddItem(lbl, UIKit.dur(1) + 0.2)
	return lbl
end

function UIKit.rain(parent, emoji, count)
	if not parent or not UIKit.effectsOn() then return end
	for _ = 1, count or 16 do
		task.delay(math.random() * 0.6, function()
			if not parent.Parent then return end
			local sz = math.random(28, 56)
			local l = UIKit.new("TextLabel", { BackgroundTransparency = 1, Text = emoji, TextScaled = true, Size = UDim2.fromOffset(sz, sz),
				AnchorPoint = CENTER, Position = UDim2.fromScale(math.random(), -0.1), Rotation = math.random(-40, 40), ZIndex = 80, Parent = parent })
			local d = 1.4 + math.random() * 0.8
			UIKit.tween(l, d, { Position = UDim2.fromScale(l.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.15),
				Rotation = l.Rotation + math.random(-180, 180) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(l, UIKit.dur(d) + 0.1)
		end)
	end
end

local toastGui, toastN = nil, 0
local function toastRoot()
	if UIKit.toastParent and UIKit.toastParent.Parent then
		local host = UIKit.toastParent:FindFirstChild("KitToastHost")
		if not host then
			host = UIKit.new("Frame", { Name = "KitToastHost", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 500,
				Parent = UIKit.toastParent }, {
				UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
				UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 72) }),
			})
		end
		return host
	end
	if toastGui and toastGui.Parent then return toastGui end
	local lp = Players.LocalPlayer
	local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	toastGui = UIKit.new("ScreenGui", { Name = "KitToasts", DisplayOrder = 500, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg }, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 72) }),
	})
	return toastGui
end

function UIKit.toast(text, color)
	local root = toastRoot()
	if not root then return end
	toastN += 1
	local slot = UIKit.new("Frame", { Name = "Toast", BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 0, 56), LayoutOrder = toastN, Parent = root },
		{ UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 56) }) })
	local holder, face = UIKit.comicBox({ Parent = slot, Color = color or C.Yellow, Tilt = (toastN % 2 == 0) and 1.5 or -1.5, ShadowOffset = 5 })
	UIKit.label({ Text = text, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, MaxTextSize = 26, Parent = face })
	local s = UIKit.getScale(holder)
	s.Scale = 0.2
	UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.sfx("Pop", 0.2)
	local list = {}
	for _, ch in ipairs(root:GetChildren()) do if ch.Name == "Toast" then table.insert(list, ch) end end
	table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 1, #list - 4 do list[i]:Destroy() end
	task.delay(2.4, function()
		if not slot.Parent then return end
		UIKit.tween(s, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(UIKit.dur(0.22))
		slot:Destroy()
	end)
end

-- หน้าต่าง modal: ริบบิ้นหัวข้อเอียง + ปุ่ม X (คืน panel, close, backdrop)
function UIKit.panel(parent, title, color)
	local back = UIKit.new("TextButton", { Name = "PanelBackdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.TableDark,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = parent })
	UIKit.tween(back, 0.2, { BackgroundTransparency = 0.3 })
	local holder, panel = UIKit.comicBox({ Name = "PanelHolder", Parent = back, Size = UDim2.fromScale(0.74, 0.8),
		Position = UDim2.fromScale(0.5, 0.54), AnchorPoint = CENTER, Color = C.Panel, ShadowOffset = 10, StrokeThickness = 4, ZIndex = 41 })
	panel.Name = "Panel"
	panel:SetAttribute("IsKitPanel", true)
	local _, ribbon = UIKit.comicBox({ Name = "Ribbon", Parent = holder, Size = UDim2.new(0.5, 0, 0, 56), Position = UDim2.new(0.5, 0, 0, -18),
		AnchorPoint = CENTER, Color = color or C.Pink, Tilt = -3, ZIndex = 45 })
	UIKit.label({ Text = title or "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		MaxTextSize = 34, StrokeThickness = 4, Parent = ribbon })
	local function close()
		if not back.Parent then return end
		UIKit.sfx("Whoosh")
		UIKit.tween(UIKit.getScale(holder), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UIKit.tween(back, 0.18, { BackgroundTransparency = 1 })
		task.delay(UIKit.dur(0.2), function() if back.Parent then back:Destroy() end end)
	end
	UIKit.button({ Name = "Close", Parent = holder, Text = "X", Color = C.Red, Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, -8, 0, 8), AnchorPoint = CENTER, Radius = UDim.new(1, 0), Tilt = 8, ZIndex = 46, OnClick = close })
	panel.Destroying:Connect(function() if back.Parent then back:Destroy() end end)
	local s = UIKit.getScale(holder)
	s.Scale = 0.5
	UIKit.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.sfx("Whoosh")
	return panel, close, back
end

function UIKit.badge(parent, text, color, p)
	p = p or {}
	local f = UIKit.new("Frame", { Name = p.Name or "Badge", BackgroundColor3 = color or C.Yellow, Size = p.Size or UDim2.fromOffset(90, 30),
		Position = p.Position or UDim2.new(), AnchorPoint = p.AnchorPoint or Vector2.zero, Rotation = p.Tilt or -4,
		ZIndex = p.ZIndex or 5, Parent = parent }, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(C.Outline, 3) })
	local l = UIKit.label({ Name = "Label", Text = text, Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, MaxTextSize = p.MaxTextSize or 20, ZIndex = f.ZIndex, Parent = f })
	return f, l
end

function UIKit.tierBadge(parent, rarity, size)
	local tier = Theme.RarityTier[rarity] or 1
	local f = UIKit.new("Frame", { Name = "TierBadge", BackgroundColor3 = Theme.Rarity[rarity] or C.Gray, Size = size or UDim2.fromOffset(30, 30),
		AnchorPoint = CENTER, Rotation = 45, ZIndex = 30, Parent = parent },
		{ UIKit.corner(6), UIKit.stroke(C.Outline, 3), UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	UIKit.label({ Text = "T" .. tier, Size = UDim2.fromScale(1.1, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		Tilt = -45, MaxTextSize = 18, ZIndex = 31, Parent = f })
	f:SetAttribute("Tier", tier)
	return f
end

return UIKit