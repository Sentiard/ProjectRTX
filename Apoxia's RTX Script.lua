--[[
	=====================================
	RTX Script v4.0
	+ Water Blur + Menu Blur (Local Script)
	=====================================
	Made By. Apoxia
	=====================================
]]

-- ============================================
-- [1] Debug Settings
-- ============================================
local DEBUG_MODE = false  -- Enable/Disable Debug

local function debugPrint(category, message)
	if DEBUG_MODE then
		print("[" .. category .. "] " .. message)
	end
end

-- ============================================
-- [2] Logo Output
-- ============================================

print("           ,ggg,")                                                            
print("          dP  8I")                                                            
print("         dP   88")                                                            
print("        dP    88                                           gg")               
print("       ,8'    88                                           11")               
print("       d88888888   gg,gggg,      ,ggggg,       ,gg,   ,gg  gg     ,gggg,gg")  
print(" __   ,8      88   I8P    Yb    dP    Y8ggg   d8  8b,dP    88    dP    Y8I")
print("dP   ,8P      Y8   I8'    ,8i  i8'    ,8I    dP   ,88      88   i8'    ,8I")  
print("Yb,_,dP       `8b,,I8 _  ,d8' ,d8,   ,d8'  ,dP  ,dP Y8,  _,88,_,d8,   ,d8b,") 
print("  Y8P          `Y8PI8 YY88888PP Y8888P     8   dP     Y8 8P Y8P Y8888P `Y8") 
print("                   I8")                                                       
print("                   I8")                                                      
print("                   I8")                                                       
print("                   I8")                                                       
print("                   I8")                                                       
print("                   I8")                                                      
print()
print("Apoxia's RTX Script 4.0")
print("Made By. Apoxia.")
print()

-- ============================================
-- [3] Services and Basic Setup
-- ============================================
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService('GuiService')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService("UserInputService")
local terra = workspace.Terrain
local camera = workspace.CurrentCamera

debugPrint("INIT", "Services loaded successfully")

-- Basic configuration
if Lighting then
	for _, obj in ipairs(Lighting:GetChildren()) do
		pcall(function() obj:Destroy() end)
	end
end

terra.WaterReflectance = 1
terra.WaterTransparency = 1
Lighting.GlobalShadows = true

debugPrint("INIT", "Lighting initialization complete")

-- ============================================
-- [4] Day/Night Cycle Configuration
-- ============================================
local MORNING_DURATION = 240      -- Morning duration (seconds)
local SUNSET_DURATION = 120       -- Sunset duration (seconds)
local EVENING_DURATION = 240      -- Evening duration (seconds)

local TIME_MORNING = 6            -- Morning start time
local TIME_TRANSITION_START = 16.5 -- Sunset transition start
local TIME_SUNSET = 17            -- Sunset time
local TIME_EVENING = 19           -- Evening time

local SKYBOX_SWAP_THRESHOLD = 0.80 
local SKYBOX_STAR_SWAP_THRESHOLD = 0.95
local PER_FRAME_SMOOTH = 0.12
local SUNSET_BLOOM_ATTEN_START = 0.30
local SUNSET_BLOOM_ATTEN_END = SKYBOX_SWAP_THRESHOLD

debugPrint("CONFIG", "Day/Night Cycle configuration loaded")

-- ============================================
-- [5] Water Blur Configuration
-- ============================================
local WATER_BLUR_MAX_SIZE = 20
local WATER_BLUR_DECAY_SPEED = 1
local currentWaterBlurSize = 0

debugPrint("CONFIG", "Water blur configuration loaded")

-- ============================================
-- [6] Utility Functions
-- ============================================
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	if x < 0 then return 0 elseif x > 1 then return 1 else return x end
end

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

local function isColor(v)
	return typeof(v) == "Color3"
end

local function lerpColor(a, b, t)
	if isColor(a) and isColor(b) then return a:Lerp(b, t) end
	return a or b
end

local function safeSet(o, k, v)
	pcall(function()
		if o and v ~= nil then o[k] = v end
	end)
end

local function safeDestroy(o)
	pcall(function()
		if o and o.Parent then o:Destroy() end
	end)
end

debugPrint("UTIL", "Utility functions loaded")

-- ============================================
-- [7] Blur Creation/Management Functions
-- ============================================

