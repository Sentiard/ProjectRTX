--[[
	=====================================
	RTX Script v5.0
	=====================================
	Made By. @vcxznum778
	=====================================
]]

-- ============================================
-- Config
-- ============================================

local DEBUG_MODE = true
local PRINT_BANNER = true

local MORNING_DURATION = 240
local SUNSET_DURATION = 120
local EVENING_DURATION = 240

local TIME_MORNING = 6
local TIME_TRANSITION_START = 16.5
local TIME_SUNSET = 17
local TIME_EVENING = 19

local SKYBOX_SWAP_THRESHOLD = 0.80
local SKYBOX_STAR_SWAP_THRESHOLD = 0.95
local SUNSET_BLOOM_ATTEN_START = 0.30
local SUNSET_BLOOM_ATTEN_END = SKYBOX_SWAP_THRESHOLD

local VISUAL_SMOOTH_SPEED = 8

local WATER_BLUR_MAX_SIZE = 20
local WATER_BLUR_SPEED = 45
local WATER_SAMPLE_INTERVAL = 0.12
local WATER_SAMPLE_SIZE = 2

local ESC_MENU_BLUR_SIZE = 24
local ESC_MENU_TWEEN_TIME = 0.5

-- ============================================
-- Services
-- ============================================

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Terrain = workspace.Terrain
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================
-- Utility
-- ============================================

local function debugPrint(category, message)
	if DEBUG_MODE then
		print(("[%s] %s"):format(category, message))
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function isColor(value)
	return typeof(value) == "Color3"
end

local function lerpColor(a, b, t)
	if isColor(a) and isColor(b) then
		return a:Lerp(b, t)
	end

	return a or b
end

local function safeSet(object, property, value)
	if object and value ~= nil then
		pcall(function()
			object[property] = value
		end)
	end
end

local function safeDestroy(object)
	if object and object.Parent then
		pcall(function()
			object:Destroy()
		end)
	end
end

