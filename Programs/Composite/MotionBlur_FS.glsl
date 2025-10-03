

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 framebuffer1;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"
#include "/Lib/BasicFunctions/TemporalNoise.glsl"


#ifdef VS_VELOCITY
	vec2 ScreenVelocity(vec2 coord, float depth){
		vec3 projection = vec3(coord, depth) * 2.0 - 1.0;
		projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);
		projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
		projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;	
		projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;
		return coord - projection.xy;
	}
#else
	vec2 ScreenVelocity(vec2 coord, float depth){
		vec3 projection = vec3(coord, depth) * 2.0 - 1.0;
		projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);
		projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
		if (depth < 1.0) projection += cameraPositionToPrevious;
		projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;		
		projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;
		return coord - projection.xy;
	}
#endif


float SampleDepthFetch(sampler2D depthSampler, ivec2 coord){
	return texelFetch(depthSampler, coord, 0).x;
}

float SampleDepthFetchClosest3x3(sampler2D depthSampler, vec2 coord){
	ivec2 nearestTexel = ivec2(coord * screenSize);
	float depth0 = SampleDepthFetch(depthSampler, nearestTexel + ivec2(-1, -1));
	float depth1 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 0, -1));
	float depth2 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 1, -1));
	float depth3 = SampleDepthFetch(depthSampler, nearestTexel + ivec2(-1,  0));
	float depth4 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 0,  0));
	float depth5 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 1,  0));
	float depth6 = SampleDepthFetch(depthSampler, nearestTexel + ivec2(-1,  1));
	float depth7 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 0,  1));
	float depth8 = SampleDepthFetch(depthSampler, nearestTexel + ivec2( 1,  1));

	return min9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);
}

vec3 MotionBlur(){
	vec2 velocity = vec2(0.0);

	#ifdef VS_VELOCITY
		float depth = texelFetch(depthtex0, texelCoord, 0).x;
		if (depth < 1.0){
			velocity = texelFetch(colortex7, texelCoord, 0).xy;
		}else{
			velocity = ScreenVelocity(texCoord, depth);
		}
	#else
		#if FSR2_SCALE >= 0
			ivec2 sampleTexel = ivec2(texCoord * fsrScreenSize);
		#else
			ivec2 sampleTexel = texelCoord;
		#endif

		float materialIDs = GetMaterialID(sampleTexel);

		float depth = 0.0;
		if (materialIDs == MATID_WATER){
			depth = texelFetch(depthtex0, sampleTexel, 0).x;
		}else{
			depth = texelFetch(depthtex1, sampleTexel, 0).x;
		}

		#ifdef DISABLE_PLAYER_TAA_MOTION_BLUR
			if (depth > 0.7 && materialIDs != MATID_END_PORTAL && materialIDs != MATID_ENTITIES_PLAYER) 
		#else
			if (depth > 0.7 && materialIDs != MATID_END_PORTAL)
		#endif
			velocity = ScreenVelocity(texCoord, depth);
	#endif



	vec3 color = vec3(0.0);

	float stability = inversesqrt(dot(velocity, velocity));

	if (stability > 1e5){
		color = texelFetch(colortex3, texelCoord, 0).rgb;

	}else{
		velocity *= saturate(stability);
		#if MOTION_BLUR_SUTTER_MODE == 0
			const float sutter = MOTION_BLUR_SUTTER_ANGLE / 360.0;
		#else
			const float sutter = 1.0 / MOTION_BLUR_SUTTER_SPEED / frameTime;
		#endif
		velocity *= sutter * 0.5;


		vec2 stepDir = velocity * (1.0 / MOTION_BLUR_QUALITY);

		float noise = 0.5;
		#ifdef MOTION_BLUR_DITHER
			noise = BlueNoiseTemporal().x;
		#endif		

		vec2 coord = texCoord - velocity * 0.5 + noise * stepDir;

		const float steps = MOTION_BLUR_QUALITY;
		#if defined DECREASE_HAND_GHOSTING && FSR2_SCALE < 0
			float samples = 0.0;
		#endif

		for (int i = 0; i < MOTION_BLUR_QUALITY; i++){
			vec2 sampleCoord = clamp(coord, 1.5 * pixelSize , 1.0 - 1.5 * pixelSize);

			#if defined DECREASE_HAND_GHOSTING && FSR2_SCALE < 0
				if (SampleDepthFetchClosest3x3(depthtex1, sampleCoord) < 0.7) continue;
				samples++;
			#endif
			color += textureLod(colortex3, sampleCoord, 0.0).rgb;
			
			coord += stepDir;
		}

		#if defined DECREASE_HAND_GHOSTING && FSR2_SCALE < 0
			if (samples == 0.0){
				color = texelFetch(colortex3, texelCoord, 0).rgb;
			}else{
				color.rgb /= samples;
			}
		#else
			color.rgb /= MOTION_BLUR_QUALITY;
		#endif

		//color.rgb = vec3(abs(velocity.xy), 0.0);
	}

	return max(color, vec3(0.0));
}




/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main(){
	#ifdef MOTION_BLUR
		vec3 color = MotionBlur();
	#else
		vec3 color = texelFetch(colortex3, texelCoord, 0).rgb;
	#endif

/*
	#ifdef DIMENSION_OVERWORLD
		#if defined LENS_GLARE || defined LENS_FLARE
			color += CurveToLinear(texelFetch(colortex3, texelCoord, 0).rgb) * eyeBrightnessSmoothCurved;
		#endif
	#endif
*/
	float bloomGuide = 0.0;
	#ifdef TITLE
		bloomGuide = title(color);
	#endif

	//color = LinearToCurve(color);

	framebuffer1 = vec4(color, bloomGuide);

/*
	vec4 data11 = texelFetch(colortex3, texelCoord, 0);

	vec2 texel = floor(gl_FragCoord.xy);

	#ifdef TITLE
		if (texel == vec2(1.0, 0.0)){
			float preAlpha = data4.a;
			float newAlpha = preAlpha + min(frameTime, 0.5) * 0.05;
			data11.a = saturate(newAlpha);
		}
	#endif

	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOW
		if (texel == vec2(40.0, screenSize.y - 1.0)){
			data2.a = mix(data2.a, CloudShadowFromTex(vec3(0.0)), 2.0 * frameTime);
		}
	#endif

	#if defined DOF && CAMERA_FOCUS_MODE == 0
		if (texel == vec2(60.0, screenSize.y - 1.0)){
			ivec2 centerTexelCoord = ivec2(screenSize * 0.5);
			float prevCenterDepth = data2.a * 0.125 + 0.875;

			float centerDepth = texelFetch(depthtex0, centerTexelCoord, 0).x;
			#ifdef DISTANT_HORIZONS
				if (centerDepth == 1.0){
					centerDepth = texelFetch(dhDepthTex0, centerTexelCoord, 0).x;
					centerDepth = ScreenDepth_From_DHScreenDepth(centerDepth);
				}
			#endif
			centerDepth = max(centerDepth, 0.875);

			float f = exp2(-frameTime * 10.0 / DOF_DEPTH_SMMOOTH_HALFLIFE);
			float centerMaterialID = GetMaterialID(centerTexelCoord);
			#ifdef DOF_FOCUS_IGNORE_HAND_PARTICLE
				if (heldItemId != 11000.0 && centerMaterialID == MATID_HAND || centerMaterialID == MATID_PARTICLE) f = 1.0;
			#endif

			data2.a = saturate(mix(centerDepth, prevCenterDepth, f) * 8.0 - 7.0);
		}
	#endif

	framebuffer3 = data11;
*/
}
