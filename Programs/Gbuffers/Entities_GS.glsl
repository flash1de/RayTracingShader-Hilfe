//Terrain_GS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


in vec4 g_color[];
in vec2 g_texCoord[];
in vec3 g_worldPos[];
in vec2 g_blockLight[];
flat in float g_materialIDs[];
flat in float g_emissiveness[];

#if (defined ENTITIES_VS_TBN && (defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES) && (MC_VERSION < 11500 || MC_VERSION > 11604)) || (defined PROGRAM_HAND && MC_VERSION < 11300)
	in mat3 g_tbn[];
#endif

#ifdef PROGRAM_BLOCK
	in vec4 g_portalCoord[];
#endif

#if PARALLAX_MODE > 0
	in vec4 g_quadCoordMapping[];
	in float g_quadCoordX[];
#endif


out vec4 v_color;
out vec2 v_texCoord;
out vec3 v_worldPos;
out vec2 v_blockLight;
flat out float v_materialIDs;
flat out float v_emissiveness;

#if (defined ENTITIES_VS_TBN && (defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES) && (MC_VERSION < 11500 || MC_VERSION > 11604)) || (defined PROGRAM_HAND && MC_VERSION < 11300)
	out mat3 v_tbn;
#endif

#ifdef PROGRAM_BLOCK
	out vec4 v_portalCoord;
#endif

#if PARALLAX_MODE > 0
	flat out vec4 v_quadCoordMapping;
	flat out float v_quadCoordScale;
#endif


void main(){
	#if PARALLAX_MODE > 0
		v_quadCoordScale = max(max(
			abs(g_quadCoordX[0] - g_quadCoordX[1]) / distance(g_worldPos[0], g_worldPos[1]),
			abs(g_quadCoordX[1] - g_quadCoordX[2]) / distance(g_worldPos[1], g_worldPos[2])),
			abs(g_quadCoordX[2] - g_quadCoordX[0]) / distance(g_worldPos[2], g_worldPos[0])
		);

		v_quadCoordMapping = g_quadCoordMapping[0];

		if (abs(g_quadCoordMapping[0].x - g_quadCoordMapping[1].x) +
			abs(g_quadCoordMapping[1].x - g_quadCoordMapping[2].x) +
			abs(g_quadCoordMapping[0].y - g_quadCoordMapping[1].y) +
			abs(g_quadCoordMapping[1].y - g_quadCoordMapping[2].y)
			> 0.0
		) v_quadCoordMapping.x = 0.0;
	#endif


	for (int i = 0; i < 3; i++){
		gl_Position = gl_in[i].gl_Position;

		v_color = g_color[i];
		v_texCoord = g_texCoord[i];
		v_worldPos = g_worldPos[i];
		v_blockLight = g_blockLight[i];
		v_materialIDs = g_materialIDs[0];
		v_emissiveness = g_emissiveness[0];
		#if (defined ENTITIES_VS_TBN && (defined PROGRAM_ENTITIES || defined PROGRAM_SPIDEREYES) && (MC_VERSION < 11500 || MC_VERSION > 11604)) || (defined PROGRAM_HAND && MC_VERSION < 11300)
			v_tbn = g_tbn[i];
		#endif
		#ifdef PROGRAM_BLOCK
			v_portalCoord = g_portalCoord[i];
		#endif

		EmitVertex();
	}
	EndPrimitive();
}
