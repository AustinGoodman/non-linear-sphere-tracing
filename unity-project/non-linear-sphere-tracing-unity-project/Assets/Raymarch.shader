Shader "Unlit/Raymarch" {
    Properties {
        MAX_STEPS ("Max Raymarch Steps", Int) = 200
        THRESHOLD ("Scene Hit Threshold", Float) = 0.0001
        NORMAL_DIFFERENTIAL ("Normal Differential", Float) = 0.0001
        MAX_DISTANCE ("Max Raymarch Distance", Float) = 400.0
        TESSELLATION_FACTOR("Tessllation Factor (Int)", Int) = 1
        MATERIAL_COLOR ("Color", Color) = (1.0, 0.0, 0.0, 1.0)
        DEFORMATION_PARAMETER("Deformation Parameter", Float) = 1.0
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
                float3 deformedWorldSpacePosition : TEXCOORD1;
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
            float DEFORMATION_PARAMETER;
            
            float3 deform(float3 x) {
                float alpha = DEFORMATION_PARAMETER;
                float c = cos(alpha*x.z);
                float s = sin(alpha*x.z);
                float3x3 mat =  float3x3 (
                    c, -s, 0.0f,
                    s, c, 0.0f,
                    0.0f, 0.0f, 1.0f
                ); 
                return mul(transpose(mat), x);
            }  
            
            float3x3 jacobian(float3 x) {
                float3 h = float3(NORMAL_DIFFERENTIAL, 0, 0);
                
                float3 dfdx = deform(x + h.xyy) - deform(x - h.xyy);
                float3 dfdy = deform(x + h.yxy) - deform(x - h.yxy);
                float3 dfdz = deform(x + h.yyx) - deform(x - h.yyx);
                
                float3 grad1 = float3(dfdx.x, dfdy.x, dfdz.x)/(2.0f*h.x);
                float3 grad2 = float3(dfdx.y, dfdy.y, dfdz.y)/(2.0f*h.x);
                float3 grad3 = float3(dfdx.z, dfdy.z, dfdz.z)/(2.0f*h.x);
                
                float3x3 jacobian = transpose(float3x3(grad1, grad2, grad3));
                
                return jacobian;
            }
            
            float3 omega(float3 x, float3 omega0) {
                float3x3 J = jacobian(x);
                float3x3 Jinverse = inverse(J);
                
                return normalize(mul(Jinverse, omega0));
            }
            
            float3 rungeKutta(float3 x0, float3 omega0, float sd) {
                float h = sd;
                
                float3 k1 = omega(x0, omega0);
                float3 k2 = omega(x0 + 0.5f*h*k1, omega0);
                float3 k3 = omega(x0 + 0.5f*h*k2, omega0);
                float3 k4 = omega(x0 + h*k3, omega0);
                
                return x0 + (h/6.0f)*(k1 + 2.0f*k2 + 2.0f*k3 + k4);
            }
            
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
            
            SceneHit raymarchNonlinear(float3 rayOrigin, float3 omega0) {
                SceneHit sceneHit;
                sceneHit.position = rayOrigin;
                sceneHit.normal = float3(0.0, 0.0, 0.0);
                sceneHit.distanceTravelled = 0.0;
                sceneHit.hit = false;
                
                for(int i = 0; i < MAX_STEPS; i++) {
                    float sdfValue = getSDF(sceneHit.position);
                    
                    if(sdfValue <= THRESHOLD) {
                        sceneHit.hit = true;
                        
                        float3 normal = getNormal(sceneHit.position);
                        
                        float3x3 J = jacobian(sceneHit.position);
                        float3x3 Jinverse = inverse(J);
                        sceneHit.normal = normalize(mul(transpose(Jinverse), normal));
                        
                        break;
                    }
                    
                    sceneHit.position = rungeKutta(sceneHit.position, omega0, sdfValue);
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
                vi.deformedWorldSpacePosition = deform(vi.worldSpacePosition);
                vi.vertex = UnityWorldToClipPos(float4(vi.deformedWorldSpacePosition, 1.0));
                
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
                float3 rayDirection = normalize(vi.deformedWorldSpacePosition - _WorldSpaceCameraPos);
                
                SceneHit sceneHit = raymarchNonlinear(rayOrigin, rayDirection);
                
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