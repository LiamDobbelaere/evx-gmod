AddCSLuaFile()

ENT.PrintName = "Credits"
ENT.Author = "Digaly"
ENT.Information = "Credits for EV-X"
ENT.Category = "EV-X"

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable = false
ENT.Spawnable = true
ENT.AdminOnly = true

local cwhite = Color(255, 255, 255, 255);
local cblue = Color(0, 200, 255, 255);
local corange = Color(255, 200, 0, 255);
local clime = Color(200, 255, 0, 255);
local cred = Color(245, 25, 25, 255);

local textStrings = {
    {
        text = "Enemy Variations X",
        color = cwhite,
        maxTime = 2.222,
        wobbleFac = 1,
        wobbleSpeedFac = 1
    }, {
        text = ">>> Created by >>>",
        color = cblue,
        maxTime = 2.222,
        wobbleFac = 0.5,
        wobbleSpeedFac = 8
    }, {
        text = "Digaly",
        color = clime,
        maxTime = 2.222,
        wobbleFac = 2,
        wobbleSpeedFac = 1
    }, {
        text = ">>> Contributions by >>>",
        color = corange,
        maxTime = 2.222,
        wobbleFac = 0.5,
        wobbleSpeedFac = 8
    }, {
        text = "Mercury: gas and detonation type",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "zorich_michael: teleporting (possessed)",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "Vladbzf: puller, pyro,\nlifesteal, stun type",
        color = corange,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "Jerkakame: rogue, gnome,\nbulletproof, possessed type\n+ Levels, level color intensity",
        color = corange,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "Lord Crown Empire: pyro type",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "Darkjake: remove colors idea",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "ts.5678: player variations",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 1.5,
        wobbleSpeedFac = 1
    }, {
        text = "And everyone else\nwho provided suggestions!",
        color = cblue,
        maxTime = 2.222 * 2,
        wobbleFac = 0.5,
        wobbleSpeedFac = 8
    }, {
        text = "Thank you for playing EV-X!",
        color = cwhite,
        maxTime = 2.222 * 1,
        wobbleFac = 20,
        wobbleSpeedFac = 0.5
    }, {
        text = "Thank you for playing EV-X!",
        color = corange,
        maxTime = 2.222 * 1,
        wobbleFac = 20,
        wobbleSpeedFac = 0.5
    }, {
        text = "Thank you for playing EV-X!",
        color = cblue,
        maxTime = 2.222 * 1,
        wobbleFac = 20,
        wobbleSpeedFac = 0.5
    }, {
        text = "Thank you for playing EV-X!",
        color = cwhite,
        maxTime = 2.222 * 1,
        wobbleFac = 20,
        wobbleSpeedFac = 0.5
    }
}

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
    if CLIENT then
        self.textTimer = CurTime()
        self.textIndex = 1
        self.currentColor = Color(0, 0, 0, 255)
        self.destroyNextTick = false

        self.music = CreateSound(self, "evx/credits.mp3")
        self.music:SetSoundLevel(0)
        self.music:Play()
        return
    end

    self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)

    local shouldDestroy = #ents.FindByClass("sent_evx_credits") > 1
    self:SetNWBool("destroyNextTick", shouldDestroy)
end

function ENT:OnRemove()
    if CLIENT then
        self.music:Stop()
        return
    end
end

-- Draw some 3D text
local function Draw3DText(pos, ang, scale, text, color, flipView)
    if (flipView) then
        ang:RotateAroundAxis(Vector(0, 0, 1), 180)
        text = string.reverse(text)
    end

    cam.Start3D2D(pos, ang, scale)
    draw.DrawText(text, "DermaLarge", 0, 0, color, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:Think()
    if CLIENT then return end

    if self:GetNWBool("destroyNextTick", false) then self:Remove() end
end

function ENT:Draw()
    self:DrawModel()

    if CurTime() - self.textTimer > textStrings[self.textIndex].maxTime then
        self.textTimer = CurTime()

        self.textIndex = self.textIndex + 1
        if self.textIndex > #textStrings then self.textIndex = 1 end
    end

    local text = textStrings[self.textIndex].text

    local mins, maxs = self:GetModelBounds()
    local newLineCount = 0
    for s in string.gmatch(text, "[^\n]+") do newLineCount = newLineCount + 1 end

    local pos = self:GetPos() + Vector(0, 0, maxs.z + (80 * newLineCount))

    local ang = Angle(0,
                      math.sin(SysTime() * 3 *
                                   textStrings[self.textIndex].wobbleSpeedFac) *
                          20 * textStrings[self.textIndex].wobbleFac % 360, 90)
    local ang2 = Angle(0,
                       math.sin(SysTime() * 3 *
                                    textStrings[self.textIndex].wobbleSpeedFac) *
                           20 * textStrings[self.textIndex].wobbleFac % 360, 90)

    local col = textStrings[self.textIndex].color
    self.currentColor = Color(Lerp(4 * FrameTime(), self.currentColor.r, col.r),
                              Lerp(4 * FrameTime(), self.currentColor.g, col.g),
                              Lerp(4 * FrameTime(), self.currentColor.b, col.b),
                              255)

    Draw3DText(pos + Vector(0, 3, -3), ang, 2, text, Color(0, 0, 0, 255), false)
    Draw3DText(pos, ang, 2, text, self.currentColor, false)
    Draw3DText(pos + Vector(0, 3, -3), ang, 2, text, Color(0, 0, 0, 255), true)
    Draw3DText(pos, ang2, 2, text, self.currentColor, true)
end
