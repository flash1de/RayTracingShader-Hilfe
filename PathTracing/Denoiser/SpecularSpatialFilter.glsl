

vec4 SpecularSpatialFilter(vec4 currData, float depth){
	vec4 normalData = texelFetch(colortex6, texelCoord, 0);

	vec3 worldNormal = DecodeNormal(normalData.xy);
	vec3 viewVertexNormal = mat3(gbufferModelView) * DecodeNormal(normalData.zw);
	
	vec3 viewPos = ViewPos_From_ScreenPos_Raw(texCoord, depth);
	vec3 viewDir = normalize(viewPos);

	vec2 specularTex = Unpack2x8(texelFetch(colortex5, texelCoord, 0).x);
	float roughness = 1.0 - specularTex.x;
	roughness = roughness * roughness;
	float smoothness = specularTex.y > 229.5 / 255.0 ? -specularTex.x : specularTex.x;
	
	vec2 normalTrans = saturate(dot(mat3(gbufferModelView) * worldNormal, -viewDir) * 2.0) * vec2(0.6, -0.2) + vec2(0.4, 1.2);

	vec2 axis = normalize(vec2(cross(viewVertexNormal, viewDir)));
	axis *= saturate(roughness * 17.5) * 17.5;
	axis *= saturate(currData.w * 0.25 + 0.35);

	#if PT_SPECULAR_NORMAL_WEIGHT == 0
		float normalThreshold = mix(3000.0, 75.0, saturate(roughness * 5.0 - 0.25));
	#else
		float normalThreshold = 500.0 / (roughness + 0.1);
	#endif
	float smoothnessThreshold = 30.0 / (1.0 + saturate(-viewPos.z * 0.1));
	float luminanceThreshold = saturate(currData.w * 0.25) * 0.45 + 0.05;
	float distThreshold = currData.w * 20.0 + 6.0;
	
	#if SPATIAL_FILTER_ORDER == 0
		vec2 noise = vec2(0.0);
		axis *= 2.0;
	#elif SPATIAL_FILTER_ORDER == 1
		vec2 noise = vec2(0.0);
	#elif SPATIAL_FILTER_ORDER == 2
		vec2 noise = BlueNoiseTemporal().yx - 0.5;
		#if defined DECREASE_HAND_GHOSTING && !defined DISABLE_HAND_SPECULAR
			if (GetMaterialID(texelCoord) == MATID_HAND) noise = BlueNoise() - 0.5;
		#endif
		axis *= 0.5;
	#endif

	#if SPATIAL_FILTER_ORDER < 2
		vec4 filteredData = currData;
		filteredData.rgb *= pow(length(currData.rgb + 1e-13), luminanceThreshold - 1.0);
		float weights = 1.0;

		const vec2 offset[8] = vec2[8](
			vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0), 
			vec2(-1.0,  0.0),                  vec2(1.0,  0.0), 
			vec2(-1.0,  1.0), vec2(0.0,  1.0), vec2(1.0,  1.0)
		);

		for (int i = 0; i < 8; i++){
		
	#else
		vec4 filteredData = vec4(0.0);
		float weights = 0.0;

		const vec2 offset[9] = vec2[9](
			vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0), 
			vec2(-1.0,  0.0), vec2(0.0,  0.0), vec2(1.0,  0.0), 
			vec2(-1.0,  1.0), vec2(0.0,  1.0), vec2(1.0,  1.0)
		);

		for (int i = 0; i < 9; i++){
		
	#endif

	
		vec2 sampleOffset = (offset[i] + noise) * normalTrans;
		sampleOffset = axis * sampleOffset.x + vec2(axis.y, -axis.x) * sampleOffset.y;

		if (length(sampleOffset) <= distThreshold){
			vec2 sampleCoord = (vec2(texelCoord) + 0.5) + sampleOffset;
			ivec2 sampleTexel = ivec2(floor(sampleCoord));
			sampleCoord *= UNIFORM_PIXEL_SIZE;
	
			if (sampleTexel == clamp(sampleTexel, ivec2(2), ivec2(UNIFORM_SCREEN_SIZE - 3.0))){
				#if SPATIAL_FILTER_ORDER == 0
					vec4 sampleData = textureLod(colortex10, sampleCoord, 0.0);
				#else
					#if FSR2_SCALE >= 0
						vec4 sampleData = textureLod(colortex2, sampleCoord * fsrRenderScale, 0.0);
					#else
						vec4 sampleData = textureLod(colortex2, sampleCoord, 0.0);
					#endif
				#endif
				sampleData.rgb *= pow(length(sampleData.rgb + 1e-13), luminanceThreshold - 1.0);

				float sampleWeight = saturate(sampleData.a * 1e10);

				vec3 sampleNormal = DecodeNormal(texelFetch(colortex6, sampleTexel, 0).xy);
				sampleWeight *= pow(saturate(dot(sampleNormal, worldNormal)), normalThreshold);

				vec2 sampleData1 = texelFetch(colortex9, sampleTexel, 0).zw;

				sampleWeight *= exp2(-smoothnessThreshold * abs(sampleData1.y - smoothness));

				vec3 sampleViewPos = ViewPos_From_ScreenPos_Raw(sampleCoord, sampleData1.x);			
				float depthGradient = abs(dot(sampleViewPos - viewPos, viewVertexNormal));
				sampleWeight *= step(depthGradient, -viewPos.z * 0.05);

				filteredData += sampleData * sampleWeight;
				weights += sampleWeight;		
			}
		}
	}

	if (weights < 1e-5){
		filteredData = currData;
		
	}else{
		filteredData /= weights;

		filteredData.rgb *= pow(length(filteredData.rgb + 1e-13), 1.0 / luminanceThreshold - 1.0);
	}

	//filteredData = currData;

	return filteredData;
}