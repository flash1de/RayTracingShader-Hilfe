//Hand_Water_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec2 taaJitter;

in vec4 mc_Entity;

out vec3 v_color;
out vec2 v_texCoord;
out vec3 v_worldPos;
out float v_blockLight;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	vec4 worldPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	v_worldPos = worldPos.xyz;
	gl_Position = gl_ProjectionMatrix * gbufferModelView * worldPos;

	#if FSR2_SCALE >= 0
		FsrScaleVS(gl_Position, taaJitter);
	#else
		#ifdef TAA
			gl_Position.xy = taaJitter * gl_Position.w + gl_Position.xy;
		#endif
	#endif

	v_color = gl_Color.rgb;
	v_texCoord = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

	v_blockLight = saturate(float(gl_MultiTexCoord1.y - 8) / 232.0);
}