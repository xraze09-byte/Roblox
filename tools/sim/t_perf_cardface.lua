-- ทดสอบ Perf / CardFace / HandFan / UIKit.shake / Style.scroll (headless)
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no module " .. path) end
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end

local Perf = mod("UI/Perf.lua")
local Settings = mod("UI/Settings.lua")
local UIKit = mod("UI/UIKit.lua")
local CardFace = mod("UIClient/CardFace.lua")
local HandFan = mod("UIClient/HandFan.lua")
local Style = mod("UI/Style.lua")

-- Perf: ระดับกราฟิก
check("Perf outside match = High", Perf.Name() == "High")
Perf.SetMatch(true)
check("Perf in match = Balanced", Perf.Name() == "Balanced")
check("Balanced: no ambient", Perf.get("ambient") == false)
check("Balanced: shine only Legend+", Perf.allowShine("Legend") and not Perf.allowShine("Epic") and not Perf.allowShine("Rare"))
Perf.SetMatch(false)
check("High: shine Rare+", Perf.allowShine("Rare") and not Perf.allowShine("Common"))
local seen = {}
Perf.Changed:Connect(function(n) table.insert(seen, n) end)
Settings.Set("Quality", "Low")
check("Quality=Low forces Low + fires Changed", Perf.Name() == "Low" and seen[#seen] == "Low")
check("Low: sparkles at 25%", Perf.count(12) == 3)
Settings.Set("Quality", "Auto")
check("Quality=Auto returns to High outside match", Perf.Name() == "High")
check("High sparkle count unchanged", Perf.count(12) == 12)
Perf.SetMatch(true)
check("Balanced sparkle halved", Perf.count(12) == 6)
Perf.SetMatch(false)

-- Auto-Low จาก FPS ตก (ตามตาราง: <40 นาน 3 วิ → Low, ตกครั้งที่ 2 → ล็อก Low)
local RS = H.game:GetService("RunService")
local function frames(dt, secs) for _ = 1, math.floor(secs / dt) do RS.RenderStepped:Fire(dt) end end
Perf.SetMatch(true)
frames(1/20, 1)     -- warm: EMA ลงมาต่ำกว่า 40
frames(1/20, 4)
check("FPS 20 for >3s -> Low", Perf.Name() == "Low", Perf.Name())
frames(1/70, 10)    -- FPS ดีขึ้นนาน >8s -> กลับ Balanced
check("FPS recovers -> Balanced", Perf.Name() == "Balanced", Perf.Name())
frames(1/20, 5)     -- ตกครั้งที่ 2
check("2nd drop -> Low", Perf.Name() == "Low", Perf.Name())
frames(1/70, 30)
check("2nd drop locks Low for match", Perf.Name() == "Low", Perf.Name())
Perf.SetMatch(false)
check("SetMatch(false) resets to High", Perf.Name() == "High", Perf.Name())

-- UIKit.Settings.VFX <-> Effects
Settings.Set("Effects", false)
check("VFX follows Effects=false", UIKit.Settings.VFX == false and UIKit.effectsOn() == false)
Settings.Set("Effects", true)
check("VFX follows Effects=true", UIKit.Settings.VFX == true)

-- CardFace: API เดิมครบ + ทำงานกับการ์ดทุกประเภท
local cards = {
	{ Uid = "a", Id = "x", Name = "ตัวละคร", Type = "Character", Cost = 3, ATK = 4, HP = 5, MaxHP = 7, Rarity = "Epic", Element = "Sati", Keywords = { "Rush", "Taunt" }, WeaponName = "ไม้", WeaponDur = 2 },
	{ Uid = "b", Id = "y", Name = "อาวุธ", Type = "Weapon", Cost = 2, Bonus = 2, Durability = 3, Rarity = "Rare", Desc = "ตีแรง" },
	{ Uid = "c", Id = "z", Name = "เวท", Type = "Spell", Cost = 1, Rarity = "Common", Flavor = "แค่ฟลาเวอร์" },
	{ Uid = "d", Id = "w", Name = "ไม่มีอะไร", Type = "Spell" },
}
for _, c in ipairs(cards) do
	local ok, f = pcall(CardFace.new, c)
	check("CardFace.new " .. c.Type .. " (" .. c.Id .. ")", ok, not ok and f or nil)
	if ok then
		for _, m in ipairs({ "Update", "SetGlow", "SetStatus", "SetCostWarning", "SetLift", "PopIn", "Flash", "Destroy" }) do
			check("  method " .. m, type(f[m]) == "function")
		end
		for _, g in ipairs({ "playable", "ready", "target", "hover", "selected", "none" }) do
			local okg, e = pcall(f.SetGlow, f, g)
			if not okg then check("  SetGlow " .. g, false, e) end
		end
		pcall(f.SetLift, f, true); pcall(f.PopIn, f)
	end
end
local f = CardFace.new(cards[1])
check("KeywordText kept", CardFace.KeywordText(cards[1]) ~= "")
check("Flavor shown when no desc", (function() local g = CardFace.new(cards[3]); return g.Desc.Text:find("ฟลาเวอร์") ~= nil end)())
check("Hurt HP colors differ", f.HpBox.BackgroundColor3 ~= CardFace.new({ Type = "Character", HP = 7, MaxHP = 7, Cost = 1, ATK = 1 }).HpBox.BackgroundColor3)
-- โดนตี → Flash แล้ว glow กลับ
f:SetGlow("ready")
f:Update({ Uid = "a", Id = "x", Name = "ตัวละคร", Type = "Character", Cost = 3, ATK = 4, HP = 2, MaxHP = 7, Rarity = "Epic", Element = "Sati" })
check("Flash sets Flashing", f.Flashing == true)
-- สเกลไม่ชนกัน: UIKit.getScale(root) ต้องไม่ใช่ UIScale ของ Body
local sRoot = UIKit.getScale(f.Root)
check("HandFan scale distinct from face scale", sRoot ~= f.Scale and f.Scale.Parent == f.Body)

-- HandFan: จัดมือ + Reject ไม่พัง
local container = HandFan.Container(H.newInstance("Frame"))
local views = {}
for i = 1, 3 do views[i] = CardFace.new({ Uid = "h" .. i, Type = "Character", Cost = i, ATK = i, HP = i, Name = "n" .. i }) end
local okL, eL = pcall(HandFan.Layout, container, views)
check("HandFan.Layout", okL, not okL and eL or nil)
local okR, eR = pcall(HandFan.Reject, views[1])
check("HandFan.Reject", okR, not okR and eR or nil)
local okH, eH = pcall(HandFan.SetHeld, container, views[2], true)
check("HandFan.SetHeld", okH, not okH and eH or nil)
local okL2, eL2 = pcall(HandFan.Layout, container, { views[1], views[2], views[3], CardFace.new({ Uid = "h4", Type = "Spell", Cost = 1 }) })
check("HandFan.Layout draw 1 more", okL2, not okL2 and eL2 or nil)

-- UIKit.shake ไม่พังเมื่อ gui = nil / ไม่มี parent
check("shake(nil) safe", pcall(UIKit.shake, nil))
check("shake(frame)", pcall(UIKit.shake, H.newInstance("Frame")))

-- Style.scroll
local sc = Style.scroll({ Parent = H.newInstance("Frame") })
check("Style.scroll builds", sc ~= nil)

print(fails == 0 and "PERF_CARDFACE PASS" or ("PERF_CARDFACE FAIL " .. fails))
print("handler errors:", H.M.handlerErrors and #H.M.handlerErrors or 0)
