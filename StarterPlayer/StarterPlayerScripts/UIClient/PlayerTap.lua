-- UIClient/PlayerTap.lua
-- Tap another player in the world -> "View profile" button above their head -> onView(userId, screenPoint)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Kit = require(script.Parent:WaitForChild("MenuKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local C = Kit.C
local LP = Players.LocalPlayer

local PlayerTap = {}

local TAP_MOVE, TAP_TIME, MAX_DIST, SHOW_TIME = 14, 0.35, 150, 5

local enabled, inited, onView = true, false, nil
local tag, tagToken = nil, 0
local downs = {}

local function hideTag()
	tagToken += 1
	if tag then tag:Destroy(); tag = nil end
end

local function playerFromPart(inst)
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(inst)
			if p then return p end
		end
		inst = inst.Parent
	end
end

local function showTag(plr)
	hideTag()
	local char = plr.Character
	local head = char and (char:FindFirstChild("Head") or char.PrimaryPart)
	if not head then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "ViewProfileTag"
	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.Active = true
	bb.ResetOnSpawn = false
	bb.Size = UDim2.fromOffset(150, 48)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.Parent = LP:WaitForChild("PlayerGui")

	local btn = Kit.button(bb, "👁 ดูโปรไฟล์", C.Yellow, function()
		local v = workspace.CurrentCamera:WorldToViewportPoint(head.Position)
		hideTag()
		if onView then onView(plr.UserId, Vector2.new(v.X, v.Y)) end
	end, { Size = UDim2.fromScale(1, 1) })
	Juice.popIn(btn)

	tag = bb
	local my = tagToken
	task.delay(SHOW_TIME, function()
		if my == tagToken then hideTag() end
	end)
end

local function onTap(pos)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local ray = cam:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LP.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * MAX_DIST, params)
	local plr = hit and playerFromPart(hit.Instance)
	if plr and plr ~= LP then showTag(plr) else hideTag() end
end

local function isTapType(t)
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end
local function key(input)
	return input.UserInputType == Enum.UserInputType.Touch and input or "mouse"
end

function PlayerTap.Init(callback)
	onView = callback
	if inited then return end
	inited = true

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or not enabled or not isTapType(input.UserInputType) then return end
		downs[key(input)] = { Pos = input.Position, T = os.clock() }
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not isTapType(input.UserInputType) then return end
		local k = key(input)
		local d = downs[k]
		downs[k] = nil
		if not d or not enabled then return end
		local moved = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(d.Pos.X, d.Pos.Y)).Magnitude
		if moved > TAP_MOVE or os.clock() - d.T > TAP_TIME then return end
		onTap(input.Position)
	end)
end

function PlayerTap.SetEnabled(on)
	enabled = on and true or false
	if not enabled then hideTag() end
end

return PlayerTap