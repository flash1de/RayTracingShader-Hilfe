

float CalculateCoCRadius(float f, float d, float a){
	return abs(a * (d - f) / (d * f));
}

float GetLinearDepth(vec2 coord){
	float depth = textureLod(depthtex0, coord, 0.0).x;
	#ifdef DISTANT_HORIZONS
		if (depth == 1.0){
			depth = textureLod(dhDepthTex0, coord, 0.0).x;
			depth = LinearDepth_From_ScreenDepth_DH(depth);
		}else{
			depth = LinearDepth_From_ScreenDepth(depth);
		}
	#else
		depth = LinearDepth_From_ScreenDepth(depth);
	#endif
	return max(depth, 0.3);
}

float GetFocus(){
	#if CAMERA_FOCUS_MODE == 0
		float focus = texelFetch(pixelData2D, ivec2(PIXELDATA_CENTER_DEPTH, 0), 0).x;
	#else
		float focus = CAMERA_FOCAL_POINT;
	#endif
	return focus;
}


float CoCSpread(){
	float cocRadiusfactor = DOF_BLUR * gbufferProjection[1][1];
	#if DOF_BLUR_REFERENCE > 0
		cocRadiusfactor *= gbufferProjection[1][1];
	#endif
	float rAspectRatio = 1.0 / aspectRatio;
	#ifdef TAA
		vec2 noise = BlueNoiseTemporal();
	#else
		vec2 noise = BlueNoise();
	#endif

	#if FSR2_SCALE >= 0
		float currDepth = GetLinearDepth(texCoord * fsrRenderScale);
	#else
		float currDepth = GetLinearDepth(texCoord);
	#endif
	float focus = GetFocus();
	float currCoc = CalculateCoCRadius(focus, currDepth, cocRadiusfactor);

	float startRadius = currCoc / DOF_MAX_COC;
	startRadius *= startRadius;


	float spreadCoc = currCoc;

	const float steps = DOF_COCSPREAD_QUALITY;
	const float rSteps = 1.0 / steps;
	const mat2 rotMat = mat2(cos(goldenAngle), sin(goldenAngle), -sin(goldenAngle), cos(goldenAngle));
	float angle = noise.x * TAU;
	vec2 rot = vec2(cos(angle), sin(angle));

	for (float i = 0.0; i < steps; i++){
		rot *= rotMat;
		float sampleRadius = sqrt(startRadius + (i + noise.y) * (1.0 - startRadius) * rSteps) * DOF_MAX_COC;
		vec2 sampleCoordOffset = rot * sampleRadius;
		sampleCoordOffset.x *= rAspectRatio;
		vec2 sampleCoord = texCoord + sampleCoordOffset;
		#if FSR2_SCALE >= 0
			sampleCoord *= fsrRenderScale;
		#endif

		float sampleDepth = GetLinearDepth(sampleCoord);
		float sampleCoC = CalculateCoCRadius(focus, sampleDepth, cocRadiusfactor);

		if (sampleCoC >= sampleRadius && sampleDepth <= currDepth){
			spreadCoc = max(spreadCoc, sampleCoC);
		}
	}

	spreadCoc = min(spreadCoc, DOF_MAX_COC) / DOF_MAX_COC;
	return spreadCoc;
}

vec4 DepthOfField(){
	vec4 currData = texelFetch(colortex1, texelCoord, 0);
	float depth = texelFetch(depthtex0, texelCoord, 0).x;

	#if defined DISABLE_HAND_DOF || defined DECREASE_HAND_GHOSTING
		if (depth < 0.7) return vec4(currData.rgb, 0.0);
	#endif

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0){
			depth = texelFetch(dhDepthTex0, texelCoord, 0).x;
			depth = saturate(ScreenDepth_From_DHScreenDepth(depth));
		}
	#endif
	float currDepth = LinearDepth_From_ScreenDepth(depth);


	float cocRadiusfactor = DOF_BLUR * gbufferProjection[1][1];
	#if DOF_BLUR_REFERENCE > 0
		cocRadiusfactor *= gbufferProjection[1][1];
	#endif
	float minCoc = 0.5641895835 * UNIFORM_PIXEL_SIZE.y;
	float rAspectRatio = 1.0 / aspectRatio;

	float focus = GetFocus();
	float currCoc = CalculateCoCRadius(focus, currDepth, cocRadiusfactor);
	currCoc = clamp(currCoc, minCoc, DOF_MAX_COC);

	float spreadCoc = currData.a * DOF_MAX_COC;

	float centerWeight = spreadCoc * spreadCoc - spreadCoc + 1.0;
    centerWeight = mix(centerWeight, 1e-20, pow(currCoc / spreadCoc, 4.0));

	#ifdef DOF_CATSEYE
		vec2 catsEyeOffset = (texCoord) * 2.0 - 1.0;
		catsEyeOffset.x *= aspectRatio;
		float catsEyeDist = length(catsEyeOffset);
		catsEyeDist = max(catsEyeDist - DOF_CATSEYE_MIDPOINT, 0.0);
		catsEyeDist *= spreadCoc * DOF_CATSEYE_STRENGTH;
		catsEyeOffset = normalize(catsEyeOffset) * catsEyeDist;
	#endif

	#ifdef TAA
		vec2 noise = BlueNoiseTemporal();
	#else
		vec2 noise = BlueNoise();
	#endif

	vec3 dof = vec3(0.0);
	float weights = 0.0;
	vec3 selfColor = currData.rgb * 1e-20;
	float selfSamples = 1e-20;
	float selfWeights = 0.0;
