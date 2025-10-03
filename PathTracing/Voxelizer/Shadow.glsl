

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


//////////////////////////////////////////////////  Vertex Shader  /////////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Vertex Shader  /////////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Vertex Shader  /////////////////////////////////////////////////////////////
#ifdef PROGRAM_VSH


	uniform int blockEntityId;

	uniform vec3 cameraPositionFract;
	uniform mat4 shadowModelViewInverse;
	uniform mat4 shadowProjection;
	uniform mat4 shadowProjectionInverse;

	#ifdef DIMENSION_END
		const mat3 shadowModelViewInverseEnd = mat3(0.4523250774, -0.8087002661, -0.3760397683, 0.2486168185, 0.5192604694, -0.8176541093, 0.85649968, 0.2763556486, 0.4359310193);
		const mat3 shadowModelViewEnd = transpose(shadowModelViewInverseEnd);
	#else
		uniform vec3 shadowModelView0;
		uniform vec3 shadowModelView1;
		uniform vec3 shadowModelView2;
	#endif

	in vec4 mc_Entity;
	in vec4 at_midBlock;

	out vec3 g_color;
	out vec3 g_worldPos;
	out vec2 g_texcoord;
	#ifdef VANILLA_EMISSIVE
		out vec2 g_mcLightLevel;
	#else
		out float g_mcLightLevel;
	#endif

	out vec3 g_voxelCoord;
	out float g_notInVoxel;
	out float g_normalInvalid;

	flat out float g_voxelID;


	#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"

	#include "/Lib/RTWSM/SampleWarp.glsl"
	

	void main(){
		vec4 worldPos = shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

		g_worldPos = worldPos.xyz;

		#ifdef DIMENSION_END
			worldPos.xyz = shadowModelViewEnd * worldPos.xyz;
		#else
			worldPos.xyz = mat3(shadowModelView0, shadowModelView1, shadowModelView2) * worldPos.xyz;
		#endif
		gl_Position = worldPos;
		gl_Position.xyz *= vec3(shadowProjection[0][0], shadowProjection[0][0], -shadowProjection[0][0] * 0.5);

		//g_texcoord.zw = gl_Position.xy * 0.5 + 0.5;
		gl_Position.xy += SampleRTWWarpSmooth(gl_Position.xy * 0.5 + 0.5) * 2.0;
		
		g_color = gl_Color.rgb;
		g_texcoord.xy = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

		#ifdef VANILLA_EMISSIVE
			g_mcLightLevel = vec2(at_midBlock.w * at_midBlock.w * 0.00442222, saturate(float(gl_MultiTexCoord1.y - 8) / 232.0));
		#else
			g_mcLightLevel = saturate(float(gl_MultiTexCoord1.y - 8) / 232.0);
		#endif

		vec3 worldNormal = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);

		g_voxelID = mc_Entity.x;

		g_notInVoxel = step(399.5, g_voxelID);
		#ifndef PT_FULLBLOCK_DETECTION
			g_notInVoxel += step(g_voxelID, 0.5);
		#endif
		g_notInVoxel *= float(abs(g_voxelID - 8400.0) > 400.5);
		g_normalInvalid = step(maxVec3(abs(worldNormal)), 0.99);
		
		g_voxelCoord = vec3(-2.0);

		if (g_notInVoxel < 0.5){
/*
			#if defined PT_FULLBLOCK_VERIFICATION && defined PT_FULLBLOCK_DETECTION

				if (g_voxelID <= 0.0){
					vec3 vertexPos = gl_Vertex.xyz + cameraPositionFract;
					vertexPos = abs(vertexPos - round(vertexPos));
					float posInvalid = vertexPos.x + vertexPos.y + vertexPos.z;
					posInvalid = step(0.001, posInvalid);

					g_normalInvalid += posInvalid;
				}

			#elif !defined PT_FULLBLOCK_VERIFICATION && !defined PT_FULLBLOCK_DETECTION

				if (g_voxelID <= 1.0){
					vec3 vertexPos = gl_Vertex.xyz + cameraPositionFract;
					vertexPos = abs(vertexPos - round(vertexPos));
					float posInvalid = vertexPos.x + vertexPos.y + vertexPos.z;
					posInvalid = step(0.001, posInvalid);

					g_notInVoxel = posInvalid + g_normalInvalid;
				}

			#elif defined PT_FULLBLOCK_DETECTION

				if (g_voxelID <= 1.0){
					vec3 vertexPos = gl_Vertex.xyz + cameraPositionFract;
					vertexPos = abs(vertexPos - round(vertexPos));
					float posInvalid = vertexPos.x + vertexPos.y + vertexPos.z;
					posInvalid = step(0.001, posInvalid);

					if (g_voxelID <= 0.0){
						g_normalInvalid += posInvalid;
					}else{
						g_notInVoxel = posInvalid + g_normalInvalid;
					}		
				}

			#endif
*/

			if (g_voxelID <= 1.0){
				vec3 vertexPos = gl_Vertex.xyz + cameraPositionFract;
				vertexPos = abs(vertexPos - round(vertexPos));
				float posInvalid = vertexPos.x + vertexPos.y + vertexPos.z;
				posInvalid = step(0.001, posInvalid);

				#ifdef PT_FULLBLOCK_DETECTION
				if (g_voxelID <= 0.0){
					g_normalInvalid += posInvalid;
				}else
				#endif
				{
					g_notInVoxel = posInvalid + g_normalInvalid;
				}
			}

			g_voxelCoord = g_worldPos + cameraPositionFract + at_midBlock.xyz * 0.015625 + (voxelResolution * 0.5 - 0.5);
		}
	}


