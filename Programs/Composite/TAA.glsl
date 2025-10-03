

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 framebuffer3;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;


#include "/Lib/GbufferData.glsl"

#include "/Lib/Uniform/GbufferTransforms.glsl"


vec3 RGB_To_YCoCg(vec3 color) {
	return vec3(color.r * 0.25 + color.g * 0.5 + color.b * 0.25, color.r * 0.5 - color.b * 0.5, color.r * -0.25 + color.g * 0.5 + color.b * -0.25);
}

vec3 YCoCg_To_RGB(vec3 color) {
	float temp = color.r - color.b;
	return vec3(temp + color.g, color.r + color.b, temp - color.g);
}


vec3 BicubicTexture(sampler2D texSampler, vec2 coord, vec2 texSize){
	vec2 texPixelSize = 1.0 / texSize;
	coord = coord * texSize;

	vec2 p = floor(coord - 0.5) + 0.5;
	vec2 f = coord - p;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	const float c = 0.5;
	vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
	vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
	vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
	vec2 w3 =         c  * f3 -                c * f2;

	vec2 w12 = w1 + w2;
	vec2 tc12 = texPixelSize * (p + w2 / w12);
	vec2 tc0 = texPixelSize * (p - 1.0);
	vec2 tc3 = texPixelSize * (p + 2.0);

	vec4 color = vec4(textureLod(texSampler, vec2(tc12.x, tc0.y ), 0.0).rgb, 1.0) * (w12.x * w0.y ) +
				vec4(textureLod(texSampler, vec2(tc0.x,  tc12.y), 0.0).rgb, 1.0) * (w0.x  * w12.y) +
				vec4(textureLod(texSampler, vec2(tc12.x, tc12.y), 0.0).rgb, 1.0) * (w12.x * w12.y) +
				vec4(textureLod(texSampler, vec2(tc3.x,  tc12.y), 0.0).rgb, 1.0) * (w3.x  * w12.y) +
				vec4(textureLod(texSampler, vec2(tc12.x, tc3.y ), 0.0).rgb, 1.0) * (w12.x * w3.y );
	return max(color.rgb / color.a, vec3(0.0));
}

vec4 BicubicTextureVec4(sampler2D texSampler, vec2 coord, vec2 texSize){
	vec2 texPixelSize = 1.0 / texSize;
	coord = coord * texSize;

	vec2 p = floor(coord - 0.5) + 0.5;
	vec2 f = coord - p;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	const float c = 0.5;
	vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
	vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
	vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
	vec2 w3 =         c  * f3 -                c * f2;

	vec2 w12 = w1 + w2;
	vec2 tc12 = texPixelSize * (p + w2 / w12);
	vec2 tc0 = texPixelSize * (p - 1.0);
	vec2 tc3 = texPixelSize * (p + 2.0);

	vec4 color = textureLod(texSampler, vec2(tc12.x, tc0.y ), 0.0) * (w12.x * w0.y ) +
				textureLod(texSampler, vec2(tc0.x,  tc12.y), 0.0) * (w0.x  * w12.y) +
				textureLod(texSampler, vec2(tc12.x, tc12.y), 0.0) * (w12.x * w12.y) +
				textureLod(texSampler, vec2(tc3.x,  tc12.y), 0.0) * (w3.x  * w12.y) +
				textureLod(texSampler, vec2(tc12.x, tc3.y ), 0.0) * (w12.x * w3.y );
	return max(color / (w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y), 0.0);
}


