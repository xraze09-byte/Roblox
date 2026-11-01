-- ReplicatedStorage/Shared/UI/Icons.lua
-- Centralized high-resolution outline icon asset registry for Gawa Card Battle
local Icons = {}

Icons.Asset = {
	Play = "rbxassetid://120640728059482",
	Pause = "rbxassetid://73290945271220",
	Chest = "rbxassetid://95714444952803",
	Checkmark = "rbxassetid://105893723071009",
	Close = "rbxassetid://72638817403379",
	Coin = "rbxassetid://116556317847119",
	Coins = "rbxassetid://125011859706993",
	Down = "rbxassetid://125547804701006",
	Up = "rbxassetid://96448943341589",
	Left = "rbxassetid://116555592987842",
	Right = "rbxassetid://100324819787945",
	Heart = "rbxassetid://94622274383529",
	Key = "rbxassetid://131536936946861",
	Lightning = "rbxassetid://107298595269428",
	Lock = "rbxassetid://106367991264609",
	Unlock = "rbxassetid://90004253860844",
	Minus = "rbxassetid://115911067067237",
	Plus = "rbxassetid://107998190327332",
	Panel = "rbxassetid://86248026128133",
	Sort = "rbxassetid://133193663389057",
}

-- Fallback emoji map for headless / offline environments
Icons.Fallback = {
	Play = "⚔️",
	Pause = "⏸️",
	Chest = "🎁",
	Checkmark = "✅",
	Close = "✕",
	Coin = "🪙",
	Coins = "💎",
	Down = "▼",
	Up = "▲",
	Left = "◄",
	Right = "►",
	Heart = "❤️",
	Key = "🔑",
	Lightning = "⚡",
	Lock = "🔒",
	Unlock = "🔓",
	Minus = "−",
	Plus = "+",
	Panel = "📦",
	Sort = "↕️",
}

function Icons.has(name)
	return typeof(name) == "string" and Icons.Asset[name] ~= nil
end

function Icons.get(name)
	return Icons.Asset[name] or ""
end

function Icons.fallback(name)
	return Icons.Fallback[name] or "•"
end

function Icons.image(name, props, parent)
	local img = Instance.new("ImageLabel")
	img.Name = "Icon_" .. tostring(name)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = Icons.get(name)
	img.BorderSizePixel = 0

	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				img[k] = v
			end
		end
	end
	if parent or (props and props.Parent) then
		img.Parent = parent or props.Parent
	end
	return img
end

function Icons.button(name, props, parent)
	local btn = Instance.new("ImageButton")
	btn.Name = "Btn_" .. tostring(name)
	btn.BackgroundTransparency = 1
	btn.ScaleType = Enum.ScaleType.Fit
	btn.Image = Icons.get(name)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false

	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				btn[k] = v
			end
		end
	end
	if parent or (props and props.Parent) then
		btn.Parent = parent or props.Parent
	end
	return btn
end

return Icons
