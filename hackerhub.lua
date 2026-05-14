 -- ============================================================
-- BlobKick スタンドアロン スクリプト
-- ============================================================

local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jadpy/suki/refs/heads/main/orion')))()
local Window = OrionLib:MakeWindow({
    Name = "Hacker Hub v1.5",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "BlobKickConfig",
    IntroText = "Hacker Hub"
})

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local LP = Player

-- ============================================================
-- ESPタブ
-- ============================================================
local ESPTab = Window:MakeTab({
    Name = "プレイヤー",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})


local autoClickEnabled = false
local autoClickConn    = nil
ESPTab:AddToggle({
    Name    = "オートクリック",
    Default = false,
    Callback = function(on)
        autoClickEnabled = on
        if on then
            if autoClickConn then autoClickConn:Disconnect() end
            local VU = game:GetService("VirtualUser")
            autoClickConn = game:GetService("RunService").RenderStepped:Connect(function()
                if autoClickEnabled then
                    for _ = 1, 5 do
                        VU:ClickButton1(Vector2.new())
                    end
                end
            end)
        else
            if autoClickConn then
                autoClickConn:Disconnect()
                autoClickConn = nil
            end
        end
    end
})


-- 共通変数
local espEnabled       = false
local xrayEnabled      = false
local distEnabled      = false
local chamEnabled      = false
local espObjects       = {}
local distLabels       = {}
local chamLines        = {}
local camLockEnabled   = false
local camLockPos       = nil
local camLockConn      = nil
local origMaterials    = {}
local origTransp       = {}
local xrayHighlights   = {}
local xrayMapParts     = {}  -- XRay: マップパーツの元Transparency保存
local distScreenGui    = nil
local distScreenFrame  = nil
local distScrollFrame  = nil
local distScreenLabels = {}

-- XRay（Highlight方式・壁越し表示）
local function applyXray(char, on)
    if not char then return end
    -- プレイヤーを特定
    local targetPlayer = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == char then
            targetPlayer = p
            break
        end
    end
    if on then
        -- 既にHighlightがあれば何もしない
        if targetPlayer and xrayHighlights[targetPlayer] then return end
        local hl = Instance.new("Highlight")
        hl.Name = "XRayHighlight"
        hl.FillColor = Color3.fromRGB(255, 100, 100)
        hl.OutlineColor = Color3.fromRGB(255, 0, 0)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        pcall(function() hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
        hl.Adornee = char
        hl.Parent = char
        if targetPlayer then
            xrayHighlights[targetPlayer] = hl
        end
    else
        -- Highlightを削除
        if targetPlayer and xrayHighlights[targetPlayer] then
            pcall(function() xrayHighlights[targetPlayer]:Destroy() end)
            xrayHighlights[targetPlayer] = nil
        else
            -- フォールバック：キャラクター内のHighlightを直接削除
            local hl = char:FindFirstChild("XRayHighlight")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end
end

-- マップXRay（壁・床・天井を半透明化）
local function applyMapXray(on)
    if on then
        -- workspace内の全BasePart（プレイヤーキャラ以外）を半透明化
        local function processDescendants(obj)
            for _, part in ipairs(obj:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- プレイヤーキャラクターのパーツはスキップ
                    local isPlayerChar = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and part:IsDescendantOf(p.Character) then
                            isPlayerChar = true
                            break
                        end
                    end
                    if not isPlayerChar and part.Transparency < 0.9 then
                        xrayMapParts[part] = part.Transparency
                        part.Transparency = 0.7
                    end
                end
            end
        end
        processDescendants(workspace)
    else
        -- 元のTransparencyに戻す
        for part, origT in pairs(xrayMapParts) do
            pcall(function()
                if part and part.Parent then
                    part.Transparency = origT
                end
            end)
        end
        xrayMapParts = {}
    end
end

-- 画面右側の距離リスト表示（スクロール・ドラッグ対応）
local function createDistScreenGui()
    if distScreenGui then return end
    distScreenGui = Instance.new("ScreenGui")
    distScreenGui.Name = "DistScreenGui"
    distScreenGui.ResetOnSpawn = false
    distScreenGui.DisplayOrder = 100
    distScreenGui.Parent = Player.PlayerGui

    -- 外枠フレーム（ドラッグ可能）
    distScreenFrame = Instance.new("Frame")
    distScreenFrame.Size = UDim2.new(0, 150, 0, 180)
    distScreenFrame.Position = UDim2.new(1, -158, 0.5, -90)
    distScreenFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    distScreenFrame.BackgroundTransparency = 0.4
    distScreenFrame.BorderSizePixel = 0
    distScreenFrame.ClipsDescendants = true
    distScreenFrame.Parent = distScreenGui

    -- タイトルバー（ドラッグ用）
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 20)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = distScreenFrame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 1, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.Text = "プレイヤー距離"
    titleLbl.Parent = titleBar

    -- スクロールフレーム
    distScrollFrame = Instance.new("ScrollingFrame")
    distScrollFrame.Name = "DistScrollFrame"
    distScrollFrame.Size = UDim2.new(1, 0, 1, -20)
    distScrollFrame.Position = UDim2.new(0, 0, 0, 20)
    distScrollFrame.BackgroundTransparency = 1
    distScrollFrame.BorderSizePixel = 0
    distScrollFrame.ScrollBarThickness = 4
    distScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 80, 80)
    distScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    distScrollFrame.Parent = distScreenFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.Parent = distScrollFrame

    -- ドラッグ実装
    local dragging = false
    local dragStartPos = nil
    local frameStartPos = nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = input.Position
            frameStartPos = distScreenFrame.Position
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStartPos
            distScreenFrame.Position = UDim2.new(
                frameStartPos.X.Scale,
                frameStartPos.X.Offset + delta.X,
                frameStartPos.Y.Scale,
                frameStartPos.Y.Offset + delta.Y
            )
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function removeDistScreenGui()
    if distScreenGui then
        distScreenGui:Destroy()
        distScreenGui = nil
        distScreenFrame = nil
        distScrollFrame = nil
        distScreenLabels = {}
    end
end

local function updateDistScreen()
    if not distScreenGui or not distScrollFrame then return end
    local myChar = Player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, lbl in pairs(distScreenLabels) do
        pcall(function() lbl:Destroy() end)
    end
    distScreenLabels = {}
    if not myHRP then return end
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == Player then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
        table.insert(list, { name = p.DisplayName, dist = dist })
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    for i, info in ipairs(list) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = " " .. info.name .. "  " .. info.dist .. "m"
        lbl.LayoutOrder = i
        lbl.Parent = distScrollFrame
        distScreenLabels[i] = lbl
    end
    -- CanvasSize手動更新（AutomaticCanvasSize非対応環境向け）
    pcall(function() distScrollFrame.CanvasSize = UDim2.new(0, 0, 0, #list * 19) end)
end

-- チャムライン（赤い紐）Beam方式（リアルタイム自動追従）
local function createChamLine(player)
    if chamLines[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myChar = Player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- 自分側のAttachment（体の中心）
    local att0 = Instance.new("Attachment")
    att0.Name = "ChamAtt0_" .. player.Name
    att0.CFrame = CFrame.new(0, 0, 0)
    att0.Parent = myHRP

    -- 相手側のAttachment（体の中心）
    local att1 = Instance.new("Attachment")
    att1.Name = "ChamAtt1_" .. player.Name
    att1.CFrame = CFrame.new(0, 0, 0)
    att1.Parent = hrp

    -- Beam（Attachmentが動くと自動でリアルタイム追従）
    local beam = Instance.new("Beam")
    beam.Name = "ChamBeam_" .. player.Name
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    local chamColor = Color3.fromRGB(255, 0, 0)
    beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, chamColor), ColorSequenceKeypoint.new(1, chamColor)})
    beam.Width0 = 0.08
    beam.Width1 = 0.08
    pcall(function() beam.FaceCamera = true end)
    beam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,0)})
    beam.Segments = 1
    beam.Parent = workspace.Terrain

    chamLines[player] = { beam = beam, att0 = att0, att1 = att1 }
end

local function removeChamLine(player)
    if chamLines[player] then
        pcall(function()
            chamLines[player].beam:Destroy()
            chamLines[player].att0:Destroy()
            chamLines[player].att1:Destroy()
        end)
        chamLines[player] = nil
    end
end

-- ESP Billboard
local function createESPBillboard(player)
    if espObjects[player] then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP_Billboard"
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 200, 0, 60)
    bg.StudsOffset = Vector3.new(0, 2.5, 0)
    bg.Parent = head
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 28, 0, 28)
    icon.Position = UDim2.new(0.5, -14, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=48&height=48&format=png"
    icon.Parent = bg
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 28)
    label.Position = UDim2.new(0, 0, 0, 30)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = player.DisplayName .. " (" .. player.Name .. ")"
    label.Parent = bg
    espObjects[player] = bg
end

local function removeESPBillboard(player)
    if espObjects[player] then
        pcall(function() espObjects[player]:Destroy() end)
        espObjects[player] = nil
    end
end

-- 距離ラベル（頭上）
local function createDistLabel(player)
    if distLabels[player] then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "DIST_Billboard"
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 120, 0, 24)
    bg.StudsOffset = Vector3.new(0, 4.5, 0)
    bg.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Text = "0 studs"
    lbl.Parent = bg
    distLabels[player] = { gui = bg, label = lbl }
end

local function removeDistLabel(player)
    if distLabels[player] then
        pcall(function() distLabels[player].gui:Destroy() end)
        distLabels[player] = nil
    end
end

-- Heartbeatで距離更新＋チャムライン更新
RunService.Heartbeat:Connect(function()
    local myChar = Player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, p in ipairs(Players:GetPlayers()) do
        if p == Player then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        -- 頭上距離ラベル更新
        if distEnabled and distLabels[p] and myHRP and hrp then
            local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
            distLabels[p].label.Text = dist .. " studs"
        end
        -- チャムライン: Beam方式は自動追従のため更新不要
    end
    -- 画面上距離リスト更新（0.1秒ごと間引き）
    if distEnabled then
        distScreenTimer = (distScreenTimer or 0) + 1
        if distScreenTimer >= 6 then
            distScreenTimer = 0
            updateDistScreen()
        end
    end
end)

-- プレイヤー追加/削除時の処理
local function onESPCharAdded(player, char)
    char:WaitForChild("Head", 5)
    if espEnabled  then createESPBillboard(player) end
    if distEnabled then createDistLabel(player) end
    -- XRayはマップ壁対象のためキャラ追加時は不要
    if chamEnabled then createChamLine(player) end
end

local function setupESPPlayer(player)
    if player == Player then return end
    if player.Character then
        task.spawn(function() onESPCharAdded(player, player.Character) end)
    end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        onESPCharAdded(player, char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    setupESPPlayer(p)
end
Players.PlayerAdded:Connect(setupESPPlayer)
Players.PlayerRemoving:Connect(function(p)
    removeESPBillboard(p)
    removeDistLabel(p)
    removeChamLine(p)
    if xrayHighlights[p] then
        pcall(function() xrayHighlights[p]:Destroy() end)
        xrayHighlights[p] = nil
    end
end)

-- ESP トグル
ESPTab:AddToggle({
    Name = "ESP（名前・ID・アイコン）",
    Default = false,
    Callback = function(v)
        espEnabled = v
        if v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player then createESPBillboard(p) end
            end
        else
            for p, _ in pairs(espObjects) do removeESPBillboard(p) end
        end
    end
})

-- 距離表示 トグル
ESPTab:AddToggle({
    Name = "距離表示",
    Default = false,
    Callback = function(v)
        distEnabled = v
        if v then
            createDistScreenGui()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player then createDistLabel(p) end
            end
        else
            removeDistScreenGui()
            for p, _ in pairs(distLabels) do removeDistLabel(p) end
        end
    end
})

-- XRay トグル（マップ壁半透明化）
ESPTab:AddToggle({
    Name = "XRay（壁を半透明）",
    Default = false,
    Callback = function(v)
        xrayEnabled = v
        applyMapXray(v)
    end
})

-- チャムライン（赤い紐）トグル
ESPTab:AddToggle({
    Name = "チャムライン（赤い紐）",
    Default = false,
    Callback = function(v)
        chamEnabled = v
        if v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player then createChamLine(p) end
            end
        else
            for p, _ in pairs(chamLines) do removeChamLine(p) end
        end
    end
})

ESPTab:AddToggle({
    Name = "カメラ固定",
    Default = false,
    Callback = function(v)
        camLockEnabled = v
        if v then
            local cam = workspace.CurrentCamera
            camLockPos = cam.CFrame.Position
            camLockConn = RunService.RenderStepped:Connect(function()
                if not camLockEnabled then return end
                local cam2 = workspace.CurrentCamera
                local lookDir = cam2.CFrame.LookVector
                cam2.CameraType = Enum.CameraType.Scriptable
                cam2.CFrame = CFrame.new(camLockPos, camLockPos + lookDir)
            end)
        else
            if camLockConn then
                camLockConn:Disconnect()
                camLockConn = nil
            end
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        end
    end
})




-- ============================================================
-- サーバー移動セクション
-- ============================================================

-- リジョイン（今いるサーバーに入り直す）
ESPTab:AddButton({
    Name = "リジョイン（今のサーバー）",
    Callback = function()
        local TS = game:GetService("TeleportService")
        local placeId = game.PlaceId
        local jobId   = game.JobId
        pcall(function()
            TS:TeleportToPlaceInstance(placeId, jobId, Player)
        end)
    end
})

-- 別サーバーへ（同じゲームのランダムサーバー）
ESPTab:AddButton({
    Name = "別サーバーへ",
    Callback = function()
        local TS = game:GetService("TeleportService")
        local placeId = game.PlaceId
        pcall(function()
            TS:Teleport(placeId, Player)
        end)
    end
})


-- Insaneアニメーション
local _insaneAnim = nil
local _insaneTrack = nil
ESPTab:AddToggle({
    Name = "Insane",
    Default = false,
    Callback = function(val)
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if val then
            _insaneAnim = Instance.new("Animation")
            _insaneAnim.AnimationId = "rbxassetid://33796059"
            _insaneTrack = hum:LoadAnimation(_insaneAnim)
            _insaneTrack:Play(0.1, 1, 1e8)
        else
            if _insaneTrack then
                _insaneTrack:Stop()
                _insaneTrack = nil
            end
            if _insaneAnim then
                _insaneAnim:Destroy()
                _insaneAnim = nil
            end
        end
    end
})


-- ============================================================
-- インプットラグ解除タブ
-- ============================================================
local MiscTab = Window:MakeTab({
    Name = "アイテム",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MiscTab:AddSection({ Name = "アイテム" })

local ToyList = {
    ["ココナッツ"]   = "FoodCoconut",
    ["バナナ"]    = "FoodBanana",
    ["ポテト"]     = "FoodFrenchFries",
    ["肉"] = "FoodMeatStick",
    ["うんこ"]      = "PoopPile",
    ["ドーナツ"]     = "FoodDonut",
    ["ケーキ"]      = "FoodCakePink",
    ["バーガー"]    = "FoodHamburger",
    ["ピザ"]     = "FoodPizzaCheese",
    ["ホットドッグ"]    = "FoodHotdog",
    ["キノコ"]  = "FoodMushroomPoison",
}

local DropdownValues = {}
for shortName, _ in pairs(ToyList) do
    table.insert(DropdownValues, shortName)
end
table.sort(DropdownValues)

local SelectedToy = ToyList[DropdownValues[1]]

MiscTab:AddDropdown({
    Name = "アイテム連打選択",
    Default = DropdownValues[1],
    Options = DropdownValues,
    Callback = function(Value)
        SelectedToy = ToyList[Value]
    end
})

_G.AntiInputLag = false
MiscTab:AddToggle({
    Name = "アイテム連打",
    Default = false,
    Callback = function(Value)
        _G.AntiInputLag = Value
        if Value then
            task.spawn(function()
                local plr  = Players.LocalPlayer
                local char = plr.Character or plr.CharacterAdded:Wait()
                local hrp  = char:WaitForChild("HumanoidRootPart")
                local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                while _G.AntiInputLag do
                    local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if not toysFolder then
                        task.wait(0.1)
                        continue
                    end
                    local toy = toysFolder:FindFirstChild(SelectedToy)
                    if not toy then
                        pcall(function()
                            SpawnRemote:InvokeServer(
                                SelectedToy,
                                hrp.CFrame * CFrame.new(0, 5, 0),
                                Vector3.new(0,0,0)
                            )
                        end)
                        local t0 = tick()
                        repeat
                            RunService.Heartbeat:Wait()
                            toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            toy = toysFolder and toysFolder:FindFirstChild(SelectedToy)
                        until toy or tick() - t0 > 1 or not _G.AntiInputLag
                    end
                    if toy and toy.Parent then
                        local holdPart = toy:FindFirstChild("HoldPart")
                        if holdPart then
                            local holdingPlayer = holdPart:FindFirstChild("HoldingPlayer")
                            holdingPlayer = holdingPlayer and holdingPlayer.Value
                            if holdingPlayer and holdingPlayer ~= plr then
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy,
                                        hrp.CFrame * CFrame.new(0, 2000, 0),
                                        Vector3.new(0,0,0)
                                    )
                                end)
                                toy:Destroy()
                            else
                                pcall(function()
                                    holdPart.HoldItemRemoteFunction:InvokeServer(toy, char)
                                end)
                                task.wait(0.05)
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy,
                                        hrp.CFrame * CFrame.new(0, 2000, 0),
                                        Vector3.new(0,0,0)
                                    )
                                end)
                                task.wait(0.01)
                            end
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end
})

