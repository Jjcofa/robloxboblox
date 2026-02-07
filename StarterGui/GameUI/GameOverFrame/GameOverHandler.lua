-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gameOverFrame = script.Parent -- Экран смерти
local statsLabel = gameOverFrame:WaitForChild("StatsLabel")
local restartBtn = gameOverFrame:WaitForChild("RestartBtn")

-- ИЩЕМ ГЛАВНОЕ МЕНЮ (Оно находится рядом с GameOverFrame, в GameUI)
-- Структура: GameUI -> GameOverFrame (мы тут) -> Parent (GameUI) -> Frame (Главное Меню)
local mainMenuFrame = gameOverFrame.Parent:FindFirstChild("Frame") 

-- Ссылки на события
local gameOverEvent = ReplicatedStorage.Events:WaitForChild("GameOverEvent")
local restartEvent = ReplicatedStorage.Events:WaitForChild("RestartGameEvent")

-- 1. ПОКАЗАТЬ ЭКРАН СМЕРТИ
gameOverEvent.OnClientEvent:Connect(function(finalKills, finalLevel)
	statsLabel.Text = "Kills: " .. finalKills .. " | Level: " .. finalLevel

	gameOverFrame.Visible = true
	gameOverFrame.BackgroundTransparency = 1
	local tween = TweenService:Create(gameOverFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0.3})
	tween:Play()
end)

-- 2. КНОПКА "TRY AGAIN"
restartBtn.MouseButton1Click:Connect(function()
	-- Скрываем экран смерти
	gameOverFrame.Visible = false

	-- Показываем главное меню выбора оружия
	if mainMenuFrame then
		mainMenuFrame.Visible = true
	end

	-- Говорим серверу: "Воскреси меня и почисти карту"
	restartEvent:FireServer()
end)