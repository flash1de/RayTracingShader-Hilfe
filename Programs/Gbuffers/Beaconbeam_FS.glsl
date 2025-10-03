//Textured_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;

uniform sampler2D tex;
uniform sampler2D specular;
uniform sampler2D normals;


/* RENDERTARGETS: 0,5,6 */
layout(location = 0) out vec4 framebuffer0;
layout(location = 1) out vec4 framebuffer5;
layout(location = 2) out vec4 framebuffer6;


in vec4 v_color;
in vec2 v_texCoord;
in vec3 v_worldPos;
in vec2 v_blockLight;


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
	mat3 tbn = mat3(T * invmax, B * invmax, N);


//albedo
	vec4 albedo = textureLod(tex, v_texCoord, 0.0);
	albedo *= v_color;

	if (albedo.a < 0.9) discard;

	#if WHITE_DEBUG_WORLD > 0
		albedo.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif

//normal
	#ifdef MC_NORMAL_MAP
		vec3 normalTex = DecodeNormalTex(textureLod(normals, v_texCoord, 0.0).rgb);
	#else
		vec3 normalTex = vec3(0.0, 0.0, 1.0);
	#endif

	vec3 worldNormal = tbn * normalize(normalTex);

	#ifdef ENTITIES_NORMAL_CLAMP
		vec3 worldDir = -normalize(v_worldPos);
		worldNormal = normalize(worldNormal + tbn[2] * inversesqrt(saturate(dot(worldNormal, worldDir)) + 0.001));
	#endif

	vec4 normalEnc = vec4(EncodeNormal(worldNormal), EncodeNormal(tbn[2]));


//specular
	#ifdef MC_SPECULAR_MAP
		vec2 specularTex = textureLod(specular, v_texCoord, 0.0).ba;
		#if TEXTURE_PBR_FORMAT == 2
			specularTex.g = specularTex.r;
		#endif
	#else
		vec2 specularTex = vec2(0.0);
	#endif

	#if TEXTURE_EMISSIVENESS_MODE == 0
		specularTex.g = 0.5;
	#else
		#if TEXTURE_PBR_FORMAT < 2
			specularTex.g -= step(1.0, specularTex.g);
		#endif
		specularTex.g = max(specularTex.g, 0.5);
	#endif


	framebuffer0 = vec4(albedo.rgb, 1.0);
	framebuffer5 = vec4(0.0, Pack2x8(specularTex), Pack2x8(vec2(1.0, 1.0 / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
	framebuffer6 = normalEnc;
}
