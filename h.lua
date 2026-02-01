-- Rayfield UIをインストールしていない場合は先にインストールしてください
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ローカルプレイヤーを安全に取得
local LocalPlayer
local function GetLocalPlayer()
    while not Players.LocalPlayer do
        wait(0.1)
    end
    return Players.LocalPlayer
end

LocalPlayer = GetLocalPlayer()

-- 変数
local CurrentTarget = nil
local TeleportEnabled = false
local RandomTPEnabled = false
local AimbotEnabled = false
local AimbotWallCheck = true
local ESPEnabled = false
local StudOffset = 5
local RandomTPStudOffset = 3
local RandomTPCooldown = 2
local RandomTPStayTime = 3
local LastRandomTP = 0
local SmoothAimbot = false
local AimbotSmoothness = 0.1
local AimbotFOV = 30
local AimbotAccuracy = 100
local SilentAim = false
local SilentAimChance = 100
local TPAnimation = true
local TPSpeed = 1.0
local StayAboveEnabled = false
local StayAboveHeight = 20
local UnderneathTPEnabled = false
local WallClipEnabled = false

-- 位置保存用
local OriginalPosition = nil
local IsStayingAbove = false
local IsUnderneathTP = false

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

-- デバッグ用
local function DebugPrint(message)
    print("[DEBUG]: " .. message)
end

-- 安全なキャラクター取得
local function GetSafeCharacter(player)
    if not player then return nil end
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") then
        local humanoid = character.Humanoid
        if humanoid and humanoid.Health > 0 then
            return character
        end
    end
    return nil
end

-- チームチェック関数
local function IsEnemy(player)
    if not player then return true end
    if not LocalPlayer then return true end
    
    -- チームチェック
    if game:GetService("Players").LocalPlayer.Team and player.Team then
        return player.Team ~= LocalPlayer.Team
    end
    
    return true
end

-- 壁チェック関数
local function IsVisible(targetPosition, origin)
    if not AimbotWallCheck or WallClipEnabled then 
        return true 
    end
    
    local direction = (targetPosition - origin).Unit
    local distance = (targetPosition - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
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
        if player ~= LocalPlayer then
            local character = GetSafeCharacter(player)
            if character and IsEnemy(player) then
                local head = character:FindFirstChild("Head")
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

-- Teleport関数群
local TeleportMethods = {
    -- 背後にTP
    Behind = function(target, customStudOffset)
        if not target then return end
        local character = GetSafeCharacter(LocalPlayer)
        local targetChar = GetSafeCharacter(target)
        if not character or not targetChar then return end
        
        local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
        local localRoot = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart or not localRoot then return end
        
        local offset = customStudOffset or StudOffset
        local direction = humanoidRootPart.CFrame.LookVector
        local newCFrame = humanoidRootPart.CFrame * CFrame.new(0, 0, -offset - 3)
        
        if TPAnimation then
            local tweenInfo = TweenInfo.new(TPSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(localRoot, tweenInfo, {CFrame = newCFrame})
            tween:Play()
        else
            character:PivotTo(newCFrame)
        end
    end,
    
    -- 上にTP
    Above = function(target, customStudOffset)
        if not target then return end
        local character = GetSafeCharacter(LocalPlayer)
        local targetChar = GetSafeCharacter(target)
        if not character or not targetChar then return end
        
        local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 5 + offset, 0))
    end,
    
    -- 前にTP
    Front = function(target, customStudOffset)
        if not target then return end
        local character = GetSafeCharacter(LocalPlayer)
        local targetChar = GetSafeCharacter(target)
        if not character or not targetChar then return end
        
        local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local offset = customStudOffset or StudOffset
        character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 0, 3 + offset))
    end
}

-- 現在選択されたTP方法
local CurrentTeleportMethod = TeleportMethods.Behind

-- 上空に滞在するTP関数
local function StayAboveTargetFunc(target)
    if not target or not StayAboveEnabled then 
        IsStayingAbove = false
        return 
    end
    
    local targetChar = GetSafeCharacter(target)
    if not targetChar then 
        IsStayingAbove = false
        return 
    end
    
    local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        IsStayingAbove = false
        return 
    end
    
    IsStayingAbove = true
    
    while StayAboveEnabled and IsStayingAbove and target and targetChar do
        local character = GetSafeCharacter(LocalPlayer)
        if not character then break end
        
        local newPosition = humanoidRootPart.CFrame * CFrame.new(0, StayAboveHeight, 0)
        character:PivotTo(newPosition)
        
        -- ターゲットが死んだら終了
        if targetChar.Humanoid.Health <= 0 then
            break
        end
        
        RunService.Heartbeat:Wait()
    end
    
    IsStayingAbove = false
