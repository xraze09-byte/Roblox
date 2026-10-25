-- ไฟล์ลูกของ UIClient: GateRoller (ModuleScript)
-- ฉากสุ่มช่องเกตแบบสล็อตแมชชีน: หมุนเร็ว ค่อยๆ ช้าลง แล้วเฉลยผลพร้อมเอฟเฟกต์ (ผลจริงมาจากเซิร์ฟเวอร์)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Style"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))

local GateRoller = {}

GateRoller.Outcome = {
	Golden = { Text = "ร่างทองออกแสง x3", Color = S.C.Accent, Sub = "แจ็กพอต! พลังคูณสาม" },
	Pumped = { Text = "ปั่นติด x1.5", Color = S.C.Good, Sub = "เกตเปิดติด บัฟมา" },
	Normal = { Text = "ธรรมดา x1", Color = S.C.Info, Sub = "เฉยๆ ไม่มีอะไรเกิดขึ้น" },
	Droopy = { Text = "ย้วย x0.5", Color = S.C.Violet, Sub = "เกลือ... พลังเหลือครึ่ง" },
	Poop = { Text = "กลายเป็นก้อนอึ", Color = S.C.Brown, Sub = "HP 1 / ATK 0 ขอแสดงความเสียใจ" },
}
local ORDER = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }
local CENTER = Vector2.new(0.5, 0.5)

function GateRoller.Play(parent, card, outcomeId, isMine)
	local dim = S.new("Frame", {
		Name = "GateRoll", Size = UDim2.fromScale(1, 1), BackgroundColor3 = S.C.Bg,
		BackgroundTransparency = 1, Active = true, ZIndex = 60, Parent = parent,
	})
	S.tween(dim, 0.2, { BackgroundTransparency = 0.35 })

	local title = S.box({ Color = isMine and S.C.Pink or S.C.Violet, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.5, 0.09), Radius = 14, Stroke = 4, Rotation = -2, ZIndex = 61, Parent = dim })
	S.new("UISizeConstraint", { MinSize = Vector2.new(260, 44), MaxSize = Vector2.new(620, 90), Parent = title })
	S.text({ Text = isMine and "ช่องเกตของคุณกำลังสุ่ม!" or "ช่องเกตฝั่งศัตรูกำลังสุ่ม!", Font = S.Font.Heavy, Max = 40,
		XAlign = "Center", Stroke = 3, ZIndex = 62, Parent = title })
	S.pulse(title, 0.97, 1.04, 0.5)

	-- การ์ดที่ส่งเข้าเกต (ซ่อนไว้ก่อน เปิดตอนเฉลย)
	local holder = S.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.3, 0.44), ZIndex = 61, Parent = dim })
	local view = CardFace.new(card, {})
	view.Root.ZIndex = 62
	view.Root.Visible = false
	view.Root.Parent = holder

	-- วงแหวนรุ้งหมุนข้างหลังการ์ด
	local ring = S.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.36, 0.52), ZIndex = 60, Parent = dim }, {
		S.corner(999), S.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	S.rainbow(S.stroke(Color3.new(1, 1, 1), 10, ring), 240)
	S.spin(ring, 60)

	local slot = S.box({ Color = S.C.Panel, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.46, 0.12), Radius = 16, Stroke = 5, ZIndex = 61, Parent = dim })
	S.new("UISizeConstraint", { MinSize = Vector2.new(260, 54), MaxSize = Vector2.new(620, 110), Parent = slot })
	local slotText = S.text({ Font = S.Font.Heavy, Max = 46, XAlign = "Center", Stroke = 3, ZIndex = 62,
		Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 1), Parent = slot })
	local sub = S.text({ Font = S.Font.Bold, Max = 18, XAlign = "Center", Color = S.C.TextDim, Stroke = 1.5, ZIndex = 62,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.875), Size = UDim2.fromScale(0.6, 0.06), Parent = dim })

	-- หมุนเร็ว แล้วค่อยๆ ช้าลง (เร้าใจ)
	local step = 0.04
	local i = math.random(#ORDER)
	while step < 0.3 do
		i = i % #ORDER + 1
		local o = GateRoller.Outcome[ORDER[i]]
		slotText.Text = o.Text
		slot.BackgroundColor3 = o.Color
		slot.Rotation = math.random(-3, 3)
		task.wait(step)
		step *= 1.15
	end

	-- ผลจริง (ได้มาจากเซิร์ฟเวอร์ ฝั่งผู้เล่นแค่แสดงผล)
	local result = GateRoller.Outcome[outcomeId] or GateRoller.Outcome.Normal
	slotText.Text = result.Text
	sub.Text = result.Sub
	slot.BackgroundColor3 = result.Color
	slot.Rotation = -2
	S.bump(slot, 0.35)
	view.Root.Visible = true
	view:PopIn()

	if outcomeId == "Golden" then
		S.confetti(dim, { S.C.Accent, S.C.Orange, Color3.new(1, 1, 1) }, 45)
		S.wobble(title, 1.5)
	elseif outcomeId == "Pumped" then
		S.confetti(dim, { S.C.Good, S.C.Lime }, 20)
	elseif outcomeId == "Poop" then
		S.confetti(dim, { S.C.Brown, Color3.fromRGB(90, 56, 30) }, 25)
		S.wobble(view.Root, 1.5)
		S.tween(view.Root, 0.5, { Rotation = 8 }, Enum.EasingStyle.Bounce)
	elseif outcomeId == "Droopy" then
		S.tween(view.Root, 0.8, { Rotation = 14, Position = UDim2.fromScale(0.5, 0.6) }, Enum.EasingStyle.Quad)
	end

	task.wait(2.2)
	S.tween(dim, 0.2, { BackgroundTransparency = 1 })
	for _, d in dim:GetDescendants() do
		if d:IsA("GuiObject") then pcall(function() d.Visible = false end) end
	end
	task.wait(0.2)
	dim:Destroy()
end

return GateRoller
