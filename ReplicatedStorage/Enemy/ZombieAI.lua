-- @ScriptType: Script
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService") -- [НОВОЕ] Нужен для отключения столкновений
local SimplePath = require(script:WaitForChild("SimplePath")) 

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- == 1. НАСТРОЙКИ ==
local DAMAGE = 7            
local ATTACK_COOLDOWN = 1   
local ATTACK_RANGE = 3     -- [ИЗМЕНЕНИЕ] Чуть увеличил, чтобы с учетом оффсета доставали

local AGRO_DISTANCE = 350
local DELAY_MIN = 10
local DELAY_MAX = 30
local SCAN_RADIUS_MIN = 50
local SCAN_RADIUS_MAX = 200

-- [НОВОЕ] Уникальный сдвиг для этого зомби, чтобы они не толпились в одной точке
-- Они будут стараться встать вокруг игрока в радиусе 3-4 студов
local MyAttackOffset = Vector3.new(math.random(-40, 40)/10, 0, math.random(-40, 40)/10)

-- == [НОВОЕ] НАСТРОЙКА КОЛЛИЗИЙ (ЧТОБЫ НЕ ЛАЗИЛИ ПО ГОЛОВАМ) ==
local ZOMBIE_GROUP = "ZombieGroup"

-- Пытаемся создать группу и настроить её (делаем это через pcall, чтобы не было ошибок, если группа уже есть)
task.spawn(function()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(ZOMBIE_GROUP)
		-- Зомби НЕ сталкиваются с Зомби (false)
		PhysicsService:CollisionGroupSetCollidable(ZOMBIE_GROUP, ZOMBIE_GROUP, false)
	end)

	-- Применяем группу ко всем частям этого зомби
	for _, part in pairs(Character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = ZOMBIE_GROUP
		end
	end
end)
-- ============================================================

-- == 2. ЗДОРОВЬЕ ==
local head = Character:FindFirstChild("Head") or HumanoidRootPart
local billboard = head:FindFirstChildOfClass("BillboardGui") or Character:FindFirstChildOfClass("BillboardGui")
local healthBarFill = nil

if billboard then
	billboard.Enabled = false
	local frame = billboard:FindFirstChildOfClass("Frame")
	if frame then
		healthBarFill = frame:FindFirstChild("Fill") or frame:FindFirstChild("Bar") or frame:FindFirstChildOfClass("Frame")
	end
end

local function updateHealthBar()
	-- Сначала проверяем, жива ли вообще "вывеска"
	if billboard then
		billboard.Enabled = (Humanoid.Health < Humanoid.MaxHealth)
	end

	-- [ИСПРАВЛЕНИЕ] Проверяем, находится ли полоска в игре (Workspace)
	-- Если зомби уже удалился, мы просто пропускаем этот шаг и не получаем ошибку
	if healthBarFill and healthBarFill:IsDescendantOf(workspace) then
		local percent = Humanoid.Health / Humanoid.MaxHealth
		healthBarFill:TweenSize(UDim2.new(percent, 0, 1, 0), "Out", "Quad", 0.3, true)
	end
end
Humanoid.HealthChanged:Connect(updateHealthBar)
updateHealthBar()

-- == 3. ПУТЬ ==
local AgentParameters = { 
	Costs = { Water = 50 },
	AgentRadius = 2, -- Учитываем размер зомби
	AgentCanJump = true
}
local Path = SimplePath.new(Character, AgentParameters)
Path.Visualize = false

local CurrentTarget = nil
local LastPosition = nil
local IsWandering = false

function GetRandomOffset()
	local ScanRadius = math.random(SCAN_RADIUS_MIN, SCAN_RADIUS_MAX)
	return Vector3.new(ScanRadius * math.random(-1,1), 0, ScanRadius * math.random(-1,1))
end

function GetRandomPoint()
	local Position = Vector3.new(HumanoidRootPart.Position.X, 300, HumanoidRootPart.Position.Z) + GetRandomOffset()
	local Direction = CFrame.new(Position).UpVector * -500 
	local Params = RaycastParams.new()
	Params.IgnoreWater = false
	-- Игнорируем самого себя при поиске точки
	Params.FilterDescendantsInstances = {Character}
	local Result = workspace:Raycast(Position, Direction, Params)
	if Result and Result.Instance and Result.Material ~= Enum.Material.Water then
		return Result
	end
	return false
end

