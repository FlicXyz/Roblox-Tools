--!strict
-- Runs every automated check: type analysis, lint, formatting, unit tests.
-- Usage: lune run check

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local PROJECT_FILE = "default.project.json"
local TYPES_PATH = ".cache/globalTypes.d.luau"
local TYPES_URL =
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local function step(label: string, program: string, params: { string }): boolean
	print("\n== " .. label)
	local result = process.exec(program, params, { stdio = "inherit" })
	if not result.ok then
		print("-- " .. label .. " FAILED (exit " .. tostring(result.code) .. ")")
	end
	return result.ok
end

if not fs.isFile(TYPES_PATH) then
	print("Downloading Roblox type definitions...")
	local response = net.request(TYPES_URL)
	assert(response.ok, "could not download " .. TYPES_URL)
	if not fs.isDir(".cache") then
		fs.writeDir(".cache")
	end
	fs.writeFile(TYPES_PATH, response.body)
end

local results = {
	step("sourcemap", "rojo", { "sourcemap", PROJECT_FILE, "--output", "sourcemap.json" }),
	step("types (luau-lsp)", "luau-lsp", {
		"analyze",
		"--platform=roblox",
		"--sourcemap=sourcemap.json",
		"--definitions=" .. TYPES_PATH,
		"--base-luaurc=.luaurc",
		"src",
	}),
	step("lint (selene)", "selene", { "src" }),
	step("format (stylua)", "stylua", { "--check", "src", "tests", ".lune" }),
	step("unit tests", "lune", { "run", "test" }),
}

local failed = 0
for _, ok in results do
	if not ok then
		failed += 1
	end
end

print(
	if failed == 0 then "\nAll checks passed." else string.format("\n%d check(s) failed.", failed)
)
process.exit(if failed == 0 then 0 else 1)
