


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


layout (local_size_x = 16, local_size_y = 8) in;

layout (rgba16) uniform image2D colorimg2;


#ifdef PROGRAM_BLOOM_DOWNSAMPLE

	#if   PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 1
		const vec2 workGroupsRender = vec2(0.5, 0.5);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 2
		const vec2 workGroupsRender = vec2(0.252, 0.252);
	#endif

	shared uvec2 sampleColor[333];


	vec2 sampleCoord(int id, vec2 groupTexelOrigin){
		float row = float(id) / 35.0;
		float p = floor(row);
		float f = row - p;
		float rowOffset = saturate(f * 2e10 - 1e10);
		vec2 offset = vec2(
			f * 70.0 - rowOffset * 35.0,
			p * 2.0 + rowOffset
		);

		vec2 sampleCoord = groupTexelOrigin + offset;

		#if   PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 1
			sampleCoord = clamp(sampleCoord, vec2(1.5), screenSize - 1.5);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 2
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.5) - 0.5);
			sampleCoord.y += floor(screenSize.y * 0.5);
		#endif

		return sampleCoord * pixelSize;
	}

	void main(){
		vec2 groupTexelOrigin = vec2(gl_WorkGroupID.xy) * vec2(32.0, 16.0) - 1.0;
		int id = int(gl_LocalInvocationIndex);

		vec3 sampleData = textureLod(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0.0).rgb;
		sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		id += 128;

		sampleData = textureLod(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0.0).rgb;
		sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		id += 128;
		
		if(id < 333){
			sampleData = textureLod(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0.0).rgb;
			sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		}
		
		barrier();

		int wid = int(gl_LocalInvocationID.x + gl_LocalInvocationID.y * 35u);

		uvec2 writeData = sampleColor[wid];
		vec3 blur = vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.03125;
		writeData = sampleColor[wid + 1];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.03125;
		writeData = sampleColor[wid + 18];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 19];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 35];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 36];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.03125;
		writeData = sampleColor[wid + 37];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 53];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 54];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 70];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.03125;
		writeData = sampleColor[wid + 71];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 72];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.03125;

		ivec2 drawTexel = ivec2(gl_GlobalInvocationID.xy);

		#if   PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 1			
			if (all(lessThan(drawTexel, ivec2(screenSize * 0.5)))){
				drawTexel.y += int(screenSize.y * 0.5);

				#ifdef DIMENSION_END
					#if BLOOM_CLAMP_STRENGTH > 1
						float exposure = texelFetch(pixelData2D, ivec2(PIXELDATA_EXPOSURE, 0), 0).x;
						exposure = pow(exposure, 0.85);

						exposure = exposure * 15.0 + 5e-5;
					
						float lumiance = length(blur) + 1e-13;
						blur /= lumiance;
						lumiance = min(lumiance / exposure, 1.5);
						if (lumiance > 0.5){
							lumiance = lumiance - 1.5;
							lumiance = 1.0 - lumiance * lumiance * 0.5;
						}
						blur *= lumiance * exposure;
					#endif
				#else				
					#if BLOOM_CLAMP_STRENGTH > 0
						float exposure = texelFetch(pixelData2D, ivec2(PIXELDATA_EXPOSURE, 0), 0).x;
						exposure = pow(exposure, 0.85);

						#if BLOOM_CLAMP_STRENGTH == 1
							exposure = exposure * 21.0 + 5e-5;
						#else
							exposure = exposure * 7.0 + 5e-5;
						#endif
						
						float lumiance = length(blur) + 1e-13;
						blur /= lumiance;
						lumiance = min(lumiance / exposure, 1.5);
						if (lumiance > 0.5){
							lumiance = lumiance - 1.5;
							lumiance = 1.0 - lumiance * lumiance * 0.5;
						}
						blur *= lumiance * exposure;
					#endif
				#endif

				imageStore(colorimg2, drawTexel, vec4(blur, 0.0));
			}
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 2
			imageStore(colorimg2, drawTexel, vec4(blur, 0.0));
		#endif
		
	}

#endif


#define BLOOM_SIZE_LOD3 0.16
#define BLOOM_SIZE_LOD4 0.035
#define BLOOM_SIZE_LOD5 0.0085
#define BLOOM_SIZE_LOD6 0.002
#define BLOOM_SIZE_LOD7 0.0005
#define BLOOM_SIZE_LOD8 0.00015

#define BLOOM_STEP_LOD3 2.0
#define BLOOM_STEP_LOD4 5.0
#define BLOOM_STEP_LOD5 12.0
#define BLOOM_STEP_LOD6 28.0
#define BLOOM_STEP_LOD7 50.0
#define BLOOM_STEP_LOD8 90.0


