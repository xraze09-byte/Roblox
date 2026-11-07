--!strict
--[[
	🪑 CardTableBuilder.server.lua
	สร้างโต๊ะดวลการ์ด 3D สไตล์ Manga Chaos Arcade
	• โมเดลชื่อ "CardTable" พร้อมแท็ก CollectionService "GlueDuelTable"
	• ติดตั้ง ProximityPrompt [E] "ดวลกาวการ์ด 🃏"
	• เมื่อผู้เล่นกด E จะสั่ง OpenTable ให้กล้องซูมเข้าโต๊ะและเริ่มดวลทันที
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TABLE_ORIGIN = Vector3.new(0, 0, -28)

local function buildDuelTable()
	local existing = workspace:FindFirstChild("CardTable")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "CardTable"
	model.Parent = workspace

	-- ฐานโต๊ะหลัก
	local base = Instance.new("Part")
	base.Name = "TableBase"
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(28, 24, 46)
	base.Size = Vector3.new(12, 3.2, 8)
	base.Position = TABLE_ORIGIN + Vector3.new(0, 1.6, 0)
	base.Parent = model

	-- ผ้าปูโต๊ะแบ่ง 2 ฝั่ง (น้ำเงินอาร์เคด vs แดงคอมมิก)
	local feltBlue = Instance.new("Part")
	feltBlue.Name = "FeltBlue"
	feltBlue.Anchored = true
	feltBlue.CanCollide = false
	feltBlue.Material = Enum.Material.Fabric
	feltBlue.Color = Color3.fromRGB(30, 60, 110)
	feltBlue.Size = Vector3.new(10.8, 0.15, 3.5)
	feltBlue.Position = base.Position + Vector3.new(0, 1.65, 1.8)
	feltBlue.Parent = model

	local feltRed = Instance.new("Part")
	feltRed.Name = "FeltRed"
	feltRed.Anchored = true
	feltRed.CanCollide = false
	feltRed.Material = Enum.Material.Fabric
	feltRed.Color = Color3.fromRGB(110, 30, 50)
	feltRed.Size = Vector3.new(10.8, 0.15, 3.5)
	feltRed.Position = base.Position + Vector3.new(0, 1.65, -1.8)
	feltRed.Parent = model

	-- เส้นนีออนคั่นกลางโต๊ะ
	local centerNeon = Instance.new("Part")
	centerNeon.Name = "CenterNeon"
	centerNeon.Anchored = true
	centerNeon.CanCollide = false
	centerNeon.Material = Enum.Material.Neon
	centerNeon.Color = Color3.fromRGB(255, 214, 10)
	centerNeon.Size = Vector3.new(11.2, 0.2, 0.25)
	centerNeon.Position = base.Position + Vector3.new(0, 1.68, 0)
	centerNeon.Parent = model

	-- ขอบไฟนีออนชมพูกาวรอบโต๊ะ
	local neonTrim = Instance.new("Part")
	neonTrim.Name = "NeonTrim"
	neonTrim.Anchored = true
	neonTrim.CanCollide = false
	neonTrim.Material = Enum.Material.Neon
	neonTrim.Color = Color3.fromRGB(255, 64, 168)
	neonTrim.Size = Vector3.new(12.3, 0.35, 8.3)
	neonTrim.Position = base.Position + Vector3.new(0, 1.5, 0)
	neonTrim.Parent = model

	-- จุดอ้างอิงกล้องมุมสูงเหนือโต๊ะ
	local camPoint = Instance.new("Part")
	camPoint.Name = "CameraPoint"
	camPoint.Anchored = true
	camPoint.CanCollide = false
	camPoint.Transparency = 1
	camPoint.Size = Vector3.new(1, 1, 1)
	camPoint.CFrame = CFrame.lookAt(base.Position + Vector3.new(0, 13, 8.5), base.Position + Vector3.new(0, 1.6, 0))
	camPoint.Parent = model

	-- ป้ายโฮโลแกรมลอยเหนือโต๊ะ
	local bb = Instance.new("BillboardGui")
	bb.Name = "TableSign"
	bb.Size = UDim2.fromOffset(280, 74)
	bb.StudsOffset = Vector3.new(0, 5.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 65
	bb.Adornee = base
	bb.Parent = base

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
	badge.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 214, 10)
	stroke.Thickness = 3
	stroke.Parent = badge

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = "🃏 โต๊ะดวลการ์ดกาว [กด E]"
	title.TextColor3 = Color3.fromRGB(255, 214, 10)
	title.TextSize = 22
	title.Parent = badge

	-- ติดตั้ง ProximityPrompt [E]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GlueDuelPrompt"
	prompt.ActionText = "ดวลกาวการ์ด 🃏"
	prompt.ObjectText = "Gawa Chaos Arcade"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	prompt.Triggered:Connect(function(player: Player)
		if player:GetAttribute("GlueInDuel") == true then return end
		local remotes = ReplicatedStorage:FindFirstChild("GlueCardRemotes")
		local openRemote = remotes and remotes:FindFirstChild("OpenTable") :: RemoteEvent?
		if openRemote then
			openRemote:FireClient(player, model, {
				difficulty = "Medium",
				mode = "Bot",
			})
		end
	end)

	model.PrimaryPart = base
	CollectionService:AddTag(model, "GlueDuelTable")
end

buildDuelTable()