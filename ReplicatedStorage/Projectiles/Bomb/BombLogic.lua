-- @ScriptType: Script
local BombModel = script.Parent
local Character = BombModel.Parent
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- [ВАЖНО]
local ServerScriptService = game:GetService("ServerScriptService")

local EnemyRegistry = require(ServerScriptService:WaitForChild("EnemyRegistry"))
-- [ВАЖНО] Ищем переключатель паузы. Создай BoolValue "GamePaused" в ReplicatedStorage!
local GamePaused = ReplicatedStorage:WaitForChild("GamePaused", 5) 

-- == НАСТРОЙКИ БОЯ ==
local DAMAGE = 10           
local EXPLOSION_RADIUS = 10 
local COOLDOWN = 3          
local SEARCH_RANGE = 30 

-- Настройки крита
local CRIT_CHANCE = 15      
local CRIT_MULT = 2         

local MIN_DIST = 8   
local MAX_DIST = 14  

-- == НАСТРОЙКИ РЮКЗАКА ==
local BACKPACK_OFFSET = Vector3.new(0, 0.6, 0.65) 
local BACKPACK_ROTATION = Vector3.new(180, 0, 90) 

-- == 1. АВТО-СБОРКА ==
if not BombModel.PrimaryPart then
	local anyPart = BombModel:FindFirstChildWhichIsA("BasePart", true)
	if anyPart then BombModel.PrimaryPart = anyPart else return end
end
local MainPart = BombModel.PrimaryPart
for _, part in pairs(BombModel:GetDescendants()) do
	if part:IsA("BasePart") and part ~= MainPart then
		local weld = Instance.new("WeldConstraint"); weld.Part0 = MainPart; weld.Part1 = part; weld.Parent = MainPart; part.Anchored = false; part.CanCollide = false
	end
end
MainPart.Anchored = false; MainPart.CanCollide = false

-- == 2. КРЕПЛЕНИЕ К СПИНЕ ==
local AttachPart = Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso") or Character:FindFirstChild("HumanoidRootPart")
if AttachPart then 
	local Weld = Instance.new("Weld"); Weld.Name = "BackpackWeld"; Weld.Part0 = AttachPart; Weld.Part1 = MainPart
	Weld.C0 = CFrame.new(BACKPACK_OFFSET) * CFrame.Angles(math.rad(BACKPACK_ROTATION.X), math.rad(BACKPACK_ROTATION.Y), math.rad(BACKPACK_ROTATION.Z))
	Weld.C1 = CFrame.new(); Weld.Parent = MainPart
end

-- == ФУНКЦИЯ ПОКАЗА УРОНА ==
local function ShowDamagePopUp(targetChar, amount, isCrit)
	local head = targetChar:FindFirstChild("Head") or targetChar.PrimaryPart
	if not head then return end

	local bgui = Instance.new("BillboardGui")
	bgui.Name = "DamageGui"
	bgui.Size = isCrit and UDim2.new(0, 130, 0, 65) or UDim2.new(0, 80, 0, 40)
	bgui.Adornee = head
	bgui.StudsOffset = Vector3.new(math.random(-1.5, 1.5), 2, 0) 
	bgui.AlwaysOnTop = true

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Text = isCrit and "CRIT! "..math.floor(amount) or tostring(math.floor(amount))
	lbl.TextColor3 = isCrit and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 220, 0)

	lbl.TextTransparency = isCrit and 0 or 0.1 
	lbl.TextStrokeTransparency = 0.5 
	lbl.TextScaled = true
	lbl.Font = Enum.Font.LuckiestGuy
	lbl.Parent = bgui
	bgui.Parent = workspace 

	local displayTime = 1.0
	TweenService:Create(bgui, TweenInfo.new(displayTime), {StudsOffset = bgui.StudsOffset + Vector3.new(0, 4, 0)}):Play()
	TweenService:Create(lbl, TweenInfo.new(displayTime), {TextTransparency = 1}):Play()
	Debris:AddItem(bgui, displayTime)
end

