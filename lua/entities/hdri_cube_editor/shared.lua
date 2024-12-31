ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "HDRI Cube"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "Editors"

function ENT:SetupDataTables()
    self:NetworkVar("Angle", 0, "CustomRotation")
end