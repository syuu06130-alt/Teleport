-- Teleport Script with Rayfield UI Integration
-- This script provides teleportation features behind selected or random players, with team checks, aimbot (head lock), ESP, and additional TP variations.
-- Note: Ensure Rayfield library is loaded appropriately in your Roblox environment.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Teleport Script",
    LoadingTitle = "Initializing Features",
    LoadingSubtitle = "By xAI Assistance",
})

local Tab = Window:CreateTab("Main Features")

-- Global Variables
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TPEnabled = false
local SelectedPlayer = nil
local StudDistance = 5  -- Default studs behind
local AimbotEnabled = false
local WallCheck = true  -- Default on
local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local HeadESPEnabled = false
local HeadESPColor = Color3.fromRGB(0, 255, 0)
local HeadESPShape = "Circle"  -- Options: Circle, Square
local HeadESPSize = 10
local RandomTPTarget = nil

-- Utility Functions
local function GetPlayerFromName(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

local function IsSameTeam(player)
    if LocalPlayer.Team == nil or player.Team == nil then
        return false
    end
    return LocalPlayer.Team == player.Team
end

local function FindRandomPlayer()
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsSameTeam(player) and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            table.insert(candidates, player)
        end
    end
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
    return nil
end

local function TeleportBehind(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    local root = target.Character.HumanoidRootPart
    local direction = root.CFrame.LookVector * -1  -- Behind direction
    local position = root.Position + direction * StudDistance
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
end

-- Head Lock (Aimbot) Function
local function Aimbot(target)
    if not target or not target.Character or not target.Character:FindFirstChild("Head") then
        return
    end
    local camera = Workspace.CurrentCamera
    local head = target.Character.Head
    if WallCheck then
        local ray = Ray.new(camera.CFrame.Position, (head.Position - camera.CFrame.Position).unit * 500)
        local hit, position = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
        if hit and hit:IsDescendantOf(target.Character) then
            camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
        end
    else
        camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
    end
end

-- ESP Function
local function CreateESP(player)
    if not player.Character then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"
    billboard.Adornee = player.Character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    local frame = Instance.new("Frame", billboard)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = ESPColor
    frame.BackgroundTransparency = 0.5
    billboard.Parent = player.Character
end

local function RemoveESP(player)
    if player.Character and player.Character:FindFirstChild("ESP") then
        player.Character.ESP:Destroy()
    end
end

-- Head ESP Function
local function CreateHeadESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    local drawing = Drawing.new(HeadESPShape == "Circle" and "Circle" or "Square")
    drawing.Visible = true
    drawing.Color = HeadESPColor
    drawing.Thickness = 1
    drawing.Filled = false
    drawing.Radius = HeadESPSize  -- For Circle
    drawing.Size = Vector2.new(HeadESPSize, HeadESPSize)  -- For Square
    local connection = RunService.RenderStepped:Connect(function()
        local head = player.Character.Head
        local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(head.Position)
        if onScreen then
            drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
            drawing.Visible = true
        else
            drawing.Visible = false
        end
    end)
    return {drawing, connection}
end

local HeadESPs = {}
local function RemoveHeadESP(player)
    if HeadESPs[player] then
        HeadESPs[player][1]:Remove()
        HeadESPs[player][2]:Disconnect()
        HeadESPs[player] = nil
    end
end

-- UI Elements
Tab:CreateDropdown({
    Name = "Select Player",
    Options = (function()
        local opts = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(opts, player.Name)
            end
        end
        return opts
    end)(),
    Callback = function(value)
        SelectedPlayer = GetPlayerFromName(value)
    end
})

Tab:CreateSlider({
    Name = "Studs Behind",
    Range = {0, 25},
    Increment = 1,
    Suffix = "Studs",
    Callback = function(value)
        StudDistance = value
    end
})

Tab:CreateToggle({
    Name = "TP Enabled",
    Callback = function(state)
        TPEnabled = state
    end
})

-- Random TP with Team Check
Tab:CreateButton({
    Name = "Random TP (Team Check)",
    Callback = function()
        RandomTPTarget = FindRandomPlayer()
        if RandomTPTarget then
            TeleportBehind(RandomTPTarget)
            -- Monitor death
            local humanoid = RandomTPTarget.Character.Humanoid
            local conn = humanoid.Died:Connect(function()
                RandomTPTarget = FindRandomPlayer()
                if RandomTPTarget then
                    TeleportBehind(RandomTPTarget)
                end
            end)
            -- Clean up on player leave or script end
        end
    end
})

-- Aimbot Toggle
Tab:CreateToggle({
    Name = "Head Lock (Aimbot)",
    Callback = function(state)
        AimbotEnabled = state
    end
})

Tab:CreateToggle({
    Name = "Wall Check for Aimbot",
    CurrentValue = true,
    Callback = function(state)
        WallCheck = state
    end
})

-- ESP Features
Tab:CreateToggle({
    Name = "ESP Enabled",
    Callback = function(state)
        ESPEnabled = state
        if state then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESP(player)
                end
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                RemoveESP(player)
            end
        end
    end
})

Tab:CreateColorPicker({
    Name = "ESP Color",
    Color = ESPColor,
    Callback = function(color)
        ESPColor = color
        -- Update existing ESPs if needed
    end
})

-- Head ESP Features
Tab:CreateToggle({
    Name = "Head ESP Enabled",
    Callback = function(state)
        HeadESPEnabled = state
        if state then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    HeadESPs[player] = CreateHeadESP(player)
                end
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                RemoveHeadESP(player)
            end
        end
    end
})

Tab:CreateColorPicker({
    Name = "Head ESP Color",
    Color = HeadESPColor,
    Callback = function(color)
        HeadESPColor = color
        -- Update if needed
    end
})

Tab:CreateDropdown({
    Name = "Head ESP Shape",
    Options = {"Circle", "Square"},
    Callback = function(value)
        HeadESPShape = value
        -- Recreate if needed
    end
})

Tab:CreateSlider({
    Name = "Head ESP Size",
    Range = {5, 20},
    Increment = 1,
    Callback = function(value)
        HeadESPSize = value
        -- Update if needed
    end
})

-- Main Loop for TP and Aimbot
RunService.Heartbeat:Connect(function()
    if TPEnabled and SelectedPlayer then
        TeleportBehind(SelectedPlayer)
    end
    if AimbotEnabled and SelectedPlayer then
        Aimbot(SelectedPlayer)
    end
end)

-- Additional TP Related Codes (10 Variations)
-- 1. TP to Front
local function TeleportFront(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local position = root.Position + root.CFrame.LookVector * StudDistance
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
end

-- 2. TP Above
local function TeleportAbove(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local position = root.Position + Vector3.new(0, StudDistance, 0)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end

-- 3. TP Below (if possible)
local function TeleportBelow(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local position = root.Position - Vector3.new(0, StudDistance, 0)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end

-- 4. Circle TP Around Target
local function CircleTP(target, radius)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local angle = math.rad(math.random(0, 360))
    local position = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
end

-- 5. TP with Offset Left
local function TeleportLeft(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local rightVector = root.CFrame.RightVector * -1  -- Left
    local position = root.Position + rightVector * StudDistance
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
end

-- 6. TP with Offset Right
local function TeleportRight(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local position = root.Position + root.CFrame.RightVector * StudDistance
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
end

-- 7. Delayed TP
local function DelayedTP(target, delay)
    wait(delay)
    TeleportBehind(target)
end

-- 8. TP Chain (to multiple players)
local function ChainTP(players)
    for _, player in ipairs(players) do
        TeleportBehind(player)
        wait(0.5)
    end
end

-- 9. TP with Velocity Match
local function TeleportWithVelocity(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local direction = root.CFrame.LookVector * -1
    local position = root.Position + direction * StudDistance
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(position, root.Position)
    LocalPlayer.Character.HumanoidRootPart.Velocity = root.Velocity
end

-- 10. Safe TP (Check for Obstacles)
local function SafeTP(target)
    if not target or not target.Character then return end
    local root = target.Character.HumanoidRootPart
    local direction = root.CFrame.LookVector * -1
    local ray = Ray.new(root.Position, direction * StudDistance)
    local hit = Workspace:FindPartOnRay(ray)
    if not hit then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(root.Position + direction * StudDistance, root.Position)
    end
end

-- To integrate these, you can add buttons or toggles in the UI for each variation as needed.
