Shader "Unlit/Raymarch" {
    Properties {
        TESSELLATION_FACTOR("Tessllation Factor (Int)", Int) = 1
    }
    
    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            
            #pragma vertex passToHullShader
            #pragma hull hullShader
            #pragma domain domainShader
            #pragma fragment fragmentShader
            
            #include "UnityCG.cginc"
            #include "SceneDefinition.cginc"

            struct VertexAttributes {
                float4 vertex : POSITION;
            };

            struct VertexInterpolants {
                float4 vertex : SV_POSITION;
            };
            
            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            
            int TESSELLATION_FACTOR;

            VertexInterpolants vertexShader (VertexAttributes va) {
                VertexInterpolants vi;
                
                float3 worldSpacePosition = mul(unity_ObjectToWorld, va.vertex);
                vi.vertex = UnityWorldToClipPos(float4(worldSpacePosition, 1.0));
                
                return vi;
            }
            
            VertexAttributes passToHullShader(VertexAttributes vsi) {       
                return vsi;
            }
            
            TessellationFactors patchConstantFunction (InputPatch<VertexAttributes, 3> patch) {
                TessellationFactors f;
                f.edge[0] = TESSELLATION_FACTOR;
                f.edge[1] = TESSELLATION_FACTOR;
                f.edge[2] = TESSELLATION_FACTOR;
                f.inside = TESSELLATION_FACTOR;
                return f;
            }
            
            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_partitioning("integer")]
            [UNITY_patchconstantfunc("patchConstantFunction")]
            VertexAttributes hullShader(InputPatch<VertexAttributes, 3> patch, uint id : SV_OutputControlPointID) {
                return patch[id];
            }
            
            [UNITY_domain("tri")]
            VertexInterpolants domainShader (TessellationFactors factors, OutputPatch<VertexAttributes, 3> patch, float3 barycentricCoordinates : SV_DomainLocation) {
                VertexAttributes data;
            
                //barycentric interpolation
                data.vertex = patch[0].vertex * barycentricCoordinates.x + patch[1].vertex * barycentricCoordinates.y + patch[2].vertex * barycentricCoordinates.z;
            
                return vertexShader(data);
            }
   
            float4 fragmentShader (VertexInterpolants vi) : SV_Target {
                float4 color = float4(1.0, 0.0, 0.0, 1);    

                return color;
            }
            
            ENDCG
        }
    }
}