-- MainBlur (Day/Night Cycle) - Lighting
local function getOrCreateMainBlur()
	local mainBlur = Lighting:FindFirstChild("MainBlur")
	if not mainBlur then
		mainBlur = Instance.new("BlurEffect")
		mainBlur.Name = "MainBlur"
		mainBlur.Size = 0
		mainBlur.Enabled = true
		mainBlur.Parent = Lighting
		debugPrint("BLUR", "MainBlur created (Lighting)")
	end
	return mainBlur
end

-- WaterBlur (Water detection) - Lighting
local function getOrCreateWaterBlur()
	local waterBlur = Lighting:FindFirstChild("WaterBlur")
	if not waterBlur then
		waterBlur = Instance.new("BlurEffect")
		waterBlur.Name = "WaterBlur"
		waterBlur.Size = 0
		waterBlur.Enabled = true
		waterBlur.Parent = Lighting
		debugPrint("BLUR", "WaterBlur created (Lighting)")
	end
	return waterBlur
end

-- EscBlur (ESC Menu) - Lighting
local function getOrCreateEscBlur()
	local escBlur = Lighting:FindFirstChild("EscBlur")
	if not escBlur then
		escBlur = Instance.new("BlurEffect")
		escBlur.Name = "EscBlur"
		escBlur.Size = 0
		escBlur.Enabled = true
		escBlur.Parent = Lighting
		debugPrint("BLUR", "EscBlur created (Lighting)")
	end
	return escBlur
end

-- ============================================
-- [8] Lighting Effects Creation/Management Functions
-- ============================================

local function getOrCreateSky()
	local s = Lighting:FindFirstChildOfClass("Sky")
	if not s then s = Instance.new("Sky"); s.Parent = Lighting end
	return s
end

local function getOrCreateAtmosphere()
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if not a then a = Instance.new("Atmosphere"); a.Name = "Atmosphere"; a.Parent = Lighting end
	return a
end

local function getOrCreateColorCorrection()
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "ColorCorrection"; cc.Parent = Lighting end
	return cc
end

local function getOrCreateBloom()
	local b = Lighting:FindFirstChildOfClass("BloomEffect")
	if not b then
		b = Instance.new("BloomEffect")
		b.Name = "Bloom"
		pcall(function() b.Threshold = 2 end)
		b.Parent = Lighting
	end
	pcall(function() if not b.Threshold then b.Threshold = 2 end end)
	return b
end

local function getOrCreateSunRays()
	local sr = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sr then sr = Instance.new("SunRaysEffect"); sr.Name = "SunRays"; sr.Parent = Lighting end
	return sr
end

local function getOrCreateDOF()
	local df = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not df then df = Instance.new("DepthOfFieldEffect"); df.Name = "DepthOfField"; df.Parent = Lighting end
	return df
end

local function getOrCreateClouds()
	local clouds = terra:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = terra
	end
	return clouds
end

debugPrint("EFFECT", "Lighting effect functions loaded")

-- ============================================
-- [9] Vignette UI Functions
-- ============================================

local function createVignette()
	local existing = StarterGui:FindFirstChild("VignetteGui")
	if existing then safeDestroy(existing) end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VignetteGui"
	gui.Parent = StarterGui
	gui.IgnoreGuiInset = true
	local img = Instance.new("ImageLabel")
	img.Parent = gui
	img.AnchorPoint = Vector2.new(0.5, 1)
	img.Position = UDim2.new(0.5, 0, 1, 0)
	img.Size = UDim2.new(1, 0, 1.05, 0)
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://4576475446"
	img.ImageTransparency = 0.3
	img.ZIndex = 10
	debugPrint("VIGNETTE", "Vignette created")
end

local function removeVignette()
	local v = StarterGui:FindFirstChild("VignetteGui")
	if v then safeDestroy(v) end
	debugPrint("VIGNETTE", "Vignette removed")
end

-- ============================================
-- [10] ESC Menu Blur Handler
-- ============================================

local function initMenuBlur()
	local escBlur = getOrCreateEscBlur()
	local tweenInfo = TweenInfo.new(.5)
	local tween = TweenService:Create(escBlur, tweenInfo, {Size = 0})

	GuiService.MenuOpened:Connect(function()
		tween:Cancel()
		escBlur.Size = 24
		debugPrint("MENU", "Menu opened - EscBlur size: 24")
	end)

	GuiService.MenuClosed:Connect(function()
		tween:Play()
		debugPrint("MENU", "Menu closed - EscBlur tween started")
	end)
