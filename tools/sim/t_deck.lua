local CardData = H.load(H.RS.Shared.CardData)
local Config = H.load(H.RS.Shared.Config)
local UIKit = H.load(H.RS.Shared.UI.UIKit)
local DeckBuilder = H.load(H.player.PlayerGui.Parent and H.sources and (function()
	for inst, info in pairs(H.sources) do if info.path:find("UIClient/DeckBuilder.lua") then return inst end end end)())

local cards, owned = {}, {}
local n = 0
for id, def in pairs(CardData) do
	if type(def) == "table" and def.Type and def.Type ~= "Leader" then cards[id] = def; owned[id] = 2; n += 1 end
end
print("cards:", n, "quota:", DeckBuilder.QUOTA.Character, DeckBuilder.QUOTA.Weapon, DeckBuilder.QUOTA.Spell)

local saved
local parent = H.newInstance("Frame")
local panelOk, panel = pcall(DeckBuilder.Open, parent, { Cards = cards, Owned = owned, Deck = {},
	OnSave = function(ids) saved = ids; return true end })
print("Open ok:", panelOk, panelOk and "" or panel)
if not panelOk then return end

local function findSave()
	for _, d in ipairs(panel:GetDescendants()) do
		if d.ClassName == "TextButton" then
			local face = d:FindFirstChild("Face"); local lbl = face and face:FindFirstChild("Label")
			if lbl and lbl.Text == "เซฟเด็ค!" then return d end
		end
	end
end
local save = findSave()
print("save button found:", save ~= nil)
if save then
	print("Disabled attr on EMPTY deck (expect true):", save:GetAttribute("Disabled"))
	save.Activated:Fire()
	print("saved after click on empty deck (expect nil):", saved)
end

-- ── positive path: build a legal 24-card deck and save ──
local Config2 = Config
local function legalDeck()
	local out, per = {}, { Character = 0, Weapon = 0, Spell = 0 }
	local shields = 0
	local ids = {}
	for id in pairs(cards) do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local d = cards[id]
		local isShield = d.Type == "Spell" and type(d.Effect) == "table" and d.Effect.Kind == "Shield"
		local copies = (Config.MAX_COPIES and Config.MAX_COPIES[d.Rarity]) or 1
		for _ = 1, math.min(copies, 2) do
			if per[d.Type] < DeckBuilder.QUOTA[d.Type] and not (isShield and shields >= (Config.MAX_SHIELDS_IN_DECK or 2)) then
				table.insert(out, id); per[d.Type] += 1; if isShield then shields += 1 end
			end
		end
	end
	return out, per
end
local deckIds, per = legalDeck()
print("legal deck size:", #deckIds, "C/W/S:", per.Character, per.Weapon, per.Spell)

local saved2
local parent2 = H.newInstance("Frame")
local panel2 = DeckBuilder.Open(parent2, { Cards = cards, Owned = owned, Deck = deckIds, OnSave = function(ids) saved2 = ids; return true end })
local save2
for _, d in ipairs(panel2:GetDescendants()) do
	if d.ClassName == "TextButton" then
		local f = d:FindFirstChild("Face"); local l = f and f:FindFirstChild("Label")
		if l and l.Text == "เซฟเด็ค!" then save2 = d end
	end
end
print("FULL deck -> Disabled (expect nil/false):", save2:GetAttribute("Disabled"))
save2.Activated:Fire()
print("saved count (expect " .. #deckIds .. "):", saved2 and #saved2)

-- failure path: OnSave returns false + msg, and OnSave throws
local parent3 = H.newInstance("Frame")
local panel3 = DeckBuilder.Open(parent3, { Cards = cards, Owned = owned, Deck = deckIds, OnSave = function() error("boom") end })
local sv3
for _, d in ipairs(panel3:GetDescendants()) do
	if d.ClassName == "TextButton" then local f = d:FindFirstChild("Face"); local l = f and f:FindFirstChild("Label"); if l and l.Text == "เซฟเด็ค!" then sv3 = d end end
end
local okc, err = pcall(function() sv3.Activated:Fire() end)
print("OnSave throws -> UI survives:", okc, err)
print("warnings:", M and M.warnings and #M.warnings or (MOCK.warnings and #MOCK.warnings or 0))
if MOCK.taskErrors then for _, e in ipairs(MOCK.taskErrors) do print("TASK ERR:", e) end end
for i, w in ipairs(MOCK.warnings or {}) do print("WARN " .. i .. ": " .. tostring(w)) end
