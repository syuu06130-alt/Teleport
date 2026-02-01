-- Rayfield UIをインストールしていない場合は先にインストールしてください
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- ローカルプレイヤー
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 基本設定
local CurrentTarget = nil
local RandomTargetPlayer = nil

-- Teleport設定
local TeleportEnabled = false
local StudOffset = 5
local CurrentTeleportMethod = nil

-- 上空TP設定
local SkyTPEnabled = false
local SkyTPHeight = 50
local SkyTPStayEnabled = false

-- 床下TP設定
local UnderfloorTPEnabled = false
local UnderfloorDepth = -10
local UnderfloorTeamCheck = true

-- Random TP設定
local RandomTPEnabled = false
local RandomTPStudOffset = 5
local RandomTPCooldown = 2
local RandomTPStayTime = 5
local RandomTPTeamCheck = true
local RandomTPOnDeath = true
local LastRandomTP = 0
local LastRandomTPChange = 0

-- Aimbot設定
local AimbotEnabled = false
local AimbotAccuracy = 100
local AimbotWallCheck = true
local AimbotWallPenetration = false
local AimbotTeamCheck = true
local AimbotSmoothness = 1
local AimbotFOV = 360
local AimbotPrediction = false
local AimbotPredictionAmount = 0.1

-- ESP設定
local ESPEnabled = false
local ESPColors = {
    Head = Color3.fromRGB(255, 0, 0),
    Box = Color3.fromRGB(0, 255, 0),
    Tracer = Color3.fromRGB(255, 255, 0)
}
local ESPHeadSize = 1
local ESPHeadEnabled = true
local ESPBoxEnabled = true
local ESPTracerEnabled = true
local ESPDistance = 1000
local ESPShowDistance = true
local ESPShowHealth = true
local ESPObjects = {}

-- ===== ユーティリティ関数 =====

-- チームチェック関数
local function IsEnemy(player)
    if not player or not player.Team then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- 壁チェック関数
local function IsVisible(targetPosition, origin)
    if AimbotWallPenetration then return true end
    if not AimbotWallCheck then return true end
    
    local direction = (targetPosition - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    
    if raycastResult then
        local hitCharacter = raycastResult.Instance:FindFirstAncestorOfClass("Model")
        if hitCharacter then
            local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
            local targetToCheck = CurrentTarget or RandomTargetPlayer
            return hitPlayer and hitPlayer == targetToCheck
        end
        return false
    end
    return true
end

-- FOVチェック関数
local function IsInFOV(targetPosition)
    if AimbotFOV >= 360 then return true end
    
    local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPosition)
    if not onScreen then return false end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local targetPoint = Vector2.new(screenPoint.X, screenPoint.Y)
    local distance = (screenCenter - targetPoint).Magnitude
    
    return distance <= AimbotFOV
end

-- ランダムプレイヤー選択
local function GetRandomEnemy()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 then
                if not RandomTPTeamCheck or IsEnemy(player) then
                    table.insert(enemies, player)
                end
            end
        end
    end
    
    if #enemies > 0 then
        return enemies[math.random(1, #enemies)]
    end
    return nil
end

-- ===== Teleport関数群 =====

local TeleportMethods = {
    Behind = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        local newPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, offset)
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = newPosition
        end
    end,
    
    Above = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 5 + offset, 0)
        end
    end,
    
    Front = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 0, -3 - offset)
        end
    end,
    
    RightSide = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(3 + offset, 0, 0)
        end
    end,
    
    LeftSide = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(-3 - offset, 0, 0)
        end
    end,
    
    Sky = function(target, height)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local skyHeight = height or SkyTPHeight
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, skyHeight, 0)
        end
    end,
    
    Underfloor = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, UnderfloorDepth, 0)
        end
    end
}

CurrentTeleportMethod = TeleportMethods.Behind

-- ===== ESP関数 =====