end

-- ============================================
-- [11] Preset Data
-- ============================================

local PRESETS = {
	Morning = {
		clockTime = TIME_MORNING,
		sky = { Up="http://www.roblox.com/asset/?id=144931564", Dn="http://www.roblox.com/asset/?id=144931530", Lf="http://www.roblox.com/asset/?id=144933244", Rt="http://www.roblox.com/asset/?id=144933299", Ft="http://www.roblox.com/asset/?id=144933262", Bk="http://www.roblox.com/asset/?id=144933338", SunAngularSize = 8 },
		lighting = { LightingStyle = "Realistic", ShadowSoftness = 1, Brightness = 4, Ambient = Color3.fromRGB(210,220,255), OutdoorAmbient = Color3.fromRGB(70,78,88), EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.9, FogStart = 0, FogEnd = 5000, FogColor = Color3.fromRGB(230,235,245), GlobalShadows = true, ExposureCompensation = 0.5 },
		atmosphere = { Density = 0.38, Offset = 0, Color = Color3.fromRGB(255,255,255), Decay = Color3.fromRGB(220,230,255), Glare = 0.25, Haze = 1 },
		colorCorrection = { TintColor = Color3.fromRGB(245,250,255), Saturation = 0.15, Contrast = 0.08, Brightness = 0.02 },
		bloom = { Intensity = -0.001, Size = 31, Threshold = 2 },
		blur = { Size = 2 },
		sunrays = { Intensity = 0.12, Spread = 1 },
		depthOfField = nil,
		vignette = false,
		Clouds = { Enabled = true, Cover = 0.6, Density = 1, Color = Color3.fromRGB(221, 247, 255) },
		ColorGradingEffect = {
			Enabled = true,
			Temperature = 6500,
			ContrastBoost = 0.0,
			FilmFade = 0.0,
			ShadowTint = Color3.fromRGB(10, 15, 30),
			HighlightTint = Color3.fromRGB(255, 240, 220)
		}
	},
	Sunset = {
		clockTime = 17,
		sky = { Up="rbxassetid://169210149", Dn="rbxassetid://169210108", Lf="rbxassetid://169210133", Rt="rbxassetid://169210143", Ft="rbxassetid://169210121", Bk="rbxassetid://169210090", SunAngularSize = 18 },
		lighting = { Brightness = 2.05, Ambient = Color3.fromRGB(140,80,50), OutdoorAmbient = Color3.fromRGB(60,35,30), EnvironmentDiffuseScale = 0.28, EnvironmentSpecularScale = 0.2, FogStart = 0, FogEnd = 12000, FogColor = Color3.fromRGB(210,110,60), GlobalShadows = true, ExposureCompensation = 0.15 },
		atmosphere = { Density = 0.36, Offset = 0.55, Color = Color3.fromRGB(230,140,90), Decay = Color3.fromRGB(90,50,30), Glare = 0.48, Haze = 1.1 },
		colorCorrection = { TintColor = Color3.fromRGB(255,180,110), Saturation = 0.05, Contrast = 0.22, Brightness = 0.09 },
		bloom = { Intensity = 1.8, Size = 70, Threshold = 1.8 },
		blur = { Size = 3.5 },
		sunrays = { Intensity = 0.12, Spread = 0.85 },
		depthOfField = { FocusDistance = 28, InFocusRadius = 12, FarIntensity = 0.45, NearIntensity = 0 },
		vignette = true,
		Clouds = { Enabled = true, Cover = 0.6, Density = 1, Color = Color3.fromRGB(154, 121, 105) },
		ColorGradingEffect = {
			Temperature = 4200,
			ContrastBoost = 0.35,
			FilmFade = 0.25
		}
	},
	Evening = {
		clockTime = 0,
		sky = { Up="http://www.roblox.com/asset/?id=144931564", Dn="http://www.roblox.com/asset/?id=144931530", Lf="http://www.roblox.com/asset/?id=144933244", Rt="http://www.roblox.com/asset/?id=144933299", Ft="http://www.roblox.com/asset/?id=144933262", Bk="http://www.roblox.com/asset/?id=144933338", SunAngularSize = 6, MoonAngularSize = 10, StarCount = 5000 },
		lighting = {
			Brightness = 2.2,
			Ambient = Color3.fromRGB(110,120,170),
			OutdoorAmbient = Color3.fromRGB(90,90,130),
			EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1,
			FogStart = 0, FogEnd = 80000,
			FogColor = Color3.fromRGB(38,40,70),
			GlobalShadows = true,
			ExposureCompensation = 1.4,
		},
		atmosphere = {
			Density = 0.41,
			Offset = 0,
			Color = Color3.fromRGB(130,140,180),
			Decay = Color3.fromRGB(50,60,90),
			Glare = 0.65,
			Haze = 1.16
		},
		colorCorrection = {
			TintColor = Color3.fromRGB(180,195,230),
			Saturation = 0.1,
			Contrast = 0.15,
			Brightness = 0.12,
		},
		bloom = { Intensity = 1.25, Size = 34, Threshold = 2 },
		blur = { Size = 1 },
		sunrays = { Intensity = 0.06, Spread = 0.6 },
		depthOfField = nil,
		vignette = false,
		Clouds = { Enabled = true, Cover = 0.6, Density = 1, Color = Color3.fromRGB(56, 63, 65) },
		ColorGradingEffect = {
			Temperature = 9000,
			ContrastBoost = 0.08,
			FilmFade = -0.03,
			ShadowTint = Color3.fromRGB(20, 35, 70),
			HighlightTint = Color3.fromRGB(200, 220, 255)
		}
	}
}

