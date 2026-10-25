-- ReplicatedStorage/Shared/UI/CardInspector (ModuleScript)
-- หน้าดูการ์ดแบบเต็ม: ใช้ได้ทุกเมนู ทุกสถานะ (ScreenGui แยก DisplayOrder 1000 = อยู่บนสุดเสมอ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local CardView = require(script.Parent.CardView)
local CardData = require(script.Parent.Parent.CardData)

local CardInspector = {}
local CENTER = Vector2.new(0.5, 0.5)
local INSPECT_KEY = Enum.KeyCode.F

local gui
local ui = {}
local isOpen = false
local shown = nil
local list, index = nil, 1
local bigView = nil
local T = 18
local hovered = nil
local tracked = setmetatable({}, { __mode = "k" })

local function esc(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

local function statText(now, baseVal)
	if typeof(baseVal) ~= "number" or now == baseVal then return tostring(now) end
	return ("%s %s (เดิม %s)"):format(tostring(now), now > baseVal and "▲" or "▼", tostring(baseVal))
end

local function text(parent, order, str, size, color, font)
	return UIKit.new("TextLabel", {
		Name = "Text", LayoutOrder = order, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Font = font or Theme.FontBody, RichText = true, Text = str,
		TextSize = size or T, TextColor3 = color or Theme.Color.Outline,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
end

local function row(parent, order)
	return UIKit.new("Frame", {
		Name = "Row", LayoutOrder = order, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Wraps = true,
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function chip(parent, str, color)
	return UIKit.new("TextLabel", {
		Name = "Chip", BackgroundColor3 = color, Size = UDim2.new(0, 0, 0, T + 16),
		AutomaticSize = Enum.AutomaticSize.X, Font = Theme.Font, Text = str,
		TextSize = T, TextColor3 = Color3.new(1, 1, 1), Parent = parent,
	}, {
		UIKit.corner(UDim.new(0.5, 0)),
		UIKit.new("UIStroke", { Thickness = 2, Color = Theme.Color.Outline }),
		UIKit.new("UIStroke", { Thickness = 2, Color = Theme.Color.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
end

local function section(parent, order, title, color)
	local box = UIKit.new("Frame", {
		Name = "Section", LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	}, {
		UIKit.corner(UDim.new(0, 12)),
		UIKit.new("UIStroke", { Thickness = 2, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UIKit.new("UIPadding", {
			PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
		}),
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	text(box, 0, "<b>" .. title .. "</b>", T, color)
	return box
end

local function build()
	gui = UIKit.new("ScreenGui", {
		Name = "CardInspector", DisplayOrder = 1000, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	ui.dim = UIKit.new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, Parent = gui,
	})
	ui.dim.Activated:Connect(function() CardInspector.Close() end)

	-- TextButton = กันคลิกบนกล่องทะลุไปปิดหน้าต่าง
	ui.box = UIKit.new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.fromScale(0.88, 0.82),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = CENTER,
		BackgroundColor3 = Theme.Color.Panel, Parent = ui.dim,
	}, {
		UIKit.corner(UDim.new(0.04, 0)),
		UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1.75 }),
	})
	ui.stroke = UIKit.stroke(nil, 5)
	ui.stroke.Parent = ui.box
	ui.scale = UIKit.new("UIScale", { Parent = ui.box })

	-- ซ้าย: แสงตามความหายาก + การ์ดใบใหญ่
	ui.left = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.38, 0.9), Position = UDim2.fromScale(0.025, 0.05),
		BackgroundTransparency = 0.55, Parent = ui.box,
	}, {
		UIKit.corner(UDim.new(0.06, 0)),
		UIKit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9),
			}),
		}),
	})

	-- ขวา: ข้อมูลทั้งหมด (เลื่อนได้ ยาวแค่ไหนก็ไม่โดนตัด)
	ui.info = UIKit.new("ScrollingFrame", {
		Size = UDim2.fromScale(0.54, 0.76), Position = UDim2.fromScale(0.43, 0.06),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Outline, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = ui.box,
	}, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 4) }),
	})

	ui.prev = UIKit.button({
		Text = "◀", Color = Theme.Color.Blue, Size = UDim2.fromScale(0.07, 0.1),
		Position = UDim2.fromScale(0.43, 0.95), AnchorPoint = Vector2.new(0, 1), Parent = ui.box,
		OnClick = function() CardInspector.Step(-1) end,
	})
	ui.next = UIKit.button({
		Text = "▶", Color = Theme.Color.Blue, Size = UDim2.fromScale(0.07, 0.1),
		Position = UDim2.fromScale(0.97, 0.95), AnchorPoint = Vector2.new(1, 1), Parent = ui.box,
		OnClick = function() CardInspector.Step(1) end,
	})
	ui.counter = UIKit.label({
		Text = "", Size = UDim2.fromScale(0.3, 0.07), Position = UDim2.fromScale(0.7, 0.935),
		AnchorPoint = Vector2.new(0.5, 1), Parent = ui.box,
	})
	local close = UIKit.button({
		Text = "✖", Color = Theme.Color.Red, Size = UDim2.fromScale(0.05, 0.09),
		Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0.6, 0.4), Parent = ui.box,
		OnClick = function() CardInspector.Close() end,
	})
	UIKit.new("UIAspectRatioConstraint", { Parent = close })

	UIKit.label({
		Text = "คลิกพื้นหลัง / F / B = ปิด   •   ◀ ▶ / Q E / LB RB = เปลี่ยนใบ",
		Font = Theme.FontBody, Size = UDim2.fromScale(0.8, 0.035),
		Position = UDim2.fromScale(0.5, 0.985), AnchorPoint = Vector2.new(0.5, 1), Parent = ui.dim,
	})
