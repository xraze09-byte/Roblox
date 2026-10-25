-- StarterPlayerScripts/UIClient/HandFan (ModuleScript)
-- การ์ดในมือเรียงเป็นพัดโค้ง + ชี้แล้วลอยขึ้น/ขยาย/ดันใบข้างออก
local TweenService = game:GetService("TweenService")
local HandFan = {}

local CFG = {
	Spread = 0.12,     -- ระยะห่างสูงสุดระหว่างใบ
	Width = 0.78,      -- ความกว้างรวมสูงสุดของทั้งมือ
	Angle = 5,         -- องศาต่อใบ
	MaxAngle = 28,
	Arc = 0.1,         -- ใบริมสุดต่ำลงเท่าไร
	HoverY = 0.97,     -- ตำแหน่งตอนชี้ (ยึดขอบล่าง การ์ดขยายขึ้นด้านบน)
	HoverScale = 1.4,
	Push = 0.05,
	Draw = UDim2.fromScale(1.25, 1.4), -- การ์ดใหม่ลอยมาจากมุมขวาล่าง (กองการ์ด)
}
local TI = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local hooked = setmetatable({}, { __mode = "k" })
local hoveredFrame = nil

function HandFan.Container(parent, position, size)
	local f = Instance.new("Frame")
	f.Name = "Hand"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = position
	f.Size = size
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

local function scaleOf(frame)
	local s = frame:FindFirstChild("FanScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FanScale"
		s.Parent = frame
	end
	return s
end

function HandFan.Layout(container, views)
	local list = {}
	for _, v in pairs(views) do
		if v.Frame.Parent == container then table.insert(list, v) end
	end
	table.sort(list, function(a, b) return a.Frame.LayoutOrder < b.Frame.LayoutOrder end)
	local n = #list
	if n == 0 then return end

	local spread = math.min(CFG.Spread, CFG.Width / math.max(n - 1, 1))
	local angle = math.min(CFG.Angle, CFG.MaxAngle / n)
	local mid = (n + 1) / 2
	local half = math.max(mid - 1, 1)

	local hoverIndex
	for i, v in ipairs(list) do
		if v.Frame == hoveredFrame then hoverIndex = i end
	end
	if not hoverIndex then hoveredFrame = nil end -- การ์ดที่ชี้อยู่ถูกลบ/ใช้ไปแล้ว

	for i, v in ipairs(list) do
		local f = v.Frame
		local off = i - mid
		local norm = off / half
		local x, y, rot, scale = 0.5 + off * spread, 1 + norm * norm * CFG.Arc, off * angle, 1
		f.ZIndex = i
		if hoverIndex then
			if i == hoverIndex then
				y, rot, scale = CFG.HoverY, 0, CFG.HoverScale
				f.ZIndex = 100
			elseif i < hoverIndex then
				x -= CFG.Push
			else
				x += CFG.Push
			end
		end

		f.AnchorPoint = Vector2.new(0.5, 1)
		if not hooked[f] then
			hooked[f] = true
			f.Position = CFG.Draw
			f.Rotation = 25
			local hit = v.Body and v.Body:FindFirstChild("Hitbox")
			if hit then
				local function enter() hoveredFrame = f HandFan.Layout(container, views) end
				local function leave()
					if hoveredFrame == f then hoveredFrame = nil HandFan.Layout(container, views) end
				end
				hit.MouseEnter:Connect(enter)
				hit.MouseLeave:Connect(leave)
				hit.SelectionGained:Connect(enter)
				hit.SelectionLost:Connect(leave)
			end
		end
		TweenService:Create(f, TI, { Position = UDim2.fromScale(x, y), Rotation = rot }):Play()
		TweenService:Create(scaleOf(f), TI, { Scale = scale }):Play()
	end
end

return HandFan