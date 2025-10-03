

#define DIFFUSE_TRACING


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;

#ifdef DIMENSION_OVERWORLD
	in vec3 colorShadowlight;
	in vec3 colorSkylight;
#endif

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D shadowcolor0;

uniform sampler3D voxelData3D;

#ifdef PT_IRC
	uniform sampler3D irradianceCache3D;
	uniform sampler3D irradianceCache3D_Alt;
#endif



uint randSeed = HashWellons32(uint(gl_FragCoord.x + screenSize.x * gl_FragCoord.y) * uint(frameCounter));
#include "/Lib/PathTracing/Tracer/TracingNoise.glsl"

#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/BasicFunctions/Blocklight.glsl"
#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif

#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"
#include "/Lib/PathTracing/Tracer/TracingUtilities.glsl"
#include "/Lib/PathTracing/Tracer/SampleIRC.glsl"
#include "/Lib/PathTracing/Voxelizer/BlockShape.glsl"
#include "/Lib/PathTracing/Tracer/ShadowTracing.glsl"

#ifdef DIMENSION_END
	#include "/Lib/IndividualFunctions/EndSkyTimer.glsl"
#endif


vec3 SkyLighting(vec3 raydir, float pdf, float lightmap){
	//float SdotN = dot(worldNormal, normalize(worldSunVector + vec3(0.0, 1.0, 0.0)));
	//float MdotN = dot(worldNormal, normalize(-worldSunVector + vec3(0.0, 1.0, 0.0)));

	//vec3 skylight = colorSunSkylight * (SdotN * 0.35 + 0.65);
	//skylight += colorMoonSkylight * (MdotN * 0.35 + 0.65);

	//vec3 skySunLight = colorShadowlight * (worldNormal.y * 0.015 + 0.02);

	//skylight += skySunLight;

	//#ifdef VOLUMETRIC_CLOUDS
	//	float coverage = mix(CLOUD_CLEAR_COVERY, CLOUD_RAIN_COVERY, wetness);
	//	//skylight += skySunLight * ((1.0 - wetness) * saturate(coverage * 4.0 - 0.6));
	//#endif

	//skylight = mix(skylight, colorShadowlight * (SdotN * 0.003 + 0.005), wetness * 0.6);

	vec2 skyCoord = CubemapProjection(raydir);
	vec3 skyColor = textureLod(colortex12, skyCoord, 0.0).rgb;
	skyColor *= pdf;
	#ifndef DIMENSION_END
		skyColor *= saturate(raydir.y * 25.0 + 0.5);
		skyColor *= isEyeInWater == 1 ? saturate(lightmap + 0.05) : lightmap;
	#endif
	
	return skyColor;
}


