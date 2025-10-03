

//#define COLORTEX12_3D


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


////////////////////PROGRAM_FINAL_0/////////////////////////////////////////////////////////////////
////////////////////PROGRAM_FINAL_0/////////////////////////////////////////////////////////////////
#ifdef PROGRAM_FINAL_0


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 compositeOutput1;


#include "/Lib/Uniform/GbufferTransforms.glsl"

#ifdef DIMENSION_NETHER
	#include "/Lib/BasicFunctions/NetherColor.glsl"
#endif


vec3 RRTAndODTFit(vec3 v){
	vec3 a = v * (v + 0.0245786) - 0.000090537;
	vec3 b = v * (v + 0.4329510) + 0.238081;
	return a / b;
}

vec3 ACES(vec3 color){
	color *= 1.4;

	#ifdef ABNEY_EFFECT_CORRECTION
		color *= mat3(0.99999976, -1.26657e-7, -1.29064e-9, 1.67316e-8, 0.99999976, -5.32026e-9, -0.00725587, 6.47740e-9, 1.00725580);
	#endif

	color *= mat3(0.59719, 0.35458, 0.04823, 0.07600, 0.90834, 0.01566, 0.02840, 0.13383, 0.83777);

	color = RRTAndODTFit(color);

	color *= mat3(1.60475, -0.53108, -0.07367, -0.10208, 1.10813, -0.00605, -0.00327, -0.07276, 1.07602);

	return LinearToGamma(color);
}


vec3 AgxDefaultContrastApprox(vec3 x){
	return (((((15.5 * x - 40.14) * x + 31.96) * x - 6.868) * x + 0.4298) * x + 0.1191) * x - 0.00232;			 
}

vec3 AgX(vec3 color) {
	color *= 2.3;

	#ifdef ABNEY_EFFECT_CORRECTION
		color *= mat3(0.99999976, -1.26657e-7, -1.29064e-9, 1.67316e-8, 0.99999976, -5.32026e-9, -0.00725587, 6.47740e-9, 1.00725580);
	#endif

	color *= mat3(0.842479062253094, 0.0784335999999992, 0.0792237451477643, 0.0423282422610123, 0.878468636469772, 0.0791661274605434, 0.0423756549057051, 0.0784336, 0.879142973793104);

	const float hev = AGX_EV * 0.5;
	const float midGrey = 0.18;
	color = clamp(log2(color / midGrey), -hev, hev);
	color = (color + hev) / AGX_EV;

	color = AgxDefaultContrastApprox(color);

	color *= mat3(1.19687900512017, -0.0980208811401368, -0.0990297440797205, -0.0528968517574562, 1.15190312990417, -0.0989611768448433, -0.0529716355144438, -0.0980434501171241, 1.15107367264116);

	return color;
}

vec3 None(vec3 color){
	return pow(color, vec3(1.0 / 2.2));
}

