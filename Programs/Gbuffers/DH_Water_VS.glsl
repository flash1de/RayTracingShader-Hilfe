//DH_Terrain_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 dhProjection;
uniform vec2 taaJitter;


out vec4 v_color;
out vec3 v_worldPos;
out mat3 v_tbn;
out float v_blockLight;
flat out float v_materialIDs;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	vec4 worldPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	v_worldPos = worldPos.xyz;
	gl_Position = dhProjection * gl_ModelViewMatrix * gl_Vertex;

	#if FSR2_SCALE >= 0
		FsrScaleVS(gl_Position, taaJitter);
	#else
		#ifdef TAA
			gl_Position.xy = taaJitter * gl_Position.w + gl_Position.xy;
		#endif
	#endif

	v_color = gl_Color;
	vec2 lmcoord = vec2(gl_TextureMatrix[1][0][0] * gl_MultiTexCoord1.x, gl_TextureMatrix[1][1][1] * gl_MultiTexCoord1.y) + gl_TextureMatrix[1][3].xy;
	v_blockLight = saturate(lmcoord.y * 1.103449 - 0.0689656);

	mat3 normalMat = mat3(gbufferModelViewInverse) * gl_NormalMatrix;
	vec3 T = vec3(0.0);
	vec3 B = vec3(0.0);
	vec3 N = normalize(normalMat * gl_Normal);

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		T = normalize(normalMat * vec3( 0.0,  0.0, -1.0));
		B = normalize(normalMat * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5){
		// -1.0,  0.0,  0.0
		T = normalize(normalMat * vec3( 0.0,  0.0,  1.0));
		B = normalize(normalMat * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5){
		//  0.0,  1.0,  0.0
		T = normalize(normalMat * vec3( 1.0,  0.0,  0.0));
		B = normalize(normalMat * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5){
		//  0.0, -1.0,  0.0
		T = normalize(normalMat * vec3( 1.0,  0.0,  0.0));
		B = normalize(normalMat * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5){
		//  0.0,  0.0,  1.0
		T = normalize(normalMat * vec3( 1.0,  0.0,  0.0));
		B = normalize(normalMat * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5){
		//  0.0,  0.0, -1.0
		T = normalize(normalMat * vec3(-1.0,  0.0,  0.0));
		B = normalize(normalMat * vec3( 0.0, -1.0,  0.0));
	}
	
	v_tbn = mat3(T, B, N);

	v_materialIDs = MATID_STAINEDGLASS;
	if (dhMaterialId == DH_BLOCK_WATER) v_materialIDs = MATID_WATER;
}