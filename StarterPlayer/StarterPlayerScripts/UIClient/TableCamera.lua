-- StarterPlayer/StarterPlayerScripts/UIClient/TableCamera.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Settings"))
local function effectsOn() return Settings.Get("Effects") ~= false end

local TableCamera = {}
local FLY_TIME, TABLE_FOV = 1.4, 55
local active, savedFov, conn, session = false, 70, nil, 0
local farSide = false

local function getTable()
	return workspace:FindFirstChild("CardTable") or workspace:WaitForChild("CardTable", 5)
end

local function setControls(on)
	local ok, pm = pcall(function()
		return require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if not ok or not pm then return end
	local c = pm:GetControls()
	if on then c:Enable() else c:Disable() end
end


-- นั่ง SeatOpp (PvP คนที่สอง) = อยู่ฝั่งตรงข้าม: หมุนมุมมอง 180 องศารอบกลางโต๊ะ ให้ฝั่งเราอยู่ล่างจอเสมอ
local function onFarSide()
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	-- เซิร์ฟเวอร์สั่งนั่งตอนเริ่มแมตช์ อาจมาถึงช้ากว่า OnStart เล็กน้อย: รอสูงสุด 0.6 วิ
	local t0 = os.clock()
	while not hum.SeatPart and os.clock() - t0 < 0.6 do task.wait(0.05) end
	local seat = hum.SeatPart
	return seat ~= nil and seat.Name == "SeatOpp"
end

local function stop() if conn then conn:Disconnect(); conn = nil end end
local function bezier(a, b, c, t) local u = 1 - t; return a * u * u + b * 2 * u * t + c * t * t end
local function ease(t) return t < 0.5 and 4 * t ^ 3 or 1 - (-2 * t + 2) ^ 3 / 2 end

-- onArrived ถูกเรียกเมื่อกล้องถึงโต๊ะ (ใช้เปิด Battle UI)
function TableCamera.Enter(onArrived)
	if active then if onArrived then onArrived() end return end
	session += 1
	local my = session
	active = true
	local tbl = getTable()
	if session ~= my then return end -- แมตช์จบระหว่างรอโต๊ะ: Exit คืนกล้องให้แล้ว
	local point = tbl and tbl:FindFirstChild("CameraPoint", true)
	if not point then
		active = false
		warn("[TableCamera] ไม่พบ workspace.CardTable.CameraPoint")
		if onArrived then onArrived() end
		return
	end
	local cam = workspace.CurrentCamera
	savedFov = cam.FieldOfView
	setControls(false)
	cam.CameraType = Enum.CameraType.Scriptable

	local felt = tbl:FindFirstChild("Felt", true)
	local goal = point.CFrame
	local focus = felt and felt.Position or (goal * CFrame.new(0, 0, -20)).Position
	local far = onFarSide()
	if session ~= my then return end -- แมตช์จบระหว่างรอที่นั่ง
	if far then
		local pivot = CFrame.new(focus)
		goal = pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse() * goal
	end
	farSide = far
	local start, startFov = cam.CFrame, cam.FieldOfView
	local mid = start.Position:Lerp(goal.Position, 0.5) + Vector3.new(0, 14, 0)
	local t0, arrived = os.clock(), false

	stop()
	conn = RunService.RenderStepped:Connect(function()
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		local a = math.clamp((os.clock() - t0) / FLY_TIME, 0, 1)
		if a < 1 then
			local e = ease(a)
			local pos = bezier(start.Position, mid, goal.Position, e)
			local rot = start.Rotation:Lerp(CFrame.lookAt(pos, focus).Rotation, math.min(e * 3, 1))
			cam.CFrame = (CFrame.new(pos) * rot):Lerp(goal, e ^ 4)
			cam.FieldOfView = startFov + (TABLE_FOV - startFov) * e
		else
			if not arrived then
				arrived = true
				cam.FieldOfView = TABLE_FOV
				if onArrived then task.spawn(onArrived) end
			end
			local t = os.clock()
			local sway = effectsOn() and CFrame.Angles(math.sin(t * 0.6) * 0.004, math.cos(t * 0.45) * 0.006, 0) or CFrame.identity
			cam.CFrame = goal * sway
		end
	end)
end

function TableCamera.Exit()
	if not active then return end
	active = false
	stop()
	session += 1
	local my = session
	local cam = workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local function restore()
		if session ~= my then return end -- ถ้าเข้าแมตช์ใหม่ระหว่างกล้องบินกลับ ไม่ต้องคืนค่า
		cam.CameraType = Enum.CameraType.Custom
		if hum then cam.CameraSubject = hum end
		cam.FieldOfView = savedFov
		setControls(true)
	end
	if not hrp then restore() return end
	local back = CFrame.lookAt((hrp.CFrame * CFrame.new(0, 5, 13)).Position, hrp.Position + Vector3.new(0, 2, 0))
	local tw = TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
		{ CFrame = back, FieldOfView = savedFov })
	tw:Play()
	tw.Completed:Once(restore)
end

-- วงซัมมอน 3D บนโต๊ะเรืองแสงตอนลงการ์ด (ทำงานฝั่ง client เท่านั้น ผู้เล่นอื่นไม่เห็น)
function TableCamera.Pulse(side, index, color)
	local tbl = workspace:FindFirstChild("CardTable")
	local mine = (side == "me") ~= farSide -- นั่งฝั่งไกล: วง "me" ของเราคือวงชุด Opp บนโต๊ะ
	local ring = tbl and tbl:FindFirstChild((mine and "Me" or "Opp") .. index, true)
	if not ring or not effectsOn() then return end
	local wave = ring:Clone()
	wave.Name, wave.Transparency = "Pulse", 0.05
	if color then wave.Color = color end
	wave.Parent = workspace
	TweenService:Create(wave, TweenInfo.new(0.6, Enum.EasingStyle.Quart),
		{ Size = Vector3.new(0.12, 9, 9), Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.7)
	ring.Transparency = 0
	TweenService:Create(ring, TweenInfo.new(0.8), { Transparency = 0.55 }):Play()
end

return TableCamera