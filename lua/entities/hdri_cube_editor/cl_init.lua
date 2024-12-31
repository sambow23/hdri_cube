include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

local materialCache = {}

local function CreateModifiedTexture(basePath, colorModification)
    local cacheKey = basePath .. "_" .. tostring(colorModification.r) .. tostring(colorModification.g) .. tostring(colorModification.b)
    
    if materialCache[cacheKey] then
        return materialCache[cacheKey]
    end

    local baseMat = Material(basePath)
    local baseTexture = baseMat:GetTexture("$basetexture")
    
    if not baseTexture then 
        print("[HDRI Cube] Error: No base texture found in", basePath)
        return baseMat 
    end

    -- Create unique name for this modification
    local textureName = "hdri_cube_modified_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    -- Create render target
    local rt = GetRenderTargetEx(
        textureName,
        baseTexture:Width(),
        baseTexture:Height(),
        RT_SIZE_LITERAL,
        MATERIAL_RT_DEPTH_NONE,
        0,
        0,
        IMAGE_FORMAT_RGBA8888
    )

    -- Now create the texture
    render.PushRenderTarget(rt)
    render.OverrideAlphaWriteEnable(true, true)
    cam.Start2D()
        render.Clear(0, 0, 0, 255)
        
        surface.SetMaterial(baseMat)
        surface.SetDrawColor(
            colorModification.r or 255,
            colorModification.g or 255,
            colorModification.b or 255,
            colorModification.a or 255
        )
        surface.DrawTexturedRect(0, 0, rt:Width(), rt:Height())
        
    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()

    -- Create a new material that uses our render target directly
    local newMat = CreateMaterial(textureName, "VertexLitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$model"] = 1,
        ["$nocull"] = 1
    })

    materialCache[cacheKey] = newMat
    print("[HDRI Cube] Created new material:", textureName)
    return newMat
end

function ENT:SetHDRIColor(color)
    if not self.CurrentTexturePath then
        self.CurrentTexturePath = "hdri_cube/default_texture"
    end
    
    local newMat = CreateModifiedTexture(self.CurrentTexturePath, color)
    if newMat then
        self.Material = newMat
        print("[HDRI Cube] Applied new color:", color.r, color.g, color.b)
    else
        print("[HDRI Cube] Failed to create modified texture!")
    end
end

function ENT:SetHDRITexture(texturePath, color)
    self.CurrentTexturePath = texturePath
    self:SetHDRIColor(color or Color(255, 255, 255, 255))
end

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