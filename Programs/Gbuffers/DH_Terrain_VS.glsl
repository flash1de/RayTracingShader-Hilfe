//DH_Terrain_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 dhProjection;
uniform vec2 taaJitter;


out vec3 v_color;
out vec3 v_worldPos;
out vec3 v_normal;
out vec2 v_blockLight;
flat out float v_materialIDs;
flat out float v_emissiveness;


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

	v_color = gl_Color.rgb;
	v_normal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
	vec2 lmcoord = vec2(gl_TextureMatrix[1][0][0] * gl_MultiTexCoord1.x, gl_TextureMatrix[1][1][1] * gl_MultiTexCoord1.y) + gl_TextureMatrix[1][3].xy;
	v_blockLight = saturate(lmcoord * 1.103449 - 0.0689656);

	v_materialIDs = MATID_LAND;
	v_emissiveness = 0.0;

	if (dhMaterialId == DH_BLOCK_LEAVES){
		v_materialIDs = MATID_LEAVES;
	}else if (dhMaterialId == DH_BLOCK_LAVA){
		v_materialIDs = MATID_LAND + 0.1;
		v_emissiveness = 1.0;
	}else if (dhMaterialId == DH_BLOCK_ILLUMINATED || v_blockLight.x > 0.93){
		v_emissiveness = 1.0;
	}
}