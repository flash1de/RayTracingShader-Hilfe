

in vec3 vaPosition;


void main(){
	#if FSR2_SCALE >= 0 && defined FULLRES_BUFFER
		gl_Position = vec4(vaPosition.xy * 8.0 - vec2(6.5, 1.5), 0.0, 1.0);
	#else
		gl_Position = vec4(vaPosition.xy * 8.0 - vec2(6.5, 1.5), 0.0, 1.0);
	#endif
}
