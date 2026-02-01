-- Rayfield UIをインストールしていない場合は先にインストールしてください
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- 変数
local LocalPlayer = Players.LocalPlayer
local CurrentTarget = nil
local TeleportEnabled = false
local RandomTPEnabled = false
local AimbotEnabled = false
local AimbotWallCheck = true
local ESPEnabled = false
local StudOffset = 5
local SelectedPart = "HumanoidRootPart"
local RandomTPCooldown = 2
local LastRandomTP = 0

-- Random TP専用設定
local RandomTPStudOffset = 5
local RandomTPAutoUpdate = true
local RandomTPOnDeath = true
local RandomTPTeamCheck = true

-- Aimbot詳細設定
local AimbotSmoothness = 1
local AimbotFOV = 360
local AimbotPrediction = false
local AimbotPredictionAmount = 0.1
local AimbotTeamCheck = true

-- ESP用変数
local ESPObjects = {}
local ESPColors = {
    Head = Color3.fromRGB(255, 0, 0),
    Box = Color3.fromRGB(0, 255, 0),
    Tracer = Color3.fromRGB(255, 255, 0)
}
local ESPShapes = {"Box", "Circle", "Triangle"}
local SelectedESPShape = "Box"
local ESPHeadSize = 1
local ESPHeadEnabled = true
local ESPBoxEnabled = true
local ESPTracerEnabled = true
local ESPDistance = 1000
local ESPShowDistance = true
local ESPShowHealth = true

-- チームチェック関数
local function IsEnemy(player)
    if not player or not player.Team then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- 壁チェック関数（改良版）
local function IsVisible(targetPosition, origin)
    if not AimbotWallCheck then return true end
    
    local direction = (targetPosition - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    
    if raycastResult then
        -- ヒットしたオブジェクトがターゲットプレイヤーの一部かチェック
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
    
    local camera = Workspace.CurrentCamera
    local screenPoint, onScreen = camera:WorldToViewportPoint(targetPosition)
    
    if not onScreen then return false end
    
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local targetPoint = Vector2.new(screenPoint.X, screenPoint.Y)
    local distance = (screenCenter - targetPoint).Magnitude
    
    return distance <= AimbotFOV
end

-- Teleport関数群（5種類のTP方法）
local TeleportMethods = {
    -- 1. 背後にTP（基本）
    Behind = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        local direction = humanoidRootPart.CFrame.LookVector
        local newPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, offset)
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(newPosition)
        end
    end,
    
    -- 2. 上にTP
    Above = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 5 + offset, 0))
        end
    end,
    
    -- 3. 前にTP
    Front = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 0, -3 - offset))
        end
    end,
    
    -- 4. 右側にTP
    RightSide = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(3 + offset, 0, 0))
        end
    end,
    
    -- 5. 左側にTP
    LeftSide = function(target, customOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customOffset or StudOffset
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(-3 - offset, 0, 0))
        end
    end
}

-- 現在選択されたTP方法
local CurrentTeleportMethod = TeleportMethods.Behind

-- ランダムプレイヤー選択（チームチェック付き）
local RandomTargetPlayer = nil

local function GetRandomEnemy()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 then
                -- RandomTPTeamCheckが有効な場合のみ敵チームをチェック
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

