-- @ScriptType: Script
local ServerScriptService = game:GetService("ServerScriptService")
-- Подключаем наш справочник врагов
local EnemyRegistry = require(ServerScriptService:WaitForChild("EnemyRegistry"))

local swordModel = script.Parent
if swordModel.Name == "Handle" then
	swordModel = swordModel.Parent
end

local handle = swordModel:WaitForChild("Handle", 5) 
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

if not handle then 
	warn("SwordLogic: Handle не найден в модели!")
	return 
end

local DAMAGE = swordModel:GetAttribute("Damage") or 5
local CRIT_CHANCE = swordModel:GetAttribute("CritChance") or 5
local CRIT_MULT = swordModel:GetAttribute("CritMultiplier") or 2

local hitList = {} 
local hasPlayedHitSound = false 
local slashSound = handle:FindFirstChild("SwordSlash") or handle:FindFirstChild("SwordLunge")

-- Ищем все части меча для касания
for _, part in pairs(swordModel:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character:FindFirstChild("Humanoid")

			-- [ГЛАВНОЕ ИСПРАВЛЕНИЕ]
			-- Теперь мы спрашиваем у Registry: "Это враг?"
			-- Это сработает для всех, кто есть в твоем списке (Enemy, EnemyBlack и т.д.)
			if humanoid and EnemyRegistry.IsEnemy(character) and humanoid.Health > 0 then

				if not hitList[character] then
					hitList[character] = true 

					-- РАСЧЕТ КРИТА
					local finalDamage = DAMAGE
					local isCrit = math.random(1, 100) <= CRIT_CHANCE
					if isCrit then
						finalDamage = DAMAGE * CRIT_MULT
					end

					humanoid:TakeDamage(finalDamage)

					-- === ВЫЛЕТАЮЩИЕ ЦИФРЫ ===
					local head = character:FindFirstChild("Head") or character.PrimaryPart
					if head then
						local bgui = Instance.new("BillboardGui")
						bgui.Name = "DamageGui"
						bgui.Size = isCrit and UDim2.new(0, 130, 0, 65) or UDim2.new(0, 80, 0, 40)
						bgui.Adornee = head
						bgui.StudsOffset = Vector3.new(math.random(-1.5, 1.5), 2, 0) 
						bgui.AlwaysOnTop = true

						local lbl = Instance.new("TextLabel")
						lbl.BackgroundTransparency = 1
						lbl.Size = UDim2.new(1, 0, 1, 0)
						lbl.Text = isCrit and "CRIT! "..math.floor(finalDamage) or tostring(math.floor(finalDamage))
						lbl.TextColor3 = isCrit and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)

						lbl.TextTransparency = isCrit and 0 or 0.1 
						lbl.TextStrokeTransparency = 0.5 
						lbl.TextScaled = true
						lbl.Font = Enum.Font.LuckiestGuy
						lbl.Parent = bgui
						bgui.Parent = character

						local displayTime = 1.0
						TweenService:Create(bgui, TweenInfo.new(displayTime), {StudsOffset = bgui.StudsOffset + Vector3.new(0, 4, 0)}):Play()
						TweenService:Create(lbl, TweenInfo.new(displayTime), {TextTransparency = 1}):Play()
						Debris:AddItem(bgui, displayTime)
					end

					-- Звук
					if slashSound and not hasPlayedHitSound then
						hasPlayedHitSound = true
						local hitSfx = slashSound:Clone()
						hitSfx.Parent = handle
						hitSfx.Volume = slashSound.Volume * 0.8 
						hitSfx:Play()
						Debris:AddItem(hitSfx, 1)
					end
				end
			end
		end)
	end
end