end

local function show(card, quiet)
	shown = card
	local base = card.Id and CardData[card.Id] or nil
	local accent = card.Rarity == "Mystic" and Theme.Color.Pink or (Theme.Rarity[card.Rarity] or Theme.Rarity.Common)
	ui.stroke.Color = accent
	ui.left.BackgroundColor3 = accent

	if bigView then bigView:Remove() end
	bigView = CardView.new(card, { Size = UDim2.fromScale(0.92, 0.92), Static = true })
	bigView.Frame.AnchorPoint = CENTER
	bigView.Frame.Position = UDim2.fromScale(0.5, 0.5)
	bigView.Frame.Parent = ui.left
	if not quiet then bigView:PopIn() end

	for _, c in ipairs(ui.info:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end

	text(ui.info, 1, "<b>" .. esc(card.Name or "???") .. "</b>", math.floor(T * 1.8), Theme.Color.Outline, Theme.Font)

	local tags = row(ui.info, 2)
	chip(tags, Theme.RarityText[card.Rarity] or card.Rarity or "ธรรมดา", accent)
	chip(tags, Theme.TypeText[card.Type] or card.Type or "?", Theme.Color.Gray)
	local el = Theme.Element[card.Element]
	if el then chip(tags, "ธาตุ" .. el.Text, el.Color) end

	local stats = row(ui.info, 3)
	chip(stats, "💰 ค่าร่าย " .. statText(card.Cost or 0, base and base.Cost), Theme.Color.Yellow)
	if card.Type == "Character" or card.Type == "Leader" then
		chip(stats, "⚔️ โจมตี " .. statText(card.ATK or 0, base and base.ATK), Theme.Color.Red)
		chip(stats, "❤️ พลังชีวิต " .. statText(math.max(card.HP or 0, 0), base and base.HP), Theme.Color.Green)
	elseif card.Type == "Weapon" then
		if typeof(card.Bonus) == "number" then chip(stats, "🗡️ โบนัส +" .. card.Bonus, Theme.Color.Red) end
		if typeof(card.Durability) == "number" then chip(stats, "🔧 ความทน " .. card.Durability, Theme.Color.Blue) end
		if card.Freeze then chip(stats, "❄️ แช่แข็งเป้า", Theme.Color.Blue) end
	end

	local desc = card.Desc or (base and base.Desc)
	if desc and desc ~= "" then
		local s = section(ui.info, 4, "📜 ความสามารถ", Color3.fromRGB(60, 100, 200))
		text(s, 1, esc(desc))
	end

	if card.Keywords and #card.Keywords > 0 then
		local s = section(ui.info, 5, "🏷️ คีย์เวิร์ด", Color3.fromRGB(140, 70, 210))
		for i, kw in ipairs(card.Keywords) do
			text(s, i, ("<b>%s</b> — %s"):format(esc(Theme.Keyword[kw] or kw), esc(Theme.KeywordDesc[kw] or "-")))
		end
	end

	local status = {}
	local gate = card.GateResult and Theme.Gate[card.GateResult]
	if gate then table.insert(status, "🎲 ผลเกต: " .. gate.Text) end
	if card.Frozen then table.insert(status, "❄️ ถูกแช่แข็ง") end
	if card.Slime then table.insert(status, "🟢 ติดเมือก") end
	if card.WeaponName then
		table.insert(status, ("🗡️ ถืออาวุธ %s (เหลือ %s ครั้ง)"):format(esc(card.WeaponName), tostring(card.WeaponDur or 0)))
	end
	if card.Type == "Character" and card.CanAttack == false then table.insert(status, "💤 เทิร์นนี้ยังโจมตีไม่ได้") end
	if #status > 0 then
		local s = section(ui.info, 6, "📍 สถานะตอนนี้", Color3.fromRGB(200, 90, 40))
		for i, line in ipairs(status) do text(s, i, line) end
	end

	local flavor = card.Flavor or (base and base.Flavor)
	if flavor and flavor ~= "" and flavor ~= desc then
		text(ui.info, 7, "<i>“" .. esc(flavor) .. "”</i>", T - 2, Color3.fromRGB(110, 100, 90))
	end

	local many = list ~= nil and #list > 1
	ui.prev.Visible, ui.next.Visible, ui.counter.Visible = many, many, many
	ui.counter.Text = many and ("%d / %d"):format(index, #list) or ""
	ui.info.Size = UDim2.fromScale(0.54, many and 0.76 or 0.88)
	if not quiet then ui.info.CanvasPosition = Vector2.zero end
end

-- card: ข้อมูลการ์ด | cards/i: (ไม่บังคับ) รายการให้กด ◀ ▶ ได้
function CardInspector.Open(card, cards, i)
	if not card then return end
	if not gui then build() end
	local cam = workspace.CurrentCamera
	T = math.clamp(math.floor((cam and cam.ViewportSize.Y or 720) / 40), 12, 24)
	list, index = cards, i or 1
	show(card)
	if not isOpen then
		isOpen = true
		gui.Enabled = true
		ui.dim.BackgroundTransparency = 1
		ui.scale.Scale = 0.7
		UIKit.tween(ui.dim, 0.2, { BackgroundTransparency = 0.35 })
		UIKit.tween(ui.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.sfx("Click")
	end
end

function CardInspector.OpenByName(name)
	for id, data in pairs(CardData) do
		if type(data) == "table" and data.Name == name then
			local c = table.clone(data)
			c.Id = id
			return CardInspector.Open(c)
		end
	end
end

function CardInspector.Step(d)
	if not (isOpen and list and #list > 1) then return end
	index = (index - 1 + d) % #list + 1
	show(list[index])
	UIKit.sfx("Click")
end

-- อัปเดตแบบสด: ถ้าการ์ดที่เปิดดูอยู่โดนตี/บัฟ ข้อมูลจะเปลี่ยนตามทันที
function CardInspector.Refresh(card)
	if not (isOpen and shown and card and card.Uid and shown.Uid == card.Uid) then return end
	if list then list[index] = card end
	show(card, true)
end

function CardInspector.Close()
	if not isOpen then return end
	isOpen = false
	UIKit.tween(ui.dim, 0.15, { BackgroundTransparency = 1 })
	UIKit.tween(ui.scale, 0.15, { Scale = 0.7 }).Completed:Once(function()
		if not isOpen then gui.Enabled = false end
	end)
end

function CardInspector.IsOpen() return isOpen end

-- CardView เรียกเพื่อให้กด F ตอนชี้ หรือกด Y บนจอย เปิดดูได้
function CardInspector.Track(hit, open)
	tracked[hit] = open
	hit.MouseEnter:Connect(function() hovered = hit end)
	hit.MouseLeave:Connect(function() if hovered == hit then hovered = nil end end)
end

if RunService:IsClient() then
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then return end
		local k = input.KeyCode
		if isOpen then
			if k == INSPECT_KEY or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Backspace then
				CardInspector.Close()
			elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL1 then
				CardInspector.Step(-1)
			elseif k == Enum.KeyCode.E or k == Enum.KeyCode.Right or k == Enum.KeyCode.ButtonR1 then
				CardInspector.Step(1)
			end
		elseif k == INSPECT_KEY and hovered and hovered.Parent and tracked[hovered] then
			tracked[hovered]()
		elseif k == Enum.KeyCode.ButtonY then
			local sel = GuiService.SelectedObject
			if sel and tracked[sel] then tracked[sel]() end
		end
	end)
end

return CardInspector