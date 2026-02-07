-- @ScriptType: Script
local Players = game:GetService("Players") 
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
		local upTween = TweenService:Create(apple, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Vector3.new(apple.Position.X, initialY + 0.5, apple.Position.Z)})
		upTween:Play()
		upTween.Completed:Wait()

		if isPickedUp then break end

		local downTween = TweenService:Create(apple, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = Vector3.new(apple.Position.X, initialY, apple.Position.Z)})
		downTween:Play()
		downTween.Completed:Wait()
	end
end)

-- == ПОДБОР ПРЕДМЕТА ==
apple.Touched:Connect(function(hit)
	if isPickedUp then return end 

	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)

	if not player then return end

	local humanoid = character:FindFirstChild("Humanoid")

	if humanoid and humanoid.Health > 0 then
		if humanoid.Health >= humanoid.MaxHealth then return end

		isPickedUp = true

		-- Лечим
		humanoid.Health = math.min(humanoid.Health + HEAL_AMOUNT, humanoid.MaxHealth)

		-- === НОВОЕ: ВЫЛЕТАЮЩИЙ ТЕКСТ ЛЕЧЕНИЯ ===
		local head = character:FindFirstChild("Head") or character.PrimaryPart
		if head then
			local bgui = Instance.new("BillboardGui")
			bgui.Name = "HealGui"
			bgui.Size = UDim2.new(0, 100, 0, 50)
			bgui.Adornee = head
			bgui.StudsOffset = Vector3.new(0, 2, 0)
			bgui.AlwaysOnTop = true

			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.Text = "+" .. HEAL_AMOUNT .. " HP"
			lbl.TextColor3 = Color3.fromRGB(0, 255, 100) -- Ярко-зеленый
			lbl.TextTransparency = 0
			lbl.TextStrokeTransparency = 0.5 -- Контур для четкости
			lbl.TextScaled = true
			lbl.Font = Enum.Font.LuckiestGuy
			lbl.Parent = bgui

			-- Важно: родителем ставим голову или персонажа, 
			-- чтобы надпись жила, даже когда яблоко удалится через Debris
			bgui.Parent = head 

			local displayTime = 1.2
			TweenService:Create(bgui, TweenInfo.new(displayTime), {StudsOffset = Vector3.new(0, 6, 0)}):Play()
			TweenService:Create(lbl, TweenInfo.new(displayTime), {TextTransparency = 1}):Play()
			Debris:AddItem(bgui, displayTime)
		end
		-- =======================================

		-- Звук
		if pickupSound then
			pickupSound:Play()
		end

		-- Скрываем и удаляем
		spinTween:Cancel()
		apple.Transparency = 1
		apple.CanTouch = false -- Чтобы не сработало дважды за секунду

		for _, child in pairs(apple:GetChildren()) do
			if child:IsA("Light") or child:IsA("ParticleEmitter") or child:IsA("BillboardGui") then
				-- Не трогаем наш новый HealGui, отключаем только старые эффекты яблока
				if child.Name ~= "HealGui" then
					child.Enabled = false
				end
			end
		end

		Debris:AddItem(apple, 1)
	end
end)