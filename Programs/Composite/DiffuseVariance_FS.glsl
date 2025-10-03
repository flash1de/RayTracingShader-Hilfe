

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/PathTracing/Denoiser/DiffuseVarianceEstimation.glsl"


void main(){
	framebuffer1 = vec4(0.0);

	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

	if (depth < 1.0) framebuffer1 = DiffuseVarianceEstimation();
}
