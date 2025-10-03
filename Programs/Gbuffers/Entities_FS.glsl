//Entities_FS Spidereyes_FS Block_FS Hand_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
#ifdef DIMENSION_OVERWORLD
	uniform vec3 shadowModelViewInverse2;
#else
	const mat3 shadowModelViewInverseEnd = mat3(0.4523250774, -0.8087002661, -0.3760397683, 0.2486168185, 0.5192604694, -0.8176541093, 0.85649968, 0.2763556486, 0.4359310193);
#endif

uniform vec3 cameraPosition;
uniform vec3 cameraPositionToPrevious;
uniform float wetness;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 taaJitter;
uniform vec2 pixelSize;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;

//#ifdef DIMENSION_END
//	#include "/Lib/Uniform/ShadowModelViewEnd.glsl"
//#endif

uniform sampler2D tex;
uniform sampler2D specular;
uniform sampler2D normals;
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


in vec4 v_color;
in vec2 v_texCoord;
in vec3 v_worldPos;
in vec2 v_blockLight;
flat in float v_materialIDs;
flat in float v_emissiveness;

#if (defined ENTITIES_VS_TBN && (defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES) && (MC_VERSION < 11500 || MC_VERSION > 11604)) || (defined PROGRAM_HAND && MC_VERSION < 11300)
	in mat3 v_tbn;
#endif

#ifdef PROGRAM_BLOCK
	in vec4 v_portalCoord;

	const vec3[] COLORS = vec3[](
	vec3(0.022087, 0.098399, 0.110818),
	vec3(0.011892, 0.095924, 0.089485),
	vec3(0.027636, 0.101689, 0.100326),
	vec3(0.046564, 0.109883, 0.114838),
	vec3(0.064901, 0.117696, 0.097189),
	vec3(0.063761, 0.086895, 0.123646),
	vec3(0.084817, 0.111994, 0.166380),
	vec3(0.097489, 0.154120, 0.091064),
	vec3(0.106152, 0.131144, 0.195191),
	vec3(0.097721, 0.110188, 0.187229),
	vec3(0.133516, 0.138278, 0.148582),
	vec3(0.070006, 0.243332, 0.235792),
	vec3(0.196766, 0.142899, 0.214696),
	vec3(0.047281, 0.315338, 0.321970),
	vec3(0.204675, 0.390010, 0.302066),
	vec3(0.080955, 0.314821, 0.661491));

	const mat4 SCALE_TRANSLATE = mat4(0.5, 0.0, 0.0, 0.25,
									  0.0, 0.5, 0.0, 0.25,
									  0.0, 0.0, 1.0, 0.0,
									  0.0, 0.0, 0.0, 1.0);

	mat2 mat2_rotate_z(float radian){
		return mat2(cos(radian), -sin(radian), sin(radian), cos(radian));
	}

	mat4 end_portal_layer(float layer){
		mat4 translate = mat4(1.0, 0.0, 0.0, 17.0 / layer,
							  0.0, 1.0, 0.0, (2.0 + layer / 1.5) * (frameTimeCounter * 0.0005),
							  0.0, 0.0, 1.0, 0.0,
							  0.0, 0.0, 0.0, 1.0);

		mat2 rotate = mat2_rotate_z(radians((layer * layer * 4321.0 + layer * 9.0) * 2.0));

		mat2 scale = mat2((4.5 - layer / 4.0) * 2.0);

		return mat4(scale * rotate) * translate * SCALE_TRANSLATE;
	}
#endif

#if PARALLAX_MODE > 0
	flat in vec4 v_quadCoordMapping;
#endif


#ifdef VS_VELOCITY
	in vec3 v_velocity;
	#if defined PROGRAM_HAND && HAND_FOV_MODE != 1
		flat in float v_fovFactor;
	#endif
#endif


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif
#include "/Lib/IndividualFunctions/Parallax.glsl"
#include "/Lib/IndividualFunctions/Ripple.glsl"


