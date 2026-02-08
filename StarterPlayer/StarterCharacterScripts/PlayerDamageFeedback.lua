-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- Проверка запуска
local Player = Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local Head = Character:WaitForChild("Head")

-- == НАСТРОЙКИ ==
local HIT_SOUND_ID = "rbxassetid://566593606" 
local FLASH_COLOR = Color3.fromRGB(255, 74, 77) 
local DAMAGE_COLOR = Color3.fromRGB(255, 74, 77)

-- Подготовка звука
local SoundTemplate = Instance.new("Sound")
SoundTemplate.SoundId = HIT_SOUND_ID
SoundTemplate.Volume = 1 -- Сделал погромче
SoundTemplate.Parent = script

local LastHealth = Humanoid.Health

-- Основная функция эффекта
local function OnDamage(damageAmount)

	-- 1. ЗВУК
	local sfx = SoundTemplate:Clone()
	sfx.Pitch = math.random(9, 11) / 10
	sfx.Parent = Head
	sfx:Play()
	Debris:AddItem(sfx, 1)

	-- 2. ВСПЫШКА (HIGHLIGHT)
	-- Удаляем старую вспышку, если она еще есть
	local oldHighlight = Character:FindFirstChild("DamageFlash")
	if oldHighlight then oldHighlight:Destroy() end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlash"
	highlight.FillColor = FLASH_COLOR
	highlight.OutlineColor = FLASH_COLOR
	highlight.FillTransparency = 0.3 -- Сделал ярче (было 0.5)
	highlight.OutlineTransparency = 1
	highlight.Adornee = Character
	highlight.Parent = Character

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(highlight, tweenInfo, {FillTransparency = 1})
	tween:Play()
	Debris:AddItem(highlight, 0.3)

	-- 3. ЦИФРЫ
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(2, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(math.random(-2,2), 3, 0) -- Чуть выше и шире разброс
	billboard.Adornee = Head
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Parent = billboard
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damageAmount))
	label.TextColor3 = DAMAGE_COLOR
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0,0,0) -- Черная обводка
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true

	billboard.Parent = workspace -- Кидаем в мир, чтобы не тряслось вместе с головой

	-- Анимация
	local goalOffset = billboard.StudsOffset + Vector3.new(0, 3, 0)
	local tMove = TweenService:Create(billboard, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {StudsOffset = goalOffset})
	local tFade = TweenService:Create(label, TweenInfo.new(1), {TextTransparency = 1, TextStrokeTransparency = 1})

	tMove:Play()
	tFade:Play()
	Debris:AddItem(billboard, 1)
end

-- СЛУШАЕМ ЗДОРОВЬЕ
Humanoid.HealthChanged:Connect(function(newHealth)
	-- Если здоровье стало меньше, чем было секунду назад
	if newHealth < LastHealth then
		local dmg = LastHealth - newHealth
		-- Реагируем только на урон больше 0
		if dmg > 0 then
			OnDamage(dmg)
		end
	end
	LastHealth = newHealth
end)