#if defined DIMENSION_NETHER && FSR2_SCALE < 0
	float blendedDepth = 0.0;
	float selfDepth = currDepth * 1e-20;
#endif


	const float steps = DOF_QUALITY;
	const float rSteps = 1.0 / steps;
	const mat2 rotMat = mat2(cos(goldenAngle), sin(goldenAngle), -sin(goldenAngle), cos(goldenAngle));
	float angle = noise.x * TAU;
	vec2 rot = vec2(cos(angle), sin(angle));

	for (float i = 0.0; i < steps; i++){
		rot *= rotMat;
		float sampleRadius = sqrt((i + noise.y) * rSteps) * spreadCoc;
		vec2 sampleCoordOffset = rot * sampleRadius;
		
		#ifdef DOF_CATSEYE
			if (distance(catsEyeOffset, sampleCoordOffset) > spreadCoc) continue;
		#endif

		sampleCoordOffset.x *= rAspectRatio;
		
		vec2 sampleCoord = texCoord + sampleCoordOffset;
		#if FSR2_SCALE >= 0
			sampleCoord = min(sampleCoord, 1.0 - fsrPixelSize * 0.5);
			sampleCoord *= fsrRenderScale;		
		#endif

		#if defined DISABLE_HAND_DOF || defined DECREASE_HAND_GHOSTING
			float sampleDepth = textureLod(depthtex0, sampleCoord, 0.0).x;

			if (sampleDepth < 0.7) continue;

			#ifdef DISTANT_HORIZONS
				if (sampleDepth == 1.0){
					sampleDepth = textureLod(dhDepthTex0, sampleCoord, 0.0).x;
					sampleDepth = LinearDepth_From_ScreenDepth_DH(sampleDepth);
				}else{
					sampleDepth = LinearDepth_From_ScreenDepth(sampleDepth);
				}
			#else
				sampleDepth = LinearDepth_From_ScreenDepth(sampleDepth);
			#endif
		#else
			float sampleDepth = GetLinearDepth(sampleCoord);
		#endif

		float sampleCoC = CalculateCoCRadius(focus, sampleDepth, cocRadiusfactor);
		sampleCoC = clamp(sampleCoC, minCoc, DOF_MAX_COC);
		vec3 sampleColor = textureLod(colortex1, sampleCoord, 0.0).rgb;

#if defined DIMENSION_NETHER && FSR2_SCALE < 0

		if (currCoc >= sampleRadius && sampleDepth >= currDepth){
			selfColor += sampleColor;
			selfDepth += sampleDepth;
			selfSamples += 1.0;
		}else if (sampleCoC >= sampleRadius && sampleDepth < currDepth){
			float sampleWeight = max(1.0, currCoc / sampleCoC);
			sampleWeight *= sampleWeight;
			dof += sampleColor * sampleWeight;
			blendedDepth += sampleDepth * sampleWeight;
			weights += sampleWeight;
		}else{
			selfWeights += centerWeight;
		}
	}

	dof += selfColor * (1.0 + selfWeights / selfSamples);
    dof /= weights + selfSamples + selfWeights;

	blendedDepth += selfDepth * (1.0 + selfWeights / selfSamples);
	blendedDepth /= weights + selfSamples + selfWeights;

    return vec4(max(dof, 0.0), blendedDepth);

#else

		if (currCoc >= sampleRadius && sampleDepth >= currDepth){
			selfColor += sampleColor;
			selfSamples += 1.0;
		}else if (sampleCoC >= sampleRadius && sampleDepth < currDepth){
			float sampleWeight = max(1.0, currCoc / sampleCoC);
			sampleWeight *= sampleWeight;
			dof += sampleColor * sampleWeight;
			weights += sampleWeight;
		}else{
			selfWeights += centerWeight;
		}
	}

	dof += selfColor * (1.0 + selfWeights / selfSamples);
    dof /= weights + selfSamples + selfWeights;

    return vec4(max(dof, 0.0), 0.0);

#endif
}
