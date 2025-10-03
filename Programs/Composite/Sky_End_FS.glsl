

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;



#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/IndividualFunctions/EndSky.glsl"


////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main(){
	float depth 					= texelFetch(depthtex1, texelCoord, 0).x;

	if (depth < 1.0) discard;

	vec3 viewPos 					= ViewPos_From_ScreenPos(texCoord, depth);

	vec3 worldPos					= mat3(gbufferModelViewInverse) * viewPos;

	vec3 viewDir 					= normalize(viewPos);
	vec3 worldDir 					= normalize(worldPos);


//////////////////// Sky ///////////////////////////////////////////////////////////////////////////
//////////////////// Sky ///////////////////////////////////////////////////////////////////////////

	vec3 color = vec3(0.0);

	BlackHole_AccretionDisc_Stars(color, worldDir, shadowModelViewInverseEnd[2]);

	PlanetEnd2(color, vec3(0.0), worldDir);

	framebuffer2 = vec4(max(color, vec3(0.0)), 0.0);

}