local function CreateESP(player)
    if ESPObjects[player] then return end
    
    local drawingObjects = {}
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = ESPColors.Box
    box.Thickness = 2
    box.Filled = false
    
    local headCircle = Drawing.new("Circle")
    headCircle.Visible = false
    headCircle.Color = ESPColors.Head
    headCircle.Thickness = 2
    headCircle.Filled = false
    
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = ESPColors.Tracer
    tracer.Thickness = 2
    
    local distanceText = Drawing.new("Text")
    distanceText.Visible = false
    distanceText.Color = Color3.fromRGB(255, 255, 255)
    distanceText.Size = 14
    distanceText.Center = true
    distanceText.Outline = true
    
    local healthText = Drawing.new("Text")
    healthText.Visible = false
    healthText.Color = Color3.fromRGB(0, 255, 0)
    healthText.Size = 14
    healthText.Center = true
    healthText.Outline = true
    
    ESPObjects[player] = {
        Box = box,
        HeadCircle = headCircle,
        Tracer = tracer,
        DistanceText = distanceText,
        HealthText = healthText
    }
end

local function UpdateESP()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    for player, drawings in pairs(ESPObjects) do
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        else
            local character = player.Character
            local rootPart = character.HumanoidRootPart
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            
            local distance = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance > ESPDistance then
                for _, drawing in pairs(drawings) do
                    drawing.Visible = false
                end
                return
            end
            
            local rootPos, rootVisible = Camera:WorldToViewportPoint(rootPart.Position)
            
            if rootVisible then
                if ESPBoxEnabled then
                    local boxSize = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z)
                    drawings.Box.Position = Vector2.new(rootPos.X - boxSize.X / 2, rootPos.Y - boxSize.Y / 2)
                    drawings.Box.Size = boxSize
                    drawings.Box.Visible = ESPEnabled
                    drawings.Box.Color = ESPColors.Box
                else
                    drawings.Box.Visible = false
                end
                
                if head and ESPHeadEnabled then
                    local headPos = Camera:WorldToViewportPoint(head.Position)
                    if headPos.Z > 0 then
                        drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
                        drawings.HeadCircle.Radius = ESPHeadSize * (50 / headPos.Z)
                        drawings.HeadCircle.Visible = ESPEnabled
                        drawings.HeadCircle.Color = ESPColors.Head
                    end
                else
                    drawings.HeadCircle.Visible = false
                end
                
                if ESPTracerEnabled then
                    drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    drawings.Tracer.Visible = ESPEnabled
                    drawings.Tracer.Color = ESPColors.Tracer
                else
                    drawings.Tracer.Visible = false
                end
                
                if ESPShowDistance then
                    drawings.DistanceText.Position = Vector2.new(rootPos.X, rootPos.Y + 30)
                    drawings.DistanceText.Text = string.format("%.1f studs", distance)
                    drawings.DistanceText.Visible = ESPEnabled
                else
                    drawings.DistanceText.Visible = false
                end
                
                if ESPShowHealth and humanoid then
                    local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100
                    drawings.HealthText.Position = Vector2.new(rootPos.X, rootPos.Y + 50)
                    drawings.HealthText.Text = string.format("HP: %.0f%%", healthPercent)
                    
                    if healthPercent > 75 then
                        drawings.HealthText.Color = Color3.fromRGB(0, 255, 0)
                    elseif healthPercent > 50 then
                        drawings.HealthText.Color = Color3.fromRGB(255, 255, 0)
                    elseif healthPercent > 25 then
                        drawings.HealthText.Color = Color3.fromRGB(255, 165, 0)
                    else
                        drawings.HealthText.Color = Color3.fromRGB(255, 0, 0)
                    end
                    
                    drawings.HealthText.Visible = ESPEnabled
                else
                    drawings.HealthText.Visible = false
                end
            else
                for _, drawing in pairs(drawings) do
                    drawing.Visible = false
                end
            end
        end
    end
