//Skybasic_VS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int renderStage;
uniform vec2 taaJitter;

out vec4 v_color;


#if FSR2_SCALE >= 0
	#include "/Lib/FSR2/GbufferScale.glsl"
#endif


void main(){
	#if STAR_TYPE < 2
		gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
	#else
		if (renderStage == MC_RENDER_STAGE_STARS){
			gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
			vec4 worldPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

			const float rotYAngle = SUNRISE_ROTATION * 0.01745329252;
			const mat3 rotY = mat3(
				cos(rotYAngle), 0.0, -sin(rotYAngle),
				0.0,            1.0,  0.0,
				sin(rotYAngle), 0.0,  cos(rotYAngle)
			);
			worldPos.xyz = worldPos.xyz * rotY;
			gl_Position = gl_ProjectionMatrix * gbufferModelView * worldPos;

			#if FSR2_SCALE >= 0
				FsrScaleVS(gl_Position, taaJitter);
			#else
				#ifdef TAA
					gl_Position.xy = taaJitter * gl_Position.w + gl_Position.xy;
				#endif
			#endif
		}else{
			gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
		}
	#endif

	v_color = gl_Color;
}