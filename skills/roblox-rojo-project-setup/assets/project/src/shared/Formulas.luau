--!strict
-- Starter pure module: no `game`, no services, no engine types. It requires its siblings by string
-- path, so the same file loads in Roblox and under Lune. Replace it with the project's real logic.

local GameConfig = require("./Config/GameConfig")

local Formulas = {}

function Formulas.reward(level: number): number
	return GameConfig.BaseReward * (1 + GameConfig.BonusPerLevel * level)
end

return Formulas