local function getOrCreateNamed(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing and existing.ClassName == className then
		return existing
	end

	if existing then
		safeDestroy(existing)
	end

	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent

	return object
end

local function getOrCreateClass(parent, className, name)
	local existing = parent:FindFirstChildOfClass(className)

	if existing then
		return existing
	end

	local object = Instance.new(className)
	object.Name = name or className
	object.Parent = parent

	return object
end

local function temperatureToColor(kelvin)
	local temp = math.clamp(kelvin, 1000, 40000) / 100

	local r = temp <= 66 and 255 or 329.7 * ((temp - 60) ^ -0.133)
	local g = temp <= 66 and 99.47 * math.log(temp) - 161.12 or 288.12 * ((temp - 60) ^ -0.075)
	local b = temp >= 66 and 255 or temp <= 19 and 0 or 138.52 * math.log(temp - 10) - 305.04

	return Color3.fromRGB(
		math.clamp(r, 0, 255),
		math.clamp(g, 0, 255),
		math.clamp(b, 0, 255)
	)
end

local function moveTowards(current, target, maxDelta)
	if math.abs(target - current) <= maxDelta then
		return target
	end

	if target > current then
		return current + maxDelta
	end

	return current - maxDelta
end

-- ============================================
-- Effect Accessors
-- ============================================

local function getBlur(name)
	local blur = getOrCreateNamed(Lighting, "BlurEffect", name)
	blur.Enabled = true
	return blur
end

local function getSky()
	return getOrCreateClass(Lighting, "Sky", "Sky")
end

local function getAtmosphere()
	return getOrCreateClass(Lighting, "Atmosphere", "Atmosphere")
end

local function getColorCorrection()
	return getOrCreateClass(Lighting, "ColorCorrectionEffect", "ColorCorrection")
end

local function getBloom()
	local bloom = getOrCreateClass(Lighting, "BloomEffect", "Bloom")
	safeSet(bloom, "Threshold", bloom.Threshold or 2)
	return bloom
end

local function getSunRays()
	return getOrCreateClass(Lighting, "SunRaysEffect", "SunRays")
end

local function getDepthOfField()
	return getOrCreateClass(Lighting, "DepthOfFieldEffect", "DepthOfField")
end

local function getClouds()
	return getOrCreateClass(Terrain, "Clouds", "Clouds")
end

-- ============================================
-- Vignette
-- ============================================

local vignetteGui
local vignetteEnabled

local function getVignette()
	if vignetteGui and vignetteGui.Parent then
		return vignetteGui
	end

	local existing = PlayerGui:FindFirstChild("VignetteGui")
	if existing and existing:IsA("ScreenGui") then
		vignetteGui = existing
		return vignetteGui
	end

	if existing then
		safeDestroy(existing)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VignetteGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = PlayerGui

	local image = Instance.new("ImageLabel")
	image.Name = "Vignette"
	image.AnchorPoint = Vector2.new(0.5, 1)
	image.Position = UDim2.fromScale(0.5, 1)
	image.Size = UDim2.new(1, 0, 1.05, 0)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://4576475446"
	image.ImageTransparency = 0.3
	image.ZIndex = 10
	image.Parent = gui

	vignetteGui = gui
	return gui
end

local function setVignetteEnabled(enabled)
	if vignetteEnabled == enabled then
		return
	end

	vignetteEnabled = enabled
	getVignette().Enabled = enabled
end

-- ============================================
-- Menu Blur
-- ============================================

local function initMenuBlur()
	local escBlur = getBlur("EscBlur")
	escBlur.Size = 0

	local closeTween

	GuiService.MenuOpened:Connect(function()
		if closeTween then
			closeTween:Cancel()
		end

		escBlur.Size = ESC_MENU_BLUR_SIZE
		debugPrint("MENU", "Menu opened")
	end)

	GuiService.MenuClosed:Connect(function()
		if closeTween then
			closeTween:Cancel()
		end

		closeTween = TweenService:Create(
			escBlur,
			TweenInfo.new(ESC_MENU_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = 0 }
		)

		closeTween:Play()
		debugPrint("MENU", "Menu closed")
	end)
end

-- ============================================
-- Presets
-- ============================================

local PRESETS = {
	Morning = {
		clockTime = TIME_MORNING,
		sky = {
			Up = "http://www.roblox.com/asset/?id=144931564",
			Dn = "http://www.roblox.com/asset/?id=144931530",
			Lf = "http://www.roblox.com/asset/?id=144933244",
			Rt = "http://www.roblox.com/asset/?id=144933299",
			Ft = "http://www.roblox.com/asset/?id=144933262",
			Bk = "http://www.roblox.com/asset/?id=144933338",
			SunAngularSize = 8
		},
		lighting = {
			ShadowSoftness = 1,
			Brightness = 4,
			Ambient = Color3.fromRGB(210, 220, 255),
			OutdoorAmbient = Color3.fromRGB(70, 78, 88),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.9,
			FogStart = 0,
			FogEnd = 5000,
			FogColor = Color3.fromRGB(230, 235, 245),
			GlobalShadows = true,
			ExposureCompensation = 0.5
		},
		atmosphere = {
			Density = 0.38,
			Offset = 0,
			Color = Color3.fromRGB(255, 255, 255),
			Decay = Color3.fromRGB(220, 230, 255),
			Glare = 0.25,
			Haze = 1
		},
		colorCorrection = {
			TintColor = Color3.fromRGB(245, 250, 255),
			Saturation = 0.15,
			Contrast = 0.08,
			Brightness = 0.02
		},
		bloom = {
			Intensity = -0.001,
			Size = 31,
			Threshold = 2
		},
		blur = {
			Size = 2
		},
		sunrays = {
			Intensity = 0.12,
			Spread = 1
		},
		depthOfField = nil,
		vignette = false,
		Clouds = {
			Enabled = true,
			Cover = 0.6,
			Density = 1,
			Color = Color3.fromRGB(221, 247, 255)
		},
		ColorGradingEffect = {
			Enabled = true,
			Temperature = 6500,
			ContrastBoost = 0,
			FilmFade = 0,
			ShadowTint = Color3.fromRGB(10, 15, 30),
			HighlightTint = Color3.fromRGB(255, 240, 220)
		}
	},

	Sunset = {
		clockTime = 17,
		sky = {
			Up = "rbxassetid://169210149",
			Dn = "rbxassetid://169210108",
			Lf = "rbxassetid://169210133",
			Rt = "rbxassetid://169210143",
			Ft = "rbxassetid://169210121",
			Bk = "rbxassetid://169210090",
			SunAngularSize = 18
		},
		lighting = {
			Brightness = 2.05,
			Ambient = Color3.fromRGB(140, 80, 50),
			OutdoorAmbient = Color3.fromRGB(60, 35, 30),
			EnvironmentDiffuseScale = 0.28,
			EnvironmentSpecularScale = 0.2,
			FogStart = 0,
			FogEnd = 12000,
			FogColor = Color3.fromRGB(210, 110, 60),
			GlobalShadows = true,
			ExposureCompensation = 0.15
		},
		atmosphere = {
			Density = 0.36,
			Offset = 0.55,
			Color = Color3.fromRGB(230, 140, 90),
			Decay = Color3.fromRGB(90, 50, 30),
			Glare = 0.48,
			Haze = 1.1
		},
		colorCorrection = {
			TintColor = Color3.fromRGB(255, 180, 110),
			Saturation = 0.05,
			Contrast = 0.22,
			Brightness = 0.09
		},
		bloom = {
			Intensity = 1.8,
			Size = 70,
			Threshold = 1.8
		},
		blur = {
			Size = 3.5
		},
		sunrays = {
			Intensity = 0.12,
			Spread = 0.85
		},
		depthOfField = {
			FocusDistance = 28,
			InFocusRadius = 12,
			FarIntensity = 0.45,
			NearIntensity = 0
		},
		vignette = true,
		Clouds = {
			Enabled = true,
			Cover = 0.6,
			Density = 1,
			Color = Color3.fromRGB(154, 121, 105)
		},
		ColorGradingEffect = {
			Temperature = 4200,
			ContrastBoost = 0.35,
			FilmFade = 0.25
		}
	},

	Evening = {
		clockTime = 0,
		sky = {
			Up = "http://www.roblox.com/asset/?id=144931564",
			Dn = "http://www.roblox.com/asset/?id=144931530",
			Lf = "http://www.roblox.com/asset/?id=144933244",
			Rt = "http://www.roblox.com/asset/?id=144933299",
			Ft = "http://www.roblox.com/asset/?id=144933262",
			Bk = "http://www.roblox.com/asset/?id=144933338",
			SunAngularSize = 6,
			MoonAngularSize = 10,
			StarCount = 5000
		},
		lighting = {
			Brightness = 2.2,
			Ambient = Color3.fromRGB(110, 120, 170),
			OutdoorAmbient = Color3.fromRGB(90, 90, 130),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 1,
			FogStart = 0,
			FogEnd = 80000,
			FogColor = Color3.fromRGB(38, 40, 70),
			GlobalShadows = true,
			ExposureCompensation = 1.4
		},
		atmosphere = {
			Density = 0.41,
			Offset = 0,
			Color = Color3.fromRGB(130, 140, 180),
			Decay = Color3.fromRGB(50, 60, 90),
			Glare = 0.65,
			Haze = 1.16
		},
		colorCorrection = {
			TintColor = Color3.fromRGB(180, 195, 230),
			Saturation = 0.1,
			Contrast = 0.15,
			Brightness = 0.12
		},
		bloom = {
			Intensity = 1.25,
			Size = 34,
			Threshold = 2
		},
		blur = {
			Size = 1
		},
		sunrays = {
			Intensity = 0.06,
			Spread = 0.6
		},
		depthOfField = nil,
		vignette = false,
		Clouds = {
			Enabled = true,
			Cover = 0.6,
			Density = 1,
			Color = Color3.fromRGB(56, 63, 65)
		},
		ColorGradingEffect = {
			Temperature = 9000,
			ContrastBoost = 0.08,
			FilmFade = -0.03,
			ShadowTint = Color3.fromRGB(20, 35, 70),
			HighlightTint = Color3.fromRGB(200, 220, 255)
		}
	}
}

-- ============================================
-- Time
-- ============================================

local FULL_DAY_SECONDS = MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION + MORNING_DURATION

local function findSegmentAndT(clockTime)
	local ct = clockTime

	if ct < TIME_MORNING then
		ct = ct + 24
	end

	if ct >= TIME_MORNING and ct < TIME_TRANSITION_START then
		return "Morning", "Morning", 0
	end

	if ct >= TIME_TRANSITION_START and ct < TIME_SUNSET then
		local t = (ct - TIME_TRANSITION_START) / (TIME_SUNSET - TIME_TRANSITION_START)
		return "Morning", "Sunset", smoothstep(t)
	end

	if ct >= TIME_SUNSET and ct < TIME_EVENING then
		local t = (ct - TIME_SUNSET) / (TIME_EVENING - TIME_SUNSET)
		return "Sunset", "Evening", smoothstep(t)
	end

	local t = (ct - TIME_EVENING) / ((24 - TIME_EVENING) + TIME_MORNING)
	return "Evening", "Morning", smoothstep(t)
end

local function calculateClockTimeFromElapsed(elapsed)
	if elapsed < MORNING_DURATION then
		local t = elapsed / MORNING_DURATION
		return TIME_MORNING + (TIME_TRANSITION_START - TIME_MORNING) * t
	end

	if elapsed < MORNING_DURATION + SUNSET_DURATION then
		local t = (elapsed - MORNING_DURATION) / SUNSET_DURATION
		return TIME_TRANSITION_START + (TIME_SUNSET - TIME_TRANSITION_START) * t
	end

	if elapsed < MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION then
		local t = (elapsed - MORNING_DURATION - SUNSET_DURATION) / EVENING_DURATION
		return TIME_SUNSET + (TIME_EVENING - TIME_SUNSET) * t
	end

	local t = (elapsed - MORNING_DURATION - SUNSET_DURATION - EVENING_DURATION) / MORNING_DURATION
	local clockTime = TIME_EVENING + ((24 - TIME_EVENING) + TIME_MORNING) * t

	if clockTime >= 24 then
		clockTime = clockTime - 24
	end

	return clockTime
end

local function applyClockTime(clockTime)
	local epsilon = 0.01

	if clockTime >= 6 and clockTime < 6 + epsilon then
		clockTime = 6 + epsilon
	elseif clockTime > 18 - epsilon and clockTime <= 18 then
		clockTime = 18 - epsilon
	end

	Lighting.ClockTime = clockTime
	return clockTime
end

-- ============================================
-- Water Blur
-- ============================================

local currentWaterBlurSize = 0
local waterSampleTimer = WATER_SAMPLE_INTERVAL
local cameraInWater = false

local function sampleCameraMaterial()
	local camera = workspace.CurrentCamera

	if not camera then
		return Enum.Material.Air
	end

	local position = camera.CFrame.Position
	local sampleVector = Vector3.new(WATER_SAMPLE_SIZE, WATER_SAMPLE_SIZE, WATER_SAMPLE_SIZE)
	local region = Region3.new(position - sampleVector, position + sampleVector):ExpandToGrid(4)

	local material = Enum.Material.Air

	pcall(function()
		local materials = Terrain:ReadVoxels(region, 4)
		local size = materials.Size

		if size.X > 0 and size.Y > 0 and size.Z > 0 then
			local x = math.max(1, math.ceil(size.X / 2))
			local y = math.max(1, math.ceil(size.Y / 2))
			local z = math.max(1, math.ceil(size.Z / 2))

			material = materials[x][y][z]
		end
	end)

	return material
end

local function updateWaterBlur(dt)
	waterSampleTimer = waterSampleTimer + dt

	if waterSampleTimer >= WATER_SAMPLE_INTERVAL then
		waterSampleTimer = 0
		cameraInWater = sampleCameraMaterial() == Enum.Material.Water
	end

	local targetSize = cameraInWater and WATER_BLUR_MAX_SIZE or 0
	currentWaterBlurSize = moveTowards(currentWaterBlurSize, targetSize, WATER_BLUR_SPEED * dt)

	getBlur("WaterBlur").Size = currentWaterBlurSize
end

-- ============================================
-- Visual Update
-- ============================================

local function updateVisuals(clockTime, dt)
	local sky = getSky()
	local atmosphere = getAtmosphere()
	local colorCorrection = getColorCorrection()
	local bloom = getBloom()
	local sunRays = getSunRays()
	local mainBlur = getBlur("MainBlur")
	local clouds = getClouds()

	local aName, bName, t = findSegmentAndT(clockTime)
	local A = PRESETS[aName]
	local B = PRESETS[bName]

	local smoothAlpha = dt and (1 - math.exp(-VISUAL_SMOOTH_SPEED * math.max(dt, 0))) or 1

	local function pick(section, key, fallback)
		local sectionA = A[section]
		local sectionB = B[section]

		local aValue = sectionA and sectionA[key]
		local bValue = sectionB and sectionB[key]

		if aValue == nil then
			aValue = fallback
		end

		if bValue == nil then
			bValue = fallback
		end

		if type(aValue) == "number" and type(bValue) == "number" then
			return lerp(aValue, bValue, t)
		end

		if isColor(aValue) and isColor(bValue) then
			return lerpColor(aValue, bValue, t)
		end

		return t < 0.5 and aValue or bValue
	end

	local gradingA = A.ColorGradingEffect or {}
	local gradingB = B.ColorGradingEffect or {}

	local temperature = lerp(gradingA.Temperature or 6500, gradingB.Temperature or 6500, t)
	local contrastBoost = lerp(gradingA.ContrastBoost or 0, gradingB.ContrastBoost or 0, t)
	local filmFade = lerp(gradingA.FilmFade or 0, gradingB.FilmFade or 0, t)

	local shadowTint = lerpColor(
		gradingA.ShadowTint or Color3.fromRGB(0, 0, 0),
		gradingB.ShadowTint or Color3.fromRGB(0, 0, 0),
		t
	)

	local highlightTint = lerpColor(
		gradingA.HighlightTint or Color3.fromRGB(255, 255, 255),
		gradingB.HighlightTint or Color3.fromRGB(255, 255, 255),
		t
	)

	-- Clouds
	local cloudsA = A.Clouds or {}
	local cloudsB = B.Clouds or {}

	safeSet(clouds, "Cover", lerp(cloudsA.Cover or clouds.Cover, cloudsB.Cover or clouds.Cover, t))
	safeSet(clouds, "Density", lerp(cloudsA.Density or clouds.Density, cloudsB.Density or clouds.Density, t))

	if isColor(cloudsA.Color or clouds.Color) and isColor(cloudsB.Color or clouds.Color) then
		clouds.Color = lerpColor(cloudsA.Color or clouds.Color, cloudsB.Color or clouds.Color, t)
	end

	clouds.Enabled = t < 0.5 and cloudsA.Enabled ~= false or cloudsB.Enabled ~= false

	-- Lighting
	local targetBrightness = pick("lighting", "Brightness", Lighting.Brightness)
	Lighting.Brightness = lerp(Lighting.Brightness, targetBrightness, smoothAlpha)

	safeSet(Lighting, "ShadowSoftness", pick("lighting", "ShadowSoftness", Lighting.ShadowSoftness))
	safeSet(Lighting, "Ambient", pick("lighting", "Ambient", Lighting.Ambient))
	safeSet(Lighting, "OutdoorAmbient", pick("lighting", "OutdoorAmbient", Lighting.OutdoorAmbient))
	safeSet(Lighting, "EnvironmentDiffuseScale", pick("lighting", "EnvironmentDiffuseScale", Lighting.EnvironmentDiffuseScale))
	safeSet(Lighting, "EnvironmentSpecularScale", pick("lighting", "EnvironmentSpecularScale", Lighting.EnvironmentSpecularScale))
	safeSet(Lighting, "FogStart", pick("lighting", "FogStart", Lighting.FogStart))
	safeSet(Lighting, "FogEnd", pick("lighting", "FogEnd", Lighting.FogEnd))
	safeSet(Lighting, "FogColor", pick("lighting", "FogColor", Lighting.FogColor))

	local targetExposure = pick("lighting", "ExposureCompensation", Lighting.ExposureCompensation or 0)
	Lighting.ExposureCompensation = lerp(Lighting.ExposureCompensation or 0, targetExposure, smoothAlpha)

	-- Atmosphere
	safeSet(atmosphere, "Density", pick("atmosphere", "Density", atmosphere.Density))
	safeSet(atmosphere, "Offset", pick("atmosphere", "Offset", atmosphere.Offset))
	safeSet(atmosphere, "Color", pick("atmosphere", "Color", atmosphere.Color))
	safeSet(atmosphere, "Decay", pick("atmosphere", "Decay", atmosphere.Decay))
	safeSet(atmosphere, "Glare", pick("atmosphere", "Glare", atmosphere.Glare))
	safeSet(atmosphere, "Haze", pick("atmosphere", "Haze", atmosphere.Haze))

	-- Color Correction
	local presetTint = pick("colorCorrection", "TintColor", colorCorrection.TintColor)
	local temperatureTint = temperatureToColor(temperature)

	local finalTint = lerpColor(presetTint, temperatureTint, 0.35)
	finalTint = lerpColor(finalTint, highlightTint, 0.12)
	finalTint = lerpColor(finalTint, shadowTint, 0.05)

	safeSet(colorCorrection, "TintColor", finalTint)
	safeSet(colorCorrection, "Saturation", pick("colorCorrection", "Saturation", colorCorrection.Saturation))

	colorCorrection.Contrast = pick("colorCorrection", "Contrast", colorCorrection.Contrast) + contrastBoost
	colorCorrection.Brightness = pick("colorCorrection", "Brightness", colorCorrection.Brightness) + filmFade * 0.5

	-- Bloom
	local bloomIntensity = pick("bloom", "Intensity", bloom.Intensity)
	local bloomSize = pick("bloom", "Size", bloom.Size)
	local bloomThreshold = pick("bloom", "Threshold", bloom.Threshold or 2)

	local bloomAttenuation = 1
	if aName == "Morning" and bName == "Sunset" then
		local attenuationT = clamp01((t - SUNSET_BLOOM_ATTEN_START) / (SUNSET_BLOOM_ATTEN_END - SUNSET_BLOOM_ATTEN_START))
		bloomAttenuation = lerp(1, 0.6, smoothstep(attenuationT))
	end

	safeSet(bloom, "Intensity", bloomIntensity * bloomAttenuation)
	safeSet(bloom, "Size", bloomSize)
	safeSet(bloom, "Threshold", bloomThreshold)

	-- Main Blur
	mainBlur.Size = pick("blur", "Size", mainBlur.Size)

	-- Sun Rays
	safeSet(sunRays, "Intensity", pick("sunrays", "Intensity", sunRays.Intensity) * bloomAttenuation)
	safeSet(sunRays, "Spread", pick("sunrays", "Spread", sunRays.Spread))

	-- Depth of Field
	local existingDof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")

	if A.depthOfField or B.depthOfField then
		local dof = existingDof or getDepthOfField()

		local function emptyDof(reference)
			reference = reference or {}
			return {
				FocusDistance = reference.FocusDistance or dof.FocusDistance or 28,
				InFocusRadius = reference.InFocusRadius or dof.InFocusRadius or 12,
				FarIntensity = 0,
				NearIntensity = 0
			}
		end

		local dofA = A.depthOfField or emptyDof(B.depthOfField)
		local dofB = B.depthOfField or emptyDof(A.depthOfField)

		safeSet(dof, "FocusDistance", lerp(dofA.FocusDistance or 28, dofB.FocusDistance or 28, t))
		safeSet(dof, "InFocusRadius", lerp(dofA.InFocusRadius or 12, dofB.InFocusRadius or 12, t))
		safeSet(dof, "FarIntensity", lerp(dofA.FarIntensity or 0, dofB.FarIntensity or 0, t))
		safeSet(dof, "NearIntensity", lerp(dofA.NearIntensity or 0, dofB.NearIntensity or 0, t))
	elseif existingDof then
		safeDestroy(existingDof)
	end

	-- Skybox
	local skyA = A.sky or {}
	local skyB = B.sky or {}

	local skyChoice
	if aName == "Morning" and bName == "Sunset" then
		skyChoice = skyA
	else
		skyChoice = t < SKYBOX_SWAP_THRESHOLD and skyA or skyB
	end

	safeSet(sky, "SkyboxUp", skyChoice.Up)
	safeSet(sky, "SkyboxDn", skyChoice.Dn)
	safeSet(sky, "SkyboxLf", skyChoice.Lf)
	safeSet(sky, "SkyboxRt", skyChoice.Rt)
	safeSet(sky, "SkyboxFt", skyChoice.Ft)
	safeSet(sky, "SkyboxBk", skyChoice.Bk)

	if type(skyA.SunAngularSize or sky.SunAngularSize) == "number" and type(skyB.SunAngularSize or sky.SunAngularSize) == "number" then
		safeSet(sky, "SunAngularSize", lerp(skyA.SunAngularSize or sky.SunAngularSize, skyB.SunAngularSize or sky.SunAngularSize, t))
	end

	if type(skyA.MoonAngularSize or sky.MoonAngularSize) == "number" and type(skyB.MoonAngularSize or sky.MoonAngularSize) == "number" then
		local moonT = clamp01((t - 0.6) / 0.4)
		safeSet(sky, "MoonAngularSize", lerp(skyA.MoonAngularSize or sky.MoonAngularSize, skyB.MoonAngularSize or sky.MoonAngularSize, moonT))
	end

	if type(skyA.StarCount or sky.StarCount) == "number" and type(skyB.StarCount or sky.StarCount) == "number" then
		local starT = 0

		if t >= SKYBOX_STAR_SWAP_THRESHOLD then
			starT = clamp01((t - SKYBOX_STAR_SWAP_THRESHOLD) / (1 - SKYBOX_STAR_SWAP_THRESHOLD))
		end

		safeSet(sky, "StarCount", lerp(skyA.StarCount or sky.StarCount, skyB.StarCount or sky.StarCount, starT))
	end

	-- Vignette
	local vignetteA = A.vignette == true
	local vignetteB = B.vignette == true
	setVignetteEnabled(t < SKYBOX_SWAP_THRESHOLD and vignetteA or vignetteB)

	-- Global Shadows
	local globalShadowsA = A.lighting and A.lighting.GlobalShadows
	local globalShadowsB = B.lighting and B.lighting.GlobalShadows

	if globalShadowsA ~= nil and globalShadowsB ~= nil then
		Lighting.GlobalShadows = t < 0.5 and globalShadowsA or globalShadowsB
	end
end

-- ============================================
-- Startup
-- ============================================

if PRINT_BANNER then
	print("Sentiard's RTX Script. v5.0")
	print("Made By. @vcxznum778.")
end

Terrain.WaterReflectance = 1
Terrain.WaterTransparency = 1

Lighting.GlobalShadows = true

getBlur("MainBlur").Size = 0
getBlur("WaterBlur").Size = 0
getBlur("EscBlur").Size = 0

local initialClockTime = applyClockTime(TIME_MORNING)

setVignetteEnabled(false)
updateVisuals(initialClockTime)
initMenuBlur()

debugPrint("INIT", "RTX Script initialized")

-- ============================================
-- Main Loop
-- ============================================

local lastTime = os.clock()
local elapsed = 0

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.clamp(now - lastTime, 0, 0.5)
	lastTime = now

	elapsed = (elapsed + dt) % FULL_DAY_SECONDS

	local clockTime = calculateClockTimeFromElapsed(elapsed)
	clockTime = applyClockTime(clockTime)

	updateVisuals(clockTime, dt)
	updateWaterBlur(dt)
end)

debugPrint("MAIN", "Main loop started")
