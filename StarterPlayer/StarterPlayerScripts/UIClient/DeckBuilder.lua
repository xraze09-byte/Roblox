-- StarterPlayer/StarterPlayerScripts/UIClient/DeckBuilder.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared.UI.UIKit)
local FX = require(Shared.UI.FX)

local Config = require(Shared.Config)
local Theme = UIKit.Theme
local C, CENTER = Theme.Color, UIKit.CENTER
local DeckBuilder = {}

-- กฎเดียวกับ DeckRules.MaxCopies / IsShield ฝั่งเซิร์ฟเวอร์ (ไม่งั้นเด็คที่ดูถูกจะโดนเซิร์ฟเวอร์ปฏิเสธตอนเซฟ)
local function maxCopies(def) return (def and Config.MAX_COPIES and Config.MAX_COPIES[def.Rarity]) or 1 end
local function isShield(def) return def.Type == "Spell" and type(def.Effect) == "table" and def.Effect.Kind == "Shield" end

-- ตรงกับกฎปัจจุบัน (รวม 24 ใบ) ถ้าเปลี่ยนกฎให้แก้ที่นี่ และแก้ใน DeckRules ฝั่งเซิร์ฟเวอร์ด้วย
DeckBuilder.QUOTA = Config and Config.DECK_COMPOSITION or { Character = 12, Weapon = 5, Spell = 7 }
local TYPES = { "Character", "Weapon", "Spell" }
local TYPE_ORDER = { Character = 1, Weapon = 2, Spell = 3 }
local TYPE_EMOJI = { Character = "🤪", Weapon = "🗡️", Spell = "✨" }
local SWAP_SFX = { "Boing", "Honk", "Quack", "Slip", "Pop" }

local function borderStroke(t)
	local s = UIKit.stroke(C.Outline, t)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function tile(parent, def, order)
	local holder, face = UIKit.comicBox({ Name = def.Id, Parent = parent, Color = C.CardBg, ShadowOffset = 4, LayoutOrder = order })
	local z = face.ZIndex
	UIKit.new("Frame", { BackgroundColor3 = Theme.TypeColor[def.Type] or C.Gray, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.2),
		ZIndex = z, Parent = face }, { UIKit.corner(Theme.Radius) })
	UIKit.label({ Text = Theme.TypeLabel[def.Type] or def.Type, Size = UDim2.fromScale(0.6, 0.16), Position = UDim2.fromScale(0.5, 0.02),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 16, ZIndex = z + 1, Parent = face })
	UIKit.label({ Text = def.Emoji or TYPE_EMOJI[def.Type] or "❓", StrokeThickness = 0, Size = UDim2.fromScale(0.6, 0.32),
		Position = UDim2.fromScale(0.5, 0.23), AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 60, ZIndex = z + 1, Parent = face })
	UIKit.label({ Text = def.Name or def.Id, Size = UDim2.fromScale(0.92, 0.15), Position = UDim2.fromScale(0.5, 0.57),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 18, ZIndex = z + 1, Parent = face })
	local stat = def.Type == "Character" and string.format("⚔%s ❤%s", tostring(def.ATK or "?"), tostring(def.HP or "?"))
		or def.Type == "Weapon" and ("+" .. tostring(def.Bonus or "?"))
		or (Theme.RarityLabel[def.Rarity] or "")
	UIKit.label({ Text = stat, Color = C.Yellow, Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.5, 0.74),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 16, ZIndex = z + 1, Parent = face })

	local cost = UIKit.new("Frame", { BackgroundColor3 = C.Blue, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(-8, -8),
		ZIndex = z + 3, Parent = holder }, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(C.Outline, 3) })
	UIKit.label({ Text = tostring(def.Cost or 0), Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER, MaxTextSize = 22, ZIndex = z + 4, Parent = cost })
	UIKit.tierBadge(holder, def.Rarity).Position = UDim2.new(1, -4, 0, 4)
	FX.rarityGlow(holder, def.Rarity, { Sparkles = false }) -- ในตารางไม่ใส่ประกาย เพื่อไม่ให้หนักเครื่อง
	local _, countLbl = UIKit.badge(holder, "0/0", C.Pink, { Size = UDim2.fromOffset(64, 26), Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = CENTER, ZIndex = z + 5 })
	local hit = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 6, Parent = holder })
	return holder, countLbl, hit
end

