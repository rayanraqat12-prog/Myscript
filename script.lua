--[[
    Galaxy Teleporter GUI with Advanced Features (Cosmic Cube Minimize)
    --------------------------------------------------------------------
    Features:
      - Save positions & teleport (instant, smooth, realistic)
      - Fly (adjustable speed)
      - Advanced anti‑cheat noclip
      - Invisible mode
      - WalkSpeed control
      - Drag the window around
      - Minimize to a cosmic cube with a dark green "S"
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- ============ STATE ============
local savedPositions = {}
local selectedIndex = nil
local currentTab = "teleporter"
local teleportMethod = "instant"

-- Fly state
local isFlying = false
local flySpeed = 50
local flyBody = nil
local flyBodyVelocity = nil
local flyConnection = nil

-- Noclip state
local isNoclipping = false
local noclipSpeed = 25
local originalCollisionGroups = {}
local noclipConnection = nil

-- Invisible state
local isInvisible = false
local originalCharacterParts = {}

-- Helper function for clamp
local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- ============ GUI SETUP ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyTeleporterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- ============ MAIN WINDOW (Full View) ============
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 380, 0, 420)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 45)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(45, 15, 75)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 20, 60)),
})
gradient.Rotation = 45
gradient.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(150, 100, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.3
stroke.Parent = mainFrame

-- Scattered stars inside main window
local function addStar(parent, xScale, yScale, size, brightness)
    local star = Instance.new("Frame")
    star.Size = UDim2.new(0, size, 0, size)
    star.Position = UDim2.new(xScale, 0, yScale, 0)
    star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    star.BackgroundTransparency = 1 - brightness
    star.BorderSizePixel = 0
    star.ZIndex = 1
    star.Parent = parent

    local starCorner = Instance.new("UICorner")
    starCorner.CornerRadius = UDim.new(1, 0)
    starCorner.Parent = star

    task.spawn(function()
        while star.Parent do
            local t1 = TweenService:Create(star, TweenInfo.new(math.random(10, 25) / 10), {BackgroundTransparency = 1})
            t1:Play()
            t1.Completed:Wait()
            local t2 = TweenService:Create(star, TweenInfo.new(math.random(10, 25) / 10), {BackgroundTransparency = 1 - brightness})
            t2:Play()
            t2.Completed:Wait()
        end
    end)
end

math.randomseed(tick())
for i = 1, 16 do
    addStar(mainFrame, math.random(0, 100) / 100, math.random(0, 100) / 100, math.random(1, 3), math.random(40, 90) / 100)
end

-- ============ TITLE BAR ============
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 15, 55)
titleBar.BackgroundTransparency = 0.2
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 16)
titleCorner.Parent = titleBar

local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 16)
titleBarFix.Position = UDim2.new(0, 0, 1, -16)
titleBarFix.BackgroundColor3 = titleBar.BackgroundColor3
titleBarFix.BackgroundTransparency = titleBar.BackgroundTransparency
titleBarFix.BorderSizePixel = 0
titleBarFix.ZIndex = 2
titleBarFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ Galaxy Teleporter"
titleLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3
titleLabel.Active = true
titleLabel.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 28, 0, 28)
minimizeButton.Position = UDim2.new(1, -34, 0.5, -14)
minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 30, 100)
minimizeButton.Text = "–"
minimizeButton.TextColor3 = Color3.fromRGB(230, 210, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 16
minimizeButton.ZIndex = 3
minimizeButton.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0)
minCorner.Parent = minimizeButton

-- ============ MAIN CONTENT FRAME ============
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -30)
contentFrame.Position = UDim2.new(0, 0, 0, 30)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame

-- ============ SIDE TAB BAR (Left Side) ============
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(0, 90, 1, 0)
tabBar.Position = UDim2.new(0, 0, 0, 0)
tabBar.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 2
tabBar.Parent = contentFrame

local tabBarStroke = Instance.new("UIStroke")
tabBarStroke.Color = Color3.fromRGB(100, 70, 180)
tabBarStroke.Transparency = 0.5
tabBarStroke.Parent = tabBar

local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 16)
tabBarCorner.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.FillDirection = Enum.FillDirection.Vertical
tabLayout.Parent = tabBar

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingTop = UDim.new(0, 6)
tabPadding.PaddingBottom = UDim.new(0, 6)
tabPadding.PaddingLeft = UDim.new(0, 4)
tabPadding.PaddingRight = UDim.new(0, 4)
tabPadding.Parent = tabBar

-- Teleporter Tab Button
local teleporterTabBtn = Instance.new("TextButton")
teleporterTabBtn.Name = "TeleporterTab"
teleporterTabBtn.Size = UDim2.new(1, 0, 0, 35)
teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
teleporterTabBtn.Text = "🏠\nTP"
teleporterTabBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
teleporterTabBtn.Font = Enum.Font.GothamBold
teleporterTabBtn.TextSize = 10
teleporterTabBtn.AutoButtonColor = false
teleporterTabBtn.ZIndex = 3
teleporterTabBtn.LayoutOrder = 1
teleporterTabBtn.Parent = tabBar

local teleporterTabCorner = Instance.new("UICorner")
teleporterTabCorner.CornerRadius = UDim.new(0, 8)
teleporterTabCorner.Parent = teleporterTabBtn

