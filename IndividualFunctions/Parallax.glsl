

#if PARALLAX_MODE > 1

#include "/Lib/BasicFunctions/TemporalNoise.glsl"

float sampleHeight(float lod, vec2 quadCoord){
	vec2 atlasCoord = fract(quadCoord) * v_quadCoordMapping.xy + v_quadCoordMapping.zw;
	return textureLod(normals, atlasCoord, lod).a;
}

float BilinearHeightSample(vec2 quadCoord, vec2 atlasSizeF, vec2 quadPixelSize, float lod){
	vec2 atlasCoord = quadCoord * v_quadCoordMapping.xy + v_quadCoordMapping.zw;
	vec2 f = fract(atlasCoord * atlasSizeF);

	vec4 sh = vec4(sampleHeight(lod, quadCoord),
				   sampleHeight(lod, vec2(quadCoord.x + quadPixelSize.x, quadCoord.y)),
				   sampleHeight(lod, vec2(quadCoord.x, quadCoord.y + quadPixelSize.y)),
				   sampleHeight(lod, quadCoord + quadPixelSize)
	);

	sh += saturate(1.0 - sh * 1e20);

	return mix(mix(sh.x, sh.y, f.x),
			   mix(sh.z, sh.w, f.x),
			   f.y);
}

vec3 HeightBasedNormal(vec2 quadCoord, vec2 atlasSizeF, vec2 quadPixelSize, float lod){
	vec2 atlasCoord = quadCoord * v_quadCoordMapping.xy + v_quadCoordMapping.zw;
	vec2 f = fract(atlasCoord * atlasSizeF);

	vec4 sh = vec4(sampleHeight(lod, quadCoord),
				   sampleHeight(lod, vec2(quadCoord.x + quadPixelSize.x, quadCoord.y)),
				   sampleHeight(lod, vec2(quadCoord.x, quadCoord.y + quadPixelSize.y)),
				   sampleHeight(lod, quadCoord + quadPixelSize)
	);

	#if PARALLAX_MODE == 2
		sh.w = sh.y + sh.z -sh.x - sh.w;
		#ifndef PROGRAM_TERRAIN
			return vec3(sh.w * f.yx + (sh.x - sh.yz), (8.0 / PARALLAX_DEPTH) * quadPixelSize.x);
		#else
			return vec3(sh.w * f.yx + (sh.x - sh.yz), (8.0 / PARALLAX_DEPTH) / v_quadCoordScale * quadPixelSize.x);
		#endif
	#else
		const float eps = 0.01;
		f -= 0.5;

		float dX = mix(sh.x - sh.y, sh.z - sh.w, saturate(f.y * 1e20)) * saturate((eps - abs(f.x)) * 1e20);
		float dY = mix(sh.x - sh.z, sh.y - sh.w, saturate(f.x * 1e20)) * saturate((eps - abs(f.y)) * 1e20);
		
		return vec3(dX, dY, step(abs(dX) + abs(dY), 0.0));
	#endif
}

