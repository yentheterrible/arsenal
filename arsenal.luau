local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "This client script must run after the local player is available")

local UI_SOURCE_URL = "https://raw.githubusercontent.com/yentheterrible/ui/refs/heads/main/init.lua"
assert(type(loadstring) == "function", "This environment must provide loadstring to load the Havoc UI")
local uiSource = game:HttpGet(UI_SOURCE_URL)
assert(type(uiSource) == "string" and uiSource ~= "", "The Havoc UI request returned an empty response")
local uiChunk, loadError = loadstring(uiSource)
assert(type(uiChunk) == "function", "Could not compile the Havoc UI: " .. tostring(loadError))
local loaded, HavocLib = pcall(uiChunk)
assert(loaded, "Could not initialize the Havoc UI: " .. tostring(HavocLib))
assert(type(HavocLib) == "table" and type(HavocLib.new) == "function", "The downloaded Havoc UI has an invalid API")

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
for _, guiName in ipairs({ "HavocPublicClient", "HavocPracticeClient" }) do
	local previousGui = playerGui:FindFirstChild(guiName)
	if previousGui then
		previousGui:Destroy()
	end
end

local Window = HavocLib.new({
	Name = "HavocPublicClient",
	Title = "havoc",
	Subtitle = "public release + arsenal pack",
	Version = "v1.1.0",
	Size = UDim2.fromOffset(560, 460),
})

-- ===================== CORE STATE =====================
local running = true
local connections = {}
local function track(connection)
	table.insert(connections, connection)
	return connection
end
local function disconnect(connection)
	if connection then connection:Disconnect() end
end

local function getCharacter(player) return player and player.Character end
local function getHumanoid(character) return character and character:FindFirstChildOfClass("Humanoid") end
local function getRoot(player)
	local character = getCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end
local function isAlive(player)
	if not player or player == LocalPlayer or player.Parent ~= Players then return false end
	local humanoid = getHumanoid(getCharacter(player))
	return humanoid ~= nil and humanoid.Health > 0
end

-- ===================== TABS =====================
local Combat = Window:Tab({ Name = "combat", Icon = "target" })
local AimSection = Combat:Section({ Name = "aimlock", Icon = "aimbot" })

local Visuals = Window:Tab({ Name = "visuals", Icon = "eye" })
local VisualSection = Visuals:Section({ Name = "esp", Icon = "esp" })
local HitboxSection = Visuals:Section({ Name = "hitbox", Icon = "box" })
local ExtraESPSection = Visuals:Section({ Name = "object esp", Icon = "package" })

local Movement = Window:Tab({ Name = "movement", Icon = "movement" })
local FlySection = Movement:Section({ Name = "fly", Icon = "plane" })
local SpeedSection = Movement:Section({ Name = "speed / jump", Icon = "zap" })
local AntiAimSection = Movement:Section({ Name = "anti aim", Icon = "rotate-cw" })

local Gun = Window:Tab({ Name = "gun mods", Icon = "crosshair" })
local GunSection = Gun:Section({ Name = "weapon", Icon = "gun" })

local Skins = Window:Tab({ Name = "skins", Icon = "palette" })
local ArmSection = Skins:Section({ Name = "arms / gun", Icon = "shirt" })
local RainbowSection = Skins:Section({ Name = "rainbow", Icon = "sparkles" })

local Misc = Window:Tab({ Name = "misc", Icon = "layers" })
local ExtraSection = Misc:Section({ Name = "extra", Icon = "star" })
local PerformanceSection = Misc:Section({ Name = "performance", Icon = "cpu" })
local ServerSection = Misc:Section({ Name = "server", Icon = "server" })

local Credits = Window:Tab({ Name = "credits", Icon = "info" })
local CreditsSection = Credits:Section({ Name = "credits", Icon = "sparkles" })
CreditsSection:Paragraph({ Name = "convict + arsenal pack", Content = "havoc base + advancefalling features merged" })

-- ===================== AIMLOCK (original) =====================
local AimLockEnabled = false
local AimTarget = nil
local AimPartName = "HumanoidRootPart"
local AimRadius = 500
local AimSmoothness = 0.18
local AimPrediction = 0.12
local AimTeamCheck = true
local ShowAimFOV = true
local AIM_ACQUIRE_INTERVAL = 0.12
local nextAimAcquire = 0
local AimLockToggle

local AimOverlay = Instance.new("Frame")
AimOverlay.Name = "HavocAimOverlay"
AimOverlay.BackgroundTransparency = 1
AimOverlay.Size = UDim2.fromScale(1, 1)
AimOverlay.ZIndex = 20
AimOverlay.Parent = Window.ScreenGui

local AimFOVRing = Instance.new("Frame")
AimFOVRing.Name = "AimFOVRing"
AimFOVRing.AnchorPoint = Vector2.new(0.5, 0.5)
AimFOVRing.BackgroundTransparency = 1
AimFOVRing.BorderSizePixel = 0
AimFOVRing.Visible = false
AimFOVRing.ZIndex = 20
AimFOVRing.Parent = AimOverlay
local AimFOVCorner = Instance.new("UICorner")
AimFOVCorner.CornerRadius = UDim.new(1, 0)
AimFOVCorner.Parent = AimFOVRing
local AimFOVStroke = Instance.new("UIStroke")
AimFOVStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
AimFOVStroke.Color = Color3.fromRGB(10, 132, 255)
AimFOVStroke.LineJoinMode = Enum.LineJoinMode.Round
AimFOVStroke.Thickness = 1.25
AimFOVStroke.Transparency = 0.28
AimFOVStroke.Parent = AimFOVRing

local AimStatus = Instance.new("Frame")
AimStatus.Name = "AimTargetStatus"
AimStatus.AnchorPoint = Vector2.new(0.5, 1)
AimStatus.BackgroundColor3 = Color3.fromRGB(18, 19, 22)
AimStatus.BackgroundTransparency = 0.08
AimStatus.BorderSizePixel = 0
AimStatus.Position = UDim2.new(0.5, 0, 1, -38)
AimStatus.Size = UDim2.fromOffset(208, 36)
AimStatus.Visible = false
AimStatus.ZIndex = 20
AimStatus.Parent = AimOverlay
local AimStatusCorner = Instance.new("UICorner")
AimStatusCorner.CornerRadius = UDim.new(0, 12)
AimStatusCorner.Parent = AimStatus
local AimStatusStroke = Instance.new("UIStroke")
AimStatusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
AimStatusStroke.Color = Color3.fromRGB(255, 255, 255)
AimStatusStroke.Thickness = 1
AimStatusStroke.Transparency = 0.86
AimStatusStroke.Parent = AimStatus
local AimStatusDot = Instance.new("Frame")
AimStatusDot.Name = "StateIndicator"
AimStatusDot.AnchorPoint = Vector2.new(0, 0.5)
AimStatusDot.BackgroundColor3 = Color3.fromRGB(10, 132, 255)
AimStatusDot.BorderSizePixel = 0
AimStatusDot.Position = UDim2.new(0, 13, 0.5, 0)
AimStatusDot.Size = UDim2.fromOffset(8, 8)
AimStatusDot.ZIndex = 21
AimStatusDot.Parent = AimStatus
local AimStatusDotCorner = Instance.new("UICorner")
AimStatusDotCorner.CornerRadius = UDim.new(1, 0)
AimStatusDotCorner.Parent = AimStatusDot
local AimStatusText = Instance.new("TextLabel")
AimStatusText.Name = "StatusText"
AimStatusText.BackgroundTransparency = 1
AimStatusText.Font = Enum.Font.GothamMedium
AimStatusText.Position = UDim2.fromOffset(29, 0)
AimStatusText.Size = UDim2.new(1, -40, 1, 0)
AimStatusText.Text = "AIMLOCK  /  SEARCHING"
AimStatusText.TextColor3 = Color3.fromRGB(210, 212, 218)
AimStatusText.TextSize = 11
AimStatusText.TextTruncate = Enum.TextTruncate.AtEnd
AimStatusText.TextXAlignment = Enum.TextXAlignment.Left
AimStatusText.ZIndex = 21
AimStatusText.Parent = AimStatus

local function isEnemy(player)
	if not isAlive(player) then return false end
	if AimTeamCheck and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then return false end
	return true
end

