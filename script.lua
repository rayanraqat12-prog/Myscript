--[[
    Galaxy Teleporter GUI – LocalScript (mobile friendly)
    - 2D dragging everywhere (window, cube, auto TP)
    - Height 280 px
    - List never glitches (rebuilt after deletions)
    - Cosmic cube & auto‑teleport with tap detection
    - Noclip (simple wall‑pass, no speed)
    - Invisible, WalkSpeed
    - Fly removed entirely
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============ STATE ============
local savedPositions = {}
local selectedIndex = nil
local teleportMethod = "instant"

local isNoclipping = false
local originalCollisionGroups = {}

local isInvisible = false
local originalCharacterParts = {}

local autoTeleportEnabled = false
local autoTeleportGui = nil
local autoTeleportButton = nil

local function clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

-- ============ GUI SETUP ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyTeleporterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main window (height 280)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 380, 0, 280)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

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

-- Star helper
local function addStar(parent, xScale, yScale, size, brightness)
    local star = Instance.new("Frame")
    star.Size = UDim2.new(0, size, 0, size)
    star.Position = UDim2.new(xScale, 0, yScale, 0)
    star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    star.BackgroundTransparency = 1 - brightness
    star.BorderSizePixel = 0
    star.ZIndex = 1
    star.Parent = parent
    Instance.new("UICorner", star).CornerRadius = UDim.new(1, 0)
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

Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 16)
titleBarFix.Position = UDim2.new(0, 0, 1, -16)
titleBarFix.BackgroundColor3 = titleBar.BackgroundColor3
titleBarFix.BackgroundTransparency = 0.2
titleBarFix.BorderSizePixel = 0
titleBarFix.ZIndex = 2
titleBarFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ Galaxy Teleporter"
titleLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3
titleLabel.Active = false
titleLabel.Parent = titleBar

-- ============ DRAG HANDLE (2D) ============
local dragHandle = Instance.new("TextButton")
dragHandle.Size = UDim2.new(1, -36, 1, 0)
dragHandle.Position = UDim2.new(0, 0, 0, 0)
dragHandle.BackgroundTransparency = 1
dragHandle.Text = ""
dragHandle.ZIndex = 2
dragHandle.Parent = titleBar

local dragActive = false
local dragStartTouch = nil
local dragStartFramePos = nil

dragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragStartTouch = input.Position
        dragStartFramePos = mainFrame.AbsolutePosition
    end
end)

dragHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartTouch
        local newX = dragStartFramePos.X + delta.X
        local newY = dragStartFramePos.Y + delta.Y
        mainFrame.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- ============ MINIMIZE BUTTON ============
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 28, 0, 28)
minimizeButton.Position = UDim2.new(1, -34, 0.5, -14)
minimizeButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
minimizeButton.Text = "⬡"
minimizeButton.TextColor3 = Color3.fromRGB(0, 255, 0)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.ZIndex = 3
minimizeButton.Parent = titleBar

Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(1, 0)

-- ============ MAIN CONTENT ============
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 1, -30)
contentFrame.Position = UDim2.new(0, 0, 0, 30)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(0, 90, 1, 0)
tabBar.Position = UDim2.new(0, 0, 0, 0)
tabBar.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 2
tabBar.Parent = contentFrame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 16)
local tabBarStroke = Instance.new("UIStroke", tabBar)
tabBarStroke.Color = Color3.fromRGB(100, 70, 180)
tabBarStroke.Transparency = 0.5

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

-- Teleporter tab button
local teleporterTabBtn = Instance.new("TextButton")
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
Instance.new("UICorner", teleporterTabBtn).CornerRadius = UDim.new(0, 8)
local teleporterTabStroke = Instance.new("UIStroke", teleporterTabBtn)
teleporterTabStroke.Color = Color3.fromRGB(150, 100, 255)
teleporterTabStroke.Transparency = 0.3

