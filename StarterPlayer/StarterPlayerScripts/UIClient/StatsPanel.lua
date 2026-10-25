-- StarterPlayerScripts/UIClient/StatsPanel (ModuleScript)
-- หน้าสถิติ: วันนี้ / 7 วัน / ตลอดชีพ | ใส่ลงใน UIKit.panel(...).Content
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local UIKit = require(UI:WaitForChild("UIKit"))
local CardData = require(ReplicatedStorage.Shared:WaitForChild("CardData"))

local StatsPanel = {}
local TABS = {
	{ Key = "Today", Text = "📅 วันนี้" },
	{ Key = "Week", Text = "🗓️ 7 วัน" },
	{ Key = "Total", Text = "🏆 ตลอดชีพ" },
}
local ROW_H = 40

local function clock(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
	if h > 0 then return ("%d ชม. %d นาที"):format(h, m) end
	if m > 0 then return ("%d นาที %d วิ"):format(m, s) end
	return ("%d วิ"):format(s)
end

local function num(n) return tostring(math.floor((n or 0) + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
local function pct(n) return ("%.1f%%"):format(n or 0) end
local function cardName(id) local c = id and CardData[id] return c and c.Name or "-" end

-- กลุ่มสถิติ: { หัวข้อ, { {ป้าย, ค่า}, ... } }
local function groups(b)
	local d = b.Derived
	local topPlayed = d.TopPlayedCard and ("%s (%s ครั้ง)"):format(cardName(d.TopPlayedCard), num(d.TopPlayedCount)) or "-"
	local topKill = d.TopKillCard and ("%s (%s ตัว)"):format(cardName(d.TopKillCard), num(d.TopKillCount)) or "-"
	local topLeader = d.TopLeader and ("%s (%s แมตช์)"):format(cardName(d.TopLeader), num(d.TopLeaderMatches)) or "-"
	return {
		{ "⚔️ ผลการแข่ง", {
			{ "แมตช์ทั้งหมด", num(b.Matches) },
			{ "ชนะ", num(b.Wins) }, { "แพ้", num(b.Losses) },
			{ "เสมอ", num(b.Draws) },
			{ "อัตราชนะ", pct(d.WinRate) },
			{ "PvP (ชนะ/แพ้)", ("%s / %s  (%s)"):format(num(b.WinsPvP), num(b.LossesPvP), pct(d.WinRatePvP)) },
			{ "ซ้อมบอท (ชนะ/แพ้)", ("%s / %s  (%s)"):format(num(b.WinsBot), num(b.LossesBot), pct(d.WinRateBot)) },
			{ "ได้เล่นก่อน ชนะ", pct(d.GoingFirstWinRate) },
		} },
		{ "⏱️ เวลา", {
			{ "เวลาเล่นรวม", clock(b.PlaySec) },
			{ "เฉลี่ยต่อแมตช์", clock(d.AvgMatchSec) },
			{ "แมตช์ที่ยาวที่สุด", clock(b.LongestMatchSec) },
			{ "ชนะเร็วที่สุด", b.ShortestWinSec > 0 and clock(b.ShortestWinSec) or "-" },
			{ "เวลาเฉพาะที่ชนะ", clock(b.WinSec) },
			{ "เวลาเฉพาะที่แพ้", clock(b.LossSec) },
		} },
		{ "🔎 คิว", {
			{ "เข้าคิว PvP", num(b.QueuePvP) },
			{ "เข้าคิวซ้อมบอท", num(b.QueueBot) },
			{ "ยกเลิกคิว", num(b.QueueCancel) },
			{ "จับคู่สำเร็จ", num(b.QueueMatched) },
			{ "รอคิวเฉลี่ย", clock(d.AvgQueueWaitSec) },
		} },
		{ "🃏 การ์ด", {
			{ "ลงการ์ดทั้งหมด", num(b.CardsPlayed) },
			{ "ตัวละคร / เวท / อาวุธ", ("%s / %s / %s"):format(num(b.CharactersPlayed), num(b.SpellsPlayed), num(b.WeaponsPlayed)) },
			{ "ลงสนาม / ลงเกต", ("%s / %s"):format(num(b.PlayedToField), num(b.PlayedToGate)) },
			{ "พอยต์ที่ใช้", num(b.PointsSpent) },
			{ "การ์ดต่อแมตช์", tostring(d.CardsPerMatch) },
			{ "จั่วการ์ด", num(b.CardsDrawn) },
			{ "การ์ดที่ใช้บ่อยสุด", topPlayed },
			{ "การ์ดที่ฆ่าได้มากสุด", topKill },
			{ "ผู้นำที่เล่นบ่อยสุด", topLeader },
		} },
		{ "🎲 ช่องเกต", {
			{ "ทอยเกตทั้งหมด", num(b.GateRolls) },
			{ "ร่างทอง ✨", ("%s (%s)"):format(num(b.GateGolden), pct(d.GoldenRate)) },
			{ "ปั่นติด 💪", num(b.GatePumped) },
			{ "ธรรมดา 😐", num(b.GateNormal) },
			{ "ย้วย 😵", num(b.GateDroopy) },
			{ "ก้อนอึ 💩", ("%s (%s)"):format(num(b.GatePoop), pct(d.PoopRate)) },
		} },
		{ "💥 การต่อสู้", {
			{ "โจมตีทั้งหมด", num(b.Attacks) },
			{ "ตีผู้นำ / ตีการ์ด", ("%s / %s"):format(num(b.AttacksAtLeader), num(b.AttacksAtCard)) },
			{ "ตีพลาด (สไลม์)", num(b.AttacksMissed) },
			{ "ดาเมจใส่ผู้นำ", num(b.DamageToLeader) },
			{ "ดาเมจใส่การ์ด", num(b.DamageToCards) },
			{ "ดาเมจที่ผู้นำเราโดน", num(b.DamageTaken) },
			{ "ฆ่าการ์ดศัตรู", num(b.KillsMade) },
			{ "การ์ดเราตาย", num(b.CardsLost) },
			{ "ฮีลรวม", num(b.HealDone) },
			{ "โล่ที่ตั้ง", num(b.ShieldGained) },
			{ "สวมอาวุธ / ปาอาวุธ", ("%s / %s"):format(num(b.WeaponsEquipped), num(b.WeaponsThrown)) },
			{ "โบนัสธาตุ / โทษธาตุ", ("%s / %s"):format(num(b.ElementBonus), num(b.ElementPenalty)) },
		} },
		{ "⏳ เทิร์น", {
			{ "เทิร์นที่เล่น", num(b.Turns) },
			{ "ข้ามเทิร์น (ดองพอยต์)", num(b.TurnsSkipped) },
			{ "พอยต์ที่ดองไว้รวม", num(b.PointsBanked) },
			{ "หมดเวลาเทิร์น", num(b.TurnsTimedOut) },
			{ "ถูกการ์ดหมดกองเล่นงาน", ("%s ครั้ง (-%s HP)"):format(num(b.FatigueTurns), num(b.FatigueDamage)) },
		} },
		{ "🚪 การจบเกม", {
			{ "ยอมแพ้", num(b.Surrenders) },
			{ "แพ้เพราะ AFK", num(b.AfkLosses) },
			{ "หลุด/ออกกลางแมตช์", num(b.Disconnects) },
			{ "ศัตรูหนีออกให้เราชนะ", num(b.OpponentLeft) },
		} },
		{ "💎 รางวัล", {
			{ "เพชรที่ได้จากแมตช์", num(b.GemsEarned) },
			{ "โบนัสค่าหัว", num(b.BountyEarned) },
			{ "เพชรสูงสุดในแมตช์เดียว", num(b.BestGemsOneMatch) },
		} },
	}
end

local function sectionBox(list, order, title)
	local box = UIKit.new("Frame", {
		Name = "Group", LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, Parent = list,
	}, {
		UIKit.corner(UDim.new(0, 12)),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UIKit.new("TextLabel", {
		LayoutOrder = 0, Size = UDim2.new(1, 0, 0, ROW_H - 4), BackgroundTransparency = 1, Font = Theme.Font,
		Text = title, TextSize = 24, TextColor3 = Theme.Color.Outline, TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
	})
	return box
end

local function statRow(parent, order, label, value)
	local r = UIKit.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = parent })
	UIKit.new("TextLabel", {
		Size = UDim2.fromScale(0.55, 1), BackgroundTransparency = 1, Font = Theme.FontBody, Text = label, TextSize = 18,
		TextColor3 = Color3.fromRGB(90, 80, 70), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r,
	})
	UIKit.new("TextLabel", {
		Size = UDim2.fromScale(0.45, 1), Position = UDim2.fromScale(0.55, 0), BackgroundTransparency = 1, Font = Theme.FontBody,
		Text = value, TextSize = 18, TextColor3 = Theme.Color.Outline, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = r,
	})
end

-- กราฟแท่งแมตช์ 7 วันล่าสุด (ชนะ = เขียว, แพ้ = แดง)
local function dayChart(list, order, days)
	local box = sectionBox(list, order, "📈 แมตช์ 7 วันล่าสุด")
	local area = UIKit.new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1, Parent = box })
	local peak = 1
	for _, d in ipairs(days) do peak = math.max(peak, d.Wins + d.Losses) end
	for i, d in ipairs(days) do
		local x = (i - 1) / #days
		local col = UIKit.new("Frame", { Size = UDim2.fromScale(1 / #days, 1), Position = UDim2.fromScale(x, 0), BackgroundTransparency = 1, Parent = area })
		local wH, lH = d.Wins / peak * 0.7, d.Losses / peak * 0.7
		UIKit.new("Frame", { -- แพ้ (ล่าง)
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.5, lH),
			BackgroundColor3 = Theme.Color.Red, BorderSizePixel = 0, Parent = col,
		}, { UIKit.corner(UDim.new(0.2, 0)) })
		UIKit.new("Frame", { -- ชนะ (วางบนแพ้)
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.78 - lH), Size = UDim2.fromScale(0.5, wH),
			BackgroundColor3 = Theme.Color.Green, BorderSizePixel = 0, Parent = col,
		}, { UIKit.corner(UDim.new(0.2, 0)) })
		UIKit.new("TextLabel", {
			Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2), BackgroundTransparency = 1, Font = Theme.FontBody,
			Text = d.Day:sub(9, 10) .. "/" .. d.Day:sub(6, 7), TextSize = 14, TextColor3 = Color3.fromRGB(90, 80, 70), Parent = col,
		})
		if d.Wins + d.Losses > 0 then
			UIKit.new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.78 - lH - wH), Size = UDim2.fromScale(1, 0.14),
				BackgroundTransparency = 1, Font = Theme.FontBody, Text = tostring(d.Wins + d.Losses), TextSize = 14,
				TextColor3 = Theme.Color.Outline, Parent = col,
			})
		end
	end