#ifdef DIMENSION_NETHER

	vec4 SampleCurr(vec2 coord){
		vec4 curr = textureLod(colortex1, coord, 0.0);
		curr.rgb = RGB_To_YCoCg(LinearToCurve(curr.rgb));
		return curr;
	}

	vec4 SampleCurrFetch(ivec2 coord){
		vec4 curr = texelFetch(colortex1, coord, 0);
		curr.rgb = RGB_To_YCoCg(LinearToCurve(curr.rgb));
		return curr;
	}

	vec4 SampleCurrBicubic(vec2 coord){
		vec4 curr = BicubicTextureVec4(colortex1, coord, screenSize);
		curr.rgb = RGB_To_YCoCg(LinearToCurve(curr.rgb));
		return curr;
	}

	vec2 SamplePreviousDepthBilinear(vec2 coord){
		coord = coord * screenSize - 0.5;

		vec2 f = fract(coord);
		ivec2 texel = ivec2(coord);

		vec2 s0 = Unpack2x16(texelFetch(colortex3, texel, 0).a);
		vec2 s1 = Unpack2x16(texelFetch(colortex3, texel + ivec2(1, 0), 0).a);
		vec2 s2 = Unpack2x16(texelFetch(colortex3, texel + ivec2(0, 1), 0).a);
		vec2 s3 = Unpack2x16(texelFetch(colortex3, texel + ivec2(1, 1), 0).a);

		return mix(mix(s0, s1, f.x), mix(s2, s3, f.x), f.y);
	}

	vec4 SamplePrevious(vec2 coord){
		#ifdef TAA_BICUBIC_PREVIOUS
			vec3 prevColor = RGB_To_YCoCg(LinearToCurve(BicubicTexture(colortex3, coord, screenSize)));
		#else
			vec3 prevColor = RGB_To_YCoCg(LinearToCurve(textureLod(colortex3, coord, 0.0).rgb));
		#endif
		float prevReferenceDepth = SamplePreviousDepthBilinear(coord).x * 1024.0;
		return vec4(prevColor, prevReferenceDepth);
	}

	float SamplePrevDepthFetch(ivec2 coord){
		return Unpack2x16(texelFetch(colortex3, coord, 0).a).y;
	}

	vec2 SamplePrevDepthMinMax3x3(vec2 prevCoord){
		ivec2 nearestTexel = ivec2(prevCoord * screenSize);
		float depth0 = SamplePrevDepthFetch(nearestTexel + ivec2(-1, -1));
		float depth1 = SamplePrevDepthFetch(nearestTexel + ivec2( 0, -1));
		float depth2 = SamplePrevDepthFetch(nearestTexel + ivec2( 1, -1));
		float depth3 = SamplePrevDepthFetch(nearestTexel + ivec2(-1,  0));
		float depth4 = SamplePrevDepthFetch(nearestTexel + ivec2( 0,  0));
		float depth5 = SamplePrevDepthFetch(nearestTexel + ivec2( 1,  0));
		float depth6 = SamplePrevDepthFetch(nearestTexel + ivec2(-1,  1));
		float depth7 = SamplePrevDepthFetch(nearestTexel + ivec2( 0,  1));
		float depth8 = SamplePrevDepthFetch(nearestTexel + ivec2( 1,  1));

		float depthMin = max9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);
		float depthMax = min9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);

		return vec2(1.0 - depthMin, 1.0 - depthMax);
	}

	vec3 GetVariance3x3(ivec2 coord, vec3 currColor, out vec3 avgColor, out vec3 crossAvgColor, out vec2 referenceDepthMinMax){
		vec4 data0 = SampleCurrFetch(coord + ivec2(-1, -1));
		vec4 data1 = SampleCurrFetch(coord + ivec2( 0, -1));
		vec4 data2 = SampleCurrFetch(coord + ivec2( 1, -1));
		vec4 data3 = SampleCurrFetch(coord + ivec2(-1,  0));
		vec4 data4 = SampleCurrFetch(coord + ivec2( 0,  0));
		vec4 data5 = SampleCurrFetch(coord + ivec2( 1,  0));
		vec4 data6 = SampleCurrFetch(coord + ivec2(-1,  1));
		vec4 data7 = SampleCurrFetch(coord + ivec2( 0,  1));
		vec4 data8 = SampleCurrFetch(coord + ivec2( 1,  1));

		crossAvgColor = data1.rgb + data3.rgb + data4.rgb + data5.rgb + data7.rgb;
		avgColor = (crossAvgColor + data0.rgb + data2.rgb + data6.rgb + data8.rgb) / 9.0;
		crossAvgColor *= 0.2;
		vec3 m2 = (data0.rgb * data0.rgb + data1.rgb * data1.rgb + data2.rgb * data2.rgb + data3.rgb * data3.rgb + data4.rgb * data4.rgb + data5.rgb * data5.rgb + data6.rgb * data6.rgb + data7.rgb * data7.rgb + data8.rgb * data8.rgb) / 9.0;

		vec3 variance = sqrt(m2 - avgColor * avgColor) * TAA_AGGRESSION;

		vec3 minColor = min(avgColor - variance, currColor) * 0.5;
		vec3 maxColor = max(avgColor + variance, currColor) * 0.5;

		referenceDepthMinMax = vec2(min9(data0.a, data1.a, data2.a, data3.a, data4.a, data5.a, data6.a, data7.a, data8.a),
									max9(data0.a, data1.a, data2.a, data3.a, data4.a, data5.a, data6.a, data7.a, data8.a));

		avgColor = minColor + maxColor;
		return maxColor - minColor;
	}

