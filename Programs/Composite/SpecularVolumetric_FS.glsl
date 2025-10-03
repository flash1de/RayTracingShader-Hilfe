

#define BLACKHOLE_LQ


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;

#ifdef DIMENSION_OVERWORLD
	in vec3 worldShadowVector;
	in vec3 worldSunVector;

	in vec3 colorShadowlight;
	in vec3 colorSunlight;
	in vec3 colorMoonlight;

	in vec3 colorSkylight;
	in vec3 colorSunSkylight;
	in vec3 colorMoonSkylight;

	in vec2 fogTime;
#endif

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D shadowcolor0;

uniform sampler3D voxelData3D;

#ifdef PT_IRC
	uniform sampler3D irradianceCache3D;
	uniform sampler3D irradianceCache3D_Alt;
#endif


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"
#ifdef DIMENSION_OVERWORLD
#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"
#endif
#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif

#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"

#ifdef DIMENSION_OVERWORLD
	#include "/Lib/IndividualFunctions/WaterFog.glsl"

	#define VFOG_LQ
	#include "/Lib/IndividualFunctions/VolumetricFog.glsl"
#endif
#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSky.glsl"
#endif

void main(){
	float depth = texelFetch(depthtex0, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = -texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

	if (abs(depth) == 1.0) discard;

	bool isSmooth = false;
	GbufferData gbuffer = GetGbufferDataTranslucent(isSmooth);
	MaterialMask materialMask = CalculateMasks(gbuffer.materialID);

	framebuffer2 = vec4(0.0);

	if (gbuffer.material.reflectionStrength > 0.0){
		vec3 viewPos = ViewPos_From_ScreenPos(texCoord, depth);
		#ifdef DISTANT_HORIZONS
			if (depth < 0.0) viewPos = ViewPos_From_ScreenPos_DH(texCoord, -depth);
		#endif
		vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz;
		vec3 worldDir = normalize(worldPos.xyz);

		vec3 hitWorldPos = texelFetch(colortex4, texelCoord, 0).xyz;

		framebuffer2 = texelFetch(colortex2, texelCoord, 0);
		vec3 reflection = framebuffer2.rgb;

		vec3 rayDir = hitWorldPos.xyz - worldPos;
		float hitDist = length(rayDir);
		rayDir /= max(hitDist, 1e-20);

		float specular = 1.0;
		if (gbuffer.material.metalness < 229.5 / 255.0 && !isSmooth){
			vec3 h = normalize(rayDir - worldDir);
			float LdotH = saturate(dot(rayDir, h));
			float NdotL = saturate(dot(gbuffer.worldNormal, rayDir));
			float NdotV = saturate(dot(-worldDir, gbuffer.worldNormal));

			specular *= F_Schlick(LdotH, gbuffer.material.metalness, 1.0).x;
			specular *= V_Schlick(NdotL, NdotV + 0.8, gbuffer.material.roughness);
		}

		if (hitDist > 0.0){

			float dist = length(worldPos);
			#ifdef DISTANT_HORIZONS
				float farDist = max(float(dhRenderDistance), far) * 1.4;
				#ifdef DH_LIMIT_VFOG_DIST
					farDist = min(2048.0, farDist);
				#endif
			#else
				float farDist = far * 1.4;
			#endif
			
			#ifdef DIMENSION_OVERWORLD
				float rayDist = max(min(hitDist + dist, farDist) - dist, 0.0);
				vec3 endPos = worldPos + rayDir * rayDist;
				float globalCloudShadow = 1.0 - wetness * (RAIN_SHADOW * 0.985);	


				#if (defined UNDERWATER_VFOG && defined VFOG_REFLECTION) || defined WATER_FOG
					if (isEyeInWater == 1){
						float k = 1.0 - (1.0 / (WATER_IOR * WATER_IOR)) * (1.0 - worldShadowVector.y * worldShadowVector.y);
						vec3 shadowVectorRefracted = -worldShadowVector * (1.0 / WATER_IOR);
						shadowVectorRefracted.y -= (1.0 / WATER_IOR) * -worldShadowVector.y + sqrt(k);
						float VdotSR = dot(shadowVectorRefracted, rayDir);

						#ifdef WATER_FOG
							WaterFog(reflection, rayDir, hitDist, VdotSR);
						#endif

						#ifdef UNDERWATER_VFOG
						#ifdef VFOG_REFLECTION
							reflection += UnderwaterVolumetricFog(worldPos, endPos, rayDir, VdotSR, globalCloudShadow);
						#endif
						#endif
					}
				#endif

				#ifdef LANDSCATTERING
					#ifdef DISTANT_HORIZONS
						LandAtmosphericScattering(reflection, rayDist, worldPos, endPos, rayDir, hitDist > 5e4);
					#else
						#ifdef LANDSCATTERING_REFLECTION
							LandAtmosphericScattering(reflection, rayDist, worldPos, endPos, rayDir, hitDist > 5e4);
						#endif
					#endif
				#endif

				#ifdef VFOG
				#ifdef VFOG_REFLECTION
					float fogTimeFactor = 1.0;
					#ifndef VFOG_IGNORE_WORLDTIME
						#ifndef DISABLE_LOCAL_PRECIPITATION
							fogTimeFactor *= mix(fogTime.x, 1.0, wetness * (1.0 - eyeNoPrecipitationSmooth * 0.7));
						#else
							fogTimeFactor *= mix(fogTime.x, 1.0, wetness);
						#endif
					#endif

					if (fogTimeFactor > 0.01 && isEyeInWater == 0) VolumetricFog(reflection, worldPos, endPos, rayDir, globalCloudShadow, fogTimeFactor);
				#endif
				#endif

			#endif

			#ifdef DIMENSION_NETHER
				dist = min(dist, 200.0);
				float rayDist = min(hitDist + dist, 200.0);

				NetherFog(reflection, dist, rayDist);

			#endif

			#ifdef DIMENSION_END
				if (hitDist > 5e4){
					BlackHole_AccretionDisc_Stars(reflection, rayDir, shadowModelViewInverseEnd[2]);
					PlanetEnd2(reflection, vec3(0.0), rayDir);
				}

				float rayDist = hitDist + dist;

				EndFog(reflection, rayDist, rayDir, shadowModelViewInverseEnd[2]);

				//if(isEyeInWater == 1) reflection *= vec3(0.5, 0.55, 0.7);
			#endif

		}

		reflection *= saturate(specular);

		framebuffer2 = vec4(reflection, framebuffer2.a);
	}
}
