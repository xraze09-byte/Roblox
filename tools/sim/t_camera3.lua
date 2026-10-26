MOCK = H.M
local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local task, CFr, V3 = H.globals.task, H.globals.CFrame, H.globals.Vector3
local ws = H.game:GetService("Workspace")
local cam = ws.CurrentCamera
cam.CFrame = CFr.new(0, 5, 5); cam.FieldOfView = 70
local function ctype() local c = cam.CameraType; return c and (c.Name or c) or "nil" end
local ch = H.newInstance("Model"); H.newInstance("Humanoid").Parent = ch
local hrp = H.newInstance("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = ch; hrp.CFrame = CFr.new(0,0,0); hrp.Position = V3.new(0,0,0)
H.player.Character = ch
local tbl = H.newInstance("Model"); tbl.Name = "CardTable"; tbl.Parent = ws
local pt = H.newInstance("Part"); pt.Name = "CameraPoint"; pt.CFrame = CFr.new(0,10,10); pt.Parent = tbl
local felt = H.newInstance("Part"); felt.Name = "Felt"; felt.Position = V3.new(0,0,0); felt.Parent = tbl
local TC = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/TableCamera.lua"))
local problems = {}
local function bad(m) problems[#problems + 1] = m end

-- 1) camera error inside the frame loop: must restore the camera and still fire onArrived
local arrived = 0
local RS = H.game:GetService("RunService")
cam.CameraType = "Custom"
task.spawn(TC.Enter, function() arrived += 1 end)
MOCK.pump(0.3)
-- sabotage: make CameraPoint-derived goal blow up on next frame by breaking cam.CFrame writes
local mt = getmetatable(cam)
local oldNew = mt.__newindex
mt.__newindex = function(t, k, v) if k == "FieldOfView" and v ~= 70 and v ~= 55 then error("boom-from-test") end return oldNew(t, k, v) end
RS.RenderStepped:Fire(0.016)
mt.__newindex = oldNew
MOCK.pump(2)
print("frame-error: CameraType=" .. ctype() .. " arrived=" .. arrived)
RS.RenderStepped:Fire(0.016); RS.RenderStepped:Fire(0.016)
-- 2) normal arrival
local arrived2 = 0
cam.CameraType = "Custom"
task.spawn(TC.Enter, function() arrived2 += 1 end)
MOCK.pump(3)
for i = 1, 200 do RS.RenderStepped:Fire(0.016); MOCK.pump(0.02) end
print("normal: CameraType=" .. ctype() .. " arrived=" .. arrived2)
if arrived2 < 1 then bad("normal fly-in never fired onArrived") end
-- 3) fly-back where Completed never fires (respawn): camera must still be restored
TC.Exit()
MOCK.pump(0.1)
print("exit (t+0.1s): CameraType=" .. ctype())
MOCK.pump(3)
print("exit (t+3s, Completed may never fire): CameraType=" .. ctype())
if ctype() ~= "Custom" then bad("camera stuck on " .. ctype() .. " after Exit when tween Completed never fires") end
print("problems:", #problems); for _, p in ipairs(problems) do print("  - " .. p) end
