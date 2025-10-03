//Terrain_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
#ifdef DIMENSION_OVERWORLD
	uniform vec3 shadowModelViewInverse2;
#else
	const mat3 shadowModelViewInverseEnd = mat3(0.4523250774, -0.8087002661, -0.3760397683, 0.2486168185, 0.5192604694, -0.8176541093, 0.85649968, 0.2763556486, 0.4359310193);
#endif

uniform float frameTimeCounter;
uniform int frameCounter;
uniform ivec2 atlasSize;
uniform vec3 cameraPosition;
uniform vec3 cameraPositionToPrevious;
uniform float wetness;
uniform float rainStrength;
uniform int renderStage;

uniform vec2 taaJitter;
uniform vec2 pixelSize;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;

//#ifdef DIMENSION_END
//	#include "/Lib/Uniform/ShadowModelViewEnd.glsl"
//#endif

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;


#ifdef VS_VELOCITY
	/* RENDERTARGETS: 0,5,6,7 */
	layout(location = 0) out vec4 framebuffer0;
	layout(location = 1) out vec4 framebuffer5;
	layout(location = 2) out vec4 framebuffer6;
	layout(location = 3) out vec4 framebuffer7;
#else
	/* RENDERTARGETS: 0,5,6 */
	layout(location = 0) out vec4 framebuffer0;
	layout(location = 1) out vec4 framebuffer5;
	layout(location = 2) out vec4 framebuffer6;
#endif


in vec3 v_color;
in vec2 v_texCoord;
in vec3 v_worldPos;
in vec2 v_blockLight;
flat in float v_materialIDs;
flat in float v_emissiveness;
#ifdef TERRAIN_VS_TBN
	in mat3 v_tbn;
#endif
#if PARALLAX_MODE > 0
	flat in vec4 v_quadCoordMapping;
	flat in float v_quadCoordScale;
#else
	flat in float v_textureResolution;
#endif



#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif
#include "/Lib/IndividualFunctions/Parallax.glsl"
#include "/Lib/IndividualFunctions/Ripple.glsl"


#if PARALLAX_MODE == 0

vec4 SampleAnisotropic(vec2 coord, float originLod, inout vec3 normalTex, inout vec4 specularTex){
	vec2 atlasTiles = vec2(atlasSize) / v_textureResolution;
	vec2 tilesCoord = coord * atlasTiles;

	//https://www.shadertoy.com/view/4lXfzn
	mat2 qd = mat2(dFdx(tilesCoord), dFdy(tilesCoord));
	#if FSR2_SCALE >= 0
		qd *= fsrRenderScale.x;
	#endif
	qd = inverse(qd);
	qd = transpose(qd) * qd;

	float d = determinant(qd);
	float t = (qd[0][0] + qd[1][1]) * 0.5;

	float D = sqrt(abs(t * t - d));
	float V = t - D;
	float v = t + D;
	vec2 A = vec2(-qd[0][1], qd[0][0] - V);
	A *= inversesqrt(V * dot(A, A) + 1e-20);

	float lod = log2(inversesqrt(v) * v_textureResolution);

	//#if FSR2_SCALE >= 0
		//lod -= 1.0 / fsrRenderScale.x;
	//#endif

	const float steps = ANISOTROPIC_FILTERING_QUALITY;
	const float rSteps = 1.0 / ANISOTROPIC_FILTERING_QUALITY;

	A *= rSteps;

	vec4 albedoSample = vec4(0.0);
	#ifdef ANISOTROPIC_FILTERING_NORMAL_SPECULAR
		vec3 normalSample = vec3(0.0);
		vec4 specularSample = vec4(0.0);
	#endif

	vec2 tilesBaseCoord = floor(tilesCoord);

	for (float i = 0.5 - steps * 0.5; i < steps * 0.5; i++){
		vec2 sampleCoord = i * A;
		sampleCoord = (tilesBaseCoord + fract(tilesCoord + sampleCoord)) / atlasTiles;

		vec4 sampleAlbedo = textureLod(tex, sampleCoord, lod);

		albedoSample += vec4(sampleAlbedo.rgb * sampleAlbedo.a, sampleAlbedo.a);

		#ifdef ANISOTROPIC_FILTERING_NORMAL_SPECULAR

			#ifdef MC_NORMAL_MAP
				normalSample += textureLod(normals, sampleCoord, lod).rgb * sampleAlbedo.a;
			#endif

			#ifdef MC_SPECULAR_MAP
				#if TEXTURE_EMISSIVENESS_MODE == 0
					specularSample += textureLod(specular, sampleCoord, lod) * sampleAlbedo.a;
				#endif
			#endif

		#endif
	}

	float weights = 1.0 / albedoSample.a;

	#ifdef ANISOTROPIC_FILTERING_NORMAL_SPECULAR

		#ifdef MC_NORMAL_MAP
			normalTex = DecodeNormalTex(normalSample * weights);
		#endif

		#ifdef MC_SPECULAR_MAP
			#if TEXTURE_EMISSIVENESS_MODE == 0
				specularTex = specularSample * weights;
			#else			
				specularTex = textureLod(specular, coord, 0.0);
			#endif
		#endif

	#else

		#ifdef MC_NORMAL_MAP
			normalTex = DecodeNormalTex(textureLod(normals, coord, originLod).rgb);
		#endif

		#ifdef MC_SPECULAR_MAP
			#if TEXTURE_EMISSIVENESS_MODE == 0
				specularTex = textureLod(specular, coord, originLod);
			#else			
				specularTex = textureLod(specular, coord, 0.0);
			#endif			
		#endif

	#endif
	
	return vec4(albedoSample.rgb * weights, textureLod(tex, coord, 0.0).a);
}