local teleporterTabStroke = Instance.new("UIStroke")
teleporterTabStroke.Color = Color3.fromRGB(150, 100, 255)
teleporterTabStroke.Transparency = 0.3
teleporterTabStroke.Parent = teleporterTabBtn

-- Misc Tab Button
local miscTabBtn = Instance.new("TextButton")
miscTabBtn.Name = "MiscTab"
miscTabBtn.Size = UDim2.new(1, 0, 0, 35)
miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
miscTabBtn.Text = "⭐\nMisc"
miscTabBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
miscTabBtn.Font = Enum.Font.GothamBold
miscTabBtn.TextSize = 10
miscTabBtn.AutoButtonColor = false
miscTabBtn.ZIndex = 3
miscTabBtn.LayoutOrder = 2
miscTabBtn.Parent = tabBar

local miscTabCorner = Instance.new("UICorner")
miscTabCorner.CornerRadius = UDim.new(0, 8)
miscTabCorner.Parent = miscTabBtn

local miscTabStroke = Instance.new("UIStroke")
miscTabStroke.Color = Color3.fromRGB(100, 70, 180)
miscTabStroke.Transparency = 0.5
miscTabStroke.Parent = miscTabBtn

-- ============ BODY (Right Side) ============
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, -90, 1, 0)
bodyFrame.Position = UDim2.new(0, 90, 0, 0)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ZIndex = 2
bodyFrame.Parent = contentFrame

-- ============ TELEPORTER TAB ============
local teleporterTab = Instance.new("Frame")
teleporterTab.Name = "TeleporterTab"
teleporterTab.Size = UDim2.new(1, 0, 1, 0)
teleporterTab.BackgroundTransparency = 1
teleporterTab.ZIndex = 3
teleporterTab.Parent = bodyFrame
teleporterTab.Visible = true

local teleporterScroll = Instance.new("ScrollingFrame")
teleporterScroll.Size = UDim2.new(1, 0, 1, 0)
teleporterScroll.BackgroundTransparency = 1
teleporterScroll.ScrollBarThickness = 4
teleporterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
teleporterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
teleporterScroll.ZIndex = 3
teleporterScroll.Parent = teleporterTab

local teleporterLayout = Instance.new("UIListLayout")
teleporterLayout.Padding = UDim.new(0, 4)
teleporterLayout.SortOrder = Enum.SortOrder.LayoutOrder
teleporterLayout.Parent = teleporterScroll

local teleporterScrollPadding = Instance.new("UIPadding")
teleporterScrollPadding.PaddingTop = UDim.new(0, 6)
teleporterScrollPadding.PaddingBottom = UDim.new(0, 6)
teleporterScrollPadding.PaddingLeft = UDim.new(0, 6)
teleporterScrollPadding.PaddingRight = UDim.new(0, 6)
teleporterScrollPadding.Parent = teleporterScroll

-- Name input box
local nameBox = Instance.new("TextBox")
nameBox.Name = "NameBox"
nameBox.Size = UDim2.new(1, 0, 0, 22)
nameBox.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
nameBox.PlaceholderText = "Name..."
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(230, 220, 255)
nameBox.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 10
nameBox.ClearTextOnFocus = false
nameBox.ZIndex = 3
nameBox.LayoutOrder = 1
nameBox.Parent = teleporterScroll

local nameBoxCorner = Instance.new("UICorner")
nameBoxCorner.CornerRadius = UDim.new(0, 6)
nameBoxCorner.Parent = nameBox

local nameBoxStroke = Instance.new("UIStroke")
nameBoxStroke.Color = Color3.fromRGB(120, 90, 200)
nameBoxStroke.Transparency = 0.4
nameBoxStroke.Parent = nameBox

-- Save button
local saveButton = Instance.new("TextButton")
saveButton.Name = "SaveButton"
saveButton.Size = UDim2.new(1, 0, 0, 24)
saveButton.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
saveButton.Text = "✦ Save"
saveButton.TextColor3 = Color3.fromRGB(240, 230, 255)
saveButton.Font = Enum.Font.GothamBold
saveButton.TextSize = 10
saveButton.AutoButtonColor = false
saveButton.ZIndex = 3
saveButton.LayoutOrder = 2
saveButton.Parent = teleporterScroll

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 6)
saveCorner.Parent = saveButton

local saveGradient = Instance.new("UIGradient")
saveGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 40, 150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 20, 90)),
})
saveGradient.Rotation = 90
saveGradient.Parent = saveButton

-- Teleport Method Label
local methodLabel = Instance.new("TextLabel")
methodLabel.Size = UDim2.new(1, 0, 0, 12)
methodLabel.BackgroundTransparency = 1
methodLabel.Text = "Method: " .. teleportMethod
methodLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
methodLabel.Font = Enum.Font.GothamBold
methodLabel.TextSize = 8
methodLabel.TextXAlignment = Enum.TextXAlignment.Left
methodLabel.ZIndex = 3
methodLabel.LayoutOrder = 3
methodLabel.Parent = teleporterScroll

-- Method Selection Buttons Container
local methodButtonsContainer = Instance.new("Frame")
methodButtonsContainer.Size = UDim2.new(1, 0, 0, 20)
methodButtonsContainer.BackgroundTransparency = 1
methodButtonsContainer.ZIndex = 3
methodButtonsContainer.LayoutOrder = 4
methodButtonsContainer.Parent = teleporterScroll

