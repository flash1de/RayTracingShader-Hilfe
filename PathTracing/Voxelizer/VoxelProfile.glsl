

#ifndef DIMENSION_NETHER

	#if SHADOW_RENDER_DISTANCE == 4
		#if PT_VOXEL_RESOLUTION > 16000
			const float shadowDistance = 256.0;
		#elif PT_VOXEL_RESOLUTION > 12000
			const float shadowDistance = 192.0;
		#elif PT_VOXEL_RESOLUTION > 8000
			const float shadowDistance = 128.0;
		#elif PT_VOXEL_RESOLUTION > 6000
			const float shadowDistance = 96.0;
		#else
			const float shadowDistance = 64.0;
		#endif

	#elif SHADOW_RENDER_DISTANCE == 6
		#if PT_VOXEL_RESOLUTION > 16000
			const float shadowDistance = 256.0;
		#elif PT_VOXEL_RESOLUTION > 12000
			const float shadowDistance = 192.0;
		#elif PT_VOXEL_RESOLUTION > 8000
			const float shadowDistance = 128.0;
		#else
			const float shadowDistance = 96.0;
		#endif

	#elif SHADOW_RENDER_DISTANCE == 8
		#if PT_VOXEL_RESOLUTION > 16000
			const float shadowDistance = 256.0;
		#elif PT_VOXEL_RESOLUTION > 12000
			const float shadowDistance = 192.0;
		#else
			const float shadowDistance = 128.0;
		#endif

	#elif SHADOW_RENDER_DISTANCE == 12
		#if PT_VOXEL_RESOLUTION > 16000
			const float shadowDistance = 256.0;
		#else
			const float shadowDistance = 192.0;
		#endif

	#elif SHADOW_RENDER_DISTANCE == 16
		const float shadowDistance = 256.0;

	#elif SHADOW_RENDER_DISTANCE == 24
		const float shadowDistance = 384.0;

	#elif SHADOW_RENDER_DISTANCE == 32
		const float shadowDistance = 512.0;

	#elif SHADOW_RENDER_DISTANCE == 48
		const float shadowDistance = 768.0;

	#elif SHADOW_RENDER_DISTANCE == 64
		const float shadowDistance = 1024.0;

	#elif SHADOW_RENDER_DISTANCE == 96
		const float shadowDistance = 1536.0;

	#elif SHADOW_RENDER_DISTANCE == 128
		const float shadowDistance = 2048.0;

	#endif

	const float shadowWidth = 2048.0;

#endif


#if   PT_VOXEL_RESOLUTION == 4004

	const ivec3 voxelResolutionInt 	= ivec3(128);
	const float voxelDistance 		= 64.0;
	
	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 2816;
		const float voxelWidth 			= 768.0;
	#else
		const int shadowMapResolution 	= 1536;
		const float shadowDistance 		= 64.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 6004

	const ivec3 voxelResolutionInt 	= ivec3(192, 128, 192);
	const float voxelDistance 		= 96.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 3584;
		const float voxelWidth 			= 1536.0;
	#else
		const int shadowMapResolution 	= 2304;
		const float shadowDistance 		= 96.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 6006

	const ivec3 voxelResolutionInt 	= ivec3(192);
	const float voxelDistance 		= 96.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 3968;
		const float voxelWidth 			= 1920.0;
	#else
		const int shadowMapResolution 	= 2688;
		const float shadowDistance 		= 96.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 8004

	const ivec3 voxelResolutionInt 	= ivec3(256, 128, 256);
	const float voxelDistance 		= 128.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 4096;
		const float voxelWidth 			= 2048.0;
	#else
		const int shadowMapResolution 	= 3072;
		const float shadowDistance 		= 128.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 8006

	const ivec3 voxelResolutionInt 	= ivec3(256, 192, 256);
	const float voxelDistance 		= 128.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 4864;
		const float voxelWidth 			= 2816.0;
	#else
		const int shadowMapResolution 	= 3584;
		const float shadowDistance 		= 128.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 8008

	const ivec3 voxelResolutionInt 	= ivec3(256);
	const float voxelDistance 		= 128.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 5760;
		const float voxelWidth 			= 3456.0;
	#else
		const int shadowMapResolution 	= 4096;
		const float shadowDistance 		= 128.0;

	#endif


