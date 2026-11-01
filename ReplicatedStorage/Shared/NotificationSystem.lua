local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotificationSystem = {}

local function getNotificationRE()
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not Remotes then
		Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	end
	if Remotes then
		return Remotes:FindFirstChild("Notification") or Remotes:WaitForChild("Notification", 10)
	end
	return nil
end

function NotificationSystem.Notify(message, color, lifetime, icon)
	if RunService:IsClient() then
		local rem = getNotificationRE()
		if rem then
			rem:FireServer(message, color, lifetime, icon)
		end
	end
end

function NotificationSystem.NotifyPlayer(player, message, color, lifetime, icon)
	if RunService:IsServer() and player then
		local rem = getNotificationRE()
		if rem then
			rem:FireClient(player, message, color, lifetime, icon)
		end
	end
end

function NotificationSystem.NotifyAll(message, color, lifetime, icon)
	if RunService:IsServer() then
		local rem = getNotificationRE()
		if rem then
			rem:FireAllClients(message, color, lifetime, icon)
		end
	end
end

return NotificationSystem