local methodLayout = Instance.new("UIListLayout")
methodLayout.Padding = UDim.new(0, 2)
methodLayout.SortOrder = Enum.SortOrder.LayoutOrder
methodLayout.FillDirection = Enum.FillDirection.Horizontal
methodLayout.Parent = methodButtonsContainer

-- Method buttons
local instantMethodBtn = Instance.new("TextButton")
instantMethodBtn.Name = "InstantMethod"
instantMethodBtn.Size = UDim2.new(0.33, -1.33, 1, 0)
instantMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
instantMethodBtn.Text = "Inst"
instantMethodBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
instantMethodBtn.Font = Enum.Font.GothamBold
instantMethodBtn.TextSize = 8
instantMethodBtn.AutoButtonColor = false
instantMethodBtn.ZIndex = 3
instantMethodBtn.LayoutOrder = 1
instantMethodBtn.Parent = methodButtonsContainer

local instantCorner = Instance.new("UICorner")
instantCorner.CornerRadius = UDim.new(0, 5)
instantCorner.Parent = instantMethodBtn

local tweenMethodBtn = Instance.new("TextButton")
tweenMethodBtn.Name = "TweenMethod"
tweenMethodBtn.Size = UDim2.new(0.33, -1.33, 1, 0)
tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
tweenMethodBtn.Text = "Smth"
tweenMethodBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
tweenMethodBtn.Font = Enum.Font.GothamBold
tweenMethodBtn.TextSize = 8
tweenMethodBtn.AutoButtonColor = false
tweenMethodBtn.ZIndex = 3
tweenMethodBtn.LayoutOrder = 2
tweenMethodBtn.Parent = methodButtonsContainer

local tweenCorner = Instance.new("UICorner")
tweenCorner.CornerRadius = UDim.new(0, 5)
tweenCorner.Parent = tweenMethodBtn

local realisticMethodBtn = Instance.new("TextButton")
realisticMethodBtn.Name = "RealisticMethod"
realisticMethodBtn.Size = UDim2.new(0.33, -1.33, 1, 0)
realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
realisticMethodBtn.Text = "Real"
realisticMethodBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
realisticMethodBtn.Font = Enum.Font.GothamBold
realisticMethodBtn.TextSize = 8
realisticMethodBtn.AutoButtonColor = false
realisticMethodBtn.ZIndex = 3
realisticMethodBtn.LayoutOrder = 3
realisticMethodBtn.Parent = methodButtonsContainer

local realisticCorner = Instance.new("UICorner")
realisticCorner.CornerRadius = UDim.new(0, 5)
realisticCorner.Parent = realisticMethodBtn

-- Menu label
local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 12)
menuLabel.BackgroundTransparency = 1
menuLabel.Text = "Positions"
menuLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
menuLabel.Font = Enum.Font.GothamBold
menuLabel.TextSize = 9
menuLabel.TextXAlignment = Enum.TextXAlignment.Left
menuLabel.ZIndex = 3
menuLabel.LayoutOrder = 5
menuLabel.Parent = teleporterScroll

-- Scrolling list of saved positions
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PositionList"
scrollFrame.Size = UDim2.new(1, 0, 0, 100)
scrollFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 40)
scrollFrame.BackgroundTransparency = 0.3
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 3
scrollFrame.LayoutOrder = 6
scrollFrame.Parent = teleporterScroll

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 2)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 3)
listPadding.PaddingBottom = UDim.new(0, 3)
listPadding.PaddingLeft = UDim.new(0, 3)
listPadding.PaddingRight = UDim.new(0, 3)
listPadding.Parent = scrollFrame

-- Button container
local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(1, 0, 0, 54)
buttonContainer.BackgroundTransparency = 1
buttonContainer.ZIndex = 3
buttonContainer.LayoutOrder = 7
buttonContainer.Parent = teleporterScroll

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 3)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.Parent = buttonContainer

-- Teleport button
local teleportButton = Instance.new("TextButton")
teleportButton.Name = "TeleportButton"
teleportButton.Size = UDim2.new(1, 0, 0, 22)
teleportButton.BackgroundColor3 = Color3.fromRGB(50, 25, 100)
teleportButton.Text = "🚀 TP"
teleportButton.TextColor3 = Color3.fromRGB(240, 230, 255)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 9
teleportButton.AutoButtonColor = false
teleportButton.ZIndex = 3
teleportButton.LayoutOrder = 1
teleportButton.Parent = buttonContainer

local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 6)
teleportCorner.Parent = teleportButton

local teleportStroke = Instance.new("UIStroke")
teleportStroke.Color = Color3.fromRGB(150, 100, 255)
teleportStroke.Transparency = 0.3
teleportStroke.Parent = teleportButton

-- Delete & Clear Container
local deleteClearContainer = Instance.new("Frame")
deleteClearContainer.Size = UDim2.new(1, 0, 0, 24)
deleteClearContainer.BackgroundTransparency = 1
deleteClearContainer.ZIndex = 3
deleteClearContainer.LayoutOrder = 2
deleteClearContainer.Parent = buttonContainer

local deleteClearLayout = Instance.new("UIListLayout")
deleteClearLayout.Padding = UDim.new(0, 2)
deleteClearLayout.SortOrder = Enum.SortOrder.LayoutOrder
deleteClearLayout.FillDirection = Enum.FillDirection.Horizontal
deleteClearLayout.Parent = deleteClearContainer