#elif PT_VOXEL_RESOLUTION == 12004

	const ivec3 voxelResolutionInt 	= ivec3(384, 128, 384);
	const float voxelDistance 		= 192.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 5376;
		const float voxelWidth 			= 3328.0;
	#else
		const int shadowMapResolution 	= 4608;
		const float shadowDistance 		= 192.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 12006

	const ivec3 voxelResolutionInt 	= ivec3(384, 192, 384);
	const float voxelDistance 		= 192.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 6656;
		const float voxelWidth 			= 4608.0;
	#else
		const int shadowMapResolution 	= 5376;
		const float shadowDistance 		= 192.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 12008

	const ivec3 voxelResolutionInt 	= ivec3(384, 256, 384);
	const float voxelDistance 		= 192.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 7424;
		const float voxelWidth 			= 5376.0;
	#else
		const int shadowMapResolution 	= 6144;
		const float shadowDistance 		= 192.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 16004

	const ivec3 voxelResolutionInt 	= ivec3(512, 128, 512);
	const float voxelDistance 		= 256.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 7168;
		const float voxelWidth 			= 5120.0;
	#else
		const int shadowMapResolution 	= 6144;
		const float shadowDistance 		= 256.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 16006

	const ivec3 voxelResolutionInt 	= ivec3(512, 192, 512);
	const float voxelDistance 		= 256.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 8192;
		const float voxelWidth 			= 6144.0;
	#else
		const int shadowMapResolution 	= 7168;
		const float shadowDistance 		= 256.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 16008

	const ivec3 voxelResolutionInt 	= ivec3(512, 256, 512);
	const float voxelDistance 		= 256.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 9728;
		const float voxelWidth 			= 7680.0;
	#else
		const int shadowMapResolution 	= 8192;
		const float shadowDistance 		= 256.0;
	#endif


#elif PT_VOXEL_RESOLUTION == 16016

	const ivec3 voxelResolutionInt 	= ivec3(512, 512, 512);
	const float voxelDistance 		= 256.0;

	#ifndef DIMENSION_NETHER
		const int shadowMapResolution 	= 12800;
		const float voxelWidth 			= 10752.0;
	#else
		const int shadowMapResolution 	= 11776;
		const float shadowDistance 		= 256.0;
	#endif


#endif




const vec3 voxelResolution = vec3(voxelResolutionInt);

const float shadowSize 			= float(shadowMapResolution);
const float shadowPixelSize 	= 1.0 / shadowSize;


#ifndef DIMENSION_NETHER
	const float shadowRatio = shadowWidth / shadowSize;

	void ShiftShadowScreenPos(inout vec2 coord){
		coord = coord * shadowRatio + vec2(1.0 - shadowRatio, 0.0);
	}

	void ShiftShadowNdcPos(inout vec2 coord){
		coord = coord * shadowRatio + vec2(1.0 - shadowRatio, shadowRatio - 1.0);
	}
#else
	const float voxelWidth = float(shadowMapResolution);

	void ShiftShadowScreenPos(inout vec2 coord){}
	void ShiftShadowNdcPos(inout vec2 coord){}
#endif

vec2 VoxelTexel_From_VoxelCoord(vec3 voxelCoord){
	voxelCoord.x += voxelCoord.y * voxelResolution.x;
	voxelCoord.y = floor(voxelCoord.x / voxelWidth);
	voxelCoord.xz += voxelCoord.y * vec2(-voxelWidth, voxelResolution.x);
	return voxelCoord.xz;
}


const int ircResolution = min(PT_IRC_RESOLUTION, voxelResolutionInt.x);


// 128 6  * 24 2816 8
// 192 10 * 20 3968 7
// 256 13 * 20 5376 8
// 384 17 * 23 8832 7
// 512 21 * 25 12800 9

// 196 14^3 2744
// 256 16^3 4096
// 324 18^3 5832
// 400 20^3 8000
// 528 23 * 23 12144