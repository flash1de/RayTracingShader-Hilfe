

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 10 */
layout(location = 0) out vec4 framebuffer10;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/PathTracing/Denoiser/SpecularTemporalFilter.glsl"


void main(){
	float depth = texelFetch(depthtex0, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = -texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

	if (abs(depth) == 1.0) discard;

	vec4 currData = texelFetch(colortex2, texelCoord, 0);
	if (currData.a <= 0.0){
		framebuffer10 = currData;
	}else{
		framebuffer10 = SpecularTemporalFilter(currData);
	}
}