void main(){
//TBN
	vec2 duv1 = dFdx(v_texCoord);
	vec2 duv2 = dFdy(v_texCoord);

	#if (!defined ENTITIES_VS_TBN || (!defined PROGRAM_ENTITIES && !defined PROGRAM_SPIDEREYES) || (MC_VERSION >= 11500 && MC_VERSION <= 11604)) && (!defined PROGRAM_HAND || MC_VERSION >= 11300)
		vec3 dp1 = dFdx(v_worldPos);
		vec3 dp2 = dFdy(v_worldPos);

		vec3 N = normalize(cross(dp1, dp2));
		vec3 dp2perp = cross(dp2, N);
		vec3 dp1perp = cross(N, dp1);
		vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
		vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
		float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
		mat3 tbnMat = mat3(T * invmax, B * invmax, N);
	#else
		mat3 tbnMat = v_tbn;

		if (!gl_FrontFacing) tbnMat[2] = -tbnMat[2];
/*
		if (v_materialIDs == 200.0){
			vec3 dp1 = dFdx(v_worldPos);
			vec3 dp2 = dFdy(v_worldPos);

			vec3 N = normalize(cross(dp1, dp2));
			vec3 dp2perp = cross(dp2, N);
			vec3 dp1perp = cross(N, dp1);
			vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
			vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
			float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
			tbnMat = mat3(T * invmax, B * invmax, N);
		}
*/
	#endif

	vec2 atlasSizeF = vec2(textureSize(tex, 0));
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


//parallax
	#ifdef DIMENSION_NETHER
		float parallaxShadow = 1.0;
		vec3 shadowVector = vec3(0.0);
	#else
		#ifdef DIMENSION_OVERWORLD
			vec3 shadowVector = shadowModelViewInverse2;
		#else
			vec3 shadowVector = shadowModelViewInverseEnd[2];
		#endif

		float parallaxShadow = saturate(dot(tbnMat[2], shadowVector) * 200.0);
	#endif


	#if defined ENTITIES_PARALLAX && PARALLAX_MODE > 0 && defined MC_NORMAL_MAP

		vec3 normalTex = vec3(0.0, 0.0, 1.0);
		vec2 parallaxCoord = ParallaxOcclusionMapping(v_texCoord, tbnMat, shadowVector, lod, normalTex, parallaxShadow);

		vec4 albedoTex = textureLod(tex, parallaxCoord, lod);

		#if defined PROGRAM_ENTITIES
			if (Radiance(v_color.rgb) < 0.002 || albedoTex.a + saturate(1.0 - abs(v_materialIDs - (MATID_ENTITIES_NODISCARD + 0.5))) < 0.004 || v_materialIDs > 255.0) discard;
		#elif defined PROGRAM_SPIDEREYES
			if (albedoTex.a < 0.1) discard; 
		#elif defined PROGRAM_BLOCK
			if (albedoTex.a < 0.004 && v_materialIDs != MATID_END_PORTAL) discard;
		#elif defined PROGRAM_HAND && defined DECREASE_HAND_GHOSTING
			if (albedoTex.a < 0.16) discard;
		#else
			if (albedoTex.a < 0.004) discard;
		#endif

		#ifdef MC_SPECULAR_MAP
			vec4 specularTex = textureLod(specular, parallaxCoord, lod);
		#else
			vec4 specularTex = vec4(0.0);
		#endif

	#else

		vec4 albedoTex = textureLod(tex, v_texCoord, lod);

		#if defined PROGRAM_ENTITIES
			if (Radiance(v_color.rgb) < 0.002 || albedoTex.a + saturate(1.0 - abs(v_materialIDs - (MATID_ENTITIES_NODISCARD + 0.5))) < 0.004 || v_materialIDs > 255.0) discard;
		#elif defined PROGRAM_SPIDEREYES
			if (albedoTex.a < 0.1) discard;
		#elif defined PROGRAM_HAND && defined DECREASE_HAND_GHOSTING
			if (albedoTex.a < 0.16) discard;
		#else
			if (albedoTex.a < 0.004) discard;
		#endif

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


//albedo
	vec4 albedo = vec4(albedoTex.rgb * v_color.rgb, albedoTex.a);

	#if WHITE_DEBUG_WORLD > 0
		albedo.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif


//wet effect
	#ifdef ENABLE_ROUGH_SPECULAR

		float NdotU = tbnMat[2].y;

		#if defined TEXTURE_PBR_POROSITY && TEXTURE_PBR_FORMAT < 2
			float porosity = saturate(specularTex.b * (255.0 / 63.0) - step(64.0 / 255.0, specularTex.b));
		#else
			float porosity = TEXTURE_DEFAULT_POROSITY;
		#endif

		#ifdef PROGRAM_HAND

			#ifdef DIMENSION_OVERWORLD
				#ifndef DISABLE_LOCAL_PRECIPITATION
					float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
				#else
					float wet = wetness + SURFACE_WETNESS;
				#endif
				wet *= 0.5;
				wet *= saturate(v_blockLight.y * 10.0 - 9.0);
				wet *= saturate(NdotU * 0.5 + 0.5);
			#else
				float wet = SURFACE_WETNESS;
				wet *= 0.5;
				wet *= saturate(NdotU * 0.5 + 0.5);
			#endif
			
		#else

			vec3 mcPos = v_worldPos + cameraPosition;

			#ifdef DIMENSION_OVERWORLD
				#ifndef DISABLE_LOCAL_PRECIPITATION
					float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
				#else
					float wet = wetness + SURFACE_WETNESS;
				#endif

				wet *= step(0.9, v_blockLight.y);

				vec2 rainNormal = vec2(0.0);
				if (wet > 1e-7){
					wet *= GetModulatedRainSpecular(mcPos);

					float lightMask = saturate(v_blockLight.y * 10.0 - 9.0);

					#if defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES
						//if (v_materialIDs == MATID_ENTITIES_SNOW){
							//#ifdef RAIN_SPLASH_EFFECT
							//	float splashStrength = saturate(NdotU * 2.0 - 1.0) * lightMask * (2.0 - porosity);
							//	if (splashStrength > 0.0) rainNormal = GetRainNormal(mcPos, splashStrength, wet);
							//#endif
						//}else{
							wet *= 0.5;
						//}
					//#else
						//#ifdef RAIN_SPLASH_EFFECT
						//	float splashStrength = saturate(NdotU * 2.0 - 1.0) * lightMask * (2.0 - porosity);
						//	if (splashStrength > 0.0) rainNormal = GetRainNormal(mcPos, splashStrength, wet);
						//#endif		
					#endif

					wet *= lightMask;
					wet *= saturate(NdotU * 0.5 + 0.5);
				}
			#else
				float wet = SURFACE_WETNESS;

				if (wet > 1e-7){
					wet *= float(abs(v_emissiveness - 0.99) > 0.005);
					wet *= GetModulatedRainSpecular(mcPos);
					#if defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES
						wet *= 0.5;
					#endif
					wet *= saturate(NdotU * 0.5 + 0.5);
				}
			#endif
			
		#endif

	#else
		float wet = 0.0;	
	#endif



//normal
	#if defined MC_NORMAL_MAP && defined ENABLE_ROUGH_SPECULAR
		normalTex = mix(normalize(normalTex), vec3(0.0, 0.0, 1.0), saturate(wet * (1.6 - porosity * 0.6)));
	#endif

	vec3 worldNormal = tbnMat * normalize(normalTex);

	//#if !defined PROGRAM_HAND && defined ENABLE_ROUGH_SPECULAR && defined DIMENSION_OVERWORLD && defined RAIN_SPLASH_EFFECT
	//	worldNormal = normalize(worldNormal + mat3(gbufferModelView) * vec3(rainNormal.x, 0.0, rainNormal.y));
	//#endif

	#if defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES
		#ifdef ENTITIES_NORMAL_CLAMP
			vec3 worldDir = -normalize(v_worldPos.xyz);
			worldNormal = normalize(worldNormal + tbnMat[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
		#endif
	#elif defined PROGRAM_BLOCK
		#ifdef TERRAIN_NORMAL_CLAMP
			vec3 worldDir = -normalize(v_worldPos);
			worldNormal = normalize(worldNormal + tbnMat[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
		#endif
	#elif defined PROGRAM_HAND
		#ifdef HAND_NORMAL_CLAMP
			vec3 worldDir = -normalize(v_worldPos);
			worldNormal = normalize(worldNormal + tbnMat[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
		#endif
	#endif


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

	#ifdef PROGRAM_ENTITIES
	#ifdef DISABLE_PLAYER_SPECULAR
		if(v_materialIDs == MATID_ENTITIES_PLAYER) specularTex = vec4(0.0);
	#endif
	#endif	


//hardcoded texture
/*（
	#ifdef PROGRAM_ENTITIES
		if (v_materialIDs == MATID_ENTITIES_SNOW){
			albedo.rgb = vec3(0.9690, 0.9965, 0.9965);
			worldNormal = tbnMat[2];
			specularTex = vec4(0.0, 0.0, 0.7, 0.0);
		}
	#endif
*/
	#ifdef PROGRAM_BLOCK
		if (v_materialIDs == MATID_END_PORTAL){
			vec3 portalColor = textureLod(tex, v_portalCoord.xy / v_portalCoord.w, 0.0).rgb * COLORS[0];
			for (int i = 0; i < 16; i++){
				vec4 coord = v_portalCoord * end_portal_layer(float(i + 1));
				portalColor += textureLod(tex, coord.xy / coord.w, 0.0).rgb * COLORS[i];
			}
			albedo = vec4(portalColor, 1.0);
			specularTex.rgb = vec3(1.0, 0.0, 254.0 / 255.0);
		}
	#endif

	//if (v_quadCoordMapping.x == 0.0) albedo.rgb = vec3(1.0, 0.0, 0.0);


	framebuffer0 = albedo;
	framebuffer5 = vec4(Pack2x8(specularTex.rg), Pack2x8(specularTex.ba), Pack2x8(vec2(parallaxShadow, v_materialIDs / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
	framebuffer6 = vec4(EncodeNormal(worldNormal), EncodeNormal(tbnMat[2]));

	#ifdef VS_VELOCITY
		#ifdef PROGRAM_HAND
			vec3 currViewPos = mat3(gbufferModelView) * v_worldPos + gbufferModelView[3].xyz;
			vec3 prevViewPos = currViewPos - v_velocity;

			vec3 projectionDiagonal = vec3(gbufferProjection[0][0], gbufferProjection[1][1], gbufferProjection[2][2]);
			vec3 projectionTrans = gbufferProjection[3].xyz;
			
			#if HAND_FOV_MODE == 1
				projectionDiagonal.z *= MC_HAND_DEPTH;
				projectionTrans.z *= MC_HAND_DEPTH;
				vec3 currScreenPos = (projectionDiagonal * currViewPos + projectionTrans) / -currViewPos.z * 0.5 + 0.5;

				vec3 prevProjectionDiagonal = vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]);
				vec3 prevProjectionTrans = gbufferProjection[3].xyz;
				prevProjectionDiagonal.z *= MC_HAND_DEPTH;
				prevProjectionTrans.z *= MC_HAND_DEPTH;
				vec3 prevScreenPos = (prevProjectionDiagonal * prevViewPos + prevProjectionTrans) / -prevViewPos.z * 0.5 + 0.5;
			#else
				projectionDiagonal.y = v_fovFactor;
				projectionDiagonal.x = projectionDiagonal.y / aspectRatio;
				projectionDiagonal.z *= MC_HAND_DEPTH;
				projectionTrans.z *= MC_HAND_DEPTH;

				vec3 currScreenPos = (projectionDiagonal * currViewPos + projectionTrans) / -currViewPos.z * 0.5 + 0.5;
				vec3 prevScreenPos = (projectionDiagonal * prevViewPos + projectionTrans) / -prevViewPos.z * 0.5 + 0.5;
			#endif
		#else
			vec3 prevScreenPos = vec3(0.0);

			if (v_materialIDs != 200.0){
				prevScreenPos = mat3(gbufferModelView) * v_worldPos + gbufferModelView[3].xyz - v_velocity;
				prevScreenPos = (vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]) * prevScreenPos + gbufferPreviousProjection[3].xyz) / -prevScreenPos.z * 0.5 + 0.5;
			}else{
				prevScreenPos = v_worldPos + cameraPositionToPrevious;
				prevScreenPos = mat3(gbufferPreviousModelView) * prevScreenPos + gbufferPreviousModelView[3].xyz;
				prevScreenPos = (vec3(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1], gbufferPreviousProjection[2][2]) * prevScreenPos + gbufferPreviousProjection[3].xyz) / -prevScreenPos.z * 0.5 + 0.5;
			}

			vec3 currScreenPos = vec3(gl_FragCoord.xy * pixelSize - taaJitter * 0.5, gl_FragCoord.z);
		#endif

		vec3 velocity = currScreenPos - prevScreenPos;
		#ifdef PROGRAM_BLOCK
			if (v_materialIDs == MATID_END_PORTAL) velocity = vec3(0.0);
		#endif

		framebuffer7 = vec4(velocity, 0.0);
	#endif
}
