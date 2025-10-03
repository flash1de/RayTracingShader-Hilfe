//Basic_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;


/* RENDERTARGETS: 0,5,6 */
layout(location = 0) out vec4 framebuffer0;
layout(location = 1) out vec4 framebuffer5;
layout(location = 2) out vec4 framebuffer6;


flat in vec4 v_color;
in vec2 v_texCoord;
in vec3 v_normal;
in vec2 v_blockLight;
flat in float v_isLine;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec4 albedo = v_color;

	vec2 mcLightmap = saturate(v_blockLight + 1e-6);

	float materialIDs = MATID_LAND;

	#if MC_VERSION >= 11605
		if (albedo.a < 0.1) discard;
	#else
		if (albedo.a <= 0.004) discard;
	#endif

	if (albedo.a == 0.4){
		albedo.rgb = vec3(SELECTION_BOX_COLOR_R, SELECTION_BOX_COLOR_G, SELECTION_BOX_COLOR_B);
		materialIDs = MATID_SELECTION;
		mcLightmap = vec2(0.0);
	}

	if (v_isLine > 0.5){
		materialIDs = MATID_SELECTION;
		mcLightmap = vec2(0.0);
	}

	vec2 normalEnc = EncodeNormal(v_normal);

	framebuffer0 = vec4(albedo.rgb, 1.0);
	framebuffer5 = vec4(0.0, 0.0, Pack2x8(vec2(1.0, materialIDs / 255.0)), Pack2x8(mcLightmap));
	framebuffer6 = vec4(normalEnc, normalEnc);
}
