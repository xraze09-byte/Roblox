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
- `t_lobby.lua` (rewritten for Lobby v2) top bar / left nav / content window never overlap or leave the screen across 8 viewport sizes.
- `t_lobby_v2.lua` Lobby v2 behavior: every tab renders, stats translated, quest badge, PvP queue timer + cancel, tower button, ProfileChanged floor update, profile retry.
- `t_tower.lua` tower server logic on a real Match: boss shield/buff per floor, full match plays out, reward formula, floor progression, DataService persists TowerFloor.

Real-player-path tests (added after the "everything is buggy" report; they drive the REAL GameServer + REAL client UI, not hand-made state):
- `t_server_fuzz.lua` fires every Remote with nil/NaN/huge/wrong-type args against the real GameServer: expects no throw, no kick.
- `t_e2e.lua` full server journeys: profile, Bot/Tower/PvP, surrender, leave mid-match, rejoin persistence, SaveDeck/Gacha/Quest/Farm.
- `t_win_bot.lua` / `t_win_tower.lua` rigged wins: Bot pays REWARD_WIN_BOT, Tower pays BASE+floor*PER_FLOOR and advances one floor.
- `t_bridge.lua` / `t_tap.lua` real MatchUI wired to the real server through the remotes; taps cards/slots exactly like a player.
- `t_uiplay.lua` auto-plays N full matches by tapping real buttons only (field, spells, attacks, end turn).
- `t_gate_weapon.lua` gate play (cost discount, "next turn roll" label, roll result) and weapon equip through the UI.
- `t_lobby_real.lua` / `t_lobby_data.lua` clicks every FAB/popup row; checks gems label follows ProfileChanged, deck popup count, Save button.
- `mock.lua` now has a STRICT property whitelist (strict_props.json): writing a property that does not exist on the real Roblox class is recorded in `H.M.invalid` (real Roblox would throw).

Result on main 313b642: all pass, 0 real bugs found by these; every failure seen while writing them was a harness issue.
