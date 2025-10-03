//Line_FS


#include "/Lib/Utilities.glsl"


uniform vec2 taaJitter;

uniform sampler2D depthtex0;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 framebuffer0;

layout(rgba8) uniform image2D colorimg0;
layout(rgba16) uniform image2D colorimg5;


flat in vec4 v_color;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	vec4 albedo = v_color;

	if(albedo.a > 0.1 && gl_FragCoord.z < texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x){
		if (albedo.a == 0.4)
			albedo.rgb = vec3(SELECTION_BOX_COLOR_R, SELECTION_BOX_COLOR_G, SELECTION_BOX_COLOR_B);

		imageStore(colorimg0, ivec2(gl_FragCoord.xy), vec4(albedo.rgb, 1.0));
		imageStore(colorimg5, ivec2(gl_FragCoord.xy), vec4(0.0, 0.0, MATID_SELECTION / 255.0, 0.0));
	}

	discard;

	framebuffer0 = vec4(0.0);
}
