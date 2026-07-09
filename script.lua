--[[
    Galaxy Teleporter v2
    Part 1/4
    Core + GUI + Drag + Minimize + Teleporter Base
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--================ STATE ================--

local savedPositions = {}
local selectedIndex = nil

local teleportMethod = "instant"

local isFlying = false
local flySpeed = 50

local isNoclipping = false
local noclipSpeed = 25

local savedWalkSpeed = 16

--================ GUI ================--

local gui = Instance.new("ScreenGui")
gui.Name = "GalaxyTeleporterV2"
gui.ResetOnSpawn = false
gui.Parent = playerGui


local main = Instance.new("Frame")
main.Size = UDim2.new(0,380,0,420)
main.Position = UDim2.new(.5,-190,.5,-210)
main.BackgroundColor3 = Color3.fromRGB(15,10,35)
main.BorderSizePixel = 0
main.Parent = gui


local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,15)
corner.Parent = main


local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-40,0,35)
title.Position = UDim2.new(0,10,0,0)
title.BackgroundTransparency = 1
title.Text = "✦ Galaxy Teleporter v2"
title.TextColor3 = Color3.fromRGB(230,220,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main


local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0,30,0,30)
minimize.Position = UDim2.new(1,-35,0,3)
minimize.Text = "-"
minimize.TextSize = 18
minimize.BackgroundColor3 = Color3.fromRGB(70,40,120)
minimize.TextColor3 = Color3.new(1,1,1)
minimize.Parent = main


local content = Instance.new("Frame")
content.Size = UDim2.new(1,-20,1,-50)
content.Position = UDim2.new(0,10,0,40)
content.BackgroundTransparency = 1
content.Parent = main


--================ DRAG =================--

local dragging = false
local dragStart
local startPos


title.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = main.Position

    end

end)


UserInputService.InputChanged:Connect(function(input)

    if dragging then

        local delta = input.Position - dragStart

        main.Position =
            UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )

    end

end)


UserInputService.InputEnded:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false

    end

end)


--================ MINIMIZE =================--

local minimized = false


minimize.MouseButton1Click:Connect(function()

    minimized = not minimized

    if minimized then

        content.Visible = false

        TweenService:Create(
            main,
            TweenInfo.new(.25),
            {Size = UDim2.new(0,380,0,40)}
        ):Play()

    else

        content.Visible = true

        TweenService:Create(
            main,
            TweenInfo.new(.25),
            {Size = UDim2.new(0,380,0,420)}
        ):Play()

    end

end)


--================ TELEPORT TAB =================--

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1,0,0,25)
nameBox.PlaceholderText = "Position name"
nameBox.BackgroundColor3 = Color3.fromRGB(35,25,60)
nameBox.TextColor3 = Color3.new(1,1,1)
nameBox.Parent = content


local saveButton = Instance.new("TextButton")
saveButton.Size = UDim2.new(1,0,0,25)
saveButton.Position = UDim2.new(0,0,0,30)
saveButton.Text = "Save Position"
saveButton.BackgroundColor3 = Color3.fromRGB(80,40,140)
saveButton.TextColor3 = Color3.new(1,1,1)
saveButton.Parent = content


local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1,0,0,150)
list.Position = UDim2.new(0,0,0,65)
list.BackgroundColor3 = Color3.fromRGB(25,20,45)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = content


local layout = Instance.new("UIListLayout")
layout.Parent = list


local function getRoot()

    local char = player.Character
    if not char then return end

    return char:FindFirstChild("HumanoidRootPart")

end


local function teleport(cf)

    local root = getRoot()

    if root then
        root.CFrame = cf
    end

end


local function refreshList()

    for _,v in pairs(list:GetChildren()) do

        if v:IsA("TextButton") then
            v:Destroy()
        end

    end


    for i,pos in ipairs(savedPositions) do

        local btn = Instance.new("TextButton")

        btn.Size = UDim2.new(1,0,0,25)
        btn.Text = pos.name
        btn.BackgroundColor3 =
            i == selectedIndex
            and Color3.fromRGB(100,60,180)
            or Color3.fromRGB(40,30,70)

        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = list


        btn.MouseButton1Click:Connect(function()

            selectedIndex = i
            refreshList()

        end)

    end

end


