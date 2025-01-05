include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

local materialCache = {}
local rtCache = {} -- Initialize the rtCache table
local STATIC_RT_PREFIX = "hdri_static_rt_"

_G.HDRICube_CleanupRenderTargets = function()
    local success, err = pcall(CleanupRenderTargets)
    if not success then
        DebugLog("Error during cleanup:", err)
    end
end

net.Receive("HDRICube_Cleanup", function()
    local ent = net.ReadEntity()
    if IsValid(ent) and ent.CubeMesh then
        ent.CubeMesh:Destroy()
        ent.CubeMesh = nil
    end
end)

local function CleanupMaterials()
    -- Clean up any materials created with CreateMaterial
    for name, material in pairs(materialCache) do
        if name:StartWith("HDRICube_") then
            if type(material) == "IMaterial" and material.Destroy then
                material:Destroy()
                DebugLog("Destroyed material:", name)
            end
        end
    end

    -- Clean up any GetRenderTarget textures that might be lingering
    for rtName, rt in pairs(rtCache) do
        if rt and type(rt) == "ITexture" then
            -- Safety check for render.ReleaseRenderTarget
            if render and render.ReleaseRenderTarget then
                local success, err = pcall(function()
                    render.ReleaseRenderTarget(rt)
                end)
                if success then
                    DebugLog("Released RT:", rtName)
                else
                    DebugLog("Failed to release RT:", rtName, err)
                end
            else
                DebugLog("render.ReleaseRenderTarget not available")
            end
        end
    end
end

local function DebugLog(...)
    local args = {...}
    local str = "[HDRI Debug] "
    for i, v in ipairs(args) do
        str = str .. tostring(v) .. " "
    end
    print(str)
end

local function GetStaticRTName(color)
    -- Create a completely static name based only on color values
    return string.format("%s%d_%d_%d", 
        STATIC_RT_PREFIX,
        math.floor(color.r or 255),
        math.floor(color.g or 255),
        math.floor(color.b or 255)
    )
end

local function CleanupRenderTargets()
    DebugLog("Starting full HDRI cleanup")
    
    -- Safety check for render context
    if render and render.GetRenderTarget then
        local currentRT = render.GetRenderTarget()
        if currentRT then
            render.SetRenderTarget(nil)
            DebugLog("Reset render target")
        end
    end
    
    -- Cleanup materials first
    pcall(CleanupMaterials)
    
    -- Make sure we're not in the middle of rendering
    if render and render.SetRenderTarget then
        render.SetRenderTarget(nil)
    end
    
    -- Clear both caches safely
    if materialCache then
        table.Empty(materialCache)
    end
    if rtCache then
        table.Empty(rtCache)
    end
    
    -- Force garbage collection
    collectgarbage("collect")
    
    -- Remove hooks safely
    if hook and hook.Remove then
        hook.Remove("Think", "HDRICubeEditor_Monitor")
        hook.Remove("PostRender", "HDRICube_RenderUpdate")
    end
    
    -- Clear any pending timers safely
    if timer and timer.Remove then
        timer.Remove("HDRICube_UpdateTimer")
    end
    
    DebugLog("Cleanup completed")
end

-- Make cleanup function globally accessible
_G.HDRICube_CleanupRenderTargets = CleanupRenderTargets

local function CreateModifiedTexture(basePath, colorModification)
    local rtName = GetStaticRTName(colorModification)
    DebugLog("Creating texture for", rtName)
    
    if materialCache[rtName] then
        DebugLog("Found cached material for", rtName)
        return materialCache[rtName]
    end

    local baseMat = Material(basePath)
    local baseTexture = baseMat:GetTexture("$basetexture")
    
    if not baseTexture then 
        DebugLog("Error: No base texture found in", basePath)
        return baseMat 
    end

    -- Create render target
    local rt = GetRenderTargetEx(
        rtName,
        baseTexture:Width(),
        baseTexture:Height(),
        RT_SIZE_LITERAL,
        MATERIAL_RT_DEPTH_NONE,
        0,
        0,
        IMAGE_FORMAT_RGBA8888
    )
    
    -- Store render target in cache
    rtCache[rtName] = rt

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

    -- Create a new material with deterministic name
    local newMat = CreateMaterial(rtName, "VertexLitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$model"] = 1,
        ["$nocull"] = 1
    })

    materialCache[rtName] = newMat
    print("[HDRI Cube] Created new material:", rtName)
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
    
    -- Create a stable material instance with safety check
    local matName = "HDRICube_Material_" .. self:EntIndex()
    self.Material = Material(matName) -- Check if it already exists
    
    if not self.Material or self.Material:IsError() then
        self.Material = CreateMaterial(matName, "VertexLitGeneric", {
            ["$basetexture"] = "hdri_cube/default_texture",
            ["$model"] = 1,
            ["$nocull"] = 1
        })
    end
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

function ENT:OnRemove()
    local success, err = pcall(function()
        if self.CubeMesh and type(self.CubeMesh) == "IMesh" then
            self.CubeMesh:Destroy()
            self.CubeMesh = nil
        end
        
        if self.Material and type(self.Material) == "IMaterial" and self.Material.Destroy then
            self.Material:Destroy()
            self.Material = nil
        end
        
        -- Cleanup any entity-specific render targets
        local entityRTs = {}
        for rtName, rt in pairs(rtCache) do
            if rtName:find(tostring(self:EntIndex())) then
                table.insert(entityRTs, rtName)
            end
        end
        
        for _, rtName in ipairs(entityRTs) do
            if rtCache[rtName] and render and render.ReleaseRenderTarget then
                pcall(function()
                    render.ReleaseRenderTarget(rtCache[rtName])
                    rtCache[rtName] = nil
                end)
            end
        end
    end)
    
    if not success then
        DebugLog("Error during entity cleanup:", err)
    end
end