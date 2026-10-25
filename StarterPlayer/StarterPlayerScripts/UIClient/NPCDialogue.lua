-- StarterPlayer/StarterPlayerScripts/UIClient/NPCDialogue.lua
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local NPCDialogue = {}

local FACE = { Normal = "🙂", Happy = "😆", Angry = "😡", Shock = "😱", Sad = "😭", Smug = "😏", Sus = "🤨" }
local BG = { Normal = C.Yellow, Happy = C.Lime, Angry = C.Red, Shock = C.Blue, Sad = C.Purple, Smug = C.Pink, Sus = C.Orange }
local SLOW = { ["!"] = true, ["?"] = true, ["."] = true, ["…"] = true }

local function loopTween(inst, t, props)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
	tw:Play()
	return tw
end

local function express(st, expr)
	if st.loop then st.loop:Cancel(); st.loop = nil end
	local p = st.portrait
	p.Rotation, p.Position = 0, st.basePos
	if expr == "Happy" then
		st.loop = loopTween(p, 0.22, { Position = st.basePos - UDim2.fromOffset(0, 12) })
	elseif expr == "Angry" then
		UIKit.shake(st.holder, 14); UIKit.sfx("Honk", 0.2)
	elseif expr == "Shock" then
		UIKit.jelly(p, 0.5); UIKit.sfx("Boing", 0.1)
	elseif expr == "Sad" then
		st.loop = loopTween(p, 1.2, { Rotation = -8, Position = st.basePos + UDim2.fromOffset(0, 8) })
	elseif expr == "Smug" then
		st.loop = loopTween(p, 0.8, { Rotation = 10 })
	else
		st.loop = loopTween(p, 1.4, { Position = st.basePos - UDim2.fromOffset(0, 4) }) -- ขยับเบาๆ เหมือนหายใจ
	end
end