#else

	vec3 SampleCurrColor(vec2 coord){
		return RGB_To_YCoCg(LinearToCurve(textureLod(colortex1, coord, 0.0).rgb));
	}

	vec3 SampleCurrColorFetch(ivec2 coord){
		return RGB_To_YCoCg(LinearToCurve(texelFetch(colortex1, coord, 0).rgb));
	}

	vec3 SampleCurrColorBicubic(vec2 coord){
		return RGB_To_YCoCg(LinearToCurve(BicubicTexture(colortex1, coord, screenSize)));
	}

	vec3 SamplePrevColor(vec2 coord){
		#ifdef TAA_BICUBIC_PREVIOUS
			return RGB_To_YCoCg(LinearToCurve(BicubicTexture(colortex3, coord, screenSize)));
		#else
			return RGB_To_YCoCg(LinearToCurve(textureLod(colortex3, coord, 0.0).rgb));
		#endif
	}

	float SamplePrevDepthFetch(ivec2 coord){
		return texelFetch(colortex3, coord, 0).w;
	}

	vec2 SamplePrevDepthMinMax3x3(vec2 prevCoord){
		ivec2 nearestTexel = ivec2(prevCoord * screenSize);
		float depth0 = SamplePrevDepthFetch(nearestTexel + ivec2(-1, -1));
		float depth1 = SamplePrevDepthFetch(nearestTexel + ivec2( 0, -1));
		float depth2 = SamplePrevDepthFetch(nearestTexel + ivec2( 1, -1));
		float depth3 = SamplePrevDepthFetch(nearestTexel + ivec2(-1,  0));
		float depth4 = SamplePrevDepthFetch(nearestTexel + ivec2( 0,  0));
		float depth5 = SamplePrevDepthFetch(nearestTexel + ivec2( 1,  0));
		float depth6 = SamplePrevDepthFetch(nearestTexel + ivec2(-1,  1));
		float depth7 = SamplePrevDepthFetch(nearestTexel + ivec2( 0,  1));
		float depth8 = SamplePrevDepthFetch(nearestTexel + ivec2( 1,  1));

		float depthMin = max9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);
		float depthMax = min9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);

		return vec2(1.0 - depthMin, 1.0 - depthMax);
	}

	vec3 GetVariance3x3(ivec2 coord, vec3 currColor, out vec3 avgColor, out vec3 crossAvgColor){
		vec3 color0 = SampleCurrColorFetch(coord + ivec2(-1, -1));
		vec3 color1 = SampleCurrColorFetch(coord + ivec2( 0, -1));
		vec3 color2 = SampleCurrColorFetch(coord + ivec2( 1, -1));
		vec3 color3 = SampleCurrColorFetch(coord + ivec2(-1,  0));
		vec3 color4 = SampleCurrColorFetch(coord + ivec2( 0,  0));
		vec3 color5 = SampleCurrColorFetch(coord + ivec2( 1,  0));
		vec3 color6 = SampleCurrColorFetch(coord + ivec2(-1,  1));
		vec3 color7 = SampleCurrColorFetch(coord + ivec2( 0,  1));
		vec3 color8 = SampleCurrColorFetch(coord + ivec2( 1,  1));

		crossAvgColor = color1 + color3 + color4 + color5 + color7;
		avgColor = (crossAvgColor + color0 + color2 + color6 + color8) / 9.0;
		crossAvgColor *= 0.2;
		vec3 m2 = (color0 * color0 + color1 * color1 + color2 * color2 + color3 * color3 + color4 * color4 + color5 * color5 + color6 * color6 + color7 * color7 + color8 * color8) / 9.0;

		vec3 variance = sqrt(m2 - avgColor * avgColor) * TAA_AGGRESSION;

		vec3 minColor = min(avgColor - variance, currColor) * 0.5;
		vec3 maxColor = max(avgColor + variance, currColor) * 0.5;

		avgColor = minColor + maxColor;
		return maxColor - minColor;
	}

