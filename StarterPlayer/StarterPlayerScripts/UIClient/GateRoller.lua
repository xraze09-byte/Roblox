-- ไฟล์ลูกของ UIClient: GateRoller (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local CardView = require(UIFolder:WaitForChild("CardView"))

local GateRoller = {}
local ORDER = { "Golden", "Pumped", "Normal", "Droopy", "Poop" }
local CENTER = Vector2.new(0.5, 0.5)

function GateRoller.Play(parent, card, outcomeId, isMine)
	local dim = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, Active = true, Parent = parent,
	})
	UIKit.tween(dim, 0.2, { BackgroundTransparency = 0.35 })
	UIKit.label({
		Text = isMine and "🎲 ช่องเกตของคุณกำลังสุ่ม!" or "🎲 ช่องเกตฝั่งศัตรูกำลังสุ่ม!",
		Size = UDim2.fromScale(0.8, 0.08), Position = UDim2.fromScale(0.5, 0.1), AnchorPoint = CENTER, Parent = dim, MaxTextSize = 50,
	})

	local view = CardView.new(card, { Size = UDim2.fromScale(0.3, 0.45) })
	view.Frame.AnchorPoint = CENTER
	view.Frame.Position = UDim2.fromScale(0.5, 0.42)
	view.Frame.Visible = false
	view.Frame.Parent = dim

	local slot = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.45, 0.11), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = CENTER,
		BackgroundColor3 = Theme.Color.Panel, Parent = dim,
	}, { UIKit.corner(), UIKit.stroke(nil, 5) })
	local slotText = UIKit.label({ Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = slot, MaxTextSize = 56 })

	-- หมุนเร็ว แล้วค่อยๆ ช้าลง (เร้าใจ)
	local step = 0.04
	local i = math.random(#ORDER)
	while step < 0.3 do
		i = i % #ORDER + 1
		local o = Theme.Gate[ORDER[i]]
		slotText.Text = o.Text
		slot.BackgroundColor3 = o.Color
		UIKit.sfx("Tick")
		task.wait(step)
		step *= 1.15
	end

	-- ผลจริง (ได้มาจากเซิร์ฟเวอร์ ฝั่งผู้เล่นแค่แสดงผล)
	local result = Theme.Gate[outcomeId] or Theme.Gate.Normal
	slotText.Text = result.Text
	slot.BackgroundColor3 = result.Color
	UIKit.jelly(slot, 0.4)
	view.Frame.Visible = true
	view:PopIn()

	if outcomeId == "Golden" then
		UIKit.sfx("Jackpot")
		UIKit.rain(dim, "✨", 30)
	elseif outcomeId == "Poop" then
		UIKit.sfx("Fart")
		UIKit.rain(dim, "💩", 25)
		UIKit.shake(view.Body)
	else
		UIKit.sfx("Reveal")
	end

	task.wait(2.2)
	dim:Destroy()
end

return GateRoller