AddCSLuaFile()

-- shared
local function safeCall(f, ...) if f ~= nil then f(unpack({...})) end end

local function randomEnemyLevel()
    local selectedRange = math.random(100)
    local min = 0
    local max = 0

    if selectedRange < 50 then
        min = 1
        max = 45
    elseif selectedRange < 95 then
        min = 45
        max = 75
    else
        min = 75
        max = 100
    end

    return math.random(min, max)
end

local evxTypes = {
    "explosion", "mother", "boss", "bigboss", "knockback", "cloaked", "puller",
    "rogue", "pyro", "lifesteal", "metal", "gnome", "gas", "spidersack",
    "possessed"
}
table.sort(evxTypes)
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
            local explosionMagnitude = tostring(
                                           ent:GetNWInt("evxLevel", 1) / 100 *
                                               240) -- pre-level was 80
            local explode = ents.Create("env_explosion")
            explode:SetPos(ent:GetPos())
            explode:SetOwner(ent)
            explode:Spawn()
            explode:SetKeyValue("iMagnitude", explosionMagnitude)
            explode:Fire("Explode", 0, 0)
        end
    },
    gas = {
        color = Color(80, 255, 0, 255),
        killed = function(ent, attacker, inflictor)
            local lvl = ent:GetNWInt("evxLevel", 1)
            local size = 'small'
            local lifetime = 0

            if lvl < 20 then
                size = 'small'
                lifetime = 15
            elseif lvl < 40 then
                size = 'medium'
                lifetime = 15
            elseif lvl < 80 then
                size = 'large'
                lifetime = 20
            else
                size = 'huge'
                lifetime = 25
            end

            local gasCloud = ents.Create("sent_evx_gascloud")
            gasCloud.size = size
            gasCloud.life = lifetime
            gasCloud:SetPos(ent:GetPos())
            gasCloud:SetOwner(ent)
            gasCloud:Spawn()

            gasCloud:EmitSound(Sound("evx/gas.wav"), 100, 100)
        end
    },
    spidersack = {
        color = Color(50, 100, 50, 255),
        spawn = function(ent) end,
        killed = function(ent, attacker, inflictor)
            local lvl = ent:GetNWInt("evxLevel", 1)
            local spiderCount = 0

            if lvl < 40 then
                spiderCount = 1
            elseif lvl < 80 then
                spiderCount = 2
            else
                spiderCount = 3
            end

            local bmin, bmax = ent:GetModelBounds()
            local scale = ent:GetModelScale()

            for i = -spiderCount, spiderCount do
                for j = -spiderCount, spiderCount do
                    local baby = ents.Create("npc_headcrab_fast")
                    baby:SetPos(ent:GetPos() +
                                    Vector(i * bmax.x * scale,
                                           j * bmax.y * scale, 0))

                    baby:SetNWInt("evxLevel", ent:GetNWInt("evxLevel", 1))
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

            if not ent.evxPermanent then
                -- clean spiders up after 1 to 5 minutes
                timer.Simple(math.Rand(60, 60 * 5), function()
                    if IsValid(ent) then
                        ent:TakeDamage(1, ent, ent)
                    end
                end)
            end
        end,
        tick = function(ent) ent:SetPlaybackRate(100) end,
        givedamage = function(target, dmginfo) dmginfo:SetDamage(1) end
    },
    possessed = {
        spawn = function(ent)
            ent:SetRenderFX(kRenderFxDistort)
            ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
            ent.evxAttackTime = 0
            ent.evxPainTime = 0
        end,
        color = Color(10, 10, 10, 10),
        killed = function(ent)
            local lvl = ent:GetNWInt("evxLevel", 1)
            local radius = 0
            local strength = 0

            if lvl < 40 then
                radius = 500
                strength = 1
            elseif lvl < 80 then
                radius = 1000
                strength = 2
            else
                radius = 1000
                strength = 3
            end

            local nearbyStuff = ents.FindInSphere(ent:GetPos(), 1000)
            for _, nearbyEnt in pairs(nearbyStuff) do
                if IsValid(nearbyEnt) and IsValid(nearbyEnt:GetPhysicsObject()) then
                    local phys = nearbyEnt:GetPhysicsObject()
                    phys:ApplyForceCenter(
                        (ent:GetPos() - nearbyEnt:GetPos()) * phys:GetMass() * 3)
                end
            end

            ent:EmitSound(Sound("evx/horror3.wav"), 70, 100)
        end,
        takedamage = function(target, dmginfo)
            local me = target

            if me.evxPainTime and (CurTime() - me.evxPainTime > 6) then
                me:EmitSound(Sound("evx/horror2.wav"), 70, 100)

                me.evxPainTime = CurTime()
            end
        end,
        givedamage = function(target, dmginfo)
            local me = dmginfo:GetInflictor()

            if me.evxAttackTime and (CurTime() - me.evxAttackTime > 6) then
                me:EmitSound(Sound("evx/horror4.wav"), 70, 100)

                me.evxAttackTime = CurTime()
            end
        end,
        tick = function(ent) ent:SetPlaybackRate(100) end
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

            for i, v in ipairs(player.GetAll()) do
                ent:AddEntityRelationship(v, D_HT, 99)
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
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local igniteTime = lvl * 4

            if target:IsPlayer() or target:IsNPC() or
                IsValid(target:GetPhysicsObject()) then
                target:Ignite(igniteTime)
            end
        end
    },
    lifesteal = {
        color = Color(0, 255, 130, 255),
        givedamage = function(target, dmginfo)
            local attacker = dmginfo:GetInflictor()

            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local lifestealFactor = lvl * 4

            if target:IsPlayer() or target:IsNPC() then
                if IsValid(attacker) and attacker:IsNPC() then
                    local lifestealDamage =
                        dmginfo:GetDamage() * lifestealFactor
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
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local dmg = lvl * 4

            dmginfo:ScaleDamage(dmg)
            dmginfo:SetDamageForce(dmginfo:GetDamageForce() * dmg)
        end
    },
    bigboss = {
        color = Color(0, 255, 255, 255),
        spawn = function(ent)
            ent:SetModelScale(2)
            ent:SetHealth(ent:Health() * 16)
        end,
        givedamage = function(target, dmginfo)
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local dmg = lvl * 8

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

                baby:SetNWInt("evxLevel", ent:GetNWInt("evxLevel", 1))
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
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local dmg = lvl * 2

            dmginfo:ScaleDamage(dmg)
            dmginfo:SetDamageForce(dmginfo:GetDamageForce() * dmg)
        end
    },
    knockback = {
        color = Color(255, 0, 255, 255),
        givedamage = function(target, dmginfo)
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local knockback = lvl * 3

            if target:IsPlayer() or target:IsNPC() then
                target:SetVelocity(dmginfo:GetDamageForce() * knockback)
            else
                if IsValid(target:GetPhysicsObject()) then
                    target:GetPhysicsObject():SetVelocity(
                        dmginfo:GetDamageForce() * knockback)
                end
            end

        end
    },
    puller = {
        color = Color(0, 255, 0, 255),
        givedamage = function(target, dmginfo)
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local pullAmount = lvl * -3
            local stunAmount = lvl * 0.4

            if target:IsPlayer() or target:IsNPC() then
                target:SetVelocity(dmginfo:GetDamageForce() * pullAmount)
                -- stun effect
                if target:IsPlayer() then
                    target:Freeze(true)
                    timer.Simple(stunAmount, function()
                        target:Freeze(false)
                    end)
                end
            else
                if IsValid(target:GetPhysicsObject()) then
                    target:GetPhysicsObject():SetVelocity(
                        dmginfo:GetDamageForce() * pullAmount)
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
            local lvl = dmginfo:GetInflictor():GetNWInt("evxLevel", 1) / 100
            local scaledDamage = lvl * 3
            local force = lvl * 4

            dmginfo:ScaleDamage(scaledDamage)
            dmginfo:SetDamageForce(dmginfo:GetDamageForce() * force)
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
            submenu:AddOption(v:gsub("^%l", string.upper),
                              function() self:SetVariant(ent, v) end)
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

        if ent:GetNWString("evxType", false) == false then
            ent:SetNWInt("evxLevel", randomEnemyLevel())
        end

        ent:SetNWString("evxType", variant)
        table.insert(evxPendingInit, ent)
    end
})

