-- ไฟล์ลูกของ UIClient: GateRoller (ModuleScript)
-- ประตูมิติสุ่ม (RNG Event Gate): สล็อตหมุนเร็วแล้วค่อยช้าลง เปิดการ์ด แล้วระเบิดเอฟเฟกต์ตามผล
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local S = require(UIFolder:WaitForChild("Style"))
local CardFace = require(script.Parent:WaitForChild("CardFace"))

local GateRoller = {}
local ORDER = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }
local CENTER = Vector2.new(0.5, 0.5)
local SHOUT = {
	Golden = "โคตรโกง!!!", Pumped = "ปั่นติด!", Normal = "เฉยๆ...", Droopy = "ย้วยยย", Poop = "เกลือจัด",
}

-- วงประตูมิติหมุนวน (วงแหวนสีหลายชั้น)
local function portal(parent, z)
	local ring = S.new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.42, 0.42), ZIndex = z, Parent = parent }, { S.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local colors = { S.C.Pink, S.C.Sky, S.C.Lime, S.C.Accent }
	for i = 1, 4 do
		local r = S.new("Frame", { BackgroundColor3 = colors[i], AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - (i - 1) * 0.2, 1 - (i - 1) * 0.2), ZIndex = z + i, Parent = ring }, { S.round() })
		S.outline(r, 3)
		S.gradient(r, colors[i], colors[i % 4 + 1], i * 45)
		task.spawn(function()
			local dir = (i % 2 == 0) and -1 or 1
			while r.Parent do
				local g = r:FindFirstChildOfClass("UIGradient")
				if g then g.Rotation = (g.Rotation + dir * 4) % 360 end
				task.wait()
			end
		end)
	end
	return ring
end

function GateRoller.Play(parent, card, outcomeId, isMine)
	local dim = S.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = S.C.Bg, BackgroundTransparency = 1,
		Active = true, ZIndex = 40, Parent = parent,
	})
	S.tween(dim, 0.2, { BackgroundTransparency = 0.3 })
	S.shout({
		Text = isMine and "ประตูมิติของคุณกำลังสุ่ม!" or "ประตูมิติฝั่งศัตรูกำลังสุ่ม!", Color = S.C.Accent, Max = 44,
		Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.5, 0.1), AnchorPoint = CENTER, ZIndex = 42, Parent = dim,
	})
	local ring = portal(dim, 41)
	S.pulse(ring, 0.05, 0.5)

	local view = CardFace.new(card, { Size = UDim2.fromScale(0.3, 0.42), ZIndex = 50 })
	view.Root.AnchorPoint = CENTER
	view.Root.Position = UDim2.fromScale(0.5, 0.45)
	view.Root.Visible = false
	view.Root.Parent = dim

	local slotWrap, slotLabel = S.sticker({ Text = "...", Color = S.C.Paper, Max = 40, Rotation = 0,
		Size = UDim2.fromScale(0.5, 0.12), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = CENTER, ZIndex = 45, Parent = dim })
	local slotBody = slotWrap:FindFirstChild("Body")

	-- หมุนเร็ว แล้วค่อยๆ ช้าลง (เร้าใจ)
	local step = 0.04
	local i = math.random(#ORDER)
	while step < 0.32 do
		i = i % #ORDER + 1
		local o = Theme.Gate[ORDER[i]]
		slotLabel.Text = o.Text
		slotBody.BackgroundColor3 = o.Color
		S.sfx("Tick", 1 + (0.32 - step))
		task.wait(step)
		step *= 1.16
	end

	-- ผลจริง (ได้มาจากเซิร์ฟเวอร์ ฝั่งผู้เล่นแค่แสดงผล)
	local result = Theme.Gate[outcomeId] or Theme.Gate.Normal
	slotLabel.Text = result.Text
	slotBody.BackgroundColor3 = result.Color
	S.punch(slotWrap, 0.5)
	S.jiggle(slotWrap, 6)
	view.Root.Visible = true
	view:PopIn()
	S.sparkle(ring, result.Color, 24, 1.2)

	local shout = S.shout({ Text = SHOUT[outcomeId] or "", Color = result.Color, Max = 72, Rotation = -8,
		Size = UDim2.fromScale(0.8, 0.14), Position = UDim2.fromScale(0.5, 0.26), AnchorPoint = CENTER, ZIndex = 60, Parent = dim })
	S.punch(shout, 0.8)

	if outcomeId == "Golden" then
		S.sfx("Jackpot")
		S.confetti(dim, 60)
		S.pulse(view.Root, 0.08, 0.4)
	elseif outcomeId == "Poop" then
		S.sfx("Fart")
		S.jiggle(view.Root, 14)
		S.tween(view.Body, 0.6, { BackgroundColor3 = result.Color })
	elseif outcomeId == "Pumped" then
		S.sfx("Reveal")
		S.confetti(dim, 25)
	else
		S.sfx("Reveal")
	end

	task.wait(2.2)
	S.tween(dim, 0.25, { BackgroundTransparency = 1 })
	S.tween(view.Scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.25)
	dim:Destroy()
end

return GateRoller
