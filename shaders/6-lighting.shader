Shader "Unlit/Raymarch" {
    Properties {
        MAX_STEPS ("Max Raymarch Steps", Int) = 200
        THRESHOLD ("Scene Hit Threshold", Float) = 0.0001
        NORMAL_DIFFERENTIAL ("Normal Differential", Float) = 0.0001
        MAX_DISTANCE ("Max Raymarch Distance", Float) = 400.0
        TESSELLATION_FACTOR("Tessllation Factor (Int)", Int) = 1
        MATERIAL_COLOR ("Color", Color) = (1.0, 0.0, 0.0, 1.0)
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
            #include "Utilities.cginc"

            struct VertexAttributes {
                float4 vertex : POSITION;
            };

            struct VertexInterpolants {
                float4 vertex : SV_POSITION;
                float3 worldSpacePosition : TEXCOORD0;
            };
            
            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            
            struct SceneHit {
                float3 position;
                float3 normal;
                float distanceTravelled;
                bool hit;
            };
            
            int MAX_STEPS;
            float THRESHOLD;
            float NORMAL_DIFFERENTIAL;
            float MAX_DISTANCE;
            int TESSELLATION_FACTOR;
            float4 MATERIAL_COLOR;
            
            float3 getNormal(float3 pos) {
                float3 h = float3(NORMAL_DIFFERENTIAL, 0, 0);
                
                float3 normal = float3(
                    getSDF(pos + h.xyy) - getSDF(pos - h.xyy),
                    getSDF(pos + h.yxy) - getSDF(pos - h.yxy),
                    getSDF(pos + h.yyx) - getSDF(pos - h.yyx)
                );
                
                return normalize(normal);
            }
            
            SceneHit raymarch(float3 rayOrigin, float3 rayDirection) {
                SceneHit sceneHit;
                sceneHit.position = rayOrigin;
                sceneHit.normal = float3(0.0, 0.0, 0.0);
                sceneHit.distanceTravelled = 0.0;
                sceneHit.hit = false;
                
                for(int i = 0; i < MAX_STEPS; i++) {
                    float sdfValue = getSDF(sceneHit.position);
                    
                    if(sdfValue <= THRESHOLD) {
                        sceneHit.hit = true;
                        sceneHit.normal = getNormal(sceneHit.position);
                        break;
                    }
                    
                    sceneHit.position += sdfValue*rayDirection;
                    sceneHit.distanceTravelled += sdfValue;
                    
                    if(sceneHit.distanceTravelled >= MAX_DISTANCE) {
                        break;
                    }
                }
                
                return sceneHit;
            }

            VertexInterpolants vertexShader (VertexAttributes va) {
                VertexInterpolants vi;
                
                vi.worldSpacePosition = mul(unity_ObjectToWorld, va.vertex);
                vi.vertex = UnityWorldToClipPos(float4(vi.worldSpacePosition, 1.0));
                
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
                
                float3 rayOrigin = vi.worldSpacePosition;
                float3 rayDirection = normalize(vi.worldSpacePosition - _WorldSpaceCameraPos);
                
                SceneHit sceneHit = raymarch(rayOrigin, rayDirection);
                
                if(sceneHit.hit) {
                    float3 hitPosition = sceneHit.position;
                    float3 hitNormal = sceneHit.normal;

                    //calculate the raymarched lighting
                    float3 lightDirection = _WorldSpaceLightPos0.xyz;
                    float3 lightColor = float3(1.0, 1.0, 1.0);
                    float diffuse = clamp(dot(hitNormal, lightDirection), 0.0, 1.0);
                    float3 refl = reflect(lightDirection, hitNormal);
                    float specular = pow(max(dot(rayDirection, refl), 0.0), 4.0);
                    
                    float3 materialColor = gammaCorrectInverse(MATERIAL_COLOR.xyz);
                    float skyColor = gammaCorrectInverse(float3(0.780, 0.952, 1));
                    
                    color.rgb = materialColor*(lightColor*diffuse + lightColor*specular + 0.08f*skyColor);
                } else {
                    discard;
                }

                color.rgb = gammaCorrect(color.rgb);
                return color;
            }
            
            ENDCG
        }
    }
}