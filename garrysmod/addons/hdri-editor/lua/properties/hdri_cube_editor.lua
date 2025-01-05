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
-- Editor Panel creation
local function CreateEditorPanel(ent)
    if IsValid(HDRI_EditorPanel) then
        HDRI_EditorPanel:SetVisible(true)
        HDRI_EditorPanel:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    HDRI_EditorPanel = frame
    frame:SetSize(300, 700) -- Increased height to accommodate animator
    frame:SetTitle("HDRI Cube Editor")
    frame:SetDraggable(true)  -- Enable dragging
    frame:SetSizable(true)
    frame:SetDeleteOnClose(true)
    frame:ShowCloseButton(true)  -- Ensure close button is visible
    frame:SetMinHeight(700) -- Set minimum height to ensure controls don't get cramped
    frame:SetMinWidth(300)  -- Set minimum width to maintain layout
    
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

    -- Create scroll panel to handle overflow
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(0, 0, 0, 0)

    -- Create main container panel
    local container = vgui.Create("DPanel", scroll)
    container:Dock(TOP)
    container:DockMargin(0, 0, 0, 0)
    container:SetTall(800) -- Make it taller than needed to accommodate all elements

    -- Create container for rotation controls
    local rotationPanel = vgui.Create("DPanel", container)
    rotationPanel:Dock(TOP)
    rotationPanel:SetTall(120)
    rotationPanel:DockMargin(5, 5, 5, 5)

    -- Label
    local rotLabel = vgui.Create("DLabel", rotationPanel)
    rotLabel:SetText("Rotation")
    rotLabel:SetPos(5, 5)
    rotLabel:SetSize(290, 20)
    rotLabel:SetTextColor(Color(0, 0, 0))

    -- Create number inputs for each axis
    local function CreateAxisControl(axis, y, default)
        local label = vgui.Create("DLabel", rotationPanel)
        label:SetText(axis)
        label:SetPos(5, y)
        label:SetSize(20, 20)
        label:SetTextColor(Color(0, 0, 0))

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
    local colorMixer = vgui.Create("DColorMixer", container)
    colorMixer:Dock(TOP)
    colorMixer:SetTall(200)
    colorMixer:SetAlphaBar(true)
    colorMixer:SetPalette(true)
    colorMixer:SetColor(Color(255, 255, 255, 255))
    
    -- Add color apply button
    local applyColor = vgui.Create("DButton", container)
    applyColor:Dock(TOP)
    applyColor:SetText("Apply Color")
    applyColor:DockMargin(5, 5, 5, 5)
    applyColor:SetTall(30)
    applyColor.DoClick = function()
        local color = colorMixer:GetColor()
        ent:SetHDRIColor(color)
    end
    
    -- Add preset buttons
    local presetPanel = vgui.Create("DPanel", container)
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
    local resetButton = vgui.Create("DButton", container)
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

    -- Animator Panel
    local animatorPanel = vgui.Create("DPanel", container)
    animatorPanel:Dock(TOP)
    animatorPanel:SetTall(180)
    animatorPanel:DockMargin(5, 5, 5, 5)
    
    -- Animator Label
    local animLabel = vgui.Create("DLabel", animatorPanel)
    animLabel:SetText("Rotation Animator")
    animLabel:SetPos(5, 5)
    animLabel:SetSize(290, 20)
    animLabel:SetTextColor(Color(0, 0, 0))
    
    -- Create animator controls for each axis
    local function CreateAxisAnimator(axis, y)
        local container = vgui.Create("DPanel", animatorPanel)
        container:SetPos(5, y)
        container:SetSize(280, 45)
        
        local label = vgui.Create("DLabel", container)
        label:SetText(axis)
        label:SetPos(5, 2)
        label:SetSize(20, 20)
        label:SetTextColor(Color(0, 0, 0))
        
        -- Start value
        local startLabel = vgui.Create("DLabel", container)
        startLabel:SetText("Start")
        startLabel:SetPos(30, 2)
        startLabel:SetSize(30, 20)
        startLabel:SetTextColor(Color(0, 0, 0))
        
        local startValue = vgui.Create("DNumberWang", container)
        startValue:SetPos(65, 2)
        startValue:SetSize(40, 20)
        startValue:SetMinMax(0, 360)
        startValue:SetValue(0)
        
        -- End value
        local endLabel = vgui.Create("DLabel", container)
        endLabel:SetText("End")
        endLabel:SetPos(115, 2)
        endLabel:SetSize(30, 20)
        endLabel:SetTextColor(Color(0, 0, 0))
        
        local endValue = vgui.Create("DNumberWang", container)
        endValue:SetPos(145, 2)
        endValue:SetSize(40, 20)
        endValue:SetMinMax(0, 360)
        endValue:SetValue(360)
        
        -- Speed control
        local speedLabel = vgui.Create("DLabel", container)
        speedLabel:SetText("Speed")
        speedLabel:SetPos(195, 2)
        speedLabel:SetSize(35, 20)
        speedLabel:SetTextColor(Color(0, 0, 0))
        
        local speedValue = vgui.Create("DNumberWang", container)
        speedValue:SetPos(235, 2)
        speedValue:SetSize(40, 20)
        speedValue:SetMinMax(0.1, 10)
        speedValue:SetDecimals(1)
        speedValue:SetValue(1.0)
        
        -- Enable checkbox
        local enableBox = vgui.Create("DCheckBox", container)
        enableBox:SetPos(5, 25)
        enableBox:SetValue(false)
        
        local enableLabel = vgui.Create("DLabel", container)
        enableLabel:SetText("Enable " .. axis .. " Axis Animation")
        enableLabel:SetPos(25, 25)
        enableLabel:SetSize(150, 20)
        enableLabel:SetTextColor(Color(0, 0, 0))
        
        return {
            start = startValue,
            finish = endValue,
            speed = speedValue,
            enabled = enableBox,
            current = 0,
            direction = 1
        }
    end
    
    local animators = {
        x = CreateAxisAnimator("X", 30),
        y = CreateAxisAnimator("Y", 80),
        z = CreateAxisAnimator("Z", 130)
    }
    
    -- Animation control buttons
    local controlsPanel = vgui.Create("DPanel", animatorPanel)
    controlsPanel:SetPos(5, 155)
    controlsPanel:SetSize(280, 25)
    
    local startAllBtn = vgui.Create("DButton", controlsPanel)
    startAllBtn:SetPos(5, 2)
    startAllBtn:SetSize(80, 20)
    startAllBtn:SetText("Start All")
    
    local stopAllBtn = vgui.Create("DButton", controlsPanel)
    stopAllBtn:SetPos(95, 2)
    stopAllBtn:SetSize(80, 20)
    stopAllBtn:SetText("Stop All")
    stopAllBtn:SetEnabled(false)
    
    local isAnimating = false
    local animationTimer = nil
    
    local function UpdateAnimation()
        if not IsValid(ent) or not IsValid(frame) then
            if timer.Exists("HDRICube_Animation") then
                timer.Remove("HDRICube_Animation")
            end
            return
        end
    
        local anyEnabled = false
        local newAngles = Angle(
            xRot:GetValue(),
            yRot:GetValue(),
            zRot:GetValue()
        )
    
        for axis, animator in pairs(animators) do
            if animator.enabled:GetChecked() then
                anyEnabled = true
                local start = animator.start:GetValue()
                local finish = animator.finish:GetValue()
                local speed = animator.speed:GetValue()
                
                animator.current = animator.current + (speed * animator.direction)
                
                local value
                if animator.direction == 1 and animator.current >= finish then
                    animator.direction = -1
                    value = finish
                elseif animator.direction == -1 and animator.current <= start then
                    animator.direction = 1
                    value = start
                else
                    value = animator.current
                end
                
                if axis == "x" then
                    newAngles.p = value
                    xRot:SetValue(value)
                elseif axis == "y" then
                    newAngles.y = value
                    yRot:SetValue(value)
                elseif axis == "z" then
                    newAngles.r = value
                    zRot:SetValue(value)
                end
            end
        end
    
        if anyEnabled then
            net.Start("HDRICube_UpdateRotation")
                net.WriteEntity(ent)
                net.WriteAngle(newAngles)
            net.SendToServer()
        else
            timer.Remove("HDRICube_Animation")
            isAnimating = false
            startAllBtn:SetEnabled(true)
            stopAllBtn:SetEnabled(false)
        end
    end
    
    startAllBtn.DoClick = function()
        if isAnimating then return end
        
        -- Initialize current values
        for axis, animator in pairs(animators) do
            if animator.enabled:GetChecked() then
                animator.current = animator.start:GetValue()
                animator.direction = 1
            end
        end
        
        timer.Create("HDRICube_Animation", 0.016, 0, UpdateAnimation) -- ~60fps
        isAnimating = true
        startAllBtn:SetEnabled(false)
        stopAllBtn:SetEnabled(true)
    end
    
    stopAllBtn.DoClick = function()
        if timer.Exists("HDRICube_Animation") then
            timer.Remove("HDRICube_Animation")
        end
        isAnimating = false
        startAllBtn:SetEnabled(true)
        stopAllBtn:SetEnabled(false)
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