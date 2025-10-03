

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"



/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;

layout(rgba16f) uniform writeonly image2D colorimg4;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;
uint randSeed = HashWellons32(uint(gl_FragCoord.x + screenSize.x * gl_FragCoord.y) * uint(frameCounter));

#ifdef DIMENSION_OVERWORLD
	in vec3 worldShadowVector;
	in vec3 worldSunVector;

	in vec3 colorShadowlight;
	in vec3 colorSunlight;
	in vec3 colorMoonlight;

	in vec3 colorSkylight;
	//in vec3 colorSunSkylight;
	//in vec3 colorMoonSkylight;

	in float shadowHighlightStrength;
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


float RenderMoonDiscReflection(vec3 worldDir, vec3 moonDir){
	float d = dot(worldDir, moonDir);

	float size = 0.0025;
	float hardness = 300.0;

	float disc = curve(saturate((d - (1.0 - size)) * hardness));
	return disc * disc;
}

#ifdef DIMENSION_OVERWORLD
	vec3 ComputeFakeSkyReflection(vec3 reflectWorldDir){
		#ifndef DIMENSION_NETHER
			vec2 skyImageCoord = CubemapProjection(reflectWorldDir);
			vec4 skyImage = textureLod(colortex12, skyImageCoord, 0.0);

			#ifdef MOON_TEXTURE
				if (isEyeInWater == 0){
					float moonDisc = RenderMoonDiscReflection(reflectWorldDir, -worldSunVector);
					moonDisc *= mix(1.0, skyImage.a, RAIN_SHADOW);
					moonDisc *= 15.0 * SKY_TEXTURE_BRIGHTNESS;
					skyImage.rgb += colorMoonlight * moonDisc;
				} 
			#endif

			return skyImage.rgb;

		#else
			return vec3(0.0);
			
		#endif
	}
#endif

