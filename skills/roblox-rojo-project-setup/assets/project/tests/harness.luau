--!strict
-- Minimal test harness for specs run under Lune (`lune run test`).

type Case = { name: string, fn: () -> () }
type Suite = { name: string, cases: { Case } }

local harness = {}

local suites: { Suite } = {}
local current: Suite? = nil

local function repr(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, key in keys do
			table.insert(parts, tostring(key) .. " = " .. repr(value[key]))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function harness.describe(name: string, body: () -> ())
	local suite: Suite = { name = name, cases = {} }
	table.insert(suites, suite)
	current = suite
	body()
	current = nil
end

function harness.it(name: string, fn: () -> ())
	assert(current, "it() must be called inside describe()")
	table.insert(current.cases, { name = name, fn = fn })
end

local expect = {}

function expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		local prefix = if label then label .. ": " else ""
		error(prefix .. "expected " .. repr(expected) .. ", got " .. repr(actual), 2)
	end
end

function expect.deepEqual(actual: any, expected: any, label: string?)
	if not deepEqual(actual, expected) then
		local prefix = if label then label .. ": " else ""
		error(prefix .. "expected " .. repr(expected) .. ", got " .. repr(actual), 2)
	end
end

function expect.near(actual: number, expected: number, epsilon: number?, label: string?)
	if math.abs(actual - expected) > (epsilon or 1e-6) then
		local prefix = if label then label .. ": " else ""
		error(prefix .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function expect.truthy(value: any, label: string?)
	if not value then
		error((label or "value") .. ": expected truthy, got " .. repr(value), 2)
	end
end

function expect.falsy(value: any, label: string?)
	if value then
		error((label or "value") .. ": expected falsy, got " .. repr(value), 2)
	end
end

harness.expect = expect

-- Runs every registered suite. Returns (passed, failed).
function harness.run(): (number, number)
	local passed, failed = 0, 0
	for _, suite in suites do
		for _, case in suite.cases do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
			else
				failed += 1
				print(
					string.format("FAIL  %s > %s\n      %s", suite.name, case.name, tostring(err))
				)
			end
		end
	end
	return passed, failed
end

return harness
