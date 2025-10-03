//Water_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec2 taaJitter;

in vec4 mc_Entity;

out vec3 v_color;
out vec2 v_texCoord;
out vec3 v_worldPos;
out vec2 v_blockLight;
flat out float v_materialIDs;

#ifdef TERRAIN_VS_TBN
	in vec4 at_tangent;
	out mat3 v_tbn;
#endif


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

	#ifdef TERRAIN_VS_TBN
		vec3 N = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
		vec3 T = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * at_tangent.xyz);
		vec3 B = cross(T, N) * sign(at_tangent.w);
		v_tbn = mat3(T, B, N);
	#endif

	v_blockLight = vec2(float(abs(mc_Entity.x - 8016.5) < 8.0), saturate((gl_MultiTexCoord1.y - 8) / 232.0));

	v_materialIDs = mc_Entity.x == 400.0 ? MATID_WATER : MATID_STAINEDGLASS;
}
