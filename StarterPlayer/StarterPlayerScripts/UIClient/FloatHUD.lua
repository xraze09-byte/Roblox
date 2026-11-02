-- StarterPlayerScripts/UIClient/FloatHUD.lua
-- ปุ่มลอย + เมนูรองแบบ Pop-up (แทน LobbyUI ทั้งหมด ไม่มีหน้าเต็มจอ)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Decks = require(Shared:WaitForChild("Decks"))
local CardData = require(Shared:WaitForChild("CardData"))
local Icons = require(Shared:WaitForChild("UI"):WaitForChild("Icons"))
local Net = require(script.Parent:WaitForChild("Net"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local DeckBuilder
do
	local m = script.Parent:FindFirstChild("DeckBuilder")
	if m then
		local ok, r = pcall(require, m)
		if ok then DeckBuilder = r else warn("[FloatHUD] โหลด DeckBuilder ไม่ได้: " .. tostring(r)) end
	end
end

local function tryReq(name)
	local m = script.Parent:FindFirstChild(name)
	if not m then return nil end
	local ok, r = pcall(require, m)
	if not ok then warn("[FloatHUD] โหลด " .. name .. " ไม่ได้: " .. tostring(r)) return nil end
	return r
end
local MenuKit = tryReq("MenuKit")
local PlayPanel = tryReq("PlayPanel")
local ProfilePanel = tryReq("ProfilePanel")
local PlayerTap = tryReq("PlayerTap")


local C = {
	Red = Color3.fromRGB(255, 70, 100), Pink = Color3.fromRGB(255, 90, 200), Lime = Color3.fromRGB(150, 255, 90),
	Orange = Color3.fromRGB(255, 150, 40), Yellow = Color3.fromRGB(255, 220, 60), Blue = Color3.fromRGB(80, 170, 255),
	Purple = Color3.fromRGB(150, 90, 255), Panel = Color3.fromRGB(58, 24, 130), Ink = Color3.fromRGB(25, 10, 45),
	White = Color3.new(1, 1, 1), Gray = Color3.fromRGB(150, 150, 170),
}
local RARITY = { Common = C.Gray, Rare = C.Blue, Epic = C.Purple, Legend = C.Yellow, Legendary = C.Yellow }
local PAD, GAP, EDGE = 10, 8, 12

local FloatHUD = {}
FloatHUD.C = C

-- ===== state =====
local hud, overlay, catcher, gemsLabel, moreBadge, toastLabel
local deck = nil -- { dim, win } หน้าต่างจัดเด็คที่เปิดอยู่
local cb = {}
local profile = nil
local leaderIndex = 1
local queueMode = nil
local inMatch = false
local refreshing = false
local openPopup, openOwner = nil, nil
local fabs, extras = {}, {}
local openGacha, openQuests, openStats, openFarms -- forward

-- ===== helpers =====
local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(1, 0); c.Parent = p; return c end
local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or C.Ink; s.Thickness = th or 3; s.Parent = p
	return s
end
local function label(parent, text, color, h)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, h or 26)
	l.Font = Juice.Font
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = color or C.White
	l.Text = text
	l.Parent = parent
	return l
end
local function blobButton(parent, text, color, size, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = size
	b.BackgroundColor3 = color
	b.Font = Juice.Font
	b.TextScaled = true
	b.TextColor3 = C.Ink
	b.Text = text
	b.Parent = parent
	corner(b); stroke(b, C.Ink, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	Juice.bind(b)
	b.Activated:Connect(function() onClick(b) end)
	return b
end
-- ปุ่มเต็มแถวในกล่อง: ห่อด้วย holder เพื่อให้เด้ง/ยุบจากตรงกลาง (UIListLayout ไม่สน AnchorPoint)
local function row(parent, order, text, color, fn, h, iconKey)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, math.max(44, h or 46))
	holder.LayoutOrder = order
	holder.Parent = parent
	local b = blobButton(holder, text, color, UDim2.fromScale(1, 1), fn)
	b.Position = UDim2.fromScale(0.5, 0.5)

	if iconKey and Icons.has(iconKey) then
		b.TextXAlignment = Enum.TextXAlignment.Left
		local pad = b:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, 48)
			pad.PaddingRight = UDim.new(0, 12)
		end
		Icons.image(iconKey, {
			Name = "RowIcon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = b.ZIndex + 2,
		}, holder)
	end

	return b, holder
end

local function toast(text, color)
	if not overlay then return end
	if toastLabel then toastLabel:Destroy() end
	local lb = label(overlay, text, C.White, 44)
	lb.AnchorPoint = Vector2.new(0.5, 0)
	lb.Position = UDim2.new(0.5, 0, 0, 64)
	lb.Size = UDim2.fromOffset(math.min(420, overlay.AbsoluteSize.X - 24), 44)
	lb.BackgroundTransparency = 0
	lb.BackgroundColor3 = color or C.Purple
	lb.ZIndex = 100
	corner(lb, UDim.new(0, 12)); stroke(lb, C.Ink, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = lb
	toastLabel = lb
	Juice.popIn(lb)
	task.delay(2.2, function()
		if toastLabel ~= lb then return end
		toastLabel = nil
		Juice.popOut(lb, function() lb:Destroy() end)
	end)
end
FloatHUD.Toast = toast

local function cardDef(id)
	if typeof(CardData.Get) == "function" then
		local ok, d = pcall(CardData.Get, id)
		if ok and d then return d end
	end
	return CardData[id] or (typeof(CardData.Cards) == "table" and CardData.Cards[id]) or nil
end
local function leaderId() return (Decks.Leaders or {})[leaderIndex] end
local function leaderName()
	local id = leaderId()
	local def = id and cardDef(id)
	return def and (def.Name or def.DisplayName) or tostring(id or "-")
end

-- เปิดหน้าต่างใหญ่ (จัดเด็ค): ซ่อนปุ่มลอย + ปิดปุ่มในฉาก
local function setModal(open)
	if hud then hud.Enabled = not open and not inMatch end
	if cb.OnModal and not inMatch then cb.OnModal(open) end
end

-- ===== popup core =====
local function closePopup()
	if not openPopup then return end
	local p = openPopup
	openPopup, openOwner = nil, nil
	if catcher then catcher.Visible = false end
	Juice.popOut(p, function() p:Destroy() end)
end
FloatHUD.Close = closePopup

local function ownerCenter(owner)
	if not owner or not owner.Parent then return hud.AbsoluteSize / 2 end
	return owner.AbsolutePosition + owner.AbsoluteSize / 2 - hud.AbsolutePosition
end

-- แผงชิดซ้าย/ขวาของปุ่ม (owner = nil → กลางจอ)
local function side(owner, right)
	if not owner then return nil, nil end
	if right then return Vector2.new(1, 0.5), Vector2.new(-60, 0) end
	return Vector2.new(0, 0.5), Vector2.new(60, 0)
end

local function openPanel(owner, opts)
	closePopup()
	local screen = hud.AbsoluteSize
	local w = math.min(opts.Width or 260, screen.X - EDGE * 2)

	-- เป็น TextButton เพื่อกินคลิก ไม่ให้ทะลุไปโดน ClickAway แล้วกล่องปิดเอง
	local p = Instance.new("TextButton")
	p.Name = "FloatPanel"
	p.Text = ""
	p.AutoButtonColor = false
	p.Selectable = false
	p.BackgroundColor3 = C.Panel
	p.ZIndex = 10
	p.Parent = hud
	corner(p, UDim.new(0, 16)); stroke(p, opts.Color or C.Yellow, 4)
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do pad[k] = UDim.new(0, PAD) end
	pad.Parent = p
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = p
	local header = Instance.new("Frame")
	header.Name = "PanelHeader"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 32)
	header.LayoutOrder = 0
	header.Parent = p

	local titleLbl = label(header, opts.Title, opts.Color or C.Yellow, 30)
	titleLbl.Position = UDim2.new(0, 0, 0, 0)
	titleLbl.Size = UDim2.new(1, -36, 1, 0)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.AutoButtonColor = false
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.BackgroundColor3 = C.Red
	closeBtn.Text = ""
	closeBtn.ZIndex = 12
	closeBtn.Parent = header
	corner(closeBtn, UDim.new(1, 0))
	stroke(closeBtn, C.Ink, 2)
	Icons.image("Close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 13,
	}, closeBtn)
	Juice.bind(closeBtn)
	closeBtn.Activated:Connect(closePopup)

	opts.Build(p, w - PAD * 2)

	-- คำนวณความสูงเอง (ไม่ใช้ AutomaticSize ที่คำนวณเพี้ยนเมื่อมี UIScale)
	local h, n = PAD * 2, 0
	for _, ch in p:GetChildren() do
		if ch:IsA("GuiObject") then h += ch.Size.Y.Offset; n += 1 end
	end
	h += GAP * math.max(0, n - 1)
	local maxH = screen.Y - EDGE * 2
	if h > maxH then h = maxH; p.ClipsDescendants = true end
	p.Size = UDim2.fromOffset(w, h)

	-- บังคับให้อยู่ในจอเสมอ
	local anchor = opts.Anchor or Vector2.new(0.5, 0.5)
	local c = ownerCenter(owner) + (opts.Offset or Vector2.zero)
	local x = math.clamp(c.X - anchor.X * w, EDGE, math.max(EDGE, screen.X - w - EDGE))
	local y = math.clamp(c.Y - anchor.Y * h, EDGE, math.max(EDGE, screen.Y - h - EDGE))
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromOffset(x + w / 2, y + h / 2)

	Juice.popIn(p)
	openPopup, openOwner = p, owner
	catcher.Visible = true
	return p
