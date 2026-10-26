local function path(p) for inst, info in pairs(H.sources) do if info.path == p then return inst end end error("no " .. p) end
local store = {}
rawset(H.game:GetService("DataStoreService"), "GetDataStore", function() return { GetAsync = function(_, k) return store[k] end, UpdateAsync = function(_, k, fn) store[k] = fn(store[k]) return store[k] end } end)
local FloatHUD = H.load(path("StarterPlayer/StarterPlayerScripts/UIClient/FloatHUD.lua"))
local hudGui, overlay
local INSET = 36 -- Roblox topbar (TopbarSafeInsets)
local function rect(g, VW, VH)
	local function px(u) return u.X.Scale * VW + u.X.Offset, u.Y.Scale * VH + u.Y.Offset end
	local w, h = px(g.Size); local x, y = px(g.Position); local ap = g.AnchorPoint or { X = 0, Y = 0 }
	return { x = x - ap.X * w, y = y - ap.Y * h, w = w, h = h }
end
local sizes = { {1920,1080}, {1280,720}, {1024,410}, {980,310}, {844,390}, {667,375}, {568,320} }
local total = 0
for _, sz in ipairs(sizes) do
	local VW, VH = sz[1], sz[2]
	hudGui, overlay = H.newInstance("ScreenGui"), H.newInstance("ScreenGui")
	hudGui.AbsoluteSize = H.globals.Vector2.new(VW, VH)
	FloatHUD.Build(hudGui, overlay, { OnModal = function() end })
	local items = {}
	for _, d in ipairs(hudGui:GetChildren()) do
		if tostring(d.Name):find("^Fab_") then
			local r = rect(d, VW, VH)
			local tag = d:FindFirstChild("Tag")
			local tagH = tag and 24 or 0
			items[#items + 1] = { name = d.Name, x = r.x, y = r.y, w = r.w, h = r.h + tagH - 10 }
		end
	end
	local issues = {}
	for _, a in ipairs(items) do
		if a.y < 0 then issues[#issues + 1] = a.name .. " cut off at TOP (y=" .. math.floor(a.y) .. ")" end
		if a.y + a.h > VH then issues[#issues + 1] = a.name .. " cut off at BOTTOM" end
		if a.x < 0 then issues[#issues + 1] = a.name .. " cut off at LEFT" end
		if a.x + a.w > VW then issues[#issues + 1] = a.name .. " cut off at RIGHT" end
	end
	for i = 1, #items do for j = i + 1, #items do
		local a, b = items[i], items[j]
		if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then issues[#issues + 1] = "OVERLAP " .. a.name .. " x " .. b.name end
	end end
	total += #issues
	print(("%4dx%-4d %s"):format(VW, VH, #issues == 0 and "ok" or table.concat(issues, "; ")))
end
print("FAB_LAYOUT issues:", total)
