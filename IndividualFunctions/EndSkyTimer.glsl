

#if END_MANUAL_PLANET_CYCLE >= 0
	const float timeFactor = fract(float(END_MANUAL_PLANET_CYCLE) / 360.0 + 0.282) * TAU;
#else
	float timeFactor = fract(frameTimeCounter * ((1.0 / 60.0) / END_PLANET_CYCLE) + 0.282) * TAU;
#endif

float planetShadow = smoothstep(0.62, 0.35, timeFactor) + smoothstep(1.6, 1.87, timeFactor);