-- @ScriptType: Script
-- @ScriptType: Script (Внутри Bomb)
local Bomb = script.Parent
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local EnemyRegistry = require(ServerScriptService:WaitForChild("EnemyRegistry"))

-- == 1. ПОДГОТОВКА ==
local primary = Bomb.PrimaryPart or Bomb:FindFirstChildWhichIsA("BasePart")
if not primary then 
	Bomb:Destroy() 
	return 
end
Bomb.PrimaryPart = primary

-- Замораживаем физику
for _, part in pairs(Bomb:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Anchored = true 
		part.CanCollide = false
	end
end

-- Читаем настройки
local SPEED = Bomb:GetAttribute("Speed") or 35
local DAMAGE = Bomb:GetAttribute("Damage") or 30
local RANGE = Bomb:GetAttribute("Range") or 6
local CRIT_CHANCE = Bomb:GetAttribute("CritChance") or 10

local shooterName = Bomb:GetAttribute("TargetPlayer")
local isExploded = false

Debris:AddItem(Bomb, 8) 

-- Ждем Target
local targetValue = Bomb:WaitForChild("Target", 2)
local currentTarget = targetValue and targetValue.Value

-- == ВИЗУАЛ УРОНА ==
local function ShowDamagePopUp(targetChar, amount, isCrit)
	local head = targetChar:FindFirstChild("Head") or targetChar.PrimaryPart
	if not head then return end
	local bgui = Instance.new("BillboardGui"); bgui.Name = "DamageGui"; bgui.Size = isCrit and UDim2.new(0, 130, 0, 65) or UDim2.new(0, 80, 0, 40); bgui.Adornee = head; bgui.StudsOffset = Vector3.new(math.random(-1.5, 1.5), 2, 0); bgui.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.Text = isCrit and "CRIT! "..math.floor(amount) or tostring(math.floor(amount)); lbl.TextColor3 = isCrit and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 220, 0); lbl.TextTransparency = isCrit and 0 or 0.1; lbl.TextStrokeTransparency = 0.5; lbl.TextScaled = true; lbl.Font = Enum.Font.LuckiestGuy; lbl.Parent = bgui; bgui.Parent = workspace 
	TweenService:Create(bgui, TweenInfo.new(1), {StudsOffset = bgui.StudsOffset + Vector3.new(0, 4, 0)}):Play(); TweenService:Create(lbl, TweenInfo.new(1), {TextTransparency = 1}):Play(); Debris:AddItem(bgui, 1)
end

-- == ВЗРЫВ (ТОЛЬКО ОГОНЬ) ==
local function Explode(position)
	if isExploded then return end
	isExploded = true

	-- 1. Точка эффекта
	local vfxRoot = Instance.new("Part")
	vfxRoot.Transparency = 1
	vfxRoot.Anchored = true
	vfxRoot.CanCollide = false
	vfxRoot.Position = position
	vfxRoot.Parent = workspace

	-- 2. Звук
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://142070127"
	s.Volume = 1.0
	s.Parent = vfxRoot
	s:Play()

	-- 3. ОГОНЬ (Сделал чуть больше, раз убрали столб)
	local fire = Instance.new("Fire")
	fire.Size = 8        -- Размер пламени
	fire.Heat = 20       -- Как быстро поднимается вверх
	fire.Color = Color3.fromRGB(255, 100, 0)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
	fire.Parent = vfxRoot

	-- 4. СВЕТ (Вспышка)
	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 15
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Parent = vfxRoot

	-- Удаляем огонь и свет через полсекунды (быстрая вспышка)
	Debris:AddItem(fire, 0.6)
	Debris:AddItem(light, 0.4)
	Debris:AddItem(vfxRoot, 2)

	-- == НАНЕСЕНИЕ УРОНА ==
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if shooterName and game.Players:FindFirstChild(shooterName) and game.Players[shooterName].Character then
		params.FilterDescendantsInstances = {game.Players[shooterName].Character}
	end

	local hitParts = workspace:GetPartBoundsInRadius(position, RANGE, params)
	local hitEnemies = {}

	for _, part in pairs(hitParts) do
		local enemyChar = part.Parent
		if EnemyRegistry.IsEnemy(enemyChar) then
			local hum = enemyChar:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 and not hitEnemies[enemyChar] then
				hitEnemies[enemyChar] = true
				local finalDamage = DAMAGE
				local isCrit = math.random(1, 100) <= CRIT_CHANCE
				if isCrit then finalDamage = DAMAGE * 2 end 
				hum:TakeDamage(finalDamage)
				ShowDamagePopUp(enemyChar, finalDamage, isCrit)
			end
		end
	end

	Bomb.PrimaryPart.Transparency = 1
	Debris:AddItem(Bomb, 0.1)
end

-- == ПОЛЕТ ==
local lastPos = Bomb.PrimaryPart.Position

RunService.Heartbeat:Connect(function(dt)
	if isExploded or not Bomb.PrimaryPart then return end

	-- Обновляем цель
	if targetValue and targetValue.Value and targetValue.Value.Parent then
		local hum = targetValue.Value.Parent:FindFirstChild("Humanoid")
		if hum and hum.Health > 0 then
			currentTarget = targetValue.Value
		else
			currentTarget = nil 
		end
	end

	local currentPos = Bomb.PrimaryPart.Position
	local nextPos

	if currentTarget then
		local targetPos = currentTarget.Position
		local direction = (targetPos - currentPos).Unit
		nextPos = currentPos + (direction * SPEED * dt)
		Bomb:PivotTo(CFrame.lookAt(nextPos, targetPos))

		if (targetPos - currentPos).Magnitude < 2 then 
			Explode(targetPos)
			return
		end
	else
		local direction = Bomb.PrimaryPart.CFrame.LookVector
		nextPos = currentPos + (direction * SPEED * dt)
		Bomb:PivotTo(CFrame.new(nextPos) * Bomb.PrimaryPart.CFrame.Rotation)
	end

	Bomb.PrimaryPart.CFrame = Bomb.PrimaryPart.CFrame * CFrame.Angles(-0.1, 0, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {Bomb, game.Players:FindFirstChild(shooterName) and game.Players[shooterName].Character}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayDir = nextPos - lastPos
	local hit = workspace:Raycast(lastPos, rayDir * 1.5, rayParams)

	if hit then Explode(hit.Position) end

	lastPos = nextPos
end)