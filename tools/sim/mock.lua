-- Minimal mock-Roblox runtime (Luau). Loads repo modules with their own env.
local ROOT = ...
local M = {}

local function Signal()
	local s = { _h = {} }
	function s:Connect(f) local c = { f = f, Connected = true }; table.insert(self._h, c)
		return { Disconnect = function() c.Connected = false end } end
	function s:Once(f) return self:Connect(f) end
	function s:Wait() return end
	function s:Fire(...)
		for _, c in ipairs(table.clone(self._h)) do
			if c.Connected then
				local co = coroutine.create(c.f)
				local ok, e = coroutine.resume(co, ...)
				if not ok then M.handlerErrors = M.handlerErrors or {}; table.insert(M.handlerErrors, tostring(e)) end
			end
		end
	end
	return s
end
M.Signal = Signal

local SIGNALS = { Activated=1, MouseButton1Click=1, MouseButton1Down=1, MouseButton1Up=1, MouseButton2Click=1,
	MouseEnter=1, MouseLeave=1, InputBegan=1, InputEnded=1, InputChanged=1, Changed=1, ChildAdded=1, ChildRemoved=1,
	Destroying=1, AncestryChanged=1, TouchLongPress=1, FocusLost=1, Heartbeat=1, RenderStepped=1, Completed=1, Event=1,
	OnClientEvent=1, OnServerEvent=1, PlayerAdded=1, PlayerRemoving=1, MouseMoved=1, TouchTap=1, TouchMoved=1, TouchEnded=1, TouchStarted=1, TouchPinch=1, TouchPan=1, WindowFocused=1, WindowFocusReleased=1,  MouseButton2Down=1, MouseButton2Up=1 }

local ClassIs = {
	TextButton = { GuiButton=1, GuiObject=1, GuiBase2d=1, TextButton=1 },
	ImageButton = { GuiButton=1, GuiObject=1, ImageButton=1 },
	Frame = { GuiObject=1, Frame=1 }, ScrollingFrame = { GuiObject=1, ScrollingFrame=1 },
	TextLabel = { GuiObject=1, TextLabel=1 }, ImageLabel = { GuiObject=1, ImageLabel=1 },
	TextBox = { GuiObject=1, TextBox=1 },
	-- ฉาก 3D: Part/Seat/MeshPart ฯลฯ เป็น BasePart ใน Roblox จริง (WorldPrompts เช็ก IsA("BasePart"))
	Part = { BasePart=1, PVInstance=1, Part=1 }, Seat = { BasePart=1, PVInstance=1, Seat=1 },
	MeshPart = { BasePart=1, PVInstance=1, MeshPart=1 }, WedgePart = { BasePart=1, PVInstance=1, WedgePart=1 },
	SpawnLocation = { BasePart=1, PVInstance=1, SpawnLocation=1 },
	ScreenGui = { LayerCollector=1, ScreenGui=1 }, BillboardGui = { LayerCollector=1, BillboardGui=1 },
}

local STRICT = STRICT_PROPS or {}
local STRICT_SET = {}
for cls, list in pairs(STRICT) do local s = {}; for _, p in ipairs(list) do s[p] = true end STRICT_SET[cls] = s end
M.invalid = {}
local function flag(kind, class, k)
	local key = kind .. " " .. class .. "." .. tostring(k)
	local tb = debug and debug.traceback and debug.traceback("", 3) or ""
	local where = tb:match("([%w_/%.]+%.lua:%d+)") or tb:match("(%S+:%d+)") or "?"
	local e = M.invalid[key]
	if not e then M.invalid[key] = { n = 1, where = where } else e.n += 1 end
