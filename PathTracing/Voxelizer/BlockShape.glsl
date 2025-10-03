

float SphereIntersectionLength(Ray ray, vec3 blockOrigin, vec3 sphereOrigin, float sphereRadius){ // sphereRadius <= 0.5
	sphereOrigin = -blockOrigin - sphereOrigin;

	float b = dot(ray.dir, sphereOrigin);
	float c = dot(sphereOrigin, sphereOrigin) - sphereRadius * sphereRadius;
	float d = b * b - c;

	float intersectionLength = 0.0;

	if (d > 0.0){
		d = sqrt(d);
		intersectionLength = saturate(min(-b + d, d * 2.0));
	}

	return intersectionLength;
}

float BoxIntersectionLength(Ray ray, vec3 blockOrigin){
	vec3 boxMax = blockOrigin + 1.0;

	vec3 t1 = ray.rdir * blockOrigin;
	vec3 t2 = ray.rdir * boxMax;

	vec3 tMin = min(t1, t2);
	vec3 tMax = max(t1, t2);

	float tEnter = maxVec3(tMin);
	float tExit = minVec3(tMax);

	return max(tExit - tEnter, 0.0);
}

vec3 LightShpereColor(float voxelID){
	vec3 shpereColor = vec3(0.0);

	if (voxelID <= 244.0){
		if (voxelID == 242.0){ // Torch
			shpereColor = vec3(0.88, 0.42, 0.14) * 0.3 * SPHERELIGHT_BRIGHTNESS;
		}else if (abs(voxelID - 240.0) < 1.5){ // Fire
			shpereColor = vec3(0.88, 0.42, 0.14) * 1.8 * SPHERELIGHT_BRIGHTNESS;
		}else{ // Redstone Torch 243
			shpereColor = vec3(0.4, 0.08, 0.05) * 0.05 * SPHERELIGHT_BRIGHTNESS;
		}
	}else{
		if (voxelID == 245.0){ // Amethyst Cluster
			shpereColor = vec3(0.84, 0.52, 1.28) * 0.3 * SPHERELIGHT_BRIGHTNESS;
		}else if (voxelID == 246.0){ // Soul Torch
			shpereColor = vec3(0.4, 0.98, 1.0) * 0.3 * SPHERELIGHT_BRIGHTNESS;
		#ifdef DIFFUSE_TRACING
			}else if (abs(voxelID - 248.5) < 2.0){ // Candle & Sea Pickle  247 248 249 250
				shpereColor = (vec3(0.88, 0.42, 0.14) * 0.2 * SPHERELIGHT_BRIGHTNESS) * (voxelID * 0.15 - 36.9);
			}else{
				shpereColor = (vec3(COLOR_LIGHTBLOCK_R, COLOR_LIGHTBLOCK_G, COLOR_LIGHTBLOCK_B) * BRIGHTNESS_LIGHTBLOCK) * (voxelID * (1.0 / 15.0) - (255.0 / 15.0));
			}
		#else
			}else{ // Candle & Sea Pickle  247 248 249 250
				shpereColor = (vec3(0.88, 0.42, 0.14) * 0.2 * SPHERELIGHT_BRIGHTNESS) * (voxelID * 0.15 - 36.9);
			}
		#endif
	}

	return shpereColor;
}

vec3 HitLightShpere(Ray ray, vec3 voxelCoord, float voxelID, float rayLength){
	vec3 shpereLighting = vec3(0.0);

	vec3 blockOrigin = voxelCoord - ray.ori;
	float intersectionLength = SphereIntersectionLength(ray, blockOrigin, vec3(0.5), 0.5);

	if (intersectionLength > 0.0)
		intersectionLength = intersectionLength * intersectionLength;
		shpereLighting = LightShpereColor(voxelID) * (intersectionLength * BLOCKLIGHT_BRIGHTNESS);

	return shpereLighting;
}

vec3 HitLightShpereReflection(Ray ray, vec3 voxelCoord, float voxelID, float rayLength){
	vec3 shpereLighting = vec3(0.0);

	vec3 blockOrigin = voxelCoord - ray.ori;
	float intersectionLength = SphereIntersectionLength(ray, blockOrigin, vec3(0.5), 0.25);

	if (intersectionLength > 0.0)
		intersectionLength = intersectionLength * intersectionLength;
		intersectionLength = intersectionLength * intersectionLength * 50.0;
		shpereLighting = LightShpereColor(voxelID) * (intersectionLength * BLOCKLIGHT_BRIGHTNESS);

	return shpereLighting;
}

bool IsHitBox(Ray ray, vec3 blockOrigin, vec3 boxOrigin, vec3 boxSize, inout float rayLength, inout vec3 hitNormal){
	vec3 boxMin = blockOrigin + boxOrigin;
	vec3 boxMax = boxMin + boxSize;

	vec3 t1 = ray.rdir * boxMin;
	vec3 t2 = ray.rdir * boxMax;

	vec3 tMin = min(t1, t2);
	vec3 tMax = max(t1, t2);

	float tEnter = maxVec3(tMin);
	float tExit = minVec3(tMax);

	bool hit = min(rayLength, tExit) >= tEnter && tExit >= 0.0;

	if (hit){
		hitNormal = -step(vec3(tEnter), tMin) * ray.sdir;
		rayLength = tEnter;
	}

	return hit;
}


#ifdef SHOW_TODO
#error "block shape : Optimize shape structure"
#endif

