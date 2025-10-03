//Line_FS


#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;


/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 framebuffer0;
layout(location = 1) out vec4 framebuffer5;


flat in vec4 v_color;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec4 albedo = v_color;

	if (albedo.a < 0.1) discard;

	if (albedo.a == 0.4)
		albedo.rgb = vec3(SELECTION_BOX_COLOR_R, SELECTION_BOX_COLOR_G, SELECTION_BOX_COLOR_B);

	framebuffer0 = vec4(albedo.rgb, 1.0);
	framebuffer5 = vec4(0.0, 0.0, Pack2x8(vec2(1.0, MATID_SELECTION / 255.0)), 0.0);
}
