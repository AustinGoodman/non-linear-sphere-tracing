Shader "Unlit/Raymarch" {
    Properties {
    }
    
    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            
            #pragma vertex vertexShader
            #pragma fragment fragmentShader

            #include "UnityCG.cginc"

            struct VertexAttributes {
                float4 vertex : POSITION;
            };

            struct VertexInterpolants {
                float4 vertex : SV_POSITION;
            };

            VertexInterpolants vertexShader (VertexAttributes va) {
                VertexInterpolants vi;
                
                float3 worldSpacePosition = mul(unity_ObjectToWorld, va.vertex);
                vi.vertex = UnityWorldToClipPos(float4(worldSpacePosition, 1.0));
                
                return vi;
            }
   
            float4 fragmentShader (VertexInterpolants vi) : SV_Target {
                float4 color = float4(1, 0, 0, 1);    

                return color;
            }
            
            ENDCG
        }
    }
}