properties.Add("variantslevel", {
    MenuLabel = "Variant level",
    Order = 601,
    MenuIcon = "icon16/bug_edit.png",
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

        for _, v in pairs({1, 5, 15, 30, 50, 70, 90, 100}) do
            submenu:AddOption('Lv. ' .. v,
                              function() self:SetVariantLevel(ent, v) end)
        end
    end,
    Action = function(self, ent) end,
    SetVariantLevel = function(self, ent, level)
        self:MsgStart()
        net.WriteEntity(ent)
        net.WriteInt(level, 8)
        self:MsgEnd()
    end,
    Receive = function(self, length, player)
        local ent = net.ReadEntity()
        local level = net.ReadInt(8)

        if (not self:Filter(ent, player)) then return end

        ent:SetNWInt("evxLevel", level)
        table.insert(evxPendingInit, ent)
    end
})

if CLIENT then
    CreateClientConVar("evx_draw_hud", "1", true, false,
                       "Disable drawing the ev-x hud, like displaying NPC health and type",
                       0, 1)

    hook.Add("AddToolMenuCategories", "EVXCategory", function()
        spawnmenu.AddToolCategory("Utilities", "EV-X", "EV-X")
    end)

    hook.Add("PopulateToolMenu", "EVXSettings", function()
        spawnmenu.AddToolMenuOption("Utilities", "EV-X", "Spawnrates",
                                    "Spawnrates", "", "", function(panel)
            panel:ClearControls()

            panel:NumSlider("Nothing", "evx_rate_nothing", 0, 200)
            for _, v in pairs(evxTypes) do
                panel:NumSlider(v:gsub("^%l", string.upper), "evx_rate_" .. v,
                                0, 200)
            end

            panel:NumSlider("Random spiders chance",
                            "evx_random_spiders_chance", 0, 1)

            panel:Button("RESET all spawn rates", "evx_rate_reset_all")
        end)

        spawnmenu.AddToolMenuOption("Utilities", "EV-X", "General", "General",
                                    "", "", function(panel)
            panel:ClearControls()
            panel:CheckBox("Enabled", "evx_enabled")
            panel:CheckBox("Affect allies", "evx_affect_allies")
            panel:CheckBox("Use colors", "evx_use_colors")
            panel:CheckBox("Use color intensity for levels",
                           "evx_level_use_color_intensity")
            panel:CheckBox("Randomize on rate change",
                           "evx_randomize_on_rate_change")
            panel:NumSlider("Force level", "evx_level_force", 0, 100)
        end)
    end)

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

        local level = trace.Entity:GetNWInt("evxLevel", -1)
        local text = 'Lv. ' .. level
        local font = "TargetID"
        local levelColor = Color(180, 180, 180)
        if level >= 90 then
            levelColor = Color(255, 0, 0) -- red
        elseif level >= 70 then
            levelColor = Color(255, 128, 0) -- orange
        elseif level >= 50 then
            levelColor = Color(255, 255, 0) -- yellow
        elseif level >= 30 then
            levelColor = Color(0, 128, 255) -- blue
        elseif level >= 15 then
            levelColor = Color(0, 255, 200) -- green-blue
        elseif level >= 5 then
            levelColor = Color(0, 255, 0) -- green
        end

        surface.SetFont(font)
        local w, h = surface.GetTextSize(text)
        local x = MouseX - w / 2

        draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 120))
        draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 50))
        draw.SimpleText(text, font, x, y, levelColor)

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
    CreateConVar("evx_randomize_on_rate_change", "1",
                 {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Re-randomize the NPC variations when the spawnrates change",
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
    CreateConVar("evx_rate_gas", "20", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the gas ev-x modifier in enemies", 0, 100000)
    CreateConVar("evx_rate_spidersack", "20", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the spidersack ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_rate_possessed", "15", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The spawnrate of the possessed ev-x modifier in enemies", 0,
                 100000)
    CreateConVar("evx_level_force", "0", {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Force a level for all ev-x enemies, 0 to disable", 0, 100)
    CreateConVar("evx_level_use_color_intensity", "1",
                 {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "Use color intensity to display an ev-x enemy's level", 0, 1)
    CreateConVar("evx_random_spiders_chance", "0.25",
                 {FCVAR_REPLICATED, FCVAR_ARCHIVE},
                 "The odds of getting random spider babies around physics props, 1 means 100% of the time",
                 0, 1)

    local function IsEvxEnabled() return GetConVar("evx_enabled"):GetBool() end
    local function IsRandomizingOnRateChange()
        return GetConVar("evx_randomize_on_rate_change"):GetBool()
    end
    local function IsAffectingAllies()
        return GetConVar("evx_affect_allies"):GetBool()
    end
    local function IsUsingColors()
        return GetConVar("evx_use_colors"):GetBool()
    end
    local function IsUsingLevelColors()
        return GetConVar("evx_level_use_color_intensity"):GetBool()
    end
    local function GetSpawnRateFor(type)
        return GetConVar("evx_rate_" .. type):GetInt()
    end
    local function GetRandomSpidersChance()
        return GetConVar("evx_random_spiders_chance"):GetFloat()
    end
    local function GetForcedLevel()
        return GetConVar("evx_level_force"):GetInt()
    end

    local evxNPCs = {}
    local evxTickNPCs = {}
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

    local evxChances = {}
    local weightSum = 0

    local function evxApply(ent)
        if not IsEvxEnabled() then return end

        if ent:GetClass() == "prop_physics" and math.random() <
            GetRandomSpidersChance() then
            local baby = ents.Create("npc_headcrab_fast")

            timer.Simple(0, function()
                if IsValid(baby) and IsValid(ent) then
                    local min, max = ent:GetCollisionBounds()

                    baby:SetPos(ent:GetPos() + Vector(0, 0, max.z))
                end
            end)

            baby.evxPermanent = true
            baby:SetNWString("evxType", "spiderbaby")
            baby:Spawn()
            baby:Activate()

            table.insert(evxPendingInit, baby)
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

                    if GetForcedLevel() > 0 then
                        ent:SetNWInt("evxLevel", GetForcedLevel())
                    else
                        ent:SetNWInt("evxLevel", randomEnemyLevel())
                    end

                    table.insert(evxPendingInit, ent)
                    break
                end
            end
        end

        for evxNPC, _ in pairs(evxNPCs) do
            if IsValid(evxNPC) and evxNPC:IsNPC() and
                evxNPC:GetNWString("evxType", false) then
                safeCall(evxConfig[evxNPC:GetNWString("evxType")].entitycreated,
                         evxNPC, ent)
            end
        end
    end

    local function recalculateWeights()
        evxChances = {
            ["nothing"] = GetSpawnRateFor("nothing"),
            ["spidersack"] = GetSpawnRateFor("spidersack"),
            ["possessed"] = GetSpawnRateFor("possessed"),
            ["gas"] = GetSpawnRateFor("gas"),
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

        weightSum = 0
        for k, v in pairs(evxChances) do weightSum = weightSum + v end

        if IsRandomizingOnRateChange() then
            for evxNPC, _ in pairs(evxNPCs) do
                if IsValid(evxNPC) and evxNPC:IsNPC() then
                    evxApply(evxNPC)
                end
            end
        end
    end

    recalculateWeights()

    cvars.AddChangeCallback("evx_rate_nothing", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_knockback", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_puller", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_pyro", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_lifesteal", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_explosion", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_cloaked", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_mother", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_boss", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_rogue", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_bigboss", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_metal", recalculateWeights)
    cvars.AddChangeCallback("evx_rate_gnome", recalculateWeights)

    concommand.Add("evx_rate_reset_all", function()
        GetConVar("evx_rate_nothing"):Revert()
        for _, v in pairs(evxTypes) do
            GetConVar("evx_rate_" .. v):Revert()
        end
        GetConVar("evx_random_spiders_chance"):Revert()
        GetConVar("evx_level_force"):Revert()
    end)

    -- TODO NPC variation exclusions:
    -- copy chances table
    -- remove bad variations for this npc
    -- subtract removed weights from the weightsum 
    -- use new weightsum and new chances table

    -- Jerkakame
    -- infected variant
    -- that spawns a headcrab
    -- the headcrab infects others

    local evxChancesType2 = {
        ["explosion"] = 50,
        ["knockback"] = 20,
        ["boss"] = 20,
        ["mother"] = 20,
        ["bigboss"] = 5
    }
    local weightSumType2 = 0
    for k, v in pairs(evxChancesType2) do weightSumType2 = weightSumType2 + v end

    function evxInit(ent)
        -- reset these before a modifier changes it
        ent:SetModelScale(1)
        ent:SetHealth(ent:GetMaxHealth())
        ent:SetMaterial("")
        ent:SetRenderFX(kRenderFxNone)
        ent:SetRenderMode(RENDERMODE_NORMAL)

        if IsUsingColors() then
            local variationStrength = math.max(0.4,
                                               ent:GetNWInt("evxLevel", 1) / 100)

            if ent:GetNWString("evxType") == 'spiderbaby' or
                (not IsUsingLevelColors()) then variationStrength = 1 end

            local col = evxConfig[ent:GetNWString("evxType")].color
            local def = Color(255, 255, 255, 255)
            local lerpedCol = Color(Lerp(variationStrength, def.r, col.r),
                                    Lerp(variationStrength, def.g, col.g),
                                    Lerp(variationStrength, def.b, col.b))

            ent:SetColor(lerpedCol)
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

    hook.Add("OnEntityCreated", "EVXSpawnedNPC", evxApply)

    hook.Add("Think", "EVXThink", function()
        if not IsEvxEnabled() then return end

        for evxPendingIndex = 1, #evxPendingInit do
            local evxNPC = evxPendingInit[evxPendingIndex]
            if IsValid(evxNPC) and evxNPC:GetNWString("evxType", false) then
                evxInit(evxNPC)
            end
        end

        for evxNPC, _ in pairs(evxTickNPCs) do
            if IsValid(evxNPC) and evxNPC:GetNWString("evxType", false) then
                safeCall(evxConfig[evxNPC:GetNWString("evxType")].tick, evxNPC)
            end
        end

        evxPendingInit = {}
    end)
end