-- opts = { Cards = {[id]=def}, Owned = {[id]=จำนวน}, Deck = {id,...}, OnSave = function(ids) return ok, msg end }
function DeckBuilder.Open(parent, opts)
	opts = opts or {}
	local cards, owned = {}, opts.Owned or {}
	for id, def in pairs(opts.Cards or {}) do
		if type(def) == "table" and def.Type ~= "Leader" then
			local copy = table.clone(def)
			copy.Id = copy.Id or id
			cards[id] = copy
		end
	end
	local deck = {}
	for _, id in ipairs(opts.Deck or {}) do deck[id] = (deck[id] or 0) + 1 end

	local panel = UIKit.panel(parent, "จัดเด็คกาวๆ", C.Pink)
	local function sorter(a, b)
		local da, db = cards[a], cards[b]
		if TYPE_ORDER[da.Type] ~= TYPE_ORDER[db.Type] then return TYPE_ORDER[da.Type] < TYPE_ORDER[db.Type] end
		if (da.Cost or 0) ~= (db.Cost or 0) then return (da.Cost or 0) < (db.Cost or 0) end
		return tostring(da.Name) < tostring(db.Name)
	end
	local function count(t)
		local n = 0
		for id, k in pairs(deck) do if cards[id] and cards[id].Type == t then n += k end end
		return n
	end

	-- ฝั่งซ้าย: คอลเลกชัน
	local left = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, -10, 1, -64), Position = UDim2.new(0, 14, 0, 50), Parent = panel })
	local tabs = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = left }, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local grid = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.new(0, 0, 0, 56), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10, ScrollBarImageColor3 = C.Pink, Parent = left }, {
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(124, 172), CellPadding = UDim2.fromOffset(16, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14) }) })

	-- ฝั่งขวา: เด็ค
	local right = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.38, -24, 1, -64), Position = UDim2.new(0.62, 10, 0, 50), Parent = panel }, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local meters = {}
	for i, t in ipairs(TYPES) do
		local holder, face = UIKit.comicBox({ Parent = right, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = i, Color = C.TableDark, ShadowOffset = 4 })
		local fill = UIKit.new("Frame", { BackgroundColor3 = Theme.TypeColor[t], BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
			ZIndex = face.ZIndex, Parent = face }, { UIKit.corner(Theme.Radius) })
		local lbl = UIKit.label({ Text = "", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
			MaxTextSize = 24, ZIndex = face.ZIndex + 1, Parent = face })
		meters[t] = { holder = holder, fill = fill, lbl = lbl, last = -1 }
	end
	local list = UIKit.new("ScrollingFrame", { BackgroundColor3 = C.TableDark, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 1, -236), LayoutOrder = 10, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8, Parent = right }, {
		UIKit.corner(12), UIKit.stroke(C.Outline, 3),
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6) }) })
	local btnRow = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 60), LayoutOrder = 20, Parent = right }, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local tiles, refresh, remove = {}, nil, nil

	local function shieldCount()
		local n = 0
		for id, k in pairs(deck) do if cards[id] and isShield(cards[id]) then n += k end end
		return n
	end

	local function add(id, holder)
		local def = cards[id]
		local q = DeckBuilder.QUOTA[def.Type]
		if not q then return end
		if (deck[id] or 0) >= maxCopies(def) then
			UIKit.shake(holder); UIKit.sfx("Honk", 0.1)
			UIKit.toast((def.Name or id) .. " ใส่ได้สูงสุด " .. maxCopies(def) .. " ใบ", C.Orange)
			return
		end
		if isShield(def) and shieldCount() >= (Config.MAX_SHIELDS_IN_DECK or 2) then
			UIKit.shake(holder); UIKit.sfx("Honk", 0.1)
			UIKit.toast("การ์ดโล่ใส่ได้ไม่เกิน " .. (Config.MAX_SHIELDS_IN_DECK or 2) .. " ใบ", C.Orange)
			return
		end
		if count(def.Type) >= q then
			UIKit.shake(holder); UIKit.sfx("Honk", 0.1)
			UIKit.toast((Theme.TypeLabel[def.Type] or def.Type) .. " เต็มแล้ว! (" .. q .. ")", C.Red)
			return
		end
		if (deck[id] or 0) >= (owned[id] or 0) then
			UIKit.shake(holder); UIKit.sfx("Honk", 0.1)
			UIKit.toast("มีใบนี้แค่ " .. (owned[id] or 0) .. " ใบ ไปสุ่มเพิ่มก่อน!", C.Orange)
			return
		end
		deck[id] = (deck[id] or 0) + 1
		UIKit.sfx(SWAP_SFX[math.random(#SWAP_SFX)], 0.25)
		UIKit.jelly(holder, 0.2)
		if (Theme.RarityTier[def.Rarity] or 1) >= 4 then FX.sparkles(holder, Theme.Rarity[def.Rarity], 10) end
		refresh()
	end

	remove = function(id)
		if not deck[id] then return end
		deck[id] -= 1
		if deck[id] <= 0 then deck[id] = nil end
		UIKit.sfx("Slip", 0.25)
		if tiles[id] then UIKit.jelly(tiles[id].holder, -0.12) end
		refresh()
	end

	local ids = {}
	for id, n in pairs(owned) do
		if n > 0 and cards[id] and DeckBuilder.QUOTA[cards[id].Type] then table.insert(ids, id) end
	end
	table.sort(ids, sorter)
	for i, id in ipairs(ids) do
		local holder, countLbl, hit = tile(grid, cards[id], i)
		tiles[id] = { holder = holder, count = countLbl, type = cards[id].Type }
		hit.Activated:Connect(function() add(id, holder) end)
		hit.MouseButton2Click:Connect(function() remove(id) end)
	end

	for i, f in ipairs({ { "All", "ทั้งหมด", C.Yellow }, { "Character", "ตัวละคร", C.Pink }, { "Weapon", "อาวุธ", C.Orange }, { "Spell", "สกิล", C.Blue } }) do
		UIKit.button({ Parent = tabs, Text = f[2], Color = f[3], Size = UDim2.new(0.24, -6, 1, 0), LayoutOrder = i, Lip = 4,
			Tilt = (i % 2 == 0) and 2 or -2, MaxTextSize = 22, OnClick = function()
				for _, t in pairs(tiles) do t.holder.Visible = (f[1] == "All" or t.type == f[1]) end
			end })
	end

	local saveBtn = UIKit.button({ Parent = btnRow, Text = "เซฟเด็ค!", Color = C.Green, Size = UDim2.new(0.62, -6, 1, 0), LayoutOrder = 1,
		Debounce = 1, OnClick = function()
			local out = {}
			for id, k in pairs(deck) do for _ = 1, k do table.insert(out, id) end end
			if not opts.OnSave then return end
			local okc, ok, msg = pcall(opts.OnSave, out)
			if not okc then warn("[DeckBuilder] OnSave error: " .. tostring(ok)); ok, msg = false, "เซฟไม่ผ่าน ลองใหม่" end
			if ok then
				UIKit.toast("เซฟแล้ว! เด็คนี้กาวมาก", C.Green)
				FX.sparkles(panel, C.Lime, 24)
			else
				local text = msg
				if opts.Message then text = opts.Message(msg) end
				UIKit.toast(tostring(text or "เซฟไม่ผ่าน ลองใหม่"), C.Red)
			end
		end })
	UIKit.button({ Parent = btnRow, Text = "ล้าง", Color = C.Red, Size = UDim2.new(0.38, -6, 1, 0), LayoutOrder = 2,
		OnClick = function() deck = {}; UIKit.sfx("Fart", 0.2); refresh() end })

	refresh = function()
		local valid = true
		for _, t in ipairs(TYPES) do
			local n, q, m = count(t), DeckBuilder.QUOTA[t], meters[t]
			valid = valid and n == q
			UIKit.tween(m.fill, 0.25, { Size = UDim2.fromScale(math.clamp(n / q, 0, 1), 1) }, Enum.EasingStyle.Back)
			local txt = string.format("%s %d/%d%s", Theme.TypeLabel[t], n, q, n == q and " ✔" or "")
			if n ~= m.last then
				if m.last >= 0 then UIKit.bounceText(m.lbl, txt, 0.25) else UIKit.setText(m.lbl, txt) end
				if n == q and m.last >= 0 then FX.sparkles(m.holder, Theme.TypeColor[t], 8) end
				m.last = n
			end
		end
		for id, t in pairs(tiles) do UIKit.setText(t.count, string.format("%d/%d", deck[id] or 0, owned[id] or 0)) end
		for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiButton") then ch:Destroy() end end
		local inDeck = {}
		for id in pairs(deck) do if cards[id] then table.insert(inDeck, id) end end
		table.sort(inDeck, sorter)
		for i, id in ipairs(inDeck) do
			local def = cards[id]
			local row = UIKit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.TypeColor[def.Type] or C.Gray,
				Size = UDim2.new(1, -12, 0, 34), LayoutOrder = i, Parent = list }, { UIKit.corner(10), borderStroke(2.5) })
			UIKit.label({ Text = string.format("x%d  %s", deck[id], def.Name or id), AlignX = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -54, 1, -6), Position = UDim2.new(0, 10, 0, 3), MaxTextSize = 20, Parent = row })
			UIKit.label({ Text = "T" .. (Theme.RarityTier[def.Rarity] or 1), Color = Theme.Rarity[def.Rarity] or C.White,
				Size = UDim2.new(0, 38, 1, -6), Position = UDim2.new(1, -44, 0, 3), MaxTextSize = 20, Parent = row })
			row.Activated:Connect(function() remove(id) end)
		end
		UIKit.setDisabled(saveBtn, not valid)
	end
	refresh()
	return panel
end

return DeckBuilder