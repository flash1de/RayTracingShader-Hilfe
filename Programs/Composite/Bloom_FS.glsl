

#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 framebuffer2;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;


vec4 BicubicBlurTexture(sampler2D texSampler, vec2 coord, vec2 texSize){
    vec2 texPixelSize = 1.0 / texSize;
    coord = coord * texSize - 0.5;

    vec2 p = floor(coord);
    vec2 f = coord - p;

    vec2 ff = f * f;
    vec4 w0;
    vec4 w1;
    w0.xz = 1.0 - f; w0.xz *= w0.xz * w0.xz;
    w1.yw = ff * f;
    w1.xz = 3.0 * w1.yw + 4.0 - 6.0 * ff;
    w0.yw = 6.0 - w1.xz - w1.yw - w0.xz;

    vec4 s = w0 + w1;
    vec4 c = p.xxyy + vec2(-0.5, 1.5).xyxy + w1 / s;
    c *= texPixelSize.xxyy;

    vec2 m = s.xz / (s.xz + s.yw);
    return mix(mix(textureLod(texSampler, c.yw, 0.0), textureLod(texSampler, c.xw, 0.0), m.x),
                mix(textureLod(texSampler, c.yz, 0.0), textureLod(texSampler, c.xz, 0.0), m.x),
                m.y);
}


void main(){
	vec2 originSize = vec2(0.25);
	const float intervalWidth = 3.0;

	vec2 tCoord = texCoord * 2.0;
	vec2 border = pixelSize * 8.0 + 1.0;
	

	#if FSR2_SCALE >= 0
		float rainAlpha = textureLod(colortex0, tCoord * fsrRenderScale, 0).a;
	#else
		float rainAlpha = textureLod(colortex0, tCoord, 0).a;
	#endif
	//#ifdef DIMENSION_OVERWORLD
	//	rainAlpha = 1.0 - textureLod(colortex0, tCoord, 0.0).a;
	//	rainAlpha = saturate(rainAlpha * RAIN_VISIBILITY);
	//#endif

	vec2 coord = texCoord;
	vec2 sampleOrigin = vec2(0.0);

	vec3 bloom = vec3(0.0);
	if (tCoord.x <= border.x && tCoord.y <= border.y){

		bloom += BicubicBlurTexture(colortex2, coord * 0.5, screenSize).rgb * 1.0;

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.25 - sampleOrigin, screenSize).rgb * mix(1.0, 0.83333333, rainAlpha);

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.125 - sampleOrigin, screenSize).rgb * mix(1.0, 0.69444444, rainAlpha);

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.0625 - sampleOrigin, screenSize).rgb * mix(1.0, 0.57870370, rainAlpha);

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.03125 - sampleOrigin, screenSize).rgb * mix(1.0, 0.48225309, rainAlpha);

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.015625 - sampleOrigin, screenSize).rgb * mix(1.0, 0.40187757, rainAlpha);

		sampleOrigin.x -= originSize.x + pixelSize.x * intervalWidth;
		originSize *= 0.5;
		bloom += BicubicBlurTexture(colortex2, coord * 0.0078125 - sampleOrigin, screenSize).rgb * mix(1.0, 0.33489798, rainAlpha);

	}

	bloom *= mix(0.2774, 1.2 / 7.0, rainAlpha); // 0.23118661

	framebuffer2 = vec4(bloom, 0.0);
}
