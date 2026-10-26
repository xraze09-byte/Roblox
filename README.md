# Gawa Card Battle: RNG Troll (Roblox)

Server-authoritative 1v1 card battle with a random "Gate" slot. Version: **Core v1.0**.

## Structure
```
ReplicatedStorage/Shared/        Config, Rules, CardData, Decks, DeckRules, QuestData
ReplicatedStorage/Shared/UI/     Theme, UIKit, CardView, Style (ธีมใหม่)
ServerScriptService/CardTableBuilder.server.lua  สร้างโต๊ะการ์ด 3D (ย้ายด้วย ORIGIN)
ServerStorage/Modules/           GateRNG, CardEffects, BotAI, Match, DataService, StatsService,
                                 Guard (rate limit), GachaService, QuestService
ServerScriptService/             GameServer (creates Remotes, matchmaking, rewards), CardValidator
StarterPlayer/StarterPlayerScripts/UIClient/   init.client + TableCamera (กล้องแพนไปโต๊ะ), LobbyUI, MatchUI, Net, CardFace, Inspect, DragController, StatsPanel, SettingsPanel,
                                                TurnBanner, CombatFX, TargetArrow, HandFan, MatchBackdrop
```
`Remotes` is created at runtime by `GameServer`; do not declare it in `default.project.json`.

## Rules summary
- Leader HP 30, win by reducing the opponent leader to 0
- 5 points per turn, banking cap 15, skip (spend nothing) to bank
- Starting hand 3, draw 2 per turn, max hand 5, 3 field slots
- Gate slot: 1 point discount, outcome rolled at start of next turn
- Fatigue when deck is empty: leader loses 1, 2, 3... HP
- Keywords: Rush, Taunt, Necro, Unlucky, Steal. Elements: Sati > Biao > Muen > Sati, Gawa = coin flip

## Gate outcomes
Golden 5% x3 / Pumped 20% x1.5 / Normal 45% x1 / Droopy 20% x0.5 / Poop 10% (HP 1, ATK 0)

## Done
Bot match, PvP queue, spells (7), weapons, 3 leaders, rewards + streak bounty, DataService, CardValidator, event log UI.

## TODO (next batches)
Gacha + pity, deck builder, quests, Tower, Ranked, Tournament, weather, emotes, pets, titles,
spectator, replay, black market, Gawa Pass, leaderboard, report.
Before launch: swap DataService for ProfileStore, add anti-farming for PvP gems.

## Stats
`StatsService` keeps lifetime + per-day (Thai time, UTC+7, last 14 days) counters inside the player profile
(`Data.Stats`, `Data.Daily`). Match calls `match:Track(player, fn)` at the exact point of each event, so every
number is counted server-side. The lobby "📊 สถิติ" panel reads it through the `GetStats` RemoteFunction.
Note: the current rules have no draws (`CheckWinner` always picks a winner), so `Draws` stays 0 until a draw rule exists.

## Rojo setup
1. Install Rojo (CLI + Studio plugin), see https://rojo.space/docs
2. `git clone https://github.com/xraze09-byte/Roblox.git && cd Roblox`
3. `rojo serve`
4. In Studio: Plugins > Rojo > Connect
5. Press Play: Output should show `[CardValidator] ✅`
