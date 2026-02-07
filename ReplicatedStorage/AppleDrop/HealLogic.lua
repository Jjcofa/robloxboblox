-- @ScriptType: Script
local Players = game:GetService("Players") -- Служба игроков
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local apple = script.Parent

-- == НАСТРОЙКИ ==
local HEAL_AMOUNT = 30
local isPickedUp = false

local pickupSound = apple:FindFirstChild("PickupSound")

-- == АНИМАЦИЯ (КРУЧЕНИЕ И ПОКАЧИВАНИЕ) ==
local spinInfo = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local spinTween = TweenService:Create(apple, spinInfo, {Orientation = apple.Orientation + Vector3.new(0, 360, 0)})
spinTween:Play()

task.spawn(function()
	local initialY = apple.Position.Y
	while not isPickedUp and apple.Parent do
		-- Вверх
		local upTween = TweenService:Create(apple, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Vector3.new(apple.Position.X, initialY + 0.5, apple.Position.Z)})
		upTween:Play()
		upTween.Completed:Wait()

		if isPickedUp then break end

		-- Вниз
		local downTween = TweenService:Create(apple, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Vector3.new(apple.Position.X, initialY, apple.Position.Z)})
		downTween:Play()
		downTween.Completed:Wait()
	end
end)

-- == ПОДБОР ПРЕДМЕТА ==
apple.Touched:Connect(function(hit)
	if isPickedUp then return end 

	local character = hit.Parent

	-- !!! ГЛАВНАЯ ПРОВЕРКА !!!
	-- Проверяем, принадлежит ли этот персонаж реальному игроку
	local player = Players:GetPlayerFromCharacter(character)

	if not player then 
		-- Если это не игрок (значит это зомби или другой предмет), выходим
		return 
	end

	local humanoid = character:FindFirstChild("Humanoid")

	if humanoid and humanoid.Health > 0 then
		-- Не подбирать, если здоровье полное
		if humanoid.Health >= humanoid.MaxHealth then return end

		isPickedUp = true

		-- Лечим
		humanoid.Health = math.min(humanoid.Health + HEAL_AMOUNT, humanoid.MaxHealth)

		-- Звук
		if pickupSound then
			pickupSound:Play()
		end

		-- Скрываем и удаляем
		spinTween:Cancel()
		apple.Transparency = 1

		for _, child in pairs(apple:GetChildren()) do
			if child:IsA("Light") or child:IsA("ParticleEmitter") or child:IsA("BillboardGui") then
				child.Enabled = false
			end
		end

		Debris:AddItem(apple, 1)
	end
end)