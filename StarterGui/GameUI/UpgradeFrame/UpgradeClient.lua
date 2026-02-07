-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- == ССЫЛКИ НА ОБЪЕКТЫ ==
local frame = script.Parent -- Сам UpgradeFrame
-- ВАЖНО: Убедись, что твои кнопки называются именно так!
local btn1 = frame:WaitForChild("Option1Btn") 
local btn2 = frame:WaitForChild("Option2Btn")

-- == СОБЫТИЯ ==
local showEvent = ReplicatedStorage.Events:WaitForChild("ShowUpgradeEvent")
local selectEvent = ReplicatedStorage.Events:WaitForChild("SelectUpgradeEvent")

-- == ЛОГИКА ==

-- 1. Сервер говорит: "Покажи меню с вот этими вариантами"
showEvent.OnClientEvent:Connect(function(options)
	-- options — это таблица с двумя улучшениями, которую мы прислали из GameManager

	-- Делаем окно видимым
	frame.Visible = true

	-- Обновляем текст на кнопках
	-- options[1] — первое улучшение, options[2] — второе

	-- Если у тебя на кнопках просто текст:
	btn1.Text = "<b>" .. options[1].name .. "</b>\n" .. options[1].desc
	btn2.Text = "<b>" .. options[2].name .. "</b>\n" .. options[2].desc

	-- (Если у тебя внутри кнопок есть отдельные лейблы Title и Desc, 
	-- то пиши btn1.Title.Text = ... и т.д.)
end)

-- 2. Ты нажимаешь на ПЕРВУЮ кнопку
btn1.MouseButton1Click:Connect(function()
	if not frame.Visible then return end -- Защита от случайных кликов

	frame.Visible = false -- Прячем меню
	selectEvent:FireServer(1) -- Говорим серверу: "Я выбрал номер 1"
end)

-- 3. Ты нажимаешь на ВТОРУЮ кнопку
btn2.MouseButton1Click:Connect(function()
	if not frame.Visible then return end

	frame.Visible = false -- Прячем меню
	selectEvent:FireServer(2) -- Говорим серверу: "Я выбрал номер 2"
end)
