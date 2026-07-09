--[[
    Galaxy Teleporter GUI with Advanced Features
    -----------------------------------------------
    A LocalScript that lets a player:
      - Save positions and teleport (3 methods: instant, smooth, realistic)
      - Fly with adjustable speed
      - Advanced anti-cheat noclip
      - Change WalkSpeed
      - Drag the window around, minimize it

    HOW TO USE:
    1. Place this as a LocalScript inside StarterPlayer > StarterPlayerScripts.
    2. That's it — works out of the box for single player / personal testing.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============ STATE ============
local savedPositions = {} -- { {name = "Home", cframe = CFrame}, ... }
local selectedIndex = nil
local currentTab = "teleporter" -- "teleporter" or "misc"
local teleportMethod = "instant" -- "instant", "tween", or "realistic"

-- Fly state
local isFlying = false
local flySpeed = 50
local flyDirection = Vector3.new(0, 0, 0)
local flyBody = nil
local flyBodyVelocity = nil
local flyConnection = nil

-- Noclip state
local isNoclipping = false
local noclipSpeed = 25
local noclipConnections = {}
local originalCollisionGroups = {}

-- ============ GUI SETUP ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyTeleporterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 600)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -300)
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

-- Scattered stars
local function addStar(xScale, yScale, size, brightness)
    local star = Instance.new("Frame")
    star.Size = UDim2.new(0, size, 0, size)
    star.Position = UDim2.new(xScale, 0, yScale, 0)
    star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    star.BackgroundTransparency = 1 - brightness
    star.BorderSizePixel = 0
    star.ZIndex = 1
    star.Parent = mainFrame

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
    addStar(math.random(0, 100) / 100, math.random(0, 100) / 100, math.random(1, 3), math.random(40, 90) / 100)
end

-- ============ TITLE BAR ============
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
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
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ Galaxy Teleporter"
titleLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3
titleLabel.Active = true
titleLabel.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 34, 0, 34)
minimizeButton.Position = UDim2.new(1, -40, 0.5, -17)
minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 30, 100)
minimizeButton.Text = "–"
minimizeButton.TextColor3 = Color3.fromRGB(230, 210, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.ZIndex = 3
minimizeButton.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0)
minCorner.Parent = minimizeButton

-- ============ MAIN CONTENT FRAME (Title + Body Side by Side) ============
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -36)
contentFrame.Position = UDim2.new(0, 0, 0, 36)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame

-- ============ SIDE TAB BAR (Left Side) ============
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(0, 120, 1, 0)
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
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.FillDirection = Enum.FillDirection.Vertical
tabLayout.Parent = tabBar

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingTop = UDim.new(0, 8)
tabPadding.PaddingBottom = UDim.new(0, 8)
tabPadding.PaddingLeft = UDim.new(0, 8)
tabPadding.PaddingRight = UDim.new(0, 8)
tabPadding.Parent = tabBar

-- Teleporter Tab Button
local teleporterTabBtn = Instance.new("TextButton")
teleporterTabBtn.Name = "TeleporterTab"
teleporterTabBtn.Size = UDim2.new(1, 0, 0, 40)
teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
teleporterTabBtn.Text = "🏠\nTeleporter"
teleporterTabBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
teleporterTabBtn.Font = Enum.Font.GothamBold
teleporterTabBtn.TextSize = 11
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
miscTabBtn.Size = UDim2.new(1, 0, 0, 40)
miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
miscTabBtn.Text = "⭐\nMisc"
miscTabBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
miscTabBtn.Font = Enum.Font.GothamBold
miscTabBtn.TextSize = 11
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
bodyFrame.Size = UDim2.new(1, -120, 1, 0)
bodyFrame.Position = UDim2.new(0, 120, 0, 0)
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
teleporterScroll.ScrollBarThickness = 0
teleporterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
teleporterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
teleporterScroll.ZIndex = 3
teleporterScroll.Parent = teleporterTab

