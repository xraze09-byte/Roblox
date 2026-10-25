local MatchHUD
for inst, info in pairs(H.sources) do if info.path:find("UIClient/MatchHUD.lua") then MatchHUD = H.load(inst) end end
local gui = H.newInstance("Frame")
local hud = MatchHUD.new(gui, {})
-- Apply a realistic state to exercise every SetX path (HP, shield, points, turn, banner)
local ok, err = pcall(function()
	hud:Apply({ myHP = 30, oppHP = 30, myShield = 2, oppShield = 0, myLeader = "เรา • ลุง", oppLeader = "บอท • ป้า",
		isMyTurn = true, turnEndsAt = 120, myPoints = 7, mySpent = false, myHand = {} })
	hud:Apply({ myHP = 22, oppHP = 9, myShield = 0, oppShield = 3, isMyTurn = false, turnEndsAt = 120, myPoints = 0, mySpent = true, myHand = {} })
end)
print("Apply x2:", ok, err or "")
H.M.pump(3)
for _, e in ipairs(H.M.taskErrors or {}) do print("TASK ERR:", e) end
for _, e in ipairs(H.M.handlerErrors or {}) do print("HANDLER ERR:", e) end
-- HUD must be parented to root, and every floating piece must be a direct child of root (independent, not nested in a bar)
local direct = {}
for _, c in ipairs(hud.root:GetChildren()) do direct[#direct + 1] = c.Name end
table.sort(direct)
print("direct children of HUD root:", table.concat(direct, ", "))
hud:Destroy()
print("destroy ok, root parent:", hud.root.Parent)