end

local function scrollList(parent, order, itemH, count)
	local gap = 6
	local content = math.max(0, count * (itemH + gap) - gap)
	local maxH = math.max(120, hud.AbsoluteSize.Y - 190)
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.new(1, 0, 0, math.min(content, maxH))
	sf.CanvasSize = UDim2.fromOffset(0, content) -- ตั้งเอง ไม่ใช้ AutomaticCanvasSize (บั๊ก canvas = 0)
	sf.ScrollBarThickness = content > maxH and 6 or 0
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.LayoutOrder = order
	sf.Parent = parent
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = sf
	return sf
end

local function openRadial(owner, items, radius, a0, a1)
	closePopup()
	local screen = hud.AbsoluteSize
	local c = ownerCenter(owner)
	local holder = Instance.new("Frame")
	holder.Name = "Radial"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Position = UDim2.fromOffset(c.X, c.Y)
	holder.ZIndex = 10
	holder.Parent = hud
	local n = #items
	local bw = math.clamp(math.floor(screen.X * 0.22), 130, 170)
	local bh = 46 -- min 44px touch target
	local r = math.clamp(math.min(screen.X, screen.Y) * 0.28, 95, radius or 150)

	for i, it in items do
		local t = (n == 1) and 0.5 or (i - 1) / (n - 1)
		local a = math.rad(a0 + (a1 - a0) * t)
		local minX, minY = bw / 2 + EDGE, bh / 2 + EDGE
		local px = math.clamp(c.X + math.cos(a) * r, minX, math.max(minX, screen.X - bw / 2 - EDGE))
		local py = math.clamp(c.Y + math.sin(a) * r, minY, math.max(minY, screen.Y - bh / 2 - EDGE))
		local b
		b = blobButton(holder, it.Text, it.Color, UDim2.fromOffset(bw, bh), function()
			if not it.Keep then closePopup() end
			it.OnClick(b)
		end)
		b.Position = UDim2.fromOffset(px - c.X, py - c.Y)

		if it.Icon and Icons.has(it.Icon) then
			local pad = b:FindFirstChildOfClass("UIPadding")
			if pad then pad.PaddingLeft = UDim.new(0, 36) end
			Icons.image(it.Icon, {
				Name = "RadialIcon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				ZIndex = b.ZIndex + 1,
			}, b)
		end

		Juice.popIn(b, (i - 1) * 0.05)
		Juice.wobble(b, { Amp = 2, Rot = 3, Speed = 3 })
	end
	openPopup, openOwner = holder, owner
	catcher.Visible = true
end

-- ===== Battle / Queue =====
local function paintQueue()
	local fab = fabs.Battle
	if not fab then return end
	local waiting = queueMode ~= nil
	local iconInst = fab:FindFirstChild("Icon")
	if iconInst and iconInst:IsA("ImageLabel") then
		iconInst.Image = waiting and Icons.get("Pause") or Icons.get("Play")
	elseif iconInst and iconInst:IsA("TextLabel") then
		iconInst.Text = waiting and "รอ..." or "เล่น!"
	end
	fab.Tag.Text = waiting and "กำลังหา..." or "เล่น!"
	fab.BackgroundColor3 = waiting and C.Pink or C.Red
end

local PVP_HINT_SEC = 30
local queueTicket = nil

