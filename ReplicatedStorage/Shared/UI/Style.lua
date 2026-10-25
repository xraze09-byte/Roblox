-- ธีมเรียบ: สีน้อย ไม่มีอีโมจิ ไม่มีกราเดียนต์ ปุ่มไม่เด้ง
local Style = {}

local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end

Style.Font = {
	Regular = font("BuilderSans", Enum.Font.Gotham),
	Medium = font("BuilderSansMedium", Enum.Font.GothamMedium),
	Bold = font("BuilderSansBold", Enum.Font.GothamBold),
	Heavy = font("BuilderSansExtraBold", Enum.Font.GothamBlack),
}

Style.C = {
	Bg = Color3.fromRGB(21, 23, 26),     Panel = Color3.fromRGB(30, 33, 37),
	Panel2 = Color3.fromRGB(40, 44, 49), Line = Color3.fromRGB(62, 67, 72),
	Felt = Color3.fromRGB(28, 41, 37),   FeltDark = Color3.fromRGB(21, 31, 28),
	Paper = Color3.fromRGB(234, 228, 214), Ink = Color3.fromRGB(30, 28, 26),
	InkSoft = Color3.fromRGB(105, 99, 90), Text = Color3.fromRGB(230, 226, 218),
	TextDim = Color3.fromRGB(146, 150, 146), Accent = Color3.fromRGB(214, 137, 54),
	Good = Color3.fromRGB(104, 160, 104), Bad = Color3.fromRGB(190, 74, 58),
	Info = Color3.fromRGB(96, 142, 186),
}
Style.Rarity = {
	Common = Color3.fromRGB(150, 146, 138), Rare = Color3.fromRGB(86, 132, 180),
	Epic = Color3.fromRGB(150, 98, 170), Legend = Color3.fromRGB(205, 160, 60), Mystic = Color3.fromRGB(200, 90, 120),
}
Style.Element = {
	Sati = Color3.fromRGB(74, 110, 140), Biao = Color3.fromRGB(160, 72, 60),
	Muen = Color3.fromRGB(110, 96, 140), Gawa = Color3.fromRGB(150, 120, 60),
}
Style.Name = {
	Type = { Character = "ตัวละคร", Spell = "เวท", Weapon = "อาวุธ", Leader = "ผู้นำ" },
	Element = { Sati = "สติ", Biao = "เบียว", Muen = "มึน", Gawa = "กาว" },
	Rarity = { Common = "ธรรมดา", Rare = "หายาก", Epic = "มหากาพย์", Legend = "ตำนาน", Mystic = "ลึกลับ" },
	Keyword = { Rush = "บุก", Taunt = "ยั่วยุ", Necro = "ปลุกศพ", Unlucky = "ดวงซวย", Steal = "ขโมย" },
}

