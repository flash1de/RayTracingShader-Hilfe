

vec4 SpecularTemporalFilter(vec4 currData){
	vec4 integratedData = currData;

	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	// reprojection
	vec3 prevWorldPos = vec3(texCoord, depth) * 2.0 - 1.0;
	//#ifdef TAA
		prevWorldPos.xy += taaJitterToPrevious * 0.1;
	//#endif
	prevWorldPos = (vec3(vec2(gbufferProjectionInverse[0][0], gbufferProjectionInverse[1][1]) * prevWorldPos.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2][3] * prevWorldPos.z + gbufferProjectionInverse[3][3]);

	float dist = -prevWorldPos.z;
	if (depth < 0.7){
		#ifndef DECREASE_HAND_GHOSTING
			prevWorldPos += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
		#endif
	}else{
		prevWorldPos = mat3(gbufferModelViewInverse) * prevWorldPos + gbufferModelViewInverse[3].xyz + cameraPositionToPrevious;
	}

	vec3 prevScreenPos = prevWorldPos;
	if (depth >= 0.7) prevScreenPos = mat3(gbufferPreviousModelView) * prevScreenPos + gbufferPreviousModelView[3].xyz;
	prevScreenPos = (vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]) * prevScreenPos + gbufferPreviousProjection[3].xyz) / -prevScreenPos.z * 0.5 + 0.5;

	if (saturate(prevScreenPos.xy) == prevScreenPos.xy){
		vec2 prevTexelcoord = prevScreenPos.xy * UNIFORM_SCREEN_SIZE - 0.5;
		vec2 prevTexel = floor(prevTexelcoord);

		vec4 normalData = texelFetch(colortex6, texelCoord, 0);
		vec3 worldNormal = DecodeNormal(normalData.xy);
		vec3 vertexNormal = DecodeNormal(normalData.zw);

		vec4 prevData = vec4(0.0);
		float weights = 0.0;
		float maxTapWeight = 0.0;

		for (int i = 0; i < 4; i++){
			vec2 sampleTexelcoord = prevTexel + vec2(i & 1, i >> 1);
			ivec2 sampleTexel = ivec2(sampleTexelcoord);

			float bilinearWeight = (1.0 - abs(prevTexelcoord.x - sampleTexelcoord.x)) * (1.0 - abs(prevTexelcoord.y - sampleTexelcoord.y));

			vec4 sampleData = texelFetch(colortex10, sampleTexel, 0);
			float sampleWeight = float(sampleData.w > 1e-4);

			vec4 sampleData1 = texelFetch(colortex9, sampleTexel, 0);

			// remove sky
			sampleWeight *= float(sampleData1.z < 1.0);

			// reprojection
			vec3 sampleViewPos = vec3((sampleTexelcoord + 0.5) * UNIFORM_PIXEL_SIZE, sampleData1.z) * 2.0 - 1.0;
  			sampleViewPos.z = gbufferPreviousProjection[3][2] / (sampleViewPos.z + gbufferPreviousProjection[2][2]);
    		sampleViewPos = vec3(sampleViewPos.xy / vec2(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1]) * sampleViewPos.z, -sampleViewPos.z);

			vec3 sampleWorldPos = sampleViewPos;
			if (sampleData1.z >= 0.7) sampleWorldPos = (sampleViewPos - gbufferPreviousModelView[3].xyz) * mat3(gbufferPreviousModelView);

			// position difference with normal gradient
			vec3 worldVelocity = prevWorldPos - sampleWorldPos;
			float normalGradient = 1.0 / (abs(dot(worldVelocity, vertexNormal)) + 0.001);
			sampleWeight *= step(length(worldVelocity), -sampleViewPos.z * 0.001 * normalGradient + 1e-4);

			// normal difference
			vec3 sampleNormal = DecodeNormal(sampleData1.xy);
			sampleWeight *= pow(saturate(dot(sampleNormal, worldNormal)), 64.0);

			maxTapWeight = max(maxTapWeight, sampleWeight);
			sampleWeight = bilinearWeight * sampleWeight + 1e-10;

			prevData += sampleData * sampleWeight;
			weights += sampleWeight;
		}
		prevData /= weights;

		float smoothness = Unpack2x8_X(texelFetch(colortex5, texelCoord, 0).x);
		float blendWeight = saturate(4.25 - smoothness * 4.5);
		#ifdef DISABLE_REFLECTION_TEMPORAL_MOTIONWEIGHT
			blendWeight += 6.0 * (1.0 - smoothness * 0.6);
		#else
			float motionWeight = fsqrt(length(cameraPositionToPrevious)) * smoothness * smoothness;
			motionWeight /= dist * 0.4 + 1.0;
			motionWeight = saturate(1.0 - smoothness * 0.6 - motionWeight * 8.0);
			blendWeight += 6.0 * motionWeight;
		#endif
		blendWeight *= saturate(25.0 - smoothness * 25.0) * max(0.01666667 / frameTime, 1.0);
		
		blendWeight = 1.0 / (maxTapWeight * blendWeight + 1.0);

		#if defined DECREASE_HAND_GHOSTING && !defined DISABLE_HAND_SPECULAR
			if (GetMaterialID(texelCoord) == MATID_HAND) blendWeight = 1.0;
		#endif

		integratedData.xyz = mix(prevData.xyz, integratedData.xyz, blendWeight);
	}

	return max(integratedData, 0.0);
}