end

local function RemoveESP(player)
    if ESPObjects[player] then
        for _, drawing in pairs(ESPObjects[player]) do
            drawing:Remove()
        end
        ESPObjects[player] = nil
    end
end

-- ===== UI作成 =====

local Window = Rayfield:CreateWindow({
    Name = "多機能スクリプト v3.0",
    LoadingTitle = "スクリプト読み込み中",
    LoadingSubtitle = "完全修正版",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MultiScriptV3",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvite",
        RememberJoins = true
    },
    KeySystem = false,
})

-- ===== メインタブ =====
local MainTab = Window:CreateTab("Teleport", 4483362458)

local TeleportSection = MainTab:CreateSection("基本テレポート設定")

local TeleportToggle = MainTab:CreateToggle({
    Name = "テレポート有効化",
    CurrentValue = false,
    Flag = "TeleportEnabled",
    Callback = function(value)
        TeleportEnabled = value
    end,
})

local StudSlider = MainTab:CreateSlider({
    Name = "距離 (スタッド)",
    Range = {0, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "StudOffset",
    Callback = function(value)
        StudOffset = value
    end,
})

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "プレイヤー選択",
    Options = {},
    CurrentOption = "None",
    Flag = "SelectedPlayer",
    Callback = function(option)
        if option == "None" then
            CurrentTarget = nil
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Name == option then
                    CurrentTarget = player
                    break
                end
            end
        end
    end,
})