#endif

vec3 clipAABB(vec3 avgColor, vec3 variance, vec3 prevColor){	
	#ifdef TAA_CLIP_TO_CENTER
		const float eps = 1e-20;
		vec3 p_clip = avgColor;
		vec3 e_clip = variance - eps;

		vec3 v_clip = prevColor - p_clip;
		vec3 v_unit = v_clip.xyz / e_clip;
		vec3 a_unit = abs(v_unit);
		float ma_unit = max3(a_unit.x, a_unit.y, a_unit.z);

		if (ma_unit > 1.0)
			return p_clip + v_clip / ma_unit;
		else
			return prevColor;
	#else
		vec3 diff = prevColor - avgColor;

		vec3 clipMax = mix(vec3(1.0), variance / diff, greaterThan(diff, variance));
		vec3 clipMin = mix(vec3(1.0), -variance / diff, lessThan(diff, -variance));
		diff *= clipMax.x * clipMax.y * clipMax.z * clipMin.x * clipMin.y * clipMin.z;

		return avgColor + diff;
	#endif
}

#ifdef DIMENSION_NETHER
vec4 TemporalReprojection(vec2 coord, vec3 velocity, float currDepthMin, out float referenceDepth){
#else
vec4 TemporalReprojection(vec2 coord, vec3 velocity, float currDepthMin){
#endif
	vec2 unjitterCoord = coord + taaJitter * 0.5;
	
	#ifdef DIMENSION_NETHER
		#ifdef TAA_BICUBIC_CURRENT
			vec4 currData = SampleCurrBicubic(unjitterCoord);
		#else
			vec4 currData = SampleCurr(unjitterCoord);
		#endif
		vec3 currColor = currData.rgb;
	#else
		#ifdef TAA_BICUBIC_CURRENT
			vec3 currColor = SampleCurrColorBicubic(unjitterCoord);
		#else
			vec3 currColor = SampleCurrColor(unjitterCoord);
		#endif
	#endif

	vec3 avgColor = currColor;
	vec3 crossAvgColor = currColor;
	#ifdef DIMENSION_NETHER
		vec2 referenceDepthMinMax = vec2(0.0);
		vec3 variance = GetVariance3x3(texelCoord, currData.rgb, avgColor, crossAvgColor, referenceDepthMinMax);
	#else
		vec3 variance = GetVariance3x3(texelCoord, currColor, avgColor, crossAvgColor);
	#endif

	coord -= velocity.xy;
	#ifdef DIMENSION_NETHER
		vec4 prevData = SamplePrevious(coord);
		vec3 prevColor = prevData.rgb;
			
		const float depthThreshold = 5.0;
		prevData.a = clamp(prevData.a + velocity.z, referenceDepthMinMax.x - depthThreshold, referenceDepthMinMax.y + depthThreshold);

	#else
		vec3 prevColor = SamplePrevColor(coord);
	#endif

	prevColor = clipAABB(avgColor, variance, prevColor);

	float blendWeight = TAA_BLENDWEIGHT;

	vec2 pixelVelocity = abs(fract(velocity.xy * screenSize) - 0.5) * 2.0;
	blendWeight *= sqrt(pixelVelocity.x * pixelVelocity.y) * 0.2 + 0.8;
	blendWeight *= float(saturate(coord) == coord);

	#ifdef TAA_DEPTH_COMPARE
		vec2 prevDepth = SamplePrevDepthMinMax3x3(coord);
		float currDist = LinearDepth_From_ScreenDepth(currDepthMin);
		float threshold = max(TAA_DEPTH_COMPARE_THRESHOLD - currDist / far * 0.2 * TAA_DEPTH_COMPARE_THRESHOLD, 1e-5);
		blendWeight *= step(prevDepth.x - currDepthMin + velocity.z, threshold);
		blendWeight *= step(currDepthMin - velocity.z - prevDepth.y, threshold);
	#endif

	#ifdef TAA_MICRO_BLUR
		currColor = mix(crossAvgColor, currColor, saturate(blendWeight * 5.0 - 0.5));
	#endif

	currColor = mix(currColor, prevColor, blendWeight);
	#ifdef DIMENSION_NETHER
		referenceDepth = mix(currData.a, prevData.a, blendWeight);
		referenceDepth = referenceDepth / 1024.0;
	#endif

	currColor = max(CurveToLinear(YCoCg_To_RGB(currColor)), 0.0);
	return vec4(currColor, 1.0 - currDepthMin);
}



float SampleDepthFetch(sampler2D depthSampler, ivec2 coord){
	return texelFetch(depthSampler, coord, 0).x;
}

float SampleCurrDepthFetchClosest3x3(sampler2D depthSampler, ivec2 coord){
	float depth0 = SampleDepthFetch(depthSampler, coord + ivec2(-1, -1));
	float depth1 = SampleDepthFetch(depthSampler, coord + ivec2( 0, -1));
	float depth2 = SampleDepthFetch(depthSampler, coord + ivec2( 1, -1));
	float depth3 = SampleDepthFetch(depthSampler, coord + ivec2(-1,  0));
	float depth4 = SampleDepthFetch(depthSampler, coord + ivec2( 0,  0));
	float depth5 = SampleDepthFetch(depthSampler, coord + ivec2( 1,  0));
	float depth6 = SampleDepthFetch(depthSampler, coord + ivec2(-1,  1));
	float depth7 = SampleDepthFetch(depthSampler, coord + ivec2( 0,  1));
	float depth8 = SampleDepthFetch(depthSampler, coord + ivec2( 1,  1));

	return min9(depth0, depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8);
}

/*
#ifdef VS_VELOCITY
	float SampleCurrDepthFetchClosest3x3(sampler2D depthSampler, ivec2 coord, out ivec2 closestCoord){
		float closestDepth = 2.0;

		for (int i = -1; i < 2; i++){
		for (int j = -1; j < 2; j++){
			ivec2 sampleCoord = coord + ivec2(i, j);
			float sampleDepth = SampleDepthFetch(depthSampler, sampleCoord);
			if (sampleDepth < closestDepth){
				closestDepth = sampleDepth;
				closestCoord = sampleCoord;
			}
		}}

		return closestDepth;
	}
#endif
*/

#ifdef DISTANT_HORIZONS

vec3 ScreenVelocity(out float depth, float materialIDs){
	vec3 velocity = vec3(0.0);

	if (materialIDs == MATID_STAINEDGLASS){
		#ifdef TAA_CLOSEST_DEPTH
			depth = SampleCurrDepthFetchClosest3x3(depthtex1, texelCoord);
		#else
			depth = SampleDepthFetch(depthtex1, texelCoord);
		#endif
	}else{
		#ifdef TAA_CLOSEST_DEPTH
			depth = SampleCurrDepthFetchClosest3x3(depthtex0, texelCoord);
		#else
			depth = SampleDepthFetch(depthtex0, texelCoord);
		#endif
	}

	if (materialIDs != MATID_END_PORTAL){
		vec3 screenPos = vec3(texCoord, depth);
		vec3 projection = vec3(0.0);

		if (screenPos.z == 1.0){
			#ifdef TAA_CLOSEST_DEPTH
				screenPos.z = SampleCurrDepthFetchClosest3x3(dhDepthTex0, texelCoord);
			#else
				screenPos.z = SampleDepthDHFetch(dhDepthTex0, texelCoord);
			#endif

			projection = vec3(screenPos * 2.0 - 1.0);

			projection = (vec3(vec2(dhProjectionInverse[0].x, dhProjectionInverse[1].y) * projection.xy, 0.0) + dhProjectionInverse[3].xyz) / (dhProjectionInverse[2].w * projection.z + dhProjectionInverse[3].w);

			projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;

			if (screenPos.z < 1.0) projection += cameraPositionToPrevious;

			projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
			projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

			screenPos.z = ScreenDepth_From_DHScreenDepth(screenPos.z);
			depth = screenPos.z;
		}else{
			projection = vec3(screenPos * 2.0 - 1.0);

			projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);

			if (depth < 0.7){
				projection += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
			}else{
				projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
				projection += cameraPositionToPrevious;
				projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
			}
			
			projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;
		}
		
		velocity = screenPos - projection;
	}
	
	return velocity;
}

