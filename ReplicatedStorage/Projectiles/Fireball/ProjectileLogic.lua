-- @ScriptType: Script
local fireball = script.Parent
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- == НОВОЕ: ЧИТАЕМ СТАТЫ ИЗ АТРИБУТОВ ==
-- Если атрибута нет (баг), берем запасное значение (35 или 10)
local SPEED = fireball:GetAttribute("Speed") or 35
local DAMAGE = fireball:GetAttribute("Damage") or 10
local LIFETIME = 5

Debris:AddItem(fireball, LIFETIME)

local targetValue = fireball:WaitForChild("Target")
local isHit = false 

-- Пытаемся найти главную часть
local primary = fireball.PrimaryPart or fireball:FindFirstChild("Sphere") or fireball:FindFirstChildWhichIsA("BasePart")

-- ЗВУКИ
local launchSound = fireball:FindFirstChild("LaunchSound") 
if not launchSound and primary then launchSound = primary:FindFirstChild("LaunchSound") end
local hitSound = fireball:FindFirstChild("HitSound")
if not hitSound and primary then hitSound = primary:FindFirstChild("HitSound") end

if launchSound then launchSound:Play() end

-- Отключаем физику
for _, part in pairs(fireball:GetDescendants()) do
	if part:IsA("BasePart") then part.CanCollide = false end
end

RunService.Heartbeat:Connect(function(dt)
	if isHit then return end
	if not primary then return end 

	local targetPart = targetValue.Value 

	if targetPart and targetPart.Parent then
		local enemyModel = targetPart.Parent
		local humanoid = enemyModel:FindFirstChild("Humanoid")

		if humanoid and humanoid.Health > 0 then
			local targetPos = targetPart.Position
			local currentCF = fireball:GetPivot()

			-- Летим (используя SPEED из атрибута)
			local lookAt = CFrame.lookAt(currentCF.Position, targetPos)
			fireball:PivotTo(lookAt + (lookAt.LookVector * SPEED * dt))

			-- Проверка попадания
			if (targetPos - currentCF.Position).Magnitude < 4 then
				-- Наносим урон (используя DAMAGE из атрибута)
				humanoid:TakeDamage(DAMAGE)
				isHit = true 

				if hitSound then hitSound:Play() end

				-- Эффект исчезновения
				for _, p in pairs(fireball:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true end
				end
				for _, child in pairs(fireball:GetDescendants()) do
					if child:IsA("BasePart") then child.Transparency = 1 
					elseif child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("BillboardGui") then
						child.Enabled = false
					end
				end
				Debris:AddItem(fireball, 1.5) 
			end
		else
			local currentCF = fireball:GetPivot()
			fireball:PivotTo(currentCF * CFrame.new(0, 0, -SPEED * dt))
		end
	else
		local currentCF = fireball:GetPivot()
		fireball:PivotTo(currentCF * CFrame.new(0, 0, -SPEED * dt))
	end
end)