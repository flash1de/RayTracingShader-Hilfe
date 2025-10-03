

#define DIFFUSE_TRACING


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"


#if   PT_IRC_RESOLUTION == 128
    const ivec3 workGroups = ivec3(8, 16, 128);
#elif PT_IRC_RESOLUTION == 192
    const ivec3 workGroups = ivec3(12, 24, 192);
#elif PT_IRC_RESOLUTION == 256
    const ivec3 workGroups = ivec3(16, 32, 256);
#endif

layout (local_size_x = 16, local_size_y = 8) in;

layout (rgba16f) uniform image3D img_irradianceCache3D;
layout (rgba16f) uniform image3D img_irradianceCache3D_Alt;


uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

//uniform sampler3D voxelColor3D;
uniform sampler3D voxelData3D;

uniform sampler3D irradianceCache3D;
uniform sampler3D irradianceCache3D_Alt;


uniform ivec3 cameraPositionInt;
uniform ivec3 previousCameraPositionInt;


uint randSeed = HashWellons32((
	gl_GlobalInvocationID.x + 
	gl_GlobalInvocationID.y * uint(ircResolution) +
	gl_GlobalInvocationID.z * uint(ircResolution * ircResolution)) *
	uint(frameCounter)
);

#include "/Lib/PathTracing/Tracer/TracingNoise.glsl"
#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif

#include "/Lib/Uniform/ShadowTransforms.glsl"
#include "/Lib/PathTracing/Tracer/TracingUtilities.glsl"
#include "/Lib/PathTracing/Voxelizer/BlockShape.glsl"
#include "/Lib/PathTracing/Tracer/ShadowTracing.glsl"

#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSkyTimer.glsl"
#endif


