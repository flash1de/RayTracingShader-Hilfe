

uniform sampler2D ripple2D;


float Get3DNoise(vec3 pos){
	vec3 p = floor(pos);
	vec3 f = pos - p;
	//f = curve(f);

	vec2 uv = vec2(55.0, 0.0) * p.y + p.xz + f.xz;
	vec2 noise = textureLod(noisetex, uv / 128.0, 0.0).zw;

	return mix(noise.x, noise.y, f.y);
}

float GetModulatedRainSpecular(vec3 pos){
	pos.xz *= 5.0;

	float n = Get3DNoise(pos);
		  n += Get3DNoise(pos * 0.37) * 3.0;

	return saturate(1.0 - n * 0.25) * 0.7 + 0.3;
}


vec2 GetRippleNormal(vec2 pos, float wet, float splashStrength){
	vec2 coord = fract(pos * (0.5 / RAIN_SPLASH_SCALE)) * (127.0 / 128.0) + (0.5 / 128.0);
	coord.y = coord.y * (1.0 / 60.0) + floor(fract(frameTimeCounter * RAIN_SPLASH_SPEED) * 60.0) * (1.0 / 60.0);
	//coord.y = coord.y * (1.0 / 60.0) + 0.5;

	vec3 ripple = textureLod(ripple2D, coord, 0.0).xyz;
	ripple.z = saturate(ripple.z - saturate(0.035 - wet * 0.055));
	ripple.z *= saturate(wet * 2.0 - 1.0) * 0.5 + 0.5;
	ripple.z *= splashStrength * (0.8 * RAIN_SPLASH_STRENGTH);

	vec2 rippleNormal = (ripple.xy * 2.0 - 1.0) * ripple.z;

	return rippleNormal;
}