-- Delete button
local deleteButton = Instance.new("TextButton")
deleteButton.Name = "DeleteButton"
deleteButton.Size = UDim2.new(0.5, -1, 1, 0)
deleteButton.BackgroundColor3 = Color3.fromRGB(150, 30, 50)
deleteButton.Text = "🗑️ Del"
deleteButton.TextColor3 = Color3.fromRGB(255, 200, 200)
deleteButton.Font = Enum.Font.GothamBold
deleteButton.TextSize = 8
deleteButton.AutoButtonColor = false
deleteButton.ZIndex = 3
deleteButton.LayoutOrder = 1
deleteButton.Parent = deleteClearContainer

local deleteCorner = Instance.new("UICorner")
deleteCorner.CornerRadius = UDim.new(0, 6)
deleteCorner.Parent = deleteButton

local deleteStroke = Instance.new("UIStroke")
deleteStroke.Color = Color3.fromRGB(200, 100, 100)
deleteStroke.Transparency = 0.3
deleteStroke.Parent = deleteButton

-- Clear All button
local clearButton = Instance.new("TextButton")
clearButton.Name = "ClearButton"
clearButton.Size = UDim2.new(0.5, -1, 1, 0)
clearButton.BackgroundColor3 = Color3.fromRGB(100, 20, 20)
clearButton.Text = "⚠️ Clr"
clearButton.TextColor3 = Color3.fromRGB(255, 150, 150)
clearButton.Font = Enum.Font.GothamBold
clearButton.TextSize = 8
clearButton.AutoButtonColor = false
clearButton.ZIndex = 3
clearButton.LayoutOrder = 2
clearButton.Parent = deleteClearContainer

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 6)
clearCorner.Parent = clearButton

local clearStroke = Instance.new("UIStroke")
clearStroke.Color = Color3.fromRGB(200, 80, 80)
clearStroke.Transparency = 0.3
clearStroke.Parent = clearButton

-- ============ MISC TAB ============
local miscTab = Instance.new("Frame")
miscTab.Name = "MiscTab"
miscTab.Size = UDim2.new(1, 0, 1, 0)
miscTab.BackgroundTransparency = 1
miscTab.ZIndex = 3
miscTab.Parent = bodyFrame
miscTab.Visible = false

local miscScroll = Instance.new("ScrollingFrame")
miscScroll.Size = UDim2.new(1, 0, 1, 0)
miscScroll.BackgroundTransparency = 1
miscScroll.ScrollBarThickness = 4
miscScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
miscScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
miscScroll.ZIndex = 3
miscScroll.Parent = miscTab

local miscLayout = Instance.new("UIListLayout")
miscLayout.Padding = UDim.new(0, 6)
miscLayout.SortOrder = Enum.SortOrder.LayoutOrder
miscLayout.Parent = miscScroll

local miscScrollPadding = Instance.new("UIPadding")
miscScrollPadding.PaddingTop = UDim.new(0, 8)
miscScrollPadding.PaddingBottom = UDim.new(0, 8)
miscScrollPadding.PaddingLeft = UDim.new(0, 8)
miscScrollPadding.PaddingRight = UDim.new(0, 8)
miscScrollPadding.Parent = miscScroll

-- Fly Toggle Button
local flyToggleBtn = Instance.new("TextButton")
flyToggleBtn.Name = "FlyToggle"
flyToggleBtn.Size = UDim2.new(1, 0, 0, 32)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 30)
flyToggleBtn.Text = "✈️ Fly"
flyToggleBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
flyToggleBtn.Font = Enum.Font.GothamBold
flyToggleBtn.TextSize = 12
flyToggleBtn.AutoButtonColor = false
flyToggleBtn.ZIndex = 3
flyToggleBtn.LayoutOrder = 1
flyToggleBtn.Parent = miscScroll

local flyToggleCorner = Instance.new("UICorner")
flyToggleCorner.CornerRadius = UDim.new(0, 8)
flyToggleCorner.Parent = flyToggleBtn

local flyToggleStroke = Instance.new("UIStroke")
flyToggleStroke.Color = Color3.fromRGB(100, 200, 100)
flyToggleStroke.Transparency = 0.3
flyToggleStroke.Parent = flyToggleBtn

-- Fly Speed Label
local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Size = UDim2.new(1, 0, 0, 16)
flySpeedLabel.BackgroundTransparency = 1
flySpeedLabel.Text = "✈️ Speed: 50"
flySpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
flySpeedLabel.Font = Enum.Font.GothamBold
flySpeedLabel.TextSize = 10
flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
flySpeedLabel.ZIndex = 3
flySpeedLabel.LayoutOrder = 2
flySpeedLabel.Parent = miscScroll

-- Fly Speed Slider
local flySpeedSlider = Instance.new("TextBox")
flySpeedSlider.Name = "FlySpeedSlider"
flySpeedSlider.Size = UDim2.new(1, 0, 0, 24)
flySpeedSlider.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
flySpeedSlider.PlaceholderText = "1-200"
flySpeedSlider.Text = "50"
flySpeedSlider.TextColor3 = Color3.fromRGB(230, 220, 255)
flySpeedSlider.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
flySpeedSlider.Font = Enum.Font.Gotham
flySpeedSlider.TextSize = 11
flySpeedSlider.ZIndex = 3
flySpeedSlider.LayoutOrder = 3
flySpeedSlider.Parent = miscScroll

