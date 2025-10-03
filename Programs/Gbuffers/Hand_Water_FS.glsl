//Hand_Water_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform float wetness;

uniform vec2 taaJitter;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;

uniform sampler2D tex;
uniform sampler2D normals;


/* RENDERTARGETS: 5,6 */
layout(location = 0) out vec4 framebuffer5;
layout(location = 1) out vec4 framebuffer6;


in vec3 v_color;
in vec2 v_texCoord;
in vec3 v_worldPos;
in float v_blockLight;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
//TBN
	vec2 duv1 = dFdx(v_texCoord);
	vec2 duv2 = dFdy(v_texCoord);
	
	vec3 dp1 = dFdx(v_worldPos);
	vec3 dp2 = dFdy(v_worldPos);

	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec3 N = normalize(cross(dp1, dp2));
	vec3 dp2perp = cross(dp2, N);
	vec3 dp1perp = cross(N, dp1);
	vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
	vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
	float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
	mat3 v_tbn = mat3(T * invmax, B * invmax, N);


//albedo
	vec4 albedo = textureGrad(tex, v_texCoord, duv1, duv2);
	albedo.rgb *= v_color;

	#if WHITE_DEBUG_WORLD > 0
		albedo.rgb = vec3(1.0);
	#endif


//wet effect
	#ifdef ENABLE_ROUGH_SPECULAR

		float NdotU = v_tbn[2].y;

		#ifdef DIMENSION_OVERWORLD
			#ifndef DISABLE_LOCAL_PRECIPITATION
				float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
			#else
				float wet = wetness + SURFACE_WETNESS;
			#endif
			wet *= 0.5;
			wet *= saturate(blockLight.y * 10.0 - 9.0);
			wet *= saturate(NdotU * 0.5 + 0.5);
		#else
			float wet = SURFACE_WETNESS;
			wet *= 0.5;
			wet *= saturate(NdotU * 0.5 + 0.5);
		#endif

	#else
		float wet = 0.0;
	#endif


//normal
	#ifdef MC_NORMAL_MAP
		vec3 normalTex = DecodeNormalTex(textureGrad(normals, v_texCoord, duv1, duv2).rgb);
		#ifdef ENABLE_ROUGH_SPECULAR 
			normalTex = mix(normalTex, vec3(0.0, 0.0, 1.0), saturate(wet * 1.5));
		#endif
	#else
		vec3 normalTex = vec3(0.0, 0.0, 1.0);
	#endif

	vec3 worldNormal = v_tbn * normalize(normalTex);

	#ifdef HAND_NORMAL_CLAMP
		vec3 worldDir = -normalize(v_worldPos);
		worldNormal = normalize(worldNormal + v_tbn[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
	#endif

	//framebuffer0 = vec4(albedo.rgb, 1.0);
	framebuffer5 = vec4(Pack2x8(albedo.rg), Pack2x8(albedo.ba), Pack2x8(vec2(1.0, MATID_STAINEDGLASS / 255.0)), Pack2x8(vec2(0.0, saturate(v_blockLight + 1e-6))));
	framebuffer6 = vec4(EncodeNormal(worldNormal), EncodeNormal(v_tbn[2]));}