end
local function newInstance(class)
	local inst = { ClassName = class, Name = class, _children = {}, _attrs = {}, _props = {}, _parent = nil }
	local mt = {}
	local function setParent(self, p)
		if self._parent then
			for i, c in ipairs(self._parent._children) do if c == self then table.remove(self._parent._children, i) break end end
		end
		rawset(self, "_parent", p)
		if p then table.insert(p._children, self) end
	end
	function inst:IsA(c) return c == class or c == "Instance" or (ClassIs[class] and ClassIs[class][c]) or false end
	function inst:FindFirstAncestorWhichIsA(c) local n = rawget(self, "_parent"); while n do if n:IsA(c) then return n end n = rawget(n, "_parent") end return nil end
	function inst:FindFirstAncestor(name) local n = rawget(self, "_parent"); while n do if n.Name == name then return n end n = rawget(n, "_parent") end return nil end
	function inst:GetChildren() return table.clone(self._children) end
	function inst:GetDescendants()
		local out = {}
		local function walk(n) for _, c in ipairs(n._children) do table.insert(out, c); walk(c) end end
		walk(self); return out end
	function inst:FindFirstChild(n, rec)
		for _, c in ipairs(self._children) do if c.Name == n then return c end end
		if rec then for _, c in ipairs(self:GetDescendants()) do if c.Name == n then return c end end end
	end
	function inst:FindFirstChildOfClass(cn) for _, c in ipairs(self._children) do if c.ClassName == cn then return c end end end
	function inst:FindFirstChildWhichIsA(cn) for _, c in ipairs(self._children) do if c:IsA(cn) then return c end end end
	-- เหมือน Roblox จริง: มี timeout → รอแล้วคืน nil ; ไม่มี timeout → รอตลอดกาล (yield ไม่กลับ) ; ถ้าไม่ได้อยู่ใน coroutine ที่ yield ได้ → throw ให้เห็น
	function inst:WaitForChild(n, timeout)
		local found = self:FindFirstChild(n)
		if found then return found end
		if not M.realWait then error("WaitForChild timeout: "..n.." in "..self.Name, 2) end
		local t0 = M.clock and M.clock() or 0
		while true do
			found = self:FindFirstChild(n)
			if found then return found end
			if timeout and (M.clock() - t0) >= timeout then return nil end
			task.wait(0.05)
		end
	end
	function inst:Destroy() rawset(self, "_destroyed", true); for _, c in ipairs(table.clone(self._children)) do c:Destroy() end; setParent(self, nil) end
	function inst:ClearAllChildren() for _, c in ipairs(table.clone(self._children)) do c:Destroy() end end
	function inst:SetAttribute(k, v)
		local changed = self._attrs[k] ~= v
		self._attrs[k] = v
		if changed then local sig = rawget(self, "_attr_" .. tostring(k)); if sig then sig:Fire() end end
	end
	function inst:GetAttributeChangedSignal(k)
		local key = "_attr_" .. tostring(k)
		local sig = rawget(self, key)
		if not sig then sig = Signal(); rawset(self, key, sig) end
		return sig
	end
	function inst:GetAttribute(k) return self._attrs[k] end
	function inst:Clone() local n = newInstance(class); for k, v in pairs(self._props) do n[k] = v end; return n end
	function inst:IsDescendantOf(a) local p = self._parent while p do if p == a then return true end p = p._parent end return false end
	function inst:GetFullName() return self.Name end
	function inst:GetPropertyChangedSignal(prop)
		local key = "_pcs_" .. tostring(prop)
		local sig = rawget(self, key)
		if not sig then sig = Signal(); rawset(self, key, sig) end
		return sig
	end
	function inst:Fire(...) self.Event:Fire(...) end -- BindableEvent
	function inst:TweenSize() end function inst:TweenPosition() end
	function inst:Play() end function inst:Stop() end function inst:Pause() end
	-- ค่าเริ่มต้นเหมือน Roblox จริง (ไม่งั้นโค้ดที่เช็ก .Enabled / .Visible จะเห็น nil)
	if class == "ScreenGui" or class == "BillboardGui" or class == "SurfaceGui" then inst._props.Enabled = true end
	local mk = M.vec2Factory or function(x, y) return {X=x,Y=y} end
	inst._props.AbsoluteSize = mk(800,600); inst._props.AbsolutePosition = mk(0,0); inst._props.AbsoluteContentSize = mk(0,0)
	mt.__index = function(t, k)
		local v = rawget(t, "_props")[k]
		if v ~= nil then return v end
		if k == "Parent" then return rawget(t, "_parent") end
		if SIGNALS[k] then local s = Signal(); t._props[k] = s; return s end
		if type(k) == "string" then
			for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
		end
		return nil
	end
	mt.__newindex = function(t, k, v)
		local ss = STRICT_SET[class]
		if ss and type(k) == "string" and not ss[k] and k:sub(1,1) ~= "_" and not SIGNALS[k] then flag("SET", class, k) end
		if k == "Parent" then setParent(t, v) return end
		if k == "Name" then rawset(t, "Name", v) return end
		if k == "AbsoluteSize" then
			t._props.AbsoluteSize = v
			local sig = rawget(t, "_pcs_AbsoluteSize"); if sig then sig:Fire() end
			return
		end
		t._props[k] = v
	end
	return setmetatable(inst, mt)
end

M.newInstance = newInstance
return M
