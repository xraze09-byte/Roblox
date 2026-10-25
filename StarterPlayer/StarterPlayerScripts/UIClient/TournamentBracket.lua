-- StarterPlayer/StarterPlayerScripts/UIClient/TournamentBracket.lua
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)

local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local TournamentBracket = {}

local SAMPLE = {
	{ { A = "ไก่ทอดซีอิ๊ว", B = "ลุงเป็ด", Winner = "A" }, { A = "แมวส้ม", B = "คุณ", Winner = "B" } },
	{ { A = "เจ้าปลาทอง", B = "ไก่ทอดซีอิ๊ว", From = { nil, 1 } }, { A = "บอสถุงเท้า", B = "คุณ", From = { nil, 2 } } },
	{ { From = { 1, 2 } } },
}

-- opts = { Rounds = {...}, RoundNames = {...}, Me = "ชื่อเรา", Title = "...", OnJoin = function() end }
function TournamentBracket.Open(parent, opts)
	opts = opts or {}
	local rounds = opts.Rounds or SAMPLE
	local names = opts.RoundNames or { "รอบแรก", "รอบรอง", "ชิงแชมป์!!" }
	local me, R = opts.Me or "คุณ", #rounds
	local panel = UIKit.panel(parent, opts.Title or "ทัวร์นาเมนต์มหากาว", C.Blue)
	local area = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -110), Position = UDim2.new(0, 20, 0, 84), Parent = panel })

	local colW = 0.82 / R
	local boxW, boxH = colW * 0.8, 0.18
	local function xc(r) return (r - 0.5) * colW end

	-- คำนวณตำแหน่งแกน Y: แมตช์ที่มี From จะอยู่ตรงกลางระหว่างแมตช์ต้นทาง
	local ys = {}
	for r, matches in ipairs(rounds) do
		ys[r] = {}
		for j, m in ipairs(matches) do
			local y
			if m.From and r > 1 then
				local a = m.From[1] and ys[r - 1][m.From[1]]
				local b = m.From[2] and ys[r - 1][m.From[2]]
				y = (a and b) and (a + b) / 2 or a or b
			end
			ys[r][j] = y or (j - 0.5) / #matches
		end
	end

	local function line(x1, y1, x2, y2, lit)
		UIKit.new("Frame", { BackgroundColor3 = lit and C.Yellow or C.White, BackgroundTransparency = lit and 0 or 0.5, BorderSizePixel = 0,
			AnchorPoint = CENTER, Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
			Size = UDim2.new(math.abs(x2 - x1), 5, math.abs(y2 - y1), 5), ZIndex = 2, Parent = area })
	end
	for r = 2, R do
		for j, m in ipairs(rounds[r]) do
			for k = 1, 2 do
				local src = m.From and m.From[k]
				if src and ys[r - 1][src] then
					local sy, ty = ys[r - 1][src], ys[r][j]
					local x1, x2 = xc(r - 1) + boxW / 2, xc(r) - boxW / 2
					local mx, lit = (x1 + x2) / 2, rounds[r - 1][src].Winner ~= nil
					line(x1, sy, mx, sy, lit); line(mx, sy, mx, ty, lit); line(mx, ty, x2, ty, lit)
				end
			end
		end
	end

	for r, matches in ipairs(rounds) do
		UIKit.label({ Text = names[r] or ("รอบ " .. r), Color = r == R and C.Yellow or C.White, Size = UDim2.new(colW, 0, 0, 34),
			Position = UDim2.new(xc(r), 0, 0, -30), AnchorPoint = CENTER, Tilt = -3, MaxTextSize = 28, Parent = area })
		for j, m in ipairs(matches) do
			local holder, face = UIKit.comicBox({ Parent = area, Size = UDim2.fromScale(boxW, boxH), Position = UDim2.fromScale(xc(r), ys[r][j]),
				AnchorPoint = CENTER, Color = C.TableDark, Tilt = (j % 2 == 0) and 1.5 or -1.5, ShadowOffset = 4, ZIndex = 5 })
			local z = face.ZIndex
			for k, key in ipairs({ "A", "B" }) do
				local name = m[key] or "???"
				local won, lost = m.Winner == key, m.Winner ~= nil and m.Winner ~= key
				local row = UIKit.new("Frame", { BackgroundColor3 = won and C.Green or lost and C.Gray or C.Purple, BackgroundTransparency = lost and 0.3 or 0,
					Size = UDim2.new(1, -10, 0.5, -6), Position = UDim2.new(0, 5, (k - 1) * 0.5, 4), ZIndex = z + 1, Parent = face },
					{ UIKit.corner(8), UIKit.stroke(name == me and C.Pink or C.Outline, name == me and 4 or 2) })
				UIKit.label({ Text = (won and "👑 " or lost and "💀 " or "") .. name, AlignX = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -12, 1, -4), Position = UDim2.new(0, 8, 0, 2), MaxTextSize = 20, ZIndex = z + 2, Parent = row })
			end
			UIKit.badge(holder, "VS", C.Yellow, { Size = UDim2.fromOffset(40, 24), Position = UDim2.new(1, 4, 0.5, 0), AnchorPoint = CENTER,
				Tilt = 10, MaxTextSize = 16, ZIndex = z + 4 })
		end
	end

	-- ถ้วยแชมป์
	local final = rounds[R] and rounds[R][1]
	local champ = final and final.Winner and final[final.Winner]
	local fy = ys[R] and ys[R][1] or 0.5
	line(xc(R) + boxW / 2, fy, 0.9, fy, champ ~= nil)
	local trophy = UIKit.label({ Text = "🏆", StrokeThickness = 0, Size = UDim2.fromOffset(110, 110), Position = UDim2.fromScale(0.93, fy),
		AnchorPoint = CENTER, MaxTextSize = 100, ZIndex = 8, Parent = area })
	trophy.TextTransparency = champ and 0 or 0.6
	UIKit.label({ Text = champ or "???", Color = C.Yellow, Size = UDim2.new(0.16, 0, 0, 34), Position = UDim2.new(0.93, 0, fy, 66),
		AnchorPoint = CENTER, MaxTextSize = 26, ZIndex = 8, Parent = area })
	if champ then
		TweenService:Create(trophy, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 10 }):Play()
		FX.sparkles(area, C.Yellow, 20, Vector2.new(0.93, fy))
		UIKit.rain(panel, "🎉", 14)
	end

	if opts.OnJoin then
		UIKit.button({ Parent = panel, Text = "ลงแข่ง!", Color = C.Lime, Size = UDim2.fromOffset(170, 56), Position = UDim2.new(1, -20, 1, -14),
			AnchorPoint = Vector2.new(1, 1), Tilt = -3, Debounce = 1, OnClick = opts.OnJoin })
	end
	return panel
end

return TournamentBracket