saveButton.MouseButton1Click:Connect(function()

    local root = getRoot()

    if root then

        table.insert(
            savedPositions,
            {
                name = nameBox.Text ~= "" and nameBox.Text
                or "Position "..#savedPositions+1,

                cframe = root.CFrame
            }
        )

        nameBox.Text = ""

        refreshList()

    end

end)--================ PART 2/4 =================
-- Teleport methods + delete/clear + controls


-- Method selector

local methodLabel = Instance.new("TextLabel")
methodLabel.Size = UDim2.new(1,0,0,20)
methodLabel.Position = UDim2.new(0,0,0,225)
methodLabel.BackgroundTransparency = 1
methodLabel.Text = "Method: Instant"
methodLabel.TextColor3 = Color3.fromRGB(220,210,255)
methodLabel.Parent = content


local methodFrame = Instance.new("Frame")
methodFrame.Size = UDim2.new(1,0,0,30)
methodFrame.Position = UDim2.new(0,0,0,250)
methodFrame.BackgroundTransparency = 1
methodFrame.Parent = content


local methodLayout = Instance.new("UIListLayout")
methodLayout.FillDirection = Enum.FillDirection.Horizontal
methodLayout.Padding = UDim.new(0,5)
methodLayout.Parent = methodFrame


local function createMethodButton(text)

    local button = Instance.new("TextButton")

    button.Size = UDim2.new(.33,-5,1,0)
    button.Text = text
    button.BackgroundColor3 = Color3.fromRGB(60,40,100)
    button.TextColor3 = Color3.new(1,1,1)
    button.Parent = methodFrame

    return button

end


local instantBtn = createMethodButton("Instant")
local smoothBtn = createMethodButton("Smooth")
local realisticBtn = createMethodButton("Realistic")



instantBtn.MouseButton1Click:Connect(function()

    teleportMethod = "instant"
    methodLabel.Text = "Method: Instant"

end)


smoothBtn.MouseButton1Click:Connect(function()

    teleportMethod = "smooth"
    methodLabel.Text = "Method: Smooth"

end)


realisticBtn.MouseButton1Click:Connect(function()

    teleportMethod = "realistic"
    methodLabel.Text = "Method: Realistic"

end)



-- Teleport functions

local function instantTeleport(cf)

    local root = getRoot()

    if root then
        root.CFrame = cf
    end

end



local function smoothTeleport(cf)

    local root = getRoot()

    if root then

        local tween =
            TweenService:Create(
                root,
                TweenInfo.new(
                    .5,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    CFrame = cf
                }
            )

        tween:Play()

    end

end



local function realisticTeleport(cf)

    local root = getRoot()

    if not root then
        return
    end


    local start = root.CFrame

    local distance =
        (cf.Position-start.Position).Magnitude


    local steps =
        math.clamp(
            math.floor(distance/40),
            5,
            100
        )


    for i=1,steps do

        local alpha=i/steps

        root.CFrame =
            start:Lerp(
                cf,
                alpha
            )

        RunService.Heartbeat:Wait()

    end


end



local function doTeleport()

    if not selectedIndex then
        return
    end


    local data =
        savedPositions[selectedIndex]


    if not data then
        return
    end



    if teleportMethod=="instant" then

        instantTeleport(data.cframe)


    elseif teleportMethod=="smooth" then

        smoothTeleport(data.cframe)


    elseif teleportMethod=="realistic" then

        realisticTeleport(data.cframe)

    end

end



local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1,0,0,30)
teleportButton.Position = UDim2.new(0,0,0,290)
teleportButton.Text = "🚀 Teleport"
teleportButton.BackgroundColor3 = Color3.fromRGB(90,50,150)
teleportButton.TextColor3 = Color3.new(1,1,1)
teleportButton.Parent = content


teleportButton.MouseButton1Click:Connect(doTeleport)



-- Delete selected

local deleteButton = Instance.new("TextButton")
deleteButton.Size = UDim2.new(.5,-5,0,30)
deleteButton.Position = UDim2.new(0,0,0,330)
deleteButton.Text = "Delete"
deleteButton.BackgroundColor3 = Color3.fromRGB(150,40,40)
deleteButton.TextColor3 = Color3.new(1,1,1)
deleteButton.Parent = content



