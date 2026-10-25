-- Lobby: floating layout. Checks (a) builds, (b) no full-screen opaque backdrop, (c) window hidden by default,
-- (d) menu toggles the window, (e) no overlap/off-screen of floating pieces over many viewport sizes.
local LobbyUI
for inst, info in pairs(H.sources) do if info.path:find("UIClient/LobbyUI.lua") then LobbyUI = H.load(inst) end end
local function find(root, name) for _, d in ipairs(root:GetDescendants()) do if d.Name == name then return d end end end
local function resolve(g, VW, VH)
	local function px(u) u = u or { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } }; return u.X.Scale * VW + u.X.Offset, u.Y.Scale * VH + u.Y.Offset end
	local w, h = px(g.Size)
	local c = g:FindFirstChildOfClass("UISizeConstraint")
	if c then
		local mn, mx = c.MinSize or { X = 0, Y = 0 }, c.MaxSize or { X = math.huge, Y = math.huge }
		w = math.max(mn.X, math.min(mx.X, w)); h = math.max(mn.Y, math.min(mx.Y, h))
	end
	local x, y = px(g.Position)
	local ap = g.AnchorPoint or { X = 0, Y = 0 }
	return x - ap.X * w, y - ap.Y * h, w, h
end
local function wait(sec) local t = os.clock() while os.clock() - t < sec do end end -- ผ่าน debounce ของปุ่ม (0.25s)
local function click(b) wait(0.3); b.Activated:Fire() end
local hud, overlay = H.newInstance("Frame"), H.newInstance("Frame")
local ok, err = pcall(LobbyUI.Build, hud, overlay)
print("Build ok:", ok, ok and "" or err)
if not ok then return end
local root = find(hud, "LobbyRoot")
print("LobbyRoot found:", root ~= nil)
print("Backdrop (opaque full-screen) present (expect false):", find(hud, "Backdrop") ~= nil)
local panel, menu, dock, gem = find(hud, "Panel"), find(hud, "Menu"), find(hud, "BattleDock"), find(hud, "GemBox")
print("Panel hidden by default (expect true):", panel.Visible == false)
print("BattleDock visible by default (expect true):", dock.Visible ~= false)
local btns = {}
for _, c in ipairs(menu:GetChildren()) do if c.ClassName == "TextButton" then btns[#btns + 1] = c end end
print("menu buttons (expect 5):", #btns)
-- click "Deck"
click(btns[1])
print("after click Deck -> panel visible (expect true):", panel.Visible == true, " dock hidden (expect true):", dock.Visible == false)
click(btns[1])
print("click Deck again -> panel hidden (expect true):", panel.Visible == false, " dock visible (expect true):", dock.Visible ~= false)
for i, b in ipairs(btns) do click(b); click(find(hud, "Close")) end
print("open every tab then close: panel hidden (expect true):", panel.Visible == false)
-- layout matrix (window closed = default view)
local fails = 0
local function fire(sz) root.AbsoluteSize = { X = sz[1], Y = sz[2] } end
for _, sz in ipairs({ {1920,1080}, {1280,720}, {980,310}, {1024,184}, {800,400}, {640,360}, {844,390} }) do
	local VW, VH = sz[1], sz[2]
	fire(sz)
	local boxes = {}
	for name, g in pairs({ GemBox = gem, Menu = menu, BattleDock = dock }) do
		if g == nil then print('NIL piece', name) end
		if g and (g.Size == nil or g.Position == nil) then print('missing Size/Position on', name, g.Size, g.Position) end
		local x, y, w, h = resolve(g, VW, VH); boxes[#boxes + 1] = { name = name, x = x, y = y, w = w, h = h }
	end
	local bad = {}
	for i = 1, #boxes do
		local a = boxes[i]
		if a.x < -1 or a.y < -1 or a.x + a.w > VW + 1 or a.y + a.h > VH + 1 then bad[#bad + 1] = "OFFSCREEN " .. a.name end
		for j = i + 1, #boxes do local b = boxes[j]
			if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then bad[#bad + 1] = "OVERLAP " .. a.name .. "/" .. b.name end end
	end
	-- coverage of the screen by floating pieces (center must stay clear)
	local covered = 0
	for _, b in ipairs(boxes) do covered += b.w * b.h end
	fails += #bad
	print(string.format("%4dx%-4d %s covered=%2d%% %s", VW, VH, #bad == 0 and "ok  " or "FAIL", 100 * covered / (VW * VH), table.concat(bad, ", ")))
end
print("LOBBY_LAYOUT", fails == 0 and "PASS" or ("FAIL " .. fails))
print("handler errors:", #(MOCK.handlerErrors or {}))