local function UpdatePlayerList()
    local playerNames = {"None"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    PlayerDropdown:Refresh(playerNames, true)
end

Players.PlayerAdded:Connect(UpdatePlayerList)
Players.PlayerRemoving:Connect(UpdatePlayerList)
UpdatePlayerList()

local TeleportMethodDropdown = MainTab:CreateDropdown({
    Name = "テレポート方法",
    Options = {"Behind", "Above", "Front", "Right Side", "Left Side"},
    CurrentOption = "Behind",
    Flag = "TeleportMethod",
    Callback = function(option)
        CurrentTeleportMethod = TeleportMethods[option:gsub(" ", "")]
    end,
})

-- 上空TP設定
local SkyTPSection = MainTab:CreateSection("上空テレポート")

local SkyTPToggle = MainTab:CreateToggle({
    Name = "上空TP有効化",
    CurrentValue = false,
    Flag = "SkyTPEnabled",
    Callback = function(value)
        SkyTPEnabled = value
    end,
})

local SkyTPStayToggle = MainTab:CreateToggle({
    Name = "上空で留まる",
    CurrentValue = false,
    Flag = "SkyTPStayEnabled",
    Callback = function(value)
        SkyTPStayEnabled = value
    end,
})

local SkyTPHeightSlider = MainTab:CreateSlider({
    Name = "上空高さ",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 50,
    Flag = "SkyTPHeight",
    Callback = function(value)
        SkyTPHeight = value
    end,
})

-- 床下TP設定
local UnderfloorSection = MainTab:CreateSection("床下テレポート")

local UnderfloorTPToggle = MainTab:CreateToggle({
    Name = "床下TP有効化 (敵が死ぬまで)",
    CurrentValue = false,
    Flag = "UnderfloorTPEnabled",
    Callback = function(value)
        UnderfloorTPEnabled = value
    end,
})

local UnderfloorTeamCheckToggle = MainTab:CreateToggle({
    Name = "床下TP チームチェック",
    CurrentValue = true,
    Flag = "UnderfloorTeamCheck",
    Callback = function(value)
        UnderfloorTeamCheck = value
    end,
})

local UnderfloorDepthSlider = MainTab:CreateSlider({
    Name = "床下深さ",
    Range = {-50, -5},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = -10,
    Flag = "UnderfloorDepth",
    Callback = function(value)
        UnderfloorDepth = value
    end,
})

-- Random TP設定
local RandomTPSection = MainTab:CreateSection("ランダムテレポート")

local RandomTPToggle = MainTab:CreateToggle({
    Name = "ランダムTP有効化",
    CurrentValue = false,
    Flag = "RandomTPEnabled",
    Callback = function(value)
        RandomTPEnabled = value
        if value then
            RandomTargetPlayer = GetRandomEnemy()
            LastRandomTPChange = tick()
        else
            RandomTargetPlayer = nil
        end
    end,
})

local RandomTPTeamCheckToggle = MainTab:CreateToggle({
    Name = "ランダムTP チームチェック",
    CurrentValue = true,
    Flag = "RandomTPTeamCheck",
    Callback = function(value)
        RandomTPTeamCheck = value
    end,
})

local RandomTPStudSlider = MainTab:CreateSlider({
    Name = "ランダムTP 距離",
    Range = {0, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "RandomTPStudOffset",
    Callback = function(value)
        RandomTPStudOffset = value
    end,
})

local RandomTPCooldownSlider = MainTab:CreateSlider({
    Name = "TP実行間隔",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = " 秒",
    CurrentValue = 2,
    Flag = "RandomTPCooldown",
    Callback = function(value)
        RandomTPCooldown = value
    end,
})

local RandomTPStayTimeSlider = MainTab:CreateSlider({
    Name = "滞在時間 (ターゲット変更)",
    Range = {1, 30},
    Increment = 1,
    Suffix = " 秒",
    CurrentValue = 5,
    Flag = "RandomTPStayTime",
    Callback = function(value)
        RandomTPStayTime = value
    end,
})

local RandomTPOnDeathToggle = MainTab:CreateToggle({
    Name = "死亡時ターゲット変更",
    CurrentValue = true,
    Flag = "RandomTPOnDeath",
    Callback = function(value)
        RandomTPOnDeath = value
    end,
})

-- ===== Aimbotタブ =====
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local AimbotSection = AimbotTab:CreateSection("ヘッドロック設定")

local AimbotToggle = AimbotTab:CreateToggle({
    Name = "ヘッドロック有効化",
    CurrentValue = false,
    Flag = "AimbotEnabled",
    Callback = function(value)
        AimbotEnabled = value
    end,
})

local AimbotAccuracySlider = AimbotTab:CreateSlider({
    Name = "精度 (Accuracy)",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "AimbotAccuracy",
    Callback = function(value)
        AimbotAccuracy = value
    end,
})

local AimbotTeamCheckToggle = AimbotTab:CreateToggle({
    Name = "チームチェック",
    CurrentValue = true,
    Flag = "AimbotTeamCheck",
    Callback = function(value)
        AimbotTeamCheck = value
    end,
})

local WallCheckToggle = AimbotTab:CreateToggle({
    Name = "壁判定 (初期設定: ON)",
    CurrentValue = true,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotWallCheck = value
    end,
})

local WallPenetrationToggle = AimbotTab:CreateToggle({
    Name = "壁貫通",
    CurrentValue = false,
    Flag = "AimbotWallPenetration",
    Callback = function(value)
        AimbotWallPenetration = value
    end,
})

local AimbotSmoothnessSlider = AimbotTab:CreateSlider({
    Name = "スムーズネス",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "AimbotSmoothness",
    Callback = function(value)
        AimbotSmoothness = value
    end,
})

local AimbotFOVSlider = AimbotTab:CreateSlider({
    Name = "FOV",
    Range = {30, 360},
    Increment = 10,
    Suffix = "°",
    CurrentValue = 360,
    Flag = "AimbotFOV",
    Callback = function(value)
        AimbotFOV = value
    end,
})

local AimbotPredictionToggle = AimbotTab:CreateToggle({
    Name = "予測機能",
    CurrentValue = false,
    Flag = "AimbotPrediction",
    Callback = function(value)
        AimbotPrediction = value
    end,
})

local AimbotPredictionSlider = AimbotTab:CreateSlider({
    Name = "予測量",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.1,
    Flag = "AimbotPredictionAmount",
    Callback = function(value)
        AimbotPredictionAmount = value
    end,
})

-- ===== ESPタブ =====
local ESPTab = Window:CreateTab("ESP", 4483362458)

local ESPMainSection = ESPTab:CreateSection("ESP設定")

local ESPToggle = ESPTab:CreateToggle({
    Name = "ESP有効化",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(value)
        ESPEnabled = value
    end,
})

local ESPDistanceSlider = ESPTab:CreateSlider({
    Name = "最大距離",
    Range = {100, 5000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = 1000,
    Flag = "ESPDistance",
    Callback = function(value)
        ESPDistance = value
    end,
})

local ESPBoxToggle = ESPTab:CreateToggle({
    Name = "ボックスESP",
    CurrentValue = true,
    Flag = "ESPBoxEnabled",
    Callback = function(value)
        ESPBoxEnabled = value
    end,
})

local ESPTracerToggle = ESPTab:CreateToggle({
    Name = "トレーサーESP",
    CurrentValue = true,
    Flag = "ESPTracerEnabled",
    Callback = function(value)
        ESPTracerEnabled = value
    end,
})

local ESPShowDistanceToggle = ESPTab:CreateToggle({
    Name = "距離表示",
    CurrentValue = true,
    Flag = "ESPShowDistance",
    Callback = function(value)
        ESPShowDistance = value
    end,
})

local ESPShowHealthToggle = ESPTab:CreateToggle({
    Name = "体力表示",
    CurrentValue = true,
    Flag = "ESPShowHealth",
    Callback = function(value)
        ESPShowHealth = value
    end,
})

local HeadESPSection = ESPTab:CreateSection("ヘッドESP")

local HeadESPToggle = ESPTab:CreateToggle({
    Name = "ヘッドESP",
    CurrentValue = true,
    Flag = "ESPHeadEnabled",
    Callback = function(value)
        ESPHeadEnabled = value
    end,
})

local HeadSizeSlider = ESPTab:CreateSlider({
    Name = "ヘッドサイズ",
    Range = {0.5, 5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "ESPHeadSize",
    Callback = function(value)
        ESPHeadSize = value
    end,
})

local ESPColorSection = ESPTab:CreateSection("色設定")

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ボックス色",
    Color = Color3.fromRGB(0, 255, 0),
    Flag = "ESPColor",
    Callback = function(color)
        ESPColors.Box = color
    end
})

local HeadESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ヘッド色",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "HeadESPColor",
    Callback = function(color)
        ESPColors.Head = color
    end
})

