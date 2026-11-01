-- StarterPlayer/StarterPlayerScripts/UIClient/DanceEmoteUI.lua
-- Responsive, touch-optimized Dance & Emote interface with 200 animations and Pasulol styling
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UI"):WaitForChild("UIKit"))
local Style = require(Shared:WaitForChild("UI"):WaitForChild("Style"))
local Icons = require(Shared:WaitForChild("UI"):WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local player = Players.LocalPlayer
local C = Style.C

local DanceEmoteUI = {}

local screenGui = nil
local catcher = nil
local window = nil
local searchBox = nil
local clearSearchBtn = nil
local scrollList = nil
local stopBar = nil
local statusLabel = nil
local danceItems = {}

local currentTrack = nil
local currentDanceName = nil
local registeredCache = {}
local dances = {}
local isLoaded = false
local isOpen = false

-- ===== Animation Engine =====
local function stopDance()
	if currentTrack then
		pcall(function()
			currentTrack:Stop(0.2)
			currentTrack:Destroy()
		end)
		currentTrack = nil
		currentDanceName = nil
	end
	if stopBar then
		stopBar.Visible = false
	end
	if statusLabel then
		statusLabel.Text = "เลือกท่าเต้นที่ต้องการ"
		statusLabel.TextColor3 = C.TextDim
	end
	for btn, item in pairs(danceItems) do
		if btn and btn.Parent then
			btn.BackgroundColor3 = Color3.fromRGB(28, 14, 52)
			local activeIcon = btn:FindFirstChild("ActiveIcon")
			if activeIcon then activeIcon.Visible = false end
		end
	end
end

DanceEmoteUI.StopDance = stopDance

local function playDance(kfs, cleanName, btn)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	stopDance()

	local animId = registeredCache[kfs]
	if not animId then
		local ok, res = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
		end)
		if ok and res then
			animId = res
			registeredCache[kfs] = res
		else
			warn("[DanceEmoteUI] ลงทะเบียนท่าเต้นไม่สำเร็จ:", kfs.Name, res)
			return
		end
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		currentTrack = track
		currentDanceName = cleanName

		if stopBar then
			stopBar.Visible = true
			local nameLbl = stopBar:FindFirstChild("DanceName")
			if nameLbl then
				nameLbl.Text = "กำลังเต้น: " .. cleanName
			end
		end
		if statusLabel then
			statusLabel.Text = "กำลังเต้น: " .. cleanName
			statusLabel.TextColor3 = C.Accent
		end

		if btn and btn.Parent then
			btn.BackgroundColor3 = Color3.fromRGB(80, 32, 140)
			local activeIcon = btn:FindFirstChild("ActiveIcon")
			if activeIcon then activeIcon.Visible = true end
			Juice.burstOn(btn, nil, C.Accent)
		end
	end
end

-- Stop dance on movement or death
local function bindCharacter(char)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Running:Connect(function(speed)
			if speed > 1 and currentTrack then
				stopDance()
			end
		end)
		humanoid.Died:Connect(function()
			stopDance()
		end)
	end
end

if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

-- ===== Load Dances from Workspace or ReplicatedStorage =====
local function findAnimSaves()
	local wsMain = Workspace:FindFirstChild("MAIN ANIM")
	if wsMain and wsMain:FindFirstChild("AnimSaves") then
		return wsMain.AnimSaves
	end
	local rsMain = ReplicatedStorage:FindFirstChild("MAIN ANIM")
	if rsMain and rsMain:FindFirstChild("AnimSaves") then
		return rsMain.AnimSaves
	end
	return nil
end