-- ============================================================
-- グラブタブ
-- ============================================================
local GrabTab = Window:MakeTab({
    Name = "グラブ",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

-- Rainbow Lines
local originalColors
if ReplicatedStorage:FindFirstChild("DataEvents") and ReplicatedStorage.DataEvents:FindFirstChild("UpdateLineColorsEvent") then
    originalColors = {}
    for i = 1, 10 do
        table.insert(originalColors, Color3.new(1,1,1))
    end
end

local rainbowToggleState = false
local hueOffset = 0

local function FireRainbowColors()
    if ReplicatedStorage:FindFirstChild("DataEvents") and ReplicatedStorage.DataEvents:FindFirstChild("UpdateLineColorsEvent") then
        local cs = ColorSequence.new{
            ColorSequenceKeypoint.new(0,   Color3.fromHSV((0+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.1, Color3.fromHSV((0.1+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.2, Color3.fromHSV((0.2+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.3, Color3.fromHSV((0.3+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.4, Color3.fromHSV((0.4+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV((0.5+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.6, Color3.fromHSV((0.6+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.7, Color3.fromHSV((0.7+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.8, Color3.fromHSV((0.8+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(0.9, Color3.fromHSV((0.9+hueOffset)%1,1,1)),
            ColorSequenceKeypoint.new(1,   Color3.fromHSV((1+hueOffset)%1,1,1))
        }
        ReplicatedStorage.DataEvents.UpdateLineColorsEvent:FireServer(cs, cs.Keypoints[1].Value, cs.Keypoints[2].Value, cs.Keypoints[3].Value, cs.Keypoints[4].Value, cs.Keypoints[5].Value, cs.Keypoints[6].Value, cs.Keypoints[7].Value, cs.Keypoints[8].Value, cs.Keypoints[9].Value)
    end
end

RunService.Heartbeat:Connect(function()
    if rainbowToggleState then
        hueOffset = (hueOffset + 0.005) % 1
        FireRainbowColors()
    end
end)

local noclipGrabToggle = false
local killGrabEnabled = false
local grabLaunchEnabled = false
local grabLaunchPower = 500
local grabPushEnabled = false
local grabPushPower = 500
local grabForwardEnabled = false
local grabBackEnabled = false
local grabRightEnabled = false
local grabLeftEnabled = false
local grabSidePower = 500

local function GrabParts(model)
    if model.Name ~= "GrabParts" then return end
    
    pcall(function()
        local grabPart = model:WaitForChild("GrabPart", 2)
        if not grabPart then return end
        
        local weld = grabPart:FindFirstChild("WeldConstraint")
        local targetPart = weld and weld.Part1
        if not targetPart then return end

        local targetCharacter = targetPart.Parent

        -- グラブ押し込み（排んでいる間ループ）
        if grabPushEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabPushEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = Vector3.new(0, -grabPushPower, 0)
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- グラブ奥に飛ばす（排んでいる間ループ）
        if grabForwardEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabForwardEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if not myHRP then return end
                        local forwardVec = myHRP.CFrame.LookVector
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = forwardVec * grabSidePower
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- グラブ手前に飛ばす（排んでいる間ループ）
        if grabBackEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabBackEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if not myHRP then return end
                        local backVec = -myHRP.CFrame.LookVector
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = backVec * grabSidePower
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- グラブ右に飛ばす（排んでいる間ループ）
        if grabRightEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabRightEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if not myHRP then return end
                        local rightVec = myHRP.CFrame.RightVector
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = rightVec * grabSidePower
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- グラブ左に飛ばす（排んでいる間ループ）
        if grabLeftEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabLeftEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if not myHRP then return end
                        local leftVec = -myHRP.CFrame.RightVector
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = leftVec * grabSidePower
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- グラブ吹っ飛ばし（排んでいる間ループ）
        if grabLaunchEnabled and not targetPart.Anchored then
            task.spawn(function()
                while grabLaunchEnabled and grabPart.Parent ~= nil do
                    pcall(function()
                        if not targetPart.Parent then return end
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = Vector3.new(0, grabLaunchPower, 0)
                        bv.Parent = targetPart
                    end)
                    task.wait(0.05)
                end

                -- グラブが切れたらBodyVelocityを全て削除
                pcall(function()
                    for _, bv in ipairs(targetPart:GetChildren()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                end)
            end)
        end

        -- キルグラブ（グラブ時にジョイントを破壊してキル）
        if killGrabEnabled then
            task.spawn(function()
                pcall(function()
                    if not targetCharacter or not targetCharacter:IsA("Model") then return end
                    for _, desc in ipairs(targetCharacter:GetDescendants()) do
                        if desc:IsA("Motor6D") then
                            desc.Enabled = false
                        end
                    end
                    targetCharacter:BreakJoints()
                end)
            end)
        end

        if noclipGrabToggle and not targetPart.Anchored then
            task.spawn(function()
                if targetCharacter:IsA("Model") then
                    local allParts = targetCharacter:GetDescendants()
                    local originalCollisionState = {}

                    for _, obj in pairs(allParts) do
                        if obj:IsA("BasePart") then
                            originalCollisionState[obj] = obj.CanCollide
                        end
                    end

                    while noclipGrabToggle and grabPart.Parent do
                        for _, obj in pairs(allParts) do
                            if obj:IsA("BasePart") then
                                obj.CanCollide = false
                            end
                        end
                        task.wait(0.2)
                    end

                    for _, obj in pairs(allParts) do
                        if obj and obj:IsA("BasePart") and originalCollisionState[obj] ~= nil then
                            obj.CanCollide = originalCollisionState[obj]
                        end
                    end
                end
            end)
        end
    end)
end
GrabTab:AddToggle({
    Name = "キルグラブ",
    Default = false,
    Callback = function(v)
        killGrabEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "貫通グラブ",
    Default = false,
    Callback = function(v)
        noclipGrabToggle = v
    end
})

GrabTab:AddToggle({
    Name = "上グラブ",
    Default = false,
    Callback = function(v)
        grabLaunchEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "下グラブ",
    Default = false,
    Callback = function(v)
        grabPushEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "奥グラブ",
    Default = false,
    Callback = function(v)
        grabForwardEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "手前グラブ",
    Default = false,
    Callback = function(v)
        grabBackEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "右グラブ",
    Default = false,
    Callback = function(v)
        grabRightEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "左グラブ",
    Default = false,
    Callback = function(v)
        grabLeftEnabled = v
    end
})

GrabTab:AddToggle({
    Name = "レインボーライン",
    Default = false,
    Callback = function(Value)
        rainbowToggleState = Value
        if not Value and originalColors then
            ReplicatedStorage.DataEvents.UpdateLineColorsEvent:FireServer(originalColors[1],originalColors[2],originalColors[3],originalColors[4],originalColors[5],originalColors[6],originalColors[7],originalColors[8],originalColors[9],originalColors[10])
        end
    end

})

Workspace.ChildAdded:Connect(GrabParts)

-- ============================================================
-- ブロブマンタブ（ブロブキック）
-- ============================================================
local BlobmanTab = Window:MakeTab({
    Name = "ブロブマン",
    Icon = "rbxassetid://7743871002",
    PremiumOnly = false
})

-- キックオーラ用左右切り替え変数
local blobalter = 1
local KickAuraEnabled = false
local KICK_AURA_RANGE = 35

local function getMyBlobman()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "CreatureBlobman" and v:FindFirstChild("VehicleSeat") then
            local seat = v.VehicleSeat
            local seatWeld = seat:FindFirstChild("SeatWeld")
            if seatWeld and seatWeld.Part1 and seatWeld.Part1:IsDescendantOf(Player.Character) then
                return v
            end
        end
    end
    return nil
end

local function grabTargetKick(targetPlayer)
    local blobman = getMyBlobman()
    if not blobman or not targetPlayer.Character then return nil, nil end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return nil, nil end
    local grabPartName = (blobalter == 1) and "LeftDetector" or "RightDetector"
    local weldPartName = (blobalter == 1) and "LeftWeld" or "RightWeld"
    local grabPart = blobman:FindFirstChild(grabPartName)
    local weldPart = grabPart and (grabPart:FindFirstChild(weldPartName) or grabPart:FindFirstChildWhichIsA("Weld"))
    blobalter = (blobalter == 1) and 2 or 1
    local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local grabEvent = scriptObj and scriptObj:FindFirstChild("CreatureGrab") or blobman:FindFirstChild("CreatureGrab", true)
    if grabEvent then
        grabEvent:FireServer(grabPart, targetHRP, weldPart)
    end
    return grabPart, weldPart
end

-- キックオーラループ
task.spawn(function()
    while true do
        if KickAuraEnabled then
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr == Player or not plr.Character then continue end
                    local targetHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    if targetHRP and (targetHRP.Position - hrp.Position).Magnitude <= KICK_AURA_RANGE then
                        grabTargetKick(plr)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

BlobmanTab:AddSection({
    Name = "ブロブマン"
})

local selectedKickPlayer = nil

local function getPlayerList()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            table.insert(list, plr.DisplayName .. " (" .. plr.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromSelection(selection)
    if not selection then return nil end
    local username = selection:match("%((.-)%)")
    if username then
        return Players:FindFirstChild(username)
    end
    return nil
end

local kickLoopEnabled = false
local kickLoopID = 0  -- ループのID、古いループを自動終了させるため
local KickToggleRef = nil
local kick2LoopEnabled = false
local kick2LoopID = 0
local Kick2ToggleRef = nil

local PlayerDropdown = BlobmanTab:AddDropdown({
    Name = "プレイヤー選択",
    Default = "",
    Options = getPlayerList(),
    Callback = function(Value)
        selectedKickPlayer = getPlayerFromSelection(Value)
    end
})

-- プレイヤー参加/退出時に自動更新
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    PlayerDropdown:Refresh(getPlayerList(), true)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    PlayerDropdown:Refresh(getPlayerList(), true)
end)


KickToggleRef = BlobmanTab:AddToggle({
    Name = "ブロブキック",
    Default = false,
    Callback = function(on)
        kickLoopEnabled = on
        kickLoopID = kickLoopID + 1

        if on and not selectedKickPlayer then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Select target first",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            kickLoopEnabled = false
            -- 残ったブロブマンを全て削除
            task.spawn(function()
                task.wait(0.1)
                local DT = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                if DT then
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj.Name == "CreatureBlobman" then
                            pcall(function() DT:FireServer(obj) end)
                        end
                    end
                end
            end)
            return
        end

        if not on then
            kickLoopEnabled = false
            -- 残ったブロブマンを全て削除
            task.spawn(function()
                task.wait(0.1)
                local DT = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                if DT then
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj.Name == "CreatureBlobman" then
                            pcall(function() DT:FireServer(obj) end)
                        end
                    end
                end
            end)
            return
        end

        local target = selectedKickPlayer
        local myLoopID = kickLoopID

        task.spawn(function()
            local GE = ReplicatedStorage:WaitForChild("GrabEvents")
            local MenuToys     = ReplicatedStorage:WaitForChild("MenuToys")
            local SpawnRemoteC = MenuToys:WaitForChild("SpawnToyRemoteFunction")
            local DestroyToyC  = MenuToys:FindFirstChild("DestroyToy")

            -- ===== ブロブマン 自動スポーン & 着席 =====
            local char = Player.Character or Player.CharacterAdded:Wait()
            local hum  = char:WaitForChild("Humanoid")
            local hrp  = char:WaitForChild("HumanoidRootPart")

            -- CharacterAddedで即座にリスポーン検知
            local respawnPending = false
            local respawnConn = Player.CharacterAdded:Connect(function(newChar)
                if not kickLoopEnabled then return end
                respawnPending = true
                char = newChar
            end)

            -- 既に自分のブロブマンに乗っていない場合は自動スポーンして乗る
            local seat = hum.SeatPart
            local myToysFolder0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            local alreadyOnMyBlob = seat
                and seat.Parent
                and seat.Parent.Name == "CreatureBlobman"
                and myToysFolder0
                and seat.Parent.Parent == myToysFolder0
            if not alreadyOnMyBlob then
                -- 既存のブロブマンを全部削除してからスポーン
                local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                local DestroyToy  = ReplicatedStorage:WaitForChild("MenuToys"):FindFirstChild("DestroyToy")
                local toysF0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if toysF0 then
                    for _, b in ipairs(toysF0:GetChildren()) do
                        if b.Name == "CreatureBlobman" then
                            if DestroyToy then pcall(function() DestroyToy:FireServer(b) end) end
                            pcall(function() b:Destroy() end)
                        end
                    end
                end
                -- スポーン直前にプレイヤーの足元にテレポしてからスポーン
                pcall(function()
                    SpawnRemote:InvokeServer(
                        "CreatureBlobman",
                        CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                        Vector3.new(0, 0, 0)
                    )
                end)

                -- ブロブマンがスポーンされるまでHeartbeatベースで待機（最大3秒）
                local toysFolder
                local blob
                local t0 = tick()
                repeat
                    RunService.Heartbeat:Wait()
                    toysFolder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    blob = toysFolder and toysFolder:FindFirstChild("CreatureBlobman")
                until blob or tick() - t0 > 3 or not kickLoopEnabled

                if not kickLoopEnabled then return end
                if not blob then
                    OrionLib:MakeNotification({ Name = "Error", Content = "Blobman spawn failed", Time = 3 })
                    kickLoopEnabled = false
                    return
                end

                -- VehicleSeatに即座に着席
                local vehicleSeat = blob:FindFirstChild("VehicleSeat")
                if vehicleSeat and vehicleSeat:IsA("VehicleSeat") then
                    hrp.CFrame = vehicleSeat.CFrame + Vector3.new(0, 1, 0)
                    vehicleSeat:Sit(hum)
                end

                -- 着席確認（Heartbeatベース、最备2秒）
                seat = hum.SeatPart
                if not (seat and seat.Parent and seat.Parent.Name == "CreatureBlobman") then
                    local t1 = tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        seat = hum.SeatPart
                    until (seat and seat.Parent and seat.Parent.Name == "CreatureBlobman") or tick() - t1 > 2 or not kickLoopEnabled
                end

                if not kickLoopEnabled then return end
                if not (seat and seat.Parent and seat.Parent.Name == "CreatureBlobman") then
                    OrionLib:MakeNotification({ Name = "Error", Content = "Could not sit on Blobman", Time = 3 })
                    kickLoopEnabled = false
                    return
                end
            end

            if not kickLoopEnabled then return end

            -- ===== ブロブマン・各変数をヘルパー関数で取得 =====
            local function getMyBlob()
                local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                return tf and tf:FindFirstChild("CreatureBlobman")
            end

            local function spawnAndSitBlob(humRef, hrpRef)
                -- 最刧3回リトライ
                for attempt = 1, 3 do
                    if not kickLoopEnabled then return nil end
                    -- 既存ブロブマンを削除
                    local tf0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if tf0 then
                        for _, b in ipairs(tf0:GetChildren()) do
                            if b.Name == "CreatureBlobman" then
                                if DestroyToyC then pcall(function() DestroyToyC:FireServer(b) end) end
                                pcall(function() b:Destroy() end)
                            end
                        end
                    end
                    if not kickLoopEnabled then return nil end
                    -- プレイヤーの足底にスポーン
                    pcall(function()
                        SpawnRemoteC:InvokeServer(
                            "CreatureBlobman",
                            CFrame.new(hrpRef.Position + Vector3.new(0, 1, 0)),
                            Vector3.new(0, 0, 0)
                        )
                    end)
                    -- ブロブマンがスポーンされるまで待機（最大3秒）
                    local newBlob, t0 = nil, tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        newBlob = getMyBlob()
                    until newBlob or tick() - t0 > 3 or not kickLoopEnabled
                    if not kickLoopEnabled then return nil end
                    if newBlob then
                        local vs = newBlob:FindFirstChild("VehicleSeat")
                        if vs and vs:IsA("VehicleSeat") then
                            hrpRef.CFrame = vs.CFrame + Vector3.new(0, 1, 0)
                            vs:Sit(humRef)
                            -- 着席確認（最大2秒、複数回試行）
                            local st = tick()
                            repeat
                                RunService.Heartbeat:Wait()
                                if not (humRef.SeatPart and humRef.SeatPart.Parent and humRef.SeatPart.Parent.Name == "CreatureBlobman") then
                                    hrpRef.CFrame = vs.CFrame + Vector3.new(0, 1, 0)
                                    vs:Sit(humRef)
                                end
                            until (humRef.SeatPart and humRef.SeatPart.Parent and humRef.SeatPart.Parent.Name == "CreatureBlobman") or tick() - st > 2 or not kickLoopEnabled
                        end
                        if not kickLoopEnabled then return nil end
                        local s = humRef.SeatPart
                        if s and s.Parent and s.Parent.Name == "CreatureBlobman" then
                            return s.Parent
                        end
                    end
                end
                return nil
            end

            local blob      = seat.Parent
            local blobRoot  = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG        = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
            local CD        = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
            local R_Det     = blob:FindFirstChild("RightDetector")
            local R_Weld    = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
            local SavedPos  = blobRoot.CFrame

            local function refreshBlobRefs()
                local so = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                CG     = so and so:FindFirstChild("CreatureGrab")
                CD     = so and so:FindFirstChild("CreatureDrop")
                R_Det  = blob:FindFirstChild("RightDetector")
                R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
                SavedPos = blobRoot.CFrame
            end

            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

            -- 初回ブリング
            if tRoot and blobRoot then
                local bringStart = tick()
                while tick() - bringStart < 0.2 do
                    if not kickLoopEnabled then break end
                    blobRoot.CFrame   = tRoot.CFrame
                    blobRoot.Velocity = Vector3.new(0,0,0)
                    pcall(function()
                        if CG and R_Det then CG:FireServer(R_Det, tRoot, R_Weld) end
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.new(0,0,0), tRoot.Position, false)
                        GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                    end)
                    RunService.Heartbeat:Wait()
                end
                blobRoot.CFrame   = SavedPos
                blobRoot.Velocity = Vector3.new(0,0,0)
                task.wait(0.05)
            end

            while kickLoopEnabled and myLoopID == kickLoopID do
                -- ターゲットが抜けたら終了
                if not target or not target.Parent then
                    kickLoopEnabled = false
                    if KickToggleRef then KickToggleRef:Set(false) end
                    break
                end

                -- CharacterAddedイベントで検知したリスポーンを処理
                local justRespawned = false
                if respawnPending then
                    respawnPending = false
                    justRespawned = true
                    -- 新キャラクターが完全にロードされるまで待機
                    local newChar = char
                    local humWait = tick()
                    repeat RunService.Heartbeat:Wait()
                    until newChar:FindFirstChild("Humanoid") and newChar:FindFirstChild("HumanoidRootPart") or tick() - humWait > 5 or not kickLoopEnabled
                    if not kickLoopEnabled then break end
                    hum = newChar:WaitForChild("Humanoid")
                    hrp = newChar:WaitForChild("HumanoidRootPart")
                    task.wait(1.5)
                    if not kickLoopEnabled then break end
                    -- 起動時と全く同じコードでスポーン→着席
                    local rToysF = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if rToysF then
                        for _, b in ipairs(rToysF:GetChildren()) do
                            if b.Name == "CreatureBlobman" then
                                if DestroyToyC then pcall(function() DestroyToyC:FireServer(b) end) end
                                pcall(function() b:Destroy() end)
                            end
                        end
                    end
                    pcall(function()
                        SpawnRemoteC:InvokeServer(
                            "CreatureBlobman",
                            CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                            Vector3.new(0, 0, 0)
                        )
                    end)
                    local rBlob, rT0 = nil, tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        local rTF = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                        rBlob = rTF and rTF:FindFirstChild("CreatureBlobman")
                    until rBlob or tick() - rT0 > 3 or not kickLoopEnabled
                    if not kickLoopEnabled then break end
                    if rBlob then
                        local rVS = rBlob:FindFirstChild("VehicleSeat")
                        if rVS and rVS:IsA("VehicleSeat") then
                            hrp.CFrame = rVS.CFrame + Vector3.new(0, 1, 0)
                            rVS:Sit(hum)
                            local rST = tick()
                            repeat
                                RunService.Heartbeat:Wait()
                                if not (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") then
                                    hrp.CFrame = rVS.CFrame + Vector3.new(0, 1, 0)
                                    rVS:Sit(hum)
                                end
                            until (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") or tick() - rST > 2 or not kickLoopEnabled
                        end
                        if not kickLoopEnabled then break end
                        if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
                            blob = rBlob
                            blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                            refreshBlobRefs()
                        else
                            break
                        end
                    else
                        break
                    end
                end

                if not justRespawned then
                    if not blobRoot or not blobRoot.Parent then
                        -- ブロブマンが消えた場合は新規召喚
                        local newBlob = spawnAndSitBlob(hum, hrp)
                        if not newBlob or not kickLoopEnabled then break end
                        blob     = newBlob
                        blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                        refreshBlobRefs()
                    else
                        -- ブロブマンから降ろされた場合（相手に乗られた場合）は新規召喚
                        local mySeat = hum.SeatPart
                        if not (mySeat and mySeat.Parent and mySeat.Parent.Name == "CreatureBlobman"
                            and mySeat.Parent.Parent == Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")) then
                            local newBlob = spawnAndSitBlob(hum, hrp)
                            if not newBlob or not kickLoopEnabled then break end
                            blob     = newBlob
                            blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                            refreshBlobRefs()
                        end
                    end
                end

                tChar = target.Character
                tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tHum = tChar and tChar:FindFirstChild("Humanoid")

                if tRoot and tHum and tHum.Health > 0 then
                    blobRoot.CFrame   = SavedPos
                    blobRoot.Velocity = Vector3.new(0,0,0)

                    local lockPos     = SavedPos * CFrame.new(0, 40, 0)
                    tRoot.CFrame      = lockPos
                    tRoot.Velocity    = Vector3.new(0,0,0)
                    tRoot.RotVelocity = Vector3.new(0,0,0)

                    pcall(function()
                        tHum.PlatformStand = true
                        tHum.Sit           = true
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        if R_Det then
                            local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                            if weld then CD:FireServer(weld) end
                        end
                        GE.DestroyGrabLine:FireServer(tRoot)
                        if CG and R_Det then CG:FireServer(R_Det, tRoot, R_Weld) end
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.new(0,0,0), tRoot.Position, false)
                    end)
                else
                    -- ターゲットがリスポーン中→再登場したら即座に再グラブ
                    if tChar and not tRoot then
                        -- キャラクターはあるがHRPがまだない→待機
                        if blobRoot and blobRoot.Parent then
                            blobRoot.CFrame   = SavedPos
                            blobRoot.Velocity = Vector3.new(0,0,0)
                        end
                    elseif not tChar then
                        -- キャラクター自体がない→待機
                        if blobRoot and blobRoot.Parent then
                            blobRoot.CFrame   = SavedPos
                            blobRoot.Velocity = Vector3.new(0,0,0)
                        end
                    end
                end

                task.wait(0.05)
            end

            respawnConn:Disconnect()
            -- ターゲットのWalkSpeed/JumpPowerを元に戻す
            pcall(function()
                local tCharFin = target and target.Character
                local tHumFin  = tCharFin and tCharFin:FindFirstChild("Humanoid")
                if tHumFin then
                    tHumFin.PlatformStand = false
                    tHumFin.Sit           = false
                    tHumFin.WalkSpeed     = 16
                    tHumFin.JumpPower     = 50
                    tHumFin.JumpHeight    = 7.2
                end
            end)
            if not kickLoopEnabled then
                if blobRoot and blobRoot.Parent then
                    blobRoot.CFrame   = SavedPos
                    blobRoot.Velocity = Vector3.new(0,0,0)
                end
            end
        end)
    end
})

Kick2ToggleRef = BlobmanTab:AddToggle({
    Name = "ブロブキックv2",
    Default = false,
    Callback = function(on)
        kick2LoopEnabled = on
        kick2LoopID = kick2LoopID + 1
        if on and not selectedKickPlayer then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Select target first",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            kick2LoopEnabled = false
            return
        end
        if not on then
            kick2LoopEnabled = false
            -- 残ったブロブマンを全て削除
            task.spawn(function()
                task.wait(0.1)
                local DestroyToyOff2 = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                if DestroyToyOff2 then
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj.Name == "CreatureBlobman" then
                            pcall(function() DestroyToyOff2:FireServer(obj) end)
                        end
                    end
                end
            end)
            return
        end
        local target = selectedKickPlayer
        local myLoopID2 = kick2LoopID
        task.spawn(function()
            local GE2 = ReplicatedStorage:WaitForChild("GrabEvents")
            local MenuToys2    = ReplicatedStorage:WaitForChild("MenuToys")
            local SpawnRemoteC2 = MenuToys2:WaitForChild("SpawnToyRemoteFunction")
            local DestroyToyC2  = MenuToys2:FindFirstChild("DestroyToy")
            local char = Player.Character or Player.CharacterAdded:Wait()
            local hum  = char:WaitForChild("Humanoid")
            local hrp  = char:WaitForChild("HumanoidRootPart")

            -- CharacterAddedで即座にリスポーン検知
            local respawnPending2 = false
            local respawnConn2 = Player.CharacterAdded:Connect(function(newChar2)
                if not kick2LoopEnabled then return end
                respawnPending2 = true
                char = newChar2
            end)

            local function getMyBlob2()
                local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                return tf and tf:FindFirstChild("CreatureBlobman")
            end

            -- ===== spawnAndSitBlob2（v2用） =====
            local function spawnAndSitBlob2(humRef2, hrpRef2)
                local SpawnR2 = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                local DestroyR2 = ReplicatedStorage:WaitForChild("MenuToys"):FindFirstChild("DestroyToy")
                for attempt2 = 1, 3 do
                    if not kick2LoopEnabled then return nil end
                    local tf0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if tf0 then
                        for _, b in ipairs(tf0:GetChildren()) do
                            if b.Name == "CreatureBlobman" then
                                if DestroyR2 then pcall(function() DestroyR2:FireServer(b) end) end
                                pcall(function() b:Destroy() end)
                            end
                        end
                    end
                    if not kick2LoopEnabled then return nil end
                    pcall(function()
                        SpawnR2:InvokeServer(
                            "CreatureBlobman",
                            CFrame.new(hrpRef2.Position + Vector3.new(0, 1, 0)),
                            Vector3.new(0, 0, 0)
                        )
                    end)
                    local nb2, t0b = nil, tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        nb2 = getMyBlob2()
                    until nb2 or tick() - t0b > 3 or not kick2LoopEnabled
                    if not kick2LoopEnabled then return nil end
                    if nb2 then
                        local vs2 = nb2:FindFirstChild("VehicleSeat")
                        if vs2 and vs2:IsA("VehicleSeat") then
                            hrpRef2.CFrame = vs2.CFrame + Vector3.new(0, 1, 0)
                            vs2:Sit(humRef2)
                            local st2 = tick()
                            repeat
                                RunService.Heartbeat:Wait()
                                if not (humRef2.SeatPart and humRef2.SeatPart.Parent and humRef2.SeatPart.Parent.Name == "CreatureBlobman") then
                                    hrpRef2.CFrame = vs2.CFrame + Vector3.new(0, 1, 0)
                                    vs2:Sit(humRef2)
                                end
                            until (humRef2.SeatPart and humRef2.SeatPart.Parent and humRef2.SeatPart.Parent.Name == "CreatureBlobman") or tick() - st2 > 2 or not kick2LoopEnabled
                        end
                        if not kick2LoopEnabled then return nil end
                        local s2 = humRef2.SeatPart
                        if s2 and s2.Parent and s2.Parent.Name == "CreatureBlobman" then
                            return s2.Parent
                        end
                    end
                end
                return nil
            end

            -- ブロブマンに乗っていなければ自動スポーン
            local seat2 = hum.SeatPart
            local myToysFolder0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            local alreadyOnMyBlob2 = seat2
                and seat2.Parent
                and seat2.Parent.Name == "CreatureBlobman"
                and myToysFolder0
                and seat2.Parent.Parent == myToysFolder0
            if not alreadyOnMyBlob2 then
                -- 既存ブロブマンを削除してスポーン
                local toysF0 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if toysF0 then
                    for _, b in ipairs(toysF0:GetChildren()) do
                        if b.Name == "CreatureBlobman" then
                            if DestroyToyC2 then pcall(function() DestroyToyC2:FireServer(b) end) end
                            pcall(function() b:Destroy() end)
                        end
                    end
                end
                pcall(function()
                    SpawnRemoteC2:InvokeServer(
                        "CreatureBlobman",
                        CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                        Vector3.new(0, 0, 0)
                    )
                end)
                local t0b = tick()
                repeat
                    RunService.Heartbeat:Wait()
                until getMyBlob2() or tick() - t0b > 3 or not kick2LoopEnabled
                if not kick2LoopEnabled then return end
                if not getMyBlob2() then
                    OrionLib:MakeNotification({ Name = "Error", Content = "Blobman spawn failed", Time = 3 })
                    kick2LoopEnabled = false
                    return
                end
                local vSeat2 = getMyBlob2():FindFirstChild("VehicleSeat")
                if vSeat2 and vSeat2:IsA("VehicleSeat") then
                    hrp.CFrame = vSeat2.CFrame + Vector3.new(0, 1, 0)
                    vSeat2:Sit(hum)
                end
                local t1b = tick()
                repeat
                    RunService.Heartbeat:Wait()
                    seat2 = hum.SeatPart
                until (seat2 and seat2.Parent and seat2.Parent.Name == "CreatureBlobman") or tick() - t1b > 2 or not kick2LoopEnabled
                if not kick2LoopEnabled then return end
                if not (seat2 and seat2.Parent and seat2.Parent.Name == "CreatureBlobman") then
                    OrionLib:MakeNotification({ Name = "Error", Content = "Could not sit on Blobman", Time = 3 })
                    kick2LoopEnabled = false
                    return
                end
            end

            -- ブロブマン取得
            local blob2 = getMyBlob2()
            if not blob2 then
                OrionLib:MakeNotification({ Name = "Error", Content = "Blobman not found", Time = 3 })
                kick2LoopEnabled = false
                return
            end
            local blobRoot2 = blob2:FindFirstChild("HumanoidRootPart") or blob2.PrimaryPart
            local so2 = blob2:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG2 = so2 and so2:FindFirstChild("CreatureGrab")
            local R_Det2 = blob2:FindFirstChild("RightDetector")
            local R_Weld2 = R_Det2 and (R_Det2:FindFirstChild("RightWeld") or R_Det2:FindFirstChildWhichIsA("Weld"))
            local SavedPos2 = blobRoot2.CFrame

            local function refreshBlobRefs2()
                local so = blob2:FindFirstChild("BlobmanSeatAndOwnerScript")
                CG2     = so and so:FindFirstChild("CreatureGrab")
                R_Det2  = blob2:FindFirstChild("RightDetector")
                R_Weld2 = R_Det2 and (R_Det2:FindFirstChild("RightWeld") or R_Det2:FindFirstChildWhichIsA("Weld"))
                SavedPos2 = blobRoot2.CFrame
            end

            -- 初回ブリング
            local tChar2 = target.Character
            local tRoot2 = tChar2 and tChar2:FindFirstChild("HumanoidRootPart")
            if tRoot2 and blobRoot2 and kick2LoopEnabled then
                local bringStart2 = tick()
                while tick() - bringStart2 < 0.2 do
                    if not kick2LoopEnabled then break end
                    blobRoot2.CFrame   = CFrame.new(tRoot2.Position) * CFrame.Angles(0, 0, 0)
                    blobRoot2.Velocity = Vector3.new(0,0,0)
                    blobRoot2.RotVelocity = Vector3.new(0,0,0)
                    pcall(function()
                        if CG2 and R_Det2 then
                            CG2:FireServer(R_Det2, tRoot2, R_Weld2)
                        end
                        GE2.CreateGrabLine:FireServer(tRoot2, Vector3.new(0,0,0), tRoot2.Position, false)
                        GE2.SetNetworkOwner:FireServer(tRoot2, blobRoot2.CFrame)
                    end)
                    RunService.Heartbeat:Wait()
                end
            end

            -- 摑むループ（リスポ時は再ブリング）
            local lastCharacter = target.Character
            local wasNilChar = false  -- nilになったことを記録
            while kick2LoopEnabled and myLoopID2 == kick2LoopID do
                if not target or not target.Parent then
                    kick2LoopEnabled = false
                    if Kick2ToggleRef then Kick2ToggleRef:Set(false) end
                    break
                end

                -- CharacterAddedイベントで検知したリスポーンを処理
                if respawnPending2 then
                    respawnPending2 = false
                    local newChar2 = char
                    local humWait2 = tick()
                    repeat RunService.Heartbeat:Wait()
                    until newChar2:FindFirstChild("Humanoid") and newChar2:FindFirstChild("HumanoidRootPart") or tick() - humWait2 > 5 or not kick2LoopEnabled
                    if not kick2LoopEnabled then break end
                    hum = newChar2:WaitForChild("Humanoid")
                    hrp = newChar2:WaitForChild("HumanoidRootPart")
                    task.wait(1.5)
                    if not kick2LoopEnabled then break end
                    -- 起動時と全く同じコードでスポーン→着席
                    local rToysF2 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if rToysF2 then
                        for _, b in ipairs(rToysF2:GetChildren()) do
                            if b.Name == "CreatureBlobman" then
                                if DestroyToyC2 then pcall(function() DestroyToyC2:FireServer(b) end) end
                                pcall(function() b:Destroy() end)
                            end
                        end
                    end
                    pcall(function()
                        SpawnRemoteC2:InvokeServer(
                            "CreatureBlobman",
                            CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                            Vector3.new(0, 0, 0)
                        )
                    end)
                    local rBlob2, rT2 = nil, tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        local rTF2 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                        rBlob2 = rTF2 and rTF2:FindFirstChild("CreatureBlobman")
                    until rBlob2 or tick() - rT2 > 3 or not kick2LoopEnabled
                    if not kick2LoopEnabled then break end
                    if rBlob2 then
                        local rVS2 = rBlob2:FindFirstChild("VehicleSeat")
                        if rVS2 and rVS2:IsA("VehicleSeat") then
                            hrp.CFrame = rVS2.CFrame + Vector3.new(0, 1, 0)
                            rVS2:Sit(hum)
                            local rST2 = tick()
                            repeat
                                RunService.Heartbeat:Wait()
                                if not (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") then
                                    hrp.CFrame = rVS2.CFrame + Vector3.new(0, 1, 0)
                                    rVS2:Sit(hum)
                                end
                            until (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") or tick() - rST2 > 2 or not kick2LoopEnabled
                        end
                        if not kick2LoopEnabled then break end
                        if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
                            blob2 = rBlob2
                            blobRoot2 = blob2:FindFirstChild("HumanoidRootPart") or blob2.PrimaryPart
                            local so2r = blob2:FindFirstChild("BlobmanSeatAndOwnerScript")
                            CG2 = so2r and so2r:FindFirstChild("CreatureGrab")
                            R_Det2 = blob2:FindFirstChild("RightDetector")
                            R_Weld2 = R_Det2 and (R_Det2:FindFirstChild("RightWeld") or R_Det2:FindFirstChildWhichIsA("Weld"))
                        else
                            break
                        end
                    else
                        break
                    end
                end

                local tCharNow = target.Character
                local tRootNow = tCharNow and tCharNow:FindFirstChild("HumanoidRootPart")
                -- リスポーン検知：キャラクターが消えた後に再登場したら再ブリング
                if not tCharNow then
                    wasNilChar = true
                elseif tCharNow ~= lastCharacter or wasNilChar then
                    if tRootNow then
                        wasNilChar = false
                        lastCharacter = tCharNow
                        -- ブロブマンに乗り直してから再ブリング
                        local vSeat2 = blob2 and blob2:FindFirstChild("VehicleSeat")
                        if vSeat2 and vSeat2:IsA("VehicleSeat") then
                            hrp.CFrame = vSeat2.CFrame + Vector3.new(0, 1, 0)
                            vSeat2:Sit(hum)
                            local sitWait2 = tick()
                            repeat
                                RunService.Heartbeat:Wait()
                            until (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") or tick() - sitWait2 > 2 or not kick2LoopEnabled
                            if not kick2LoopEnabled then break end
                        end
                        -- 再ブリング
                        local reBringStart = tick()
                        while tick() - reBringStart < 0.2 do
                            if not kick2LoopEnabled then break end
                            blobRoot2.CFrame   = CFrame.new(tRootNow.Position) * CFrame.Angles(0, 0, 0)
                            blobRoot2.Velocity = Vector3.new(0,0,0)
                            blobRoot2.RotVelocity = Vector3.new(0,0,0)
                            pcall(function()
                                if CG2 and R_Det2 then
                                    CG2:FireServer(R_Det2, tRootNow, R_Weld2)
                                end
                                GE2.CreateGrabLine:FireServer(tRootNow, Vector3.new(0,0,0), tRootNow.Position, false)
                                GE2.SetNetworkOwner:FireServer(tRootNow, blobRoot2.CFrame)
                            end)
                            RunService.Heartbeat:Wait()
                        end
                    end
                end
                -- ターゲットがいなければスキップ（待機なし）
                if not tRootNow then
                    RunService.Heartbeat:Wait()
                    continue
                end
                -- ブロブマンから降ろされた場合（相手に乗られた場合）は新しく召喚し直す
                local mySeat2 = hum.SeatPart
                if not (mySeat2 and mySeat2.Parent and mySeat2.Parent.Name == "CreatureBlobman") then
                    local newBlob2 = spawnAndSitBlob2(hum, hrp)
                    if not newBlob2 or not kick2LoopEnabled then break end
                    blob2 = newBlob2
                    blobRoot2 = blob2:FindFirstChild("HumanoidRootPart") or blob2.PrimaryPart
                    refreshBlobRefs2()
                    -- 新しいブロブマンでブリング
                    if tRootNow then
                        local reBringStart2 = tick()
                        while tick() - reBringStart2 < 0.2 do
                            if not kick2LoopEnabled then break end
                            blobRoot2.CFrame   = CFrame.new(tRootNow.Position) * CFrame.Angles(0, 0, 0)
                            blobRoot2.Velocity = Vector3.new(0,0,0)
                            blobRoot2.RotVelocity = Vector3.new(0,0,0)
                            pcall(function()
                                if CG2 and R_Det2 then
                                    CG2:FireServer(R_Det2, tRootNow, R_Weld2)
                                end
                                GE2.CreateGrabLine:FireServer(tRootNow, Vector3.new(0,0,0), tRootNow.Position, false)
                                GE2.SetNetworkOwner:FireServer(tRootNow, blobRoot2.CFrame)
                            end)
                            RunService.Heartbeat:Wait()
                        end
                    end
                end
                -- 离れすぎたらブロブマンごとテレポート
                if blobRoot2 and tRootNow then
                    local dist2 = (blobRoot2.Position - tRootNow.Position).Magnitude
                    if dist2 > 45 then
                        -- ブロブマンをターゲットの少し上にテレポート
                        blobRoot2.CFrame      = CFrame.new(tRootNow.Position + Vector3.new(0, 5, 0))
                        blobRoot2.Velocity    = Vector3.new(0,0,0)
                        blobRoot2.RotVelocity = Vector3.new(0,0,0)
                        -- ターゲットの速度もリセットして安定化
                        pcall(function()
                            tRootNow.Velocity    = Vector3.new(0,0,0)
                            tRootNow.RotVelocity = Vector3.new(0,0,0)
                            GE2.DestroyGrabLine:FireServer(tRootNow)
                            GE2.SetNetworkOwner:FireServer(tRootNow, blobRoot2.CFrame)
                        end)
                        task.wait(0.05)
                    end
                end
                -- 摑む（左右切り替え）
                local grabPartName2 = (blobalter == 1) and "LeftDetector" or "RightDetector"
                local weldPartName2 = (blobalter == 1) and "LeftWeld" or "RightWeld"
                local grabPart2 = blob2:FindFirstChild(grabPartName2)
                local weldPart2 = grabPart2 and (grabPart2:FindFirstChild(weldPartName2) or grabPart2:FindFirstChildWhichIsA("Weld"))
                blobalter = (blobalter == 1) and 2 or 1
                if CG2 and grabPart2 and tRootNow then
                    pcall(function()
                        CG2:FireServer(grabPart2, tRootNow, weldPart2)
                    end)
                end
                task.wait(0.05)
            end
            respawnConn2:Disconnect()
        end)
    end
})

-- ============================================================
-- ブロブマンキックv3（ブロブマンを相手にテレポート→右手グラブループ）
-- ============================================================
local kick3LoopEnabled = false
local kick3LoopID      = 0
local Kick3ToggleRef   = nil

Kick3ToggleRef = BlobmanTab:AddToggle({
    Name    = "ブロブマンキックv3",
    Default = false,
    Callback = function(on)
        kick3LoopEnabled = on
        kick3LoopID      = kick3LoopID + 1
        if on and not selectedKickPlayer then
            OrionLib:MakeNotification({
                Name    = "エラー",
                Content = "プレイヤーを選択してください",
                Time    = 3
            })
            kick3LoopEnabled = false
            if Kick3ToggleRef then Kick3ToggleRef:Set(false) end
            return
        end
        if not on then
            -- 残ったブロブマンを削除
            task.spawn(function()
                task.wait(0.3)
                local DT = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if tf then
                    for _, b in ipairs(tf:GetChildren()) do
                        if b.Name == "CreatureBlobman" then
                            if DT then pcall(function() DT:FireServer(b) end) end
                            pcall(function() b:Destroy() end)
                        end
                    end
                end
            end)
            return
        end
        local target3   = selectedKickPlayer
        local myLoop3   = kick3LoopID
        task.spawn(function()
            local GE3        = ReplicatedStorage:WaitForChild("GrabEvents")
            local MenuToys3  = ReplicatedStorage:WaitForChild("MenuToys")
            local SpawnR3    = MenuToys3:WaitForChild("SpawnToyRemoteFunction")
            local DestroyR3  = MenuToys3:FindFirstChild("DestroyToy")
            local char3 = Player.Character or Player.CharacterAdded:Wait()
            local hum3  = char3:WaitForChild("Humanoid")
            local hrp3  = char3:WaitForChild("HumanoidRootPart")
            -- 既存ブロブマン削除
            local tf3 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            if tf3 then
                for _, b in ipairs(tf3:GetChildren()) do
                    if b.Name == "CreatureBlobman" then
                        if DestroyR3 then pcall(function() DestroyR3:FireServer(b) end) end
                        pcall(function() b:Destroy() end)
                    end
                end
            end
            task.wait(0.2)
            if not kick3LoopEnabled or myLoop3 ~= kick3LoopID then return end
            -- スポーン
            pcall(function()
                SpawnR3:InvokeServer(
                    "CreatureBlobman",
                    CFrame.new(hrp3.Position + Vector3.new(0, 1, 0)),
                    Vector3.new(0, 0, 0)
                )
            end)
            local blob3, t0_3 = nil, tick()
            repeat
                RunService.Heartbeat:Wait()
                local tf3b = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                blob3 = tf3b and tf3b:FindFirstChild("CreatureBlobman")
            until blob3 or tick() - t0_3 > 3 or not kick3LoopEnabled or myLoop3 ~= kick3LoopID
            if not blob3 or not kick3LoopEnabled or myLoop3 ~= kick3LoopID then
                kick3LoopEnabled = false
                if Kick3ToggleRef then Kick3ToggleRef:Set(false) end
                return
            end
            -- 着席
            local vs3 = blob3:FindFirstChild("VehicleSeat")
            if vs3 and vs3:IsA("VehicleSeat") then
                hrp3.CFrame = vs3.CFrame + Vector3.new(0, 1, 0)
                vs3:Sit(hum3)
                local st3 = tick()
                repeat
                    RunService.Heartbeat:Wait()
                    if not (hum3.SeatPart and hum3.SeatPart.Parent and hum3.SeatPart.Parent.Name == "CreatureBlobman") then
                        hrp3.CFrame = vs3.CFrame + Vector3.new(0, 1, 0)
                        vs3:Sit(hum3)
                    end
                until (hum3.SeatPart and hum3.SeatPart.Parent and hum3.SeatPart.Parent.Name == "CreatureBlobman") or tick() - st3 > 2 or not kick3LoopEnabled or myLoop3 ~= kick3LoopID
            end
            if not (hum3.SeatPart and hum3.SeatPart.Parent and hum3.SeatPart.Parent.Name == "CreatureBlobman") then
                kick3LoopEnabled = false
                if Kick3ToggleRef then Kick3ToggleRef:Set(false) end
                return
            end
            if not kick3LoopEnabled or myLoop3 ~= kick3LoopID then return end
            -- ブロブマン参照取得
            local bRoot3 = blob3:FindFirstChild("HumanoidRootPart") or blob3.PrimaryPart
            local so3    = blob3:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG3    = so3 and so3:FindFirstChild("CreatureGrab") or blob3:FindFirstChild("CreatureGrab", true)
            local CD3    = so3 and so3:FindFirstChild("CreatureDrop")
            local RDet3  = blob3:FindFirstChild("RightDetector")
            local RWeld3 = RDet3 and (RDet3:FindFirstChild("RightWeld") or RDet3:FindFirstChildWhichIsA("Weld"))
            -- ===== 1回だけテレポート（着席完了直後） =====
            local tChar3init = target3.Character
            local tRoot3init = tChar3init and tChar3init:FindFirstChild("HumanoidRootPart")
            if tRoot3init and bRoot3 and bRoot3.Parent then
                bRoot3.CFrame   = tRoot3init.CFrame
                bRoot3.Velocity = Vector3.new(0, 0, 0)
            end
            -- ===== メインループ（Heartbeat：右手グラブ連打のみ） =====
            local grabTimer3    = 0
            local GRAB3_INTERVAL = 0.0005
            local hbConn3
            hbConn3 = RunService.Heartbeat:Connect(function(dt)
                if not kick3LoopEnabled or myLoop3 ~= kick3LoopID then
                    hbConn3:Disconnect()
                    return
                end
                if not target3 or not target3.Parent then
                    kick3LoopEnabled = false
                    hbConn3:Disconnect()
                    return
                end
                local tChar3 = target3.Character
                local tRoot3 = tChar3 and tChar3:FindFirstChild("HumanoidRootPart")
                if not tRoot3 then return end
                -- 右手グラブ連打
                grabTimer3 = grabTimer3 + dt
                if grabTimer3 >= GRAB3_INTERVAL then
                    grabTimer3 = 0
                    -- ブロブマン参照を更新（リスポーン後対応）
                    local tf3c = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    local curBlob = tf3c and tf3c:FindFirstChild("CreatureBlobman")
                    if curBlob and curBlob ~= blob3 then
                        blob3  = curBlob
                        bRoot3 = blob3:FindFirstChild("HumanoidRootPart") or blob3.PrimaryPart
                        local so3b = blob3:FindFirstChild("BlobmanSeatAndOwnerScript")
                        CG3    = so3b and so3b:FindFirstChild("CreatureGrab") or blob3:FindFirstChild("CreatureGrab", true)
                        CD3    = so3b and so3b:FindFirstChild("CreatureDrop")
                        RDet3  = blob3:FindFirstChild("RightDetector")
                        RWeld3 = RDet3 and (RDet3:FindFirstChild("RightWeld") or RDet3:FindFirstChildWhichIsA("Weld"))
                    end
                    pcall(function()
                        if CD3 and RWeld3 then CD3:FireServer(RWeld3) end
                        GE3.DestroyGrabLine:FireServer(tRoot3)
                        if CG3 and RDet3 then CG3:FireServer(RDet3, tRoot3, RWeld3) end
                        GE3.CreateGrabLine:FireServer(tRoot3, Vector3.new(0,0,0), tRoot3.Position, false)
                    end)
                end
            end)
            -- 終了待機
            while kick3LoopEnabled and myLoop3 == kick3LoopID do
                task.wait(0.1)
            end
            if hbConn3 then hbConn3:Disconnect() end
        end)
    end
})

-- ドリフトキック
local driftSpeed = 0.5  -- 1周にかかる秒数（小さいほど速い）
-- ===================================================================
local driftKickEnabled = false
local driftKickLoopID  = 0
local DriftKickToggleRef = nil

DriftKickToggleRef = BlobmanTab:AddToggle({
    Name = "ドリフトキック",
    Default = false,
    Callback = function(on)
        driftKickEnabled = on
        driftKickLoopID  = driftKickLoopID + 1
        if on and not selectedKickPlayer then
            OrionLib:MakeNotification({
                Name = "エラー",
                Content = "プレイヤーを選択してください",
                Time = 3
            })
            driftKickEnabled = false
            if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
            return
        end
        if not on then
            -- 残ったブロブマンを全て削除
            task.spawn(function()
                task.wait(0.3)
                local DT = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if tf then
                    for _, b in ipairs(tf:GetChildren()) do
                        if b.Name == "CreatureBlobman" then
                            if DT then pcall(function() DT:FireServer(b) end) end
                            pcall(function() b:Destroy() end)
                        end
                    end
                end
            end)
            return
        end

        local target      = selectedKickPlayer
        local myLoopID    = driftKickLoopID

        task.spawn(function()
            -- リモート取得
            local GED        = ReplicatedStorage:WaitForChild("GrabEvents")
            local MenuToysD  = ReplicatedStorage:WaitForChild("MenuToys")
            local SpawnRD    = MenuToysD:WaitForChild("SpawnToyRemoteFunction")
            local DestroyRD  = MenuToysD:FindFirstChild("DestroyToy")

            local char = Player.Character or Player.CharacterAdded:Wait()
            local hum  = char:WaitForChild("Humanoid")
            local hrp  = char:WaitForChild("HumanoidRootPart")

            -- ===== ブロブマン スポーン & 着席 =====
            local function getMyBlobD()
                local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                return tf and tf:FindFirstChild("CreatureBlobman")
            end

            -- 既存ブロブマン削除
            local toysF = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            if toysF then
                for _, b in ipairs(toysF:GetChildren()) do
                    if b.Name == "CreatureBlobman" then
                        if DestroyRD then pcall(function() DestroyRD:FireServer(b) end) end
                        pcall(function() b:Destroy() end)
                    end
                end
            end

            task.wait(0.2)  -- 削除完了を待つ
            if not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
            -- スポーン
            pcall(function()
                SpawnRD:InvokeServer(
                    "CreatureBlobman",
                    CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                    Vector3.new(0, 0, 0)
                )
            end)
            local blobD, t0D = nil, tick()
            repeat
                RunService.Heartbeat:Wait()
                blobD = getMyBlobD()
            until blobD or tick() - t0D > 3 or not driftKickEnabled or myLoopID ~= driftKickLoopID

            if not blobD or not driftKickEnabled or myLoopID ~= driftKickLoopID then
                driftKickEnabled = false
                if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
                return
            end

            -- 着席
            local vsD = blobD:FindFirstChild("VehicleSeat")
            if vsD and vsD:IsA("VehicleSeat") then
                hrp.CFrame = vsD.CFrame + Vector3.new(0, 1, 0)
                vsD:Sit(hum)
                local stD = tick()
                repeat
                    RunService.Heartbeat:Wait()
                    if not (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") then
                        hrp.CFrame = vsD.CFrame + Vector3.new(0, 1, 0)
                        vsD:Sit(hum)
                    end
                until (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") or tick() - stD > 2 or not driftKickEnabled or myLoopID ~= driftKickLoopID
            end

            if not (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") then
                driftKickEnabled = false
                if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
                return
            end

            local blobRootD = blobD:FindFirstChild("HumanoidRootPart") or blobD.PrimaryPart
            if not blobRootD then
                driftKickEnabled = false
                if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
                return
            end

            -- ブロブマンの初期位置を保存（v1のSavedPosと同じ）
            local SavedPosD = blobRootD.CFrame

            -- CG取得
            local soD = blobD:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CGD = soD and soD:FindFirstChild("CreatureGrab") or blobD:FindFirstChild("CreatureGrab", true)

            -- ===== ドリフトキック本体 =====
            -- 動き：ブロブマンを相手にテレポート→相手を空中固定→自分が相手の周りを円運動グラブ
            local RADIUS   = 20     -- 円の半径（studs）
            local SPEED    = driftSpeed  -- スライダーで調整可能
            local LOCK_Y   = 40     -- 空中固定の高さオフセット（studs）
            local driftAlt = 1      -- 左右グラブ切り替え
            local angle    = 0      -- 現在の角度（ラジアン）
            local kickDone = false

            -- ターゲットの初期位置を取得
            local tCharInit = target.Character
            local tRootInit = tCharInit and tCharInit:FindFirstChild("HumanoidRootPart")
            if not tRootInit then
                driftKickEnabled = false
                if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
                return
            end

            -- CDリモート取得（DropWeld用）
            local soD2 = blobD:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CDD  = soD2 and soD2:FindFirstChild("CreatureDrop")

            -- ===== 初回ブリング（v1と同じ：ブロブマンを相手にテレポート） =====
            local bringStart = tick()
            while tick() - bringStart < 0.2 and driftKickEnabled and myLoopID == driftKickLoopID do
                blobRootD.CFrame   = tRootInit.CFrame
                blobRootD.Velocity = Vector3.new(0,0,0)
                blobRootD.RotVelocity = Vector3.new(0,0,0)
                pcall(function()
                    if CGD then
                        local gpN = (driftAlt == 1) and "LeftDetector" or "RightDetector"
                        local wpN = (driftAlt == 1) and "LeftWeld" or "RightWeld"
                        local gp = blobD:FindFirstChild(gpN)
                        local wp = gp and (gp:FindFirstChild(wpN) or gp:FindFirstChildWhichIsA("Weld"))
                        CGD:FireServer(gp, tRootInit, wp)
                    end
                    GED.CreateGrabLine:FireServer(tRootInit, Vector3.new(0,0,0), tRootInit.Position, false)
                    GED.SetNetworkOwner:FireServer(tRootInit, blobRootD.CFrame)
                end)
                RunService.Heartbeat:Wait()
            end
            if not driftKickEnabled or myLoopID ~= driftKickLoopID then
                driftKickEnabled = false
                if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
                return
            end

            -- ブロブマンをSavedPosに戻す（v1と同じ）
            blobRootD.CFrame   = SavedPosD
            blobRootD.Velocity = Vector3.new(0,0,0)
            task.wait(0.05)

            -- 空中固定位置（SavedPosの真上40studs、v1と同じ）
            local lockPosD = SavedPosD * CFrame.new(0, LOCK_Y, 0)

            -- GrabParts生成を監視してキック判定
            local grabConn = workspace.ChildAdded:Connect(function(child)
                if not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
                if child.Name == "GrabParts" then
                    kickDone = true
                    task.spawn(function()
                        task.wait(0.05)
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("Motor6D") then desc.Enabled = false end
                        end
                        task.wait(0.05)
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("BasePart") then
                                pcall(function() desc:BreakJoints() end)
                            end
                        end
                    end)
                end
            end)

            -- ===== ターゲットリスポーン検知 =====
            local targetRespawnConn = target.CharacterAdded:Connect(function(newChar)
                if not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
                -- リスポーン検知：ブロブマンを再スポーン・着席してドリフト継続
                task.spawn(function()
                    task.wait(0.5)  -- リスポーン完了を少し待つ
                    if not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
                    -- 既存ブロブマン削除
                    local tf2 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if tf2 then
                        for _, b in ipairs(tf2:GetChildren()) do
                            if b.Name == "CreatureBlobman" then
                                if DestroyRD then pcall(function() DestroyRD:FireServer(b) end) end
                                pcall(function() b:Destroy() end)
                            end
                        end
                    end
                    task.wait(0.2)
                    if not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
                    -- 再スポーン
                    pcall(function()
                        SpawnRD:InvokeServer(
                            "CreatureBlobman",
                            CFrame.new(hrp.Position + Vector3.new(0, 1, 0)),
                            Vector3.new(0, 0, 0)
                        )
                    end)
                    local newBlob, t0r = nil, tick()
                    repeat
                        RunService.Heartbeat:Wait()
                        local tf3 = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                        newBlob = tf3 and tf3:FindFirstChild("CreatureBlobman")
                    until newBlob or tick() - t0r > 3 or not driftKickEnabled or myLoopID ~= driftKickLoopID
                    if not newBlob or not driftKickEnabled or myLoopID ~= driftKickLoopID then return end
                    -- 再着席
                    local vsR = newBlob:FindFirstChild("VehicleSeat")
                    if vsR and vsR:IsA("VehicleSeat") then
                        hrp.CFrame = vsR.CFrame + Vector3.new(0, 1, 0)
                        vsR:Sit(hum)
                        local stR = tick()
                        repeat
                            RunService.Heartbeat:Wait()
                            if not (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") then
                                hrp.CFrame = vsR.CFrame + Vector3.new(0, 1, 0)
                                vsR:Sit(hum)
                            end
                        until (hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman") or tick() - stR > 2 or not driftKickEnabled or myLoopID ~= driftKickLoopID
                    end
                    -- blobDを更新
                    blobD = newBlob
                    local so2 = blobD:FindFirstChild("BlobmanSeatAndOwnerScript")
                    CGD = so2 and so2:FindFirstChild("CreatureGrab") or blobD:FindFirstChild("CreatureGrab", true)
                    local so3 = blobD:FindFirstChild("BlobmanSeatAndOwnerScript")
                    CDD = so3 and so3:FindFirstChild("CreatureDrop")
                    blobRootD = blobD:FindFirstChild("HumanoidRootPart") or blobD.PrimaryPart
                end)
            end)
            -- ===== メインループ（Heartbeat毎フレーム：滑らか回転） =====
            -- 相手を空中固定（v1と同じ）+ 自分のHRPが相手の周りを滑らかに円運動しながらグラブ
            local grabTimer = 0          -- グラブ連打タイマー
            local GRAB_INTERVAL = 0.00001  -- グラブ間隔（秒）
            local heartbeatConn
            heartbeatConn = RunService.Heartbeat:Connect(function(dt)
                if not driftKickEnabled or myLoopID ~= driftKickLoopID or kickDone then
                    heartbeatConn:Disconnect()
                    return
                end
                if not target or not target.Parent then
                    driftKickEnabled = false
                    heartbeatConn:Disconnect()
                    return
                end
                local tChar = target.Character
                local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tHum  = tChar and tChar:FindFirstChild("Humanoid")
                -- ターゲットがリスポーン中（キャラなし）なら待機
                if not tRoot or not tHum then return end

                -- ブロブマンをSavedPosに固定（v1と同じ）
                blobRootD.CFrame   = SavedPosD
                blobRootD.Velocity = Vector3.new(0,0,0)

                -- 相手を空中に固定（v1と完全に同じ方式）
                tRoot.CFrame      = lockPosD
                tRoot.CFrame      = lockPosD
                tRoot.Velocity    = Vector3.new(0,0,0)
                tRoot.RotVelocity = Vector3.new(0,0,0)
                pcall(function()
                    tHum.PlatformStand = true
                    tHum.Sit           = true
                    tHum.WalkSpeed     = 0
                    tHum.JumpPower     = 0
                    tHum.JumpHeight    = 0
                end)
                pcall(function()
                    GED.SetNetworkOwner:FireServer(tRoot, lockPosD)
                    -- Drop→Grab（左右交互）
                    local gpN  = (driftAlt == 1) and "LeftDetector" or "RightDetector"
                    local wpN  = (driftAlt == 1) and "LeftWeld" or "RightWeld"
                    local R_DetD = blobD:FindFirstChild(gpN)
                    local R_WeldD = R_DetD and (R_DetD:FindFirstChild(wpN) or R_DetD:FindFirstChildWhichIsA("Weld"))
                    if R_DetD and R_WeldD and CDD then
                        CDD:FireServer(R_WeldD)
                    end
                    GED.DestroyGrabLine:FireServer(tRoot)
                    if CGD and R_DetD then
                        CGD:FireServer(R_DetD, tRoot, R_WeldD)
                    end
                    GED.CreateGrabLine:FireServer(tRoot, Vector3.new(0,0,0), tRoot.Position, false)
                end)

                -- 毎フレーム角度を進める（滑らかな回転）
                angle = angle + (dt / SPEED) * (2 * math.pi)

                -- 固定位置を中心に自分のHRPを円軌道で移動
                local lockVec = lockPosD.Position
                local cx = lockVec.X + RADIUS * math.cos(angle)
                local cz = lockVec.Z + RADIUS * math.sin(angle)
                local cy = lockVec.Y
                local orbitPos = Vector3.new(cx, cy, cz)
                hrp.CFrame      = CFrame.new(orbitPos, tRoot.Position)
                hrp.Velocity    = Vector3.new(0,0,0)
                hrp.RotVelocity = Vector3.new(0,0,0)

                -- グラブ連打（GRAB_INTERVALごと、v1と同じ方式）
                grabTimer = grabTimer + dt
                if grabTimer >= GRAB_INTERVAL then
                    grabTimer = 0
                    driftAlt = (driftAlt == 1) and 2 or 1
                    local gpN2  = (driftAlt == 1) and "LeftDetector" or "RightDetector"
                    local wpN2  = (driftAlt == 1) and "LeftWeld" or "RightWeld"
                    local R_DetD2 = blobD:FindFirstChild(gpN2)
                    local R_WeldD2 = R_DetD2 and (R_DetD2:FindFirstChild(wpN2) or R_DetD2:FindFirstChildWhichIsA("Weld"))
                    if CGD and R_DetD2 and tRoot then
                        pcall(function()
                            if CDD and R_WeldD2 then CDD:FireServer(R_WeldD2) end
                            CGD:FireServer(R_DetD2, tRoot, R_WeldD2)
                            GED.CreateGrabLine:FireServer(tRoot, Vector3.new(0,0,0), tRoot.Position, false)
                        end)
                    end
                end
            end)

            -- Heartbeatが終わるまで待機
            while driftKickEnabled and myLoopID == driftKickLoopID and not kickDone do
                task.wait(0.1)
            end
            grabConn:Disconnect()
            if heartbeatConn then heartbeatConn:Disconnect() end
            if targetRespawnConn then targetRespawnConn:Disconnect() end
            -- ターゲットのWalkSpeed/JumpPowerを元に戻す
            pcall(function()
                local tCharFin = target.Character
                local tHumFin  = tCharFin and tCharFin:FindFirstChild("Humanoid")
                if tHumFin then
                    tHumFin.PlatformStand = false
                    tHumFin.Sit           = false
                    tHumFin.WalkSpeed     = 16
                    tHumFin.JumpPower     = 50
                    tHumFin.JumpHeight    = 7.2
                end
            end)
            driftKickEnabled = false
            if DriftKickToggleRef then DriftKickToggleRef:Set(false) end
        end)
    end
})


-- ============================================================
-- ============================================================
-- Kick All
-- ============================================================
local kaIsActive      = false
local kaExcludeFriends = false
local kaCurrentBlob   = nil

local function kaIsFriend(player)
    local ok, result = pcall(function() return Player:IsFriendsWith(player.UserId) end)
    return ok and result
end

local function kaGetAllPlayers()
    local players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            if kaExcludeFriends and kaIsFriend(p) then continue end
            table.insert(players, p)
        end
    end
    return players
end

local function KickAll()
    if kaIsActive then return end
    kaIsActive = true
    local allPlayers = kaGetAllPlayers()
    if #allPlayers == 0 then kaIsActive = false; return end

    local rootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local spawnPos = rootPart.CFrame * CFrame.new(0, 0, -5)
        pcall(function()
            ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0))
        end)
    end
    task.wait(0.1)

    local kaToyFolder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
    kaCurrentBlob = kaToyFolder and kaToyFolder:FindFirstChild("CreatureBlobman")
    if not kaCurrentBlob then kaIsActive = false; return end

    local vehicleSeat = kaCurrentBlob:FindFirstChild("VehicleSeat")
    if vehicleSeat and Player.Character then
        vehicleSeat:Sit(Player.Character:FindFirstChildOfClass("Humanoid"))
    end
    task.wait(0.05)

    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then kaIsActive = false; return end

    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            myRoot.CFrame = targetRoot.CFrame
            task.wait(0.005)
            for i = 1, 3 do
                pcall(function()
                    kaCurrentBlob.BlobmanSeatAndOwnerScript.CreatureRelease:FireServer(kaCurrentBlob.LeftDetector.LeftWeld)
                end)
                if i < 3 then task.wait(0.01) end
            end
        end
    end

    myRoot.CFrame = CFrame.new(0, 100, 0)
    task.wait(0.01)

    for _, part in ipairs(kaCurrentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = true end) end
    end
    task.wait(0.01)

    local radius = 15
    for i, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local angle = math.rad((i - 1) * (360 / #allPlayers))
            targetRoot.CFrame = CFrame.new(radius * math.cos(angle), 110, radius * math.sin(angle))
        end
    end
    task.wait(0.01)

    for _ = 1, 2 do
        for _, targetPlayer in ipairs(allPlayers) do
            local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                pcall(function()
                    ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(targetRoot, CFrame.new(targetRoot.Position))
                    ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(targetRoot)
                end)
            end
        end
        task.wait(0.01)
    end
    task.wait(0.01)

    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            pcall(function()
                kaCurrentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(kaCurrentBlob.LeftDetector, targetRoot, kaCurrentBlob.LeftDetector.LeftWeld)
                kaCurrentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(kaCurrentBlob.RightDetector, targetRoot, kaCurrentBlob.RightDetector.RightWeld)
            end)
        end
    end

    for _, part in ipairs(kaCurrentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = false end) end
    end
    kaIsActive = false
end

local kaLoopActive = false

-- リスポーン時にkaIsActiveをリセット（2回目以降も動くように）
Player.CharacterAdded:Connect(function()
    kaIsActive = false
    if kaCurrentBlob then
        pcall(function() kaCurrentBlob:Destroy() end)
        kaCurrentBlob = nil
    end
end)

BlobmanTab:AddSection({ Name = "Kick All" })

BlobmanTab:AddToggle({
    Name    = "Kick All Loop",
    Default = false,
    Callback = function(val)
        kaLoopActive = val
        if val then
            task.spawn(function()
                while kaLoopActive do
                    KickAll()
                    local timeout = 0
                    while kaIsActive and timeout < 15 do
                        task.wait(0.1); timeout = timeout + 0.1
                    end
                    task.wait(0.3)
                end
            end)
        end
    end
})

-- 操作タブ（UFO + 列車コントロール）
-- ===================================================================
local TrainTab = Window:MakeTab({
    Name = "その他",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

-- ===== 列車コントロール 変数 =====
local AutomationEnabled = false
local AutomationConnection = nil
local TargetItemName = "InstrumentWoodwindOcarina"
local SecondItemName = "FoodMayonnaise"

local occupiedSeats = {}
local seatConnections = {}
local firstTimeRiders = {}
local allSeats = {}

-- ===== 列車コントロール 関数 =====
local function getAllItemsWithRemote()
    local items = {}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("RemoteFunction") and obj.Name == "HoldItemRemoteFunction" then
            local holdPart = obj.Parent
            if holdPart and holdPart.Name == "HoldPart" then
                local item = holdPart.Parent
                if item then
                    local dropRemote = holdPart:FindFirstChild("DropItemRemoteFunction")
                    table.insert(items, {
                        Name = item.Name,
                        Object = item,
                        RemoteFunction = obj,
                        DropRemoteFunction = dropRemote,
                    })
                end
            end
        end
    end
    return items
end

local function getPlayerCharacter()
    return Workspace:FindFirstChild(LP.Name .. "_sub") or
           Workspace:FindFirstChild(LP.Name) or
           LP.Character
end

local function holdItem(itemData)
    local char = getPlayerCharacter()
    if char and itemData and itemData.RemoteFunction then
        pcall(function()
            itemData.RemoteFunction:InvokeServer(itemData.Object, char)
        end)
    end
end

local function useItem(itemData)
    pcall(function()
        local UseRemote = ReplicatedStorage:FindFirstChild("HoldEvents")
        if UseRemote then
            local Use = UseRemote:FindFirstChild("Use")
            if Use then
                Use:FireServer(itemData.Object)
            end
        end
    end)
end

local function dropItemHigh(itemData)
    local char = getPlayerCharacter()
    if char and itemData and itemData.DropRemoteFunction then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                itemData.DropRemoteFunction:InvokeServer(
                    itemData.Object,
                    root.CFrame * CFrame.new(0, 900, 0),
                    Vector3.new(0, 900, 0)
                )
            end)
        end
    end
end

local function spawnItem(itemName)
    local char = getPlayerCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        local SpawnToyRemote = ReplicatedStorage:FindFirstChild("MenuToys")
        if SpawnToyRemote then
            local SpawnFunc = SpawnToyRemote:FindFirstChild("SpawnToyRemoteFunction")
            if SpawnFunc then
                SpawnFunc:InvokeServer(
                    itemName,
                    CFrame.new(root.Position + Vector3.new(0, 900, 0)),
                    Vector3.new(0, 0, 0)
                )
            end
        end
    end)
end

local function findTargetItem()
    for _, item in pairs(getAllItemsWithRemote()) do
        if item.Name == TargetItemName then return item end
    end
    return nil
end

local function findSecondItem()
    for _, item in pairs(getAllItemsWithRemote()) do
        if item.Name == SecondItemName then return item end
    end
    return nil
end

local function performAutoAction(isFirstTime)
    if isFirstTime then
        if not findTargetItem() then spawnItem(TargetItemName) end
        if not findSecondItem() then spawnItem(SecondItemName) end
        task.wait(1.0)
        local target = findTargetItem()
        local second = findSecondItem()
        if target then holdItem(target) task.wait(0.1) end
        if second then holdItem(second) task.wait(0.1) end
        if target then useItem(target) task.wait(0.1) end
        if target then dropItemHigh(target) task.wait(0.1) end
        if second then dropItemHigh(second) end
    else
        local target = findTargetItem()
        if not target then
            spawnItem(TargetItemName)
            task.wait(1.0)
            target = findTargetItem()
        end
        if target then
            holdItem(target)
            task.wait(0.3)
            dropItemHigh(target)
        end
    end
end

local function setupSeat(seat)
    local conn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local humanoid = seat.Occupant
        if humanoid then
            local player = Players:GetPlayerFromCharacter(humanoid.Parent)
            if player then
                occupiedSeats[seat] = player
                if AutomationEnabled then
                    local isFirst = not firstTimeRiders[player.UserId]
                    if isFirst then firstTimeRiders[player.UserId] = true end
                    performAutoAction(isFirst)
                end
            end
            local sitConn
            sitConn = humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
                if not humanoid.Sit and player then
                    occupiedSeats[seat] = nil
                    if AutomationEnabled then performAutoAction(false) end
                    if sitConn then sitConn:Disconnect() end
                end
            end)
        end
    end)
    seatConnections[seat] = conn
    table.insert(allSeats, seat)
end

local function startSeatDetection()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Seat") and obj.Name == "Seat" then setupSeat(obj) end
    end
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Seat") and obj.Name == "Seat" then setupSeat(obj) end
    end)
end

local function sitOnRandomEmptySeat()
    local empty = {}
    for _, seat in pairs(allSeats) do
        if seat and seat.Parent and seat:IsA("Seat") and not seat.Occupant then
            table.insert(empty, seat)
        end
    end
    if #empty == 0 then
        OrionLib:MakeNotification({ Name = "座席なし", Content = "空いている座席がありません", Time = 2 })
        return
    end
    local seat = empty[math.random(1, #empty)]
    local char = getPlayerCharacter()
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root then
            hum.Sit = false
            task.wait(0.2)
            root.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.2)
            seat:Sit(hum)
            OrionLib:MakeNotification({ Name = "着席", Content = "ランダムな空席に座りました", Time = 2 })
        end
    end
end

local function startAutomation()
    if AutomationConnection then AutomationConnection:Disconnect() end
    local char = getPlayerCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    AutomationConnection = hum.Seated:Connect(function(active, seat)
        if AutomationEnabled then
            task.wait(0.1)
            performAutoAction(active)
        end
    end)
    if AutomationEnabled and hum.SeatPart then performAutoAction(true) end
end

local function stopAutomation()
    if AutomationConnection then
        AutomationConnection:Disconnect()
        AutomationConnection = nil
    end
end

-- ===== 操作タブ UI =====
TrainTab:AddSection({ Name = "UFO" })

TrainTab:AddToggle({
    Name = "UFO操作",
    Default = false,
    Callback = function(state)
        if not state then return end
        local StickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
        local SpawnRemote = ReplicatedStorage.MenuToys:WaitForChild("SpawnToyRemoteFunction")
        local CanSpawn = Player:WaitForChild("CanSpawnToy")
        local ToysFolder = workspace:WaitForChild(Player.Name .. "SpawnedInToys")
        local UFOs = {
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("InnerUFO"),
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("OuterUFO")
        }
        local function getHRP()
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                return Player.Character.HumanoidRootPart
            end
            return Player.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
        end
        task.spawn(function()
            for i = 1, 12 do
                local t = tick()
                while not CanSpawn.Value do
                    if tick() - t > 5 then break end
                    task.wait(0.1)
                end
                local hrp = getHRP()
                if hrp then
                    pcall(function()
                        SpawnRemote:InvokeServer(
                            "NinjaShuriken",
                            hrp.CFrame * CFrame.new(0, 10, 15),
                            Vector3.new()
                        )
                    end)
                end
                task.wait(0.15)
            end
            task.wait(1)
            for _, Toy in ipairs(ToysFolder:GetChildren()) do
                if Toy.Name == "NinjaShuriken" and Toy:FindFirstChild("StickyPart") then
                    for _, UFO in ipairs(UFOs) do
                        if UFO
                            and UFO:FindFirstChild("Object")
                            and UFO.Object:FindFirstChild("ObjectModel")
                            and UFO.Object.ObjectModel:FindFirstChild("Body") then
                            StickyEvent:FireServer(
                                Toy.StickyPart,
                                UFO.Object.ObjectModel.Body,
                                CFrame.new()
                            )
                            local follow = UFO.Object:FindFirstChild("FollowThisPart")
                            if follow then
                                if follow:FindFirstChild("AlignOrientation") then
                                    follow.AlignOrientation.Enabled = false
                                end
                                if follow:FindFirstChild("AlignPosition") then
                                    follow.AlignPosition.Enabled = false
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
})

TrainTab:AddSection({ Name = "列車" })

TrainTab:AddButton({
    Name = "ランダムな空席に座る",
    Callback = sitOnRandomEmptySeat
})

TrainTab:AddToggle({
    Name = "列車コントロール準備",
    Default = false,
    Callback = function(value)
        AutomationEnabled = value
        if value then
            startAutomation()
            startSeatDetection()
            OrionLib:MakeNotification({
                Name = "自動化ON",
                Content = "乗車/降車時に" .. TargetItemName .. "を自動操作",
                Time = 3
            })
        else
            stopAutomation()
            OrionLib:MakeNotification({ Name = "自動化OFF", Content = "停止しました", Time = 2 })
        end
    end
})

TrainTab:AddButton({
    Name = "vFly GUI起動",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet('https://raw.githubusercontent.com/makkurokurosukescript/VFly-gui/refs/heads/main/VFly%20gui'))()
        end)
    end
})

TrainTab:AddSection({ Name = "三人称・カメラ" })
TrainTab:AddButton({
    Name = "三人称カメラ",
    Callback = function()
        local LP = game:GetService("Players").LocalPlayer
        LP.CameraMaxZoomDistance = math.huge
        LP.CameraMode = Enum.CameraMode.Classic
    end
})
local fovEnabled = false
local fovValue = 70
local originalFov = 70

TrainTab:AddToggle({
    Name = "FOV変更 ON/OFF",
    Default = false,
    Callback = function(Value)
        fovEnabled = Value
        if Value then
            originalFov = Workspace.CurrentCamera.FieldOfView
            Workspace.CurrentCamera.FieldOfView = fovValue
        else
            Workspace.CurrentCamera.FieldOfView = originalFov
        end
    end
})
TrainTab:AddSlider({
    Name = "FOV調整",
    Min = 0,
    Max = 120,
    Default = 120,
    Increment = 1,
    ValueName = "",
    Callback = function(Value)
        fovValue = Value
        if fovEnabled then
            Workspace.CurrentCamera.FieldOfView = Value
        end
    end
})

TrainTab:AddSection({ Name = "バリア" })

TrainTab:AddButton({
    Name = "バリア破壊",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if not player then
            OrionLib:MakeNotification({Name="Error", Content="Player not found", Time = 4})
            return
        end
        if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then
            OrionLib:MakeNotification({Name="Error", Content="Character not ready", Time = 4})
            return
        end
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local originalWalkSpeed, originalJumpPower
        if humanoid then
            originalWalkSpeed = humanoid.WalkSpeed
            originalJumpPower = humanoid.JumpPower
            pcall(function() humanoid.WalkSpeed = 0 humanoid.JumpPower = 0 end)
        end
        local success, err = pcall(function()
            local MenuToys = ReplicatedStorage:WaitForChild("MenuToys")
            local hrp = player.Character.HumanoidRootPart
            local originalCFrame = hrp.CFrame
            hrp.CFrame = CFrame.new(246.052, -7.35, 431.821)
            task.wait(0.05)
            MenuToys.SpawnToyRemoteFunction:InvokeServer(
                "InstrumentWoodwindOcarina",
                CFrame.new(184.148834, -5.54824972, 498.136749,
                    0.829037189, -0.214714944, 0.516328275,
                    0, 0.923344612, 0.383972496,
                    -0.559193552, -0.318327487, 0.765486956),
                Vector3.new(0, 34, 0)
            )
            task.wait(0.2)
            local toyFolder = workspace:FindFirstChild(player.Name .. "SpawnedInToys")
            if not toyFolder then error("SpawnedInToys folder not found") end
            local ocarina = toyFolder:FindFirstChild("InstrumentWoodwindOcarina")
            if not ocarina then error("InstrumentWoodwindOcarina not found") end
            if ocarina:FindFirstChild("HoldPart") and ocarina.HoldPart:FindFirstChild("HoldItemRemoteFunction") then
                pcall(function()
                    ocarina.HoldPart.HoldItemRemoteFunction:InvokeServer(ocarina, player.Character)
                end)
                task.wait(0.2)
            end
            player.Character.HumanoidRootPart.CFrame = CFrame.new(304.06, 25.77, 488.54)
            task.wait(0.05)
            local destroyEv = ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
            if destroyEv then
                destroyEv:FireServer(ocarina)
            else
                error("DestroyToy event not found")
            end
            task.wait(0.05)
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = originalCFrame
            end
            OrionLib:MakeNotification({Name="Success", Content="Barrier break executed", Time = 3})
        end)
        local curHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if curHum then
            pcall(function()
                if originalWalkSpeed ~= nil then curHum.WalkSpeed = originalWalkSpeed end
                if originalJumpPower ~= nil then curHum.JumpPower = originalJumpPower end
            end)
        end
        if not success then
            OrionLib:MakeNotification({Name="Error", Content=tostring(err), Time = 6})
        end
    end
})


TrainTab:AddSection({ Name = "モバイルボタン" })

-- UI要素を事前作成（Enabled=falseで非表示）
local _mobGui = Instance.new("ScreenGui")
_mobGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
_mobGui.ResetOnSpawn = false
_mobGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_mobGui.Enabled = false

-- テレポートボタン
local _mobTpBtn = Instance.new("TextButton")
_mobTpBtn.Name = "gsgsgsg"
_mobTpBtn.Parent = _mobGui
_mobTpBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobTpBtn.BackgroundTransparency = 1
_mobTpBtn.BorderSizePixel = 0
_mobTpBtn.Position = UDim2.new(0.685, 0, 0.79, 0)
_mobTpBtn.Size = UDim2.new(0, 41, 0, 39)
_mobTpBtn.Font = Enum.Font.SourceSans
_mobTpBtn.Text = ""
_mobTpBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
_mobTpBtn.TextSize = 14

local _mobTpImg1 = Instance.new("ImageLabel")
_mobTpImg1.Name = "TPLeabel"
_mobTpImg1.Parent = _mobTpBtn
_mobTpImg1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobTpImg1.BackgroundTransparency = 1
_mobTpImg1.BorderSizePixel = 0
_mobTpImg1.Position = UDim2.new(-0.191510454, 0, -0.187805966, 0)
_mobTpImg1.Size = UDim2.new(0, 55, 0, 54)
_mobTpImg1.Image = "rbxassetid://97166444"

local _mobTpImg2 = Instance.new("ImageLabel")
_mobTpImg2.Name = "TPLeabel"
_mobTpImg2.Parent = _mobTpImg1
_mobTpImg2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobTpImg2.BackgroundTransparency = 1
_mobTpImg2.BorderSizePixel = 0
_mobTpImg2.Position = UDim2.new(0.00591708114, 0, 0.0376456939, 0)
_mobTpImg2.Size = UDim2.new(0, 54, 0, 51)
_mobTpImg2.Image = "rbxassetid://6723742952"

-- アンカーボタン
local _mobAnchorBtn = Instance.new("TextButton")
_mobAnchorBtn.Name = "AnchorToggle"
_mobAnchorBtn.Parent = _mobGui
_mobAnchorBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobAnchorBtn.BackgroundTransparency = 1
_mobAnchorBtn.BorderSizePixel = 0
_mobAnchorBtn.Position = UDim2.new(0.55, 35, 0.79, 0)
_mobAnchorBtn.Size = UDim2.new(0, 43, 0, 42)
_mobAnchorBtn.Font = Enum.Font.SourceSans
_mobAnchorBtn.Text = ""
_mobAnchorBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
_mobAnchorBtn.TextSize = 14

local _mobAnchorImg1 = Instance.new("ImageLabel")
_mobAnchorImg1.Name = "AnchorLeabel"
_mobAnchorImg1.Parent = _mobAnchorBtn
_mobAnchorImg1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobAnchorImg1.BackgroundTransparency = 1
_mobAnchorImg1.BorderSizePixel = 0
_mobAnchorImg1.Position = UDim2.new(-0.148969784, 0, -0.192690164, 0)
_mobAnchorImg1.Size = UDim2.new(0, 55, 0, 54)
_mobAnchorImg1.Image = "rbxassetid://97166444"

local _mobAnchorImg2 = Instance.new("ImageLabel")
_mobAnchorImg2.Name = "AnchorLeabel"
_mobAnchorImg2.Parent = _mobAnchorImg1
_mobAnchorImg2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
_mobAnchorImg2.BackgroundTransparency = 1
_mobAnchorImg2.BorderSizePixel = 0
_mobAnchorImg2.Position = UDim2.new(0.0415438563, 0, 0.0960388184, 0)
_mobAnchorImg2.Size = UDim2.new(0.885727763, 0, 0.796296299, 0)
_mobAnchorImg2.Image = "rbxassetid://3040311268"

-- テレポート処理（Zキー）
local function _mobTeleportToLookAt()
    pcall(function()
        local character = Player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local camera = workspace.CurrentCamera
        local unitRay = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, raycastParams)
        if raycastResult then
            hrp.CFrame = CFrame.new(raycastResult.Position + Vector3.new(0, 5, 0))
        end
    end)
end
_mobTpBtn.MouseButton1Click:Connect(_mobTeleportToLookAt)

-- アンカー処理（Kキー）
local _mobAnchoredObjects = {}
local ANCHOR_SOUND_ID = "rbxassetid://18404418062"
local function _mobPlayEffect()
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = ANCHOR_SOUND_ID
        sound.Volume = 1
        sound.RollOffMaxDistance = 0
        sound.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        task.wait(0.02)
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 3)
    end)
end
local function _mobUnAnchor(targetPart)
    local targetModel = targetPart.Parent:IsA("Model") and targetPart.Parent or targetPart
    local data = _mobAnchoredObjects[targetPart]
    if data then
        if data.BP then data.BP:Destroy() end
        if data.BG then data.BG:Destroy() end
        if data.HL then data.HL:Destroy() end
        targetModel:SetAttribute("IsAnchored", false)
        _mobAnchoredObjects[targetPart] = nil
    end
end
local function _mobToggleAnchor()
    local grabFolder = Workspace:FindFirstChild("GrabParts")
    if not grabFolder then return end
    local grabPart = grabFolder:FindFirstChild("GrabPart")
    if not (grabPart and grabPart:FindFirstChild("WeldConstraint")) then return end
    local target = grabPart.WeldConstraint.Part1
    if not target then return end
    local map = Workspace:FindFirstChild("Map")
    local isMapObject = map and target:IsDescendantOf(map)
    if not isMapObject then
        local targetModel = target.Parent:IsA("Model") and target.Parent or target
        if _mobAnchoredObjects[target] or targetModel:GetAttribute("IsAnchored") then
            _mobUnAnchor(target)
        else
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.Position = target.Position
            bp.P = 40000
            bp.D = 950
            bp.Parent = target
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.CFrame = target.CFrame
            bg.P = 40000
            bg.D = 950
            bg.Parent = target
            local hl = Instance.new("Highlight")
            hl.Name = "AnchorHighlight"
            hl.FillColor = Color3.new(0, 0, 0.5)
            hl.OutlineColor = Color3.new(0, 0, 0.5)
            hl.FillTransparency = 0.7
            hl.Adornee = targetModel
            hl.Parent = targetModel
            targetModel:SetAttribute("IsAnchored", true)
            _mobAnchoredObjects[target] = { BP = bp, BG = bg, HL = hl }
            _mobPlayEffect()
        end
    end
end
_mobAnchorBtn.MouseButton1Click:Connect(_mobToggleAnchor)

-- キーボード接続（トグルON時のみ有効）
local _mobZConn = nil
local _mobKConn = nil

TrainTab:AddToggle({
    Name = "モバイルボタン表示",
    Default = false,
    Callback = function(v)
        _mobGui.Enabled = v
        if v then
            if not _mobZConn then
                _mobZConn = game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
                    if gp then return end
                    if input.KeyCode == Enum.KeyCode.Z then _mobTeleportToLookAt() end
                end)
            end
            if not _mobKConn then
                _mobKConn = game:GetService("ContextActionService"):BindAction(
                    "MobAnchorToggle",
                    function(_, state) if state == Enum.UserInputState.Begin then _mobToggleAnchor() end end,
                    false,
                    Enum.KeyCode.K
                )
            end
        else
            if _mobZConn then _mobZConn:Disconnect(); _mobZConn = nil end
            game:GetService("ContextActionService"):UnbindAction("MobAnchorToggle")
            _mobKConn = nil
        end
    end
})

-- ===== テレポートタブ =====
local TeleportTab = Window:MakeTab({
    Name = "テレポート",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local selectedTeleportPlayer = nil

local function getTeleportPlayerList()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            table.insert(list, plr.DisplayName .. " (" .. plr.Name .. ")")
        end
    end
    return list
end

local function getTeleportPlayerFromSelection(selection)
    if not selection then return nil end
    local username = selection:match("%((.-)%)")
    if username then
        return Players:FindFirstChild(username)
    end
    return nil
end

TeleportTab:AddSection({ Name = "プレイヤーテレポート" })

local TeleportPlayerDropdown = TeleportTab:AddDropdown({
    Name = "テレポートするプレイヤー",
    Default = "",
    Options = getTeleportPlayerList(),
    Callback = function(Value)
        selectedTeleportPlayer = getTeleportPlayerFromSelection(Value)
    end
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    TeleportPlayerDropdown:Refresh(getTeleportPlayerList(), true)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    TeleportPlayerDropdown:Refresh(getTeleportPlayerList(), true)
end)

TeleportTab:AddButton({
    Name = "テレポート",
    Callback = function()
        if selectedTeleportPlayer then
            local target = selectedTeleportPlayer
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local tCFrame = target.Character.HumanoidRootPart.CFrame
                Player.Character.HumanoidRootPart.CFrame = tCFrame * CFrame.new(0, 0, 2)
            end
        end
    end
})


local teleportLoopEnabled = false
TeleportTab:AddToggle({
    Name = "テレポートループ",
    Default = false,
    Callback = function(Value)
        teleportLoopEnabled = Value
        if Value then
            task.spawn(function()
                while teleportLoopEnabled do
                    if selectedTeleportPlayer then
                        local target = selectedTeleportPlayer
                        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                            and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                            local tCFrame = target.Character.HumanoidRootPart.CFrame
                            Player.Character.HumanoidRootPart.CFrame = tCFrame * CFrame.new(0, 0, 2)
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end
})

-- ===== 初期化 =====
OrionLib:Init()
task.wait(0.5)
OrionLib:MakeNotification({
    Name = "Hacker Hub v1.5",
    Content = "起動しました",
    Time = 4
})

-- 起動チャットメッセージ
task.spawn(function()
    task.wait(1)
    local msg = "Hacker Hub v1.5"
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            -- 新チャットシステム：TextChannels内の全チャンネルを試行
            local channels = TextChatService:WaitForChild("TextChannels", 5)
            if channels then
                local ch = channels:FindFirstChild("RBXGeneral")
                    or channels:FindFirstChildWhichIsA("TextChannel")
                if ch then ch:SendAsync(msg) end
            end
        else
            -- 旧チャットシステム
            local chatEvent = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            if chatEvent then chatEvent.SayMessageRequest:FireServer(msg, "All") end
        end
    end)
end)

-- アンチ爆発
local antiExplosionConn
local function setupAntiExplosion(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local ragdolled = hum:FindFirstChild("Ragdolled")
    if ragdolled and ragdolled:IsA("BoolValue") then
        if antiExplosionConn then antiExplosionConn:Disconnect() end
        antiExplosionConn = ragdolled:GetPropertyChangedSignal("Value"):Connect(function()
            local anchored = ragdolled.Value
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Anchored = anchored
                end
            end
        end)
    end
end

task.spawn(function()
    task.wait(1)
    startSeatDetection()
    if AutomationEnabled then startAutomation() end
    if LP.Character then setupAntiExplosion(LP.Character) end
end)

LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if AutomationEnabled then startAutomation() end
    setupAntiExplosion(char)
end)


-- ============================================================
-- TASタブ（ウォールホップ・ラダーフリック）
-- ============================================================
local TASTab = Window:MakeTab({
    Name = "アスレ",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TASTab:AddSection({ Name = "ウォールホップ" })

-- 変数
local tasChar      = Player.Character or Player.CharacterAdded:Wait()
local tasHum       = tasChar:WaitForChild("Humanoid")
local tasRoot      = tasChar:WaitForChild("HumanoidRootPart")
local tasConns     = {}
local wallhopOn    = false
local tasUpPower   = 72   -- 上昇力固定
local tasSpeedMult = 1.18 -- 横速度倍率

-- キャラクターリスポーン対応
Player.CharacterAdded:Connect(function(newChar)
    tasChar  = newChar
    tasHum   = newChar:WaitForChild("Humanoid")
    tasRoot  = newChar:WaitForChild("HumanoidRootPart")
end)

-- ウォールホップ（壁に触れてジャンプ中→自動で上昇）
TASTab:AddToggle({
    Name = "ウォールホップ AUTO",
    Default = false,
    Callback = function(on)
        wallhopOn = on
        if tasConns.wallhop then
            tasConns.wallhop:Disconnect()
            tasConns.wallhop = nil
        end
        if not on then return end
        local wallhopCD = false  -- クールダウンフラグ
        tasConns.wallhop = RunService.Heartbeat:Connect(function()
            if not wallhopOn or not tasRoot or not tasHum then return end
            if wallhopCD then return end

            -- ジャンプ中のみ反応
            local state = tasHum:GetState()
            if state ~= Enum.HumanoidStateType.Jumping and
               state ~= Enum.HumanoidStateType.Freefall then return end

            -- 前方の壁のみ検知（地面・左右は除外）
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {tasChar}
            local fwdRay = Workspace:Raycast(tasRoot.Position, tasRoot.CFrame.LookVector * 4, params)

            -- 前方に壁があるかつ垂直に近い壁（地面ではない）か確認
            if not fwdRay or not fwdRay.Instance or not fwdRay.Instance.CanCollide then return end
            local normal = fwdRay.Normal
            -- 法線のY成分が小さい（垂直な壁）もののみ反応
            if math.abs(normal.Y) > 0.5 then return end

            -- ウォールホップ発動
            wallhopCD = true
            local up  = tasUpPower + math.random(-7, 13)
            local fwd2 = tasRoot.CFrame.LookVector * (18 + math.random(0, 8))
            tasRoot.Velocity = Vector3.new(
                tasRoot.Velocity.X * tasSpeedMult + fwd2.X,
                up,
                tasRoot.Velocity.Z * tasSpeedMult + fwd2.Z
            )
            local orig = tasRoot.CFrame
            tasRoot.CFrame = orig * CFrame.Angles(0, math.rad(math.random(80, 120)), 0)
            task.wait(0.002)
            tasRoot.CFrame = orig
            task.delay(0.005, function()
                if tasHum then tasHum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            -- 短いクールダウン（連続発動対応）
            task.delay(0.02, function() wallhopCD = false end)
        end)
    end
})

-- 後ろウォールホップ（後ろの壁に当たったら自動上昇）
local backWallhopOn = false
TASTab:AddToggle({
    Name = "後ろウォールホップ AUTO",
    Default = false,
    Callback = function(on)
        backWallhopOn = on
        if tasConns.backWallhop then
            tasConns.backWallhop:Disconnect()
            tasConns.backWallhop = nil
        end
        if not on then return end
        local bwCD = false
        tasConns.backWallhop = RunService.Heartbeat:Connect(function()
            if not backWallhopOn or not tasRoot or not tasHum then return end
            if bwCD then return end

            -- ジャンプ中のみ反応
            local state = tasHum:GetState()
            if state ~= Enum.HumanoidStateType.Jumping and
               state ~= Enum.HumanoidStateType.Freefall then return end

            -- 後方の壁だけ検知
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {tasChar}
            local backRay = Workspace:Raycast(tasRoot.Position, -tasRoot.CFrame.LookVector * 4, params)

            if not backRay or not backRay.Instance or not backRay.Instance.CanCollide then return end
            local normal = backRay.Normal
            if math.abs(normal.Y) > 0.5 then return end

            -- 後ろウォールホップ発動
            bwCD = true
            local up   = tasUpPower + math.random(-7, 13)
            local back = -tasRoot.CFrame.LookVector * (18 + math.random(0, 8))
            tasRoot.Velocity = Vector3.new(
                tasRoot.Velocity.X * tasSpeedMult + back.X,
                up,
                tasRoot.Velocity.Z * tasSpeedMult + back.Z
            )
            local orig = tasRoot.CFrame
            tasRoot.CFrame = orig * CFrame.Angles(0, math.rad(math.random(80, 120)), 0)
            task.wait(0.002)
            tasRoot.CFrame = orig
            task.delay(0.005, function()
                if tasHum then tasHum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            task.delay(0.02, function() bwCD = false end)
        end)
    end
})


-- ============================================================
-- チャットタブ
-- ============================================================
local ChatTab = Window:MakeTab({
    Name = "チャット",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- VC Cheat: プレイヤー選択ドロップダウン
local vcSelectedPlayer = nil

local function getVCPlayerList()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            table.insert(list, plr.DisplayName .. " (" .. plr.Name .. ")")
        end
    end
    return list
end

local function getVCPlayerFromSelection(selection)
    if not selection then return nil end
    local username = selection:match("%((.-)%)")
    if username then
        return Players:FindFirstChild(username)
    end
    return nil
end

local VCPlayerDropdown = ChatTab:AddDropdown({
    Name = "プレイヤー選択",
    Default = "",
    Options = getVCPlayerList(),
    Callback = function(Value)
        vcSelectedPlayer = getVCPlayerFromSelection(Value)
    end
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    VCPlayerDropdown:Refresh(getVCPlayerList(), true)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    VCPlayerDropdown:Refresh(getVCPlayerList(), true)
end)

-- VC Cheat トグル
local vcCheatEnabled = false
local vcCheatConn = nil
local vcHeartbeatConn = nil

ChatTab:AddToggle({
    Name = "VC Cheat（声を聞く）",
    Default = false,
    Callback = function(val)
        vcCheatEnabled = val
        if val then
            if not vcSelectedPlayer then
                OrionLib:MakeNotification({
                    Name = "Error",
                    Content = "プレイヤーを選択してください",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
                vcCheatEnabled = false
                return
            end
            -- VC Cheat: ターゲットのAudioDeviceInput音量を上げ、自分のキャラにAudioListenerを追加
            local function enableVCForTarget(targetPlayer)
                local char = targetPlayer.Character
                if not char then return end
                -- AudioDeviceInput（マイク）の音量を上げる
                for _, desc in ipairs(char:GetDescendants()) do
                    if desc:IsA("AudioDeviceInput") then
                        pcall(function() desc.Volume = 100 end)
                    end
                end
                -- AudioEmitter（スピーカー）の音量も上げる
                for _, desc in ipairs(char:GetDescendants()) do
                    if desc:IsA("AudioEmitter") then
                        pcall(function() desc.Volume = 100 end)
                    end
                end
                -- 自分のキャラにAudioListenerを追加（距離制限を無視して聞こえるようにする）
                local myChar = Player.Character
                if myChar then
                    local existing = myChar:FindFirstChild("_vcCheatListener")
                    if not existing then
                        local listener = Instance.new("AudioListener")
                        listener.Name = "_vcCheatListener"
                        listener.Parent = myChar
                    end
                end
                -- SoundServiceのDistanceFactor/RolloffScaleを調整して遠くても聞こえるようにする
                local SoundService = game:GetService("SoundService")
                pcall(function()
                    SoundService.DistanceFactor = 1
                    SoundService.RolloffScale = 0
                end)
            end
            enableVCForTarget(vcSelectedPlayer)
            -- キャラクター変更時も再適用
            vcCheatConn = vcSelectedPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                if vcCheatEnabled then
                    enableVCForTarget(vcSelectedPlayer)
                end
            end)
        else
            -- クリーンアップ
            if vcCheatConn then
                vcCheatConn:Disconnect()
                vcCheatConn = nil
            end
            -- AudioDeviceInput/AudioEmitterの音量を元に戻す
            if vcSelectedPlayer and vcSelectedPlayer.Character then
                for _, desc in ipairs(vcSelectedPlayer.Character:GetDescendants()) do
                    if desc:IsA("AudioDeviceInput") or desc:IsA("AudioEmitter") then
                        pcall(function() desc.Volume = 1 end)
                    end
                end
            end
            -- AudioListenerを削除
            local myChar = Player.Character
            if myChar then
                local listener = myChar:FindFirstChild("_vcCheatListener")
                if listener then listener:Destroy() end
            end
            -- SoundServiceを元に戻す
            local SoundService = game:GetService("SoundService")
            pcall(function()
                SoundService.DistanceFactor = 3.33
                SoundService.RolloffScale = 1
            end)
        end
    end
})