#endif	
//////////////////////////////////////////////////  Geometry Shader  ///////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Geometry Shader  ///////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Geometry Shader  ///////////////////////////////////////////////////////////
#ifdef PROGRAM_GSH


	#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"


	layout(triangles) in;
	#ifdef DIMENSION_NETHER
		layout(triangle_strip, max_vertices = 3) out;
	#else
		layout(triangle_strip, max_vertices = 6) out;
	#endif


	uniform mat4 shadowProjection;
	uniform ivec2 atlasSize;
	uniform int renderStage;


	in vec3 g_color[];
	in vec3 g_worldPos[];
	in vec2 g_texcoord[];
	#ifdef VANILLA_EMISSIVE
		in vec2 g_mcLightLevel[];
	#else
		in float g_mcLightLevel[];
	#endif

	in vec3 g_voxelCoord[];
	in float g_notInVoxel[];
	in float g_normalInvalid[];

	flat in float g_voxelID[];


	out vec3 v_color;
	out vec4 v_worldPos_voxelData_isWater_isVoxel;
	out vec2 v_texcoord_mcLightLevel;
	flat out vec2 v_midTexCoord;


	void main(){
		v_midTexCoord = vec2(0.0);
		
		vec3 posDiff = vec3(
			distance(g_worldPos[0], g_worldPos[1]),
			distance(g_worldPos[1], g_worldPos[2]),
			distance(g_worldPos[2], g_worldPos[0])
		);

		#ifndef DIMENSION_NETHER
			bool shadowVaild = all(lessThan(abs(gl_in[0].gl_Position.xy), vec2(1.0)));
			shadowVaild = shadowVaild || all(lessThan(abs(gl_in[1].gl_Position.xy), vec2(1.0)));
			shadowVaild = shadowVaild || all(lessThan(abs(gl_in[2].gl_Position.xy), vec2(1.0)));

			if (shadowVaild){
				float bias = saturate(maxVec3(posDiff) * 0.5 - 1.0) * shadowProjection[0][0] * 0.3;
				float isWater = float(g_voxelID[0] == 400.0) * 0.4;
				
				for (int i = 0; i < 3; i++) {
					gl_Position = gl_in[i].gl_Position;
					gl_Position.z += bias;
					ShiftShadowNdcPos(gl_Position.xy);

					v_color = g_color[i];
					v_worldPos_voxelData_isWater_isVoxel = vec4(g_worldPos[i], isWater);
					v_texcoord_mcLightLevel = g_texcoord[i];

					EmitVertex();
				}
				EndPrimitive();
			}
		#endif

		vec3 voxelCoord = round(g_voxelCoord[0] * 0.33333333 + g_voxelCoord[1] * 0.33333333 + g_voxelCoord[2] * 0.33333333);

		if (all(bvec3(
			clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 1.0)) == voxelCoord,
			g_notInVoxel[0] + g_notInVoxel[1] + g_notInVoxel[2] < 0.5,
			renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
		))){

			vec2 atlasResolution = vec2(atlasSize);

			vec2 maxTexCoord = max(g_texcoord[0].xy, max(g_texcoord[1].xy, g_texcoord[2].xy));
			vec2 minTexCoord = min(g_texcoord[0].xy, min(g_texcoord[1].xy, g_texcoord[2].xy));

			v_midTexCoord = (maxTexCoord + minTexCoord) * 0.5;
			vec2 coordSize = (maxTexCoord - minTexCoord) * atlasResolution;

			#if TEXTURE_RESOLUTION == 0
				float coordMaxSize = maxVec3(vec3(
					maxVec2(abs(g_texcoord[0].xy - g_texcoord[1].xy) * atlasResolution) / posDiff.x,
					maxVec2(abs(g_texcoord[1].xy - g_texcoord[2].xy) * atlasResolution) / posDiff.y,
					maxVec2(abs(g_texcoord[0].xy - g_texcoord[2].xy) * atlasResolution) / posDiff.z
				));

				float textureResolution = floor(coordMaxSize + 0.5);
			#else
				float textureResolution = TEXTURE_RESOLUTION;
			#endif

			float voxelID = g_voxelID[0];

			#ifdef VANILLA_EMISSIVE
				vec2 blockLight = vec2(g_mcLightLevel[0].x, g_mcLightLevel[0].y * 0.33333333 + g_mcLightLevel[1].y * 0.33333333 + g_mcLightLevel[2].y * 0.33333333);
			#else
				vec2 blockLight = vec2(0.0, g_mcLightLevel[0] * 0.33333333 + g_mcLightLevel[1] * 0.33333333 + g_mcLightLevel[2] * 0.33333333);
			#endif

			float zOffset = g_normalInvalid[0] + g_normalInvalid[1] + g_normalInvalid[2];

			#ifdef PT_FULLBLOCK_DETECTION
				if (voxelID > 0.0){
			#endif
				coordSize /= textureResolution;

				zOffset += saturate(coordSize.x * coordSize.y) * -0.2;

				bool isCutout = voxelID == 2.0;

				if (abs(voxelID - 8400.0) < 400.5){
					voxelID -= 8000.0;

					if (voxelID > 499.5){
						blockLight.x = saturate(voxelID * 0.01 - 5.0) * 0.995;
						voxelID = 1.0;		
					}

				}else{
					#ifdef VANILLA_EMISSIVE
						float hardcodedLight = 
							float(uint(voxelID == 2) | uint(abs(voxelID - 224.5) < 5.0)) * 0.995 +
							float(abs(voxelID - 223.0) < 1.5                           ) * 0.005 +
							float(abs(voxelID - 188.5) < 31.0                          ) * 0.5;
						if (hardcodedLight > 0.0) blockLight.x = hardcodedLight;
					#else
						blockLight.x = 
							float(uint(voxelID == 2) | uint(abs(voxelID - 224.5) < 5.0)) * 0.995 +
							float(abs(voxelID - 223.0) < 1.5                           ) * 0.005 +
							float(abs(voxelID - 188.5) < 31.0                          ) * 0.5;
					#endif
				}
				
				voxelID = bool(
					uint(voxelID == 2.0) |
					uint(voxelID == 51.0) |
					uint(voxelID == 55.0) |
					uint(abs(voxelID - 6.0) < 2.5) |
					uint(abs(voxelID - 188.5) < 31.0) |
					uint(abs(g_voxelID[0] - 8016.5) < 8.0)
				) 
				? 	1000.0 - voxelID
				: 	voxelID + 1000.0;


			#ifdef PT_FULLBLOCK_VERIFICATION
				if (voxelID == 1001.0){
					if (abs(posDiff.x + posDiff.y + posDiff.z - 3.41421356) > 0.001){
						voxelID = 65536.0;
						zOffset = -0.49;
					}
				}
			#endif

			#ifdef PT_FULLBLOCK_DETECTION
				}else{
					bool isFullBlock = abs(posDiff.x + posDiff.y + posDiff.z - 3.41421356) + zOffset < 0.001 && renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT;
					#ifdef PT_FULLBLOCK_DETECTION_ALPHA_TRACING
						voxelID = isFullBlock ? 999.0 : 65536.0;
					#else
						voxelID = isFullBlock ? 1001.0 : 65536.0;
					#endif
					zOffset = float(isFullBlock);
				}
			#endif


			vec2 voxelTexel = VoxelTexel_From_VoxelCoord(voxelCoord);
			const vec2[3] vertexOffset = vec2[3](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.5, 1.0));

			for (int i = 0; i < 3; i++){
				gl_Position = vec4((voxelTexel + vertexOffset[i]) * shadowPixelSize * 2.0 - 1.0, zOffset * 0.5 - 0.75, 1.0);

				v_color = g_color[i];
				v_worldPos_voxelData_isWater_isVoxel = vec4(voxelID, textureResolution, 0.0, 1.0);
				v_texcoord_mcLightLevel = blockLight;

				EmitVertex();
			}

			EndPrimitive();
		}
	}


