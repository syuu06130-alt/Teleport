-- Rayfield UIをインストールしていない場合は先にインストールしてください
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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
local RandomTPStudOffset = 3
local LastRandomTP = 0
local SmoothAimbot = false
local AimbotSmoothness = 0.1
local AimbotFOV = 30
local SilentAim = false
local SilentAimChance = 100
local TPLagCompensation = false
local TPAnimation = true
local TPSpeed = 1.0

-- ESP用変数
local ESPObjects = {}
local ESPColors = {
    Head = Color3.fromRGB(255, 0, 0),
    Box = Color3.fromRGB(0, 255, 0),
    Tracer = Color3.fromRGB(255, 255, 0),
    Info = Color3.fromRGB(255, 255, 255)
}
local ESPShapes = {"Box", "Circle", "Triangle"}
local SelectedESPShape = "Box"
local ESPHeadSize = 1
local ESPHeadEnabled = true
local ESPBoxEnabled = true
local ESPHealthBar = true
local ESPDistance = true
local ESPMaxDistance = 500
local ESPTextSize = 13
local ESPThickness = 1

-- Aimbot FOV表示
local AimbotFOVCircle = Drawing.new("Circle")
AimbotFOVCircle.Visible = false
AimbotFOVCircle.Color = Color3.fromRGB(255, 255, 255)
AimbotFOVCircle.Thickness = 1
AimbotFOVCircle.NumSides = 64
AimbotFOVCircle.Filled = false

-- チームチェック関数
local function IsEnemy(player)
    if not player or not player.Team then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- 壁チェック関数（改良版）
local function IsVisible(targetPosition, origin, ignoreList)
    if not AimbotWallCheck then return true end
    
    local direction = (targetPosition - origin).Unit
    local distance = (targetPosition - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.CurrentCamera}
    
    if ignoreList then
        for _, obj in ipairs(ignoreList) do
            table.insert(raycastParams.FilterDescendantsInstances, obj)
        end
    end
    
    local raycastResult = Workspace:Raycast(origin, direction * distance, raycastParams)
    
    if raycastResult then
        local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
        if hitModel then
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            return hitPlayer and hitPlayer == CurrentTarget
        end
    end
    return true
end

-- 距離計算関数
local function GetDistance(from, to)
    return (from - to).Magnitude
end

-- FOV内かチェック
local function IsInFOV(position)
    local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(position)
    if not onScreen then return false end
    
    local center = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
    local point = Vector2.new(screenPoint.X, screenPoint.Y)
    
    return (center - point).Magnitude <= AimbotFOV
end

-- 最適なターゲット取得（Aimbot用）
local function GetBestTarget()
    local bestTarget = nil
    local closestDistance = math.huge
    local camera = Workspace.CurrentCamera
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            if humanoid.Health > 0 and IsEnemy(player) then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    local distance = GetDistance(camera.CFrame.Position, head.Position)
                    
                    if IsInFOV(head.Position) and distance < closestDistance then
                        if IsVisible(head.Position, camera.CFrame.Position) then
                            closestDistance = distance
                            bestTarget = player
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Teleport関数群（7種類のTP方法に拡張）
local TeleportMethods = {
    -- 1. 背後にTP（基本）
    Behind = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        local direction = humanoidRootPart.CFrame.LookVector
        local newPosition = humanoidRootPart.CFrame * CFrame.new(0, 0, -offset - 3)
        
        if TPAnimation then
            -- スムーズなテレポート
            local tweenInfo = TweenInfo.new(TPSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(LocalPlayer.Character.HumanoidRootPart, tweenInfo, {CFrame = newPosition})
            tween:Play()
        else
            LocalPlayer.Character:PivotTo(newPosition)
        end
    end,
    
    -- 2. 上にTP
    Above = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 5 + offset, 0))
    end,
    
    -- 3. 前にTP
    Front = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 0, 3 + offset))
    end,
    
    -- 4. 右側にTP
    RightSide = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(3 + offset, 0, 0))
    end,
    
    -- 5. 左側にTP
    LeftSide = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(-3 - offset, 0, 0))
    end,
    
    -- 6. ランダム位置にTP
    RandomPosition = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        local randomAngle = math.random(0, 360)
        local randomDistance = math.random(offset, offset + 5)
        local x = math.cos(math.rad(randomAngle)) * randomDistance
        local z = math.sin(math.rad(randomAngle)) * randomDistance
        
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(x, 0, z))
    end,
    
    -- 7. 予測位置にTP（ラグ補正）
    Predictive = function(target, customStudOffset)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        
        -- 速度ベースの予測
        local velocity = humanoidRootPart.Velocity
        local predictedPosition = humanoidRootPart.Position + (velocity * 0.1) -- 0.1秒先を予測
        
        local newCFrame = CFrame.new(predictedPosition) * CFrame.new(0, 0, -offset - 3)
        LocalPlayer.Character:PivotTo(newCFrame)
    end
}

