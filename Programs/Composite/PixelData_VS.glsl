

#include "/Lib/Utilities.glsl"
#include "/Lib/UniformDeclare.glsl"


layout (rg16f) uniform image2D img_pixelData2D;

in vec3 vaPosition;


#include "/Lib/Uniform/GbufferTransforms.glsl"


float GetMaterialID(ivec2 coord){
	return float(uint(texelFetch(colortex5, coord, 0).b * 65535.0) & 255u);
}


void main(){
	#if defined FSR2 && defined FULLRES_BUFFER
		gl_Position = vec4(vaPosition.xy * 8.0 - vec2(6.5, 1.5), 0.0, 1.0);
	#else
		gl_Position = vec4(vaPosition.xy * 8.0 - vec2(6.5, 1.5), 0.0, 1.0);
	#endif
	
	if (gl_VertexID == 0){
		float worldTimeF = float(worldTime + isEyeInWater * 150);
		imageStore(img_pixelData2D, ivec2(PIXELDATA_WORLDTIME, 0), vec4(worldTimeF, 0.0, 0.0, 0.0));

		#if defined DOF && CAMERA_FOCUS_MODE == 0
			float prevCenterDepth = texelFetch(pixelData2D, ivec2(PIXELDATA_CENTER_DEPTH, 0), 0).x;
			
			prevCenterDepth = prevCenterDepth <= 0.0 ? 0.98 : ScreenDepth_From_LinearDepth(prevCenterDepth);

			float f = exp2(-frameTime * (10.0 / DOF_DEPTH_SMMOOTH_HALFLIFE));
			ivec2 centerTexelCoord = ivec2(UNIFORM_SCREEN_SIZE * 0.5);

			#ifdef DOF_FOCUS_IGNORE_HAND_PARTICLE
				float centerMaterialID = GetMaterialID(centerTexelCoord);
				if (centerMaterialID == MATID_PARTICLE) f = 1.0;

				float centerDepth = 0.0;
				if (heldItemId != 11000.0 && centerMaterialID == MATID_HAND){
					centerDepth = texelFetch(depthtex2, centerTexelCoord, 0).x;
				}else{
					centerDepth = texelFetch(depthtex0, centerTexelCoord, 0).x;
				}

			#else
				float centerDepth = texelFetch(depthtex0, centerTexelCoord, 0).x;

			#endif

			#ifdef DISTANT_HORIZONS
				if (centerDepth == 1.0){
					centerDepth = texelFetch(dhDepthTex0, centerTexelCoord, 0).x;
					centerDepth = ScreenDepth_From_DHScreenDepth(centerDepth);
				}
			#endif

			centerDepth = max(LinearDepth_From_ScreenDepth(mix(centerDepth, prevCenterDepth, f)), 0.3);

			imageStore(img_pixelData2D, ivec2(PIXELDATA_CENTER_DEPTH, 0), vec4(centerDepth, 0.0, 0.0, 0.0));
		#endif

	}
}