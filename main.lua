-- // Rayfieldを使った背後TP + 色々なTP系機能 スクリプト
-- // 2025-2026年時点の一般的なRayfield + Luau Exploit想定

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "背後TP & TP Collection",
    LoadingTitle = "Loading TP Features",
    LoadingSubtitle = "please wait...",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "TP_Settings"
    }
})

local MainTab = Window:CreateTab("Main", 4483362458) -- icon id例
local PlayerSection = MainTab:CreateSection("Target & Settings")

-- // 変数
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local selectedPlayer = nil
local standDistance = 5
local tpEnabled = false

-- // プレイヤーリスト取得関数
local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(names, plr.Name)
        end
    end
    return names
end

-- // UI要素
local Dropdown = MainTab:CreateDropdown({
    Name = "Select Target Player",
    Options = getPlayerNames(),
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "SelectedPlayer",
    Callback = function(Option)
        selectedPlayer = Players:FindFirstChild(Option[1])
        if selectedPlayer then
            Rayfield:Notify({
                Title = "Target Selected",
                Content = "現在選択: " .. selectedPlayer.Name,
                Duration = 3
            })
        end
    end
})

local Slider = MainTab:CreateSlider({
    Name = "Stand Distance (0〜25)",
    Range = {0, 25},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "StandDistance",
    Callback = function(Value)
        standDistance = Value
    end
})

local Toggle = MainTab:CreateToggle({
    Name = "Enable Back TP (背後に張り付き)",
    CurrentValue = false,
    Flag = "BackTPToggle",
    Callback = function(Value)
        tpEnabled = Value
        if not Value then
            Rayfield:Notify({Title = "Back TP", Content = "停止しました", Duration = 2})
        end
    end
})

-- // 背後にTPして留まるメインループ
RunService.Heartbeat:Connect(function()
    if not tpEnabled then return end
    if not selectedPlayer then return end
    if not selectedPlayer.Character then return end
    
    local targetHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not targetHRP or not myHRP then return end
    
    -- 対象の後ろ方向を計算
    local lookVector = targetHRP.CFrame.LookVector
    local targetCFrame = targetHRP.CFrame * CFrame.new(0, 0, standDistance) -- 正のZが前なので後ろは+距離
    
    -- 背後にピッタリTP（回転も合わせるパターン）
    myHRP.CFrame = targetCFrame * CFrame.Angles(0, math.rad(180), 0) -- 180度回転で正面を向く
end)


-- // ────────────────────────────────────────────────
-- //          ここから他のTP系機能10個程度
-- // ────────────────────────────────────────────────

local TP_Tab = Window:CreateTab("Extra TP", 7733964710)

-- 1. 対象の頭上にTP
TP_Tab:CreateButton({
    Name = "TP → Target Head (頭上)",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local target = selectedPlayer.Character:FindFirstChild("Head")
        if target and LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.CFrame * CFrame.new(0, 5, 0)
        end
    end
})

-- 2. 対象の真下にTP
TP_Tab:CreateButton({
    Name = "TP → Under Target (真下)",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local target = selectedPlayer.Character.HumanoidRootPart
        if target and LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.CFrame * CFrame.new(0, -8, 0)
        end
    end
})

-- 3. ランダムな近く（±10 studs）にTP
TP_Tab:CreateButton({
    Name = "Random Nearby TP (±10)",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local target = selectedPlayer.Character.HumanoidRootPart
        if target and LocalPlayer.Character then
            local offset = Vector3.new(math.random(-10,10), 0, math.random(-10,10))
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.CFrame + offset
        end
    end
})

-- 4. 対象の左側にTP
TP_Tab:CreateButton({
    Name = "TP → Left Side",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local hrp = selectedPlayer.Character.HumanoidRootPart
        LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(-standDistance, 0, 0)
    end
})

-- 5. 対象の右側にTP
TP_Tab:CreateButton({
    Name = "TP → Right Side",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local hrp = selectedPlayer.Character.HumanoidRootPart
        LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(standDistance, 0, 0)
    end
})

-- 6. 対象と同じ場所に完全重なりTP（なるべく）
TP_Tab:CreateButton({
    Name = "TP → Exact Same Position",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local hrp = selectedPlayer.Character.HumanoidRootPart
        if LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame
        end
    end
})

-- 7. 対象の前（顔の方向）にTP
TP_Tab:CreateButton({
    Name = "TP → Front of Target",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local hrp = selectedPlayer.Character.HumanoidRootPart
        LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, -standDistance)
    end
})

-- 8. 対象を見下ろす位置にTP（高所）
TP_Tab:CreateButton({
    Name = "TP → Look Down on Target",
    Callback = function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local hrp = selectedPlayer.Character.HumanoidRootPart
        LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 15, 8) * CFrame.Angles(math.rad(-30), 0, 0)
    end
})

-- 9. 超高速で背後に何度もTP（スパム用）
local spamBack = false
TP_Tab:CreateToggle({
    Name = "Spam Back TP (高速)",
    CurrentValue = false,
    Callback = function(v)
        spamBack = v
    end
})

RunService.RenderStepped:Connect(function()
    if not spamBack then return end
    if not selectedPlayer or not selectedPlayer.Character then return end
    local target = selectedPlayer.Character.HumanoidRootPart
    local me = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if target and me then
        me.CFrame = target.CFrame * CFrame.new(0, 0, standDistance) * CFrame.Angles(0, math.rad(180), 0)
    end
end)

-- 10. マウス位置にワープ（ClassicなマウスTP）
TP_Tab:CreateButton({
    Name = "Teleport to Mouse (マウス位置)",
    Callback = function()
        local mouse = LocalPlayer:GetMouse()
        if mouse.Target and LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end
})

-- // プレイヤー参加/退出時にドロップダウンを更新（簡易）
Players.PlayerAdded:Connect(function()
    task.wait(1)
    Dropdown:Refresh(getPlayerNames(), true)
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    Dropdown:Refresh(getPlayerNames(), true)
end)

Rayfield:Notify({
    Title = "Loaded!",
    Content = "背後TP & " .. tostring(10) .. "個のTP機能が利用可能です",
    Duration = 4
})