end

-- สรุปผู้นำ (แมตช์/ชนะ/แพ้)
local function leaderTable(list, order, b)
	local rows = {}
	for id, l in pairs(b.Leaders) do table.insert(rows, { id = id, l = l }) end
	if #rows == 0 then return end
	table.sort(rows, function(a, c) return (a.l.Matches or 0) > (c.l.Matches or 0) end)
	local box = sectionBox(list, order, "👑 สถิติรายผู้นำ")
	for i, r in ipairs(rows) do
		statRow(box, i, cardName(r.id), ("%s แมตช์ • ชนะ %s • แพ้ %s"):format(num(r.l.Matches), num(r.l.Wins), num(r.l.Losses)))
	end
end

-- การ์ดที่ใช้บ่อย 8 อันดับ
local function cardTable(list, order, b)
	local rows = {}
	for id, c in pairs(b.Cards) do
		if (c.Played or 0) > 0 then table.insert(rows, { id = id, c = c }) end
	end
	if #rows == 0 then return end
	table.sort(rows, function(a, c) return a.c.Played > c.c.Played end)
	local box = sectionBox(list, order, "🃏 การ์ดที่ใช้บ่อย 8 อันดับ")
	for i = 1, math.min(8, #rows) do
		local r = rows[i]
		statRow(box, i, ("%d. %s"):format(i, cardName(r.id)),
			("ลง %s • ฆ่า %s • ตาย %s"):format(num(r.c.Played), num(r.c.Kills), num(r.c.Deaths)))
	end
end

function StatsPanel.Build(content, fetch)
	local tabBar = UIKit.new("Frame", { Size = UDim2.fromScale(1, 0.1), BackgroundTransparency = 1, Parent = content }, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local body = UIKit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.88), Position = UDim2.fromScale(0, 0.12), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content,
	}, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	local snapshot, current, loading = nil, "Today", false
	local buttons = {}

	local function render()
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if not snapshot then
			UIKit.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, Font = Theme.Font, TextSize = 26,
				Text = loading and "⏳ กำลังโหลดสถิติ..." or "โหลดสถิติไม่สำเร็จ ลองเปิดใหม่อีกครั้ง",
				TextColor3 = Theme.Color.Outline, Parent = body,
			})
			return
		end
		local b = snapshot[current]
		local n = 0
		local function nextOrder() n = n + 1 return n end
		UIKit.new("TextLabel", {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Font = Theme.FontBody, TextSize = 18,
			Text = ("🔥 ชนะติดต่อกันตอนนี้ %d  •  สูงสุด %d  •  วันที่ %s (เวลาไทย)"):format(snapshot.Streak, snapshot.BestStreak, snapshot.DayKey),
			TextColor3 = Color3.fromRGB(90, 80, 70), Parent = body,
		})
		if b.Matches == 0 and b.QueuePvP + b.QueueBot == 0 then
			UIKit.new("TextLabel", {
				LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Font = Theme.Font, TextSize = 22,
				Text = "ยังไม่มีข้อมูลในช่วงนี้ ลงสนามสักตาแล้วกลับมาดูนะ 🎮", TextColor3 = Theme.Color.Outline, Parent = body,
			})
		end
		if current == "Week" then dayChart(body, nextOrder(), snapshot.Days) end
		for _, g in ipairs(groups(b)) do
			local box = sectionBox(body, nextOrder(), g[1])
			for i, r in ipairs(g[2]) do statRow(box, i, r[1], r[2]) end
		end
		leaderTable(body, nextOrder(), b)
		cardTable(body, nextOrder(), b)
	end

	local function refreshTabs()
		for key, btn in pairs(buttons) do
			UIKit.setColor(btn, key == current and Theme.Color.Pink or Theme.Color.Gray)
		end
	end

	for i, tab in ipairs(TABS) do
		local btn = UIKit.button({
			Text = tab.Text, Color = Theme.Color.Gray, Size = UDim2.fromScale(0.3, 1), Parent = tabBar,
			OnClick = function() current = tab.Key refreshTabs() render() end,
		})
		btn.LayoutOrder = i
		buttons[tab.Key] = btn
	end
	refreshTabs()

	-- เรียกทุกครั้งที่เปิดหน้า เพื่อให้ตัวเลขสดเสมอ
	local api = {}
	function api.Refresh()
		loading = true
		render()
		task.spawn(function()
			local ok, result = pcall(fetch)
			loading = false
			snapshot = ok and typeof(result) == "table" and result or nil
			if body.Parent then render() end
		end)
	end
	api.Refresh()
	return api
end

return StatsPanel
