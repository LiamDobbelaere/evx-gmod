AddCSLuaFile()

-- shared
local function safeCall(f, ...) if f ~= nil then f(unpack({...})) end end

local evxTypes = {
    "explosion", "mother", "boss", "bigboss", "knockback", "cloaked", "puller",
    "rogue", "pyro", "lifesteal", "metal", "gnome"
}
local evxPendingInit = {}
-- possible evx properties and hooks:
-- color - ev-x NPC color
-- spawn(ent) - ev-x NPC spawn function 
-- entitycreated(npc, ent) - react to ANY entity being made on the map (npc = ourselves)
-- takedamage(target, dmginfo) - ev-x NPC is taking damage
-- givedamage(target, dmginfo) - ev-x NPC is giving damage
-- tick(ent) - ev-x tick, ent is the ev-x NPC itself
-- killed(ent, attacker, inflictor) - ev-x NPC was killed
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
    spidersack = {
        color = Color(255, 255, 255, 255),
        spawn = function(ent) end,
        killed = function(ent, attacker, inflictor)
            local bmin, bmax = ent:GetModelBounds()
            local scale = ent:GetModelScale()

            for i = -5, 5 do
                for j = -5, 5 do
                    local baby = ents.Create("npc_headcrab_fast")
                    baby:SetPos(ent:GetPos() +
                                    Vector(i * bmax.x * scale,
                                           j * bmax.y * scale, 0))

                    if IsValid(ent:GetActiveWeapon()) then
                        baby:Give(ent:GetActiveWeapon():GetClass())
                    end

                    baby:SetNWString("evxType", "spiderbaby")
                    baby:Spawn()
                    baby:Activate()

                    table.insert(evxPendingInit, baby)
                end
            end
        end
    },
    spiderbaby = {
        color = Color(0, 0, 0, 255),
        spawn = function(ent)
            ent:SetModelScale(0.2)
            ent:SetHealth(1)
        end,
        tick = function(ent) ent:SetPlaybackRate(100) end,
        givedamage = function(target, dmginfo) dmginfo:SetDamage(1) end
    },
    possessed = {
        -- https://www.youtube.com/watch?v=vFCwjkKWOdw
        -- horror 2 on hurt
        -- horror 1 on sight
        -- horror 3 on death
        -- horror 4 on attack
        color = Color(10, 10, 10, 255),
        tick = function() ent:SetPlaybackRate(100) end
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
    turret = {
        color = Color(128, 128, 128, 255),
        spawn = function(ent)
            ent:CapabilitiesClear()
            if IsValid(ent:GetPhysicsObject()) then
                ent:GetPhysicsObject():EnableMotion(false)
            end
        end
    },
    metal = {
        color = Color(255, 255, 255, 255),
        spawn = function(ent) ent:SetMaterial("debug/env_cubemap_model") end,
        takedamage = function(target, dmginfo)
            if not dmginfo:IsDamageType(DMG_BLAST) then
                dmginfo:ScaleDamage(0)
            end
            dmginfo:SetDamageType(DMG_SHOCK)
        end
    },
    gnome = {
        color = Color(0, 128, 255, 255),
        spawn = function(ent)
            ent:SetModelScale(0.4)
            ent:SetHealth(ent:Health() / 4)
        end,
        givedamage = function(target, dmginfo)
            if target:IsPlayer() or target:IsNPC() then
                if target:Health() > 1 then
                    dmginfo:SetDamage(target:Health() - 1)
                    dmginfo:GetInflictor():EmitSound(Sound("evx/gnomed.wav"),
                                                     70, 100)
                else
                    dmginfo:ScaleDamage(0)
                end
            end
        end
    },
    pyro = {
        color = Color(255, 128, 0, 255),
        givedamage = function(target, dmginfo)
            if target:IsPlayer() or target:IsNPC() or
                IsValid(target:GetPhysicsObject()) then
                target:Ignite(1.5)
            end
        end
    },
    lifesteal = {
        color = Color(0, 255, 130, 255),
        givedamage = function(target, dmginfo)
            local attacker = dmginfo:GetInflictor()

            if target:IsPlayer() or target:IsNPC() then
                if IsValid(attacker) and attacker:IsNPC() then
                    local lifestealDamage = dmginfo:GetDamage() * 2
                    if attacker:Health() < attacker:GetMaxHealth() then
                        attacker:SetHealth(
                            math.min(attacker:Health() + lifestealDamage,
                                     attacker:GetMaxHealth()))
                        attacker:EmitSound(Sound("items/medshot4.wav"), 75, 80)

                    end
                    print(attacker:Health())
                end
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
                Vector(-bmax.x * scale, bmax.y * scale, 0),
                Vector(bmax.x * scale, bmax.y * scale, 0),
                Vector(-bmax.x * scale, -bmax.y * scale, 0),
                Vector(bmax.x * scale, -bmax.y * scale, 0)
            }

            for i, position in ipairs(positions) do
                local baby = ents.Create(ent:GetClass())
                baby:SetPos(ent:GetPos() + position)

                if ent:IsNPC() and IsValid(ent:GetActiveWeapon()) then
                    baby:Give(ent:GetActiveWeapon():GetClass())
                end

                baby:SetNWString("evxType", "motherchild")
                baby:Spawn()
                baby:Activate()

                table.insert(evxPendingInit, baby)
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
                    timer.Simple(.3, function()
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

        ent:SetNWString("evxType", variant)
        table.insert(evxPendingInit, ent)
    end
})

