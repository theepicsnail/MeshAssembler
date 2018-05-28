// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Snail/Shaders/MeshAssembler2" 
{
    Properties 
    {
		_MainTex("Main Texture", 2D) = "white" {}

		[Header(Visibility Range)]
		_VISIBLE("Visible distance", Float) = 5
		_INVISIBLE("Invisible distance", Float) = 20

		[Header(Movement)]
		_SCALE("Scale", Float) = 1
		[Toggle(SCALE_PROPORTIONAL)]
		SCALE_PROPORTIONAL("Proportional to polygon area", Float)=0

		[Header(Space Nose)]
		_NOISE_SCALE("Frequency", Float) = 1
		_NOISE_VARIANCE("Amplitude", Float) = .1

		[Header(Time Noise)]
		_TIME_SPEED("Frequency", Float) = 1
		_TIME_VARIANCE("Amplitude", Float) = .1

		[Header(Other)]
		[Toggle(DEBUGGING)]
		DEBUGGING("Debugging", Float) = 0
		
		// Super handy guide for prettier properties!
		// https://gist.github.com/keijiro/22cba09c369e27734011
    }

    SubShader 
    {
		Tags {
			"Queue"="Transparent"
			"RenderType"="Transparent"
		}
    	CGINCLUDE
    		#include "UnityCG.cginc"
    		#include "../ShaderUtils/Inlines.cginc"
    		#include "../ShaderUtils/Noise.cginc"
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;

			uniform float _SCALE;

			uniform float _VISIBLE;
			uniform float _INVISIBLE;

			uniform float _NOISE_SCALE;
			uniform float _NOISE_VARIANCE;

			uniform float _TIME_VARIANCE;
			uniform float _TIME_SPEED;
    	ENDCG

    	Pass {
	        ZWrite Off
	        Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
            	#pragma shader_feature DEBUGGING
            	#pragma shader_feature SCALE_PROPORTIONAL

				struct VS_INPUT { 
					float4 vertex : POSITION; 
					float4 uv : TEXCOORD0;
			    	float3 normal : NORMAL;
				};
				struct GS_INPUT { 
					float4 vertex : POSITION; 
					float4 uv : TEXCOORD0;
			    	float3 normal : NORMAL;
				};
				struct FS_INPUT { 
					float4 vertex : POSITION; 
					float4 uv : TEXCOORD0;
					// uv.w is tranpancy
				};

				// Mostly passthrough shader.
				// I do want all the verticies in world space (not clip yet).
				#pragma vertex VS_Main
				GS_INPUT VS_Main(VS_INPUT input)
				{
					GS_INPUT output = (GS_INPUT)0;
					output.vertex =  mul(unity_ObjectToWorld, input.vertex);
					output.normal = input.normal;
					output.uv = input.uv;
					return output;
				}


				#pragma geometry GS_Main
				[maxvertexcount(3)] 
				void GS_Main(triangle GS_INPUT input[3], 
							 uint pid : SV_PrimitiveID, 
							 inout TriangleStream<FS_INPUT> stream) {
					// By default we don't move the vertex and its opaque.
					float3 net_shift = float3(0,0,0);
					float opacity = 1;
					#ifndef DEBUGGING

					// Each polygon will have a little bit of noise to make 
					// them unique. We'll use both position and the primative
					// id for that.

					// Per poly random number [0,1]
					float poly_noise = frac(sin(pid*1000)*1000);

					// Per poly center, used for distance and noise.
					float4 center = (
						input[0].vertex + 
						input[1].vertex + 
						input[2].vertex ) / 3;

					// simplex gradient(xyz) and value(w) for our poly.
					float4 space_noise = snoise_grad(center*_NOISE_SCALE);

					// Noise to offset the movement percent by.
					// abs(percent_noise) <= _NOISE_VARIANCE + _TIME_VARIANCE
					float percent_noise = 
						// World noise
						_NOISE_VARIANCE * space_noise.w + 
						// Time noise
						_TIME_VARIANCE * sin(
							// Each poly wiggles at its own frequency.
							_Time.y * _TIME_SPEED * space_noise.w

							// Each poly wiggles at the same frequency, but
							// are out of phase.
							//_Time.y * _TIME_SPEED + space_noise.w * UNITY_TWO_PI
						);
					

					// Percent [0,1] from invisible(0) to visible(1)
					float p = saturate(
						Remap(
							distance(center, GetCameraPosition()), 
							_VISIBLE, _INVISIBLE, 1, 0)
						+ percent_noise
						);

					// p = 0 to .5 is sliding over where the poly goes
					// remaps and clamps 
					// p =  0 -> side_movement = 1
					// p = .5 -> side_movement = 0
					// p =  1 -> side_movement = 0
					float side_movement = 1-saturate(p*2);

					// p=.5 to 1 is sliding the poly down into place.
					// p =  0 -> vert_movement = 1
					// p = .5 -> vert_movement = 1
					// p =  1 -> vert_movement = 0
					float vert_movement = saturate((1-p)*2);

					// Use the gradient from the world space noise
					// for the 0-> .5 portion of the trip
					float3 side_direction = normalize(space_noise.xyz);

					// normal direction of the poly is the slide in direction.
					float3 out_direction = normalize(
						input[0].normal + 
						input[1].normal + 
						input[2].normal );


					#ifdef SCALE_PROPORTIONAL
					
					_SCALE *= length(cross(
						input[1].vertex.xyz - input[0].vertex.xyz,
						input[2].vertex.xyz - input[0].vertex.xyz
						));
					#endif
					// Move out and over from the actual position
					net_shift = _SCALE * (
						out_direction * vert_movement +
						side_direction * side_movement);

					opacity = p;
					#endif
				

					FS_INPUT output = (FS_INPUT) 0;
					for(uint i = 0 ; i < 3; i++){
						output.uv.xy = input[i].uv.xy;
						output.uv.w = opacity;

						// Shift the vertex
						output.vertex = input[i].vertex;
						output.vertex.xyz += net_shift;
						// Convert from world to clip space.
						output.vertex = mul(UNITY_MATRIX_VP, output.vertex);
						stream.Append(output);
					}
				}

				
                #pragma fragment FS_Main
				float4 FS_Main(FS_INPUT input) : COLOR
				{
					float4 color = tex2D(_MainTex, input.uv.xy);
					color.w *= input.uv.w;
					return color;
				}
			ENDCG
		}
    } 
}
