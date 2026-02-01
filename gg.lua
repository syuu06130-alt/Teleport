-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービスの取得
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- 変数の初期化
local SelectedPlayer = nil
local TPEnabled = false
local TPStud = 5
local RandomTPEnabled = false
local TeamCheck = true
local HeadLockEnabled = false
local WallCheckEnabled = true
local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local HeadESPEnabled = false
local HeadESPColor = Color3.fromRGB(0, 255, 0)
local HeadESPShape = "Box" -- Box, Sphere, Cylinder
local HeadESPSize = 1
local TPConnection = nil
local RandomTPConnection = nil
local HeadLockConnection = nil

-- ESP用のフォルダ
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "ESPFolder"

-- ユーティリティ関数
local function GetPlayerList()
    local playerList = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

local function GetCharacter(player)
    return player and player.Character
end

local function GetRootPart(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
end

local function GetHead(character)
    return character and character:FindFirstChild("Head")
end

local function IsSameTeam(player1, player2)
    if not TeamCheck then return false end
    return player1.Team == player2.Team
end

local function IsAlive(player)
    local char = GetCharacter(player)
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function HasWallBetween(from, to)
    if not WallCheckEnabled then return false end
    
    local ray = Ray.new(from, (to - from))
    local part = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    
    return part ~= nil
end

-- TP関数
local function TPBehindPlayer(targetPlayer, stud)
    if not targetPlayer or not TPEnabled then return end
    
    local localChar = GetCharacter(LocalPlayer)
    local targetChar = GetCharacter(targetPlayer)
    
    if not localChar or not targetChar then return end
    if TeamCheck and IsSameTeam(LocalPlayer, targetPlayer) then return end
    if not IsAlive(targetPlayer) then return end
    
    local localRoot = GetRootPart(localChar)
    local targetRoot = GetRootPart(targetChar)
    
    if localRoot and targetRoot then
        local behindPosition = targetRoot.CFrame * CFrame.new(0, 0, stud)
        localRoot.CFrame = behindPosition
    end
end

-- ランダムプレイヤー取得
local function GetRandomPlayer()
    local validPlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if not TeamCheck or not IsSameTeam(LocalPlayer, player) then
                table.insert(validPlayers, player)
            end
        end
    end
    
    if #validPlayers > 0 then
        return validPlayers[math.random(1, #validPlayers)]
    end
    return nil
end

-- ESP作成関数
local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local char = GetCharacter(player)
    if not char then return end
    
    local rootPart = GetRootPart(char)
    if not rootPart then return end
    
    -- Body ESP
    local highlight = Instance.new("Highlight")
    highlight.Name = "BodyESP_" .. player.Name
    highlight.Adornee = char
    highlight.FillColor = ESPColor
    highlight.OutlineColor = ESPColor
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = ESPFolder
    highlight.Enabled = ESPEnabled
    
    -- Head ESP
    local head = GetHead(char)
    if head and HeadESPEnabled then
        local espPart
        
        if HeadESPShape == "Box" then
            espPart = Instance.new("BoxHandleAdornment")
            espPart.Size = head.Size * HeadESPSize
        elseif HeadESPShape == "Sphere" then
            espPart = Instance.new("SphereHandleAdornment")
            espPart.Radius = head.Size.X * HeadESPSize
        else -- Cylinder
            espPart = Instance.new("CylinderHandleAdornment")
            espPart.Height = head.Size.Y * HeadESPSize
            espPart.Radius = head.Size.X * HeadESPSize
        end
        
        espPart.Name = "HeadESP_" .. player.Name
        espPart.Adornee = head
        espPart.Color3 = HeadESPColor
        espPart.AlwaysOnTop = true
        espPart.Transparency = 0.5
        espPart.ZIndex = 10
        espPart.Parent = ESPFolder
    end
end

local function UpdateAllESP()
    ESPFolder:ClearAllChildren()
    
    if ESPEnabled or HeadESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            CreateESP(player)
        end
    end
end

-- Head Lock (Aimbot)
local function HeadLock()
    if not HeadLockEnabled then return end
    
    local camera = workspace.CurrentCamera
    local closestPlayer = nil
    local closestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if not TeamCheck or not IsSameTeam(LocalPlayer, player) then
                local char = GetCharacter(player)
                local head = GetHead(char)
                
                if head then
                    local distance = (head.Position - camera.CFrame.Position).Magnitude
                    
                    if not HasWallBetween(camera.CFrame.Position, head.Position) then
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    if closestPlayer then
        local head = GetHead(GetCharacter(closestPlayer))
        if head then
            camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
        end
    end
end

-- UI作成
local Window = Rayfield:CreateWindow({
    Name = "高機能TPスクリプト",
    LoadingTitle = "読み込み中...",
    LoadingSubtitle = "by Script Creator",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TPScript",
        FileName = "Config"
    }
})

-- プレイヤー選択タブ
local PlayerTab = Window:CreateTab("プレイヤーTP", 4483362458)

local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "プレイヤーを選択",
    Options = GetPlayerList(),
    CurrentOption = "",
    Flag = "PlayerDropdown",
    Callback = function(Option)
        SelectedPlayer = Players:FindFirstChild(Option)
    end,
})

