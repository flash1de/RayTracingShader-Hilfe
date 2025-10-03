

#include "/Lib/IndividualFunctions/EndSkyTimer.glsl"


vec3 HashStars(vec3 worldDir, vec3 lightDir){
	float angleY = frameTimeCounter * 0.001;
	mat3 eyeRoataionMatrixY = mat3(cos(angleY), 0, sin(angleY), 0, 1, 0, -sin(angleY), 0, cos(angleY));

	worldDir = eyeRoataionMatrixY * worldDir;

	#if FSR2_SCALE >= 0
		const float scale = 300.0 - float(FSR2_SCALE) * 40.0;
		const float coverage = 0.007 + FSR2_SCALE * 0.003;
	#else
		const float scale = 384.0;
		const float coverage = 0.007;
	#endif
	const float maxLuminance = 0.03;
	const float minTemperature = 4000.0;
	const float maxTemperature = 9000.0;

	float cosine = dot(lightDir,  vec3(0, 0, 1));
	vec3 axis = cross(lightDir,  vec3(0, 0, 1));
	float cosecantSquared = 1.0 / dot(axis, axis);
	worldDir = cosine * worldDir + cross(axis, worldDir) + (cosecantSquared - cosecantSquared * cosine) * dot(axis, worldDir) * axis;

	vec3  p = worldDir * scale;
	ivec3 i = ivec3(floor(p));
	vec3  f = p - i;
	float r = dot(f - 0.5, f - 0.5);

	vec3 i3 = fract(i * vec3(443.897, 441.423, 437.195));
	i3 += dot(i3, i3.yzx + 19.19);
	vec2 hash = fract((i3.xx + i3.yz) * i3.zy);
	hash.y = 2.0 * hash.y - 4.0 * hash.y * hash.y + 3.0 * hash.y * hash.y * hash.y;

	float c = remapSaturate(hash.x, 1.0 - coverage, 1.0);
	return (maxLuminance * remapSaturate(r, 0.25, 0.0) * c * c) * Blackbody(mix(minTemperature, maxTemperature, hash.y));
}


vec3 H(vec3 albedo, float a){
	vec3 R = sqrt(vec3(1.0) - albedo);
	vec3 r = (1.0 - R) / (1.0 + R);
	vec3 H = r + (0.5 - r * a) * log((1.0 + a) / a);
	H *= albedo * a;

	return 1.0 / (1.0 - H);
}

vec3 ppss(vec3 albedo, vec3 normal, vec3 eyeDir, vec3 lightDir){
	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, eyeDir);
	albedo *= curve(saturate(NdotL));

	vec3 color = albedo * H(albedo, NdotL) * H(albedo, NdotV) / (4.0 * PI * (NdotL + NdotV));

	return saturate(color);
}

float Disc(float a, float s, float h){
	float disc = curve(saturate((a - (1.0 - s)) * h));
	return disc * disc;
}