-- 現在選択されたTP方法
local CurrentTeleportMethod = TeleportMethods.Behind

-- ランダムプレイヤー選択（チームチェック付き）
local function GetRandomEnemy()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 and IsEnemy(player) then
                table.insert(enemies, player)
            end
        end
    end
    
    if #enemies > 0 then
        return enemies[math.random(1, #enemies)]
    end
    return nil
end

-- ESP描画関数（改良版）
local function CreateESP(player)
    if ESPObjects[player] then return end
    
    local drawingObjects = {}
    
    -- ボックスESP
    if ESPBoxEnabled then
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = ESPColors.Box
        box.Thickness = ESPThickness
        box.Filled = false
        drawingObjects.Box = box
    end
    
    -- ヘッドESP
    if ESPHeadEnabled then
        local headCircle = Drawing.new("Circle")
        headCircle.Visible = false
        headCircle.Color = ESPColors.Head
        headCircle.Thickness = ESPThickness
        headCircle.Filled = false
        drawingObjects.HeadCircle = headCircle
    end
    
    -- トレーサー
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = ESPColors.Tracer
    tracer.Thickness = ESPThickness
    drawingObjects.Tracer = tracer
    
    -- ヘルスバー
    if ESPHealthBar then
        local healthBar = Drawing.new("Line")
        healthBar.Visible = false
        healthBar.Color = Color3.fromRGB(0, 255, 0)
        healthBar.Thickness = 2
        drawingObjects.HealthBar = healthBar
        
        local healthBarBackground = Drawing.new("Line")
        healthBarBackground.Visible = false
        healthBarBackground.Color = Color3.fromRGB(255, 0, 0)
        healthBarBackground.Thickness = 2
        drawingObjects.HealthBarBackground = healthBarBackground
    end
    
    -- 情報テキスト
    local infoText = Drawing.new("Text")
    infoText.Visible = false
    infoText.Color = ESPColors.Info
    infoText.Size = ESPTextSize
    infoText.Outline = true
    infoText.OutlineColor = Color3.new(0, 0, 0)
    drawingObjects.InfoText = infoText
    
    ESPObjects[player] = drawingObjects
end

local function UpdateESP()
    local camera = Workspace.CurrentCamera
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    for player, drawings in pairs(ESPObjects) do
        if not player or not player.Character then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        else
            local character = player.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            local head = character:FindFirstChild("Head")
            
            if rootPart and humanoid then
                local rootPos, rootVisible = camera:WorldToViewportPoint(rootPart.Position)
                local distance = GetDistance(camera.CFrame.Position, rootPart.Position)
                
                if rootVisible and distance <= ESPMaxDistance then
                    -- ボックスESP
                    if drawings.Box then
                        local boxSize = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z)
                        drawings.Box.Position = Vector2.new(rootPos.X - boxSize.X / 2, rootPos.Y - boxSize.Y / 2)
                        drawings.Box.Size = boxSize
                        drawings.Box.Visible = ESPEnabled
                        drawings.Box.Color = ESPColors.Box
                    end
                    
                    -- ヘッドESP
                    if drawings.HeadCircle and head then
                        local headPos = camera:WorldToViewportPoint(head.Position)
                        if headPos.Z > 0 then
                            drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
                            drawings.HeadCircle.Radius = ESPHeadSize * (50 / headPos.Z)
                            drawings.HeadCircle.Visible = ESPEnabled
                            drawings.HeadCircle.Color = ESPColors.Head
                        end
                    end
                    
                    -- トレーサー
                    if drawings.Tracer then
                        drawings.Tracer.From = Vector2.new(screenCenter.X, camera.ViewportSize.Y)
                        drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                        drawings.Tracer.Visible = ESPEnabled
                        drawings.Tracer.Color = ESPColors.Tracer
                    end
                    
                    -- ヘルスバー
                    if drawings.HealthBar and drawings.HealthBarBackground then
                        local boxSize = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z)
                        local healthPercentage = humanoid.Health / humanoid.MaxHealth
                        local barHeight = boxSize.Y * healthPercentage
                        
                        -- 背景（赤）
                        drawings.HealthBarBackground.From = Vector2.new(rootPos.X - boxSize.X / 2 - 5, rootPos.Y + boxSize.Y / 2)
                        drawings.HealthBarBackground.To = Vector2.new(rootPos.X - boxSize.X / 2 - 5, rootPos.Y - boxSize.Y / 2)
                        drawings.HealthBarBackground.Visible = ESPEnabled
                        
                        -- 現在のヘルス（緑）
                        drawings.HealthBar.From = Vector2.new(rootPos.X - boxSize.X / 2 - 5, rootPos.Y + boxSize.Y / 2)
                        drawings.HealthBar.To = Vector2.new(rootPos.X - boxSize.X / 2 - 5, rootPos.Y + boxSize.Y / 2 - barHeight)
                        drawings.HealthBar.Visible = ESPEnabled
                    end
                    
                    -- 情報テキスト
                    if drawings.InfoText then
                        local info = ""
                        if ESPDistance then
                            info = string.format("[%.0f studs]", distance)
                        end
                        if player.Team then
                            info = info .. "\n" .. player.Team.Name
                        end
                        
                        drawings.InfoText.Position = Vector2.new(rootPos.X, rootPos.Y + boxSize.Y / 2 + 5)
                        drawings.InfoText.Text = info
                        drawings.InfoText.Visible = ESPEnabled and info ~= ""
                    end
                else
                    for _, drawing in pairs(drawings) do
                        drawing.Visible = false
                    end
                end
            else
                for _, drawing in pairs(drawings) do
                    drawing.Visible = false
                end
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
    Name = "Teleport Script v2",
    LoadingTitle = "Advanced Teleport Script",
    LoadingSubtitle = "by Roblox Scripter - 詳細設定対応",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TeleportScript",
        FileName = "AdvancedConfig"
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
    Name = "Stud Offset",
    Range = {0, 25},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = StudOffset,
    Flag = "StudOffset",
    Callback = function(value)
        StudOffset = value
    end,
})