vec3 MergeBloom(vec3 color, float bloomGuide){
	#ifdef DIMENSION_OVERWORLD
		float rainAlpha = 1.0 - texelFetch(colortex0, texelCoord, 0).a;
		rainAlpha *= RAIN_VISIBILITY;
	#endif

	#ifdef DIMENSION_NETHER
		#if FSR2_SCALE >= 0
			float linearDepth = 0.0;
		#else
			float linearDepth = Unpack2x16(texelFetch(colortex3, texelCoord, 0).a).x * 1024.0;
		#endif
		//#ifndef DISTANT_HORIZONS
			linearDepth = min(linearDepth, far * 0.8);
		//#endif
	#else
		float depth = texelFetch(depthtex0, texelCoord, 0).x;
		float linearDepth = LinearDepth_From_ScreenDepth(depth);
		//#ifdef DISTANT_HORIZONS
			//if (depth == 1.0) linearDepth = LinearDepth_From_ScreenDepth_DH(texelFetch(dhDepthTex0, texelCoord, 0).x);
		//#endif
	#endif


	//const float maxBloomHeight = 10000.0;
	//float scale = min(1.0, maxBloomHeight / screenSize.y) * 0.5;

	vec3 bloom = textureLod(colortex2, texCoord * 0.5, 0.0).rgb;


	float bloomAmount = BLOOM_AMOUNT;

	#ifdef DIMENSION_END
		bloomAmount *= 0.8 * NETHER_END_BLOOM_BOOST + 1.0;
	#endif

	#ifdef DIMENSION_NETHER
		float biomeOffset =	 BiomeNetherWastesSmooth * 1.0;
		biomeOffset +=		 BiomeCrimsonForestSmooth * 0.75;
		biomeOffset +=		 BiomeWarpedForestSmooth * 0.25;
		biomeOffset +=		 BiomeBasaltDeltasSmooth * 0.5;
	
		biomeOffset = biomeOffset * NETHER_END_BLOOM_BOOST + 1.0;
	
		float fogDensity = biomeOffset * (NETHER_END_BLOOM_BOOST * NETHERFOG_DENSITY * 0.009);
	
		if (isEyeInWater > 1) fogDensity = 0.7;
	
		float fogFactor = 1.0 - exp2(-linearDepth * fogDensity);
		fogFactor *= fogFactor * bloomGuide;
	
		bloomAmount = max(bloomAmount * biomeOffset, min(fogFactor, 0.92));
	#else
		//float fogDensity = float(isEyeInWater > 1) * 0.7;

		//#ifdef WATER_FOG
		//	fogDensity = float(isEyeInWater == 1) * 0.07 * WATERFOG_DENSITY;
		//#endif

		//float visibility = 1.0 / exp2(linearDepth * fogDensity);
		//float fogFactor = 1.1 - visibility;
		//fogFactor *= bloomGuide;

		//bloomAmount = max(bloomAmount, fogFactor);
		bloomAmount = max(bloomAmount, float(isEyeInWater >= 1) * 0.3);
	#endif


	#ifdef DIMENSION_OVERWORLD
		#ifndef INDOOR_FOG
			float rainBloomAmount = wetness * (0.12 * eyeBrightnessSmoothCurved + 0.06);
		#else
			float rainBloomAmount = wetness * 0.18;
		#endif
		//rainBloomAmount = saturate(rainBloomAmount + rainAlpha * 0.2);

		bloomAmount = max(bloomAmount, rainBloomAmount);

		#if defined VFOG && !defined DOF
			#ifdef VFOG_BLOOM
				float fogTransmittance = textureLod(colortex3, texCoord + taaJitter * 0.5, 0.0).a * bloomGuide;

				float fogBloomAmount = fsqrt(fogTransmittance);

				bloomAmount = max(bloomAmount, fogTransmittance);
			#endif
		#endif
	#endif

	#ifndef DISABLE_BLINDNESS_DARKNESS
		bloomAmount *= 1.0 - blindness - darknessFactor;
	#endif

	return mix(color, bloom, saturate(bloomAmount));
}


float GetExposureValue(){
	return texelFetch(pixelData2D, ivec2(PIXELDATA_EXPOSURE, 0), 0).y;
}

float Vignette(vec2 coord, const float falloff, const float roundness){
	vec2 aCoord = coord * 2.0 - 1.0;
	aCoord.x *= mix(1.0, aspectRatio, roundness);
	float rf = dot(aCoord, aCoord) * falloff * falloff + 1.0;
	return 1.0 / (rf * rf);
}



#ifdef PT_TRACING_EYE

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

//uniform sampler3D voxelColor3D;
uniform sampler3D voxelData3D;

#ifdef PT_IRC
	uniform sampler3D irradianceCache3D;
	uniform sampler3D irradianceCache3D_Alt;
#endif

#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"
#include "/Lib/GbufferData.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"


vec3 colorTorchlight = vec3(1.0);
uint randSeed = 0u;

#include "/Lib/PathTracing/Tracer/TracingUtilities.glsl"
#include "/Lib/PathTracing/Voxelizer/BlockShape.glsl"
#include "/Lib/PathTracing/Tracer/ShadowTracing.glsl"

struct TracingData
{
	Ray ray;
	vec3 result;
	vec3 surface;
	vec3 hitVoxelPos;
	vec3 hitNormal;
	float hitSkylight;
	bool traceTranslucent;
};

