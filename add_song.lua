--[[
    Add Custom Song UI
    - Paste script + name
    - Choose existing category or create a new one
    - Stores category as first line comment: --CAT:categoryname
]]

local function createNotifLib()
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Linh-1205/autopiano/refs/heads/main/notif_lib.lua", true))()
    end)
    if ok and lib then return lib end
    return {
        SendNotification = function(_, title, text)
            print("[Notif]", title, text)
        end
    }
end
local NotificationLibrary = createNotifLib()

local function playSound(soundId, loudness)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Parent = game.Players.LocalPlayer.Character or game.Players.LocalPlayer
    sound.Volume = loudness or 1
    sound:Play()
end

-- Default categories (same as main)
local defaultCategories = {
    "custom", "peak", "best", "epic", "beautiful",
    "video games", "memes", "classical", "anime/jpop",
    "pop/hiphop", "sad", "electronic", "rock"
}

-- Load extra user categories if any
local userCats = {}
pcall(function()
    if isfile and isfile("AUTOPIANO_CUSTOM_SONGS/_categories.txt") then
        local raw = readfile("AUTOPIANO_CUSTOM_SONGS/_categories.txt")
        for line in raw:gmatch("[^\r\n]+") do
            local c = line:match("^%s*(.-)%s*$")
            if c ~= "" then table.insert(userCats, c) end
        end
    end
end)

local allCats = {}
local seen = {}
for _, c in ipairs(defaultCategories) do
    if not seen[c] then seen[c] = true; table.insert(allCats, c) end
end
for _, c in ipairs(userCats) do
    if not seen[c] then seen[c] = true; table.insert(allCats, c) end
end

local addgui = Instance.new("ScreenGui")
addgui.Name = "addgui"
addgui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
addgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
addgui.ResetOnSpawn = false

local newsongframe = Instance.new("Frame")
newsongframe.Name = "newsongframe"
newsongframe.Parent = addgui
newsongframe.AnchorPoint = Vector2.new(0.5, 0.5)
newsongframe.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
newsongframe.BorderSizePixel = 0
newsongframe.Position = UDim2.new(0.5, 0, 0.5, 0)
newsongframe.Size = UDim2.new(0, 280, 0, 420)

local uic = Instance.new("UICorner")
uic.CornerRadius = UDim.new(0, 12)
uic.Parent = newsongframe

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 140, 170)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = newsongframe

local newsonglabel = Instance.new("TextLabel")
newsonglabel.Name = "newsonglabel"
newsonglabel.Parent = newsongframe
newsonglabel.BackgroundTransparency = 1
newsonglabel.Position = UDim2.new(0, 16, 0, 12)
newsonglabel.Size = UDim2.new(1, -50, 0, 32)
newsonglabel.Font = Enum.Font.GothamBold
newsonglabel.Text = "Add Custom Song"
newsonglabel.TextColor3 = Color3.fromRGB(255, 255, 255)
newsonglabel.TextSize = 20
newsonglabel.TextXAlignment = Enum.TextXAlignment.Left

local cancelButton = Instance.new("TextButton")
cancelButton.Name = "cancelButton"
cancelButton.Parent = newsongframe
cancelButton.AnchorPoint = Vector2.new(1, 0)
cancelButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
cancelButton.Position = UDim2.new(1, -10, 0, 10)
cancelButton.Size = UDim2.new(0, 28, 0, 28)
cancelButton.Font = Enum.Font.GothamBold
cancelButton.Text = "✕"
cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
cancelButton.TextSize = 14
Instance.new("UICorner", cancelButton).CornerRadius = UDim.new(0, 6)

local insertscript = Instance.new("TextBox")
insertscript.Name = "insertscript"
insertscript.Parent = newsongframe
insertscript.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
insertscript.Position = UDim2.new(0, 16, 0, 52)
insertscript.Size = UDim2.new(1, -32, 0, 120)
insertscript.Font = Enum.Font.Code
insertscript.PlaceholderText = "Paste your song script here..."
insertscript.Text = ""
insertscript.TextColor3 = Color3.fromRGB(230, 230, 235)
insertscript.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
insertscript.TextSize = 13
insertscript.TextWrapped = true
insertscript.MultiLine = true
insertscript.ClearTextOnFocus = false
insertscript.TextXAlignment = Enum.TextXAlignment.Left
insertscript.TextYAlignment = Enum.TextYAlignment.Top
Instance.new("UICorner", insertscript).CornerRadius = UDim.new(0, 8)

local insertsongName = Instance.new("TextBox")
insertsongName.Name = "insertsongName"
insertsongName.Parent = newsongframe
insertsongName.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
insertsongName.Position = UDim2.new(0, 16, 0, 184)
insertsongName.Size = UDim2.new(1, -32, 0, 32)
insertsongName.Font = Enum.Font.Gotham
insertsongName.PlaceholderText = "Song name..."
insertsongName.Text = ""
insertsongName.TextColor3 = Color3.fromRGB(230, 230, 235)
insertsongName.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
insertsongName.TextSize = 15
insertsongName.ClearTextOnFocus = false
Instance.new("UICorner", insertsongName).CornerRadius = UDim.new(0, 8)

-- Category label
local catLabel = Instance.new("TextLabel")
catLabel.Parent = newsongframe
catLabel.BackgroundTransparency = 1
catLabel.Position = UDim2.new(0, 16, 0, 224)
catLabel.Size = UDim2.new(1, -32, 0, 18)
catLabel.Font = Enum.Font.Gotham
catLabel.Text = "Category"
catLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
catLabel.TextSize = 13
catLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Category dropdown (simple scroll of buttons)
local catScroll = Instance.new("ScrollingFrame")
catScroll.Parent = newsongframe
catScroll.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
catScroll.Position = UDim2.new(0, 16, 0, 246)
catScroll.Size = UDim2.new(1, -32, 0, 80)
catScroll.ScrollBarThickness = 4
catScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
catScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", catScroll).CornerRadius = UDim.new(0, 8)