local TPSpeedSlider = MainTab:CreateSlider({
    Name = "TP Speed",
    Range = {0.1, 3},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = TPSpeed,
    Flag = "TPSpeed",
    Callback = function(value)
        TPSpeed = value
    end,
})

local AnimationToggle = MainTab:CreateToggle({
    Name = "TP Animation",
    CurrentValue = TPAnimation,
    Flag = "TPAnimation",
    Callback = function(value)
        TPAnimation = value
    end,
})

local LagCompToggle = MainTab:CreateToggle({
    Name = "Lag Compensation",
    CurrentValue = TPLagCompensation,
    Flag = "LagCompensation",
    Callback = function(value)
        TPLagCompensation = value
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

Players.PlayerAdded:Connect(UpdatePlayerList)
Players.PlayerRemoving:Connect(UpdatePlayerList)
UpdatePlayerList()

local TeleportMethodDropdown = MainTab:CreateDropdown({
    Name = "Teleport Method",
    Options = {"Behind", "Above", "Front", "Right Side", "Left Side", "Random Position", "Predictive"},
    CurrentOption = "Behind",
    Flag = "TeleportMethod",
    Callback = function(option)
        local methodName = option:gsub(" ", "")
        if methodName == "RightSide" then methodName = "RightSide" end
        if methodName == "LeftSide" then methodName = "LeftSide" end
        if methodName == "RandomPosition" then methodName = "RandomPosition" end
        CurrentTeleportMethod = TeleportMethods[methodName]
    end,
})

-- Random TPセクション
local RandomTPSection = MainTab:CreateSection("Random TP Settings")

local RandomTPToggle = MainTab:CreateToggle({
    Name = "Random TP (Team Check)",
    CurrentValue = RandomTPEnabled,
    Flag = "RandomTPEnabled",
    Callback = function(value)
        RandomTPEnabled = value
    end,
})

local RandomTPStudSlider = MainTab:CreateSlider({
    Name = "Random TP Stud Offset",
    Range = {0, 25},
    Increment = 1,
    Suffix = "studs",
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
    Suffix = "s",
    CurrentValue = RandomTPCooldown,
    Flag = "RandomTPCooldown",
    Callback = function(value)
        RandomTPCooldown = value
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

local AimbotSection = AimbotTab:CreateSection("Aimbot Settings")

local AimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Head Lock (Aimbot)",
    CurrentValue = AimbotEnabled,
    Flag = "AimbotEnabled",
    Callback = function(value)
        AimbotEnabled = value
    end,
})

local WallCheckToggle = AimbotTab:CreateToggle({
    Name = "Wall Check (初期設定: オン)",
    CurrentValue = AimbotWallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotWallCheck = value
    end,
})

local SmoothAimbotToggle = AimbotTab:CreateToggle({
    Name = "Smooth Aimbot",
    CurrentValue = SmoothAimbot,
    Flag = "SmoothAimbot",
    Callback = function(value)
        SmoothAimbot = value
    end,
})

local SmoothnessSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Smoothness",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = AimbotSmoothness,
    Flag = "AimbotSmoothness",
    Callback = function(value)
        AimbotSmoothness = value
    end,
})