vec3 PathTracingEye(vec3 worldDir){
    vec3 voxelPos = gbufferModelViewInverse[3].xyz + cameraPositionFract + (voxelResolution * 0.5);
	//voxelPos += gbufferModelViewInverse[2].xyz * 40.0;

	vec3 result = vec3(0.0);

	vec2 atlasPixelSize = 1.0 / vec2(textureSize(atlas2D, 0));

 

	TracingData pt;

	float hitSkylight = 1.0;
		

	pt.surface = vec3(1.0);
	pt.result = vec3(0.0);
	vec3 hitVoxelPos = voxelPos;

	pt.ray = PackRay(voxelPos, worldDir);

	bool exitTracing = true;

	vec3 voxelCoord = floor(pt.ray.ori);
	vec3 totalStep = (pt.ray.sdir * (voxelCoord - pt.ray.ori + 0.5) + 0.5) * abs(pt.ray.rdir);
	float rayLength = 0.0;
	vec3 tracingNext = step(totalStep, vec3(minVec3(totalStep)));
	vec3 hitNormal = vec3(0.0);

	vec4 texColor;

	vec4 voxelData;
	float voxelID;

	bool eliminated = false;


	for (int i = 0; i < 300; i++){
		if (rayLength > 300.0 || clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord){
			exitTracing = true;
			break;
		} 

		voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
		voxelID = floor(voxelData.z * 65535.0 - 999.9);

		vec2 coordOffset = vec2(0.0);


		if (abs(voxelID) < 240.0){


			bool hit = IsHitBlock(pt.ray, totalStep, tracingNext, voxelCoord, abs(voxelID), rayLength, hitNormal, coordOffset);

			if (i == 0) hit = IsHitBlock_FromOrigin_WithInternalIntersection(pt.ray, totalStep, tracingNext, voxelCoord, abs(voxelID), rayLength, hitNormal, coordOffset, eliminated);

			if (hit){

				hitVoxelPos = pt.ray.ori + pt.ray.dir * rayLength + hitNormal * (rayLength * 1e-6 + 1e-5);

				vec2 voxelDataW = Unpack2x8(voxelData.w);

				vec3 dataCoord = GetAtlasCoordWithLod(voxelCoord, voxelData.xy, voxelDataW.x, hitVoxelPos, hitNormal, coordOffset, atlasPixelSize);
				texColor = textureLod(atlas2D, dataCoord.xy, dataCoord.z);

				bool isTranslucent = voxelID == 3.0 || abs(voxelID - 16.5) < 8.0;

				if (isTranslucent){
					vec3 stainedGlassColor = normalize(texColor.rgb + 0.0001) * pow(dot(texColor.rgb, texColor.rgb), 0.25);
					pt.surface *= GammaToLinear(mix(vec3(0.96), texColor.rgb * 0.96, pow(texColor.a, 0.25)));
				}else 

				if (voxelID >= 0.0 || (texColor.a >= 0.1 && rayLength > 0.0)){
					exitTracing = false;
					#ifdef DIMENSION_OVERWORLD
					#ifdef SUNLIGHT_LEAK_FIX
						hitSkylight = voxelDataW.y;
					#endif
					#endif
					break;
					break;
				}

			}

		} //hit voxel ?

		#ifdef PT_SPARE_TRACING
			if (abs(voxelData.z - 0.76) < 0.16){
				float spareSize = floor(voxelData.z * 20.0 - 10.0);

				vec3 spareOrigin = floor(voxelCoord / spareSize) * spareSize;

				vec3 boxMin = spareOrigin - pt.ray.ori;
				vec3 boxMax = boxMin + spareSize;

				vec3 t1 = pt.ray.rdir * boxMin;
				vec3 t2 = pt.ray.rdir * boxMax;

				vec3 tMax = max(t1, t2);
				rayLength = minVec3(tMax);

				tracingNext = step(tMax, vec3(rayLength));

				vec3 exitVoxelCoord = floor(pt.ray.ori + rayLength * pt.ray.dir + tracingNext * pt.ray.sdir * 0.5);

				totalStep += (exitVoxelCoord - voxelCoord) * pt.ray.sdir * abs(pt.ray.rdir);
				voxelCoord = exitVoxelCoord;
			}else{
				rayLength = minVec3(totalStep);
				tracingNext = step(totalStep, vec3(rayLength));
				voxelCoord += tracingNext * pt.ray.sdir;
				totalStep += tracingNext * abs(pt.ray.rdir);
			}
		#else
			rayLength = minVec3(totalStep);
			tracingNext = step(totalStep, vec3(rayLength));
			voxelCoord += tracingNext * pt.ray.sdir;
			totalStep += tracingNext * abs(pt.ray.rdir);
		#endif	
	} //stepping loop

	if (!exitTracing && !eliminated){

		ivec2 voxelTexel = ivec2(VoxelTexel_From_VoxelCoord(voxelCoord));
		vec4 hitAlbedo = texelFetch(shadowcolor0, voxelTexel, 0);
		//vec4 hitAlbedo = texelFetch(voxelColor3D, ivec3(voxelCoord), 0);

		hitAlbedo.rgb *= texColor.rgb;
		#ifdef DP_plain_world
			hitAlbedo.rgb = vec3(DP_plain_world_color);
		#endif

		result = hitAlbedo.rgb * pt.surface;

		#ifndef DIMENSION_NETHER
			#ifdef DIMENSION_OVERWORLD
				vec3 worldShadowVector = shadowModelViewInverse2;
			#else
				vec3 worldShadowVector = shadowModelViewInverseEnd[2];
			#endif

			float sunLighting = saturate(dot(worldShadowVector, hitNormal)) * 0.5;

			#ifdef DIMENSION_OVERWORLD
			#ifdef SUNLIGHT_LEAK_FIX
				sunLighting *= saturate(hitSkylight * 444.0 + float(isEyeInWater == 1));
			#endif
			#endif

			//if (sunLighting > 0.0) sunLighting *= SimpleShadowTracing(hitVoxelPos, worldShadowVector);

			if (sunLighting > 0.0) {
				vec3 hitWorldPos = hitVoxelPos - cameraPositionFract - (voxelResolution * 0.5);
				result += SimpleShadow(hitWorldPos, hitNormal) * sunLighting * pt.surface;
			}
		#endif

		#ifdef DEBUG_IRC
		#ifdef PT_IRC
			result = SampleIrradianceCache(hitVoxelPos);
		#endif
		#endif

		//result = hitAlbedo.aaa;
	}

	//result = vec3(Unpack2x8_Y(voxelData.w));

    return result;
}

