# Gawa Card Battle: RNG Troll (Roblox)

Server-authoritative 1v1 card battle with a random "Gate" slot.

## Structure
```
ReplicatedStorage/Shared/Config.lua
ServerStorage/Modules/GateRNG.lua
ServerStorage/Modules/Match.lua
ServerScriptService/MatchHandler.server.lua
```

## Rules summary
- Leader HP 30, win by reducing the opponent leader to 0
- 5 points per turn, banking cap 15, skip (spend nothing) to bank
- Gate slot: 1 point discount, outcome rolled at start of next turn
- Fatigue when deck is empty: leader loses 1, 2, 3... HP

## Gate outcomes
Golden 5% x3 / Pumped 20% x1.5 / Normal 45% x1 / Droopy 20% x0.5 / Poop 10% (HP 1, ATK 0)

## TODO
CardData, GachaService (with pity and published drop rates), DataService (ProfileStore),
CardEffects (Spell/Weapon/Shield), Attack remote, client UI/VFX, MatchEnded/GateRolled remotes.

## Rojo setup
1. Install Rojo (CLI + Studio plugin), see https://rojo.space/docs
2. `git clone https://github.com/xraze09-byte/Roblox.git && cd Roblox`
3. `rojo serve`
4. In Studio: Plugins > Rojo > Connect
