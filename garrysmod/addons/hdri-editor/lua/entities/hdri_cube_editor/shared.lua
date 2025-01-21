ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "HDRI Editor"
ENT.Author = "CR"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "Editors"

function ENT:SetupDataTables()
    self:NetworkVar("Angle", 0, "CustomRotation")
end