debugPrint("PRESET", "Preset data loaded (Morning, Sunset, Evening)")

-- ============================================
-- [12] Time Calculation Functions
-- ============================================

local function findSegmentAndT(clockTime)
	local ct = clockTime

	if ct < TIME_MORNING then
		ct = ct + 24
	end

	if ct >= TIME_MORNING and ct < TIME_TRANSITION_START then
		return "Morning", "Morning", 0

	elseif ct >= TIME_TRANSITION_START and ct < TIME_SUNSET then
		local t = (ct - TIME_TRANSITION_START) / (TIME_SUNSET - TIME_TRANSITION_START)
		return "Morning", "Sunset", smoothstep(clamp01(t))

	elseif ct >= TIME_SUNSET and ct < TIME_EVENING then
		local t = (ct - TIME_SUNSET) / (TIME_EVENING - TIME_SUNSET)
		return "Sunset", "Evening", smoothstep(clamp01(t))

	else
		local t = (ct - TIME_EVENING) / ((24 - TIME_EVENING) + TIME_MORNING)
		return "Evening", "Morning", smoothstep(clamp01(t))
	end
end

local function setSunDirection(clockTime)
	if Lighting then
		local epsilon = 0.01
		if clockTime >= 6 and clockTime < 6 + epsilon then
			Lighting.ClockTime = 6 + epsilon
		elseif clockTime >= 18 - epsilon and clockTime < 18 then
			Lighting.ClockTime = 18 - epsilon
		end
	end
end

debugPrint("TIME", "Time calculation functions loaded")

-- ============================================
-- [13] Water Blur Update Function
-- ============================================

local waterBlurUpdateCounter = 0

local function updateWaterBlur()
	local camPosition = camera.CFrame.Position
	local material = Enum.Material.Air

	pcall(function()
		local terrain = workspace.Terrain
		local regionSize = 1
		local region = Region3.new(
			camPosition - Vector3.new(regionSize, regionSize, regionSize), 
			camPosition + Vector3.new(regionSize, regionSize, regionSize)
		)
		region = region:ExpandToGrid(4)

		local materials, sizes = terrain:ReadVoxels(region, 4)
		local size = materials.Size

		if size.X > 0 and size.Y > 0 and size.Z > 0 then
			material = materials[1][1][1]
		end
	end)

	-- Update water blur size
	if material == Enum.Material.Water then
		currentWaterBlurSize = math.min(currentWaterBlurSize + WATER_BLUR_DECAY_SPEED, WATER_BLUR_MAX_SIZE)
	else
		currentWaterBlurSize = math.max(currentWaterBlurSize - WATER_BLUR_DECAY_SPEED, 0)
	end

	-- Apply to WaterBlur only
	local waterBlur = getOrCreateWaterBlur()
	waterBlur.Size = currentWaterBlurSize

	-- Debug logging (every 1 second)
	waterBlurUpdateCounter = waterBlurUpdateCounter + 1
	if waterBlurUpdateCounter >= 60 then
		debugPrint("WATER", "Size: " .. tostring(currentWaterBlurSize) .. " | Material: " .. tostring(material))
		waterBlurUpdateCounter = 0
	end
