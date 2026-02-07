-- @ScriptType: ModuleScript
local UpgradeDB = {}

-- Веса (шансы): Обычное = 100, Редкое = 30
-- Шанс редкого примерно 23%

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
			desc = "+1 к Радиусу атаки", -- Влияет на дистанцию удара (Attack Range)
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
			name = "ЛЕГЕНДАРНЫЙ МЕЧ",
			desc = "[РЕДКОЕ] +3 Урона, -0.2 Перезарядки",
			stats = {damage = 3, cooldown = -0.2},
			weight = 30 -- Редкое
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
			name = "ДРЕВНЯЯ МАГИЯ",
			desc = "[РЕДКОЕ] +4 Урона, +4 Скорости",
			stats = {damage = 4, speed = 4},
			weight = 30 -- Редкое
		}
	}
}

-- Функция выбора 2 случайных улучшений для конкретного оружия
function UpgradeDB.getRandomUpgrades(weaponName)
	local pool = UpgradeDB.Upgrades[weaponName]
	if not pool then return {} end

	-- Создаем лотерейный барабан с учетом веса
	local lottery = {}
	for _, upg in pairs(pool) do
		for i = 1, upg.weight do
			table.insert(lottery, upg)
		end
	end

	-- Выбираем первого победителя
	local option1 = lottery[math.random(1, #lottery)]
	local option2 = nil

	-- Выбираем второго (чтобы не совпадал с первым)
	repeat
		option2 = lottery[math.random(1, #lottery)]
	until option2.id ~= option1.id

	return {option1, option2}
end

return UpgradeDB