deleteButton.MouseButton1Click:Connect(function()

    if selectedIndex then

        table.remove(
            savedPositions,
            selectedIndex
        )

        selectedIndex=nil

        refreshList()

    end

end)



-- Clear all

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(.5,-5,0,30)
clearButton.Position = UDim2.new(.5,5,0,330)
clearButton.Text = "Clear"
clearButton.BackgroundColor3 = Color3.fromRGB(120,30,30)
clearButton.TextColor3 = Color3.new(1,1,1)
clearButton.Parent = content



clearButton.MouseButton1Click:Connect(function()

    table.clear(savedPositions)

    selectedIndex=nil

    refreshList()

end)



-- Walk speed

local walkBox = Instance.new("TextBox")
walkBox.Size = UDim2.new(1,0,0,25)
walkBox.Position = UDim2.new(0,0,0,370)
walkBox.Text = "16"
walkBox.PlaceholderText = "WalkSpeed"
walkBox.BackgroundColor3 = Color3.fromRGB(35,25,60)
walkBox.TextColor3 = Color3.new(1,1,1)
walkBox.Parent = content



local applyWalk = Instance.new("TextButton")
applyWalk.Size = UDim2.new(1,0,0,25)
applyWalk.Position = UDim2.new(0,0,0,400)
applyWalk.Text = "Apply WalkSpeed"
applyWalk.BackgroundColor3 = Color3.fromRGB(70,100,150)
applyWalk.TextColor3 = Color3.new(1,1,1)
applyWalk.Parent = content



applyWalk.MouseButton1Click:Connect(function()

    local char = player.Character

    if char then

        local hum =
            char:FindFirstChildOfClass("Humanoid")

        if hum then

            local speed =
                tonumber(walkBox.Text)


            if speed then

                savedWalkSpeed=speed
                hum.WalkSpeed=speed

            end

        end

    end

end)--================ PART 3/4 =================
-- Fly + Noclip System


local flyConnection
local flyVelocity
local noclipConnection



--================ FLY =================


local function startFly()

    if isFlying then
        return
    end

    local root = getRoot()

    if not root then
        return
    end


    isFlying = true


    flyVelocity = Instance.new("BodyVelocity")

    flyVelocity.MaxForce =
        Vector3.new(
            math.huge,
            math.huge,
            math.huge
        )

    flyVelocity.Velocity =
        Vector3.zero

    flyVelocity.Parent = root



    flyConnection =
        RunService.RenderStepped:Connect(function()

            if not isFlying then
                return
            end


            local camera =
                workspace.CurrentCamera


            local direction =
                Vector3.zero



            local look =
                camera.CFrame.LookVector


            local right =
                camera.CFrame.RightVector



            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction += Vector3.new(
                    look.X,
                    0,
                    look.Z
                )
            end


            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction -= Vector3.new(
                    look.X,
                    0,
                    look.Z
                )
            end


            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction += right
            end


            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction -= right
            end


            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                direction += Vector3.yAxis
            end


            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                direction -= Vector3.yAxis
            end



            if direction.Magnitude > 0 then

                direction =
                    direction.Unit

            end



            flyVelocity.Velocity =
                direction * flySpeed


        end)

end



local function stopFly()

    isFlying=false


    if flyConnection then

        flyConnection:Disconnect()

        flyConnection=nil

    end



    if flyVelocity then

        flyVelocity:Destroy()

        flyVelocity=nil

    end

end





--================ NOCLIP =================


local function setCollision(state)

    local char =
        player.Character


    if not char then
        return
    end


    for _,part in pairs(char:GetDescendants()) do

        if part:IsA("BasePart") then

            part.CanCollide = state

        end

    end

end



local function startNoclip()

    if isNoclipping then
        return
    end


    isNoclipping=true



    noclipConnection =
        RunService.Stepped:Connect(function()

            if isNoclipping then

                setCollision(false)

            end

        end)

end



local function stopNoclip()

    isNoclipping=false


    if noclipConnection then

        noclipConnection:Disconnect()

        noclipConnection=nil

    end


    setCollision(true)

end




--================ MISC BUTTONS =================


local flyButton = Instance.new("TextButton")

flyButton.Size = UDim2.new(0,120,0,35)

flyButton.Position =
    UDim2.new(0,10,1,-45)

flyButton.Text="✈ Fly"

