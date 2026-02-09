-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local events = ReplicatedStorage:WaitForChild("Events")
local notificationEvent = events:WaitForChild("NotificationEvent")

local gui = script.Parent
local waveLabel = gui:WaitForChild("WaveLabel")

-- Создаем UIScale для зума, если его нет
local uiScale = waveLabel:FindFirstChild("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = waveLabel
end

local ALARM_SOUND_ID = "rbxassetid://119324582891677"
local pulseConnection = nil 

notificationEvent.OnClientEvent:Connect(function(text, color)
	-- Если прошлая анимация еще идет, сбрасываем её
	if pulseConnection then pulseConnection:Disconnect() pulseConnection = nil end

	-- 1. СНАЧАЛА ЗВУК (ГРОМКОСТЬ 0.5 - ТИХО)
	local sound = Instance.new("Sound")
	sound.SoundId = ALARM_SOUND_ID
	sound.Volume = 0.5 
	sound.Parent = gui
	sound:Play()
	Debris:AddItem(sound, 10)

	-- 2. ЖДЕМ 1 СЕКУНДУ (Текста еще нет, только звук)
	task.wait(1)

	-- 3. ПОДГОТОВКА ТЕКСТА
	waveLabel.Visible = true
	waveLabel.Text = text
	waveLabel.TextColor3 = color or Color3.fromRGB(255, 50, 50)
	waveLabel.TextTransparency = 0 

	-- Центрируем
	waveLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	waveLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
	waveLabel.Size = UDim2.new(0.8, 0, 0.1, 0)

	-- Старт с нуля (текст невидимый из-за масштаба)
	uiScale.Scale = 0 

	-- 4. ЭФФЕКТ ПОЯВЛЕНИЯ (Pop-Up)	-- Текст вырастает из 0 до 1
	local popInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local popTween = TweenService:Create(uiScale, popInfo, {Scale = 1})
	popTween:Play()

	-- Ждем, пока он вырастет
	task.wait(0.5)

	-- 5. ПЛАВНАЯ ПУЛЬСАЦИЯ
	local startTime = os.clock()

	pulseConnection = RunService.RenderStepped:Connect(function()
		-- Мягкая волна синуса для дыхания
		local alpha = math.sin((os.clock() - startTime) * 3)
		-- Меняем масштаб совсем чуть-чуть (от 1.0 до 1.05), чтобы было плавно
		local scale = 1 + (alpha * 0.05) 
		uiScale.Scale = scale
	end)

	-- 6. ТЕКСТ ВИСИТ 5 СЕКУНД
	task.wait(4)

	-- 7. УБИРАЕМ
	if pulseConnection then 
		pulseConnection:Disconnect() 
		pulseConnection = nil 
	end

	-- Плавное исчезновение
	local shrinkTween = TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0})
	shrinkTween:Play()

	shrinkTween.Completed:Wait()
	waveLabel.Visible = false
	uiScale.Scale = 1
end)