local teleporterLayout = Instance.new("UIListLayout")
teleporterLayout.Padding = UDim.new(0, 8)
teleporterLayout.SortOrder = Enum.SortOrder.LayoutOrder
teleporterLayout.Parent = teleporterScroll

local teleporterScrollPadding = Instance.new("UIPadding")
teleporterScrollPadding.PaddingTop = UDim.new(0, 10)
teleporterScrollPadding.PaddingBottom = UDim.new(0, 10)
teleporterScrollPadding.PaddingLeft = UDim.new(0, 10)
teleporterScrollPadding.PaddingRight = UDim.new(0, 10)
teleporterScrollPadding.Parent = teleporterScroll

-- Name input box
local nameBox = Instance.new("TextBox")
nameBox.Name = "NameBox"
nameBox.Size = UDim2.new(1, 0, 0, 28)
nameBox.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
nameBox.PlaceholderText = "Name this position..."
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(230, 220, 255)
nameBox.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 12
nameBox.ClearTextOnFocus = false
nameBox.ZIndex = 3
nameBox.LayoutOrder = 1
nameBox.Parent = teleporterScroll

local nameBoxCorner = Instance.new("UICorner")
nameBoxCorner.CornerRadius = UDim.new(0, 10)
nameBoxCorner.Parent = nameBox

local nameBoxStroke = Instance.new("UIStroke")
nameBoxStroke.Color = Color3.fromRGB(120, 90, 200)
nameBoxStroke.Transparency = 0.4
nameBoxStroke.Parent = nameBox

-- Save button
local saveButton = Instance.new("TextButton")
saveButton.Name = "SaveButton"
saveButton.Size = UDim2.new(1, 0, 0, 32)
saveButton.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
saveButton.Text = "✦ Save Position"
saveButton.TextColor3 = Color3.fromRGB(240, 230, 255)
saveButton.Font = Enum.Font.GothamBold
saveButton.TextSize = 12
saveButton.AutoButtonColor = false
saveButton.ZIndex = 3
saveButton.LayoutOrder = 2
saveButton.Parent = teleporterScroll

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 10)
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
methodLabel.Size = UDim2.new(1, 0, 0, 16)
methodLabel.BackgroundTransparency = 1
methodLabel.Text = "Teleport Method: " .. teleportMethod
methodLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
methodLabel.Font = Enum.Font.GothamBold
methodLabel.TextSize = 10
methodLabel.TextXAlignment = Enum.TextXAlignment.Left
methodLabel.ZIndex = 3
methodLabel.LayoutOrder = 3
methodLabel.Parent = teleporterScroll

-- Method Selection Buttons Container
local methodButtonsContainer = Instance.new("Frame")
methodButtonsContainer.Size = UDim2.new(1, 0, 0, 26)
methodButtonsContainer.BackgroundTransparency = 1
methodButtonsContainer.ZIndex = 3
methodButtonsContainer.LayoutOrder = 4
methodButtonsContainer.Parent = teleporterScroll

local methodLayout = Instance.new("UIListLayout")
methodLayout.Padding = UDim.new(0, 4)
methodLayout.SortOrder = Enum.SortOrder.LayoutOrder
methodLayout.FillDirection = Enum.FillDirection.Horizontal
methodLayout.Parent = methodButtonsContainer

-- Method buttons
local instantMethodBtn = Instance.new("TextButton")
instantMethodBtn.Name = "InstantMethod"
instantMethodBtn.Size = UDim2.new(0.33, -2.67, 1, 0)
instantMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
instantMethodBtn.Text = "Instant"
instantMethodBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
instantMethodBtn.Font = Enum.Font.GothamBold
instantMethodBtn.TextSize = 10
instantMethodBtn.AutoButtonColor = false
instantMethodBtn.ZIndex = 3
instantMethodBtn.LayoutOrder = 1
instantMethodBtn.Parent = methodButtonsContainer

local instantCorner = Instance.new("UICorner")
instantCorner.CornerRadius = UDim.new(0, 8)
instantCorner.Parent = instantMethodBtn

