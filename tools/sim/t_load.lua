local names, byPath = {}, {}
for inst, info in pairs(H.sources) do if inst.ClassName == "ModuleScript" then byPath[info.path] = inst; table.insert(names, info.path) end end
table.sort(names)
local ok, fails = 0, {}
for _, p in ipairs(names) do
	local s, e = pcall(H.load, byPath[p])
	if s then ok += 1 else table.insert(fails, p .. "\n   " .. tostring(e)) end
end
print("LOAD PASS ok=" .. ok .. "/" .. #names)
for _, f in ipairs(fails) do print("FAIL " .. f) end
