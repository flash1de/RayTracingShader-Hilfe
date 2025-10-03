

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


#if   PT_VOXEL_RESOLUTION == 4004
	const ivec3 workGroups = ivec3(16, 16, 16);
#elif PT_VOXEL_RESOLUTION == 6004
	const ivec3 workGroups = ivec3(24, 16, 24);
#elif PT_VOXEL_RESOLUTION == 6006
	const ivec3 workGroups = ivec3(24, 24, 24);
#elif PT_VOXEL_RESOLUTION == 8004
	const ivec3 workGroups = ivec3(32, 16, 32);
#elif PT_VOXEL_RESOLUTION == 8006
	const ivec3 workGroups = ivec3(32, 24, 32);
#elif PT_VOXEL_RESOLUTION == 8008
	const ivec3 workGroups = ivec3(32, 32, 32);
#elif PT_VOXEL_RESOLUTION == 12004
	const ivec3 workGroups = ivec3(48, 16, 48);
#elif PT_VOXEL_RESOLUTION == 12006
	const ivec3 workGroups = ivec3(48, 24, 48);
#elif PT_VOXEL_RESOLUTION == 12008
	const ivec3 workGroups = ivec3(48, 32, 48);
#elif PT_VOXEL_RESOLUTION == 16004
	const ivec3 workGroups = ivec3(64, 16, 64);
#elif PT_VOXEL_RESOLUTION == 16006
	const ivec3 workGroups = ivec3(64, 24, 64);
#elif PT_VOXEL_RESOLUTION == 16008
	const ivec3 workGroups = ivec3(64, 32, 64);
#elif PT_VOXEL_RESOLUTION == 16016
	const ivec3 workGroups = ivec3(64, 64, 64);
#endif

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout (rgba16) uniform writeonly image3D img_voxelData3D;

#ifdef PT_SPARE_TRACING
	shared uint isOccupied_8;
	shared uint isOccupied_4[8];
	shared uint isOccupied_2[64];
#endif

uniform sampler2D shadowcolor1;


#include "/Lib/PathTracing/Voxelizer/VoxelProfile.glsl"


void main(){
	#ifdef PT_SPARE_TRACING
		int id_4 = int((gl_LocalInvocationID.x >> 2u) + (gl_LocalInvocationID.y >> 2u) * 2u + (gl_LocalInvocationID.z >> 2u) * 4u);
		int id_2 = int((gl_LocalInvocationID.x >> 1u) + (gl_LocalInvocationID.y >> 1u) * 4u + (gl_LocalInvocationID.z >> 2u) * 16u);

		isOccupied_8 = 0u;
		isOccupied_4[id_4] = 0u;
		isOccupied_2[id_2] = 0u;

		barrier();
	#endif

	ivec3 drawTexel = ivec3(gl_GlobalInvocationID.xyz);
	ivec2 voxelTexel = ivec2(VoxelTexel_From_VoxelCoord(vec3(drawTexel)));

	vec4 voxelData = texelFetch(shadowcolor1, voxelTexel, 0);

	#ifdef PT_SPARE_TRACING
		uint occupied = uint(voxelData.z < 1.0);

		uint occupied_8 = atomicMax(isOccupied_8, occupied);

		barrier();

		if (isOccupied_8 == 0u){
			voxelData.z = 0.91;
		}else{
			uint occupied_4 = atomicMax(isOccupied_4[id_4], occupied);
			barrier();
			if (isOccupied_4[id_4] == 0u){
				voxelData.z = 0.71;
			}else{			
				uint occupied_2 = atomicMax(isOccupied_2[id_2], occupied);
				barrier();
				if (isOccupied_2[id_2] == 0u)
					voxelData.z = 0.61; 
			}
		}
	#endif

	imageStore(img_voxelData3D, drawTexel, voxelData);
}