local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local S = require(UIFolder:WaitForChild("Style"))
local FloatHUD = require(script:WaitForChild("FloatHUD"))
local WorldPrompts = require(script:WaitForChild("WorldPrompts"))
local MatchUI = require(script:WaitForChild("MatchUI"))
local TableCamera = require(script:WaitForChild("TableCamera"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

for _, name in { "LobbyHUD", "MenuHUD", "FloatHUD", "MatchUI", "Overlay" } do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local hud = S.screen("FloatHUD", 1, playerGui)   -- ปุ่มลอยตอนเดินในโลก 3D
local match = S.screen("MatchUI", 5, playerGui)
local overlay = S.screen("Overlay", 10, playerGui)
UIKit.toastParent = overlay
S.toastParent = overlay

FloatHUD.Build(hud, overlay, {
	-- เปิดหน้าจัดเด็ค → ปิดปุ่มในฉากชั่วคราว
	OnModal = function(open) WorldPrompts.SetEnabled(not open) end,
})
WorldPrompts.Start(FloatHUD.Action)

MatchUI.Build(match, overlay, {
	OnStart = function()
		FloatHUD.EnterMatch()
		WorldPrompts.SetEnabled(false)
		match.Enabled = false
		TableCamera.Enter(function() match.Enabled = true end)
	end,
	OnExit = function()
		TableCamera.Exit()
		match.Enabled = true
		FloatHUD.ExitMatch()
		WorldPrompts.SetEnabled(true)
	end,
})