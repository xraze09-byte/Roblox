-- ระบบลากวางที่ใช้ได้ทั้งเมาส์และทัชสกรีน
-- รับการลากทีละอันเท่านั้น และยกเลิกเมื่อกด Esc / คลิกขวา / ออกจากหน้าต่าง / การ์ดหายไป
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))

local Drag = {}
local THRESHOLD = 8 -- ขยับเกินกี่พิกเซลถึงนับว่าลาก (น้อยกว่านี้ = แตะ)

local gui = S.screen("DragLayer", 20, Players.LocalPlayer:WaitForChild("PlayerGui"))
local layer = S.new("Frame", { Name = "Layer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local line = S.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = S.C.Accent,
	Visible = false, ZIndex = 10, Parent = layer })
local head = S.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
	Rotation = 45, BackgroundColor3 = S.C.Accent, Visible = false, ZIndex = 11, Parent = layer })
S.stroke(S.C.Ink, 2, head)

local active = nil

local function vec(input) return Vector2.new(input.Position.X, input.Position.Y) end
local function toLayer(p) return p - layer.AbsolutePosition end

local function inside(g, p)
	if not g.Parent or not g.Visible then return false end
	local a, s = g.AbsolutePosition, g.AbsoluteSize
	return p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
end

-- เลือกเป้าที่เล็กที่สุดที่ครอบจุดนั้น (การ์ดชนะโซนใหญ่)
local function hitTest(a)
	local best, bestArea = nil, math.huge
	for _, t in a.targets do
		local g = t.Gui
		if g and inside(g, a.pos) then
			local area = g.AbsoluteSize.X * g.AbsoluteSize.Y
			if area < bestArea then best, bestArea = t, area end
		end
	end
	return best
end

local function call(fn, ...)
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Drag] " .. tostring(err)) end
end

local function finish(drop)
	local a = active
	if not a then return end
	active = nil
	if a.dragging and drop then a.hover = hitTest(a) end
	if a.ghost then a.ghost:Destroy() end
	line.Visible, head.Visible = false, false
	local spec = a.spec
	if a.dragging then
		call(spec.OnEnd)
		if spec.OnDrop then task.spawn(spec.OnDrop, drop and a.hover or nil) end
	elseif drop and spec.OnTap then
		task.spawn(spec.OnTap)
	end
end

local function startDragging(a)
	local spec = a.spec
	if spec.CanStart then
		local ok, allowed = pcall(spec.CanStart)
		if not ok or not allowed then
			active = nil
			return false
		end
	end
	a.dragging = true
	if spec.Targets then
		local ok, list = pcall(spec.Targets)
		a.targets = (ok and typeof(list) == "table") and list or {}
	end
	if spec.Ghost then
		local ok, g = pcall(spec.Ghost)
		if ok and typeof(g) == "Instance" then
			g.Parent = layer
			a.ghost = g
		end
	end
	call(spec.OnStart)
	return true
end

function Drag.Begin(input, spec)
	if active then return false end
	local p = vec(input)
	active = {
		spec = spec, input = input, start = p, pos = p, dragging = false, targets = {},
		isMouse = input.UserInputType == Enum.UserInputType.MouseButton1,
	}
	return true
end

function Drag.Cancel() finish(false) end
function Drag.IsActive() return active ~= nil end
function Drag.IsDragging() return active ~= nil and active.dragging end
function Drag.DraggingSource() return active and active.dragging and active.spec.Source or nil end

RunService.RenderStepped:Connect(function()
	local a = active
	if not a then return end
	if a.isMouse and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		finish(false) -- เดิม finish(true): ปล่อยเมาส์นอกหน้าต่างแล้วการ์ดถูกเล่นเองโดยไม่ตั้งใจ
		return
	end
	if not a.dragging then
		if (a.pos - a.start).Magnitude < THRESHOLD then return end
		if not startDragging(a) then return end
	end
	local lp = toLayer(a.pos)
	if a.ghost then
		local lift = a.isMouse and 0 or a.ghost.AbsoluteSize.Y * 0.35 -- ทัช: ยกการ์ดขึ้นไม่ให้นิ้วบัง
		a.ghost.Position = UDim2.fromOffset(lp.X, lp.Y - lift)
	end
	if a.spec.Arrow then
		local from = toLayer(a.start)
		local d = lp - from
		local len = d.Magnitude
		line.Visible, head.Visible = len > 4, len > 4
		line.Size = UDim2.fromOffset(len, 4)
		line.Position = UDim2.fromOffset((from.X + lp.X) / 2, (from.Y + lp.Y) / 2)
		line.Rotation = math.deg(math.atan2(d.Y, d.X))
		head.Position = UDim2.fromOffset(lp.X, lp.Y)
	end
	local hover = hitTest(a)
	if hover ~= a.hover then
		a.hover = hover
		call(a.spec.OnHover, hover)
	end
end)

local function onMove(input)
	local a = active
	if not a then return end
	if a.isMouse then
		if input.UserInputType == Enum.UserInputType.MouseMovement then a.pos = vec(input) end
	elseif input == a.input then
		a.pos = vec(input)
	end
end

local function onEnd(input)
	local a = active
	if not a then return end
	if (a.isMouse and input.UserInputType == Enum.UserInputType.MouseButton1) or input == a.input then
		a.pos = vec(input)
		finish(true)
	end
end

UserInputService.InputChanged:Connect(onMove)
UserInputService.TouchMoved:Connect(onMove)
UserInputService.InputEnded:Connect(onEnd)
UserInputService.TouchEnded:Connect(onEnd)
UserInputService.InputBegan:Connect(function(input)
	if active and (input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2) then
		Drag.Cancel()
	end
end)
UserInputService.WindowFocusReleased:Connect(Drag.Cancel)

return Drag
