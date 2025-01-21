print("[HDRI Cube] Loading properties")

if CLIENT then
    -- Force immediate cleanup before loading anything else
    timer.Simple(0, function()
        if _G.HDRICube_CleanupRenderTargets then
            local success, err = pcall(_G.HDRICube_CleanupRenderTargets)
            if not err then
                print("[HDRI Cube] Initial cleanup completed")
            else
                print("[HDRI Cube] Cleanup error:", err)
            end
        end
    end)

    -- Common cleanup function
    local function SafeCleanup()
        if _G.HDRICube_CleanupRenderTargets then
            pcall(_G.HDRICube_CleanupRenderTargets)
        end
        if CleanupEditorPanel then
            pcall(CleanupEditorPanel)
        end
    end

    -- Add cleanup hooks with error handling
    local hooks = {
        "ShutDown",
        "GMODPreReload",
        "OnReloadGamemode",
        "PreGamemodeLoaded",
        "OnDisconnectFromServer",
        "PreSaveGMAItem"
    }

    for _, hookName in ipairs(hooks) do
        hook.Add(hookName, "HDRICube_Cleanup_" .. hookName, SafeCleanup)
    end

    hook.Add("PopulateToolMenu", "HDRICube_AddMenuSettings", function()
        spawnmenu.AddToolMenuOption("Utilities", "HDRI Cube", "HDRICubeSettings", "Settings", "", "", function(panel)
            panel:ClearControls()
            
            -- Enable/Disable auto-spawn
            panel:CheckBox("Auto-spawn on join", "hdricube_autospawn")
            
            -- Button to spawn manually
            panel:Button("Spawn HDRI Cube", "hdricube_spawn")
            
            -- Button to open editor
            panel:Button("Open Editor", "hdricube_openeditor")
            
            -- Add help text
            panel:Help("The HDRI Cube will follow below your feet when spawned.")
        end)
    end)

    -- Create ConVars
    CreateClientConVar("hdricube_autospawn", "1", true, false, "Auto-spawn HDRI Cube on join")
end

include("properties/hdri_cube_editor.lua")

if SERVER then
    util.AddNetworkString("HDRICube_OpenEditor")
    util.AddNetworkString("HDRICube_UpdateTexture")

    -- Console commands for spawning and managing the HDRI Cube
    local function SpawnHDRICube(ply)
        -- Remove existing HDRI Cube if any
        if IsValid(ply.HDRICube) then
            ply.HDRICube:Remove()
        end

        -- Spawn new HDRI Cube
        local cube = ents.Create("hdri_cube_editor")
        if IsValid(cube) then
            cube:SetPos(ply:GetPos() - Vector(0, 0, 100)) -- Position below player
            cube:SetAngles(Angle(0, 0, 0))
            cube:Spawn()
            cube:SetParent(ply)
            
            -- Disable collision
            local phys = cube:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableCollisions(false)
            end
            
            -- Store reference to cube
            ply.HDRICube = cube
        end
    end

    concommand.Add("hdricube_spawn", function(ply)
        if IsValid(ply) then
            SpawnHDRICube(ply)
        end
    end)

    concommand.Add("hdricube_openeditor", function(ply)
        if IsValid(ply) and IsValid(ply.HDRICube) then
            net.Start("HDRICube_OpenEditor")
                net.WriteEntity(ply.HDRICube)
            net.Send(ply)
        end
    end)

    -- Hook for auto-spawning
    hook.Add("PlayerInitialSpawn", "HDRICube_AutoSpawn", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) and ply:GetInfoNum("hdricube_autospawn", 1) == 1 then
                SpawnHDRICube(ply)
            end
        end)
    end)

    -- Cleanup hook
    hook.Add("PlayerDisconnected", "HDRICube_Cleanup", function(ply)
        if IsValid(ply.HDRICube) then
            ply.HDRICube:Remove()
        end
    end)
end

-- Create materials directory if it doesn't exist
if not file.Exists("materials/hdri_cube", "GAME") then
    file.CreateDir("materials/hdri_cube")
end