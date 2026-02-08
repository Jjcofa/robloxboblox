-- @ScriptType: ModuleScript
local WaveManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Ссылки на объекты
local enemyTemplate = ReplicatedStorage:WaitForChild("Enemy")
local appleTemplate = ReplicatedStorage:WaitForChild("AppleDrop")

-- == ИСПРАВЛЕНИЕ ТУТ ==
-- Мы теперь ищем уже готовое событие, которое ты создал руками
local notificationEvent = ReplicatedStorage.Events:WaitForChild("NotificationEvent")

-- Функция спавна одного зомби (КРУГОВОЙ СПАВН)
local function spawnSingleZombie(player, distanceRadius)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end

	local root = player.Character.HumanoidRootPart

	-- 1. Случайный угол (360 градусов)
	local angle = math.rad(math.random(1, 360))

	-- 2. Радиус с небольшим разбросом
	local radius = distanceRadius + math.random(-5, 5) 

	-- 3. Считаем позицию через Sin/Cos
	local offsetX = math.cos(angle) * radius
	local offsetZ = math.sin(angle) * radius

	local spawnPos = root.Position + Vector3.new(offsetX, 3, offsetZ)

	local newEnemy = enemyTemplate:Clone()
	newEnemy.Parent = workspace
	-- Разворачиваем лицом к игроку
	newEnemy:PivotTo(CFrame.new(spawnPos, root.Position))
	newEnemy:SetAttribute("TargetPlayer", player.Name)

	local hum = newEnemy:FindFirstChild("Humanoid")
	if hum then
		hum.Died:Connect(function()
			if player:FindFirstChild("leaderstats") then
				player.leaderstats.Kills.Value += 1
			end

			if math.random(1, 100) <= 5 and appleTemplate then
				local drop = appleTemplate:Clone()
				drop.CFrame = newEnemy.HumanoidRootPart.CFrame 
				drop.Parent = workspace
				Debris:AddItem(drop, 180)
			end
			task.wait(1)
			if newEnemy then newEnemy:Destroy() end
		end)
	end
end

-- == ГЛАВНАЯ ФУНКЦИЯ ==
function WaveManager.triggerBigWave(player, count, duration)
	-- Отправляем сигнал
	notificationEvent:FireClient(player, "БОЛЬШАЯ ВОЛНА НА ПОДХОДЕ!", Color3.fromRGB(255, 50, 50))

	-- Запускаем цикл спавна
	task.spawn(function()
		local delayBetweenSpawns = duration / count 

		for i = 1, count do
			if not player.Character then break end 

			spawnSingleZombie(player, 45) -- Радиус кольца 45 студов

			task.wait(delayBetweenSpawns)
		end
	end)
end

return WaveManager