local function startMode(mode)
	if inMatch then return end
	local leavingPvP = queueMode == "PvP" and mode ~= "PvP"
	closePopup()
	local lid = leaderId()
	if not lid then toast("ยังไม่มีผู้นำให้เลือก", C.Red) return end
	local ok, status = Net.invokeLocked("queue", "Queue", mode, lid)
	if not ok then toast(Net.message(status), C.Red) paintQueue() return end
	if leavingPvP and queueMode == "PvP" then
		queueMode = nil
		queueTicket = nil
	end
	if status == "WAITING" and not inMatch then
		queueMode = mode
		toast("กำลังหาคู่ต่อสู้... กดอีกทีเพื่อยกเลิก", C.Pink)
		local ticket = {}
		queueTicket = ticket
		task.delay(PVP_HINT_SEC, function()
			if queueTicket == ticket and queueMode == "PvP" and not inMatch then
				toast("ยังไม่เจอคู่ต่อสู้ ลองเล่นกับบอทได้เลย ระบบจะยกเลิกคิว PvP ให้", C.Orange)
			end
		end)
	end
	paintQueue()
end

local function togglePvP()
	if inMatch then return end
	if queueMode == "PvP" then
		closePopup()
		local ok, status = Net.invokeLocked("queue", "Queue", "Cancel")
		if ok then queueMode = nil; toast("ยกเลิกการค้นหาแล้ว", C.Gray)
		else toast(Net.message(status), C.Red) end
		paintQueue()
	else
		startMode("PvP")
	end
end

-- ===== Play panel: แท็บ บอท / PvP (1v1) =====
local BOT_LEVELS = {
	{ Mode = "BotEasy", Key = "Easy", Label = "ง่าย", Color = C.Lime, Desc = "เล่นสบายๆ บางทีก็พลาด" },
	{ Mode = "Bot", Key = "Normal", Label = "ปานกลาง", Color = C.Yellow, Desc = "บอทมาตรฐาน" },
	{ Mode = "BotHard", Key = "Hard", Label = "ยาก", Color = C.Orange, Desc = "เลือกเป้าเก่ง ปิดเกมไว" },
	{ Mode = "BotHacker", Key = "Hacker", Label = "แฮกเกอร์", Color = C.Red, Desc = "คิดไว เล่นโหด มีโล่เพิ่ม" },
	{ Mode = "BotMix", Key = "Mix", Label = "สุ่มระดับ", Color = C.Purple, Desc = "สุ่มความยากใหม่ทุกแมตช์" },
}
local PVP_TYPES = {
	{ Mode = "PvP", Label = "ออนไลน์", Color = C.Pink, Desc = "จับคู่กับผู้เล่นจริง" },
	{ Label = "แรงค์", Color = C.Gray, Desc = "เร็วๆ นี้", Locked = true },
}
local MATCH_SIZES = {
	{ Text = "1v1", Color = C.Blue },
	{ Text = "1v2", Color = C.Gray },
	{ Text = "1v3", Color = C.Gray },
}
local PLAY_BODY_H = 210
local playTab, botLevelIndex, pvpIndex = "Bot", 2, 1

local function hbox(parent, order, h)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, h)
	f.LayoutOrder = order or 0
	f.Parent = parent
	return f
end

local function markSelected(b)
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then s.Color = C.White; s.Thickness = 4 end
end

local function segment(parent, items, selected, onPick)
	local n = #items
	for i, it in items do
		local h = Instance.new("Frame")
		h.BackgroundTransparency = 1
		h.Position = UDim2.new((i - 1) / n, 2, 0, 0)
		h.Size = UDim2.new(1 / n, -4, 1, 0)
		h.Parent = parent
		local b = blobButton(h, it.Text, i == selected and it.Color or C.Gray, UDim2.fromScale(1, 1), function() onPick(i) end)
		b.Position = UDim2.fromScale(0.5, 0.5)
		if i == selected then markSelected(b) end
	end
end

local function botInfo(key)
	local list = Config.BOT_DIFFICULTY
	return type(list) == "table" and list[key] or nil
end

local function botRewardText(lv)
	if lv.Key == "Mix" then
		local lo, hi
		for _, k in (Config.BOT_MIX_POOL or {}) do
			local info = botInfo(k)
			local r = info and tonumber(info.Reward)
			if r then lo = math.min(lo or r, r); hi = math.max(hi or r, r) end
		end
		if lo then return ("รางวัลชนะ: %d-%d เพชร"):format(lo, hi) end
		return "รางวัลชนะ: ตามระดับที่สุ่มได้"
	end
	local info = botInfo(lv.Key)
	return ("รางวัลชนะ: %d เพชร"):format(info and tonumber(info.Reward) or Config.REWARD_WIN_BOT or 0)
end

local function buildPlayList(body, items, selected, onPick)
	local itemH, gap = 44, 6
	local content = #items * (itemH + gap) - gap + 12
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundColor3 = C.Ink
	sf.BackgroundTransparency = 0.4
	sf.BorderSizePixel = 0
	sf.Size = UDim2.new(0.42, -4, 1, 0)
	sf.CanvasSize = UDim2.fromOffset(0, content)
	sf.ScrollBarThickness = content > PLAY_BODY_H and 6 or 0
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.Parent = body
	corner(sf, UDim.new(0, 12))
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do pad[k] = UDim.new(0, 6) end
	pad.Parent = sf
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = sf
	for i, it in items do
		local b = row(sf, i, it.Label, i == selected and it.Color or C.Gray, function() onPick(i, it) end, itemH)
		if i == selected then markSelected(b) end
	end
end