vec2 ParallaxOcclusionMapping(vec2 coord, mat3 tbnMat, vec3 shadowVector, float lod, inout vec3 normalTex, inout float parallaxShadow){
	#ifdef PROGRAM_TERRAIN
		vec2 atlasSizeF = vec2(atlasSize);
	#else
		vec2 atlasSizeF = vec2(textureSize(tex, 0));
	#endif

	if (v_quadCoordMapping.x > 0.0){
		vec2 quadPixelSize = 1.0 / (v_quadCoordMapping.xy * atlasSizeF);
		vec3 parallaxQuadCoord = vec3((coord - v_quadCoordMapping.zw) / v_quadCoordMapping.xy, 1.0);
		#ifdef PROGRAM_TERRAIN
			//parallaxQuadCoord.xy = v_quadCoord;
		#endif

		float sampleHeight = BilinearHeightSample(parallaxQuadCoord.xy, atlasSizeF, quadPixelSize, lod);

		if (sampleHeight > 0.0 && sampleHeight < 1.0){
			parallaxQuadCoord.xy -= quadPixelSize * 0.5;

			vec3 viewVector = normalize(v_worldPos - gbufferModelViewInverse[3].xyz) * tbnMat;
			viewVector /= -viewVector.z;
			
			vec3 stepDir = viewVector / PARALLAX_QUALITY;
			stepDir.y *= quadPixelSize.y / quadPixelSize.x;
			#ifndef PROGRAM_TERRAIN
				stepDir.xy *= PARALLAX_DEPTH * 0.125;
			#else
				stepDir.xy *= v_quadCoordScale * PARALLAX_DEPTH * 0.25;
			#endif

			float stepLength = 2.0 / PARALLAX_QUALITY;

			for (int i = 0; i < PARALLAX_QUALITY; i++, stepLength += 2.0 / PARALLAX_QUALITY){
				parallaxQuadCoord += stepDir * stepLength;

				sampleHeight = BilinearHeightSample(parallaxQuadCoord.xy, atlasSizeF, quadPixelSize, lod);

				if (sampleHeight > parallaxQuadCoord.z) break;
			}

			for (int i = 0; i < PARALLAX_MAX_REFINEMENTS; i++){
				if (sampleHeight > parallaxQuadCoord.z){
					parallaxQuadCoord -= stepDir * stepLength;
					stepLength *= 0.5;
				}

				parallaxQuadCoord += stepDir * stepLength;

				sampleHeight = BilinearHeightSample(parallaxQuadCoord.xy, atlasSizeF, quadPixelSize, lod);
			}

			if (sampleHeight <= parallaxQuadCoord.z) parallaxQuadCoord += stepDir * stepLength * 2.0;

			#ifndef DIMENSION_NETHER
			#ifdef PARALLAX_SHADOW

				if(parallaxShadow > 0.0){
					vec3 shadowQuadCoord = parallaxQuadCoord;

					shadowVector = shadowVector * tbnMat;
					shadowVector /= shadowVector.z * 0.9 + 0.1;		

					vec3 stepSize = shadowVector / (PARALLAX_SHADOW_QUALITY);
					stepSize.y *= quadPixelSize.y / quadPixelSize.x;
					#ifndef PROGRAM_TERRAIN
						stepSize.xy *= PARALLAX_DEPTH * 0.125;
					#else
						stepSize.xy *= v_quadCoordScale * PARALLAX_DEPTH * 0.25;
					#endif

					#if defined TAA
						shadowQuadCoord += stepSize * (BlueNoiseTemporal().x + 0.25);
					#else
						shadowQuadCoord += stepSize * (BlueNoise().x + 0.25);
					#endif

					for (int i = 0; i < PARALLAX_SHADOW_QUALITY; i++, shadowQuadCoord += stepSize){	
						if (shadowQuadCoord.z > 1.0) break;

						sampleHeight = BilinearHeightSample(shadowQuadCoord.xy, atlasSizeF, quadPixelSize, lod);

						float diff = shadowQuadCoord.z - sampleHeight;
						parallaxShadow *= saturate(diff * 40.0 + 0.2);

						if(parallaxShadow < 0.003) break;
					}
				}
			#endif
			#endif

			#if PARALLAX_BASED_NORMAL == 2
				normalTex = HeightBasedNormal(parallaxQuadCoord.xy, atlasSizeF, quadPixelSize, lod);
			#endif

			parallaxQuadCoord.xy += quadPixelSize * 0.5;

			coord = fract(parallaxQuadCoord.xy) * v_quadCoordMapping.xy + v_quadCoordMapping.zw;
		}
	}

	//vec2 parallaxCoord = ivec2(coord * atlasSizeF);

	#if PARALLAX_BASED_NORMAL < 2
		normalTex = DecodeNormalTex(textureLod(normals, coord, lod).rgb);
	#endif

	return coord;
}


#elif PARALLAX_MODE == 1


float sampleHeightT(float lod, ivec2 quadTexel, vec2 atlasPixelSize){
	vec2 atlasCoord = (vec2(quadTexel) + 0.5) * atlasPixelSize;
	return textureLod(normals, atlasCoord, lod).a;
}


