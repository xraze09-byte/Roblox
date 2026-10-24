local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Remotes = ReplicatedStorage.Remotes
local MatchRegistry = require(ServerStorage.Modules.MatchRegistry)

Remotes.PlayCard.OnServerInvoke = function(player, handIndex, target)
	if typeof(handIndex) ~= "number" or handIndex % 1 ~= 0 then return false end
	if target ~= "Field" and target ~= "Gate" then return false end
	local match = MatchRegistry.Get(player)
	if not match then return false end
	return match:PlayCard(player, handIndex, target)
end

Remotes.Attack.OnServerInvoke = function(player, attackerUid, targetUid)
	if typeof(attackerUid) ~= "string" or typeof(targetUid) ~= "string" then return false end
	local match = MatchRegistry.Get(player)
	if not match then return false end
	return match:Attack(player, attackerUid, targetUid)
end

Remotes.EndTurn.OnServerEvent:Connect(function(player)
	local match = MatchRegistry.Get(player)
	if match then match:EndTurn(player, false) end
end)
