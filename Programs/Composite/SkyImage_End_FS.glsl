

#define END_PLANET_WEAK_DIFFUSE


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 12 */
layout(location = 0) out vec4 framebuffer12;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;


#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/BasicFunctions/TemporalNoise.glsl"

#include "/Lib/IndividualFunctions/EndSky.glsl"


vec3 CubemapProjectionInverse(vec2 texel){
	const float tileSize = SKYBOX_RESOLUTION / 3.0;
	float tileSizeDivide = 1.0 / (0.5 * tileSize - 1.5);

	vec3 dir = vec3(0.0);

	if (texel.x < tileSize) {
		dir.x = step(tileSize, texel.y) * 2.0 - 1.0;
		dir.y = (texel.x - tileSize * 0.5) * tileSizeDivide;
		dir.z = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
	} else if (texel.x < 2.0 * tileSize) {
		dir.x = (texel.x - tileSize * 1.5) * tileSizeDivide;
		dir.y = step(tileSize, texel.y) * 2.0 - 1.0;
		dir.z = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
	} else {
		dir.x = (texel.x - tileSize * 2.5) * tileSizeDivide;
		dir.y = (texel.y - tileSize * (step(tileSize, texel.y) + 0.5)) * tileSizeDivide;
		dir.z = step(tileSize, texel.y) * 2.0 - 1.0;
	}

	return normalize(dir);
}

////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main(){
	float depth 					= texelFetch(depthtex1, texelCoord, 0).x;
	vec3 viewPos 					= ViewPos_From_ScreenPos(texCoord, depth);

	vec3 worldPos					= mat3(gbufferModelViewInverse) * viewPos;

	vec3 viewDir 					= normalize(viewPos);
	vec3 worldDir 					= normalize(worldPos);

//////////////////// Sky Image /////////////////////////////////////////////////////////////////////
//////////////////// Sky Image /////////////////////////////////////////////////////////////////////

	vec3 skyImage = vec3(0.0);

	vec3 viewVector = CubemapProjectionInverse(gl_FragCoord.xy);

	PlanetEnd2(skyImage, vec3(0.0), viewVector);

	EndFog(skyImage, 1024.0, viewVector, shadowModelViewInverseEnd[2]);

	framebuffer12 = vec4(skyImage, 0.0);
}
