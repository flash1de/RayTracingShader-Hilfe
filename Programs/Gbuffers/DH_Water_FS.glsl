//DH_Terrain_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform float far;
uniform float frameTimeCounter;
uniform float wetness;
uniform int isEyeInWater;

uniform vec2 taaJitter;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;


/* RENDERTARGETS: 1,5,6 */
layout(location = 0) out vec4 framebuffer1;
layout(location = 1) out vec4 framebuffer5;
layout(location = 2) out vec4 framebuffer6;


in vec4 v_color;
in vec3 v_worldPos;
in mat3 v_tbn;
in float v_blockLight;
flat in float v_materialIDs;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif
#include "/Lib/IndividualFunctions/WaterWaves.glsl"
#include "/Lib/IndividualFunctions/Ripple.glsl"


void DH_noise(inout vec4 color, vec3 pos){
	const float steps = DH_TEXTURE_NOISE_STEPS;
	pos = floor(pos * steps) / steps;
	
	float weight = Luminance(color.rgb) * 2.0 - 1.0;
	weight = 1.0 - weight * weight;
	weight *= DH_TEXTURE_NOISE_STRENGTH * color.a;

	float noise = fract(sin(dot(pos.xy + fract(sin(pos.z * (91.3458)) * 47453.5453), vec2(12.9898, 78.233))) * 43758.5453);
	noise = (noise * 2.0 - 1.0) * weight;

	color.rgb = saturate(color.rgb - color.rgb * noise);
}


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	#ifdef DH_TERRAIN_CULLING
		if (length(v_worldPos) < far * 0.7 || texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0) discard;
	#else
		if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0) discard;
	#endif

//albedo
	vec4 albedo = v_color;
	#ifdef DH_TEXTURE_NOISE
		DH_noise(albedo, v_worldPos + cameraPosition + v_tbn[2] * 0.001);
	#endif

	#if WHITE_DEBUG_WORLD > 0
		albedo.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif

//wet effect
	vec3 mcPos = v_worldPos + cameraPosition;
	float NdotU = v_tbn[2].y;

	#ifdef ENABLE_ROUGH_SPECULAR
	
		#ifdef DIMENSION_OVERWORLD
			#ifndef DISABLE_LOCAL_PRECIPITATION
				float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
			#else
				float wet = wetness + SURFACE_WETNESS;
			#endif

			wet *= step(0.9, v_blockLight);

			if (wet > 1e-7){
				wet *= GetModulatedRainSpecular(mcPos);
				wet *= saturate(v_blockLight * 10.0 - 9.0);
				wet *= saturate(NdotU * 0.5 + 0.5);
			}

		#else
			float wet = SURFACE_WETNESS;

			if (wet > 1e-7){
				GetModulatedRainSpecular(mcPos);
				wet *= saturate(NdotU * 0.5 + 0.5);
			}
		#endif

	#else
		float wet = 0.0;
	#endif

//normal
	vec3 waterNormal = vec3(0.0, 0.0, 1.0);

	if (v_materialIDs == MATID_WATER){
		#ifdef WATER_PARALLAX
			mcPos = WaveParallax(mcPos, normalize((v_worldPos.xyz - gbufferModelViewInverse[3].xyz) * v_tbn));
		#endif
		NdotU = saturate(NdotU + float(isEyeInWater == 1) * 2.0);
		waterNormal = WaveNormal(mcPos, NdotU * 13.0 + 5.0);

		waterNormal = v_tbn * waterNormal;

		vec3 worldDir = -normalize(v_worldPos.xyz);
		#ifdef DISTANT_HORIZONS
			const float weight = 0.06;
		#else
			const float weight = 0.03;
		#endif
		waterNormal = normalize(waterNormal.xyz + (v_tbn[2] / (max(0.0, dot(v_tbn[2], worldDir)) + 0.001)) * weight);

	}else{
		waterNormal = v_tbn[2];
	}


	framebuffer1 = vec4(0.0, 0.0, 0.0, float(v_materialIDs == MATID_WATER));
	framebuffer5 = vec4(Pack2x8(albedo.rg), Pack2x8(albedo.ba), Pack2x8(vec2(1.0, v_materialIDs / 255.0)), Pack2x8(vec2(0.0, saturate(v_blockLight + 1e-6))));
	framebuffer6 = vec4(EncodeNormal(waterNormal), EncodeNormal(v_tbn[2]));
}