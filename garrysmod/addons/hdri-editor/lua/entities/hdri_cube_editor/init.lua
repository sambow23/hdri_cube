AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
-- Remove the AddCSLuaFile("properties/hdri_cube_editor.lua") line
include("shared.lua")

util.AddNetworkString("HDRICube_UpdateRotation")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
    
    self:SetCustomRotation(Angle(0, 0, 0))
end

-- Network receiver for rotation updates
net.Receive("HDRICube_UpdateRotation", function(len, ply)
    local ent = net.ReadEntity()
    local newAng = net.ReadAngle()
    
    if IsValid(ent) and ent:GetClass() == "hdri_cube_editor" then
        ent:SetCustomRotation(newAng)
    end
end)

function ENT:OnRemove()
    -- Notify clients to cleanup their resources
    net.Start("HDRICube_Cleanup")
        net.WriteEntity(self)
    net.Broadcast()
end

util.AddNetworkString("HDRICube_Cleanup")