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
end

include("properties/hdri_cube_editor.lua")

if SERVER then
    util.AddNetworkString("HDRICube_OpenEditor")
    util.AddNetworkString("HDRICube_UpdateTexture")
end

-- Create materials directory if it doesn't exist
if not file.Exists("materials/hdri_cube", "GAME") then
    file.CreateDir("materials/hdri_cube")
end