#endif
//////////////////////////////////////////////////  Fragment Shader  ///////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Fragment Shader  ///////////////////////////////////////////////////////////
//////////////////////////////////////////////////  Fragment Shader  ///////////////////////////////////////////////////////////
#ifdef PROGRAM_FSH


	#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"


	layout(location = 0) out vec4 shadowbuffer0;
	layout(location = 1) out vec4 shadowbuffer1;


	uniform mat4 shadowModelViewInverse;
	uniform vec3 cameraPosition;
	uniform ivec2 atlasSize;
	uniform int isEyeInWater;
	uniform vec2 screenSize;
	uniform vec2 pixelSize;
	uniform int frameCounter;
	uniform int renderStage;
	
	uniform sampler2D tex;
	uniform sampler2D noisetex;
	uniform sampler2D pixelData2D;

	#include "/Lib/BasicFunctions/TemporalNoise.glsl"

	#include "/Lib/RTWSM/SampleWarp.glsl"


	in vec3 v_color;
	in vec4 v_worldPos_voxelData_isWater_isVoxel;
	in vec2 v_texcoord_mcLightLevel;
	flat in vec2 v_midTexCoord;


	vec2 GetWavesNormalFromTex(vec3 pos){
		const float maxCausticsNormalHeight = CAUSTICS_TEX_RESOLUTION;

		vec2 coord = pos.xz;

		#ifdef SHOW_TODO
		#error "caustics : shadowVectorRefracted"
		#endif

		//float k = 1.0 - (1.0 / (WATER_IOR * WATER_IOR)) * (1.0 - shadowModelViewInverse[2].y * shadowModelViewInverse[2].y);
		//vec3 shadowVectorRefracted = -shadowModelViewInverse[2].xyz * (1.0 / WATER_IOR);
		//shadowVectorRefracted.y -= (1.0 / WATER_IOR) * -shadowModelViewInverse[2].y + sqrt(k);

		//coord.x += pos.y * shadowVectorRefracted.x / shadowVectorRefracted.y;
		//coord.y += pos.y * shadowVectorRefracted.z / shadowVectorRefracted.y;

		coord = fract(coord * 0.02);
		coord = coord * vec2(511.0 / 512.0, 511.0 / 513.0) + vec2(0.5 / 512.0, 1.5 / 513.0);

		return textureLod(pixelData2D, coord, 0.0).xy;
	}

	float CalculateWaterCaustics(vec3 worldPos){
		vec2 dither = BlueNoiseTemporal() - 0.5;

		float caustics = 0.0;

		for (float i = -1.0; i <= 1.0; i++){
		for (float j = -1.0; j <= 1.0; j++){
			vec3 lookupPoint = worldPos;
			lookupPoint.xz +=  (dither + vec2(i, j)) * 0.12;

			vec2 wavesNormal = GetWavesNormalFromTex(lookupPoint);

			vec2 collisionPoint = lookupPoint.xz - wavesNormal * 3.0;
			collisionPoint -= worldPos.xz;

			float dist = fsqrt(dot(collisionPoint, collisionPoint));

			caustics += exp2(-dist * 50.0);
		}}

		return saturate(caustics * 0.7);
	}


	void main(){
		#ifndef DIMENSION_NETHER

		//gl_FragDepth = gl_FragCoord.z;

		if (v_worldPos_voxelData_isWater_isVoxel.w < 0.5){
			//vec3 shadowScreenCoord = gl_FragCoord.xyz;

			//vec2 pixelDiff = (gl_FragCoord.xy - vec2(voxelWidth, 0.0)) - (v_texcoord_mcLightLevel.zw + SampleRTWWarpSmooth(v_texcoord_mcLightLevel.zw)) * 2048.0;
			//float realDepth = gl_FragCoord.z + pixelDiff.x * dFdx(gl_FragCoord.z) + pixelDiff.y * dFdy(gl_FragCoord.z);
			//gl_FragDepth = realDepth;

			vec4 albedoTex = textureLod(tex, v_texcoord_mcLightLevel.xy, 0.0);
			
			if (clamp(gl_FragCoord.xy, vec2(voxelWidth, 0.0), vec2(shadowSize, shadowWidth)) != gl_FragCoord.xy
			 || albedoTex.a < 0.004) discard;

			albedoTex.rgb *= v_color;

			if (v_worldPos_voxelData_isWater_isVoxel.w > 0.2){
				vec3 mcPos = v_worldPos_voxelData_isWater_isVoxel.xyz + cameraPosition;
				float caustics = CalculateWaterCaustics(mcPos);

				float altitude = mcPos.y * 0.5 + 32.0;
				float p = floor(altitude);

				albedoTex = vec4(caustics, altitude - p, p / 255.0, 0.0);

			}else{
				albedoTex.a = albedoTex.a * 0.996 + 0.004;
			}

			shadowbuffer0 = vec4(albedoTex);
			shadowbuffer1 = vec4(0.0);
		}else
		
		#endif

		{
			shadowbuffer0 = vec4(v_color.rgb, v_texcoord_mcLightLevel.x);

			float skylight = saturate(SkyLightmapCurve(v_texcoord_mcLightLevel.y * 1.07));

			#if TEXTURE_RESOLUTION == 0
				float textureResolution = exp2(round(log2(v_worldPos_voxelData_isWater_isVoxel.y)));
			#else
				float textureResolution = TEXTURE_RESOLUTION;
			#endif
			vec2 atlasTiles = vec2(atlasSize) / textureResolution;
			textureResolution = saturate(log2(textureResolution) / 255.0);

			vec2 midCoord = (floor(v_midTexCoord * atlasTiles) + vec2(0.5)) / atlasTiles;

			float voxelID = v_worldPos_voxelData_isWater_isVoxel.x / 65535.0;
			
			shadowbuffer1 = vec4(midCoord, voxelID, Pack2x8(vec2(textureResolution, skylight)));
		}
	}


#endif