local function loadDances()
	if isLoaded then return end
	local animSaves = findAnimSaves()
	if not animSaves then
		task.delay(2, loadDances)
		return
	end

	local list = {}
	for _, child in ipairs(animSaves:GetChildren()) do
		if child:IsA("KeyframeSequence") then
			local cleanName = child.Name:gsub("%[NEW%!%]", ""):gsub("%[UPDATED%!%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
			table.insert(list, {
				instance = child,
				cleanName = cleanName,
				lowerName = cleanName:lower(),
			})
		end
	end

	table.sort(list, function(a, b)
		return a.lowerName < b.lowerName
	end)

	dances = list
	isLoaded = true
	DanceEmoteUI.RenderList("")
end

-- ===== Render Filtered Dance List =====
function DanceEmoteUI.RenderList(query)
	if not scrollList then return end
	danceItems = {}

	for _, c in ipairs(scrollList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end

	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local count = 0

	for i, item in ipairs(dances) do
		if query == "" or string.find(item.lowerName, query, 1, true) then
			count = count + 1
			local isPlaying = (currentDanceName == item.cleanName)

			local btn = Instance.new("TextButton")
			btn.Name = string.format("%03d_%s", i, item.cleanName)
			btn.AutoButtonColor = false
			btn.Size = UDim2.new(1, -4, 0, 44) -- 44px min touch target
			btn.BackgroundColor3 = isPlaying and Color3.fromRGB(80, 32, 140) or Color3.fromRGB(28, 14, 52)
			btn.Text = ""
			btn.LayoutOrder = i
			btn.ZIndex = 22
			btn.Parent = scrollList

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = btn

			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = isPlaying and C.Accent or Color3.fromRGB(56, 30, 96)
			stroke.Thickness = isPlaying and 2 or 1
			stroke.Parent = btn

			-- Play icon on left
			local playIcon = Icons.image("Play", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				ZIndex = 23,
			}, btn)

			-- Dance Name
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Position = UDim2.new(0, 40, 0, 0)
			lbl.Size = UDim2.new(1, -85, 1, 0)
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 13
			lbl.TextColor3 = isPlaying and C.Accent or C.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextWrapped = true
			lbl.Text = item.cleanName
			lbl.ZIndex = 23
			lbl.Parent = btn

			-- Active checkmark on right
			local activeIcon = Icons.image("Checkmark", {
				Name = "ActiveIcon",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				Visible = isPlaying,
				ZIndex = 23,
			}, btn)

			Juice.bind(btn)
			btn.Activated:Connect(function()
				playDance(item.instance, item.cleanName, btn)
			end)

			danceItems[btn] = item
		end
	end

	if count == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.Font = Style.Font.Medium
		empty.TextSize = 14
		empty.TextColor3 = C.TextDim
		empty.Text = "ไม่พบท่าเต้นที่ค้นหา"
		empty.ZIndex = 23
		empty.Parent = scrollList
	end
end

-- ===== Build Responsive UI =====
function DanceEmoteUI.Build(parent)
	local targetParent = parent or player:WaitForChild("PlayerGui")
	local existing = targetParent:FindFirstChild("DanceEmoteGui")
	if existing then
		existing:Destroy()
	end
	if screenGui and screenGui.Parent then
		screenGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DanceEmoteGui"
	screenGui.DisplayOrder = 15
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	pcall(function() screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	screenGui.Parent = targetParent

	-- ClickAway / Backdrop
	catcher = Instance.new("TextButton")
	catcher.Name = "ClickAway"
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.BackgroundTransparency = 0.5
	catcher.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 20
	catcher.Visible = false
	catcher.Parent = screenGui
	catcher.Activated:Connect(DanceEmoteUI.Close)

	-- Window
	window = Instance.new("TextButton")
	window.Name = "EmoteWindow"
	window.Text = ""
	window.AutoButtonColor = false
	window.Selectable = false
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(0.9, 0, 0.82, 0)
	window.BackgroundColor3 = Color3.fromRGB(36, 16, 74)
	window.ZIndex = 21
	window.Visible = false
	window.Parent = screenGui

	local winCorner = Instance.new("UICorner")
	winCorner.CornerRadius = UDim.new(0, 18)
	winCorner.Parent = window

	local winStroke = Instance.new("UIStroke")
	winStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	winStroke.Color = Color3.fromRGB(255, 220, 60)
	winStroke.Thickness = 3
	winStroke.Parent = window

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 260)
	sizeConstraint.MaxSize = Vector2.new(460, 580)
	sizeConstraint.Parent = window

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = window

	-- Top Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 38)
	titleBar.ZIndex = 22
	titleBar.Parent = window

	Icons.image("Play", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 23,
	}, titleBar)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 34, 0, 0)
	title.Size = UDim2.new(1, -78, 1, 0)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 230, 80)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ท่าเต้น (200+)"
	title.ZIndex = 22
	title.Parent = titleBar

	-- Close Button with Icons.Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.AutoButtonColor = false
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = Color3.fromRGB(42, 18, 72)
	closeBtn.Text = ""
	closeBtn.ZIndex = 23
	closeBtn.Parent = titleBar

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(1, 0)
	cCorner.Parent = closeBtn

	local cStroke = Instance.new("UIStroke")
	cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cStroke.Color = Color3.fromRGB(255, 220, 60)
	cStroke.Thickness = 2
	cStroke.Parent = closeBtn

	Icons.image("Close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 24,
	}, closeBtn)

	Juice.bind(closeBtn)
	closeBtn.Activated:Connect(DanceEmoteUI.Close)

	-- Search Bar
	local searchFrame = Instance.new("Frame")
	searchFrame.Name = "SearchFrame"
	searchFrame.Position = UDim2.new(0, 0, 0, 44)
	searchFrame.Size = UDim2.new(1, 0, 0, 38)
	searchFrame.BackgroundColor3 = Color3.fromRGB(22, 10, 42)
	searchFrame.ZIndex = 22
	searchFrame.Parent = window

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 10)
	sCorner.Parent = searchFrame

	local sStroke = Instance.new("UIStroke")
	sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sStroke.Color = Color3.fromRGB(60, 34, 105)
	sStroke.Thickness = 1.5
	sStroke.Parent = searchFrame

	searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.BackgroundTransparency = 1
	searchBox.Position = UDim2.new(0, 12, 0, 0)
	searchBox.Size = UDim2.new(1, -44, 1, 0)
	searchBox.Font = Enum.Font.GothamMedium
	searchBox.TextSize = 13
	searchBox.TextColor3 = Color3.new(1, 1, 1)
	searchBox.PlaceholderText = "ค้นหาท่าเต้น..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(160, 140, 200)
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.ZIndex = 23
	searchBox.Parent = searchFrame

	clearSearchBtn = Instance.new("TextButton")
	clearSearchBtn.Name = "ClearSearch"
	clearSearchBtn.BackgroundTransparency = 1
	clearSearchBtn.AnchorPoint = Vector2.new(1, 0.5)
	clearSearchBtn.Position = UDim2.new(1, -6, 0.5, 0)
	clearSearchBtn.Size = UDim2.fromOffset(26, 26)
	clearSearchBtn.Text = ""
	clearSearchBtn.Font = Enum.Font.GothamBold
	clearSearchBtn.TextSize = 13
	clearSearchBtn.TextColor3 = Color3.fromRGB(180, 160, 220)
	clearSearchBtn.Visible = false
	clearSearchBtn.ZIndex = 24
	clearSearchBtn.Parent = searchFrame

	Icons.image("Close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 25,
	}, clearSearchBtn)

	clearSearchBtn.Activated:Connect(function()
		searchBox.Text = ""
		clearSearchBtn.Visible = false
		DanceEmoteUI.RenderList("")
	end)

	local searchDebounce = 0
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = searchBox.Text
		clearSearchBtn.Visible = (#query > 0)
		searchDebounce = searchDebounce + 1
		local cur = searchDebounce
		task.delay(0.12, function()
			if searchDebounce == cur then
				DanceEmoteUI.RenderList(query)
			end
		end)
	end)

	-- Subtitle / Status
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.new(0, 2, 0, 86)
	statusLabel.Size = UDim2.new(1, -4, 0, 20)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = C.TextDim
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = "เลือกท่าเต้นที่ต้องการ"
	statusLabel.ZIndex = 22
	statusLabel.Parent = window

	-- Dance Scroll List
	scrollList = Instance.new("ScrollingFrame")
	scrollList.Name = "DanceList"
	scrollList.BackgroundTransparency = 1
	scrollList.BorderSizePixel = 0
	scrollList.Position = UDim2.new(0, 0, 0, 110)
	scrollList.Size = UDim2.new(1, 0, 1, -164)
	scrollList.ScrollBarThickness = 6
	scrollList.ScrollBarImageColor3 = Color3.fromRGB(180, 100, 255)
	scrollList.CanvasSize = UDim2.new()
	scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollList.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollList.ZIndex = 22
	scrollList.Parent = window

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = scrollList

	-- Bottom Stop Dance Bar
	stopBar = Instance.new("Frame")
	stopBar.Name = "StopBar"
	stopBar.AnchorPoint = Vector2.new(0.5, 1)
	stopBar.Position = UDim2.new(0.5, 0, 1, 0)
	stopBar.Size = UDim2.new(1, 0, 0, 46)
	stopBar.BackgroundColor3 = Color3.fromRGB(24, 10, 44)
	stopBar.Visible = (currentTrack ~= nil)
	stopBar.ZIndex = 23
	stopBar.Parent = window

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 10)
	sbCorner.Parent = stopBar

	local sbStroke = Instance.new("UIStroke")
	sbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sbStroke.Color = Color3.fromRGB(80, 40, 120)
	sbStroke.Thickness = 1.5
	sbStroke.Parent = stopBar

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "DanceName"
	nameLbl.BackgroundTransparency = 1
	nameLbl.Position = UDim2.new(0, 12, 0, 0)
	nameLbl.Size = UDim2.new(1, -140, 1, 0)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 12
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Text = currentDanceName and ("กำลังเต้น: " .. currentDanceName) or "กำลังเต้น..."
	nameLbl.ZIndex = 24
	nameLbl.Parent = stopBar

	local stopBtn = Instance.new("TextButton")
	stopBtn.Name = "StopBtn"
	stopBtn.AutoButtonColor = false
	stopBtn.AnchorPoint = Vector2.new(1, 0.5)
	stopBtn.Position = UDim2.new(1, -6, 0.5, 0)
	stopBtn.Size = UDim2.fromOffset(116, 34)
	stopBtn.BackgroundColor3 = Color3.fromRGB(230, 45, 75)
	stopBtn.Font = Enum.Font.FredokaOne
	stopBtn.TextSize = 13
	stopBtn.TextColor3 = Color3.new(1, 1, 1)
	stopBtn.Text = "  หยุดเต้น"
	stopBtn.ZIndex = 24
	stopBtn.Parent = stopBar

	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 8)
	stopCorner.Parent = stopBtn

	local stopStroke = Instance.new("UIStroke")
	stopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stopStroke.Color = Color3.fromRGB(25, 10, 45)
	stopStroke.Thickness = 2
	stopStroke.Parent = stopBtn

	Icons.image("Pause", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 25,
	}, stopBtn)

	Juice.bind(stopBtn)
	stopBtn.Activated:Connect(stopDance)

	-- Load dances
	task.spawn(loadDances)

	-- Hotkey: B to toggle on Desktop
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.B then
			DanceEmoteUI.Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
			DanceEmoteUI.Close()
		end
	end)
end

function DanceEmoteUI.Open()
	if not window then
		DanceEmoteUI.Build()
	end
	isOpen = true
	catcher.Visible = true
	Juice.popIn(window)
	if searchBox then
		searchBox.Text = ""
	end
	DanceEmoteUI.RenderList("")
end

function DanceEmoteUI.Close()
	if not isOpen then return end
	isOpen = false
	catcher.Visible = false
	Juice.popOut(window)
end

function DanceEmoteUI.Toggle()
	if isOpen then
		DanceEmoteUI.Close()
	else
		DanceEmoteUI.Open()
	end
end

function DanceEmoteUI.SetVisible(visible)
	if not visible then
		DanceEmoteUI.Close()
	end
	if screenGui then
		screenGui.Enabled = visible
	end
end

return DanceEmoteUI
