-- @ScriptType: Script
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local SimplePath = require(script:WaitForChild("SimplePath")) 

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- == 1. НАСТРОЙКИ ==
local DAMAGE = 12           
local ATTACK_COOLDOWN = 1  
local ATTACK_RANGE = 3     -- Увеличили, чтобы доставал

local AGRO_DISTANCE = 350
local DELAY_MIN = 10
local DELAY_MAX = 30
local SCAN_RADIUS_MIN = 50
local SCAN_RADIUS_MAX = 200

local MyAttackOffset = Vector3.new(math.random(-40, 40)/10, 0, math.random(-40, 40)/10)

-- == НАСТРОЙКА КОЛЛИЗИЙ ==
local ZOMBIE_GROUP = "ZombieGroup"

task.spawn(function()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(ZOMBIE_GROUP)
		PhysicsService:CollisionGroupSetCollidable(ZOMBIE_GROUP, ZOMBIE_GROUP, false)
	end)

	for _, part in pairs(Character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = ZOMBIE_GROUP
		end
	end
end)

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
	AgentRadius = 3, -- Чуть больше для черного
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
	if LastRequest and (LastRequest - goal).Magnitude < 2 then 
		if SameRequests >= 5 then return false else SameRequests += 1 end		
	else
		LastRequest = goal
		SameRequests = 0
	end		

	Path:Run(goal)

	if waitForStop then
		repeat task.wait(0.1) until Path._status == SimplePath.StatusType.Idle		
	end
	return true	
end

Path.Blocked:Connect(function()
	Humanoid.Jump = true
end)

-- == 4. ГЛАВНЫЙ ЦИКЛ ==
local LastAttackTime = 0

-- [ВАЖНО] Вот здесь был разрыв. Теперь цикл один и целый.
while Humanoid and Humanoid.Health > 0 do

	-- 1. ПРОВЕРКА ЗАМОРОЗКИ (Если Anchored — спим)
	if HumanoidRootPart.Anchored then
		if Path._status ~= SimplePath.StatusType.Idle then
			Path:Stop() 
		end
		-- Можно сбросить скорость, чтобы анимация ходьбы тоже остановилась (если она управляется скоростью)
		Humanoid.WalkSpeed = 0 
		task.wait(0.5) 
		continue 
	else
		-- Возвращаем скорость, если разморозили
		if Humanoid.WalkSpeed == 0 then Humanoid.WalkSpeed = 16 end
	end
	-- -----------------------------

	local NewTarget, TargetHumanoid, Distance = GetNearestTarget()	

	-- 2. Смена цели
	if CurrentTarget ~= NewTarget then
		CurrentTarget = NewTarget
		LastPosition = nil
		if NewTarget == nil and Path._status ~= SimplePath.StatusType.Idle then 
			Path:Stop() 
		end
	end	

	-- 3. Логика поведения
	if CurrentTarget then
		local distToTarget = (HumanoidRootPart.Position - CurrentTarget.Position).Magnitude

		if distToTarget <= ATTACK_RANGE then
			-- === АТАКА ===
			if Path._status ~= SimplePath.StatusType.Idle then
				Path:Stop()
			end

			-- Поворот к игроку
			HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, Vector3.new(CurrentTarget.Position.X, HumanoidRootPart.Position.Y, CurrentTarget.Position.Z))

			local t = os.clock()
			if (t - LastAttackTime) >= ATTACK_COOLDOWN then
				LastAttackTime = t
				-- Анимацию атаки здесь не вызываем, если надеемся на стандартный Animate.
				-- Но стандартный Animate обычно НЕ умеет атаковать сам.
				-- Если он просто стоит и смотрит — значит, удара нет.

				if TargetHumanoid and TargetHumanoid.Health > 0 then
					TargetHumanoid:TakeDamage(DAMAGE)
					print("Black Zombie SMASH!") 
				end
			end
		else
			-- === ПОГОНЯ ===
			local TargetPosWithOffset = CurrentTarget.Position + MyAttackOffset

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