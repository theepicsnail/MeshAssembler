/*
struct appdata_full {
	float4 vertex : POSITION;
	float4 tangent : TANGENT;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
	float4 texcoord1 : TEXCOORD1;
	fixed4 color : COLOR;
}
*/

Shader "Snail/Shaders/MeshAssembler" {

    Properties
    {
		_DebugValue ("DebugValue", Float) = 0
        _MainTex ("Texture", 2D) = "white" {}
        _Movement ("Movement", Range(-5, 5)) = 1
		_Visible ("Visible", Range(0, 100)) = 15
		_Invisible ("Invisible", Range(0, 100)) = 20
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent"  }
        Cull off
 
        Pass
        {
			ZWrite On
			Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
 
            #include "UnityCG.cginc"
 
            struct v2g
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };
 
            struct g2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 col : COLOR;
            };
			
            sampler2D _MainTex;
            float4 _MainTex_ST;

			float random (in float3 st) {
				return frac(
					cos(
						dot(
							st.xyz, 
							float3(
								12.9898,
								78.233,
								123.691
							)
						)
					)
					* 43758.5453123
				);
			}
           
            v2g vert (appdata_base v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.normal = v.normal;
                return o;
            }
			float _DebugValue;
		    float _Movement;
			float _Visible;
			float _Invisible;
            [maxvertexcount(3)]
            void geom(triangle v2g IN[3], inout TriangleStream<g2f> tristream)
            {
				float4 mid = (IN[0].vertex+IN[1].vertex+IN[2].vertex)/3;
				float hash = random(mid);
				float movement =  _Movement * (hash * 2 - 1);
				float distance = length(
					_WorldSpaceCameraPos.xyz - 
					mul(unity_ObjectToWorld, mid));
				// 0 = invisible, 1 = visible, can be outside 0-1 range.
				float range = _Visible-_Invisible;
				float delta = distance - _Invisible;
				float percent = lerp(delta, range, _DebugValue)/range;
				percent += 0.1 * (1+sin(_Time.y * (1+hash)/2));
				percent = saturate(percent);
				
				if(percent == 0) 
					return;

				g2f o;

				
                float3 edgeA = IN[1].vertex - IN[0].vertex;
                float3 edgeB = IN[2].vertex - IN[0].vertex;
				float3 c = cross(edgeA, edgeB); 
				float3 outDir = normalize(c);
                float3 normalDir = normalize(c);

				// Using o.pos as the delta.
				float3 over = cos(IN[1].vertex * 1234.56);
                for(int i = 0; i < 3; i++)
                {
					// First half is sliding over where it goes
					if(percent < .5) 
					{
						//over -= over.y; // * dot(normalDir, over); // Make it perpendicular to the normal
						over = normalize(over);
						// At percent = 0, position is shifted by 'over'
						// at percent = .5 position is shifted by 0.
						o.pos.xyz = (lerp(over, 0, percent*2) + normalDir) * movement;
					} else {
						// Second half is sliding into place
						// percent = .5 should be shifted by normalDir * movement
						// percent = 1 should be shifted by 0
						o.pos.xyz = normalDir * movement * (1-percent)*2 ;
					}

                    o.pos = UnityObjectToClipPos(IN[i].vertex+ o.pos);
                    o.uv = IN[i].uv;
                    o.col = fixed4(saturate(percent*2), 0, 0, 0);
                    tristream.Append(o);
                }
			
                tristream.RestartStrip();
            }
           
            fixed4 frag (g2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
				col.a = i.col.r* col.a;
                return col;
            }
            ENDCG
        }
    }
}