vec2 ParallaxOcclusionMapping(vec2 coord, mat3 tbnMat, vec3 shadowVector, float lod, inout vec3 hitNormal, inout float parallaxShadow){
	#ifdef PROGRAM_TERRAIN
		vec2 atlasSizeF = vec2(atlasSize);
	#else
		vec2 atlasSizeF = vec2(textureSize(tex, 0));
	#endif
	vec2 atlasPixelSize = 1.0 / atlasSizeF;

	vec2 atlasTexel = coord * atlasSizeF;
	ivec2 parallaxTexel = ivec2(floor(atlasTexel));

	float sampleHeight = sampleHeightT(lod, parallaxTexel, atlasPixelSize);
	sampleHeight += saturate(1.0 - sampleHeight * 1e20);

	bool exit = false;

	if (sampleHeight > 0.0 && sampleHeight < 1.0){
		//#ifdef PARALLAX_FADE
			//vec2 duvMax = max(abs(duv1), abs(duv2)) / v_quadCoordMapping.xy;
			//float fade = saturate(pow(max(duvMax.x, duvMax.y), -0.4) * 0.2);
			//float fade = 1.0;
		//#endif

		ivec4 tileBase = ivec4(
			floor(v_quadCoordMapping.zw * atlasSizeF + 1e-7),
			ceil((v_quadCoordMapping.xy + v_quadCoordMapping.zw) * atlasSizeF - 1e-7)		
		);
		tileBase.zw -= tileBase.xy;

		vec3 viewVector = normalize(v_worldPos - gbufferModelViewInverse[3].xyz) * tbnMat;
		vec3 stepDir = vec3(viewVector.xy, -viewVector.z);
		float quadSize = v_quadCoordMapping.x * atlasSizeF.x;
		#ifndef PROGRAM_TERRAIN
			stepDir.xy *= quadSize * PARALLAX_DEPTH * 0.125;
		#else
			stepDir.xy *= v_quadCoordScale * quadSize * PARALLAX_DEPTH * 0.25;
		#endif
		stepDir = normalize(stepDir);

		vec2 ardir = abs(1.0 / stepDir.xy);
		ivec2 sdir = (floatBitsToInt(stepDir.xy) >> 31) * 2 + 1;

		vec2 totalStep = (vec2(sdir) * (0.5 - (atlasTexel - vec2(parallaxTexel))) + 0.5) * ardir;

		float stepLength = 0.0;
		float stepHeight = 1.0;
		float prevStepHeight = 1.0;
		ivec2 stepNext = ivec2(0);

		for (int i = 0; i < PARALLAX_QUALITY; i++){
			stepLength = min(totalStep.x, totalStep.y);
			stepHeight = 1.0 - stepLength * stepDir.z;
			if (sampleHeight > stepHeight){
				if (sampleHeight > prevStepHeight){
					hitNormal = vec3(-stepNext * sdir, 0.0);
					sampleHeight = prevStepHeight;
				}
				exit = true;
				break;
			}

			stepNext = (floatBitsToInt(vec2(stepLength) - totalStep) >> 31) + 1;
			parallaxTexel += stepNext * sdir;
			totalStep += vec2(stepNext) * ardir;
			prevStepHeight = stepHeight;

			parallaxTexel = tileBase.xy + ((parallaxTexel - tileBase.xy) % tileBase.zw);
			sampleHeight = sampleHeightT(lod, parallaxTexel, atlasPixelSize);
			sampleHeight += saturate(1.0 - sampleHeight * 1e20);
		}


		#ifndef DIMENSION_NETHER
		#ifdef PARALLAX_SHADOW
			shadowVector = shadowVector * tbnMat;

			float shadow = 1.0;

			if(dot(shadowVector, hitNormal) * parallaxShadow > 0.0 && exit){
				float currHeight = sampleHeight;
				stepLength = (1.0 - currHeight) / stepDir.z;

				vec2 shadowTexel = atlasTexel + stepLength * stepDir.xy;
				ivec2 shadowParallaxTexel = ivec2(floor(shadowTexel));

				#ifndef PROGRAM_TERRAIN
					shadowVector.xy *= quadSize * PARALLAX_DEPTH * 0.125;
				#else
					shadowVector.xy *= v_quadCoordScale * quadSize * PARALLAX_DEPTH * 0.25;
				#endif
				stepDir = normalize(shadowVector);

				vec2 ardir = abs(1.0 / stepDir.xy);
				ivec2 sdir = (floatBitsToInt(stepDir.xy) >> 31) * 2 + 1;

				totalStep = (vec2(sdir) * (0.5 - (shadowTexel - shadowParallaxTexel)) + 0.5) * ardir;
				stepNext = ivec2(0);

				for (int i = 0; i < PARALLAX_SHADOW_QUALITY; i++){
					stepLength = min(totalStep.x, totalStep.y);
					stepHeight = currHeight + stepLength * stepDir.z;

					stepNext = (floatBitsToInt(vec2(stepLength) - totalStep) >> 31) + 1;
					shadowParallaxTexel += stepNext * sdir;
					totalStep += vec2(stepNext) * ardir;

					shadowParallaxTexel = tileBase.xy + ((shadowParallaxTexel - tileBase.xy) % tileBase.zw);
					sampleHeight = sampleHeightT(lod, shadowParallaxTexel, atlasPixelSize);
					sampleHeight += saturate(1.0 - sampleHeight * 1e20);

					if (sampleHeight > stepHeight){
						parallaxShadow = 0.0;
						break;
					}
				}

				//#ifdef PARALLAX_FADE
				//	parallaxShadow *= mix(1.0, shadow, fade);
				//#else
					parallaxShadow *= shadow;
				//#endif
			}
		#endif
		#endif

		coord = (vec2(parallaxTexel) + 0.5) / atlasSizeF;

	#if PARALLAX_BASED_NORMAL == 1
		//#ifdef PARALLAX_FADE
		//	hitNormal = mix(DecodeNormalTex(texelFetch(normals, parallaxTexel, 0).rgb), hitNormal, fade * (1.0 - hitNormal.z));
		//#else
			if(hitNormal.z == 1.0) hitNormal = DecodeNormalTex(textureLod(normals, coord, lod).rgb);
		//#endif
		}else{
			hitNormal = DecodeNormalTex(textureLod(normals, coord, lod).rgb);
	//#elif PARALLAX_BASED_NORMAL == 2 && defined PARALLAX_FADE
	//	hitNormal = mix(vec3(0.0, 0.0, 1.0), hitNormal, fade);
	#endif
	}

	#if PARALLAX_BASED_NORMAL == 0
		hitNormal = DecodeNormalTex(textureLod(normals, coord, lod).rgb);
	#endif

	return coord;
}

#endif