vec3 DiffuseTracing(float depth, vec3 vertexNormal, vec3 worldNormal, vec2 lightmap){
	vec3 viewPosRaw = ViewPos_From_ScreenPos(texCoord, depth);
	#ifdef DISTANT_HORIZONS
		if (depth < 0.0){
			viewPosRaw = ViewPos_From_ScreenPos_DH(texCoord, -depth);
			depth = 1.1;
		}
	#endif
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPosRaw.xyz;
	worldPos += gbufferModelViewInverse[3].xyz;

	vec3 voxelPos = worldPos + cameraPositionFract + (voxelResolution * 0.5);
	voxelPos += vertexNormal * (-viewPosRaw.z * 0.0003);


	#if PT_DIFFUSE_SPP > 1

	vec3 result = vec3(0.0);
	for (int i = 0; i < PT_DIFFUSE_SPP; i++){

	#endif

		vec3 diffuse = vec3(0.0);

		vec3 hitVoxelPos = voxelPos;
		vec3 hitNormal = worldNormal;
		vec3 rayDir = HemisphereUnitVector(hitNormal);
		float pdf = saturate(dot(rayDir, vertexNormal) * 1e10) * saturate(dot(rayDir, hitNormal)) * 2.0;
		
		#ifdef PT_DIFFUSE_SST
			bool sh = false;
			vec4 viewPos = vec4(viewPosRaw, 0.0);
			

			if (depth > 0.7){
				
				vec3 viewRayDir = rayDir * mat3(gbufferModelViewInverse);
				vec3 viewVertexNormal = vertexNormal * mat3(gbufferModelViewInverse);			
				float radius = min(-viewPos.z * 5e-4 + 0.025, -viewPos.z * 0.02 / gbufferProjection[1][1]);
				viewPos.w = radius * 6.0;
				float distThreshold = (0.0075 / PT_DIFFUSE_SST_THICKNESS) / radius;
				float noise = RandWellons().x;
				
				for (int i = 0; i < 6; i++){
					float stepLength = float(i) + noise;
					stepLength = stepLength * stepLength * radius;
					vec3 stepViewPos = viewPos.xyz + viewRayDir * stepLength;

					vec2 sampleCoord = (vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * stepViewPos.xy + gbufferProjection[3].xy) / -stepViewPos.z * 0.5 + 0.5;

					if (saturate(sampleCoord) != sampleCoord) break;

					#if FSR2_SCALE >= 0
						float sampleDepth = textureLod(depthtex1, sampleCoord * fsrRenderScale, 0.0).x;
					#else
						float sampleDepth = textureLod(depthtex1, sampleCoord, 0.0).x;
					#endif
					vec3 sampleViewPos = vec3(sampleCoord, sampleDepth);
					#ifdef DISTANT_HORIZONS
						if (sampleDepth == 1.0){
							#if FSR2_SCALE >= 0
								sampleDepth = textureLod(dhDepthTex0, sampleCoord * fsrRenderScale, 0.0).x;
							#else
								sampleDepth = textureLod(dhDepthTex0, sampleCoord, 0.0).x;
							#endif
							sampleViewPos = ViewPos_From_ScreenPos_Raw_DH(sampleViewPos.xy, sampleDepth);
						}else{
							sampleViewPos = ViewPos_From_ScreenPos_Raw(sampleViewPos.xy, sampleViewPos.z);
						}
					#else
						sampleViewPos = ViewPos_From_ScreenPos_Raw(sampleViewPos.xy, sampleViewPos.z);
					#endif

					vec3 posDiff = sampleViewPos - viewPos.xyz;
					float depthGradient = dot(posDiff, viewVertexNormal);

					sh = depthGradient > -viewPos.z * 0.002 + 0.005;

					float distDiff = (sampleViewPos.z - stepViewPos.z) * distThreshold;
					sh = sh && (dot(normalize(posDiff), viewRayDir) > 0.99 || saturate(distDiff) == distDiff);

					if(sh){
						#if defined PT_DIFFUSE_SST_REPORJECT && FSR2_SCALE < 0
							viewPos.xyz = sampleViewPos;
						#else
							viewPos.xy = sampleCoord;
						#endif
						break;
					}
				}
			}

			if (sh){
				#if defined PT_DIFFUSE_SST_REPORJECT && FSR2_SCALE < 0
					vec3 prevPos = mat3(gbufferPreviousModelView) * (mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz + cameraPositionToPrevious) + gbufferPreviousModelView[3].xyz;
					viewPos.z = prevPos.z;
					viewPos.xy = (vec2(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1]) * prevPos.xy + gbufferPreviousProjection[3].xy) / -prevPos.z * 0.5 + 0.5;

					diffuse = vec3(saturate(viewPos.xy) == viewPos.xy);
					ivec2 sampleTexel = ivec2(viewPos.xy * UNIFORM_SCREEN_SIZE);

					vec3 sampleVertexNormal = DecodeNormal(texelFetch(colortex6, sampleTexel, 0).zw);
					diffuse *= (saturate(dot(-rayDir, sampleVertexNormal) * 1e10) * 0.7 + 0.3) * saturate(dot(rayDir, hitNormal)) * 2.0;

					#if FSR2_SCALE >= 0
						vec3 prevData = texelFetch(colortex3, ivec2(viewPos.xy * screenSize), 0).rgb;

					#else
						vec4 prevData = texelFetch(colortex3, sampleTexel, 0);
						#ifdef DIMENSION_NETHER						
							prevData.w = Unpack2x16(prevData.w).y;
						#endif
						float prevDist = LinearDepth_From_ScreenDepth(1.0 - prevData.w);
						diffuse *= step(abs(prevDist + viewPos.z), viewPos.w);

					#endif

					diffuse *= prevData.rgb;

				#else
					vec3 sampleVertexNormal = DecodeNormal(texelFetch(colortex6, ivec2(viewPos.xy * UNIFORM_SCREEN_SIZE), 0).zw);
					diffuse = vec3((saturate(dot(-rayDir, sampleVertexNormal)) * 0.7 + 0.3) * saturate(dot(rayDir, hitNormal)) * 2.0);

					diffuse *= texelFetch(colortex3, ivec2(viewPos.xy * screenSize), 0).rgb;

				#endif
			}else

		#endif

		#ifdef DISTANT_HORIZONS
			if (clamp(hitVoxelPos, vec3(0.0), vec3(voxelResolution)) != hitVoxelPos && depth < 1.0){		
		#else
			if (clamp(hitVoxelPos, vec3(0.0), vec3(voxelResolution)) != hitVoxelPos){
		#endif

			#if defined DIMENSION_OVERWORLD || defined DIMENSION_END
				diffuse = SkyLighting(rayDir, pdf, lightmap.y);
				diffuse += BlockLighting(lightmap.x);
			#endif
			#ifdef DIMENSION_END
				diffuse += vec3(1.088, 0.979, 0.923) * NOLIGHT_BRIGHTNESS * 10.0;
			#endif
			#ifdef DIMENSION_NETHER
				diffuse = NetherLighting();
			#endif
			
			diffuse += BlockLighting(lightmap.x);		

		}else{
			#ifdef DIMENSION_OVERWORLD
				#ifdef SUNLIGHT_LEAK_FIX
				float hitSkylight = lightmap.y;
				#endif
				vec3 sunLight = colorShadowlight * (1.0 - wetness * RAIN_SHADOW);
				float waterFogLight = dot(vec3(2e-4), colorSkylight) * float(isEyeInWater == 1);
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

			vec3 hitSurface = vec3(pdf);
			vec4 voxelColor = vec4(0.0);
			#ifdef PT_LOWRES_ATLAS
				vec3 atlasCoord = vec3(0.0);
			#else
				vec2 atlasCoord = vec2(0.0);
			#endif
			

			bool traceTranslucent = true;
			
			for (int i = 0; i < PT_DIFFUSE_TRACING_DISTANCE; i++){
				if (rayLength > PT_DIFFUSE_TRACING_DISTANCE || clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord) break; //out of voxel range ?

				vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
				float voxelID = floor(voxelData.z * 65535.0 - 999.9);

				if (abs(voxelID) <= 399.0){

					if (voxelID >= 237.0){
						diffuse += HitLightShpere(ray, voxelCoord, voxelID, rayLength) * hitSurface;		
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

							#ifdef PT_LOWRES_ATLAS
								atlasCoord = GetAtlasCoordWithLod(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
								voxelColor = textureLod(atlas2D, atlasCoord.xy, atlasCoord.z);
							#else
								atlasCoord = GetAtlasCoord(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
								voxelColor = textureLod(atlas2D, atlasCoord.xy, 0);
							#endif

							if (isTranslucent){
								vec3 translucentColor = GammaToLinear(voxelColor.rgb);
								if (voxelID < 0.0) diffuse += translucentColor * (Radiance(translucentColor) * pdf * (BLOCKLIGHT_BRIGHTNESS * 0.5));
								hitSurface *= mix(vec3(0.95), translucentColor * 0.9, pow(voxelColor.a, 0.25));
								traceTranslucent = false;
							}else{
								#ifdef PT_TRACING_ALPHA
									#ifdef PT_DIFFUSE_FULLBLOCK_NO_SELF_INTERSECTION
										if (!bool((uint(voxelID <= 1.0) & uint(rayLength <= 0.0)) | (uint(voxelID <= 0.0) & uint(voxelColor.a < 0.1))))
									#else
										if (voxelID >= 0.0 || bool(uint(voxelColor.a >= 0.1) & uint(rayLength > 0.0)))
									#endif
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
				diffuse += vec3(0.1, 0.6, 1.0) * (saturate(rayLength * 0.05) * waterFogLight * pdf);
				diffuse += (vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS) * (saturate(rayLength * 0.2) * pdf);
			#endif

			#ifdef DIMENSION_END
				diffuse += (blackbody * NOLIGHT_BRIGHTNESS * 10.0) * (saturate(rayLength * 0.2) * pdf);
			#endif

			#ifdef DIMENSION_NETHER
				diffuse += NetherLighting() * (saturate(rayLength * 0.1) * pdf);
			#endif

		}

#if PT_DIFFUSE_SPP > 1
		
		result += diffuse;
	}
	return result / PT_DIFFUSE_SPP;

#else
		
	return diffuse;

#endif
}


void main(){
	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = -texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

	if (abs(depth) == 1.0) discard;

	GbufferData gbuffer = GetGbufferDataSoild();

	vec3 lighting = DiffuseTracing(depth, gbuffer.vertexNormal, gbuffer.worldNormal, gbuffer.lightmap);

	framebuffer1 = vec4(max(lighting * 100.0, vec3(0.0)), 0.0);
}