#endif





vec3 ColorGrading(vec3 color){
	color = saturate(GammaToLinear(color));

	{	
		vec3 highlight = color * (5.0 / 3.0) - (2.0 / 3.0);
		highlight = saturate(highlight * highlight * (0.6 - highlight * 0.6));
		highlight *= saturate(color * 1e10 - 4e9);

		vec3 shadow = 1.0 - color * (5.0 / 3.0);
		shadow = saturate(shadow * shadow * (0.6 - shadow * 0.6));
		shadow *= saturate(6e9 - color * 1e10);

		color = saturate(color + highlight * HIGHLIGHT_CURVE + shadow * SHADOW_CURVE);
	}

	color = saturate(color * (WHITE_POINT - BLACK_POINT) + BLACK_POINT);

	{
		color += 1e-20;
		float luminance = Luminance(color);

		float gammaLuminance = pow(luminance, 1.0 / 2.2);
		float highlightWeight = curve(saturate(gammaLuminance * 2.5 - 1.5));
		float shadowWeight = curve(saturate(1.0 - gammaLuminance * 2.5));

		vec3 highlight = normalize(color + HSV_to_RGB_Smooth(HIGHLIGHT_HUE / 360.0, 1.0, HIGHLIGHT_STRENGTH));
		vec3 shadow    = normalize(color + HSV_to_RGB_Smooth(SHADOW_HUE    / 360.0, 1.0, SHADOW_STRENGTH));
		vec3 midtone   = normalize(color + HSV_to_RGB_Smooth(MIDTONE_HUE   / 360.0, 1.0, MIDTONE_STRENGTH));

		float colorLength = length(color);
		color /= colorLength;
		color = highlight * highlightWeight + shadow * shadowWeight + midtone * (1.0 - highlightWeight - shadowWeight);
		color *= colorLength;

		#ifdef KEEP_LUMINANCE
			color *= luminance / Luminance(color);
		#endif

		color = saturate(color);
	}

	color = saturate(mix(color, vec3(Luminance(color)), 1.0 - SATURATION));

	color = saturate(pow(color, vec3(1.0 / GAMMA)));

	return color;
}

/*
#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec3 EquirectToDirection(vec2 uv) {

    uv = NORM2SNORM(uv);
    uv.x *= PI;  // phi
    uv.y *= hPI; // theta
        
    return vec3(cos(uv.x)*cos(uv.y)
              , sin(uv.y)
              , sin(uv.x)*cos(uv.y));
}

uniform sampler2D pixelData2D;
//*/
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main(){
	ivec2 texelCoord = ivec2(gl_FragCoord.xy);
	vec4 data1 = texelFetch(colortex1, texelCoord, 0);
	//data1 = texelFetch(colortex2, texelCoord, 0);
	vec3 color = data1.rgb;


	#ifdef PT_TRACING_EYE

		float depth = texelFetch(depthtex0, texelCoord, 0).x;
		vec3 viewPos = ViewPos_From_ScreenPos_Raw(texCoord, depth);
		vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

		color = PathTracingEye(worldDir);

		#ifdef DEBUG_IRC
			color *= GetExposureValue();

			color = TONEMAP_OPERATOR(color);
		#endif

		if (hideGUI > 0) color = color * 0.5 + texelFetch(colortex0, texelCoord, 0).rgb * 0.5;

	#else

		#ifdef BLOOM
			color = MergeBloom(color, 1.0 - data1.a);
		#endif

		#ifdef VIGNETTE
			color *= Vignette(texCoord, VIGNETTE_FALLOFF, VIGNETTE_ROUNDNESS);
		#endif

		color *= GetExposureValue();

		color = TONEMAP_OPERATOR(color);

		#ifdef ADVANCED_COLOR
			color = ColorGrading(color);
		#endif

		#ifdef SNEAKING_VIGNETTE
			color *= mix(1.0, Vignette(vec2(0.5, texCoord.y), 0.7, 0.0), isSneakingSmooth);
		#endif


	#endif

	compositeOutput1 = vec4(color, 0.0);
}