#endif


/*

float HashWellons(inout uint randSeed){
	randSeed = HashWellons32(randSeed);
	return float(randSeed) / float(0xffffffffu);
}


vec2 rnp(int index){
	vec2 n = texelFetch(noisetex, ivec2(index, 9), 0).xy;


	return n;
}


vec2 RippleTest(vec2 mcPos){
	mcPos = fract(mcPos);
	float timer = fract(frameTimeCounter * 0.1);
	uint randSeed = 9000u;
	vec2 ripple = vec2(0.0);


	for (int i = 0; i < 64; i ++){
		//vec2 rippleOrigin = vec2(HashWellons(randSeed), HashWellons(randSeed));
		//float start = HashWellons(randSeed);


		vec2 rippleOrigin = rnp(i);
		float start = (float(i) + (HashWellons(randSeed) - 0.5) * 0.5) / 64.0;
		

		//float strength = HashWellons(randSeed) * 0.2 + 0.8;
		float strength = 1.0;

		for (float x = -1.0; x <= 1.0; x++){
		for (float y = -1.0; y <= 1.0; y++){
			vec2 tileOffset = vec2(x, y);
			vec2 ripplePos = rippleOrigin + tileOffset;
			
			for (float t = 0.0; t <= 1.0; t++){
				float ringTimer = max(timer - start + t, 0.0);
				float ringRadius = -0.1 + ringTimer * 0.7;


				float ringStrength = saturate(strength - ringTimer * 1.4) * saturate(ringRadius * 100.0);
				ringStrength = ringStrength;

				float dist = distance(mcPos, ripplePos) - ringRadius;

				float eps = 0.0001;

				float range = 200.0 * ringStrength * ringStrength;

				float p = curve(saturate(1.0 - abs(dist) * range)) - curve(saturate(1.0 - abs(dist - eps) * range));


				ripple += normalize(mcPos.xy - ripplePos.xy) * p * 50.0 * ringStrength;
			}
		}}
	}


	return ripple;
}

*/