function GetNearestTarget()
	local dist = AGRO_DISTANCE
	local target = nil
	local targetHum = nil
	for i, p in pairs(game.Players:GetPlayers()) do
		local TargetCharacter = p.Character
		if TargetCharacter then
			local TargetHumanoid = TargetCharacter:FindFirstChildOfClass("Humanoid")
			local TargetHRP = TargetCharacter:FindFirstChild("HumanoidRootPart")
			if TargetHumanoid and TargetHumanoid.Health > 0 and TargetHRP then
				local d = (TargetHRP.Position - HumanoidRootPart.Position).Magnitude
				if d <= dist then
					dist = d
					target = TargetHRP
					targetHum = TargetHumanoid
				end
			end
		end
	end
	return target, targetHum, dist
end

function StateChanged(oldState, newState)
	if newState == Enum.HumanoidStateType.Seated then
		local Seat = Humanoid.SeatPart
		if Seat then
			local SeatWeld = Seat:FindFirstChild("SeatWeld")
			if SeatWeld then Debris:AddItem(SeatWeld, 0) end			
		end
		Humanoid.Sit = false
		Humanoid.Jump = true
	elseif newState == Enum.HumanoidStateType.Swimming then
		Humanoid.Jump = true
	end
end
Humanoid.StateChanged:Connect(StateChanged)

local SameRequests = 0
local LastRequest = nil

function RunTo(goal, waitForStop)
	-- Простая оптимизация: если цель та же самая, не пересчитываем путь слишком часто
	if LastRequest and (LastRequest - goal).Magnitude < 2 then -- Если цель сдвинулась меньше чем на 2 студа
		if SameRequests >= 5 then return false else SameRequests += 1 end		
	else
		LastRequest = goal
		SameRequests = 0
	end		

	-- Подключаем обработку блокировок только один раз или корректно сбрасываем (упрощено)
	-- В оригинале SimplePath лучше вызывать Run в цикле без постоянного реконнекта, но оставим твой стиль
	Path:Run(goal)

	if waitForStop then
		-- Для патрулирования ждем окончания
		repeat task.wait(0.1) until Path._status == SimplePath.StatusType.Idle		
	end
	return true	
end

-- Обработка ошибок пути (если застрял - прыгай)
Path.Blocked:Connect(function()
	Humanoid.Jump = true
end)

-- == 4. ГЛАВНЫЙ ЦИКЛ ==
local LastAttackTime = 0

while Humanoid and Humanoid.Health > 0 do	
	local NewTarget, TargetHumanoid, Distance = GetNearestTarget()	

	-- 1. Смена цели
	if CurrentTarget ~= NewTarget then
		CurrentTarget = NewTarget
		LastPosition = nil
		-- Если потеряли цель, останавливаемся
		if NewTarget == nil and Path._status ~= SimplePath.StatusType.Idle then 
			Path:Stop() 
		end
	end	

	-- 2. Логика
	if CurrentTarget then
		local distToTarget = (HumanoidRootPart.Position - CurrentTarget.Position).Magnitude

		if distToTarget <= ATTACK_RANGE then
			-- === АТАКА ===
			if Path._status ~= SimplePath.StatusType.Idle then
				Path:Stop()
			end

			-- Поворачиваемся к врагу лицом
			HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, Vector3.new(CurrentTarget.Position.X, HumanoidRootPart.Position.Y, CurrentTarget.Position.Z))

			local t = os.clock()
			if (t - LastAttackTime) >= ATTACK_COOLDOWN then
				LastAttackTime = t
				if TargetHumanoid and TargetHumanoid.Health > 0 then
					TargetHumanoid:TakeDamage(DAMAGE)
					print("КУСЬ!") 
				end
			end
		else
			-- === ПОГОНЯ ===
			-- [ВАЖНО] Бежим не ровно в игрока, а в точку рядом с ним (с учетом личного сдвига зомби)
			local TargetPosWithOffset = CurrentTarget.Position + MyAttackOffset

			-- Обновляем путь, если цель сдвинулась
			if not LastPosition or (TargetPosWithOffset - LastPosition).Magnitude > 3 then
				LastPosition = TargetPosWithOffset				
				RunTo(LastPosition)
			end
		end

	elseif not IsWandering then		
		-- === ПАТРУЛЬ ===
		IsWandering = true			
		local RaycastResult	
		repeat RaycastResult = GetRandomPoint() task.wait() until RaycastResult
		local Goal = RaycastResult.Position			
		task.spawn(function()
			RunTo(Goal, true)		
			task.wait(math.random(DELAY_MIN, DELAY_MAX))
			IsWandering = false
		end)			
	end

	task.wait(0.1)
end

Path:Destroy()
Debris:AddItem(Character, 4)