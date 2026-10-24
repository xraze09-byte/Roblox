-- StarterPlayer/StarterPlayerScripts/UIClient (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local LobbyUI = require(script:WaitForChild("LobbyUI"))
local MatchUI = require(script:WaitForChild("MatchUI"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

local function screen(name, order)
	return UIKit.new("ScreenGui", {
		Name = name, DisplayOrder = order, IgnoreGuiInset = true,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
	})
end

local hud = screen("LobbyHUD", 1)
local match = screen("MatchUI", 5)
local overlay = screen("Overlay", 10) -- แจ้งเตือน, ป๊อปอัป, วงล้อเกต
UIKit.toastParent = overlay

LobbyUI.Build(hud, overlay)
MatchUI.Build(match, overlay, {
	OnStart = function() hud.Enabled = false end,
	OnExit = function() hud.Enabled = true end,
})