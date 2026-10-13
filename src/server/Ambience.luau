-- Late-afternoon match lighting: low golden sun, warm haze, bloom on the floodlights and a
-- light colour grade. Set once by the server; Lighting replicates to clients.

local Lighting = game:GetService("Lighting")

local Ambience = {}

local function effect(className: string, props: { [string]: any })
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = Lighting
end

function Ambience.apply()
	Lighting.ClockTime = 17.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(95, 92, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 142, 155)
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	effect("Atmosphere", {
		Density = 0.3,
		Offset = 0.1,
		Color = Color3.fromRGB(199, 178, 166),
		Decay = Color3.fromRGB(106, 100, 130),
		Glare = 0.4,
		Haze = 1.4,
	})
	effect("BloomEffect", { Intensity = 0.8, Size = 28, Threshold = 1.3 })
	effect("ColorCorrectionEffect", {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.12,
		TintColor = Color3.fromRGB(255, 244, 232),
	})
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.7 })
end

return Ambience