if CLIENT then
    CreateClientConVar("evx_draw_hud", "1", true, false,
                       "Disable drawing the ev-x hud, like displaying NPC health and type",
                       0, 1)

    hook.Add("HUDPaint", "HUDPaint_DrawABox", function()
        if not GetConVar("evx_draw_hud"):GetBool() then return end

        local tr = util.GetPlayerTrace(LocalPlayer())
        local trace = util.TraceLine(tr)
        if (not trace.Hit) then return end
        if (not trace.HitNonWorld) then return end

        local text = "ERROR"
        local font = "TargetID"
        local evxType = ""

        if trace.Entity:GetNWString("evxType", false) then
            text = string.upper(trace.Entity:GetNWString("evxType"))
            evxType = trace.Entity:GetNWString("evxType")
        else
            return
        end

        if evxType == "cloaked" or evxType == "spiderbaby" then return end

        surface.SetFont(font)
        local w, h = surface.GetTextSize(text)

        local MouseX, MouseY = gui.MousePos()

        if (MouseX == 0 and MouseY == 0) then

            MouseX = ScrW() / 2
            MouseY = ScrH() / 2

        end

        local x = MouseX
        local y = MouseY

        x = x - w / 2
        y = y + 30

        -- The fonts internal drop shadow looks lousy with AA on
        draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 120))
        draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 50))
        draw.SimpleText(text, font, x, y, evxConfig[evxType].color)

        y = y + h + 5

        local text = trace.Entity:GetClass()
        local font = "TargetID"

        surface.SetFont(font)
        local w, h = surface.GetTextSize(text)
        local x = MouseX - w / 2

        draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 120))
        draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 50))
        draw.SimpleText(text, font, x, y, Color(255, 255, 255))

        y = y + h + 5

        local text = trace.Entity:Health() .. " HP"
        local font = "TargetID"

        surface.SetFont(font)
        local w, h = surface.GetTextSize(text)
        local x = MouseX - w / 2

        draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 120))
        draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 50))
        draw.SimpleText(text, font, x, y, Color(255, 255, 255))
    end)
end

