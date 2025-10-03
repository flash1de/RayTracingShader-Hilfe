

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


layout (rgba16f) uniform writeonly image2D colorimg2;


in vec3 vaPosition;

out vec3 worldShadowVector;
out vec3 shadowVector;
out vec3 worldSunVector;

out vec3 colorShadowlight;
out vec3 colorSunlight;
out vec3 colorMoonlight;

out vec3 colorSkylight;
out vec3 colorSunSkylight;
out vec3 colorMoonSkylight;

out vec3 colorTorchlight;

out float timeNoon;
out float timeMidnight;


#include "/Lib/BasicFunctions/PrecomputedAtmosphere.glsl"


void main(){
	gl_Position = vec4(vaPosition.xy * vec2(2.0, 4.0 / 3.0) - 1.0, 0.0, 1.0);

	worldShadowVector = shadowModelViewInverse2;
	shadowVector = mat3(gbufferModelView) * worldShadowVector;
	//worldSunVector = worldTime > 12785 && worldTime < 23215 ? -worldShadowVector : worldShadowVector;
	worldSunVector = worldShadowVector * (step(sunAngle, 0.5) * 2.0 - 1.0);

	timeNoon = 1.0 - pow(1.0 - (clamp(worldSunVector.y, 0.2, 0.99) - 0.2) / 0.8, 6.0);
	timeMidnight = 1.0 - curve(saturate((1.0 - saturate(-worldSunVector.y)) * 5.0 - 4.0));

	#ifdef VS_CLOUD_LIGHTING
		vec3 camera = vec3(0.0, 500.0 * 0.001 + atmosphereModel_bottom_radius, 0.0);
	#else
		#ifdef ATMO_HORIZON
			vec3 camera = vec3(0.0, max(cameraPosition.y, ATMO_MIN_ALTITUDE) * 0.001 + atmosphereModel_bottom_radius, 0.0);
		#else
			vec3 camera = vec3(0.0, max(cameraPosition.y, 63.0) * 0.001 + atmosphereModel_bottom_radius, 0.0);
		#endif
	#endif

	colorSunlight = GetSunAndSkyIrradiance(camera, worldSunVector, -worldSunVector, colorMoonlight, colorSunSkylight, colorMoonSkylight);

	colorSunlight *= 1.0 - curve(saturate((1.0 - saturate(worldSunVector.y)) * 30.0 - 29.0));
	colorMoonlight *= 1.0 - curve(saturate((1.0 - saturate(-worldSunVector.y)) * 5.0 - 4.0));
	#ifdef COLD_MOONLIGHT
		DoNightEye(colorMoonlight);
	#endif

	colorShadowlight = colorSunlight + colorMoonlight;
	colorSkylight = colorSunSkylight + colorMoonSkylight;

    if (gl_VertexID == 0){
        imageStore(colorimg2, ivec2(0, 0), vec4(colorShadowlight, 0.0));
		imageStore(colorimg2, ivec2(1, 0), vec4(colorSkylight, 0.0));
		//imageStore(colorimg2, ivec2(2, 0), vec4(colorMoonSkylight, 0.0));
    }

	colorTorchlight = Blackbody(3000.0);


}
