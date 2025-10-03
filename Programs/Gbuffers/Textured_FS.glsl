//Textured_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;

uniform sampler2D tex;


/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 framebuffer0;
layout(location = 1) out vec4 framebuffer5;


in vec4 v_color;
in vec2 v_texCoord;
in vec2 v_blockLight;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

//albedo
    vec4 albedo = texture(tex, v_texCoord);
    albedo *= v_color;

	if(albedo.a < 0.004) discard;

	#if WHITE_DEBUG_WORLD > 0
        albedo.rgb = vec3(1.0);
    #endif

//material ID
	float materialIDs = MATID_PARTICLE + float(v_blockLight.x > 0.999999);

	framebuffer0 = vec4(albedo.rgb, 1.0);
    framebuffer5 = vec4(Pack2x8(albedo.rg), Pack2x8(albedo.ba), Pack2x8(vec2(1.0, materialIDs / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
}
