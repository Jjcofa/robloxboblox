-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("Frame") -- Наше меню

-- Ищем ТРИ кнопки по их именам
local fireballBtn = frame:WaitForChild("FireballBtn")
local swordBtn = frame:WaitForChild("SwordBtn")
local bombBtn = frame:WaitForChild("BombBtn") -- [НОВОЕ] Ищем кнопку бомбы

local startGameEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("StartGameEvent")

-- Заморозка игрока при входе
local controls = require(player.PlayerScripts.PlayerModule):GetControls()
controls:Disable() 

-- Общая функция для старта игры
local function startGame(weaponName)
	print("Выбрано оружие: " .. weaponName)

	-- Отправляем серверу выбор
	startGameEvent:FireServer(weaponName)

	-- Скрываем меню и возвращаем управление
	frame.Visible = false
	controls:Enable()
end

-- == ПОДКЛЮЧАЕМ КНОПКИ ==

-- Если нажали на Fireball
fireballBtn.MouseButton1Click:Connect(function()
	startGame("Fireball")
end)

-- Если нажали на Sword
swordBtn.MouseButton1Click:Connect(function()
	startGame("Sword")
end)

-- [НОВОЕ] Если нажали на Bomb
bombBtn.MouseButton1Click:Connect(function()
	startGame("Bomb") -- Отправляем серверу слово "Bomb", и GameManager выдаст нам её
end)