bool HitShape(Ray ray, vec3 voxelCoord, float voxelID, inout float rayLength, out vec3 hitNormal, out vec2 coordOffset){
	vec3 blockOrigin = voxelCoord - ray.ori;
	hitNormal = vec3(0.0);
	coordOffset = vec2(0.0);

	bool hit = false;

	const float rotIndex[8] = float[8](1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0);

	if (voxelID <= 8.0){ // Door

		int rotID = int(voxelID - 5.0);
		float rotCos = rotIndex[rotID];
		float rotSin = rotIndex[rotID + 4];
		mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

		vec3 ori = vec3(-0.5);
		ori.xz = ori.xz * rot;
		ori += vec3(0.5);
		vec3 size = vec3(1.0, 1.0, 3.0 / 16.0);
		size.xz = size.xz * rot;

		hit = IsHitBox(ray, blockOrigin, ori, size, rayLength, hitNormal);


	}else if (voxelID <= 24.0){ // Stained Glass Pane

		hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 7.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal);

		if (voxelID >= 10.0){
			int fenceID = int(voxelID - 10.0);
			int shapeID = fenceID & 3;
			int rotID = fenceID >> 2;
			float rotCos = rotIndex[rotID];
			float rotSin = rotIndex[rotID + 4];
			mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

			vec2 ori0 = vec2(-1.0 / 16.0, 0.0) * rot;
			ori0 += vec2(0.5);
			vec2 size0 = vec2(2.0 / 16.0, -0.5) * rot;

			vec2 ori1 = vec2(0.5, -1.0 / 16.0) * rot;
			ori1 += vec2(0.5);
			vec2 size1 = vec2(shapeID <= 1 ? -0.5 : -1.0, 2.0 / 16.0) * rot;

			if (shapeID <= 2){
				hit = IsHitBox(ray, blockOrigin, vec3(ori0.x, 0.0, ori0.y), vec3(size0.x, 1.0, size0.y), rayLength, hitNormal) || hit;
			}
			if (shapeID >= 1){
				hit = IsHitBox(ray, blockOrigin, vec3(ori1.x, 0.0, ori1.y), vec3(size1.x, 1.0, size1.y), rayLength, hitNormal) || hit;
			}
			if (voxelID == 21.0){
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal) || hit;
			}
		}


	}else if (voxelID <= 48.0){ // Stairs

		int stairsID = int(voxelID - 25.0);
		int shapeID = stairsID % 3;
		int rotID = stairsID % 12 / 3;
		float rotCos = rotIndex[rotID];
		float rotSin = rotIndex[rotID + 4];
		mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

		vec3 ori0 = vec3(0.0);
		vec3 size0 = vec3(1.0, 0.5, 1.0);

		vec3 ori1 = vec3(-0.5, 0.0, -0.5);
		ori1.xz = ori1.xz * rot;
		ori1 += vec3(0.5);
		vec3 size1 = vec3(1.0, 0.5, 0.5);
		size1.xz = size1.xz * rot;

		vec3 ori2 = vec3(0.5);
		vec3 size2 = vec3(-0.5, 0.5, 0.5);
		size2.xz = size2.xz * rot;

		if (stairsID >= 12){
			ori0.y += 0.5;
			ori1.y -= 0.5;
			ori2.y -= 0.5;
		}

		hit = IsHitBox(ray, blockOrigin, ori0, size0, rayLength, hitNormal);
		if (shapeID <= 1) hit = IsHitBox(ray, blockOrigin, ori1, size1, rayLength, hitNormal) || hit;
		if (shapeID >= 1) hit = IsHitBox(ray, blockOrigin, ori2, size2, rayLength, hitNormal) || hit;


	}else if (voxelID <= 66.0){ // Top / Bottom Cutted
	
		if (voxelID == 53.0){ // Hopper
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 1.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 14.0 / 16.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(4.0 / 16.0, 4.0 / 16.0, 4.0 / 16.0), vec3(8.0 / 16.0, 6.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal) || hit;

		}else if (voxelID == 55.0){ // Top Trapdoor
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 13.0 / 16.0, 0.0), vec3(1.0, 3.0 / 16.0, 1.0), rayLength, hitNormal);

		}else if (voxelID == 59.0){ // Composter
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 2.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 14.0 / 16.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength, hitNormal) || hit;

		}else if (voxelID <= 63.0){ // Top Cutted
			hit = IsHitBox(ray, blockOrigin, vec3(0.0), vec3(1.0, voxelID * 0.0625 - 3.0, 1.0), rayLength, hitNormal);

		}else{ // Bottom Cutted
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, -voxelID * 0.25 + 16.75, 0.0), vec3(1.0, voxelID * 0.25 - 15.75, 1.0), rayLength, hitNormal);
		}

	}else if (voxelID <= 74.0){ // Piston
	
		if (voxelID <= 68.0){ // Piston N
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, voxelID * 0.5 - 33.25), vec3(1.0, 1.0, -voxelID * 0.5 + 34.25), rayLength, hitNormal);

		}else if (voxelID <= 70.0){ // Piston W
			hit = IsHitBox(ray, blockOrigin, vec3(voxelID * 0.5 - 34.25, 0.0, 0.0), vec3(-voxelID * 0.5 + 35.25, 1.0, 1.0), rayLength, hitNormal);

		}else if (voxelID <= 72.0){ // Piston S
			hit = IsHitBox(ray, blockOrigin, vec3(0.0), vec3(1.0, 1.0, -voxelID * 0.5 + 36.25), rayLength, hitNormal);

		}else{ // Piston E
			hit = IsHitBox(ray, blockOrigin, vec3(0.0), vec3(-voxelID * 0.5 + 37.25, 1.0, 1.0), rayLength, hitNormal);
		}


	}else if (voxelID <= 114.0){ // Wall
		
		if (voxelID == 89.0){ // Cauldron
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(2.0 / 16.0, 13.0 / 16.0, 1.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(1.0, 1.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(1.0, 13.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0, 0.0), vec3(2.0 / 16.0, 13.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 14.0 / 16.0), vec3(1.0, 13.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;

			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(12.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 12.0 / 16.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(12.0 / 16.0, 0.0, 12.0 / 16.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;

		}else if (voxelID == 90.0){ // Scaffolding
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 14.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 14.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal) || hit;

		}else if (voxelID == 105.0){ // anvil NS
			hit = IsHitBox(ray, blockOrigin, vec3(2.0 / 16.0, 0.0, 2.0 / 16.0), vec3(12.0 / 16.0, 4.0 / 16.0, 12.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 3.0 / 16.0), vec3(8.0 / 16.0, 5.0 / 16.0, 10.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 4.0 / 16.0), vec3(4.0 / 16.0, 10.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(3.0 / 16.0, 10.0 / 16.0, 0.0), vec3(10.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal) || hit;

		}else if (voxelID == 106.0){ // anvil WE
			hit = IsHitBox(ray, blockOrigin, vec3(2.0 / 16.0, 0.0, 2.0 / 16.0), vec3(12.0 / 16.0, 4.0 / 16.0, 12.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(3.0 / 16.0, 0.0, 4.0 / 16.0), vec3(10.0 / 16.0, 5.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 6.0 / 16.0), vec3(8.0 / 16.0, 10.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 3.0 / 16.0), vec3(1.0, 6.0 / 16.0, 10.0 / 16.0), rayLength, hitNormal) || hit;

		}else if (voxelID == 80.0){ // Wall None
			hit = IsHitBox(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 4.0 / 16.0), vec3(0.5, 1.0, 0.5), rayLength, hitNormal);

		}else if (voxelID <= 82.0){ // Wall 4
			float height = (14.0 + 2.0 * step(voxelID, 81.0)) / 16.0;

			hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 0.0), vec3(6.0 / 16.0, height, 1.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 5.0 / 16.0), vec3(1.0, height, 6.0 / 16.0), rayLength, hitNormal) || hit;

		}else{
			float height = (14.0 + 2.0 * step(voxelID, 98.0)) / 16.0;

			int wallID = int(voxelID - 83.0);
			int shapeID = wallID % 16 / 4;
			int rotID = wallID % 4;
			float rotCos = rotIndex[rotID];
			float rotSin = rotIndex[rotID + 4];
			mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

			vec3 ori0 = vec3(-3.0 / 16.0, -0.5, -0.5);
			ori0.xz = ori0.xz * rot;
			ori0 += vec3(0.5);
			vec3 size0 = vec3(6.0 / 16.0, height, 11.0 / 16.0);
			size0.xz = size0.xz * rot;

			vec3 ori1 = vec3(0.5, -0.5, -3.0 / 16.0);
			ori1.xz = ori1.xz * rot;
			ori1 += vec3(0.5);
			vec3 size1 = vec3(shapeID <= 1 ? -1.0 : -11.0 / 16.0, height, 6.0 / 16.0);
			size1.xz = size1.xz * rot;

			if (shapeID != 1) hit = IsHitBox(ray, blockOrigin, ori0, size0, rayLength, hitNormal);
			if (shapeID != 3) hit = IsHitBox(ray, blockOrigin, ori1, size1, rayLength, hitNormal) || hit;
		}

	}else if (voxelID <= 142.0){ // Fence

		if (voxelID <= 130.0){ // Fence

			hit = IsHitBox(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 6.0 / 16.0), vec3(4.0 / 16.0, 1.0, 4.0 / 16.0), rayLength, hitNormal);

			if (voxelID >= 116.0){
				int fenceID = int(voxelID - 116.0);
				int shapeID = fenceID % 4;
				int rotID = fenceID / 4;
				float rotCos = rotIndex[rotID];
				float rotSin = rotIndex[rotID + 4];
				mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

				vec2 ori0 = vec2(-1.0 / 16.0, 0.0) * rot;
				ori0 += vec2(0.5);
				vec2 size0 = vec2(2.0 / 16.0, -0.5) * rot;

				vec2 ori1 = vec2(0.5, -1.0 / 16.0) * rot;
				ori1 += vec2(0.5);
				vec2 size1 = vec2(shapeID <= 1 ? -0.5 : -1.0, 2.0 / 16.0) * rot;

				if (shapeID <= 2){
					hit = IsHitBox(ray, blockOrigin, vec3(ori0.x, 6.0 / 16.0, ori0.y), vec3(size0.x, 3.0 / 16.0, size0.y), rayLength, hitNormal) || hit;
					hit = IsHitBox(ray, blockOrigin, vec3(ori0.x, 12.0 / 16.0, ori0.y), vec3(size0.x, 3.0 / 16.0, size0.y), rayLength, hitNormal) || hit;
				}
				if (shapeID >= 1){
					hit = IsHitBox(ray, blockOrigin, vec3(ori1.x, 6.0 / 16.0, ori1.y), vec3(size1.x, 3.0 / 16.0, size1.y), rayLength, hitNormal) || hit;
					hit = IsHitBox(ray, blockOrigin, vec3(ori1.x, 12.0 / 16.0, ori1.y), vec3(size1.x, 3.0 / 16.0, size1.y), rayLength, hitNormal) || hit;
				}
				if (voxelID == 127.0){
					hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 6.0 / 16.0, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
					hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 12.0 / 16.0, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
				}
			}


		}else if (voxelID <= 136.0){ // Fence Gate NS

			float heightOffset = 3.0 * step(voxelID, 133.0) / 16.0;
			float shapeID = mod(voxelID, 3.0);

			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 2.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 2.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;

			if (shapeID == 2.0){
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(1.0, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(1.0, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(6.0 / 16.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			}else if (shapeID == 0.0){
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 9.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			}else{
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 13.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 13.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			}


		}else{ // Fence Gate WE

			float heightOffset = 3.0 * step(voxelID, 139.0) / 16.0;
			float shapeID = mod(voxelID, 3.0);

			hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 2.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 2.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;

			if (shapeID == 2.0){
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 6.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			}else if (shapeID == 0.0){
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 9.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			}else{
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(13.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
				hit = IsHitBox(ray, blockOrigin, vec3(13.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal) || hit;
			}
		}


	}else if (abs(voxelID - 199.0) < 41.5){ // Light Source [158, 240]
		if (voxelID <= 219.0){
			uint lichenID = uint(voxelID - 157.0);
			if (bool(lichenID & 32u)){ // down
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 5e-6, 0.0), vec3(1.0, 5e-6, 1.0), rayLength, hitNormal);
			}
			if (bool(lichenID & 16u)){ // up
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 1.0 - 5e-6, 0.0), vec3(1.0, 5e-6, 1.0), rayLength, hitNormal) || hit;
			}
			if (bool(lichenID & 8u)){ // north
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 5e-6), vec3(1.0, 1.0, 5e-6), rayLength, hitNormal) || hit;
			}
			if (bool(lichenID & 4u)){ // east
				hit = IsHitBox(ray, blockOrigin, vec3(1.0 - 5e-6, 0.0, 0.0), vec3(5e-6, 1.0, 1.0), rayLength, hitNormal) || hit;
			}
			if (bool(lichenID & 2u)){ // south
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 1.0 - 5e-6), vec3(1.0, 1.0, 5e-6), rayLength, hitNormal) || hit;
			}
			if (bool(lichenID & 1u)){ // west
				hit = IsHitBox(ray, blockOrigin, vec3(5e-6, 0.0, 0.0), vec3(5e-6, 1.0, 1.0), rayLength, hitNormal) || hit;
			}

		}else if (voxelID == 220.0){ // Lantern
			hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 6.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;

			#ifndef PT_TEMP_COORD_OFFSET
				coordOffset = vec2(-5.0 / 16.0, -7.0 / 16.0);
			#endif

		}else if (voxelID == 221.0){ // Lantern Hanging
			hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 1.0 / 16.0, 5.0 / 16.0), vec3(6.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(6.0 / 16.0, 1.0 / 16.0, 6.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;

			#ifdef PT_TEMP_COORD_OFFSET
				coordOffset = vec2(5.0 / 16.0, -5.0 / 16.0);
			#else
				coordOffset = vec2(-5.0 / 16.0, -6.0 / 16.0);
			#endif

		}else if (abs(voxelID - 223.0) < 1.5){ // End Rod
			if (voxelID == 222.0){ // End Rod X
				hit = IsHitBox(ray, blockOrigin, vec3(0.0, 7.0 / 16.0, 7.0 / 16.0), vec3(1.0, 2.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal);

			}else if (voxelID == 223.0){ // End Rod Y
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 7.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal);

			}else{ // End Rod Z
				hit = IsHitBox(ray, blockOrigin, vec3(7.0 / 16.0, 7.0 / 16.0, 0.0), vec3(2.0 / 16.0, 2.0 / 16.0, 1.0), rayLength, hitNormal);
			}

		}else if (voxelID == 235.0 || voxelID == 237.0 || voxelID == 239.0){ // Campfire NS
			hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 0.0), vec3(14.0 / 16.0, 1.0 / 16.0, 1.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(11.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 1.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 11.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;

		}else{ // Campfire WE // 236 238 240
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 1.0 / 16.0), vec3(1.0, 1.0 / 16.0, 14.0 / 16.0), rayLength, hitNormal);
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 1.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(0.0, 0.0, 11.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
			hit = IsHitBox(ray, blockOrigin, vec3(11.0 / 16.0, 3.0 / 16.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal) || hit;
		}


	}else if (voxelID == 143.0){ // Pressure Plate

		hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 1.0 / 16.0), vec3(14.0 / 16.0, 1.0 / 16.0, 14.0 / 16.0), rayLength, hitNormal);


	}else if (voxelID == 144.0){ // Pressure Plate Powered

		hit = IsHitBox(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 1.0 / 16.0), vec3(14.0 / 16.0, 0.5 / 16.0, 14.0 / 16.0), rayLength, hitNormal);


