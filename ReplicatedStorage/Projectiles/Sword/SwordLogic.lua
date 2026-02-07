-- @ScriptType: Script
local swordModel = script.Parent
local handle = swordModel:FindFirstChild("Handle")

local DAMAGE = swordModel:GetAttribute("Damage") or 5
local hitList = {} 
local hasPlayedHitSound = false 

-- Находим оригинальный звук взмаха
local slashSound = handle:FindFirstChild("SwordSlash") or handle:FindFirstChild("SwordLunge")

for _, part in pairs(swordModel:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character:FindFirstChild("Humanoid")

			if humanoid and character.Name == "Enemy" and humanoid.Health > 0 then
				if not hitList[character] then
					hitList[character] = true 
					humanoid:TakeDamage(DAMAGE)

					-- Создаем ОТДЕЛЬНУЮ копию для звука попадания
					if slashSound and not hasPlayedHitSound then
						hasPlayedHitSound = true

						local hitSfx = slashSound:Clone()
						hitSfx.Name = "HitEffectSound"
						hitSfx.Parent = handle
						hitSfx.Volume = slashSound.Volume * 0.8 -- Чуть тише основного взмаха
						hitSfx:Play()

						-- Удаляем копию, когда она доиграет
						game:GetService("Debris"):AddItem(hitSfx, 1)
					end
				end
			end
		end)
	end
end