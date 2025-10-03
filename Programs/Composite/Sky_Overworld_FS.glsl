

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;

in vec3 worldShadowVector;
in vec3 worldSunVector;

in vec3 colorShadowlight;
//in vec3 colorSunlight;
//in vec3 colorMoonlight;

in vec3 colorSkylight;
//in vec3 colorSunSkylight;
//in vec3 colorMoonSkylight;

in vec2 fogTime;


#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"
#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"

#include "/Lib/IndividualFunctions/NUBIS.glsl"
#include "/Lib/IndividualFunctions/PlanarClouds.glsl"

// Modified from spectrum by zombye

vec3 HashStars(vec3 worldDir){
	#if FSR2_SCALE >= 0
		const float scale = 300.0 - float(FSR2_SCALE) * 40.0;
		const float coverage = 0.007 + FSR2_SCALE * 0.003;
	#else
		const float scale = 384.0;
		const float coverage = 0.007;
	#endif
	const float maxLuminance = 0.05;
	const float minTemperature = 4000.0;
	const float maxTemperature = 8000.0;


	worldDir =  mat3(shadowModelView0, shadowModelView1, shadowModelView2) * worldDir;

	vec3  p = worldDir * scale;
	ivec3 i = ivec3(floor(p));
	vec3  f = p - i;
	float r = dot(f - 0.5, f - 0.5);

	vec3 i3 = fract(i * vec3(443.897, 441.423, 437.195));
	i3 += dot(i3, i3.yzx + 19.19);
	vec2 hash = fract((i3.xx + i3.yz) * i3.zy);
	hash.y = 2.0 * hash.y - 4.0 * hash.y * hash.y + 3.0 * hash.y * hash.y * hash.y;

	float c = remapSaturate(hash.x, 1.0 - coverage, 1.0);
	return (maxLuminance * remapSaturate(r, 0.25, 0.0) * c * c) * Blackbody(mix(minTemperature, maxTemperature, hash.y));
}

////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main(){
	float depth 					= texelFetch(depthtex1, texelCoord, 0).x;

	if (depth < 1.0) discard;

	vec3 viewPos 					= ViewPos_From_ScreenPos(texCoord, depth);

	vec3 worldPos					= mat3(gbufferModelViewInverse) * viewPos;

	vec3 viewDir 					= normalize(viewPos);
	vec3 worldDir 					= normalize(worldPos);

	#ifdef ATMO_HORIZON
		vec3 camera = vec3(0.0, max(cameraPosition.y, ATMO_MIN_ALTITUDE) * 0.001 + atmosphereModel_bottom_radius, 0.0);
	#else
		vec3 camera = vec3(0.0, max(cameraPosition.y, 63.0) * 0.001 + atmosphereModel_bottom_radius, 0.0);
	#endif

	vec3 cameraSkyBox = vec3(0.0, max(cameraPosition.y, ATMO_SKYBOX_MIN_ALTITUDE) * 0.001 + atmosphereModel_bottom_radius, 0.0);

	vec2 noise_0  = vec2(bayer64(gl_FragCoord.xy), 0.5);
	vec2 noise_1 = BlueNoiseTemporal().xy;

	vec2 cloudAltitude = vec2(mix(CLOUD_CLEAR_ALTITUDE, CLOUD_RAIN_ALTITUDE, wetness));
	cloudAltitude.y += mix(CLOUD_CLEAR_THICKNESS, CLOUD_RAIN_THICKNESS, wetness);

	float wind = 0.0005 * (frameTimeCounter * CLOUD_SPEED + 10.0 * FTC_OFFSET);
	//wind = 0.0005 * mod(frameTimeCounter * 50.0, 3600.0);
	vec3 windDirection = vec3(1.0, wetness * 0.1 - 0.05, -0.4) * wind;


//////////////////// Sky ///////////////////////////////////////////////////////////////////////////
//////////////////// Sky ///////////////////////////////////////////////////////////////////////////

	vec3 color = vec3(0.0);

	vec3 transmittance = vec3(1.0);

	#ifdef ATMO_HORIZON
		bool horizon = true;
	#else
		bool horizon = false;
	#endif
	bool ray_r_mu_intersects_ground;
	vec3 atmosphere = GetSkyRadiance(camera, worldDir, worldSunVector, -worldSunVector, horizon, transmittance, ray_r_mu_intersects_ground);

	color += atmosphere;

	float cloudTransmittance = 1.0;
	#ifdef VOLUMETRIC_CLOUDS
		if ((cameraPosition.y > cloudAltitude.x || !ray_r_mu_intersects_ground) && (cameraPosition.y < cloudAltitude.y || worldDir.y < 0.0))
			NubisCumulus(color, worldDir, cloudAltitude, windDirection, camera, noise_1, cloudTransmittance);
	#endif

	#ifdef PLANAR_CLOUDS
		if (cameraPosition.y < PC_ALTITUDE && !ray_r_mu_intersects_ground)
			PlanarClouds(color, worldDir, camera, noise_1.y, cloudTransmittance);
	#endif


	vec3 celestial = GammaToLinear(texelFetch(colortex0, texelCoord, 0).rgb) * (SKY_TEXTURE_BRIGHTNESS * 0.2);

	#if STAR_TYPE == 1
		celestial += HashStars(worldDir);
	#endif

	celestial *= NIGHT_BRIGHTNESS;

	vec3 sunDisc = RenderSunDisc(worldDir, worldSunVector) * (3.2 - fogTime.x * 3.0);
	vec3 moonDisc = vec3(0.8886, 1.0019, 1.3095) * (RenderMoonDisc(worldDir, -worldSunVector) * NIGHT_BRIGHTNESS);

	#ifdef MOON_TEXTURE
		celestial = mix(celestial * cloudTransmittance + sunDisc + moonDisc,
						(celestial + sunDisc + moonDisc * float(isEyeInWater != 0)) * cloudTransmittance,
						mix(1.0, RAIN_SHADOW, wetness));
	#else
		celestial = mix(celestial * cloudTransmittance + sunDisc + moonDisc,
						(celestial + sunDisc + moonDisc) * cloudTransmittance,
						mix(1.0, RAIN_SHADOW, wetness));
	#endif

	color += celestial * transmittance * 200.0;

	#ifdef CAVE_MODE
		color = mix(color, vec3(max(NOLIGHT_BRIGHTNESS, 0.00007) * 0.05), saturate(eyeBrightnessZeroSmooth));
	#endif

	//color *= saturate(worldDir.y * 25.0 + 0.5);
		
	//color /= MAIN_OUTPUT_FACTOR;
	//color = LinearToCurve(color);

	framebuffer2 = vec4(max(color, vec3(0.0)), 0.0);

}
