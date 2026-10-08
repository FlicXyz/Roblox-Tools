--!strict
-- Engine-bound code requires by instance and is verified by a play test, not by the unit tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)

print("[Server] started; reward at level 1 =", Formulas.reward(1))
