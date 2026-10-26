local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local S = require(UIFolder:WaitForChild("Style"))
local FloatHUD = require(script:WaitForChild("FloatHUD"))
local WorldPrompts = require(script:WaitForChild("WorldPrompts"))
local LobbyUI = require(script:WaitForChild("LobbyUI"))
local MatchUI = require(script:WaitForChild("MatchUI"))
local TableCamera = require(script:WaitForChild("TableCamera"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

for _, name in { "LobbyHUD", "FloatHUD", "MenuHUD", "MatchUI", "Overlay" } do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local hud = S.screen("FloatHUD", 1, playerGui)      -- ปุ่มลอย (หน้าหลักตอนอยู่ในโลก 3D)
local menu = S.screen("MenuHUD", 3, playerGui)      -- หน้าเต็มเดิม (เควสต์/สถิติ/ฟาร์ม/โหมด) เปิดจากปุ่ม ☰
local match = S.screen("MatchUI", 5, playerGui)
local overlay = S.screen("Overlay", 10, playerGui)
UIKit.toastParent = overlay
S.toastParent = overlay
menu.Enabled = false

FloatHUD.Build(hud, overlay)
WorldPrompts.Start(function(action) FloatHUD.Action(action) end)

-- LobbyUI ถูกสร้างครั้งเดียวและซ่อนไว้ ไม่ทึบเต็มจอจนกว่าผู้เล่นจะเปิดเอง
LobbyUI.Build(menu, overlay)
LobbyUI.OnClose = function()
	menu.Enabled = false
	hud.Enabled = true
	WorldPrompts.SetEnabled(true)
end
local function openMenu(tab)
	FloatHUD.Close()
	hud.Enabled = false
	WorldPrompts.SetEnabled(false)
	menu.Enabled = true
	LobbyUI.OpenTab(tab)
	LobbyUI.Refresh()
end
FloatHUD.AddMenuItem("📜 เควสต์", FloatHUD.C.Lime, function() openMenu("Quests") end)
FloatHUD.AddMenuItem("📊 สถิติ", FloatHUD.C.Blue, function() openMenu("Stats") end)
FloatHUD.AddMenuItem("🌾 ฟาร์ม / โหมดอื่น", FloatHUD.C.Orange, function() openMenu("Modes") end)

MatchUI.Build(match, overlay, {
	OnStart = function()
		hud.Enabled = false
		menu.Enabled = false
		WorldPrompts.SetEnabled(false)
		FloatHUD.ResetQueue()
		LobbyUI.ResetQueue()
		match.Enabled = false
		TableCamera.Enter(function() match.Enabled = true end)
	end,
	OnExit = function()
		TableCamera.Exit()
		match.Enabled = true
		hud.Enabled = true
		WorldPrompts.SetEnabled(true)
		FloatHUD.Refresh()
		LobbyUI.Refresh()
	end,
})