local function openPlay(owner)
	if inMatch then return end
	local panel = openPanel(nil, {
		Title = "เลือกโหมดเล่น", Color = C.Lime, Width = 520,
		Build = function(p)
			local tabs = hbox(p, 1, 40)
			local body = hbox(p, 2, PLAY_BODY_H)
			local render
			render = function()
				for _, ch in tabs:GetChildren() do ch:Destroy() end
				for _, ch in body:GetChildren() do ch:Destroy() end
				local isBot = playTab == "Bot"
				segment(tabs, { { Text = "บอท", Color = C.Lime }, { Text = "PvP", Color = C.Pink } }, isBot and 1 or 2, function(i)
					local want = i == 1 and "Bot" or "PvP"
					if want ~= playTab then playTab = want; render() end
				end)

				local items = isBot and BOT_LEVELS or PVP_TYPES
				local sel = isBot and botLevelIndex or pvpIndex
				buildPlayList(body, items, sel, function(i, picked)
					if picked.Locked then toast("โหมดนี้ยังไม่เปิด เร็วๆ นี้!", C.Orange) return end
					if isBot then botLevelIndex = i else pvpIndex = i end
					render()
				end)

				local it = items[sel] or items[1]
				local right = Instance.new("Frame")
				right.BackgroundTransparency = 1
				right.Position = UDim2.new(0.42, 4, 0, 0)
				right.Size = UDim2.new(0.58, -4, 1, 0)
				right.Parent = body
				local rl = Instance.new("UIListLayout")
				rl.Padding = UDim.new(0, 6)
				rl.SortOrder = Enum.SortOrder.LayoutOrder
				rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
				rl.Parent = right

				local title, desc
				if isBot then
					local info = botInfo(it.Key)
					if it.Key == "Mix" then
						title = "คู่ต่อสู้: ???"
					else
						title = "คู่ต่อสู้: " .. ((info and info.Name) or ("บอท" .. it.Label))
					end
					desc = it.Desc .. "\n" .. botRewardText(it)
				else
					title = "PvP " .. it.Label
					desc = it.Desc .. ("\nชนะ %d / แพ้ %d เพชร"):format(Config.REWARD_WIN_PVP or 0, Config.REWARD_LOSE_PVP or 0)
				end
				local t = label(right, title, it.Color, 26)
				t.LayoutOrder = 1
				t.TextXAlignment = Enum.TextXAlignment.Left
				local d = label(right, desc, C.White, 34)
				d.LayoutOrder = 2
				d.TextXAlignment = Enum.TextXAlignment.Left

				row(right, 3, "ผู้นำ: " .. leaderName(), C.Yellow, function(b)
					local leaders = Decks.Leaders or {}
					if #leaders <= 1 then return end
					leaderIndex = leaderIndex % #leaders + 1
					b.Text = "ผู้นำ: " .. leaderName()
				end, 44, "Heart")

				segment(hbox(right, 4, 34), MATCH_SIZES, 1, function(i)
					if i ~= 1 then toast("โหมด 1v2 / 1v3 กำลังพัฒนา เร็วๆ นี้!", C.Orange) end
				end)

				local waitingPvP = not isBot and queueMode == "PvP"
				local pb = row(right, 5, waitingPvP and "ยกเลิกหา" or "เล่น!", waitingPvP and C.Pink or C.Lime, function()
					if isBot then
						startMode(BOT_LEVELS[botLevelIndex].Mode)
					elseif it.Locked then
						toast("โหมดนี้ยังไม่เปิด เร็วๆ นี้!", C.Orange)
					else
						togglePvP()
					end
				end, 44, "Play")
				Juice.wobble(pb, { Amp = 1, Rot = 3, Speed = 4 })
			end
			render()
		end,
	})
	if panel then openOwner = owner end
end

local function openBattle(owner)
	openPlay(owner or fabs.Battle)
end

-- ===== Gacha =====
local function gachaCost(n)
	if n == 10 then return Config.GACHA_COST_10 or (Config.GACHA_COST_1 or 0) * 10 end
	return Config.GACHA_COST_1 or 0
end

