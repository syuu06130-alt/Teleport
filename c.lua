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

-- チームチェック関数
local function IsEnemy(player)
    if not player or not player.Team then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- 壁チェック関数
local function IsVisible(targetPosition, origin)
    if not AimbotWallCheck then return true end
    
    local direction = (targetPosition - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = Workspace:Raycast(origin, direction * 1000, raycastParams)
    
    if raycastResult then
        local hitPlayer = Players:GetPlayerFromCharacter(raycastResult.Instance:FindFirstAncestorOfClass("Model"))
        return hitPlayer and hitPlayer == CurrentTarget
    end
    return true
end

-- Teleport関数群（5種類のTP方法）
local TeleportMethods = {
    -- 1. 背後にTP（基本）
    Behind = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local direction = humanoidRootPart.CFrame.LookVector
        local offset = CFrame.new(0, 0, StudOffset)
        local newPosition = humanoidRootPart.CFrame * offset * CFrame.new(0, 0, -3)
        
        LocalPlayer.Character:PivotTo(newPosition)
    end,
    
    -- 2. 上にTP
    Above = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 5 + StudOffset, 0))
    end,
    
    -- 3. 前にTP
    Front = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 0, 3 + StudOffset))
    end,
    
    -- 4. 右側にTP
    RightSide = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(3 + StudOffset, 0, 0))
    end,
    
    -- 5. 左側にTP
    LeftSide = function(target)
        if not target or not target.Character then return end
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        LocalPlayer.Character:PivotTo(humanoidRootPart.CFrame * CFrame.new(-3 - StudOffset, 0, 0))
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
    
    ESPObjects[player] = {
        Box = box,
        HeadCircle = headCircle,
        Tracer = tracer
    }
end

local function UpdateESP()
    for player, drawings in pairs(ESPObjects) do
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            drawings.Box.Visible = false
            drawings.HeadCircle.Visible = false
            drawings.Tracer.Visible = false
        else
            local character = player.Character
            local rootPart = character.HumanoidRootPart
            local head = character:FindFirstChild("Head")
            
            -- 3D座標を2Dスクリーン座標に変換
            local rootPos, rootVisible = Workspace.CurrentCamera:WorldToViewportPoint(rootPart.Position)
            
            if rootVisible then
                -- ボックスESP
                local boxSize = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z)
                drawings.Box.Position = Vector2.new(rootPos.X - boxSize.X / 2, rootPos.Y - boxSize.Y / 2)
                drawings.Box.Size = boxSize
                drawings.Box.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                drawings.Box.Color = ESPColors.Box
                
                -- ヘッドESP
                if head and ESPHeadEnabled then
                    local headPos = Workspace.CurrentCamera:WorldToViewportPoint(head.Position)
                    if headPos.Z > 0 then
                        drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
                        drawings.HeadCircle.Radius = ESPHeadSize * (50 / headPos.Z)
                        drawings.HeadCircle.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                        drawings.HeadCircle.Color = ESPColors.Head
                    end
                end
                
                -- トレーサー
                drawings.Tracer.From = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y)
                drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                drawings.Tracer.Visible = ESPEnabled and not (player == CurrentTarget and AimbotEnabled)
                drawings.Tracer.Color = ESPColors.Tracer
            else
                drawings.Box.Visible = false
                drawings.HeadCircle.Visible = false
                drawings.Tracer.Visible = false
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
    Name = "Teleport Script",
    LoadingTitle = "Teleport Script",
    LoadingSubtitle = "by Roblox Scripter",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TeleportScript",
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

local RandomTPToggle = MainTab:CreateToggle({
    Name = "Random TP (Team Check)",
    CurrentValue = RandomTPEnabled,
    Flag = "RandomTPEnabled",
    Callback = function(value)
        RandomTPEnabled = value
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
                TeleportMethods.Behind(enemy)
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
    Name = "Wall Check",
    CurrentValue = AimbotWallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotWallCheck = value
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
        CurrentTeleportMethod(CurrentTarget)
    end
    
    -- ランダムTPの自動実行
    if RandomTPEnabled then
        local currentTime = tick()
        if currentTime - LastRandomTP > RandomTPCooldown then
            local enemy = GetRandomEnemy()
            if enemy then
                TeleportMethods.Behind(enemy)
                LastRandomTP = currentTime
            end
        end
    end
    
    -- Aimbot
    if AimbotEnabled and CurrentTarget and CurrentTarget.Character then
        local character = CurrentTarget.Character
        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if head and rootPart and LocalPlayer.Character then
            local localHead = LocalPlayer.Character:FindFirstChild("Head")
            local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if localHead and localRoot then
                local camera = Workspace.CurrentCamera
                
                -- 壁チェック
                if IsVisible(head.Position, localRoot.Position) then
                    camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
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
            drawings.Box.Visible = false
            drawings.HeadCircle.Visible = false
            drawings.Tracer.Visible = false
        end
    end
end)

-- スクリプト終了時のクリーンアップ
game:GetService("UserInputService").WindowFocused:Connect(function()
    -- ウィンドウがフォーカスを失ったときにESPを非表示にする
    for _, drawings in pairs(ESPObjects) do
        drawings.Box.Visible = false
        drawings.HeadCircle.Visible = false
        drawings.Tracer.Visible = false
    end
end)

game:GetService("UserInputService").WindowFocusReleased:Connect(function()
    -- ウィンドウがフォーカスを取り戻したときにESPを再表示
    if ESPEnabled then
        for _, drawings in pairs(ESPObjects) do
            drawings.Box.Visible = true
            drawings.HeadCircle.Visible = true
            drawings.Tracer.Visible = true
        end
    end
end)

-- 通知
Rayfield:Notify({
    Title = "Teleport Script Loaded",
    Content = "Script has been successfully loaded!",
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

print("Teleport Script loaded successfully!")
