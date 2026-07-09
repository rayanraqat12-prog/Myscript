--[[
    Galaxy Teleporter GUI
    ---------------------
    A LocalScript that lets a player:
      - Save their current position under a custom name
      - Browse saved positions in a scrolling menu
      - Select one and teleport to it
      - Drag the window around, minimize it

    HOW TO USE:
    1. Place this as a LocalScript inside StarterPlayer > StarterPlayerScripts.
    2. That's it — works out of the box for single player / personal testing.

    NOTE ON MULTIPLAYER GAMES:
    This teleports the LOCAL player's own character by setting their
    HumanoidRootPart CFrame directly. That's fine for solo testing, private
    servers, or games without anti-cheat. If your game has server-side anti-
    exploit / anti-cheat systems, they may flag or reset a client-side
    teleport. For a production multiplayer game you'd normally fire a
    RemoteEvent and have the SERVER move the character instead. Happy to
    build that server-authoritative version too if you need it.
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

-- ============ GUI SETUP ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyTeleporterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 340)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -170)
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

-- ============ BODY ============
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, 0, 1, -36)
bodyFrame.Position = UDim2.new(0, 0, 0, 36)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ZIndex = 2
bodyFrame.Parent = mainFrame

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
nameBox.Parent = bodyFrame

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
saveButton.Parent = bodyFrame

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
menuLabel.Parent = bodyFrame

-- Scrolling list of saved positions
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PositionList"
scrollFrame.Size = UDim2.new(1, -24, 1, -178)
scrollFrame.Position = UDim2.new(0, 12, 0, 118)
scrollFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 40)
scrollFrame.BackgroundTransparency = 0.3
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 3
scrollFrame.Parent = bodyFrame

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
teleportButton.Size = UDim2.new(1, -24, 0, 40)
teleportButton.Position = UDim2.new(0, 12, 1, -50)
teleportButton.BackgroundColor3 = Color3.fromRGB(50, 25, 100)
teleportButton.Text = "🚀 Teleport to Selected"
teleportButton.TextColor3 = Color3.fromRGB(240, 230, 255)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 14
teleportButton.AutoButtonColor = false
teleportButton.ZIndex = 3
teleportButton.Parent = bodyFrame

local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 10)
teleportCorner.Parent = teleportButton

local teleportStroke = Instance.new("UIStroke")
teleportStroke.Color = Color3.fromRGB(150, 100, 255)
teleportStroke.Transparency = 0.3
teleportStroke.Parent = teleportButton

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

-- ============ SAVE BUTTON ============
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

-- ============ TELEPORT BUTTON ============
teleportButton.MouseButton1Click:Connect(function()
    if not selectedIndex or not savedPositions[selectedIndex] then return end

    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = savedPositions[selectedIndex].cframe
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
            Size = UDim2.new(0, 260, 0, 36)
        })
        minimizeButton.Text = "+"
        bodyFrame.Visible = false
    else
        bodyFrame.Visible = true
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

-- ============ DRAGGING (works with touch AND mouse) ============
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