local function getAimPart(character)
	if not character then return nil end
	local part = character:FindFirstChild(AimPartName)
	if part and part:IsA("BasePart") then return part end
	local fallback = character:FindFirstChild("HumanoidRootPart")
	if fallback and fallback:IsA("BasePart") then return fallback end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	return nil
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function isVisible(player, part)
	local camera = workspace.CurrentCamera
	local character = getCharacter(player)
	if not camera or not character or not part or not part:IsDescendantOf(character) then return false end
	raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }
	local origin = camera.CFrame.Position
	local direction = part.Position - origin
	if direction.Magnitude <= 0 then return true end
	local result = workspace:Raycast(origin, direction, raycastParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function getScreenDistance(camera, part)
	local position, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen or position.Z <= 0 then return nil end
	local inset = GuiService:GetGuiInset()
	local mousePosition = UserInputService:GetMouseLocation() - inset
	return (Vector2.new(position.X, position.Y) - mousePosition).Magnitude
end

local function canKeepAimTarget(player)
	if not isEnemy(player) then return false end
	local camera = workspace.CurrentCamera
	local part = getAimPart(getCharacter(player))
	return camera ~= nil and part ~= nil and isVisible(player, part)
end

local function isValidAimTarget(player)
	if not canKeepAimTarget(player) then return false end
	local camera = workspace.CurrentCamera
	local part = getAimPart(getCharacter(player))
	local distance = getScreenDistance(camera, part)
	return distance ~= nil and distance <= AimRadius
end

local function findClosestTarget()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local closestPlayer = nil
	local closestDistance = AimRadius
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isEnemy(player) then
			local part = getAimPart(getCharacter(player))
			if part then
				local distance = getScreenDistance(camera, part)
				if distance and distance < closestDistance and isVisible(player, part) then
					closestDistance = distance
					closestPlayer = player
				end
			end
		end
	end
	return closestPlayer
end

local function setAimLockEnabled(enabled)
	AimLockEnabled = enabled == true
	AimTarget = nil
	nextAimAcquire = 0
	if AimLockToggle and AimLockToggle.Value ~= AimLockEnabled then
		AimLockToggle:Set(AimLockEnabled, false)
	end
end

local function updateAimOverlay()
	local active = running and Window.Root.Visible and AimLockEnabled
	AimStatus.Visible = active
	AimFOVRing.Visible = active and ShowAimFOV
	if not active then return end
	local inset = GuiService:GetGuiInset()
	local mousePosition = UserInputService:GetMouseLocation() - inset
	AimFOVRing.Position = UDim2.fromOffset(mousePosition.X, mousePosition.Y)
	local diameter = math.floor(AimRadius * 2)
	AimFOVRing.Size = UDim2.fromOffset(diameter, diameter)
	local targetName = AimTarget and AimTarget.DisplayName
	if targetName then
		if #targetName > 18 then targetName = string.sub(targetName, 1, 17) .. "..." end
		AimStatusText.Text = "LOCKED  /  " .. string.upper(targetName)
		AimStatusText.TextColor3 = Color3.fromRGB(245, 245, 247)
		AimStatusDot.BackgroundColor3 = Color3.fromRGB(48, 209, 88)
		AimFOVStroke.Color = Color3.fromRGB(48, 209, 88)
	else
		AimStatusText.Text = "AIMLOCK  /  SEARCHING"
		AimStatusText.TextColor3 = Color3.fromRGB(210, 212, 218)
		AimStatusDot.BackgroundColor3 = Color3.fromRGB(10, 132, 255)
		AimFOVStroke.Color = Color3.fromRGB(10, 132, 255)
	end
end

local function updateAim(deltaTime)
	updateAimOverlay()
	if not AimLockEnabled then return end
	if not running or not Window.Root.Visible then return end
	local localHumanoid = getHumanoid(getCharacter(LocalPlayer))
	if not localHumanoid or localHumanoid.Health <= 0 or UserInputService:GetFocusedTextBox() then return end
	if AimTarget and not canKeepAimTarget(AimTarget) then AimTarget = nil end
	if not AimTarget and os.clock() >= nextAimAcquire then
		nextAimAcquire = os.clock() + AIM_ACQUIRE_INTERVAL
		AimTarget = findClosestTarget()
	end
	updateAimOverlay()
	local target = AimTarget
	local camera = workspace.CurrentCamera
	local part = target and getAimPart(getCharacter(target))
	if not camera or not part then return end
	local predictedPosition = part.Position + part.AssemblyLinearVelocity * AimPrediction
	local direction = predictedPosition - camera.CFrame.Position
	if direction.Magnitude <= 0 then return end
	local targetCFrame = CFrame.lookAt(camera.CFrame.Position, predictedPosition)
	local smoothness = math.clamp(AimSmoothness, 0, 1)
	local alpha = 1 - (1 - smoothness) ^ (math.max(deltaTime, 0) * 60)
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
end

AimLockToggle = AimSection:Toggle({ Name = "aimlock", Default = false, Callback = setAimLockEnabled })
AimSection:Keybind({
	Name = "aimlock key",
	Default = Enum.KeyCode.Q,
	Callback = function()
		if not running or not Window.Root.Visible then return end
		setAimLockEnabled(not AimLockEnabled)
	end,
})
AimSection:Dropdown({
	Name = "aim part",
	Options = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" },
	Default = AimPartName,
	Callback = function(value) AimPartName = value end,
})
AimSection:Toggle({
	Name = "team check",
	Default = AimTeamCheck,
	Callback = function(value)
		AimTeamCheck = value
		if AimTarget and not isEnemy(AimTarget) then AimTarget = nil end
	end,
})
AimSection:Toggle({
	Name = "show aimlock fov",
	Default = ShowAimFOV,
	Callback = function(value) ShowAimFOV = value updateAimOverlay() end,
})
AimSection:Slider({ Name = "aimlock fov", Min = 50, Max = 1500, Step = 25, Default = AimRadius, Callback = function(value) AimRadius = value end })
AimSection:Slider({ Name = "aim smoothness", Min = 0.05, Max = 1, Step = 0.01, Default = AimSmoothness, Callback = function(value) AimSmoothness = value end })
AimSection:Slider({ Name = "prediction", Min = 0, Max = 0.5, Step = 0.01, Default = AimPrediction, Callback = function(value) AimPrediction = value end })

-- ===================== PLAYER ESP (Highlight) =====================
local ESPEnabled = false
local ESPColor = Color3.fromRGB(170, 0, 255)
local ESPFillTransparency = 0.45
local Highlights = {}
local ESPConnections = {}
local ESPToggle

local function destroyHighlight(player)
	local highlight = Highlights[player]
	if highlight then
		Highlights[player] = nil
		highlight:Destroy()
	end
end

local function applyHighlightStyle(highlight)
	highlight.FillColor = ESPColor
	highlight.OutlineColor = ESPColor:Lerp(Color3.new(1, 1, 1), 0.58)
	highlight.FillTransparency = ESPFillTransparency
	highlight.OutlineTransparency = math.clamp(ESPFillTransparency * 0.35, 0, 0.7)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function setPlayerHighlight(player, character)
	if not running or not ESPEnabled or player == LocalPlayer or player.Parent ~= Players then
		destroyHighlight(player)
		return
	end
	if not character or player.Character ~= character or not character:IsDescendantOf(workspace) then
		destroyHighlight(player)
		return
	end
	local existing = Highlights[player]
	if existing and existing.Adornee == character and existing.Parent then
		applyHighlightStyle(existing)
		return
	end
	destroyHighlight(player)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HavocPublicHighlight"
	highlight.Adornee = character
	applyHighlightStyle(highlight)
	highlight.Parent = character
	Highlights[player] = highlight
end

local function unwatchPlayerESP(player)
	local playerConnections = ESPConnections[player]
	if playerConnections then
		disconnect(playerConnections.CharacterAdded)
		disconnect(playerConnections.CharacterRemoving)
		ESPConnections[player] = nil
	end
	destroyHighlight(player)
end

local function watchPlayerESP(player)
	if not ESPEnabled or player == LocalPlayer or player.Parent ~= Players then return end
	if not ESPConnections[player] then
		ESPConnections[player] = {
			CharacterAdded = player.CharacterAdded:Connect(function(character)
				task.defer(setPlayerHighlight, player, character)
			end),
			CharacterRemoving = player.CharacterRemoving:Connect(function(character)
				local highlight = Highlights[player]
				if highlight and highlight.Adornee == character then destroyHighlight(player) end
			end),
		}
	end
	setPlayerHighlight(player, player.Character)
end

local function setESPEnabled(enabled)
	ESPEnabled = enabled == true
	if ESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do watchPlayerESP(player) end
	else
		local players = {}
		for player in pairs(ESPConnections) do table.insert(players, player) end
		for player in pairs(Highlights) do
			if not table.find(players, player) then table.insert(players, player) end
		end
		for _, player in ipairs(players) do unwatchPlayerESP(player) end
	end
end

ESPToggle = VisualSection:Toggle({ Name = "player esp", Default = false, Callback = setESPEnabled })
VisualSection:ColorPicker({
	Name = "highlight color",
	Default = ESPColor,
	Callback = function(value)
		ESPColor = value
		for _, highlight in pairs(Highlights) do applyHighlightStyle(highlight) end
	end,
})
VisualSection:Slider({
	Name = "fill transparency",
	Min = 0, Max = 1, Step = 0.05, Default = ESPFillTransparency,
	Callback = function(value)
		ESPFillTransparency = value
		for _, highlight in pairs(Highlights) do applyHighlightStyle(highlight) end
	end,
})

-- Local player ESP; no third-party code is downloaded or executed.
local extraPlayerESP = {
	Enabled = false,
	Tracers = false,
	Names = false,
	Boxes = false,
	TeamMates = false,
	TeamColor = false,
	Color = Color3.fromRGB(255, 255, 255),
}
local extraPlayerESPElements = {}
local extraPlayerESPGui = Instance.new("ScreenGui")
extraPlayerESPGui.Name = "HavocExtraPlayerESP"
extraPlayerESPGui.IgnoreGuiInset = true
extraPlayerESPGui.ResetOnSpawn = false
extraPlayerESPGui.Parent = playerGui

local function clearExtraPlayerESP(player)
	local elements = extraPlayerESPElements[player]
	if not elements then return end
	extraPlayerESPElements[player] = nil
	for _, element in pairs(elements) do
		if element then element:Destroy() end
	end
end

local function getExtraESPColor(player)
	if extraPlayerESP.TeamColor and player.Team then
		return player.TeamColor.Color
	end
	return extraPlayerESP.Color
end

local function updateExtraPlayerESP()
	local camera = Workspace.CurrentCamera
	if not running or not extraPlayerESP.Enabled or not camera
		or not (extraPlayerESP.Tracers or extraPlayerESP.Names or extraPlayerESP.Boxes) then
		for player in pairs(extraPlayerESPElements) do clearExtraPlayerESP(player) end
		return
	end

	local present = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAlive(player)
			and (extraPlayerESP.TeamMates or player.Team ~= LocalPlayer.Team) then
			local character = player.Character
			local root = getRoot(player)
			if character and root then
				present[player] = true
				local elements = extraPlayerESPElements[player]
				if not elements or elements.Character ~= character then
					clearExtraPlayerESP(player)
					elements = { Character = character }
					extraPlayerESPElements[player] = elements
				end

				local color = getExtraESPColor(player)
				if extraPlayerESP.Boxes then
					if not elements.Box then
						elements.Box = Instance.new("Highlight")
						elements.Box.Name = "HavocPlayerBox"
						elements.Box.Adornee = character
						elements.Box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						elements.Box.Parent = extraPlayerESPGui
					end
					elements.Box.FillColor = color
					elements.Box.OutlineColor = color
					elements.Box.FillTransparency = 0.82
					elements.Box.OutlineTransparency = 0.12
				elseif elements.Box then
					elements.Box:Destroy()
					elements.Box = nil
				end

				if extraPlayerESP.Names then
					if not elements.Name then
						local billboard = Instance.new("BillboardGui")
						billboard.Name = "HavocPlayerName"
						billboard.Adornee = root
						billboard.AlwaysOnTop = true
						billboard.Size = UDim2.fromOffset(160, 24)
						billboard.StudsOffset = Vector3.new(0, 2.8, 0)
						billboard.Parent = extraPlayerESPGui
						local label = Instance.new("TextLabel")
						label.Name = "Label"
						label.BackgroundTransparency = 1
						label.Size = UDim2.fromScale(1, 1)
						label.Font = Enum.Font.GothamBold
						label.TextSize = 13
						label.TextStrokeTransparency = 0.35
						label.Parent = billboard
						elements.Name = billboard
					end
					local label = elements.Name:FindFirstChild("Label")
					if label then
						label.Text = player.DisplayName
						label.TextColor3 = color
					end
				elseif elements.Name then
					elements.Name:Destroy()
					elements.Name = nil
				end

				if extraPlayerESP.Tracers then
					if not elements.Tracer then
						local line = Instance.new("Frame")
						line.Name = "HavocPlayerTracer"
						line.AnchorPoint = Vector2.new(0, 0.5)
						line.BorderSizePixel = 0
						line.Parent = extraPlayerESPGui
						elements.Tracer = line
					end
					local screenPoint, onScreen = camera:WorldToViewportPoint(root.Position)
					local line = elements.Tracer
					if onScreen and screenPoint.Z > 0 then
						local origin = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
						local target = Vector2.new(screenPoint.X, screenPoint.Y)
						local delta = target - origin
						line.Position = UDim2.fromOffset(origin.X, origin.Y)
						line.Size = UDim2.fromOffset(delta.Magnitude, 2)
						line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
						line.BackgroundColor3 = color
						line.Visible = true
					else
						line.Visible = false
					end
				elseif elements.Tracer then
					elements.Tracer:Destroy()
					elements.Tracer = nil
				end
			end
		end
	end

	for player in pairs(extraPlayerESPElements) do
		if not present[player] then clearExtraPlayerESP(player) end
	end
end

local function setExtraPlayerESPOption(option, value)
	extraPlayerESP[option] = value
	updateExtraPlayerESP()
end

VisualSection:Toggle({
	Name = "tracers",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("Tracers", value) end,
})
VisualSection:Toggle({
	Name = "names",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("Names", value) end,
})
VisualSection:Toggle({
	Name = "boxes",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("Boxes", value) end,
})
VisualSection:Toggle({
	Name = "teammates",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("TeamMates", value) end,
})
VisualSection:Toggle({
	Name = "team color",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("TeamColor", value) end,
})
VisualSection:Toggle({
	Name = "enable player overlays",
	Default = false,
	Callback = function(value) setExtraPlayerESPOption("Enabled", value) end,
})
VisualSection:ColorPicker({
Name = "overlay color",
	Default = extraPlayerESP.Color,
	Callback = function(color)
		extraPlayerESP.Color = color
		updateExtraPlayerESP()
	end,
})
track(RunService.RenderStepped:Connect(updateExtraPlayerESP))

-- ===================== HITBOX =====================
local hitboxEnabled = false
local noCollisionEnabled = false
local hitbox_original_properties = {}
local hitboxSize = 21
local hitboxTransparency = 6
local hitboxTeamCheck = "FFA"
local defaultBodyParts = { "UpperTorso", "Head", "HumanoidRootPart" }
local hitboxPlayerConnections = {}

local function savedPart(player, part)
	if not hitbox_original_properties[player] then hitbox_original_properties[player] = {} end
	if not hitbox_original_properties[player][part.Name] then
		hitbox_original_properties[player][part.Name] = {
			CanCollide = part.CanCollide,
			Transparency = part.Transparency,
			Size = part.Size
		}
	end
end

local function restoredPart(player)
	if hitbox_original_properties[player] then
		for partName, properties in pairs(hitbox_original_properties[player]) do
			local part = player.Character and player.Character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.CanCollide = properties.CanCollide
				part.Transparency = properties.Transparency
				part.Size = properties.Size
			end
		end
	end
end

local function findClosestPart(player, partName)
	if not player.Character then return nil end
	for _, part in ipairs(player.Character:GetChildren()) do
		if part:IsA("BasePart") and part.Name:lower():match(partName:lower()) then
			return part
		end
	end
	return nil
end

local function extendHitbox(player)
	for _, partName in ipairs(defaultBodyParts) do
		local part = player.Character and (player.Character:FindFirstChild(partName) or findClosestPart(player, partName))
		if part and part:IsA("BasePart") then
			savedPart(player, part)
			part.CanCollide = not noCollisionEnabled
			part.Transparency = hitboxTransparency / 10
			part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
		end
	end
end

local function isHitboxEnemy(player)
	if hitboxTeamCheck == "FFA" or hitboxTeamCheck == "Everyone" then return true end
	return player.Team ~= LocalPlayer.Team
end

local function updateHitboxes()
	for _, v in ipairs(Players:GetPlayers()) do
		if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
			if isHitboxEnemy(v) then
				extendHitbox(v)
			else
				restoredPart(v)
			end
		end
	end
end

local function onCharacterAdded(character)
	task.wait(0.1)
	if hitboxEnabled then updateHitboxes() end
end

local function onPlayerAdded(player)
	if hitboxPlayerConnections[player] then return end
	hitboxPlayerConnections[player] = {
		CharacterAdded = player.CharacterAdded:Connect(onCharacterAdded),
		CharacterRemoving = player.CharacterRemoving:Connect(function()
		restoredPart(player)
		hitbox_original_properties[player] = nil
		end),
	}
end

track(Players.PlayerAdded:Connect(onPlayerAdded))
track(Players.PlayerRemoving:Connect(function(player)
	local playerConnections = hitboxPlayerConnections[player]
	if playerConnections then
		disconnect(playerConnections.CharacterAdded)
		disconnect(playerConnections.CharacterRemoving)
		hitboxPlayerConnections[player] = nil
	end
	restoredPart(player)
	hitbox_original_properties[player] = nil
end))
for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end

HitboxSection:Toggle({
	Name = "enable hitbox",
	Default = false,
	Callback = function(enabled)
		hitboxEnabled = enabled
		if not enabled then
			for _, player in ipairs(Players:GetPlayers()) do restoredPart(player) end
			hitbox_original_properties = {}
		else
			updateHitboxes()
		end
	end,
})

HitboxSection:Slider({
	Name = "hitbox size",
	Min = 1, Max = 25, Step = 1, Default = 21,
	Callback = function(value)
		hitboxSize = value
		if hitboxEnabled then updateHitboxes() end
	end,
})

HitboxSection:Slider({
	Name = "hitbox transparency",
	Min = 1, Max = 10, Step = 1, Default = 6,
	Callback = function(value)
		hitboxTransparency = value
		if hitboxEnabled then updateHitboxes() end
	end,
})

HitboxSection:Dropdown({
	Name = "team check",
	Options = { "FFA", "Team-Based", "Everyone" },
	Default = "FFA",
	Callback = function(value)
		hitboxTeamCheck = value
		if hitboxEnabled then updateHitboxes() end
	end,
})

HitboxSection:Toggle({
	Name = "no collision",
	Default = false,
	Callback = function(enabled)
		noCollisionEnabled = enabled
		if hitboxEnabled then updateHitboxes() end
	end,
})

-- continuous update loop for hitbox
track(RunService.Heartbeat:Connect(function()
	if hitboxEnabled then
		updateHitboxes()
	end
end))

-- ===================== OBJECT ESP (Ammo / HP) =====================
local esp_data = {}
local esp_title = "HavocObjectESP"
local objectESPStates = {}

local function createObjectESP(parent, label)
	local BillboardGui = Instance.new("BillboardGui")
	local TextLabel = Instance.new("TextLabel")
	BillboardGui.Name = esp_title
	BillboardGui.Parent = parent
	BillboardGui.AlwaysOnTop = true
	BillboardGui.Size = UDim2.new(0, 50, 0, 50)
	BillboardGui.StudsOffset = Vector3.new(0, 2, 0)
	TextLabel.Parent = BillboardGui
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, 0, 1, 0)
	TextLabel.Text = label
	TextLabel.TextColor3 = Color3.new(1, 0, 0)
	TextLabel.TextScaled = false
	return BillboardGui
