-- StarterPlayer/StarterPlayerScripts/UIClient/MatchHUD.lua
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)
local Perf = require(Shared.UI.Perf)
local Config = require(Shared.Config)
local okCD, CardData = pcall(require, Shared.CardData)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local PPT = Config.POINTS_PER_TURN or 5
local TURN_TIME = Config.TURN_TIME or 120
local FIELD_SLOTS = Config.FIELD_SLOTS or 3

local MatchHUD = {}
MatchHUD.__index = MatchHUD

local function now() return workspace:GetServerTimeNow() end

local function defOf(c)
	if type(c) == "table" then return c.Def or c end
	if okCD and type(CardData) == "table" then return CardData[c] end
	return nil
end


-- ชิ้นลอยแยกอิสระ: ขนาดอิงสัดส่วนจอ แต่มีพื้น/เพดานเป็น pixel เพื่อไม่ให้ถูกบีบเป็นแถบเมื่อ viewport เตี้ย
local function floatLimit(holder, minW, minH, maxW, maxH)
	UIKit.new("UISizeConstraint", { MinSize = Vector2.new(minW, minH), MaxSize = Vector2.new(maxW or 100000, maxH or 100000), Parent = holder })
end

---------------------------------------------------------------- HP
local function buildHP(self, side)
	local mine = side == "me"
	local holder, face = UIKit.comicBox({ Name = side .. "HP", Parent = self.root, Size = UDim2.fromScale(0.26, 0.07),
		Position = mine and UDim2.new(0, 16, 0, 44) or UDim2.new(1, -16, 0, 44),
		AnchorPoint = mine and Vector2.zero or Vector2.new(1, 0), Color = C.TableDark, Tilt = mine and -1.5 or 1.5, ZIndex = 20 })
	floatLimit(holder, 200, 38, 420, 64)
	local name = UIKit.label({ Text = mine and "เรา" or "ศัตรู", Color = mine and C.Lime or C.Pink, Size = UDim2.new(0.7, 0, 0, 26),
		Position = UDim2.new(mine and 0 or 1, 0, 0, -4), AnchorPoint = Vector2.new(mine and 0 or 1, 1),
		AlignX = mine and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, MaxTextSize = 24, ZIndex = 25, Parent = holder })
	local track = UIKit.new("Frame", { BackgroundColor3 = C.Ink, Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, ZIndex = 22, Parent = face }, { UIKit.corner(8) })
	local anchor, pos = Vector2.new(mine and 0 or 1, 0), UDim2.fromScale(mine and 0 or 1, 0)
	local lag = UIKit.new("Frame", { BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = anchor, Position = pos,
		Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = track }, { UIKit.corner(8) })
	local fill = UIKit.new("Frame", { BackgroundColor3 = C.Green, BorderSizePixel = 0, AnchorPoint = anchor, Position = pos,
		Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = track }, {
		UIKit.corner(8), UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }) })
	local num = UIKit.label({ Text = "-", Size = UDim2.fromScale(0.9, 1.1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		MaxTextSize = 30, ZIndex = 26, Parent = track })
	local shield, shieldLbl = UIKit.badge(holder, "🛡 0", C.Blue, { Size = UDim2.fromOffset(72, 30),
		Position = UDim2.new(mine and 1 or 0, mine and 8 or -8, 0.5, 0), AnchorPoint = Vector2.new(mine and 0 or 1, 0.5), ZIndex = 27 })
	shield.Visible = false
	self.hp[side] = { holder = holder, name = name, fill = fill, lag = lag, num = num, shield = shield, shieldLbl = shieldLbl,
		max = Config.LEADER_HP or 30, shieldVal = 0 }
end

function MatchHUD:SetHP(side, hp, shield, leaderName)
	local b = self.hp[side]
	if not b or hp == nil then return end
	if leaderName and leaderName ~= "" and b.name.Text ~= leaderName then UIKit.setText(b.name, leaderName) end
	b.max = math.max(b.max, hp)
	local ratio = math.clamp(hp / b.max, 0, 1)
	local old = b.hp
	b.hp = hp
	UIKit.tween(b.fill, 0.2, { Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = ratio > 0.5 and C.Green or ratio > 0.25 and C.Yellow or C.Red })
	task.delay(UIKit.dur(0.35), function()
		if b.lag.Parent then UIKit.tween(b.lag, 0.5, { Size = UDim2.fromScale(ratio, 1) }) end
	end)
	if old and hp ~= old then
		UIKit.bounceText(b.num, hp, 0.4)
		if hp < old then
			UIKit.shake(b.holder, 10); UIKit.sfx("Hit", 0.2)
			UIKit.popup(b.holder, "-" .. (old - hp), C.Red)
		else
			UIKit.sfx("Heal", 0.1)
			UIKit.popup(b.holder, "+" .. (hp - old), C.Green)
		end
	else
		UIKit.setText(b.num, hp)
	end
	shield = shield or 0
	b.shield.Visible = shield > 0
	if shield ~= b.shieldVal then
		UIKit.bounceText(b.shieldLbl, "🛡 " .. shield, 0.3)
		b.shieldVal = shield
	end
end

---------------------------------------------------------------- Points
local OFF_CELL = Color3.fromRGB(50, 40, 80)

local function buildPoints(self)
	local holder, face = UIKit.comicBox({ Name = "Points", Parent = self.root, Size = UDim2.fromScale(0.2, 0.09),
		Position = UDim2.new(0, 16, 1, -16), AnchorPoint = Vector2.new(0, 1), Color = C.TableDark, Tilt = -2, ZIndex = 20 })
	floatLimit(holder, 190, 46, 340, 78)
	UIKit.label({ Text = "พลังกาว", Color = C.Lime, Size = UDim2.new(0.5, 0, 0, 24), Position = UDim2.new(0, 6, 0, -4),
		AnchorPoint = Vector2.new(0, 1), AlignX = Enum.TextXAlignment.Left, MaxTextSize = 22, ZIndex = 25, Parent = holder })
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.68, 0.6), Position = UDim2.fromScale(0.04, 0.5),
		AnchorPoint = Vector2.new(0, 0.5), ZIndex = 22, Parent = face }, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0),
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.cells = {}
	for i = 1, PPT do
		local cell = UIKit.new("Frame", { Name = "Cell", BackgroundColor3 = C.Lime, Size = UDim2.fromScale(0.94 / PPT - 0.03, 1),
			LayoutOrder = i, ZIndex = 23, Parent = row }, { UIKit.corner(UDim.new(0.4, 0)), UIKit.stroke(C.Outline, 2.5) })
		local g = UIKit.new("UIGradient", { Rotation = 90, Color = Theme.seq(C.White, Color3.fromRGB(200, 200, 200), Color3.fromRGB(140, 140, 140)), Parent = cell })
		self.cells[i] = { frame = cell, grad = g }
	end
	self.pointsNum = UIKit.label({ Text = tostring(PPT), Color = C.Yellow, Size = UDim2.fromScale(0.24, 0.9),
		Position = UDim2.fromScale(0.98, 0.5), AnchorPoint = Vector2.new(1, 0.5), MaxTextSize = 56, ZIndex = 24, Parent = face })
	self.bankBadge, self.bankLbl = UIKit.badge(holder, "+0", C.Pink, { Size = UDim2.fromOffset(84, 28),
		Position = UDim2.new(1, 6, 0, -4), AnchorPoint = Vector2.new(1, 0.5), Tilt = 6, MaxTextSize = 16, ZIndex = 27 })
	self.bankBadge.Visible = false
	self.pointsHolder = holder

	self.shieldHint = UIKit.badge(self.root, "🛡 มีโล่ฝาหม้อ! ลงได้ฟรี 0 พอยต์", C.Blue, {
		Size = UDim2.fromOffset(250, 28), Position = UDim2.new(0, 16, 1, -86), AnchorPoint = Vector2.new(0, 1), Tilt = -2, MaxTextSize = 16, ZIndex = 26 })
	self.shieldHint.Name = "ShieldHint"
	self.shieldHint.Visible = false

	-- เกจกระเพื่อมเหมือนเยลลี่
	local t0, acc = os.clock(), 0
	table.insert(self.conns, RunService.Heartbeat:Connect(function(dt)
		local hz = Perf.get("hudHz")
		if hz <= 0 or not UIKit.effectsOn() then return end
		acc += dt
		if acc < 1 / hz then return end
		acc = 0
		local t = os.clock() - t0
		for i, c in ipairs(self.cells) do c.grad.Offset = Vector2.new(0, math.sin(t * 4 + i) * 0.15) end
	end))