/*
	}else if (voxelID == 145.0){ // Flower Pot

		hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 6.0 / 16.0, 1.0 / 16.0), rayLength, hitNormal);
		hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(1.0 / 16.0, 6.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal) || hit;
		hit = IsHitBox(ray, blockOrigin, vec3(10.0 / 16.0, 0.0, 5.0 / 16.0), vec3(1.0 / 16.0, 6.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal) || hit;
		hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 10.0 / 16.0), vec3(6.0 / 16.0, 6.0 / 16.0, 1.0 / 16.0), rayLength, hitNormal) || hit;
		hit = IsHitBox(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 4.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal) || hit;

*/
	}

	return hit;
}

bool IsHitBlock(Ray ray, vec3 totalStep, vec3 tracingNext, vec3 voxelCoord, float voxelID, inout float rayLength, out vec3 hitNormal, out vec2 coordOffset){
	hitNormal = vec3(0.0);
	coordOffset = vec2(0.0);
	
	bool hit = true;

	if (voxelID <= 4.0){
		hitNormal = -tracingNext * ray.sdir;
	}else{
		rayLength = minVec3(totalStep);
		hit = HitShape(ray, voxelCoord, voxelID, rayLength, hitNormal, coordOffset);
	}

	return hit;
}









bool IsHitBox_Lite(Ray ray, vec3 blockOrigin, vec3 boxOrigin, vec3 boxSize, inout float rayLength){
	vec3 boxMin = blockOrigin + boxOrigin;
	vec3 boxMax = boxMin + boxSize;

	vec3 t1 = ray.rdir * boxMin;
	vec3 t2 = ray.rdir * boxMax;

	vec3 tMin = min(t1, t2);
	vec3 tMax = max(t1, t2);

	float tEnter = maxVec3(tMin);
	float tExit = minVec3(tMax);

	bool hit = min(rayLength, tExit) >= tEnter && tExit >= 0.0;

	if (hit) rayLength = tEnter;

	return hit;
}