local flySpeedSliderCorner = Instance.new("UICorner")
flySpeedSliderCorner.CornerRadius = UDim.new(0, 6)
flySpeedSliderCorner.Parent = flySpeedSlider

local flySpeedSliderStroke = Instance.new("UIStroke")
flySpeedSliderStroke.Color = Color3.fromRGB(120, 90, 200)
flySpeedSliderStroke.Transparency = 0.4
flySpeedSliderStroke.Parent = flySpeedSlider

-- Noclip Toggle Button
local noclipToggleBtn = Instance.new("TextButton")
noclipToggleBtn.Name = "NoclipToggle"
noclipToggleBtn.Size = UDim2.new(1, 0, 0, 32)
noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
noclipToggleBtn.Text = "👻 Noclip"
noclipToggleBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
noclipToggleBtn.Font = Enum.Font.GothamBold
noclipToggleBtn.TextSize = 12
noclipToggleBtn.AutoButtonColor = false
noclipToggleBtn.ZIndex = 3
noclipToggleBtn.LayoutOrder = 4
noclipToggleBtn.Parent = miscScroll

local noclipToggleCorner = Instance.new("UICorner")
noclipToggleCorner.CornerRadius = UDim.new(0, 8)
noclipToggleCorner.Parent = noclipToggleBtn

local noclipToggleStroke = Instance.new("UIStroke")
noclipToggleStroke.Color = Color3.fromRGB(200, 160, 80)
noclipToggleStroke.Transparency = 0.3
noclipToggleStroke.Parent = noclipToggleBtn

-- Noclip Speed Label
local noclipSpeedLabel = Instance.new("TextLabel")
noclipSpeedLabel.Size = UDim2.new(1, 0, 0, 16)
noclipSpeedLabel.BackgroundTransparency = 1
noclipSpeedLabel.Text = "👻 Speed: 25"
noclipSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
noclipSpeedLabel.Font = Enum.Font.GothamBold
noclipSpeedLabel.TextSize = 10
noclipSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
noclipSpeedLabel.ZIndex = 3
noclipSpeedLabel.LayoutOrder = 5
noclipSpeedLabel.Parent = miscScroll

-- Noclip Speed Slider
local noclipSpeedSlider = Instance.new("TextBox")
noclipSpeedSlider.Name = "NoclipSpeedSlider"
noclipSpeedSlider.Size = UDim2.new(1, 0, 0, 24)
noclipSpeedSlider.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
noclipSpeedSlider.PlaceholderText = "1-100"
noclipSpeedSlider.Text = "25"
noclipSpeedSlider.TextColor3 = Color3.fromRGB(230, 220, 255)
noclipSpeedSlider.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
noclipSpeedSlider.Font = Enum.Font.Gotham
noclipSpeedSlider.TextSize = 11
noclipSpeedSlider.ZIndex = 3
noclipSpeedSlider.LayoutOrder = 6
noclipSpeedSlider.Parent = miscScroll

local noclipSpeedSliderCorner = Instance.new("UICorner")
noclipSpeedSliderCorner.CornerRadius = UDim.new(0, 6)
noclipSpeedSliderCorner.Parent = noclipSpeedSlider

local noclipSpeedSliderStroke = Instance.new("UIStroke")
noclipSpeedSliderStroke.Color = Color3.fromRGB(120, 90, 200)
noclipSpeedSliderStroke.Transparency = 0.4
noclipSpeedSliderStroke.Parent = noclipSpeedSlider

-- Invisible Toggle Button
local invisibleToggleBtn = Instance.new("TextButton")
invisibleToggleBtn.Name = "InvisibleToggle"
invisibleToggleBtn.Size = UDim2.new(1, 0, 0, 32)
invisibleToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
invisibleToggleBtn.Text = "👁️ Invisible"
invisibleToggleBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
invisibleToggleBtn.Font = Enum.Font.GothamBold
invisibleToggleBtn.TextSize = 12
invisibleToggleBtn.AutoButtonColor = false
invisibleToggleBtn.ZIndex = 3
invisibleToggleBtn.LayoutOrder = 7
invisibleToggleBtn.Parent = miscScroll

local invisibleToggleCorner = Instance.new("UICorner")
invisibleToggleCorner.CornerRadius = UDim.new(0, 8)
invisibleToggleCorner.Parent = invisibleToggleBtn

local invisibleToggleStroke = Instance.new("UIStroke")
invisibleToggleStroke.Color = Color3.fromRGB(180, 120, 220)
invisibleToggleStroke.Transparency = 0.3
invisibleToggleStroke.Parent = invisibleToggleBtn

-- WalkSpeed Label
local walkSpeedLabel = Instance.new("TextLabel")
walkSpeedLabel.Size = UDim2.new(1, 0, 0, 16)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Text = "🚶 Walk: 16"
walkSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
walkSpeedLabel.Font = Enum.Font.GothamBold
walkSpeedLabel.TextSize = 10
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
walkSpeedLabel.ZIndex = 3
walkSpeedLabel.LayoutOrder = 8
walkSpeedLabel.Parent = miscScroll

