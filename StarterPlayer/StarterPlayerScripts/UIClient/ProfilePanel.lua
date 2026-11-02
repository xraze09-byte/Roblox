-- UIClient/ProfilePanel.lua
-- Left: 3D avatar. Right: Overview | Stats | Card Book | Deck | Friend(locked) | Clan(locked)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))
local Kit = require(script.Parent:WaitForChild("MenuKit"))
local Net = require(script.Parent:WaitForChild("Net"))
local C = Kit.C

local ProfilePanel = {}

local RARITY_ORDER = { Mystic = 1, Legend = 2, Epic = 3, Rare = 4, Common = 5 }
local RARITY_COLOR = { Common = C.Gray, Rare = C.Blue, Epic = C.Purple, Legend = C.Orange, Mystic = C.Pink }
local TYPE_TH = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ" }
local TYPE_ORDER = { Character = 1, Spell = 2, Weapon = 3 }

local cardCache
local function allCards()
	if cardCache then return cardCache end
	local list = {}
	for id, def in CardData do
		if typeof(def) == "table" and def.Type and def.Type ~= "Leader" then
			table.insert(list, { Id = id, Def = def })
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = RARITY_ORDER[a.Def.Rarity] or 9, RARITY_ORDER[b.Def.Rarity] or 9
		if ra ~= rb then return ra < rb end
		local ca, cb = a.Def.Cost or 0, b.Def.Cost or 0
		if ca ~= cb then return ca < cb end
		return tostring(a.Id) < tostring(b.Id)
	end)
	cardCache = list
	return list
end

local function ownedCount(col)
	local n = 0
	for _, c in allCards() do
		if (col[c.Id] or 0) > 0 then n += 1 end
	end
	return n
end

local function fmtTime(s)
	s = math.floor(tonumber(s) or 0)
	local h, m = s // 3600, (s % 3600) // 60
	return h > 0 and ("%d ชม. %d นาที"):format(h, m) or ("%d นาที"):format(m)
end

local function statRow(parent, order, name, value, color)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.Dark
	f.Size = UDim2.new(1, 0, 0, 34)
	f.LayoutOrder = order
	f.Parent = parent
	Kit.corner(f, UDim.new(0, 8))
	Kit.label(f, name, C.White, {
		Position = UDim2.fromOffset(10, 5), Size = UDim2.new(0.6, -10, 1, -10),
		TextXAlignment = Enum.TextXAlignment.Left }, 20)
	Kit.label(f, tostring(value), color or C.Yellow, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.new(0.4, -10, 1, -10),
		TextXAlignment = Enum.TextXAlignment.Right }, 20)
end

-- ===== Tabs =====
local RENDER = {}

