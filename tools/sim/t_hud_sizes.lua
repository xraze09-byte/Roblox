-- HUD layout across viewport sizes: no overlaps, nothing off-screen.
local MatchHUD
for inst, info in pairs(H.sources) do if info.path:find("UIClient/MatchHUD.lua") then MatchHUD = H.load(inst) end end

local function resolve(g, VW, VH)
	local function px(u) return u.X.Scale * VW + u.X.Offset, u.Y.Scale * VH + u.Y.Offset end
	local w, h = px(g.Size)
	local ar = g:FindFirstChildOfClass("UIAspectRatioConstraint")
	local c = g:FindFirstChildOfClass("UISizeConstraint")
	if c then w = math.max(c.MinSize.X, math.min(c.MaxSize.X, w)); h = math.max(c.MinSize.Y, math.min(c.MaxSize.Y, h)) end
	if ar then h = w / ar.AspectRatio end
	local x, y = px(g.Position)
	return x - g.AnchorPoint.X * w, y - g.AnchorPoint.Y * h, w, h
end

local sizes = { {1920,1080}, {1280,720}, {980,310}, {1024,184}, {800,200}, {640,150}, {844,390}, {568,320} }
local fails = 0
for _, sz in ipairs(sizes) do
	local VW, VH = sz[1], sz[2]
	local gui = H.newInstance("Frame"); gui.AbsoluteSize = { X = VW, Y = VH }
	local hud = MatchHUD.new(gui, {})
	hud.root.AbsoluteSize = { X = VW, Y = VH }
	hud:Apply({ myHP = 30, oppHP = 30, myShield = 0, oppShield = 0, isMyTurn = true, turnEndsAt = 0, myPoints = 5, mySpent = false,
		myHand = { { Cost = 0, Effect = { Kind = "Shield" } } } })
	local boxes = {}
	local function add(name, g) if g.Visible ~= false then local x, y, w, h = resolve(g, VW, VH); boxes[#boxes + 1] = { name = name, x = x, y = y, w = w, h = h } end end
	add("HPme", hud.hp.me.holder); add("HPopp", hud.hp.opp.holder); add("Points", hud.pointsHolder)
	add("Skip", hud.skip); add("ShieldHint", hud.shieldHint); add("Timer", hud.timerHolder)
	-- turn label sits relative to timer
	do
		local tx, ty, tw, th = resolve(hud.timerHolder, VW, VH)
		local l = hud.turnLbl
		local lw, lh = l.Size.X.Scale * tw + l.Size.X.Offset, l.Size.Y.Scale * th + l.Size.Y.Offset
		local lx = tx + l.Position.X.Scale * tw + l.Position.X.Offset - l.AnchorPoint.X * lw
		local ly = ty + l.Position.Y.Scale * th + l.Position.Y.Offset - l.AnchorPoint.Y * lh
		boxes[#boxes + 1] = { name = "TurnLbl", x = lx, y = ly, w = lw, h = lh }
	end
	local bad = {}
	for i = 1, #boxes do
		local a = boxes[i]
		if a.x < -1 or a.y < -1 or a.x + a.w > VW + 1 or a.y + a.h > VH + 1 then bad[#bad + 1] = "OFFSCREEN " .. a.name end
		for j = i + 1, #boxes do
			local b = boxes[j]
			if not ((a.name == "Timer" and b.name == "TurnLbl") or (a.name == "TurnLbl" and b.name == "Timer")) then
				if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then bad[#bad + 1] = "OVERLAP " .. a.name .. "/" .. b.name end
			end
		end
	end
	fails += #bad
	print(string.format("%4dx%-4d %s %s", VW, VH, #bad == 0 and "ok  " or "FAIL", table.concat(bad, ", ")))
	hud:Destroy()
end
print("HUD_SIZES", fails == 0 and "PASS" or ("FAIL " .. fails))