-- == 3. ВЗРЫВ ==
local function CreateExplosion()
	-- [НОВОЕ] ПРОВЕРКА ПАУЗЫ ПЕРЕД ВЗРЫВОМ
	if GamePaused and GamePaused.Value == true then return end 

	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if not RootPart then return end

	-- ПОИСК ЦЕЛИ
	local explosionPos = nil
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {Character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local partsInArea = workspace:GetPartBoundsInRadius(RootPart.Position, SEARCH_RANGE, params)
	local enemiesFound = {}

	for _, part in pairs(partsInArea) do
		local enemyChar = part.Parent
		if EnemyRegistry.IsEnemy(enemyChar) then
			local hum = enemyChar:FindFirstChild("Humanoid")
			local eRoot = enemyChar:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and eRoot then
				local alreadyAdded = false
				for _, e in pairs(enemiesFound) do if e == enemyChar then alreadyAdded = true break end end
				if not alreadyAdded then table.insert(enemiesFound, eRoot) end
			end
		end
	end

	if #enemiesFound > 0 then
		local targetRoot = enemiesFound[math.random(1, #enemiesFound)]
		explosionPos = targetRoot.Position
	else
		local randomDist = math.random(MIN_DIST, MAX_DIST)
		local randomAngle = math.rad(math.random(0, 360))
		explosionPos = RootPart.Position + Vector3.new(math.cos(randomAngle)*randomDist, 0, math.sin(randomAngle)*randomDist)
	end

	-- == ВИЗУАЛ ==
	local vfxRoot = Instance.new("Part")
	vfxRoot.Name = "ExplosionVFX"
	vfxRoot.Transparency = 1
	vfxRoot.Anchored = true
	vfxRoot.CanCollide = false
	vfxRoot.Size = Vector3.new(1, 1, 1)
	vfxRoot.Position = explosionPos
	vfxRoot.Parent = workspace

	-- 1. КОЛЬЦО
	local shockwave = Instance.new("Part")
	shockwave.Shape = Enum.PartType.Ball 
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 230, 50)
	shockwave.Transparency = 0.2
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Size = Vector3.new(1, 1, 1)
	shockwave.CFrame = CFrame.new(explosionPos)
	shockwave.Parent = workspace

	task.spawn(function()
		local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local goal = {Size = Vector3.new(20, 1, 20), Transparency = 1}
		local tween = TweenService:Create(shockwave, tweenInfo, goal)
		tween:Play()
		tween.Completed:Wait()
		shockwave:Destroy()
	end)

	-- 2. ИСКРЫ
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxassetid://278549557" 
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 0))
	})
	sparks.LightEmission = 1 
	sparks.Size = NumberSequence.new(0.5, 0) 
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Speed = NumberRange.new(20, 35) 
	sparks.SpreadAngle = Vector2.new(360, 360) 
	sparks.Drag = 5 
	sparks.Rate = 0
	sparks.Parent = vfxRoot

	-- 3. ДЫМ
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxassetid://242296180" 
	smoke.Color = ColorSequence.new(Color3.fromRGB(50, 50, 50)) 
	smoke.Size = NumberSequence.new(3, 8)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	smoke.Lifetime = NumberRange.new(1, 1.5)
	smoke.Speed = NumberRange.new(5, 15)
	smoke.SpreadAngle = Vector2.new(360, 360)
	smoke.Rate = 0
	smoke.Parent = vfxRoot

	-- 4. ОГОНЬ
	local fire = Instance.new("Fire")
	fire.Size = 10 
	fire.Heat = 20
	fire.Color = Color3.fromRGB(255, 150, 50)
	fire.SecondaryColor = Color3.fromRGB(100, 0, 0)
	fire.Parent = vfxRoot

	-- 5. СВЕТ
	local light = Instance.new("PointLight")
	light.Range = 15
	light.Brightness = 4
	light.Color = Color3.fromRGB(255, 180, 50)
	light.Parent = vfxRoot

	-- 6. ЗВУК
	local boomSound = Instance.new("Sound")
	boomSound.SoundId = "rbxassetid://142070127"
	boomSound.Volume = 0.8
	boomSound.Pitch = math.random(8, 10)/10
	boomSound.Parent = vfxRoot
	boomSound:Play()

	task.wait(0.05)
	sparks:Emit(40) 
	smoke:Emit(20)  

	task.delay(0.6, function()
		fire.Enabled = false 
		local t = TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 0})
		t:Play()
	end)
	Debris:AddItem(vfxRoot, 3)

	-- == УРОН С КРИТОМ ==
	local parts = workspace:GetPartBoundsInRadius(explosionPos, EXPLOSION_RADIUS, params)
	local hitEnemies = {}

	for _, part in pairs(parts) do
		local enemyChar = part.Parent
		if EnemyRegistry.IsEnemy(enemyChar) then
			local hum = enemyChar:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 and not hitEnemies[enemyChar] then
				hitEnemies[enemyChar] = true

				local finalDamage = DAMAGE
				local isCrit = math.random(1, 100) <= CRIT_CHANCE
				if isCrit then finalDamage = DAMAGE * CRIT_MULT end

				hum:TakeDamage(finalDamage)
				ShowDamagePopUp(enemyChar, finalDamage, isCrit)

				local hrp = enemyChar:FindFirstChild("HumanoidRootPart")
				if hrp then hrp.Velocity = Vector3.new(0, 45, 0) end
			end
		end
	end
end

-- == 4. ТАЙМЕР (С УЧЕТОМ ПАУЗЫ) ==
while BombModel and BombModel.Parent do
	-- Если игра на паузе, ждем пока снимут паузу
	if GamePaused and GamePaused.Value == true then
		GamePaused.Changed:Wait() -- Скрипт замирает здесь
		task.wait(0.5) -- Небольшая задержка после снятия паузы
	end

	task.wait(COOLDOWN)

	-- Дополнительная проверка: вдруг пока мы ждали кулдаун, снова нажали паузу?
	if GamePaused and GamePaused.Value == false then
		CreateExplosion()
	end
end