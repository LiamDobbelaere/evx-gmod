AddCSLuaFile()

if SERVER then
    local evxTypes = {"explosion", "mother", "boss", "bigboss", "knockback"}
    local evxChances = {
        ["explosion"] = 50,
        ["nothing"] = 50,
        ["knockback"] = 20,
        ["boss"] = 20,
        ["mother"] = 20,
        ["bigboss"] = 5
        -- ["mix2"] = 1000
    }
    local weightSum = 0
    for k, v in pairs(evxChances) do weightSum = weightSum + v end

    local evxChancesType2 = {
        ["explosion"] = 50,
        ["knockback"] = 20,
        ["boss"] = 20,
        ["mother"] = 20,
        ["bigboss"] = 5
    }
    local weightSumType2 = 0
    for k, v in pairs(evxChancesType2) do weightSumType2 = weightSumType2 + v end

    local evxConfig = {
        explosion = {
            color = Color(255, 0, 0, 255),
            spawn = function(ply, ent) end,
            takedamage = function(target, dmginfo)
                if target:Health() - dmginfo:GetDamage() <= 0 and
                    (not target.evxExploded) then
                    target.evxExploded = true
                    dmginfo:SetDamageType(DMG_BURN)
                    local explode = ents.Create("env_explosion") -- creates the explosion
                    explode:SetPos(target:GetPos())
                    -- this creates the explosion through your self.Owner:GetEyeTrace, which is why I put eyetrace in front
                    explode:SetOwner(target) -- this sets you as the person who made the explosion
                    explode:Spawn() -- this actually spawns the explosion
                    explode:SetKeyValue("iMagnitude", "80") -- the magnitude
                    explode:Fire("Explode", 0, 0)
                end
            end,
            givedamage = function(target, dmginfo) end,
            lategivedamage = function(target, dmginfo) end
        },
        boss = {
            color = Color(80, 80, 100, 255),
            spawn = function(ply, ent)
                ent:SetModelScale(1.5)
                ent:SetHealth(math.max(200, ent:Health()))
            end,
            takedamage = function(target, dmginfo) end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(2)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 2)
            end,
            lategivedamage = function(target, dmginfo) end
        },
        bigboss = {
            color = Color(0, 255, 255, 255),
            spawn = function(ply, ent)
                ent:SetModelScale(2)
                ent:SetHealth(math.max(400, ent:Health()))
            end,
            takedamage = function(target, dmginfo) end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(4)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 4)
            end,
            lategivedamage = function(target, dmginfo) end
        },
        mother = {
            color = Color(255, 255, 0, 255),
            spawn = function(ply, ent) ent:SetModelScale(1.5) end,
            takedamage = function(target, dmginfo)
                if target:Health() - dmginfo:GetDamage() <= 0 then
                    local b1 = ents.Create(target:GetClass())
                    b1:SetPos(target:GetPos() + Vector(-10, 0, 10))
                    if IsValid(target:GetActiveWeapon()) then
                        b1:Give(target:GetActiveWeapon():GetClass())
                    end
                    b1.evxType = "motherchild"
                    evxInit(nil, b1)
                    b1:Spawn()
                    local b2 = ents.Create(target:GetClass())
                    b2:SetPos(target:GetPos() + Vector(10, 0, 10))
                    if IsValid(target:GetActiveWeapon()) then
                        b2:Give(target:GetActiveWeapon():GetClass())
                    end
                    b2.evxType = "motherchild"
                    evxInit(nil, b2)
                    b2:Spawn()
                    local b3 = ents.Create(target:GetClass())
                    b3:SetPos(target:GetPos() + Vector(0, -10, 10))
                    if IsValid(target:GetActiveWeapon()) then
                        b3:Give(target:GetActiveWeapon():GetClass())
                    end
                    b3.evxType = "motherchild"
                    evxInit(nil, b3)
                    b3:Spawn()
                    local b4 = ents.Create(target:GetClass())
                    b4:SetPos(target:GetPos() + Vector(0, 10, 10))
                    if IsValid(target:GetActiveWeapon()) then
                        b4:Give(target:GetActiveWeapon():GetClass())
                    end
                    b4.evxType = "motherchild"
                    evxInit(nil, b4)
                    b4:Spawn()
                end
            end,
            givedamage = function(target, dmginfo) end,
            lategivedamage = function(target, dmginfo) end
        },
        motherchild = {
            color = Color(255, 128, 0, 255),
            spawn = function(ply, ent)
                ent:SetModelScale(0.5)
                ent:SetHealth(ent:Health() / 2)
            end,
            takedamage = function(target, dmginfo) end,
            givedamage = function(target, dmginfo) end,
            lategivedamage = function(target, dmginfo) end
        },
        knockback = {
            color = Color(255, 0, 255, 255),
            spawn = function(ply, ent) end,
            takedamage = function(target, dmginfo) end,
            givedamage = function(target, dmginfo)
                local src = dmginfo:GetAttacker():GetPos()
                local dst = target:GetPos()
                local vec = dst - src
                local nrm = vec:GetNormalized()

                target:SetVelocity(dmginfo:GetDamageForce() * 0.8) -- Vector(nrm.x * 300, nrm.y * 300, 400))
            end,
            lategivedamage = function(target, dmginfo) end
        }
    }
    local evxPendingInit = {}
    local evxPendingLateGiveDamage = {}

    function evxInit(ply, ent)
        ent:SetColor(evxConfig[ent.evxType].color)
        evxConfig[ent.evxType].spawn(ply, ent)

        if ent.evxType2 then
            ent:SetMaterial("models/shiny")
            ent:SetColor(Color(255, 255, 255, 0))
            evxConfig[ent.evxType2].spawn(ply, ent)
        end
    end

    hook.Add("EntityTakeDamage", "EntityDamageExample",
             function(target, dmginfo)
        -- we're a ev-x enemy taking damage
        if IsValid(target) and target.evxType then
            evxConfig[target.evxType].takedamage(target, dmginfo)

            if target.evxType2 then
                evxConfig[target.evxType2].takedamage(target, dmginfo)
            end
        end

        -- we're a player taking damage from an ev-x enemy
        if IsValid(target) and target:IsPlayer() and
            IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker().evxType then
            evxConfig[dmginfo:GetAttacker().evxType].givedamage(target, dmginfo)
            table.insert(evxPendingLateGiveDamage, {
                ["type"] = dmginfo:GetAttacker().evxType,
                ["target"] = target,
                ["dmginfo"] = dmginfo
            })

            if dmginfo:GetAttacker().evxType2 then
                evxConfig[dmginfo:GetAttacker().evxType2].givedamage(target,
                                                                     dmginfo)
                table.insert(evxPendingLateGiveDamage, {
                    ["type"] = dmginfo:GetAttacker().evxType2,
                    ["target"] = target,
                    ["dmginfo"] = dmginfo
                })
            end
        end
    end)

    local function GetRandomType(chances, weightSum)
        local randomWeight = math.random(weightSum)

        for k, v in pairs(chances) do
            randomWeight = randomWeight - v
            if randomWeight <= 0 then return k end
        end
    end

    hook.Add("OnEntityCreated", "EVXSpawnedNPC", function(ent)
        if IsValid(ent) and ent:IsNPC() then
            -- Weighted random selection
            local randomWeight = math.random(weightSum)
            for k, v in pairs(evxChances) do
                randomWeight = randomWeight - v
                if randomWeight <= 0 then
                    if k == "nothing" then break end
                    if k == "mix2" then
                        ent.evxType = GetRandomType(evxChancesType2,
                                                    weightSumType2)
                        ent.evxType2 = GetRandomType(evxChancesType2,
                                                     weightSumType2)
                        table.insert(evxPendingInit, ent)
                        break
                    end

                    ent.evxType = k
                    table.insert(evxPendingInit, ent)
                    break
                end
            end
        end
    end)

    hook.Add("Tick", "EVXTick", function()
        for evxPendingIndex = 1, #evxPendingInit do
            if IsValid(evxPendingInit[evxPendingIndex]) then
                evxInit(nil, evxPendingInit[evxPendingIndex])
            end
        end

        for evxPendingIndex = 1, #evxPendingLateGiveDamage do
            local p = evxPendingLateGiveDamage[evxPendingIndex]
            evxConfig[p.type].lategivedamage(p.target, p.dmginfo)
        end

        evxPendingInit = {}
        evxPendingLateGiveDamage = {}
    end)
end
