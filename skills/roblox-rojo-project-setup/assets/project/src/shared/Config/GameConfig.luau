--!strict
-- Tunable values. Plain numbers, strings and tables only: the unit tests load this file outside
-- Roblox, where Vector3, Color3, Enum and `game` do not exist. Values that need engine types go in a
-- separate config module that only engine-bound code requires.

local GameConfig = {
	BaseReward = 10,
	BonusPerLevel = 0.5,
}

return GameConfig