local FOVSlider = AimbotTab:CreateSlider({
    Name = "Aimbot FOV",
    Range = {1, 180},
    Increment = 1,
    Suffix = "°",
    CurrentValue = AimbotFOV,
    Flag = "AimbotFOV",
    Callback = function(value)
        AimbotFOV = value
        AimbotFOVCircle.Radius = value
    end,
})

local ShowFOVToggle = AimbotTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = false,
    Flag = "ShowFOVCircle",
    Callback = function(value)
        AimbotFOVCircle.Visible = value
    end,
})

local SilentAimToggle = AimbotTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = SilentAim,
    Flag = "SilentAim",
    Callback = function(value)
        SilentAim = value
    end,
})

local SilentAimChanceSlider = AimbotTab:CreateSlider({
    Name = "Silent Aim Chance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = SilentAimChance,
    Flag = "SilentAimChance",
    Callback = function(value)
        SilentAimChance = value
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

local ESPToggle = ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = ESPEnabled,
    Flag = "ESPEnabled",
    Callback = function(value)
        ESPEnabled = value
    end,
})

local HeadESPToggle = ESPTab:CreateToggle({
    Name = "Head ESP",
    CurrentValue = ESPHeadEnabled,
    Flag = "ESPHeadEnabled",
    Callback = function(value)
        ESPHeadEnabled = value
    end,
})

local BoxESPToggle = ESPTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = ESPBoxEnabled,
    Flag = "ESPBoxEnabled",
    Callback = function(value)
        ESPBoxEnabled = value
    end,
})

local HealthBarToggle = ESPTab:CreateToggle({
    Name = "Health Bar",
    CurrentValue = ESPHealthBar,
    Flag = "ESPHealthBar",
    Callback = function(value)
        ESPHealthBar = value
    end,
})

local DistanceToggle = ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = ESPDistance,
    Flag = "ESPDistance",
    Callback = function(value)
        ESPDistance = value
    end,
})

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ESP Color",
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

local TracerColorPicker = ESPTab:CreateColorPicker({
    Name = "Tracer Color",
    Color = ESPColors.Tracer,
    Flag = "TracerColor",
    Callback = function(color)
        ESPColors.Tracer = color
    end
})

local InfoColorPicker = ESPTab:CreateColorPicker({
    Name = "Info Text Color",
    Color = ESPColors.Info,
    Flag = "InfoColor",
    Callback = function(color)
        ESPColors.Info = color
    end
})

local HeadSizeSlider = ESPTab:CreateSlider({
    Name = "Head ESP Size",
    Range = {0.5, 3},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = ESPHeadSize,
    Flag = "ESPHeadSize",
    Callback = function(value)
        ESPHeadSize = value
    end,
})

local ESPThicknessSlider = ESPTab:CreateSlider({
    Name = "ESP Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = ESPThickness,
    Flag = "ESPThickness",
    Callback = function(value)
        ESPThickness = value
    end,
})

local TextSizeSlider = ESPTab:CreateSlider({
    Name = "Text Size",
    Range = {8, 20},
    Increment = 1,
    Suffix = "px",
    CurrentValue = ESPTextSize,
    Flag = "ESPTextSize",
    Callback = function(value)
        ESPTextSize = value
    end,
})

