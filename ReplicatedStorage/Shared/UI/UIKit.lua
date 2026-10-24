-- ReplicatedStorage/Shared/UI/UIKit
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Theme = require(script.Parent.Theme)

local UIKit = {}
UIKit.Settings = { Voice = true, VFX = true, Tomato = true }
UIKit.toastParent = nil

local CENTER = Vector2.new(0.5, 0.5)

function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UIKit.corner(radius)
	return UIKit.new("UICorner", { CornerRadius = radius or UDim.new(0.2, 0) })
end

function UIKit.stroke(color, thickness)
	return UIKit.new("UIStroke", {
		Color = color or Theme.Color.Outline,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.tween(inst, time, props, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UIKit.sfx(name)
	local folder = SoundService:FindFirstChild("SFX")
	local sound = folder and folder:FindFirstChild(name)
	if sound then SoundService:PlayLocalSound(sound) end
end

function UIKit.label(p)
	local lbl = UIKit.new("TextLabel", {
		Name = p.Name or "Label",
		BackgroundTransparency = 1,
		Font = p.Font or Theme.Font,
		Text = p.Text or "",
		TextColor3 = p.Color or Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Center,
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		Parent = p.Parent,
	}, {
		UIKit.new("UIStroke", { Thickness = p.StrokeThickness or 2, Color = Theme.Color.Outline }),
		UIKit.new("UITextSizeConstraint", { MaxTextSize = p.MaxTextSize or 40 }),
	})
	return lbl
end

-- ปุ่มเด้งดึ๋ง: ขยายตอนชี้ หดตอนกด
function UIKit.button(p)
	local btn = UIKit.new("TextButton", {
		Name = p.Name or "Button",
		Size = p.Size or UDim2.fromScale(0.2, 0.1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = p.Color or Theme.Color.Yellow,
		AutoButtonColor = false,
		Text = "",
		Parent = p.Parent,
	}, { UIKit.corner(), UIKit.stroke(nil, 3) })
	local label = UIKit.label({
		Text = p.Text, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, Parent = btn, MaxTextSize = p.MaxTextSize,
	})
	local scale = UIKit.new("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function() UIKit.tween(scale, 0.1, { Scale = 1.07 }) end)
	btn.MouseLeave:Connect(function() UIKit.tween(scale, 0.1, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() UIKit.tween(scale, 0.05, { Scale = 0.9 }) end)
	btn.MouseButton1Up:Connect(function() UIKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then UIKit.shake(btn) return end
		UIKit.sfx("Click")
		if p.OnClick then p.OnClick() end
	end)
	return btn, label
end

function UIKit.setColor(btn, color)
	btn:SetAttribute("BaseColor", color)
	if not btn:GetAttribute("Disabled") then btn.BackgroundColor3 = color end
end

function UIKit.setDisabled(btn, disabled)
	if btn:GetAttribute("BaseColor") == nil then btn:SetAttribute("BaseColor", btn.BackgroundColor3) end
	btn:SetAttribute("Disabled", disabled)
	btn.BackgroundColor3 = disabled and Theme.Color.Gray or btn:GetAttribute("BaseColor")
end

function UIKit.shake(gui)
	task.spawn(function()
		for _, r in { -8, 8, -5, 5, -2, 0 } do
			gui.Rotation = r
			task.wait(0.04)
		end
	end)
end

-- เอฟเฟกต์ย้วย: บีบแบนแล้วเด้งกลับ (ค่าติดลบ = ยืดสูง)
function UIKit.jelly(gui, amount)
	local base = gui:GetAttribute("BaseSize")
	if not base then
		base = gui.Size
		gui:SetAttribute("BaseSize", base)
	end
	amount = amount or 0.25
	gui.Size = UDim2.new(base.X.Scale * (1 + amount), base.X.Offset, base.Y.Scale * (1 - amount), base.Y.Offset)
	UIKit.tween(gui, 0.7, { Size = base }, Enum.EasingStyle.Elastic)
end

-- ตัวเลขดาเมจลอยขึ้น
function UIKit.popup(parent, text, color)
	local pop = UIKit.label({
		Text = text, Color = color or Theme.Color.Red, Size = UDim2.fromScale(1.2, 0.35),
		Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = CENTER, Parent = parent,
		MaxTextSize = 64, StrokeThickness = 3,
	})
	pop.ZIndex = 20
	UIKit.tween(pop, 0.9, { Position = UDim2.fromScale(0.5, -0.3), TextTransparency = 1 })
	UIKit.tween(pop:FindFirstChildOfClass("UIStroke"), 0.9, { Transparency = 1 })
	task.delay(0.9, function() pop:Destroy() end)
end

-- ฝนอีโมจิ (ใช้ตอนช่องเกตออกทอง/อึ หรือตอนชนะ)
function UIKit.rain(parent, emoji, count)
	for _ = 1, count or 20 do
		local x = math.random()
		local drop = UIKit.label({
			Text = emoji, Size = UDim2.fromScale(0.05, 0.08), Position = UDim2.fromScale(x, -0.1),
			Parent = parent, StrokeThickness = 0, MaxTextSize = 80,
		})
		UIKit.tween(drop, 1 + math.random(), {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.3, 1.15),
			Rotation = math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(2.2, function() drop:Destroy() end)
	end
end

function UIKit.toast(text, color)
	local parent = UIKit.toastParent
	if not parent then warn(text) return end
	local box = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.4, 0.07), Position = UDim2.fromScale(0.5, -0.1), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = color or Theme.Color.Pink, ZIndex = 50, Parent = parent,
	}, { UIKit.corner(), UIKit.stroke() })
	UIKit.label({ Text = text, Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = box })
	UIKit.tween(box, 0.35, { Position = UDim2.fromScale(0.5, 0.1) }, Enum.EasingStyle.Back)
	task.delay(2, function()
		UIKit.tween(box, 0.3, { Position = UDim2.fromScale(0.5, -0.1) })
		task.wait(0.3)
		box:Destroy()
	end)
end

-- หน้าต่างป๊อปอัป (ใช้ทำหน้า เด็ค / กาชา / ตั้งค่า)
function UIKit.panel(parent, title, color)
	local dim = UIKit.new("Frame", {
		Name = "Panel_" .. title, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Active = true, Visible = false, Parent = parent,
	})
	local box = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.72, 0.78), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = CENTER,
		BackgroundColor3 = Theme.Color.Panel, Active = true, Parent = dim,
	}, { UIKit.corner(UDim.new(0.04, 0)), UIKit.stroke(nil, 4) })
	local scale = UIKit.new("UIScale", { Parent = box })
	local header = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.5, 0.12), Position = UDim2.fromScale(0.5, 0), AnchorPoint = CENTER,
		BackgroundColor3 = color or Theme.Color.Pink, Parent = box,
	}, { UIKit.corner(), UIKit.stroke(nil, 4) })
	UIKit.label({ Text = title, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER, Parent = header })
	local content = UIKit.new("Frame", {
		Name = "Content", Size = UDim2.fromScale(0.94, 0.82), Position = UDim2.fromScale(0.03, 0.12),
		BackgroundTransparency = 1, Parent = box,
	})

	local panel = { Root = dim, Content = content }
	function panel.Open()
		dim.Visible = true
		scale.Scale = 0.6
		UIKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	function panel.Close()
		dim.Visible = false
	end
	local close = UIKit.button({
		Text = "✖", Color = Theme.Color.Red, Size = UDim2.fromScale(0.08, 0.1),
		Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0.6, 0.4), Parent = box, OnClick = panel.Close,
	})
	UIKit.new("UIAspectRatioConstraint", { Parent = close })
	return panel
end

return UIKit