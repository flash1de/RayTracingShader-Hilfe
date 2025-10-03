

#include "/Lib/Utilities.glsl"
#include "/Lib/UniformDeclare.glsl"


/* DRAWBUFFERS:1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/IndividualFunctions/DOF.glsl"


void main(){
	#ifdef DOF
		framebuffer1 = DepthOfField();
	#endif
}