-- Misc tab button
local miscTabBtn = Instance.new("TextButton")
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
Instance.new("UICorner", miscTabBtn).CornerRadius = UDim.new(0, 8)
local miscTabStroke = Instance.new("UIStroke", miscTabBtn)
miscTabStroke.Color = Color3.fromRGB(100, 70, 180)
miscTabStroke.Transparency = 0.5

-- Body
local bodyFrame = Instance.new("Frame")
bodyFrame.Size = UDim2.new(1, -90, 1, 0)
bodyFrame.Position = UDim2.new(0, 90, 0, 0)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ZIndex = 2
bodyFrame.Parent = contentFrame

-- ============ TELEPORTER TAB ============
local teleporterTab = Instance.new("Frame")
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

-- Name input
local nameBox = Instance.new("TextBox")
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
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", nameBox).Color = Color3.fromRGB(120, 90, 200)
nameBox.UIStroke.Transparency = 0.4

-- Save button
local saveButton = Instance.new("TextButton")
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
Instance.new("UICorner", saveButton).CornerRadius = UDim.new(0, 6)

-- Method label
local methodLabel = Instance.new("TextLabel")
methodLabel.Size = UDim2.new(1, 0, 0, 12)
methodLabel.BackgroundTransparency = 1
methodLabel.Text = "Method: instant"
methodLabel.TextColor3 = Color3.fromRGB(170, 150, 210)
methodLabel.Font = Enum.Font.GothamBold
methodLabel.TextSize = 8
methodLabel.TextXAlignment = Enum.TextXAlignment.Left
methodLabel.ZIndex = 3
methodLabel.LayoutOrder = 3
methodLabel.Parent = teleporterScroll

-- Method buttons container
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

local instantMethodBtn = Instance.new("TextButton")
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
Instance.new("UICorner", instantMethodBtn).CornerRadius = UDim.new(0, 5)

local tweenMethodBtn = Instance.new("TextButton")
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
Instance.new("UICorner", tweenMethodBtn).CornerRadius = UDim.new(0, 5)

local realisticMethodBtn = Instance.new("TextButton")
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
Instance.new("UICorner", realisticMethodBtn).CornerRadius = UDim.new(0, 5)

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

-- Scrolling list
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 0, 80)
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
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)
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

-- Bottom buttons
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

local teleportButton = Instance.new("TextButton")
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
Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", teleportButton).Color = Color3.fromRGB(150, 100, 255)
teleportButton.UIStroke.Transparency = 0.3

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

