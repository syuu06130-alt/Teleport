-- Rayfield UI搭載 多機能スクリプト
-- 機能: プレイヤーTP、ヘッドロック(Aimbot)、ESP、チームチェック

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- ローカルプレイヤー
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 設定変数
local Settings = {
    -- TP設定
    SelectedPlayer = nil,
    TeleportEnabled = false,
    TeleportDistance = 5,
    RandomTPEnabled = false,
    TeamCheck = true,
    
    -- ヘッドロック設定
    HeadLockEnabled = false,
    WallCheck = true,
    
    -- ESP設定
    ESPEnabled = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
    HeadESPEnabled = false,
    HeadESPColor = Color3.fromRGB(0, 255, 0),
    HeadESPShape = "Box", -- Box, Sphere
    HeadESPSize = 2,
    
    -- その他のTP機能
    LoopTPEnabled = false,
    BehindTPEnabled = false,
    FrontTPEnabled = false,
    AboveTPEnabled = false,
    RandomPositionTPEnabled = false
}

-- ESP保存用テーブル
local ESPObjects = {}
local HeadESPObjects = {}

-- ランダムターゲットプレイヤー
local RandomTarget = nil

-- ウィンドウ作成
local Window = Rayfield:CreateWindow({
    Name = "多機能スクリプト",
    LoadingTitle = "読み込み中...",
    LoadingSubtitle = "by Script Creator",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "ScriptConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvite",
        RememberJoins = true
    },
    KeySystem = false
})

-- タブ作成
local TPTab = Window:CreateTab("テレポート", 4483362458)
local AimbotTab = Window:CreateTab("ヘッドロック", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)

-- ===== プレイヤーリスト取得関数 =====
local function GetPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

-- ===== チームチェック関数 =====
local function IsSameTeam(player)
    if not Settings.TeamCheck then
        return false
    end
    return player.Team == LocalPlayer.Team
end

-- ===== 壁判定関数 =====
local function HasLineOfSight(targetPart)
    if not Settings.WallCheck then
        return true
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

