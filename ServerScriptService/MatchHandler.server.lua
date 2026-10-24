local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes

local ActiveMatches = {} -- [player] = match

Remotes.PlayCard.OnServerInvoke = function(player, handIndex, target)
	if typeof(handIndex) ~= "number" or handIndex % 1 ~= 0 then return false end
	if target ~= "Field" and target ~= "Gate" then return false end
	local match = ActiveMatches[player]
	if not match then return false end
	return match:PlayCard(player, handIndex, target)
end

Remotes.EndTurn.OnServerEvent:Connect(function(player)
	local match = ActiveMatches[player]
	if match then match:EndTurn(player, false) end
end)