void PlanetEnd2(inout vec3 color, vec3 eye, vec3 rayDir){
	const float Rground = 20e6;
	const float Ratmo = 20.1e6;
	eye.y += Rground;
	eye.y += 15e6;

	vec3 lightDir = shadowModelViewInverseEnd[2];

	float VdotL = dot(lightDir, rayDir);

	float mie = MiePhaseFunction(0.8, VdotL);

	float angleX = -1.57079633 + (0.2 * sin(timeFactor + 3.0) - 0.1);
	float angleY = timeFactor;

	mat3 eyeRoataionMatrixX = mat3(1, 0, 0, 0, cos(angleX), -sin(angleX), 0, sin(angleX), cos(angleX));
	mat3 eyeRoataionMatrixY = mat3(cos(angleY), 0, sin(angleY), 0, 1, 0, -sin(angleY), 0, cos(angleY));
	mat3 eyeRoataionMatrix = eyeRoataionMatrixX * eyeRoataionMatrixY;

	float ringAngle = 0.008 * sin(timeFactor + 4.6);

	mat3 ringRoataionMatrix = mat3(1.0, 0.0, 0.0,
								   0.0, cos(ringAngle), sin(ringAngle),
								   0.0, -sin(ringAngle), cos(ringAngle));
	mat3 ringRoataionMatrixInverse = transpose(ringRoataionMatrix);



	rayDir = eyeRoataionMatrix * rayDir;
	lightDir = eyeRoataionMatrix * lightDir;

	vec3 rayDirRing = ringRoataionMatrix * rayDir;
	vec3 lightDirRing = ringRoataionMatrix * lightDir;

	vec3 ringOrigin = vec3(0.0, cos(ringAngle), sin(ringAngle)) * (eye.y / Rground);
	vec2 ringRadius = vec2(1.6, 2.6);



	vec3 surface = vec3(0.0);
	float LdotR = dot(rayDir, -lightDir);

	vec2 groundIntersection = RaySphereIntersection(eye, rayDir, Rground);
	vec2 topAtmoIntersection = RaySphereIntersection(eye, rayDir, Ratmo);


	vec3 surfacePos = rayDir * groundIntersection.x;
	vec3 surfaceNormal = normalize(surfacePos + vec3(0.0, eye.y, 0.0));

	if (groundIntersection.y > 0.0){
		color *= 0.0;

		const vec3 surfaceAlbedo = vec3(0.98, 0.87, 0.55) * 0.96;

		surface = ppss(surfaceAlbedo, surfaceNormal, -rayDir, lightDir);

		#ifdef END_PLANET_WEAK_DIFFUSE
			surface *= 0.4;
		#endif

		vec3 origin = ringOrigin + surfacePos / Rground;
		vec3 rayPos = RayPlaneIntersection(origin, lightDirRing, vec3(0.0, 0.0, 1.0));
		float rayRadius = length(rayPos);

		if (rayRadius > ringRadius.x && rayRadius < ringRadius.y && dot(rayPos - origin, lightDirRing) > 0.0){
			float position = rayRadius * 15.0 + 6.0;

			float accum = 0.0;
			float alpha = 0.5;

			for (int i = 0; i < 4; i++) {
				accum += alpha * HashWellons32_Linear(position);
				position *= 4.0;
				alpha *= 0.45;
			}

			surface *= exp(-CurveToLinear(saturate(accum - 0.1) * 1.6) * smoothstep(ringRadius.x, ringRadius.x * 1.1, rayRadius));
		}


		float UdotN = saturate(dot(ringRoataionMatrixInverse[2], surfaceNormal));
		float DdotN = saturate(dot(-ringRoataionMatrixInverse[2], surfaceNormal));
		float OLdotN = saturate(dot(ringRoataionMatrixInverse * normalize(vec3(-lightDir.xy, 0.0)), surfaceNormal));

		float ringLighting = Disc(UdotN, 1.2, 1.5) * (1.0 - Disc(UdotN, 3.4, 0.3));
		ringLighting += Disc(DdotN, 1.2, 1.5) * (1.0 - Disc(DdotN, 3.4, 0.3));
		ringLighting *= 1.0 - Disc(OLdotN, 0.7, 1.3);

		surface += surfaceAlbedo * (1.5e-4 + ringLighting * 0.01);
	}

	if (topAtmoIntersection.y > 0.0){
		float isGround = step(0.0, groundIntersection.y);
		float thickness = (topAtmoIntersection.y - topAtmoIntersection.x - (groundIntersection.y - groundIntersection.x) * isGround) * 1e-7;
		float topAtmoMie = mie * thickness * thickness;
		topAtmoMie *= mix(1.0, smoothstep(0.9, 0.4, dot(surfaceNormal, normalize(eye))), isGround);
		surface += topAtmoMie * vec3(0.65, 0.7, 1.0);
	}

	color += surface * 0.9;


	float inRing = saturate(abs(ringAngle) * 3000.0 - 0.8);

	float ring = 0.0;
	float transmittance = 1.0;

	if (rayDirRing.z * ringAngle < 0.0){

		vec3 origin = vec3(0.0, cos(ringAngle), sin(ringAngle)) * (eye.y / Rground);

		vec3 ringPos = RayPlaneIntersection(origin, rayDirRing, vec3(0.0, 0.0, 1.0));
		float rayRadius = length(ringPos);
		vec2 ringRadius = vec2(1.6, 2.6);


		if(rayRadius > ringRadius.x && rayRadius < ringRadius.y){
			float position = rayRadius * 15.0 + 6.0;

			float accum = 0.0;
			float alpha = 0.5;

			for (int i = 0; i < 6; i++) {
				accum += alpha * HashWellons32_Linear(position);
				position *= 4.0;
				alpha *= 0.45;
			}

			ring = CurveToLinear(saturate(accum - 0.15) * 1.4);
			ring *= smoothstep(ringRadius.x, ringRadius.x * 1.1, rayRadius);

			if(ringPos.y < 0.0 && groundIntersection.y > 0.0){
				ring *= 0.0;
			}else{
				transmittance *= exp2(-ring * 2.5);
			}

			float d = length(cross(lightDirRing, ringPos));
			ring *= 0.98 * max(smoothstep(0.8, 1.2, d), step(0.0, dot(lightDirRing, ringPos))) + 0.02;

		}
	}

	ring = mix(planetShadow * 0.49 + 0.01, ring, inRing);
	ring *= 1.0 + mie * 10.0 * planetShadow;

	transmittance = mix(0.7, transmittance, inRing);

	color *= transmittance;
	color += ring * (0.04 * vec3(1.0, 0.85, 0.60));
}



