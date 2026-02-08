-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

Players.CharacterAutoLoads = false 

-- == ССЫЛКИ НА СОБЫТИЯ ==
local startGameEvent = ReplicatedStorage.Events.StartGameEvent
local gameOverEvent = ReplicatedStorage.Events:WaitForChild("GameOverEvent")
local restartEvent = ReplicatedStorage.Events:WaitForChild("RestartGameEvent")
local showUpgradeEvent = ReplicatedStorage.Events:WaitForChild("ShowUpgradeEvent")
local selectUpgradeEvent = ReplicatedStorage.Events:WaitForChild("SelectUpgradeEvent")

-- == ОБЪЕКТЫ ==
local enemyTemplate = ReplicatedStorage:WaitForChild("Enemy") 
local enemyBlackTemplate = ReplicatedStorage:WaitForChild("EnemyBlack") -- [ДОБАВИТЬ ЭТУ СТРОКУ]
local timeLeftValue = ReplicatedStorage:WaitForChild("TimeLeft") 
local fireballTemplate = ReplicatedStorage:WaitForChild("Projectiles"):WaitForChild("Fireball") 
local swordTemplate = ReplicatedStorage:WaitForChild("Projectiles"):WaitForChild("Sword")
local bombTemplate = ReplicatedStorage:WaitForChild("Projectiles"):WaitForChild("Bomb")
local appleTemplate = ReplicatedStorage:WaitForChild("AppleDrop")

-- == БАЗА УЛУЧШЕНИЙ ==
local UpgradeDB = require(ServerScriptService:WaitForChild("UpgradeDB"))
-- [НОВОЕ] Подключаем WaveManager
local WaveManager = require(ServerScriptService:WaitForChild("WaveManager"))
local EnemyRegistry = require(ServerScriptService:WaitForChild("EnemyRegistry")) -- [ВОТ ОНА, ОДНА СТРОКА]

-- == НАСТРОЙКИ ==
local GAME_TIME = 600 
local SPAWN_RATE = 1.5  
local XP_PER_KILL = 1    
local MAX_LEVEL = 10     

local activeSessions = {}

-- 1. ОЧИСТКА КАРТЫ
local function cleanupMap()
	for _, obj in pairs(workspace:GetChildren()) do
		if obj.Name == "Enemy" or obj.Name == "Sword" or obj.Name == "Fireball" or obj.Name == "AppleDrop" then
			obj:Destroy()
		end
	end
end

-- 2. СТАТИСТИКА
local function setupLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = 0
	kills.Parent = stats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 0
	level.Parent = stats

	local exp = Instance.new("IntValue")
	exp.Name = "XP"
	exp.Value = 0
	exp.Parent = player
end

-- == ФУНКЦИИ ЗАМОРОЗКИ ==
local function toggleZombies(freeze)
	for _, obj in pairs(workspace:GetChildren()) do
		-- Используем Реестр, чтобы найти ВСЕХ врагов
		if EnemyRegistry.IsEnemy(obj) and obj:FindFirstChild("HumanoidRootPart") then
			obj.HumanoidRootPart.Anchored = freeze

			-- Дополнительно: Если морозим, останавливаем анимацию ходьбы (Path)
			local hum = obj:FindFirstChild("Humanoid")
			if hum then
				if freeze then
					hum.WalkSpeed = 0 -- Чтобы ноги не скользили
				else
					hum.WalkSpeed = 16 -- Или какая у них скорость по умолчанию
				end
			end
		end
	end
end

local function togglePlayer(player, freeze)
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = freeze
	end
end