-- lines[i] = { Speaker, Expr, Text, Speed, Next, Choices = {{ Text, Goto, OnPick, Close }} }
-- opts = { Speaker = "ชื่อหลัก", Portraits = { [Speaker] = { Happy = "rbxassetid://..." } }, OnDone = function() end }
function NPCDialogue.Play(parent, lines, opts)
	opts = opts or {}
	local root = UIKit.new("TextButton", { Name = "Dialogue", Text = "", AutoButtonColor = false, BackgroundColor3 = C.TableDark,
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 150, Parent = parent })
	UIKit.tween(root, 0.2, { BackgroundTransparency = 0.55 })

	local boxHolder, box = UIKit.comicBox({ Parent = root, Size = UDim2.fromScale(0.78, 0.26), Position = UDim2.fromScale(0.57, 0.96),
		AnchorPoint = Vector2.new(0.5, 1), Color = C.Panel, ShadowOffset = 8, StrokeThickness = 4, ZIndex = 151 })
	local portHolder, portFace = UIKit.comicBox({ Parent = root, Size = UDim2.fromScale(0.16, 0.3), Position = UDim2.fromScale(0.03, 0.96),
		AnchorPoint = Vector2.new(0, 1), Color = C.Yellow, Tilt = -4, ZIndex = 155, Clip = true })
	local portrait = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05),
		ZIndex = 157, Parent = portFace })
	local emoji = UIKit.new("TextLabel", { BackgroundTransparency = 1, TextScaled = true, Text = FACE.Normal, Size = UDim2.fromScale(1, 1),
		ZIndex = 158, Parent = portrait })
	local img = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit,
		Visible = false, ZIndex = 158, Parent = portrait })
	local _, nameFace = UIKit.comicBox({ Parent = boxHolder, Size = UDim2.new(0.3, 0, 0, 46), Position = UDim2.new(0.03, 0, 0, -16),
		AnchorPoint = Vector2.new(0, 0.5), Color = C.Pink, Tilt = -3, ZIndex = 158 })
	local nameLbl = UIKit.label({ Text = "", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		MaxTextSize = 28, ZIndex = 160, Parent = nameFace })
	local text = UIKit.label({ Text = "", Color = C.Ink, StrokeThickness = 0, Wrap = true, AlignX = Enum.TextXAlignment.Left,
		AlignY = Enum.TextYAlignment.Top, Size = UDim2.new(1, -40, 1, -46), Position = UDim2.new(0, 20, 0, 34), MaxTextSize = 30,
		ZIndex = 153, Parent = box })
	local arrow = UIKit.label({ Text = "▼", Color = C.Pink, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -26, 1, -20),
		AnchorPoint = CENTER, Visible = false, ZIndex = 154, Parent = box })
	loopTween(arrow, 0.35, { Position = arrow.Position + UDim2.fromOffset(0, 6) })
	local choices = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.new(0.95, 0, 0.7, -10),
		AnchorPoint = Vector2.new(1, 1), ZIndex = 170, Parent = root }, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }) })

	local st = { portrait = portrait, holder = portHolder, basePos = portrait.Position }
	local idx, typing, skip, waitingChoice, finished = 0, false, false, false, false

	local function finish()
		if finished then return end
		finished = true
		if st.loop then st.loop:Cancel() end
		UIKit.tween(root, 0.2, { BackgroundTransparency = 1 })
		UIKit.tween(UIKit.getScale(boxHolder), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UIKit.tween(UIKit.getScale(portHolder), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(UIKit.dur(0.2), function() root:Destroy() end)
		if opts.OnDone then opts.OnDone() end
	end

	local show
	local function jump(i)
		if i and lines[i] then show(i) else finish() end
	end

	show = function(i)
		idx = i
		local line = lines[i]
		local speaker = line.Speaker or opts.Speaker or "???"
		local expr = line.Expr or "Normal"
		if nameLbl.Text ~= speaker then UIKit.bounceText(nameLbl, speaker, 0.25) end
		local set = opts.Portraits and opts.Portraits[speaker]
		local imgId = set and set[expr]
		img.Visible, emoji.Visible = imgId ~= nil, imgId == nil
		if imgId then img.Image = imgId else emoji.Text = FACE[expr] or FACE.Normal end
		portFace.BackgroundColor3 = BG[expr] or C.Yellow
		express(st, expr)

		for _, c in ipairs(choices:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
		arrow.Visible = false
		UIKit.setText(text, line.Text or "")
		local gs = {}
		for first, last in utf8.graphemes(text.Text) do table.insert(gs, text.Text:sub(first, last)) end
		text.MaxVisibleGraphemes = 0
		typing, skip = true, false

		task.spawn(function()
			for g = 1, #gs do
				if skip or idx ~= i or finished then break end
				text.MaxVisibleGraphemes = g
				if g % 2 == 0 then UIKit.sfx("Blip", 0.3) end
				task.wait(UIKit.dur(SLOW[gs[g]] and 0.18 or (line.Speed or 0.028)))
			end
			if idx ~= i or finished then return end
			text.MaxVisibleGraphemes = -1
			typing = false
			if line.Choices then
				waitingChoice = true
				for k, ch in ipairs(line.Choices) do
					UIKit.button({ Parent = choices, Text = ch.Text, Color = ({ C.Lime, C.Blue, C.Orange, C.Pink })[(k - 1) % 4 + 1],
						Size = UDim2.new(1, 0, 0, 54), LayoutOrder = k, Tilt = (k % 2 == 0) and 2 or -2, MaxTextSize = 24, ZIndex = 171,
						OnClick = function()
							if not waitingChoice then return end
							waitingChoice = false
							if ch.OnPick then ch.OnPick() end
							if ch.Close then finish() else jump(ch.Goto or idx + 1) end
						end })
				end
			else
				arrow.Visible = true
			end
		end)
	end

	root.Activated:Connect(function()
		if finished or waitingChoice then return end
		if typing then skip = true return end
		UIKit.sfx("Click", 0.2)
		jump(lines[idx].Next or idx + 1)
	end)

	local s = UIKit.getScale(boxHolder)
	s.Scale = 0.3
	UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	jump(1)
	return { Close = finish }
end

return NPCDialogue