vec4 SpecularTracing(vec3 hitVoxelPos, vec3 worldPos, vec3 worldDir, vec3 worldNormal, vec3 vertexNormal, Material material, float lightmap, float maskHand, bool isSmooth, float highlightStrength){
	bool totalInternalReflection = texelFetch(colortex1, texelCoord, 0).a > 0.5;
	//worldNormal = vertexNormal;
	//skylight = smoothstep(0.3, 0.8, lightmap.y);

	vec2 noise = BlueNoiseTemporal();

	#if defined DECREASE_HAND_GHOSTING && !defined DISABLE_HAND_SPECULAR
		if (maskHand > 0.5) noise = BlueNoise();
	#endif

	vec3 reflection = vec3(0.0);
	#if PT_SSR_MODE < 2
		vec3 reflectionTint = vec3(1.0);
	#else
		vec4 reflectionTint = vec4(1.0, 1.0, 1.0, 0.0);
	#endif
	vec3 rayDir = worldDir;


	if (isSmooth){
		rayDir = reflect(worldDir, worldNormal);
	}else{
		vec3 normalUp = normalize(vec3(0.0, worldNormal.z, -worldNormal.y));
		mat3 toTangent = mat3(cross(normalUp, worldNormal), normalUp, worldNormal);
		vec3 tangentView = worldDir * toTangent;

		#if defined DECREASE_HAND_SPECULAR && !defined DISABLE_HAND_SPECULAR
			vec3 vndf = sampleGGXVNDF(-tangentView, material.roughness + 1e-10, noise, 0.75 - maskHand * 0.65);
		#else
			vec3 vndf = sampleGGXVNDF(-tangentView, material.roughness + 1e-10, noise, 0.75);
		#endif

		rayDir = reflect(worldDir, toTangent * vndf);
	}

	float NdotV = saturate(dot(-worldDir, worldNormal));
	vec2 atlasPixelSize = 1.0 / vec2(textureSize(atlas2D, 0));

	#ifdef DIMENSION_OVERWORLD
		#ifdef SUNLIGHT_LEAK_FIX
			float skylight = saturate(lightmap * 4.44);
		#else
			float skylight = 1.0;
		#endif
	#else
		float skylight = 1.0;
	#endif

	#ifdef DIMENSION_OVERWORLD
		vec3 sunLight = colorShadowlight * (1.0 - wetness * RAIN_SHADOW);
	#endif
	#ifdef DIMENSION_END
		const vec3 blackbody = vec3(1.088, 0.979, 0.923);
		vec3 sunLight = (blackbody * SUNLIGHT_INTENSITY * 0.7) * (planetShadow * planetShadow);
	#endif

	bool exitTracing = true;

	vec4 hitWorldPos = vec4(0.0);
	float rayLength = 0.0;

	if (clamp(hitVoxelPos, vec3(0.0), vec3(voxelResolution)) == hitVoxelPos){
		vec3 hitNormal = worldNormal;
		float hitSkylight = skylight;

		Ray ray = PackRay(hitVoxelPos, rayDir);

		vec3 voxelCoord = floor(ray.ori);
		vec3 totalStep = (ray.sdir * (voxelCoord - ray.ori + 0.5) + 0.5) * abs(ray.rdir);
		vec3 tracingNext = step(totalStep, vec3(minVec3(totalStep)));

		vec4 voxelColor = vec4(0.0);
		#ifdef PT_LOWRES_ATLAS
			vec3 atlasCoord = vec3(0.0);
		#else
			vec2 atlasCoord = vec2(0.0);
		#endif
		bool traceTranslucent = true;
		
		for (int i = 0; i < PT_SPECULAR_TRACING_DISTANCE; i++){
			if (rayLength > PT_SPECULAR_TRACING_DISTANCE || clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord) break; //out of voxel range ?

			#if PT_SSR_MODE == 1
				hitWorldPos.x = rayLength;
			#endif

			vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
			float voxelID = floor(voxelData.z * 65535.0 - 999.9);

			if (abs(voxelID) <= 255.0){
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
							#ifdef PT_LOWRES_ATLAS_SMOOTH_SPECULAR
								atlasCoord.z = floor(atlasCoord.z * saturate(material.roughness * 50.0));
							#endif
							voxelColor = textureLod(atlas2D, atlasCoord.xy, atlasCoord.z);
						#else
							atlasCoord = GetAtlasCoord(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
							voxelColor = textureLod(atlas2D, atlasCoord.xy, 0);
						#endif

						if (isTranslucent){
							vec3 translucentColor = GammaToLinear(voxelColor.rgb);
							if (voxelID < 0.0) reflection += translucentColor * (Radiance(translucentColor) * BLOCKLIGHT_BRIGHTNESS * 0.5);
							reflectionTint.rgb *= mix(vec3(0.95), translucentColor * 0.9, pow(voxelColor.a, 0.25));

							#if PT_SSR_MODE >= 2
								reflectionTint.a = rayLength;
							#endif
							traceTranslucent = false;
						}else{
							#ifdef PT_TRACING_ALPHA				
								if (voxelID >= 0.0 || (voxelColor.a >= 0.1 && rayLength > 0.0))
							#endif
								{
									exitTracing = false;
									#ifdef DIMENSION_OVERWORLD
									hitSkylight = voxelDataW.y;
									#endif
									break;
								}
						}

					} //hit shape ?

				}else{

					reflection += HitLightShpereReflection(ray, voxelCoord, voxelID, rayLength) * reflectionTint.rgb;
						
				} //hit light sphere ?
			} //hit block ?

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

		if (!exitTracing){
			hitWorldPos.xyz = hitVoxelPos - cameraPositionFract - (voxelResolution * 0.5);

			#ifdef PT_SPECULAR_SCREEN_REUSE
				vec3 hitScreenPos = ScreenPos_From_ViewPos_Raw((hitWorldPos.xyz - gbufferModelViewInverse[3].xyz) * mat3(gbufferModelViewInverse));
				vec3 screenReflection = vec3(0.0);
				
				if (saturate(hitScreenPos) == hitScreenPos){
					ivec2 sampleTexel = ivec2(hitScreenPos.xy * UNIFORM_SCREEN_SIZE + 0.5);

					float sampleDepth = texelFetch(depthtex1, sampleTexel, 0).x;
					vec3 sampleWorldPos = mat3(gbufferModelViewInverse) * ViewPos_From_ScreenPos_Raw(hitScreenPos.xy, sampleDepth) + gbufferModelViewInverse[3].xyz;
					float depthGradient = abs(dot(sampleWorldPos - hitWorldPos.xyz, hitNormal));
					if (depthGradient < 0.15){
						vec3 sampleVertexNormal = DecodeNormal(texelFetch(colortex6, sampleTexel, 0).zw);
						if ((dot(sampleVertexNormal, hitNormal) > 0.9) && (dot(sampleVertexNormal, -normalize(sampleWorldPos)) > 0.08)){
							screenReflection = texelFetch(colortex1, sampleTexel, 0).rgb * reflectionTint.rgb;
							hitWorldPos.w = curve(saturate(4.0 - 4.0 * maxVec2(abs(hitScreenPos.xy * 2.0 - 1.0))));
						}
					}
				}
			#endif

			ivec2 voxelTexel = ivec2(VoxelTexel_From_VoxelCoord(voxelCoord));
			voxelColor = texelFetch(shadowcolor0, voxelTexel, 0) * vec4(voxelColor.rgb, 1.0);

			#if WHITE_DEBUG_WORLD > 0
				voxelColor.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
			#endif
			voxelColor.rgb = GammaToLinear(voxelColor.rgb);

			vec3 ptLighting = vec3(0.0);	

			#ifdef DIMENSION_OVERWORLD
				#ifdef PT_IRC
					#ifdef PT_SPECULAR_IRC_SMOOTH
						ptLighting += SampleIrradianceCache_Full_Smooth(hitVoxelPos, hitNormal, colorSkylight, colorShadowlight, hitSkylight);
					#else
						ptLighting += SampleIrradianceCache_Full(hitVoxelPos, hitNormal, colorSkylight, colorShadowlight, hitSkylight);
					#endif
				#endif
			#else
				#ifdef PT_IRC
					#ifdef PT_SPECULAR_IRC_SMOOTH
						ptLighting += SampleIrradianceCache_Full_Smooth(hitVoxelPos, hitNormal, vec3(0.0), vec3(0.0), hitSkylight);
					#else
						ptLighting += SampleIrradianceCache_Full(hitVoxelPos, hitNormal, vec3(0.0), vec3(0.0), hitSkylight);
					#endif
				#endif
			#endif

			#ifdef PT_LOWRES_ATLAS
				#if TEXTURE_PBR_FORMAT < 2
					vec2 specTex = textureLod(atlasSpecular2D, atlasCoord.xy, atlasCoord.z).ga;
					specTex.g -= step(1.0, specTex.g);
				#else
					vec2 specTex = textureLod(atlasSpecular2D, atlasCoord.xy, atlasCoord.z).gb;
					specTex.g *= 0.996;
				#endif
			#else
				#if TEXTURE_PBR_FORMAT < 2
					vec2 specTex = textureLod(atlasSpecular2D, atlasCoord.xy, 0.0).ga;
					specTex.g -= step(1.0, specTex.g);
				#else
					vec2 specTex = textureLod(atlasSpecular2D, atlasCoord.xy, 0.0).gb;
					specTex.g *= 0.996;
				#endif
			#endif

			#if TEXTURE_EMISSIVENESS_MODE == 1
				if (voxelColor.a == 1.0){
					voxelColor.rgb = vec3(0.95);
				}else{
					voxelColor.a = specTex.g;
				}		
			#elif TEXTURE_EMISSIVENESS_MODE == 2
				voxelColor.a = max(voxelColor.a, specTex.g);
				if (voxelColor.a == 1.0) voxelColor.rgb = vec3(0.95);
			#else
				if (voxelColor.a == 1.0) voxelColor.rgb = vec3(0.95);
			#endif
			bool isMetal = specTex.r > 229.5 / 255.0;
			float metalness = specTex.r * float(isMetal);


			#ifndef DIMENSION_NETHER
				#ifdef DIMENSION_END
					float sunLighting = saturate(dot(shadowModelViewInverseEnd[2], hitNormal)) * rPI;
				#else
					float sunLighting = saturate(dot(shadowModelViewInverse2, hitNormal)) * rPI;
				#endif
				sunLighting *= 1.0 - metalness * (METALMASK_STRENGTH * 0.1 + 0.9);

				#ifdef DIMENSION_OVERWORLD
				#ifdef SUNLIGHT_LEAK_FIX
					sunLighting *= saturate(hitSkylight * 444.0 + float(isEyeInWater == 1));
				#endif
				#endif
				/*
				#ifdef PT_SHADOW
					#ifdef SUNLIGHT_LEAK_FIX
						/if (isEyeInWater == 1)
					#endif
						{
							if (sunLighting > 0.0) sunLighting *= SimpleShadowTracing(hitVoxelPos, worldShadowVector);
						}
				#endif
				*/
				if (sunLighting > 0.0){
					ptLighting += sunLight * SimpleShadow(hitWorldPos.xyz, hitNormal, 1.5e-6) * sunLighting;
				}
			#endif

			ptLighting *= 1.0 - metalness * METALMASK_STRENGTH;

			ptLighting += BLOCKLIGHT_BRIGHTNESS * voxelColor.a * Radiance(voxelColor.rgb);

			#ifdef PT_SPECULAR_SCREEN_REUSE
				reflection += mix(ptLighting * voxelColor.rgb * reflectionTint.rgb, screenReflection, hitWorldPos.w);
				hitWorldPos.w = saturate(1e10 - hitWorldPos.w * 1e10);
			#else
				reflection += ptLighting * voxelColor.rgb * reflectionTint.rgb;
			#endif

		} //PT hit
	}

	//reflection = vec3(0.0);

	#if PT_SSR_MODE < 2
		if (exitTracing)
	#endif

	#if PT_SSR_MODE == 0
		{
			#ifdef DIMENSION_OVERWORLD
				if (isEyeInWater == 0 && skylight > 0.0) reflection += ComputeFakeSkyReflection(rayDir) * skylight;

				if (isSmooth && highlightStrength > 0.0){
					float specularHighlight = SpecularGGX(worldNormal, -worldDir, worldShadowVector, 0.002, vec3(0.06)).x;
					specularHighlight *= highlightStrength * skylight * (saturate(worldNormal.y * 3.0 + 2.0) * 0.75 + 0.25);
					#ifdef MOON_TEXTURE
						reflection += colorSunlight * specularHighlight;
					#else
						reflection += colorShadowlight * specularHighlight;
					#endif
				}
			#endif
		}

	#else
		{
			#if PT_SSR_MODE < 2
				vec3 viewRayOri = (worldPos + hitWorldPos.x * rayDir) * mat3(gbufferModelViewInverse);
			#else
				vec3 viewRayOri = worldPos * mat3(gbufferModelViewInverse);
				viewRayOri += vertexNormal * mat3(gbufferModelViewInverse) * (PT_SSR_QUALITY * (-viewRayOri.z * 0.00002 + 0.001));
			#endif
			vec3 viewRayDir = rayDir * mat3(gbufferModelViewInverse);

			vec3 screenRayPos = ScreenPos_From_ViewPos_Raw(viewRayOri);
			float nearThreshold = maskHand * 0.7;

			bool ssrHit = false;

			//if (saturate(screenRayPos) == screenRayPos){
				float viewRayFar = (-near - viewRayOri.z) / viewRayDir.z + step(viewRayDir.z, 0.0) * 1e20;
				vec3 screenRayDir = normalize(ScreenPos_From_ViewPos_Raw(viewRayOri + viewRayDir * viewRayFar) - screenRayPos);

				vec3 rScreenRayDir = 1.0 / screenRayDir;
				vec3 t1 = -screenRayPos * rScreenRayDir;
				#ifdef DISTANT_HORIZONS
					float farDepth = ScreenDepth_From_DHScreenDepth(1.0);
					vec3 t2 = (vec3(1.0, 1.0, farDepth) - screenRayPos) * rScreenRayDir;
				#else
					vec3 t2 = (vec3(1.0, 1.0, 1.000001) - screenRayPos) * rScreenRayDir;
				#endif
				
				float stepLength = minVec3(max(t1, t2));

				const float stepRatio = 1.0 / (PT_SSR_QUALITY - 3.0);		
				vec2 stepLengthMinMax = vec2(minVec2(UNIFORM_PIXEL_SIZE / (abs(screenRayDir.xy) * stepRatio * stepLength + 1e-10)), stepLength);
				stepLengthMinMax *= stepRatio;
				stepLengthMinMax.x = minVec2(stepLengthMinMax);
				stepLengthMinMax.x *= (0.05 + saturate(NdotV * 5.0 - 0.5) * 0.95);

				float zScaling = abs(1.0 / screenRayDir.z); 

				stepLength = stepLengthMinMax.y * (noise.x * 0.99 + 0.01);
				screenRayPos += screenRayDir * stepLength;


				for (int i = 0; i < PT_SSR_QUALITY; i++){
					if (saturate(screenRayPos.xy) != screenRayPos.xy || screenRayPos.z <= nearThreshold) break;

					#if FSR2_SCALE >= 0
						float sampleDepth = textureLod(depthtex1, screenRayPos.xy * fsrRenderScale, 0.0).x;
					#else
						float sampleDepth = textureLod(depthtex1, screenRayPos.xy, 0.0).x;
					#endif
					#ifdef DISTANT_HORIZONS
						if (sampleDepth == 1.0){
							#if FSR2_SCALE >= 0
								sampleDepth = textureLod(dhDepthTex1, screenRayPos.xy * fsrRenderScale, 0.0).x;
							#else
								sampleDepth = textureLod(dhDepthTex1, screenRayPos.xy, 0.0).x;
							#endif
							sampleDepth = ScreenDepth_From_DHScreenDepth(sampleDepth);
						}
					#endif

					if (sampleDepth < screenRayPos.z + 1e-7){
						vec3 refineDir = screenRayDir * (stepLength * 0.5);
						for (int j = 0; j < 6; j++) {
							screenRayPos += refineDir * fsign(sampleDepth - screenRayPos.z);
							#if FSR2_SCALE >= 0
								sampleDepth = textureLod(depthtex1, screenRayPos.xy * fsrRenderScale, 0.0).x;
							#else
								sampleDepth = textureLod(depthtex1, screenRayPos.xy, 0.0).x;
							#endif							
							#ifdef DISTANT_HORIZONS
								if (sampleDepth == 1.0){
									#if FSR2_SCALE >= 0
										sampleDepth = textureLod(dhDepthTex1, screenRayPos.xy * fsrRenderScale, 0.0).x;
									#else
										sampleDepth = textureLod(dhDepthTex1, screenRayPos.xy, 0.0).x;
									#endif
									sampleDepth = ScreenDepth_From_DHScreenDepth(sampleDepth);
								}
							#endif
							refineDir *= 0.5;
						}

						float distDiff = sampleDepth - screenRayPos.z;
						if (distDiff < 1e-6 && distDiff > -3e-4){
							float stepDist = LinearDepth_From_ScreenDepth(screenRayPos.z);
							float sampleDist = LinearDepth_From_ScreenDepth(sampleDepth);

							ssrHit = abs(sampleDist - stepDist) / stepDist < 0.1;
							#ifdef DISTANT_HORIZONS 
								ssrHit = ssrHit || all(greaterThanEqual(vec2(sampleDepth, screenRayPos.z), vec2(farDepth)));
							#endif
							if (ssrHit){
								#ifdef DIMENSION_END
									#ifdef DISTANT_HORIZONS 
										ssrHit = sampleDepth < farDepth;
									#else
										ssrHit = sampleDepth < 1.0;
									#endif
								#endif
								screenRayPos.z = sampleDepth;
								break;
							}
						}
					}	

					float sampleError = abs(screenRayPos.z - sampleDepth) * zScaling;
					stepLength = clamp(sampleError, stepLengthMinMax.x, stepLengthMinMax.y);
					screenRayPos += screenRayDir * stepLength;	
				} //SSR step loop
			//} //in screen

			#if PT_SSR_MODE == 1

				vec3 screenReflection = vec3(0.0);

				#ifdef DIMENSION_OVERWORLD
					if (skylight > 0.0){
						screenReflection += ComputeFakeSkyReflection(rayDir) * skylight;
					}
				#endif

				if (ssrHit){
					#ifdef PT_SSR_SMOOTH_EDGE
						float ssrWeight = curveTop(saturate(9.0 - 9.0 * maxVec2(abs(screenRayPos.xy * 2.0 - 1.0))));
					#else
						float ssrWeight = float(saturate(screenRayPos.xy) == screenRayPos.xy);
					#endif
					#if FSR2_SCALE >= 0
						screenReflection = mix(screenReflection, textureLod(colortex1, screenRayPos.xy * fsrRenderScale, 0.0).rgb, ssrWeight);
					#else
						screenReflection = mix(screenReflection, textureLod(colortex1, screenRayPos.xy, 0.0).rgb, ssrWeight);
					#endif

					#ifdef DISTANT_HORIZONS
						exitTracing = screenRayPos.z > 0.999999 * farDepth;
					#else
						exitTracing = screenRayPos.z > 0.999999;
					#endif
					
					#ifdef DIMENSION_OVERWORLD
						highlightStrength *= saturate(1.0 - ssrWeight + float(exitTracing));
					#endif

					hitWorldPos.xyz = mat3(gbufferModelViewInverse) * ViewPos_From_ScreenPos_Raw(screenRayPos.xy, screenRayPos.z);
				}

				#ifdef DIMENSION_OVERWORLD
					if (isSmooth && highlightStrength > 0.0){
						float specularHighlight = SpecularGGX(worldNormal, -worldDir, worldShadowVector, 0.002, vec3(0.06)).x;
						specularHighlight *= highlightStrength * skylight * (saturate(worldNormal.y * 3.0 + 2.0) * 0.75 + 0.25);
						#ifdef MOON_TEXTURE
							screenReflection += colorSunlight * specularHighlight;
						#else
							screenReflection += colorShadowlight * specularHighlight;
						#endif
					}
				#endif

				reflection += screenReflection * reflectionTint;


			#elif PT_SSR_MODE == 2

				#ifdef DIMENSION_OVERWORLD
					if (exitTracing && skylight > 0.0){
						reflection += ComputeFakeSkyReflection(rayDir) * reflectionTint.rgb * skylight;
					}
				#endif

				highlightStrength *= float(exitTracing);

				if (ssrHit){
					hitWorldPos.xyz = mat3(gbufferModelViewInverse) * ViewPos_From_ScreenPos_Raw(screenRayPos.xy, screenRayPos.z);

					#if FSR2_SCALE >= 0
						vec3 screenReflection = textureLod(colortex1, screenRayPos.xy * fsrRenderScale, 0.0).rgb;
					#else
						vec3 screenReflection = textureLod(colortex1, screenRayPos.xy, 0.0).rgb;
					#endif

					vec3 posDiff = hitWorldPos.xyz - worldPos;
					float ssrRayLength = length(posDiff);
					if (ssrRayLength > reflectionTint.a) screenReflection *= reflectionTint.rgb;

					#ifdef PT_SSR_SMOOTH_EDGE
						float ssrWeight = curveTop(saturate(9.0 - 9.0 * maxVec2(abs(screenRayPos.xy * 2.0 - 1.0))));
					#else
						float ssrWeight = float(saturate(screenRayPos.xy) == screenRayPos.xy);
					#endif
					ssrWeight *= float(ssrRayLength < (rayLength * 1.1 + 0.1) + float(exitTracing) * 1e10);
					ssrWeight *= saturate(
						saturate(10.0 - dot(posDiff, vertexNormal) * 10.0) +  
						saturate(ssrRayLength + length(worldPos) * (PT_SPECULAR_TRACING_DISTANCE * 0.1) - (PT_SPECULAR_TRACING_DISTANCE * PT_SPECULAR_TRACING_DISTANCE * 0.085)) +		
						float(exitTracing)
					);

					reflection = mix(reflection, screenReflection, ssrWeight);
					
					#ifdef DISTANT_HORIZONS
						exitTracing = screenRayPos.z > 0.999999 * farDepth;
					#else
						exitTracing = screenRayPos.z > 0.999999;
					#endif

					#ifdef DIMENSION_OVERWORLD
						highlightStrength *= saturate(1.0 - ssrWeight + float(exitTracing));
					#endif
				}

				#ifdef DIMENSION_OVERWORLD
					if (isSmooth && highlightStrength > 0.0){
						float specularHighlight = SpecularGGX(worldNormal, -worldDir, worldShadowVector, 0.002, vec3(0.06)).x;
						specularHighlight *= highlightStrength * skylight * (saturate(worldNormal.y * 3.0 + 2.0) * 0.75 + 0.25);
						#ifdef MOON_TEXTURE
							reflection += colorSunlight * reflectionTint.rgb * specularHighlight;
						#else
							reflection += colorShadowlight * reflectionTint.rgb * specularHighlight;
						#endif
					}
				#endif

			#elif PT_SSR_MODE == 3

				#ifdef DIMENSION_OVERWORLD
					if (exitTracing && skylight > 0.0){
						reflection += ComputeFakeSkyReflection(rayDir) * reflectionTint.rgb * skylight;
					}
				#endif

				highlightStrength *= float(exitTracing);

				if (ssrHit){
					hitWorldPos.xyz = mat3(gbufferModelViewInverse) * ViewPos_From_ScreenPos_Raw(screenRayPos.xy, screenRayPos.z);

					#if FSR2_SCALE >= 0
						vec3 screenReflection = textureLod(colortex1, screenRayPos.xy * fsrRenderScale, 0.0).rgb;
					#else
						vec3 screenReflection = textureLod(colortex1, screenRayPos.xy, 0.0).rgb;
					#endif
					
					float ssrRayLength = distance(hitWorldPos.xyz, worldPos);
					if (ssrRayLength > reflectionTint.a) screenReflection *= reflectionTint.rgb;
					
					#ifdef PT_SSR_SMOOTH_EDGE
						float ssrWeight = curveTop(saturate(9.0 - 9.0 * maxVec2(abs(screenRayPos.xy * 2.0 - 1.0))));
					#else
						float ssrWeight = float(saturate(screenRayPos.xy) == screenRayPos.xy);
					#endif
					ssrWeight *= float(ssrRayLength < rayLength + float(exitTracing) * 1e10 + 0.1);

					reflection = mix(reflection, screenReflection, ssrWeight);
					
					#ifdef DISTANT_HORIZONS
						exitTracing = screenRayPos.z > 0.999999 * farDepth;
					#else
						exitTracing = screenRayPos.z > 0.999999;
					#endif
					
					#ifdef DIMENSION_OVERWORLD
						highlightStrength *= saturate(1.0 - ssrWeight + float(exitTracing));
					#endif
				}

				#ifdef DIMENSION_OVERWORLD
					if (isSmooth && highlightStrength > 0.0){
						float specularHighlight = SpecularGGX(worldNormal, -worldDir, worldShadowVector, 0.002, vec3(0.06)).x;
						specularHighlight *= highlightStrength * skylight * (saturate(worldNormal.y * 3.0 + 2.0) * 0.75 + 0.25);
						#ifdef MOON_TEXTURE
							reflection += colorSunlight * reflectionTint.rgb * specularHighlight;
						#else
							reflection += colorShadowlight * reflectionTint.rgb * specularHighlight;
						#endif
					}
				#endif

			#endif

			
			
		} //PT not hit
	#endif

	if(exitTracing) hitWorldPos.xyz = worldPos + rayDir * 6e4;

	#ifndef DIMENSION_NETHER
		hitWorldPos.w *= saturate(1.0 - material.roughness * 20.0);
		imageStore(colorimg4, texelCoord, hitWorldPos);
	#endif

	float hitDist = isSmooth ? -1.0 : distance(hitWorldPos.xyz, worldPos) + step(dot(rayDir, vertexNormal), 0.0) * 10.0 + 1e-3;

	return vec4(max(reflection, 0.0), hitDist);
}


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

		#ifdef DIMENSION_OVERWORLD
			float highlightStrength = float(isEyeInWater == 0 || materialMask.water < 0.5) * shadowHighlightStrength;
		#else
			const float highlightStrength = 0.0;
		#endif

		#ifdef DIMENSION_OVERWORLD
		#ifdef SUNLIGHT_LEAK_FIX
			highlightStrength *= saturate(gbuffer.lightmap.g * 1e10);
		#endif
		#endif
	
		vec3 voxelPos = worldPos + gbufferModelViewInverse[3].xyz + cameraPositionFract + (voxelResolution * 0.5);
		voxelPos += gbuffer.vertexNormal * (-viewPos.z * 0.0003);

		framebuffer2 = SpecularTracing(voxelPos, worldPos, worldDir, gbuffer.worldNormal, gbuffer.vertexNormal, gbuffer.material, gbuffer.lightmap.g, materialMask.hand, isSmooth, highlightStrength);
	}
}