-- 3. ОПЫТ И LEVEL UP
local function addExp(player, amount)
	local session = activeSessions[player.UserId]
	if not session or session.isPaused then return end

	local xpVal = player:FindFirstChild("XP")
	local levelVal = player.leaderstats.Level

	if xpVal and levelVal then
		if levelVal.Value >= MAX_LEVEL then return end
		xpVal.Value += amount

		local requiredXP = 7 + (levelVal.Value * 5)

		if xpVal.Value >= requiredXP then
			xpVal.Value -= requiredXP 
			levelVal.Value += 1

			local levelUpSoundId = "rbxassetid://2686079706" 
			local sound = Instance.new("Sound")
			sound.SoundId = levelUpSoundId
			sound.Volume = 1
			sound.Parent = player.Character or player.PlayerGui
			sound:Play()
			Debris:AddItem(sound, 3)

			session.isPaused = true 
			toggleZombies(true) 
			togglePlayer(player, true)

			local options = UpgradeDB.getRandomUpgrades(session.weapon)
			session.currentOptions = options 
			showUpgradeEvent:FireClient(player, options)
		end
	end
end

-- 4. ОБРАБОТКА ВЫБОРА
selectUpgradeEvent.OnServerEvent:Connect(function(player, choiceIndex)
	local session = activeSessions[player.UserId]
	if session and session.isPaused and session.currentOptions then
		local selectedUpgrade = session.currentOptions[choiceIndex]
		if selectedUpgrade then
			for statName, value in pairs(selectedUpgrade.stats) do
				if session.stats[statName] then
					session.stats[statName] += value
				end
			end
			session.isPaused = false
			session.currentOptions = nil
			toggleZombies(false) 
			togglePlayer(player, false)
		end
	end
end)

-- 5. ПОИСК ВРАГА (ВЕРСИЯ С РЕЕСТРОМ)
local function findNearestEnemy(playerPos, range)
	local closestEnemy = nil
	local minDistance = range

	for _, object in pairs(workspace:GetChildren()) do

		-- [ГЛАВНОЕ ИЗМЕНЕНИЕ]
		-- Спрашиваем у Реестра: "Это враг?"
		-- Теперь неважно, как его зовут, главное, чтобы он был в списке Registry.
		if EnemyRegistry.IsEnemy(object) and object:FindFirstChild("Humanoid") and object:FindFirstChild("HumanoidRootPart") then

			local hum = object.Humanoid
			if hum.Health > 0 then
				local dist = (object.HumanoidRootPart.Position - playerPos).Magnitude

				-- Компенсация для больших врагов всё равно нужна
				local compensation = 0
				if object.Name == "EnemyBlack" then 
					compensation = 3 -- Даем фору толстяку
				end

				if (dist - compensation) < minDistance then
					closestEnemy = object.HumanoidRootPart
					minDistance = dist
				end
			end
		end
	end
	return closestEnemy
end

