-- ServerStorage/Modules/CardEffects (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local CardEffects = {}
local rng = Random.new()

local function find(list, uid)
	for i, c in list do
		if c.Uid == uid then return c, i end
	end
	return nil
end

-- สุ่มโดนศัตรู (ตัวละครที่ยังไม่ตาย + ผู้นำ)
local function hitRandomEnemy(match, opp, damage)
	local pool = { "LEADER" }
	for _, c in opp.field do
		if c.HP > 0 then table.insert(pool, c) end
	end
	local t = pool[rng:NextInteger(1, #pool)]
	if t == "LEADER" then
		match:DamageLeader(opp, damage)
		return "ผู้นำของ " .. opp.name
	end
	t.HP -= damage
	return t.Name
end

local Spells = {}

function Spells.Shield(match, me, _, card)
	me.shield += card.Effect.Value
	match:Track(me.player, function(d, S) S.Add(d, "ShieldGained", card.Effect.Value) end)
	match:Notify(("🛡️ %s ตั้งโล่ฝาหม้อ (กันได้ %d)"):format(me.name, me.shield), "Blue")
end

function Spells.Slime(match, _, _, _, t)
	t.Slime = true
	match:Notify(("🟢 %s เหยียบสไลม์! ตีครั้งหน้าพลาดได้ 50%%"):format(t.Name), "Green")
end

function Spells.Damage(match, me, _, card, t)
	local dealt = math.max(0, math.min(t.HP, card.Effect.Value))
	t.HP -= card.Effect.Value
	match.lastHit[t.Uid] = { by = me.player, card = card.Id }
	match:Track(me.player, function(d, S) S.Add(d, "DamageToCards", dealt) end)
	match:Notify(("👋 %s โดน %s %d!"):format(t.Name, card.Name, card.Effect.Value), "Red")
end

function Spells.Heal(match, me, _, card, t)
	local v = card.Effect.Value
	if t == "LEADER" then
		local gained = math.min(v, Config.LEADER_HP - me.leaderHP)
		match:Track(me.player, function(d, S) S.Add(d, "HealDone", math.max(0, gained)) end)
		me.leaderHP = math.min(me.leaderHP + v, Config.LEADER_HP)
		match:Notify(("💚 %s ฮีลผู้นำ +%d"):format(me.name, v), "Green")
	else
		local gained = math.min(v, (t.MaxHP or (t.HP + v)) - t.HP)
		match:Track(me.player, function(d, S) S.Add(d, "HealDone", math.max(0, gained)) end)
		t.HP = math.min(t.HP + v, t.MaxHP or (t.HP + v))
		match:Notify(("💚 %s ฮีล +%d"):format(t.Name, v), "Green")
	end
end

function Spells.Buff(match, _, _, card, t)
	local v = card.Effect.Value
	t.MaxHP = (t.MaxHP or t.HP) + v
	t.HP += v
	t.ATK += v
	match:Notify(("📣 %s ตื่นเต็มตา! ATK +%d HP +%d"):format(t.Name, v, v), "Yellow")
end

function Spells.Mystery(match, me, opp, card)
	local roll = rng:NextInteger(1, 3)
	if roll == 1 then
		local name = hitRandomEnemy(match, opp, card.Effect.Value)
		match:Notify(("🎁 กล่องระเบิดใส่ %s %d!"):format(name, card.Effect.Value), "Red")
	elseif roll == 2 then
		match:Draw(me, 2)
		match:Notify(("🎁 %s ได้จั่วการ์ด 2 ใบ"):format(me.name), "Blue")
	else
		match:Notify("🎁 ว่างเปล่า... มีแต่เสียงหัวเราะ 🤣", "Yellow")
	end
end

function Spells.Bomb(match, me, _, card)
	local delay = card.Effect.Delay or 2
	table.insert(match.bombs, { turns = delay, damage = card.Effect.Value })
	match:Notify(("💣 %s ตั้งหม้อหุงข้าว! อีก %d เทิร์นระเบิดทั้งสนาม"):format(me.name, delay), "Red")
end

function CardEffects.Equip(match, ally, weapon)
	if ally.WeaponName then
		ally.ATK = math.max(0, ally.ATK - (ally.WeaponBonus or 0))
	end
	ally.ATK += weapon.Bonus
	ally.WeaponName = weapon.Name
	ally.WeaponBonus = weapon.Bonus
	ally.WeaponDur = weapon.Durability or 2
	ally.WeaponFreeze = weapon.Freeze == true
	match:Notify(("🗡️ %s สวม %s (ATK +%d)"):format(ally.Name, weapon.Name, weapon.Bonus), "Yellow")
end

-- ตรวจเป้าหมายก่อน ถ้าผ่านจะคืนฟังก์ชันสำหรับทำผล ถ้าไม่ผ่านจะคืน nil, รหัส error
function CardEffects.Prepare(match, me, card, target)
	local opp = match:OtherSide(me)

	if card.Type == "Weapon" then
		if typeof(target) ~= "string" then return nil, "NEED_TARGET" end
		local ally = find(me.field, target)
		if ally then
			return function()
				match:Track(me.player, function(d, S) S.Add(d, "WeaponsEquipped") end)
				CardEffects.Equip(match, ally, card)
			end
		end
		if target == "LEADER" then
			return function()
				match:DamageLeader(opp, card.Bonus, me.player)
				match:Track(me.player, function(d, S) S.Add(d, "WeaponsThrown") end)
				match:Notify(("🗡️ ปา%sใส่ผู้นำของ %s %d!"):format(card.Name, opp.name, card.Bonus), "Red")
			end
		end
		local enemy = find(opp.field, target)
		if enemy then
			return function()
				local dealt = math.max(0, math.min(enemy.HP, card.Bonus))
				enemy.HP -= card.Bonus
				match.lastHit[enemy.Uid] = { by = me.player, card = card.Id }
				match:Track(me.player, function(d, S)
					S.Add(d, "WeaponsThrown")
					S.Add(d, "DamageToCards", dealt)
				end)
				if card.Freeze and enemy.HP > 0 then enemy.Frozen = true end
				match:Notify(("🗡️ ปา%sใส่ %s %d!%s"):format(card.Name, enemy.Name, card.Bonus,
					card.Freeze and " ❄️แช่แข็ง" or ""), "Red")
			end
		end
		return nil, "INVALID_TARGET"
	end

	if card.Type ~= "Spell" or typeof(card.Effect) ~= "table" then return nil, "INVALID_CARD" end
	local handler = Spells[card.Effect.Kind]
	if not handler then return nil, "INVALID_CARD" end

	local ttype = Rules.TargetType(card)
	local t = nil
	if ttype ~= "None" then
		if typeof(target) ~= "string" then return nil, "NEED_TARGET" end
		if ttype == "EnemyChar" then
			t = find(opp.field, target)
		elseif ttype == "AllyChar" then
			t = find(me.field, target)
		elseif ttype == "Ally" then
			t = (target == "MY_LEADER") and "LEADER" or find(me.field, target)
		end
		if not t then return nil, "INVALID_TARGET" end
	end
	return function() handler(match, me, opp, card, t) end
end

-- ตอนลงสนาม: ขุดศพ / ขโมย
function CardEffects.OnEnter(match, side, card)
	if Rules.HasKeyword(card, "Necro") then
		local pool = {}
		for i, c in side.graveyard do
			if c.Type == "Character" then table.insert(pool, i) end
		end
		if #pool > 0 and #side.hand < Config.MAX_HAND then
			local dead = table.remove(side.graveyard, pool[rng:NextInteger(1, #pool)])
			table.insert(side.hand, match.MakeCard(dead.Id))
			match:Notify(("⚰️ %s ขุด %s กลับขึ้นมือ!"):format(card.Name, dead.Name), "Pink")
		else
			match:Notify(("⚰️ %s ขุดแล้วไม่เจออะไร"):format(card.Name))
		end
	end

	if Rules.HasKeyword(card, "Steal") then
		local opp = match:OtherSide(side)
		local amount = opp.banking and math.min(2, opp.points) or 0
		if amount > 0 then
			opp.points -= amount
			side.points = math.min(side.points + amount, Config.MAX_BANKED_POINTS)
			match:Notify(("🦹 %s ขโมยพอยต์ที่ดองไว้ %d!"):format(card.Name, amount), "Pink")
		else
			match:Notify(("🦹 %s หาพอยต์ขโมยไม่เจอ"):format(card.Name))
		end
	end
end

-- ตอนตาย: ดวงซวย
function CardEffects.OnDeath(match, side, card)
	if Rules.HasKeyword(card, "Unlucky") then
		if rng:NextInteger(0, 1) == 1 then
			local name = hitRandomEnemy(match, match:OtherSide(side), 3)
			match:Notify(("🪙 ดวงซวยออกหัว! %s โดน 3"):format(name), "Yellow")
		else
			match:DamageLeader(side, 3)
			match:Notify(("🪙 ดวงซวยออกก้อย! ผู้นำของ %s โดนเอง 3 🤦"):format(side.name), "Red")
		end
	end
end

return CardEffects