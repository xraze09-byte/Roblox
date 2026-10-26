-- MatchUI เต็มวงจร: build -> StateUpdate -> glow/perf/timer -> MatchEnded -> match ที่ 2
local function mod(path) for inst, info in pairs(H.sources) do if info.path:find(path, 1, true) then return H.load(inst) end end error("no " .. path) end
local MatchUI, Perf, Config = mod("UIClient/MatchUI.lua"), mod("UI/Perf.lua"), mod("Shared/Config.lua")
local fails = 0
local function check(name, cond, extra)
	print((cond and "ok   " or "FAIL ") .. name .. (extra and ("  " .. tostring(extra)) or ""))
	if not cond then fails += 1 end
end
local RS = H.game:GetService("RunService")
local remotes = H.RS:FindFirstChild("Remotes")
local function ev(n) return remotes:FindFirstChild(n).OnClientEvent end

local gui, overlay = H.newInstance("Frame"), H.newInstance("Frame")
local started, exited = 0, 0
local ok, err = pcall(MatchUI.Build, gui, overlay, { OnStart = function() started += 1 end, OnExit = function() exited += 1 end })
check("MatchUI.Build", ok, not ok and err or nil)
if not ok then return end

local function card(uid, cost, extra)
	local c = { Uid = uid, Id = uid, Name = uid, Type = "Character", Cost = cost, ATK = 2, HP = 3, MaxHP = 3, Rarity = "Rare", Element = "Sati", CanAttack = false }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end
local function state(id, mine, pts)
	return { matchId = id, isMyTurn = mine, myPoints = pts, myLeader = "L1", oppLeader = "L2", myHP = 30, oppHP = 30,
		myDeck = 10, myGrave = 0, oppHandCount = 3, oppDeck = 10, turnEndsAt = H.game:GetService("Workspace"):GetServerTimeNow() + 60,
		myHand = { card("h1", 1), card("h2", 5) }, myField = { card("f1", 2, { CanAttack = true }) }, oppField = {},
		oppGateFilled = false }
end
check("Perf starts High (lobby)", Perf.Name() == "High")
ev("StateUpdate"):Fire(state("m1", true, 3))
check("OnStart fired once", started == 1, started)
check("Perf Balanced in match", Perf.Name() == "Balanced", Perf.Name())

-- same state many times: ต้องไม่ error และ Perf ไม่กระตุก
for i = 1, 20 do ev("StateUpdate"):Fire(state("m1", i % 2 == 0, 3)) end
check("20 state updates, no handler errors", not (H.M.handlerErrors and #H.M.handlerErrors > 0), H.M.handlerErrors and H.M.handlerErrors[1])

-- timer RenderStepped ทำงาน
local okT = pcall(function() for _ = 1, 120 do RS.RenderStepped:Fire(1/60) end end)
check("timer loop 120 frames", okT)

-- จบแมตช์
ev("MatchEnded"):Fire(true, "LEADER_DOWN", "m1", 10)
H.M.pump(2)
check("Perf back to High after MatchEnded", Perf.Name() == "High", Perf.Name())
-- StateUpdate ที่มาช้าหลังจบ ห้ามเปิด Perf กลับ
ev("StateUpdate"):Fire(state("m1", true, 3))
check("late StateUpdate after end ignored", Perf.Name() == "High", Perf.Name())

-- แมตช์ที่ 2 (ต้องผ่าน exitMatch: หาปุ่มกลับ)
local function find(root, name) for _, d in ipairs(root:GetDescendants()) do if d.Name == name then return d end end end
local back
local pool = {}
for _, r in ipairs({ gui, overlay, H.game:GetService("Players").LocalPlayer and H.game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") }) do
	if r then for _, d in ipairs(r:GetDescendants()) do table.insert(pool, d) end end
end
for _, d in ipairs(pool) do if d.ClassName == "TextButton" and tostring(d.Text):find("กลับไปเดินเล่น", 1, true) then back = d end end
if not back then print("buttons seen:", #pool) end
check("back button found", back ~= nil)
if back then back.Activated:Fire() end
check("exit invoked", exited == 1, exited)
ev("StateUpdate"):Fire(state("m2", true, 5))
check("2nd match starts + Balanced", started == 2 and Perf.Name() == "Balanced", started .. "/" .. Perf.Name())
check("no handler errors overall", not (H.M.handlerErrors and #H.M.handlerErrors > 0), H.M.handlerErrors and H.M.handlerErrors[1])
print(fails == 0 and "MATCHUI PASS" or ("MATCHUI FAIL " .. fails))