RENDER.Overview = function(host, d)
	local sc = Kit.scroll(host)
	local w, l = d.Wins or 0, d.Losses or 0
	local total = w + l
	statRow(sc, 1, "ชนะ / แพ้", ("%d / %d"):format(w, l))
	statRow(sc, 2, "อัตราชนะ", total > 0 and ("%d%%"):format(math.floor(w / total * 100 + 0.5)) or "-")
	statRow(sc, 3, "ชนะติดกันตอนนี้", d.Streak or 0)
	statRow(sc, 4, "ชนะติดกันสูงสุด", d.BestStreak or 0)
	statRow(sc, 5, "หอคอย", ("ชั้น %d"):format(d.TowerFloor or 1))
	statRow(sc, 6, "การ์ดที่สะสม", ("%d / %d"):format(ownedCount(d.Collection or {}), #allCards()))
	if d.Gems then statRow(sc, 7, "เพชร", d.Gems, C.Lime) end
end

RENDER.Fight = function(host, d)
	local F = d.Fight or {}
	local sc = Kit.scroll(host)
	local ROWS = {
		{ "Matches", "แมตช์ทั้งหมด" }, { "Wins", "ชนะ" }, { "Losses", "แพ้" }, { "Draws", "เสมอ" },
		{ "CardsPlayed", "การ์ดที่ลง" }, { "Attacks", "จำนวนครั้งที่โจมตี" }, { "KillsMade", "กำจัดการ์ดศัตรู" },
		{ "DamageToLeader", "ดาเมจใส่ผู้นำศัตรู" }, { "DamageTaken", "ดาเมจที่ได้รับ" }, { "HealDone", "ฮีลรวม" },
		{ "GateRolls", "ทอยประตู" },
	}
	for i, r in ROWS do statRow(sc, i, r[2], F[r[1]] or 0) end
	statRow(sc, #ROWS + 1, "เวลาเล่น", fmtTime(F.PlaySec))
end

RENDER.Index = function(host, d)
	local col = d.Collection or {}
	local cards = allCards()
	local owned = ownedCount(col)
	Kit.label(host, ("สะสมแล้ว %d / %d ใบ (%d%%)"):format(owned, #cards,
		#cards > 0 and math.floor(owned / #cards * 100) or 0), C.Yellow, { Size = UDim2.new(1, 0, 0, 26) })

	local sc = Instance.new("ScrollingFrame")
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 6
	sc.CanvasSize = UDim2.new()
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sc.Position = UDim2.fromOffset(0, 32)
	sc.Size = UDim2.new(1, 0, 1, -32)
	sc.Parent = host
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(96, 66)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = sc

	for i, c in cards do
		local n = col[c.Id] or 0
		local have = n > 0
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.BackgroundColor3 = have and (RARITY_COLOR[c.Def.Rarity] or C.Gray) or C.Dark
		f.Parent = sc
		Kit.corner(f, UDim.new(0, 8)); Kit.stroke(f, C.Ink, 2)
		Kit.label(f, have and (c.Def.Name or tostring(c.Id)) or "???", have and C.Ink or C.Gray, {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.62, -4), TextWrapped = true }, 16)
		Kit.label(f, have and ("x%d"):format(n) or (c.Def.Rarity or ""), have and C.Ink or C.Gray, {
			Position = UDim2.new(0, 4, 0.62, 0), Size = UDim2.new(1, -8, 0.38, -4) }, 14)
	end
end

RENDER.Deck = function(host, d)
	local deck = d.Deck or {}
	local counts, order = {}, {}
	for _, id in deck do
		if not counts[id] then counts[id] = 0; table.insert(order, id) end
		counts[id] += 1
	end
	table.sort(order, function(a, b)
		local da, db = CardData[a] or {}, CardData[b] or {}
		local ta, tb = TYPE_ORDER[da.Type] or 9, TYPE_ORDER[db.Type] or 9
		if ta ~= tb then return ta < tb end
		if (da.Cost or 0) ~= (db.Cost or 0) then return (da.Cost or 0) < (db.Cost or 0) end
		return tostring(a) < tostring(b)
	end)
	local sc = Kit.scroll(host)
	Kit.label(sc, ("เด็ค %d ใบ"):format(#deck), C.Yellow, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0 })
	if #order == 0 then
		Kit.label(sc, "ยังไม่ได้จัดเด็ค", C.Gray, { LayoutOrder = 1 })
	end
	for i, id in order do
		local def = CardData[id] or {}
		statRow(sc, i, ("[%d] %s"):format(def.Cost or 0, def.Name or tostring(id)),
			("%s x%d"):format(TYPE_TH[def.Type] or "-", counts[id]), RARITY_COLOR[def.Rarity])
	end
end

-- ===== 3D avatar =====
local function buildModel(vp, plr)
	local char = plr and plr.Character
	if not char then
		Kit.label(vp, "?", C.Gray, { Size = UDim2.fromScale(1, 1) }, 60)
		return
	end
	local old = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(char.Clone, char)
	char.Archivable = old
	if not ok or not clone then return end

	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

	local world = Instance.new("WorldModel")
	world.Parent = vp
	clone:PivotTo(CFrame.new())
	clone.Parent = world

	local cf, size = clone:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam
	local dist = (size.Y * 0.5) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.2
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, -dist), cf.Position)

	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent or not clone.Parent then conn:Disconnect() return end
		t += dt
		clone:PivotTo(CFrame.Angles(0, math.sin(t * 0.8) * 0.6, 0)) -- gentle sway
	end)
end

-- ===== Open =====
local openToken = 0

-- userId: nil = me. opts.From: Vector2 screen point to grow from
function ProfilePanel.Open(userId, opts)
	opts = opts or {}
	local lp = Players.LocalPlayer
	userId = userId or lp.UserId
	openToken += 1
	local my = openToken

	local target = Players:GetPlayerByUserId(userId)
	local isMe = userId == lp.UserId
	local w = Kit.open({
		Title = isMe and "โปรไฟล์ของฉัน" or ("โปรไฟล์ " .. (target and target.DisplayName or "")),
		Color = C.Yellow, From = opts.From,
	})
	local body = w.Body

	-- Left: avatar + name
	local left = Instance.new("Frame")
	left.BackgroundColor3 = C.Dark
	left.Size = UDim2.new(0.32, -6, 1, 0)
	left.Parent = body
	Kit.corner(left)

	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.Position = UDim2.fromOffset(6, 6)
	vp.Size = UDim2.new(1, -12, 1, -64)
	vp.Parent = left
	buildModel(vp, target)

	Kit.label(left, target and target.DisplayName or "-", C.White, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -28), Size = UDim2.new(1, -16, 0, 28) }, 24)
	Kit.label(left, target and ("@" .. target.Name) or "", C.Gray, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -6), Size = UDim2.new(1, -16, 0, 20) }, 16)

	-- Right: tabs + content
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.32, 6, 0, 0)
	right.Size = UDim2.new(0.68, -6, 1, 0)
	right.Parent = body

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 46)
	content.Size = UDim2.new(1, 0, 1, -46)
	content.Parent = right

	local data, currentTab = nil, "Overview"
	local function show(id)
		currentTab = id
		Kit.clear(content)
		if not data then
			Kit.label(content, "กำลังโหลด...", C.Gray, { Size = UDim2.new(1, 0, 0, 30) })
			return
		end
		local fn = RENDER[id]
		if fn then
			local ok, err = pcall(fn, content, data)
			if not ok then warn("[ProfilePanel] " .. tostring(err)) end
		end
	end

	local _, select = Kit.tabs(right, {
		{ Id = "Overview", Text = "ภาพรวม" },
		{ Id = "Fight", Text = "สถิติ" },
		{ Id = "Index", Text = "สมุดการ์ด" },
		{ Id = "Deck", Text = "เด็ค" },
		{ Id = "Friend", Text = "เพื่อน", Locked = true },
		{ Id = "Clan", Text = "แคลน", Locked = true },
	}, show)
	select("Overview")

	task.spawn(function()
		local res = Net.invoke("GetPublicProfile", userId)
		if my ~= openToken or not w.Root.Parent then return end
		if typeof(res) ~= "table" then
			Kit.clear(content)
			Kit.label(content, "โหลดโปรไฟล์ไม่ได้ (ผู้เล่นอาจออกจากเกมแล้ว)", C.Red, { Size = UDim2.new(1, 0, 0, 30) })
			return
		end
		data = res
		show(currentTab)
	end)
end

return ProfilePanel