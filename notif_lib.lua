--[[
    Self-contained Notification Library
    No external dependencies.
]]

local NotificationLibrary = {}

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local holder = Instance.new("ScreenGui")
holder.Name = "AutoPianoNotifs"
holder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
holder.ResetOnSpawn = false
holder.Parent = CoreGui

local list = Instance.new("Frame")
list.Name = "List"
list.BackgroundTransparency = 1
list.Size = UDim2.new(0, 320, 1, -40)
list.Position = UDim2.new(1, -340, 0, 20)
list.Parent = holder

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = list

local colors = {
    Success = Color3.fromRGB(46, 204, 113),
    Error   = Color3.fromRGB(231, 76, 60),
    Info    = Color3.fromRGB(52, 152, 219),
    Warning = Color3.fromRGB(241, 196, 15),
}

function NotificationLibrary:SendNotification(title, text, duration)
    duration = duration or 3
    title = title or "Info"
    text = text or ""

    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    card.BackgroundTransparency = 0.08
    card.Size = UDim2.new(1, 0, 0, 0)
    card.ClipsDescendants = true
    card.Parent = list

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = colors[title] or colors.Info
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = card

    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = colors[title] or colors.Info
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BorderSizePixel = 0
    accent.Parent = card
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0, 12)
    ac.Parent = accent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 16, 0, 8)
    titleLbl.Size = UDim2.new(1, -28, 0, 20)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = title
    titleLbl.TextColor3 = colors[title] or colors.Info
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 16, 0, 28)
    body.Size = UDim2.new(1, -28, 0, 36)
    body.Font = Enum.Font.Gotham
    body.Text = text
    body.TextColor3 = Color3.fromRGB(230, 230, 235)
    body.TextSize = 13
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Parent = card

    -- animate in
    TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, 72)
    }):Play()

    task.delay(duration, function()
        local tw = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Wait()
        card:Destroy()
    end)
end

return NotificationLibrary
