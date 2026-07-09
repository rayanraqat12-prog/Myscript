--[[
    Galaxy Teleporter GUI with Tabs
    --------------------------------
    A LocalScript that lets a player:
      - Save positions and teleport (Teleporter Tab)
      - Fly with adjustable speed (Misc Tab)
      - Change WalkSpeed (Misc Tab)
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

-- Fly state
local isFlying = false
local flySpeed = 50
local flyDirection = Vector3.new(0, 0, 0)
local flyBody = nil
local flyBodyVelocity = nil
local flyConnection = nil

-- ============ GUI SETUP ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyTeleporterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 420)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -210)
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

-- ============ TAB BAR ============
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 2
tabBar.Parent = mainFrame

local tabBarStroke = Instance.new("UIStroke")
tabBarStroke.Color = Color3.fromRGB(100, 70, 180)
tabBarStroke.Transparency = 0.5
tabBarStroke.Parent = tabBar

-- Teleporter Tab Button
local teleporterTabBtn = Instance.new("TextButton")
teleporterTabBtn.Name = "TeleporterTab"
teleporterTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
teleporterTabBtn.Position = UDim2.new(0, 0, 0, 0)
teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
teleporterTabBtn.Text = "🏠 Teleporter"
teleporterTabBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
teleporterTabBtn.Font = Enum.Font.GothamBold
teleporterTabBtn.TextSize = 13
teleporterTabBtn.AutoButtonColor = false
teleporterTabBtn.ZIndex = 3
teleporterTabBtn.Parent = tabBar

local teleporterTabCorner = Instance.new("UICorner")
teleporterTabCorner.CornerRadius = UDim.new(0, 8)
teleporterTabCorner.Parent = teleporterTabBtn

-- Misc Tab Button
local miscTabBtn = Instance.new("TextButton")
miscTabBtn.Name = "MiscTab"
miscTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
miscTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
miscTabBtn.Text = "⭐ Misc"
miscTabBtn.TextColor3 = Color3.fromRGB(200, 180, 230)
miscTabBtn.Font = Enum.Font.GothamBold
miscTabBtn.TextSize = 13
miscTabBtn.AutoButtonColor = false
miscTabBtn.ZIndex = 3
miscTabBtn.Parent = tabBar

local miscTabCorner = Instance.new("UICorner")
miscTabCorner.CornerRadius = UDim.new(0, 8)
miscTabCorner.Parent = miscTabBtn

-- ============ BODY ============
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, 0, 1, -76)
bodyFrame.Position = UDim2.new(0, 0, 0, 76)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ZIndex = 2
bodyFrame.Parent = mainFrame

-- ============ TELEPORTER TAB ============
local teleporterTab = Instance.new("Frame")
teleporterTab.Name = "TeleporterTab"
teleporterTab.Size = UDim2.new(1, 0, 1, 0)
teleporterTab.BackgroundTransparency = 1
teleporterTab.ZIndex = 3
teleporterTab.Parent = bodyFrame
teleporterTab.Visible = true

-- Name input box
local nameBox = Instance.new("TextBox")
nameBox.Name = "NameBox"
nameBox.Size = UDim2.new(1, -24, 0, 34)
nameBox.Position = UDim2.new(0, 12, 0, 10)
nameBox.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
nameBox.PlaceholderText = "Name this position..."
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(230, 220, 255)
nameBox.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 14
nameBox.ClearTextOnFocus = false
nameBox.ZIndex = 3
nameBox.Parent = teleporterTab

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
saveButton.Size = UDim2.new(1, -24, 0, 36)
saveButton.Position = UDim2.new(0, 12, 0, 52)
saveButton.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
saveButton.Text = "✦ Save Current Position"
saveButton.TextColor3 = Color3.fromRGB(240, 230, 255)
saveButton.Font = Enum.Font.GothamBold
saveButton.TextSize = 14
saveButton.AutoButtonColor = false
saveButton.ZIndex = 3
saveButton.Parent = teleporterTab

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

-- Menu label
local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, -24, 0, 18)
menuLabel.Position = UDim2.new(0, 12, 0, 96)
menuLabel.BackgroundTransparency = 1
menuLabel.Text = "Saved Positions"
menuLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
menuLabel.Font = Enum.Font.GothamBold
menuLabel.TextSize = 13
menuLabel.TextXAlignment = Enum.TextXAlignment.Left
menuLabel.ZIndex = 3
menuLabel.Parent = teleporterTab

-- Scrolling list of saved positions
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PositionList"
scrollFrame.Size = UDim2.new(1, -24, 1, -210)
scrollFrame.Position = UDim2.new(0, 12, 0, 118)
scrollFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 40)
scrollFrame.BackgroundTransparency = 0.3
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 3
scrollFrame.Parent = teleporterTab

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 10)
scrollCorner.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = scrollFrame

