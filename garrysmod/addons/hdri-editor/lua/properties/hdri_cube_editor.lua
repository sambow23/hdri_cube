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

    -- Create themed frame
    local frame = vgui.Create("DFrame")
    HDRI_EditorPanel = frame
    frame:SetSize(360, 500)
    frame:SetTitle("HDRI Editor")
    frame:SetDraggable(true)
    frame:SetSizable(true)
    frame:SetDeleteOnClose(true)
    frame:ShowCloseButton(true)
    frame:SetMinHeight(500)
    frame:SetMinWidth(350)

    -- Custom paint function for better appearance
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 255))
        draw.RoundedBox(8, 1, 1, w-2, h-2, Color(60, 60, 60, 255))
        draw.RoundedBox(8, 1, 1, w-2, 25, Color(50, 50, 50, 255))
    end

    -- Set position
    if lastPos then
        frame:SetPos(lastPos.x, lastPos.y)
    else
        local x, y = gui.MouseX(), gui.MouseY()
        frame:SetPos(math.min(x, ScrW() - frame:GetWide()), math.min(y, ScrH() - frame:GetTall()))
    end

    frame.OnScreenSizeChanged = function(self)
        lastPos = { x = self:GetX(), y = self:GetY() }
    end

    -- Create scroll panel with custom paint
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 5, 5)

    -- Custom scrollbar
    local sbar = scroll:GetVBar()
    sbar:SetWide(8)
    sbar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 100)) end
    sbar.btnUp.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60)) end
    sbar.btnDown.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60)) end
    sbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70)) end

    -- Main container
    local container = vgui.Create("DPanel", scroll)
    container:Dock(TOP)
    container:DockMargin(5, 5, 5, 5)
    container:SetTall(730)
    container.Paint = function(_, w, h) 
        draw.RoundedBox(6, 0, 0, w, h, Color(45, 45, 45, 255))
    end

    -- Section creation helper
    local function CreateSection(parent, title, height)
        local section = vgui.Create("DPanel", parent)
        section:Dock(TOP)
        section:SetTall(height)
        section:DockMargin(5, 5, 5, 5)
        
        section.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(35, 35, 35, 255))
            draw.SimpleText(title, "DermaDefaultBold", 10, 5, Color(200, 200, 200))
        end

        -- Create content panel with padding for title
        local content = vgui.Create("DPanel", section)
        content:Dock(FILL)
        content:DockMargin(5, 25, 5, 5)
        content.Paint = function() end

        return content
    end

    -- Rotation Controls Section
    local rotContent = CreateSection(container, "Rotation Controls", 140)
    
    -- Enhanced axis control creation
    local function CreateAxisControl(parent, axis, y, default)
        local container = vgui.Create("DPanel", parent)
        container:Dock(TOP)
        container:DockMargin(5, 5, 5, 0)
        container:SetTall(30)
        container.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40))
        end
    
        local label = vgui.Create("DLabel", container)
        label:SetText(axis)
        label:SetTextColor(Color(200, 200, 200))
        label:SetPos(10, 8)
        label:SetSize(20, 20)
    
        local numSlider = vgui.Create("DNumSlider", container)
        numSlider:SetPos(30, -2)
        numSlider:SetSize(280, 20)
        numSlider:SetMin(0)
        numSlider:SetMax(360)
        numSlider:SetDecimals(1)
        numSlider:SetValue(default or 0)
        numSlider:SetDark(false)
    
        -- Style the label and wang
        if numSlider.Label then
            numSlider.Label:SetTextColor(Color(200, 200, 200))
        end
        if numSlider.TextArea then
            numSlider.TextArea:SetTextColor(Color(200, 200, 200))
        end
    
        -- Custom slider paint
        numSlider.Slider.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, h/2-2, w, 4, Color(30, 30, 30))
        end
        
        numSlider.Slider.Knob.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 180))
        end
    
        return numSlider
    end

    local currentRot = ent:GetCustomRotation()
    local xRot = CreateAxisControl(rotContent, "X", 30, currentRot.p)
    local yRot = CreateAxisControl(rotContent, "Y", 60, currentRot.y)
    local zRot = CreateAxisControl(rotContent, "Z", 90, currentRot.r)

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

    xRot.OnValueChanged = UpdateRotation
    yRot.OnValueChanged = UpdateRotation
    zRot.OnValueChanged = UpdateRotation

    -- Color Control Section
    local colorContent = CreateSection(container, "HDRI Presets", 190) -- Increased height for two rows
    
    local presetPanel = vgui.Create("DPanel", colorContent)
    presetPanel:Dock(FILL)
    presetPanel:DockMargin(10, 10, 10, 10)
    presetPanel.Paint = function() end

    local presets = {
        ["1"] = {color = Color(255, 255, 255, 255)},
        ["2"] = {color = Color(255, 200, 150, 255)},
        ["3"] = {color = Color(150, 200, 255, 255)},
        ["4"] = {color = Color(100, 100, 150, 255)},
        ["5"] = {color = Color(200, 60, 150, 255)},
        ["6"] = {color = Color(210, 160, 150, 255)},
        ["7"] = {color = Color(200, 80, 100, 255)},
        ["8"] = {color = Color(255, 100, 40, 255)},
    }

    -- Calculate button size based on panel width
    presetPanel.PerformLayout = function(self, w, h)
        local buttonsPerRow = 4
        local margin = 5
        local totalMargins = margin * (buttonsPerRow - 1)
        local buttonSize = (w - totalMargins) / buttonsPerRow
        
        -- Position buttons
        for i, btn in pairs(self:GetChildren()) do
            local col = (i - 1) % buttonsPerRow
            local row = math.floor((i - 1) / buttonsPerRow)
            
            local x = col * (buttonSize + margin)
            local y = row * (buttonSize + margin)
            
            btn:SetPos(x, y)
            btn:SetSize(buttonSize, buttonSize)
        end
    end

    for name, data in pairs(presets) do
        local btn = vgui.Create("DButton", presetPanel)
        btn:SetText("")
        
        btn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(60, 60, 60) or Color(50, 50, 50)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            
            -- Draw color preview
            draw.RoundedBox(4, 2, 2, w-4, h-4, data.color)
            
            if self:IsHovered() then
                draw.RoundedBox(4, 0, h-2, w, 2, Color(70, 130, 180))
            end
        end

        btn.DoClick = function()
            ent:SetHDRIColor(data.color)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
    end

    -- Animation Section
    local animContent = CreateSection(container, "Animation Controls", 380)
    local buttonPanel = vgui.Create("DPanel", animContent)
    local isAnimating = false
    local startAllBtn, stopAllBtn

    -- Create axis animator function
    local function CreateAxisAnimator(parent, axis)
        local container = vgui.Create("DPanel", parent)
        container:Dock(TOP)
        container:DockMargin(5, 5, 5, 5)
        container:SetTall(90)
        container.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40))
        end

        -- Title and checkbox row
        local titleRow = vgui.Create("DPanel", container)
        titleRow:Dock(TOP)
        titleRow:SetTall(20)
        titleRow:DockMargin(10, 5, 10, 0)
        titleRow.Paint = function() end

        local enableBox = vgui.Create("DCheckBox", titleRow)
        enableBox:Dock(RIGHT)
        enableBox:SetWide(20)
        enableBox:SetValue(false)

        local title = vgui.Create("DLabel", titleRow)
        title:SetText(axis .. " Axis Animation")
        title:SetTextColor(Color(200, 200, 200))
        title:Dock(FILL)

        -- Controls row with better spacing
        local controlsRow = vgui.Create("DPanel", container)
        controlsRow:Dock(FILL)
        controlsRow:DockMargin(10, 5, 10, 5)
        controlsRow.Paint = function() end

        -- Create input with label
        local function CreateControl(text, defaultVal, xPos, decimals)
            local group = vgui.Create("DPanel", controlsRow)
            group:SetPos(xPos, 0)
            group:SetSize(80, 45)
            group.Paint = function() end

            local label = vgui.Create("DLabel", group)
            label:SetText(text)
            label:SetTextColor(Color(200, 200, 200))
            label:Dock(TOP)
            label:SetTall(20)

            local input = vgui.Create("DNumberWang", group)
            input:Dock(TOP)
            input:SetTall(20)
            input:SetMin(0)
            input:SetMax(decimals and 10 or 360)
            input:SetDecimals(decimals and 1 or 0)
            input:SetValue(defaultVal)
            input:SetTextColor(Color(200, 200, 200))
            input.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
                self:DrawTextEntryText(Color(200, 200, 200), Color(70, 130, 180), Color(200, 200, 200))
            end

            return input
        end

        local startValue = CreateControl("Start", 0, 0)
        local endValue = CreateControl("End", 360, 95)
        local speedValue = CreateControl("Speed", 0.1, 190, true)

        -- Add checkbox change handler
        enableBox.OnChange = function(_, value)
            if value then
                -- Start animation for this axis
                if not isAnimating then
                    startAllBtn:DoClick()
                end
            end
        end

        return {
            start = startValue,
            finish = endValue,
            speed = speedValue,
            enabled = enableBox,
            current = 0
        }
    end

    -- Create button helper function
    local function CreateAnimButton(text, dock, onClick)
        local btn = vgui.Create("DButton", buttonPanel)
        btn:SetText(text)
        btn:DockMargin(2, 0, 2, 0)
        
        if dock == "left" then
            btn:Dock(LEFT)
        elseif dock == "right" then
            btn:Dock(RIGHT)
        else
            btn:Dock(FILL)
        end
        
        btn:SetWide(80)
        
        btn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(60, 60, 60) or Color(50, 50, 50)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            
            if self:IsHovered() then
                draw.RoundedBox(4, 0, h-2, w, 2, Color(70, 130, 180))
            end
        end

        btn.DoClick = onClick
        return btn
    end

    -- Create animators for each axis
    local animators = {
        x = CreateAxisAnimator(animContent, "X"),
        y = CreateAxisAnimator(animContent, "Y"),
        z = CreateAxisAnimator(animContent, "Z")
    }

    -- Setup button panel
    buttonPanel:Dock(BOTTOM)
    buttonPanel:SetTall(40)
    buttonPanel:DockMargin(5, 5, 5, 5)
    buttonPanel.Paint = function() end

    -- Animation start function
    local function StartAnimation()
        if isAnimating then return end
        
        -- Initialize current values
        for axis, animator in pairs(animators) do
            if animator.enabled:GetChecked() then
                animator.current = animator.start:GetValue()
            end
        end
        
        timer.Create("HDRICube_Animation", 0.016, 0, function()
            if not IsValid(ent) or not IsValid(frame) then
                timer.Remove("HDRICube_Animation")
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
                    
                    animator.current = animator.current + speed
                    
                    if animator.current >= finish then
                        animator.current = start + (animator.current - finish)
                    end
                    
                    if axis == "x" then
                        newAngles.p = animator.current
                        xRot:SetValue(animator.current)
                    elseif axis == "y" then
                        newAngles.y = animator.current
                        yRot:SetValue(animator.current)
                    elseif axis == "z" then
                        newAngles.r = animator.current
                        zRot:SetValue(animator.current)
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
        end)
        
        isAnimating = true
        startAllBtn:SetEnabled(false)
        stopAllBtn:SetEnabled(true)
        surface.PlaySound("ui/buttonclickrelease.wav")
    end

    -- Create control buttons
    startAllBtn = CreateAnimButton("Start All", "left", StartAnimation)
    stopAllBtn = CreateAnimButton("Stop All", "right", function()
        if timer.Exists("HDRICube_Animation") then
            timer.Remove("HDRICube_Animation")
        end
        isAnimating = false
        startAllBtn:SetEnabled(true)
        stopAllBtn:SetEnabled(false)
        
        -- Uncheck all checkboxes
        for _, animator in pairs(animators) do
            animator.enabled:SetValue(false)
        end
        
        surface.PlaySound("ui/buttonclickrelease.wav")
    end)
    stopAllBtn:SetEnabled(false)

    -- Create Reset button
    local resetBtn = CreateAnimButton("Reset All Rotations", "center", function()
        xRot:SetValue(0)
        yRot:SetValue(0)
        zRot:SetValue(0)
        UpdateRotation()
        surface.PlaySound("ui/buttonclickrelease.wav")
    end)
    resetBtn:DockMargin(5, 0, 5, 0)

    frame:MakePopup()

    -- Add fade in animation
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.2, 0)

    -- Monitor visibility and validity
    hook.Add("Think", "HDRICubeEditor_Monitor", function()
        if not IsValid(frame) then
            hook.Remove("Think", "HDRICubeEditor_Monitor")
            return
        end

        frame:SetVisible(input.IsKeyDown(KEY_C))
        
        if not IsValid(ent) then
            frame:Remove()
            HDRI_EditorPanel = nil
            lastPos = nil
            hook.Remove("Think", "HDRICubeEditor_Monitor")
        end
    end)
end

net.Receive("HDRICube_OpenEditor", function()
    local ent = net.ReadEntity()
    if IsValid(ent) then
        CreateEditorPanel(ent)
    end
end)

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