-- ESP描画関数
local function CreateESP(player)
    if ESPObjects[player] then return end
    
    local drawingObjects = {}
    
    -- ボックスESP
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = ESPColors.Box
    box.Thickness = 2
    box.Filled = false
    
    -- ヘッドESP
    local headCircle = Drawing.new("Circle")
    headCircle.Visible = false
    headCircle.Color = ESPColors.Head
    headCircle.Thickness = 2
    headCircle.Filled = false
    
    -- トレーサー
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = ESPColors.Tracer
    tracer.Thickness = 2
    
    -- 距離表示
    local distanceText = Drawing.new("Text")
    distanceText.Visible = false
    distanceText.Color = Color3.fromRGB(255, 255, 255)
    distanceText.Size = 14
    distanceText.Center = true
    distanceText.Outline = true
    
    -- 体力表示
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
    for player, drawings in pairs(ESPObjects) do
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            drawings.Box.Visible = false
            drawings.HeadCircle.Visible = false
            drawings.Tracer.Visible = false
            drawings.DistanceText.Visible = false
            drawings.HealthText.Visible = false
        else
            local character = player.Character
            local rootPart = character.HumanoidRootPart
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            
            -- 距離チェック
            local distance = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance > ESPDistance then
                drawings.Box.Visible = false
                drawings.HeadCircle.Visible = false
                drawings.Tracer.Visible = false
                drawings.DistanceText.Visible = false
                drawings.HealthText.Visible = false
                return
            end
            
            -- 3D座標を2Dスクリーン座標に変換
            local rootPos, rootVisible = Workspace.CurrentCamera:WorldToViewportPoint(rootPart.Position)
            
            if rootVisible then
                -- ボックスESP
                if ESPBoxEnabled then
                    local boxSize = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z)
                    drawings.Box.Position = Vector2.new(rootPos.X - boxSize.X / 2, rootPos.Y - boxSize.Y / 2)
                    drawings.Box.Size = boxSize
                    drawings.Box.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                    drawings.Box.Color = ESPColors.Box
                else
                    drawings.Box.Visible = false
                end
                
                -- ヘッドESP
                if head and ESPHeadEnabled then
                    local headPos = Workspace.CurrentCamera:WorldToViewportPoint(head.Position)
                    if headPos.Z > 0 then
                        drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
                        drawings.HeadCircle.Radius = ESPHeadSize * (50 / headPos.Z)
                        drawings.HeadCircle.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                        drawings.HeadCircle.Color = ESPColors.Head
                    end
                else
                    drawings.HeadCircle.Visible = false
                end
                
                -- トレーサー
                if ESPTracerEnabled then
                    drawings.Tracer.From = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    drawings.Tracer.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                    drawings.Tracer.Color = ESPColors.Tracer
                else
                    drawings.Tracer.Visible = false
                end
                
                -- 距離表示
                if ESPShowDistance then
                    drawings.DistanceText.Position = Vector2.new(rootPos.X, rootPos.Y + 30)
                    drawings.DistanceText.Text = string.format("%.1f studs", distance)
                    drawings.DistanceText.Visible = ESPEnabled
                else
                    drawings.DistanceText.Visible = false
                end
                
                -- 体力表示
                if ESPShowHealth and humanoid then
                    local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100
                    drawings.HealthText.Position = Vector2.new(rootPos.X, rootPos.Y + 50)
                    drawings.HealthText.Text = string.format("HP: %.0f%%", healthPercent)
                    
                    -- 体力に応じて色を変更
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
                drawings.Box.Visible = false
                drawings.HeadCircle.Visible = false
                drawings.Tracer.Visible = false
                drawings.DistanceText.Visible = false
                drawings.HealthText.Visible = false
            end
        end
    end
end

-- ESP削除関数
local function RemoveESP(player)
    if ESPObjects[player] then
        for _, drawing in pairs(ESPObjects[player]) do
            drawing:Remove()
        end
        ESPObjects[player] = nil
    end
end

