-- MatchUI: สร้าง UI ทั้งหมดจากโค้ด (ไม่ต้องวางของใน Studio)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local COLORS = {
	bg = Color3.fromRGB(24, 26, 38),
	panel = Color3.fromRGB(38, 42, 62),
	card = Color3.fromRGB(235, 228, 205),
	cardDim = Color3.fromRGB(150, 146, 130),
	text = Color3.fromRGB(245, 245, 250),
	dark = Color3.fromRGB(30, 30, 40),
	good = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(230, 90, 90),
	accent = Color3.fromRGB(255, 190, 70),
	Character = Color3.fromRGB(120, 170, 240),
	Spell = Color3.fromRGB(190, 120, 230),
	Weapon = Color3.fromRGB(230, 140, 80),
	Leader = Color3.fromRGB(240, 210, 90),
}
local GATE_NAMES = {
	Golden = "ทอง x3", Pumped = "พลัง x1.5", Normal = "ปกติ",
	Droopy = "ห่อเหี่ยว x0.5", Poop = "กลายเป็นอึ",
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local gui = make("ScreenGui", {
	Name = "MatchUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local root = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.bg, BorderSizePixel = 0,
}, gui)

-- ===== แถบบน: HP ฝั่งตรงข้าม =====
local oppBar = make("Frame", {
	Size = UDim2.fromScale(1, 0.08), BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
}, root)
local oppHP = make("TextLabel", {
	Size = UDim2.fromScale(0.4, 1), Position = UDim2.fromScale(0.02, 0),
	BackgroundTransparency = 1, TextColor3 = COLORS.bad, TextScaled = true,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Text = "คู่ต่อสู้ HP -",
}, oppBar)
make("UITextSizeConstraint", { MaxTextSize = 28 }, oppHP)
local oppInfo = make("TextLabel", {
	Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.48, 0),
	BackgroundTransparency = 1, TextColor3 = COLORS.text, TextScaled = true,
	Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Text = "ไพ่ในมือ 0",
}, oppBar)
make("UITextSizeConstraint", { MaxTextSize = 22 }, oppInfo)

-- ===== สนามฝั่งตรงข้าม =====
local oppField = make("Frame", {
	Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.1),
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.02, 0),
}, oppField)

local status = make("TextLabel", {
	Size = UDim2.fromScale(0.9, 0.05), Position = UDim2.fromScale(0.05, 0.31),
	BackgroundTransparency = 1, TextColor3 = COLORS.accent, TextScaled = true,
	Font = Enum.Font.GothamBold, Text = "กำลังเริ่มแมตช์...",
}, root)
make("UITextSizeConstraint", { MaxTextSize = 24 }, status)

-- ===== สนามฝั่งเรา + ช่องเกต =====
local myArea = make("Frame", {
	Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.37),
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.02, 0),
}, myArea)

local gateSlot = make("TextButton", {
	Size = UDim2.fromScale(0.16, 0.9), BackgroundColor3 = COLORS.panel, AutoButtonColor = true,
	Text = "เกต\n(แตะเพื่อวาง)", TextColor3 = COLORS.accent, TextScaled = true,
	Font = Enum.Font.GothamBold, LayoutOrder = 0,
}, myArea)
corner(gateSlot)
make("UIStroke", { Color = COLORS.accent, Thickness = 2 }, gateSlot)
make("UITextSizeConstraint", { MaxTextSize = 18 }, gateSlot)

local fieldSlots = make("Frame", {
	Size = UDim2.fromScale(0.7, 0.9), BackgroundTransparency = 1, LayoutOrder = 1,
}, myArea)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.03, 0),
}, fieldSlots)

-- ===== มือ =====
local handFrame = make("Frame", {
	Size = UDim2.fromScale(0.96, 0.25), Position = UDim2.fromScale(0.02, 0.6),
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.015, 0),
}, handFrame)

