local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ZeptoUI = {}

local SCREEN_GUI = nil
local OVERLAY = nil
local BLUR = nil
local UI_OPEN = true
local NOTIF_CONTAINER = nil
local WINDOWS = {}

-- Настройки размера по умолчанию
local CONFIG = {
	HeaderHeight = 35,
	ItemHeight = 30,
	FontSize = 16,
	WindowWidth = 200,
	AccentColor = Color3.fromRGB(0, 170, 255)
}

-- Изменение масштаба всего UI
function ZeptoUI:SetScale(scale)
	CONFIG.HeaderHeight = 35 * scale
	CONFIG.ItemHeight = 30 * scale
	CONFIG.FontSize = 16 * scale
	CONFIG.WindowWidth = 200 * scale
	-- Для применения на лету нужно будет обновить уже созданные окна, 
	-- но обычно это вызывается ОДИН раз перед созданием окон.
end

function ZeptoUI:Init(name)
	if not SCREEN_GUI then
		SCREEN_GUI = Instance.new("ScreenGui")
		SCREEN_GUI.Name = name or "ZeptoUI"
		SCREEN_GUI.IgnoreGuiInset = true
		SCREEN_GUI.ResetOnSpawn = false
		SCREEN_GUI.Parent = game.CoreGui or game.Players.LocalPlayer:WaitForChild("PlayerGui")

		OVERLAY = Instance.new("Frame")
		OVERLAY.Size = UDim2.new(1, 0, 1, 0)
		OVERLAY.BackgroundColor3 = Color3.new(0, 0, 0)
		OVERLAY.BackgroundTransparency = 0.5
		OVERLAY.ZIndex = 1
		OVERLAY.Parent = SCREEN_GUI

		BLUR = Instance.new("BlurEffect", game:GetService("Lighting"))
		BLUR.Size = 10
		NOTIF_CONTAINER = Instance.new("Frame")
		NOTIF_CONTAINER.Name = "Notifications"
		NOTIF_CONTAINER.Size = UDim2.new(0, 280, 1, -20)
		NOTIF_CONTAINER.Position = UDim2.new(1, -290, 0, 10)
		NOTIF_CONTAINER.BackgroundTransparency = 1
		NOTIF_CONTAINER.ZIndex = 100 -- Всегда поверх окон
		NOTIF_CONTAINER.Parent = SCREEN_GUI

		local NotifLayout = Instance.new("UIListLayout", NOTIF_CONTAINER)
		NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
		NotifLayout.Padding = UDim.new(0, 8)
	end
	return SCREEN_GUI
end

function ZeptoUI:AddCollapseKeybind(key)
	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == key then
			UI_OPEN = not UI_OPEN
			local targetTrans = UI_OPEN and 0.5 or 1
			local targetBlur = UI_OPEN and 10 or 0

			TweenService:Create(OVERLAY, TweenInfo.new(0.3), {BackgroundTransparency = targetTrans}):Play()
			TweenService:Create(BLUR, TweenInfo.new(0.3), {Size = targetBlur}):Play()

			for _, win in pairs(WINDOWS) do
				win.Visible = UI_OPEN
			end
		end
	end)
end

local function makeDraggable(frame, handle)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

