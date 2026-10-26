-- Lobby v2 layout: แถบบน / เมนูซ้าย / หน้าต่างเนื้อหา ต้องไม่ทับกันและไม่ล้นจอ ในทุกขนาด viewport
-- (โครงทั้งหมดใช้ Scale ล้วน จึงคำนวณจาก Size/Position + UISizeConstraint/AspectRatio ของ mock)
local LobbyUI
for inst, info in pairs(H.sources) do if info.path:find("UIClient/LobbyUI.lua") then LobbyUI = H.load(inst) end end
local function find(root, pred) for _, d in ipairs(root:GetDescendants()) do if pred(d) then return d end end end
local hud, overlay = H.newInstance("Frame"), H.newInstance("Frame")
local ok, err = pcall(LobbyUI.Build, hud, overlay)
print("Build ok:", ok, ok and "" or err)
if not ok then return end
H.M.pump(2)
local root = find(hud, function(d) return d.Name == "LobbyRoot" end)
print("LobbyRoot found:", root ~= nil)
print("Backdrop (opaque full-screen) present (expect false):", find(hud, function(d) return d.Name == "Backdrop" end) ~= nil)
local top = find(root, function(d) return d.ClassName == "Frame" and d.Size.X.Scale == 0.97 and d.Size.Y.Scale == 0.11 end)
local nav = find(root, function(d) return d.ClassName == "Frame" and d.Size.X.Scale == 0.185 and d.Size.Y.Scale == 0.83 end)
local content = find(root, function(d) return d.ClassName == "Frame" and d.Size.X.Scale == 0.77 and d.Size.Y.Scale == 0.83 end)
print("top/nav/content found:", top ~= nil, nav ~= nil, content ~= nil)
local function resolve(g, VW, VH)
	local function px(u) return u.X.Scale * VW + u.X.Offset, u.Y.Scale * VH + u.Y.Offset end
	local w, h = px(g.Size); local x, y = px(g.Position)
	return { x = x, y = y, w = w, h = h }
end
local fails = 0
for _, sz in ipairs({ {1920,1080}, {1280,720}, {980,310}, {1024,184}, {800,400}, {640,360}, {844,390}, {568,320} }) do
	local VW, VH = sz[1], sz[2]
	local boxes = { Top = resolve(top, VW, VH), Nav = resolve(nav, VW, VH), Content = resolve(content, VW, VH) }
	local bad = {}
	for n, a in pairs(boxes) do
		if a.x < -1 or a.y < -1 or a.x + a.w > VW + 1 or a.y + a.h > VH + 1 then bad[#bad + 1] = "OFFSCREEN " .. n end
	end
	local names = { "Top", "Nav", "Content" }
	for i = 1, 3 do for j = i + 1, 3 do
		local a, b = boxes[names[i]], boxes[names[j]]
		if a.x < b.x + b.w - 0.5 and b.x < a.x + a.w - 0.5 and a.y < b.y + b.h - 0.5 and b.y < a.y + a.h - 0.5 then bad[#bad + 1] = "OVERLAP " .. names[i] .. "/" .. names[j] end
	end end
	-- เมนูซ้าย 6 ปุ่มต้องสูงพอแตะได้ (>= 20px) ไม่งั้นรายงานเป็นคำเตือน ไม่ใช่ล้ม
	local btnH = boxes.Nav.h * 0.148
	if not next(bad) then print(string.format("%4dx%-4d ok    nav button h=%dpx", VW, VH, btnH)) else fails += 1; print(string.format("%4dx%-4d FAIL  %s", VW, VH, table.concat(bad, ", "))) end
end
print(fails == 0 and "LOBBY_LAYOUT\tPASS" or "LOBBY_LAYOUT\tFAIL")
print("handler errors:", H.M.handlerErrors and #H.M.handlerErrors or 0)
