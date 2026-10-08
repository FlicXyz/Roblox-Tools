--!strict
local harness = require("./harness")
local Formulas = require("../src/shared/Formulas")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Formulas.reward", function()
	it("is the base reward at level 0", function()
		expect.equal(Formulas.reward(0), 10)
	end)

	it("adds half the base reward per level", function()
		expect.equal(Formulas.reward(2), 20)
	end)
end)
