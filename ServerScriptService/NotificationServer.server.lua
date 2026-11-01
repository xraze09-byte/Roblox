local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function getNotificationSystem()
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 5)
	if sharedFolder and sharedFolder:FindFirstChild("NotificationSystem") then
		return require(sharedFolder:FindFirstChild("NotificationSystem"))
	end
	local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	if moduleFolder and moduleFolder:FindFirstChild("NotificationSystem") then
		return require(moduleFolder:FindFirstChild("NotificationSystem"))
	end
	return nil
end

local NotificationSystem = getNotificationSystem()

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)
local NotificationRE = Remotes and (Remotes:FindFirstChild("Notification") or Remotes:WaitForChild("Notification", 10))

if NotificationRE then
	NotificationRE.OnServerEvent:Connect(function(player, message, color, lifetime, icon)
		if not NotificationSystem then
			NotificationSystem = getNotificationSystem()
		end
		if typeof(message) ~= "string" then
			message = tostring(message or "")
		end
		if #message > 250 then
			message = string.sub(message, 1, 250)
		end
		if typeof(color) ~= "Color3" then
			color = Color3.new(1, 1, 1)
		end
		if typeof(lifetime) ~= "number" or lifetime <= 0 or lifetime > 30 then
			lifetime = 4
		end
		if typeof(icon) ~= "string" then
			icon = nil
		end
		if NotificationSystem then
			NotificationSystem.NotifyPlayer(player, message, color, lifetime, icon)
		end
	end)
end

local function welcomePlayer(player)
	task.wait(1.5)
	if not NotificationSystem then
		NotificationSystem = getNotificationSystem()
	end
	if player and player.Parent and NotificationSystem then
		NotificationSystem.NotifyPlayer(player, "Welcome, " .. (player.DisplayName or player.Name) .. "!", Color3.fromRGB(255, 187, 69), 4, "Checkmark")
	end
end

Players.PlayerAdded:Connect(welcomePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(welcomePlayer, player)
end
