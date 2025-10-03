

vec4 DiffuseVarianceEstimation(){
	vec4 integratedData = texelFetch(colortex8, texelCoord, 0);

	vec2 moments = vec2(0.0);

	for (int i = -1; i <= 1; i++){
	for (int j = -1; j <= 1; j++){
		ivec2 sampleTexel = texelCoord + ivec2(i, j) * 2;
		sampleTexel = clamp(sampleTexel, ivec2(1), ivec2(screenSize - 2.0));
		float sampleLuminance = Luminance(texelFetch(colortex8, sampleTexel, 0).rgb);
		moments += vec2(sampleLuminance, sampleLuminance * sampleLuminance);
	}}
	moments /= 9.0;

	float variance = max(moments.y - moments.x * moments.x, 0.0) * (25.0 / PT_DIFFUSE_SPATIAL_FILTER_LUMINANCE_WEIGHT);

	float accumFrames = integratedData.w * (PT_DIFFUSE_SPP * 0.18);
	float exposure = saturate(texelFetch(pixelData2D, ivec2(PIXELDATA_EXPOSURE, 0), 0).x * 1000.0);

	variance += (moments.x * moments.x + exposure) / max(exp2(accumFrames * accumFrames) - 1.0, 1e-5);

	variance = sqrt(variance + 2e-6);
	variance = accumFrames > 0.3 ? variance : -variance;

	return vec4(max(integratedData.rgb, 0.0), variance);
}