local tweenMethodBtn = Instance.new("TextButton")
tweenMethodBtn.Name = "TweenMethod"
tweenMethodBtn.Size = UDim2.new(0.33, -2.67, 1, 0)
tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
tweenMethodBtn.Text = "Smooth"
tweenMethodBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
tweenMethodBtn.Font = Enum.Font.GothamBold
tweenMethodBtn.TextSize = 10
tweenMethodBtn.AutoButtonColor = false
tweenMethodBtn.ZIndex = 3
tweenMethodBtn.LayoutOrder = 2
tweenMethodBtn.Parent = methodButtonsContainer

local tweenCorner = Instance.new("UICorner")
tweenCorner.CornerRadius = UDim.new(0, 8)
tweenCorner.Parent = tweenMethodBtn

local realisticMethodBtn = Instance.new("TextButton")
realisticMethodBtn.Name = "RealisticMethod"
realisticMethodBtn.Size = UDim2.new(0.33, -2.67, 1, 0)
realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
realisticMethodBtn.Text = "Realistic"
realisticMethodBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
realisticMethodBtn.Font = Enum.Font.GothamBold
realisticMethodBtn.TextSize = 10
realisticMethodBtn.AutoButtonColor = false
realisticMethodBtn.ZIndex = 3
realisticMethodBtn.LayoutOrder = 3
realisticMethodBtn.Parent = methodButtonsContainer

local realisticCorner = Instance.new("UICorner")
realisticCorner.CornerRadius = UDim.new(0, 8)
realisticCorner.Parent = realisticMethodBtn

-- Menu label
local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 16)
menuLabel.BackgroundTransparency = 1
menuLabel.Text = "Saved Positions"
menuLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
menuLabel.Font = Enum.Font.GothamBold
menuLabel.TextSize = 11
menuLabel.TextXAlignment = Enum.TextXAlignment.Left
menuLabel.ZIndex = 3
menuLabel.LayoutOrder = 5
menuLabel.Parent = teleporterScroll

-- Scrolling list of saved positions
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PositionList"
scrollFrame.Size = UDim2.new(1, 0, 0, 150)
scrollFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 40)
scrollFrame.BackgroundTransparency = 0.3
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 3
scrollFrame.LayoutOrder = 6
scrollFrame.Parent = teleporterScroll

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 10)
scrollCorner.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.PaddingLeft = UDim.new(0, 4)
listPadding.PaddingRight = UDim.new(0, 4)
listPadding.Parent = scrollFrame

-- Button container
local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(1, 0, 0, 68)
buttonContainer.BackgroundTransparency = 1
buttonContainer.ZIndex = 3
buttonContainer.LayoutOrder = 7
buttonContainer.Parent = teleporterScroll

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 6)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.Parent = buttonContainer

-- Teleport button
local teleportButton = Instance.new("TextButton")
teleportButton.Name = "TeleportButton"
teleportButton.Size = UDim2.new(1, 0, 0, 30)
teleportButton.BackgroundColor3 = Color3.fromRGB(50, 25, 100)
teleportButton.Text = "🚀 Teleport"
teleportButton.TextColor3 = Color3.fromRGB(240, 230, 255)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 11
teleportButton.AutoButtonColor = false
teleportButton.ZIndex = 3
teleportButton.LayoutOrder = 1
teleportButton.Parent = buttonContainer

local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 10)
teleportCorner.Parent = teleportButton

local teleportStroke = Instance.new("UIStroke")
teleportStroke.Color = Color3.fromRGB(150, 100, 255)
teleportStroke.Transparency = 0.3
teleportStroke.Parent = teleportButton

-- Delete & Clear Container
local deleteClearContainer = Instance.new("Frame")
deleteClearContainer.Size = UDim2.new(1, 0, 0, 32)
deleteClearContainer.BackgroundTransparency = 1
deleteClearContainer.ZIndex = 3
deleteClearContainer.LayoutOrder = 2
deleteClearContainer.Parent = buttonContainer