-- Rayfield UIの作成
local Window = Rayfield:CreateWindow({
    Name = "Teleport Script v2.0",
    LoadingTitle = "Teleport Script v2.0",
    LoadingSubtitle = "Enhanced Version",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TeleportScriptV2",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

-- メインタブ
local MainTab = Window:CreateTab("Main", 4483362458)

-- Teleportセクション
local TeleportSection = MainTab:CreateSection("Teleport Settings")

local TeleportToggle = MainTab:CreateToggle({
    Name = "Enable Teleport",
    CurrentValue = TeleportEnabled,
    Flag = "TeleportEnabled",
    Callback = function(value)
        TeleportEnabled = value
    end,
})

local StudSlider = MainTab:CreateSlider({
    Name = "Stud Offset (通常TP)",
    Range = {0, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = StudOffset,
    Flag = "StudOffset",
    Callback = function(value)
        StudOffset = value
    end,
})

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Select Player",
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

-- プレイヤーリストの更新
local function UpdatePlayerList()
    local playerNames = {"None"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    PlayerDropdown:Refresh(playerNames, true)
end

-- プレイヤーが参加/退出したときの更新
Players.PlayerAdded:Connect(UpdatePlayerList)
Players.PlayerRemoving:Connect(UpdatePlayerList)
UpdatePlayerList()

local TeleportMethodDropdown = MainTab:CreateDropdown({
    Name = "Teleport Method",
    Options = {"Behind", "Above", "Front", "Right Side", "Left Side"},
    CurrentOption = "Behind",
    Flag = "TeleportMethod",
    Callback = function(option)
        CurrentTeleportMethod = TeleportMethods[option:gsub(" ", "")]
    end,
})

-- Random TPセクション
local RandomTPSection = MainTab:CreateSection("Random TP Settings (Team Check)")

local RandomTPTeamCheckToggle = MainTab:CreateToggle({
    Name = "Random TP Team Check",
    CurrentValue = RandomTPTeamCheck,
    Flag = "RandomTPTeamCheck",
    Callback = function(value)
        RandomTPTeamCheck = value
    end,
})

local RandomTPToggle = MainTab:CreateToggle({
    Name = "Enable Random TP",
    CurrentValue = RandomTPEnabled,
    Flag = "RandomTPEnabled",
    Callback = function(value)
        RandomTPEnabled = value
        if value then
            RandomTargetPlayer = GetRandomEnemy()
        else
            RandomTargetPlayer = nil
        end
    end,
})

local RandomTPStudSlider = MainTab:CreateSlider({
    Name = "Random TP Stud Offset",
    Range = {0, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = RandomTPStudOffset,
    Flag = "RandomTPStudOffset",
    Callback = function(value)
        RandomTPStudOffset = value
    end,
})

local RandomTPCooldownSlider = MainTab:CreateSlider({
    Name = "Random TP Cooldown",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = RandomTPCooldown,
    Flag = "RandomTPCooldown",
    Callback = function(value)
        RandomTPCooldown = value
    end,
})

local RandomTPAutoUpdateToggle = MainTab:CreateToggle({
    Name = "Auto Update Random Target",
    CurrentValue = RandomTPAutoUpdate,
    Flag = "RandomTPAutoUpdate",
    Callback = function(value)
        RandomTPAutoUpdate = value
    end,
})

local RandomTPOnDeathToggle = MainTab:CreateToggle({
    Name = "Change Target on Death",
    CurrentValue = RandomTPOnDeath,
    Flag = "RandomTPOnDeath",
    Callback = function(value)
        RandomTPOnDeath = value
    end,
})

-- キーバインドセクション
local KeybindSection = MainTab:CreateSection("Keybinds")

local TeleportKeybind = MainTab:CreateKeybind({
    Name = "Teleport Keybind",
    CurrentKeybind = "G",
    HoldToInteract = false,
    Flag = "TeleportKeybind",
    Callback = function(key)
        if TeleportEnabled and CurrentTarget and CurrentTeleportMethod then
            CurrentTeleportMethod(CurrentTarget)
        end
    end,
})

local RandomTPKeybind = MainTab:CreateKeybind({
    Name = "Random TP Keybind",
    CurrentKeybind = "H",
    HoldToInteract = false,
    Flag = "RandomTPKeybind",
    Callback = function(key)
        if RandomTPEnabled then
            local enemy = GetRandomEnemy()
            if enemy then
                TeleportMethods.Behind(enemy, RandomTPStudOffset)
            end
        end
    end,
})

-- Aimbotタブ
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local AimbotSection = AimbotTab:CreateSection("Head Lock Settings")

local AimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Head Lock (Aimbot)",
    CurrentValue = AimbotEnabled,
    Flag = "AimbotEnabled",
    Callback = function(value)
        AimbotEnabled = value
    end,
})

local WallCheckToggle = AimbotTab:CreateToggle({
    Name = "Wall Check (初期設定: ON)",
    CurrentValue = AimbotWallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotWallCheck = value
    end,
})

local AimbotTeamCheckToggle = AimbotTab:CreateToggle({
    Name = "Team Check (チームチェック)",
    CurrentValue = AimbotTeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(value)
        AimbotTeamCheck = value
    end,
})

local AimbotSmoothnessSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Smoothness",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = AimbotSmoothness,
    Flag = "AimbotSmoothness",
    Callback = function(value)
        AimbotSmoothness = value
    end,
})

local AimbotFOVSlider = AimbotTab:CreateSlider({
    Name = "Aimbot FOV",
    Range = {30, 360},
    Increment = 10,
    Suffix = "°",
    CurrentValue = AimbotFOV,
    Flag = "AimbotFOV",
    Callback = function(value)
        AimbotFOV = value
    end,
})

local AimbotPredictionToggle = AimbotTab:CreateToggle({
    Name = "Prediction",
    CurrentValue = AimbotPrediction,
    Flag = "AimbotPrediction",
    Callback = function(value)
        AimbotPrediction = value
    end,
})

local AimbotPredictionSlider = AimbotTab:CreateSlider({
    Name = "Prediction Amount",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = AimbotPredictionAmount,
    Flag = "AimbotPredictionAmount",
    Callback = function(value)
        AimbotPredictionAmount = value
    end,
})

local AimbotKeybind = AimbotTab:CreateKeybind({
    Name = "Aimbot Lock Key",
    CurrentKeybind = "Q",
    HoldToInteract = true,
    Flag = "AimbotKeybind",
    Callback = function(key)
        -- キーを押している間のみ有効にするためのコールバック
    end,
})

-- ESPタブ
local ESPTab = Window:CreateTab("ESP", 4483362458)

local ESPMainSection = ESPTab:CreateSection("Main ESP Settings")

local ESPToggle = ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = ESPEnabled,
    Flag = "ESPEnabled",
    Callback = function(value)
        ESPEnabled = value
    end,
})

