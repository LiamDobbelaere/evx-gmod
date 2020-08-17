AddCSLuaFile()

game.AddParticles("particles/evx.pcf")
PrecacheParticleSystem("evx_gas_infinite")

ENT.PrintName = "Gas cloud"
ENT.Author = "Digaly"
ENT.Information = "Don't breathe this"
ENT.Category = "EV-X"

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable = false
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end

    local ent = ents.Create(ClassName)
    ent:SetPos(tr.HitPos + tr.HitNormal * 50)
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Initialize()
    if (CLIENT) then return end

    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMaterial("models/debug/debugwhite")
    self:SetColor(Color(255, 255, 0, 255))

    local phys = self:GetPhysicsObject()
    if (phys:IsValid()) then
        phys:Wake()
        phys:EnableGravity(false)
        phys:EnableMotion(false)
    end

    ParticleEffect("evx_gas_infinite", self:GetPos(), Angle(0, 0, 0), self)
end

function ENT:Think()
    if CLIENT then return end

    local nearbyEnts = ents.FindInSphere(self:GetPos(), 350)
    local dmg = DamageInfo()
    dmg:SetDamage(8)
    dmg:SetAttacker(self)
    dmg:SetDamageType(DMG_POISON)

    for _, ent in pairs(nearbyEnts) do
        if ent:IsPlayer() or ent:IsNPC() then ent:TakeDamageInfo(dmg) end
    end

    -- Think once per second
    self:NextThink(CurTime() + 1)
    return true
end