local deleteClearLayout = Instance.new("UIListLayout")
deleteClearLayout.Padding = UDim.new(0, 4)
deleteClearLayout.SortOrder = Enum.SortOrder.LayoutOrder
deleteClearLayout.FillDirection = Enum.FillDirection.Horizontal
deleteClearLayout.Parent = deleteClearContainer

-- Delete button
local deleteButton = Instance.new("TextButton")
deleteButton.Name = "DeleteButton"
deleteButton.Size = UDim2.new(0.5, -2, 1, 0)
deleteButton.BackgroundColor3 = Color3.fromRGB(150, 30, 50)
deleteButton.Text = "🗑️ Delete"
deleteButton.TextColor3 = Color3.fromRGB(255, 200, 200)
deleteButton.Font = Enum.Font.GothamBold
deleteButton.TextSize = 10
deleteButton.AutoButtonColor = false
deleteButton.ZIndex = 3
deleteButton.LayoutOrder = 1
deleteButton.Parent = deleteClearContainer

local deleteCorner = Instance.new("UICorner")
deleteCorner.CornerRadius = UDim.new(0, 10)
deleteCorner.Parent = deleteButton

local deleteStroke = Instance.new("UIStroke")
deleteStroke.Color = Color3.fromRGB(200, 100, 100)
deleteStroke.Transparency = 0.3
deleteStroke.Parent = deleteButton

-- Clear All button
local clearButton = Instance.new("TextButton")
clearButton.Name = "ClearButton"
clearButton.Size = UDim2.new(0.5, -2, 1, 0)
clearButton.BackgroundColor3 = Color3.fromRGB(100, 20, 20)
clearButton.Text = "⚠️ Clear All"
clearButton.TextColor3 = Color3.fromRGB(255, 150, 150)
clearButton.Font = Enum.Font.GothamBold
clearButton.TextSize = 10
clearButton.AutoButtonColor = false
clearButton.ZIndex = 3
clearButton.LayoutOrder = 2
clearButton.Parent = deleteClearContainer

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 10)
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
miscScroll.ScrollBarThickness = 0
miscScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
miscScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
miscScroll.ZIndex = 3
miscScroll.Parent = miscTab

local miscLayout = Instance.new("UIListLayout")
miscLayout.Padding = UDim.new(0, 8)
miscLayout.SortOrder = Enum.SortOrder.LayoutOrder
miscLayout.Parent = miscScroll

local miscScrollPadding = Instance.new("UIPadding")
miscScrollPadding.PaddingTop = UDim.new(0, 10)
miscScrollPadding.PaddingBottom = UDim.new(0, 10)
miscScrollPadding.PaddingLeft = UDim.new(0, 10)
miscScrollPadding.PaddingRight = UDim.new(0, 10)
miscScrollPadding.Parent = miscScroll

-- Fly Toggle Button
local flyToggleBtn = Instance.new("TextButton")
flyToggleBtn.Name = "FlyToggle"
flyToggleBtn.Size = UDim2.new(1, 0, 0, 36)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 30)
flyToggleBtn.Text = "✈️ Start Flying"
flyToggleBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
flyToggleBtn.Font = Enum.Font.GothamBold
flyToggleBtn.TextSize = 13
flyToggleBtn.AutoButtonColor = false
flyToggleBtn.ZIndex = 3
flyToggleBtn.LayoutOrder = 1
flyToggleBtn.Parent = miscScroll

local flyToggleCorner = Instance.new("UICorner")
flyToggleCorner.CornerRadius = UDim.new(0, 10)
flyToggleCorner.Parent = flyToggleBtn

local flyToggleStroke = Instance.new("UIStroke")
flyToggleStroke.Color = Color3.fromRGB(100, 200, 100)
flyToggleStroke.Transparency = 0.3
flyToggleStroke.Parent = flyToggleBtn

-- Noclip Toggle Button
local noclipToggleBtn = Instance.new("TextButton")
noclipToggleBtn.Name = "NoclipToggle"
noclipToggleBtn.Size = UDim2.new(1, 0, 0, 36)
noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
noclipToggleBtn.Text = "👻 Start Noclip"
noclipToggleBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
noclipToggleBtn.Font = Enum.Font.GothamBold
noclipToggleBtn.TextSize = 13
noclipToggleBtn.AutoButtonColor = false
noclipToggleBtn.ZIndex = 3
noclipToggleBtn.LayoutOrder = 2
noclipToggleBtn.Parent = miscScroll