-- ===== ランダムプレイヤー取得関数 =====
local function GetRandomPlayer()
    local validPlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not IsSameTeam(player) then
                table.insert(validPlayers, player)
            end
        end
    end
    
    if #validPlayers > 0 then
        return validPlayers[math.random(1, #validPlayers)]
    end
    return nil
end

-- ===== テレポート関数 =====
local function TeleportBehind(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and localRoot then
        local behindPosition = targetRoot.CFrame * CFrame.new(0, 0, Settings.TeleportDistance)
        localRoot.CFrame = behindPosition
    end
end

local function TeleportInFront(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and localRoot then
        local frontPosition = targetRoot.CFrame * CFrame.new(0, 0, -Settings.TeleportDistance)
        localRoot.CFrame = frontPosition
    end
end

local function TeleportAbove(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and localRoot then
        local abovePosition = targetRoot.CFrame * CFrame.new(0, Settings.TeleportDistance, 0)
        localRoot.CFrame = abovePosition
    end
end

local function TeleportToPosition(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and localRoot then
        localRoot.CFrame = targetRoot.CFrame
    end
end

local function TeleportRandomAround(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and localRoot then
        local angle = math.random() * math.pi * 2
        local distance = Settings.TeleportDistance
        local offsetX = math.cos(angle) * distance
        local offsetZ = math.sin(angle) * distance
        
        local randomPosition = targetRoot.CFrame * CFrame.new(offsetX, 0, offsetZ)
        localRoot.CFrame = randomPosition
    end
end

-- ===== ESP作成関数 =====
local function CreateESP(player)
    if ESPObjects[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESP"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(4, 0, 5.5, 0)
    billboardGui.StudsOffset = Vector3.new(0, 0, 0)
    billboardGui.Parent = rootPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.7
    frame.BackgroundColor3 = Settings.ESPColor
    frame.BorderSizePixel = 2
    frame.Parent = billboardGui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, -0.2, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Parent = billboardGui
    
    ESPObjects[player] = billboardGui
end

local function CreateHeadESP(player)
    if HeadESPObjects[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    local espPart
    if Settings.HeadESPShape == "Box" then
        espPart = Instance.new("BoxHandleAdornment")
        espPart.Size = Vector3.new(Settings.HeadESPSize, Settings.HeadESPSize, Settings.HeadESPSize)
    else
        espPart = Instance.new("SphereHandleAdornment")
        espPart.Radius = Settings.HeadESPSize
    end
    
    espPart.Color3 = Settings.HeadESPColor
    espPart.Transparency = 0.5
    espPart.AlwaysOnTop = true
    espPart.ZIndex = 5
    espPart.Adornee = head
    espPart.Parent = head
    
    HeadESPObjects[player] = espPart
end

local function RemoveESP(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end

local function RemoveHeadESP(player)
    if HeadESPObjects[player] then
        HeadESPObjects[player]:Destroy()
        HeadESPObjects[player] = nil
    end
end

-- ===== UI要素作成 =====

-- テレポートタブ
local PlayerDropdown = TPTab:CreateDropdown({
    Name = "プレイヤー選択",
    Options = GetPlayerNames(),
    CurrentOption = "",
    Flag = "PlayerDropdown",
    Callback = function(option)
        Settings.SelectedPlayer = Players:FindFirstChild(option)
    end
})

local DistanceSlider = TPTab:CreateSlider({
    Name = "距離 (スタッド)",
    Range = {0, 25},
    Increment = 1,
    Suffix = " スタッド",
    CurrentValue = 5,
    Flag = "DistanceSlider",
    Callback = function(value)
        Settings.TeleportDistance = value
    end
})

local TPToggle = TPTab:CreateToggle({
    Name = "背後にTP (連続)",
    CurrentValue = false,
    Flag = "TPToggle",
    Callback = function(value)
        Settings.TeleportEnabled = value
    end
})

TPTab:CreateButton({
    Name = "背後に1回TP",
    Callback = function()
        if Settings.SelectedPlayer then
            TeleportBehind(Settings.SelectedPlayer)
        end
    end
})

TPTab:CreateButton({
    Name = "前方に1回TP",
    Callback = function()
        if Settings.SelectedPlayer then
            TeleportInFront(Settings.SelectedPlayer)
        end
    end
})

TPTab:CreateButton({
    Name = "上空に1回TP",
    Callback = function()
        if Settings.SelectedPlayer then
            TeleportAbove(Settings.SelectedPlayer)
        end
    end
})

TPTab:CreateButton({
    Name = "同じ位置にTP",
    Callback = function()
        if Settings.SelectedPlayer then
            TeleportToPosition(Settings.SelectedPlayer)
        end
    end
})

TPTab:CreateButton({
    Name = "ランダム位置にTP",
    Callback = function()
        if Settings.SelectedPlayer then
            TeleportRandomAround(Settings.SelectedPlayer)
        end
    end
})

TPTab:CreateSection("ランダムTP機能")

local TeamCheckToggle = TPTab:CreateToggle({
    Name = "チームチェック",
    CurrentValue = true,
    Flag = "TeamCheckToggle",
    Callback = function(value)
        Settings.TeamCheck = value
    end
})

local RandomTPToggle = TPTab:CreateToggle({
    Name = "ランダムプレイヤーTP (死亡時再選択)",
    CurrentValue = false,
    Flag = "RandomTPToggle",
    Callback = function(value)
        Settings.RandomTPEnabled = value
        if value then
            RandomTarget = GetRandomPlayer()
        else
            RandomTarget = nil
        end
    end
})

-- ヘッドロック(Aimbot)タブ
local HeadLockToggle = AimbotTab:CreateToggle({
    Name = "ヘッドロック有効化",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(value)
        Settings.HeadLockEnabled = value
    end
})

local WallCheckToggle = AimbotTab:CreateToggle({
    Name = "壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(value)
        Settings.WallCheck = value
    end
})

-- ESPタブ
local ESPToggle = ESPTab:CreateToggle({
    Name = "全体ESP有効化",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(value)
        Settings.ESPEnabled = value
        if not value then
            for player, _ in pairs(ESPObjects) do
                RemoveESP(player)
            end
        end
    end
})

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ESP色",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ESPColorPicker",
    Callback = function(value)
        Settings.ESPColor = value
    end
})

ESPTab:CreateSection("ヘッドESP")

local HeadESPToggle = ESPTab:CreateToggle({
    Name = "ヘッドESP有効化",
    CurrentValue = false,
    Flag = "HeadESPToggle",
    Callback = function(value)
        Settings.HeadESPEnabled = value
        if not value then
            for player, _ in pairs(HeadESPObjects) do
                RemoveHeadESP(player)
            end
        end
    end
})

local HeadESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ヘッドESP色",
    Color = Color3.fromRGB(0, 255, 0),
    Flag = "HeadESPColorPicker",
    Callback = function(value)
        Settings.HeadESPColor = value
    end
})

local HeadESPShapeDropdown = ESPTab:CreateDropdown({
    Name = "ヘッドESP形状",
    Options = {"Box", "Sphere"},
    CurrentOption = "Box",
    Flag = "HeadESPShapeDropdown",
    Callback = function(option)
        Settings.HeadESPShape = option
        -- 既存のヘッドESPを更新
        for player, _ in pairs(HeadESPObjects) do
            RemoveHeadESP(player)
            if Settings.HeadESPEnabled then
                CreateHeadESP(player)
            end
        end
    end
})

local HeadESPSizeSlider = ESPTab:CreateSlider({
    Name = "ヘッドESPサイズ",
    Range = {0.5, 5},
    Increment = 0.5,
    Suffix = "",
    CurrentValue = 2,
    Flag = "HeadESPSizeSlider",
    Callback = function(value)
        Settings.HeadESPSize = value
        -- 既存のヘッドESPを更新
        for player, _ in pairs(HeadESPObjects) do
            RemoveHeadESP(player)
            if Settings.HeadESPEnabled then
                CreateHeadESP(player)
            end
        end
    end
})

-- ===== メインループ =====
RunService.RenderStepped:Connect(function()
    -- 連続TP
    if Settings.TeleportEnabled and Settings.SelectedPlayer then
        TeleportBehind(Settings.SelectedPlayer)
    end
    
    -- ランダムTP
    if Settings.RandomTPEnabled then
        if not RandomTarget or not RandomTarget.Character or not RandomTarget.Character:FindFirstChild("Humanoid") or RandomTarget.Character.Humanoid.Health <= 0 then
            RandomTarget = GetRandomPlayer()
        end
        
        if RandomTarget then
            TeleportBehind(RandomTarget)
        end
    end
    
    -- ヘッドロック
    if Settings.HeadLockEnabled then
        local targetPlayer = Settings.SelectedPlayer or RandomTarget
        if targetPlayer and targetPlayer.Character then
            local head = targetPlayer.Character:FindFirstChild("Head")
            if head and (not Settings.WallCheck or HasLineOfSight(head)) then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            end
        end
    end
    
    -- ESP更新
    if Settings.ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if not ESPObjects[player] then
                    CreateESP(player)
                end
            end
        end
    end
    
    if Settings.HeadESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if not HeadESPObjects[player] then
                    CreateHeadESP(player)
                end
            end
        end
    end
end)

-- プレイヤー退出時のクリーンアップ
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    RemoveHeadESP(player)
    
    if Settings.SelectedPlayer == player then
        Settings.SelectedPlayer = nil
    end
    if RandomTarget == player then
        RandomTarget = nil
    end
end)

-- プレイヤードロップダウン更新
task.spawn(function()
    while task.wait(3) do
        PlayerDropdown:Refresh(GetPlayerNames())
    end
end)

print("スクリプト読み込み完了!")
