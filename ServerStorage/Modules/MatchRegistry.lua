-- ตารางแมตช์ที่ใช้ร่วมกันระหว่าง MatchHandler และ MatchService
local MatchRegistry = {}
local active = {}

function MatchRegistry.Get(player) return active[player] end
function MatchRegistry.Set(player, match) active[player] = match end

return MatchRegistry