end

local function applyObjectESP(object, label)
	if object:IsA("TouchTransmitter") and object.Parent then
		local parent = object.Parent
		if not parent:FindFirstChild(esp_title) then
			local newESP = createObjectESP(parent, label)
			esp_data[parent] = newESP
		end
	end
end

local function toggleObjectESP(enable, name, label)
	local state = objectESPStates[name]
	if enable then
		if state then return end
		state = { Elements = {} }
		objectESPStates[name] = state
		for _, v in ipairs(Workspace:GetDescendants()) do
			if v:IsA("TouchTransmitter") and v.Parent.Name == name then
				applyObjectESP(v, label)
				local element = v.Parent:FindFirstChild(esp_title)
				if element then state.Elements[v.Parent] = element end
			end
		end
		state.Connection = Workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("TouchTransmitter") and descendant.Parent and descendant.Parent.Name == name then
				applyObjectESP(descendant, label)
				local element = descendant.Parent:FindFirstChild(esp_title)
				if element then state.Elements[descendant.Parent] = element end
			end
		end)
	else
		if not state then return end
		disconnect(state.Connection)
		for parent, espElement in pairs(state.Elements) do
			if espElement then
				espElement:Destroy()
			end
			esp_data[parent] = nil
		end
		objectESPStates[name] = nil
	end
