-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local UpgradeDB = {}

-- Веса (шансы): Обычное = 100, Редкое = 30

UpgradeDB.Upgrades = {
	["Sword"] = {
		{
			id = "Sword_Dmg",
			name = "Заточка",
			desc = "+2 Урона",
			stats = {damage = 2},
			weight = 100
		},
		{
			id = "Sword_Range",
			name = "Длинная рукоять",
			desc = "+1 к Радиусу атаки",
			stats = {range = 1},
			weight = 100
		},
		{
			id = "Sword_CD",
			name = "Легкий сплав",
			desc = "-0.3 сек перезарядки",
			stats = {cooldown = -0.3},
			weight = 100
		},
		{
			id = "Sword_Rare",
			name = "ЭКСКАЛИБУР",
			desc = "[РЕДКОЕ] +3 Урона, -0.2 Перезарядки",
			stats = {damage = 3, cooldown = -0.2},
			weight = 30
		}
	},

	["Fireball"] = {
		{
			id = "Fire_Speed",
			name = "Аэродинамика",
			desc = "+5 к Скорости полета",
			stats = {speed = 5},
			weight = 100
		},
		{
			id = "Fire_Dmg",
			name = "Адское пламя",
			desc = "+5 Урона",
			stats = {damage = 5},
			weight = 100
		},
		{
			id = "Fire_CD",
			name = "Быстрая магия",
			desc = "-0.2 сек перезарядки",
			stats = {cooldown = -0.2},
			weight = 100
		},
		{
			id = "Fire_Rare",
			name = "МЕТЕОРИТ",
			desc = "[РЕДКОЕ] +4 Урона, +4 Скорости",
			stats = {damage = 4, speed = 4},
			weight = 30
		}
	},

	["Bomb"] = {
		{
			id = "Bomb_Dmg",
			name = "Больше пороха",
			desc = "+5 Урона",
			stats = {damage = 5},
			weight = 100
		},
		{
			id = "Bomb_CD",
			name = "Короткий фитиль",
			desc = "-0.2 сек перезарядки",
			stats = {cooldown = -0.2},
			weight = 100
		},
		{
			id = "Bomb_Crit",
			name = "Осколки",
			desc = "+5% Шанс крита",
			stats = {critChance = 5},
			weight = 100
		},
		{
			id = "Bomb_Rare",
			name = "АТОМНАЯ БОМБА",
			desc = "[РЕДКОЕ] +5 Урона, +5 Крит. шанс",
			stats = {damage = 5, critChance = 5},
			weight = 30
		}
	}
}

-- Функция выбора 2 случайных улучшений
function UpgradeDB.getRandomUpgrades(weaponName)
	local pool = UpgradeDB.Upgrades[weaponName]

	-- Защита от ошибки: если для оружия нет улучшений, возвращаем пустышки, чтобы не крашнуло
	if not pool then 
		warn("UpgradeDB: Нет улучшений для оружия " .. tostring(weaponName))
		return {
			{name = "Ошибка", desc = "Нет данных", stats = {}},
			{name = "Ошибка", desc = "Нет данных", stats = {}}
		}
	end

	local lottery = {}
	for _, upg in pairs(pool) do
		for i = 1, upg.weight do
			table.insert(lottery, upg)
		end
	end

	local option1 = lottery[math.random(1, #lottery)]
	local option2 = nil

	repeat
		option2 = lottery[math.random(1, #lottery)]
	until option2.id ~= option1.id

	return {option1, option2}
end

return UpgradeDB