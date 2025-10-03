//Weather_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform sampler2D tex;


uniform vec2 taaJitter;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 framebuffer0;


in vec2 v_texCoord;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec4 albedo = texture(tex, v_texCoord);

	if(albedo.a < 0.1) discard;

	framebuffer0 = vec4(0.0, 0.0, 0.0, albedo.a);
}
