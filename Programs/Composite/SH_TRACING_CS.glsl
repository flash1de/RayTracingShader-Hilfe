

#define DIFFUSE_TRACING


#extension GL_KHR_shader_subgroup_arithmetic : enable


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"


const ivec3 workGroups = ivec3(1, 1, 1);
layout (local_size_x = 512) in;


layout (rg16f) uniform image2D img_pixelData2D;

#if defined MC_GL_VENDOR_NVIDIA || defined MC_GL_VENDOR_AMD
	shared vec4 prefixSumCache0[16];
	shared vec4 prefixSumCache1[16];
	shared vec4 prefixSumCache2[16];
#else
	shared vec4 prefixSumCache0[32];
	shared vec4 prefixSumCache1[32];
	shared vec4 prefixSumCache2[32];
#endif


uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

//uniform sampler3D voxelColor3D;
uniform sampler3D voxelData3D;

#ifdef PT_IRC
	uniform sampler3D irradianceCache3D;
	uniform sampler3D irradianceCache3D_Alt;
#endif


#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif

#include "/Lib/Uniform/ShadowTransforms.glsl"
#include "/Lib/PathTracing/Tracer/TracingUtilities.glsl"
#include "/Lib/PathTracing/Tracer/SampleIRC.glsl"
#include "/Lib/PathTracing/Voxelizer/BlockShape.glsl"
#include "/Lib/PathTracing/Tracer/ShadowTracing.glsl"

#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSkyTimer.glsl"
#endif