end

debugPrint("WATER", "Water blur update function loaded")

-- ============================================
-- [14] Main Visual Update Function
-- ============================================

local mainBlurUpdateCounter = 0

local function updateVisuals(clockTime)
	local sky = getOrCreateSky()
	local atm = getOrCreateAtmosphere()
	local cc = getOrCreateColorCorrection()
	local bloom = getOrCreateBloom()
	local sr = getOrCreateSunRays()
	local mainBlur = getOrCreateMainBlur()
	local df = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")

	local aName, bName, t = findSegmentAndT(clockTime)
	local A = PRESETS[aName]
	local B = PRESETS[bName]

	-- ---- Color Temperature Grading ----
	local gA = A.ColorGradingEffect or {}
	local gB = B.ColorGradingEffect or {}

	local temperature = lerp(gA.Temperature or 6500, gB.Temperature or 6500, t)
	local contrastBoost = lerp(gA.ContrastBoost or 0, gB.ContrastBoost or 0, t)
	local filmFade = lerp(gA.FilmFade or 0, gB.FilmFade or 0, t)

	local shadowTint = lerpColor(gA.ShadowTint or Color3.fromRGB(0,0,0), gB.ShadowTint or Color3.fromRGB(0,0,0), t)
	local highlightTint = lerpColor(gA.HighlightTint or Color3.fromRGB(255,255,255), gB.HighlightTint or Color3.fromRGB(255,255,255), t)

	local function temperatureToColor(k)
		local temp = k / 100
		local r = (temp <= 66) and 255 or 329.7 * ((temp - 60) ^ -0.133)
		local g = (temp <= 66) and (99.47 * math.log(temp) - 161.12) or 288.12 * ((temp - 60) ^ -0.075)
		local b = (temp >= 66) and 255 or ((temp <= 19) and 0 or (138.52 * math.log(temp - 10) - 305.04))
		return Color3.fromRGB(math.clamp(r,0,255), math.clamp(g,0,255), math.clamp(b,0,255))
	end

	local tempColor = temperatureToColor(temperature)

	cc.TintColor = lerpColor(cc.TintColor, tempColor, 0.35)
	cc.TintColor = lerpColor(cc.TintColor, highlightTint, 0.12)
	cc.TintColor = lerpColor(cc.TintColor, shadowTint, 0.05)

	-- ---- Pick Function ----
	local function pick(section, key, fallback)
		local aV = (A[section] and A[section][key]) or fallback
		local bV = (B[section] and B[section][key]) or fallback
		if type(aV) == "number" and type(bV) == "number" then
			return lerp(aV, bV, t)
		end
		if isColor(aV) and isColor(bV) then
			return lerpColor(aV, bV, t)
		end
		return (t < 0.5) and aV or bV
	end

	-- ---- Cloud Update ----
	local clouds = getOrCreateClouds()

	local cloudA = A.Clouds or {}
	local cloudB = B.Clouds or {}

	local targetCover = lerp(cloudA.Cover or clouds.Cover, cloudB.Cover or clouds.Cover, t)
	local targetDensity = lerp(cloudA.Density or clouds.Density, cloudB.Density or clouds.Density, t)

	safeSet(clouds, "Cover", targetCover)
	safeSet(clouds, "Density", targetDensity)

	local aColor = cloudA.Color or clouds.Color
	local bColor = cloudB.Color or clouds.Color
	if isColor(aColor) and isColor(bColor) then
		clouds.Color = lerpColor(aColor, bColor, t)
	end

	local enabledA = cloudA.Enabled ~= false
	local enabledB = cloudB.Enabled ~= false
	clouds.Enabled = (t < 0.5) and enabledA or enabledB

	-- ---- Lighting Update ----
	local targetBrightness = pick("lighting", "Brightness", Lighting.Brightness)
	Lighting.Brightness = lerp(Lighting.Brightness, targetBrightness, PER_FRAME_SMOOTH)
	safeSet(Lighting, "Ambient", pick("lighting", "Ambient", Lighting.Ambient))
	safeSet(Lighting, "OutdoorAmbient", pick("lighting", "OutdoorAmbient", Lighting.OutdoorAmbient))
	pcall(function() Lighting.ColorShift_Top = pick("lighting", "ColorShift_Top", Lighting.ColorShift_Top) end)
	pcall(function() Lighting.ColorShift_Bottom = pick("lighting", "ColorShift_Bottom", Lighting.ColorShift_Bottom) end)
	safeSet(Lighting, "EnvironmentDiffuseScale", pick("lighting", "EnvironmentDiffuseScale", Lighting.EnvironmentDiffuseScale))
	safeSet(Lighting, "EnvironmentSpecularScale", pick("lighting", "EnvironmentSpecularScale", Lighting.EnvironmentSpecularScale))
	safeSet(Lighting, "FogStart", pick("lighting", "FogStart", Lighting.FogStart))
	safeSet(Lighting, "FogEnd", pick("lighting", "FogEnd", Lighting.FogEnd))
	pcall(function() Lighting.FogColor = pick("lighting", "FogColor", Lighting.FogColor) end)
	local targetExposure = pick("lighting", "ExposureCompensation", Lighting.ExposureCompensation or 0)
	Lighting.ExposureCompensation = lerp(Lighting.ExposureCompensation or 0, targetExposure, PER_FRAME_SMOOTH)

	-- ---- Atmosphere Update ----
	pcall(function() atm.Density = pick("atmosphere", "Density", atm.Density) end)
	pcall(function() atm.Offset = pick("atmosphere", "Offset", atm.Offset) end)
	pcall(function() atm.Color = pick("atmosphere", "Color", atm.Color) end)
	pcall(function() atm.Decay = pick("atmosphere", "Decay", atm.Decay) end)
	pcall(function() atm.Glare = pick("atmosphere", "Glare", atm.Glare) end)
	pcall(function() atm.Haze = pick("atmosphere", "Haze", atm.Haze) end)

	-- ---- Color Correction Update ----
	pcall(function()
		local aCol = (A.colorCorrection and A.colorCorrection.TintColor) or cc.TintColor
		local bCol = (B.colorCorrection and B.colorCorrection.TintColor) or cc.TintColor
		if isColor(aCol) and isColor(bCol) then cc.TintColor = lerpColor(aCol, bCol, t) end
	end)
	safeSet(cc, "Saturation", lerp((A.colorCorrection and A.colorCorrection.Saturation) or cc.Saturation, (B.colorCorrection and B.colorCorrection.Saturation) or cc.Saturation, t))

	local baseContrast = lerp(
		(A.colorCorrection and A.colorCorrection.Contrast) or cc.Contrast,
		(B.colorCorrection and B.colorCorrection.Contrast) or cc.Contrast,
		t
	)

	local baseBrightness = lerp(
		(A.colorCorrection and A.colorCorrection.Brightness) or cc.Brightness,
		(B.colorCorrection and B.colorCorrection.Brightness) or cc.Brightness,
		t
	)

	cc.Contrast = baseContrast + contrastBoost
	cc.Brightness = baseBrightness + filmFade * 0.5

	-- ---- Bloom Update ----
	local baseBloom = lerp((A.bloom and A.bloom.Intensity) or bloom.Intensity, (B.bloom and B.bloom.Intensity) or bloom.Intensity, t)
	local baseBloomSize = lerp((A.bloom and A.bloom.Size) or bloom.Size, (B.bloom and B.bloom.Size) or bloom.Size, t)
	local baseBloomThresh = lerp((A.bloom and A.bloom.Threshold) or bloom.Threshold or 2, (B.bloom and B.bloom.Threshold) or bloom.Threshold or 2, t)

	local atten = 1
	if (aName == "Morning" and bName == "Sunset") or (aName == "Sunset" and bName == "Sunset") then
		local blendedStart = (aName == "Morning" and bName == "Sunset")
		local base = blendedStart and 1 or 0.6
		local target = blendedStart and 0.6 or 0.6
		local blendT = blendedStart and (clamp01((t - SUNSET_BLOOM_ATTEN_START) / (SUNSET_BLOOM_ATTEN_END - SUNSET_BLOOM_ATTEN_START))) or 1
		atten = lerp(base, target, smoothstep(blendT))
	end

	safeSet(bloom, "Intensity", baseBloom * atten)
	safeSet(bloom, "Size", baseBloomSize)
	pcall(function() bloom.Threshold = baseBloomThresh end)

	-- ---- MainBlur Update ----
	local aBlurSize = (A.blur and A.blur.Size) or 0
	local bBlurSize = (B.blur and B.blur.Size) or 0
	local targetBlurSize = lerp(aBlurSize, bBlurSize, t)
	mainBlur.Size = targetBlurSize

	-- Debug logging (every 1 second)
	mainBlurUpdateCounter = mainBlurUpdateCounter + 1
	if mainBlurUpdateCounter >= 60 then
		debugPrint("MAIN_BLUR", "Size: " .. tostring(mainBlur.Size) .. " | Target: " .. tostring(targetBlurSize) .. " | Time: " .. tostring(clockTime))
		mainBlurUpdateCounter = 0
	end

	-- ---- Sun Rays Update ----
	local baseSRIntensity = lerp((A.sunrays and A.sunrays.Intensity) or sr.Intensity, (B.sunrays and B.sunrays.Intensity) or sr.Intensity, t)
	local baseSRSpread = lerp((A.sunrays and A.sunrays.Spread) or sr.Spread, (B.sunrays and B.sunrays.Spread) or sr.Spread, t)
	safeSet(sr, "Intensity", baseSRIntensity * atten)
	safeSet(sr, "Spread", baseSRSpread)

	-- ---- Depth of Field Update ----
	if (A.depthOfField or B.depthOfField) then
		local dof = df or getOrCreateDOF()
		local aD = A.depthOfField or { FocusDistance = dof.FocusDistance or 0, InFocusRadius = dof.InFocusRadius or 0, FarIntensity = dof.FarIntensity or 0, NearIntensity = dof.NearIntensity or 0 }
		local bD = B.depthOfField or aD
		pcall(function() dof.FocusDistance = lerp(aD.FocusDistance or 0, bD.FocusDistance or 0, t) end)
		pcall(function() dof.InFocusRadius = lerp(aD.InFocusRadius or 0, bD.InFocusRadius or 0, t) end)
		pcall(function() dof.FarIntensity = lerp(aD.FarIntensity or 0, bD.FarIntensity or 0, t) end)
		pcall(function() dof.NearIntensity = lerp(aD.NearIntensity or 0, bD.NearIntensity or 0, t) end)
	else
		if df then safeDestroy(df) end
	end

	-- ---- Skybox Update ----
	local skyA = A.sky or {}
	local skyB = B.sky or {}

	local skyChoice
	if aName == "Morning" and bName == "Morning" then
		skyChoice = skyA
	elseif aName == "Morning" and bName == "Sunset" then
		skyChoice = skyA
	elseif aName == "Sunset" and bName == "Sunset" then
		skyChoice = (t < SKYBOX_SWAP_THRESHOLD) and skyA or skyB
	else
		skyChoice = (t < SKYBOX_SWAP_THRESHOLD) and skyA or skyB
	end

	pcall(function() if skyChoice.Up then sky.SkyboxUp = skyChoice.Up end end)
	pcall(function() if skyChoice.Dn then sky.SkyboxDn = skyChoice.Dn end end)
	pcall(function() if skyChoice.Lf then sky.SkyboxLf = skyChoice.Lf end end)
	pcall(function() if skyChoice.Rt then sky.SkyboxRt = skyChoice.Rt end end)
	pcall(function() if skyChoice.Ft then sky.SkyboxFt = skyChoice.Ft end end)
	pcall(function() if skyChoice.Bk then sky.SkyboxBk = skyChoice.Bk end end)

	local aSun = (skyA and skyA.SunAngularSize) or sky.SunAngularSize
	local bSun = (skyB and skyB.SunAngularSize) or sky.SunAngularSize
	if type(aSun) == "number" and type(bSun) == "number" then
		pcall(function() sky.SunAngularSize = lerp(aSun, bSun, t) end)
	end

	local aMoon = (skyA and skyA.MoonAngularSize) or sky.MoonAngularSize
	local bMoon = (skyB and skyB.MoonAngularSize) or sky.MoonAngularSize
	if type(aMoon) == "number" and type(bMoon) == "number" then
		local moonT = clamp01((t - 0.6) / (1 - 0.6))
		pcall(function() sky.MoonAngularSize = lerp(aMoon, bMoon, moonT) end)
	end

	local aStars = (skyA and skyA.StarCount) or sky.StarCount
	local bStars = (skyB and skyB.StarCount) or sky.StarCount
	if type(aStars) == "number" and type(bStars) == "number" then
		local starT = (t >= SKYBOX_STAR_SWAP_THRESHOLD) and ((t - SKYBOX_STAR_SWAP_THRESHOLD)/(1 - SKYBOX_STAR_SWAP_THRESHOLD)) or 0
		pcall(function() sky.StarCount = lerp(aStars, bStars, clamp01(starT)) end)
	end

	-- ---- Vignette Update ----
	local vignA = (A.vignette and true) or false
	local vignB = (B.vignette and true) or false
	local vignNow = (t < SKYBOX_SWAP_THRESHOLD) and vignA or vignB
	if vignNow then createVignette() else removeVignette() end

	-- ---- Global Shadow Update ----
	local gsA = (A.lighting and A.lighting.GlobalShadows)
	local gsB = (B.lighting and B.lighting.GlobalShadows)
	if gsA ~= nil and gsB ~= nil then
		Lighting.GlobalShadows = (t < 0.5) and gsA or gsB
	end
