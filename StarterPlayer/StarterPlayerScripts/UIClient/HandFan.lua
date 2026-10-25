-- StarterPlayerScripts/UIClient/HandFan (ModuleScript)
-- การ์ดในมือ (สูงสุด Config.MAX_HAND = 5 ใบ) เรียงเป็นพัดโค้ง ชี้แล้วลอยขึ้น/ขยาย/ดันใบข้างออก
-- ใช้กับ CardFace (v.Root / v.Scale) และ DragController ที่ผูก InputBegan ไว้บน Root อยู่แล้ว
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local HandFan = {}

local CFG = {
	Spread = 0.17,     -- ระยะห่างสูงสุดระหว่างใบ (สัดส่วนความกว้างมือ)
	Width = 0.8,       -- ความกว้างรวมสูงสุดของทั้งมือ
	Angle = 6,         -- องศาต่อใบ
	MaxAngle = 30,
	Arc = 0.12,        -- ใบริมสุดต่ำลงเท่าไร
	HoverLift = 0.16,  -- ลอยขึ้นเท่าไรตอนชี้
	HoverScale = 1.28,
	Push = 0.05,
	Draw = UDim2.fromScale(1.2, 1.5), -- การ์ดใหม่ลอยมาจากมุมขวาล่าง (กองการ์ด)
}
local TI = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local hooked = setmetatable({}, { __mode = "k" })
local hovered = nil

local function tween(inst, props)
	TweenService:Create(inst, TI, props):Play()
end

-- views: map uid -> CardFace ; จัดเฉพาะใบที่อยู่ใน container
function HandFan.Layout(container, views)
	local list = {}
	for _, v in pairs(views) do
		if v.Root.Parent == container then table.insert(list, v) end
	end
	table.sort(list, function(a, b) return a.Root.LayoutOrder < b.Root.LayoutOrder end)
	local n = #list
	if n == 0 then hovered = nil return end

	local maxHand = math.max(Config.MAX_HAND or 5, n)
	local spread = math.min(CFG.Spread, CFG.Width / math.max(maxHand - 1, 1))
	local angle = math.min(CFG.Angle, CFG.MaxAngle / n)
	local mid = (n + 1) / 2
	local half = math.max(mid - 1, 1)

	local hoverIndex
	for i, v in ipairs(list) do
		if v.Root == hovered then hoverIndex = i end
	end
	if not hoverIndex then hovered = nil end -- การ์ดที่ชี้อยู่ถูกใช้ไปแล้ว

	for i, v in ipairs(list) do
		local f = v.Root
		local off = i - mid
		local norm = off / half
		local x, y, rot, scale = 0.5 + off * spread, 1 + norm * norm * CFG.Arc, off * angle, 1
		f.ZIndex = 2 + i
		if hoverIndex then
			if i == hoverIndex then
				y, rot, scale = 1 - CFG.HoverLift, 0, CFG.HoverScale
				f.ZIndex = 40
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
			f.MouseEnter:Connect(function()
				hovered = f
				HandFan.Layout(container, views)
			end)
			f.MouseLeave:Connect(function()
				if hovered == f then
					hovered = nil
					HandFan.Layout(container, views)
				end
			end)
		end
		tween(f, { Position = UDim2.fromScale(x, y), Rotation = rot })
		if v.Scale then tween(v.Scale, { Scale = scale }) end
	end
end

return HandFan
