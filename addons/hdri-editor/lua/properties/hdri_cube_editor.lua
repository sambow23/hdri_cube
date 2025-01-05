local HDRI_EditorPanel = nil
local lastPos = nil -- Store the last position

local function CleanupEditorPanel()
    if IsValid(HDRI_EditorPanel) then
        -- Remove any active hooks
        hook.Remove("Think", "HDRICubeEditor_Monitor")
        
        -- Store last position before removal
        lastPos = {
            x = HDRI_EditorPanel:GetX(),
            y = HDRI_EditorPanel:GetY()
        }
        
        -- Remove the panel
        HDRI_EditorPanel:Remove()
        HDRI_EditorPanel = nil
    end
end

-- Editor Panel creation
local function CreateEditorPanel(ent)
    if IsValid(HDRI_EditorPanel) then
        HDRI_EditorPanel:SetVisible(true)
        HDRI_EditorPanel:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    HDRI_EditorPanel = frame
    frame:SetSize(300, 500)
    frame:SetTitle("HDRI Cube Editor")
    frame:SetDraggable(true)  -- Enable dragging
    frame:SetSizable(true)
    frame:SetDeleteOnClose(true)
    frame:ShowCloseButton(true)  -- Ensure close button is visible
    
    -- Set position: use last known position or default to cursor position
    if lastPos then
        frame:SetPos(lastPos.x, lastPos.y)
    else
        local x, y = gui.MouseX(), gui.MouseY()
        frame:SetPos(math.min(x, ScrW() - frame:GetWide()), math.min(y, ScrH() - frame:GetTall()))
    end

    -- Store position when moved
    frame.OnScreenSizeChanged = function(self)
        lastPos = { x = self:GetX(), y = self:GetY() }
    end

    -- Create container for rotation controls
    local rotationPanel = vgui.Create("DPanel", frame)
    rotationPanel:Dock(TOP)
    rotationPanel:SetTall(120)
    rotationPanel:DockMargin(5, 5, 5, 5)

    -- Label
    local rotLabel = vgui.Create("DLabel", rotationPanel)
    rotLabel:SetText("Rotation")
    rotLabel:SetPos(5, 5)
    rotLabel:SetSize(290, 20)
    rotLabel:SetTextColor(Color(255, 255, 255))

    -- Create number inputs for each axis
    local function CreateAxisControl(axis, y, default)
        local label = vgui.Create("DLabel", rotationPanel)
        label:SetText(axis)
        label:SetPos(5, y)
        label:SetSize(20, 20)
        label:SetTextColor(Color(255, 255, 255))

        local numSlider = vgui.Create("DNumSlider", rotationPanel)
        numSlider:SetPos(25, y - 2)
        numSlider:SetSize(260, 20)
        numSlider:SetMin(0)
        numSlider:SetMax(360)
        numSlider:SetDecimals(1)
        numSlider:SetValue(default or 0)
        
        numSlider.OnMouseWheeled = function(self, delta)
            local shift = input.IsKeyDown(KEY_LSHIFT)
            local ctrl = input.IsKeyDown(KEY_LCONTROL)
            local amt = (shift and 0.1) or (ctrl and 10) or 1
            self:SetValue(self:GetValue() + delta * amt)
        end

        return numSlider
    end

    local currentRot = ent:GetCustomRotation()
    local xRot = CreateAxisControl("X", 30, currentRot.p)
    local yRot = CreateAxisControl("Y", 60, currentRot.y)
    local zRot = CreateAxisControl("Z", 90, currentRot.r)

    -- Update function
    local function UpdateRotation()
        if not IsValid(ent) then 
            frame:Remove()
            HDRI_EditorPanel = nil
            lastPos = nil
            return 
        end
        
        local newAng = Angle(xRot:GetValue(), yRot:GetValue(), zRot:GetValue())
        net.Start("HDRICube_UpdateRotation")
            net.WriteEntity(ent)
            net.WriteAngle(newAng)
        net.SendToServer()
    end

    -- Add value change callbacks
    xRot.OnValueChanged = function() UpdateRotation() end
    yRot.OnValueChanged = function() UpdateRotation() end
    zRot.OnValueChanged = function() UpdateRotation() end

    -- Create color mixer
    local colorMixer = vgui.Create("DColorMixer", frame)
    colorMixer:Dock(TOP)
    colorMixer:SetTall(200)
    colorMixer:SetAlphaBar(true)
    colorMixer:SetPalette(true)
    colorMixer:SetColor(Color(255, 255, 255, 255))
    
    -- Add color apply button
    local applyColor = vgui.Create("DButton", frame)
    applyColor:Dock(TOP)
    applyColor:SetText("Apply Color")
    applyColor:DockMargin(5, 5, 5, 5)
    applyColor:SetTall(30)
    applyColor.DoClick = function()
        local color = colorMixer:GetColor()
        ent:SetHDRIColor(color)
    end
    
    -- Add preset buttons
    local presetPanel = vgui.Create("DPanel", frame)
    presetPanel:Dock(TOP)
    presetPanel:SetTall(100)
    presetPanel:DockMargin(5, 5, 5, 5)
    
    local presets = {
        ["Default"] = Color(255, 255, 255, 255),
        ["Warm"] = Color(255, 200, 150, 255),
        ["Cool"] = Color(150, 200, 255, 255),
        ["Night"] = Color(100, 100, 150, 255)
    }
    
    for name, color in pairs(presets) do
        local btn = vgui.Create("DButton", presetPanel)
        btn:Dock(LEFT)
        btn:SetText(name)
        btn:DockMargin(5, 5, 5, 5)
        btn:SetWide(60)
        btn.DoClick = function()
            print("[HDRI Color Debug] Applying preset:", name, 
                  "R:", color.r, 
                  "G:", color.g, 
                  "B:", color.b)
            colorMixer:SetColor(color)
            ent:SetHDRIColor(color)
        end
    end

    -- Reset button
    local resetButton = vgui.Create("DButton", frame)
    resetButton:Dock(TOP)
    resetButton:SetText("Reset Rotation")
    resetButton:DockMargin(5, 5, 5, 5)
    resetButton:SetTall(30)
    resetButton.DoClick = function()
        xRot:SetValue(0)
        yRot:SetValue(0)
        zRot:SetValue(0)
        UpdateRotation()
    end

    frame:MakePopup()
    
    -- Single Think hook for both visibility and validity
    hook.Add("Think", "HDRICubeEditor_Monitor", function()
        if not IsValid(frame) then
            hook.Remove("Think", "HDRICubeEditor_Monitor")
            return
        end

        -- Update visibility based on C key
        frame:SetVisible(input.IsKeyDown(KEY_C))
        
        -- Check entity validity
        if not IsValid(ent) then
            frame:Remove()
            HDRI_EditorPanel = nil
            lastPos = nil
            hook.Remove("Think", "HDRICubeEditor_Monitor")
        end
    end)
end

-- HDRI Cube Editor Property
properties.Add("hdricube_editor", {
    MenuLabel = "Open HDRI Editor",
    MenuIcon = "icon16/color_wheel.png",
    Order = 100,
    
    Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        if not IsValid(ply) then return false end
        if ent:GetClass() != "hdri_cube_editor" then return false end
        return true
    end,
    
    Action = function(self, ent)
        RunConsoleCommand("-menu_context")
        if IsValid(HDRI_EditorPanel) then
            HDRI_EditorPanel:SetVisible(true)
            HDRI_EditorPanel:MakePopup()
        else
            CreateEditorPanel(ent)
        end
    end
})

-- Clean up hook on entity removal
hook.Add("EntityRemoved", "HDRICubeEditor_Cleanup", function(ent)
    if IsValid(HDRI_EditorPanel) and ent:GetClass() == "hdri_cube_editor" then
        HDRI_EditorPanel:Remove()
        HDRI_EditorPanel = nil
        hook.Remove("Think", "HDRICubeEditor_Monitor")
    end
end)

hook.Add("VGUIFinished", "HDRICube_CleanupUI", CleanupEditorPanel)