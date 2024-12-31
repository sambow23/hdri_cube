include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

local function CreateCubeMesh()
    local mesh = Mesh()
    local size = 6
    
    -- Vertices for a cube with corrected UVs and winding order
    local vertices = {
        -- Front face
        {pos = Vector(-size, size, size), normal = Vector(0, 0, 1), u = 0, v = 0},
        {pos = Vector(size, size, size), normal = Vector(0, 0, 1), u = 1, v = 0},
        {pos = Vector(size, -size, size), normal = Vector(0, 0, 1), u = 1, v = 1},
        {pos = Vector(-size, -size, size), normal = Vector(0, 0, 1), u = 0, v = 1},
        
        -- Back face
        {pos = Vector(-size, size, -size), normal = Vector(0, 0, -1), u = 1, v = 0},
        {pos = Vector(-size, -size, -size), normal = Vector(0, 0, -1), u = 1, v = 1},
        {pos = Vector(size, -size, -size), normal = Vector(0, 0, -1), u = 0, v = 1},
        {pos = Vector(size, size, -size), normal = Vector(0, 0, -1), u = 0, v = 0},
        
        -- Right face
        {pos = Vector(size, size, size), normal = Vector(1, 0, 0), u = 0, v = 0},
        {pos = Vector(size, size, -size), normal = Vector(1, 0, 0), u = 1, v = 0},
        {pos = Vector(size, -size, -size), normal = Vector(1, 0, 0), u = 1, v = 1},
        {pos = Vector(size, -size, size), normal = Vector(1, 0, 0), u = 0, v = 1},
        
        -- Left face
        {pos = Vector(-size, size, size), normal = Vector(-1, 0, 0), u = 1, v = 0},
        {pos = Vector(-size, -size, size), normal = Vector(-1, 0, 0), u = 1, v = 1},
        {pos = Vector(-size, -size, -size), normal = Vector(-1, 0, 0), u = 0, v = 1},
        {pos = Vector(-size, size, -size), normal = Vector(-1, 0, 0), u = 0, v = 0},
        
        -- Top face
        {pos = Vector(-size, size, size), normal = Vector(0, 1, 0), u = 0, v = 1},
        {pos = Vector(-size, size, -size), normal = Vector(0, 1, 0), u = 0, v = 0},
        {pos = Vector(size, size, -size), normal = Vector(0, 1, 0), u = 1, v = 0},
        {pos = Vector(size, size, size), normal = Vector(0, 1, 0), u = 1, v = 1},
        
        -- Bottom face
        {pos = Vector(-size, -size, size), normal = Vector(0, -1, 0), u = 0, v = 0},
        {pos = Vector(size, -size, size), normal = Vector(0, -1, 0), u = 1, v = 0},
        {pos = Vector(size, -size, -size), normal = Vector(0, -1, 0), u = 1, v = 1},
        {pos = Vector(-size, -size, -size), normal = Vector(0, -1, 0), u = 0, v = 1}
    }

    -- Build triangles from quads
    local triangles = {}
    for i = 0, 5 do -- 6 faces
        local base = i * 4 + 1
        table.insert(triangles, vertices[base])
        table.insert(triangles, vertices[base + 1])
        table.insert(triangles, vertices[base + 2])
        
        table.insert(triangles, vertices[base])
        table.insert(triangles, vertices[base + 2])
        table.insert(triangles, vertices[base + 3])
    end

    mesh:BuildFromTriangles(triangles)
    return mesh
end

function ENT:Initialize()
    self.CubeMesh = CreateCubeMesh()
    
    -- Create a stable material instance
    self.Material = CreateMaterial("HDRICube_Material_" .. self:EntIndex(), "VertexLitGeneric", {
        ["$basetexture"] = "hdri_cube/default_texture",
        ["$model"] = 1,
        ["$nocull"] = 1
    })
end

function ENT:Draw()
    -- Draw the collision model but invisible
    render.SetBlend(0)
    self:DrawModel()
    render.SetBlend(1)
    
    -- Set up rendering state
    render.SetMaterial(self.Material)
    
    -- Calculate world matrix with custom rotation
    local matrix = Matrix()
    local pos = self:GetPos()
    local customRot = self:GetCustomRotation()
    
    -- Apply custom rotation
    matrix:SetAngles(customRot)
    matrix:SetTranslation(pos)
    
    -- Set up the transformation
    cam.PushModelMatrix(matrix)
    self.CubeMesh:Draw()
    cam.PopModelMatrix()
end