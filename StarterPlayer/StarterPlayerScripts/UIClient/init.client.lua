local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local S = require(UIFolder:WaitForChild("Style"))
local LobbyUI = require(script:WaitForChild("LobbyUI"))
local MatchUI = require(script:WaitForChild("MatchUI"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

for _, name in { "LobbyHUD", "MatchUI", "Overlay" } do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local hud = S.screen("LobbyHUD", 1, playerGui)
local match = S.screen("MatchUI", 5, playerGui)
local overlay = S.screen("Overlay", 10, playerGui)
UIKit.toastParent = overlay
S.toastParent = overlay

LobbyUI.Build(hud, overlay)
MatchUI.Build(match, overlay, {
	OnStart = function()
		hud.Enabled = false
		LobbyUI.ResetQueue()
	end,
	OnExit = function()
		hud.Enabled = true
		LobbyUI.Refresh()
	end,
})