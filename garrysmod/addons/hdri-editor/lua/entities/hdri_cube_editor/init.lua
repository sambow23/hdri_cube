AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("HDRICube_UpdateRotation")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    
    -- Non-physical setup
    self:PhysicsInit(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    
    -- Ensure no collisions or physics
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:DrawShadow(false)
    
    -- Prevent any physics calculations
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:EnableCollisions(false)
        phys:EnableGravity(false)
        phys:EnableDrag(false)
        phys:Sleep()
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