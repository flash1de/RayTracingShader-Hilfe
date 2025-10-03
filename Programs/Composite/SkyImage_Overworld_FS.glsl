

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 12 */
layout(location = 0) out vec4 framebuffer12;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;

in vec3 worldShadowVector;
in vec3 worldSunVector;
//in vec3 shadowVector;

//in vec3 colorSunlight;
//in vec3 colorMoonlight;
in vec3 colorShadowlight;

//in vec3 colorSunSkylight;
//in vec3 colorMoonSkylight;
in vec3 colorSkylight;

//in vec2 fogTime;


#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"
#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"

#include "/Lib/IndividualFunctions/NUBIS.glsl"
#include "/Lib/IndividualFunctions/PlanarClouds.glsl"


vec3 CubemapProjectionInverse(vec2 texel){
	const float tileSize = SKYBOX_RESOLUTION / 3.0;
	float tileSizeDivide = 1.0 / (0.5 * tileSize - 1.5);

	vec3 dir = vec3(0.0);

	if (texel.x < tileSize) {
		dir.x = step(tileSize, texel.y) * 2.0 - 1.0;
		dir.y = (texel.x - tileSize * 0.5) * tileSizeDivide;
		dir.z = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
	} else if (texel.x < 2.0 * tileSize) {
		dir.x = (texel.x - tileSize * 1.5) * tileSizeDivide;
		dir.y = step(tileSize, texel.y) * 2.0 - 1.0;
		dir.z = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
	} else {
		dir.x = (texel.x - tileSize * 2.5) * tileSizeDivide;
		dir.y = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
		dir.z = step(tileSize, texel.y) * 2.0 - 1.0;
	}

	return normalize(dir);
}

////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main(){
	float depth 					= texelFetch(depthtex1, texelCoord, 0).x;
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
	//vec2 noise_1 = BlueNoiseTemporal().xy;

	vec2 cloudAltitude = vec2(mix(CLOUD_CLEAR_ALTITUDE, CLOUD_RAIN_ALTITUDE, wetness));
	cloudAltitude.y += mix(CLOUD_CLEAR_THICKNESS, CLOUD_RAIN_THICKNESS, wetness);

	float wind = 0.0005 * (frameTimeCounter * CLOUD_SPEED + 10.0 * FTC_OFFSET);
	//wind = 0.0005 * mod(frameTimeCounter * 50.0, 3600.0);
	vec3 windDirection = vec3(1.0, wetness * 0.1 - 0.05, -0.4) * wind;


//////////////////// Sky Image /////////////////////////////////////////////////////////////////////
//////////////////// Sky Image /////////////////////////////////////////////////////////////////////

	vec3 skyImage = vec3(0.0);

	vec3 viewVector = CubemapProjectionInverse(gl_FragCoord.xy);

	#ifdef ATMO_REFLECTION_HORIZON
		bool horizon = true;
	#else
		bool horizon = false;
	#endif
	vec3 transmittance = vec3(1.0);
	bool ray_r_mu_intersects_ground;
	vec3 atmosphere = GetSkyRadiance(cameraSkyBox, viewVector, worldSunVector, -worldSunVector, horizon, transmittance, ray_r_mu_intersects_ground);

	skyImage += atmosphere;

	float cloudTransmittance = 1.0;
	#ifdef VOLUMETRIC_CLOUDS
		if ((cameraPosition.y > cloudAltitude.x || !ray_r_mu_intersects_ground) && (cameraPosition.y < cloudAltitude.y || worldDir.y < 0.0))
			NubisCumulus(skyImage, viewVector, cloudAltitude, windDirection, camera, noise_0, cloudTransmittance);
	#endif

	#ifdef PLANAR_CLOUDS
		if (cameraPosition.y < PC_ALTITUDE && !ray_r_mu_intersects_ground)
			PlanarClouds(skyImage, viewVector, cameraSkyBox, noise_0.x, cloudTransmittance);
	#endif

	#ifdef CAVE_MODE
		skyImage = mix(skyImage, vec3(max(NOLIGHT_BRIGHTNESS, 0.00005) * 0.07), eyeBrightnessZeroSmooth);
	#endif

	framebuffer12 = vec4(skyImage, cloudTransmittance);
}