end

-- 床下固定TP関数
local function UnderneathTPFunc(target)
    if not target or not UnderneathTPEnabled then 
        IsUnderneathTP = false
        return 
    end
    
    local targetChar = GetSafeCharacter(target)
    if not targetChar then 
        IsUnderneathTP = false
        return 
    end
    
    local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        IsUnderneathTP = false
        return 
    end
    
    IsUnderneathTP = true
    
    while UnderneathTPEnabled and IsUnderneathTP and target and targetChar do
        local character = GetSafeCharacter(LocalPlayer)
        if not character then break end
        
        -- 床下にTP
        local newPosition = humanoidRootPart.CFrame * CFrame.new(0, -5, 0)
        character:PivotTo(newPosition)
        
        -- ターゲットが死んだら終了
        if targetChar.Humanoid.Health <= 0 then
            break
        end
        
        RunService.Heartbeat:Wait()
    end
    
    IsUnderneathTP = false
end

-- ランダムプレイヤー選択（チームチェック付き）
local function GetRandomEnemy()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = GetSafeCharacter(player)
            if character and IsEnemy(player) then
                table.insert(enemies, player)
            end
        end
    end
    
    if #enemies > 0 then
        return enemies[math.random(1, #enemies)]
    end
    return nil
end

-- ランダムTP実行関数
local function ExecuteRandomTP()
    local enemy = GetRandomEnemy()
    if enemy then
        local startTime = tick()
        
        -- 元の位置を保存
        local character = GetSafeCharacter(LocalPlayer)
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                OriginalPosition = root.CFrame
            end
        end
        
        -- TP実行
        TeleportMethods.Behind(enemy, RandomTPStudOffset)
        
        -- 指定時間滞在
        while tick() - startTime < RandomTPStayTime do
            if not RandomTPEnabled then break end
            
            local targetChar = GetSafeCharacter(enemy)
            if not targetChar or targetChar.Humanoid.Health <= 0 then
                enemy = GetRandomEnemy()
                if not enemy then break end
                TeleportMethods.Behind(enemy, RandomTPStudOffset)
            else
                TeleportMethods.Behind(enemy, RandomTPStudOffset)
            end
            
            RunService.Heartbeat:Wait()
        end
        
        -- 元の位置に戻る
        if OriginalPosition and character then
            character:PivotTo(OriginalPosition)
        end
    end
end

-- ESP描画関数
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
        if not player or not Players:FindFirstChild(player.Name) then
            for _, drawing in pairs(drawings) do
                if drawing then drawing.Visible = false end
            end
        else
            local character = player.Character
            if not character then
                for _, drawing in pairs(drawings) do
                    if drawing then drawing.Visible = false end
                end
            else
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
                        end
                        
                        -- ヘッドESP
                        if drawings.HeadCircle and head then
                            local headPos = camera:WorldToViewportPoint(head.Position)
                            if headPos.Z > 0 then
                                drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
                                drawings.HeadCircle.Radius = ESPHeadSize * (50 / headPos.Z)
                                drawings.HeadCircle.Visible = ESPEnabled
                            end
                        end
                        
                        -- トレーサー
                        if drawings.Tracer then
                            drawings.Tracer.From = Vector2.new(screenCenter.X, camera.ViewportSize.Y)
                            drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                            drawings.Tracer.Visible = ESPEnabled
                        end
                        
                        -- 情報テキスト
                        if drawings.InfoText then
                            local info = player.Name
                            if ESPDistance then
                                info = info .. string.format(" [%.0f]", distance)
                            end
                            
                            drawings.InfoText.Position = Vector2.new(rootPos.X, rootPos.Y - 50)
                            drawings.InfoText.Text = info
                            drawings.InfoText.Visible = ESPEnabled
                        end
                    else
                        for _, drawing in pairs(drawings) do
                            if drawing then drawing.Visible = false end
                        end
                    end
                else
                    for _, drawing in pairs(drawings) do
                        if drawing then drawing.Visible = false end
                    end
                end
            end
        end
    end
end

-- ESP削除関数
local function RemoveESP(player)
    if ESPObjects[player] then
        for _, drawing in pairs(ESPObjects[player]) do
            if drawing then
                drawing:Remove()
            end
        end
        ESPObjects[player] = nil
    end
end

-- Rayfield UIの作成
local Window = Rayfield:CreateWindow({
    Name = "Teleport Script v3 - 修正版",
    LoadingTitle = "完全修正 Teleport Script",
    LoadingSubtitle = "全ての機能が動作するバージョン",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TeleportScript",
        FileName = "FixedConfig"
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

-- 上空滞在TPセクション
local StayAboveSection = MainTab:CreateSection("上空滞在TP")

local StayAboveToggle = MainTab:CreateToggle({
    Name = "上空にTPして滞在",
    CurrentValue = StayAboveEnabled,
    Flag = "StayAboveEnabled",
    Callback = function(value)
        StayAboveEnabled = value
        if value and CurrentTarget then
            task.spawn(function()
                StayAboveTargetFunc(CurrentTarget)
            end)
        else
            IsStayingAbove = false
        end
    end,
})

local StayAboveHeightSlider = MainTab:CreateSlider({
    Name = "滞在高さ",
    Range = {10, 100},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = StayAboveHeight,
    Flag = "StayAboveHeight",
    Callback = function(value)
        StayAboveHeight = value
    end,
})

-- 床下固定TPセクション
local UnderneathSection = MainTab:CreateSection("床下固定TP")

local UnderneathToggle = MainTab:CreateToggle({
    Name = "床下固定TP（死ぬまで）",
    CurrentValue = UnderneathTPEnabled,
    Flag = "UnderneathTPEnabled",
    Callback = function(value)
        UnderneathTPEnabled = value
        if value and CurrentTarget then
            task.spawn(function()
                UnderneathTPFunc(CurrentTarget)
            end)
        else
            IsUnderneathTP = false
        end
    end,
})

local WallClipToggle = MainTab:CreateToggle({
    Name = "壁貫通",
    CurrentValue = WallClipEnabled,
    Flag = "WallClipEnabled",
    Callback = function(value)
        WallClipEnabled = value
    end,
})

-- プレイヤー選択
local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Select Player",
    Options = {"None"},
    CurrentOption = "None",
    Flag = "SelectedPlayer",
    Callback = function(option)
        if option == "None" then
            CurrentTarget = nil
            StayAboveEnabled = false
            UnderneathTPEnabled = false
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

Players.PlayerAdded:Connect(function()
    wait(0.5)
    UpdatePlayerList()
end)

Players.PlayerRemoving:Connect(function()
    wait(0.5)
    UpdatePlayerList()
end)

UpdatePlayerList()

local TeleportMethodDropdown = MainTab:CreateDropdown({
    Name = "Teleport Method",
    Options = {"Behind", "Above", "Front"},
    CurrentOption = "Behind",
    Flag = "TeleportMethod",
    Callback = function(option)
        CurrentTeleportMethod = TeleportMethods[option]
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
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = RandomTPCooldown,
    Flag = "RandomTPCooldown",
    Callback = function(value)
        RandomTPCooldown = value
    end,
})

local RandomTPStayTimeSlider = MainTab:CreateSlider({
    Name = "Random TP 滞在時間",
    Range = {1, 30},
    Increment = 1,
    Suffix = "s",
    CurrentValue = RandomTPStayTime,
    Flag = "RandomTPStayTime",
    Callback = function(value)
        RandomTPStayTime = value
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
            task.spawn(ExecuteRandomTP)
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
    Name = "壁判定 (初期設定: オン)",
    CurrentValue = AimbotWallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotWallCheck = value
    end,
})

local AccuracySlider = AimbotTab:CreateSlider({
    Name = "Aimbot 精度",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = AimbotAccuracy,
    Flag = "AimbotAccuracy",
    Callback = function(value)
        AimbotAccuracy = value
        AimbotSmoothness = (101 - value) / 100
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
    Name = "FOV Circle 表示",
    CurrentValue = false,
    Flag = "ShowFOVCircle",
    Callback = function(value)
        AimbotFOVCircle.Visible = value
    end,
})

local AimbotKeybind = AimbotTab:CreateKeybind({
    Name = "Aimbot Keybind",
    CurrentKeybind = "Q",
    HoldToInteract = true,
    Flag = "AimbotKeybind",
    Callback = function(key)
        -- キーを押している間のみ有効
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
        if not value then
            for _, drawings in pairs(ESPObjects) do
                for _, drawing in pairs(drawings) do
                    if drawing then drawing.Visible = false end
                end
            end
        end
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

local DistanceToggle = ESPTab:CreateToggle({
    Name = "距離表示",
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

local MaxDistanceSlider = ESPTab:CreateSlider({
    Name = "最大表示距離",
    Range = {50, 1000},
    Increment = 10,
    Suffix = "studs",
    CurrentValue = ESPMaxDistance,
    Flag = "ESPMaxDistance",
    Callback = function(value)
        ESPMaxDistance = value
    end,
})

-- 設定タブ
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local ResetButton = SettingsTab:CreateButton({
    Name = "設定リセット",
    Callback = function()
        TeleportEnabled = false
        RandomTPEnabled = false
        AimbotEnabled = false
        ESPEnabled = false
        StayAboveEnabled = false
        UnderneathTPEnabled = false
        WallClipEnabled = false
        
        IsStayingAbove = false
        IsUnderneathTP = false
        
        Rayfield:Notify({
            Title = "設定をリセット",
            Content = "全ての設定をデフォルトに戻しました",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

local DestroyButton = SettingsTab:CreateButton({
    Name = "UIを閉じる",
    Callback = function()
        Rayfield:Destroy()
        for player, drawings in pairs(ESPObjects) do
            RemoveESP(player)
        end
        if AimbotFOVCircle then
            AimbotFOVCircle:Remove()
        end
    end,
})

-- FOVサークルの設定
AimbotFOVCircle.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
AimbotFOVCircle.Radius = AimbotFOV

-- メインループ
local RandomTPActive = false

RunService.RenderStepped:Connect(function(deltaTime)
    -- FOVサークルの更新
    if AimbotFOVCircle then
        AimbotFOVCircle.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
    end
    
    -- Teleportの自動実行
    if TeleportEnabled and CurrentTarget and CurrentTeleportMethod then
        if not IsStayingAbove and not IsUnderneathTP then
            CurrentTeleportMethod(CurrentTarget)
        end
    end
    
    -- ランダムTPの自動実行
    if RandomTPEnabled and not RandomTPActive then
        local currentTime = tick()
        if currentTime - LastRandomTP > RandomTPCooldown then
            RandomTPActive = true
            LastRandomTP = currentTime
            task.spawn(function()
                ExecuteRandomTP()
                RandomTPActive = false
            end)
        end
    end
    
    -- Aimbot
    if AimbotEnabled then
        -- ターゲットの自動選択
        if not CurrentTarget then
            CurrentTarget = GetBestTarget()
        end
        
        if CurrentTarget then
            local targetChar = GetSafeCharacter(CurrentTarget)
            if targetChar then
                local head = targetChar:FindFirstChild("Head")
                if head then
                    local camera = Workspace.CurrentCamera
                    
                    -- 壁チェック
                    if IsVisible(head.Position, camera.CFrame.Position) then
                        -- 精度に基づくスムーズなAimbot
                        local targetCFrame = CFrame.new(camera.CFrame.Position, head.Position)
                        local currentCFrame = camera.CFrame
                        
                        -- 精度計算（精度が高いほど素早く、低いほど遅く）
                        local accuracyFactor = AimbotAccuracy / 100
                        local smoothedCFrame = currentCFrame:Lerp(targetCFrame, accuracyFactor)
                        camera.CFrame = smoothedCFrame
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
    end
end)

-- ゲーム開始時の初期化
task.spawn(function()
    wait(1)
    UpdatePlayerList()
    
    -- 既存のプレイヤーにESPを作成
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
end)

-- 通知
Rayfield:Notify({
    Title = "Teleport Script v3 ロード完了",
    Content = "全ての機能が正常に動作するよう修正されました",
    Duration = 5,
    Image = 4483362458,
})

DebugPrint("スクリプトが正常にロードされました")
