

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


#if FSR2_SCALE >= 0
/*
const int 	colortex3Format 		= RGBA16F;
const int 	colortex7Format 		= RGBA8;
const int 	colortex14Format 		= RGBA8;

const bool	colortex7Clear 			= true;
const bool	colortex14Clear 		= false;
*/
#else
#ifdef DIMENSION_NETHER
/*
const int 	colortex3Format 		= RGBA32F;
*/
#else
/*
const int 	colortex3Format 		= RGBA16F;
*/
#endif
#endif

/*
const int 	colortex0Format 		= RGBA8;
const int 	colortex1Format 		= RGBA16F;
const int 	colortex2Format 		= RGBA16F;
const int 	colortex4Format 		= RGBA16F;
const int 	colortex5Format 		= RGBA16;
const int 	colortex6Format 		= RGBA16;
const int 	colortex8Format 		= RGBA16F;
const int 	colortex9Format 		= RGBA32F;
const int 	colortex10Format 		= RGBA16F;
const int 	colortex12Format 		= RGBA16F;

const int 	shadowcolor1Format 		= RGBA16;


const bool	colortex0Clear 			= true;
const vec4	colortex0ClearColor 	= vec4(0.0, 0.0, 0.0, 1.0);
const bool	colortex1Clear 			= true;
const bool	colortex2Clear 			= true;
const bool	colortex3Clear 			= false;
const bool	colortex4Clear 			= true;
const bool	colortex5Clear 			= true;
const bool	colortex6Clear 			= true;
const bool	colortex8Clear 			= false;
const bool	colortex9Clear 			= false;
const bool	colortex10Clear 		= false;
const bool	colortex12Clear 		= true;

const float shadowIntervalSize 			= 4.0;
const float shadowDistanceRenderMul 	= 1.0;

const bool 	shadowHardwareFiltering0 	= false;
const bool 	shadowHardwareFiltering1 	= false;
const bool 	shadowtex0Mipmap 			= false;
const bool 	shadowtex0Nearest 			= false;
const bool 	shadowtex1Mipmap 			= false;
const bool 	shadowtex1Nearest 			= false;
const bool 	shadowcolor0Mipmap 			= false;
const bool 	shadowcolor0Nearest 		= false;
const bool 	shadowcolor1Mipmap 			= false;
const bool 	shadowcolor1Nearest 		= false;


const int 	noiseTextureResolution 	= 64;

const float wetnessHalflife 		= 10.0; 	//[10.0 20.0 30.0 50.0 75.0 100.0 150.0 200.0 300.0 500.0]
const float drynessHalflife 		= 10.0; 	//[10.0 20.0 30.0 50.0 75.0 100.0 150.0 200.0 300.0 500.0]
const float eyeBrightnessHalflife 	= 10.0;

const float sunPathRotation 		= -30.0; 	// [-90.0 -89.0 -88.0 -87.0 -86.0 -85.0 -84.0 -83.0 -82.0 -81.0 -80.0 -79.0 -78.0 -77.0 -76.0 -75.0 -74.0 -73.0 -72.0 -71.0 -70.0 -69.0 -68.0 -67.0 -66.0 -65.0 -64.0 -63.0 -62.0 -61.0 -60.0 -59.0 -58.0 -57.0 -56.0 -55.0 -54.0 -53.0 -52.0 -51.0 -50.0 -49.0 -48.0 -47.0 -46.0 -45.0 -44.0 -43.0 -42.0 -41.0 -40.0 -39.0 -38.0 -37.0 -36.0 -35.0 -34.0 -33.0 -32.0 -31.0 -30.0 -29.0 -28.0 -27.0 -26.0 -25.0 -24.0 -23.0 -22.0 -21.0 -20.0 -19.0 -18.0 -17.0 -16.0 -15.0 -14.0 -13.0 -12.0 -11.0 -10.0 -9.0 -8.0 -7.0 -6.0 -5.0 -4.0 -3.0 -2.0 -1.0 0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0]

const float ambientOcclusionLevel 	= 1.0;
const int 	superSamplingLevel 		= 0;
*/


#ifdef EYES_LIGHTING
#endif
#ifdef ENTITIES_VS_TBN
#endif
#ifdef ENTITIES_PARALLAX
#endif
#ifdef PT_TAG_DETECTION
#endif
#ifdef HAND_SCREEN_SHADOW
#endif
#ifdef DISABLE_HAND_DOF
#endif
#ifdef DECREASE_HAND_GHOSTING
#endif
#ifdef DISABLE_PLAYER_TAA_MOTION_BLUR
#endif
#ifdef PT_DIFFUSE_SST_REPORJECT
#endif

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler3D voxelData3D;