void main(){
//TBN
	vec2 duv1 = dFdx(v_texCoord);
	vec2 duv2 = dFdy(v_texCoord);
	
	#ifndef TERRAIN_VS_TBN
		vec3 dp1 = dFdx(v_worldPos);
		vec3 dp2 = dFdy(v_worldPos);

		vec3 N = normalize(cross(dp1, dp2));
		vec3 dp2perp = cross(dp2, N);
		vec3 dp1perp = cross(N, dp1);

		vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
		vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
		float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
		mat3 v_tbn = mat3(T * invmax, B * invmax, N);
	#endif


	vec2 atlasSizeF = vec2(atlasSize);
	duv1 *= atlasSizeF;
	duv2 *= atlasSizeF;
	float lod = 0.5 * log2(max(dot(duv1, duv1), dot(duv2, duv2)));

	#if FSR2_SCALE >= 0
		#if FSR2_SCALE == 1
			lod -= 0.58;
		#elif FSR2_SCALE == 2
			lod -= 0.76;
		#elif FSR2_SCALE == 3
			lod -= 1.0;
		#elif FSR2_SCALE == 4
			lod -= 1.58;
		#endif
	
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif


//anisotropic filtering & parallax
	#ifdef DIMENSION_NETHER
		float parallaxShadow = 1.0;
		vec3 shadowVector = vec3(0.0);
	#else
		#ifdef DIMENSION_OVERWORLD
			vec3 shadowVector = shadowModelViewInverse2;
		#else
			vec3 shadowVector = shadowModelViewInverseEnd[2];
		#endif

		float parallaxShadow = saturate(dot(v_tbn[2], shadowVector) * 200.0);
	#endif

	#if PARALLAX_MODE > 0

		vec3 normalTex = vec3(0.0, 0.0, 1.0);
		vec2 parallaxCoord = ParallaxOcclusionMapping(v_texCoord, v_tbn, shadowVector, lod, normalTex, parallaxShadow);

		vec4 albedoTex = textureLod(tex, parallaxCoord, lod);

		#if MC_VERSION >= 11605 && !defined IS_IRIS
			float alphaRef = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ? 0.004 : 0.1;
		#else
			float alphaRef = 0.1;
		#endif
		if (albedoTex.a < alphaRef) discard;

		#ifdef MC_SPECULAR_MAP
			#if TEXTURE_EMISSIVENESS_MODE == 0
				vec4 specularTex = textureLod(specular, parallaxCoord, lod);
			#else			
				vec4 specularTex = textureLod(specular, parallaxCoord, 0.0);
			#endif		
		#else
			vec4 specularTex = vec4(0.0);
		#endif

	#else

		#if ANISOTROPIC_FILTERING_QUALITY > 0

			vec3 normalTex = vec3(0.0, 0.0, 1.0);
			vec4 specularTex = vec4(0.0);

			vec4 albedoTex = SampleAnisotropic(v_texCoord, lod, normalTex, specularTex);

			#if MC_VERSION >= 11605 && !defined IS_IRIS
				float alphaRef = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ? 0.004 : 0.1;
			#else
				float alphaRef = 0.1;
			#endif

			if (albedoTex.a < alphaRef) discard;


		#else

			vec4 albedoTex = textureLod(tex, v_texCoord, lod);


			#if MC_VERSION >= 11605 && !defined IS_IRIS
				float alphaRef = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ? 0.004 : 0.1;
			#else
				float alphaRef = 0.1;
			#endif
			if (albedoTex.a < alphaRef) discard;

			#ifdef MC_NORMAL_MAP
				vec3 normalTex = DecodeNormalTex(textureLod(normals, v_texCoord, lod).rgb);
			#else
				vec3 normalTex = vec3(0.0, 0.0, 1.0);
			#endif


			#ifdef MC_SPECULAR_MAP
				#if TEXTURE_EMISSIVENESS_MODE == 0
					vec4 specularTex = textureLod(specular, v_texCoord, lod);
				#else			
					vec4 specularTex = textureLod(specular, v_texCoord, 0.0);
				#endif		
			#else
				vec4 specularTex = vec4(0.0);
			#endif
			
		#endif

	#endif


//albedo
	vec3 albedo = albedoTex.rgb * v_color;

	//if (v_quadCoordMapping.x == 0.0) albedo = vec3(1.0, 0.0, 0.0);

	#if WHITE_DEBUG_WORLD > 0
		albedo = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif


//wet effect
	#ifdef ENABLE_ROUGH_SPECULAR

		vec3 mcPos = v_worldPos + cameraPosition;
		float NdotU = v_tbn[2].y;

		//albedo = vec3(RippleTest(mcPos.xz), 0.0);

		#ifdef TEXTURE_PBR_POROSITY
		#endif

		#if defined TEXTURE_PBR_POROSITY && TEXTURE_PBR_FORMAT < 2
			float porosity = saturate(specularTex.b * (255.0 / 63.0) - step(64.0 / 255.0, specularTex.b));
		#else
			const float porosity = TEXTURE_DEFAULT_POROSITY;
		#endif

		#ifdef DIMENSION_OVERWORLD
			#ifndef DISABLE_LOCAL_PRECIPITATION
				float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
			#else
				float wet = wetness + SURFACE_WETNESS;
			#endif

			wet *= float(abs(v_emissiveness - 0.99) > 0.005);
			wet *= step(0.9, v_blockLight.y);

			vec2 rainNormal = vec2(0.0);
			if (wet > 1e-7){
				wet *= GetModulatedRainSpecular(mcPos);
				wet *= saturate(v_blockLight.y * 10.0 - 9.0);

				albedo *= 1.0 - wet * fsqrt(porosity) * POROSITY_ABSORPTION;

				wet = saturate(wet * (1.8 - porosity) - porosity * 0.2);

				#ifdef RAIN_SPLASH_EFFECT
					float splashStrength = rainStrength;
					splashStrength *= saturate(NdotU * 2.0 - 1.0);
					splashStrength *= saturate(1.5 - porosity * 1.5);
					splashStrength *= exp2(-length(v_worldPos) * 0.05);

					if (splashStrength > 1e-5) rainNormal = GetRippleNormal(mcPos.xz, wet, splashStrength);
				#endif

				wet *= saturate(NdotU * 0.5 + 0.5);
			}
		#else
			float wet = SURFACE_WETNESS;

			if (wet > 1e-7){
				wet *= float(abs(v_emissiveness - 0.99) > 0.005);
				wet *= GetModulatedRainSpecular(mcPos);

				albedo *= 1.0 - wet * fsqrt(porosity) * POROSITY_ABSORPTION;

				wet = saturate(wet * (1.8 - porosity) - porosity * 0.2);
				wet *= saturate(NdotU * 0.5 + 0.5);
			}		
		#endif

	#else
		float wet = 0.0;
	#endif


//normal
	#if defined MC_NORMAL_MAP && defined ENABLE_ROUGH_SPECULAR
		normalTex = mix(
			normalize(normalTex),
			vec3(0.0, 0.0, 1.0),
			saturate(wet * 2.0 - 1.0)
		);
	#endif


	vec3 worldNormal = v_tbn * normalize(normalTex);


	#if defined ENABLE_ROUGH_SPECULAR && defined DIMENSION_OVERWORLD && defined RAIN_SPLASH_EFFECT 
		worldNormal = normalize(worldNormal + vec3(rainNormal.x, 0.0, rainNormal.y));
	#endif


	#ifdef TERRAIN_NORMAL_CLAMP
		vec3 worldDir = -normalize(v_worldPos);
		worldNormal = normalize(worldNormal + v_tbn[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
	#endif

	vec4 normalEnc = vec4(EncodeNormal(worldNormal), EncodeNormal(v_tbn[2]));


//specular
	#if defined MC_SPECULAR_MAP && TEXTURE_PBR_FORMAT == 2
		specularTex.a = specularTex.b;
	#endif

	#if TEXTURE_EMISSIVENESS_MODE == 0
		specularTex.a = v_emissiveness;
	#else
		#if TEXTURE_PBR_FORMAT < 2
			specularTex.a -= step(1.0, specularTex.a);
		#endif
		#if TEXTURE_EMISSIVENESS_MODE == 2
			specularTex.a = max(specularTex.a, v_emissiveness);
		#endif
	#endif

	#if TEXTURE_EMISSIVENESS_MODE != 1
		if (v_emissiveness < 0.0){
			specularTex.a = saturate(2.0 * albedo.r - 1.5 * albedo.g);
		}
	#endif
	
	#ifdef ENABLE_ROUGH_SPECULAR
		specularTex.r = mix(specularTex.r, 1.0, wet);
	#endif

	//specularTex.r = 1.0 - sqrt(0.020);

	framebuffer0 = vec4(albedo, 1.0); //vec3(any(greaterThan(at_midBlock, vec3(31.0))))
	framebuffer5 = vec4(Pack2x8(specularTex.rg), Pack2x8(specularTex.ba), Pack2x8(vec2(parallaxShadow, v_materialIDs / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
	framebuffer6 = vec4(normalEnc);

	#ifdef VS_VELOCITY
		vec3 prevScreenPos = v_worldPos + cameraPositionToPrevious;
		prevScreenPos = mat3(gbufferPreviousModelView) * prevScreenPos + gbufferPreviousModelView[3].xyz;
		prevScreenPos = (vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]) * prevScreenPos + gbufferPreviousProjection[3].xyz) / -prevScreenPos.z * 0.5 + 0.5;
			
		vec3 currScreenPos = vec3(gl_FragCoord.xy * pixelSize - taaJitter * 0.5, gl_FragCoord.z);
		
		framebuffer7 = vec4(currScreenPos - prevScreenPos, 0.0);
	#endif
}
