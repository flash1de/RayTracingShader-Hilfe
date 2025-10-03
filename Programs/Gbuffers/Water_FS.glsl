//Water_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float wetness;
uniform float rainStrength;
uniform int isEyeInWater;

uniform vec2 taaJitter;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;


/* RENDERTARGETS: 1,5,6 */
layout(location = 0) out vec4 framebuffer1;
layout(location = 1) out vec4 framebuffer5;
layout(location = 2) out vec4 framebuffer6;


in vec3 v_color;
in vec2 v_texCoord;
in vec3 v_worldPos;
in vec2 v_blockLight;
flat in float v_materialIDs;

#ifdef TERRAIN_VS_TBN
	in mat3 v_tbn;
#endif


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


#include "/Lib/IndividualFunctions/WaterWaves.glsl"

#include "/Lib/IndividualFunctions/Ripple.glsl"


void main(){
//TBN
	vec2 duv1 = dFdx(v_texCoord);
	vec2 duv2 = dFdy(v_texCoord);
	
	#ifndef TERRAIN_VS_TBN
		vec3 dp1 = dFdx(v_worldPos);
		vec3 dp2 = dFdy(v_worldPos);

		vec3 N = normalize(cross(dp1, dp2));
		vec3 dp2perp = cross(dp2, N);
		vec3 dp1perp = cross(N, dp1);
		vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
		vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
		float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
		mat3 v_tbn = mat3(T * invmax, B * invmax, N);
	#endif


	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif


//albedo
	vec4 albedo = textureGrad(tex, v_texCoord, duv1, duv2);
	albedo.rgb *= v_color;

	#if WHITE_DEBUG_WORLD > 0
		//tex.rgb = vec3(1.0);
	#endif


//wet
	vec3 mcPos = v_worldPos + cameraPosition;
	float NdotU = v_tbn[2].y;

	#ifdef ENABLE_ROUGH_SPECULAR

		#ifdef DIMENSION_OVERWORLD
			#ifndef DISABLE_LOCAL_PRECIPITATION
				float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
			#else
				float wet = wetness + SURFACE_WETNESS;
			#endif

			wet *= step(0.9, v_blockLight.y);

			vec2 rainNormal = vec2(0.0);
			if (wet > 1e-7){
				wet *= GetModulatedRainSpecular(mcPos);
						
				wet *= saturate(v_blockLight.y * 10.0 - 9.0);
				wet = saturate(wet * 1.8);

				if (isEyeInWater == 1) NdotU = -NdotU;

				#ifdef RAIN_SPLASH_EFFECT
					float splashStrength = rainStrength;
					splashStrength *= saturate(NdotU * 2.0 - 1.0);
					splashStrength *= exp2(-length(v_worldPos) * 0.05);

					if (splashStrength > 1e-5) rainNormal = GetRippleNormal(mcPos.xz, wet, splashStrength);

					if (isEyeInWater == 1) rainNormal = -rainNormal;
				#endif

				wet *= saturate(NdotU * 0.5 + 0.5);
			}

		#else
			float wet = SURFACE_WETNESS;

			if (wet > 1e-7){
				wet *= GetModulatedRainSpecular(mcPos);
				wet = saturate(wet * 1.8);
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
		#ifdef MC_NORMAL_MAP
			waterNormal = DecodeNormalTex(textureGrad(normals, v_texCoord, duv1, duv2).rgb);
			#ifdef ENABLE_ROUGH_SPECULAR
				waterNormal = mix(waterNormal, vec3(0.0, 0.0, 1.0), wet);
			#endif
		#endif

		waterNormal = v_tbn * waterNormal;
	}

	#if defined ENABLE_ROUGH_SPECULAR && defined DIMENSION_OVERWORLD && defined RAIN_SPLASH_EFFECT 
		waterNormal = normalize(waterNormal + vec3(rainNormal.x, 0.0, rainNormal.y));
	#endif



	//framebuffer0 = vec4(albedo.rgb, 1.0);
	framebuffer1 = vec4(0.0, 0.0, 0.0, float(v_materialIDs == MATID_WATER));
	framebuffer5 = vec4(Pack2x8(albedo.rg), Pack2x8(albedo.ba), Pack2x8(vec2(1.0, v_materialIDs / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
	framebuffer6 = vec4(EncodeNormal(waterNormal), EncodeNormal(v_tbn[2]));
}
