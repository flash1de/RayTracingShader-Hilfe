

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;

#if FSR2_SCALE >= 0
	layout(rgba16f) uniform writeonly image2D colorimg8;
#endif

ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#ifdef DIMENSION_OVERWORLD
	in vec3 worldShadowVector;
	in vec3 shadowVector;
	in vec3 worldSunVector;

	in vec3 colorShadowlight;
	in vec3 colorSunlight;
	in vec3 colorMoonlight;

	in vec3 colorSkylight;
	in vec3 colorSunSkylight;
	in vec3 colorMoonSkylight;

	in vec2 fogTime;
#endif

#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"
#ifdef DIMENSION_OVERWORLD
#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"
#endif
#include "/Lib/BasicFunctions/Blocklight.glsl"
#include "/Lib/BasicFunctions/HeldLight.glsl"
#include "/Lib/BasicFunctions/VanillaComposite.glsl"
#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif

#ifdef DIMENSION_OVERWORLD
	#include "/Lib/IndividualFunctions/VolumetricFog.glsl"
	#define FULL_WATERFOG
	#include "/Lib/IndividualFunctions/WaterFog.glsl"
#endif
#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSky.glsl"
#endif

#include "/Lib/IndividualFunctions/DOF.glsl"

#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/Common.glsl"
#endif


vec4 GlassRefraction(vec3 normal, vec3 vertexNormal, vec3 viewPos, vec3 viewDir, inout float depth, inout float opaqueDist, float waterDist, MaterialMask mask){
	vec4 data1 = vec4(0.0);

	if (mask.stainedGlass + mask.water > 0.5){
		vec2 refractCoord = texCoord;
		float waterDeep = opaqueDist - waterDist;
		vec3 refractPos = viewPos;

		if (mask.stainedGlass > 0.5){
			vec3 refractDir = refract(viewDir, normal, 0.66);
			refractDir = refractDir / saturate(dot(refractDir, -normal));
			refractDir *= saturate(waterDeep * 2.0) * (float(depth >= 0.7) * 0.95 + 0.05) * 0.125;

			refractPos += refractDir;
		}else{			
			vertexNormal = vertexNormal * mat3(gbufferModelViewInverse);
			vec3 normalDiff = normal - vertexNormal;

			refractPos += (viewDir + normalDiff) * saturate(waterDeep * 0.3) * 5.0;
		}

		refractCoord = (vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * refractPos.xy + gbufferProjection[3].xy) / -refractPos.z * 0.5 + 0.5;

		#if FSR2_SCALE >= 0 
			float refractDepth = textureLod(depthtex1, refractCoord * fsrRenderScale, 0.0).x;
		#else
			float refractDepth = textureLod(depthtex1, refractCoord, 0.0).x;
		#endif

		if (refractDepth > depth && saturate(refractCoord) == refractCoord){
			#if FSR2_SCALE >= 0 
				data1 = textureLod(colortex1, refractCoord * fsrRenderScale, 0.0);
				depth = textureLod(depthtex1, refractCoord * fsrRenderScale, 0.0).x;
			#else
				data1 = textureLod(colortex1, refractCoord, 0.0);
				depth = textureLod(depthtex1, refractCoord, 0.0).x;
			#endif
			//opaqueDist = min(length(ViewPos_From_ScreenPos(refractCoord, depth)) + float(depth == 1.0) * 1e10, farDist);
			opaqueDist = length(ViewPos_From_ScreenPos(refractCoord, depth)) + float(depth == 1.0) * 1e10;
		}else{
			data1 = texelFetch(colortex1, texelCoord, 0);

			#ifdef DIMENSION_NETHER
				depth = texelFetch(depthtex1, texelCoord, 0).x;
			#endif
		}

		#ifdef DIMENSION_END
			if (mask.stainedGlass > 0.5){
				float rayDist = length(ViewPos_From_ScreenPos(refractCoord, depth));
				vec3 rayDir = mat3(gbufferModelViewInverse) * normalize(refractPos);
				EndFog(data1.xyz, waterDist, rayDist, rayDir, shadowModelViewInverseEnd[2]);
			}
		#endif

		#ifdef DIMENSION_NETHER
			if (mask.stainedGlass > 0.5){
				float rayDist = min(length(ViewPos_From_ScreenPos(refractCoord, depth)), far * 1.4);
				NetherFog(data1.xyz, waterDist, rayDist);
			}
		#endif

	}else{
		data1 = texelFetch(colortex1, texelCoord, 0);
	}

	return data1;
}


