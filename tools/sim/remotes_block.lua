-- Remotes (mirrors GameServer REMOTES list)
local Remotes = newInstance("Folder"); Remotes.Name = "Remotes"
M.handlers = {}
local RF = { "PlayCard", "Attack", "Queue", "GetStats", "GetProfile", "SaveDeck", "Gacha", "ClaimQuest", "GetFarms", "ClaimFarm", "UpgradeFarm" }
local RE = { "EndTurn", "Surrender", "StateUpdate", "GateRolled", "MatchEnded", "Notify", "ProfileChanged" }
for _, n in ipairs(RF) do
	local r = newInstance("RemoteFunction"); r.Name = n; r.Parent = Remotes
	rawset(r, "InvokeServer", function(self, ...) local h = M.handlers[n]; if h then return h(...) end return false, "NO_HANDLER" end)
end
for _, n in ipairs(RE) do
	local r = newInstance("RemoteEvent"); r.Name = n; r.Parent = Remotes
	rawset(r, "OnClientEvent", Signal()); rawset(r, "OnServerEvent", Signal())
	rawset(r, "FireServer", function(self, ...) M.fired = M.fired or {}; table.insert(M.fired, { n, ... }) end)
	rawset(r, "FireClient", function(self, plr, ...) M.sent = M.sent or {}; table.insert(M.sent, { n, plr, ... }) end)
	rawset(r, "FireAllClients", function(self, ...) end)
end
Remotes.Parent = RS