local catLayout = Instance.new("UIListLayout")
catLayout.Parent = catScroll
catLayout.Padding = UDim.new(0, 4)
catLayout.SortOrder = Enum.SortOrder.LayoutOrder

local selectedCat = "custom"
local catButtons = {}

local function refreshCatButtons()
    for _, b in ipairs(catButtons) do b:Destroy() end
    catButtons = {}
    for i, c in ipairs(allCats) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 24)
        btn.BackgroundColor3 = (c == selectedCat) and Color3.fromRGB(255, 120, 160) or Color3.fromRGB(55, 55, 65)
        btn.Text = c
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Parent = catScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            selectedCat = c
            refreshCatButtons()
        end)
        table.insert(catButtons, btn)
    end
end
refreshCatButtons()

-- New category input
local newCatBox = Instance.new("TextBox")
newCatBox.Parent = newsongframe
newCatBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
newCatBox.Position = UDim2.new(0, 16, 0, 334)
newCatBox.Size = UDim2.new(1, -100, 0, 28)
newCatBox.Font = Enum.Font.Gotham
newCatBox.PlaceholderText = "New category name..."
newCatBox.Text = ""
newCatBox.TextColor3 = Color3.fromRGB(230, 230, 235)
newCatBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
newCatBox.TextSize = 13
newCatBox.ClearTextOnFocus = false
Instance.new("UICorner", newCatBox).CornerRadius = UDim.new(0, 6)

local addCatBtn = Instance.new("TextButton")
addCatBtn.Parent = newsongframe
addCatBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
addCatBtn.Position = UDim2.new(1, -76, 0, 334)
addCatBtn.Size = UDim2.new(0, 60, 0, 28)
addCatBtn.Font = Enum.Font.GothamBold
addCatBtn.Text = "+ Cat"
addCatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addCatBtn.TextSize = 12
Instance.new("UICorner", addCatBtn).CornerRadius = UDim.new(0, 6)

addCatBtn.MouseButton1Click:Connect(function()
    local name = newCatBox.Text:match("^%s*(.-)%s*$")
    if name == "" then
        NotificationLibrary:SendNotification("Error", "Enter a category name.", 2)
        return
    end
    if seen[name] then
        selectedCat = name
        refreshCatButtons()
        newCatBox.Text = ""
        return
    end
    seen[name] = true
    table.insert(allCats, name)
    selectedCat = name
    -- persist
    pcall(function()
        if not isfolder("AUTOPIANO_CUSTOM_SONGS") then makefolder("AUTOPIANO_CUSTOM_SONGS") end
        local existing = ""
        if isfile("AUTOPIANO_CUSTOM_SONGS/_categories.txt") then
            existing = readfile("AUTOPIANO_CUSTOM_SONGS/_categories.txt")
        end
        writefile("AUTOPIANO_CUSTOM_SONGS/_categories.txt", existing .. name .. "\n")
    end)
    refreshCatButtons()
    newCatBox.Text = ""
    playSound("6493287948", 0.1)
    NotificationLibrary:SendNotification("Success", "Category added: " .. name, 2)
end)

local submitSong = Instance.new("TextButton")
submitSong.Name = "submitSong"
submitSong.Parent = newsongframe
submitSong.BackgroundColor3 = Color3.fromRGB(255, 120, 160)
submitSong.Position = UDim2.new(0, 16, 0, 372)
submitSong.Size = UDim2.new(1, -32, 0, 36)
submitSong.Font = Enum.Font.GothamBold
submitSong.Text = "Add Song"
submitSong.TextColor3 = Color3.fromRGB(255, 255, 255)
submitSong.TextSize = 16
Instance.new("UICorner", submitSong).CornerRadius = UDim.new(0, 8)

-- Drag
local UserInputService = game:GetService("UserInputService")
local gui = newsongframe
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

gui.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = gui.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

gui.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

cancelButton.MouseButton1Click:Connect(function()
    addgui:Destroy()
end)

submitSong.MouseButton1Click:Connect(function()
    local scriptInput = insertscript.Text
    local songName = insertsongName.Text:match("^%s*(.-)%s*$")

    if songName == "" or scriptInput == "" then
        playSound("6493287948", 0.1)
        NotificationLibrary:SendNotification("Error", "Please fill in both fields.", 3)
        return
    end

    if not isfolder("AUTOPIANO_CUSTOM_SONGS") then
        makefolder("AUTOPIANO_CUSTOM_SONGS")
    end

    local songexists = false
    for _, file in ipairs(listfiles("./AUTOPIANO_CUSTOM_SONGS")) do
        if string.find(tostring(file), songName .. ".txt") then
            playSound("6493287948", 0.1)
            NotificationLibrary:SendNotification("Error", "A song with that name already exists.", 3)
            songexists = true
            break
        end
    end

    if not songexists then
        -- Prepend category marker so main script can read it
        local finalScript = "--CAT:" .. selectedCat .. "\n" .. scriptInput
        writefile("AUTOPIANO_CUSTOM_SONGS/" .. songName .. ".txt", finalScript)
        playSound("6493287948", 0.1)
        NotificationLibrary:SendNotification("Success", "Added \"" .. songName .. "\" → " .. selectedCat, 4)
        insertscript.Text = ""
        insertsongName.Text = ""
    end

    task.wait(0.4)
    if updateSongs then
        updateSongs()
    end
    addgui:Destroy()
end)