local TPToggle = PlayerTab:CreateToggle({
    Name = "TP有効化",
    CurrentValue = false,
    Flag = "TPToggle",
    Callback = function(Value)
        TPEnabled = Value
        
        if TPConnection then
            TPConnection:Disconnect()
            TPConnection = nil
        end
        
        if Value and SelectedPlayer then
            TPConnection = RunService.Heartbeat:Connect(function()
                TPBehindPlayer(SelectedPlayer, TPStud)
            end)
        end
    end,
})

local StudSlider = PlayerTab:CreateSlider({
    Name = "TPスタッド距離",
    Range = {0, 25},
    Increment = 0.5,
    CurrentValue = 5,
    Flag = "StudSlider",
    Callback = function(Value)
        TPStud = Value
    end,
})

-- ランダムTPタブ
local RandomTab = Window:CreateTab("ランダムTP", 4483362458)

local TeamCheckToggle = RandomTab:CreateToggle({
    Name = "チームチェック",
    CurrentValue = true,
    Flag = "TeamCheck",
    Callback = function(Value)
        TeamCheck = Value
    end,
})

local RandomTPToggle = RandomTab:CreateToggle({
    Name = "ランダムTP有効化",
    CurrentValue = false,
    Flag = "RandomTPToggle",
    Callback = function(Value)
        RandomTPEnabled = Value
        
        if RandomTPConnection then
            RandomTPConnection:Disconnect()
            RandomTPConnection = nil
        end
        
        if Value then
            local currentTarget = GetRandomPlayer()
            
            RandomTPConnection = RunService.Heartbeat:Connect(function()
                if currentTarget and IsAlive(currentTarget) then
                    TPBehindPlayer(currentTarget, TPStud)
                else
                    currentTarget = GetRandomPlayer()
                end
            end)
        end
    end,
})

-- Aimbotタブ
local AimbotTab = Window:CreateTab("Head Lock", 4483362458)

local HeadLockToggle = AimbotTab:CreateToggle({
    Name = "Head Lock有効化",
    CurrentValue = false,
    Flag = "HeadLock",
    Callback = function(Value)
        HeadLockEnabled = Value
        
        if HeadLockConnection then
            HeadLockConnection:Disconnect()
            HeadLockConnection = nil
        end
        
        if Value then
            HeadLockConnection = RunService.RenderStepped:Connect(HeadLock)
        end
    end,
})

local WallCheckToggle = AimbotTab:CreateToggle({
    Name = "壁判定",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(Value)
        WallCheckEnabled = Value
    end,
})

-- ESPタブ
local ESPTab = Window:CreateTab("ESP設定", 4483362458)

local ESPToggle = ESPTab:CreateToggle({
    Name = "Body ESP",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(Value)
        ESPEnabled = Value
        UpdateAllESP()
    end,
})

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "Body ESP色",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ESPColor",
    Callback = function(Value)
        ESPColor = Value
        UpdateAllESP()
    end
})

local HeadESPToggle = ESPTab:CreateToggle({
    Name = "Head ESP",
    CurrentValue = false,
    Flag = "HeadESP",
    Callback = function(Value)
        HeadESPEnabled = Value
        UpdateAllESP()
    end,
})