end

ExtraESPSection:Toggle({
	Name = "ammo box esp",
	Default = false,
	Callback = function(enabled) toggleObjectESP(enabled, "DeadAmmo", "Ammo Box") end,
})
ExtraESPSection:Toggle({
	Name = "hp jar esp",
	Default = false,
	Callback = function(enabled) toggleObjectESP(enabled, "DeadHP", "HP Jar") end,
})

-- ===================== FLY =====================
local flySettings = { fly = false, flyspeed = 50 }
local c, h, bv, bav, cam, flying
local flyDeathConnection
local p = LocalPlayer
local buttons = { W = false, S = false, A = false, D = false, Moving = false }
local flyKeys = { W = true, S = true, A = true, D = true }
local endFly

local function startFly()
	if not p.Character or not p.Character:FindFirstChild("Head") or flying then return false end
	c = p.Character
	h = getHumanoid(c)
	if not h then return false end
	h.PlatformStand = true
	cam = Workspace.CurrentCamera
	if not cam then
		h.PlatformStand = false
		return false
	end
	bv = Instance.new("BodyVelocity")
	bav = Instance.new("BodyAngularVelocity")
	bv.Velocity, bv.MaxForce, bv.P = Vector3.new(0, 0, 0), Vector3.new(10000, 10000, 10000), 1000
	bav.AngularVelocity, bav.MaxTorque, bav.P = Vector3.new(0, 0, 0), Vector3.new(10000, 10000, 10000), 1000
	bv.Parent = c.Head
	bav.Parent = c.Head
	flying = true
	if flyDeathConnection then flyDeathConnection:Disconnect() end
	flyDeathConnection = h.Died:Connect(function()
		endFly()
	end)
	return true
end

endFly = function()
	if h and h.Parent then h.PlatformStand = false end
	if bv then bv:Destroy() end
	if bav then bav:Destroy() end
	if flyDeathConnection then
		flyDeathConnection:Disconnect()
		flyDeathConnection = nil
	end
	flying = false
	buttons.W, buttons.S, buttons.A, buttons.D, buttons.Moving = false, false, false, false, false
end

track(UserInputService.InputBegan:Connect(function(input, GPE)
	if GPE then return end
	for key in pairs(flyKeys) do
		if input.KeyCode == Enum.KeyCode[key] then
			buttons[key] = true
			buttons.Moving = true
			break
		end
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	local a = false
	for key in pairs(flyKeys) do
		if input.KeyCode == Enum.KeyCode[key] then buttons[key] = false end
		if buttons[key] then a = true end
	end
	buttons.Moving = a
end))

local function setVec(vec)
	if vec.Magnitude <= 1e-6 then return Vector3.zero end
	return vec.Unit * flySettings.flyspeed
end

track(RunService.Heartbeat:Connect(function(step)
	if flying and c and c.PrimaryPart then
		local pos = c.PrimaryPart.Position
		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then return end
		cam = currentCamera
		local cf = cam.CFrame
		local ax, ay, az = cf:toEulerAnglesXYZ()
		c:SetPrimaryPartCFrame(CFrame.new(pos.x, pos.y, pos.z) * CFrame.Angles(ax, ay, az))
		if buttons.Moving then
			local t = Vector3.new()
			if buttons.W then t = t + setVec(cf.lookVector) end
			if buttons.S then t = t - setVec(cf.lookVector) end
			if buttons.A then t = t - setVec(cf.rightVector) end
			if buttons.D then t = t + setVec(cf.rightVector) end
			c:TranslateBy(t * step)
		end
	end
end))

FlySection:Toggle({
	Name = "fly",
	Default = false,
	Callback = function(state)
		flySettings.fly = state
		if state then
			if not startFly() then
				flySettings.fly = false
				Window:Notify({ Title = "fly unavailable", Content = "A loaded character and camera are required.", Duration = 3 })
			end
		else
			endFly()
		end
	end,
})
FlySection:Slider({
	Name = "fly speed",
	Min = 1, Max = 500, Step = 1, Default = 50,
	Callback = function(s) flySettings.flyspeed = s end,
})

