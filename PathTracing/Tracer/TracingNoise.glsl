



uint HashWellons(){
	return randSeed = HashWellons32(randSeed);
}

vec3 RandUnitVector(){
	vec2 noise = vec2(RandWellons(), RandWellons());
	vec2 randAngle = vec2(TAU * noise.x, acos(2.0 * noise.y - 1.0));
	return vec3(sin(randAngle.x) * sin(randAngle.y), cos(randAngle.x) * sin(randAngle.y), cos(randAngle.y));
}

vec3 HemisphereUnitVector(vec3 n){
	vec3 randVector = RandUnitVector();
	return randVector * fsign(dot(randVector, n));
}