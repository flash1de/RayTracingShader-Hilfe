
struct Ray
{
	vec3 ori;
	vec3 dir;
	vec3 rdir;
	vec3 sdir;
};

Ray PackRay(vec3 ori, vec3 dir){
	Ray ray;

	ray.ori = ori;
	ray.dir = dir;
	ray.rdir = 1.0 / ray.dir;
	ray.sdir = sign(ray.dir);

	return ray;
}

vec2 GetAtlasCoord(vec3 voxelCoord, vec2 midTexCoord, float textureResolution, vec3 hitVoxelPos, vec3 hitNormal, vec2 coordOffset, vec2 atlasPixelSize){
	vec3 hitMidPos = hitVoxelPos - voxelCoord - 0.5;

	vec2 hitCoordOffset = vec2(
		hitMidPos.x * abs(hitNormal.y) - hitMidPos.z * hitNormal.x + hitMidPos.x * hitNormal.z,
		hitMidPos.y * abs(hitNormal.y) + hitMidPos.z * hitNormal.y - hitMidPos.y
	);
	hitCoordOffset = saturate(hitCoordOffset + coordOffset + 0.5);

	vec2 atlasTiles = exp2(round(textureResolution * 255.0)) * atlasPixelSize;

	return (floor(midTexCoord / atlasTiles) + hitCoordOffset) * atlasTiles;
}

vec3 GetAtlasCoordWithLod(vec3 voxelCoord, vec2 midTexCoord, float textureResolution, vec3 hitVoxelPos, vec3 hitNormal, vec2 coordOffset, vec2 atlasPixelSize){
	vec3 hitMidPos = hitVoxelPos - voxelCoord - 0.5;

	vec2 hitCoordOffset = vec2(
		hitMidPos.x * abs(hitNormal.y) - hitMidPos.z * hitNormal.x + hitMidPos.x * hitNormal.z,
		hitMidPos.y * abs(hitNormal.y) + hitMidPos.z * hitNormal.y - hitMidPos.y
	);
	hitCoordOffset = saturate(hitCoordOffset + coordOffset + 0.5);

	textureResolution = round(textureResolution * 255.0);
	float lod = max(textureResolution - PT_LOWRES_ATLAS_MIN_RESOLUTION, 0.0);
	
	vec2 atlasTiles = exp2(textureResolution) * atlasPixelSize;
	vec2 atlasCoord = (floor(midTexCoord / atlasTiles) + hitCoordOffset) * atlasTiles;

	return vec3(atlasCoord, lod);
}

vec2 CubemapProjection(vec3 dir){
	const float tileSize = SKYBOX_RESOLUTION / 3.0;
	float tileSizeDivide = 0.5 * tileSize - 1.5;
	vec3 adir = abs(dir);

	vec2 texel;
	if (adir.x > adir.y && adir.x > adir.z){
		dir /= adir.x;
		texel.x = dir.y * tileSizeDivide + tileSize * 0.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.x) + 0.5);
	}else if (adir.y > adir.x && adir.y > adir.z){
		dir /= adir.y;
		texel.x = dir.x * tileSizeDivide + tileSize * 1.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.y) + 0.5);
	}else{
		dir /= adir.z;
		texel.x = dir.x * tileSizeDivide + tileSize * 2.5;
		texel.y = dir.y * tileSizeDivide + tileSize * (step(0.0, dir.z) + 0.5);
	}

	return texel * (1.0 / SKYBOX_RESOLUTION);
}

vec3 SimpleSkyLighting(vec3 skylightColor, vec3 shadowlightColor, float NdotU, float lightmap){
	vec3 skylight = skylightColor * (NdotU * 0.35 + 0.65);
	vec3 skySunLight = shadowlightColor * (NdotU * 0.015 + 0.02);

	skylight += skySunLight;

	//#ifdef VOLUMETRIC_CLOUDS
	//	float coverage = mix(CLOUD_CLEAR_COVERY, CLOUD_RAIN_COVERY, wetness);
	//	skylight += skySunLight * ((1.0 - wetness) * saturate(coverage * 4.0 - 0.6));
	//#endif

	skylight = mix(skylight, shadowlightColor  * (NdotU * 0.003 + 0.005), wetness * 0.6);

	return skylight * max(float(isEyeInWater == 1) * 0.003, lightmap * 0.22);
}