function Style.new(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
	local parent
	for k, v in props or {} do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

function Style.corner(r) return Style.new("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end
function Style.pad(px)
	local u = UDim.new(0, px)
	return Style.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end
function Style.stroke(color, thickness, parent)
	return Style.new("UIStroke", {
		Color = color, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

function Style.text(p)
	local lbl = Style.new("TextLabel", {
		Name = p.Name or "Text", BackgroundTransparency = 1, Text = p.Text or "",
		Font = p.Font or Style.Font.Regular, TextColor3 = p.Color or Style.C.Text,
		TextScaled = true, TextWrapped = p.Wrap ~= false,
		TextXAlignment = Enum.TextXAlignment[p.XAlign or "Left"],
		TextYAlignment = Enum.TextYAlignment[p.YAlign or "Center"],
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, ZIndex = p.ZIndex or 1,
		LayoutOrder = p.LayoutOrder or 0, Parent = p.Parent,
	})
	Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = p.Min or 6, Parent = lbl })
	return lbl
end

function Style.button(p)
	local base = p.Color or Style.C.Panel2
	local btn = Style.new("TextButton", {
		Name = p.Name or "Button", AutoButtonColor = false, Text = p.Text or "",
		Font = p.Font or Style.Font.Bold, TextColor3 = p.TextColor or Style.C.Text,
		TextScaled = true, TextWrapped = true, BackgroundColor3 = base,
		Position = p.Position or UDim2.new(), Size = p.Size or UDim2.fromScale(1, 1),
		AnchorPoint = p.AnchorPoint or Vector2.zero, LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1, Parent = p.Parent,
	}, {
		Style.corner(p.Radius or 4),
		Style.new("UITextSizeConstraint", { MaxTextSize = p.Max or 18, MinTextSize = 6 }),
		Style.pad(p.Pad or 6),
	})
	local hovered = false
	local function paint()
		local c = btn:GetAttribute("Base") or base
		if btn:GetAttribute("Disabled") then
			btn.BackgroundColor3 = c:Lerp(Style.C.Bg, 0.55)
			btn.TextTransparency = 0.45
		else
			btn.BackgroundColor3 = hovered and c:Lerp(Color3.new(1, 1, 1), 0.08) or c
			btn.TextTransparency = 0
		end
	end
	btn:SetAttribute("Base", base)
	btn.MouseEnter:Connect(function() hovered = true paint() end)
	btn.MouseLeave:Connect(function() hovered = false paint() end)
	btn:GetAttributeChangedSignal("Disabled"):Connect(paint)
	btn:GetAttributeChangedSignal("Base"):Connect(paint)
	if p.OnClick then
		local last = 0
		btn.Activated:Connect(function()
			if btn:GetAttribute("Disabled") then return end
			local now = os.clock()
			if now - last < (p.Debounce or 0.25) then return end -- กันกดรัวฝั่งไคลเอนต์
			last = now
			p.OnClick(btn)
		end)
	end
	paint()
	return btn
end

function Style.setEnabled(btn, on) btn:SetAttribute("Disabled", not on) end
function Style.setBase(btn, color) btn:SetAttribute("Base", color) end

-- ตัดอีโมจิออกจากข้อความที่มาจากเซิร์ฟเวอร์
function Style.clean(text)
	text = tostring(text or "")
	local ok, out = pcall(function()
		local parts = {}
		for _, cp in utf8.codes(text) do
			local emoji = cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF)
				or (cp >= 0x2B00 and cp <= 0x2BFF) or cp == 0xFE0F or cp == 0x200D
			if not emoji then table.insert(parts, utf8.char(cp)) end
		end
		return table.concat(parts)
	end)
	if not ok then return text end
	return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Style.screen(name, order, parent)
	local g = Style.new("ScreenGui", {
		Name = name, DisplayOrder = order, ResetOnSpawn = false,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	pcall(function() g.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets end)
	g.Parent = parent
	return g
end

-- Toast: ซ้อนกันเป็นแถว ไม่ทับกัน สูงสุด 3 อัน
Style.toastParent = nil
local holder, seq, lastText, lastAt = nil, 0, nil, 0
local KIND = {
	info = Style.C.Panel2, good = Color3.fromRGB(44, 68, 48), bad = Color3.fromRGB(84, 40, 36),
}
function Style.toast(text, kind)
	local parent = Style.toastParent
	if not parent then return end
	text = Style.clean(text)
	if text == "" then return end
	if text == lastText and os.clock() - lastAt < 0.6 then return end
	lastText, lastAt = text, os.clock()
	if not holder or not holder.Parent then
		holder = Style.new("Frame", {
			Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.42, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50, Parent = parent,
		}, {
			Style.new("UIListLayout", {
				Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Style.new("UISizeConstraint", { MaxSize = Vector2.new(460, 9999) }),
		})
	end
	local items = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #items >= 3 do table.remove(items, 1):Destroy() end
	seq += 1
	local f = Style.new("Frame", {
		BackgroundColor3 = KIND[kind or "info"] or KIND.info, Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = seq, ZIndex = 50, Parent = holder,
	}, { Style.corner(4) })
	Style.stroke(Style.C.Line, 1, f)
	Style.text({ Text = text, Max = 16, XAlign = "Center", Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0), ZIndex = 51, Parent = f })
	task.delay(2.6, function() if f.Parent then f:Destroy() end end)
end

return Style