bool HitShape_Lite(Ray ray, vec3 voxelCoord, float voxelID, inout float rayLength){
	vec3 blockOrigin = voxelCoord - ray.ori;

	bool hit = false;

	const float rotIndex[8] = float[8](1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0);

	if (voxelID <= 48.0){ // Stairs

		int stairsID = int(voxelID - 25.0);
		int shapeID = stairsID % 3;
		int rotID = stairsID % 12 / 3;
		float rotCos = rotIndex[rotID];
		float rotSin = rotIndex[rotID + 4];
		mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

		vec3 ori0 = vec3(0.0);
		vec3 size0 = vec3(1.0, 0.5, 1.0);

		vec3 ori1 = vec3(-0.5, 0.0, -0.5);
		ori1.xz = ori1.xz * rot;
		ori1 += vec3(0.5);
		vec3 size1 = vec3(1.0, 0.5, 0.5);
		size1.xz = size1.xz * rot;

		vec3 ori2 = vec3(0.5);
		vec3 size2 = vec3(-0.5, 0.5, 0.5);
		size2.xz = size2.xz * rot;

		if (stairsID >= 12){
			ori0.y += 0.5;
			ori1.y -= 0.5;
			ori2.y -= 0.5;
		}

		hit = IsHitBox_Lite(ray, blockOrigin, ori0, size0, rayLength);
		if (shapeID <= 1) hit = IsHitBox_Lite(ray, blockOrigin, ori1, size1, rayLength) || hit;
		if (shapeID >= 1) hit = IsHitBox_Lite(ray, blockOrigin, ori2, size2, rayLength) || hit;


	}else if (voxelID <= 66.0){ // Top / Bottom Cutted
	
		if (voxelID == 53.0){ // Hopper
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength);
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 1.0 / 16.0, 1.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(14.0 / 16.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 14.0 / 16.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(4.0 / 16.0, 4.0 / 16.0, 4.0 / 16.0), vec3(8.0 / 16.0, 6.0 / 16.0, 8.0 / 16.0), rayLength) || hit;

		}else if (voxelID == 51.0 || voxelID == 55.0){ // Top Trapdoor


		}else if (voxelID == 59.0){ // Composter
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength);
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 2.0 / 16.0, 1.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength) || hit;
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 0.0, 14.0 / 16.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength) || hit;

		}else if (voxelID <= 63.0){ // Top Cutted
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0), vec3(1.0, voxelID * 0.0625 - 3.0, 1.0), rayLength);

		}else{ // Bottom Cutted
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, -voxelID * 0.25 + 16.75, 0.0), vec3(1.0, voxelID * 0.25 - 15.75, 1.0), rayLength);
		}

	}else{ // Piston
	
		if (voxelID <= 68.0){ // Piston N
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0, 0.0, voxelID * 0.5 - 33.25), vec3(1.0, 1.0, -voxelID * 0.5 + 34.25), rayLength);

		}else if (voxelID <= 70.0){ // Piston W
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(voxelID * 0.5 - 34.25, 0.0, 0.0), vec3(-voxelID * 0.5 + 35.25, 1.0, 1.0), rayLength);

		}else if (voxelID <= 72.0){ // Piston S
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0), vec3(1.0, 1.0, -voxelID * 0.5 + 36.25), rayLength);

		}else{ // Piston E
			hit = IsHitBox_Lite(ray, blockOrigin, vec3(0.0), vec3(-voxelID * 0.5 + 37.25, 1.0, 1.0), rayLength);
		}


	}

	return hit;
}










