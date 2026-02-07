-- @ScriptType: Script
local fireball = script.Parent
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- Ждем загрузки атрибутов и основных частей
local SPEED = fireball:GetAttribute("Speed") or 35
local DAMAGE = fireball:GetAttribute("Damage") or 10
local CRIT_CHANCE = fireball:GetAttribute("CritChance") or 5
local CRIT_MULT = fireball:GetAttribute("CritMultiplier") or 2
local LIFETIME = 5

-- Безопасный поиск главной части (ждем до 5 секунд)
local primary = fireball:WaitForChild("Sphere", 5) or fireball.PrimaryPart or fireball:FindFirstChildWhichIsA("BasePart")

Debris:AddItem(fireball, LIFETIME)

local targetValue = fireball:WaitForChild("Target", 5)
local isHit = false 

if not primary then 
	warn("ProjectileLogic: Главная часть фаербола не найдена!")
	return 
end

-- ЗВУКИ
local launchSound = fireball:FindFirstChild("LaunchSound") or primary:FindFirstChild("LaunchSound")
local hitSound = fireball:FindFirstChild("HitSound") or primary:FindFirstChild("HitSound")

if launchSound then launchSound:Play() end

-- Отключаем физику для всех частей
for _, part in pairs(fireball:GetDescendants()) do
	if part:IsA("BasePart") then part.CanCollide = false end
end

RunService.Heartbeat:Connect(function(dt)
	if isHit or not primary then return end 

	local targetPart = targetValue and targetValue.Value 

	if targetPart and targetPart.Parent then
		local enemyModel = targetPart.Parent
		local humanoid = enemyModel:FindFirstChild("Humanoid")

		if humanoid and humanoid.Health > 0 then
			local targetPos = targetPart.Position
			local currentCF = fireball:GetPivot()

			-- Плавный полет к цели
			local lookAt = CFrame.lookAt(currentCF.Position, targetPos)
			fireball:PivotTo(lookAt + (lookAt.LookVector * SPEED * dt))

			-- Проверка попадания (дистанция 4 студа)
			if (targetPos - currentCF.Position).Magnitude < 4 then
				isHit = true 

				-- РАСЧЕТ КРИТА
				local finalDamage = DAMAGE
				local isCrit = math.random(1, 100) <= CRIT_CHANCE
				if isCrit then
					finalDamage = DAMAGE * CRIT_MULT
				end

				humanoid:TakeDamage(finalDamage)

				-- === ВЫЛЕТАЮЩИЕ ЦИФРЫ (СОЧНЫЕ И ДОЛГИЕ) ===
				local head = enemyModel:FindFirstChild("Head") or enemyModel.PrimaryPart
				if head then
					local bgui = Instance.new("BillboardGui")
					bgui.Name = "DamageGui"
					bgui.Size = isCrit and UDim2.new(0, 160, 0, 80) or UDim2.new(0, 100, 0, 50)
					bgui.Adornee = head
					bgui.StudsOffset = Vector3.new(0, 2, 0)
					bgui.AlwaysOnTop = true

					local lbl = Instance.new("TextLabel")
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 1, 0)
					lbl.Text = isCrit and "CRIT! -"..math.floor(finalDamage) or "-"..math.floor(finalDamage)

					-- Цвета и прозрачность по твоему запросу
					lbl.TextColor3 = isCrit and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 85, 0)
					lbl.TextTransparency = isCrit and 0 or 0.1 -- Крит максимально четкий
					lbl.TextStrokeTransparency = 0.5 -- Контур
					lbl.TextScaled = true
					lbl.Font = Enum.Font.LuckiestGuy
					lbl.Parent = bgui
					bgui.Parent = enemyModel

					-- Увеличенное время жизни (1.2 сек)
					local displayTime = 1.2
					TweenService:Create(bgui, TweenInfo.new(displayTime), {StudsOffset = Vector3.new(0, 6, 0)}):Play()
					TweenService:Create(lbl, TweenInfo.new(displayTime), {TextTransparency = 1}):Play()
					Debris:AddItem(bgui, displayTime)
				end

				if hitSound then hitSound:Play() end

				-- Эффект исчезновения модели
				for _, p in pairs(fireball:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true p.Transparency = 1 end
					if p:IsA("ParticleEmitter") or p:IsA("PointLight") or p:IsA("Trail") then
						if p.Name ~= "DamageGui" then p.Enabled = false end
					end
				end
				Debris:AddItem(fireball, 1.5) 
			end
		else
			fireball:PivotTo(fireball:GetPivot() * CFrame.new(0, 0, -SPEED * dt))
		end
	else
		fireball:PivotTo(fireball:GetPivot() * CFrame.new(0, 0, -SPEED * dt))
	end
end)