vec3 SimpleShadow(vec3 worldPos, vec3 geoNormal){
	vec3 result = vec3(1.0);

	#ifdef DIMENSION_END
		vec3 shadowScreenPos = shadowModelViewEnd * worldPos;
		shadowScreenPos *= vec3(shadowProjection[0][0], shadowProjection[0][0], -shadowProjection[0][0] * 0.5);
		
		vec3 shadowGeoNormal = shadowModelViewEnd * vec3(geoNormal);
	#else
		vec3 shadowScreenPos = mat3(shadowModelView0, shadowModelView1, shadowModelView2) * worldPos;
		shadowScreenPos *= vec3(shadowProjection[0][0], shadowProjection[0][0], -shadowProjection[0][0] * 0.5);
		
		vec3 shadowGeoNormal = mat3(shadowModelView0, shadowModelView1, shadowModelView2) * vec3(geoNormal);
	#endif
	shadowGeoNormal.z *= -1.0;
	shadowScreenPos += shadowGeoNormal * 0.00025;

	shadowScreenPos = shadowScreenPos * 0.5 + 0.5;

	vec2 warp = vec2(
		textureLod(rtwWarp1D, vec2(shadowScreenPos.x, 0.25), 0.0).x,
		textureLod(rtwWarp1D, vec2(shadowScreenPos.y, 0.75), 0.0).x
	);
	shadowScreenPos.xy += warp * 2.0 - 1.0;

	if (shadowScreenPos.xy == saturate(shadowScreenPos.xy)){
		result = vec3(0.0);

		ShiftShadowScreenPos(shadowScreenPos.xy);
		shadowScreenPos.z -= 4e-5;

		float soildShadow = step(shadowScreenPos.z, textureLod(shadowtex1, shadowScreenPos.xy, 0.0).x);

		if (soildShadow > 0.0){
			float translucentShadow = step(shadowScreenPos.z, textureLod(shadowtex0, shadowScreenPos.xy, 0.0).x);
			result += vec3(translucentShadow);

			float coloredShadow = saturate(soildShadow - translucentShadow);

			if (coloredShadow > 1e-3){
				vec4 shadowColorSample = textureLod(shadowcolor0, shadowScreenPos.xy, 0.0);
				if	(shadowColorSample.a > 0.003){
					shadowColorSample.rgb = mix(vec3(0.95), GammaToLinear(shadowColorSample.rgb) * 0.95, pow(shadowColorSample.a, 0.25));
					result += shadowColorSample.rgb * coloredShadow;
				}else{
					float altitude = shadowColorSample.g * 2.0 + shadowColorSample.b * 510.0;
					altitude = max(altitude - 64.0 - cameraPosition.y - worldPos.y, 0.0);

					shadowColorSample.r = mix(0.85, shadowColorSample.r, saturate(altitude * 0.5));
					result += exp2(-vec3(WATER_ATTENUATION_R, WATER_ATTENUATION_G, WATER_ATTENUATION_B) * altitude) * shadowColorSample.r;
				}
			}
		}
	}

	return result;
}

vec3 SimpleShadow(vec3 worldPos, vec3 geoNormal, float bias){
	vec3 result = vec3(1.0);

	#ifdef DIMENSION_END
		vec3 shadowScreenPos = shadowModelViewEnd * worldPos;
		shadowScreenPos *= vec3(shadowProjection[0][0], shadowProjection[0][0], -shadowProjection[0][0] * 0.5);
		
		vec3 shadowGeoNormal = shadowModelViewEnd * vec3(geoNormal);
	#else
		vec3 shadowScreenPos = mat3(shadowModelView0, shadowModelView1, shadowModelView2) * worldPos;
		shadowScreenPos *= vec3(shadowProjection[0][0], shadowProjection[0][0], -shadowProjection[0][0] * 0.5);
		
		vec3 shadowGeoNormal = mat3(shadowModelView0, shadowModelView1, shadowModelView2) * vec3(geoNormal);
	#endif
	shadowGeoNormal.z *= -1.0;

	shadowScreenPos = shadowScreenPos * 0.5 + 0.5;

	float warpPixelSizeMin = minVec2(vec2(
		textureLod(rtwWarp1D, vec2(shadowScreenPos.x, 0.25), 0.0).y,
		textureLod(rtwWarp1D, vec2(shadowScreenPos.y, 0.75), 0.0).y
	));

	shadowScreenPos += shadowGeoNormal * (bias / (warpPixelSizeMin + 1e-4));

	if (shadowScreenPos.xy == saturate(shadowScreenPos.xy)){
		result = vec3(0.0);

		shadowScreenPos.xy += SampleRTWWarpSmooth(shadowScreenPos.xy);

		ShiftShadowScreenPos(shadowScreenPos.xy);
		shadowScreenPos.z -= 4e-5;

		float soildShadow = SampleShadowBilinear(shadowtex1, shadowScreenPos);

		if (soildShadow > 0.0){
			float translucentShadow = SampleShadowBilinear(shadowtex0, shadowScreenPos);
			result += vec3(translucentShadow);

			float coloredShadow = saturate(soildShadow - translucentShadow);

			if (coloredShadow > 1e-3){
				vec4 shadowColorSample = textureLod(shadowcolor0, shadowScreenPos.xy, 0.0);
				if	(shadowColorSample.a > 0.003){
					shadowColorSample.rgb = mix(vec3(0.95), GammaToLinear(shadowColorSample.rgb) * 0.95, pow(shadowColorSample.a, 0.25));
					result += shadowColorSample.rgb * coloredShadow;
				}else{
					float altitude = shadowColorSample.g * 2.0 + shadowColorSample.b * 510.0;
					altitude = max(altitude - 64.0 - cameraPosition.y - worldPos.y, 0.0);

					shadowColorSample.r = mix(0.85, shadowColorSample.r, saturate(altitude * 0.5));
					result += exp2(-vec3(WATER_ATTENUATION_R, WATER_ATTENUATION_G, WATER_ATTENUATION_B) * altitude) * shadowColorSample.r;
				}
			}
		}
	}

	return result;
}