import os, sys, re
REPO = "../roblox-repo"
mock = open("mock.lua").read().replace("local ROOT = ...", "")
env = open("env.lua").read()

# collect sources
files = {}
for dp, dn, fn in os.walk(REPO):
    if ".git" in dp: continue
    for f in fn:
        if f.endswith(".lua"):
            p = os.path.join(dp, f)
            files[os.path.relpath(p, REPO).replace("\\", "/")] = open(p, encoding="utf-8").read()

def lq(s):
    # safe Luau long string with level that can't collide
    lvl = 0
    while ("]" + "=" * lvl + "]") in s: lvl += 1
    return "[" + "=" * lvl + "[\n" + s + "]" + "=" * lvl + "]"

emb = "local SOURCES = {}\n" + "".join(f'SOURCES["{k}"] = {lq(v)}\n' for k, v in sorted(files.items()))

# patch env.lua: replace io-based mounting with SOURCES-based
env = env.replace('local M = require("./mock")', 'local M = MOCK')
env = env.replace("local REPO = _G_REPO", "")
mount_start = env.index("local function readFile")
mount_end = env.index("-- ───── module loader")
new_mount = '''
local sources = {}
local function mountTree(rootName, parent)
	for path, src in pairs(SOURCES) do
		local rel = path:match("^"..rootName.."/(.+)$")
		if rel then
			local cur = parent
			local parts = {}
			for p in rel:gmatch("[^/]+") do table.insert(parts, p) end
			for i = 1, #parts - 1 do
				local nxt = cur:FindFirstChild(parts[i])
				if not nxt then nxt = newInstance("Folder"); nxt.Name = parts[i]; nxt.Parent = cur end
				cur = nxt
			end
			local name = parts[#parts]
			local base = name:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
			local kind = name:match("%.server%.lua$") and "Script" or name:match("%.client%.lua$") and "LocalScript" or "ModuleScript"
			local m = newInstance(kind); m.Name = base; m.Parent = cur
			sources[m] = { src = src, path = path }
		end
	end
end
mountTree("ReplicatedStorage", RS)
mountTree("ServerStorage", SS)
mountTree("StarterPlayer/StarterPlayerScripts", game:GetService("StarterPlayer"))
mountTree("ServerScriptService", game:GetService("ServerScriptService"))
'''
env = env[:mount_start] + new_mount + open('remotes_block.lua').read() + env[mount_end:]
env = env.replace("local info = sources[inst]; if not info", "local info = sources[inst]; if not info")
env = env.replace("local fn, err = loadstring(info.src, \"=\"..info.path)", "local fn, err = loadstring(info.src, \"=\"..info.path)")

tests = open(sys.argv[1]).read() if len(sys.argv) > 1 else ""
out = emb + "\nlocal MOCK = (function()\n" + mock + "\nend)()\nlocal H = (function()\n" + env + "\nend)()\n" + tests
open("bundle.lua", "w", encoding="utf-8").write(out)
print("bundle bytes:", len(out), "files:", len(files))