local noclipToggleCorner = Instance.new("UICorner")
noclipToggleCorner.CornerRadius = UDim.new(0, 10)
noclipToggleCorner.Parent = noclipToggleBtn

local noclipToggleStroke = Instance.new("UIStroke")
noclipToggleStroke.Color = Color3.fromRGB(200, 160, 80)
noclipToggleStroke.Transparency = 0.3
noclipToggleStroke.Parent = noclipToggleBtn

-- Fly Speed Label
local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Size = UDim2.new(1, 0, 0, 18)
flySpeedLabel.BackgroundTransparency = 1
flySpeedLabel.Text = "✈️ Fly Speed: 50"
flySpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
flySpeedLabel.Font = Enum.Font.GothamBold
flySpeedLabel.TextSize = 11
flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
flySpeedLabel.ZIndex = 3
flySpeedLabel.LayoutOrder = 3
flySpeedLabel.Parent = miscScroll

-- Fly Speed Slider
local flySpeedSlider = Instance.new("TextBox")
flySpeedSlider.Name = "FlySpeedSlider"
flySpeedSlider.Size = UDim2.new(1, 0, 0, 26)
flySpeedSlider.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
flySpeedSlider.PlaceholderText = "Enter speed (1-200)"
flySpeedSlider.Text = "50"
flySpeedSlider.TextColor3 = Color3.fromRGB(230, 220, 255)
flySpeedSlider.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
flySpeedSlider.Font = Enum.Font.Gotham
flySpeedSlider.TextSize = 12
flySpeedSlider.ZIndex = 3
flySpeedSlider.LayoutOrder = 4
flySpeedSlider.Parent = miscScroll

local flySpeedSliderCorner = Instance.new("UICorner")
flySpeedSliderCorner.CornerRadius = UDim.new(0, 10)
flySpeedSliderCorner.Parent = flySpeedSlider

local flySpeedSliderStroke = Instance.new("UIStroke")
flySpeedSliderStroke.Color = Color3.fromRGB(120, 90, 200)
flySpeedSliderStroke.Transparency = 0.4
flySpeedSliderStroke.Parent = flySpeedSlider

-- Noclip Speed Label
local noclipSpeedLabel = Instance.new("TextLabel")
noclipSpeedLabel.Size = UDim2.new(1, 0, 0, 18)
noclipSpeedLabel.BackgroundTransparency = 1
noclipSpeedLabel.Text = "👻 Noclip Speed: 25"
noclipSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
noclipSpeedLabel.Font = Enum.Font.GothamBold
noclipSpeedLabel.TextSize = 11
noclipSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
noclipSpeedLabel.ZIndex = 3
noclipSpeedLabel.LayoutOrder = 5
noclipSpeedLabel.Parent = miscScroll

-- Noclip Speed Slider
local noclipSpeedSlider = Instance.new("TextBox")
noclipSpeedSlider.Name = "NoclipSpeedSlider"
noclipSpeedSlider.Size = UDim2.new(1, 0, 0, 26)
noclipSpeedSlider.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
noclipSpeedSlider.PlaceholderText = "Enter speed (1-100)"
noclipSpeedSlider.Text = "25"
noclipSpeedSlider.TextColor3 = Color3.fromRGB(230, 220, 255)
noclipSpeedSlider.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
noclipSpeedSlider.Font = Enum.Font.Gotham
noclipSpeedSlider.TextSize = 12
noclipSpeedSlider.ZIndex = 3
noclipSpeedSlider.LayoutOrder = 6
noclipSpeedSlider.Parent = miscScroll

local noclipSpeedSliderCorner = Instance.new("UICorner")
noclipSpeedSliderCorner.CornerRadius = UDim.new(0, 10)
noclipSpeedSliderCorner.Parent = noclipSpeedSlider