-- WalkSpeed Input
local walkSpeedInput = Instance.new("TextBox")
walkSpeedInput.Name = "WalkSpeedInput"
walkSpeedInput.Size = UDim2.new(1, 0, 0, 24)
walkSpeedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
walkSpeedInput.PlaceholderText = "1-200"
walkSpeedInput.Text = "16"
walkSpeedInput.TextColor3 = Color3.fromRGB(230, 220, 255)
walkSpeedInput.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
walkSpeedInput.Font = Enum.Font.Gotham
walkSpeedInput.TextSize = 11
walkSpeedInput.ZIndex = 3
walkSpeedInput.LayoutOrder = 9
walkSpeedInput.Parent = miscScroll

local walkSpeedInputCorner = Instance.new("UICorner")
walkSpeedInputCorner.CornerRadius = UDim.new(0, 6)
walkSpeedInputCorner.Parent = walkSpeedInput

local walkSpeedInputStroke = Instance.new("UIStroke")
walkSpeedInputStroke.Color = Color3.fromRGB(120, 90, 200)
walkSpeedInputStroke.Transparency = 0.4
walkSpeedInputStroke.Parent = walkSpeedInput

-- Apply WalkSpeed Button
local applyWalkSpeedBtn = Instance.new("TextButton")
applyWalkSpeedBtn.Name = "ApplyWalkSpeed"
applyWalkSpeedBtn.Size = UDim2.new(1, 0, 0, 32)
applyWalkSpeedBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
applyWalkSpeedBtn.Text = "✓ Apply"
applyWalkSpeedBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
applyWalkSpeedBtn.Font = Enum.Font.GothamBold
applyWalkSpeedBtn.TextSize = 12
applyWalkSpeedBtn.AutoButtonColor = false
applyWalkSpeedBtn.ZIndex = 3
applyWalkSpeedBtn.LayoutOrder = 10
applyWalkSpeedBtn.Parent = miscScroll

local applyWalkSpeedCorner = Instance.new("UICorner")
applyWalkSpeedCorner.CornerRadius = UDim.new(0, 6)
applyWalkSpeedCorner.Parent = applyWalkSpeedBtn

-- ============ POSITION LIST LOGIC ============
local entryButtons = {}

local function refreshHighlights()
    for i, btn in pairs(entryButtons) do
        if i == selectedIndex then
            btn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
            btn.UIStroke.Transparency = 0
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
            btn.UIStroke.Transparency = 0.6
        end
    end
end

local function addEntryToList(entryIndex, entryName)
    local entryButton = Instance.new("TextButton")
    entryButton.Name = "Entry_" .. entryIndex
    entryButton.Size = UDim2.new(1, 0, 0, 22)
    entryButton.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
    entryButton.Text = "  ✧ " .. entryName
    entryButton.TextColor3 = Color3.fromRGB(220, 210, 255)
    entryButton.Font = Enum.Font.Gotham
    entryButton.TextSize = 9
    entryButton.TextXAlignment = Enum.TextXAlignment.Left
    entryButton.AutoButtonColor = false
    entryButton.ZIndex = 4
    entryButton.LayoutOrder = entryIndex
    entryButton.Parent = scrollFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 6)
    entryCorner.Parent = entryButton

    local entryStroke = Instance.new("UIStroke")
    entryStroke.Name = "UIStroke"
    entryStroke.Color = Color3.fromRGB(150, 100, 255)
    entryStroke.Transparency = 0.6
    entryStroke.Parent = entryButton

    entryButton.MouseButton1Click:Connect(function()
        selectedIndex = entryIndex
        refreshHighlights()
    end)

    entryButtons[entryIndex] = entryButton
end

-- ============ TELEPORT METHODS ============

local function instantTeleport(targetCFrame)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = targetCFrame
end

local function smoothTeleport(targetCFrame)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local function realisticTeleport(targetCFrame)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local startPos = hrp.CFrame
    local distance = (targetCFrame.Position - startPos.Position).Magnitude
    local steps = math.ceil(distance / 50)
    
    for i = 1, steps do
        if not character or not character.Parent then break end
        local alpha = i / steps
        hrp.CFrame = startPos:Lerp(targetCFrame, alpha)
        RunService.RenderStepped:Wait()
    end
    
    if character and character.Parent then
        hrp.CFrame = targetCFrame
    end
end

-- ============ NOCLIP ============