local TracerESPColorPicker = ESPTab:CreateColorPicker({
    Name = "トレーサー色",
    Color = Color3.fromRGB(255, 255, 0),
    Flag = "TracerESPColor",
    Callback = function(color)
        ESPColors.Tracer = color
    end
})

-- ===== メインループ =====
RunService.RenderStepped:Connect(function(deltaTime)
    -- 基本テレポート
    if TeleportEnabled and CurrentTarget and CurrentTeleportMethod then
        CurrentTeleportMethod(CurrentTarget, StudOffset)
    end
    
    -- 上空TP
    if SkyTPEnabled and SkyTPStayEnabled and CurrentTarget then
        TeleportMethods.Sky(CurrentTarget, SkyTPHeight)
    end
    
    -- 床下TP (敵が死ぬまで)
    if UnderfloorTPEnabled and CurrentTarget then
        -- チームチェック
        if not UnderfloorTeamCheck or IsEnemy(CurrentTarget) then
            -- ターゲットが生きているかチェック
            if CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("Humanoid") then
                if CurrentTarget.Character.Humanoid.Health > 0 then
                    TeleportMethods.Underfloor(CurrentTarget)
                end
            end
        end
    end
    
    -- ランダムTP
    if RandomTPEnabled then
        local currentTime = tick()
        
        -- ターゲットが死んだら新しいターゲットを選択
        if RandomTPOnDeath and RandomTargetPlayer then
            if not RandomTargetPlayer.Character or 
               not RandomTargetPlayer.Character:FindFirstChild("Humanoid") or 
               RandomTargetPlayer.Character.Humanoid.Health <= 0 then
                RandomTargetPlayer = GetRandomEnemy()
                LastRandomTPChange = currentTime
            end
        end
        
        -- 滞在時間経過後に新しいターゲットを選択
        if currentTime - LastRandomTPChange >= RandomTPStayTime then
            RandomTargetPlayer = GetRandomEnemy()
            LastRandomTPChange = currentTime
        end
        
        -- TP実行
        if RandomTargetPlayer and currentTime - LastRandomTP >= RandomTPCooldown then
            TeleportMethods.Behind(RandomTargetPlayer, RandomTPStudOffset)
            LastRandomTP = currentTime
        end
    end
    
    -- Aimbot (Head Lock)
    if AimbotEnabled then
        local targetToAim = CurrentTarget or RandomTargetPlayer
        
        -- チームチェック
        if targetToAim and AimbotTeamCheck and not IsEnemy(targetToAim) then
            targetToAim = nil
        end
        
        if targetToAim and targetToAim.Character then
            local character = targetToAim.Character
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 and LocalPlayer.Character then
                local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if localRoot then
                    -- FOVチェック
                    if IsInFOV(head.Position) then
                        -- 壁チェック
                        if IsVisible(head.Position, Camera.CFrame.Position) then
                            local targetPosition = head.Position
                            
                            -- 予測機能
                            if AimbotPrediction then
                                local rootPart = character:FindFirstChild("HumanoidRootPart")
                                if rootPart then
                                    local velocity = rootPart.AssemblyLinearVelocity
                                    if velocity then
                                        targetPosition = targetPosition + (velocity * AimbotPredictionAmount)
                                    end
                                end
                            end
                            
                            -- 精度適用 (ランダム要素を追加)
                            if AimbotAccuracy < 100 then
                                local inaccuracy = (100 - AimbotAccuracy) / 100
                                local randomOffset = Vector3.new(
                                    (math.random() - 0.5) * inaccuracy * 5,
                                    (math.random() - 0.5) * inaccuracy * 5,
                                    (math.random() - 0.5) * inaccuracy * 5
                                )
                                targetPosition = targetPosition + randomOffset
                            end
                            
                            -- スムーズネス適用
                            local currentCFrame = Camera.CFrame
                            local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
                            
                            if AimbotSmoothness > 0.1 then
                                Camera.CFrame = currentCFrame:Lerp(targetCFrame, 1 / AimbotSmoothness)
                            else
                                Camera.CFrame = targetCFrame
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- ESP更新
    if ESPEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] then
                CreateESP(player)
            end
        end
        
        for player in pairs(ESPObjects) do
            if not Players:FindFirstChild(player.Name) then
                RemoveESP(player)
            end
        end
        
        UpdateESP()
    else
        for _, drawings in pairs(ESPObjects) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
    end
end)

-- クリーンアップ
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if CurrentTarget == player then
        CurrentTarget = nil
    end
    if RandomTargetPlayer == player then
        RandomTargetPlayer = nil
    end
end)

-- 通知
Rayfield:Notify({
    Title = "スクリプト読み込み完了",
    Content = "多機能スクリプト v3.0 が正常に読み込まれました！",
    Duration = 6.5,
    Image = 4483362458,
    Actions = {
        Ignore = {
            Name = "OK",
            Callback = function()
                print("通知確認")
            end
        },
    },
})

print("=== 多機能スクリプト v3.0 読み込み完了 ===")
print("すべての機能が正常に動作します")
