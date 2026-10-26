-- StarterPlayerScripts/UIClient/FloatHUD.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Decks = require(Shared:WaitForChild("Decks"))
local CardData = require(Shared:WaitForChild("CardData"))
local Net = require(script.Parent:WaitForChild("Net"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local DeckBuilder
do
	local m = script.Parent:FindFirstChild("DeckBuilder")
	if m then local ok, r = pcall(require, m); if ok then DeckBuilder = r end end
end

local C = {
	Red = Color3.fromRGB(255, 70, 100), Pink = Color3.fromRGB(255, 90, 200), Lime = Color3.fromRGB(150, 255, 90),
	Orange = Color3.fromRGB(255, 150, 40), Yellow = Color3.fromRGB(255, 220, 60), Blue = Color3.fromRGB(80, 170, 255),
	Purple = Color3.fromRGB(150, 90, 255), Panel = Color3.fromRGB(58, 24, 130), Ink = Color3.fromRGB(25, 10, 45),
	White = Color3.new(1, 1, 1), Gray = Color3.fromRGB(150, 150, 170),
}
local RARITY = { Common = C.Gray, Rare = C.Blue, Epic = C.Purple, Legend = C.Yellow, Legendary = C.Yellow }

local FloatHUD = {}
FloatHUD.C = C

-- ===== state =====
local hud, overlay, catcher, gemsLabel, deckWindow
local profile = nil
local leaderIndex = 1
local queueMode = nil
local openPopup, openOwner = nil, nil
local fabs, extras = {}, {}

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

local function toast(text, color)
	if not overlay then return end
	local lb = label(overlay, text, C.White, 44)
	lb.AnchorPoint = Vector2.new(0.5, 0)
	lb.Position = UDim2.new(0.5, 0, 0, 64)
	lb.Size = UDim2.fromOffset(380, 44)
	lb.BackgroundTransparency = 0
	lb.BackgroundColor3 = color or C.Purple
	lb.ZIndex = 100
	corner(lb, UDim.new(0, 12)); stroke(lb, C.Ink, 3)
	Juice.popIn(lb)
	task.delay(2, function() Juice.popOut(lb, function() lb:Destroy() end) end)
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

-- ===== popup core =====
local function closePopup()
	if not openPopup then return end
	local p = openPopup
	openPopup, openOwner = nil, nil
	catcher.Visible = false
	Juice.popOut(p, function() p:Destroy() end)
end
FloatHUD.Close = closePopup

local function ownerCenter(owner)
	if not owner then return hud.AbsoluteSize / 2 end
	return owner.AbsolutePosition + owner.AbsoluteSize / 2 - hud.AbsolutePosition
end

local function openPanel(owner, opts)
	closePopup()
	local p = Instance.new("Frame")
	p.Name = "FloatPanel"
	p.AutomaticSize = Enum.AutomaticSize.Y
	p.Size = UDim2.fromOffset(opts.Width or 250, 0)
	p.AnchorPoint = opts.Anchor or Vector2.new(0.5, 0.5)
	local c = ownerCenter(owner) + (opts.Offset or Vector2.zero)
	p.Position = UDim2.fromOffset(c.X, c.Y)
	p.BackgroundColor3 = C.Panel
	p.ZIndex = 10
	p.Parent = hud
	corner(p, UDim.new(0, 16)); stroke(p, opts.Color or C.Yellow, 4)
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do pad[k] = UDim.new(0, 10) end
	pad.Parent = p
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = p
	label(p, opts.Title, opts.Color or C.Yellow, 30).LayoutOrder = 0
	opts.Build(p)
	Juice.popIn(p)
	openPopup, openOwner = p, owner
	catcher.Visible = true
	return p
end

local function row(parent, order, text, color, fn)
	local b = blobButton(parent, text, color, UDim2.new(1, 0, 0, 46), fn)
	b.AnchorPoint = Vector2.zero
	b.LayoutOrder = order
	return b
end

local function openRadial(owner, items, radius, a0, a1)
	closePopup()
	local holder = Instance.new("Frame")
	holder.Name = "Radial"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	local c = ownerCenter(owner)
	holder.Position = UDim2.fromOffset(c.X, c.Y)
	holder.ZIndex = 10
	holder.Parent = hud
	local n = #items
	for i, it in items do
		local t = (n == 1) and 0.5 or (i - 1) / (n - 1)
		local a = math.rad(a0 + (a1 - a0) * t)
		local b
		b = blobButton(holder, it.Text, it.Color, UDim2.fromOffset(160, 48), function()
			if not it.Keep then closePopup() end
			it.OnClick(b)
		end)
		b.Position = UDim2.fromOffset(math.cos(a) * radius, math.sin(a) * radius)
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
	fab.Icon.Text = queueMode and "⏳" or "⚔️"
	fab.Tag.Text = queueMode and "กำลังหา..." or "สู้!"
	fab.BackgroundColor3 = queueMode and C.Pink or C.Red
end

local function startMode(mode)
	if queueMode == "PvP" and mode ~= "PvP" then
		toast("ยกเลิกการหา PvP ก่อนนะ", C.Orange)
		return
	end
	closePopup()
	local ok, status = Net.invokeLocked("queue", "Queue", mode, leaderId())
	if not ok then toast(Net.message(status), C.Red); return end
	-- ถ้าแมตช์เริ่มไปแล้ว hud จะถูกปิด (OnStart) → ไม่ต้องตั้งสถานะรอ
	if mode == "PvP" and hud.Enabled then
		queueMode = "PvP"
		toast("🌐 กำลังหาคู่ต่อสู้...", C.Pink)
	end
	paintQueue()
end

local function togglePvP()
	if queueMode == "PvP" then
		local ok, status = Net.invokeLocked("queue", "Queue", "Cancel")
		if ok then queueMode = nil; toast("ยกเลิกการค้นหาแล้ว", C.Gray)
		else toast(Net.message(status), C.Red) end
		paintQueue()
	else
		startMode("PvP")
	end
end

local function openBattle(owner)
	local leaders = Decks.Leaders or {}
	openRadial(owner, {
		{ Text = "👑 " .. leaderName(), Color = C.Yellow, Keep = true, OnClick = function(b)
			if #leaders == 0 then return end
			leaderIndex = leaderIndex % #leaders + 1
			b.Text = "👑 " .. leaderName()
		end },
		{ Text = "🤖 ซ้อมบอท", Color = C.Lime, OnClick = function() startMode("Bot") end },
		{ Text = queueMode == "PvP" and "❌ ยกเลิกหา" or "🌐 PvP", Color = C.Pink, OnClick = togglePvP },
		{ Text = ("🗼 หอคอย %d"):format(profile and profile.TowerFloor or 1), Color = C.Orange,
			OnClick = function() startMode("Tower") end },
	}, 140, 125, 235) -- กางออกทางซ้ายของปุ่ม
end

-- ===== Gacha =====
local function showPulls(results)
	openPanel(nil, { Title = "🎉 ได้การ์ด!", Color = C.Pink, Width = 520, Build = function(p)
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = 1
		grid.Parent = p
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(92, 60)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gl.Parent = grid
		for i, r in results do
			local id = typeof(r) == "table" and (r.Id or r.CardId or r.id) or r
			local def = cardDef(id)
			local rar = (typeof(r) == "table" and r.Rarity) or (def and def.Rarity) or "Common"
			local isNew = typeof(r) == "table" and r.New
			local chip = label(grid, (def and def.Name or tostring(id)) .. (isNew and "\nNEW!" or ""), C.Ink)
			chip.BackgroundTransparency = 0
			chip.BackgroundColor3 = RARITY[rar] or C.Gray
			corner(chip, UDim.new(0, 10)); stroke(chip, C.Ink, 2)
			Juice.popIn(chip, i * 0.08)
			if rar == "Epic" or rar == "Legend" or rar == "Legendary" then
				task.delay(i * 0.08 + 0.2, function() if chip.Parent then Juice.burstOn(chip, nil, RARITY[rar]) end end)
			end
		end
		label(p, "แตะที่ว่างเพื่อปิด", C.Gray, 20).LayoutOrder = 2
	end })
end

local function pull(count)
	local ok, results = Net.invokeLocked("gacha", "Gacha", count)
	if not ok then toast(Net.message(results), C.Red); return end
	showPulls(typeof(results) == "table" and results or {})
end

local function openGacha(owner)
	openPanel(owner, {
		Title = "🎰 กาชาเกลือ", Color = C.Pink,
		Anchor = owner and Vector2.new(0, 0.5) or nil, Offset = owner and Vector2.new(56, 0) or nil,
		Build = function(p)
			row(p, 1, ("สุ่ม 1 ครั้ง  💎 %d"):format(Config.GACHA_COST_1 or 0), C.Pink, function() pull(1) end)
			row(p, 2, ("สุ่ม 10 ครั้ง  💎 %d"):format(Config.GACHA_COST_10 or 0), C.Lime, function() pull(10) end)
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

local function openDeckBuilder()
	closePopup()
	if not DeckBuilder then toast("🚧 ยังไม่มีระบบจัดเด็ค", C.Orange); return end
	if deckWindow then deckWindow:Destroy() end
	local win = Instance.new("Frame")
	win.Name = "DeckWindow"
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromScale(0.72, 0.78)
	win.BackgroundTransparency = 1
	win.Parent = overlay
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(900, 620)
	lim.Parent = win
	deckWindow = win
	local function close()
		if deckWindow == win then deckWindow = nil end
		Juice.popOut(win, function() win:Destroy() end)
		FloatHUD.Refresh()
	end
	local x = blobButton(win, "✕", C.Red, UDim2.fromOffset(44, 44), close)
	x.Position = UDim2.new(1, 0, 0, 0)
	x.ZIndex = 20
	if not profile then toast("กำลังโหลดข้อมูล รอแป๊บนึง...", C.Orange); close(); return end
	-- opts ตรงกับที่ LobbyUI เดิมส่งให้ DeckBuilder.Open
	DeckBuilder.Open(win, { Cards = CardData, Owned = profile.Collection, Deck = profile.Deck,
		Message = Net.message,
		OnSave = function(ids)
			local ok, err = Net.invoke("SaveDeck", ids)
			if ok then FloatHUD.Refresh() end
			return ok, err
		end })
	Juice.popIn(win)
end

local function openDeck(owner)
	openPanel(owner, {
		Title = "🃏 เด็คของคุณ", Color = C.Blue,
		Anchor = Vector2.new(0, 0.5), Offset = Vector2.new(56, 0),
		Build = function(p)
			label(p, ("ในเด็ค: %d ใบ"):format(deckCount()), C.White, 24).LayoutOrder = 1
			row(p, 2, "✏️ จัดเด็ค", C.Yellow, openDeckBuilder)
		end,
	})
end

-- ===== ☰ อื่นๆ (เสียบเมนูเพิ่มได้) =====
function FloatHUD.AddMenuItem(text, color, fn)
	table.insert(extras, { Text = text, Color = color or C.Lime, OnClick = fn })
end
local function openMore(owner)
	openPanel(owner, {
		Title = "☰ อื่นๆ", Color = C.Purple,
		Anchor = Vector2.new(1, 0.5), Offset = Vector2.new(-56, 0),
		Build = function(p)
			if #extras == 0 then label(p, "ยังไม่มีเมนูเพิ่ม", C.Gray, 22).LayoutOrder = 1 end
			for i, it in extras do row(p, i, it.Text, it.Color, function() closePopup(); it.OnClick() end) end
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

	local ic = label(b, icon, C.White)
	ic.Name = "Icon"
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.45)
	ic.Size = UDim2.fromScale(0.62, 0.62)

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

-- ===== profile =====
local function applyProfile(snap)
	if typeof(snap) ~= "table" then return end
	local old = profile and profile.Gems
	profile = snap
	if gemsLabel then
		gemsLabel.Text = ("💎 %d"):format(snap.Gems or 0)
		if old and old ~= snap.Gems then Juice.squish(gemsLabel) end
	end
end
local function refreshProfile()
	local a, b = Net.invoke("GetProfile")
	local snap = (typeof(a) == "table" and a) or (typeof(b) == "table" and b) or nil
	if snap then applyProfile(snap); return true end
	return false
end

-- ===== Public API =====
function FloatHUD.Build(hudGui, overlayGui)
	hud, overlay = hudGui, overlayGui
	for _, ch in hud:GetChildren() do ch:Destroy() end

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

	gemsLabel = label(hud, "💎 ...", C.White, 40)
	gemsLabel.BackgroundTransparency = 0
	gemsLabel.BackgroundColor3 = C.Ink
	gemsLabel.AnchorPoint = Vector2.new(0.5, 0)
	gemsLabel.Position = UDim2.new(0.5, 0, 0, 12)
	gemsLabel.Size = UDim2.fromOffset(170, 40)
	gemsLabel.ZIndex = 6
	corner(gemsLabel, UDim.new(0, 12)); stroke(gemsLabel, C.Yellow, 3)
	Juice.wobble(gemsLabel, { Amp = 2, Rot = 2, Speed = 1.2 })

	makeFab("Battle", "⚔️", "สู้!", C.Red, UDim2.new(1, -75, 0.5, 20), 96, openBattle)
	makeFab("More", "☰", "อื่นๆ", C.Purple, UDim2.new(1, -75, 0.5, -105), 64, openMore)
	makeFab("Deck", "🃏", "เด็ค", C.Blue, UDim2.new(0, 70, 0.5, -55), 76, openDeck)
	makeFab("Gacha", "🎰", "กาชา", C.Pink, UDim2.new(0, 70, 0.5, 60), 76, openGacha)

	Net.on("ProfileChanged", applyProfile)
	FloatHUD.Refresh()
end

-- เรียกจากปุ่มในฉาก 3D (WorldPrompts)
function FloatHUD.Action(action)
	if not hud or not hud.Enabled then return end
	if action == "Bot" or action == "Tower" then startMode(action)
	elseif action == "PvP" then togglePvP()
	elseif action == "Gacha" then openGacha(nil)
	elseif action == "Deck" then openDeckBuilder()
	elseif action == "Battle" then openBattle(fabs.Battle)
	end
end

function FloatHUD.ResetQueue()
	queueMode = nil
	closePopup()
	if deckWindow then deckWindow:Destroy(); deckWindow = nil end
	paintQueue()
end

function FloatHUD.Refresh()
	task.spawn(function()
		for _ = 1, 20 do
			if refreshProfile() then break end
			task.wait(1.5)
		end
	end)
end

return FloatHUD