void MergeSpecular(inout vec3 color, vec3 viewPos, vec3 viewDir, float dist, vec3 normal, vec3 albedo, Material material, bool totalInternalReflection){
	vec4 reflection = texelFetch(colortex2, texelCoord, 0);

	//color = reflection.rgb; return;
	
	#ifdef SPECULAR_HELDLIGHT
		vec3 f0 = vec3(material.metalness);

		if (material.metalness > 229.5 / 255.0){
			#if TEXTURE_PBR_FORMAT == 0
				if(material.metalness < 237.5 / 255.0){
					f0 = PredefinedMetalF0(material.metalness);
				}else{
					f0 = albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
				}				
			#else
				f0 = albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
			#endif
		}
	#endif

	if (totalInternalReflection){
		color = reflection.rgb;
	}else{
		vec3 l = normalize(reflect(viewDir, normal) + normal * material.roughness);
		vec3 h = normalize(l - viewDir);
		float LdotH = saturate(dot(l, h));
		float NdotL = saturate(dot(normal, l));
		float NdotV = saturate(dot(normal, -viewDir));

		if (reflection.a < -0.5){
			float specular = F_Schlick(LdotH, material.metalness, 1.0);
			specular *= V_Schlick(NdotL, NdotV + 0.8, material.roughness);
			specular *= material.reflectionStrength;

			color = mix(color, reflection.rgb, saturate(specular));
		}else if (material.metalness > 229.5 / 255.0){
			#ifndef SPECULAR_HELDLIGHT
				vec3 f0 = vec3(0.0);
				#if TEXTURE_PBR_FORMAT == 0
					if(material.metalness < 237.5 / 255.0){
						f0 = PredefinedMetalF0(material.metalness);
					}else{
						f0 = albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
					}				
				#else
					f0 = albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
				#endif
			#endif

			vec3 specular = saturate(F_Schlick_Reflection(LdotH, f0));

			reflection.rgb *= specular;

			const float metalnessMask = clamp(METAL_ORIGIN_COLOR / (1.0 - METALMASK_STRENGTH), 0.0, 1.0);
			specular = metalnessMask - specular * metalnessMask;

			color = mix(texelFetch(colortex4, texelCoord, 0).rgb, color, specular);
			color += reflection.rgb;
						
		}else{
			color += reflection.rgb * material.reflectionStrength;
		}
	}

	#ifdef SPECULAR_HELDLIGHT
		if (heldBlockLightValue + heldBlockLightValue2 > 0.0)
			color += TorchSpecularHighlight(viewPos, viewDir, dist, normal, material.roughness, f0);
	#endif
}


void CaveFog(inout vec3 color, float worldDirY, float dist){
	if (eyeBrightnessZeroSmooth > 0.0 && isEyeInWater == 0){
		float fogDensity = 0.01 - worldDirY * 0.005;
		float fogFactor = 1.0 - exp2(-dist * fogDensity);
		fogFactor *= fogFactor;

		vec3 fogColor = mix(vec3(0.95, 0.99, 1.24), vec3(0.75, 0.99, 1.85), 0.5 - worldDirY * 0.5);

		color += fogColor * (fogFactor * eyeBrightnessZeroSmooth * (CAVE_FOG_BRIGHTNESS * 3e-5));
	}
}