local function startNoclip()
    if isNoclipping then return end
    isNoclipping = true

    local character = player.Character
    if not character then isNoclipping = false return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isNoclipping = false return end

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisionGroups[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
    noclipToggleBtn.Text = "👻 Stop"
    
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.RenderStepped:Connect(function()
        if not isNoclipping then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local cam = workspace.CurrentCamera
        local forward = (cam.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
        local right = cam.CFrame.RightVector
        local up = Vector3.new(0, 1, 0)
        
        local moveDir = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - up end
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * noclipSpeed * 0.016
        end
        
        root.CFrame = root.CFrame + moveDir
    end)
end

local function stopNoclip()
    if not isNoclipping then return end
    isNoclipping = false

    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    local char = player.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and originalCollisionGroups[part] ~= nil then
                part.CanCollide = originalCollisionGroups[part]
            end
        end
    end

    originalCollisionGroups = {}
    noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
    noclipToggleBtn.Text = "👻 Noclip"
end

-- ============ INVISIBLE ============

local function startInvisible()
    if isInvisible then return end
    isInvisible = true
    
    local char = player.Character
    if not char then isInvisible = false return end
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCharacterParts[part] = part.Transparency
            part.Transparency = 1
        elseif part:IsA("Accessory") then
            local handle = part:FindFirstChild("Handle")
            if handle then
                originalCharacterParts[handle] = handle.Transparency
                handle.Transparency = 1
            end
        end
    end
    
    invisibleToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
    invisibleToggleBtn.Text = "👁️ Visible"
end

local function stopInvisible()
    if not isInvisible then return end
    isInvisible = false
    
    local char = player.Character
    if char then
        for part, trans in pairs(originalCharacterParts) do
            if part and part.Parent then
                part.Transparency = trans
            end
        end
    end
    
    originalCharacterParts = {}
    invisibleToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    invisibleToggleBtn.Text = "👁️ Invisible"
end

-- ============ FLY ============

local function startFlying()
    if isFlying then return end
    isFlying = true
    
    local character = player.Character
    if not character then isFlying = false return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isFlying = false return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    
    flyBody = Instance.new("BodyVelocity")
    flyBody.Velocity = Vector3.new(0, 0, 0)
    flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBody.Parent = hrp
    
    flyToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 30)
    flyToggleBtn.Text = "✈️ Stop"
    
    if flyConnection then flyConnection:Disconnect() end
    flyConnection = RunService.RenderStepped:Connect(function()
        if not isFlying then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root or not flyBody then return end
        
        local cam = workspace.CurrentCamera
        local forward = (cam.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
        local right = cam.CFrame.RightVector
        local up = Vector3.new(0, 1, 0)
        
        local moveDir = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - up end
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * flySpeed
        end
        
        flyBody.Velocity = moveDir
    end)
end

local function stopFlying()
    if not isFlying then return end
    isFlying = false
    
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    if flyBody then
        flyBody:Destroy()
        flyBody = nil
    end
    
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
    end
    
    flyToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 30)
    flyToggleBtn.Text = "✈️ Fly"
end

-- ============ WINDOW DRAGGING (Main Window) ============
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = mouse.X - mainFrame.AbsolutePosition.X
        startPos = mainFrame.Position
    end
end)

titleBar.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if dragging and dragStart and startPos then
        local newX = mouse.X - dragStart
        mainFrame.Position = UDim2.new(0, newX, startPos.Y.Scale, startPos.Y.Offset)
    end
end)

-- ============ MINIMIZED COSMIC CUBE ============
local minimizedCube = Instance.new("Frame")
minimizedCube.Name = "MinimizedCube"
minimizedCube.Size = UDim2.new(0, 60, 0, 60)
minimizedCube.Position = UDim2.new(0.5, -30, 0.5, -30) -- temporary, will be set on minimize
minimizedCube.BackgroundColor3 = Color3.fromRGB(5, 2, 20)
minimizedCube.BorderSizePixel = 0
minimizedCube.Visible = false
minimizedCube.Parent = screenGui

local cubeCorner = Instance.new("UICorner")
cubeCorner.CornerRadius = UDim.new(0, 12)
cubeCorner.Parent = minimizedCube

-- Cosmic gradient background
local cubeGradient = Instance.new("UIGradient")
cubeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 0, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 5, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 15, 40)),
})
cubeGradient.Rotation = -45
cubeGradient.Parent = minimizedCube

local cubeStroke = Instance.new("UIStroke")
cubeStroke.Color = Color3.fromRGB(0, 200, 0)
cubeStroke.Thickness = 2
cubeStroke.Transparency = 0.4
cubeStroke.Parent = minimizedCube

-- Add small twinkling stars to the cube
for i = 1, 4 do
    addStar(minimizedCube, math.random(5, 95)/100, math.random(5, 95)/100, 1, 0.9)
end

-- The "S" in the center
local sLabel = Instance.new("TextLabel")
sLabel.Size = UDim2.new(1, 0, 1, 0)
sLabel.BackgroundTransparency = 1
sLabel.Text = "S"
sLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
sLabel.Font = Enum.Font.GothamBlack
sLabel.TextSize = 36
sLabel.TextStrokeTransparency = 0.5
sLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- dark outline
sLabel.ZIndex = 5
sLabel.Parent = minimizedCube

-- Dragging for the cube
local cubeDragging = false
local cubeDragStart = nil
local cubeStartPos = nil

minimizedCube.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        cubeDragging = true
        cubeDragStart = mouse.X - minimizedCube.AbsolutePosition.X
        cubeStartPos = minimizedCube.Position
    end
end)

minimizedCube.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        cubeDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if cubeDragging and cubeDragStart and cubeStartPos then
        local newX = mouse.X - cubeDragStart
        minimizedCube.Position = UDim2.new(0, newX, cubeStartPos.Y.Scale, cubeStartPos.Y.Offset)
    end
end)

-- When the cube is clicked (without dragging), expand back
minimizedCube.MouseButton1Click:Connect(function()
    -- Only restore if we didn't just finish a drag (simple: check if position moved a lot? We'll just restore immediately)
    -- To avoid conflict, we use a flag: if the mouse moved a significant distance during the click, don't expand.
    -- But we'll use a simple approach: expand on click, but only if not dragging (cubeDragging false). However, MouseButton1Click fires after InputEnded if no movement. So we can check a small time window or distance.
    -- Simpler: add a distance threshold in dragging, but we can just use the same method as the main window: clicking the cube directly (without dragging) will expand.
    -- Since drag only moves horizontally in this implementation, we can compare the start and end positions. If they are the same (or within a few pixels), we expand.
    -- We'll just expand, and rely on the fact that a click that moves the cube will still trigger MouseButton1Click after dragging, which might be undesirable. Better: we use a flag "wasDragged" to prevent.