local noclipSpeedSliderStroke = Instance.new("UIStroke")
noclipSpeedSliderStroke.Color = Color3.fromRGB(120, 90, 200)
noclipSpeedSliderStroke.Transparency = 0.4
noclipSpeedSliderStroke.Parent = noclipSpeedSlider

-- WalkSpeed Label
local walkSpeedLabel = Instance.new("TextLabel")
walkSpeedLabel.Size = UDim2.new(1, 0, 0, 18)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Text = "🚶 Walk Speed: 16"
walkSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
walkSpeedLabel.Font = Enum.Font.GothamBold
walkSpeedLabel.TextSize = 11
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
walkSpeedLabel.ZIndex = 3
walkSpeedLabel.LayoutOrder = 7
walkSpeedLabel.Parent = miscScroll

-- WalkSpeed Input
local walkSpeedInput = Instance.new("TextBox")
walkSpeedInput.Name = "WalkSpeedInput"
walkSpeedInput.Size = UDim2.new(1, 0, 0, 26)
walkSpeedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
walkSpeedInput.PlaceholderText = "Enter walk speed (1-200)"
walkSpeedInput.Text = "16"
walkSpeedInput.TextColor3 = Color3.fromRGB(230, 220, 255)
walkSpeedInput.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
walkSpeedInput.Font = Enum.Font.Gotham
walkSpeedInput.TextSize = 12
walkSpeedInput.ZIndex = 3
walkSpeedInput.LayoutOrder = 8
walkSpeedInput.Parent = miscScroll

local walkSpeedInputCorner = Instance.new("UICorner")
walkSpeedInputCorner.CornerRadius = UDim.new(0, 10)
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
applyWalkSpeedBtn.Text = "✓ Apply Walk Speed"
applyWalkSpeedBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
applyWalkSpeedBtn.Font = Enum.Font.GothamBold
applyWalkSpeedBtn.TextSize = 12
applyWalkSpeedBtn.AutoButtonColor = false
applyWalkSpeedBtn.ZIndex = 3
applyWalkSpeedBtn.LayoutOrder = 9
applyWalkSpeedBtn.Parent = miscScroll

local applyWalkSpeedCorner = Instance.new("UICorner")
applyWalkSpeedCorner.CornerRadius = UDim.new(0, 10)
applyWalkSpeedCorner.Parent = applyWalkSpeedBtn

-- ============ POSITION LIST LOGIC ============
local entryButtons = {} -- index -> button instance

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
    entryButton.Size = UDim2.new(1, 0, 0, 28)
    entryButton.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
    entryButton.Text = "  ✧ " .. entryName
    entryButton.TextColor3 = Color3.fromRGB(220, 210, 255)
    entryButton.Font = Enum.Font.Gotham
    entryButton.TextSize = 11
    entryButton.TextXAlignment = Enum.TextXAlignment.Left
    entryButton.AutoButtonColor = false
    entryButton.ZIndex = 4
    entryButton.LayoutOrder = entryIndex
    entryButton.Parent = scrollFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 8)
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

-- ============ ADVANCED TELEPORT METHODS ============

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
    
    local tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local function realisticTeleport(targetCFrame)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local startPos = hrp.CFrame
    local targetPos = targetCFrame
    local distance = (targetPos.Position - startPos.Position).Magnitude
    
    local steps = math.ceil(distance / 50)
    for i = 1, steps do
        local alpha = i / steps
        local newCFrame = startPos:Lerp(targetPos, alpha)
        hrp.CFrame = newCFrame
        RunService.RenderStepped:Wait()
    end
    
    hrp.CFrame = targetPos
end