#ifdef DIMENSION_OVERWORLD
	void Rain(inout vec3 color, float rainMask){
		vec3 rainSunlight = colorShadowlight * (5.0 - RAIN_SHADOW * 4.0);
		vec3 rainColor = colorSkylight + rainSunlight * 0.1;

		#ifndef DISABLE_LOCAL_PRECIPITATION
			color = mix(color, rainColor * (eyeSnowySmooth * 0.07 + 0.01), rainMask * (0.2 * eyeSnowySmooth + 0.15) * wetness * RAIN_VISIBILITY);
		#else
			color = mix(color, rainColor * 0.01, saturate(rainMask * wetness * (RAIN_VISIBILITY * 0.15)));
		#endif
	}
#endif

#if FSR2_SCALE >= 0
#ifdef DISTANT_HORIZONS

	vec2 ScreenVelocity(float depth, MaterialMask mask, bool isDH){
		vec2 velocity = vec2(0.0);

		if (mask.endPortal < 0.5){
			vec3 projection = vec3(texCoord, depth) * 2.0 - 1.0;

			if (isDH){
				projection = (vec3(vec2(dhProjectionInverse[0].x, dhProjectionInverse[1].y) * projection.xy, 0.0) + dhProjectionInverse[3].xyz) / (dhProjectionInverse[2].w * projection.z + dhProjectionInverse[3].w);

				projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;

				if (depth < 1.0) projection += cameraPositionToPrevious;

				projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
				projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

			}else{
				projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);

				if (mask.hand > 0.5){
					projection += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
				}else{
					projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
					projection += cameraPositionToPrevious;
					projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
				}
				
				projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;
			}
			
			velocity = texCoord - projection.xy;
		}
		
		return velocity;
	}

#else


	vec2 ScreenVelocity(float depth, MaterialMask mask){
		vec2 velocity = vec2(0.0);

		if (mask.endPortal < 0.5){
			vec3 projection = vec3(texCoord, depth) * 2.0 - 1.0;

			projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);

			if (mask.hand > 0.5){
				projection += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
			}else{
				projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
				if (depth < 1.0) projection += cameraPositionToPrevious;
				projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
			}
			
			projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

			velocity = texCoord - projection.xy;
		}

		return velocity;
	}

#endif
#endif


