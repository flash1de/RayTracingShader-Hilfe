

#ifdef PT_IRC

vec4 SampleIrradianceCache_Raw_OutBlocker(ivec3 ircTexel, float sampleWeight, out float blocker){
	vec4 ircColor = texelFetch(irradianceCache3D, ircTexel, 0);
	blocker = ircColor.a;
	ircColor = vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
	return ircColor - blocker * ircColor;
}

vec4 SampleIrradianceCache_Raw_Blocker(ivec3 ircTexel, float sampleWeight){
	vec4 ircColor = texelFetch(irradianceCache3D, ircTexel, 0);
	sampleWeight *= 1.0 - ircColor.a;
	return vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw(ivec3 ircTexel, float sampleWeight){
	vec3 ircColor = texelFetch(irradianceCache3D, ircTexel, 0).rgb;
	return vec4(ircColor * sampleWeight, float(dot(ircColor, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw_OutBlocker_Alt(ivec3 ircTexel, float sampleWeight, out float blocker){
	vec4 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0);
	blocker = ircColor.a;
	ircColor = vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
	return ircColor - blocker * ircColor;
}

vec4 SampleIrradianceCache_Raw_Blocker_Alt(ivec3 ircTexel, float sampleWeight){
	vec4 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0);
	sampleWeight *= 1.0 - ircColor.a;
	return  vec4(ircColor.rgb * sampleWeight, float(dot(ircColor.rgb, vec3(1.0)) > 0.0) * sampleWeight);
}

vec4 SampleIrradianceCache_Raw_Alt(ivec3 ircTexel, float sampleWeight){
	vec3 ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0).rgb;
	return vec4(ircColor * sampleWeight, float(dot(ircColor, vec3(1.0)) > 0.0) * sampleWeight);
}

vec3 SampleIrradianceCache(vec3 hitVoxelPos){
	ivec3 ircTexel = ivec3(hitVoxelPos) + ((ircResolution - voxelResolutionInt) >> 1);
	vec3 ircColor = vec3(0.0);
	if ((frameCounter & 1) == 0){
		ircColor = texelFetch(irradianceCache3D, ircTexel, 0).rgb;
	}else{
		ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0).rgb;
	}
	return ircColor * 0.01;
}

vec3 SampleIrradianceCache_Full(vec3 hitVoxelPos, vec3 hitNormal, vec3 skylightColor, vec3 shadowlightColor, float lightmap){
	ivec3 ircTexel = ivec3(hitVoxelPos) + ((ircResolution - voxelResolutionInt) >> 1);
	vec3 ircColor = vec3(0.0);

	if (clamp(ircTexel, 0, ircResolution - 1) == ircTexel){
		if ((frameCounter & 1) == 0){
			ircColor = texelFetch(irradianceCache3D, ircTexel, 0).rgb * 0.01;
		}else{
			ircColor = texelFetch(irradianceCache3D_Alt, ircTexel, 0).rgb * 0.01;
		}
	}else{
		#if defined DIMENSION_OVERWORLD || defined DIMENSION_END
			ircColor = SimpleSkyLighting(skylightColor, shadowlightColor, hitNormal.y, lightmap);
		#else
			ircColor = NetherLighting();
		#endif

		#ifdef DIMENSION_OVERWORLD
			ircColor += vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS;
			ircColor += vec3(0.1, 0.6, 1.0) * (dot(vec3(2e-4), skylightColor) * float(isEyeInWater == 1));
		#endif
	}

	return ircColor;
}

vec3 SampleIrradianceCache_Full_Smooth(vec3 hitVoxelPos, vec3 hitNormal, vec3 skylightColor, vec3 shadowlightColor, float lightmap){
	ivec3 hitVoxelCoord = ivec3(hitVoxelPos);
	ivec3 ircTexel = hitVoxelCoord + ((ircResolution - voxelResolutionInt) >> 1);
	vec4 ircColor = vec4(0.0);

	if (clamp(ircTexel, 1, ircResolution - 2) == ircTexel){
		vec3 centerOffset = vec3(hitVoxelCoord) + 0.5 - hitVoxelPos;

		hitNormal = abs(hitNormal);
		hitNormal.xy = step(maxVec3(hitNormal), hitNormal.xz);
		vec3 T = vec3(1.0 - hitNormal.x, hitNormal.x, 0.0);
		vec3 B = vec3(0.0, hitNormal.y, 1.0 - hitNormal.y);

		float blocker = 0.0;

		if ((frameCounter & 1) == 0){
			vec3 sampleOffset = centerOffset;
			float sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw(ircTexel, sampleWeight);

			sampleOffset = centerOffset -T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(-T), sampleWeight, blocker);

			float blocker00 = blocker;
			float blocker01 = blocker;

			sampleOffset = centerOffset -B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(-B), sampleWeight, blocker);

			blocker00 += blocker;
			float blocker10 = blocker;

			if (blocker00 < 1.5){
				sampleOffset = centerOffset -T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(-T -B), sampleWeight);
			}

			sampleOffset = centerOffset +T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(T), sampleWeight, blocker);

			blocker10 += blocker;
			float blocker11 = blocker;

			if (blocker10 < 1.5){
				sampleOffset = centerOffset +T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(T -B), sampleWeight);
			}

			sampleOffset = centerOffset +B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker(ircTexel + ivec3(B), sampleWeight, blocker);

			blocker01 += blocker;
			blocker11 += blocker;

			if (blocker01 < 1.5){
				sampleOffset = centerOffset -T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(-T +B), sampleWeight);
			}

			if (blocker11 < 1.5){
				sampleOffset = centerOffset +T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker(ircTexel + ivec3(T +B), sampleWeight);
			}
		}else{
			vec3 sampleOffset = centerOffset;
			float sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_Alt(ircTexel, sampleWeight);

			sampleOffset = centerOffset -T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(-T), sampleWeight, blocker);

			float blocker00 = blocker;
			float blocker01 = blocker;

			sampleOffset = centerOffset -B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(-B), sampleWeight, blocker);

			blocker00 += blocker;
			float blocker10 = blocker;

			if (blocker00 < 1.5){
				sampleOffset = centerOffset -T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(-T -B), sampleWeight);
			}

			sampleOffset = centerOffset +T;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(T), sampleWeight, blocker);

			blocker10 += blocker;
			float blocker11 = blocker;

			if (blocker10 < 1.5){
				sampleOffset = centerOffset +T -B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(T -B), sampleWeight);
			}

			sampleOffset = centerOffset +B;
			sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
			ircColor += SampleIrradianceCache_Raw_OutBlocker_Alt(ircTexel + ivec3(B), sampleWeight, blocker);

			blocker01 += blocker;
			blocker11 += blocker;

			if (blocker01 < 1.5){
				sampleOffset = centerOffset -T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(-T +B), sampleWeight);
			}

			if (blocker11 < 1.5){
				sampleOffset = centerOffset +T +B;
				sampleWeight = exp2(-dot(sampleOffset, sampleOffset) * PT_IRC_BLUR_FACTOR);
				ircColor += SampleIrradianceCache_Raw_Blocker_Alt(ircTexel + ivec3(T +B), sampleWeight);
			}
		}

		ircColor.rgb *= 0.01 / max(ircColor.a, 1e-10);
	}else{
		#if defined DIMENSION_OVERWORLD || defined DIMENSION_END
			ircColor.rgb = SimpleSkyLighting(skylightColor, shadowlightColor, hitNormal.y, lightmap);
		#else
			ircColor.rgb = NetherLighting();
		#endif

		#ifdef DIMENSION_OVERWORLD
			ircColor.rgb += vec3(0.97, 0.99, 1.18) * NOLIGHT_BRIGHTNESS;
			ircColor.rgb += vec3(0.1, 0.6, 1.0) * (dot(vec3(2e-4), skylightColor) * float(isEyeInWater == 1));
		#endif
		
	}

	return ircColor.rgb;
}

#endif