#ifdef PT_IRC
	uniform sampler3D irradianceCache3D;
	uniform sampler3D irradianceCache3D_Alt;
#endif

/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;

layout(rgba16f) uniform writeonly image2D colorimg4;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;

#ifdef DIMENSION_END
	const vec3 worldShadowVector = shadowModelViewInverseEnd[2];
	vec3 shadowVector = worldShadowVector * mat3(gbufferModelViewInverse);
#elif defined DIMENSION_OVERWORLD
	in vec3 worldShadowVector;
	in vec3 shadowVector;

	in vec3 colorShadowlight;
#endif


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"
#include "/Lib/PathTracing/Tracer/TracingUtilities.glsl"
#include "/Lib/PathTracing/Voxelizer/BlockShape.glsl"
#include "/Lib/PathTracing/Tracer/ShadowTracing.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"
#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"
#include "/Lib/BasicFunctions/Blocklight.glsl"
#include "/Lib/BasicFunctions/HeldLight.glsl"
#ifndef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/Sunlight_Shadow.glsl"
#endif

#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSkyTimer.glsl"
#endif


////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef PT_IRC
vec4 SampleIrradianceCache_Raw_OutBlocker(ivec3 ircTexel, float sampleWeight, out float blocker){
	vec4 ircColor = texelFetch(irradianceCache3D, ircTexel, 0);
	blocker = ircColor.a;
	ircColor = vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
	return ircColor - blocker * ircColor;
}

vec4 SampleIrradianceCache_Raw_Blocker(ivec3 ircTexel, float sampleWeight){
	vec4 ircColor = texelFetch(irradianceCache3D, ircTexel, 0);
	sampleWeight *= 1.0 - ircColor.a;
	return vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw(ivec3 ircTexel, float sampleWeight){
	vec3 ircColor = texelFetch(irradianceCache3D, ircTexel, 0).rgb;
	return vec4(ircColor * sampleWeight, float(dot(ircColor, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw_OutBlocker_Alt(ivec3 ircTexel, float sampleWeight, out float blocker){
	vec4 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0);
	blocker = ircColor.a;
	ircColor = vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
	return ircColor - blocker * ircColor;
}

vec4 SampleIrradianceCache_Raw_Blocker_Alt(ivec3 ircTexel, float sampleWeight){
	vec4 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0);
	sampleWeight *= 1.0 - ircColor.a;
	return  vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw_Alt(ivec3 ircTexel, float sampleWeight){
	vec3 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0).rgb;
	return vec4(ircColor * sampleWeight, float(dot(ircColor, vec3(1.0)) > 0.0) * sampleWeight);
}

vec3 SampleIrradianceCache(vec3 hitVoxelPos){
	ivec3 ircTexel = ivec3(hitVoxelPos) + ((ircResolution - voxelResolutionInt) >> 1);
	vec3 ircColor = vec3(0.0);
	if ((frameCounter & 1) == 0){
		ircColor = texelFetch(irradianceCache3D, ircTexel, 0).rgb;
	}else{
		ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0).rgb;
	}
	return ircColor * 0.01;
}

vec3 SampleIrradianceCache_Full_Smooth(vec3 hitVoxelPos, vec3 hitNormal){
	ivec3 hitVoxelCoord = ivec3(hitVoxelPos);
	ivec3 ircTexel = hitVoxelCoord + ((ircResolution - voxelResolutionInt) >> 1);
	vec4 ircColor = vec4(0.0);

	if (clamp(ircTexel, 0, ircResolution - 1) == ircTexel){
		vec3 centerOffset = vec3(hitVoxelCoord) + 0.5 - hitVoxelPos;

		hitNormal = abs(hitNormal);
		hitNormal.xy = step(maxVec3(hitNormal), hitNormal.xz);
		vec3 T = vec3(1.0 - hitNormal.x, hitNormal.x, 0.0);
		vec3 B = vec3(0.0, hitNormal.y, 1.0 - hitNormal.y);

		float blocker = 0.0;

		if ((frameCounter & 1) == 0){
			vec3 sampleOffset = centerOffset;
			float sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw(ircTexel, sampleWeight);

			sampleOffset = centerOffset -T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(-T), sampleWeight, blocker);

			float blocker00 = blocker;
			float blocker01 = blocker;

			sampleOffset = centerOffset -B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(-B), sampleWeight, blocker);

			blocker00 += blocker;
			float blocker10 = blocker;

			if (blocker00 < 1.5){
				sampleOffset = centerOffset -T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(-T -B), sampleWeight);
			}

			sampleOffset = centerOffset +T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(T), sampleWeight, blocker);

			blocker10 += blocker;
			float blocker11 = blocker;

			if (blocker10 < 1.5){
				sampleOffset = centerOffset +T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(T -B), sampleWeight);
			}

			sampleOffset = centerOffset +B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(B), sampleWeight, blocker);

			blocker01 += blocker;
			blocker11 += blocker;

			if (blocker01 < 1.5){
				sampleOffset = centerOffset -T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(-T +B), sampleWeight);
			}

			if (blocker11 < 1.5){
				sampleOffset = centerOffset +T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(T +B), sampleWeight);
			}
		}else{
			vec3 sampleOffset = centerOffset;
			float sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_Alt(ircTexel, sampleWeight);

			sampleOffset = centerOffset -T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(-T), sampleWeight, blocker);

			float blocker00 = blocker;
			float blocker01 = blocker;

			sampleOffset = centerOffset -B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(-B), sampleWeight, blocker);

			blocker00 += blocker;
			float blocker10 = blocker;

			if (blocker00 < 1.5){
				sampleOffset = centerOffset -T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(-T -B), sampleWeight);
			}

			sampleOffset = centerOffset +T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(T), sampleWeight, blocker);

			blocker10 += blocker;
			float blocker11 = blocker;

			if (blocker10 < 1.5){
				sampleOffset = centerOffset +T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(T -B), sampleWeight);
			}

			sampleOffset = centerOffset +B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(B), sampleWeight, blocker);

			blocker01 += blocker;
			blocker11 += blocker;

			if (blocker01 < 1.5){
				sampleOffset = centerOffset -T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(-T +B), sampleWeight);
			}

			if (blocker11 < 1.5){
				sampleOffset = centerOffset +T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(T +B), sampleWeight);
			}
		}

		ircColor.rgb *= 0.01 / max(ircColor.a, 1e-10);
	}

	return ircColor.rgb;
}
#endif


