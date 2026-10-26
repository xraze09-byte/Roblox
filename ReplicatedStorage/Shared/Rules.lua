-- ReplicatedStorage/Shared/Rules (ModuleScript)
local Config = require(script.Parent:WaitForChild("Config"))
local Rules = {}

Rules.Beats = { Sati = "Biao", Biao = "Muen", Muen = "Sati" }
Rules.Keywords = { Rush = true, Taunt = true, Necro = true, Unlucky = true, Steal = true }
Rules.ELEMENT_BONUS = 2 -- ธาตุชนะทาง
Rules.GAWA_BONUS = 1    -- ธาตุกาว ชนะทุกธาตุ (ยกเว้นกาวด้วยกัน)

function Rules.HasKeyword(card, kw)
	return card ~= nil and card.Keywords ~= nil and table.find(card.Keywords, kw) ~= nil
end

function Rules.HasTaunt(field)
	for _, c in field do
		if Rules.HasKeyword(c, "Taunt") then return true end
	end
	return false
end

-- Board = ตัวละคร, Weapon = สวม/ปา, None = ไม่ต้องเลือก, EnemyChar / AllyChar / Ally
function Rules.TargetType(card)
	if card.Type == "Character" then return "Board" end
	if card.Type == "Weapon" then return "Weapon" end
	return (card.Effect and card.Effect.Target) or "None"
end

function Rules.GateCost(card)
	return math.max(0, (card.Cost or 0) - Config.GATE_DISCOUNT)
end

-- โบนัสธาตุแบบตายตัว (ไม่สุ่ม) ใช้ทั้งตอนตีและตอนสวน
function Rules.ElementBonus(atkEl, defEl)
	if not atkEl or not defEl then return 0 end
	if atkEl == "Gawa" then
		return defEl == "Gawa" and 0 or Rules.GAWA_BONUS
	end
	if Rules.Beats[atkEl] == defEl then return Rules.ELEMENT_BONUS end
	return 0
end

-- คำนวณผลการปะทะ (เซิร์ฟเวอร์ใช้จริง / client ใช้โชว์ตัวเลขล่วงหน้า)
function Rules.CombatPreview(attacker, target)
	local dmg = math.max(0, (attacker.ATK or 0) + Rules.ElementBonus(attacker.Element, target.Element))
	local counter = 0
	if not target.Frozen and (target.ATK or 0) > 0 then
		counter = math.max(0, target.ATK + Rules.ElementBonus(target.Element, attacker.Element))
	end
	return dmg, counter
end

-- ลงสนามได้ไหม (ถ้ามีการ์ดในเกต จะจองช่องไว้ 1 ช่อง กันการ์ดเกตค้าง)
function Rules.FieldFree(fieldCount, gateFilled)
	return fieldCount + (gateFilled and 1 or 0) < Config.FIELD_SLOTS
end

return Rules