vec3 EyeTracing(vec3 rayDir){
	vec3 hitVoxelPos = cameraPositionFract + (voxelResolution * 0.5);

	vec3 diffuse = vec3(0.0);

	#ifdef DIMENSION_OVERWORLD
		#ifdef SUNLIGHT_LEAK_FIX
			float hitSkylight = saturate(float(eyeBrightnessSmooth.y - 8) / 232.0);
		#endif
		vec3 sunLight = texelFetch(colortex2, ivec2(0), 0).rgb * (1.0 - wetness * RAIN_SHADOW);
		float waterFogLight = dot(vec3(2e-4), texelFetch(colortex2, ivec2(1, 0), 0).rgb) * float(isEyeInWater == 1);
	#endif
	#ifdef DIMENSION_END
		const vec3 blackbody = vec3(1.088, 0.979, 0.923);
		vec3 sunLight = (blackbody * SUNLIGHT_INTENSITY * 0.7) * (planetShadow * planetShadow);
	#endif

	vec2 atlasPixelSize = 1.0 / vec2(textureSize(atlas2D, 0));

	Ray ray = PackRay(hitVoxelPos, rayDir);

	bool exitTracing = true;

	vec3 voxelCoord = floor(ray.ori);
	vec3 totalStep = (ray.sdir * (voxelCoord - ray.ori + 0.5) + 0.5) * abs(ray.rdir);
	float rayLength = 0.0;
	vec3 tracingNext = step(totalStep, vec3(minVec3(totalStep)));

	vec3 hitNormal = vec3(0.0);
	vec3 hitSurface = vec3(1.0);
	vec4 voxelColor = vec4(0.0);
	vec2 atlasCoord = vec2(0.0);

	bool traceTranslucent = true;


	for (int i = 0; i < PT_DIFFUSE_TRACING_DISTANCE; i++){
		if (rayLength > PT_DIFFUSE_TRACING_DISTANCE || clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord) break; //out of voxel range ?

		vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
		float voxelID = floor(voxelData.z * 65535.0 - 999.9);

		if (abs(voxelID) <= 399.0){

			if (voxelID >= 237.0){
				diffuse += HitLightShpere(ray, voxelCoord, voxelID, rayLength);		
			} //light sphere

			if (abs(voxelID) <= 240.0){
				vec2 coordOffset;

				bool isTranslucent = bool(
					uint(abs(voxelID) == 3.0) |
					uint(abs(abs(voxelID) - 16.5) < 8.0)
				);

				if ((traceTranslucent || !isTranslucent) && IsHitBlock(ray, totalStep, tracingNext, voxelCoord, abs(voxelID), rayLength, hitNormal, coordOffset)){

					hitVoxelPos = ray.ori + ray.dir * rayLength + hitNormal * (rayLength * 1e-6 + 1e-5);

					vec2 voxelDataW = Unpack2x8(voxelData.w);

					atlasCoord = GetAtlasCoord(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
					voxelColor = textureLod(atlas2D, atlasCoord, 0.0);

					if (isTranslucent){
						vec3 translucentColor = GammaToLinear(voxelColor.rgb);
						if (voxelID < 0.0) diffuse += translucentColor * (Radiance(translucentColor) * (BLOCKLIGHT_BRIGHTNESS * 0.5));
						hitSurface *= mix(vec3(0.95), translucentColor * 0.9, pow(voxelColor.a, 0.25));
						traceTranslucent = false;
					}else{
						#ifdef PT_TRACING_ALPHA
							if (voxelID >= 0.0 || bool(uint(voxelColor.a >= 0.1) & uint(rayLength > 0.0)))
						#endif
							{
								exitTracing = false;
								#ifdef DIMENSION_OVERWORLD
								#ifdef SUNLIGHT_LEAK_FIX
									hitSkylight = voxelDataW.y;
								#endif
								#endif
								break;
							}
					}
				} //hit shape ?
			} //cube block

		}

		#ifdef PT_SPARE_TRACING
			if (abs(voxelData.z - 0.76) < 0.16){
				float spareSize = floor(voxelData.z * 20.0 - 10.0);

				vec3 spareOrigin = floor(voxelCoord / spareSize) * spareSize;

				vec3 boxMin = spareOrigin - ray.ori;
				vec3 boxMax = boxMin + spareSize;

				vec3 t1 = ray.rdir * boxMin;
				vec3 t2 = ray.rdir * boxMax;

				vec3 tMax = max(t1, t2);
				rayLength = minVec3(tMax);

				tracingNext = step(tMax, vec3(rayLength));

				vec3 exitVoxelCoord = floor(ray.ori + rayLength * ray.dir + tracingNext * ray.sdir * 0.5);

				totalStep += (exitVoxelCoord - voxelCoord) * ray.sdir * abs(ray.rdir);
				voxelCoord = exitVoxelCoord;
			}else{
				rayLength = minVec3(totalStep);
				tracingNext = step(totalStep, vec3(rayLength));
				voxelCoord += tracingNext * ray.sdir;
				totalStep += tracingNext * abs(ray.rdir);
			}
		#else
			rayLength = minVec3(totalStep);
			tracingNext = step(totalStep, vec3(rayLength));
			voxelCoord += tracingNext * ray.sdir;
			totalStep += tracingNext * abs(ray.rdir);
		#endif
	} //stepping loop


	#if defined DIMENSION_OVERWORLD || defined DIMENSION_END
		if (exitTracing){
			rayLength = PT_DIFFUSE_TRACING_DISTANCE;
			vec2 skyCoord = CubemapProjection(ray.dir);
			vec3 skyColor = textureLod(colortex12, skyCoord, 0.0).rgb;			
			#ifdef DIMENSION_OVERWORLD
				skyColor *= saturate(ray.dir.y * 25.0 + 0.5);
				#ifdef SUNLIGHT_LEAK_FIX
					skyColor *= isEyeInWater == 1 ? saturate(hitSkylight + 0.05) : saturate(hitSkylight * 4.44);
				#endif
			#endif
			diffuse += skyColor * hitSurface;
		}else{
	#endif
	#ifdef DIMENSION_NETHER
		if (!exitTracing){
	#endif
		ivec2 voxelTexel = ivec2(VoxelTexel_From_VoxelCoord(voxelCoord));
		voxelColor = texelFetch(shadowcolor0, voxelTexel, 0) * vec4(voxelColor.rgb, 1.0);

		#if TEXTURE_EMISSIVENESS_MODE == 0
			if (voxelColor.a == 1.0) voxelColor.rgb = vec3(0.95);

		#else
			#if TEXTURE_PBR_FORMAT < 2
				float emissiveness = textureLod(atlasSpecular2D, atlasCoord, 0.0).a;
				emissiveness -= step(1.0, emissiveness);
			#else
				float emissiveness = textureLod(atlasSpecular2D, atlasCoord, 0.0).b * 0.996;
			#endif

			#if TEXTURE_EMISSIVENESS_MODE == 1
				if (voxelColor.a == 1.0){
					voxelColor.rgb = vec3(0.95);
				}else{
					voxelColor.a = emissiveness;
				}
			#else
				voxelColor.a = max(voxelColor.a, emissiveness);

				if (voxelColor.a == 1.0) voxelColor.rgb = vec3(0.95);
			#endif					
		#endif

		#if WHITE_DEBUG_WORLD > 0
			voxelColor.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
		#endif
		voxelColor.rgb = GammaToLinear(voxelColor.rgb);


		hitSurface *= voxelColor.rgb;


		diffuse += (BLOCKLIGHT_BRIGHTNESS * voxelColor.a * Radiance(voxelColor.rgb)) * hitSurface;

		#ifdef PT_IRC
			diffuse += SampleIrradianceCache(hitVoxelPos) * hitSurface;				
		#endif

		#ifndef DIMENSION_NETHER
			#ifdef DIMENSION_END
				float sunLighting = saturate(dot(shadowModelViewInverseEnd[2], hitNormal)) * rPI;
			#else
				float sunLighting = saturate(dot(shadowModelViewInverse2, hitNormal)) * rPI;
			#endif
			#ifdef DIMENSION_OVERWORLD
			#ifdef SUNLIGHT_LEAK_FIX
				sunLighting *= saturate(hitSkylight * 444.0 + float(isEyeInWater == 1));
			#endif
			#endif
			/*
			#ifdef PT_SHADOW
				#ifdef SUNLIGHT_LEAK_FIX
					if (isEyeInWater == 1)
				#endif
					{
						if (sunLighting > 0.0) sunLighting *= SimpleShadowTracing(hitVoxelPos, worldShadowVector);
					}
			#endif
			*/		
			if (sunLighting > 0.0){
				vec3 hitWorldPos = hitVoxelPos - cameraPositionFract - (voxelResolution * 0.5);
				vec3 sunColor = sunLight * SimpleShadow(hitWorldPos, hitNormal) * sunLighting;
				diffuse += sunColor * hitSurface;
			}
		#endif
	}

	#if defined DIMENSION_OVERWORLD
		diffuse += vec3(0.1, 0.6, 1.0) * (saturate(rayLength * 0.05) * waterFogLight);
		diffuse += (vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS) * saturate(rayLength * 0.2);
	#endif

	#ifdef DIMENSION_END
		diffuse += (blackbody * NOLIGHT_BRIGHTNESS * 10.0) * saturate(rayLength * 0.2);
	#endif

	#ifdef DIMENSION_NETHER
		diffuse += NetherLighting() * saturate(rayLength * 0.1);
	#endif


	return diffuse;
}


void main(){
	#ifndef DECREASE_HAND_GHOSTING
		return;
	#else

		vec2 noise = Sequences_R2(float(gl_LocalInvocationIndex) * (1.0 + float(frameCounter & 7)) + 1.0);
		vec2 randAngle = vec2(TAU * noise.x, acos(2.0 * noise.y - 1.0));
		vec3 rayDir = vec3(sin(randAngle.x) * sin(randAngle.y), cos(randAngle.x) * sin(randAngle.y), cos(randAngle.y));

		vec3 radiance = EyeTracing(rayDir);

		vec4 shR = EncodeSH2(radiance.r, rayDir);
		vec4 shG = EncodeSH2(radiance.g, rayDir);
		vec4 shB = EncodeSH2(radiance.b, rayDir);

		shR = subgroupInclusiveAdd(shR);
		shG = subgroupInclusiveAdd(shG);
		shB = subgroupInclusiveAdd(shB);

		if (gl_SubgroupInvocationID == gl_SubgroupSize - 1u) 
			prefixSumCache0[gl_SubgroupID] = shR;
			prefixSumCache1[gl_SubgroupID] = shG;
			prefixSumCache2[gl_SubgroupID] = shB;

		barrier();

		uint loopLength = uint(findMSB(gl_NumSubgroups));
		loopLength += uint(gl_NumSubgroups - (1u << (loopLength - 1u)) > 0u);

		for (uint i = 0; i < loopLength; i++){
			if ((gl_SubgroupID & (1u << i)) > 0u){
				uint id = (gl_SubgroupID >> i << i) - 1u;
				shR += prefixSumCache0[id];
				shG += prefixSumCache1[id];
				shB += prefixSumCache2[id];
			
				if (gl_SubgroupInvocationID == gl_SubgroupSize - 1u) 
					prefixSumCache0[gl_SubgroupID] = shR;
					prefixSumCache1[gl_SubgroupID] = shG;
					prefixSumCache2[gl_SubgroupID] = shB;
			}

			barrier();
		}

		if (gl_LocalInvocationIndex == 511u){
			const float weight = 4.0 * PI / 512.0;

			float alpha = 0.01 + fsqrt(length(cameraPositionToPrevious)) * 0.1;

			shR = mix(vec4(texelFetch(pixelData2D, ivec2(PIXELDATA_SHR_XY, 0), 0).xy, texelFetch(pixelData2D, ivec2(PIXELDATA_SHR_ZW, 0), 0).xy), shR * weight, alpha);
			shG = mix(vec4(texelFetch(pixelData2D, ivec2(PIXELDATA_SHG_XY, 0), 0).xy, texelFetch(pixelData2D, ivec2(PIXELDATA_SHG_ZW, 0), 0).xy), shG * weight, alpha);
			shB = mix(vec4(texelFetch(pixelData2D, ivec2(PIXELDATA_SHB_XY, 0), 0).xy, texelFetch(pixelData2D, ivec2(PIXELDATA_SHB_ZW, 0), 0).xy), shB * weight, alpha);

			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHR_XY, 0), vec4(shR.xy, 0.0, 0.0));
			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHR_ZW, 0), vec4(shR.zw, 0.0, 0.0));
			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHG_XY, 0), vec4(shG.xy, 0.0, 0.0));
			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHG_ZW, 0), vec4(shG.zw, 0.0, 0.0));
			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHB_XY, 0), vec4(shB.xy, 0.0, 0.0));
			imageStore(img_pixelData2D, ivec2(PIXELDATA_SHB_ZW, 0), vec4(shB.zw, 0.0, 0.0));
		}
	#endif
}
