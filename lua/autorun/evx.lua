AddCSLuaFile()

-- shared
local function safeCall(f, ...) if f ~= nil then f(unpack({...})) end end

local evxTypes = {
    "explosion", "mother", "boss", "bigboss", "knockback", "cloaked", "puller",
    "rogue"
}
local evxPendingInit = {}

properties.Add("variants", {
    MenuLabel = "Variants",
    Order = 600,
    MenuIcon = "icon16/bug.png",
    Filter = function(self, ent, ply)
        if (not IsValid(ent)) then return false end
        if (not ent:IsNPC()) then return false end
        if (not gamemode.Call("CanProperty", ply, "variants", ent)) then
            return false
        end

        return true
    end,
    MenuOpen = function(self, option, ent, tr)
        local submenu = option:AddSubMenu()

        for k, v in pairs(evxTypes) do
            submenu:AddOption(v, function() self:SetVariant(ent, v) end)
        end
    end,
    Action = function(self, ent) end,
    SetVariant = function(self, ent, variant)
        self:MsgStart()
        net.WriteEntity(ent)
        net.WriteString(variant)
        self:MsgEnd()
    end,
    Receive = function(self, length, player)
        local ent = net.ReadEntity()
        local variant = net.ReadString()

        if (not self:Filter(ent, player)) then return end

        ent.evxType = variant
        table.insert(evxPendingInit, ent)
    end
})

