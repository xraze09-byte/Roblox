-- ServerScriptService/WorldSpots.server.lua
local CollectionService = game:GetService("CollectionService")

local TAG = "FloatSpot"
local TABLE_ORIGIN = CFrame.new(0, 0, -60) -- ต้องตรงกับ ORIGIN ใน CardTableBuilder
local TABLE_SPOT_HEIGHT = 5                -- ความสูงปุ่มเหนือโต๊ะ

local NPCS = { -- ขยับ Offset ให้ไม่ชนโต๊ะ/ฉากได้เลย
	{ Name = "BotSensei",   Action = "Bot",   Label = "🤖 ซ้อมบอท", Color = Color3.fromRGB(150, 255, 90), Offset = Vector3.new(-16, 0, 12) },
	{ Name = "GachaGuy",    Action = "Gacha", Label = "🎰 กาชา",    Color = Color3.fromRGB(255, 90, 200), Offset = Vector3.new(16, 0, 12) },
	{ Name = "TowerKeeper", Action = "Tower", Label = "🗼 หอคอย",   Color = Color3.fromRGB(255, 150, 40), Offset = Vector3.new(-16, 0, -12) },
	{ Name = "DeckSmith",   Action = "Deck",  Label = "🃏 จัดเด็ค", Color = Color3.fromRGB(80, 170, 255), Offset = Vector3.new(16, 0, -12) },
}

local function block(model, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function tagSpot(part, action, label, color, range, height)
	part:SetAttribute("Action", action)
	part:SetAttribute("Label", label)
	part:SetAttribute("Color", color)
	part:SetAttribute("Range", range)
	part:SetAttribute("Height", height)
	CollectionService:AddTag(part, TAG)
end

for _, def in NPCS do
	local model = Instance.new("Model")
	model.Name = "NPC_" .. def.Name
	local pos = (TABLE_ORIGIN * CFrame.new(def.Offset)).Position
	local face = CFrame.lookAt(pos, Vector3.new(TABLE_ORIGIN.X, pos.Y, TABLE_ORIGIN.Z))
	local dark = Color3.fromRGB(40, 30, 60)

	block(model, "LegL", Vector3.new(1, 2, 1), face * CFrame.new(-0.5, 1, 0), dark)
	block(model, "LegR", Vector3.new(1, 2, 1), face * CFrame.new(0.5, 1, 0), dark)
	block(model, "Torso", Vector3.new(2, 2, 1), face * CFrame.new(0, 3, 0), def.Color)
	local head = block(model, "Head", Vector3.new(1.6, 1.6, 1.6), face * CFrame.new(0, 4.8, 0), Color3.fromRGB(255, 220, 170))
	local d = Instance.new("Decal")
	d.Texture = "rbxasset://textures/face.png"
	d.Face = Enum.NormalId.Front
	d.Parent = head

	model.PrimaryPart = head
	model.Parent = workspace
	tagSpot(head, def.Action, def.Label, def.Color, 14, 2.5)
end

-- จุดหาคู่ PvP เหนือโต๊ะการ์ด
local anchor = Instance.new("Part")
anchor.Name = "BattleSpot"
anchor.Size = Vector3.one
anchor.Transparency = 1
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.CFrame = TABLE_ORIGIN + Vector3.new(0, TABLE_SPOT_HEIGHT, 0)
anchor.Parent = workspace:WaitForChild("CardTable", 30) or workspace
tagSpot(anchor, "PvP", "🌐 หาคู่ PvP", Color3.fromRGB(255, 70, 100), 18, 0)