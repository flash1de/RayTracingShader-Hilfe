//DH_Terrain_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform float far;
uniform float wetness;

uniform vec2 taaJitter;
uniform float eyeSnowySmooth;
uniform float eyeNoPrecipitationSmooth;


uniform sampler2D noisetex;


/* RENDERTARGETS: 0,5,6 */
layout(location = 0) out vec4 framebuffer0;
layout(location = 1) out vec4 framebuffer5;
layout(location = 2) out vec4 framebuffer6;


in vec3 v_color;
in vec3 v_worldPos;
in vec3 v_normal;
in vec2 v_blockLight;
flat in float v_materialIDs;
flat in float v_emissiveness;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif
#include "/Lib/IndividualFunctions/Ripple.glsl"


void DH_noise(inout vec3 color, vec3 pos){
	const float steps = DH_TEXTURE_NOISE_STEPS;
	pos = floor(pos * steps) / steps;
	
	float weight = Luminance(color) * 2.0 - 1.0;
	weight = 1.0 - weight * weight;
	weight *= float(v_materialIDs == MATID_LEAVES) + 1.0;
	weight *= 1.0 - fract(v_materialIDs) * 10.0;
	weight *= DH_TEXTURE_NOISE_STRENGTH;

	float noise = fract(sin(dot(pos.xy + fract(sin(pos.z * (91.3458)) * 47453.5453), vec2(12.9898, 78.233))) * 43758.5453);
	noise = (noise * 2.0 - 1.0) * weight;

	color = saturate(color + color * noise);
}


void main(){
	#if FSR2_SCALE >= 0
		if (FsrDiscardFS(gl_FragCoord.xy)) discard;
	#endif

	#ifdef DH_TERRAIN_CULLING
		if (length(v_worldPos) < far * 0.7) discard;
	#endif

//albedo
	vec3 albedo = v_color;
	#ifdef DH_TEXTURE_NOISE
		DH_noise(albedo, v_worldPos + cameraPosition + v_normal * 0.001);
	#endif

	#if WHITE_DEBUG_WORLD > 0
		albedo = vec3(WHITE_DEBUG_WORLD * 0.1);
	#endif

//wet effect
	#ifdef ENABLE_ROUGH_SPECULAR

		vec3 mcPos = v_worldPos + cameraPosition;
		float NdotU = v_normal.y;
		
		const float porosity = TEXTURE_DEFAULT_POROSITY;

		#ifdef DIMENSION_OVERWORLD
			#ifndef DISABLE_LOCAL_PRECIPITATION
				float wet = wetness * (1.0 - eyeSnowySmooth) * (1.0 - eyeNoPrecipitationSmooth) + SURFACE_WETNESS;
			#else
				float wet = wetness + SURFACE_WETNESS;
			#endif

			wet *= float(abs(v_emissiveness - 0.99) > 0.005);
			wet *= step(0.9, v_blockLight.y);

			if (wet > 1e-7){
				wet *= GetModulatedRainSpecular(mcPos);
				wet *= saturate(v_blockLight.y * 10.0 - 9.0);
				wet *= saturate(NdotU * 0.5 + 0.5);
			}

		#else
			float wet = SURFACE_WETNESS;

			if (wet > 1e-7){
				GetModulatedRainSpecular(mcPos);
				wet *= saturate(NdotU * 0.5 + 0.5);
			}
		#endif


		albedo *= 1.0 - wet * fsqrt(porosity) * POROSITY_ABSORPTION;

	#else
		float wet = 0.0;
	#endif

//normal
	vec2 normalEnc = EncodeNormal(v_normal);


	framebuffer0 = vec4(albedo, 1.0);
	framebuffer5 = vec4(0.0, Pack2x8(vec2(0.0, v_emissiveness)), Pack2x8(vec2(1.0, v_materialIDs / 255.0)), Pack2x8(saturate(v_blockLight + 1e-6)));
	framebuffer6 = vec4(normalEnc, normalEnc);
}