-- StarterPlayer/StarterPlayerScripts/UIClient/NotificationUI.lua
-- Modern, responsive, touch-friendly Notification banner system with icon integration
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("UI"):WaitForChild("Style"))
local Icons = require(Shared:WaitForChild("UI"):WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local player = Players.LocalPlayer
local C = Style.C

local NotificationUI = {}

local screenGui = nil
local holder = nil

local function getRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	end
	return remotes
end

local function playNotificationSound()
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://18595195017"
		sound.Volume = 0.55
		sound.SoundGroup = SoundService:FindFirstChild("SoundEffects")
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 3)
	end)
end

-- Auto-detect icon from message text if none explicitly specified
local function pickIcon(message, requestedIcon)
	if requestedIcon and Icons.Asset[requestedIcon] then
		return requestedIcon
	end
	local msg = tostring(message or ""):lower()
	if msg:find("💎") or msg:find("gem") or msg:find("เพชร") or msg:find("coin") then
		return "Coins"
	elseif msg:find("quest") or msg:find("เควสต์") or msg:find("รางวัล") or msg:find("gift") or msg:find("chest") then
		return "Chest"
	elseif msg:find("pvp") or msg:find("bot") or msg:find("สู้") or msg:find("battle") or msg:find("play") then
		return "Play"
	elseif msg:find("level") or msg:find("อัป") or msg:find("upgrade") then
		return "Up"
	elseif msg:find("lock") or msg:find("ปลด") then
		return "Unlock"
	elseif msg:find("เต้น") or msg:find("dance") or msg:find("emote") then
		return "Play"
	end
	return "Checkmark"
end

function NotificationUI.Init(parent)
	if screenGui and screenGui.Parent then
		screenGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationUI"
	screenGui.DisplayOrder = 35 -- Above standard HUD and MatchUI
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	pcall(function() screenGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets end)
	screenGui.Parent = parent or player:WaitForChild("PlayerGui")

	holder = Instance.new("Frame")
	holder.Name = "NotificationHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 58)
	holder.Size = UDim2.new(0.92, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.ZIndex = 50
	holder.Parent = screenGui

	local maxConstraint = Instance.new("UISizeConstraint")
	maxConstraint.MinSize = Vector2.new(280, 0)
	maxConstraint.MaxSize = Vector2.new(450, 9999)
	maxConstraint.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = holder

	-- Listen for remote events from server
	task.spawn(function()
		local remotes = getRemotes()
		if remotes then
			local rem = remotes:FindFirstChild("Notification") or remotes:WaitForChild("Notification", 10)
			if rem and rem:IsA("RemoteEvent") then
				rem.OnClientEvent:Connect(function(msg, col, life, icon)
					NotificationUI.Show(msg, col, life, icon)
				end)
			end
		end
	end)
end

function NotificationUI.Show(message, color, lifetime, iconName)
	if not holder or not holder.Parent then
		NotificationUI.Init()
	end

	message = tostring(message or "")
	if #message == 0 then return end
	color = (typeof(color) == "Color3") and color or Color3.fromRGB(255, 220, 60)
	lifetime = (typeof(lifetime) == "number" and lifetime > 0) and lifetime or 4.0
	local iconKey = pickIcon(message, iconName)

	-- Remove leading emoji if present so the vector icon displays as the sole primary glyph
	local cleanMsg = message:gsub("^[%s%p]*[\240\159\144-\159\154\175\226\156\133\226\154\148\226\154\161\226\156\168\226\157\140\226\157\142]+[%s%p]*", "")
	if #cleanMsg > 0 then message = cleanMsg end

	local card = Instance.new("TextButton")
	card.Name = "NotificationCard"
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(34, 16, 68)
	card.BackgroundTransparency = 0.15
	card.ZIndex = 51
	card.Parent = holder

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Color = color
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	-- Icon display
	local icon = Icons.image(iconKey, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 52,
	}, card)

	-- Message Label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Message"
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.new(0, 42, 0, 0)
	textLabel.Size = UDim2.new(1, -48, 0, 0)
	textLabel.AutomaticSize = Enum.AutomaticSize.Y
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 13.5
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.TextWrapped = true
	textLabel.Text = message
	textLabel.ZIndex = 52
	textLabel.Parent = card

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.5
	uiScale.Parent = card

	-- Animate In (Bounce & Slide)
	TweenService:Create(uiScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	playNotificationSound()

	local isDismissed = false
	local function dismiss()
		if isDismissed or not card.Parent then return end
		isDismissed = true
		local fade = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		fade:Play()
		TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = 0.6,
		}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		TweenService:Create(textLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()

		task.delay(0.28, function()
			if card.Parent then card:Destroy() end
		end)
	end

	-- Tap to dismiss
	card.Activated:Connect(dismiss)

	-- Auto dismiss after lifetime
	task.delay(lifetime, dismiss)
end

_G.CreateNotification = function(msg, col, life, icon)
	NotificationUI.Show(msg, col, life, icon)
end

return NotificationUI