if SERVER then
    CreateConVar("evx_enabled", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Enable enemy variations", 0, 1)
    CreateConVar("evx_affect_allies", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Include allies like Alyx, rebels or animals in getting variations",
                 0, 1)
    CreateConVar("evx_use_colors", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Use colors on the NPC to indicate the type of variant they are",
                 0, 1)
    CreateConVar("evx_rate_nothing", "50", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the 'no' ev-x modifier in enemies", 0, 100000)
    CreateConVar("evx_rate_knockback", "40", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the knockback ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_puller", "35", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the puller ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_pyro", "35", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the pyro ev-x modifier in enemies", 0, 100000)
    CreateConVar("evx_rate_lifesteal", "15", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the lifesteal ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_explosion", "30", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the explosion ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_cloaked", "30", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the cloaked ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_mother", "20", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the mother ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_boss", "15", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the boss ev-x modifier in enemies", 0, 100000)
    CreateConVar("evx_rate_rogue", "15", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the rogue ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_bigboss", "5", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the bigboss ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_metal", "15", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the metal ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_gnome", "2", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the gnome ev-x modifier in enemies", 0,
                 100000)
    concommand.Add("evx_rate_reset_all", function()
        GetConVar("evx_rate_nothing"):Revert()
        for _, v in pairs(evxTypes) do
            GetConVar("evx_rate_" .. v):Revert()
        end
    end)

    local function IsEvxEnabled() return GetConVar("evx_enabled"):GetBool() end
    local function IsAffectingAllies()
        return GetConVar("evx_affect_allies"):GetBool()
    end
    local function IsUsingColors()
        return GetConVar("evx_use_colors"):GetBool()
    end
    local function GetSpawnRateFor(type)
        return GetConVar("evx_rate_" .. type):GetInt()
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

    -- TODO NPC variation exclusions:
    -- copy chances table
    -- remove bad variations for this npc
    -- subtract removed weights from the weightsum 
    -- use new weightsum and new chances table

    -- Jerkakame
    -- infected variant
    -- that spawns a headcrab
    -- the headcrab infects others

    local evxChances = {
        ["nothing"] = GetSpawnRateFor("nothing"),
        ["lifesteal"] = GetSpawnRateFor("lifesteal"),
        ["metal"] = GetSpawnRateFor("metal"),
        ["gnome"] = GetSpawnRateFor("gnome"),
        ["knockback"] = GetSpawnRateFor("knockback"),
        ["puller"] = GetSpawnRateFor("puller"),
        ["pyro"] = GetSpawnRateFor("pyro"),
        ["explosion"] = GetSpawnRateFor("explosion"),
        ["cloaked"] = GetSpawnRateFor("cloaked"),
        ["mother"] = GetSpawnRateFor("mother"),
        ["boss"] = GetSpawnRateFor("boss"),
        ["rogue"] = GetSpawnRateFor("rogue"),
        ["bigboss"] = GetSpawnRateFor("bigboss")
        -- ["turret"] = 10000,
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
    local evxTickNPCs = {}

    function evxInit(ent)
        -- reset these before a modifier changes it
        ent:SetModelScale(1)
        ent:SetHealth(ent:GetMaxHealth())
        ent:SetMaterial("")

        if IsUsingColors() then
            ent:SetColor(evxConfig[ent:GetNWString("evxType")].color)
        end
        safeCall(evxConfig[ent:GetNWString("evxType")].spawn, ent)

        if ent:GetNWString("evxType2", false) then
            if IsUsingColors() then
                ent:SetMaterial("models/shiny")
                ent:SetColor(Color(255, 255, 255, 0))
            end

            safeCall(evxConfig[ent:GetNWString("evxType2")].spawn, ent)
        end

        evxNPCs[ent] = true

        if evxConfig[ent:GetNWString("evxType")].tick ~= nil then
            evxTickNPCs[ent] = true
        end
    end

    hook.Add("OnNPCKilled", "EVXOnNPCKilled", function(ent, attacker, inflictor)
        if not IsEvxEnabled() then return end

        -- we're a ev-x enemy getting killed
        if IsValid(ent) and ent:GetNWString("evxType", false) then
            safeCall(evxConfig[ent:GetNWString("evxType")].killed, ent,
                     attacker, inflictor)

            if ent:GetNWString("evxType2", false) then
                safeCall(evxConfig[ent:GetNWString("evxType2")].killed, ent,
                         attacker, inflictor)
            end

            evxNPCs[ent] = nil
            evxTickNPCs[ent] = nil
        end
    end)

    hook.Add("EntityRemoved", "EVXEntityRemoved", function(ent)
        if IsValid(ent) and ent:GetNWString("evxType", false) then
            evxNPCs[ent] = nil
            evxTickNPCs[ent] = nil
        end
    end)

    hook.Add("EntityTakeDamage", "EVXEntityTakeDamage",
             function(target, dmginfo)
        if not IsEvxEnabled() then return end

        -- we're a ev-x enemy taking damage
        if IsValid(target) and target:GetNWString("evxType", false) then
            safeCall(evxConfig[target:GetNWString("evxType")].takedamage,
                     target, dmginfo)

            if target:GetNWString("evxType2", false) then
                safeCall(evxConfig[target:GetNWString("evxType2")].takedamage,
                         target, dmginfo)
            end
        end

        -- we're an entity taking damage from an ev-x enemy
        if IsValid(target) and IsEntity(target) and
            IsValid(dmginfo:GetAttacker()) and
            dmginfo:GetAttacker():GetNWString("evxType", false) then
            safeCall(evxConfig[dmginfo:GetAttacker():GetNWString("evxType")]
                         .givedamage, target, dmginfo)

            if dmginfo:GetAttacker():GetNWString("evxType2", false) then
                safeCall(
                    evxConfig[dmginfo:GetAttacker():GetNWString("evxType2")]
                        .givedamage, target, dmginfo)
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

        -- if ent:GetClass() == "prop_physics" then
        -- spider baby
        --    local baby = ents.Create("npc_headcrab_fast")
        --    timer.Simple(1, function()
        --        if IsValid(baby) and IsValid(ent) then
        --            baby:SetPos(ent:GetPos())
        --        end
        --    end)

        --    baby:SetNWString("evxType", "spiderbaby")
        --    baby:Spawn()
        --    baby:Activate()

        --    table.insert(evxPendingInit, baby)
        -- end

        for evxNPC, _ in pairs(evxNPCs) do
            if IsValid(evxNPC) and evxNPC:IsNPC() and
                evxNPC:GetNWString("evxType", false) then
                safeCall(evxConfig[evxNPC:GetNWString("evxType")].entitycreated,
                         evxNPC, ent)
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
                        ent:SetNWString("evxType", GetRandomType(
                                            evxChancesType2, weightSumType2))
                        ent:SetNWString("evxType2", GetRandomType(
                                            evxChancesType2, weightSumType2))
                        table.insert(evxPendingInit, ent)
                        break
                    end

                    ent:SetNWString("evxType", k)
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

        for evxNPC, _ in pairs(evxTickNPCs) do
            if IsValid(evxNPC) then
                safeCall(evxConfig[evxNPC:GetNWString("evxType")].tick, evxNPC)
            end
        end

        evxPendingInit = {}
    end)
end