local deleteButton = Instance.new("TextButton")
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
Instance.new("UICorner", deleteButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", deleteButton).Color = Color3.fromRGB(200, 100, 100)
deleteButton.UIStroke.Transparency = 0.3

local clearButton = Instance.new("TextButton")
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
Instance.new("UICorner", clearButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", clearButton).Color = Color3.fromRGB(200, 80, 80)
clearButton.UIStroke.Transparency = 0.3

-- ============ MISC TAB (simplified) ============
local miscTab = Instance.new("Frame")
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

-- Noclip toggle (no speed)
local noclipToggleBtn = Instance.new("TextButton")
noclipToggleBtn.Size = UDim2.new(1, 0, 0, 32)
noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
noclipToggleBtn.Text = "👻 Noclip: OFF"
noclipToggleBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
noclipToggleBtn.Font = Enum.Font.GothamBold
noclipToggleBtn.TextSize = 11
noclipToggleBtn.AutoButtonColor = false
noclipToggleBtn.ZIndex = 3
noclipToggleBtn.LayoutOrder = 1
noclipToggleBtn.Parent = miscScroll
Instance.new("UICorner", noclipToggleBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", noclipToggleBtn).Color = Color3.fromRGB(200, 160, 80)
noclipToggleBtn.UIStroke.Transparency = 0.3

-- Invisible toggle
local invisibleToggleBtn = Instance.new("TextButton")
invisibleToggleBtn.Size = UDim2.new(1, 0, 0, 32)
invisibleToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
invisibleToggleBtn.Text = "👁️ Invisible"
invisibleToggleBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
invisibleToggleBtn.Font = Enum.Font.GothamBold
invisibleToggleBtn.TextSize = 12
invisibleToggleBtn.AutoButtonColor = false
invisibleToggleBtn.ZIndex = 3
invisibleToggleBtn.LayoutOrder = 2
invisibleToggleBtn.Parent = miscScroll
Instance.new("UICorner", invisibleToggleBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", invisibleToggleBtn).Color = Color3.fromRGB(180, 120, 220)
invisibleToggleBtn.UIStroke.Transparency = 0.3

-- Auto Teleport toggle
local autoTpToggleBtn = Instance.new("TextButton")
autoTpToggleBtn.Size = UDim2.new(1, 0, 0, 32)
autoTpToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 100)
autoTpToggleBtn.Text = "⚡ Auto TP OFF"
autoTpToggleBtn.TextColor3 = Color3.fromRGB(200, 255, 255)
autoTpToggleBtn.Font = Enum.Font.GothamBold
autoTpToggleBtn.TextSize = 11
autoTpToggleBtn.AutoButtonColor = false
autoTpToggleBtn.ZIndex = 3
autoTpToggleBtn.LayoutOrder = 3
autoTpToggleBtn.Parent = miscScroll
Instance.new("UICorner", autoTpToggleBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", autoTpToggleBtn).Color = Color3.fromRGB(0, 200, 200)
autoTpToggleBtn.UIStroke.Transparency = 0.3

-- Walk speed label
local walkSpeedLabel = Instance.new("TextLabel")
walkSpeedLabel.Size = UDim2.new(1, 0, 0, 16)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Text = "🚶 Walk: 16"
walkSpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
walkSpeedLabel.Font = Enum.Font.GothamBold
walkSpeedLabel.TextSize = 10
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
walkSpeedLabel.ZIndex = 3
walkSpeedLabel.LayoutOrder = 4
walkSpeedLabel.Parent = miscScroll

-- Walk speed input
local walkSpeedInput = Instance.new("TextBox")
walkSpeedInput.Size = UDim2.new(1, 0, 0, 24)
walkSpeedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
walkSpeedInput.PlaceholderText = "1-200"
walkSpeedInput.Text = "16"
walkSpeedInput.TextColor3 = Color3.fromRGB(230, 220, 255)
walkSpeedInput.PlaceholderColor3 = Color3.fromRGB(140, 120, 180)
walkSpeedInput.Font = Enum.Font.Gotham
walkSpeedInput.TextSize = 11
walkSpeedInput.ZIndex = 3
walkSpeedInput.LayoutOrder = 5
walkSpeedInput.Parent = miscScroll
Instance.new("UICorner", walkSpeedInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", walkSpeedInput).Color = Color3.fromRGB(120, 90, 200)
walkSpeedInput.UIStroke.Transparency = 0.4

-- Apply walk speed button
local applyWalkSpeedBtn = Instance.new("TextButton")
applyWalkSpeedBtn.Size = UDim2.new(1, 0, 0, 32)
applyWalkSpeedBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
applyWalkSpeedBtn.Text = "✓ Apply"
applyWalkSpeedBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
applyWalkSpeedBtn.Font = Enum.Font.GothamBold
applyWalkSpeedBtn.TextSize = 12
applyWalkSpeedBtn.AutoButtonColor = false
applyWalkSpeedBtn.ZIndex = 3
applyWalkSpeedBtn.LayoutOrder = 6
applyWalkSpeedBtn.Parent = miscScroll
Instance.new("UICorner", applyWalkSpeedBtn).CornerRadius = UDim.new(0, 6)

-- ============ POSITION LIST LOGIC ============
local entryButtons = {}

local function clearList()
    for _, btn in pairs(entryButtons) do
        btn:Destroy()
    end
    entryButtons = {}
end

local function rebuildList()
    clearList()
    for i, posData in ipairs(savedPositions) do
        local entryButton = Instance.new("TextButton")
        entryButton.Size = UDim2.new(1, 0, 0, 22)
        entryButton.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
        entryButton.Text = "  ✧ " .. posData.name
        entryButton.TextColor3 = Color3.fromRGB(220, 210, 255)
        entryButton.Font = Enum.Font.Gotham
        entryButton.TextSize = 9
        entryButton.TextXAlignment = Enum.TextXAlignment.Left
        entryButton.AutoButtonColor = false
        entryButton.ZIndex = 4
        entryButton.LayoutOrder = i
        entryButton.Parent = scrollFrame

        Instance.new("UICorner", entryButton).CornerRadius = UDim.new(0, 6)
        local entryStroke = Instance.new("UIStroke", entryButton)
        entryStroke.Color = Color3.fromRGB(150, 100, 255)
        entryStroke.Transparency = (i == selectedIndex) and 0 or 0.6
        if i == selectedIndex then
            entryButton.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
        end

        entryButton.Activated:Connect(function()
            selectedIndex = i
            for idx, btn in pairs(entryButtons) do
                if idx == selectedIndex then
                    btn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
                    btn.UIStroke.Transparency = 0
                else
                    btn.BackgroundColor3 = Color3.fromRGB(35, 25, 65)
                    btn.UIStroke.Transparency = 0.6
                end
            end
        end)

        entryButtons[i] = entryButton
    end
end

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

-- ============ TELEPORT METHODS ============
local function instantTeleport(targetCFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = targetCFrame
end

local function smoothTeleport(targetCFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local function realisticTeleport(targetCFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local startPos = hrp.CFrame
    local dist = (targetCFrame.Position - startPos.Position).Magnitude
    local steps = math.ceil(dist / 50)
    for i = 1, steps do
        if not char or not char.Parent then break end
        hrp.CFrame = startPos:Lerp(targetCFrame, i / steps)
        RunService.RenderStepped:Wait()
    end
    if char and char.Parent then
        hrp.CFrame = targetCFrame
    end
end

-- ============ NOCLIP (simple toggle) ============
local function startNoclip()
    if isNoclipping then return end
    isNoclipping = true
    local char = player.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisionGroups[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    noclipToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
    noclipToggleBtn.Text = "👻 Noclip: ON"
end

local function stopNoclip()
    if not isNoclipping then return end
    isNoclipping = false
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
    noclipToggleBtn.Text = "👻 Noclip: OFF"
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
        elseif part:IsA("Decal") or part:IsA("Texture") then
            originalCharacterParts[part] = part.Transparency
            part.Transparency = 1
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
        for obj, trans in pairs(originalCharacterParts) do
            if obj and obj.Parent then obj.Transparency = trans end
        end
    end
    originalCharacterParts = {}
    invisibleToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    invisibleToggleBtn.Text = "👁️ Invisible"
end

-- ============ MINIMIZED COSMIC CUBE ============
local minimizedCube = Instance.new("Frame")
minimizedCube.Size = UDim2.new(0, 60, 0, 60)
minimizedCube.BackgroundColor3 = Color3.fromRGB(5, 2, 20)
minimizedCube.BorderSizePixel = 0
minimizedCube.Visible = false
minimizedCube.Parent = screenGui
Instance.new("UICorner", minimizedCube).CornerRadius = UDim.new(0, 12)
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

for i = 1, 4 do
    addStar(minimizedCube, math.random(5,95)/100, math.random(5,95)/100, 1, 0.9)
end

local sLabel = Instance.new("TextLabel")
sLabel.Size = UDim2.new(1, 0, 1, 0)
sLabel.BackgroundTransparency = 1
sLabel.Text = "S"
sLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
sLabel.Font = Enum.Font.GothamBlack
sLabel.TextSize = 36
sLabel.TextStrokeTransparency = 0.5
sLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
sLabel.ZIndex = 5
sLabel.Parent = minimizedCube

-- Cube drag handle + tap
local cubeDragHandle = Instance.new("TextButton")
cubeDragHandle.Size = UDim2.new(1, 0, 1, 0)
cubeDragHandle.BackgroundTransparency = 1
cubeDragHandle.Text = ""
cubeDragHandle.ZIndex = 10
cubeDragHandle.Parent = minimizedCube

local cubeTouchStart = nil
local cubeDragging = false
local cubeStartTouchPos = nil
local cubeStartAbsPos = nil

cubeDragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        cubeTouchStart = input.Position
        cubeDragging = false
        cubeStartTouchPos = input.Position
        cubeStartAbsPos = minimizedCube.AbsolutePosition
    end
end)

cubeDragHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if cubeTouchStart and not cubeDragging then
            minimizedCube.Visible = false
            mainFrame.Visible = true
            contentFrame.Visible = true
        end
        cubeTouchStart = nil
        cubeDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if cubeTouchStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local dist = (input.Position - cubeTouchStart).Magnitude
        if dist > 8 then
            cubeDragging = true
        end
        if cubeDragging then
            local delta = input.Position - cubeStartTouchPos
            local newX = cubeStartAbsPos.X + delta.X
            local newY = cubeStartAbsPos.Y + delta.Y
            minimizedCube.Position = UDim2.new(0, newX, 0, newY)
        end
    end
end)

-- ============ MINIMIZE BUTTON ============
minimizeButton.Activated:Connect(function()
    if mainFrame.Visible then
        contentFrame.Visible = false
        mainFrame.Visible = false
        minimizedCube.Visible = true
        minimizedCube.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
    else
        minimizedCube.Visible = false
        mainFrame.Visible = true
        contentFrame.Visible = true
    end
end)

-- ============ AUTO TELEPORT BUTTON (2D draggable) ============
local function createAutoTeleportButton()
    if autoTeleportGui then return end
    autoTeleportGui = Instance.new("ScreenGui")
    autoTeleportGui.Name = "AutoTeleportGui"
    autoTeleportGui.ResetOnSpawn = false
    autoTeleportGui.Parent = playerGui

    autoTeleportButton = Instance.new("TextButton")
    autoTeleportButton.Size = UDim2.new(0, 120, 0, 40)
    autoTeleportButton.Position = UDim2.new(1, -130, 1, -50)
    autoTeleportButton.BackgroundColor3 = Color3.fromRGB(10, 8, 30)
    autoTeleportButton.BorderSizePixel = 0
    autoTeleportButton.Text = "TELEPORT"
    autoTeleportButton.TextColor3 = Color3.fromRGB(0, 255, 100)
    autoTeleportButton.Font = Enum.Font.GothamBlack
    autoTeleportButton.TextSize = 18
    autoTeleportButton.TextStrokeTransparency = 0.5
    autoTeleportButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    autoTeleportButton.AutoButtonColor = false
    autoTeleportButton.ZIndex = 10
    autoTeleportButton.Parent = autoTeleportGui

    Instance.new("UICorner", autoTeleportButton).CornerRadius = UDim.new(0, 12)
    local btnGradient = Instance.new("UIGradient")
    btnGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 20, 60)),
    })
    btnGradient.Rotation = 45
    btnGradient.Parent = autoTeleportButton
    Instance.new("UIStroke", autoTeleportButton).Color = Color3.fromRGB(0, 255, 100)
    autoTeleportButton.UIStroke.Thickness = 2
    autoTeleportButton.UIStroke.Transparency = 0.3

    for i = 1, 3 do
        addStar(autoTeleportButton, math.random(5,95)/100, math.random(5,95)/100, 1, 0.8)
    end

    local btnTouchStart = nil
    local btnDragging = false
    local btnStartTouchPos = nil
    local btnStartAbsPos = nil

    autoTeleportButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            btnTouchStart = input.Position
            btnDragging = false
            btnStartTouchPos = input.Position
            btnStartAbsPos = autoTeleportButton.AbsolutePosition
        end
    end)

    autoTeleportButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if btnTouchStart and not btnDragging then
                if selectedIndex and savedPositions[selectedIndex] then
                    local target = savedPositions[selectedIndex].cframe
                    if teleportMethod == "instant" then
                        instantTeleport(target)
                    elseif teleportMethod == "smooth" then
                        smoothTeleport(target)
                    elseif teleportMethod == "realistic" then
                        realisticTeleport(target)
                    end
                end
            end
            btnTouchStart = nil
            btnDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if btnTouchStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local dist = (input.Position - btnTouchStart).Magnitude
            if dist > 8 then
                btnDragging = true
            end
            if btnDragging then
                local delta = input.Position - btnStartTouchPos
                local newX = btnStartAbsPos.X + delta.X
                local newY = btnStartAbsPos.Y + delta.Y
                autoTeleportButton.Position = UDim2.new(0, newX, 0, newY)
            end
        end
    end)
end

local function destroyAutoTeleportButton()
    if autoTeleportGui then
        autoTeleportGui:Destroy()
        autoTeleportGui = nil
        autoTeleportButton = nil
    end
end

-- ============ BUTTON EVENTS (Activated) ============
teleporterTabBtn.Activated:Connect(function()
    teleporterTab.Visible = true
    miscTab.Visible = false
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
    teleporterTabStroke.Transparency = 0.3
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    miscTabStroke.Transparency = 0.5
end)

miscTabBtn.Activated:Connect(function()
    teleporterTab.Visible = false
    miscTab.Visible = true
    miscTabBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 120)
    miscTabStroke.Transparency = 0.3
    teleporterTabBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
    teleporterTabStroke.Transparency = 0.5
end)