-- 6. ИГРОВОЙ ЦИКЛ
local function startPlayerSession(player, weaponChoice)
	local initialStats = {
		damage = 10,
		cooldown = 1.5,
		speed = 35,   
		range = 5,    
		size = 1,
		critChance = 5,
		critMultiplier = 2
	}

	if weaponChoice == "Sword" then
		initialStats.damage = 5
		initialStats.cooldown = 1.3 
		initialStats.range = 6
	elseif weaponChoice == "Fireball" then
		initialStats.damage = 15
		initialStats.cooldown = 2.0
		initialStats.speed = 40
		initialStats.range = 60
	elseif weaponChoice == "Bomb" then
		local newBomb = bombTemplate:Clone()
		newBomb.Parent = player.Character
		-- Скрипт внутри newBomb (BombLogic) запустится автоматически

		-- Убираем лишние параметры из сессии, так как бомба автономна
		-- Но можно оставить stats для красоты интерфейса
		initialStats.damage = 25
		initialStats.cooldown = 3
	end

	activeSessions[player.UserId] = {
		isPlaying = true,
		isPaused = false,
		startTime = os.time(),
		weapon = weaponChoice,
		stats = initialStats,
		lastAttackTime = 0,     
		lastEnemySpawnTime = 0,
		waveTriggered = false -- [НОВОЕ] Флаг, была ли волна
	}

	task.spawn(function()
		while activeSessions[player.UserId] and activeSessions[player.UserId].isPlaying do
			local session = activeSessions[player.UserId]
			if session.isPaused then task.wait(0.1) continue end

			local currentTime = os.time() 
			local exactTime = os.clock()  

			-- [ИЗМЕНЕНИЕ] Считаем время от начала игры для волны
			local timeInGame = currentTime - session.startTime
			local remaining = math.max(0, GAME_TIME - timeInGame)

			timeLeftValue.Value = remaining

			local isDead = (not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0)

			if remaining <= 0 or isDead then
				activeSessions[player.UserId].isPlaying = false
				gameOverEvent:FireClient(player, player.leaderstats.Kills.Value, player.leaderstats.Level.Value)
				break 
			end

			-- [НОВОЕ] ПРОВЕРКА ВОЛНЫ (30 секунд)
			if timeInGame >= 30 and not session.waveTriggered then
				session.waveTriggered = true
				-- Спавним 30 зомби за 15 секунд
				WaveManager.triggerBigWave(player, 30, 15)
			end

			-- == АТАКА ИГРОКА (ТВОЙ КОД, БЕЗ ИЗМЕНЕНИЙ) ==
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and not isDead then
				local root = player.Character.HumanoidRootPart

				if exactTime - session.lastAttackTime >= session.stats.cooldown then

					-- == ФАЕРБОЛ ==
					if session.weapon == "Fireball" then
						local target = findNearestEnemy(root.Position, session.stats.range)
						if target then
							local fb = fireballTemplate:Clone()
							fb:PivotTo(root.CFrame * CFrame.new(0, 0, -3)) 

							-- ПЕРЕДАЧА АТРИБУТОВ (КРИТ И УРОН)
							fb:SetAttribute("Damage", session.stats.damage)
							fb:SetAttribute("Speed", session.stats.speed)
							fb:SetAttribute("CritChance", session.stats.critChance)
							fb:SetAttribute("CritMultiplier", session.stats.critMultiplier)
							fb:SetAttribute("TargetPlayer", player.Name)

							-- Оранжевый шлейф (ТВОЙ КОД)
							local mainPart = fb.PrimaryPart or fb:FindFirstChildWhichIsA("BasePart")
							if mainPart then
								local att0 = Instance.new("Attachment", mainPart)
								local att1 = Instance.new("Attachment", mainPart)
								att0.Position = Vector3.new(0, 1, 0)
								att1.Position = Vector3.new(0, -1, 0)

								local trail = Instance.new("Trail")
								trail.Attachment0 = att0
								trail.Attachment1 = att1
								trail.Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 0))
								})
								trail.Transparency = NumberSequence.new(0.3, 1)
								trail.Lifetime = 0.5
								trail.WidthScale = NumberSequence.new(1, 0)
								trail.Parent = mainPart
							end

							fb.Parent = workspace
							fb.Target.Value = target
							session.lastAttackTime = exactTime
						end

						-- == МЕЧ ==
					elseif session.weapon == "Sword" then
						local newSword = swordTemplate:Clone()
						local handle = newSword:FindFirstChild("Handle")

						if handle then
							handle.Anchored = false
							handle.CanCollide = false
							handle.Massless = true

							local slashSound = handle:FindFirstChild("SwordSlash") or handle:FindFirstChild("SwordLunge")
							if slashSound then slashSound:Play() end

							-- ПЕРЕДАЧА АТРИБУТОВ
							newSword:SetAttribute("Damage", session.stats.damage)
							newSword:SetAttribute("CritChance", session.stats.critChance)
							newSword:SetAttribute("CritMultiplier", session.stats.critMultiplier)

							local radius = session.stats.range or 5
							newSword.Parent = workspace 

							local weld = Instance.new("Weld")
							weld.Part0 = root 
							weld.Part1 = handle
							weld.C0 = CFrame.new(radius, 0.3, 0)
							weld.Parent = handle

							task.spawn(function()
								local duration = 0.4
								local startTime = os.clock()

								-- Эффекты меча (ТВОЙ КОД)
								local swordTrail = Instance.new("Trail")
								swordTrail.Attachment0 = Instance.new("Attachment", handle)
								swordTrail.Attachment1 = Instance.new("Attachment", handle)
								swordTrail.Attachment0.Position = Vector3.new(0, 0, handle.Size.Z * 0.8)
								swordTrail.Attachment1.Position = Vector3.new(0, 0, -handle.Size.Z * 0.8)
								swordTrail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 200, 255))
								swordTrail.Transparency = NumberSequence.new(0.4, 1)
								swordTrail.WidthScale = NumberSequence.new(1.2, 0)
								swordTrail.Lifetime = 0.25
								swordTrail.Parent = handle

								while os.clock() - startTime < duration do
									if not newSword.Parent then break end
									local alpha = (os.clock() - startTime) / duration 
									local angle = alpha * (math.pi * 2) 
									weld.C0 = CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0.3, 0) * CFrame.Angles(0, math.rad(90), math.rad(45))
									task.wait() 
								end

								if newSword.Parent then
									for _, p in pairs(newSword:GetDescendants()) do
										if p:IsA("BasePart") then p.Transparency = 1 p.CanTouch = false end
										if p:IsA("Trail") or p:IsA("ParticleEmitter") then p.Enabled = false end
									end
									Debris:AddItem(newSword, 1)
								end
							end)
							session.lastAttackTime = exactTime
						end
					end
				end 
			end 

			-- СПАВН ВРАГОВ (ОБЫЧНЫЙ)
			if currentTime - session.lastEnemySpawnTime >= SPAWN_RATE then
				session.lastEnemySpawnTime = currentTime 
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local root = player.Character.HumanoidRootPart

					-- [НОВОЕ] 1. Выбираем, кого спавнить
					local templateToSpawn = enemyTemplate -- По умолчанию обычный

					-- Если прошло больше 45 сек И выпал шанс 1 из 5 (20%)
					if timeInGame >= 45 and math.random(1, 5) == 1 then
						templateToSpawn = enemyBlackTemplate
					end

					-- 2. Расчет позиции (Твой код с пончиком)
					local minDist = 60  
					local maxDist = 120 

					local angle = math.rad(math.random(1, 360)) 
					local dist = math.random(minDist, maxDist)  

					local offsetX = math.cos(angle) * dist
					local offsetZ = math.sin(angle) * dist

					local spawnPos = root.Position + Vector3.new(offsetX, 5, offsetZ)

					-- 3. Спавним выбранного (templateToSpawn)
					local newEnemy = templateToSpawn:Clone()
					newEnemy.Parent = workspace
					newEnemy:PivotTo(CFrame.new(spawnPos, root.Position)) -- Лицом к игроку
					newEnemy:SetAttribute("TargetPlayer", player.Name)

					local hum = newEnemy:FindFirstChild("Humanoid")
					if hum then
						hum.Died:Connect(function()
							player.leaderstats.Kills.Value += 1

							-- [НОВОЕ] Проверка опыта (Черный дает x3)
							local amountXP = XP_PER_KILL
							if newEnemy.Name == "EnemyBlack" then
								amountXP = XP_PER_KILL * 3
							end
							addExp(player, amountXP) 

							if math.random(1, 100) <= 5 and appleTemplate then
								local drop = appleTemplate:Clone()
								drop.CFrame = newEnemy.HumanoidRootPart.CFrame 
								drop.Parent = workspace
								Debris:AddItem(drop, 180)
							end
							task.wait(1)
							newEnemy:Destroy()
						end)
					end
				end
			end
			task.wait(0.1) 
		end
	end)
end

-- СОБЫТИЯ И ПРИСОЕДИНЕНИЕ
Players.PlayerAdded:Connect(function(player)
	setupLeaderstats(player)
	player:LoadCharacter()
end)

startGameEvent.OnServerEvent:Connect(function(player, weaponName)
	if player.Character then
		player.leaderstats.Kills.Value = 0
		player.leaderstats.Level.Value = 0
		if player:FindFirstChild("XP") then player.XP.Value = 0 end
		player.Character.HumanoidRootPart.Anchored = false
		startPlayerSession(player, weaponName)
	end
end)

restartEvent.OnServerEvent:Connect(function(player)
	cleanupMap()
	player:LoadCharacter() 
end)