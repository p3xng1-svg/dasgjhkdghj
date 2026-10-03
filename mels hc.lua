--// MEL'S HC - Dark Solid Purple GUI (FULLY WORKING WITH SILENT AIM)
--// Paste into executor and run

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local mouse = lp:GetMouse()

--==================================================
-- SILENT AIM CONFIG
--==================================================

local cfg = {
    silentAim = true,
    useKeybind = true,
    silentAimKey = Enum.KeyCode.V,
    uiToggleKey = Enum.KeyCode.RightShift,
    silentAimHitChance = 100,
    silentAimFOV = 100,
    silentAimFOVShow = false,
    silentAimFOVFilled = false,
    silentAimFOVOpacity = 0.2,
    silentAimFOVColor = Color3.fromRGB(160, 210, 235),
    
    silentAimPart = "UpperTorso",
    silentAimClosestPart = false,
    
    silentAimTeamCheck = false,
    silentAimWallCheck = false,
    silentAimKnockCheck = false,
    silentAimMaxDist = 1000,
    
    silentAimPredX = 0,
    silentAimPredY = 0,
    
    bypassRevolver = false,
}

local whitelist = {}

-- Body parts list with "Closest Part" included
local bodyPartsList = {
    "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Closest Part"
}

--==================================================
-- FOV CIRCLE
--==================================================

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Radius = cfg.silentAimFOV
fovCircle.Color = cfg.silentAimFOVColor
fovCircle.Filled = cfg.silentAimFOVFilled
fovCircle.Visible = cfg.silentAimFOVShow
fovCircle.Transparency = 1 - cfg.silentAimFOVOpacity

local silentAimCachedPart = nil

--==================================================
-- SILENT AIM FUNCTIONS
--==================================================

local function isHoldingRevolver()
    if not cfg.bypassRevolver then return false end
    local char = lp.Character
    if not char then return false end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local toolName = string.lower(tool.Name)
        if string.find(toolName, "revolver") or string.find(toolName, "rev") then
            return true
        end
    end
    return false
end

local function getHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(p)
    local h = getHum(p)
    return h and h.Health > 0
end

local function isKnocked(p)
    if not cfg.silentAimKnockCheck then return false end
    local char = p.Character
    if not char then return false end
    
    local effects = char:FindFirstChild("Bodyeffects") or char:FindFirstChild("BodyEffects")
    if not effects then return false end
    
    local ko = effects:FindFirstChild("K.O") or effects:FindFirstChild("KO")
    local dead = effects:FindFirstChild("Dead")
    
    if ko and ko.Value == true then return true end
    if dead and dead.Value == true then return true end
    return false
end

local function sameTeam(p)
    return lp.Team and p.Team and lp.Team == p.Team
end

local function isWhitelisted(p)
    return whitelist[p.UserId] == true
end

