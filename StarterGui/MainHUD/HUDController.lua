-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService") 

-- Отключаем стандартную полоску ХП
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- == ССЫЛКИ НА GUI ==
-- Скрипт лежит в MainHUD, поэтому script.Parent найдет нужные объекты
local gui = script.Parent

-- 1. Здоровье (Ищем HealthFrame, как на скрине)
local hpFrame = gui:WaitForChild("HealthFrame") 
local hpFill = hpFrame:WaitForChild("Fill") 
-- Если внутри HealthFrame нет текста, строку ниже можно удалить
local hpText = hpFrame:FindFirstChild("HealthText") 

-- 2. Опыт (Ищем XPBar, как на скрине)
local xpBar = gui:WaitForChild("XPBar") 
local xpFill = xpBar:WaitForChild("Fill")
-- Если внутри XPBar нет текста, строку ниже можно удалить
local levelText = xpBar:FindFirstChild("LevelText") 

-- 3. ТАЙМЕР (ИСПРАВЛЕНО ИМЯ!)
-- На скрине он называется TimerLabel, а не TimerText
local timerLabel = gui:WaitForChild("TimerLabel") 
local timeLeftValue = ReplicatedStorage:WaitForChild("TimeLeft")

-- 4. УБИЙСТВА (Если нужно обновлять KillsLabel)
local killsLabel = gui:FindFirstChild("KillsLabel")

-- ===========================
--        ФУНКЦИИ
-- ===========================

-- 1. Форматирование времени (10:00)
local function formatTime(seconds)
	local min = math.floor(seconds / 60)
	local sec = seconds % 60
	return string.format("%02d:%02d", min, sec)
end

-- 2. Обновление Таймера
local function updateTimer()
	if timerLabel then
		timerLabel.Text = formatTime(timeLeftValue.Value)
	end
end

-- 3. Обновление Здоровья
local function updateHealth()
	local percent = humanoid.Health / humanoid.MaxHealth
	hpFill:TweenSize(UDim2.new(percent, 0, 1, 0), "Out", "Quad", 0.3, true)

	if hpText then
		hpText.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	end
end

-- 4. Обновление Опыта и Киллов
local function updateStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local xpValue = player:FindFirstChild("XP")

	if leaderstats and xpValue then
		local levelValue = leaderstats:FindFirstChild("Level")
		local killsValue = leaderstats:FindFirstChild("Kills")

		-- Обновляем Опыт
		if levelValue then
			local currentLevel = levelValue.Value
			local currentXP = xpValue.Value
			local maxXP = 10 + (currentLevel * 5) -- Формула сервера

			if maxXP <= 0 then maxXP = 10 end
			local percent = math.clamp(currentXP / maxXP, 0, 1)

			xpFill:TweenSize(UDim2.new(percent, 0, 1, 0), "Out", "Quad", 0.5, true)

			if levelText then
				levelText.Text = "Lvl " .. currentLevel
			end
		end

		-- Обновляем Киллы (раз у нас есть KillsLabel)
		if killsLabel and killsValue then
			killsLabel.Text = "Kills: " .. killsValue.Value
		end
	end
end

-- ===========================
--      ПОДКЛЮЧЕНИЕ СОБЫТИЙ
-- ===========================

-- Подключаем Таймер
timeLeftValue.Changed:Connect(updateTimer)
updateTimer() 

-- Подключаем Здоровье
humanoid.HealthChanged:Connect(updateHealth)
updateHealth()

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth()
end)

-- Подключаем Статистику (XP, Level, Kills)
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local xpValue = player:WaitForChild("XP", 10)

	if leaderstats and xpValue then
		local levelValue = leaderstats:WaitForChild("Level")
		local killsValue = leaderstats:WaitForChild("Kills")

		xpValue.Changed:Connect(updateStats)
		levelValue.Changed:Connect(updateStats)
		if killsValue then killsValue.Changed:Connect(updateStats) end

		updateStats()
	end
end)