function ZeptoUI:Notify(title, text, duration)
	if not SCREEN_GUI then self:Init() end
	duration = duration or 5

	local Notif = Instance.new("Frame")
	Notif.Size = UDim2.new(1, 0, 0, 0) -- Начинаем с нулевой высоты для анимации
	Notif.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	Notif.BorderSizePixel = 0
	Notif.ClipsDescendants = true
	Notif.Parent = NOTIF_CONTAINER

	-- Полоска сбоку (Акцентная)
	local SideBar = Instance.new("Frame")
	SideBar.Size = UDim2.new(0, 4, 1, 0)
	SideBar.BackgroundColor3 = CONFIG.AccentColor
	SideBar.BorderSizePixel = 0
	SideBar.Parent = Notif

	local Tlabel = Instance.new("TextLabel")
	Tlabel.Size = UDim2.new(1, -15, 0, 25)
	Tlabel.Position = UDim2.new(0, 12, 0, 5)
	Tlabel.Text = title:upper()
	Tlabel.Font = Enum.Font.GothamBold
	Tlabel.TextColor3 = Color3.new(1, 1, 1)
	Tlabel.TextSize = 14
	Tlabel.TextXAlignment = Enum.TextXAlignment.Left
	Tlabel.BackgroundTransparency = 1
	Tlabel.Parent = Notif

	local Dlabel = Instance.new("TextLabel")
	Dlabel.Size = UDim2.new(1, -15, 0, 0)
	Dlabel.Position = UDim2.new(0, 12, 0, 28)
	Dlabel.AutomaticSize = Enum.AutomaticSize.Y
	Dlabel.Text = text
	Dlabel.Font = Enum.Font.Gotham
	Dlabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	Dlabel.TextSize = 13
	Dlabel.TextXAlignment = Enum.TextXAlignment.Left
	Dlabel.TextWrapped = true
	Dlabel.BackgroundTransparency = 1
	Dlabel.Parent = Notif

	-- Анимация появления
	TweenService:Create(Notif, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, 65)}):Play()

	-- Удаление по таймеру
	task.delay(duration, function()
		local out = TweenService:Create(Notif, TweenInfo.new(0.4), {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
		out:Play()
		out.Completed:Connect(function()
			Notif:Destroy()
		end)
	end)
end

function ZeptoUI:CreateWindow(title, position)
	if not SCREEN_GUI then self:Init() end

	local MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, CONFIG.WindowWidth, 0, CONFIG.HeaderHeight)
	MainFrame.Position = position or UDim2.new(0, 100, 0, 100)
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	MainFrame.BorderSizePixel = 0
	MainFrame.AutomaticSize = Enum.AutomaticSize.Y
	MainFrame.ZIndex = 10
	MainFrame.Parent = SCREEN_GUI
	table.insert(WINDOWS, MainFrame)

	local Header = Instance.new("TextLabel")
	Header.Size = UDim2.new(1, 0, 0, CONFIG.HeaderHeight)
	Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	Header.Text = title:upper()
	Header.TextColor3 = Color3.new(1, 1, 1)
	Header.Font = Enum.Font.GothamBold
	Header.TextSize = CONFIG.FontSize + 2
	Header.ZIndex = 11
	Header.BorderSizePixel = 0
	Header.Parent = MainFrame

	local Container = Instance.new("Frame")
	Container.Size = UDim2.new(1, 0, 0, 0)
	Container.Position = UDim2.new(0, 0, 0, CONFIG.HeaderHeight)
	Container.AutomaticSize = Enum.AutomaticSize.Y
	Container.BackgroundTransparency = 1
	Container.ZIndex = 10
	Container.Parent = MainFrame
	
	local Line = Instance.new("Frame")
	Line.Size = UDim2.new(1, 0, 0, 2)
	Line.Position = UDim2.new(0, 0, 1, 0)
	Line.BackgroundColor3 = CONFIG.AccentColor -- Тот самый синий/оранжевый
	Line.BorderSizePixel = 0
	Line.ZIndex = 12
	Line.Parent = Header

	-- Добавим UIStroke для четкости (если еще не добавил)
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 1
	Stroke.Color = Color3.fromRGB(45, 45, 45)
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Parent = MainFrame

	local Layout = Instance.new("UIListLayout", Container)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder

	makeDraggable(MainFrame, Header)

	-- Плавное сворачивание категории (ПКМ)
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			Container.Visible = not Container.Visible
			MainFrame.AutomaticSize = Container.Visible and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
			if not Container.Visible then
				TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, CONFIG.WindowWidth, 0, CONFIG.HeaderHeight)}):Play()
			end
		end
	end)

	local WindowFunctions = {}

	function WindowFunctions:AddButton(name, callback)
		local Button = Instance.new("TextButton")
		Button.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)
		Button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		Button.Text = name
		Button.TextColor3 = Color3.new(1, 1, 1)
		Button.TextSize = CONFIG.FontSize
		Button.Font = Enum.Font.Gotham
		Button.BorderSizePixel = 0
		Button.ZIndex = 15
		Button.Parent = Container

		Button.MouseButton1Click:Connect(callback)
		Button.MouseEnter:Connect(function() 
			TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
		end)
		Button.MouseLeave:Connect(function() 
			TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 28, 28)}):Play()
		end)
	end

	function WindowFunctions:AddToggle(name, callback)
		local toggled = false
		local TButton = Instance.new("TextButton")
		TButton.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)
		TButton.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		TButton.Text = "  " .. name
		TButton.TextColor3 = Color3.fromRGB(180, 180, 180)
		TButton.TextXAlignment = Enum.TextXAlignment.Left
		TButton.TextSize = CONFIG.FontSize
		TButton.Font = Enum.Font.Gotham
		TButton.ZIndex = 15
		TButton.BorderSizePixel = 0
		TButton.Parent = Container

		local Ind = Instance.new("Frame")
		Ind.Size = UDim2.new(0, CONFIG.ItemHeight * 0.5, 0, CONFIG.ItemHeight * 0.5)
		Ind.Position = UDim2.new(1, -(CONFIG.ItemHeight * 0.8), 0.5, -(CONFIG.ItemHeight * 0.25))
		Ind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		Ind.ZIndex = 15
		Ind.BorderSizePixel = 0
		Ind.Parent = TButton

		TButton.MouseButton1Click:Connect(function()
			toggled = not toggled
			local color = toggled and CONFIG.AccentColor or Color3.fromRGB(50, 50, 50)
			local txtColor = toggled and Color3.new(1,1,1) or Color3.fromRGB(180, 180, 180)

			TweenService:Create(Ind, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
			TweenService:Create(TButton, TweenInfo.new(0.2), {TextColor3 = txtColor}):Play()
			callback(toggled)
		end)
	end

	function WindowFunctions:AddSlider(name, min, max, default, callback)
		local dragging = false
		local SliderFrame = Instance.new("Frame")
		SliderFrame.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight * 1.6)
		SliderFrame.BackgroundTransparency = 1
		SliderFrame.ZIndex = 15
		SliderFrame.Parent = Container

		local Title = Instance.new("TextLabel")
		Title.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight * 0.7)
		Title.Position = UDim2.new(0, 10, 0, 5)
		Title.Text = name .. ": " .. default
		Title.TextColor3 = Color3.new(1, 1, 1)
		Title.TextSize = CONFIG.FontSize - 2
		Title.BackgroundTransparency = 1
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Font = Enum.Font.Gotham
		Title.Parent = SliderFrame
		Title.ZIndex = 16

		local Back = Instance.new("Frame")
		Back.Size = UDim2.new(1, -20, 0, 4)
		Back.Position = UDim2.new(0.5, 0, 0, CONFIG.ItemHeight * 1.1)
		Back.AnchorPoint = Vector2.new(0.5, 0)
		Back.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		Back.BorderSizePixel = 0
		Back.Parent = SliderFrame
		Back.ZIndex = 17

		local Fill = Instance.new("Frame")
		Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
		Fill.BackgroundColor3 = CONFIG.AccentColor
		Fill.BorderSizePixel = 0
		Fill.Parent = Back
		Fill.ZIndex = 18

		local function update(input)
			local pos = math.clamp((input.Position.X - Back.AbsolutePosition.X) / Back.AbsoluteSize.X, 0, 1)
			TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new(pos, 0, 1, 0)}):Play()
			local val = math.floor(min + (max - min) * pos)
			Title.Text = name .. ": " .. val
			callback(val)
		end

		Back.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update(input) end end)
		UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end end)
		UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	end

	function WindowFunctions:AddDropdown(name, list, callback)
		local dropped = false
		local DropFrame = Instance.new("Frame")
		DropFrame.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)
		DropFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		DropFrame.ClipsDescendants = true
		DropFrame.ZIndex = 15
		DropFrame.Parent = Container

		local Button = Instance.new("TextButton")
		Button.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)
		Button.BackgroundTransparency = 1
		Button.Text = "  " .. name .. "  ▼"
		Button.TextColor3 = Color3.new(1, 1, 1)
		Button.TextSize = CONFIG.FontSize
		Button.Font = Enum.Font.Gotham
		Button.TextXAlignment = Enum.TextXAlignment.Left
		Button.Parent = DropFrame
		Button.ZIndex =16

		local ListContainer = Instance.new("Frame")
		ListContainer.Size = UDim2.new(1, 0, 0, #list * CONFIG.ItemHeight)
		ListContainer.Position = UDim2.new(0, 0, 0, CONFIG.ItemHeight)
		ListContainer.BackgroundTransparency = 1
		ListContainer.Parent = DropFrame
		Instance.new("UIListLayout", ListContainer)

		for _, v in pairs(list) do
			local Option = Instance.new("TextButton")
			Option.Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)
			Option.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			Option.Text = v
			Option.TextColor3 = Color3.fromRGB(200, 200, 200)
			Option.TextSize = CONFIG.FontSize - 2
			Option.Font = Enum.Font.Gotham
			Option.BorderSizePixel = 0
			Option.ZIndex = 17
			Option.Parent = ListContainer
			Option.MouseButton1Click:Connect(function()
				Button.Text = "  " .. name .. ": " .. v .. "  ▼"
				dropped = false
				TweenService:Create(DropFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, CONFIG.ItemHeight)}):Play()
				callback(v)
			end)
		end

		Button.MouseButton1Click:Connect(function()
			dropped = not dropped
			local targetH = dropped and (CONFIG.ItemHeight + (#list * CONFIG.ItemHeight)) or CONFIG.ItemHeight
			TweenService:Create(DropFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
		end)
	end

	return WindowFunctions
end

return ZeptoUI
