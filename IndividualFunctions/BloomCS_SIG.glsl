


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


//NEXT GENERATION POST PROCESSING IN CALL OF DUTY: ADVANCED WARFARE. SIGGRAPH 2014.


#ifdef PROGRAM_BLOOM_DOWNSAMPLE

	#if   PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 1
		const vec2 workGroupsRender = vec2(0.5, 0.5);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 2
		const vec2 workGroupsRender = vec2(0.25, 0.25);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 3
		const vec2 workGroupsRender = vec2(0.125, 0.125);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 4
		const vec2 workGroupsRender = vec2(0.0625, 0.0625);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 5
		const vec2 workGroupsRender = vec2(0.03125, 0.03125);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 6
		const vec2 workGroupsRender = vec2(0.015625, 0.015625);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 7
		const vec2 workGroupsRender = vec2(0.0078125, 0.0078125);
	#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 8
		const vec2 workGroupsRender = vec2(0.00390625, 0.00390625);
	#endif

	layout (local_size_x = 16, local_size_y = 8) in;

	layout (rgba16) uniform image2D colorimg2;

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
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 3
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.25) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.5);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 4
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.125) - 0.5);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 5
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.0625) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.125);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 6
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.03125) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.1875);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 7
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.015625) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.21875);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 8
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.0078125) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.234375);
		#endif

		#if PROGRAM_BLOOM_DOWNSAMPLE_LEVEL > 3
			sampleCoord.y += floor(screenSize.y * 0.5);
		#endif

		return sampleCoord * pixelSize;
	}

	void main(){
		vec2 groupTexelOrigin = vec2(gl_WorkGroupID.xy) * vec2(32.0, 16.0) - 0.5;
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

		ivec2 drawCoord = ivec2(gl_GlobalInvocationID.xy);

		#if   PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 1			
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.5)))){
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 2
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.25)))){
				drawCoord.x += int(screenSize.x * 0.5);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 3
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.125)))){
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 4
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0625)))){
				drawCoord.x += int(screenSize.x * 0.125);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 5
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.03125)))){
				drawCoord.x += int(screenSize.x * 0.1875);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 6
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.015625)))){
				drawCoord.x += int(screenSize.x * 0.21875);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 7
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0078125)))){
				drawCoord.x += int(screenSize.x * 0.234375);
		#elif PROGRAM_BLOOM_DOWNSAMPLE_LEVEL == 8
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.00390625)))){
				drawCoord.x += int(screenSize.x * 0.2421875);
		#endif

		#if PROGRAM_BLOOM_DOWNSAMPLE_LEVEL > 2
			drawCoord.y += int(screenSize.y * 0.5);
		#endif

			imageStore(colorimg2, drawCoord, vec4(blur, 0.0));
		}
	}
#endif




























