--!strict
-- Runs the unit tests in tests/*.spec.luau.
-- Usage: lune run test            (all specs)
--        lune run test Formulas   (specs whose file name contains "Formulas")

local fs = require("@lune/fs")
local process = require("@lune/process")

local harness = require("../tests/harness")

local filter = process.args[1]

local files = {}
for _, name in fs.readDir("tests") do
	if
		string.match(name, "%.spec%.luau$") and (not filter or string.find(name, filter, 1, true))
	then
		table.insert(files, name)
	end
end
table.sort(files)

-- No spec files is a failure, not a pass: "0 failed" must mean tests ran.
if #files == 0 then
	print("FAIL  no spec files found in tests/" .. (if filter then " matching " .. filter else ""))
	process.exit(1)
end

local loadFailures = 0
for _, name in files do
	local path = "../tests/" .. string.gsub(name, "%.luau$", "")
	local ok, err = pcall(function()
		return (require :: any)(path)
	end)
	if not ok then
		loadFailures += 1
		print(string.format("FAIL  %s could not load\n      %s", name, tostring(err)))
	end
end

local passed, failed = harness.run()
failed += loadFailures

print(string.format("\n%d passed, %d failed (%d spec files)", passed, failed, #files))
process.exit(if failed > 0 then 1 else 0)
