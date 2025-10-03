

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#define SPATIAL_FILTER_ORDER 1
#include "/Lib/PathTracing/Denoiser/DiffuseSpatialFilter.glsl"


void main(){
	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = -texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

    if (abs(depth) == 1.0) discard;
		
	framebuffer1 = DiffuseSpatialFilter(depth);
}