end

debugPrint("VISUAL", "Main visual update function loaded")

-- ============================================
-- [15] Time Calculation Function
-- ============================================

local FULL_DAY_SECONDS = MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION + MORNING_DURATION

local function calculateClockTimeFromElapsed(elapsed)
	local t = 0
	if elapsed < MORNING_DURATION then
		t = elapsed / MORNING_DURATION
		return TIME_MORNING + (TIME_TRANSITION_START - TIME_MORNING) * t
	elseif elapsed < MORNING_DURATION + SUNSET_DURATION then
		local sub_t = (elapsed - MORNING_DURATION) / SUNSET_DURATION
		return TIME_TRANSITION_START + (TIME_SUNSET - TIME_TRANSITION_START) * sub_t
	elseif elapsed < MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION then
		local sub_t = (elapsed - MORNING_DURATION - SUNSET_DURATION) / EVENING_DURATION
		return TIME_SUNSET + (TIME_EVENING - TIME_SUNSET) * sub_t
	elseif elapsed < MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION + MORNING_DURATION then
		local sub_t = (elapsed - (MORNING_DURATION + SUNSET_DURATION + EVENING_DURATION)) / MORNING_DURATION
		local wrap = TIME_EVENING + (24 - TIME_EVENING + TIME_MORNING) * sub_t
		if wrap >= 24 then wrap = wrap - 24 end
		return wrap
	else
		return TIME_MORNING
	end
end

debugPrint("TIME", "Elapsed time calculation function loaded")

-- ============================================
-- [16] Initialization and Startup
-- ============================================

if not Lighting then
	debugPrint("ERROR", "Lighting service not found")
	return
end

Lighting.ClockTime = TIME_MORNING
setSunDirection(TIME_MORNING)
updateVisuals(Lighting.ClockTime)
initMenuBlur()

debugPrint("INIT", "✓ 3 Blurs created: MainBlur, WaterBlur, EscBlur")
debugPrint("INIT", "✓ System initialization complete")

-- ============================================
-- [17] Main Loop
-- ============================================

local last = tick()
local elapsed = 0

RunService.RenderStepped:Connect(function()
	local now = tick()
	local dt = now - last
	last = now
	elapsed = elapsed + dt

	if elapsed > FULL_DAY_SECONDS then
		elapsed = elapsed - FULL_DAY_SECONDS
	end

	local newCT = calculateClockTimeFromElapsed(elapsed)
	Lighting.ClockTime = newCT
	setSunDirection(newCT)
	updateVisuals(newCT)
	updateWaterBlur()
end)

debugPrint("MAIN", "Main loop started")