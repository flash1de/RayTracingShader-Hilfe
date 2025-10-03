//Terrain_GS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


uniform ivec2 atlasSize;


in vec3 g_color[];
in vec2 g_texCoord[];
in vec3 g_worldPos[];
in vec2 g_blockLight[];
flat in float g_materialIDs[];
flat in float g_emissiveness[];
#ifdef TERRAIN_VS_TBN
	in mat3 g_tbn[];
#endif
#if PARALLAX_MODE > 0
	in float g_quadCoordX[];
	in vec4 g_quadCoordMapping[];
#endif

out vec3 v_color;
out vec2 v_texCoord;
out vec3 v_worldPos;
out vec2 v_blockLight;
flat out float v_materialIDs;
flat out float v_emissiveness;
#ifdef TERRAIN_VS_TBN
	out mat3 v_tbn;
#endif
#if PARALLAX_MODE > 0
	flat out vec4 v_quadCoordMapping;
	flat out float v_quadCoordScale;
#else
	flat out float v_textureResolution;
#endif


void main(){
	#if PARALLAX_MODE > 0
		v_quadCoordScale = max(max(
			abs(g_quadCoordX[0] - g_quadCoordX[1]) / distance(g_worldPos[0], g_worldPos[1]),
			abs(g_quadCoordX[1] - g_quadCoordX[2]) / distance(g_worldPos[1], g_worldPos[2])),
			abs(g_quadCoordX[2] - g_quadCoordX[0]) / distance(g_worldPos[2], g_worldPos[0]));

		v_quadCoordMapping = g_quadCoordMapping[0];

		if (abs(g_quadCoordMapping[0].x - g_quadCoordMapping[1].x) +
			abs(g_quadCoordMapping[1].x - g_quadCoordMapping[2].x) +
			abs(g_quadCoordMapping[2].x - g_quadCoordMapping[0].x) +
			abs(g_quadCoordMapping[0].y - g_quadCoordMapping[1].y) +
			abs(g_quadCoordMapping[1].y - g_quadCoordMapping[2].y) +
			abs(g_quadCoordMapping[2].y - g_quadCoordMapping[0].y)
			> 1e-21
		) v_quadCoordMapping.x = 0.0;

	#else
		#if TEXTURE_RESOLUTION == 0
			vec2 coordSize = max(max(abs(g_texCoord[0] - g_texCoord[1]) / distance(g_worldPos[0], g_worldPos[1]),
									 abs(g_texCoord[1] - g_texCoord[2]) / distance(g_worldPos[1], g_worldPos[2])),
									 abs(g_texCoord[2] - g_texCoord[0]) / distance(g_worldPos[2], g_worldPos[0]));

			v_textureResolution = floor(max(atlasSize.x * coordSize.x, atlasSize.y * coordSize.y) + 0.5);
			v_textureResolution = exp2(round(log2(v_textureResolution)));
		#else
			v_textureResolution = TEXTURE_RESOLUTION;
		#endif
	#endif


	for (int i = 0; i < 3; i++){
		gl_Position = gl_in[i].gl_Position;

		v_color = g_color[i];
		v_texCoord = g_texCoord[i];
		v_worldPos = g_worldPos[i];
		v_blockLight = g_blockLight[i];
		v_materialIDs = g_materialIDs[0];
		v_emissiveness = g_emissiveness[0];
		#ifdef TERRAIN_VS_TBN
			v_tbn = g_tbn[i];
		#endif

		EmitVertex();
	}
	EndPrimitive();
}
