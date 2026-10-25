-- StarterPlayer/StarterPlayerScripts/UIClient/FarmUI.lua
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local FarmUI = {}

local function now() return workspace:GetServerTimeNow() end

local function sample()
	local t = now()
	return {
		{ Id = "GlueGarden", Name = "สวนกาว", Emoji = "🌻", Color = C.Lime, Rate = 6, Cap = 120, LastClaim = t - 600, Level = 1 },
		{ Id = "GemMine", Name = "เหมืองเจม", Emoji = "💎", Color = C.Blue, Rate = 1, Cap = 20, LastClaim = t - 900, Level = 1 },
		{ Id = "MemePond", Name = "บ่อเลี้ยงมีม", Emoji = "🐸", Color = C.Pink, Rate = 3, Cap = 60, LastClaim = t - 300, Level = 1 },
	}
end

local function fly(panel, emoji, fromGui, toGui, n)
	local pa, ps = panel.AbsolutePosition, panel.AbsoluteSize
	local function rel(g)
		local c = g.AbsolutePosition + g.AbsoluteSize / 2 - pa
		return UDim2.fromScale(c.X / ps.X, c.Y / ps.Y)
	end
	local a, b = rel(fromGui), rel(toGui)
	for i = 1, n do
		task.delay(i * 0.04, function()
			local l = UIKit.new("TextLabel", { BackgroundTransparency = 1, Text = emoji, TextScaled = true, Size = UDim2.fromOffset(34, 34),
				AnchorPoint = CENTER, Position = a, ZIndex = 90, Parent = panel })
			local mid = a:Lerp(b, 0.5) + UDim2.fromScale((math.random() - 0.5) * 0.3, -0.2)
			UIKit.tween(l, 0.25, { Position = mid })
			task.delay(UIKit.dur(0.25), function()
				if l.Parent then UIKit.tween(l, 0.3, { Position = b }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
			end)
			Debris:AddItem(l, UIKit.dur(0.6) + 0.1)
		end)
	end
	UIKit.sfx("Coin", 0.2)
end

-- opts = { Farms = {...}, Wallet = number, WalletEmoji = "🪙",
--          OnClaim = function(id) return ok, amount end, OnUpgrade = function(id) return ok, newFarm end }
function FarmUI.Open(parent, opts)
	opts = opts or {}
	local farms = opts.Farms or sample()
	local wallet, wEmoji = opts.Wallet or 0, opts.WalletEmoji or "🪙"
	local panel = UIKit.panel(parent, "ฟาร์มชิลๆ", C.Green)
	local walletBadge, walletLbl = UIKit.badge(panel, wEmoji .. " " .. wallet, C.Yellow, { Size = UDim2.fromOffset(190, 42),
		Position = UDim2.new(0, 22, 0, 52), Tilt = -3, MaxTextSize = 26, ZIndex = 60 })

	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -130), Position = UDim2.new(0, 20, 0, 110), Parent = panel }, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

	local views = {}
	for i, f in ipairs(farms) do
		local holder, face = UIKit.comicBox({ Parent = row, Size = UDim2.fromScale(0.31, 1), LayoutOrder = i, Color = C.CardBg,
			Tilt = (i % 2 == 0) and 1.5 or -1.5 })
		local z = face.ZIndex
		UIKit.new("Frame", { BackgroundColor3 = f.Color or C.Lime, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.45), ZIndex = z, Parent = face },
			{ UIKit.corner(Theme.Radius) })
		local icon = UIKit.label({ Text = f.Emoji or "🌱", StrokeThickness = 0, Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.5, 0.06),
			AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 90, ZIndex = z + 1, Parent = face })
		TweenService:Create(icon, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 8, Position = icon.Position - UDim2.fromScale(0, 0.02) }):Play()
		UIKit.label({ Text = f.Name, Size = UDim2.fromScale(0.9, 0.09), Position = UDim2.fromScale(0.5, 0.47), AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 28, ZIndex = z + 1, Parent = face })
		local lvBadge, lvLbl = UIKit.badge(holder, "Lv." .. (f.Level or 1), C.Purple, { Size = UDim2.fromOffset(70, 28),
			Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0), Tilt = 8, ZIndex = z + 3 })
		local track = UIKit.new("Frame", { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(0.86, 0.07), Position = UDim2.fromScale(0.5, 0.6),
			AnchorPoint = Vector2.new(0.5, 0), ZIndex = z + 1, Parent = face }, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(C.Outline, 2.5) })
		local fill = UIKit.new("Frame", { BackgroundColor3 = f.Color or C.Lime, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = z + 2,
			Parent = track }, { UIKit.corner(UDim.new(1, 0)) })
		local stored = UIKit.label({ Text = "0/" .. f.Cap, Size = UDim2.fromScale(0.9, 1.3), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = CENTER, MaxTextSize = 18, ZIndex = z + 3, Parent = track })
		UIKit.label({ Text = string.format("+%s / นาที", tostring(f.Rate)), Color = C.Yellow, Size = UDim2.fromScale(0.8, 0.06),
			Position = UDim2.fromScale(0.5, 0.69), AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 18, ZIndex = z + 1, Parent = face })
		local fullBadge = UIKit.badge(holder, "เต็ม!!", C.Red, { Size = UDim2.fromOffset(76, 30), Position = UDim2.new(0, -6, 0, 6), Tilt = -10, ZIndex = z + 3 })
		fullBadge.Visible = false

		local v = { fill = fill, stored = stored, fullBadge = fullBadge, value = 0 }
		v.claim = UIKit.button({ Parent = face, Text = "เก็บ!", Color = C.Lime, Size = UDim2.fromScale(0.86, 0.11), Position = UDim2.fromScale(0.5, 0.77),
			AnchorPoint = Vector2.new(0.5, 0), ZIndex = z + 2, Debounce = 0.8, OnClick = function()
				if v.value < 1 then return end
				local ok, amount
				if opts.OnClaim then ok, amount = opts.OnClaim(f.Id) else ok, amount = true, v.value end -- ถ้าไม่ส่ง OnClaim มาจะเป็นโหมดตัวอย่าง
				if not ok then UIKit.toast(tostring(amount or "เก็บไม่ได้ ลองใหม่"), C.Red) return end
				amount = tonumber(amount) or 0
				f.LastClaim = now()
				fly(panel, f.Emoji or wEmoji, v.claim, walletBadge, math.clamp(amount, 3, 12))
				task.delay(UIKit.dur(0.45), function()
					UIKit.countTo(walletLbl, wallet, wallet + amount, 0.6, wEmoji .. " %d")
					wallet += amount
				end)
				FX.sparkles(holder, f.Color or C.Lime, 10)
			end })
		UIKit.button({ Parent = face, Text = "อัปเกรด", Color = C.Orange, Size = UDim2.fromScale(0.6, 0.08), Position = UDim2.fromScale(0.5, 0.9),
			AnchorPoint = Vector2.new(0.5, 0), Lip = 4, MaxTextSize = 20, ZIndex = z + 2, Debounce = 1, OnClick = function()
				if not opts.OnUpgrade then UIKit.toast("ยังไม่เปิดระบบอัปเกรด", C.Orange) return end
				local ok, nf = opts.OnUpgrade(f.Id)
				if not ok then UIKit.toast(tostring(nf or "เงินไม่พอ!"), C.Red) return end
				if type(nf) == "table" then for k, val in pairs(nf) do f[k] = val end end
				UIKit.bounceText(lvLbl, "Lv." .. (f.Level or 1), 0.4)
				FX.sparkles(holder, C.Yellow, 16)
				UIKit.sfx("LevelUp")
			end })
		views[f.Id] = v
	end

	local acc, tick = 0, 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		tick += 1
		for _, f in ipairs(farms) do
			local v = views[f.Id]
			local val = math.min(f.Cap, math.floor(math.max(0, now() - (f.LastClaim or now())) / 60 * f.Rate))
			v.value = val
			v.fill.Size = UDim2.fromScale(val / f.Cap, 1)
			v.stored.Text = string.format("%d/%d", val, f.Cap)
			v.fullBadge.Visible = val >= f.Cap
			if val >= f.Cap and tick % 5 == 0 then UIKit.jelly(v.fullBadge, 0.25) end
			UIKit.setDisabled(v.claim, val < 1)
		end
	end)
	panel.Destroying:Connect(function() conn:Disconnect() end)
	return panel
end

return FarmUI