local ESPDistanceSlider = ESPTab:CreateSlider({
    Name = "ESP Max Distance",
    Range = {100, 5000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = ESPDistance,
    Flag = "ESPDistance",
    Callback = function(value)
        ESPDistance = value
    end,
})

local ESPBoxToggle = ESPTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = ESPBoxEnabled,
    Flag = "ESPBoxEnabled",
    Callback = function(value)
        ESPBoxEnabled = value
    end,
})

local ESPTracerToggle = ESPTab:CreateToggle({
    Name = "Tracer ESP",
    CurrentValue = ESPTracerEnabled,
    Flag = "ESPTracerEnabled",
    Callback = function(value)
        ESPTracerEnabled = value
    end,
})

local ESPShowDistanceToggle = ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = ESPShowDistance,
    Flag = "ESPShowDistance",
    Callback = function(value)
        ESPShowDistance = value
    end,
})

local ESPShowHealthToggle = ESPTab:CreateToggle({
    Name = "Show Health",
    CurrentValue = ESPShowHealth,
    Flag = "ESPShowHealth",
    Callback = function(value)
        ESPShowHealth = value
    end,
})

local HeadESPSection = ESPTab:CreateSection("Head ESP Settings")

local HeadESPToggle = ESPTab:CreateToggle({
    Name = "Head ESP",
    CurrentValue = ESPHeadEnabled,
    Flag = "ESPHeadEnabled",
    Callback = function(value)
        ESPHeadEnabled = value
    end,
})

local HeadSizeSlider = ESPTab:CreateSlider({
    Name = "Head ESP Size",
    Range = {0.5, 5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = ESPHeadSize,
    Flag = "ESPHeadSize",
    Callback = function(value)
        ESPHeadSize = value
    end,
})

local ESPColorSection = ESPTab:CreateSection("ESP Colors")

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "Box ESP Color",
    Color = ESPColors.Box,
    Flag = "ESPColor",
    Callback = function(color)
        ESPColors.Box = color
    end
})

local HeadESPColorPicker = ESPTab:CreateColorPicker({
    Name = "Head ESP Color",
    Color = ESPColors.Head,
    Flag = "HeadESPColor",
    Callback = function(color)
        ESPColors.Head = color
    end
})

local TracerESPColorPicker = ESPTab:CreateColorPicker({
    Name = "Tracer ESP Color",
    Color = ESPColors.Tracer,
    Flag = "TracerESPColor",
    Callback = function(color)
        ESPColors.Tracer = color
    end
})

local ESPShapeDropdown = ESPTab:CreateDropdown({
    Name = "ESP Shape",
    Options = ESPShapes,
    CurrentOption = SelectedESPShape,
    Flag = "ESPShape",
    Callback = function(option)
        SelectedESPShape = option
    end,
})