-- Teleport button
local teleportButton = Instance.new("TextButton")
teleportButton.Name = "TeleportButton"
teleportButton.Size = UDim2.new(0.5, -4, 0, 34)
teleportButton.Position = UDim2.new(0, 12, 1, -82)
teleportButton.BackgroundColor3 = Color3.fromRGB(50, 25, 100)
teleportButton.Text = "🚀 Teleport"
teleportButton.TextColor3 = Color3.fromRGB(240, 230, 255)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 12
teleportButton.AutoButtonColor = false
teleportButton.ZIndex = 3
teleportButton.Parent = teleporterTab

local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 10)
teleportCorner.Parent = teleportButton

local teleportStroke = Instance.new("UIStroke")
teleportStroke.Color = Color3.fromRGB(150, 100, 255)
teleportStroke.Transparency = 0.3
teleportStroke.Parent = teleportButton

-- Delete button
local deleteButton = Instance.new("TextButton")
deleteButton.Name = "DeleteButton"
deleteButton.Size = UDim2.new(0.5, -4, 0, 34)
deleteButton.Position = UDim2.new(0.5, 4, 1, -82)
deleteButton.BackgroundColor3 = Color3.fromRGB(150, 30, 50)
deleteButton.Text = "🗑️ Delete"
deleteButton.TextColor3 = Color3.fromRGB(255, 200, 200)
deleteButton.Font = Enum.Font.GothamBold
deleteButton.TextSize = 12
deleteButton.AutoButtonColor = false
deleteButton.ZIndex = 3
deleteButton.Parent = teleporterTab

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
clearButton.Size = UDim2.new(1, -24, 0, 34)
clearButton.Position = UDim2.new(0, 12, 1, -40)
clearButton.BackgroundColor3 = Color3.fromRGB(100, 20, 20)
clearButton.Text = "⚠️ Clear All Positions"
clearButton.TextColor3 = Color3.fromRGB(255, 150, 150)
clearButton.Font = Enum.Font.GothamBold
clearButton.TextSize = 12
clearButton.AutoButtonColor = false
clearButton.ZIndex = 3
clearButton.Parent = teleporterTab

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

-- Fly Toggle Button
local flyToggleBtn = Instance.new("TextButton")
flyToggleBtn.Name = "FlyToggle"
flyToggleBtn.Size = UDim2.new(1, -24, 0, 40)
flyToggleBtn.Position = UDim2.new(0, 12, 0, 10)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 30)
flyToggleBtn.Text = "✈️ Start Flying"
flyToggleBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
flyToggleBtn.Font = Enum.Font.GothamBold
flyToggleBtn.TextSize = 14
flyToggleBtn.AutoButtonColor = false
flyToggleBtn.ZIndex = 3
flyToggleBtn.Parent = miscTab

local flyToggleCorner = Instance.new("UICorner")
flyToggleCorner.CornerRadius = UDim.new(0, 10)
flyToggleCorner.Parent = flyToggleBtn

local flyToggleStroke = Instance.new("UIStroke")
flyToggleStroke.Color = Color3.fromRGB(100, 200, 100)
flyToggleStroke.Transparency = 0.3
flyToggleStroke.Parent = flyToggleBtn

-- Fly Speed Label
local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Size = UDim2.new(1, -24, 0, 20)
flySpeedLabel.Position = UDim2.new(0, 12, 0, 60)
flySpeedLabel.BackgroundTransparency = 1
flySpeedLabel.Text = "✈️ Fly Speed: " .. flySpeed
flySpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
flySpeedLabel.Font = Enum.Font.GothamBold
flySpeedLabel.TextSize = 12
flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
flySpeedLabel.ZIndex = 3
flySpeedLabel.Parent = miscTab

-- Fly Speed Slider
local flySpeedSlider = Instance.new("TextBox")
flySpeedSlider.Name = "FlySpeedSlider"
flySpeedSlider.Size = UDim2.new(1, -24, 0, 30)
flySpeedSlider.Position = UDim2.new(0, 12, 0, 82)
flySpeedSlider.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
flySpeedSlider.PlaceholderText = "Enter speed (1-200)"
flySpeedSlider.Text = tostring(flySpeed)
flySpeedSlider.TextColor3 = Color3.fromRGB(230, 220, 255)
flySpeedSlider.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
flySpeedSlider.Font = Enum.Font.Gotham
flySpeedSlider.TextSize = 14
flySpeedSlider.ZIndex = 3
flySpeedSlider.Parent = miscTab