local function showPulls(results, owner)
	openPanel(nil, { Title = "ผลการสุ่มการ์ด", Color = C.Pink, Width = 540, Build = function(p, inner)
		local cw, ch, gap = 96, 64, 6
		local perRow = math.max(1, math.floor((inner + gap) / (cw + gap)))
		local rows = math.max(1, math.ceil(#results / perRow))
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, rows * (ch + gap) - gap)
		grid.LayoutOrder = 1
		grid.Parent = p
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(cw, ch)
		gl.CellPadding = UDim2.fromOffset(gap, gap)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid
		if #results == 0 then label(grid, "ไม่มีผลลัพธ์", C.Gray) end
		for i, r in results do
			local id = typeof(r) == "table" and (r.Id or r.CardId or r.id) or r
			local def = cardDef(id)
			local rar = (typeof(r) == "table" and r.Rarity) or (def and def.Rarity) or "Common"
			local extra = ""
			if typeof(r) == "table" then
				if r.New then extra = "\nNEW!" elseif r.Refund then extra = ("\n+%d เพชร"):format(r.Refund) end
			end
			local chip = label(grid, (def and def.Name or tostring(id)) .. extra, C.Ink)
			chip.LayoutOrder = i
			chip.BackgroundTransparency = 0
			chip.BackgroundColor3 = RARITY[rar] or C.Gray
			corner(chip, UDim.new(0, 10)); stroke(chip, C.Ink, 2)
			Juice.popIn(chip, i * 0.08)
			if rar == "Epic" or rar == "Legend" or rar == "Legendary" then
				task.delay(i * 0.08 + 0.25, function()
					if chip.Parent then Juice.burstOn(chip, nil, RARITY[rar]) end
				end)
			end
		end
		row(p, 2, "สุ่มต่อ", C.Lime, function() openGacha(owner) end, 40, "Chest")
		label(p, "แตะที่ว่างเพื่อปิด", C.Gray, 18).LayoutOrder = 3
	end })
end

local function pull(count, owner, btn)
	if profile and (profile.Gems or 0) < gachaCost(count) then
		toast("เพชรไม่พอ!", C.Red)
		if gemsLabel then Juice.shake(gemsLabel, 14) end
		if btn then Juice.shake(btn, 10) end
		return
	end
	local oldText = btn and btn.Text
	if btn then btn.Text = "กำลังสุ่ม..." end
	local ok, results = Net.invokeLocked("gacha", "Gacha", count)
	if btn and btn.Parent then btn.Text = oldText end
	if not ok then toast(Net.message(results), C.Red) return end
	showPulls(typeof(results) == "table" and results or {}, owner)
end

openGacha = function(owner)
	local anchor, offset = side(owner, false)
	openPanel(owner, {
		Title = "กาชา", Color = C.Pink, Width = 270, Anchor = anchor, Offset = offset,
		Build = function(p)
			label(p, ("มีอยู่ %d เพชร"):format(profile and profile.Gems or 0), C.White, 22).LayoutOrder = 1
			row(p, 2, ("สุ่ม 1 ครั้ง  (%d เพชร)"):format(gachaCost(1)), C.Pink, function(b) pull(1, owner, b) end, nil, "Key")
			row(p, 3, ("สุ่ม 10 ครั้ง  (%d เพชร)"):format(gachaCost(10)), C.Lime, function(b) pull(10, owner, b) end, nil, "Chest")
		end,
	})
end

-- ===== Deck =====
local function deckCount()
	local d = profile and profile.Deck
	if typeof(d) ~= "table" then return 0 end
	if #d > 0 then return #d end
	local n = 0
	for _, v in d do n += (typeof(v) == "number" and v or 1) end
	return n
end

local function closeDeck(animate)
	local p = deck
	if not p then return end
	deck = nil
	setModal(false)
	if typeof(p) == "Instance" then
		local backdrop = p:FindFirstAncestor("PanelBackdrop")
		if backdrop then
			backdrop:Destroy()
		elseif p.Parent then
			p:Destroy()
		end
	end
end

local function openDeckBuilder()
	closePopup()
	if inMatch or deck then return end
	if not DeckBuilder then toast("ยังไม่มีระบบจัดเด็ค", C.Orange) return end
	if not profile then toast("กำลังโหลดข้อมูล รอแป๊บนึง...", C.Orange); FloatHUD.Refresh(); return end

	setModal(true)
	local ok, panel = pcall(DeckBuilder.Open, overlay, {
		Cards = CardData, Owned = profile.Collection, Deck = profile.Deck, Message = Net.message,
		OnSave = function(ids) return Net.invoke("SaveDeck", ids) end,
		OnClose = function()
			if deck then
				closeDeck(false)
			end
		end,
	})
	if not ok or not panel then
		warn("[FloatHUD] DeckBuilder.Open error: " .. tostring(panel))
		deck = nil
		setModal(false)
		toast("เปิดหน้าจัดเด็คไม่ได้ ลองใหม่อีกครั้ง", C.Red)
		return
	end

	deck = panel
	panel.Destroying:Once(function()
		if deck == panel then
			deck = nil
			setModal(false)
		end
	end)
end

local function openDeck(owner)
	local anchor, offset = side(owner, false)
	openPanel(owner, {
		Title = "เด็คของคุณ", Color = C.Blue, Width = 260, Anchor = anchor, Offset = offset,
		Build = function(p)
			label(p, ("ในเด็ค: %d ใบ"):format(deckCount()), C.White, 24).LayoutOrder = 1
			label(p, "ผู้นำ: " .. leaderName(), C.Yellow, 22).LayoutOrder = 2
			row(p, 3, "จัดเด็ค", C.Yellow, openDeckBuilder, nil, "Sort")
		end,
	})
end

-- ===== Quests =====
local function questList()
	local q = profile and profile.Quests
	if typeof(q) ~= "table" then return {}, nil end
	return (typeof(q.List) == "table" and q.List) or q, tonumber(q.ResetIn)
end
local function claimableCount()
	local n = 0
	for _, q in questList() do
		if typeof(q) == "table" and not q.Claimed and (q.Progress or 0) >= (q.Goal or 1) then n += 1 end
	end
	return n
end

local function questItem(parent, q, i)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.Ink
	f.BackgroundTransparency = 0.3
	f.Size = UDim2.new(1, -8, 0, 56)
	f.LayoutOrder = i
	f.Parent = parent
	corner(f, UDim.new(0, 12))

	local prog, goal = q.Progress or 0, math.max(1, q.Goal or 1)
	local done = prog >= goal
	local t = label(f, ("%s  (%d/%d)"):format(tostring(q.Text or q.Id or "?"), math.min(prog, goal), goal), C.White)
	t.Position = UDim2.fromOffset(10, 4)
	t.Size = UDim2.new(0.62, -10, 1, -16)
	t.TextXAlignment = Enum.TextXAlignment.Left

	local barBg = Instance.new("Frame")
	barBg.BackgroundColor3 = C.Panel
	barBg.Position = UDim2.new(0, 10, 1, -10)
	barBg.Size = UDim2.new(0.62, -10, 0, 5)
	barBg.Parent = f
	corner(barBg)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = done and C.Lime or C.Yellow
	bar.Size = UDim2.fromScale(math.clamp(prog / goal, 0, 1), 1)
	bar.Parent = barBg
	corner(bar)

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0.64, 0, 0.5, 0)
	holder.Size = UDim2.new(0.36, -8, 0, 40)
	holder.Parent = f
	local text, color
	if q.Claimed then text, color = "รับแล้ว", C.Gray
	elseif done then text, color = ("รับ %d เพชร"):format(q.Reward or 0), C.Lime
	else text, color = ("%d เพชร"):format(q.Reward or 0), C.Gray end
	local b
	b = blobButton(holder, text, color, UDim2.fromScale(1, 1), function()
		if q.Claimed or not done then Juice.shake(b, 8) return end
		local ok, res = Net.invokeLocked("quest", "ClaimQuest", q.Id)
		if not ok then toast(Net.message(res), C.Red) return end
		q.Claimed = true
		Juice.unwobble(b)
		b.Text, b.BackgroundColor3 = "รับแล้ว", C.Gray
		Juice.burstOn(b, ("+%d เพชร"):format(tonumber(res) or q.Reward or 0), C.Yellow)
		FloatHUD.Refresh()
	end)
	b.Position = UDim2.fromScale(0.5, 0.5)
	if done and not q.Claimed then Juice.wobble(b, { Amp = 1, Rot = 5, Speed = 5 }) end
end

