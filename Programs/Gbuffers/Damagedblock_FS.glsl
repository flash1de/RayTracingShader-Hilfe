//Damagedblock_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;

uniform sampler2D tex;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 framebuffer0;


in vec4 v_color;
in vec2 v_texCoord;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec4 albedo = texture(tex, v_texCoord);
	albedo *= v_color;

	if (albedo.a < 0.1) discard;

	#if WHITE_DEBUG_WORLD > 0
		albedo.rgb = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif

	framebuffer0 = vec4(albedo.rgb, 1.0);
}
