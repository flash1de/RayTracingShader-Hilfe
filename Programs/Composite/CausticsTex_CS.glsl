

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


const ivec3 workGroups = ivec3(32, 64, 1);
layout (local_size_x = 16, local_size_y = 8) in;

layout (rg16f) writeonly uniform image2D img_pixelData2D;


#define CAUSZTICS_NORMAL
#include "/Lib/IndividualFunctions/WaterWaves.glsl"


void main(){
	vec2 causticsCoord = vec2(gl_GlobalInvocationID.xy) * (50.0 / 512.0);
	
	vec3 waveNormal = WaveNormal(vec3(causticsCoord.x, 0.0, causticsCoord.y), 18.0);

	imageStore(img_pixelData2D, ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y + 1), vec4(waveNormal.xy / waveNormal.z, 0.0, 0.0));
}