openQuests = function(owner)
	local list, resetIn = questList()
	local anchor, offset = side(owner, true)
	openPanel(owner, {
		Title = "เควสต์รายวัน", Color = C.Lime, Width = 400, Anchor = anchor, Offset = offset,
		Build = function(p)
			if #list == 0 then
				label(p, "ยังไม่มีเควสต์ ลองใหม่อีกทีนะ", C.Gray, 24).LayoutOrder = 1
			else
				local sf = scrollList(p, 1, 56, #list)
				for i, q in list do questItem(sf, q, i) end
			end
			if resetIn and resetIn > 0 then
				label(p, ("รีเซ็ตใน %d ชม. %d นาที"):format(resetIn // 3600, (resetIn % 3600) // 60), C.Gray, 20).LayoutOrder = 2
			end
		end,
	})
end

-- ===== Stats =====
local function pct(v) return ("%.1f%%"):format(tonumber(v) or 0) end

openStats = function(owner)
	local snap, err = Net.invokeLocked("stats", "GetStats")
	if typeof(snap) ~= "table" then toast(Net.message(err or "DATA_LOADING"), C.Red) return end
	local T = typeof(snap.Total) == "table" and snap.Total or {}
	local D = typeof(T.Derived) == "table" and T.Derived or {}
	local Td = typeof(snap.Today) == "table" and snap.Today or {}
	local lines = {
		{ "เล่นทั้งหมด", tostring(T.Matches or 0) },
		{ "ชนะ / แพ้", ("%d / %d"):format(T.Wins or 0, T.Losses or 0) },
		{ "อัตราชนะ", pct(D.WinRate) },
		{ "PvP / บอท", pct(D.WinRatePvP) .. " / " .. pct(D.WinRateBot) },
		{ "ชนะติด (สูงสุด)", ("%d (%d)"):format(tonumber(snap.Streak) or 0, tonumber(snap.BestStreak) or 0) },
		{ "การ์ดต่อเกม", tostring(D.CardsPerMatch or 0) },
		{ "ร่างทอง / อึ", pct(D.GoldenRate) .. " / " .. pct(D.PoopRate) },
		{ "วันนี้ เล่น / ชนะ", ("%d / %d"):format(Td.Matches or 0, Td.Wins or 0) },
	}
	local anchor, offset = side(owner, true)
	openPanel(owner, {
		Title = "สถิติของคุณ", Color = C.Blue, Width = 380, Anchor = anchor, Offset = offset,
		Build = function(p)
			local sf = scrollList(p, 1, 32, #lines)
			for i, ln in lines do
				local f = Instance.new("Frame")
				f.BackgroundColor3 = C.Ink
				f.BackgroundTransparency = 0.35
				f.Size = UDim2.new(1, -8, 0, 32)
				f.LayoutOrder = i
				f.Parent = sf
				corner(f, UDim.new(0, 8))
				local a = label(f, ln[1], C.White)
				a.Position = UDim2.fromOffset(8, 4); a.Size = UDim2.new(0.58, -8, 1, -8)
				a.TextXAlignment = Enum.TextXAlignment.Left
				local b = label(f, ln[2], C.Yellow)
				b.Position = UDim2.new(0.58, 0, 0, 4); b.Size = UDim2.new(0.42, -8, 1, -8)
				b.TextXAlignment = Enum.TextXAlignment.Right
				Juice.popIn(f, i * 0.03)
			end
		end,
	})
end

-- ===== Farms =====
local farmPanel = nil

local function farmButton(box, xScale, text, color, fn)
	local h = Instance.new("Frame")
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0, 0.5)
	h.Position = UDim2.new(xScale, 0, 0.5, 0)
	h.Size = UDim2.new(0.23, -4, 0, 40)
	h.Parent = box
	local b = blobButton(h, text, color, UDim2.fromScale(1, 1), fn)
	b.Position = UDim2.fromScale(0.5, 0.5)
	return b
end

local function farmItem(parent, f, i, now, owner)
	local box = Instance.new("Frame")
	box.BackgroundColor3 = C.Ink
	box.BackgroundTransparency = 0.3
	box.Size = UDim2.new(1, -8, 0, 58)
	box.LayoutOrder = i
	box.Parent = parent
	corner(box, UDim.new(0, 12))

	local rate, cap = tonumber(f.Rate) or 0, tonumber(f.Cap) or 0
	local last = tonumber(f.LastClaim) or now
	local stored = math.min(cap, math.floor(math.max(0, now - last) / 60 * rate))
	local info = label(box, ("%s Lv.%d\n%d/%d  (+%s/นาที)"):format(
		tostring(f.Name or f.Id), f.Level or 1, stored, cap, ("%g"):format(rate)), C.White)
	info.Position = UDim2.fromOffset(10, 4)
	info.Size = UDim2.new(0.52, -10, 1, -8)
	info.TextXAlignment = Enum.TextXAlignment.Left

	local claim
	claim = farmButton(box, 0.53, "เก็บ", stored > 0 and C.Lime or C.Gray, function()
		local ok, res = Net.invokeLocked("farm", "ClaimFarm", f.Id)
		if not ok then toast(Net.message(res), C.Red); Juice.shake(claim, 10) return end
		Juice.burstOn(claim, ("+%d เพชร"):format(tonumber(res) or stored), C.Yellow)
		local panel = farmPanel
		task.delay(0.35, function() if openPopup == panel then openFarms(owner) end end)
	end)
	if stored >= cap and cap > 0 then Juice.wobble(claim, { Amp = 1, Rot = 5, Speed = 5 }) end

	if f.UpgradeCost then
		local up
		up = farmButton(box, 0.765, ("อัป %d"):format(f.UpgradeCost), C.Yellow, function()
			local ok, res = Net.invokeLocked("farm", "UpgradeFarm", f.Id)
			if not ok then toast(Net.message(res), C.Red); Juice.shake(up, 10) return end
			Juice.burstOn(up, "อัปแล้ว!", C.Lime)
			local panel = farmPanel
			task.delay(0.35, function() if openPopup == panel then openFarms(owner) end end)
		end)
	else
		farmButton(box, 0.765, "MAX", C.Gray, function() end)
	end
end

openFarms = function(owner)
	local ok, list, now = Net.invokeLocked("farm", "GetFarms")
	if not ok or typeof(list) ~= "table" then toast(Net.message(list), C.Red) return end
	now = tonumber(now) or workspace:GetServerTimeNow()
	local anchor, offset = side(owner, true)
	farmPanel = openPanel(owner, {
		Title = "ฟาร์มเพชร", Color = C.Orange, Width = 440, Anchor = anchor, Offset = offset,
		Build = function(p)
			if #list == 0 then
				label(p, "ยังไม่มีฟาร์ม", C.Gray, 24).LayoutOrder = 1
			else
				local sf = scrollList(p, 1, 58, #list)
				for i, f in list do farmItem(sf, f, i, now, owner) end
			end
			label(p, "เพชรจะงอกเองเรื่อยๆ จนเต็มคลัง", C.Gray, 18).LayoutOrder = 2
		end,
	})
end

-- ===== เมนู =====
function FloatHUD.AddMenuItem(text, color, fn)
	table.insert(extras, { Text = text, Color = color or C.Lime, OnClick = fn })
end
local function openMore(owner)
	local nq = claimableCount()
	local anchor, offset = side(owner, true)
	openPanel(owner, {
		Title = "เมนู", Color = C.Purple, Width = 260, Anchor = anchor, Offset = offset,
		Build = function(p)
			local qb = row(p, 1, nq > 0 and ("เควสต์ (%d!)"):format(nq) or "เควสต์", C.Lime, function() openQuests(owner) end, nil, "Chest")
			if nq > 0 then Juice.wobble(qb, { Amp = 0, Rot = 4, Speed = 5 }) end
			row(p, 2, "สถิติ", C.Blue, function() openStats(owner) end, nil, "Up")
			row(p, 3, "ฟาร์มเพชร", C.Orange, function() openFarms(owner) end, nil, "Coin")
			row(p, 5, ("หอคอย ชั้น %d"):format(profile and profile.TowerFloor or 1), C.Orange, function() startMode("Tower") end, nil, "Up")
			row(p, 4, "ท่าเต้น (200+)", C.Pink, function()
				closePopup()
				local DanceEmoteUI = script.Parent:FindFirstChild("DanceEmoteUI")
				if DanceEmoteUI then
					pcall(function() require(DanceEmoteUI).Open() end)
				end
			end, nil, "Play")
			for i, it in extras do
				row(p, 10 + i, it.Text, it.Color, function() closePopup(); it.OnClick() end, nil, it.Icon or "Panel")
			end
		end,
	})
end

-- ===== Floating Action Buttons =====
local function makeFab(id, icon, tag, color, pos, size, onClick)
	local b = Instance.new("TextButton")
	b.Name = "Fab_" .. id
	b.AutoButtonColor = false
	b.Text = ""
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = pos
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = color
	b.ZIndex = 6
	b.Parent = hud
	corner(b); stroke(b, C.Ink, 4)

	local ic
	if typeof(icon) == "string" and Icons.has(icon) then
		ic = Icons.image(icon, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(0.66, 0.66),
			ZIndex = 7,
		}, b)
	else
		ic = label(b, icon, C.White)
		ic.Name = "Icon"
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.45)
		ic.Size = UDim2.fromScale(0.62, 0.62)
		ic.ZIndex = 7
	end

	local tg = label(b, tag, C.White)
	tg.Name = "Tag"
	tg.BackgroundTransparency = 0
	tg.BackgroundColor3 = C.Ink
	tg.AnchorPoint = Vector2.new(0.5, 0)
	tg.Position = UDim2.new(0.5, 0, 1, -10)
	tg.Size = UDim2.fromOffset(size + 14, 24)
	corner(tg, UDim.new(0, 8))

	Juice.bind(b)
	Juice.wobble(b, { Amp = 5, Rot = 6, Speed = 1.6 + math.random() * 0.8 })
	b.Activated:Connect(function()
		if openPopup and openOwner == b then closePopup() else onClick(b) end
	end)
	fabs[id] = b
	return b
end

local function makeBadge(fab)
	local bd = Instance.new("TextLabel")
	bd.Name = "Badge"
	bd.AnchorPoint = Vector2.new(0.5, 0.5)
	bd.Position = UDim2.fromScale(0.88, 0.12)
	bd.Size = UDim2.fromOffset(24, 24)
	bd.BackgroundColor3 = C.Red
	bd.Font = Juice.Font
	bd.TextScaled = true
	bd.TextColor3 = C.White
	bd.Text = "!"
	bd.Visible = false
	bd.ZIndex = 8
	bd.Parent = fab
	corner(bd); stroke(bd, C.Ink, 2)
	return bd
end

-- ===== profile =====
local function applyProfile(snap)
	if typeof(snap) ~= "table" then return end
	local old = profile and profile.Gems
	profile = snap
	if gemsLabel then
		local txt = gemsLabel:FindFirstChild("GemsText")
		if txt and txt:IsA("TextLabel") then
			txt.Text = ("%d"):format(snap.Gems or 0)
		end
		if old and old ~= snap.Gems then Juice.squish(gemsLabel) end
	end
	if moreBadge then
		local n = claimableCount()
		moreBadge.Visible = n > 0
		moreBadge.Text = tostring(n)
	end
end

local function refreshProfile()
	local snap = Net.invoke("GetProfile")
	if typeof(snap) == "table" then applyProfile(snap) return true end
	if gemsLabel and not profile then
		local txt = gemsLabel:FindFirstChild("GemsText")
		if txt and txt:IsA("TextLabel") and txt.Text == "..." then
			txt.Text = "0"
		end
	end
	return false
end

-- ===== Main-screen actions: Play / Profile / Settings =====
local function openPlay(owner)
	if inMatch then return end
	closePopup()
	if not PlayPanel then openBattle(owner) return end -- fallback: old radial menu
	PlayPanel.Open({
		StartMode = startMode,
		TogglePvP = togglePvP,
		IsQueuing = function() return queueMode == "PvP" end,
		LeaderName = leaderName,
		NextLeader = function()
			local n = #(Decks.Leaders or {})
			if n > 0 then leaderIndex = ((leaderIndex or 1) % n) + 1 end
		end,
		TowerFloor = function() return profile and profile.TowerFloor or 1 end,
	})
end

local function openProfile(userId, fromPoint)
	if inMatch or not ProfilePanel then return end
	closePopup()
	ProfilePanel.Open(userId, { From = fromPoint })
end

local function openSettingsFab()
	if inMatch then return end
	closePopup()
	if cb and cb.OpenSettings then cb.OpenSettings() return end
	local SP = tryReq("SettingsPanel")
	if not (SP and SP.Build and MenuKit) then toast("เปิดหน้าตั้งค่าไม่ได้", C.Red) return end
	local w = MenuKit.open({ Title = "ตั้งค่า", Color = C.Gray, MaxSize = Vector2.new(560, 480) })
	local ok, err = pcall(SP.Build, w.Body, {})
	if not ok then
		warn("[FloatHUD] SettingsPanel.Build: " .. tostring(err))
		MenuKit.close()
		toast("เปิดหน้าตั้งค่าไม่ได้", C.Red)
	end
end

-- ===== Public API =====
function FloatHUD.Build(hudGui, overlayGui, callbacks)
	hud, overlay, cb = hudGui, overlayGui, callbacks or {}
	for _, ch in hud:GetChildren() do ch:Destroy() end

	pcall(function() hud.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)

	catcher = Instance.new("TextButton")
	catcher.Name = "ClickAway"
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 5
	catcher.Visible = false
	catcher.Parent = hud
	catcher.Activated:Connect(closePopup)

	gemsLabel = Instance.new("Frame")
	gemsLabel.Name = "GemsBar"
	gemsLabel.BackgroundTransparency = 0
	gemsLabel.BackgroundColor3 = C.Ink
	gemsLabel.AnchorPoint = Vector2.new(0.5, 0)
	gemsLabel.Position = UDim2.new(0.5, 0, 0, 12)
	gemsLabel.Size = UDim2.fromOffset(150, 38)
	gemsLabel.ZIndex = 6
	gemsLabel.Parent = hud
	corner(gemsLabel, UDim.new(0, 12)); stroke(gemsLabel, C.Yellow, 3)

	Icons.image("Coins", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 7,
	}, gemsLabel)

	local txt = label(gemsLabel, "...", C.White, 28)
	txt.Name = "GemsText"
	txt.Position = UDim2.new(0, 36, 0, 0)
	txt.Size = UDim2.new(1, -42, 1, 0)
	txt.TextXAlignment = Enum.TextXAlignment.Center
	txt.ZIndex = 7
	Juice.wobble(gemsLabel, { Amp = 2, Rot = 2, Speed = 1.2 })

	-- ขวา: สู้/เมนู   ซ้าย: เด็ค/กาชา   (เลี่ยงมุมล่างที่เป็นจอยสติ๊ก/ปุ่มกระโดดบนมือถือ)
	-- ===== Main screen (mobile sketch) =====
	-- Top-left: Profile + coins | Right column: More, Card, Shop, Quest, Setting | Bottom-center: Play
	-- Walk stick (bottom-left) and Jump (bottom-right) are Roblox's built-in controls.
	local UIS = game:GetService("UserInputService")
	local RIGHT_IDS = { "More", "Deck", "Gacha", "Quest", "Setting" }

	local function layoutFabs()
		local screen = hud.AbsoluteSize
		local W = screen.X > 0 and screen.X or 1024
		local H = screen.Y > 0 and screen.Y or 720
		local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
		local TAG, GAP = 26, 8
		local edge = math.clamp(math.floor(W * 0.03), 16, 40)
		local top = 60 -- below Roblox's top bar

		-- Profile + coin bar
		local pSize = math.clamp(math.floor(H * 0.14), 48, 72)
		local pX, pY = edge + pSize / 2, top + pSize / 2
		if fabs.Profile then
			fabs.Profile.Size = UDim2.fromOffset(pSize, pSize)
			Juice.setBase(fabs.Profile, UDim2.fromOffset(pX, pY))
		end
		if gemsLabel then
			gemsLabel.AnchorPoint = Vector2.new(0, 0.5)
			Juice.setBase(gemsLabel, UDim2.fromOffset(pX + pSize / 2 + 12, pY))
		end

		-- Right column (2 columns on short screens), kept clear of the jump button
		local reserve = touch and math.floor(H * 0.3) or 24
		local avail = H - top - reserve
		local n, cols = #RIGHT_IDS, 1
		local size = math.floor(avail / n - TAG - GAP)
		if size < 44 then
			cols = 2
			size = math.floor(avail / math.ceil(n / cols) - TAG - GAP)
		end
		size = math.clamp(size, 40, 70)
		for i, id in RIGHT_IDS do
			local b = fabs[id]
			if b then
				local idx = i - 1
				local col = cols == 2 and (idx % 2) or 0
				local r = cols == 2 and math.floor(idx / 2) or idx
			b.Size = UDim2.fromOffset(size, size)
			Juice.setBase(b, UDim2.new(1, -(edge + size / 2 + col * (size + 18)), 0, top + size / 2 + r * (size + TAG + GAP)))
			end
		end

		-- Play (bottom center)
		if fabs.Battle then
			local s = math.clamp(math.floor(H * 0.2), 64, 100)
			fabs.Battle.Size = UDim2.fromOffset(s, s)
			Juice.setBase(fabs.Battle, UDim2.new(0.5, 0, 1, -(s / 2 + TAG + 12)))
		end
	end

	makeFab("More", "Panel", "เมนู", C.Purple, UDim2.new(1, -64, 0, 100), 56, openMore)
	makeFab("Deck", "Sort", "การ์ด", C.Blue, UDim2.new(1, -64, 0, 170), 56, openDeck)
	makeFab("Gacha", "Chest", "ร้านค้า", C.Pink, UDim2.new(1, -64, 0, 240), 56, function(b) openGacha(b) end)
	makeFab("Quest", "Checkmark", "เควสต์", C.Lime, UDim2.new(1, -64, 0, 310), 56, function(b) openQuests(b) end)
	makeFab("Setting", "⚙️", "ตั้งค่า", C.Gray, UDim2.new(1, -64, 0, 380), 56, openSettingsFab)
	makeFab("Battle", "Play", "เล่น!", C.Red, UDim2.new(0.5, 0, 1, -90), 96, openPlay)
	local prof = makeFab("Profile", "Heart", "โปรไฟล์", C.Yellow, UDim2.fromOffset(60, 90), 60, function() openProfile() end)
	moreBadge = makeBadge(fabs.Quest) -- quest "!" badge now sits on the Quest button

	-- Avatar headshot on the Profile button
	task.spawn(function()
		local P = game:GetService("Players")
		local ok, img = pcall(function()
			return P:GetUserThumbnailAsync(P.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and img and prof.Parent then
			local ic = prof:FindFirstChild("Icon")
			if ic then ic.Visible = false end
			local av = Instance.new("ImageLabel")
			av.Name = "Avatar"
			av.BackgroundTransparency = 1
			av.Image = img
			av.Size = UDim2.fromScale(1, 1)
			av.ZIndex = 7
			av.Parent = prof
			corner(av)
		end
	end)

	layoutFabs()

	if PlayerTap then
		PlayerTap.Init(function(userId, point) openProfile(userId, point) end)
	end

	Net.on("ProfileChanged", applyProfile)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		closePopup()
		layoutFabs()
	end)
	FloatHUD.Refresh()
end

-- เรียกจากปุ่มในฉาก 3D (WorldPrompts)
function FloatHUD.Action(action)
	if inMatch or not hud or not hud.Enabled then return end
	if action == "Bot" or action == "Tower" then startMode(action)
	elseif action == "PvP" then togglePvP()
	elseif action == "Gacha" then openGacha(nil)
	elseif action == "Deck" then openDeckBuilder()
	elseif action == "Battle" then openBattle(fabs.Battle)
	elseif action == "Quests" then openQuests(nil)
	elseif action == "Stats" then openStats(nil)
	elseif action == "Farm" then openFarms(nil)
	elseif action == "Emote" or action == "Dance" then
		local DanceEmoteUI = script.Parent:FindFirstChild("DanceEmoteUI")
		if DanceEmoteUI then
			pcall(function() require(DanceEmoteUI).Toggle() end)
		end
	end
end

function FloatHUD.EnterMatch()
	if MenuKit then MenuKit.close() end; if PlayerTap then PlayerTap.SetEnabled(false) end
	inMatch = true
	queueMode = nil
	closePopup()
	closeDeck(false)
	if hud then hud.Enabled = false end
	paintQueue()
end
FloatHUD.ResetQueue = FloatHUD.EnterMatch -- ชื่อเดิม

function FloatHUD.ExitMatch()
	if PlayerTap then PlayerTap.SetEnabled(true) end
	inMatch = false
	if hud then hud.Enabled = true end
	FloatHUD.Refresh()
end

function FloatHUD.Refresh()
	if refreshing then return end
	refreshing = true
	task.spawn(function()
		for _ = 1, 20 do
			if refreshProfile() then break end
			task.wait(1.5)
		end
		refreshing = false
	end)
end

return FloatHUD
-- 🔗 เชื่อมต่อเมนูกับ GlueLobbyHUD
_G.GlueMenu = _G.GlueMenu or {}
_G.GlueMenu.deck = function()
	if DeckBuilder and DeckBuilder.Open then DeckBuilder.Open() end
end
