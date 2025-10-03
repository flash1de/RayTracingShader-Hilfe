

in vec3 vaPosition;


void main(){
	vec2 texCoord = vaPosition.xy;
	texCoord *= 0.51;
	gl_Position = vec4(texCoord * 2.0 - 1.0, 0.0, 1.0);
}