instantMethodBtn.Activated:Connect(function()
    teleportMethod = "instant"
    methodLabel.Text = "Method: instant"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

tweenMethodBtn.Activated:Connect(function()
    teleportMethod = "smooth"
    methodLabel.Text = "Method: smooth"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
end)

realisticMethodBtn.Activated:Connect(function()
    teleportMethod = "realistic"
    methodLabel.Text = "Method: realistic"
    instantMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    tweenMethodBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 100)
    realisticMethodBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
end)

saveButton.Activated:Connect(function()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local posName = nameBox.Text
    if posName == "" then posName = "Position #" .. (#savedPositions + 1) end
    table.insert(savedPositions, {name = posName, cframe = hrp.CFrame})
    rebuildList()
    selectedIndex = #savedPositions
    refreshHighlights()
    nameBox.Text = ""
end)

teleportButton.Activated:Connect(function()
    if not selectedIndex or not savedPositions[selectedIndex] then return end
    local targetCFrame = savedPositions[selectedIndex].cframe
    if teleportMethod == "instant" then instantTeleport(targetCFrame)
    elseif teleportMethod == "smooth" then smoothTeleport(targetCFrame)
    elseif teleportMethod == "realistic" then realisticTeleport(targetCFrame)
    end
end)

deleteButton.Activated:Connect(function()
    if not selectedIndex then return end
    table.remove(savedPositions, selectedIndex)
    selectedIndex = nil
    rebuildList()
end)

clearButton.Activated:Connect(function()
    savedPositions = {}
    selectedIndex = nil
    rebuildList()
end)

noclipToggleBtn.Activated:Connect(function()
    if isNoclipping then stopNoclip() else startNoclip() end
end)

invisibleToggleBtn.Activated:Connect(function()
    if isInvisible then stopInvisible() else startInvisible() end
end)

autoTpToggleBtn.Activated:Connect(function()
    autoTeleportEnabled = not autoTeleportEnabled
    if autoTeleportEnabled then
        createAutoTeleportButton()
        autoTpToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
        autoTpToggleBtn.Text = "⚡ Auto TP ON"
    else
        destroyAutoTeleportButton()
        autoTpToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 100)
        autoTpToggleBtn.Text = "⚡ Auto TP OFF"
    end
end)

applyWalkSpeedBtn.Activated:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local speed = tonumber(walkSpeedInput.Text)
    if speed then
        hum.WalkSpeed = clamp(speed, 1, 200)
        walkSpeedLabel.Text = "🚶 Walk: " .. math.floor(hum.WalkSpeed)
    end
end)

-- Initial list build
rebuildList()