-- メインループ
RunService.RenderStepped:Connect(function(deltaTime)
    -- Teleportの自動実行
    if TeleportEnabled and CurrentTarget and CurrentTeleportMethod then
        CurrentTeleportMethod(CurrentTarget, StudOffset)
    end
    
    -- ランダムTPの自動実行
    if RandomTPEnabled then
        -- ターゲットが死んだら新しいターゲットを選択
        if RandomTPOnDeath and RandomTargetPlayer then
            if not RandomTargetPlayer.Character or 
               not RandomTargetPlayer.Character:FindFirstChild("Humanoid") or 
               RandomTargetPlayer.Character.Humanoid.Health <= 0 then
                RandomTargetPlayer = GetRandomEnemy()
            end
        end
        
        -- 定期的にターゲットを更新
        local currentTime = tick()
        if RandomTPAutoUpdate and currentTime - LastRandomTP > RandomTPCooldown then
            RandomTargetPlayer = GetRandomEnemy()
            LastRandomTP = currentTime
        end
        
        -- TPを実行
        if RandomTargetPlayer then
            TeleportMethods.Behind(RandomTargetPlayer, RandomTPStudOffset)
        end
    end
    
    -- Aimbot (Head Lock)
    if AimbotEnabled then
        local targetToAim = CurrentTarget or RandomTargetPlayer
        
        -- Team Checkを適用
        if targetToAim and AimbotTeamCheck and not IsEnemy(targetToAim) then
            targetToAim = nil
        end
        
        if targetToAim and targetToAim.Character then
            local character = targetToAim.Character
            local head = character:FindFirstChild("Head")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if head and rootPart and LocalPlayer.Character then
                local localHead = LocalPlayer.Character:FindFirstChild("Head")
                local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if localHead and localRoot then
                    local camera = Workspace.CurrentCamera
                    
                    -- FOVチェック
                    if IsInFOV(head.Position) then
                        -- 壁チェック
                        if not AimbotWallCheck or IsVisible(head.Position, camera.CFrame.Position) then
                            local targetPosition = head.Position
                            
                            -- 予測機能
                            if AimbotPrediction then
                                local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                                if humanoidRootPart then
                                    local velocity = humanoidRootPart.AssemblyLinearVelocity
                                    if velocity then
                                        targetPosition = targetPosition + (velocity * AimbotPredictionAmount)
                                    end
                                end
                            end
                            
                            -- スムーズネス適用
                            local currentCFrame = camera.CFrame
                            local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
                            
                            if AimbotSmoothness > 0.1 then
                                camera.CFrame = currentCFrame:Lerp(targetCFrame, 1 / AimbotSmoothness)
                            else
                                camera.CFrame = targetCFrame
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- ESPの更新
    if ESPEnabled then
        -- 新しいプレイヤーのESPを作成
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] then
                CreateESP(player)
            end
        end
        
        -- 削除されたプレイヤーのESPを削除
        for player in pairs(ESPObjects) do
            if not Players:FindFirstChild(player.Name) then
                RemoveESP(player)
            end
        end
        
        UpdateESP()
    else
        -- ESPが無効の場合はすべて非表示
        for _, drawings in pairs(ESPObjects) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
    end
end)

-- スクリプト終了時のクリーンアップ
game:GetService("UserInputService").WindowFocused:Connect(function()
    -- ウィンドウがフォーカスを失ったときにESPを非表示にする
    for _, drawings in pairs(ESPObjects) do
        for _, drawing in pairs(drawings) do
            drawing.Visible = false
        end
    end
end)

game:GetService("UserInputService").WindowFocusReleased:Connect(function()
    -- ウィンドウがフォーカスを取り戻したときにESPを再表示
    if ESPEnabled then
        for _, drawings in pairs(ESPObjects) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = true
            end
        end
    end
end)

-- 通知
Rayfield:Notify({
    Title = "Teleport Script v2.0 Loaded",
    Content = "Enhanced script loaded successfully!",
    Duration = 6.5,
    Image = 4483362458,
    Actions = {
        Ignore = {
            Name = "Okay",
            Callback = function()
                print("User acknowledged the notification")
            end
        },
    },
})

print("Teleport Script v2.0 loaded successfully!")