flyButton.BackgroundColor3 =
    Color3.fromRGB(50,120,50)

flyButton.TextColor3 =
    Color3.new(1,1,1)

flyButton.Parent=gui



flyButton.MouseButton1Click:Connect(function()

    if isFlying then

        stopFly()

        flyButton.Text="✈ Fly"

    else

        startFly()

        flyButton.Text="✈ Stop"

    end

end)




local noclipButton = Instance.new("TextButton")

noclipButton.Size =
    UDim2.new(0,120,0,35)

noclipButton.Position =
    UDim2.new(0,140,1,-45)

noclipButton.Text="👻 Noclip"

noclipButton.BackgroundColor3 =
    Color3.fromRGB(120,80,30)

noclipButton.TextColor3 =
    Color3.new(1,1,1)

noclipButton.Parent=gui



noclipButton.MouseButton1Click:Connect(function()


    if isNoclipping then

        stopNoclip()

        noclipButton.Text="👻 Noclip"


    else

        startNoclip()

        noclipButton.Text="👻 Stop"

    end


end)




--================ RESPAWN FIX =================


player.CharacterAdded:Connect(function(char)

    task.wait(1)


    local hum =
        char:WaitForChild("Humanoid")


    hum.WalkSpeed =
        savedWalkSpeed



    if isNoclipping then

        task.wait(.2)

        setCollision(false)

    end

end)--================ PART 4/4 =================
-- Mobile support + cleanup + final fixes


--================ MOBILE FLY CONTROLS =================

local mobileFrame = Instance.new("Frame")
mobileFrame.Size = UDim2.new(0,150,0,150)
mobileFrame.Position = UDim2.new(1,-170,1,-180)
mobileFrame.BackgroundTransparency = 1
mobileFrame.Parent = gui


local function createMobileButton(text,pos)

    local b = Instance.new("TextButton")

    b.Size = UDim2.new(0,45,0,45)
    b.Position = pos
    b.Text = text
    b.TextSize = 18
    b.BackgroundColor3 =
        Color3.fromRGB(60,40,100)
    b.TextColor3 =
        Color3.new(1,1,1)

    b.Parent = mobileFrame

    return b

end



local upButton =
    createMobileButton(
        "↑",
        UDim2.new(.33,0,0,0)
    )


local downButton =
    createMobileButton(
        "↓",
        UDim2.new(.33,0,1,-45)
    )


local leftButton =
    createMobileButton(
        "←",
        UDim2.new(0,0,.5,-22)
    )


local rightButton =
    createMobileButton(
        "→",
        UDim2.new(1,-45,.5,-22)
    )



local mobileDirection =
    Vector3.zero



local function updateFlyMobile()

    if flyVelocity and isFlying then

        flyVelocity.Velocity =
            mobileDirection * flySpeed

    end

end



upButton.MouseButton1Down:Connect(function()

    mobileDirection =
        Vector3.new(0,1,0)

    updateFlyMobile()

end)


downButton.MouseButton1Down:Connect(function()

    mobileDirection =
        Vector3.new(0,-1,0)

    updateFlyMobile()

end)



leftButton.MouseButton1Down:Connect(function()

    mobileDirection =
        Vector3.new(-1,0,0)

    updateFlyMobile()

end)



rightButton.MouseButton1Down:Connect(function()

    mobileDirection =
        Vector3.new(1,0,0)

    updateFlyMobile()

end)



for _,button in pairs(mobileFrame:GetChildren()) do

    if button:IsA("TextButton") then

        button.MouseButton1Up:Connect(function()

            mobileDirection =
                Vector3.zero

            updateFlyMobile()

        end)

    end

end



--================ SAFE CHARACTER CHECK =================


local function characterReady()

    local char =
        player.Character

    if not char then
        return false
    end


    return char:FindFirstChild("HumanoidRootPart")
        and char:FindFirstChildOfClass("Humanoid")

end



--================ CLEANUP =================


local function cleanup()

    stopFly()

    stopNoclip()


    if gui then

        gui:Destroy()

    end

end



-- prevent duplicate GUIs

if playerGui:FindFirstChild("GalaxyTeleporterV2_Old") then

    playerGui.GalaxyTeleporterV2_Old:Destroy()

end



--================ FINAL START =================


print("Galaxy Teleporter v2 Loaded")