local HeadESPColorPicker = ESPTab:CreateColorPicker({
    Name = "Head ESP色",
    Color = Color3.fromRGB(0, 255, 0),
    Flag = "HeadESPColor",
    Callback = function(Value)
        HeadESPColor = Value
        UpdateAllESP()
    end
})

local HeadESPShapeDropdown = ESPTab:CreateDropdown({
    Name = "Head ESP形状",
    Options = {"Box", "Sphere", "Cylinder"},
    CurrentOption = "Box",
    Flag = "HeadESPShape",
    Callback = function(Option)
        HeadESPShape = Option
        UpdateAllESP()
    end,
})

local HeadESPSizeSlider = ESPTab:CreateSlider({
    Name = "Head ESPサイズ",
    Range = {0.5, 3},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "HeadESPSize",
    Callback = function(Value)
        HeadESPSize = Value
        UpdateAllESP()
    end,
})

-- 追加TP機能タブ
local ExtraTPTab = Window:CreateTab("追加TP機能", 4483362458)

ExtraTPTab:CreateButton({
    Name = "前方にTP (10スタッド)",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        if root then
            root.CFrame = root.CFrame * CFrame.new(0, 0, -10)
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "後方にTP (10スタッド)",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        if root then
            root.CFrame = root.CFrame * CFrame.new(0, 0, 10)
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "上にTP (15スタッド)",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        if root then
            root.CFrame = root.CFrame * CFrame.new(0, 15, 0)
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "スポーン地点にTP",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        if root and LocalPlayer.Team and LocalPlayer.Team.TeamSpawnLocation then
            root.CFrame = LocalPlayer.Team.TeamSpawnLocation.CFrame
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "全プレイヤーにTP (順番)",
    Callback = function()
        spawn(function()
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local targetChar = GetCharacter(player)
                    local targetRoot = GetRootPart(targetChar)
                    local localChar = GetCharacter(LocalPlayer)
                    local localRoot = GetRootPart(localChar)
                    
                    if localRoot and targetRoot then
                        localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
                        wait(0.5)
                    end
                end
            end
        end)
    end,
})

ExtraTPTab:CreateButton({
    Name = "マウス位置にTP",
    Callback = function()
        local mouse = LocalPlayer:GetMouse()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        
        if root and mouse.Hit then
            root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "最寄りの敵にTP",
    Callback = function()
        local closestPlayer = nil
        local closestDistance = math.huge
        local localChar = GetCharacter(LocalPlayer)
        local localRoot = GetRootPart(localChar)
        
        if not localRoot then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                if not TeamCheck or not IsSameTeam(LocalPlayer, player) then
                    local targetChar = GetCharacter(player)
                    local targetRoot = GetRootPart(targetChar)
                    
                    if targetRoot then
                        local distance = (targetRoot.Position - localRoot.Position).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
        
        if closestPlayer then
            TPBehindPlayer(closestPlayer, TPStud)
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "ランダム位置にTP (100スタッド範囲)",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        
        if root then
            local randomX = math.random(-100, 100)
            local randomZ = math.random(-100, 100)
            root.CFrame = root.CFrame * CFrame.new(randomX, 0, randomZ)
        end
    end,
})

ExtraTPTab:CreateButton({
    Name = "回転しながらTP",
    Callback = function()
        spawn(function()
            local char = GetCharacter(LocalPlayer)
            local root = GetRootPart(char)
            
            if root then
                for i = 1, 36 do
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(10), 0) * CFrame.new(0, 0, -2)
                    wait(0.05)
                end
            end
        end)
    end,
})

ExtraTPTab:CreateButton({
    Name = "地面にTP",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        
        if root then
            local ray = Ray.new(root.Position, Vector3.new(0, -1000, 0))
            local hit, position = workspace:FindPartOnRay(ray, char)
            
            if hit then
                root.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
            end
        end
    end,
})

-- プレイヤー更新
spawn(function()
    while wait(5) do
        PlayerDropdown:Refresh(GetPlayerList())
    end
end)

-- 新規プレイヤーのESP作成
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        wait(1)
        UpdateAllESP()
    end)
end)

print("スクリプト読み込み完了!")