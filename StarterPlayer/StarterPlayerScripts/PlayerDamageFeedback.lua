-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Head = Character:WaitForChild("Head")

-- == НАСТРОЙКИ ==
local HIT_SOUND_ID = "rbxassetid://566593606" 
local FLASH_COLOR = Color3.fromRGB(255, 74, 77) -- Красный 
local DAMAGE_COLOR = Color3.fromRGB(255, 74, 77)

-- == 1. ПОДГОТОВКА ЗВУКА ЗАРАНЕЕ ==
-- Мы создаем "Шаблон" звука один раз при старте, чтобы не грузить его каждый раз
local SoundTemplate = Instance.new("Sound")
SoundTemplate.SoundId = HIT_SOUND_ID
SoundTemplate.Volume = 0.5
SoundTemplate.Parent = script -- Храним в скрипте пока что

-- Если звук в самом файле имеет тишину в начале, можно начать воспроизведение чуть дальше
-- SoundTemplate.TimePosition = 0.05 -- Раскомментируй, если звук всё равно отстает (обрежет начало)

local LastHealth = Humanoid.Health

-- Функция создания эффектов
local function OnDamage(damageAmount)
	-- А. МГНОВЕННЫЙ ЗВУК
	local sfx = SoundTemplate:Clone()
	sfx.Pitch = math.random(9, 11) / 10 -- Вариация тона
	sfx.Parent = Head
	sfx:Play()
	Debris:AddItem(sfx, 1)

	-- Б. ПОКРАСНЕНИЕ (Highlight)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlash"
	highlight.FillColor = FLASH_COLOR
	highlight.OutlineColor = FLASH_COLOR
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 1 -- Контур уберем, оставим только заливку (так мягче)
	highlight.Adornee = Character
	highlight.Parent = Character

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(highlight, tweenInfo, {FillTransparency = 1})
	tween:Play()
	Debris:AddItem(highlight, 0.3)

	-- В. ЦИФРЫ
	-- Создаем BillboardGui локально (видит только сам игрок)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(2, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(math.random(-10,10)/10, 2.5, 0)
	billboard.Adornee = Head
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Parent = billboard
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damageAmount))
	label.TextColor3 = DAMAGE_COLOR
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true

	billboard.Parent = workspace -- В локальном workspace (видит только игрок)

	-- Анимация подлета и исчезновения
	local goalOffset = billboard.StudsOffset + Vector3.new(0, 2, 0)
	local tMove = TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {StudsOffset = goalOffset})
	local tFade = TweenService:Create(label, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1})

	tMove:Play()
	tFade:Play()
	Debris:AddItem(billboard, 0.8)
end

-- СЛУШАЕМ ЗДОРОВЬЕ
Humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < LastHealth then
		local dmg = LastHealth - newHealth
		if dmg >= 1 then
			OnDamage(dmg)
		end
	end
	LastHealth = newHealth
end)