#endif
////////////////////END_IF//////////////////////////////////////////////////////////////////////////





////////////////////PROGRAM_FINAL_1/////////////////////////////////////////////////////////////////
////////////////////PROGRAM_FINAL_1/////////////////////////////////////////////////////////////////
#ifdef PROGRAM_FINAL_1


vec2 finalScreenSize = ceil(screenSize / MC_RENDER_QUALITY);
vec2 finalPixelSize = 1.0 / finalScreenSize;
ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * finalPixelSize;


#include "/Lib/GbufferData.glsl"

#include "/Lib/IndividualFunctions/PrintFloat.glsl"


vec3 FidelityFX_CAS(vec3 sampleE, ivec2 texelCoord){
	//      +---+
	//    g | h | i
	//  +---+---+---+
	//  | d | e | f |
	//  +---+---+---+
	//    a | b | c
	//      +---+

	vec3 sampleB = texelFetch(colortex1, texelCoord + ivec2( 0, -1), 0).rgb;
	vec3 sampleD = texelFetch(colortex1, texelCoord + ivec2(-1,  0), 0).rgb;
	vec3 sampleF = texelFetch(colortex1, texelCoord + ivec2( 1,  0), 0).rgb;
	vec3 sampleH = texelFetch(colortex1, texelCoord + ivec2( 0,  1), 0).rgb;
	float luminanceB = Luminance(sampleB);
	float luminanceD = Luminance(sampleD);
	float luminanceE = Luminance(sampleE);
	float luminanceF = Luminance(sampleF);
	float luminanceH = Luminance(sampleH);

	float minCross = min5(luminanceB, luminanceD, luminanceE, luminanceF, luminanceH);
	float maxCross = max5(luminanceB, luminanceD, luminanceE, luminanceF, luminanceH);

	#if FSR2_SCALE >= 0
		const float sharpness = FSR2_RCAS_SHARPNESS;
	#else
		const float sharpness = CAS_SHARPNESS;
	#endif

	float weight = sqrt(saturate(min(minCross, 2.0 - maxCross) / maxCross)) * (-0.1 - sharpness * 0.01);

	#ifdef CAS_DENOISE
		float noise = luminanceB * 0.25 + luminanceD * 0.25 + luminanceF * 0.25 + luminanceH * 0.25 - luminanceE;
		noise = saturate(abs(noise) / (maxCross - minCross));
		weight *= 1.0 - 0.5 * noise;
	#endif

	vec3 sharpen = (sampleB * weight + sampleD * weight + sampleF * weight + sampleH * weight + sampleE) / (1.0 + 4.0 * weight);

	return max(sharpen, vec3(0.0));
}

float BlackBar(float newRatio){
	if (newRatio == 0.0) return 1.0;
	vec2 aCoord = abs(texCoord - 0.5) * 2.0;
	float width = min(newRatio / aspectRatio, 1.0);
	float height = min(aspectRatio / newRatio, 1.0);

	return step(aCoord.x, width) * step(aCoord.y, height);
}

vec3 Fxaa(vec3 rgbM, vec2 coord){

	#define FXAA_REDUCE_MIN   (1.0/64.0)
	#define FXAA_REDUCE_MUL   (1.0/8.0)
	#define FXAA_SPAN_MAX     16.0
	
	vec3 rgbNW = textureLod(colortex1, coord + pixelSize * vec2(-0.5, -0.5), 0.0).xyz;
	vec3 rgbNE = textureLod(colortex1, coord + pixelSize * vec2( 0.5, -0.5), 0.0).xyz;
	vec3 rgbSW = textureLod(colortex1, coord + pixelSize * vec2(-0.5,  0.5), 0.0).xyz;
	vec3 rgbSE = textureLod(colortex1, coord + pixelSize * vec2( 0.5,  0.5), 0.0).xyz;

	vec3 luma = vec3(0.299, 0.587, 0.114);
	float lumaNW = dot(rgbNW, luma);
	float lumaNE = dot(rgbNE, luma);
	float lumaSW = dot(rgbSW, luma);
	float lumaSE = dot(rgbSE, luma);
	float lumaM  = dot(rgbM,  luma);

	float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
	float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

	vec2 dir;
	dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
	dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

	float dirReduce = max(
		(lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
		FXAA_REDUCE_MIN);
	float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
	dir = min(vec2( FXAA_SPAN_MAX,  FXAA_SPAN_MAX),
		  max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
		  dir * rcpDirMin)) * pixelSize;

	vec3 rgbA = (1.0/2.0) * (
	textureLod(colortex1, coord + dir * vec2(1.0/3.0 - 0.5), 0.0).xyz +
	textureLod(colortex1, coord + dir * vec2(2.0/3.0 - 0.5), 0.0).xyz);
	vec3 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * (
	textureLod(colortex1, coord + dir * vec2(0.0/3.0 - 0.5), 0.0).xyz +
	textureLod(colortex1, coord + dir * vec2(3.0/3.0 - 0.5), 0.0).xyz);

	float lumaB = dot(rgbB, luma);

	if ((lumaB < lumaMin) || (lumaB > lumaMax)) {
		return rgbA;
	} else {
		return rgbB;
	}
}

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"
#include "/Lib/Uniform/ShadowTransforms.glsl"