end

function MatchHUD:SetPoints(points)
	points = points or 0
	local old = self.points
	self.points = points
	for i, c in ipairs(self.cells) do
		local on, was = i <= points, old == nil or i <= old
		c.frame.BackgroundColor3 = on and C.Lime or OFF_CELL
		if old and on ~= was then
			UIKit.jelly(c.frame, 0.4)
			if not on then FX.sparkles(self.pointsHolder, C.Lime, 4, Vector2.new(0.04 + (i - 0.5) / PPT * 0.68, 0.5)) end
		end
	end
	if old and old ~= points then UIKit.bounceText(self.pointsNum, points) else UIKit.setText(self.pointsNum, points) end
	local extra = points - PPT
	self.bankBadge.Visible = extra > 0
	if extra > 0 then UIKit.setText(self.bankLbl, "+" .. extra .. " สะสม") end
	self:_refreshSkip()
end

---------------------------------------------------------------- Skip
local function buildSkip(self, onSkip)
	self.skip, self.skipLabel = UIKit.button({ Name = "Skip", Parent = self.root, Text = "SKIP!", Color = C.Pink,
		Size = UDim2.fromScale(0.16, 0.1), Position = UDim2.new(1, -16, 1, -34), AnchorPoint = Vector2.new(1, 1),
		Tilt = 3, MaxTextSize = 48, Lip = 8, Debounce = 0.6, ZIndex = 30,
		OnClick = function() if onSkip then onSkip() end end })
	floatLimit(self.skip, 130, 48, 260, 84)
	self.skipHint = UIKit.label({ Text = "", Color = C.Yellow, Size = UDim2.new(1.2, 0, 0, 22), Position = UDim2.new(0.5, 0, 1, 6),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 18, ZIndex = 31, Parent = self.skip })
