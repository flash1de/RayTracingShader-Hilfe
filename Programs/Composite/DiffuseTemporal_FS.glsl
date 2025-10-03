

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 8,9 */
layout(location = 0) out vec4 framebuffer8;
layout(location = 1) out vec4 framebuffer9;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/PathTracing/Denoiser/DiffuseTemporalFilter.glsl"


void main(){
	float depth = texelFetch(depthtex1, texelCoord, 0).x;

	#ifdef DISTANT_HORIZONS
		if (depth == 1.0) depth = -texelFetch(dhDepthTex0, texelCoord, 0).x;
	#endif

    if (abs(depth) == 1.0) discard;

	vec4 normalData = texelFetch(colortex6, texelCoord, 0);
	vec3 currColor = texelFetch(colortex1, texelCoord, 0).rgb;

	framebuffer8 = DiffuseTemporalFilter(depth, normalData, currColor);

	vec2 specularTex = Unpack2x8(texelFetch(colortex5, texelCoord, 0).x);
	float smoothness = specularTex.y > 229.5 / 255.0 ? -specularTex.x : specularTex.x;

	framebuffer9 = vec4(normalData.xy, depth, smoothness);
}
