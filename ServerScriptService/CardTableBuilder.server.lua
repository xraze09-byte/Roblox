-- ServerScriptService/CardTableBuilder.server.lua
local ORIGIN = CFrame.new(0, 0, -60) -- ย้ายไปวางตรงโซนต่อสู้ในแมพของคุณ

if workspace:FindFirstChild("CardTable") then return end

local rgb = Color3.fromRGB
local INK, PINK, BLUE, YELLOW = rgb(14, 10, 24), rgb(255, 36, 168), rgb(0, 196, 255), rgb(255, 228, 0)

local model = Instance.new("Model")
model.Name = "CardTable"
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- กันโต๊ะไม่ถูกโหลดตอนเปิด StreamingEnabled

local function part(name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, ORIGIN * cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = model
	return p
end

-- ขา + พื้นโต๊ะ + ผ้าปู
for _, x in ipairs({ -10, 10 }) do
	for _, z in ipairs({ -6, 6 }) do part("Leg", Vector3.new(1.4, 4, 1.4), CFrame.new(x, 2, z), INK) end
end
part("Top", Vector3.new(24, 1, 16), CFrame.new(0, 4.5, 0), rgb(130, 82, 40), Enum.Material.Wood)
local felt = part("Felt", Vector3.new(22, 0.2, 14), CFrame.new(0, 5.1, 0), rgb(44, 18, 96), Enum.Material.Fabric)

-- ขอบนีออน + เส้นแบ่งแดน (ตาข่าย)
local neon = { CanCollide = false }
part("TrimN", Vector3.new(24.4, 0.5, 0.5), CFrame.new(0, 5.1, 8), PINK, Enum.Material.Neon, neon)
part("TrimS", Vector3.new(24.4, 0.5, 0.5), CFrame.new(0, 5.1, -8), BLUE, Enum.Material.Neon, neon)
part("TrimE", Vector3.new(0.5, 0.5, 16.4), CFrame.new(12, 5.1, 0), YELLOW, Enum.Material.Neon, neon)
part("TrimW", Vector3.new(0.5, 0.5, 16.4), CFrame.new(-12, 5.1, 0), YELLOW, Enum.Material.Neon, neon)
part("Net", Vector3.new(22, 0.25, 0.3), CFrame.new(0, 5.25, 0), YELLOW, Enum.Material.Neon, neon)

-- วงซัมมอน 3 ช่องต่อฝั่ง (ฝั่ง Me อยู่ใกล้กล้องเสมอ)
local slots = Instance.new("Folder")
slots.Name, slots.Parent = "Slots", model
for i, x in ipairs({ -7, 0, 7 }) do
	for _, s in ipairs({ { "Me", 3.6, PINK }, { "Opp", -3.6, BLUE } }) do
		local ring = part(s[1] .. i, Vector3.new(0.12, 4.4, 4.4), CFrame.new(x, 5.25, s[2]) * CFrame.Angles(0, 0, math.rad(90)),
			s[3], Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.55, CanCollide = false })
		ring.Parent = slots
	end
end

-- เก้าอี้ 2 ฝั่ง
for _, z in ipairs({ 11, -11 }) do
	local dir, col = z > 0 and 1 or -1, z > 0 and PINK or BLUE
	part("Seat", Vector3.new(5, 1, 4), CFrame.new(0, 2.5, z), col)
	part("Back", Vector3.new(5, 5, 0.8), CFrame.new(0, 5.5, z + dir * 2), col)
end

-- โคมไฟเหนือโต๊ะ (สูงพอไม่ให้บังมุมกล้อง)
local lamp = part("Lamp", Vector3.new(3, 0.6, 3), CFrame.new(0, 20, 0), YELLOW, Enum.Material.Neon, neon)
local light = Instance.new("SpotLight")
light.Face, light.Brightness, light.Range, light.Angle, light.Color = Enum.NormalId.Bottom, 3, 26, 90, rgb(255, 240, 210)
light.Parent = lamp

-- จุดตั้งกล้อง: อยู่สูงด้านฝั่ง Me และมองลงกลางโต๊ะ
local cam = part("CameraPoint", Vector3.one, CFrame.new(), INK, nil,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
cam.CFrame = CFrame.lookAt((ORIGIN * CFrame.new(0, 21, 14)).Position, (ORIGIN * CFrame.new(0, 5, 1)).Position)

model.PrimaryPart = felt
model.Parent = workspace