//www.shadertoy.com/view/lstSRS

mat3 RotateMatrix(float x, float y, float z){
	mat3 matx = mat3(1.0, 0.0, 0.0,
					 0.0, cos(x), sin(x),
					 0.0, -sin(x), cos(x));

	mat3 maty = mat3(cos(y), 0.0, -sin(y),
					 0.0, 1.0, 0.0,
					 sin(y), 0.0, cos(y));

	mat3 matz = mat3(cos(z), sin(z), 0.0,
					 -sin(z), cos(z), 0.0,
					 0.0, 0.0, 1.0);

	return maty * matx * matz;
}


float Get3DNoise(vec3 pos){
	vec3 p = floor(pos);
	vec3 f = pos - p;

	vec2 uv = vec2(55.0, 0.0) * p.y + p.xz + f.xz;
	vec2 noise = textureLod(noisetex, uv / 128.0, 0.0).zw;

	return mix(noise.x, noise.y, f.y);
}


void BlackHole_AccretionDisc_Stars(inout vec3 color, vec3 rayDir, vec3 lightDir){
	vec3 eye = -lightDir * 8.0;
	vec3 rayPos = eye + rayDir * 3.0;

	mat3 rotation = RotateMatrix(0.1, 0.0, -0.265 - ACCRETIONDISC_ANGLE * PI / 180.0);


	vec3 result = vec3(0.0);
	float transmittance = 1.0;

	const float stepLength = 0.2;

	#if defined TAA || FSR2_SCALE >= 0
		float noise = BlueNoiseTemporal().x;
	#else
		float noise = IGN(gl_FragCoord.xy);
	#endif

	#ifdef BLACKHOLE_LQ
		rayPos += rayDir * noise * (stepLength * 2.0);
	#else
		rayPos += rayDir * noise * stepLength;
	#endif

	#ifdef BLACKHOLE_LQ
		for (int i = 0; i < 25; i++){
	#else
		for (int i = 0; i < 50; i++){
	#endif

		if(transmittance < 0.0001) break;

		vec3 discPos = rotation * rayPos;

		float r = length(discPos);
		float p = atan2(-discPos.zx);
		float h = discPos.y;


		float bloomDisc = length(vec2(length(discPos.xz) - 0.75, discPos.y + 0.02));
		bloomDisc = step(0.4, r) / (bloomDisc * bloomDisc * bloomDisc + 0.001);

		vec3 discColor = vec3(0.827, 0.994, 1.566) * (bloomDisc * 0.02);


		float discGradient = saturate(1.09 - r * 0.15);

		float thickness = 1.0 - (abs(h) / discGradient) * 20.0;
		float baseDensity = CurveToLinear(discGradient) * (1.0 - discGradient) * 12.207;
		float hazeDensity = saturate(thickness + 1.0) * 0.03 / (h * h + CurveToLinear(r - 0.1) * 1e-3);
		float density = saturate(mix(baseDensity * saturate(thickness), hazeDensity * hazeDensity, 0.1));

		if (density > 0.0001){
			#ifdef ACCRETIONDISC_DETAIL_ALONG_LONGTITUDE
				vec3 discCoord = vec3(r * 30.0, p * (4.0 - discGradient * 2.5), h * 8.0);
			#else
				vec3 discCoord = vec3(r * 30.0, 0.0, h * 8.0);
			#endif

			float fbm = 0.0;
			float alpha = 1.0;
			vec3 bias = frameTimeCounter * vec3(0.2, 0.1, 0.0);
			for (int i = 0; i < 4; i++) {
				fbm += alpha * Get3DNoise(discCoord);
				discCoord = (discCoord + bias) * 2.7;
				alpha *= 0.75;
			}
			fbm = saturate(fbm * 1.5 - 2.25) * 0.9 + 0.1;

			density *= fbm * baseDensity;

			float glowGradient = CurveToLinear(1.0 - discGradient);
			float glowStrength = 1.0 / (glowGradient * 200.0 + 0.002);

			float glowTemperature = 2700.0 + glowStrength * 20.0;
			#ifdef ACCRETIONDISC_DOPPLER_EFFECT
				float phase = sin(p - 1.07);
				glowTemperature *= phase * 0.25 + 1.0;
			#endif
			vec3 glow = mix(Blackbody(glowTemperature), vec3(1.15, 0.75, 1.35), 0.15 - glowGradient * 0.1) * glowStrength;
			#ifdef ACCRETIONDISC_DOPPLER_EFFECT
				glow *= phase * 0.8 + 1.0;
			#endif
			
			#ifdef BLACKHOLE_LQ
				float stepTransmittance = exp2(-density * 14.0);
			#else
				float stepTransmittance = exp2(-density * 7.0);
			#endif
			transmittance *= stepTransmittance;

			discColor += (1.0 - stepTransmittance) * glow;
		}

		result += discColor * transmittance;


		rayDir = normalize(rayDir - normalize(rayPos) / (r * r + 1e-20) * 0.06);
		rayPos += rayDir * stepLength;

		#ifdef BLACKHOLE_LQ
			r = length(rayPos);
			rayDir = normalize(rayDir - normalize(rayPos) / (r * r + 1e-20) * 0.06);
			rayPos += rayDir * stepLength;
		#endif
	}
	#ifdef BLACKHOLE_LQ
		result *= 0.04;
	#else
		result *= 0.02;
	#endif

	#if STAR_TYPE > 0
		color += HashStars(rayDir, lightDir);
	#endif

	color *= transmittance;

	color += result;
}

void EndFog(inout vec3 color, float dist, vec3 worldDir, vec3 lightDir){
	float VdotL = dot(lightDir, worldDir);

	float angleX = -1.57079633 + (0.2 * sin(timeFactor + 3.0) - 0.1) - 0.008 * sin(timeFactor + 4.7);
	float angleY = timeFactor;

	mat3 eyeRoataionMatrixX = mat3(1.0, 0.0, 0.0, 0.0, cos(angleX), -sin(angleX), 0.0, sin(angleX), cos(angleX));
	mat3 eyeRoataionMatrixY = mat3(cos(angleY), 0.0, sin(angleY), 0.0, 1.0, 0.0, -sin(angleY), 0.0, cos(angleY));
	mat3 eyeRoataionMatrix = eyeRoataionMatrixX * eyeRoataionMatrixY;

	worldDir = eyeRoataionMatrix * worldDir;

	dist = min(dist, 1024.0);
	float h = abs(worldDir.z) * dist * 0.03;
	float density = (1.0 - exp2(-h)) / h * dist;

	density *= MiePhaseFunction(0.4, VdotL) * (6e-5 * SUNLIGHT_INTENSITY) * planetShadow + (2e-6 * SUNLIGHT_INTENSITY);
	density *= planetShadow * 0.93 + 0.07;

	color += vec3(density);
}


void EndFog(inout vec3 color, float dist, float rayDist, vec3 worldDir, vec3 lightDir){
	float VdotL = dot(lightDir, worldDir);

	float angleX = -1.57079633 + (0.2 * sin(timeFactor + 3.0) - 0.1) - 0.008 * sin(timeFactor + 4.7);
	float angleY = timeFactor;

	mat3 eyeRoataionMatrixX = mat3(1.0, 0.0, 0.0, 0.0, cos(angleX), -sin(angleX), 0.0, sin(angleX), cos(angleX));
	mat3 eyeRoataionMatrixY = mat3(cos(angleY), 0.0, sin(angleY), 0.0, 1.0, 0.0, -sin(angleY), 0.0, cos(angleY));
	mat3 eyeRoataionMatrix = eyeRoataionMatrixX * eyeRoataionMatrixY;

	worldDir = eyeRoataionMatrix * worldDir;

	dist = min(dist, 1024.0);
	float h = abs(worldDir.z) * dist * 0.03;
	float density = (1.0 - exp2(-h)) / h * dist;

	rayDist = min(rayDist, 1024.0);
	float rh = abs(worldDir.z) * rayDist * 0.03;
	density = max((1.0 - exp2(-rh)) / rh * rayDist - density, 0.0);

	density *= MiePhaseFunction(0.4, VdotL) * (6e-5 * SUNLIGHT_INTENSITY) * planetShadow + (2e-6 * SUNLIGHT_INTENSITY);
	density *= planetShadow * 0.93 + 0.07;

	color += vec3(density);
}