local flySpeedSliderCorner = Instance.new("UICorner")
flySpeedSliderCorner.CornerRadius = UDim.new(0, 10)
flySpeedSliderCorner.Parent = flySpeedSlider

local flySpeedSliderStroke = Instance.new("UIStroke")
flySpeedSliderStroke.Color = Color3.fromRGB(120, 90, 200)
flySpeedSliderStroke.Transparency = 0.4
flySpeedSliderStroke.Parent = flySpeedSlider

-- WalkSpeed Label
local walkSpeedLabel = Instance.new("TextLabel")
walkSpeedLabel.Size = UDim2.new(1, -24, 0, 20)
walkSpeedLabel.Position = UDim2.new(0, 12, 0, 125)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Text = "🚶 Walk Speed: 16"
walkSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
walkSpeedLabel.Font = Enum.Font.GothamBold
walkSpeedLabel.TextSize = 12
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
walkSpeedLabel.ZIndex = 3
walkSpeedLabel.Parent = miscTab

-- WalkSpeed Input
local walkSpeedInput = Instance.new("TextBox")
walkSpeedInput.Name = "WalkSpeedInput"
walkSpeedInput.Size = UDim2.new(1, -24, 0, 30)
walkSpeedInput.Position = UDim2.new(0, 12, 0, 147)
walkSpeedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
walkSpeedInput.PlaceholderText = "Enter walk speed (1-200)"
walkSpeedInput.Text = "16"
walkSpeedInput.TextColor3 = Color3.fromRGB(230, 220, 255)
walkSpeedInput.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
walkSpeedInput.Font = Enum.Font.Gotham
walkSpeedInput.TextSize = 14
walkSpeedInput.ZIndex = 3
walkSpeedInput.Parent = miscTab

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
applyWalkSpeedBtn.Size = UDim2.new(1, -24, 0, 36)
applyWalkSpeedBtn.Position = UDim2.new(0, 12, 0, 190)
applyWalkSpeedBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
applyWalkSpeedBtn.Text = "✓ Apply Walk Speed"
applyWalkSpeedBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
applyWalkSpeedBtn.Font = Enum.Font.GothamBold
applyWalkSpeedBtn.TextSize = 13
applyWalkSpeedBtn.AutoButtonColor = false
applyWalkSpeedBtn.ZIndex = 3
applyWalkSpeedBtn.Parent = miscTab

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
    entryButton.Size = UDim2.new(1, 0, 0, 34)
    entryButton.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
    entryButton.Text = "  ✧ " .. entryName
    entryButton.TextColor3 = Color3.fromRGB(220, 210, 255)
    entryButton.Font = Enum.Font.Gotham
    entryButton.TextSize = 14
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

-- ============ FLY FUNCTION ============
local function startFlying()
    if isFlying then return end
    isFlying = true

    local character = player.Character
    if not character then isFlying = false return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isFlying = false return end

    -- Create invisible flying body
    flyBody = Instance.new("Part")
    flyBody.Shape = Enum.PartType.Block
    flyBody.Transparency = 1
    flyBody.Size = Vector3.new(1, 1, 1)
    flyBody.CanCollide = false
    flyBody.CFrame = hrp.CFrame
    flyBody.TopSurface = Enum.SurfaceType.Smooth
    flyBody.BottomSurface = Enum.SurfaceType.Smooth
    flyBody.Parent = workspace

    -- Create BodyVelocity for movement
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
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
end)

miscTabBtn.MouseButton1Click:Connect(function()
    currentTab = "misc"
    teleporterTab.Visible = false
    miscTab.Visible = true
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
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

    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = savedPositions[selectedIndex].cframe
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

-- Fly speed update
flySpeedSlider.FocusLost:Connect(function()
    local speed = tonumber(flySpeedSlider.Text) or 50
    speed = math.max(1, math.min(200, speed))
    flySpeed = speed
    flySpeedSlider.Text = tostring(flySpeed)
    flySpeedLabel.Text = "✈️ Fly Speed: " .. flySpeed
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

    -- Get camera direction
    local camera = workspace.CurrentCamera
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local finalDirection = (forward * moveDirection.Z) + (right * moveDirection.X) + (Vector3.new(0, 1, 0) * moveDirection.Y)

    if finalDirection.Magnitude > 0 then
        finalDirection = finalDirection.Unit
    end

    flyBodyVelocity.Velocity = finalDirection * flySpeed
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
            Size = UDim2.new(0, 280, 0, 36)
        })
        minimizeButton.Text = "+"
        tabBar.Visible = false
        bodyFrame.Visible = false
    else
        bodyFrame.Visible = true
        tabBar.Visible = true
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
