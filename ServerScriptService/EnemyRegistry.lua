-- @ScriptType: ModuleScript
local EnemyRegistry = {}

local validEnemies = {
	["Enemy"] = true,
	["EnemyBlack"] = true, -- <--- Обязательно добавь это!
	["BossZombie"] = true
}

function EnemyRegistry.IsEnemy(object)
	return validEnemies[object.Name] or false
end

return EnemyRegistry