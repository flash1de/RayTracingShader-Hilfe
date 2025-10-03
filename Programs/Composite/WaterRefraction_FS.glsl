#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * UNIFORM_PIXEL_SIZE;


#ifdef DIMENSION_OVERWORLD
	in float cloudVisibility;
#endif

#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"


vec2 CubemapProjection(vec3 dir){
	const float tileSize = SKYBOX_RESOLUTION / 3.0;
	float tileSizeDivide = 0.5 * tileSize - 1.5;
	vec3 adir = abs(dir);

	vec2 texel;
	if (adir.x > adir.y && adir.x > adir.z){
		dir /= adir.x;
		texel.x = dir.y * tileSizeDivide + tileSize * 0.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.x) + 0.5);
	}else if (adir.y > adir.x && adir.y > adir.z){
		dir /= adir.y;
		texel.x = dir.x * tileSizeDivide + tileSize * 1.5;
		texel.y = dir.z * tileSizeDivide + tileSize * (step(0.0, dir.y) + 0.5);
	}else{
		dir /= adir.z;
		texel.x = dir.x * tileSizeDivide + tileSize * 2.5;
		texel.y = dir.y * tileSizeDivide + tileSize * (step(0.0, dir.z) + 0.5);
	}

	return texel * (1.0 / SKYBOX_RESOLUTION);
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main(){
	#ifdef SHOW_TODO
	#error "cp0 : sun and moon"
	#endif
	vec4 data1 = texelFetch(colortex1, texelCoord, 0);

	if (isEyeInWater == 1){
		float materialIDs = GetMaterialID(texelCoord);

		if (materialIDs == MATID_WATER){

			float depth = texelFetch(depthtex0, texelCoord, 0).x;
			float opaqueDepth = texelFetch(depthtex1, texelCoord, 0).x;

			vec3 worldPos = mat3(gbufferModelViewInverse) * ViewPos_From_ScreenPos(texCoord, depth);
			vec3 worldDir = normalize(worldPos);
			vec3 worldNormal = DecodeNormal(texelFetch(colortex6, texelCoord, 0).xy);

			vec3 refractedWorldDir = refract(worldDir, worldNormal, WATER_IOR);
			#ifdef DIMENSION_OVERWORLD
				if (opaqueDepth == 1.0){
					vec2 skyImageCoord = CubemapProjection(refractedWorldDir);
					data1.xyz = textureLod(colortex12, skyImageCoord, 0.0).rgb;
				}
			#endif
			if (length(refractedWorldDir) < 0.5){
				data1.xyz = vec3(0.0);
			}
		}
		#ifdef WATER_FOG
			else{
				float depth = texelFetch(depthtex1, texelCoord, 0).x;
				if (depth > 0.999999) data1.xyz = vec3(0.0);
			}
		#endif
	}
		
	framebuffer1 = data1;
}