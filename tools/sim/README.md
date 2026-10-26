# Headless bot-vs-bot simulator

Runs `ServerStorage/Modules/Match.lua` with two `IsBot` players on a virtual clock (no Roblox needed).

    luau-bundle: python3 build.py t_sim.lua && luau bundle.lua

- `t_sim.lua`  500+ games, checks invariants every virtual second (points, field/hand limits, card conservation, duplicate Uids, winner vs HP).
- `t_comp.lua` compares first-player win rate under candidate balance changes.

Last run (500 games): 0 invariant violations, 0 stuck games, 0 errors; first player won ~50% (249/500) after the balance change below.

Balance (Config.lua): `FIRST_PLAYER_SKIPS_DRAW = true` and `SECOND_PLAYER_BONUS_POINTS = 1` bring the first-player win rate from ~70% down to ~51% (t_comp, 1000 games). Set them to `false` / `0` to restore the old rules.

UI tests (run the same way, e.g. `python3 build.py t_matchui.lua && luau bundle.lua`):
- `t_perf_cardface.lua` Perf levels (incl. FPS auto-downgrade, lock Low on 2nd drop), CardFace API for every card type, HandFan, UIKit.shake, Style.scroll.
- `t_matchui.lua` MatchUI full cycle: match 1 -> MatchEnded -> back to lobby -> match 2; checks Perf.SetMatch and that late StateUpdate is ignored.
- `t_rules.lua` combat/turn rules v2: element bonus (incl. deterministic Gawa), counter-attack with element, frozen can't attack/counter, banking only on a true skip, gate slot reserved so a gated card can never get stuck; 200 bot games.
- `t_matchui_sizes.lua` MatchUI v2 layout overlap/off-screen check.

Balance note (t_sim, 500 games): after the combat/turn rule changes first player wins ~46% (231/500) instead of ~50% (249/500); the second-player compensation in Config may now be slightly too strong.
