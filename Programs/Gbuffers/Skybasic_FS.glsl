//Skybasic_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 framebuffer0;


in vec4 v_color;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	framebuffer0 = v_color;
}