local MaxDistanceSlider = ESPTab:CreateSlider({
    Name = "Max ESP Distance",
    Range = {50, 1000},
    Increment = 10,
    Suffix = "studs",
    CurrentValue = ESPMaxDistance,
    Flag = "ESPMaxDistance",
    Callback = function(value)
        ESPMaxDistance = value
    end,
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

-- 設定タブ
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local ResetButton = SettingsTab:CreateButton({
    Name = "Reset Settings",
    Callback = function()
        TeleportEnabled = false
        RandomTPEnabled = false
        AimbotEnabled = false
        ESPEnabled = false
        AimbotWallCheck = true
        SmoothAimbot = false
        SilentAim = false
        
        Rayfield:Notify({
            Title = "Settings Reset",
            Content = "All settings have been reset to defaults",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

local DestroyButton = SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        Rayfield:Destroy()
        for player, drawings in pairs(ESPObjects) do
            RemoveESP(player)
        end
        AimbotFOVCircle:Remove()
    end,
})

-- FOVサークルの設定
AimbotFOVCircle.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
AimbotFOVCircle.Radius = AimbotFOV

-- メインループ
RunService.RenderStepped:Connect(function(deltaTime)
    -- FOVサークルの更新
    AimbotFOVCircle.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
    
    -- Teleportの自動実行
    if TeleportEnabled and CurrentTarget and CurrentTeleportMethod then
        CurrentTeleportMethod(CurrentTarget)
    end
    
    -- ランダムTPの自動実行
    if RandomTPEnabled then
        local currentTime = tick()
        if currentTime - LastRandomTP > RandomTPCooldown then
            local enemy = GetRandomEnemy()
            if enemy then
                TeleportMethods.Behind(enemy, RandomTPStudOffset)
                LastRandomTP = currentTime
            end
        end
    end
    
    -- Aimbot
    if AimbotEnabled then
        -- ターゲットの自動選択
        if not CurrentTarget or not CurrentTarget.Character or CurrentTarget.Character.Humanoid.Health <= 0 then
            CurrentTarget = GetBestTarget()
        end
        
        -- ターゲットがいる場合
        if CurrentTarget and CurrentTarget.Character then
            local character = CurrentTarget.Character
            local head = character:FindFirstChild("Head")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if head and rootPart and LocalPlayer.Character then
                local localHead = LocalPlayer.Character:FindFirstChild("Head")
                local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if localHead and localRoot then
                    local camera = Workspace.CurrentCamera
                    
                    -- 壁チェック
                    if IsVisible(head.Position, camera.CFrame.Position) then
                        if SmoothAimbot then
                            -- スムーズなAimbot
                            local targetCFrame = CFrame.new(camera.CFrame.Position, head.Position)
                            local currentCFrame = camera.CFrame
                            local smoothedCFrame = currentCFrame:Lerp(targetCFrame, AimbotSmoothness)
                            camera.CFrame = smoothedCFrame
                        else
                            -- 即時Aimbot
                            camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
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

-- Silent Aimフック（概念実装）
if SilentAim then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if method == "FindPartOnRayWithIgnoreList" or method == "Raycast" then
            if SilentAim and CurrentTarget and CurrentTarget.Character and math.random(1, 100) <= SilentAimChance then
                local head = CurrentTarget.Character:FindFirstChild("Head")
                if head then
                    -- ターゲットの頭を狙うように変更
                    args[1] = Ray.new(Workspace.CurrentCamera.CFrame.Position, (head.Position - Workspace.CurrentCamera.CFrame.Position).Unit * 1000)
                end
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
end

-- スクリプト終了時のクリーンアップ
local function Cleanup()
    for player, drawings in pairs(ESPObjects) do
        RemoveESP(player)
    end
    AimbotFOVCircle:Remove()
end

game:GetService("UserInputService").WindowFocused:Connect(function()
    -- ウィンドウがフォーカスを失ったときにESPを非表示にする
    for _, drawings in pairs(ESPObjects) do
        for _, drawing in pairs(drawings) do
            drawing.Visible = false
        end
    end
    AimbotFOVCircle.Visible = false
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
    if AimbotEnabled then
        AimbotFOVCircle.Visible = true
    end
end)

-- ゲーム終了時のクリーンアップ
game:BindToClose(function()
    Cleanup()
end)

-- 通知
Rayfield:Notify({
    Title = "Advanced Teleport Script Loaded",
    Content = "Script has been successfully loaded with advanced features!",
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

print("Advanced Teleport Script loaded successfully!")
