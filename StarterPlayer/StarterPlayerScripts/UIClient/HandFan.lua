-- StarterPlayer/StarterPlayerScripts/UIClient/HandFan.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)
local Config = require(Shared.Config)

local C = UIKit.Theme.Color
local MAX_HAND = Config.MAX_HAND or 5
local DRAW_PER_TURN = Config.DRAW_PER_TURN or 2

local HandFan = {}
local states = setmetatable({}, { __mode = "k" })

local function rootOf(v)
	if typeof(v) == "Instance" then return v end
	if type(v) == "table" then return v.Root or v.Frame or v.Gui or v.Instance end
	return nil
end
HandFan.rootOf = rootOf

function HandFan.DrawPreview(handCount)
	return math.clamp(MAX_HAND - handCount, 0, DRAW_PER_TURN)
end

local function isTouch()
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function targetFor(st, i, n)
	local off = i - (n + 1) / 2
	local spread = math.min(7, 28 / math.max(n - 1, 1))
	local step = math.min(0.16, 0.8 / math.max(n, 1))
	local x, y, rot, scale = 0.5 + off * step, 1 + off * off * 0.022, off * spread, 1
	local h = st.hover and table.find(st.cards, st.hover)
	if h then
		if i == h then
			y, rot, scale = 0.84, 0, 1.18
		else
			x += (i < h and -1 or 1) * 0.045
		end
	end
	if st.cards[i] == st.held then y, scale = 1.15, 0.85 end
	return UDim2.fromScale(x, y), rot, scale
end

-- ทวีนไปตำแหน่งเป้าหมาย (ข้ามถ้าเป้าหมายเดิม เพื่อลดจำนวนทวีน)
local function tweenTo(st, g, i, n, t)
	local pos, rot, scale = targetFor(st, i, n)
	local last = st.last[g]
	if last and last[1] == pos and math.abs(last[2] - rot) < 0.01 and math.abs(last[3] - scale) < 0.001 then
		return pos
	end
	st.last[g] = { pos, rot, scale }
	UIKit.tween(g, t, { Position = pos, Rotation = rot }, Enum.EasingStyle.Back)
	UIKit.tween(UIKit.getScale(g), t, { Scale = scale }, Enum.EasingStyle.Back)
	return pos
end

local function arrange(st, fresh)
	local n = #st.cards
	for i, g in ipairs(st.cards) do
		g.ZIndex = (g == st.hover) and 60 or 10 + i
		local delay = fresh and fresh[g]
		if delay then
			st.pending[g] = true
			task.delay(UIKit.dur(delay), function()
				st.pending[g] = nil
				if not g.Parent then return end
				local idx = table.find(st.cards, g) -- คำนวณใหม่ตอนบินจริง
				if not idx then return end
				local pos = tweenTo(st, g, idx, #st.cards, 0.45)
				UIKit.sfx("Draw", 0.2)
				FX.sparkles(st.container, C.Yellow, 8, Vector2.new(pos.X.Scale, 0.6))
			end)
		elseif not st.pending[g] then
			tweenTo(st, g, i, n, 0.22)
		end
	end
end

local function updateCounter(st, n, grew)
	local full = n >= MAX_HAND
	UIKit.setText(st.countLabel, string.format("มือ %d/%d", n, MAX_HAND))
	st.countBadge.BackgroundColor3 = full and C.Red or C.Yellow
	local nxt = HandFan.DrawPreview(n)
	UIKit.setText(st.drawLabel, nxt > 0 and ("เทิร์นหน้าจั่ว +" .. nxt) or "เทิร์นหน้าไม่ได้จั่ว")
	st.drawBadge.BackgroundColor3 = nxt > 0 and C.Blue or C.Gray
	if grew then
		UIKit.jelly(st.countBadge, 0.3)
		if full then UIKit.popup(st.countBadge, "มือเต็ม!", C.Red) end
	end
end

local function hook(st, g)
	g.AnchorPoint = Vector2.new(0.5, 1)
	g.MouseEnter:Connect(function()
		if st.held or isTouch() or st.hover == g then return end
		st.hover = g
		arrange(st)
		UIKit.sfx("CardHover", 0.25)
	end)
	g.MouseLeave:Connect(function()
		if st.hover == g then st.hover = nil; arrange(st) end
	end)
end

function HandFan.Container(parent, position, size, anchor)
	local c = UIKit.new("Frame", {
		Name = "HandFan", BackgroundTransparency = 1, Position = position or UDim2.fromScale(0.2, 0.7),
		Size = size or UDim2.fromScale(0.6, 0.3), AnchorPoint = anchor or Vector2.zero, Parent = parent,
	})
	local countBadge, countLabel = UIKit.badge(c, "มือ 0/" .. MAX_HAND, C.Yellow, {
		Size = UDim2.fromOffset(130, 34), Position = UDim2.new(0, 0, 0, -6), AnchorPoint = Vector2.new(0, 1), ZIndex = 70 })
	local drawBadge, drawLabel = UIKit.badge(c, "", C.Blue, {
		Size = UDim2.fromOffset(190, 30), Position = UDim2.new(0, 140, 0, -8), AnchorPoint = Vector2.new(0, 1),
		Tilt = 3, MaxTextSize = 16, ZIndex = 70 })
	states[c] = {
		container = c, cards = {}, lastN = 0,
		known = setmetatable({}, { __mode = "k" }),
		pending = setmetatable({}, { __mode = "k" }),
		last = setmetatable({}, { __mode = "k" }),
		countBadge = countBadge, countLabel = countLabel, drawBadge = drawBadge, drawLabel = drawLabel,
	}
	updateCounter(states[c], 0, false)
	return c
end

function HandFan.Layout(container, views)
	local st = states[container]
	if not st then return end
	local list = {}
	for _, v in ipairs(views or {}) do
		local g = rootOf(v)
		if g then table.insert(list, g) end
	end
	st.cards = list
	local n = #list
	local drawn = math.max(0, n - st.lastN)
	local fresh = {}
	for i, g in ipairs(list) do
		if g.Parent ~= container then g.Parent = container end
		if not st.known[g] then
			st.known[g] = true
			st.last[g] = nil
			hook(st, g)
			if i > n - drawn then
				fresh[g] = (i - (n - drawn) - 1) * 0.15
				g.Position, g.Rotation = UDim2.fromScale(1.2, 0.1), 40
				UIKit.getScale(g).Scale = 0.3
			else
				local pos, rot, sc = targetFor(st, i, n)
				g.Position, g.Rotation = pos, rot
				UIKit.getScale(g).Scale = sc
				st.last[g] = { pos, rot, sc }
			end
		end
	end
	if st.hover and not table.find(list, st.hover) then st.hover = nil end
	if st.held and not table.find(list, st.held) then st.held = nil end
	st.lastN = n
	updateCounter(st, n, drawn > 0)
	arrange(st, fresh)
end

function HandFan.SetHeld(container, view, on)
	local st = states[container]
	if not st then return end
	st.held = on and rootOf(view) or nil
	if on then st.hover = nil end
	arrange(st)
end

function HandFan.Reject(view)
	local g = rootOf(view)
	if not g then return end
	UIKit.shake(g:FindFirstChild("Body") or g, 10) -- สั่นตัวใน ไม่แย่งตำแหน่งกับ fan
	UIKit.sfx("Honk", 0.1)
end

return HandFan