-- ============ ADVANCED NOCLIP FUNCTION ============
local function startNoclip()
    if isNoclipping then return end
    isNoclipping = true

    local character = player.Character
    if not character then isNoclipping = false return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isNoclipping = false return end

    -- Disable collision for all character parts
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisionGroups[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
    noclipToggleBtn.Text = "👻 Stop Noclip"
end

local function stopNoclip()
    if not isNoclipping then return end
    isNoclipping = false

    local character = player.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisionGroups[part] ~= nil then
                    part.CanCollide = originalCollisionGroups[part]
                else
                    part.CanCollide = true
                end
            end
        end
    end

    originalCollisionGroups = {}
    noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
    noclipToggleBtn.Text = "👻 Start Noclip"
end

-- ============ FLY FUNCTION ============
local function startFlying()
    if isFlying then return end
    isFlying = true

    local character = player.Character
    if not character then isFlying = false return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isFlying = false return end

    flyBody = Instance.new("Part")
    flyBody.Shape = Enum.PartType.Block
    flyBody.Transparency = 1
    flyBody.Size = Vector3.new(1, 1, 1)
    flyBody.CanCollide = false
    flyBody.CFrame = hrp.CFrame
    flyBody.TopSurface = Enum.SurfaceType.Smooth
    flyBody.BottomSurface = Enum.SurfaceType.Smooth
    flyBody.Parent = workspace

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyVelocity.Parent = flyBody

    flyToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
    flyToggleBtn.Text = "✈️ Stop Flying"
end

local function stopFlying()
    if not isFlying then return end
    isFlying = false

    if flyBody then
        flyBody:Destroy()
        flyBody = nil
    end
    flyBodyVelocity = nil

    flyToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 30)
    flyToggleBtn.Text = "✈️ Start Flying"
end

-- ============ BUTTON EVENTS ============

-- Tab switching
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
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    teleporterTabStroke.Transparency = 0.5
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
    miscTabStroke.Transparency = 0.3
end)

-- Teleport method switching
instantMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "instant"
    methodLabel.Text = "Teleport Method: instant"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

tweenMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "tween"
    methodLabel.Text = "Teleport Method: smooth"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

realisticMethodBtn.MouseButton1Click:Connect(function()
    teleportMethod = "realistic"
    methodLabel.Text = "Teleport Method: realistic"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
end)