-- ===== แถบล่าง: HP/พอยต์/ปุ่มจบเทิร์น =====
local bottom = make("Frame", {
	Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 0.88),
	BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
}, root)
local myHP = make("TextLabel", {
	Size = UDim2.fromScale(0.28, 1), Position = UDim2.fromScale(0.02, 0),
	BackgroundTransparency = 1, TextColor3 = COLORS.good, TextScaled = true,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Text = "HP -",
}, bottom)
make("UITextSizeConstraint", { MaxTextSize = 30 }, myHP)
local myPoints = make("TextLabel", {
	Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(0.32, 0),
	BackgroundTransparency = 1, TextColor3 = COLORS.accent, TextScaled = true,
	Font = Enum.Font.GothamBold, Text = "พอยต์ -",
}, bottom)
make("UITextSizeConstraint", { MaxTextSize = 30 }, myPoints)
local endBtn = make("TextButton", {
	Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.67, 0.15),
	BackgroundColor3 = COLORS.good, TextColor3 = COLORS.dark, TextScaled = true,
	Font = Enum.Font.GothamBold, Text = "จบเทิร์น",
}, bottom)
corner(endBtn)
make("UITextSizeConstraint", { MaxTextSize = 26 }, endBtn)

-- ===== หน้าจอจบเกม =====
local endScreen = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.3, Visible = false, ZIndex = 50,
}, gui)
local endText = make("TextLabel", {
	Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.1, 0.35),
	BackgroundTransparency = 1, TextColor3 = COLORS.text, TextScaled = true,
	Font = Enum.Font.GothamBlack, Text = "", ZIndex = 51,
}, endScreen)
make("UITextSizeConstraint", { MaxTextSize = 60 }, endText)

-- ===== ตัวช่วยสร้างการ์ด =====
local state = nil
local selectedIndex = nil

local function cardView(card, parent, opts)
	opts = opts or {}
	local btn = make("TextButton", {
		Size = opts.size or UDim2.fromScale(0.17, 0.95),
		BackgroundColor3 = opts.dim and COLORS.cardDim or COLORS.card,
		Text = "", AutoButtonColor = opts.clickable or false,
		LayoutOrder = opts.order or 0,
	}, parent)
	corner(btn)
	if opts.selected then
		make("UIStroke", { Color = COLORS.accent, Thickness = 4 }, btn)
	else
		make("UIStroke", { Color = COLORS[card.Type] or COLORS.dark, Thickness = 2 }, btn)
	end
	make("UIAspectRatioConstraint", { AspectRatio = 0.7 }, btn)

	make("TextLabel", {
		Size = UDim2.fromScale(0.3, 0.22), Position = UDim2.fromScale(0.03, 0.03),
		BackgroundColor3 = COLORS.accent, TextColor3 = COLORS.dark, TextScaled = true,
		Font = Enum.Font.GothamBold, Text = tostring(card.Cost or 0),
	}, btn)
	local nm = make("TextLabel", {
		Size = UDim2.fromScale(0.94, 0.4), Position = UDim2.fromScale(0.03, 0.28),
		BackgroundTransparency = 1, TextColor3 = COLORS.dark, TextScaled = true,
		Font = Enum.Font.GothamBold, TextWrapped = true, Text = card.Name or "?",
	}, btn)
	make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, nm)
	if card.Type == "Character" then
		make("TextLabel", {
			Size = UDim2.fromScale(0.94, 0.25), Position = UDim2.fromScale(0.03, 0.72),
			BackgroundTransparency = 1, TextColor3 = COLORS.dark, TextScaled = true,
			Font = Enum.Font.GothamBold,
			Text = string.format("ATK %d  HP %d", card.ATK or 0, card.HP or 0),
		}, btn)
	else
		make("TextLabel", {
			Size = UDim2.fromScale(0.94, 0.25), Position = UDim2.fromScale(0.03, 0.72),
			BackgroundTransparency = 1, TextColor3 = COLORS[card.Type] or COLORS.dark,
			TextScaled = true, Font = Enum.Font.GothamBold, Text = card.Type,
		}, btn)
	end
	return btn
end

local function clear(frame)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or COLORS.accent
end

local function tryPlay(handIndex, target)
	local ok, result, reason = pcall(function()
		return Remotes.PlayCard:InvokeServer(handIndex, target)
	end)
	selectedIndex = nil
	if not ok then
		setStatus("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้", COLORS.bad)
	elseif result == false then
		local msgs = {
			NOT_YOUR_TURN = "ยังไม่ใช่เทิร์นของคุณ",
			NOT_ENOUGH_POINTS = "พอยต์ไม่พอ",
			GATE_OCCUPIED = "ช่องเกตมีการ์ดอยู่แล้ว",
			FIELD_FULL = "สนามเต็มแล้ว",
			INVALID_CARD = "การ์ดไม่ถูกต้อง",
		}
		setStatus(msgs[reason] or "เล่นการ์ดไม่ได้", COLORS.bad)
	end
end

