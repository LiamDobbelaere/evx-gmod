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
    if CLIENT then return end

    self:SetRenderMode(RENDERMODE_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self.sphereRadius = 0

    if not self.life then self.life = 15 end
    if not self.size then self.size = 'small' end

    if self.size == 'small' then
        self.sphereRadius = 270
    elseif self.size == 'medium' then
        self.sphereRadius = 350
    elseif self.size == 'large' then
        self.sphereRadius = 500
    elseif self.size == 'huge' then
        self.sphereRadius = 1000
    end

    -- small, medium, large, huge
    ParticleEffect("evx_gas_infinite_" .. self.size, self:GetPos(),
                   Angle(0, 0, 0), self)
end

function ENT:Think()
    if CLIENT then return end

    local nearbyEnts = ents.FindInSphere(self:GetPos(), self.sphereRadius)
    local dmg = DamageInfo()
    dmg:SetDamage(8)
    dmg:SetAttacker(self)
    dmg:SetDamageType(DMG_POISON)

    for _, ent in pairs(nearbyEnts) do
        if IsValid(ent) then
            if ent:IsPlayer() or ent:IsNPC() then
                ent:TakeDamageInfo(dmg)
            end
        end
    end

    self.life = self.life - 1
    if self.life <= 0 then self:Remove() end

    -- Think once per second
    self:NextThink(CurTime() + 1)
    return true
end