end)

-- More robust: use a small distance check
local cubeClickStartPos = nil
minimizedCube.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        cubeClickStartPos = Vector2.new(mouse.X, mouse.Y)
    end
end)

minimizedCube.MouseButton1Click:Connect(function()
    if cubeClickStartPos then
        local endPos = Vector2.new(mouse.X, mouse.Y)
        local dist = (endPos - cubeClickStartPos).Magnitude
        if dist <= 5 then -- only considered a click if almost no movement
            -- Expand the main window
            if not mainFrame.Visible then
                minimizedCube.Visible = false
                mainFrame.Visible = true
                contentFrame.Visible = true
                -- Place the main window near the cube
                mainFrame.Position = UDim2.new(0, minimizedCube.AbsolutePosition.X, 0, minimizedCube.AbsolutePosition.Y)
                minimizeButton.Text = "–"
            end
        end
        cubeClickStartPos = nil
    end
end)

-- ============ BUTTON EVENTS ============

teleporterTabBtn.MouseButton1Click:Connect(function()
    currentTab = "teleporter"
    teleporterTab.Visible = true
    miscTab.Visible = false
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
    teleporterTabStroke.Transparency = 0.3
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    miscTabStroke.Transparency = 0.5
end)

miscTabBtn.MouseButton1Click:Connect(function()
    currentTab = "misc"
    teleporterTab.Visible = false
    miscTab.Visible = true
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
    miscTabStroke.Transparency = 0.3
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    teleporterTabStroke.Transparency = 0.5
end)

instantMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "instant"
    methodLabel.Text = "Method: instant"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

tweenMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "smooth"
    methodLabel.Text = "Method: smooth"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

realisticMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "realistic"
    methodLabel.Text = "Method: realistic"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
end)

saveButton.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local posName = nameBox.Text
    if posName == "" then
        posName = "Position #" .. (#savedPositions + 1)
    end

    table.insert(savedPositions, {name = posName, cframe = hrp.CFrame})
    addEntryToList(#savedPositions, posName)
    selectedIndex = #savedPositions
    refreshHighlights()
    nameBox.Text = ""
end)

teleportButton.MouseButton1Click:Connect(function()
    if not selectedIndex or not savedPositions[selectedIndex] then return end
    
    local targetCFrame = savedPositions[selectedIndex].cframe
    
    if teleportMethod == "instant" then
        instantTeleport(targetCFrame)
    elseif teleportMethod == "smooth" then
        smoothTeleport(targetCFrame)
    elseif teleportMethod == "realistic" then
        realisticTeleport(targetCFrame)
    end
end)

deleteButton.MouseButton1Click:Connect(function()
    if not selectedIndex then return end
    table.remove(savedPositions, selectedIndex)
    entryButtons[selectedIndex]:Destroy()
    entryButtons[selectedIndex] = nil
    selectedIndex = nil
    refreshHighlights()
end)

clearButton.MouseButton1Click:Connect(function()
    for i, btn in pairs(entryButtons) do
        btn:Destroy()
    end
    savedPositions = {}
    entryButtons = {}
    selectedIndex = nil
end)

-- ============ MINIMIZE BUTTON (now controls cube) ============
minimizeButton.MouseButton1Click:Connect(function()
    if mainFrame.Visible then
        -- Minimize to cube
        contentFrame.Visible = false
        mainFrame.Visible = false
        minimizedCube.Visible = true
        minimizedCube.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
        minimizeButton.Text = "+"
    else
        -- Expand from cube (this case also possible if button is clicked while mainFrame hidden)
        if minimizedCube.Visible then
            minimizedCube.Visible = false
        end
        mainFrame.Visible = true
        contentFrame.Visible = true
        mainFrame.Position = UDim2.new(0, minimizedCube.AbsolutePosition.X, 0, minimizedCube.AbsolutePosition.Y)
        minimizeButton.Text = "–"
    end
end)

flyToggleBtn.MouseButton1Click:Connect(function()
    if isFlying then stopFlying() else startFlying() end
end)

flySpeedSlider.FocusLost:Connect(function()
    local speed = tonumber(flySpeedSlider.Text)
    if speed then
        flySpeed = clamp(speed, 1, 200)
        flySpeedLabel.Text = "✈️ Speed: " .. flySpeed
        flySpeedSlider.Text = tostring(flySpeed)
    end
end)

noclipToggleBtn.MouseButton1Click:Connect(function()
    if isNoclipping then stopNoclip() else startNoclip() end
end)

noclipSpeedSlider.FocusLost:Connect(function()
    local speed = tonumber(noclipSpeedSlider.Text)
    if speed then
        noclipSpeed = clamp(speed, 1, 100)
        noclipSpeedLabel.Text = "👻 Speed: " .. noclipSpeed
        noclipSpeedSlider.Text = tostring(noclipSpeed)
    end
end)

invisibleToggleBtn.MouseButton1Click:Connect(function()
    if isInvisible then stopInvisible() else startInvisible() end
end)

applyWalkSpeedBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local speed = tonumber(walkSpeedInput.Text)
    if speed then
        humanoid.WalkSpeed = clamp(speed, 1, 200)
        walkSpeedLabel.Text = "🚶 Walk: " .. math.floor(humanoid.WalkSpeed)
    end
end)
