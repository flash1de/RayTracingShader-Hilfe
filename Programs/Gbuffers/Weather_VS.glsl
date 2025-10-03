//Weather_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

uniform vec2 taaJitter;
uniform float eyeBrightnessOneSmooth;

out vec2 v_texCoord;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;;
	vec4 worldPos = gbufferModelViewInverse * viewPos;

	float angle = dot(worldPos.xyz + cameraPosition.xyz, vec3(3.0, 0.5, 3.0)) + frameTimeCounter * 0.2;
	vec2 rot = vec2(sin(angle), cos(angle));
	vec2 offset = (vec2(RAIN_WIND_X, RAIN_WIND_Z) + rot * RAIN_DISTURBANCE) * worldPos.y;

	worldPos.xz += eyeBrightnessOneSmooth * offset;

	gl_Position = gl_ProjectionMatrix * gbufferModelView * worldPos;

	#if FSR2_SCALE >= 0
		FsrScaleVS(gl_Position, vec2(0.0));
	#else

	#endif

	v_texCoord =  mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
}