-- ===================== WALKSPEED / JUMP =====================
local settings = { WalkSpeed = 16 }
local isWalkSpeedEnabled = false
local selectedWalkMethod = "Velocity"
local isJumpPowerEnabled = false
local selectedJumpMethod = "Velocity"
local IJ = false
local jumpPowerValue = 50

SpeedSection:Toggle({
	Name = "custom walkspeed",
	Default = false,
	Callback = function(enabled) isWalkSpeedEnabled = enabled end,
})
SpeedSection:Dropdown({
	Name = "walk method",
	Options = { "Velocity", "Vector", "CFrame" },
	Default = "Velocity",
	Callback = function(selected) selectedWalkMethod = selected end,
})
SpeedSection:Slider({
	Name = "walkspeed power",
	Min = 16, Max = 500, Step = 1, Default = 16,
	Callback = function(value) settings.WalkSpeed = value end,
})

local function wsm(player, deltaTime)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart then
		local VS = humanoid.MoveDirection * settings.WalkSpeed
		if selectedWalkMethod == "Velocity" then
			rootPart.Velocity = Vector3.new(VS.X, rootPart.Velocity.Y, VS.Z)
		elseif selectedWalkMethod == "Vector" or selectedWalkMethod == "CFrame" then
			rootPart.CFrame += humanoid.MoveDirection * settings.WalkSpeed * deltaTime
		else
			humanoid.WalkSpeed = settings.WalkSpeed
		end
	end
end

track(RunService.Stepped:Connect(function(_, deltaTime)
	if isWalkSpeedEnabled then
		local player = LocalPlayer
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			wsm(player, deltaTime)
		end
	end
end))

SpeedSection:Toggle({
	Name = "infinite jump",
	Default = false,
	Callback = function(state)
		IJ = state
	end,
})

