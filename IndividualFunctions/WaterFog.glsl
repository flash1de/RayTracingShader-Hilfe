
#ifdef FULL_WATERFOG

void WaterFog(inout vec3 color, vec3 worldDir, float opaqueDist, float waterDist, vec3 worldNormal, float VdotSR, MaterialMask mask, float occludedWater, float lightmap){
	occludedWater *= mask.stainedGlass;

	

	if (isEyeInWater == 0){
		float distDiff = opaqueDist - waterDist;
		waterDist = mix(distDiff, min(distDiff, 40.0), occludedWater);

		vec3 l = normalize(reflect(worldDir, worldNormal));
		vec3 h = normalize(l - worldDir);
		float F = saturate(dot(worldNormal, l)) * saturate(dot(l, h) * 1.5 - 0.5);
		float scatter = 8.0 * F / (VdotSR * 5.0 + 5.2);
		scatter *= saturate(1.0 - wetness - occludedWater);

		vec3 scattering = colorShadowlight * scatter + 1.0;

		scattering *= dot(vec3(0.33333), colorSkylight) * lightmap * 0.015;
		scattering *= vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B);

		color *= exp2(-vec3(WATER_ATTENUATION_R, WATER_ATTENUATION_G, WATER_ATTENUATION_B) * waterDist);
		color += scattering * (1.0 - exp2(-waterDist * (0.2 * WATER_SCATTERING_DENSITY)));

	}else

#else 

void WaterFog(inout vec3 color, vec3 worldDir, float waterDist, float VdotSR){

#endif
	
	{
		float eyeWaterDepth = saturate(float(eyeBrightnessSmooth.y) / 240.0);
		float scatter = 1.0 / (VdotSR * 5.0 + 5.5);

		vec3 scattering = colorShadowlight * (scatter * eyeWaterDepth * (5.0 - wetness * 3.0)) + (worldDir.y * 0.4 + 0.6);

		scattering *= dot(vec3(0.33333), colorSkylight) * 0.005;
		scattering *= vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B);

		#ifdef FULL_WATERFOG
			if (mask.hand > 0.5) waterDist = 0.5;
		#endif

		color *= exp2(-vec3(WATER_ATTENUATION_R, WATER_ATTENUATION_G, WATER_ATTENUATION_B) * waterDist);
		color += scattering * (1.0 - exp2(-waterDist * (0.04 * WATER_SCATTERING_DENSITY)));
	}

}