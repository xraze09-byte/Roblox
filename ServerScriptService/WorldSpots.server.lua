-- ServerScriptService/WorldSpots.server.lua
local CollectionService = game:GetService("CollectionService")

local TAG = "FloatSpot"
local FELT_Y = 5.1                  -- ความสูงผ้าโต๊ะจากพื้น (ตรงกับ CardTableBuilder)
local SPOT_ABOVE_TABLE = 2          -- ปุ่ม PvP ลอยเหนือผ้าโต๊ะกี่ studs
local FALLBACK_ORIGIN = CFrame.new(0, 0, -60)

if workspace:FindFirstChild("WorldSpots") then return end -- กันสร้างซ้ำ
local folder = Instance.new("Folder")
folder.Name = "WorldSpots"
folder.Parent = workspace

-- อ่านตำแหน่งจากโต๊ะจริง: ย้ายโต๊ะที่ CardTableBuilder ที่เดียว NPC ตามไปเอง
local cardTable = workspace:WaitForChild("CardTable", 30)
local felt = cardTable and cardTable:FindFirstChild("Felt", true)
local ORIGIN = felt and (felt.CFrame * CFrame.new(0, -FELT_Y, 0)) or FALLBACK_ORIGIN
if not felt then warn("[WorldSpots] ไม่พบ CardTable.Felt ใช้ตำแหน่งสำรอง") end

local NPCS = { -- ขยับ Offset ได้ถ้าชนฉาก
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
	local pos = (ORIGIN * CFrame.new(def.Offset)).Position
	local face = CFrame.lookAt(pos, Vector3.new(ORIGIN.X, pos.Y, ORIGIN.Z))
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
	model.Parent = folder
	tagSpot(head, def.Action, def.Label, def.Color, 14, 2.5)
end

-- จุดหาคู่ PvP ลอยเหนือโต๊ะการ์ด
local anchor = Instance.new("Part")
anchor.Name = "BattleSpot"
anchor.Size = Vector3.one
anchor.Transparency = 1
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.CFrame = ORIGIN * CFrame.new(0, FELT_Y + SPOT_ABOVE_TABLE, 0)
anchor.Parent = folder
tagSpot(anchor, "PvP", "🌐 หาคู่ PvP", Color3.fromRGB(255, 70, 100), 18, 0)