-- Save position
saveButton.MouseButton1Click:Connect(function()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local posName = nameBox.Text
    if posName == "" then
        posName = "Position " .. (#savedPositions + 1)
    end

    local entry = {
        name = posName,
        cframe = hrp.CFrame
    }
    table.insert(savedPositions, entry)

    local newIndex = #savedPositions
    addEntryToList(newIndex, posName)

    nameBox.Text = ""
end)

-- Teleport
teleportButton.MouseButton1Click:Connect(function()
    if not selectedIndex or not savedPositions[selectedIndex] then return end

    local targetPos = savedPositions[selectedIndex].cframe
    
    if teleportMethod == "instant" then
        instantTeleport(targetPos)
    elseif teleportMethod == "tween" then
        smoothTeleport(targetPos)
    elseif teleportMethod == "realistic" then
        realisticTeleport(targetPos)
    end
end)

-- Delete position
deleteButton.MouseButton1Click:Connect(function()
    if not selectedIndex or not savedPositions[selectedIndex] then return end

    table.remove(savedPositions, selectedIndex)

    if entryButtons[selectedIndex] then
        entryButtons[selectedIndex]:Destroy()
        entryButtons[selectedIndex] = nil
    end

    selectedIndex = nil
    refreshHighlights()

    local newEntryButtons = {}
    for i = 1, #savedPositions do
        local oldBtn = entryButtons[i]
        if oldBtn then
            oldBtn.LayoutOrder = i
            newEntryButtons[i] = oldBtn
        end
    end
    entryButtons = newEntryButtons
end)

-- Clear all
clearButton.MouseButton1Click:Connect(function()
    savedPositions = {}
    selectedIndex = nil

    for i, btn in pairs(entryButtons) do
        btn:Destroy()
    end
    entryButtons = {}
end)

-- Fly toggle
flyToggleBtn.MouseButton1Click:Connect(function()
    if isFlying then
        stopFlying()
    else
        startFlying()
    end
end)

-- Noclip toggle
noclipToggleBtn.MouseButton1Click:Connect(function()
    if isNoclipping then
        stopNoclip()
    else
        startNoclip()
    end
end)

-- Fly speed update
flySpeedSlider.FocusLost:Connect(function()
    local speed = tonumber(flySpeedSlider.Text) or 50
    speed = math.max(1, math.min(200, speed))
    flySpeed = speed
    flySpeedSlider.Text = tostring(flySpeed)
    flySpeedLabel.Text = "✈️ Fly Speed: " .. flySpeed
end)

-- Noclip speed update
noclipSpeedSlider.FocusLost:Connect(function()
    local speed = tonumber(noclipSpeedSlider.Text) or 25
    speed = math.max(1, math.min(100, speed))
    noclipSpeed = speed
    noclipSpeedSlider.Text = tostring(noclipSpeed)
    noclipSpeedLabel.Text = "👻 Noclip Speed: " .. noclipSpeed
end)

-- WalkSpeed apply
applyWalkSpeedBtn.MouseButton1Click:Connect(function()
    local walkSpeed = tonumber(walkSpeedInput.Text) or 16
    walkSpeed = math.max(1, math.min(200, walkSpeed))
    
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = walkSpeed
            walkSpeedLabel.Text = "🚶 Walk Speed: " .. walkSpeed
        end
    end
end)

-- ============ FLY MOVEMENT ============
RunService.RenderStepped:Connect(function()
    if not isFlying or not flyBody or not flyBodyVelocity then return end

    local moveDirection = Vector3.new(0, 0, 0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = moveDirection + Vector3.new(0, 0, -1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection = moveDirection + Vector3.new(0, 0, 1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection = moveDirection + Vector3.new(-1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection = moveDirection + Vector3.new(1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection = moveDirection + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        moveDirection = moveDirection + Vector3.new(0, -1, 0)
    end

    local camera = workspace.CurrentCamera
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local finalDirection = (forward * moveDirection.Z) + (right * moveDirection.X) + (Vector3.new(0, 1, 0) * moveDirection.Y)

    if finalDirection.Magnitude > 0 then
        finalDirection = finalDirection.Unit
    end

    flyBodyVelocity.Velocity = finalDirection * flySpeed
end)

-- ============ NOCLIP MOVEMENT ============
RunService.RenderStepped:Connect(function()
    if not isNoclipping then return end

    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local moveDirection = Vector3.new(0, 0, 0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = moveDirection + Vector3.new(0, 0, -1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection = moveDirection + Vector3.new(0, 0, 1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection = moveDirection + Vector3.new(-1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection = moveDirection + Vector3.new(1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection = moveDirection + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        moveDirection = moveDirection + Vector3.new(0, -1, 0)
    end

    local camera = workspace.CurrentCamera
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local finalDirection = (forward * moveDirection.Z) + (right * moveDirection.X) + (Vector3.new(0, 1, 0) * moveDirection.Y)

    if finalDirection.Magnitude > 0 then
        finalDirection = finalDirection.Unit
        hrp.CFrame = hrp.CFrame + (finalDirection * noclipSpeed * 0.016)
    end
end)

-- ============ MINIMIZE LOGIC ============
local isMinimized = false
local expandedSize = mainFrame.Size
local minimizeDebounce = false
local currentSizeTween = nil

minimizeButton.MouseButton1Click:Connect(function()
    if minimizeDebounce then return end
    minimizeDebounce = true

    if currentSizeTween then
        currentSizeTween:Cancel()
        currentSizeTween = nil
    end

    isMinimized = not isMinimized

    if isMinimized then
        currentSizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 450, 0, 36)
        })
        minimizeButton.Text = "+"
        contentFrame.Visible = false
    else
        contentFrame.Visible = true
        currentSizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = expandedSize
        })
        minimizeButton.Text = "–"
    end

    currentSizeTween:Play()
    currentSizeTween.Completed:Connect(function()
        minimizeDebounce = false
    end)
end)

-- ============ DRAGGING ============
local dragging = false
local dragInput
local dragStart
local startPos

titleLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleLabel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)