#else

vec3 ScreenVelocity(out float depth, float materialIDs){
	vec3 velocity = vec3(0.0);

/*
	#ifdef VS_VELOCITY
		ivec2 closestCoord = texelCoord;
		if (materialIDs == MATID_STAINEDGLASS){
			depth = texelFetch(depthtex1, texelCoord, 0).x;
		}else{
			#ifdef TAA_CLOSEST_DEPTH
				depth = SampleCurrDepthFetchClosest3x3(texelCoord, closestCoord);
			#else
				depth = SampleDepthFetch(texelCoord);
			#endif
		}

		if (depth < 1.0){
			velocity = texelFetch(colortex3, closestCoord, 0).xyz;
		}else{
			vec3 screenPos = vec3(texCoord, depth);
			vec3 projection = screenPos * 2.0 - 1.0;

			projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);
			projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
			projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
			projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

			velocity = screenPos - projection;
		}
	#else
*/
		if (materialIDs == MATID_STAINEDGLASS){
			#ifdef TAA_CLOSEST_DEPTH
				depth = SampleCurrDepthFetchClosest3x3(depthtex1, texelCoord);
			#else
				depth = SampleDepthFetch(depthtex1, texelCoord);
			#endif
		}else{
			#ifdef TAA_CLOSEST_DEPTH
				depth = SampleCurrDepthFetchClosest3x3(depthtex0, texelCoord);
			#else
				depth = SampleDepthFetch(depthtex0, texelCoord);
			#endif
		}

		if (materialIDs != MATID_END_PORTAL){
			vec3 screenPos = vec3(texCoord, depth);
			vec3 projection = screenPos * 2.0 - 1.0;

			projection = (vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * projection.xy, 0.0) + gbufferProjectionInverse[3].xyz) / (gbufferProjectionInverse[2].w * projection.z + gbufferProjectionInverse[3].w);

			if (depth < 0.7){
				projection += (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * MC_HAND_DEPTH;
			}else{
				projection = mat3(gbufferModelViewInverse) * projection + gbufferModelViewInverse[3].xyz;
				if (depth < 1.0) projection += cameraPositionToPrevious;
				projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
			}
			
			projection = (vec3(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].z) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

			velocity = screenPos - projection;
		}
//	#endif
	
	return velocity;
}