local function wallBetween(pos)
    if not cfg.silentAimWallCheck then return false end
    local ro = cam.CFrame.Position
    local rd = pos - ro
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {lp.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(ro, rd, params)
    if not hit then return false end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and hit.Instance:IsDescendantOf(p.Character) then return false end
    end
    return true
end

local function safeWorldToViewportPoint(pos)
    local sp, on = Vector3.new(), false
    pcall(function()
        sp, on = cam:WorldToViewportPoint(pos)
    end)
    return sp, on
end

local function getClosestBodyPart(char)
    local closestPart, shortestDist = nil, math.huge
    local mousePos = UIS:GetMouseLocation()
    for _, pName in ipairs(bodyPartsList) do
        if pName == "Closest Part" then continue end
        local part = char:FindFirstChild(pName)
        if part then
            local screenPos, onScreen = safeWorldToViewportPoint(part.Position)
            local dist = onScreen and (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude or math.huge
            if dist < shortestDist then
                shortestDist = dist
                closestPart = part
            end
        end
    end
    return closestPart or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getTargetPart(char)
    if not char then return nil end
    if cfg.silentAimPart == "Closest Part" then
        return getClosestBodyPart(char)
    end
    return char:FindFirstChild(cfg.silentAimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestPlayerToCursor()
    if isHoldingRevolver() then return nil end
    
    local closestPlayer = nil
    local shortestDist = cfg.silentAimFOV
    local mousePos = UIS:GetMouseLocation()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp and isAlive(p) and not isWhitelisted(p) and not isKnocked(p) then
            if cfg.silentAimTeamCheck and sameTeam(p) then continue end
            local hrp = getHRP(p)
            if hrp then
                local dist3D = (hrp.Position - cam.CFrame.Position).Magnitude
                if dist3D <= cfg.silentAimMaxDist then
                    local sp, onScreen = safeWorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist2D = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                        if dist2D < shortestDist then
                            local part = getTargetPart(p.Character)
                            if part and not wallBetween(part.Position) then
                                shortestDist = dist2D
                                closestPlayer = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

--==================================================
-- HOOK METAMETHOD
--==================================================

local _grm = getrawmetatable(game)
local _oldIndex = _grm.__index
setreadonly(_grm, false)

_grm.__index = function(self, key)
    if not checkcaller() and self == mouse and cfg.silentAim and not isHoldingRevolver() then
        if (key == "Hit" or key == "Target" or key == "UnitRay") and silentAimCachedPart then
            if math.random(1, 100) <= cfg.silentAimHitChance then
                local origin = cam.CFrame.Position
                local hitPos = silentAimCachedPart.Position + Vector3.new(
                    silentAimCachedPart.AssemblyLinearVelocity.X * cfg.silentAimPredX,
                    silentAimCachedPart.AssemblyLinearVelocity.Y * cfg.silentAimPredY,
                    silentAimCachedPart.AssemblyLinearVelocity.Z * cfg.silentAimPredX
                )
                if key == "UnitRay" then
                    return Ray.new(origin, (hitPos - origin).Unit)
                elseif key == "Hit" then
                    return CFrame.new(hitPos)
                elseif key == "Target" then
                    return silentAimCachedPart
                end
            end
        end
    end
    return _oldIndex(self, key)
end
setreadonly(_grm, true)

--==================================================
-- UPDATE LOOP
--==================================================

RunService.RenderStepped:Connect(function()
    local mousePos = UIS:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = cfg.silentAimFOV
    fovCircle.Color = cfg.silentAimFOVColor
    fovCircle.Visible = cfg.silentAim and cfg.silentAimFOVShow and not isHoldingRevolver()

    if cfg.silentAim then
        silentAimCachedPart = getClosestPlayerToCursor()
    else
        silentAimCachedPart = nil
    end
end)

--==================================================
-- GUI SETTINGS
--==================================================

local GUI_WIDTH = 450
local GUI_HEIGHT = 315

local HOVER_SOUND_ID = "rbxassetid://9120299506"
local CLICK_SOUND_ID = "rbxassetid://113397864512278"

local PURPLE = Color3.fromRGB(20, 10, 27)
local PURPLE_LIGHT = Color3.fromRGB(27, 14, 36)
local PURPLE_SELECTED = Color3.fromRGB(55, 25, 70)
local PURPLE_BORDER = Color3.fromRGB(70, 32, 88)
local PURPLE_HOVER = Color3.fromRGB(38, 19, 48)

local WHITE = Color3.fromRGB(239, 230, 245)
local TEXT = Color3.fromRGB(205, 191, 213)

--==================================================
-- ORIGINAL FOG SNAPSHOT
--==================================================

local originalFogColor = Lighting.FogColor
local originalFogStart = Lighting.FogStart
local originalFogEnd = Lighting.FogEnd
local originalAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local originalAtmosphereFogColor = originalAtmosphere and originalAtmosphere.Color or nil
local originalAtmosphereDensity = originalAtmosphere and originalAtmosphere.Density or nil
local originalAtmosphereHaze = originalAtmosphere and originalAtmosphere.Haze or nil
local originalAtmosphereGlare = originalAtmosphere and originalAtmosphere.Glare or nil

--==================================================
-- MAIN SCRIPT
--==================================================

do

	--==================================================
	-- ORIGINAL FOG STATE
	--==================================================

	local originalFogColor = Lighting.FogColor
	local originalFogStart = Lighting.FogStart
	local originalFogEnd = Lighting.FogEnd
	local originalAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local originalAtmosphereState = nil

	if originalAtmosphere then
		originalAtmosphereState = {
			Color = originalAtmosphere.Color,
			Decay = originalAtmosphere.Decay,
			Density = originalAtmosphere.Density,
			Glare = originalAtmosphere.Glare,
			Haze = originalAtmosphere.Haze,
		}
	end

	--==================================================
	-- SCREEN GUI
	--==================================================

	local gui = Instance.new("ScreenGui")
	gui.Name = "MelsHC"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = CoreGui

	--==================================================
	-- MAIN BLOCK
	--==================================================

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.fromOffset(GUI_WIDTH, GUI_HEIGHT)
	main.Position = UDim2.new(0.5, -GUI_WIDTH / 2, 0.5, -GUI_HEIGHT / 2)
	main.BackgroundColor3 = PURPLE
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent = gui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 17)
	mainCorner.Parent = main

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = PURPLE_BORDER
	mainStroke.Thickness = 1.4
	mainStroke.Transparency = 0.18
	mainStroke.Parent = main

	--==================================================
	-- SUBTLE GLOSS
	--==================================================

	local topGloss = Instance.new("Frame")
	topGloss.Name = "TopGloss"
	topGloss.Size = UDim2.new(1, -30, 0, 2)
	topGloss.Position = UDim2.fromOffset(15, 8)
	topGloss.BackgroundColor3 = Color3.fromRGB(105, 55, 125)
	topGloss.BackgroundTransparency = 0.55
	topGloss.BorderSizePixel = 0
	topGloss.ZIndex = 10
	topGloss.Parent = main

	local glossCorner = Instance.new("UICorner")
	glossCorner.CornerRadius = UDim.new(1, 0)
	glossCorner.Parent = topGloss

	--==================================================
	-- TITLE
	--==================================================

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromOffset(250, 30)
	title.Position = UDim2.fromOffset(18, 12)
	title.BackgroundTransparency = 1
	title.Text = "MEL'S HC"
	title.TextColor3 = WHITE
	title.TextSize = 19
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 5
	title.Parent = main

	--==================================================
	-- DIVIDER
	--==================================================

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.Position = UDim2.fromOffset(16, 52)
	divider.BackgroundColor3 = Color3.fromRGB(52, 26, 65)
	divider.BorderSizePixel = 0
	divider.ZIndex = 5
	divider.Parent = main

	--==================================================
	-- SIDEBAR
	--==================================================

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.fromOffset(120, 238)
	sidebar.Position = UDim2.fromOffset(12, 64)
	sidebar.BackgroundColor3 = PURPLE
	sidebar.BorderSizePixel = 0
	sidebar.Parent = main

	--==================================================
	-- CONTENT
	--==================================================

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -145, 0, 238)
	content.Position = UDim2.fromOffset(137, 64)
	content.BackgroundColor3 = PURPLE
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.Parent = main

	local contentStroke = Instance.new("UIStroke")
	contentStroke.Color = Color3.fromRGB(55, 27, 68)
	contentStroke.Thickness = 1
	contentStroke.Transparency = 0.45
	contentStroke.Parent = content

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 12)
	contentCorner.Parent = content

	--==================================================
	-- SOUNDS
	--==================================================

	local hoverSound = Instance.new("Sound")
	hoverSound.Name = "MechanicalHover"
	hoverSound.SoundId = HOVER_SOUND_ID
	hoverSound.Volume = 0.12
	hoverSound.PlaybackSpeed = 1
	hoverSound.Parent = gui

	local clickSound = Instance.new("Sound")
	clickSound.Name = "MechanicalClick"
	clickSound.SoundId = CLICK_SOUND_ID
	clickSound.Volume = 0.22
	clickSound.PlaybackSpeed = 1
	clickSound.Parent = gui

	--==================================================
	-- TAB DATA (lowercase)
	--==================================================

	local tabNames = {
		"silent",
		"fog",
		"whitelist",
		"settings"
	}

	local buttons = {}
	local pages = {}
	local tabTransitionId = 0

	--==================================================
	-- PAGES
	--==================================================

	for i, name in ipairs(tabNames) do

		local page = Instance.new("ScrollingFrame")
		page.Name = name .. "Page"
		page.LayoutOrder = i
		page.Size = UDim2.new(1, -18, 1, -18)
		page.Position = UDim2.fromOffset(9, 9)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 2
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.ScrollBarImageColor3 = PURPLE_BORDER
		page.ScrollBarImageTransparency = 0.3
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.Visible = (i == 1)
		page.ZIndex = 3
		page.Parent = content

		pages[name] = page
	end

	--==================================================
	-- SILENT PAGE (with scrolling enabled)
	--==================================================

	local silentPage = pages["silent"]
	silentPage.ScrollingDirection = Enum.ScrollingDirection.Y
	silentPage.AutomaticCanvasSize = Enum.AutomaticSize.None

	local silentLayout = Instance.new("UIListLayout")
	silentLayout.Padding = UDim.new(0, 7)
	silentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	silentLayout.Parent = silentPage

	local silentPadding = Instance.new("UIPadding")
	silentPadding.PaddingLeft = UDim.new(0, 10)
	silentPadding.PaddingRight = UDim.new(0, 10)
	silentPadding.PaddingTop = UDim.new(0, 8)
	silentPadding.PaddingBottom = UDim.new(0, 10)
	silentPadding.Parent = silentPage

	--==================================================
	-- CREATE TOGGLE FUNCTION
	--==================================================

	local function createToggle(page, name, defaultValue, order, callback)
		local holder = Instance.new("Frame")
		holder.Name = name .. "Holder"
		holder.Size = UDim2.new(1, 0, 0, 31)
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = order
		holder.Parent = page

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -55, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = TEXT
		label.TextSize = 12
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = holder

		local switch = Instance.new("TextButton")
		switch.Name = "Switch"
		switch.Size = UDim2.fromOffset(38, 22)
		switch.Position = UDim2.new(1, -38, 0.5, -11)
		switch.BackgroundColor3 = defaultValue and PURPLE_SELECTED or PURPLE_LIGHT
		switch.BorderSizePixel = 0
		switch.Text = ""
		switch.AutoButtonColor = false
		switch.Parent = holder

		local switchCorner = Instance.new("UICorner")
		switchCorner.CornerRadius = UDim.new(1, 0)
		switchCorner.Parent = switch

		local switchStroke = Instance.new("UIStroke")
		switchStroke.Color = PURPLE_BORDER
		switchStroke.Thickness = 1
		switchStroke.Transparency = 0.4
		switchStroke.Parent = switch

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.fromOffset(16, 16)
		knob.Position = defaultValue and UDim2.new(1, -19, 0, 3) or UDim2.fromOffset(3, 3)
		knob.BackgroundColor3 = defaultValue and WHITE or Color3.fromRGB(170, 160, 175)
		knob.BorderSizePixel = 0
		knob.Parent = switch

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob

		local enabled = defaultValue

		switch.MouseEnter:Connect(function()
			hoverSound:Stop()
			hoverSound:Play()
		end)

		switch.MouseButton1Click:Connect(function()
			enabled = not enabled
			clickSound:Stop()
			clickSound:Play()

			TweenService:Create(switch, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = enabled and PURPLE_SELECTED or PURPLE_LIGHT
			}):Play()

			TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = enabled and UDim2.new(1, -19, 0, 3) or UDim2.fromOffset(3, 3),
				BackgroundColor3 = enabled and WHITE or Color3.fromRGB(170, 160, 175)
			}):Play()
			
			if callback then callback(enabled) end
		end)
		
		return {holder = holder, switch = switch, knob = knob, enabled = enabled}
	end

	--==================================================
	-- CREATE SLIDER FUNCTION
	--==================================================

	local function createSlider(page, name, minVal, maxVal, defaultVal, order, callback)
		local label = Instance.new("TextLabel")
		label.Name = name .. "Label"
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundTransparency = 1
		label.Text = name .. "     " .. tostring(defaultVal)
		label.TextColor3 = TEXT
		label.TextSize = 12
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.LayoutOrder = order
		label.Parent = page

		local slider = Instance.new("TextButton")
		slider.Name = name .. "Slider"
		slider.Size = UDim2.new(1, 0, 0, 10)
		slider.BackgroundColor3 = PURPLE_LIGHT
		slider.BorderSizePixel = 0
		slider.Text = ""
		slider.AutoButtonColor = false
		slider.LayoutOrder = order + 1
		slider.Parent = page

		local sliderCorner = Instance.new("UICorner")
		sliderCorner.CornerRadius = UDim.new(1, 0)
		sliderCorner.Parent = slider

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		local percent = (defaultVal - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(percent, 0, 1, 0)
		fill.BackgroundColor3 = PURPLE_SELECTED
		fill.BorderSizePixel = 0
		fill.Parent = slider

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Position = UDim2.new(percent, -7, 0.5, -7)
		knob.BackgroundColor3 = WHITE
		knob.BorderSizePixel = 0
		knob.ZIndex = 5
		knob.Parent = slider

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob

		local value = defaultVal
		local dragging = false

		local function updateSlider(inputX)
			local sliderPosition = slider.AbsolutePosition.X
			local sliderSize = slider.AbsoluteSize.X

			local percent = math.clamp((inputX - sliderPosition) / sliderSize, 0, 1)
			value = math.clamp(math.floor(minVal + (maxVal - minVal) * percent), minVal, maxVal)
			local visualPercent = (value - minVal) / (maxVal - minVal)

			label.Text = name .. "     " .. tostring(value)
			fill.Size = UDim2.new(visualPercent, 0, 1, 0)
			knob.Position = UDim2.new(visualPercent, -7, 0.5, -7)
			
			if callback then callback(value) end
		end

		slider.MouseButton1Down:Connect(function()
			dragging = true
			updateSlider(UIS:GetMouseLocation().X)
			clickSound:Stop()
			clickSound:Play()
		end)

		UIS.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateSlider(input.Position.X)
			end
		end)

		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
		
		return {label = label, slider = slider, fill = fill, knob = knob, value = value}
	end

	--==================================================
	-- CREATE DROPDOWN FUNCTION
	--==================================================

	local function createDropdown(page, name, options, defaultOption, order, callback)
		local label = Instance.new("TextLabel")
		label.Name = name .. "Label"
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = TEXT
		label.TextSize = 12
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.LayoutOrder = order
		label.Parent = page

		local dropdown = Instance.new("TextButton")
		dropdown.Name = name .. "Dropdown"
		dropdown.Size = UDim2.new(1, 0, 0, 34)
		dropdown.BackgroundColor3 = PURPLE_LIGHT
		dropdown.BorderSizePixel = 0
		dropdown.Text = ""
		dropdown.AutoButtonColor = false
		dropdown.LayoutOrder = order + 1
		dropdown.ZIndex = 10
		dropdown.Parent = page

		local dropdownCorner = Instance.new("UICorner")
		dropdownCorner.CornerRadius = UDim.new(0, 8)
		dropdownCorner.Parent = dropdown

		local dropdownStroke = Instance.new("UIStroke")
		dropdownStroke.Color = PURPLE_BORDER
		dropdownStroke.Thickness = 1
		dropdownStroke.Transparency = 0.45
		dropdownStroke.Parent = dropdown

		local selectedText = Instance.new("TextLabel")
		selectedText.Size = UDim2.new(1, -35, 1, 0)
		selectedText.Position = UDim2.fromOffset(12, 0)
		selectedText.BackgroundTransparency = 1
		selectedText.Text = defaultOption
		selectedText.TextColor3 = TEXT
		selectedText.TextSize = 12
		selectedText.Font = Enum.Font.GothamMedium
		selectedText.TextXAlignment = Enum.TextXAlignment.Left
		selectedText.ZIndex = 11
		selectedText.Parent = dropdown

		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.fromOffset(25, 34)
		arrow.Position = UDim2.new(1, -30, 0, 0)
		arrow.BackgroundTransparency = 1
		arrow.Text = "⌄"
		arrow.TextColor3 = TEXT
		arrow.TextSize = 16
		arrow.Font = Enum.Font.GothamBold
		arrow.ZIndex = 11
		arrow.Parent = dropdown

		local dropdownOpen = false

		local optionHolder = Instance.new("ScrollingFrame")
		optionHolder.Name = "Options"
		optionHolder.Size = UDim2.new(1, 0, 0, 0)
		optionHolder.Position = UDim2.fromOffset(0, 37)
		optionHolder.BackgroundColor3 = PURPLE_LIGHT
		optionHolder.BorderSizePixel = 0
		optionHolder.ClipsDescendants = true
		optionHolder.ScrollingDirection = Enum.ScrollingDirection.Y
		optionHolder.ScrollBarThickness = 2
		optionHolder.ScrollBarImageColor3 = PURPLE_BORDER
		optionHolder.ScrollBarImageTransparency = 0.25
		optionHolder.CanvasSize = UDim2.new(0, 0, 0, #options * 29)
		optionHolder.ZIndex = 20
		optionHolder.Parent = dropdown

		local optionCorner = Instance.new("UICorner")
		optionCorner.CornerRadius = UDim.new(0, 8)
		optionCorner.Parent = optionHolder

		local optionLayout = Instance.new("UIListLayout")
		optionLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionLayout.Parent = optionHolder

		for i, option in ipairs(options) do
			local optionButton = Instance.new("TextButton")
			optionButton.Size = UDim2.new(1, 0, 0, 29)
			optionButton.BackgroundColor3 = PURPLE_LIGHT
			optionButton.BorderSizePixel = 0
			optionButton.Text = option
			optionButton.TextColor3 = TEXT
			optionButton.TextSize = 11
			optionButton.Font = Enum.Font.GothamMedium
			optionButton.TextXAlignment = Enum.TextXAlignment.Left
			optionButton.AutoButtonColor = false
			optionButton.LayoutOrder = i
			optionButton.ZIndex = 21
			optionButton.Parent = optionHolder

			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 12)
			padding.Parent = optionButton

			optionButton.MouseEnter:Connect(function()
				TweenService:Create(optionButton, TweenInfo.new(0.1), {BackgroundColor3 = PURPLE_HOVER}):Play()
				hoverSound:Stop()
				hoverSound:Play()
			end)

			optionButton.MouseLeave:Connect(function()
				TweenService:Create(optionButton, TweenInfo.new(0.1), {BackgroundColor3 = PURPLE_LIGHT}):Play()
			end)

			optionButton.MouseButton1Click:Connect(function()
				selectedText.Text = option
				dropdownOpen = false
				arrow.Text = "⌄"
				clickSound:Stop()
				clickSound:Play()
				TweenService:Create(optionHolder, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 0)}):Play()
				if callback then callback(option) end
			end)
		end

		dropdown.MouseEnter:Connect(function()
			hoverSound:Stop()
			hoverSound:Play()
		end)

		dropdown.MouseButton1Click:Connect(function()
			dropdownOpen = not dropdownOpen
			clickSound:Stop()
			clickSound:Play()

			local visibleHeight = math.min(#options * 29, 130)
			if dropdownOpen then
				optionHolder.CanvasPosition = Vector2.new(0, 0)
			end

			TweenService:Create(
				optionHolder,
				TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{
					Size = dropdownOpen and UDim2.new(1, 0, 0, visibleHeight)
						or UDim2.new(1, 0, 0, 0)
				}
			):Play()

			arrow.Text = dropdownOpen and "⌃" or "⌄"
		end)
		
		return {label = label, dropdown = dropdown, selectedText = selectedText}
	end

	--==================================================
	-- UPDATE SILENT PAGE CANVAS
	--==================================================

	local function updateSilentCanvas()
		local contentHeight = silentLayout.AbsoluteContentSize.Y
		silentPage.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 20)
	end

	--==================================================
	-- BUILD SILENT TAB
	--==================================================

	local silentOrder = 1
	
	-- Silent Aim toggle
	createToggle(silentPage, "Silent Aim", cfg.silentAim, silentOrder, function(v) cfg.silentAim = v end)
	silentOrder = silentOrder + 1
	
	-- Show FOV toggle
	createToggle(silentPage, "Show FOV", cfg.silentAimFOVShow, silentOrder, function(v) cfg.silentAimFOVShow = v end)
	silentOrder = silentOrder + 1
	
	-- FOV Slider
	createSlider(silentPage, "FOV", 10, 1000, cfg.silentAimFOV, silentOrder, function(v) cfg.silentAimFOV = v end)
	silentOrder = silentOrder + 2
	
	-- Hit Chance Slider
	createSlider(silentPage, "Hit Chance", 1, 100, cfg.silentAimHitChance, silentOrder, function(v) cfg.silentAimHitChance = v end)
	silentOrder = silentOrder + 2
	
	-- Max Distance Slider
	createSlider(silentPage, "Max Dist", 100, 2000, cfg.silentAimMaxDist, silentOrder, function(v) cfg.silentAimMaxDist = v end)
	silentOrder = silentOrder + 2
	
	-- Hit Part Dropdown (with Closest Part included)
	createDropdown(silentPage, "Hit Part", bodyPartsList, cfg.silentAimPart, silentOrder, function(v) 
		cfg.silentAimPart = v
		cfg.silentAimClosestPart = (v == "Closest Part")
	end)
	silentOrder = silentOrder + 2
	
	-- Bypass Revolver toggle
	createToggle(silentPage, "Bypass Revolver", cfg.bypassRevolver, silentOrder, function(v) cfg.bypassRevolver = v end)
	silentOrder = silentOrder + 1
	
	-- Wall Check toggle
	createToggle(silentPage, "Wall Check", cfg.silentAimWallCheck, silentOrder, function(v) cfg.silentAimWallCheck = v end)
	silentOrder = silentOrder + 1
	
	-- Knock Check toggle
	createToggle(silentPage, "Knock Check", cfg.silentAimKnockCheck, silentOrder, function(v) cfg.silentAimKnockCheck = v end)
	silentOrder = silentOrder + 1

	-- Update canvas after building
	task.wait(0.1)
	updateSilentCanvas()

	-- Update canvas when layout changes
	silentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		updateSilentCanvas()
	end)

	--==================================================
	-- FOG PAGE
	--==================================================

	local fogPage = pages["fog"]

	local fogLayout = Instance.new("UIListLayout")
	fogLayout.Padding = UDim.new(0, 8)
	fogLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fogLayout.Parent = fogPage

	local fogPadding = Instance.new("UIPadding")
	fogPadding.PaddingLeft = UDim.new(0, 10)
	fogPadding.PaddingRight = UDim.new(0, 10)
	fogPadding.PaddingTop = UDim.new(0, 8)
	fogPadding.PaddingBottom = UDim.new(0, 10)
	fogPadding.Parent = fogPage

	local function setFogColor(color)
		Lighting.FogColor = color
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then atmosphere.Color = color end
	end

	createSlider(fogPage, "Fog Distance", 0, 2000, Lighting.FogEnd, 1, function(v)
		Lighting.FogEnd = v
		Lighting.FogStart = math.round(v * 0.1)
	end)

	local fogColorLabel = Instance.new("TextLabel")
	fogColorLabel.Size = UDim2.new(1, 0, 0, 18)
	fogColorLabel.BackgroundTransparency = 1
	fogColorLabel.Text = "Fog Color"
	fogColorLabel.TextColor3 = TEXT
	fogColorLabel.TextSize = 12
	fogColorLabel.Font = Enum.Font.GothamMedium
	fogColorLabel.TextXAlignment = Enum.TextXAlignment.Left
	fogColorLabel.LayoutOrder = 4
	fogColorLabel.Parent = fogPage

	local colorHolder = Instance.new("Frame")
	colorHolder.Size = UDim2.new(1, 0, 0, 90)
	colorHolder.BackgroundTransparency = 1
	colorHolder.LayoutOrder = 5
	colorHolder.Parent = fogPage

	local colorGrid = Instance.new("UIGridLayout")
	colorGrid.CellSize = UDim2.fromOffset(65, 28)
	colorGrid.CellPadding = UDim2.fromOffset(4, 5)
	colorGrid.SortOrder = Enum.SortOrder.LayoutOrder
	colorGrid.Parent = colorHolder

	local fogColors = {
		{Name = "Purple", Color = Color3.fromRGB(120, 50, 160)},
		{Name = "Pink", Color = Color3.fromRGB(220, 70, 150)},
		{Name = "Blue", Color = Color3.fromRGB(60, 110, 220)},
		{Name = "Green", Color = Color3.fromRGB(70, 180, 100)},
		{Name = "Red", Color = Color3.fromRGB(210, 60, 65)},
		{Name = "Yellow", Color = Color3.fromRGB(220, 190, 60)},
		{Name = "Orange", Color = Color3.fromRGB(220, 120, 50)},
		{Name = "Magenta", Color = Color3.fromRGB(255, 0, 255)},
		{Name = "White", Color = Color3.fromRGB(255, 255, 255)}
	}

	for i, colorData in ipairs(fogColors) do
		local colorButton = Instance.new("TextButton")
		colorButton.Size = UDim2.fromOffset(65, 28)
		colorButton.BackgroundColor3 = colorData.Color
		colorButton.BorderSizePixel = 0
		colorButton.Text = colorData.Name
		colorButton.TextColor3 = (colorData.Name == "Purple") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(20, 20, 30)
		colorButton.TextSize = 9
		colorButton.Font = Enum.Font.GothamMedium
		colorButton.AutoButtonColor = false
		colorButton.LayoutOrder = i
		colorButton.Parent = colorHolder

		Instance.new("UICorner", colorButton).CornerRadius = UDim.new(0, 7)

		colorButton.MouseEnter:Connect(function()
			hoverSound:Stop()
			hoverSound:Play()
			TweenService:Create(colorButton, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(67, 30)}):Play()
		end)
		colorButton.MouseLeave:Connect(function()
			TweenService:Create(colorButton, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(65, 28)}):Play()
		end)
		colorButton.MouseButton1Click:Connect(function()
			clickSound:Stop(); clickSound:Play(); setFogColor(colorData.Color)
		end)
	end

	--==================================================
	-- CUSTOM HEX COLOR
	--==================================================

	local hexLabel = Instance.new("TextLabel")
	hexLabel.Size = UDim2.new(1, 0, 0, 18)
	hexLabel.BackgroundTransparency = 1
	hexLabel.Text = "Custom Hex Color"
	hexLabel.TextColor3 = TEXT
	hexLabel.TextSize = 12
	hexLabel.Font = Enum.Font.GothamMedium
	hexLabel.TextXAlignment = Enum.TextXAlignment.Left
	hexLabel.LayoutOrder = 6
	hexLabel.Parent = fogPage

	local hexHolder = Instance.new("Frame")
	hexHolder.Size = UDim2.new(1, 0, 0, 34)
	hexHolder.BackgroundTransparency = 1
	hexHolder.LayoutOrder = 7
	hexHolder.Parent = fogPage

	local hexBox = Instance.new("TextBox")
	hexBox.Name = "HexInput"
	hexBox.Size = UDim2.new(1, -72, 0, 34)
	hexBox.BackgroundColor3 = PURPLE_LIGHT
	hexBox.BorderSizePixel = 0
	hexBox.ClearTextOnFocus = false
	hexBox.PlaceholderText = "#A855F7"
	hexBox.PlaceholderColor3 = Color3.fromRGB(125, 110, 135)
	hexBox.Text = ""
	hexBox.TextColor3 = TEXT
	hexBox.TextSize = 11
	hexBox.Font = Enum.Font.GothamMedium
	hexBox.TextXAlignment = Enum.TextXAlignment.Left
	hexBox.ZIndex = 10
	hexBox.Parent = hexHolder
	Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 8)

	local hexPadding = Instance.new("UIPadding")
	hexPadding.PaddingLeft = UDim.new(0, 12)
	hexPadding.Parent = hexBox
	local hexStroke = Instance.new("UIStroke")
	hexStroke.Color = PURPLE_BORDER
	hexStroke.Thickness = 1
	hexStroke.Transparency = 0.45
	hexStroke.Parent = hexBox

	local hexApply = Instance.new("TextButton")
	hexApply.Size = UDim2.fromOffset(64, 34)
	hexApply.Position = UDim2.new(1, -64, 0, 0)
	hexApply.BackgroundColor3 = PURPLE_LIGHT
	hexApply.BorderSizePixel = 0
	hexApply.Text = "Apply"
	hexApply.TextColor3 = WHITE
	hexApply.TextSize = 11
	hexApply.Font = Enum.Font.GothamMedium
	hexApply.AutoButtonColor = false
	hexApply.ZIndex = 10
	hexApply.Parent = hexHolder
	Instance.new("UICorner", hexApply).CornerRadius = UDim.new(0, 8)

	local hexStatus = Instance.new("TextLabel")
	hexStatus.Size = UDim2.new(1, 0, 0, 14)
	hexStatus.BackgroundTransparency = 1
	hexStatus.Text = ""
	hexStatus.TextColor3 = TEXT
	hexStatus.TextSize = 9
	hexStatus.Font = Enum.Font.GothamMedium
	hexStatus.TextXAlignment = Enum.TextXAlignment.Left
	hexStatus.LayoutOrder = 8
	hexStatus.Parent = fogPage

	local function hexToColor3(value)
		value = tostring(value or ""):gsub("%s+", ""):gsub("^#", "")
		if #value == 3 then value = value:gsub("(.)", "%1%1") end
		if #value ~= 6 or not value:match("^%x%x%x%x%x%x$") then return nil end
		return Color3.fromRGB(tonumber(value:sub(1,2),16), tonumber(value:sub(3,4),16), tonumber(value:sub(5,6),16))
	end

	local function applyHexColor()
		local color = hexToColor3(hexBox.Text)
		if not color then hexStatus.Text = "Invalid hex color"; return end
		hexStatus.Text = "Applied #" .. hexBox.Text:gsub("^#", ""):upper()
		clickSound:Stop(); clickSound:Play(); setFogColor(color)
	end
	hexBox.FocusLost:Connect(function(enterPressed) if enterPressed then applyHexColor() end end)
	hexApply.MouseEnter:Connect(function() hoverSound:Stop(); hoverSound:Play(); TweenService:Create(hexApply, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = PURPLE_HOVER}):Play() end)
	hexApply.MouseLeave:Connect(function() TweenService:Create(hexApply, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = PURPLE_LIGHT}):Play() end)
	hexApply.MouseButton1Click:Connect(applyHexColor)

	--==================================================
	-- RESET TO ORIGINAL
	--==================================================

	local resetHolder = Instance.new("Frame")
	resetHolder.Size = UDim2.new(1, 0, 0, 40)
	resetHolder.BackgroundTransparency = 1
	resetHolder.LayoutOrder = 9
	resetHolder.Parent = fogPage

	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0.6, 0, 0, 30)
	resetBtn.Position = UDim2.new(0.2, 0, 0.5, -15)
	resetBtn.BackgroundColor3 = PURPLE_LIGHT
	resetBtn.Text = "Reset To Original"
	resetBtn.TextColor3 = WHITE
	resetBtn.TextSize = 12
	resetBtn.Font = Enum.Font.GothamMedium
	resetBtn.AutoButtonColor = false
	resetBtn.Parent = resetHolder
	Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 8)
	resetBtn.MouseEnter:Connect(function() hoverSound:Stop(); hoverSound:Play(); TweenService:Create(resetBtn, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = PURPLE_HOVER}):Play() end)
	resetBtn.MouseLeave:Connect(function() TweenService:Create(resetBtn, TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = PURPLE_LIGHT}):Play() end)
	resetBtn.MouseButton1Click:Connect(function()
		clickSound:Stop(); clickSound:Play()
		Lighting.FogColor = originalFogColor
		Lighting.FogStart = originalFogStart
		Lighting.FogEnd = originalFogEnd
		if originalAtmosphere and originalAtmosphere.Parent and originalAtmosphereState then
			originalAtmosphere.Color = originalAtmosphereState.Color
			originalAtmosphere.Decay = originalAtmosphereState.Decay
			originalAtmosphere.Density = originalAtmosphereState.Density
			originalAtmosphere.Glare = originalAtmosphereState.Glare
			originalAtmosphere.Haze = originalAtmosphereState.Haze
		end
		hexBox.Text = ""
		hexStatus.Text = "Original fog restored"
	end)

	local function updateFogCanvas()
		fogPage.CanvasSize = UDim2.new(0, 0, 0, fogLayout.AbsoluteContentSize.Y + 20)
	end
	task.wait(0.1)
	updateFogCanvas()
	fogLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateFogCanvas)

	--==================================================
	-- WHITELIST PAGE
	--==================================================

	local whitelistPage = pages["whitelist"]

	local whitelistLayout = Instance.new("UIListLayout")
	whitelistLayout.Padding = UDim.new(0, 6)
	whitelistLayout.SortOrder = Enum.SortOrder.LayoutOrder
	whitelistLayout.Parent = whitelistPage

	local whitelistPadding = Instance.new("UIPadding")
	whitelistPadding.PaddingLeft = UDim.new(0, 8)
	whitelistPadding.PaddingRight = UDim.new(0, 8)
	whitelistPadding.PaddingTop = UDim.new(0, 8)
	whitelistPadding.PaddingBottom = UDim.new(0, 10)
	whitelistPadding.Parent = whitelistPage

	local whitelistTitle = Instance.new("TextLabel")
	whitelistTitle.Size = UDim2.new(1, 0, 0, 20)
	whitelistTitle.BackgroundTransparency = 1
	whitelistTitle.Text = "Players"
	whitelistTitle.TextColor3 = WHITE
	whitelistTitle.TextSize = 13
	whitelistTitle.Font = Enum.Font.GothamBold
	whitelistTitle.TextXAlignment = Enum.TextXAlignment.Left
	whitelistTitle.LayoutOrder = 1
	whitelistTitle.Parent = whitelistPage

	local whitelistStatus = Instance.new("TextLabel")
	whitelistStatus.Size = UDim2.new(1, 0, 0, 16)
	whitelistStatus.BackgroundTransparency = 1
	whitelistStatus.Text = "Click a player to whitelist"
	whitelistStatus.TextColor3 = TEXT
	whitelistStatus.TextSize = 10
	whitelistStatus.Font = Enum.Font.GothamMedium
	whitelistStatus.TextXAlignment = Enum.TextXAlignment.Left
	whitelistStatus.LayoutOrder = 2
	whitelistStatus.Parent = whitelistPage

	local playerHolder = Instance.new("Frame")
	playerHolder.Name = "PlayerHolder"
	playerHolder.Size = UDim2.new(1, 0, 0, 0)
	playerHolder.BackgroundTransparency = 1
	playerHolder.LayoutOrder = 3
	playerHolder.Parent = whitelistPage

	local playerLayout = Instance.new("UIListLayout")
	playerLayout.Padding = UDim.new(0, 5)
	playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerLayout.Parent = playerHolder

	local playerRows = {}

	local function updateWhitelistCanvas()
		local height = playerLayout.AbsoluteContentSize.Y + 60
		whitelistPage.CanvasSize = UDim2.new(0, 0, 0, height + 20)
	end

	local function createPlayerRow(targetPlayer)
		if playerRows[targetPlayer.UserId] then return end

		local row = Instance.new("TextButton")
		row.Name = "Player_" .. targetPlayer.UserId
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundColor3 = whitelist[targetPlayer.UserId] and PURPLE_SELECTED or PURPLE_LIGHT
		row.BorderSizePixel = 0
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = playerHolder

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = PURPLE_BORDER
		rowStroke.Thickness = 1
		rowStroke.Transparency = 0.55
		rowStroke.Parent = row

		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.fromOffset(28, 28)
		avatar.Position = UDim2.fromOffset(6, 6)
		avatar.BackgroundTransparency = 1
		avatar.Parent = row

		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(1, 0)
		avatarCorner.Parent = avatar

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -95, 1, 0)
		nameLabel.Position = UDim2.fromOffset(42, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = targetPlayer.DisplayName
		nameLabel.TextColor3 = TEXT
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local usernameLabel = Instance.new("TextLabel")
		usernameLabel.Size = UDim2.new(1, -95, 1, 0)
		usernameLabel.Position = UDim2.fromOffset(42, 0)
		usernameLabel.BackgroundTransparency = 1
		usernameLabel.Text = "@" .. targetPlayer.Name
		usernameLabel.TextColor3 = TEXT
		usernameLabel.TextTransparency = 0.45
		usernameLabel.TextSize = 9
		usernameLabel.Font = Enum.Font.GothamMedium
		usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
		usernameLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		usernameLabel.Parent = row

		local status = Instance.new("TextLabel")
		status.Size = UDim2.fromOffset(45, 40)
		status.Position = UDim2.new(1, -50, 0, 0)
		status.BackgroundTransparency = 1
		status.Text = whitelist[targetPlayer.UserId] and "ON" or "OFF"
		status.TextColor3 = whitelist[targetPlayer.UserId] and WHITE or TEXT
		status.TextSize = 9
		status.Font = Enum.Font.GothamBold
		status.TextXAlignment = Enum.TextXAlignment.Center
		status.Parent = row

		local function updateRow()
			local isWhitelisted = whitelist[targetPlayer.UserId] == true
			row.BackgroundColor3 = isWhitelisted and PURPLE_SELECTED or PURPLE_LIGHT
			status.Text = isWhitelisted and "ON" or "OFF"
			status.TextColor3 = isWhitelisted and WHITE or TEXT
		end

		task.defer(function()
			if not targetPlayer.Parent then return end
			local success, image = pcall(function()
				return Players:GetUserThumbnailAsync(targetPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if success and avatar.Parent then avatar.Image = image end
		end)

		row.MouseEnter:Connect(function()
			hoverSound:Stop()
			hoverSound:Play()
			if not whitelist[targetPlayer.UserId] then
				TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = PURPLE_HOVER}):Play()
			end
		end)

		row.MouseLeave:Connect(function()
			updateRow()
		end)

		row.MouseButton1Click:Connect(function()
			whitelist[targetPlayer.UserId] = not whitelist[targetPlayer.UserId]
			clickSound:Stop()
			clickSound:Play()
			updateRow()
			whitelistStatus.Text = whitelist[targetPlayer.UserId] and targetPlayer.Name .. " whitelisted" or targetPlayer.Name .. " removed"
		end)

		playerRows[targetPlayer.UserId] = row
		updateWhitelistCanvas()
	end

	local function removePlayerRow(targetPlayer)
		local row = playerRows[targetPlayer.UserId]
		if row then row:Destroy() end
		playerRows[targetPlayer.UserId] = nil
		whitelist[targetPlayer.UserId] = nil
		updateWhitelistCanvas()
	end

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= lp then
			createPlayerRow(targetPlayer)
		end
	end

	Players.PlayerAdded:Connect(function(targetPlayer)
		if targetPlayer ~= lp then
			createPlayerRow(targetPlayer)
		end
	end)

	Players.PlayerRemoving:Connect(function(targetPlayer)
		removePlayerRow(targetPlayer)
	end)

	playerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		updateWhitelistCanvas()
	end)

	--==================================================
	-- SETTINGS PAGE
	--==================================================

	local settingsPage = pages["settings"]

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.Padding = UDim.new(0, 8)
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Parent = settingsPage

	local settingsPadding = Instance.new("UIPadding")
	settingsPadding.PaddingLeft = UDim.new(0, 10)
	settingsPadding.PaddingRight = UDim.new(0, 10)
	settingsPadding.PaddingTop = UDim.new(0, 8)
	settingsPadding.PaddingBottom = UDim.new(0, 10)
	settingsPadding.Parent = settingsPage

	-- Menu Key
	local menuKeyLabel = Instance.new("TextLabel")
	menuKeyLabel.Size = UDim2.new(1, 0, 0, 18)
	menuKeyLabel.BackgroundTransparency = 1
	menuKeyLabel.Text = "Menu Key"
	menuKeyLabel.TextColor3 = TEXT
	menuKeyLabel.TextSize = 12
	menuKeyLabel.Font = Enum.Font.GothamMedium
	menuKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
	menuKeyLabel.LayoutOrder = 1
	menuKeyLabel.Parent = settingsPage

	local menuKeyButton = Instance.new("TextButton")
	menuKeyButton.Name = "MenuKey"
	menuKeyButton.Size = UDim2.new(1, 0, 0, 34)
	menuKeyButton.BackgroundColor3 = PURPLE_LIGHT
	menuKeyButton.BorderSizePixel = 0
	menuKeyButton.Text = ""
	menuKeyButton.AutoButtonColor = false
	menuKeyButton.LayoutOrder = 2
	menuKeyButton.Parent = settingsPage

	local menuKeyCorner = Instance.new("UICorner")
	menuKeyCorner.CornerRadius = UDim.new(0, 8)
	menuKeyCorner.Parent = menuKeyButton

	local menuKeyStroke = Instance.new("UIStroke")
	menuKeyStroke.Color = PURPLE_BORDER
	menuKeyStroke.Thickness = 1
	menuKeyStroke.Transparency = 0.45
	menuKeyStroke.Parent = menuKeyButton

	local selectedKey = Enum.KeyCode.RightShift
	local listeningForKey = false

	local menuKeyText = Instance.new("TextLabel")
	menuKeyText.Size = UDim2.new(1, -24, 1, 0)
	menuKeyText.Position = UDim2.fromOffset(12, 0)
	menuKeyText.BackgroundTransparency = 1
	menuKeyText.Text = "Right Shift"
	menuKeyText.TextColor3 = TEXT
	menuKeyText.TextSize = 12
	menuKeyText.Font = Enum.Font.GothamMedium
	menuKeyText.TextXAlignment = Enum.TextXAlignment.Left
	menuKeyText.Parent = menuKeyButton

	menuKeyButton.MouseEnter:Connect(function()
		hoverSound:Stop()
		hoverSound:Play()
	end)

	menuKeyButton.MouseButton1Click:Connect(function()
		listeningForKey = true
		menuKeyText.Text = "Press a key..."
		menuKeyText.TextColor3 = Color3.fromRGB(180, 150, 195)
		clickSound:Stop()
		clickSound:Play()
	end)

	-- V Key (Silent Aim Toggle)
	local vKeyLabel = Instance.new("TextLabel")
	vKeyLabel.Size = UDim2.new(1, 0, 0, 18)
	vKeyLabel.BackgroundTransparency = 1
	vKeyLabel.Text = "Toggle Aim Key"
	vKeyLabel.TextColor3 = TEXT
	vKeyLabel.TextSize = 12
	vKeyLabel.Font = Enum.Font.GothamMedium
	vKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
	vKeyLabel.LayoutOrder = 3
	vKeyLabel.Parent = settingsPage

	local vKeyButton = Instance.new("TextButton")
	vKeyButton.Name = "VKey"
	vKeyButton.Size = UDim2.new(1, 0, 0, 34)
	vKeyButton.BackgroundColor3 = PURPLE_LIGHT
	vKeyButton.BorderSizePixel = 0
	vKeyButton.Text = ""
	vKeyButton.AutoButtonColor = false
	vKeyButton.LayoutOrder = 4
	vKeyButton.Parent = settingsPage

	local vKeyCorner = Instance.new("UICorner")
	vKeyCorner.CornerRadius = UDim.new(0, 8)
	vKeyCorner.Parent = vKeyButton

	local vKeyStroke = Instance.new("UIStroke")
	vKeyStroke.Color = PURPLE_BORDER
	vKeyStroke.Thickness = 1
	vKeyStroke.Transparency = 0.45
	vKeyStroke.Parent = vKeyButton

	local vKeyText = Instance.new("TextLabel")
	vKeyText.Size = UDim2.new(1, -24, 1, 0)
	vKeyText.Position = UDim2.fromOffset(12, 0)
	vKeyText.BackgroundTransparency = 1
	vKeyText.Text = "V"
	vKeyText.TextColor3 = TEXT
	vKeyText.TextSize = 12
	vKeyText.Font = Enum.Font.GothamMedium
	vKeyText.TextXAlignment = Enum.TextXAlignment.Left
	vKeyText.Parent = vKeyButton

	local listeningForVKey = false

	vKeyButton.MouseEnter:Connect(function()
		hoverSound:Stop()
		hoverSound:Play()
	end)

	vKeyButton.MouseButton1Click:Connect(function()
		listeningForVKey = true
		vKeyText.Text = "Press a key..."
		vKeyText.TextColor3 = Color3.fromRGB(180, 150, 195)
		clickSound:Stop()
		clickSound:Play()
	end)

	-- Update settings canvas
	local function updateSettingsCanvas()
		local totalHeight = 0
		for _, child in pairs(settingsPage:GetChildren()) do
			if child:IsA("Frame") then
				totalHeight = totalHeight + child.Size.Y.Offset + 8
			end
		end
		settingsPage.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
	end

	task.wait(0.1)
	updateSettingsCanvas()
	settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		updateSettingsCanvas()
	end)

	--==================================================
	-- KEYBIND LISTENER
	--==================================================

	UserInputService.InputBegan:Connect(function(input, processed)
		if listeningForKey then
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
				selectedKey = input.KeyCode
				listeningForKey = false
				cfg.uiToggleKey = selectedKey
				menuKeyText.Text = selectedKey.Name
				menuKeyText.TextColor3 = TEXT
				clickSound:Stop()
				clickSound:Play()
				return
			end
		end

		if listeningForVKey then
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
				cfg.silentAimKey = input.KeyCode
				listeningForVKey = false
				vKeyText.Text = input.KeyCode.Name
				vKeyText.TextColor3 = TEXT
				clickSound:Stop()
				clickSound:Play()
				return
			end
		end

		if processed then return end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == selectedKey then
				main.Visible = not main.Visible
			end
			if cfg.useKeybind and input.KeyCode == cfg.silentAimKey then
				cfg.silentAim = not cfg.silentAim
			end
		end
	end)

	--==================================================
	-- PLAYER PROFILE
	--==================================================

	local profile = Instance.new("Frame")
	profile.Name = "Profile"
	profile.Size = UDim2.fromOffset(112, 48)
	profile.Position = UDim2.fromOffset(5, 260)
	profile.BackgroundTransparency = 1
	profile.ZIndex = 7
	profile.Parent = main

	local profileAvatar = Instance.new("ImageLabel")
	profileAvatar.Name = "Avatar"
	profileAvatar.Size = UDim2.fromOffset(36, 36)
	profileAvatar.Position = UDim2.fromOffset(0, 6)
	profileAvatar.BackgroundTransparency = 1
	profileAvatar.Parent = profile

	local profileCorner = Instance.new("UICorner")
	profileCorner.CornerRadius = UDim.new(1, 0)
	profileCorner.Parent = profileAvatar

	local profileName = Instance.new("TextLabel")
	profileName.Size = UDim2.new(1, -42, 0, 19)
	profileName.Position = UDim2.fromOffset(43, 5)
	profileName.BackgroundTransparency = 1
	profileName.Text = lp.DisplayName
	profileName.TextColor3 = WHITE
	profileName.TextSize = 11
	profileName.Font = Enum.Font.GothamBold
	profileName.TextXAlignment = Enum.TextXAlignment.Left
	profileName.TextTruncate = Enum.TextTruncate.AtEnd
	profileName.Parent = profile

	local profileUsername = Instance.new("TextLabel")
	profileUsername.Size = UDim2.new(1, -42, 0, 17)
	profileUsername.Position = UDim2.fromOffset(43, 23)
	profileUsername.BackgroundTransparency = 1
	profileUsername.Text = "@" .. lp.Name
	profileUsername.TextColor3 = TEXT
	profileUsername.TextTransparency = 0.35
	profileUsername.TextSize = 9
	profileUsername.Font = Enum.Font.GothamMedium
	profileUsername.TextXAlignment = Enum.TextXAlignment.Left
	profileUsername.TextTruncate = Enum.TextTruncate.AtEnd
	profileUsername.Parent = profile

	task.defer(function()
		local success, image = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if success and profileAvatar.Parent then profileAvatar.Image = image end
	end)

	--==================================================
	-- TAB LAYOUT
	--==================================================

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0, 7)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = sidebar

	--==================================================
	-- TABS (lowercase)
	--==================================================

	for i, name in ipairs(tabNames) do

		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(120, 42)
		button.BackgroundColor3 = (i == 1) and PURPLE_SELECTED or PURPLE_LIGHT
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.LayoutOrder = i
		button.ZIndex = 4
		button.Parent = sidebar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = PURPLE_BORDER
		stroke.Thickness = 1
		stroke.Transparency = 0.58
		stroke.Parent = button

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -20, 1, 0)
		text.Position = UDim2.fromOffset(11, 0)
		text.BackgroundTransparency = 1
		text.Text = name  -- lowercase
		text.TextColor3 = TEXT
		text.TextSize = 12
		text.Font = Enum.Font.GothamMedium
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.ZIndex = 5
		text.Parent = button

		local indicator = Instance.new("Frame")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.fromOffset(2, 22)
		indicator.Position = UDim2.new(0, 0, 0.5, -11)
		indicator.BackgroundColor3 = Color3.fromRGB(145, 75, 175)
		indicator.BorderSizePixel = 0
		indicator.Visible = (i == 1)
		indicator.ZIndex = 6
		indicator.Parent = button

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(1, 0)
		indicatorCorner.Parent = indicator

		button:SetAttribute("Selected", i == 1)
		buttons[name] = button

		button.MouseEnter:Connect(function()
			if not button:GetAttribute("Selected") then
				TweenService:Create(button, TweenInfo.new(0.11), {BackgroundColor3 = PURPLE_HOVER}):Play()
			end
			hoverSound:Stop()
			hoverSound:Play()
		end)

		button.MouseLeave:Connect(function()
			if not button:GetAttribute("Selected") then
				TweenService:Create(button, TweenInfo.new(0.11), {BackgroundColor3 = PURPLE_LIGHT}):Play()
			end
		end)

		button.MouseButton1Click:Connect(function()
			clickSound:Stop()
			clickSound:Play()

			for _, otherButton in pairs(buttons) do
				otherButton:SetAttribute("Selected", false)
				TweenService:Create(otherButton, TweenInfo.new(0.12), {BackgroundColor3 = PURPLE_LIGHT}):Play()
				local otherIndicator = otherButton:FindFirstChild("Indicator")
				if otherIndicator then otherIndicator.Visible = false end
			end

			button:SetAttribute("Selected", true)
			TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = PURPLE_SELECTED}):Play()
			indicator.Visible = true

			tabTransitionId = tabTransitionId + 1
			local thisTransition = tabTransitionId

			local currentPage = nil
			for pageName, page in pairs(pages) do
				if page.Visible then
					currentPage = page
					break
				end
			end

			local nextPage = pages[name]
			if currentPage ~= nextPage then
				local direction = 1
				if currentPage and currentPage.LayoutOrder > nextPage.LayoutOrder then
					direction = -1
				end

				local pageOffset = 10 * direction

				if currentPage then
					local oldPosition = currentPage.Position
					TweenService:Create(
						currentPage,
						TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{Position = UDim2.new(0, 9 - pageOffset, 0, 9)}
					):Play()

					task.delay(0.045, function()
						if thisTransition ~= tabTransitionId then return end
						currentPage.Visible = false
						currentPage.Position = oldPosition
					end)
				end

				nextPage.Visible = true
				nextPage.Position = UDim2.new(0, 9 + pageOffset, 0, 9)

				TweenService:Create(
					nextPage,
					TweenInfo.new(0.085, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{Position = UDim2.fromOffset(9, 9)}
				):Play()
			end
		end)
	end

	--==================================================
	-- DRAGGING
	--==================================================

	local dragging = false
	local dragStart
	local startPosition

	local dragArea = Instance.new("Frame")
	dragArea.Name = "DragArea"
	dragArea.Size = UDim2.new(1, -150, 0, 52)
	dragArea.Position = UDim2.fromOffset(0, 0)
	dragArea.BackgroundTransparency = 1
	dragArea.ZIndex = 20
	dragArea.Parent = main

	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPosition = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)

	--==================================================
	-- OPENING ANIMATION
	--==================================================

	main.Size = UDim2.fromOffset(430, 300)

	TweenService:Create(
		main,
		TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromOffset(450, 315),
			Position = UDim2.new(0.5, -GUI_WIDTH / 2, 0.5, -GUI_HEIGHT / 2)
		}
	):Play()

end

print("")
print("═══════════════════════════════════════════")
print("  ✧ MEL'S HC - Dark Purple GUI")
print("═══════════════════════════════════════════")
print("  ✅ Silent Aim - All options working")
print("  ✅ FOV Circle Display")
print("  ✅ 16 Body Parts + Closest Part")
print("  ✅ Fog Tab with 10 Preset Colors")
print("  ✅ Whitelist System - Click players")
print("  ✅ Knock Check - No shooting downed")
print("  ✅ Wall Check - No shooting through walls")
print("  ✅ Revolver Bypass")
print("  ✅ Max FOV: 1000")
print("  ✅ Right Shift to toggle menu")
print("  ✅ V to toggle aim")
print("═══════════════════════════════════════════")