/*
#ifdef PROGRAM_BLOOM_UPSAMPLE


	#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
		const vec2 workGroupsRender = vec2(0.0078125, 0.0078125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
		const vec2 workGroupsRender = vec2(0.015625, 0.015625);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
		const vec2 workGroupsRender = vec2(0.03125, 0.03125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
		const vec2 workGroupsRender = vec2(0.0625, 0.0625);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
		const vec2 workGroupsRender = vec2(0.125, 0.125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
		const vec2 workGroupsRender = vec2(0.25, 0.25);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
		const vec2 workGroupsRender = vec2(0.5, 0.5);
	#endif


	layout (local_size_x = 16, local_size_y = 8) in;

	layout (rgba16) uniform image2D colorimg2;

	shared uvec2 sampleColor[96];


	ivec2 sampleCoord(int id, vec2 groupTexelOrigin){
		float row = float(id) / 12.0;
		float p = floor(row);
		float f = row - p;
		vec2 offset = vec2(f * 12.0, p);

		ivec2 sampleCoord = ivec2(groupTexelOrigin + offset);

		#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.00390625) - 1);
			sampleCoord.x += int(screenSize.x * 0.2421875);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.0078125) - 1);
			sampleCoord.x += int(screenSize.x * 0.234375);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.015625) - 1);
			sampleCoord.x += int(screenSize.x * 0.21875);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.03125) - 1);
			sampleCoord.x += int(screenSize.x * 0.1875);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.0625) - 1);
			sampleCoord.x += int(screenSize.x * 0.125);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.125) - 1);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			sampleCoord = clamp(sampleCoord, ivec2(0), ivec2(screenSize * 0.25) - 1);
			sampleCoord.x += int(screenSize.x * 0.5);
		#endif

		#if PROGRAM_BLOOM_UPSAMPLE_LEVEL > 1
			sampleCoord.y += int(screenSize.y * 0.5);
		#endif

		return sampleCoord;
	}

	void main(){
		vec2 groupTexelOrigin = vec2(gl_WorkGroupID.xy) * vec2(8.0, 4.0) - 2.0;
		int id = int(gl_LocalInvocationIndex);

		if(id < 96){
			vec3 sampleData = texelFetch(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0).rgb;
			sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		}
		
		barrier();

		int wid = int((gl_LocalInvocationID.x >> 1u) + (gl_LocalInvocationID.y >> 1u) * 12u);
		int pid = int((gl_LocalInvocationID.x & 1u) + (gl_LocalInvocationID.y & 1u) * 2u);
		ivec2 sd;

		if (pid == 0){
			wid += 39;
			sd = ivec2(-1, -1);
		}else if (pid == 1){
			wid += 37;
			sd = ivec2(1, -1);
		}else if (pid == 2){
			wid += 15;
			sd = ivec2(-1, 1);
		}else if (pid == 3){
			wid += 13;
			sd = ivec2(1, 1);
		}

		uvec2 writeData = sampleColor[wid];
		vec3 blur = vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.00494;
		writeData = sampleColor[wid + sd.x * 1];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.04303;
		writeData = sampleColor[wid + sd.x * 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.02216;
		writeData = sampleColor[wid + sd.x * 3];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 1.831e-4;

		writeData = sampleColor[wid + sd.y * 12];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.04303;
		writeData = sampleColor[wid + sd.y * 12 + sd.x * 1];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.37452;
		writeData = sampleColor[wid + sd.y * 12 + sd.x * 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.19284;
		writeData = sampleColor[wid + sd.y * 12 + sd.x * 3];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.001594;

		writeData = sampleColor[wid + sd.y * 24];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.02216;
		writeData = sampleColor[wid + sd.y * 24 + sd.x * 1];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.19284;
		writeData = sampleColor[wid + sd.y * 24 + sd.x * 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.09929;
		writeData = sampleColor[wid + sd.y * 24 + sd.x * 3];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 8.206e-4;

		writeData = sampleColor[wid + sd.y * 36];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 1.831e-4;
		writeData = sampleColor[wid + sd.y * 36 + sd.x * 1];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.001594;
		writeData = sampleColor[wid + sd.y * 36 + sd.x * 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 8.206e-4;
		writeData = sampleColor[wid + sd.y * 36 + sd.x * 3];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 6.781e-6;


		ivec2 drawCoord = ivec2(gl_GlobalInvocationID.xy);

		#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0078125)))){
				drawCoord.x += int(screenSize.x * 0.234375);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.015625)))){
				drawCoord.x += int(screenSize.x * 0.21875);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.03125)))){
				drawCoord.x += int(screenSize.x * 0.1875);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0625)))){
				drawCoord.x += int(screenSize.x * 0.125);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.125)))){
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.25)))){
				drawCoord.x += int(screenSize.x * 0.5);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.5)))){
		#endif

		#if PROGRAM_BLOOM_UPSAMPLE_LEVEL > 2
			drawCoord.y += int(screenSize.y * 0.5);
		#endif

		
			blur = blur + texelFetch(colortex2, drawCoord, 0).rgb;

			#if PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			blur *= 1.0 / 7.0;
			#endif
			
			imageStore(colorimg2, drawCoord, vec4(blur, 0.0));
		}
	}
#endif


#ifdef PROGRAM_BLOOM_UPSAMPLE


	#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
		const vec2 workGroupsRender = vec2(0.0078125, 0.0078125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
		const vec2 workGroupsRender = vec2(0.015625, 0.015625);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
		const vec2 workGroupsRender = vec2(0.03125, 0.03125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
		const vec2 workGroupsRender = vec2(0.0625, 0.0625);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
		const vec2 workGroupsRender = vec2(0.125, 0.125);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
		const vec2 workGroupsRender = vec2(0.25, 0.25);
	#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
		const vec2 workGroupsRender = vec2(0.5, 0.5);
	#endif


	layout (local_size_x = 16, local_size_y = 8) in;

	layout (rgba16) uniform image2D colorimg2;

	shared uvec2 sampleColor[240];


	vec2 sampleCoord(int id, vec2 groupTexelOrigin){
		float row = float(id) / 20.0;
		float p = floor(row);
		float f = row - p;
		vec2 offset = vec2(
			f * 10.0,
			p * 0.5
		);

		vec2 sampleCoord = groupTexelOrigin + offset;

		#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.00390625) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.2421875) + 5.0;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.0078125) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.234375) + 4.0;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.015625) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.21875) + 3.0;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.03125) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.1875) + 2.0;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.0625) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.125) + 1.0;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.125) - 0.5);
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			sampleCoord = clamp(sampleCoord, vec2(0.5), floor(screenSize * 0.25) - 0.5);
			sampleCoord.x += floor(screenSize.x * 0.5) + 1.0;
		#endif

		#if PROGRAM_BLOOM_UPSAMPLE_LEVEL > 1
			sampleCoord.y += floor(screenSize.y * 0.5) + 1.0;
		#endif

		return sampleCoord * pixelSize;
	}

	void main(){
		vec2 groupTexelOrigin = vec2(gl_WorkGroupID.xy) * vec2(8.0, 4.0) - 1.0;
		int id = int(gl_LocalInvocationIndex);

		vec3 sampleData = textureLod(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0.0).rgb;
		sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		id += 128;
		
		if(id < 240){
			sampleData = textureLod(PROGRAM_BLOOM_SAMPLE_TEXTURE, sampleCoord(id, groupTexelOrigin), 0.0).rgb;
			sampleColor[id] = uvec2(packHalf2x16(sampleData.xy), floatBitsToUint(sampleData.z));
		}
		
		barrier();

		int wid = int(gl_LocalInvocationID.x + gl_LocalInvocationID.y * 20u);

		uvec2 writeData = sampleColor[wid];
		vec3 blur = vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 2];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 4];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 40];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 42];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.25;
		writeData = sampleColor[wid + 44];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 80];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;
		writeData = sampleColor[wid + 82];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.125;
		writeData = sampleColor[wid + 84];
		blur     += vec3(unpackHalf2x16(writeData.x), uintBitsToFloat(writeData.y).x) * 0.0625;

		ivec2 drawCoord = ivec2(gl_GlobalInvocationID.xy);

		#if   PROGRAM_BLOOM_UPSAMPLE_LEVEL == 7
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0078125)))){
				drawCoord.x += int(screenSize.x * 0.234375) + 4;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 6
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.015625)))){
				drawCoord.x += int(screenSize.x * 0.21875) + 3;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 5
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.03125)))){
				drawCoord.x += int(screenSize.x * 0.1875) + 2;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 4
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.0625)))){
				drawCoord.x += int(screenSize.x * 0.125) + 1;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 3
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.125)))){
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 2
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.25)))){
				drawCoord.x += int(screenSize.x * 0.5) + 1;
		#elif PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			if (all(lessThan(drawCoord, ivec2(screenSize * 0.5)))){
		#endif

		#if PROGRAM_BLOOM_UPSAMPLE_LEVEL > 2
			drawCoord.y += int(screenSize.y * 0.5) + 1;
		#endif

		
			blur = blur + texelFetch(colortex2, drawCoord, 0).rgb;

			#if PROGRAM_BLOOM_UPSAMPLE_LEVEL == 1
			blur *= 1.0 / 7.0;
			#endif
			
			imageStore(colorimg2, drawCoord, vec4(blur, 0.0));
		}
	}
#endif
*/