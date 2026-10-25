# Headless bot-vs-bot simulator

Runs `ServerStorage/Modules/Match.lua` with two `IsBot` players on a virtual clock (no Roblox needed).

    luau-bundle: python3 build.py t_sim.lua && luau bundle.lua

- `t_sim.lua`  500+ games, checks invariants every virtual second (points, field/hand limits, card conservation, duplicate Uids, winner vs HP).
- `t_comp.lua` compares first-player win rate under candidate balance changes.

Last run (1500 games): 0 invariant violations, 0 stuck games, 0 errors; first player won ~70%.