if SERVER then
    CreateConVar("evx_enabled", "1", FCVAR_NONE, "Enable enemy variations", 0, 1)
    CreateConVar("evx_affect_allies", "1", FCVAR_NONE,
                 "Include allies like Alyx, rebels or animals in getting variations",
                 0, 1)
    CreateConVar("evx_use_colors", "1", FCVAR_NONE,
                 "Use colors on the NPC to indicate the type of variant they are",
                 0, 1)

    local function IsEvxEnabled() return GetConVar("evx_enabled"):GetBool() end
    local function IsAffectingAllies()
        return GetConVar("evx_affect_allies"):GetBool()
    end
    local function IsUsingColors()
        return GetConVar("evx_use_colors"):GetBool()
    end

    local allies = {
        ["npc_alyx"] = 1,
        ["npc_magnusson"] = 1,
        ["npc_breen"] = 1,
        ["npc_kleiner"] = 1,
        ["npc_barney"] = 1,
        ["npc_crow"] = 1,
        ["npc_dog"] = 1,
        ["npc_eli"] = 1,
        ["npc_gman"] = 1,
        ["npc_monk"] = 1,
        ["npc_mossman"] = 1,
        ["npc_pigeon"] = 1,
        ["npc_vortigaunt"] = 1,
        ["npc_seagull"] = 1,
        ["npc_citizen"] = 1,
        ["npc_fisherman"] = 1,
        ["monster_barney"] = 1,
        ["monster_cockroach"] = 1,
        ["monster_scientist"] = 1
    }
    local evxChances = {
        ["rogue"] = 10000,
        ["nothing"] = 50,
        ["knockback"] = 40,
        ["puller"] = 35,
        ["explosion"] = 30,
        ["cloaked"] = 30,
        ["mother"] = 20,
        ["boss"] = 15,
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

    local evxNPCs = {}

    -- possible evx properties and hooks:
    -- color - ev-x enemy color
    -- spawn(ent) - ev-x enemy spawn function 
    -- entitycreated(npc, ent) - react to ANY entity being made on the map (npc = ourselves)
    -- takedamage(target, dmginfo) - ev-x enemy is taking damage
    -- givedamage(target, dmginfo) - ev-x enemy is giving damage
    -- killed(ent, attacker, inflictor) - ev-x enemy was killed
    local evxConfig = {
        explosion = {
            color = Color(255, 0, 0, 255),
            killed = function(ent, attacker, inflictor)
                local explode = ents.Create("env_explosion")
                explode:SetPos(ent:GetPos())
                explode:SetOwner(ent)
                explode:Spawn()
                explode:SetKeyValue("iMagnitude", "80")
                explode:Fire("Explode", 0, 0)
            end
        },
        rogue = {
            color = Color(0, 0, 255, 255),
            entitycreated = function(npc, ent)
                if not ent:IsNPC() or ent:GetClass() == npc:GetClass() then
                    return
                end
                npc:AddEntityRelationship(ent, D_HT, 99)
                ent:AddEntityRelationship(npc, D_HT, 99)
            end,
            spawn = function(ent)
                local enemies = ents.FindByClass("npc_*")
                for _, enemy in pairs(enemies) do
                    if not enemy:IsNPC() or enemy:GetClass() == ent:GetClass() then
                        return
                    end
                    enemy:AddEntityRelationship(ent, D_HT, 99)
                    ent:AddEntityRelationship(enemy, D_HT, 99)
                end
            end
        },
        boss = {
            color = Color(80, 80, 100, 255),
            spawn = function(ent)
                ent:SetModelScale(1.5)
                ent:SetHealth(ent:Health() * 8)
            end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(2)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 2)
            end
        },
        bigboss = {
            color = Color(0, 255, 255, 255),
            spawn = function(ent)
                ent:SetModelScale(2)
                ent:SetHealth(ent:Health() * 16)
            end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(4)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 4)
            end
        },
        mother = {
            color = Color(255, 255, 0, 255),
            spawn = function(ent) ent:SetModelScale(1.5) end,
            killed = function(ent, attacker, inflictor)
                local bmin, bmax = ent:GetModelBounds()
                local scale = ent:GetModelScale()
                local positions = {
                    Vector(-bmax.x * scale, 0, bmax.z * scale),
                    Vector(bmax.x * scale, 0, bmax.z * scale),
                    Vector(0, -bmax.y * scale, bmax.z * scale),
                    Vector(0, bmax.y * scale, bmax.z * scale)
                }

                for i, position in ipairs(positions) do
                    local baby = ents.Create(ent:GetClass())
                    baby:SetPos(ent:GetPos() + position)

                    if IsValid(ent:GetActiveWeapon()) then
                        baby:Give(ent:GetActiveWeapon():GetClass())
                    end

                    baby.evxType = "motherchild"
                    baby:Spawn()
                    baby:Activate()

                    evxInit(baby)
                end
            end
        },
        motherchild = {
            color = Color(255, 128, 0, 255),
            spawn = function(ent)
                ent:SetModelScale(0.5)
                ent:SetHealth(ent:Health() / 3)
            end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(0.5)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 0.5)
            end
        },
        knockback = {
            color = Color(255, 0, 255, 255),
            givedamage = function(target, dmginfo)
                if target:IsPlayer() or target:IsNPC() then
                    target:SetVelocity(dmginfo:GetDamageForce() * 1.5)
                else
                    if IsValid(target:GetPhysicsObject()) then
                        target:GetPhysicsObject():SetVelocity(
                            dmginfo:GetDamageForce() * 1.5)
                    end
                end

            end
        },
        puller = {
            color = Color(0, 255, 0, 255),
            givedamage = function(target, dmginfo)
                if target:IsPlayer() or target:IsNPC() then
                    target:SetVelocity(dmginfo:GetDamageForce() * -1)
                    -- stun effect
                    if target:IsPlayer() then
                        target:Freeze(true)
                        timer.Simple(.6, function()
                            target:Freeze(false)
                        end)
                    end
                else
                    if IsValid(target:GetPhysicsObject()) then
                        target:GetPhysicsObject():SetVelocity(
                            dmginfo:GetDamageForce() * -1)
                    end
                end

            end
        },
        cloaked = {
            color = Color(255, 255, 255, 255),
            spawn = function(ent)
                ent:SetMaterial("evx/cloaked")
                ent:SetHealth(ent:Health() / 2)
            end,
            givedamage = function(target, dmginfo)
                dmginfo:ScaleDamage(1.5)
                dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 2)
            end
        }
    }

    function evxInit(ent)
        -- reset these before a modifier changes it
        ent:SetModelScale(1)
        ent:SetHealth(ent:GetMaxHealth())
        ent:SetMaterial("")

        if IsUsingColors() then
            ent:SetColor(evxConfig[ent.evxType].color)
        end
        safeCall(evxConfig[ent.evxType].spawn, ent)

        if ent.evxType2 then
            if IsUsingColors() then
                ent:SetMaterial("models/shiny")
                ent:SetColor(Color(255, 255, 255, 0))
            end

            safeCall(evxConfig[ent.evxType2].spawn, ent)
        end

        evxNPCs[ent] = true
    end

    hook.Add("OnNPCKilled", "EVXOnNPCKilled", function(ent, attacker, inflictor)
        if not IsEvxEnabled() then return end

        -- we're a ev-x enemy getting killed
        if IsValid(ent) and ent.evxType then
            safeCall(evxConfig[ent.evxType].killed, ent, attacker, inflictor)

            if ent.evxType2 then
                safeCall(evxConfig[ent.evxType2].killed, ent, attacker,
                         inflictor)
            end

            evxNPCs[ent] = nil
        end
    end)

    hook.Add("EntityRemoved", "EVXEntityRemoved", function(ent)
        if IsValid(ent) and ent.evxType then evxNPCs[ent] = nil end
    end)

    hook.Add("EntityTakeDamage", "EVXEntityTakeDamage",
             function(target, dmginfo)
        if not IsEvxEnabled() then return end

        -- we're a ev-x enemy taking damage
        if IsValid(target) and target.evxType then
            safeCall(evxConfig[target.evxType].takedamage, target, dmginfo)

            if target.evxType2 then
                safeCall(evxConfig[target.evxType2].takedamage, target, dmginfo)
            end
        end

        -- we're an entity taking damage from an ev-x enemy
        if IsValid(target) and IsEntity(target) and
            IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker().evxType then
            safeCall(evxConfig[dmginfo:GetAttacker().evxType].givedamage,
                     target, dmginfo)

            if dmginfo:GetAttacker().evxType2 then
                safeCall(evxConfig[dmginfo:GetAttacker().evxType2].givedamage,
                         target, dmginfo)
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
        if not IsEvxEnabled() then return end

        for evxNPC, _ in pairs(evxNPCs) do
            if IsValid(evxNPC) and evxNPC:IsNPC() and evxNPC.evxType then
                safeCall(evxConfig[evxNPC.evxType].entitycreated, evxNPC, ent)
            end
        end

        if IsValid(ent) and ent:IsNPC() then
            -- if they're an ally and the player doesn't want allies affected, bail out
            if not IsAffectingAllies() and allies[ent:GetClass()] then
                return
            end

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
        if not IsEvxEnabled() then return end

        for evxPendingIndex = 1, #evxPendingInit do
            if IsValid(evxPendingInit[evxPendingIndex]) then
                evxInit(evxPendingInit[evxPendingIndex])
            end
        end

        evxPendingInit = {}
    end)
end