bool IsHitBox_FromOrigin_WithInternalIntersection(Ray ray, vec3 blockOrigin, vec3 boxOrigin, vec3 boxSize, inout float rayLength, inout vec3 hitNormal, inout bool eliminated){
	bool hit = true;

	if (!eliminated){
		vec3 boxMin = blockOrigin + boxOrigin;
		vec3 boxMax = boxMin + boxSize;

		vec3 t1 = ray.rdir * boxMin;
		vec3 t2 = ray.rdir * boxMax;

		vec3 tMin = min(t1, t2);
		vec3 tMax = max(t1, t2);

		float tEnter = maxVec3(tMin);
		float tExit = minVec3(tMax);

		hit = min(rayLength, tExit) >= tEnter && tExit >= 0.0;

		if (hit){
			if (tEnter > 1e-3){
				hitNormal = -step(vec3(tEnter), tMin) * ray.sdir;
				rayLength = tEnter;
			}else{
				eliminated = tExit > 0.45;
				hit = eliminated;
			}
		}
	}

	return hit;
}

#ifdef SHOW_TODO
#error "block shape : copy shape (wall)"
#endif

bool HitShape_FromOrigin_WithInternalIntersection(Ray ray, vec3 voxelCoord, float voxelID, inout float rayLength, out vec3 hitNormal, out vec2 coordOffset, out bool eliminated){
	vec3 blockOrigin = voxelCoord - ray.ori;
	hitNormal = vec3(0.0);
	coordOffset = vec2(0.0);
	eliminated = false;
	
	bool hit = false;

	const float rotIndex[8] = float[8](1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0);

	if (voxelID <= 8.0){ // Door

		int rotID = int(voxelID - 5.0);
		float rotCos = rotIndex[rotID];
		float rotSin = rotIndex[rotID + 4];
		mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

		vec3 ori = vec3(-0.5);
		ori.xz = ori.xz * rot;
		ori += vec3(0.5);
		vec3 size = vec3(1.0, 1.0, 3.0 / 16.0);
		size.xz = size.xz * rot;

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori, size, rayLength, hitNormal, eliminated);


	}else if (voxelID <= 24.0){ // Stained Glass Pane

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 7.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);

		if (voxelID >= 10.0){
			int fenceID = int(voxelID - 10.0);
			int shapeID = fenceID & 3;
			int rotID = fenceID >> 2;
			float rotCos = rotIndex[rotID];
			float rotSin = rotIndex[rotID + 4];
			mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

			vec2 ori0 = vec2(-1.0 / 16.0, 0.0) * rot;
			ori0 += vec2(0.5);
			vec2 size0 = vec2(2.0 / 16.0, -0.5) * rot;

			vec2 ori1 = vec2(0.5, -1.0 / 16.0) * rot;
			ori1 += vec2(0.5);
			vec2 size1 = vec2(shapeID <= 1 ? -0.5 : -1.0, 2.0 / 16.0) * rot;

			if (shapeID <= 2){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori0.x, 0.0, ori0.y), vec3(size0.x, 1.0, size0.y), rayLength, hitNormal, eliminated) || hit;
			}
			if (shapeID >= 1){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori1.x, 0.0, ori1.y), vec3(size1.x, 1.0, size1.y), rayLength, hitNormal, eliminated) || hit;
			}
			if (voxelID == 21.0){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			}
		}


	}else if (voxelID <= 48.0){ // Stairs

		int stairsID = int(voxelID - 25.0);
		int shapeID = stairsID % 3;
		int rotID = stairsID % 12 / 3;
		float rotCos = rotIndex[rotID];
		float rotSin = rotIndex[rotID + 4];
		mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

		vec3 ori0 = vec3(0.0);
		vec3 size0 = vec3(1.0, 0.5, 1.0);

		vec3 ori1 = vec3(-0.5, 0.0, -0.5);
		ori1.xz = ori1.xz * rot;
		ori1 += vec3(0.5);
		vec3 size1 = vec3(1.0, 0.5, 0.5);
		size1.xz = size1.xz * rot;

		vec3 ori2 = vec3(0.5);
		vec3 size2 = vec3(-0.5, 0.5, 0.5);
		size2.xz = size2.xz * rot;

		if (stairsID >= 12){
			ori0.y += 0.5;
			ori1.y -= 0.5;
			ori2.y -= 0.5;
		}

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori0, size0, rayLength, hitNormal, eliminated);
		if (shapeID <= 1) hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori1, size1, rayLength, hitNormal, eliminated) || hit;
		if (shapeID >= 1) hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori2, size2, rayLength, hitNormal, eliminated) || hit;


	}else if (voxelID <= 66.0){ // Top / Bottom Cutted
	
		if (voxelID == 53.0){ // Hopper
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 1.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 0.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 10.0 / 16.0, 0.0), vec3(2.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 14.0 / 16.0), vec3(1.0, 6.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(4.0 / 16.0, 4.0 / 16.0, 4.0 / 16.0), vec3(8.0 / 16.0, 6.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID == 55.0){ // Top Trapdoor
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 13.0 / 16.0, 0.0), vec3(1.0, 3.0 / 16.0, 1.0), rayLength, hitNormal, eliminated);

		}else if (voxelID == 59.0){ // Composter
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 2.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 14.0 / 16.0), vec3(1.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID <= 63.0){ // Top Cutted
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0), vec3(1.0, voxelID * 0.0625 - 3.0, 1.0), rayLength, hitNormal, eliminated);

		}else{ // Bottom Cutted
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, -voxelID * 0.25 + 16.75, 0.0), vec3(1.0, voxelID * 0.25 - 15.75, 1.0), rayLength, hitNormal, eliminated);
		}

	}else if (voxelID <= 74.0){ // Piston
	
		if (voxelID <= 68.0){ // Piston N
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, voxelID * 0.5 - 33.25), vec3(1.0, 1.0, -voxelID * 0.5 + 34.25), rayLength, hitNormal, eliminated);

		}else if (voxelID <= 70.0){ // Piston W
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(voxelID * 0.5 - 34.25, 0.0, 0.0), vec3(-voxelID * 0.5 + 35.25, 1.0, 1.0), rayLength, hitNormal, eliminated);

		}else if (voxelID <= 72.0){ // Piston S
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0), vec3(1.0, 1.0, -voxelID * 0.5 + 36.25), rayLength, hitNormal, eliminated);

		}else{ // Piston E
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0), vec3(-voxelID * 0.5 + 37.25, 1.0, 1.0), rayLength, hitNormal, eliminated);
		}


	}else if (voxelID <= 114.0){ // Wall
		
		if (voxelID == 89.0){ // Cauldron
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(2.0 / 16.0, 13.0 / 16.0, 1.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(1.0, 1.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 0.0), vec3(1.0, 13.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0, 0.0), vec3(2.0 / 16.0, 13.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 14.0 / 16.0), vec3(1.0, 13.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(12.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 12.0 / 16.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(12.0 / 16.0, 0.0, 12.0 / 16.0), vec3(4.0 / 16.0, 3.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID == 90.0){ // Scaffolding
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 0.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 14.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 0.0, 14.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID == 105.0){ // anvil NS
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(2.0 / 16.0, 0.0, 2.0 / 16.0), vec3(12.0 / 16.0, 4.0 / 16.0, 12.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 3.0 / 16.0), vec3(8.0 / 16.0, 5.0 / 16.0, 10.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 4.0 / 16.0), vec3(4.0 / 16.0, 10.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(3.0 / 16.0, 10.0 / 16.0, 0.0), vec3(10.0 / 16.0, 6.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID == 106.0){ // anvil WE
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(2.0 / 16.0, 0.0, 2.0 / 16.0), vec3(12.0 / 16.0, 4.0 / 16.0, 12.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(3.0 / 16.0, 0.0, 4.0 / 16.0), vec3(10.0 / 16.0, 5.0 / 16.0, 8.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 6.0 / 16.0), vec3(8.0 / 16.0, 10.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 10.0 / 16.0, 3.0 / 16.0), vec3(1.0, 6.0 / 16.0, 10.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else if (voxelID == 80.0){ // Wall None
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(4.0 / 16.0, 0.0, 4.0 / 16.0), vec3(0.5, 1.0, 0.5), rayLength, hitNormal, eliminated);

		}else if (voxelID <= 82.0){ // Wall 4
			float height = (14.0 + 2.0 * step(voxelID, 81.0)) / 16.0;

			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 0.0), vec3(6.0 / 16.0, height, 1.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 5.0 / 16.0), vec3(1.0, height, 6.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else{
			float height = (14.0 + 2.0 * step(voxelID, 98.0)) / 16.0;

			int wallID = int(voxelID - 83.0);
			int shapeID = wallID % 16 / 4;
			int rotID = wallID % 4;
			float rotCos = rotIndex[rotID];
			float rotSin = rotIndex[rotID + 4];
			mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

			vec3 ori0 = vec3(-3.0 / 16.0, -0.5, -0.5);
			ori0.xz = ori0.xz * rot;
			ori0 += vec3(0.5);
			vec3 size0 = vec3(6.0 / 16.0, height, 11.0 / 16.0);
			size0.xz = size0.xz * rot;

			vec3 ori1 = vec3(0.5, -0.5, -3.0 / 16.0);
			ori1.xz = ori1.xz * rot;
			ori1 += vec3(0.5);
			vec3 size1 = vec3(shapeID <= 1 ? -1.0 : -11.0 / 16.0, height, 6.0 / 16.0);
			size1.xz = size1.xz * rot;

			if (shapeID != 1) hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori0, size0, rayLength, hitNormal, eliminated);
			if (shapeID != 3) hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, ori1, size1, rayLength, hitNormal, eliminated) || hit;
		}

	}else if (voxelID <= 142.0){ // Fence

		if (voxelID <= 130.0){ // Fence

			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 6.0 / 16.0), vec3(4.0 / 16.0, 1.0, 4.0 / 16.0), rayLength, hitNormal, eliminated);

			if (voxelID >= 116.0){
				int fenceID = int(voxelID - 116.0);
				int shapeID = fenceID % 4;
				int rotID = fenceID / 4;
				float rotCos = rotIndex[rotID];
				float rotSin = rotIndex[rotID + 4];
				mat2 rot = mat2(rotCos, rotSin, -rotSin, rotCos);

				vec2 ori0 = vec2(-1.0 / 16.0, 0.0) * rot;
				ori0 += vec2(0.5);
				vec2 size0 = vec2(2.0 / 16.0, -0.5) * rot;

				vec2 ori1 = vec2(0.5, -1.0 / 16.0) * rot;
				ori1 += vec2(0.5);
				vec2 size1 = vec2(shapeID <= 1 ? -0.5 : -1.0, 2.0 / 16.0) * rot;

				if (shapeID <= 2){
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori0.x, 6.0 / 16.0, ori0.y), vec3(size0.x, 3.0 / 16.0, size0.y), rayLength, hitNormal, eliminated) || hit;
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori0.x, 12.0 / 16.0, ori0.y), vec3(size0.x, 3.0 / 16.0, size0.y), rayLength, hitNormal, eliminated) || hit;
				}
				if (shapeID >= 1){
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori1.x, 6.0 / 16.0, ori1.y), vec3(size1.x, 3.0 / 16.0, size1.y), rayLength, hitNormal, eliminated) || hit;
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(ori1.x, 12.0 / 16.0, ori1.y), vec3(size1.x, 3.0 / 16.0, size1.y), rayLength, hitNormal, eliminated) || hit;
				}
				if (voxelID == 127.0){
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 6.0 / 16.0, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
					hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 12.0 / 16.0, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
				}
			}


		}else if (voxelID <= 136.0){ // Fence Gate NS

			float heightOffset = 3.0 * step(voxelID, 133.0) / 16.0;
			float shapeID = mod(voxelID, 3.0);

			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 2.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 2.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

			if (shapeID == 2.0){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(1.0, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(1.0, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(6.0 / 16.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}else if (shapeID == 0.0){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 9.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 1.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}else{
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 9.0 / 16.0 + heightOffset, 7.0 / 16.0), vec3(2.0 / 16.0, 3.0 / 16.0, 0.5), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0 + heightOffset, 13.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(14.0 / 16.0, 3.0 / 16.0 + heightOffset, 13.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}


		}else{ // Fence Gate WE

			float heightOffset = 3.0 * step(voxelID, 139.0) / 16.0;
			float shapeID = mod(voxelID, 3.0);

			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 2.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 2.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 11.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

			if (shapeID == 2.0){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 3.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 6.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}else if (shapeID == 0.0){
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 9.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}else{
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 0.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 9.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(0.5, 3.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(13.0 / 16.0, 3.0 / 16.0 + heightOffset, 0.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(13.0 / 16.0, 3.0 / 16.0 + heightOffset, 14.0 / 16.0), vec3(2.0 / 16.0, 9.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			}
		}


	}else if (abs(voxelID - 199.0) < 41.5){ // Light Source [158, 240]
		if (voxelID <= 219.0){
			uint lichenID = uint(voxelID - 157.0);
			if (bool(lichenID & 32u)){ // down
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 5e-6, 0.0), vec3(1.0, 5e-6, 1.0), rayLength, hitNormal, eliminated);
			}
			if (bool(lichenID & 16u)){ // up
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 1.0 - 5e-6, 0.0), vec3(1.0, 5e-6, 1.0), rayLength, hitNormal, eliminated) || hit;
			}
			if (bool(lichenID & 8u)){ // north
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 5e-6), vec3(1.0, 1.0, 5e-6), rayLength, hitNormal, eliminated) || hit;
			}
			if (bool(lichenID & 4u)){ // east
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 - 5e-6, 0.0, 0.0), vec3(5e-6, 1.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			}
			if (bool(lichenID & 2u)){ // south
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 1.0 - 5e-6), vec3(1.0, 1.0, 5e-6), rayLength, hitNormal, eliminated) || hit;
			}
			if (bool(lichenID & 1u)){ // west
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5e-6, 0.0, 0.0), vec3(5e-6, 1.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			}

		}else if (voxelID == 220.0){ // Lantern
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(6.0 / 16.0, 0.0, 6.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

			#ifndef PT_TEMP_COORD_OFFSET
				coordOffset = vec2(-5.0 / 16.0, -7.0 / 16.0);
			#endif

		}else if (voxelID == 221.0){ // Lantern Hanging
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 1.0 / 16.0, 5.0 / 16.0), vec3(6.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(6.0 / 16.0, 1.0 / 16.0, 6.0 / 16.0), vec3(4.0 / 16.0, 9.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

			#ifdef PT_TEMP_COORD_OFFSET
				coordOffset = vec2(5.0 / 16.0, -5.0 / 16.0);
			#else
				coordOffset = vec2(-5.0 / 16.0, -6.0 / 16.0);
			#endif

		}else if (abs(voxelID - 223.0) < 1.5){ // End Rod
			if (voxelID == 222.0){ // End Rod X
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 7.0 / 16.0, 7.0 / 16.0), vec3(1.0, 2.0 / 16.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);

			}else if (voxelID == 223.0){ // End Rod Y
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 0.0, 7.0 / 16.0), vec3(2.0 / 16.0, 1.0, 2.0 / 16.0), rayLength, hitNormal, eliminated);

			}else{ // End Rod Z
				hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(7.0 / 16.0, 7.0 / 16.0, 0.0), vec3(2.0 / 16.0, 2.0 / 16.0, 1.0), rayLength, hitNormal, eliminated);
			}

		}else if (voxelID == 235.0 || voxelID == 237.0 || voxelID == 239.0){ // Campfire NS
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 0.0), vec3(14.0 / 16.0, 1.0 / 16.0, 1.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(11.0 / 16.0, 0.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 1.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 3.0 / 16.0, 11.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

		}else{ // Campfire WE // 236 238 240
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 1.0 / 16.0), vec3(1.0, 1.0 / 16.0, 14.0 / 16.0), rayLength, hitNormal, eliminated);
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 1.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(0.0, 0.0, 11.0 / 16.0), vec3(1.0, 4.0 / 16.0, 4.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 3.0 / 16.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
			hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(11.0 / 16.0, 3.0 / 16.0, 0.0), vec3(4.0 / 16.0, 4.0 / 16.0, 1.0), rayLength, hitNormal, eliminated) || hit;
		}


	}else if (voxelID == 143.0){ // Pressure Plate

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 1.0 / 16.0), vec3(14.0 / 16.0, 1.0 / 16.0, 14.0 / 16.0), rayLength, hitNormal, eliminated);


	}else if (voxelID == 144.0){ // Pressure Plate Powered

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(1.0 / 16.0, 0.0, 1.0 / 16.0), vec3(14.0 / 16.0, 0.5 / 16.0, 14.0 / 16.0), rayLength, hitNormal, eliminated);