local render
render = function()
	if not state then return end
	myHP.Text = "HP " .. state.myHP
	myPoints.Text = string.format("พอยต์ %d/%d", state.myPoints, Config.MAX_BANKED_POINTS)
	oppHP.Text = "คู่ต่อสู้ HP " .. state.oppHP
	oppInfo.Text = string.format("ไพ่ในมือ %d%s", state.oppHandCount, state.oppGateFilled and "  | เกตมีการ์ด" or "")

	if state.isMyTurn then
		setStatus("เทิร์นของคุณ", COLORS.good)
		endBtn.BackgroundColor3 = COLORS.good
		endBtn.Text = "จบเทิร์น"
	else
		setStatus("เทิร์นของคู่ต่อสู้...", COLORS.cardDim)
		endBtn.BackgroundColor3 = COLORS.cardDim
		endBtn.Text = "รอ..."
	end

	-- มือ
	clear(handFrame)
	for i, card in state.myHand do
		local b = cardView(card, handFrame, {
			clickable = true, order = i, selected = (selectedIndex == i),
			dim = card.Cost > state.myPoints,
		})
		b.Activated:Connect(function()
			if not state.isMyTurn then
				setStatus("ยังไม่ใช่เทิร์นของคุณ", COLORS.bad)
				return
			end
			if card.Type ~= "Character" then
				setStatus("การ์ดประเภทนี้ยังไม่รองรับ (TODO CardEffects)", COLORS.bad)
				return
			end
			if selectedIndex == i then selectedIndex = nil else selectedIndex = i end
			if selectedIndex then
				setStatus("เลือกแล้ว: แตะสนามเพื่อวาง หรือแตะเกตเพื่อลด 1 พอยต์", COLORS.accent)
			end
			render()
		end)
	end

	-- สนามเรา
	clear(fieldSlots)
	for i = 1, Config.FIELD_SLOTS do
		local card = state.myField[i]
		if card then
			cardView(card, fieldSlots, { size = UDim2.fromScale(0.3, 0.95), order = i, dim = not card.CanAttack })
		else
			local empty = make("TextButton", {
				Size = UDim2.fromScale(0.3, 0.95), BackgroundColor3 = COLORS.panel,
				Text = "ว่าง", TextColor3 = COLORS.cardDim, TextScaled = true,
				Font = Enum.Font.Gotham, LayoutOrder = i,
			}, fieldSlots)
			corner(empty)
			make("UIAspectRatioConstraint", { AspectRatio = 0.7 }, empty)
			empty.Activated:Connect(function()
				if selectedIndex then tryPlay(selectedIndex, "Field") end
			end)
		end
	end

	-- ช่องเกต
	for _, c in gateSlot:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if state.myGate then
		gateSlot.Text = ""
		cardView(state.myGate, gateSlot, { size = UDim2.fromScale(0.9, 0.9) }).Position = UDim2.fromScale(0.05, 0.05)
	else
		gateSlot.Text = "เกต\n(แตะเพื่อวาง)"
	end

	-- สนามคู่ต่อสู้
	clear(oppField)
	for i, card in state.oppField do
		cardView(card, oppField, { size = UDim2.fromScale(0.2, 0.95), order = i })
	end
end

gateSlot.Activated:Connect(function()
	if selectedIndex then tryPlay(selectedIndex, "Gate") end
end)

endBtn.Activated:Connect(function()
	if state and state.isMyTurn then
		selectedIndex = nil
		Remotes.EndTurn:FireServer()
	end
end)

Remotes.StateUpdate.OnClientEvent:Connect(function(newState)
	state = newState
	if selectedIndex and not state.myHand[selectedIndex] then selectedIndex = nil end
	render()
end)

Remotes.GateRolled.OnClientEvent:Connect(function(userId, card, outcomeId)
	local who = (userId == player.UserId) and "เกตของคุณ" or "เกตของคู่ต่อสู้"
	setStatus(string.format("%s: %s (%s)", who, card.Name or "?", GATE_NAMES[outcomeId] or outcomeId),
		outcomeId == "Poop" and COLORS.bad or COLORS.accent)
end)

Remotes.MatchEnded.OnClientEvent:Connect(function(winnerId, reason)
	local won = winnerId == player.UserId
	endText.Text = won and "คุณชนะ!" or "คุณแพ้"
	endText.TextColor3 = won and COLORS.good or COLORS.bad
	endScreen.Visible = true
	TweenService:Create(endScreen, TweenInfo.new(0.4), { BackgroundTransparency = 0.3 }):Play()
end)