vec4 IrradianceCache(ivec3 ircTexel, ivec3 voxelTexel, ivec3 cameraPositionIntToPrevious){
	vec4 ircColor = vec4(0.0);

	vec4 currVoxelData = texelFetch(voxelData3D, voxelTexel, 0);
	float currVoxelID = floor(currVoxelData.z * 65535.0 - 999.9);

	if (abs(currVoxelID) <= 1.0){
		ircColor.a = 1.0;
	}else if (clamp(voxelTexel, ivec3(1), voxelResolutionInt - 2) == voxelTexel){
		ircColor.a = float(
			//abs(currVoxelID - 6.5) < 2.0 ||
			abs(currVoxelID - 36.5) < 12.0 ||
			currVoxelID == 56.0 ||
			currVoxelID == 59.0 ||
			currVoxelID == 65.0
		);

		float hitSkylight = 0.0;
 
		vec4 closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(0, 0, -1), 0);
		float closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		vec2 hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		vec3 sampleOffset = vec3(0.0, 0.0, -1.0) * hasCloseVoxel.x;
		vec2 hasVoxel = hasCloseVoxel;

		closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(0, -1, 0), 0);
		closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		sampleOffset += vec3(0.0, -1.0, 0.0) * hasCloseVoxel.x;
		hasVoxel += hasCloseVoxel;

		closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(-1, 0, 0), 0);
		closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		sampleOffset += vec3(-1.0, 0.0, 0.0) * hasCloseVoxel.x;
		hasVoxel += hasCloseVoxel;

		closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(1, 0, 0), 0);
		closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		sampleOffset += vec3(1.0, 0.0, 0.0) * hasCloseVoxel.x;
		hasVoxel += hasCloseVoxel;

		closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(0, 1, 0), 0);
		closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		sampleOffset += vec3(0.0, 1.0, 0.0) * hasCloseVoxel.x;
		hasVoxel += hasCloseVoxel;

		closeVoxelData = texelFetch(voxelData3D, voxelTexel + ivec3(0, 0, 1), 0);
		closeVoxelID = abs(floor(closeVoxelData.z * 65535.0 - 999.9));
		hasCloseVoxel = vec2(step(closeVoxelID, 2.0), step(closeVoxelID, 240.0));
		hitSkylight = max(hitSkylight, Unpack2x8_Y(closeVoxelData.w) * hasCloseVoxel.y);
		sampleOffset += vec3(0.0, 0.0, 1.0) * hasCloseVoxel.x;
		hasVoxel += hasCloseVoxel;

		float hasCurrVoxel = step(abs(currVoxelID), 240.0);
		if(abs(currVoxelID) <= 399.0){	
			hitSkylight = Unpack2x8_Y(currVoxelData.w);
			hasVoxel.y += hasCurrVoxel;
		}

		if (hasVoxel.y > 0.0){
			bool sampleHemisphere = hasVoxel.x == 1.0 && hasCurrVoxel == 0.0;
			//sampleHemisphere = false;
			sampleOffset *= float(sampleHemisphere);
			#ifdef DIMENSION_OVERWORLD
				vec3 sunLight = texelFetch(colortex2, ivec2(0), 0).rgb * (1.0 - wetness * RAIN_SHADOW);
				float waterFogLight = dot(vec3(2e-4), texelFetch(colortex2, ivec2(1, 0), 0).rgb) * float(isEyeInWater == 1);
			#endif
			#ifdef DIMENSION_END
				const vec3 blackbody = vec3(1.088, 0.979, 0.923);
				vec3 sunLight = (blackbody * SUNLIGHT_INTENSITY * 0.7) * (planetShadow * planetShadow);
			#endif

			vec3 hitVoxelPos = vec3(voxelTexel) + 0.5;
			hitVoxelPos += sampleOffset * 0.49999;
		
			vec2 atlasPixelSize = 1.0 / vec2(textureSize(atlas2D, 0));

			float vaildSampleCounts = 1e-10;

			for (int i = 0; i < PT_IRC_SPP; i++){
				vec3 hitNormal = -sampleOffset;
				float pdf = 1.0;

				Ray ray;

				if (sampleHemisphere){
					ray = PackRay(hitVoxelPos, HemisphereUnitVector(hitNormal));
					pdf = saturate(dot(ray.dir, hitNormal)) * 2.0;
				}else{
					ray = PackRay(hitVoxelPos, RandUnitVector());
					pdf = 1.6;
				}

				bool exitTracing = true;

				vec3 voxelCoord = floor(ray.ori);
				vec3 totalStep = (ray.sdir * (voxelCoord - ray.ori + 0.5) + 0.5) * abs(ray.rdir);
				float rayLength = 0.0;
				vec3 tracingNext = step(totalStep, vec3(minVec3(totalStep)));


				vec3 hitResult = vec3(0.0);
				vec3 hitSurface = vec3(pdf);
				vec4 voxelColor = vec4(0.0);
				#ifdef PT_LOWRES_ATLAS
					vec3 atlasCoord = vec3(0.0);
				#else
					vec2 atlasCoord = vec2(0.0);
				#endif

				bool hit = false;
				bool traceTranslucent = true;

				if (abs(currVoxelID) <= 399.0){

					if (currVoxelID >= 237.0){
						hitResult += HitLightShpere(ray, voxelCoord, currVoxelID, rayLength) * hitSurface;						
					} //hit light sphere ?

					if (abs(currVoxelID) <= 240.0){
						vec2 coordOffset;
						bool eliminated = false;

						bool isTranslucent = bool(
							uint(abs(currVoxelID) == 3.0) |
							uint(abs(abs(currVoxelID) - 16.5) < 8.0)
						);

						if ((traceTranslucent || !isTranslucent) && IsHitBlock_FromOrigin_WithInternalIntersection(ray, totalStep, tracingNext, voxelCoord, abs(currVoxelID), rayLength, hitNormal, coordOffset, eliminated)){
							if (eliminated) continue;

							hitVoxelPos = ray.ori + ray.dir * rayLength + hitNormal * (rayLength * 1e-6 + 1e-5);

							vec2 voxelDataW = Unpack2x8(currVoxelData.w);

							#ifdef PT_LOWRES_ATLAS
								atlasCoord = GetAtlasCoordWithLod(voxelCoord, currVoxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
								voxelColor = textureLod(atlas2D, atlasCoord.xy, atlasCoord.z);
							#else
								atlasCoord = GetAtlasCoord(voxelCoord, currVoxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
								voxelColor = textureLod(atlas2D, atlasCoord.xy, 0);
							#endif

							if (isTranslucent){
								vec3 translucentColor = GammaToLinear(voxelColor.rgb);
								if (currVoxelID < 0.0) hitResult += translucentColor * (Radiance(translucentColor) * pdf * (BLOCKLIGHT_BRIGHTNESS * 0.5));
								hitSurface *= mix(vec3(0.95), translucentColor * 0.9, pow(voxelColor.a, 0.25));
								traceTranslucent = false;
							}else{
								#ifdef PT_TRACING_ALPHA
									if (currVoxelID >= 0.0 || bool(uint(voxelColor.a >= 0.1) & uint(rayLength > 0.0)))
								#endif
									{
										hit = true;
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
					}

				}

				if (!hit){
					#ifdef PT_SPARE_TRACING
						if (abs(currVoxelData.z - 0.76) < 0.16){
							float spareSize = floor(currVoxelData.z * 20.0 - 10.0);

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

					for (int i = 0; i < PT_DIFFUSE_TRACING_DISTANCE; i++){
						if (rayLength > PT_DIFFUSE_TRACING_DISTANCE || clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord){
							exitTracing = true;
							break;
						} //out of voxel range ?

						vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
						float voxelID = floor(voxelData.z * 65535.0 - 999.9);

						if (abs(voxelID) <= 399.0){

							if (voxelID >= 237.0){
								hitResult += HitLightShpere(ray, voxelCoord, voxelID, rayLength) * hitSurface;
									
							} //hit light sphere ?			

							if (abs(voxelID) <= 240.0){
								vec2 coordOffset;

								bool isTranslucent = bool(
									uint(abs(voxelID) == 3.0) |
									uint(abs(abs(voxelID) - 16.5) < 8.0)
								);

								if ((traceTranslucent || !isTranslucent) && IsHitBlock(ray, totalStep, tracingNext, voxelCoord, abs(voxelID), rayLength, hitNormal, coordOffset)){

									hitVoxelPos = ray.ori + ray.dir * rayLength + hitNormal * (rayLength * 1e-6 + 1e-5);

									vec2 voxelDataW = Unpack2x8(voxelData.w);

									#ifdef PT_LOWRES_ATLAS
										atlasCoord = GetAtlasCoordWithLod(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
										voxelColor = textureLod(atlas2D, atlasCoord.xy, atlasCoord.z);
									#else
										atlasCoord = GetAtlasCoord(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
										voxelColor = textureLod(atlas2D, atlasCoord.xy, 0);
									#endif
									
									if (isTranslucent){
										vec3 translucentColor = GammaToLinear(voxelColor.rgb);
										if (voxelID < 0.0) hitResult += translucentColor * (Radiance(translucentColor) * pdf * (BLOCKLIGHT_BRIGHTNESS * 0.5));
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
							}

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
				}

				vaildSampleCounts += 1.0;

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
						hitResult += skyColor * hitSurface;
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
						#ifdef PT_LOWRES_ATLAS
							#if TEXTURE_PBR_FORMAT < 2
								float emissiveness = textureLod(atlasSpecular2D, atlasCoord.xy, atlasCoord.z).a;
								emissiveness -= step(1.0, emissiveness);
							#else
								float emissiveness = textureLod(atlasSpecular2D, atlasCoord.xy, atlasCoord.z).b * 0.996;
							#endif
						#else
							#if TEXTURE_PBR_FORMAT < 2
								float emissiveness = textureLod(atlasSpecular2D, atlasCoord.xy, 0.0).a;
								emissiveness -= step(1.0, emissiveness);
							#else
								float emissiveness = textureLod(atlasSpecular2D, atlasCoord.xy, 0.0).b * 0.996;
							#endif
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


					hitResult += (BLOCKLIGHT_BRIGHTNESS * voxelColor.a * Radiance(voxelColor.rgb)) * hitSurface;

					ivec3 prevIrcTexel = ivec3(hitVoxelPos) + ((ircResolution - voxelResolutionInt) >> 1) + cameraPositionIntToPrevious;
					vec3 prevIrcColor = vec3(0.0);
					if ((frameCounter & 1) == 0){
						prevIrcColor = texelFetch(irradianceCache3D_Alt, prevIrcTexel, 0).rgb;
					}else{
						prevIrcColor = texelFetch(irradianceCache3D, prevIrcTexel, 0).rgb;
					}
					float weight = (0.01 - PT_IRC_SELFBOUNCE_ATTENUATION * 0.01) + float(hit) * (PT_IRC_SELFBOUNCE_ATTENUATION * 0.01);
					if (!sampleHemisphere) weight *= 0.625;
					hitResult += prevIrcColor * weight * hitSurface;


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
							hitResult += sunLight * SimpleShadow(hitWorldPos, hitNormal) * sunLighting * hitSurface;
						}
					#endif

					//vec3 specTex = textureLod(atlasSpecular2D, atlasCoord, 0.0).rgb;
					//bool isMetal = specTex.g > 229.5 / 255.0;
					//float metalness = specTex.g * float(isMetal);
					//hitResult *= 1.0 - metalness * 0.985;

					//hitResult += vec3(0.1, 0.6, 1.0) * (saturate(rayLength * 0.05) * waterFogLight) * hitSurface;

					//hitResult += (vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS) * saturate(rayLength * 0.2) * hitSurface;
				}

				#if defined DIMENSION_OVERWORLD
					hitResult += vec3(0.1, 0.6, 1.0) * (saturate(rayLength * 0.05) * waterFogLight * pdf);
					hitResult += (vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS) * (saturate(rayLength * 0.2) * pdf);
				#endif

				#ifdef DIMENSION_END
					hitResult += (blackbody * NOLIGHT_BRIGHTNESS * 15.0) * (saturate(rayLength * 0.2) * pdf);
				#endif

				#ifdef DIMENSION_NETHER
					hitResult += NetherLighting() * (saturate(rayLength * 0.33) * pdf);
				#endif


				ircColor.rgb += hitResult;
			}
			ircColor.rgb /= vaildSampleCounts;	

			vec3 prevIrcColor = vec3(0.0);
			if ((frameCounter & 1) == 0){
				prevIrcColor = texelFetch(irradianceCache3D_Alt, ircTexel + cameraPositionIntToPrevious, 0).rgb;
			}else{
				prevIrcColor = texelFetch(irradianceCache3D, ircTexel + cameraPositionIntToPrevious, 0).rgb;
			}

			#ifdef PT_IRC_INITIAL_SKYLIGHT
				if (dot(prevIrcColor, vec3(1.0)) <= 0.0 && clamp(ircTexel, 15, ircResolution - 16) != ircTexel){
					#if defined DIMENSION_OVERWORLD || defined DIMENSION_END
						prevIrcColor = SimpleSkyLighting(texelFetch(colortex2, ivec2(1, 0), 0).rgb, texelFetch(colortex2, ivec2(0), 0).rgb, 0.0, saturate(hitSkylight * 2.0 - 1.0));
					#endif
					#ifdef DIMENSION_NETHER
						prevIrcColor = NetherLighting();
					#endif
				}else{
					prevIrcColor *= 0.01;
				}
			#else
				prevIrcColor *= 0.01;
			#endif

			float blendweight = 1.0 - (1.0 - PT_IRC_BLENDWEIGHT) * saturate(frameTime / 0.01666667);
			blendweight = mix(step(vaildSampleCounts, 0.5) * 0.6, 1.0, blendweight);

			float worldTimeVaildation = step(abs(float(worldTime + isEyeInWater * 150) - texelFetch(pixelData2D, ivec2(PIXELDATA_WORLDTIME, 0), 0).x), 100.0);

			ircColor.rgb = mix(ircColor.rgb * worldTimeVaildation, prevIrcColor, blendweight * worldTimeVaildation) * 100.0 + 1e-7;
			ircColor.rgb = max(ircColor.rgb, 0.0);
		}
	}

	return ircColor;
}


void main(){
	ivec3 ircTexel = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 voxelTexel = ircTexel + ((voxelResolutionInt - ircResolution) >> 1);
	ivec3 cameraPositionIntToPrevious = cameraPositionInt - previousCameraPositionInt;

	if (clamp(voxelTexel, ivec3(0), voxelResolutionInt - 1) == voxelTexel){
		if ((frameCounter & 1) == 0){
			imageStore(img_irradianceCache3D, ircTexel, IrradianceCache(ircTexel, voxelTexel, cameraPositionIntToPrevious));
		}else{	
			imageStore(img_irradianceCache3D_Alt, ircTexel, IrradianceCache(ircTexel, voxelTexel, cameraPositionIntToPrevious));
		}
	}
}