end

function MatchHUD:_refreshSkip()
	local my = self.isMyTurn == true
	UIKit.setDisabled(self.skip, not my)
	if not my then UIKit.setText(self.skipHint, "รอศัตรูอยู่...") return end
	if not self.spent then
		-- ตรงกับ Match:EndTurn: banking = not spentThisTurn
		UIKit.setText(self.skipLabel, "เก็บพอยต์!")
		UIKit.setText(self.skipHint, "ยังไม่ได้ใช้พอยต์ = เก็บไว้เทิร์นหน้า")
		UIKit.setColor(self.skip, C.Blue)
	else
		UIKit.setText(self.skipLabel, "SKIP!")
		UIKit.setText(self.skipHint, "จบเทิร์น ไปเลย!")
		UIKit.setColor(self.skip, C.Pink)
	end
end

---------------------------------------------------------------- Timer
local function buildTimer(self)
	local holder = UIKit.new("Frame", { Name = "Timer", BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 72),
		Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 30, Parent = self.root },
		{ UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	self.timerHolder = holder
	self.flames = FX.flames(holder, 29)
	UIKit.new("Frame", { Name = "Shadow", BackgroundColor3 = C.Shadow, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(5, 5),
		ZIndex = 30, Parent = holder }, { UIKit.corner(UDim.new(1, 0)) })
	-- CanvasGroup ตัดขอบตามมุมโค้ง ทรายจึงอยู่ในวงกลมพอดี
	local face = UIKit.new("CanvasGroup", { Name = "Face", BackgroundColor3 = C.TableDark, Size = UDim2.fromScale(1, 1), ZIndex = 31,
		Parent = holder }, { UIKit.corner(UDim.new(1, 0)) })
	local sand = UIKit.new("Frame", { BackgroundColor3 = C.Lime, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = face })
	UIKit.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 33, Parent = holder },
		{ UIKit.corner(UDim.new(1, 0)), UIKit.stroke(C.Outline, 4) })
	self.timeLbl = UIKit.label({ Text = "2:00", Size = UDim2.fromScale(0.85, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, MaxTextSize = 44, ZIndex = 34, Parent = holder })
	self.turnLbl = UIKit.label({ Text = "", Size = UDim2.new(2.6, 0, 0, 28), Position = UDim2.new(0.5, 0, 1, 8),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 26, ZIndex = 34, Parent = holder })

	local lastSec
	table.insert(self.conns, RunService.Heartbeat:Connect(function()
		if not self.endsAt then return end
		local rem = math.max(0, self.endsAt - now())
		if rem > TURN_TIME + 5 then rem = TURN_TIME end -- กันกรณีเวลาฝั่งเซิร์ฟเวอร์ใช้ฐานเวลาคนละแบบ
		sand.Size = UDim2.fromScale(1, rem / TURN_TIME)
		local sec = math.ceil(rem)
		if sec == lastSec then return end
		lastSec = sec
		self.timeLbl.Text = string.format("%d:%02d", sec // 60, sec % 60)
		self.timeLbl.TextColor3 = sec <= 10 and C.Red or C.White
		sand.BackgroundColor3 = sec > 30 and C.Lime or sec > 10 and C.Orange or C.Red
		self.flames:SetIntensity(sec <= 30 and (31 - sec) / 25 or 0)
		if sec <= 10 and sec > 0 then
			UIKit.bounceText(self.timeLbl, nil, 0.3)
			UIKit.shake(holder, 4 + (10 - sec))
			UIKit.sfx(self.isMyTurn and "TickTock" or "Tick", 0.05)
		end
		-- พอยต์หมดแล้ว ให้ปุ่ม SKIP เด้งเรียกร้องความสนใจ
		if self.isMyTurn and (self.points or 0) == 0 and sec % 2 == 0 then UIKit.jelly(self.skip, 0.1) end
	end))
end

function MatchHUD:Banner(text, color)
	local holder, face = UIKit.comicBox({ Parent = self.root, Size = UDim2.fromScale(0.5, 0.12), Position = UDim2.fromScale(-0.3, 0.42),
		AnchorPoint = CENTER, Color = color, Tilt = -4, ShadowOffset = 8, ZIndex = 200 })
	UIKit.label({ Text = text, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		MaxTextSize = 60, StrokeThickness = 4, ZIndex = 202, Parent = face })
	UIKit.sfx("Whoosh")
	UIKit.tween(holder, 0.35, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	task.delay(UIKit.dur(1.1), function()
		if not holder.Parent then return end
		UIKit.tween(holder, 0.3, { Position = UDim2.fromScale(1.3, 0.42) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(UIKit.dur(0.32))
		holder:Destroy()
	end)
end

function MatchHUD:SetTurn(isMine, endsAt)
	local changed = self.isMyTurn ~= isMine
	self.isMyTurn, self.endsAt = isMine, endsAt
	if changed then
		self.turnLbl.TextColor3 = isMine and C.Lime or C.Pink
		UIKit.bounceText(self.turnLbl, isMine and "ตาเรา!!" or "ตาศัตรู...", 0.4)
		self:Banner(isMine and "ตาเรา!! ลุยยย" or "ตาศัตรู... หายใจลึกๆ", isMine and C.Lime or C.Pink)
	end
	self:_refreshSkip()
end

---------------------------------------------------------------- Compact (viewport เตี้ย)
-- เมื่อ root เตี้ยกว่า COMPACT_H: ลดขนาดชิ้น ย้ายป้ายโล่ไปข้างพลังกาว เอา hint ใต้ปุ่ม Skip ออก ไม่ให้ชิ้นไหนทับกัน
local COMPACT_H = 360
function MatchHUD:_layout()
	local h = self.root.AbsoluteSize.Y
	local compact = h > 0 and h < COMPACT_H
	if compact == self.compact then return end
	self.compact = compact
	local sc = compact and 0.72 or 1
	-- HP: ชิดบนสุด
	for side, b in pairs(self.hp) do
		local c = b.holder:FindFirstChildOfClass("UISizeConstraint")
		if c then c.MinSize = Vector2.new(compact and 150 or 200, compact and 28 or 38); c.MaxSize = Vector2.new(420, compact and 40 or 64) end
		b.holder.Position = side == "me" and UDim2.new(0, 12, 0, compact and 22 or 44) or UDim2.new(1, -12, 0, compact and 22 or 44)
	end
	-- Points: มุมซ้ายล่าง เล็กลง
	local pc = self.pointsHolder:FindFirstChildOfClass("UISizeConstraint")
	if pc then pc.MinSize = Vector2.new(compact and 150 or 190, compact and 34 or 46); pc.MaxSize = Vector2.new(340, compact and 50 or 78) end
	self.pointsHolder.Position = UDim2.new(0, 12, 1, compact and -8 or -16)
	-- ป้ายโล่: วางเหนือกล่องพลังกาว (ขอบซ้ายเดียวกัน) ระยะอิงความสูงจริงของกล่องพลังกาว จึงไม่ทับทุกขนาดจอ
	local ph = self.pointsHolder.AbsoluteSize.Y
	if ph <= 0 then ph = compact and 34 or 46 end
	local pc2 = self.pointsHolder:FindFirstChildOfClass("UISizeConstraint")
	if pc2 then ph = math.max(pc2.MinSize.Y, math.min(pc2.MaxSize.Y, self.root.AbsoluteSize.Y * 0.09)) end
	self.shieldHint.Size = UDim2.fromOffset(compact and 200 or 250, compact and 22 or 28)
	self.shieldHint.AnchorPoint = Vector2.new(0, 1)
	-- เว้นที่ให้ป้าย "พลังกาว" (สูง ~24 ยื่นขึ้นเหนือกล่อง) แล้วจึงวางป้ายโล่
	self.shieldHint.Position = UDim2.new(0, 12, 1, -(ph + (compact and 8 or 16) + 28))
	-- Skip: มุมขวาล่าง hint ใต้ปุ่มซ่อนเมื่อ compact (ข้อความอยู่บนปุ่มแล้ว)
	local sk = self.skip:FindFirstChildOfClass("UISizeConstraint")
	if sk then sk.MinSize = Vector2.new(compact and 110 or 130, compact and 36 or 48); sk.MaxSize = Vector2.new(260, compact and 56 or 84) end
	self.skip.Position = UDim2.new(1, -12, 1, compact and -8 or -34)
	self.skipHint.Visible = not compact
	-- Timer: เล็กลงและชิดบน ป้ายตา/ศัตรูอยู่ข้างวง (ไม่ยื่นลงล่าง)
	local tm = self.timerHolder
	tm.Size = UDim2.fromOffset(compact and 52 or 72, compact and 52 or 72)
	tm.Position = UDim2.new(0.5, 0, 0, compact and 6 or 40)
	if compact then
		self.turnLbl.AnchorPoint = Vector2.new(0, 0.5)
		self.turnLbl.Position = UDim2.new(1, 8, 0.5, 0)
		self.turnLbl.Size = UDim2.new(1.6, 0, 0, 22)
		self.turnLbl.TextXAlignment = Enum.TextXAlignment.Left
	else
		self.turnLbl.AnchorPoint = Vector2.new(0.5, 0)
		self.turnLbl.Position = UDim2.new(0.5, 0, 1, 8)
		self.turnLbl.Size = UDim2.new(2.6, 0, 0, 28)
		self.turnLbl.TextXAlignment = Enum.TextXAlignment.Center
	end
end

---------------------------------------------------------------- API หลัก
function MatchHUD.new(gui, cb)
	cb = cb or {}
	local self = setmetatable({ hp = {}, conns = {} }, MatchHUD)
	self.root = UIKit.new("Frame", { Name = "MatchHUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })
	buildHP(self, "me")
	buildHP(self, "opp")
	buildPoints(self)
	buildSkip(self, cb.OnSkip)
	buildTimer(self)
	self:_layout()
	table.insert(self.conns, self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_layout() end))
	return self
end

function MatchHUD:Apply(s)
	self:SetHP("me", s.myHP, s.myShield, s.myLeader)
	self:SetHP("opp", s.oppHP, s.oppShield, s.oppLeader)
	self.spent = s.mySpent == true or (type(s.mySpent) == "number" and s.mySpent > 0)
	self:SetTurn(s.isMyTurn == true, s.turnEndsAt)
	self:SetPoints(s.myPoints)
	local hasShield = false
	for _, c in ipairs(s.myHand or {}) do
		local d = defOf(c)
		if d and (d.Cost or 1) == 0 and type(d.Effect) == "table" and d.Effect.Kind == "Shield" then hasShield = true break end
	end
	self.shieldHint.Visible = hasShield and s.isMyTurn == true
end

-- วงซัมมอนรูปวงรีใต้ช่องสนาม (ใต้ตาข่าย) ZIndex 0 เพื่อให้อยู่หลังการ์ดเสมอ
function MatchHUD.decorateSlot(slot, mine)
	return FX.summonCircle(slot, { Size = UDim2.fromScale(1.3, 0.5), Position = UDim2.fromScale(0.5, 0.9),
		Color = mine and C.Pink or C.Blue, ZIndex = 0 })
end

local function keyOf(u)
	if type(u) ~= "table" then return u end
	return u.Uid or u.uid or u.InstanceId or u.Id
end

-- เทียบสนามก่อนกับหลัง: ลงตัวละครใหม่ = ระเบิดสีชมพู, ใส่อาวุธ = ระเบิดสีส้ม
function MatchHUD.diffField(prev, cur, circles)
	prev, cur = prev or {}, cur or {}
	for i = 1, FIELD_SLOTS do
		local a, b, circle = prev[i], cur[i], circles[i]
		if circle then
			if b and keyOf(a) ~= keyOf(b) then
				circle:Burst(Theme.TypeColor.Character)
			elseif type(a) == "table" and type(b) == "table" and b.Weapon and keyOf(a.Weapon) ~= keyOf(b.Weapon) then
				circle:Burst(Theme.TypeColor.Weapon)
			end
			circle:SetActive(b ~= nil and b ~= false)
		end
	end
end

function MatchHUD:Destroy()
	for _, c in ipairs(self.conns) do c:Disconnect() end
	self.root:Destroy()
end

return MatchHUD