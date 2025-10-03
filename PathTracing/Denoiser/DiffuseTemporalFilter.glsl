

vec4 DiffuseTemporalFilter(float depth, vec4 normalData, vec3 currColor){
	vec4 integratedData = vec4(currColor, 1.0);
	float maxAccumFrames = depth < 0.7 ? 24.0 : PT_DIFFUSE_TEMPORAL_MAX_ACCUM;
	maxAccumFrames = min(maxAccumFrames * clamp(0.01666667 / frameTime, 1.0, 3.0), 256.0);

	// reprojection
	vec3 prevWorldPos = vec3(texCoord, depth) * 2.0 - 1.0;
	//#ifdef TAA
		const float jitterStrength = min(26.0 / maxAccumFrames, 0.5);

		prevWorldPos.xy += taaJitterToPrevious * jitterStrength;
	//#endif
	#ifdef DISTANT_HORIZONS
		if (depth < 0.0){
			prevWorldPos.z = -depth * 2.0 - 1.0;
			prevWorldPos = (vec3(vec2(dhProjectionInverse[0][0], dhProjectionInverse[1][1]) * prevWorldPos.xy, 0.0) + dhProjectionInverse[3].xyz) / (dhProjectionInverse[2][3] * prevWorldPos.z + dhProjectionInverse[3][3]);
			depth = 1.0;
		}else{
			prevWorldPos = (vec3(vec2(gbufferProjectionInverse[0][0], gbufferProjectionInverse[1][1]) * prevWorldPos.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2][3] * prevWorldPos.z + gbufferProjectionInverse[3][3]);
		}
	#else
		prevWorldPos = (vec3(vec2(gbufferProjectionInverse[0][0], gbufferProjectionInverse[1][1]) * prevWorldPos.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2][3] * prevWorldPos.z + gbufferProjectionInverse[3][3]);
	#endif

	float normalWeight = 30.0 / (1.0 - prevWorldPos.z);

	if (depth < 0.7){
		prevWorldPos += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
	}else{
		prevWorldPos = mat3(gbufferModelViewInverse) * prevWorldPos + gbufferModelViewInverse[3].xyz + cameraPositionToPrevious;
	}

	vec3 prevScreenPos = prevWorldPos;
	if (depth >= 0.7) prevScreenPos = mat3(gbufferPreviousModelView) * prevScreenPos + gbufferPreviousModelView[3].xyz;
	prevScreenPos = (vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]) * prevScreenPos + gbufferPreviousProjection[3].xyz) / -prevScreenPos.z * 0.5 + 0.5;

	if (saturate(prevScreenPos.xy) == prevScreenPos.xy){
		vec2 prevTexelcoord = prevScreenPos.xy * UNIFORM_SCREEN_SIZE - 0.5;
		vec2 prevTexel = floor(prevTexelcoord);

		vec3 worldNormal = DecodeNormal(normalData.xy);
		vec3 vertexNormal = DecodeNormal(normalData.xw);

		vec4 prevData = vec4(0.0);
		float weights = 0.0;
		float maxTapWeight = 0.0;

		for (int i = 0; i < 4; i++){
			vec2 sampleTexelcoord = prevTexel + vec2(i & 1, i >> 1);
			ivec2 sampleTexel = ivec2(sampleTexelcoord);

			float bilinearWeight = (1.0 - abs(prevTexelcoord.x - sampleTexelcoord.x)) * (1.0 - abs(prevTexelcoord.y - sampleTexelcoord.y));

			vec4 sampleData = texelFetch(colortex8, sampleTexel, 0);
			vec3 sampleData1 = texelFetch(colortex9, sampleTexel, 0).xyz;

			float sampleNormalWeight = (normalWeight * sampleData.w + normalWeight) / PT_DIFFUSE_TEMPORAL_MAX_ACCUM;

			// remove sky
			float sampleWeight = float(sampleData.a > 0 && abs(sampleData1.z) < 1.0);

			// reprojection

			#ifdef DISTANT_HORIZONS
				vec3 sampleViewPos = vec3((sampleTexelcoord + 0.5) * UNIFORM_PIXEL_SIZE, sampleData1.z) * 2.0 - 1.0;
				if (sampleData1.z < 0.0){
					sampleViewPos.z = dhPreviousProjection[3][2] / (-sampleData1.z * 2.0 - 1.0 + dhPreviousProjection[2][2]);
					sampleViewPos = vec3(sampleViewPos.xy / vec2(dhPreviousProjection[0][0], dhPreviousProjection[1][1]) * sampleViewPos.z, -sampleViewPos.z);
					sampleData1.z = 1.0;
				}else{
					sampleViewPos.z = gbufferPreviousProjection[3][2] / (sampleViewPos.z + gbufferPreviousProjection[2][2]);
					sampleViewPos = vec3(sampleViewPos.xy / vec2(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1]) * sampleViewPos.z, -sampleViewPos.z);
				}
			#else
				vec3 sampleViewPos = vec3((sampleTexelcoord + 0.5) * UNIFORM_PIXEL_SIZE, sampleData1.z) * 2.0 - 1.0;
				sampleViewPos.z = gbufferPreviousProjection[3][2] / (sampleViewPos.z + gbufferPreviousProjection[2][2]);
				sampleViewPos = vec3(sampleViewPos.xy / vec2(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1]) * sampleViewPos.z, -sampleViewPos.z);
			#endif

			vec3 sampleWorldPos = sampleViewPos;
			if (sampleData1.z >= 0.7) sampleWorldPos = (sampleViewPos - gbufferPreviousModelView[3].xyz) * mat3(gbufferPreviousModelView);

			// position difference with normal gradient
			vec3 worldVelocity = prevWorldPos - sampleWorldPos;
			//#if false
			//	float normalGradient = 1.0 / (abs(dot(worldVelocity, vertexNormal)) + 0.005);
			//	sampleWeight *= step(length(worldVelocity), -sampleViewPos.z * 0.001 * normalGradient + 1e-4);
			//#else
				float normalGradient = 1.0 / (abs(dot(worldVelocity, vertexNormal)) + 0.01);
				sampleWeight *= step(length(worldVelocity), sampleViewPos.z * sampleViewPos.z * 0.0005 * normalGradient + 1e-4);
			//#endif

			// normal difference
			vec3 sampleNormal = DecodeNormal(sampleData1.xy);
			//sampleWeight *= pow(saturate(dot(sampleNormal, worldNormal)), saturate(sampleViewPos.z * 0.02 + 1.0) * 80.0 + 10.0);
			sampleWeight *= pow(saturate(dot(sampleNormal, worldNormal)), sampleNormalWeight);

			maxTapWeight = max(maxTapWeight, sampleWeight);
			sampleWeight = bilinearWeight * sampleWeight + 1e-10;

			prevData += sampleData * sampleWeight;
			weights += sampleWeight;
		}
		prevData /= weights;

		if (depth >= 0.7) maxTapWeight *= 1.0 - saturate(exp2(log2(prevScreenPos.z - depth) * 0.7 + 4.0)) * 0.85;

		float accumFrames = prevData.w * maxTapWeight + 1.0;
		accumFrames = min(accumFrames, maxAccumFrames);
		if (abs(float(worldTime + isEyeInWater * 150) - texelFetch(pixelData2D, ivec2(PIXELDATA_WORLDTIME, 0), 0).x) > 100.0) accumFrames = 1.0;

		//accumFrames = 1.0;

		integratedData.xyz = mix(prevData.xyz, integratedData.xyz, 1.0 / accumFrames);
		integratedData.w = accumFrames;

		//integratedData.xyz = currColor;
	}

	return integratedData;
}