/*
	}else if (voxelID == 145.0){ // Flower Pot

		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 6.0 / 16.0, 1.0 / 16.0), rayLength, hitNormal, eliminated);
		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(1.0 / 16.0, 6.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(10.0 / 16.0, 0.0, 5.0 / 16.0), vec3(1.0 / 16.0, 6.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 10.0 / 16.0), vec3(6.0 / 16.0, 6.0 / 16.0, 1.0 / 16.0), rayLength, hitNormal, eliminated) || hit;
		hit = IsHitBox_FromOrigin_WithInternalIntersection(ray, blockOrigin, vec3(5.0 / 16.0, 0.0, 5.0 / 16.0), vec3(6.0 / 16.0, 4.0 / 16.0, 6.0 / 16.0), rayLength, hitNormal, eliminated) || hit;

*/
	}

	return hit;
}

bool IsHitBlock_FromOrigin_WithInternalIntersection(Ray ray, vec3 totalStep, vec3 tracingNext, vec3 voxelCoord, float voxelID, out float rayLength, out vec3 hitNormal, out vec2 coordOffset, out bool eliminated){
	rayLength = minVec3(totalStep);
	hitNormal = vec3(0.0);
	coordOffset = vec2(0.0);


	bool hit = true;

	if (voxelID <= 4.0){
		hitNormal = -tracingNext * ray.sdir;
	}else{
		rayLength = minVec3(totalStep);
		hit = HitShape_FromOrigin_WithInternalIntersection(ray, voxelCoord, voxelID, rayLength, hitNormal, coordOffset, eliminated);
	}

	return hit;
}