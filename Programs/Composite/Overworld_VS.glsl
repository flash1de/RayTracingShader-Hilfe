

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


#ifdef VS_IMAGE_STORE
	layout (rgba16f) uniform writeonly image2D colorimg2;
#endif


in vec3 vaPosition;


out vec3 worldShadowVector;
out vec3 worldSunVector;
out vec3 shadowVector;

out vec3 colorSunlight;
out vec3 colorMoonlight;
out vec3 colorShadowlight;

out vec3 colorSunSkylight;
out vec3 colorMoonSkylight;
out vec3 colorSkylight;

#ifdef VS_FOG_TIME
	out vec2 fogTime;
#endif

#ifdef VS_SUN_VISIBILITY
	out float cloudVisibility;
#endif

#ifdef VS_SHADOW_HIGHLIGHT
	out float shadowHighlightStrength;
#endif


#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"


vec2 CubemapProjection(vec3 dir){
	const float tileSize = SKYBOX_RESOLUTION / 3.0;
	float tileSizeDivide = 0.5 * tileSize - 1.5;
	vec3 adir = abs(dir);

	vec2 texel;
	if (adir.x > adir.y && adir.x > adir.z){
		dir /= adir.x;
		texel.x = dir.y * tileSizeDivide + tileSize * 0.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.x) + 0.5);
	}else if (adir.y > adir.x && adir.y > adir.z){
		dir /= adir.y;
		texel.x = dir.x * tileSizeDivide + tileSize * 1.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.y) + 0.5);
	}else{
		dir /= adir.z;
		texel.x = dir.x * tileSizeDivide + tileSize * 2.5;
		texel.y = dir.y * tileSizeDivide + tileSize * (step(0.0, dir.z) + 0.5);
	}

	return texel * (1.0 / SKYBOX_RESOLUTION);
}


void main(){
	#if FSR2_SCALE >= 0 && defined FULLRES_BUFFER
		gl_Position = vec4((vaPosition.xy * 2.0 - 1.0) * fsrRenderScale + fsrRenderScale - 1.0, 0.0, 1.0);
	#else
		gl_Position = vec4(vaPosition.xy * 8.0 - vec2(6.5, 1.5), 0.0, 1.0);
	#endif
	
	worldShadowVector = shadowModelViewInverse2;
	worldSunVector = worldShadowVector * (step(sunAngle, 0.5) * 2.0 - 1.0);
	shadowVector = mat3(gbufferModelView) * worldShadowVector;


	#ifdef VS_CLOUD_LIGHTING
		vec3 camera = vec3(0.0, 500.0 * 0.001 + atmosphereModel_bottom_radius, 0.0);
	#else
		#ifdef ATMO_HORIZON
			vec3 camera = vec3(0.0, max(cameraPosition.y, ATMO_MIN_ALTITUDE) * 0.001 + atmosphereModel_bottom_radius, 0.0);
		#else
			vec3 camera = vec3(0.0, max(cameraPosition.y, 63.0) * 0.001 + atmosphereModel_bottom_radius, 0.0);
		#endif
	#endif

	colorSunlight = GetSunAndSkyIrradiance(camera, worldSunVector, -worldSunVector, colorMoonlight, colorSunSkylight, colorMoonSkylight);

	float sunlightStrength = curve(saturate(worldSunVector.y * 30.0));
	float moonlightStrength = curve(saturate(worldSunVector.y * -5.0));
	float timeNoon = pow(1.0 - (clamp(worldSunVector.y, 0.2, 0.99) - 0.2) / 0.8, 6.0);

	colorSunlight *= sunlightStrength;
	colorMoonlight *= moonlightStrength;
	#ifdef COLD_MOONLIGHT
		DoNightEye(colorMoonlight);
	#endif

	colorShadowlight = colorSunlight + colorMoonlight;
	colorSkylight = colorSunSkylight + colorMoonSkylight;

	#ifdef VS_IMAGE_STORE
	    if (gl_VertexID == 0){
			imageStore(colorimg2, ivec2(0, 0), vec4(colorShadowlight, 0.0));
			imageStore(colorimg2, ivec2(1, 0), vec4(colorSkylight, 0.0));
			//imageStore(colorimg2, ivec2(2, 0), vec4(colorMoonSkylight, 0.0));
		}
	#endif
	
	#ifdef VS_FOG_TIME
		fogTime = vec2(
			timeNoon,
			moonlightStrength
		);
	#endif

	#ifdef VS_SUN_VISIBILITY
		vec2 skyImageCoord = CubemapProjection(worldShadowVector);
		
		cloudVisibility = saturate(textureLod(colortex12, skyImageCoord, 0.0).a * 1.5 - 0.5);
		cloudVisibility = mix(cloudVisibility, 1.0, curve(saturate((1.0 - saturate(worldSunVector.y)) * 12.0 - 11.0)) * saturate(1.0 - wetness * 1.5));
		cloudVisibility = mix(1.0, cloudVisibility, RAIN_SHADOW);
	#endif

	#ifdef VS_SHADOW_HIGHLIGHT
		vec2 skyImageCoord = CubemapProjection(worldShadowVector);

		float cloudVisibility = saturate(textureLod(colortex12, skyImageCoord, 0.0).a * 1.5 - 0.5);
		cloudVisibility = mix(cloudVisibility, 1.0, curve(saturate((1.0 - saturate(worldSunVector.y)) * 12.0 - 11.0)) * saturate(1.0 - wetness * 1.5));
		cloudVisibility = mix(1.0, cloudVisibility, RAIN_SHADOW);

		shadowHighlightStrength = cloudVisibility;
		shadowHighlightStrength *= timeNoon * 3.0 + 0.2;
	#endif
}
