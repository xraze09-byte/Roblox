-- StarterPlayerScripts/UIClient/TargetArrow (ModuleScript)
-- ลูกศรโค้งแบบ Hearthstone จากการ์ดที่เลือกไปหาเมาส์/นิ้ว
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local UI = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Settings = require(UI:WaitForChild("Settings"))

local Arrow = {}
local DOTS = 16
local holder, dots, reticle, conn, source

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

function Arrow.Stop()
	if conn then conn:Disconnect() conn = nil end
	if holder then holder:Destroy() holder = nil end
	source = nil
end

function Arrow.Start(fromObj, color)
	Arrow.Stop()
	if not (fromObj and Settings.Get("TargetArrow")) then return end
	local sg = fromObj:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg then return end
	color = color or Theme.Color.Red
	source = fromObj

	holder = make("Frame", { Name = "TargetArrow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 150 }, sg)
	dots = {}
	for i = 1, DOTS do
		local s = 6 + i * 0.7
		local d = make("Frame", {
			Size = UDim2.fromOffset(s, s), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 151,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
		make("UIStroke", { Thickness = 1.5, Color = Theme.Color.Outline }, d)
		dots[i] = d
	end
	reticle = make("Frame", {
		Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, ZIndex = 152,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, reticle)
	make("UIStroke", { Thickness = 4, Color = color }, reticle)
	for _, sz in ipairs({ UDim2.new(1.4, 0, 0, 3), UDim2.new(0, 3, 1.4, 0) }) do
		make("Frame", {
			Size = sz, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 152,
		}, reticle)
	end

	conn = RunService.RenderStepped:Connect(function()
		if not (source and source.Parent) then Arrow.Stop() return end
		local a = source.AbsolutePosition + source.AbsoluteSize / 2 - sg.AbsolutePosition
		local mouse = UserInputService:GetMouseLocation()
		-- ScreenGui ที่ IgnoreGuiInset=false วาดใต้แถบ Roblox: ต้องหัก inset ด้านบน ถ้า IgnoreGuiInset=true ไม่ต้องหัก
		local inset = sg.IgnoreGuiInset and Vector2.zero or GuiService:GetGuiInset()
		local m = mouse - inset - sg.AbsolutePosition
		local ctrl = (a + m) / 2 + Vector2.new(0, -math.min((m - a).Magnitude * 0.35, 160))
		local phase = (os.clock() * 1.5) % 1
		for i, d in ipairs(dots) do
			local t = math.clamp((i - 1 + phase) / DOTS, 0, 1)
			local u = 1 - t
			local p = a * (u * u) + ctrl * (2 * u * t) + m * (t * t)
			d.Position = UDim2.fromOffset(p.X, p.Y)
			d.BackgroundTransparency = 0.6 * u
		end
		reticle.Position = UDim2.fromOffset(m.X, m.Y)
		reticle.Rotation = (os.clock() * 90) % 360
	end)
end

-- เรียกได้ทุกเฟรม: ถ้าการ์ดต้นทางเปลี่ยนจะเริ่มใหม่ ถ้าเป็น nil จะซ่อน
function Arrow.Follow(obj, color)
	if obj == source then return end
	Arrow.Stop()
	if obj then Arrow.Start(obj, color) end
end

return Arrow