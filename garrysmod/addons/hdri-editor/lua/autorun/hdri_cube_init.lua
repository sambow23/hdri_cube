print("[HDRI Cube] Loading properties")

if CLIENT then
    -- Add function to detect if the RTX functionality is available
    local rtxFunctionalityAvailable = false
    
    -- Check if we're on x64 and if the RTX functions exist
    timer.Simple(1, function()
        if not SetIgnoreGameDirectionalLights then
            print("[HDRI Editor] RTX functions not available - likely running on x32")
            rtxFunctionalityAvailable = false
        else
            -- Test the function to make sure it actually works
            local success = pcall(SetIgnoreGameDirectionalLights, false)
            rtxFunctionalityAvailable = success
            print("[HDRI Editor] RTX functions " .. (success and "available" or "unavailable"))
        end
    end)
    
    -- Create a warning dialog function
    local function ShowRTXWarning()
        -- Create a semi-transparent background
        local background = vgui.Create("DPanel")
        background:SetSize(ScrW(), ScrH())
        background:SetPos(0, 0)
        background:SetDrawOnTop(true)
        background.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 200))
        end
        
        -- Create warning panel
        local panel = vgui.Create("DFrame")
        panel:SetSize(500, 300)
        panel:Center()
        panel:SetTitle("HDRI Editor - RTX Feature Warning")
        panel:SetDraggable(true)
        panel:ShowCloseButton(true)
        panel:MakePopup()
        panel:SetDrawOnTop(true)
        
        panel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 255))
            draw.RoundedBox(8, 1, 1, w-2, h-2, Color(60, 60, 60, 255))
            draw.RoundedBox(8, 1, 1, w-2, 25, Color(50, 50, 50, 255))
        end
        
        -- Add warning text
        local text = vgui.Create("DLabel", panel)
        text:SetPos(20, 40)
        text:SetSize(460, 180)
        text:SetTextColor(Color(255, 200, 200))
        text:SetFont("DermaLarge")
        text:SetText("RTX Features Unavailable")
        text:SetContentAlignment(5) -- Center
        
        local details = vgui.Create("DLabel", panel)
        details:SetPos(20, 80)
        details:SetSize(460, 150)
        details:SetTextColor(Color(255, 255, 255))
        details:SetFont("DermaDefault")
        details:SetWrap(true)
        details:SetText(
            "You appear to be running Garry's Mod in 32-bit mode or the RTX module is not properly loaded.\n\n" ..
            "The HDRI Editor's RTX features require 64-bit Garry's Mod with the RTX Remix Fixes 2 module installed correctly.\n\n" ..
            "You can still use the HDRI Editor, but RTX-specific features like ignoring directional lights will not work."
        )
        
        -- Add an "Understand" button
        local button = vgui.Create("DButton", panel)
        button:SetPos(150, 240)
        button:SetSize(200, 40)
        button:SetText("I Understand")
        button:SetFont("DermaDefaultBold")
        
        button.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(70, 70, 70) or Color(60, 60, 60)
            draw.RoundedBox(6, 0, 0, w, h, bgColor)
            
            if self:IsHovered() then
                draw.RoundedBox(6, 0, h-3, w, 3, Color(70, 130, 180))
            end
        end
        
        button.DoClick = function()
            background:Remove()
            panel:Remove()
            -- Set a cookie to remember this warning
            cookie.Set("HDRIEditor_RTXWarningShown", "1")
        end
        
        -- Remove background when panel closes
        panel.OnClose = function()
            background:Remove()
            cookie.Set("HDRIEditor_RTXWarningShown", "1")
        end
    end
    
    -- Modified ToggleDirectionalLights function for properties/hdri_cube_editor.lua
    function ToggleDirectionalLights(shouldIgnore)
        if not rtxFunctionalityAvailable then
            -- Only show warning if we haven't shown it yet this session
            if cookie.GetNumber("HDRIEditor_RTXWarningShown", 0) == 0 then
                ShowRTXWarning()
            end
            return false
        end
        
        -- Call the native function
        local success = pcall(SetIgnoreGameDirectionalLights, shouldIgnore)
        if not success then
            -- If function fails, mark as unavailable and show warning
            rtxFunctionalityAvailable = false
            if cookie.GetNumber("HDRIEditor_RTXWarningShown", 0) == 0 then
                ShowRTXWarning()
            end
            return false
        end
        
        return true
    end
    
    local originalListSet = list.Set
    list.Set = function(listname, key, value)
        if listname == "DesktopWindows" and key == "HDRIEditor" then
            -- Intercept the HDRI Editor window creation
            local originalInit = value.init
            value.init = function(icon, window)
                -- Close the spawned window
                window:Close()
                
                -- Check if RTX is available before starting
                if not rtxFunctionalityAvailable and cookie.GetNumber("HDRIEditor_RTXWarningShown", 0) == 0 then
                    -- Show warning first
                    ShowRTXWarning()
                    -- After warning is dismissed, continue with spawning
                    hook.Add("CookiesUpdate", "HDRIEditor_ContinueAfterWarning", function()
                        if cookie.GetNumber("HDRIEditor_RTXWarningShown", 0) == 1 then
                            RunConsoleCommand("hdricube_spawn")
                            timer.Simple(0.1, function() 
                                RunConsoleCommand("hdricube_openeditor")
                            end)
                            hook.Remove("CookiesUpdate", "HDRIEditor_ContinueAfterWarning")
                        end
                    end)
                else
                    -- Continue normally
                    RunConsoleCommand("hdricube_spawn")
                    timer.Simple(0.1, function() 
                        RunConsoleCommand("hdricube_openeditor")
                    end)
                end
            end
        end
        
        return originalListSet(listname, key, value)
    end
    
    -- Add HDRI Editor to context menu (C menu)
    list.Set("DesktopWindows", "HDRIEditor", {
        title = "HDRI Editor",
        icon = "data/hdri_cache_200_80_100.png",
        init = function(icon, window)
            -- Close the spawned window since we're opening our own editor
            window:Close()
            
            -- Spawn HDRI cube under player and open editor
            RunConsoleCommand("hdricube_spawn")
            timer.Simple(0.1, function() 
                RunConsoleCommand("hdricube_openeditor")
            end)
        end
    })

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

    -- Console commands for spawning and managing the HDRI Cube
    local function SpawnHDRICube(ply)
        -- Remove existing HDRI Cube if any
        if IsValid(ply.HDRICube) then
            ply.HDRICube:Remove()
        end

        -- Spawn new HDRI Cube
        local cube = ents.Create("hdri_cube_editor")
        if IsValid(cube) then
            cube:SetPos(ply:GetPos() - Vector(0, 0, 0)) -- Position below player
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