void main(){
	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		bool isDH = depth == 1.0;
		if (isDH) depth = texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

	if (depth < 1.0){

		GbufferData gbuffer 		= GetGbufferDataSoild();
		MaterialMask materialMask 	= CalculateMasks(gbuffer.materialID);

		#ifdef DECREASE_HAND_GHOSTING
			if (materialMask.hand > 0.5)
				depth = depth * (4.0 / MC_HAND_DEPTH) - (2.0 / MC_HAND_DEPTH + 1.0);
		#endif

		vec3 viewPos 				= ViewPos_From_ScreenPos(texCoord, depth);
		#ifdef DISTANT_HORIZONS
			if (isDH) viewPos 		= ViewPos_From_ScreenPos_DH(texCoord, depth);
		#endif


		vec3 worldPos				= mat3(gbufferModelViewInverse) * viewPos;

		vec3 viewDir 				= normalize(viewPos);
		vec3 worldDir 				= normalize(worldPos);
		vec3 viewNormal 			= gbuffer.worldNormal * mat3(gbufferModelViewInverse);

		#ifdef DISTANT_HORIZONS
			float farDist 				= max(dhFarPlane, 1024.0);
		#else
			float farDist 				= max(far * 1.2, 1024.0);
		#endif

		float opaqueDist 			= depth < 1.0 ? length(viewPos) : farDist;
		#ifdef DISTANT_HORIZONS
			float shadowmapRange = saturate(3.2 - opaqueDist / min(shadowDistance, far) * 4.0 - float(isDH) * 1e10);
		#else
			float shadowmapRange = saturate(3.2 - opaqueDist / min(shadowDistance, far) * 4.0);
		#endif

	/*
		#ifdef VOLUMETRIC_CLOUDS
			#ifdef CLOUD_SHADOW
				float cloudShadow = CloudShadowFromTex(worldPos);
			#else
				float cloudShadow = 1.0 - wetness * RAIN_SHADOW;
			#endif
		#else
			float cloudShadow = 1.0 - wetness * RAIN_SHADOW;
		#endif
	*/
		float cloudShadow = 1.0 - wetness * RAIN_SHADOW;

		gbuffer.material.scattering *= saturate(1.0 - materialMask.leaves - materialMask.grass);
		gbuffer.worldNormal = normalize(mix(gbuffer.worldNormal, vec3(0.0, 1.0, 0.0), materialMask.grass * 0.49));


		vec3 color = vec3(0.0);

		#if defined DEBUG_IRC && defined PT_IRC
			vec3 voxelPos = worldPos + gbufferModelViewInverse[3].xyz + cameraPositionFract + (voxelResolution * 0.5);
			voxelPos += gbuffer.vertexNormal * (-viewPos.z * 0.0003);

			//color += SampleIrradianceCache_Full_Smooth(voxelPos, gbuffer.vertexNormal);
			color += SampleIrradianceCache(voxelPos);
		#else
			color += texelFetch(colortex1, texelCoord, 0).rgb * 0.01;
		#endif
	
		vec3 textureLighting = TextureLighting(gbuffer.albedo, gbuffer.material.emissiveness, materialMask);

		if(heldBlockLightValue + heldBlockLightValue2 > 0.0)
			HeldLighting(color, textureLighting, viewPos, viewDir, viewNormal, gbuffer.material.roughness, materialMask.hand > 0.5);


		#ifndef DIMENSION_NETHER

			float sunlight = Fd_Burley(gbuffer.worldNormal, -worldDir, worldShadowVector, gbuffer.material.roughness);

			//float sunlightTrans = saturate(materialMask.leaves * 3.0) * 0.25 + materialMask.particle * 0.4 + materialMask.grass * 0.15;
			float sunlightTrans = materialMask.leaves * 0.25 + materialMask.grass * 0.15;
			sunlight = mix(sunlight, 0.6, sunlightTrans);
			gbuffer.parallaxShadow = saturate(gbuffer.parallaxShadow + sunlightTrans * 1e10);

			#ifdef DIMENSION_OVERWORLD
				vec3 sunlightMult = colorShadowlight * cloudShadow;
				#ifdef CAVE_MODE
					sunlightMult *= mix(1.0, 0.1, eyeBrightnessZeroSmooth);
				#endif
			#else
				const vec3 blackbody = vec3(1.088, 0.979, 0.923);
				vec3 sunlightMult = (blackbody * SUNLIGHT_INTENSITY * 0.7) * (planetShadow * planetShadow);
			#endif

			vec3 shadow = sunlightMult;
			#if PARALLAX_MODE > 0 && !defined ENABLE_SSS
				shadow *= gbuffer.parallaxShadow;
			#endif
			#ifdef DIMENSION_OVERWORLD
			#ifdef SUNLIGHT_LEAK_FIX
				float lightMask = saturate(gbuffer.lightmap.g * 1e5 + float(isEyeInWater == 1));
				shadow *= lightMask;
			#endif
			#endif

			#ifdef ENABLE_SSS
				vec3 sss = vec3(0.0);
			#endif

			if ((sunlight + gbuffer.material.scattering) * shadow.x > 0.0){
				#ifdef ENABLE_SSS
					shadow *= VariablePenumbraShadow(worldPos, gbuffer.vertexNormal, -viewPos.z, sunlight, gbuffer.albedo, gbuffer.lightmap.g, gbuffer.material.scattering, materialMask, sss);
					#ifdef DIMENSION_OVERWORLD
					#ifdef SUNLIGHT_LEAK_FIX
						sss *= lightMask;
					#endif
					#endif
					color += sss * sunlightMult;
				#else
					shadow *= VariablePenumbraShadow(worldPos, gbuffer.vertexNormal, -viewPos.z, sunlight, gbuffer.albedo, gbuffer.lightmap.g, gbuffer.material.scattering, materialMask);
				#endif
			}

			#if PARALLAX_MODE > 0 && defined ENABLE_SSS
				shadow *= gbuffer.parallaxShadow;
			#endif


			bool isMetal = gbuffer.material.metalness > 229.5 / 255.0;

			#ifdef DISABLE_HAND_SPECULAR
				float metalnessMask = 0.0;
			#elif defined DECREASE_HAND_SPECULAR
				float metalnessMask = float(isMetal);
				if (materialMask.hand > 0.5){
					metalnessMask *= saturate(1.0 - gbuffer.material.roughness * 3.0);
					metalnessMask = min(metalnessMask, 0.5);
				}
			#else
				float metalnessMask = float(isMetal);
			#endif
			vec3 sunlightSpecular = vec3(0.0);


			if (any(greaterThan(sunlight * shadow, vec3(0.0)))){
				#ifdef PT_SHADOW
					shadow *= ShadowTracing(viewPos, worldPos + gbufferModelViewInverse[3].xyz, gbuffer.vertexNormal, worldShadowVector, gbuffer.lightmap.g);
				#endif

				vec3 f0 = vec3(gbuffer.material.metalness);

				if (isMetal){
					#if TEXTURE_PBR_FORMAT == 0
						if(gbuffer.material.metalness < 237.5 / 255.0){
							f0 = PredefinedMetalF0(gbuffer.material.metalness);
						}else{
							f0 = gbuffer.albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
						}				
					#else
						f0 = gbuffer.albedo * (1.0 - METAL_MINIMAL_F0) + METAL_MINIMAL_F0;
					#endif
				}


				sunlightSpecular = SpecularGGX(viewNormal, -viewDir, shadowVector, clamp(gbuffer.material.roughness, 0.0015, 0.9), f0);
				sunlightSpecular *= saturate(4.0 - gbuffer.material.roughness * 3.5) * (0.07 - materialMask.grass * 0.035);
				#ifdef DIMENSION_END
					sunlightSpecular *= remapSaturate(gbuffer.material.roughness, 0.01, 0.05);
				#endif


				#ifdef SCREEN_SPACE_SHADOWS
					float leaveMask = materialMask.leaves * shadowmapRange;

					#ifdef HAND_SCREEN_SHADOW
						#ifdef DISABLE_PLAYER_SCREEN_SPACE_SHADOWS
							#if PARALLAX_MODE > 0
								if (leaveMask + materialMask.entitiesSnow + materialMask.entityPlayer < 1.0)
							#else
								if (leaveMask + materialMask.entitiesSnow + materialMask.entityPlayer < 1.0 && gbuffer.parallaxShadow > 0.0)
							#endif
						#else
							#if PARALLAX_MODE > 0
								if (leaveMask + materialMask.entitiesSnow < 1.0)
							#else
								if (leaveMask + materialMask.entitiesSnow < 1.0 && gbuffer.parallaxShadow > 0.0)
							#endif
						#endif
					#else
						#ifdef DISABLE_PLAYER_SCREEN_SPACE_SHADOWS
							#if PARALLAX_MODE > 0
								if (leaveMask + materialMask.hand + materialMask.entitiesSnow + materialMask.entityPlayer < 1.0)
							#else
								if (leaveMask + materialMask.hand + materialMask.entitiesSnow + materialMask.entityPlayer < 1.0 && gbuffer.parallaxShadow > 0.0)
							#endif
						#else
							#if PARALLAX_MODE > 0
								if (leaveMask + materialMask.hand + materialMask.entitiesSnow < 1.0)
							#else
								if (leaveMask + materialMask.hand + materialMask.entitiesSnow < 1.0 && gbuffer.parallaxShadow > 0.0)
							#endif
						#endif
					#endif
						{
							shadow *= mix(ScreenSpaceShadow(viewPos, viewDir, gbuffer.vertexNormal, depth, materialMask, shadowmapRange), 1.0, leaveMask);
						}
				#endif

				color += shadow * (sunlight * (1.0 - metalnessMask * (METALMASK_STRENGTH * 0.1 + 0.9)));

				sunlightSpecular *= shadow;
			}

			if (isMetal) imageStore(colorimg4, texelCoord, vec4(sunlightSpecular + textureLighting * gbuffer.albedo, 0.0));

			color = color * (1.0 - metalnessMask * METALMASK_STRENGTH) + textureLighting;
			color = color * gbuffer.albedo + sunlightSpecular;


		#else
			bool isMetal = gbuffer.material.metalness > 229.5 / 255.0;

			#ifdef DISABLE_HAND_SPECULAR
				float metalnessMask = 0.0;
			#elif defined DECREASE_HAND_SPECULAR
				float metalnessMask = float(isMetal);
				if (materialMask.hand > 0.5){
					metalnessMask *= saturate(1.0 - gbuffer.material.roughness * 3.0);
					metalnessMask = min(metalnessMask, 0.5);
				}
			#else
				float metalnessMask = float(isMetal);
			#endif

			if (isMetal) imageStore(colorimg4, texelCoord, vec4(textureLighting * gbuffer.albedo, 0.0));

			color = (color * (1.0 - metalnessMask * METALMASK_STRENGTH) + textureLighting) * gbuffer.albedo;

		#endif


		color += vec3(1.0) * materialMask.lightning;
	
		framebuffer1 = vec4(max(color, vec3(0.0)), 0.0);


	}	
	#ifndef DIMENSION_NETHER
		else{

			framebuffer1 = texelFetch(colortex2, texelCoord, 0);
			
		}
	#endif
}
