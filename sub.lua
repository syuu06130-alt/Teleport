-- Rayfield 背後TP (Team Check + Auto Switch) + Head Lock Aimbot
-- 2026年時点想定

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Auto Back TP + Head Lock",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "please wait",
    ConfigurationSaving = { Enabled = false }
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local selectedPlayer = nil           -- 手動選択（予備）
local standDistance = 4
local autoBackTPEnabled = false
local headLockEnabled = false
local teamCheck = true               -- デフォルトでTeam Check ON

-- // 敵リスト取得（Team Check対応）
local function getEnemies()
    local enemies = {}
    local myTeam = LocalPlayer.Team

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character.Humanoid
            if hum.Health > 0 then
                -- Team Check
                if not teamCheck or (myTeam == nil or plr.Team ~= myTeam) then
                    table.insert(enemies, plr)
                end
            end
        end
    end
    return enemies
end

-- // 最も近い敵を取得（マウス方向基準 or 距離基準）
local function getClosestEnemy()
    local enemies = getEnemies()
    if #enemies == 0 then return nil end

    local closest = nil
    local shortest = math.huge
    local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)

    for _, plr in ipairs(enemies) do
        local head = plr.Character:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = plr
                end
            end
        end
    end

    -- 誰も画面内にいなければ距離でフォールバック
    if not closest then
        local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart.Position
        if myPos then
            for _, plr in ipairs(enemies) do
                local dist = (myPos - plr.Character.PrimaryPart.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = plr
                end
            end
        end
    end

    return closest
end

-- // UI
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateSection("Back TP Settings")

local ToggleTeamCheck = MainTab:CreateToggle({
    Name = "Team Check (味方は除外)",
    CurrentValue = true,
    Flag = "TeamCheck",
    Callback = function(v)
        teamCheck = v
    end
})

local SliderDist = MainTab:CreateSlider({
    Name = "Stand Distance (studs)",
    Range = {0, 25},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 4,
    Callback = function(v)
        standDistance = v
    end
})

local ToggleBackTP = MainTab:CreateToggle({
    Name = "Enable Auto Back TP (倒したら自動次へ)",
    CurrentValue = false,
    Callback = function(v)
        autoBackTPEnabled = v
        if v then
            Rayfield:Notify({Title = "Back TP", Content = "自動背後追尾開始", Duration = 3})
        else
            Rayfield:Notify({Title = "Back TP", Content = "停止", Duration = 2})
        end
    end
})

MainTab:CreateSection("Head Lock (Aimbot風)")

local ToggleHeadLock = MainTab:CreateToggle({
    Name = "Enable Head Lock",
    CurrentValue = false,
    Callback = function(v)
        headLockEnabled = v
        if v then
            Rayfield:Notify({Title = "Head Lock", Content = "ON - 近い敵の頭をロック", Duration = 3})
        else
            Rayfield:Notify({Title = "Head Lock", Content = "OFF", Duration = 2})
        end
    end
})

-- 予備：手動ターゲット選択（使わなくてもOK）
local Dropdown = MainTab:CreateDropdown({
    Name = "Manual Target (optional)",
    Options = {},
    CurrentOption = {"None"},
    Callback = function(opt)
        if opt[1] ~= "None" then
            selectedPlayer = Players:FindFirstChild(opt[1])
        else
            selectedPlayer = nil
        end
    end
})

-- プレイヤーリスト更新
local function refreshDropdown()
    local names = {"None"}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    Dropdown:Refresh(names, true)
end

refreshDropdown()
Players.PlayerAdded:Connect(refreshDropdown)
Players.PlayerRemoving:Connect(refreshDropdown)

-- // メインループ：背後TP
local currentTarget = nil

RunService.Heartbeat:Connect(function(delta)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        currentTarget = nil
        return
    end

    local myHRP = LocalPlayer.Character.HumanoidRootPart

    -- Head Lock (Aimbot風)
    if headLockEnabled then
        local enemy = getClosestEnemy()
        if enemy and enemy.Character and enemy.Character:FindFirstChild("Head") then
            local headPos = enemy.Character.Head.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, headPos)
        end
    end

    -- Auto Back TP
    if not autoBackTPEnabled then
        currentTarget = nil
        return
    end

    -- 現在のターゲットが死んだor消えたら即リセット
    if currentTarget and (not currentTarget.Character or currentTarget.Character.Humanoid.Health <= 0) then
        currentTarget = nil
    end

    -- ターゲットがいなければ新しく探す
    if not currentTarget then
        currentTarget = getClosestEnemy()
        if not currentTarget then return end
    end

    -- 背後にTP
    local targetHRP = currentTarget.Character.HumanoidRootPart
    local lookVec = targetHRP.CFrame.LookVector
    local backPos = targetHRP.Position - lookVec * standDistance

    myHRP.CFrame = CFrame.new(backPos, targetHRP.Position)   -- 向きはターゲットの方を向く
end)

Rayfield:Notify({
    Title = "Loaded",
    Content = "Auto Back TP (TeamCheck + Auto Switch) & Head Lock 準備完了",
    Duration = 5
})