track(UserInputService.JumpRequest:Connect(function()
	if IJ then
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

SpeedSection:Toggle({
	Name = "custom jumppower",
	Default = false,
	Callback = function(enabled) isJumpPowerEnabled = enabled end,
})
SpeedSection:Dropdown({
	Name = "jump method",
	Options = { "Velocity", "Vector", "CFrame" },
	Default = "Velocity",
	Callback = function(selected) selectedJumpMethod = selected end,
})
SpeedSection:Slider({
	Name = "jumppower",
	Min = 30, Max = 500, Step = 1, Default = 50,
	Callback = function(value) jumpPowerValue = value end,
})

-- jump power application
local jumpConnection
local function bindJumpPower(char)
	disconnect(jumpConnection)
	local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.UseJumpPower = true
	jumpConnection = humanoid.Jumping:Connect(function(isActive)
		if isJumpPowerEnabled and isActive then
			local rootPart = char:FindFirstChild("HumanoidRootPart")
			if rootPart then
				if selectedJumpMethod == "Velocity" then
					rootPart.Velocity = rootPart.Velocity * Vector3.new(1, 0, 1) + Vector3.new(0, jumpPowerValue, 0)
				elseif selectedJumpMethod == "Vector" then
					rootPart.AssemblyLinearVelocity = Vector3.new(
						rootPart.AssemblyLinearVelocity.X,
						jumpPowerValue,
						rootPart.AssemblyLinearVelocity.Z
					)
				elseif selectedJumpMethod == "CFrame" then
					char:PivotTo(char:GetPivot() + Vector3.new(0, math.min(jumpPowerValue * 0.05, 25), 0))
				end
			end
		end
	end)
end
track(LocalPlayer.CharacterAdded:Connect(bindJumpPower))
if LocalPlayer.Character then bindJumpPower(LocalPlayer.Character) end

-- ===================== ANTI AIM =====================
local spinSpeed = 10
local gyro
local antiAimSpin
local antiAimEnabled = false

local function setAntiAimEnabled(value)
	antiAimEnabled = value == true
	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if antiAimSpin then antiAimSpin:Destroy() antiAimSpin = nil end
	if gyro then gyro:Destroy() gyro = nil end
	if not antiAimEnabled or not rootPart then return end

	antiAimSpin = Instance.new("BodyAngularVelocity")
	antiAimSpin.Name = "AntiAimSpin"
	antiAimSpin.AngularVelocity = Vector3.new(0, spinSpeed, 0)
	antiAimSpin.MaxTorque = Vector3.new(0, math.huge, 0)
	antiAimSpin.P = 500000
	antiAimSpin.Parent = rootPart
	gyro = Instance.new("BodyGyro")
	gyro.Name = "AntiAimGyro"
	gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	gyro.CFrame = rootPart.CFrame
	gyro.P = 3000
	gyro.Parent = rootPart
end

AntiAimSection:Toggle({
	Name = "anti-aim spin",
	Default = false,
	Callback = setAntiAimEnabled,
})
AntiAimSection:Slider({
	Name = "spin speed",
	Min = 10, Max = 100, Step = 1, Default = 10,
	Callback = function(value)
		spinSpeed = value
		local character = LocalPlayer.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and antiAimSpin and antiAimSpin.Parent == humanoidRootPart then
			antiAimSpin.AngularVelocity = Vector3.new(0, spinSpeed, 0)
		end
	end,
})

-- ===================== GUN MODS (Arsenal specific) =====================
local originalValues = {
	FireRate = {},
	ReloadTime = {},
	EReloadTime = {},
	Auto = {},
	Spread = {},
	Recoil = {}
}

GunSection:Toggle({
	Name = "infinite ammo v1",
	Default = false,
	Callback = function(v)
		local workspaceData = ReplicatedStorage:FindFirstChild("wkspc")
		local currentCurse = workspaceData and workspaceData:FindFirstChild("CurrentCurse")
		if not currentCurse or not currentCurse:IsA("StringValue") then
			Window:Notify({ Title = "infinite ammo unavailable", Content = "The game did not expose CurrentCurse.", Duration = 3 })
			return
		end
		if v then
			if originalValues.CurrentCurse == nil then
				originalValues.CurrentCurse = currentCurse.Value
			end
			currentCurse.Value = "Infinite Ammo"
		elseif originalValues.CurrentCurse ~= nil then
			currentCurse.Value = originalValues.CurrentCurse
			originalValues.CurrentCurse = nil
		end
	end,
})

local function applyWeaponValues(category, matches, enabled, forcedValue)
	local weapons = ReplicatedStorage:FindFirstChild("Weapons")
	if not weapons then
		Window:Notify({ Title = "weapon values unavailable", Content = "ReplicatedStorage.Weapons was not found.", Duration = 3 })
		return
	end
	local originals = originalValues[category]
	for _, valueObject in ipairs(weapons:GetDescendants()) do
		local compatibleValue = (type(forcedValue) == "number"
				and (valueObject:IsA("IntValue") or valueObject:IsA("NumberValue")))
			or (type(forcedValue) == "boolean" and valueObject:IsA("BoolValue"))
		if compatibleValue and matches[valueObject.Name] then
			if enabled then
				if originals[valueObject] == nil then
					originals[valueObject] = valueObject.Value
				end
				valueObject.Value = forcedValue
			elseif originals[valueObject] ~= nil then
				valueObject.Value = originals[valueObject]
				originals[valueObject] = nil
			end
		end
	end
end

local SettingsInfinite = false
local infiniteAmmoConnection
local infiniteAmmoOriginals = {}

local function getInfiniteAmmoValues()
	local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local client = gui and gui:FindFirstChild("GUI")
	local variables = client and client:FindFirstChild("Client")
		and client.Client:FindFirstChild("Variables")
	local ammo = variables and variables:FindFirstChild("ammocount")
	local reserve = variables and variables:FindFirstChild("ammocount2")
	local function isNumericValue(value)
		return value and (value:IsA("IntValue") or value:IsA("NumberValue"))
	end
	if isNumericValue(ammo) and isNumericValue(reserve) then
		return ammo, reserve
	end
	return nil
end

local function restoreInfiniteAmmo()
	local ammo, reserve = getInfiniteAmmoValues()
	if ammo and infiniteAmmoOriginals.Ammo ~= nil then
		ammo.Value = infiniteAmmoOriginals.Ammo
	end
	if reserve and infiniteAmmoOriginals.Reserve ~= nil then
		reserve.Value = infiniteAmmoOriginals.Reserve
	end
	infiniteAmmoOriginals = {}
end

GunSection:Toggle({
	Name = "infinite ammo v2",
	Default = false,
	Callback = function(K)
		SettingsInfinite = K
		if SettingsInfinite then
			if not infiniteAmmoConnection then
				infiniteAmmoConnection = track(RunService.Stepped:Connect(function()
					local ammo, reserve = getInfiniteAmmoValues()
					if SettingsInfinite and ammo and reserve then
						if infiniteAmmoOriginals.Ammo == nil then
							infiniteAmmoOriginals.Ammo = ammo.Value
							infiniteAmmoOriginals.Reserve = reserve.Value
						end
						ammo.Value = 99
						reserve.Value = 99
					end
				end))
			end
		elseif infiniteAmmoConnection then
			infiniteAmmoConnection:Disconnect()
			infiniteAmmoConnection = nil
			restoreInfiniteAmmo()
		end
	end,
})

GunSection:Toggle({
	Name = "fast reload",
	Default = false,
	Callback = function(x)
		applyWeaponValues("ReloadTime", { ReloadTime = true }, x, 0.01)
		applyWeaponValues("EReloadTime", { EReloadTime = true }, x, 0.01)
	end,
})

GunSection:Toggle({
	Name = "fast fire rate",
	Default = false,
	Callback = function(state)
		applyWeaponValues("FireRate", { FireRate = true, BFireRate = true }, state, 0.02)
	end,
})

GunSection:Toggle({
	Name = "always auto",
	Default = false,
	Callback = function(state)
		applyWeaponValues("Auto", {
			Auto = true,
			AutoFire = true,
			Automatic = true,
			AutoShoot = true,
			AutoGun = true,
		}, state, true)
	end,
})

GunSection:Toggle({
	Name = "no spread",
	Default = false,
	Callback = function(state)
		applyWeaponValues("Spread", { MaxSpread = true, Spread = true, SpreadControl = true }, state, 0)
	end,
})

GunSection:Toggle({
	Name = "no recoil",
	Default = false,
	Callback = function(state)
		applyWeaponValues("Recoil", { RecoilControl = true, Recoil = true }, state, 0)
	end,
})

-- ===================== SKINS / CHARMS =====================
local armMaterial = "Plastic"
local armColor = Color3.fromRGB(50, 50, 50)
local armCharms = false
local armCharmGeneration = 0
local armOriginalAppearance = {}
local gunMaterial = "Plastic"
local gunColor = Color3.fromRGB(50, 50, 50)
local gunCharms = false
local gunCharmGeneration = 0
local gunOriginalAppearance = {}
local rainbowEnabled = false
local rainbowHue = 0
local rainbowOriginalColors = {}

local function restoreAppearance(originals)
	for instance, properties in pairs(originals) do
		if instance.Parent then
			for propertyName, value in pairs(properties) do
				instance[propertyName] = value
			end
		end
		originals[instance] = nil
	end
end

local function toVertexColor(c)
	return Vector3.new(c.R, c.G, c.B)
end

ArmSection:Dropdown({
	Name = "arm material",
	Options = { "Plastic", "ForceField", "Wood", "Grass" },
	Default = "Plastic",
	Callback = function(v) armMaterial = v end,
})
ArmSection:ColorPicker({
	Name = "arm color",
	Default = Color3.fromRGB(50, 50, 50),
	Callback = function(c) armColor = c end,
})
ArmSection:Toggle({
	Name = "arm charms",
	Default = false,
	Callback = function(L)
		armCharms = L
		armCharmGeneration += 1
		local generation = armCharmGeneration
		if armCharms then
			task.spawn(function()
				while running and armCharms and generation == armCharmGeneration do
					task.wait(0.01)
					if not running or not armCharms or generation ~= armCharmGeneration then break end
					local camera = Workspace.CurrentCamera
					local cameraArms = camera and camera:FindFirstChild("Arms")
					if cameraArms then
						for _, O in pairs(cameraArms:GetDescendants()) do
							if O.Name == "Right Arm" or O.Name == "Left Arm" then
								if O:IsA("BasePart") then
									if not armOriginalAppearance[O] then
										armOriginalAppearance[O] = { Material = O.Material, Color = O.Color }
									end
									O.Material = Enum.Material[armMaterial]
									O.Color = armColor
								end
							elseif O:IsA("SpecialMesh") then
								if O.TextureId == "" then
									if not armOriginalAppearance[O] then
										armOriginalAppearance[O] = { VertexColor = O.VertexColor }
									end
									O.VertexColor = toVertexColor(armColor)
								end
							end
						end
					end
				end
			end)
		else
			restoreAppearance(armOriginalAppearance)
		end
	end,
})

ArmSection:Dropdown({
	Name = "gun material",
	Options = { "Plastic", "ForceField", "Wood", "Grass" },
	Default = "Plastic",
	Callback = function(v) gunMaterial = v end,
})
ArmSection:ColorPicker({
	Name = "gun color",
	Default = Color3.fromRGB(50, 50, 50),
	Callback = function(c) gunColor = c end,
})
ArmSection:Toggle({
	Name = "gun charms",
	Default = false,
	Callback = function(L)
		gunCharms = L
		gunCharmGeneration += 1
		local generation = gunCharmGeneration
		if gunCharms then
			task.spawn(function()
				while running and gunCharms and generation == gunCharmGeneration do
					task.wait(0.01)
					if not running or not gunCharms or generation ~= gunCharmGeneration then break end
					local camera = Workspace.CurrentCamera
					local arms = camera and camera:FindFirstChild("Arms")
					if arms then
						for _, O in pairs(arms:GetDescendants()) do
							if O:IsA("MeshPart") then
								if not gunOriginalAppearance[O] then
									gunOriginalAppearance[O] = { Material = O.Material, Color = O.Color }
								end
								O.Material = Enum.Material[gunMaterial]
								O.Color = gunColor
							end
						end
					end
				end
			end)
		else
			restoreAppearance(gunOriginalAppearance)
		end
	end,
})

RainbowSection:Toggle({
	Name = "rainbow gun",
	Default = false,
	Callback = function(state)
		rainbowEnabled = state
		if not state then restoreAppearance(rainbowOriginalColors) end
	end,
})

track(RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	local arms = camera and camera:FindFirstChild("Arms")
	if rainbowEnabled and arms then
		rainbowHue = (rainbowHue + 0.01) % 1
		for _, v in pairs(arms:GetDescendants()) do
			if v:IsA("MeshPart") then
				if not rainbowOriginalColors[v] then
					rainbowOriginalColors[v] = { Color = v.Color }
				end
				v.Color = Color3.fromHSV(rainbowHue, 1, 1)
			end
		end
	end
end))

-- ===================== MISC / EXTRA =====================
-- Xray
local xrayOn = false
local xrayOriginalTransparency = {}
local xrayDescendantConnection
local function setXray(enabled)
	xrayOn = enabled == true
	if xrayOn then
		local function applyXray(instance)
			if instance:IsA("BasePart") then
				if xrayOriginalTransparency[instance] == nil then
					xrayOriginalTransparency[instance] = instance.Transparency
				end
				instance.Transparency = 0.5
			end
		end
		for _, descendant in ipairs(Workspace:GetDescendants()) do applyXray(descendant) end
		if not xrayDescendantConnection then
			xrayDescendantConnection = Workspace.DescendantAdded:Connect(applyXray)
		end
	else
		if xrayDescendantConnection then
			xrayDescendantConnection:Disconnect()
			xrayDescendantConnection = nil
		end
		for part, transparency in pairs(xrayOriginalTransparency) do
			if part.Parent then part.Transparency = transparency end
			xrayOriginalTransparency[part] = nil
		end
	end
end
ExtraSection:Toggle({
	Name = "xray",
	Default = false,
	Callback = setXray,
})

-- Fullbright
local fullBrightEnabled = false
local originalFullBright
local function setFullBright(enabled)
	if enabled and not fullBrightEnabled then
		originalFullBright = {
			Ambient = Lighting.Ambient,
			ColorShift_Bottom = Lighting.ColorShift_Bottom,
			ColorShift_Top = Lighting.ColorShift_Top,
		}
		fullBrightEnabled = true
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
		Lighting.ColorShift_Top = Color3.new(1, 1, 1)
	elseif not enabled and fullBrightEnabled then
		Lighting.Ambient = originalFullBright.Ambient
		Lighting.ColorShift_Bottom = originalFullBright.ColorShift_Bottom
		Lighting.ColorShift_Top = originalFullBright.ColorShift_Top
		fullBrightEnabled = false
		originalFullBright = nil
	end
end
ExtraSection:Toggle({
	Name = "full bright",
	Default = false,
	Callback = setFullBright,
})

-- Screen particles mess
local particleOriginalParents = {}
local function setParticleMess(enabled)
	if enabled then
		for _, emitter in ipairs(game:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				if particleOriginalParents[emitter] == nil then
					particleOriginalParents[emitter] = emitter.Parent
				end
				local character = LocalPlayer.Character
				local particleArea = character and character:FindFirstChild("Particle Area")
				if particleArea then emitter.Parent = particleArea end
			end
		end
	else
		for emitter, originalParent in pairs(particleOriginalParents) do
			if emitter.Parent and originalParent and originalParent.Parent then
				emitter.Parent = originalParent
			end
			particleOriginalParents[emitter] = nil
		end
	end
end
ExtraSection:Toggle({
	Name = "mess up screen (particles)",
	Default = false,
	Callback = setParticleMess,
})

-- Fake role tags
local fakeTags = {}
local function toggleFakeTag(name, state)
	if state then
		if LocalPlayer:FindFirstChild(name) then return end
		local tag = Instance.new("IntValue")
		tag.Name = name
		tag.Parent = LocalPlayer
		fakeTags[name] = tag
	else
		local tag = fakeTags[name]
		fakeTags[name] = nil
		if tag then tag:Destroy() end
	end
end

ExtraSection:Toggle({ Name = "IsChad", Default = false, Callback = function(x) toggleFakeTag("IsChad", x) end })
ExtraSection:Toggle({ Name = "VIP", Default = false, Callback = function(x) toggleFakeTag("VIP", x) end })
ExtraSection:Toggle({ Name = "OldVIP", Default = false, Callback = function(x) toggleFakeTag("OldVIP", x) end })
ExtraSection:Toggle({ Name = "Romin", Default = false, Callback = function(x) toggleFakeTag("Romin", x) end })
ExtraSection:Toggle({ Name = "IsAdmin", Default = false, Callback = function(x) toggleFakeTag("IsAdmin", x) end })

-- Name change / killfeed
local runNameLoop = false
local nameLoopGeneration = 0
local nameOriginalValues = {}

local function setNameValue(instance, propertyName, value)
	if not instance then return end
	if propertyName == "Text" then
		if not instance:IsA("TextLabel") and not instance:IsA("TextButton") then return end
	elseif propertyName == "Value" then
		if not instance:IsA("StringValue") then return end
	else
		error("Unsupported name display property: " .. tostring(propertyName))
	end
	if nameOriginalValues[instance] == nil then
		nameOriginalValues[instance] = instance[propertyName]
	end
	instance[propertyName] = value
end

local function restoreNameValues()
	for instance, originalValue in pairs(nameOriginalValues) do
		if instance.Parent then
			local propertyName = instance:IsA("TextLabel") and "Text" or "Value"
			instance[propertyName] = originalValue
		end
		nameOriginalValues[instance] = nil
	end
end

ExtraSection:Toggle({
	Name = "change name / killfeed",
	Default = false,
	Callback = function(enabled)
		runNameLoop = enabled
		nameLoopGeneration += 1
		local generation = nameLoopGeneration
		if enabled then
			task.spawn(function()
				while running and runNameLoop and generation == nameLoopGeneration do
					local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
					local menu = gui and gui:FindFirstChild("Menew_Main")
					local container = menu and menu:FindFirstChild("Container")
					setNameValue(container and container:FindFirstChild("PlrName"), "Text", "Havoc")
					setNameValue(container and container:FindFirstChild("PlrName2"), "Text", "Havoc")
					for i = 1, 6 do
						local killFeed = Workspace:FindFirstChild("KillFeed")
						local entry = killFeed and killFeed:FindFirstChild(tostring(i))
						setNameValue(entry and entry:FindFirstChild("Killer"), "Value", "Havoc")
					end
					local scorecardGui = gui and gui:FindFirstChild("GUI_Scorecard")
					local scorecard = scorecardGui and scorecardGui:FindFirstChild("Scorecard")
					local playerCard = scorecard and scorecard:FindFirstChild("PlayerCard")
					setNameValue(playerCard and playerCard:FindFirstChild("Username"), "Text", "Havoc")
					task.wait(0.2)
				end
			end)
		else
			restoreNameValues()
		end
	end,
})

-- ===================== PERFORMANCE =====================
local antiLagEnabled = false
local fpsBoostEnabled = false
local originalPartSettings = {}
local originalVisualSettings = {}
local originalEffectSettings = {}
local originalTerrainSettings
local originalLightingSettings
local originalQualityLevel

local function isVisualEffect(instance)
	return instance:IsA("BlurEffect") or instance:IsA("SunRaysEffect")
		or instance:IsA("ColorCorrectionEffect") or instance:IsA("BloomEffect")
		or instance:IsA("DepthOfFieldEffect")
end

local function applyPerformanceSettings()
	if fpsBoostEnabled and not originalTerrainSettings then
		local terrain = Workspace.Terrain
		originalTerrainSettings = {
			WaterWaveSize = terrain.WaterWaveSize,
			WaterWaveSpeed = terrain.WaterWaveSpeed,
			WaterReflectance = terrain.WaterReflectance,
			WaterTransparency = terrain.WaterTransparency,
		}
		originalLightingSettings = {
			GlobalShadows = Lighting.GlobalShadows,
			FogEnd = Lighting.FogEnd,
			Brightness = Lighting.Brightness,
		}
		originalQualityLevel = settings().Rendering.QualityLevel
	end

	for _, instance in ipairs(game:GetDescendants()) do
		if instance:IsA("BasePart") then
			local shouldOptimize = fpsBoostEnabled
				or (antiLagEnabled and not (instance.Parent and instance.Parent:FindFirstChildOfClass("Humanoid")))
			if shouldOptimize then
				if not originalPartSettings[instance] then
					originalPartSettings[instance] = {
						Material = instance.Material,
						Reflectance = instance.Reflectance,
					}
				end
				instance.Material = fpsBoostEnabled and Enum.Material.Plastic or Enum.Material.SmoothPlastic
				if fpsBoostEnabled then instance.Reflectance = 0 end
			elseif originalPartSettings[instance] then
				instance.Material = originalPartSettings[instance].Material
				instance.Reflectance = originalPartSettings[instance].Reflectance
				originalPartSettings[instance] = nil
			end
		elseif fpsBoostEnabled then
			if instance:IsA("Decal") or instance:IsA("Texture") then
				if originalVisualSettings[instance] == nil then
					originalVisualSettings[instance] = instance.Transparency
				end
				instance.Transparency = 1
			elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") then
				if originalVisualSettings[instance] == nil then
					originalVisualSettings[instance] = instance.Lifetime
				end
				instance.Lifetime = NumberRange.new(0)
			elseif instance:IsA("Fire") or instance:IsA("SpotLight") or instance:IsA("Smoke") then
				if originalVisualSettings[instance] == nil then
					originalVisualSettings[instance] = instance.Enabled
				end
				instance.Enabled = false
			elseif isVisualEffect(instance) then
				if originalEffectSettings[instance] == nil then
					originalEffectSettings[instance] = instance.Enabled
				end
				instance.Enabled = false
			end
		end
	end

	if fpsBoostEnabled then
		local terrain = Workspace.Terrain
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 0
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 9e9
		Lighting.Brightness = 0
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	else
		if originalTerrainSettings then
			local terrain = Workspace.Terrain
			terrain.WaterWaveSize = originalTerrainSettings.WaterWaveSize
			terrain.WaterWaveSpeed = originalTerrainSettings.WaterWaveSpeed
			terrain.WaterReflectance = originalTerrainSettings.WaterReflectance
			terrain.WaterTransparency = originalTerrainSettings.WaterTransparency
			originalTerrainSettings = nil
		end
		if originalLightingSettings then
			Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
			Lighting.FogEnd = originalLightingSettings.FogEnd
			Lighting.Brightness = originalLightingSettings.Brightness
			originalLightingSettings = nil
		end
		if originalQualityLevel then
			settings().Rendering.QualityLevel = originalQualityLevel
			originalQualityLevel = nil
		end
		for instance, value in pairs(originalVisualSettings) do
			if instance.Parent then
				if instance:IsA("Decal") or instance:IsA("Texture") then
					instance.Transparency = value
				elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") then
					instance.Lifetime = value
				elseif instance:IsA("Fire") or instance:IsA("SpotLight") or instance:IsA("Smoke") then
					instance.Enabled = value
				end
			end
			originalVisualSettings[instance] = nil
		end
		for effect, enabled in pairs(originalEffectSettings) do
			if effect.Parent then effect.Enabled = enabled end
			originalEffectSettings[effect] = nil
		end
	end

	if not antiLagEnabled and not fpsBoostEnabled then
		for part, properties in pairs(originalPartSettings) do
			if part.Parent then
				part.Material = properties.Material
				part.Reflectance = properties.Reflectance
			end
			originalPartSettings[part] = nil
		end
	end
end

PerformanceSection:Toggle({
	Name = "anti lag",
	Default = false,
	Callback = function(state)
		antiLagEnabled = state
		applyPerformanceSettings()
	end,
})

PerformanceSection:Toggle({
	Name = "fps boost",
	Default = false,
	Callback = function(state)
		fpsBoostEnabled = state
		applyPerformanceSettings()
	end,
})

-- ===================== SERVER =====================
ServerSection:Button({
	Name = "rejoin",
	Callback = function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end,
})

-- ===================== TARGET ORBIT (original) =====================
local SpiralEnabled = false
local SpiralRadius = 8
local SpiralHeight = 3
local SpiralSpeed = 2
local SpiralAngle = 0
local SpiralTarget = nil
local SpiralConnection
local SpiralToggle

local function findRandomTarget()
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isEnemy(player) then table.insert(candidates, player) end
	end
	if #candidates == 0 then return nil end
	return candidates[math.random(1, #candidates)]
end

local function stopSpiral(syncToggle)
	SpiralEnabled = false
	SpiralTarget = nil
	if SpiralConnection then
		SpiralConnection:Disconnect()
		SpiralConnection = nil
	end
	if syncToggle ~= false and SpiralToggle and SpiralToggle.Value then
		SpiralToggle:Set(false, false)
	end
end

local function startSpiral()
	stopSpiral(false)
	local target = findRandomTarget()
	if not target then
		if SpiralToggle then SpiralToggle:Set(false, false) end
		Window:Notify({ Title = "no target available", Content = "target orbit needs another living player.", Duration = 3 })
		return
	end
	SpiralTarget = target
	SpiralEnabled = true
	SpiralAngle = 0
	SpiralConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local localRoot = getRoot(LocalPlayer)
		local targetRoot = getRoot(SpiralTarget)
		if not running or not SpiralEnabled or not isAlive(SpiralTarget) then
			stopSpiral()
			return
		end
		if not localRoot or not targetRoot then return end
		SpiralAngle += math.min(deltaTime, 1 / 20) * SpiralSpeed
		local height = math.sin(SpiralAngle * 0.5) * SpiralHeight
		local offset = Vector3.new(
			math.cos(SpiralAngle) * SpiralRadius,
			height,
			math.sin(SpiralAngle) * SpiralRadius
		)
		local position = targetRoot.Position + offset
		local lookAtPosition = targetRoot.Position
		if (lookAtPosition - position).Magnitude > 0 then
			localRoot.CFrame = CFrame.lookAt(position, lookAtPosition)
		end
	end)
end

local Tools = Window:Tab({ Name = "tools", Icon = "layers" })
local MovementTools = Tools:Section({ Name = "orbit", Icon = "rotate-cw" })
SpiralToggle = MovementTools:Toggle({
	Name = "target orbit",
	Default = false,
	Callback = function(value)
		if value then startSpiral() else stopSpiral(false) end
	end,
})
MovementTools:Slider({ Name = "orbit radius", Min = 3, Max = 30, Step = 1, Default = SpiralRadius, Callback = function(value) SpiralRadius = value end })
MovementTools:Slider({ Name = "orbit height", Min = 0, Max = 15, Step = 1, Default = SpiralHeight, Callback = function(value) SpiralHeight = value end })
MovementTools:Slider({ Name = "orbit speed", Min = 0.5, Max = 10, Step = 0.5, Default = SpiralSpeed, Callback = function(value) SpiralSpeed = value end })

local SelfSection = Tools:Section({ Name = "self", Icon = "person" })
SelfSection:Button({
	Name = "kick self",
	Callback = function() LocalPlayer:Kick("havoc: kicked yourself") end,
})

-- ===================== CLEANUP =====================
local function cleanup()
	if not running then return end
	running = false
	AimLockEnabled = false
	AimTarget = nil
	ESPEnabled = false
	extraPlayerESP.Enabled = false
	updateExtraPlayerESP()
	stopSpiral(false)
	endFly()
	armCharms = false
	gunCharms = false
	rainbowEnabled = false
	armCharmGeneration += 1
	gunCharmGeneration += 1
	restoreAppearance(armOriginalAppearance)
	restoreAppearance(gunOriginalAppearance)
	restoreAppearance(rainbowOriginalColors)
	runNameLoop = false
	nameLoopGeneration += 1
	restoreNameValues()
	SettingsInfinite = false
	if infiniteAmmoConnection then
		infiniteAmmoConnection:Disconnect()
		infiniteAmmoConnection = nil
	end
	restoreInfiniteAmmo()
	disconnect(jumpConnection)
	jumpConnection = nil
	setAntiAimEnabled(false)
	setXray(false)
	if fullBrightEnabled then setFullBright(false) end
	setParticleMess(false)
	fpsBoostEnabled = false
	antiLagEnabled = false
	applyPerformanceSettings()
	for name in pairs(objectESPStates) do
		toggleObjectESP(false, name)
	end
	for player in pairs(hitbox_original_properties) do
		restoredPart(player)
		hitbox_original_properties[player] = nil
	end
	for player, playerConnections in pairs(hitboxPlayerConnections) do
		disconnect(playerConnections.CharacterAdded)
		disconnect(playerConnections.CharacterRemoving)
		hitboxPlayerConnections[player] = nil
	end
	for name, tag in pairs(fakeTags) do
		fakeTags[name] = nil
		tag:Destroy()
	end
	if originalValues.CurrentCurse ~= nil then
		local workspaceData = ReplicatedStorage:FindFirstChild("wkspc")
		local currentCurse = workspaceData and workspaceData:FindFirstChild("CurrentCurse")
		if currentCurse and currentCurse:IsA("StringValue") then
			currentCurse.Value = originalValues.CurrentCurse
		end
		originalValues.CurrentCurse = nil
	end
	for _, originalMap in pairs(originalValues) do
		if type(originalMap) == "table" then
			for instance, value in pairs(originalMap) do
				if instance.Parent and instance:IsA("ValueBase") then
					instance.Value = value
				end
				originalMap[instance] = nil
			end
		end
	end
	local watchedPlayers = {}
	for player in pairs(ESPConnections) do table.insert(watchedPlayers, player) end
	for player in pairs(Highlights) do
		if not table.find(watchedPlayers, player) then table.insert(watchedPlayers, player) end
	end
	for _, player in ipairs(watchedPlayers) do unwatchPlayerESP(player) end
	for _, connection in ipairs(connections) do disconnect(connection) end
	table.clear(connections)
	for player in pairs(extraPlayerESPElements) do clearExtraPlayerESP(player) end
	extraPlayerESPGui:Destroy()
	AimOverlay:Destroy()
end

local function suspendFeatures()
	setAimLockEnabled(false)
	setESPEnabled(false)
	stopSpiral()
	if ESPToggle and ESPToggle.Value then ESPToggle:Set(false, false) end
end

track(RunService.RenderStepped:Connect(updateAim))
track(Players.PlayerAdded:Connect(function(player)
	if ESPEnabled then watchPlayerESP(player) end
end))
track(Players.PlayerRemoving:Connect(function(player)
	unwatchPlayerESP(player)
	if AimTarget == player then
		AimTarget = nil
		nextAimAcquire = 0
	end
end))
track(LocalPlayer.CharacterAdded:Connect(function()
	AimTarget = nil
	nextAimAcquire = 0
	stopSpiral()
	if antiAimEnabled then setAntiAimEnabled(true) end
	if flySettings.fly and not startFly() then
		flySettings.fly = false
	end
end))
track(Window.Root:GetPropertyChangedSignal("Visible"):Connect(function()
	if not Window.Root.Visible then suspendFeatures() end
end))
track(Window.Root.Destroying:Connect(cleanup))

Window:Notify({
	Title = "havoc public",
	Content = "arsenal pack loaded — hitbox, gunmods, fly, skins, everything",
	Duration = 4,
})