#endif


void main(){
	#ifdef TAA
		float materialIDs = GetMaterialID(texelCoord);

		vec4 taa = vec4(0.0);


		#if defined DECREASE_HAND_GHOSTING && defined DISABLE_PLAYER_TAA_MOTION_BLUR
			if (materialIDs == MATID_HAND || materialIDs == MATID_ENTITIES_PLAYER){
				taa = texelFetch(colortex1, texelCoord, 0);
				#ifdef DIMENSION_NETHER
					taa = vec4(taa.rgb, Pack2x16(saturate(vec2(taa.a / 1024.0, 0.0))));
				#endif
			}else
		#elif defined DECREASE_HAND_GHOSTING
			if (materialIDs == MATID_HAND){
				taa = texelFetch(colortex1, texelCoord, 0);
				#ifdef DIMENSION_NETHER
					taa = vec4(taa.rgb, Pack2x16(saturate(vec2(taa.a / 1024.0, 0.0))));
				#endif
			}else
		#elif defined DISABLE_PLAYER_TAA_MOTION_BLUR
			if (materialIDs == MATID_ENTITIES_PLAYER){
				taa = texelFetch(colortex1, texelCoord, 0);
				#ifdef DIMENSION_NETHER
					taa = vec4(taa.rgb, Pack2x16(saturate(vec2(taa.a / 1024.0, 0.0))));
				#endif
			}else
		#endif
			{
				float depth = 1.0;
				vec3 velocity = ScreenVelocity(depth, materialIDs);

			#ifdef DIMENSION_NETHER
				float referenceDepth = 0.0;
				taa = TemporalReprojection(texCoord, velocity, depth, referenceDepth);
				taa = vec4(taa.rgb, Pack2x16(saturate(vec2(referenceDepth, taa.a))));
			#else
				taa = TemporalReprojection(texCoord, velocity, depth);
			#endif
			}

	#else
		vec4 taa = texelFetch(colortex1, texelCoord, 0);

		#if FSR2_SCALE >= 0
			taa = textureLod(colortex1, texCoord * fsrRenderScale, 0.0);
		#endif

		#ifdef DIMENSION_NETHER
			taa = vec4(taa.rgb, Pack2x16(saturate(vec2(taa.a / 1024.0, 0.0))));
		#endif
	#endif

	framebuffer3 = taa;
}
