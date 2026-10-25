-- Builds the fake Roblox world + a module loader that mirrors Roblox require semantics.
local M = require("./mock")
local newInstance, Signal = M.newInstance, M.Signal
local REPO = _G_REPO

-- ───── datatypes ─────
local function vec2(x, y) return { X = x or 0, Y = y or 0 } end
local Vector2 = { new = vec2, zero = vec2(0,0) }
local Vector3 = { new = function(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0} end }
Vector3.zero = Vector3.new()
local UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local UDim2 = {
	new = function(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end,
	fromScale = function(x, y) return { X = UDim.new(x, 0), Y = UDim.new(y, 0) } end,
	fromOffset = function(x, y) return { X = UDim.new(0, x), Y = UDim.new(0, y) } end,
}
local function color(r,g,b) local c = {R=r,G=g,B=b}
	function c:Lerp(o, a) return color(r+(o.R-r)*a, g+(o.G-g)*a, b+(o.B-b)*a) end return c end
local Color3 = { new = function(r,g,b) return color(r or 0,g or 0,b or 0) end,
	fromRGB = function(r,g,b) return color((r or 0)/255,(g or 0)/255,(b or 0)/255) end,
	fromHSV = function(h,s,v) return color(v or 0,v or 0,v or 0) end,
	fromHex = function() return color(0,0,0) end }
local function seqType(name) return { new = function(...) return { _t = name, ... } end } end
local ColorSequence = seqType("CS"); local NumberSequence = seqType("NS"); local NumberRange = seqType("NR")
local ColorSequenceKeypoint = seqType("CSK"); local NumberSequenceKeypoint = seqType("NSK")
local TweenInfo = { new = function(...) return { ... } end }
local Rect = { new = function(...) return { ... } end }
local Random = { new = function(seed)
	SIM_RNG_N = (SIM_RNG_N or 0) + 1
	local st = ((seed or ((SIM_SEED or 1) * 7919 + SIM_RNG_N * 104729))) % 2147483647; if st <= 0 then st = 1 end
	local function nxt() st = (st * 48271) % 2147483647; return st / 2147483647 end
	return { NextNumber = function(_, lo, hi) return (lo or 0) + nxt() * ((hi or 1) - (lo or 0)) end,
		NextInteger = function(_, lo, hi) return lo + math.floor(nxt() * (hi - lo + 1)) end }
end }
local CFrame = { new = function() return {} end, Angles = function() return {} end }

-- Enum: any Enum.X.Y resolves to a stable table
local Enum = setmetatable({}, { __index = function(t, k)
	local e = setmetatable({}, { __index = function(t2, k2)
		local item = { Name = k2, EnumType = k, Value = 0 }
		rawset(t2, k2, item); return item end })
	rawset(t, k, e); return e end })

-- ───── instances & services ─────
local Instance = { new = function(cn, parent) local i = newInstance(cn); if parent then i.Parent = parent end return i end }

local services = {}
local function svc(name, extra)
	local s = newInstance(name); s.Name = name
	for k, v in pairs(extra or {}) do rawset(s, k, v) end
	services[name] = s; return s
end
local Players = svc("Players")
local lp = newInstance("Player"); lp.Name = "Tester"; lp.UserId = 1
local pg = newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = lp
Players.LocalPlayer = lp
Players.PlayerAdded = Signal(); Players.PlayerRemoving = Signal()
function Players:GetPlayers() return { lp } end
local RS = svc("ReplicatedStorage")
local SS = svc("ServerStorage")
svc("TweenService", { Create = function(_, inst, _, props)
	return { Play = function() for k, v in pairs(props or {}) do pcall(function() inst[k] = v end) end end, Cancel = function() end,
		Completed = Signal(), Destroy = function() end } end })
svc("SoundService"); svc("Debris", { AddItem = function() end })
svc("RunService", { Heartbeat = Signal(), RenderStepped = Signal(), IsClient = function() return true end,
	IsServer = function() return false end, IsStudio = function() return true end })
svc("UserInputService", { InputBegan = Signal(), InputEnded = Signal(), InputChanged = Signal(), TouchMoved = Signal(), TouchEnded = Signal(), TouchEnabled = false,
	GetMouseLocation = function() return vec2(0,0) end })
svc("GuiService", { GetGuiInset = function() return vec2(0,36), vec2(0,0) end })
svc("HttpService", { GenerateGUID = function() return tostring(math.random(1e9)) end, JSONEncode = function() return "{}" end })
svc("DataStoreService"); svc("MessagingService"); svc("TextService"); svc("ContentProvider"); svc("Lighting")
svc("CollectionService"); svc("StarterGui", { SetCore = function() end }); svc("MarketplaceService")
svc("TeleportService"); svc("ServerScriptService"); svc("StarterPlayer")

local game = newInstance("DataModel"); game.Name = "game"
function game:GetService(n) return services[n] or svc(n) end
local workspace = newInstance("Workspace"); workspace.Name = "workspace"
workspace.CurrentCamera = newInstance("Camera"); workspace.CurrentCamera.ViewportSize = vec2(1280, 720)
rawset(workspace, "GetServerTimeNow", function() return (M.clock and M.clock()) or 0 end)
services.Workspace = workspace

-- ───── load repo tree into the fake DataModel ─────
local function readFile(p) local f = io.open(p, "r"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local function ls(dir) local p = io.popen('ls -1 "'..dir..'"'); local t = {}; for l in p:lines() do table.insert(t, l) end p:close(); return t end
local function isDir(p) local h = io.popen('[ -d "'..p..'" ] && echo y'); local r = h:read("*a"); h:close(); return r:find("y") ~= nil end

local sources = {}   -- instance -> {src=, path=}
local function mount(dir, parent)
	for _, name in ipairs(ls(dir)) do
		local full = dir.."/"..name
		if isDir(full) then
			local f = newInstance("Folder"); f.Name = name; f.Parent = parent; mount(full, f)
		elseif name:match("%.lua$") then
			local base = name:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
			local kind = name:match("%.server%.lua$") and "Script" or name:match("%.client%.lua$") and "LocalScript" or "ModuleScript"
			local m = newInstance(kind); m.Name = base; m.Parent = parent
			sources[m] = { src = readFile(full), path = full }
		end
	end
end
local function sub(root, name) local f = newInstance("Folder"); f.Name = name; f.Parent = root; return f end
if isDir(REPO.."/ReplicatedStorage") then mount(REPO.."/ReplicatedStorage", RS) end
if isDir(REPO.."/ServerStorage") then mount(REPO.."/ServerStorage", SS) end


-- ───── module loader ─────
local globalsBase = { game=game, workspace=workspace, Instance=Instance, Vector2=Vector2, Vector3=Vector3, UDim=UDim, UDim2=UDim2,
	Color3=Color3, ColorSequence=ColorSequence, NumberSequence=NumberSequence, NumberRange=NumberRange,
	ColorSequenceKeypoint=ColorSequenceKeypoint, NumberSequenceKeypoint=NumberSequenceKeypoint, TweenInfo=TweenInfo,
	Rect=Rect, Random=Random, CFrame=CFrame, Enum=Enum, typeof=function(v)
		if type(v) == "table" then
			if v.ClassName then return "Instance" end
			if v.Scale ~= nil and v.Offset ~= nil then return "UDim" end
			if v.R and v.G and v.B then return "Color3" end
			if v.X and v.Y and not v.Z and type(v.X) == "number" then return "Vector2" end
			if v.X and v.Y and type(v.X) == "table" then return "UDim2" end
			if v.Connect then return "RBXScriptSignal" end
		end
		return type(v) end,
	warn = function(...) M.warnings = M.warnings or {}; table.insert(M.warnings, table.concat({...}, " ")) end,
	tick = os.clock, time = os.clock, os = os, string = string, table = table, math = math, pairs = pairs, ipairs = ipairs,
	next = next, select = select, type = type, tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall,
	error = error, assert = assert, unpack = table.unpack, setmetatable = setmetatable, getmetatable = getmetatable,
	rawget = rawget, rawset = rawset, rawequal = rawequal, print = print, utf8 = utf8, coroutine = coroutine, bit32 = bit32,
	buffer = buffer, newproxy = newproxy, tostring = tostring,
}

-- cooperative scheduler: task.spawn runs until first yield; task.wait yields (virtual clock); pump() advances time
local queue, now = {}, 0
local function resume(co, ...)
	local ok, e = coroutine.resume(co, ...)
	if not ok then M.taskErrors = M.taskErrors or {}; table.insert(M.taskErrors, tostring(e)) end
end
local function spawnFn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...); return co
end
globalsBase.task = {
	wait = function(t)
		local co, ismain = coroutine.running()
		if ismain then return t or 0 end
		table.insert(queue, { at = now + (t or 0.03), co = co })
		coroutine.yield(); return t or 0.03 end,
	spawn = spawnFn,
	defer = function(f, ...) local a = {...}; local co = coroutine.create(f); table.insert(queue, { at = now, co = co, args = a }); return co end,
	delay = function(t, f, ...) local a = {...}; local co = coroutine.create(f); table.insert(queue, { at = now + (t or 0), co = co, args = a }); return co end,
	cancel = function(co) for i = #queue, 1, -1 do if queue[i].co == co then table.remove(queue, i) end end end,
}
globalsBase.wait = globalsBase.task.wait
globalsBase.spawn = globalsBase.task.spawn
function M.clock() return now end
function M.pump(dt, maxSteps)
	local target = now + (dt or 1); local steps = 0
	while steps < (maxSteps or 5000) do
		table.sort(queue, function(a, b) return a.at < b.at end)
		local nxt = queue[1]
		if not nxt or nxt.at > target then break end
		table.remove(queue, 1); now = math.max(now, nxt.at); steps += 1
		if coroutine.status(nxt.co) == "suspended" then resume(nxt.co, table.unpack(nxt.args or {})) end
	end
	now = target
end


local cache, loading = {}, {}
local function load(inst)
	if cache[inst] ~= nil then return cache[inst] end
	local info = sources[inst]; if not info then error("require: not a module: "..tostring(inst and inst.Name), 3) end
	if loading[inst] then error("cyclic require: "..inst.Name, 3) end
	loading[inst] = true
	local env = setmetatable({ script = inst, require = function(m) return load(m) end }, { __index = globalsBase })
	local fn, err = loadstring(info.src, "="..info.path)
	if not fn then loading[inst] = nil; error("SYNTAX "..info.path..": "..tostring(err), 0) end
	setfenv(fn, env)
	local ok, res = pcall(fn)
	loading[inst] = nil
	if not ok then error("LOAD "..info.path..": "..tostring(res), 0) end
	cache[inst] = res == nil and true or res
	return cache[inst]
end

local function resetCache() for k in pairs(cache) do cache[k] = nil end end
return { resetCache = resetCache, game = game, RS = RS, SS = SS, load = load, sources = sources, services = services, player = lp, M = M,
	Signal = Signal, newInstance = newInstance, globals = globalsBase, vec2 = vec2 }
