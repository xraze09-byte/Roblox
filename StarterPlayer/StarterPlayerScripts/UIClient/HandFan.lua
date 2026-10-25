-- StarterPlayerScripts/UIClient/HandFan (ModuleScript)
-- การ์ดในมือ (สูงสุด 5 ใบ) เรียงเป็นพัดโค้ง: ใบใหม่ลอยมาจากกองการ์ด ชี้แล้วลอยขึ้น/ขยาย/ดันใบข้างออก
-- ใช้คู่กับ CardFace (v.Root) และ DragController (ลากวางยังทำงานตามปกติเพราะ Root ไม่ถูกย้าย parent)
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))

local HandFan = {}
HandFan.MAX = Config.MAX_HAND or 5

local CFG = {
	Spread = 0.17,    -- ระยะห่างสูงสุดระหว่างใบ (สัดส่วนความกว้าง)
	Width = 0.7,      -- ความกว้างรวมสูงสุดของทั้งมือ
	Angle = 6,        -- องศาต่อใบ
	MaxAngle = 26,
	Arc = 0.16,       -- ใบริมสุดต่ำลงเท่าไร (สัดส่วนความสูง)
	HoverY = 0.98,    -- ตำแหน่งตอนชี้ (ยึดขอบล่าง การ์ดขยายขึ้นด้านบน)
	HoverScale = 1.35,
	Push = 0.06,
	CardH = 0.88,     -- ความสูงการ์ดเทียบกับความสูงคอนเทนเนอร์
	Draw = UDim2.fromScale(1.2, 1.5), -- การ์ดใหม่ลอยมาจากมุมขวาล่าง (กองการ์ด)
}
local TI = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local hooked = setmetatable({}, { __mode = "k" })
local hoveredRoot = nil

function HandFan.Container(parent, position, size)
	local f = S.new("Frame", { Name = "Hand", AnchorPoint = Vector2.new(0.5, 0), Position = position,
		Size = size, BackgroundTransparency = 1, Parent = parent })
	return f
end

local function scaleOf(root)
	local s = root:FindFirstChild("FanScale")
	if not s then s = S.new("UIScale", { Name = "FanScale", Parent = root }) end
	return s
end

-- ขนาดการ์ดเป็นพิกเซลจากความสูงคอนเทนเนอร์ (ไม่ใช้ UIAspectRatioConstraint เพราะต้องคุมตำแหน่งเอง)
local function cardSize(container)
	local h = math.max(container.AbsoluteSize.Y * CFG.CardH, 40)
	return UDim2.fromOffset(h * CardFace.ASPECT, h)
end

function HandFan.Layout(container, views)
	local list = {}
	for _, v in pairs(views) do
		if v.Root.Parent == container then table.insert(list, v) end
	end
	table.sort(list, function(a, b) return a.Root.LayoutOrder < b.Root.LayoutOrder end)
	local n = #list
	if n == 0 then return end

	local spread = math.min(CFG.Spread, CFG.Width / math.max(n - 1, 1))
	local angle = math.min(CFG.Angle, CFG.MaxAngle / n)
	local mid = (n + 1) / 2
	local half = math.max(mid - 1, 1)
	local size = cardSize(container)

	local hoverIndex
	for i, v in ipairs(list) do
		if v.Root == hoveredRoot then hoverIndex = i end
	end
	if not hoverIndex then hoveredRoot = nil end -- ใบที่ชี้อยู่ถูกใช้ไปแล้ว

	for i, v in ipairs(list) do
		local root = v.Root
		local off = i - mid
		local norm = off / half
		local x, y, rot, scale = 0.5 + off * spread, 1 + norm * norm * CFG.Arc, off * angle, 1
		root.ZIndex = 2 + i
		if hoverIndex then
			if i == hoverIndex then
				y, rot, scale = CFG.HoverY, 0, CFG.HoverScale
				root.ZIndex = 40
			elseif i < hoverIndex then
				x -= CFG.Push
			else
				x += CFG.Push
			end
		end

		root.AnchorPoint = Vector2.new(0.5, 1)
		root.Size = size
		if not hooked[root] then
			hooked[root] = true
			-- จั่ว: ลอยมาจากกองการ์ดพร้อมหมุน
			root.Position = CFG.Draw
			root.Rotation = 35
			S.sfx("Draw")
			local function enter() hoveredRoot = root HandFan.Layout(container, views) end
			local function leave()
				if hoveredRoot == root then hoveredRoot = nil HandFan.Layout(container, views) end
			end
			root.MouseEnter:Connect(enter)
			root.MouseLeave:Connect(leave)
			root.SelectionGained:Connect(enter)
			root.SelectionLost:Connect(leave)
		end
		TweenService:Create(root, TI, { Position = UDim2.fromScale(x, y), Rotation = rot }):Play()
		TweenService:Create(scaleOf(root), TI, { Scale = scale }):Play()
	end
end

-- ป้ายนับการ์ดในมือ "มือ 3/5" (เด้งเวลาตัวเลขเปลี่ยน)
function HandFan.Counter(parent)
	local wrap, lbl = S.sticker({ Text = "มือ 0/" .. HandFan.MAX, Color = S.C.Sky, Max = 16, Rotation = 4,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(96, 32), Parent = parent })
	local api = { Root = wrap }
	function api:Set(n)
		local full = n >= HandFan.MAX
		S.setText(lbl, ("มือ %d/%d"):format(n, HandFan.MAX))
		wrap.Body.BackgroundColor3 = full and S.C.Hot or S.C.Sky
		lbl.TextColor3 = full and S.C.White or S.C.Ink
	end
	return api
end

return HandFan