/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main(){
	float depth = texelFetch(depthtex0, texelCoord, 0).x;
	float opaqueDepth = texelFetch(depthtex1, texelCoord, 0).x;

	bool isSmooth = false;
	GbufferData gbuffer 			= GetGbufferDataTranslucent(isSmooth);
	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialID);

	vec3 viewPos 					= ViewPos_From_ScreenPos(texCoord, depth);
	vec3 viewPosOpaque 				= ViewPos_From_ScreenPos(texCoord, opaqueDepth);

	#ifdef DISTANT_HORIZONS

		#if FSR2_SCALE > 0
			bool isDH = false;
		#endif
		if (depth == 1.0){
			#if FSR2_SCALE > 0
				isDH = true;
			#endif
			depth 					= texelFetch(dhDepthTex0, texelCoord, 0).x;
			viewPos 				= ViewPos_From_ScreenPos_DH(texCoord, depth);
		}	
		if (opaqueDepth == 1.0){
			opaqueDepth 			= texelFetch(dhDepthTex1, texelCoord, 0).x;
			viewPosOpaque 			= ViewPos_From_ScreenPos_DH(texCoord, opaqueDepth);
		}
	#endif

	vec3 worldPos					= mat3(gbufferModelViewInverse) * viewPos;
	vec3 viewDir 					= normalize(viewPos.xyz);
	vec3 worldDir 					= normalize(worldPos.xyz);

	vec3 viewNormal 				= gbuffer.worldNormal * mat3(gbufferModelViewInverse);

	float waterDist 				= length(viewPos) + float(depth == 1.0) * 1e10;
	float opaqueDist 				= length(viewPosOpaque) + float(opaqueDepth == 1.0) * 1e10;

	float refractDepth = depth;
	vec4 data1 = GlassRefraction(viewNormal, gbuffer.vertexNormal, viewPos, viewDir, refractDepth, opaqueDist, waterDist, materialMask);
	#if FSR2_SCALE >= 0
		#ifdef DISTANT_HORIZONS
			if(materialMask.water > 0.5 || isDH) refractDepth = depth;
		#else
			if(materialMask.water > 0.5) refractDepth = depth;
		#endif
	#endif

	vec3 color = data1.xyz;
	float occludedWater = data1.w;
	#ifdef DISTANT_HORIZONS
		if(waterDist > opaqueDist) occludedWater = 0.0;
	#endif
	bool totalInternalReflection = false;

	#ifdef DIMENSION_OVERWORLD

		if (isEyeInWater == 1 && materialMask.water > 0.5){
			float VdotN = dot(worldDir, gbuffer.worldNormal);
			totalInternalReflection = 1.0 - (WATER_IOR * WATER_IOR) * (1.0 - VdotN * VdotN) < 0.0;
		}

	#endif

	if (materialMask.stainedGlass > 0.5){
		gbuffer.albedoAlpha = pow(gbuffer.albedoAlpha, 0.25);
		color *= mix(vec3(0.95), gbuffer.albedo * 0.95, gbuffer.albedoAlpha);
	}

	if (gbuffer.material.reflectionStrength > 0.0 && isEyeInWater == 1)
		MergeSpecular(color, viewPos, viewDir, waterDist, viewNormal, gbuffer.albedo, gbuffer.material, totalInternalReflection);
	
	#ifdef DIMENSION_OVERWORLD

		float k = 1.0 - (1.0 / (WATER_IOR * WATER_IOR)) * (1.0 - worldShadowVector.y * worldShadowVector.y);
		vec3 shadowVectorRefracted = -worldShadowVector * (1.0 / WATER_IOR);
		shadowVectorRefracted.y -= (1.0 / WATER_IOR) * -worldShadowVector.y + sqrt(k);
		float VdotSR = dot(shadowVectorRefracted, worldDir);

		#ifdef WATER_FOG
			if(isEyeInWater == 1 || occludedWater > 0.5){
				WaterFog(color, worldDir, opaqueDist, waterDist, gbuffer.worldNormal, VdotSR, materialMask, occludedWater, gbuffer.lightmap.g);
			}
		#endif

	#else

		if(isEyeInWater == 1 || occludedWater > 0.5) color *= vec3(0.5, 0.55, 0.7);
	#endif

	if (materialMask.stainedGlass > 0.5) color += gbuffer.albedo * (Radiance(gbuffer.albedo) * gbuffer.lightmap.r * materialMask.stainedGlass * (BLOCKLIGHT_BRIGHTNESS * 0.5));

	if (materialMask.particle + materialMask.particlelit > 0.5){
		vec3 particleColor = pow(color, vec3(0.75)) * gbuffer.albedo * 2.0;
		particleColor += materialMask.particlelit * gbuffer.albedo * (BLOCKLIGHT_BRIGHTNESS * 0.04);
		color = mix(color, particleColor, gbuffer.albedoAlpha);
	}

	if (gbuffer.material.reflectionStrength > 0.0 && isEyeInWater == 0)
		MergeSpecular(color, viewPos, viewDir, waterDist, viewNormal, gbuffer.albedo, gbuffer.material, totalInternalReflection);


	if (isEyeInWater == 2) color = mix(color, vec3(3.721, 0.775, 0.024) * BLOCKLIGHT_BRIGHTNESS, smoothstep(0.0, 1.0, opaqueDist));
	#ifdef DIMENSION_OVERWORLD
		if (isEyeInWater == 3) color = mix(color, colorSkylight * 0.5, smoothstep(0.0, 2.0, opaqueDist));
	#endif
	#ifdef DIMENSION_NETHER
		if (isEyeInWater == 3) color = mix(color, NetherLighting() * 0.3, smoothstep(0.0, 2.0, opaqueDist));
	#endif

	
	#ifdef DIMENSION_OVERWORLD

		#ifdef DISTANT_HORIZONS
			float farDist = clamp(dhFarPlane, 1024.0, 2048.0);
		#else
			float farDist = max(far * 1.4, 1024.0);
		#endif
		waterDist = min(waterDist, farDist);

		#ifdef DISTANT_HORIZONS
			#ifdef DH_LIMIT_VFOG_DIST
				vec3 rayWorldPos = worldDir * min(waterDist, max(float(dhRenderDistance), far) * 1.4);
			#else
				vec3 rayWorldPos = worldDir * min(length(worldPos) + float(depth == 1.0) * 1e10, max(float(dhRenderDistance), far) * 1.4);
			#endif
		#else
			vec3 rayWorldPos = worldDir * min(waterDist, far * 1.4);
		#endif

		#ifdef LANDSCATTERING
			LandAtmosphericScattering(color, waterDist, vec3(0.0), rayWorldPos, worldDir, materialMask.sky > 0.5);
		#endif

		float globalCloudShadow = 1.0 - wetness * (RAIN_SHADOW * 0.985);

		#ifdef UNDERWATER_VFOG
			if (isEyeInWater == 1) color += UnderwaterVolumetricFog(vec3(0.0), worldPos, worldDir, VdotSR, globalCloudShadow);
		#endif
		
		#ifdef VFOG
			float fogTimeFactor = 1.0;
			#ifndef VFOG_IGNORE_WORLDTIME
				#ifndef DISABLE_LOCAL_PRECIPITATION
					fogTimeFactor *= mix(fogTime.x, 1.0, wetness * (1.0 - eyeNoPrecipitationSmooth * 0.7));
				#else
					fogTimeFactor *= mix(fogTime.x, 1.0, wetness);
				#endif
			#endif

			if (fogTimeFactor > 0.01 && isEyeInWater == 0) VolumetricFog(color, vec3(0.0), rayWorldPos, worldDir, globalCloudShadow, fogTimeFactor);
		#endif

		#ifdef DIMENSION_OVERWORLD
		#ifdef CAVE_FOG
			CaveFog(color, worldDir.y, waterDist);
		#endif
		#endif

		if(isEyeInWater == 0.0 && wetness > 0.0) Rain(color, 1.0 - texelFetch(colortex0, texelCoord, 0).a);

	#endif

	#ifdef DIMENSION_END
		EndFog(color, waterDist, worldDir, shadowModelViewInverseEnd[2]);
	#endif

	#ifdef DIMENSION_NETHER
		NetherFog(color, waterDist);
	#endif

	//#ifndef DISABLE_BLINDNESS_DARKNESS
	//	if (darknessFactor > 0.0) color = mix(color, vec3(NOLIGHT_BRIGHTNESS), smoothstep(5.0, mix(far, 15.0, darknessFactor), waterDist) * darknessFactor);
	//	if (blindness > 0.0) color = mix(color, vec3(NOLIGHT_BRIGHTNESS), smoothstep(1.5, mix(far, 4.5, blindness), waterDist) * blindness);
	//#endif
	
	if (materialMask.selection > 0.5 && isEyeInWater < 3){
		float exposure = texelFetch(pixelData2D, ivec2(PIXELDATA_EXPOSURE, 0), 0).x * 0.13;
		color = gbuffer.albedo * exposure;
	}

	#if FSR2_SCALE >= 0
		//color = max(color, 0.0);
		//framebuffer1 = vec4(color, LockPerceivedLuminance(color, Exposure()));
		#ifdef DISTANT_HORIZONS
			vec2 velocity = ScreenVelocity(refractDepth, materialMask, isDH);
		#else
			vec2 velocity = ScreenVelocity(refractDepth, materialMask);
		#endif
		imageStore(colorimg8, texelCoord, vec4(velocity, 0.0, 0.0));
	#endif

	#ifdef DOF
		framebuffer1 = vec4(max(color, 0.0), CoCSpread());
	#elif defined DIMENSION_NETHER
		framebuffer1 = vec4(max(color, 0.0), -viewPos.z);
	#else
		framebuffer1 = vec4(max(color, 0.0), 0.0);
	#endif
}