uniform sampler2D rtwImportance2D;

uniform sampler3D voxelData3D;

uniform sampler2D rippleX2D;
uniform sampler2D ripple2D;
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main(){
	vec3 color = vec3(0.0);
	
	if (MC_RENDER_QUALITY == 1.0){
		color = texelFetch(colortex1, texelCoord, 0).rgb;

		#if defined DECREASE_HAND_GHOSTING && defined DISABLE_PLAYER_TAA_MOTION_BLUR
			float materialIDs = GetMaterialID(texelCoord);
			if (materialIDs == MATID_HAND || materialIDs == MATID_ENTITIES_PLAYER){
				color = Fxaa(color, texCoord);
			}else
		#elif defined DECREASE_HAND_GHOSTING
			float materialIDs = GetMaterialID(texelCoord);
			if (materialIDs == MATID_HAND){
				color = Fxaa(color, texCoord);
			}else
		#elif defined DISABLE_PLAYER_TAA_MOTION_BLUR
			float materialIDs = GetMaterialID(texelCoord);
			if (materialIDs == MATID_ENTITIES_PLAYER){
				color = Fxaa(color, texCoord);
			}else
		#endif
			{
				#if (CAS_SHARPNESS > 0 && defined TAA && FSR2_SCALE < 0) || (FSR2_RCAS_SHARPNESS > 0 && FSR2_SCALE >= 0)
					color = FidelityFX_CAS(color, texelCoord);
				#endif
			}

	}else{
		color = textureLod(colortex1, texCoord, 0.0).rgb;
	}

	color += IGN(gl_FragCoord.xy) * (1.0 / 255.0);

	color *= BlackBar(SEREEN_RATIO);





	//color = vec3(pow(texelFetch(depthtex0, texelCoord, 0).x, 100.0));
	//color = vec3(pow(texelFetch(depthtex1, texelCoord, 0).x, 100.0));
	//color = vec3(pow(0.9992 - texelFetch(colortex3, texelCoord, 0).w, 2000.0));
	//color = vec3(abs(texelFetch(colortex3, texelCoord, 0).w) * 1000.0);
	//color = vec3(pow(texelFetch(fsrReconstructDepth2D, texelCoord, 0).x, 100.0));

	//color = vec3(texelFetch(ripple2D, texelCoord / 5 + ivec2(0, (frameCounter % 60) * 128), 0).z >= 1.0);

	//vec3 rp = texelFetch(ripple2D, texelCoord / 5, 0).xyz;
	//rp.xy = (rp.xy * 2.0 - 1.0) * rp.z;
	//color = vec3(rp.x * 3.0);
	

	//color = texelFetch(colortex0, texelCoord, 0).rgb;
	//color = texelFetch(colortex0, texelCoord, 0).rrr;
	//color = texelFetch(colortex7, texelCoord, 0).ggg;

	//color = texelFetch(colortex15, texelCoord, 0).rgb;
	//color = YCoCg_To_RGB(texelFetch(colortex15, texelCoord, 0).rgb);
	//color = vec3(pow(texelFetch(colortex15, texelCoord, 0).x, 1000.0));

	//color = vec3(abs(texelFetch(colortex15, texelCoord, 0).xy) * 100.0, 0.0);

	//color = texelFetch(colortex3, texelCoord, 0).rgb * 10.0;

	//color = texelFetch(colortex13, texelCoord, 0).rrr;

	//color = texelFetch(colortex3, texelCoord, 0).rgb;

	//color = LinearToGamma(texelFetch(colortex10, texelCoord, 0).rgb * 100.0);

	//color = mix(color, texelFetch(shadowcolor1, texelCoord * 5, 0).bbb, 0.5);


	//color = texelFetch(shadowcolor1, texelCoord * 4, 0).rrr;

	//color = texelFetch(colortex9, texelCoord, 0).aaa * 4.0;
	//color = texelFetch(colortex2, texelCoord, 0).aaa * 1.0;

	//color = DecodeNormal(texelFetch(colortex6, texelCoord, 0).rg) * vec3(1.0, 0.0, 1.0) * 10.0;

	//color = texelFetch(colortex12, ivec3(texelCoord, frameCounter * 16) & 0x0000003f, 0).xyz;
	//vec3 unitVector = texelFetch(colortex12, ivec3(texelCoord % 64, 0), 0).xyz * 2.0 - 1.0;
	//color = vec3(length(unitVector) * 0.5);

	//color = vec3(sqrt(texelFetch(colortex5, texelCoord, 0).a));

	//uvec4 data9 = texelFetch(colortex9, texelCoord, 0);
	//vec2 packX = unpackUnorm2x16(data9.x);
	//vec2 packY = unpackUnorm2x16(data9.y);

	//color = vec3(packY.y * 256.0 < 3.0);

	//color = texelFetch(voxelData3D, ivec3(texelCoord, 95), 0).zzz;

	//vec4 gbuffer5 = texelFetch(colortex5, texelCoord, 0);
	//vec4 specTex = vec4(Unpack2x8(gbuffer5.x), Unpack2x8(gbuffer5.y));
	//color = vec3(specTex.xy, 0.0);

	//color = vec3(texelFetch(colortex10, texelCoord, 0).a);

	//color = vec3(texelFetch(colortex4, texelCoord, 0).a);

	//color = vec3(Unpack2x16(texelFetch(colortex3, texelCoord, 0).a).x * 10.0);
	//color = HSV_to_RGB_Smooth(vec3(texCoord.x, 1.0, 1.0));


//#define DEBUG_RTW

#ifdef DEBUG_RTW
	if (all(lessThan(texelCoord, ivec2(512.0)))){

		float importance = texelFetch(rtwImportance2D, texelCoord * 2, 0).x;

		color = vec3(importance);
	}

	if (clamp(texelCoord.y, 512, 599) == texelCoord.y && texelCoord.x < 512){

		float importance = texelFetch(rtwImportance2D, ivec2(texelCoord.x * 2, 0), 0).x;

		color = vec3(importance);

		if (texelCoord.y >= 555){
			color = vec3(0.0);
			importance = texelFetch(rtwWarp1D, ivec2(texelCoord.x * 2, 0), 0).x * 4.0 - 2.0;
			color.r +=  importance * float(importance > 0);
			color.b += -importance * float(importance < 0);
		}
	}

	if (clamp(texelCoord.x, 512, 599) == texelCoord.x && texelCoord.y < 512){

		float importance = texelFetch(rtwImportance2D, ivec2(texelCoord.y * 2, 1), 0).x;

		color = vec3(importance);

		if (texelCoord.x >= 555){
			color = vec3(0.0);
			importance = texelFetch(rtwWarp1D, ivec2(texelCoord.y * 2, 1), 0).x * 4.0 - 2.0;
			color.r +=  importance * float(importance > 0);
			color.b += -importance * float(importance < 0);
		}
	}

	if (clamp(texelCoord, ivec2(0, 600), ivec2(511, 1111)) == texelCoord){
		color = vec3(0.0);
		vec2 sst = (vec2(texelCoord - ivec2(0, 600)) + 0.5) / 512.0;


		sst *= 0.5;
		sst.x += 0.5;

		color = textureLod(shadowcolor0, sst, 0.0).rgb;
		//color = vec3(textureLod(shadowtex0, sst, 0.0).x);

	}
#endif

	#ifdef DEBUG_COUNTER
		color = saturate(color);
		vec2 tCoord = gl_FragCoord.xy;
		float scale = 4.0;

		//mat4 tmat = shadowModelView;

		if (clamp(tCoord, vec2(0.0), vec2(300.0, 50.0) * scale) == tCoord){
			color = clamp(color.rgb * 0.5, vec3(0.0), vec3(0.8));

			//color += PrintFloat(texelFetch(colortex3, ivec2(0), 0).a, vec2(150.0, 35.0) * scale, scale);
			//color += PrintFloat(fsqrt(length(cameraPositionToPrevious)) * 5.0, vec2(150.0, 25.0) * scale, scale);

			

/*

			vec3 t = Blackbody(4000.0);
			color += PrintFloat(t.x, vec2(50.0, 35.0) * scale, scale);
			color += PrintFloat(t.y, vec2(50.0, 25.0) * scale, scale);
			color += PrintFloat(t.z, vec2(50.0, 15.0) * scale, scale);
//*/		

			const float vx = 21;

			const vec2 vwh = vec2(512, 512);

			const float vy = ceil(vwh.y / vx);

			color += PrintFloat(vx * vwh.x + 2048.0, vec2(50.0, 35.0) * scale, scale);
			color += PrintFloat(vy * vwh.x, vec2(50.0, 25.0) * scale, scale);
			color += PrintFloat(vx * vwh.x, vec2(50.0, 5.0) * scale, scale);







			//color += PrintFloat(LinearDepth_From_ScreenDepth(ScreenDepth_From_DHScreenDepth(texelFetch(dhDepthTex0, ivec2(screenSize * 0.5), 0).x)), vec2(50.0, 35.0) * scale, scale);
			//color += PrintFloat(texelFetch(colortex3, ivec2(2, 0), 0).a, vec2(50.0, 25.0) * scale, scale);



			//vec2 r2 = Sequences_R2(16.0) * 2.0 - 1.0;


			//color += PrintFloat(r2.x, vec2(50.0, 35.0) * scale, scale);
			//color += PrintFloat(r2.y, vec2(50.0, 25.0) * scale, scale);
			

/*
			color += PrintFloat(tmat[0][0], vec2(50.0, 35.0) * scale, scale);
			color += PrintFloat(tmat[1][0], vec2(100.0, 35.0) * scale, scale);
			color += PrintFloat(tmat[2][0], vec2(150.0, 35.0) * scale, scale);
			color += PrintFloat(tmat[3][0], vec2(200.0, 35.0) * scale, scale);

			color += PrintFloat(tmat[0][1], vec2(50.0, 25.0) * scale, scale);
			color += PrintFloat(tmat[1][1], vec2(100.0, 25.0) * scale, scale);
			color += PrintFloat(tmat[2][1], vec2(150.0, 25.0) * scale, scale);
			color += PrintFloat(tmat[3][1], vec2(200.0, 25.0) * scale, scale);

			color += PrintFloat(tmat[0][2], vec2(50.0, 15.0) * scale, scale);
			color += PrintFloat(tmat[1][2], vec2(100.0, 15.0) * scale, scale);
			color += PrintFloat(tmat[2][2], vec2(150.0, 15.0) * scale, scale);
			color += PrintFloat(tmat[3][2], vec2(200.0, 15.0) * scale, scale);

			color += PrintFloat(tmat[0][3], vec2(50.0, 5.0) * scale, scale);
			color += PrintFloat(tmat[1][3], vec2(100.0, 5.0) * scale, scale);
			color += PrintFloat(tmat[2][3], vec2(150.0, 5.0) * scale, scale);
			color += PrintFloat(tmat[3][3], vec2(200.0, 5.0) * scale, scale);
//*/		
		}
	#endif


/*
color = vec3(0.0);

const float cellSize = 15.0;
const float cellNum = 45.0;
const float maxAngle = 90.0;
const float ringInterval = 5.0;

vec2 fragCoord = floor(gl_FragCoord.xy);
fragCoord -= floor(screenSize * 0.5 - cellSize * 0.5);

vec2 cellPos = (floor(fragCoord / cellSize) * cellSize) / (cellSize * cellNum);
float angle = maxVec2(abs(cellPos));

if (angle <= 1.0){
	float z = cos(angle * (maxAngle / 180.0) * PI);
	vec2 dir = normalize(cellPos);
	vec2 xy = dir * sqrt((1.0 - z * z) / dot(dir, dir));

	vec3 normal = normalize(vec3(xy, z));
	if (angle == 0.0) normal = vec3(0.0, 0.0, 1.0);

	color = normal * 0.5 + 0.5;

	vec2 checkCoord = abs(fragCoord - cellSize * 0.5 + 0.5);
	vec2 grid = checkCoord - cellSize * 0.5 - 0.5;
	float ring = maxVec2(grid);

	if (mod(ring, cellSize) == 0.0){
		color = mix(
			color, 
			vec3(1.0), 
			float(mod(ring, cellSize * ringInterval) == 0.0) * 0.5 + 0.3
		);
	}else if (any(equal(mod(grid, cellSize), vec2(0.0)))){
		color = mix(color, vec3(0.0), 0.1);
	}
}

//*/


	gl_FragData[0] = vec4(color, 0.0);


}


#endif
////////////////////END_IF//////////////////////////////////////////////////////////////////////////
