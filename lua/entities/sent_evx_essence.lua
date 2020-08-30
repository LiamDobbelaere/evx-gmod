AddCSLuaFile()

ENT.PrintName = "Essence"
ENT.Author = "Digaly"
ENT.Information = "?"
ENT.Category = "EV-X"

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable = false
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SpawnFunction(ply, tr, ClassName)
    if #ents.FindByClass("sent_evx_credits") > 0 then return end

    if not tr.Hit then return end

    local ent = ents.Create(ClassName)
    ent:SetPos(tr.HitPos + tr.HitNormal)
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Initialize()
    if CLIENT then return end

    self:SetModel("models/gibs/antlion_gib_large_3.mdl")
    self:SetHealth(99999)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    self:PhysWake()

    timer.Simple(60, function() if IsValid(self) then self:Remove() end end)
end

if SERVER then
    function ENT:SetEVXType(evxType, evxLevel, evxConfig)
        self:SetNWString("evxType", evxType)
        self:SetNWInt("evxLevel", evxLevel)
        self:SetColor(evxConfig[evxType].color)
    end

    function ENT:Use(activator)
        if IsValid(activator) and activator:IsPlayer() then
            activator:SetNWString("evxType", self:GetNWString("evxType", ""))
            activator:SetNWInt("evxLevel", self:GetNWInt("evxLevel", ""))
            activator:SetNWFloat("essenceStart", CurTime())
            activator:EmitSound(Sound("items/medshot4.wav"), 75, 120)

            table.insert(evxPendingInit, activator)
        end

        self:Remove()
    end
end
