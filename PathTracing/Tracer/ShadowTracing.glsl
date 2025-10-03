

float ShadowTracing(vec3 viewPos, vec3 worldPos, vec3 vertexNormal, vec3 lightVector, float lightMap){
	float shadow = 1.0;

	vec3 voxelPos = worldPos + voxelDistance + cameraPositionFract;
	voxelPos += vertexNormal * (-viewPos.z * 0.0003);

	if (clamp(voxelPos, vec3(0.0), vec3(voxelResolution)) == voxelPos){
		lightMap = saturate(1.0 - lightMap * 2.0);
		vec2 shadowWeight = vec2(
			4.0 - 2.0 * saturate(lightMap - viewPos.z * 0.01), 
			0.2 + 0.5 * saturate(lightMap - viewPos.z * 0.01)
		);

		Ray ray = PackRay(voxelPos, lightVector);

		vec3 voxelCoord = floor(ray.ori);
		vec3 totalStep = (ray.sdir * (voxelCoord - ray.ori + 0.5) + 0.5) * abs(ray.rdir);
		float rayLength = 0.0;
		vec3 tracingNext;

		bool hit = false;

		for (int i = 0; i < 4; i++){
			if (clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord) break;

			vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
			float voxelID = abs(floor(voxelData.z * 65535.0 - 999.9));

			if (voxelID <= 1.0){
				hit = rayLength > 0.0;
			}else if (abs(voxelID - 49.5) < 25.0){
				rayLength = minVec3(totalStep);
				hit = HitShape_Lite(ray, voxelCoord, voxelID, rayLength);
			}

			if (hit){
				shadow = saturate((rayLength - shadowWeight.y) * shadowWeight.x);
				break;
			}

			rayLength = minVec3(totalStep);
			tracingNext = step(totalStep, vec3(rayLength));
			voxelCoord += tracingNext * ray.sdir;
			totalStep += tracingNext * abs(ray.rdir);
		}
	}

	return shadow;
}


float SimpleShadowTracing(vec3 voxelPos, vec3 lightVector){
	Ray ray = PackRay(voxelPos, lightVector);

	vec3 voxelCoord = floor(ray.ori);
	vec3 totalStep = (ray.sdir * (voxelCoord - ray.ori + 0.5) + 0.5) * abs(ray.rdir);
	float rayLength = 0.0;
	vec3 tracingNext;

	bool hit = false;

	for (int i = 0; i < 3; i++){
		if (clamp(voxelCoord, vec3(0.0), vec3(voxelResolution - 0.5)) != voxelCoord) break;

		vec4 voxelData = texelFetch(voxelData3D, ivec3(voxelCoord), 0);
		float voxelID = abs(floor(voxelData.z * 65535.0 - 999.9));

		if (voxelID <= 1.0){
			hit = rayLength > 0.0;
		}else if (abs(voxelID - 49.5) < 25.0){
			rayLength = minVec3(totalStep);
			hit = HitShape_Lite(ray, voxelCoord, voxelID, rayLength);
		}

		if (hit) break;

		rayLength = minVec3(totalStep);
		tracingNext = step(totalStep, vec3(rayLength));
		voxelCoord += tracingNext * ray.sdir;
		totalStep += tracingNext * abs(ray.rdir);
	}

	return float(!hit);
}