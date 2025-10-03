

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#define SPATIAL_FILTER_ORDER 1
#include "/Lib/PathTracing/Denoiser/SpecularSpatialFilter.glsl"


void main(){
	vec4 reflection = texelFetch(colortex2, texelCoord, 0);
    if (reflection.a <= 0.0) discard;

	float depth = texelFetch(depthtex0, texelCoord, 0).x;
	framebuffer2 = SpecularSpatialFilter(reflection, depth);
}
