-- MatchUI v2: ตรวจว่าส่วนสำคัญไม่ซ้อนกันมั่ว / ไม่ล้นจอ ใน viewport ต่าง ๆ (คำนวณจาก scale+offset ของ mock)
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local MatchUI = mod("UIClient/MatchUI.lua")
local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
assert(pcall(MatchUI.Build, gui, overlay, {}))
local fails = 0
local function find(root, name) for _, d in ipairs(root:GetDescendants()) do if d.Name == name then return d end end end
local root = find(gui, "MatchRoot")
local function box(g, VW, VH)
	local function px(u) return u.X.Scale * VW + u.X.Offset, u.Y.Scale * VH + u.Y.Offset end
	local w, h = px(g.Size); local x, y = px(g.Position)
	local ap = g.AnchorPoint or { X = 0, Y = 0 }
	return { x = x - ap.X * w, y = y - ap.Y * h, w = w, h = h }
end
-- เก็บเฟรมหลัก = ลูกตรงของ MatchRoot ที่เป็น Frame/TextButton มี Size (ไม่รวมพื้นหลังเต็มจอ)
local parts = {}
for _, ch in ipairs(root:GetChildren()) do
	if (ch.ClassName == "Frame" or ch.ClassName == "TextButton") and ch.Size and not (ch.Size.X.Scale == 1 and ch.Size.Y.Scale == 1) and ch.Name ~= "FX" then
		table.insert(parts, ch)
	end
end
print("top-level parts:", #parts)
local overl = 0
for i = 1, #parts do for j = i + 1, #parts do
	local a, b = box(parts[i], 1000, 600), box(parts[j], 1000, 600)
	if a.x < b.x + b.w - 1 and b.x < a.x + a.w - 1 and a.y < b.y + b.h - 1 and b.y < a.y + a.h - 1 then
		overl += 1; print("OVERLAP", parts[i].Name or "?", parts[j].Name or "?", string.format("(%d,%d,%d,%d) vs (%d,%d,%d,%d)", a.x, a.y, a.w, a.h, b.x, b.y, b.w, b.h))
	end
end end
for _, p in ipairs(parts) do
	local b = box(p, 1000, 600)
	if b.x < -1 or b.y < -1 or b.x + b.w > 1001 or b.y + b.h > 601 then fails += 1; print("OFFSCREEN", p.Name, b.x, b.y, b.w, b.h) end
end
print("overlaps:", overl, "offscreen:", fails)
