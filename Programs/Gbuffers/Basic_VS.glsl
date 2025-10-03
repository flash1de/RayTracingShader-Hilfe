//Basic_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelViewInverse;

uniform vec2 taaJitter;

flat out vec4 v_color;
out vec2 v_texCoord;
out vec3 v_normal;
out vec2 v_blockLight;
flat out float v_isLine;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;

	#if FSR2_SCALE >= 0
		FsrScaleVS(gl_Position, taaJitter);
	#else
		#ifdef TAA
			gl_Position.xy = taaJitter * gl_Position.w + gl_Position.xy;
		#endif
	#endif

	v_color = gl_Color;
	v_texCoord =  mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	v_normal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;

	v_blockLight = saturate(vec2(gl_MultiTexCoord1.xy - 8) / 232.0);
	v_isLine = float(clamp(gl_MultiTexCoord1.xy, 0, 240) != gl_MultiTexCoord1.xy);
}