#ifdef PROGRAM_BLOOM_AXIALBLUR_X

	const vec2 workGroupsRender = vec2(0.35, 0.252);



	vec3 AxialGaussianBlurX(sampler2D texSampler, vec2 coord, float coordScale, vec2 sampleSize, const float alpha, const float steps){
		vec3 blur = vec3(0.0);
		float weights = 0.0;

		for (float i = -steps; i <= steps; i++){
			float sampleWeight = exp2(-i * i * alpha * 5.77);

			vec2 sampleCoord = coord;
			sampleCoord.x += 2.0 / coordScale * pixelSize.x * i;

			vec2 tCoord = sampleCoord;
			sampleCoord = clamp(sampleCoord, vec2(0.0), sampleSize);

			sampleWeight *= float(tCoord == sampleCoord) + 1e-20;

			sampleCoord.x *= coordScale;

			blur += textureLod(texSampler, sampleCoord, 0.0).rgb * sampleWeight;
			weights += sampleWeight;
		}

		return blur / weights;
	}


	void main(){
		vec2 originSize = vec2(0.25);
		vec2 borderWidth = pixelSize;
		const float intervalWidth = 3.0;
		vec2 border = originSize + borderWidth;

		vec2 axis = vec2(1.0, 0.0);
		vec3 blur = vec3(0.0);

		ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
		texelCoord.x += int(screenSize.x * 0.25);
		texelCoord.y -= 1;
		vec2 coord = (vec2(texelCoord) + 0.5) * pixelSize;

		bool draw = false;


	// Lod 3
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 2.0, originSize, BLOOM_SIZE_LOD3, BLOOM_STEP_LOD3);
			draw = true;
		}

	// Lod 4
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 4.0, originSize, BLOOM_SIZE_LOD4, BLOOM_STEP_LOD4);
			draw = true;
		}

	// Lod 5
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 8.0, originSize, BLOOM_SIZE_LOD5, BLOOM_STEP_LOD5);
			draw = true;
		}

	// Lod 6
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 16.0, originSize, BLOOM_SIZE_LOD6, BLOOM_STEP_LOD6);
			draw = true;
		}

	// Lod 7
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 32.0, originSize, BLOOM_SIZE_LOD7, BLOOM_STEP_LOD7);
			draw = true;
		}

	// Lod 8
		coord.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize.x *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurX(colortex2, coord, 64.0, originSize, BLOOM_SIZE_LOD8, BLOOM_STEP_LOD8);
			draw = true;
		}
		barrier();


		if (draw){
			texelCoord.y += int(screenSize.y * 0.5) + 1;
			imageStore(colorimg2, texelCoord, vec4(blur, 0.0));
		}
	}

#endif





#ifdef PROGRAM_BLOOM_AXIALBLUR_Y

	const vec2 workGroupsRender = vec2(0.35, 0.25);


	vec3 AxialGaussianBlurY(sampler2D texSampler, vec2 coord, float coordScale, float coordOffset, float sampleOrigin, vec2 sampleSize, const float alpha, const float steps){
		vec3 blur = vec3(0.0);
		float weights = 0.0;

		for (float i = -steps; i <= steps; i++){
			float sampleWeight = exp2(-i * i * alpha * 5.77);

			vec2 sampleCoord = coord;
			sampleCoord.y += 2.0 / coordScale * pixelSize.y * i;

			vec2 tCoord = sampleCoord;
			sampleCoord = clamp(sampleCoord, vec2(sampleOrigin, 0.0), vec2(sampleOrigin + sampleSize.x, sampleSize.y));

			sampleWeight *= float(tCoord == sampleCoord) + 1e-20;

			sampleCoord.y = sampleCoord.y * coordScale + coordOffset;

			blur += textureLod(texSampler, sampleCoord, 0.0).rgb * sampleWeight;
			weights += sampleWeight;
		}

		return blur / weights;
	}


	void main(){
		vec2 originSize = vec2(0.25);
		vec2 borderWidth = pixelSize;
		const float intervalWidth = 3.0;
		vec2 border = originSize + borderWidth;

		vec2 axis = vec2(0.0, 1.0);
		vec3 blur = vec3(0.0);

		ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
		texelCoord.x += int(screenSize.x * 0.25);
		vec2 texCoord = (vec2(texelCoord) + 0.5) * pixelSize;

		float coordOffset = (floor(screenSize.y * 0.5) + 1.0) * pixelSize.y;

		vec2 coord = texCoord;

		float currInterval = 0.0;
		float sampleOrigin = 0.0;

	// Lod 3
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 2.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD3, BLOOM_STEP_LOD3);
		}

	// Lod 4
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 4.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD4, BLOOM_STEP_LOD4);
		}

	// Lod 5
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 8.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD5, BLOOM_STEP_LOD5);
		}

	// Lod 6
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 16.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD6, BLOOM_STEP_LOD6);
		}

	// Lod 7
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 32.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD7, BLOOM_STEP_LOD7);
		}

	// Lod 8
		currInterval = originSize.x + pixelSize.x * intervalWidth;
		coord.x -= currInterval;
		sampleOrigin += currInterval;
		originSize *= 0.5;
		border = originSize + borderWidth;

		if (coord.x >= -borderWidth.x && coord.x <= border.x && coord.y <= border.y){
			blur = AxialGaussianBlurY(colortex2, texCoord, 64.0, coordOffset, sampleOrigin, originSize, BLOOM_SIZE_LOD8, BLOOM_STEP_LOD8);
		}

		imageStore(colorimg2, texelCoord, vec4(blur, 0.0));
	}

#endif