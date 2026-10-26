MOCK = H.M
MOCK.realWait = true
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local task, CFr, V3 = H.globals.task, H.globals.CFrame, H.globals.Vector3
local ws = H.game:GetService("Workspace")
local cam = ws.CurrentCamera
cam.CFrame = CFr.new(0, 5, 5); cam.FieldOfView = 70
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch
local hrp = H.newInstance("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = ch; hrp.CFrame = CFr.new(0,0,0); hrp.Position = V3.new(0,0,0)
H.player.Character = ch
-- PlayerScripts exists but has NO PlayerModule (like the user's Studio: "Infinite yield possible on PlayerScripts:WaitForChild('PlayerModule')")
if not H.player:FindFirstChild("PlayerScripts") then local ps = H.newInstance("Folder"); ps.Name = "PlayerScripts"; ps.Parent = H.player end
local tbl = H.newInstance("Model"); tbl.Name = "CardTable"; tbl.Parent = ws
local pt = H.newInstance("Part"); pt.Name = "CameraPoint"; pt.CFrame = CFr.new(0,10,10); pt.Parent = tbl
local felt = H.newInstance("Part"); felt.Name = "Felt"; felt.Position = V3.new(0,0,0); felt.Parent = tbl
local LP = H.game:GetService("Players").LocalPlayer
print("LocalPlayer is H.player:", LP == H.player, "| LP PlayerScripts:", LP and LP:FindFirstChild("PlayerScripts") ~= nil)
local ps = H.player:FindFirstChild("PlayerScripts")
print("PlayerScripts:", ps ~= nil, "| PlayerModule child:", ps and ps:FindFirstChild("PlayerModule") ~= nil, "| realWait:", MOCK.realWait)
local TC = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/TableCamera.lua"))
local RS = H.game:GetService("RunService")
local arrived = 0
task.spawn(TC.Enter, function() arrived += 1 end)
local firstAt
for i = 1, 300 do
	MOCK.pump(0.02); RS.RenderStepped:Fire(0.016)
	if arrived > 0 and not firstAt then firstAt = i * 0.02 end
end
print(("onArrived first fired at virtual t=%.2fs (flight is 1.4s; >3s means Enter was blocked)"):format(firstAt or -1))
if firstAt and firstAt > 3 then problems_late = true end
local ct = cam.CameraType; ct = ct and (ct.Name or ct)
print("6s after Enter with NO PlayerModule: CameraType=" .. tostring(ct) .. " onArrived=" .. arrived)
local problems = {}
if problems_late then problems[#problems + 1] = "Enter blocked ~3s+ waiting for PlayerModule" end
if arrived == 0 then problems[#problems + 1] = "camera never arrived: Enter is blocked waiting for PlayerModule" end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
