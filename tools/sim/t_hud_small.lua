local MatchHUD
for inst, info in pairs(H.sources) do if info.path:find("UIClient/MatchHUD.lua") then MatchHUD = H.load(inst) end end
local gui = H.newInstance("Frame")
local ok, hud = pcall(MatchHUD.new, gui, {})
print("MatchHUD.new:", ok, ok and "" or hud)
if not ok then return end
local function px(u, vw, vh) return u.X.Scale * vw + u.X.Offset, u.Y.Scale * vh + u.Y.Offset end
local VW, VH = tonumber(rawget(_G,"VWX")) or 1024, tonumber(rawget(_G,"VHX")) or 184
local boxes = {}
local function add(name, g)
	local w, h = px(g.Size, VW, VH)
	local c = g:FindFirstChildOfClass("UISizeConstraint")
	if c then w = math.max(c.MinSize.X, math.min(c.MaxSize.X, w)); h = math.max(c.MinSize.Y, math.min(c.MaxSize.Y, h)) end
	local x, y = px(g.Position, VW, VH)
	x = x - g.AnchorPoint.X * w; y = y - g.AnchorPoint.Y * h
	boxes[#boxes + 1] = { name = name, x = x, y = y, w = w, h = h }
end
add("HP me", hud.hp.me.holder); add("HP opp", hud.hp.opp.holder); add("Points", hud.pointsHolder)
add("Skip", hud.skip); add("ShieldHint", hud.shieldHint)
for _, d in ipairs(gui:GetDescendants()) do if d.Name == "Timer" then add("Timer", d) end end
for _, b in ipairs(boxes) do print(string.format("%-10s x=%4d y=%4d w=%3d h=%3d", b.name, b.x, b.y, b.w, b.h)) end
local overlaps = 0
for i = 1, #boxes do for j = i + 1, #boxes do
	local a, b = boxes[i], boxes[j]
	if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
		overlaps += 1; print("OVERLAP:", a.name, "x", b.name) end end end
print("viewport", VW .. "x" .. VH, "overlaps:", overlaps)
