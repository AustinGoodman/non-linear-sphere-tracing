# Nonlinear Sphere Tracing Tutorial

## Part 0 - Read the Paper
https://cs.dartmouth.edu/wjarosz/publications/seyb19nonlinear.html

## Part 1 - Creating a Simple Pass Through Shader
Create a new unlit shader asset from Unity's asset manager. You can delete all the unnecessary Unity stuff and change all the default names to something a little less deranged. After that, all you need to do for this part is create a vertex shader that transforms the vertex position attributes from object space to clip space. Once you're done you should have something like this:
```HLSL
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
```
<br/>

Now create a material and attach the shader to it. Create a cube with the material you made and you should see a simple colored cube.

![image](https://user-images.githubusercontent.com/80550270/161393133-3188fce3-4fed-4b26-9aac-53d6c5e3c6b8.png)

<br/>

## Part 2 - Boilerplate Tesselation Shader
I would like to keep this tutorial as simple and short as possible so instead of implementing the dynamic tessellation scheme described in the paper, I will instead just include a simple shader which subdivides the mesh indiscriminately. I won't explain tessellation shaders here but https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/ is a good introduction. There won't be any changes to the tessellation side of things going forward so you can just copy and paste the code if you don't understand it all.
```HLSL
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
                float4 color = float4(1, 0, 0, 1);    

                return color;
            }
            
            ENDCG
        }
    }
}
```
<br/>

To check that the tessellation is working you can enable the Select Wire gizmo in the Unity scene editor. Changing Tesselation Factor on the cube's material should result in more triangles becoming visible.

<br/>

<figure>
     <figcaption>Tesselation Factor = 1</figcaption>
    <img src="https://user-images.githubusercontent.com/80550270/161393820-dabd9244-4964-41d6-8bf5-19b49ed4e606.png" width="300" height="300">
</figure> 

<figure>
    <figcaption>Tesselation Factor = 4</figcaption>
    <img src="https://user-images.githubusercontent.com/80550270/161393764-5efb6333-246a-4b61-85fc-f344c2110754.png" width="300" height="300">
</figure> 

<br/>

## Part 3 - Setting Up The Signed Distance Field
The next thing we have to do is define the signed distance field we would like to render. To do this, create a new file called SceneDefinition.cginc and place the functions for any signed distance field primitives you would like to use. Next create a function getSDF which will return the signed distance field representing the scene. Here is my SceneDefinition.cginc: 
```HLSL
float sdSphere(float3 pos, float R) {
    return length(pos) - R;
}

float sdBox(float3 pos, float3 dimensions) {
    float3 q = abs(pos) - dimensions;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdTorus(float3 pos, float holeRadius, float crossSectionRadius) {
  float2 q = float2(length(pos.xz)-holeRadius,pos.y);
  return length(q)-crossSectionRadius;
}

float getSDF(float3 pos) {
    return sdTorus(pos, 1.0, 0.4);
}
```

<br/> Now include SceneDefinition in your raymarch shader like so: 
```HLSL
#include "SceneDefinition.cginc"
```

<br/>

## Part 4 - Preparing for Raymarching
Our signed distance field was defined with respect to world space coordinates, so in order to raymarch it we will need our ray origin to be in world space. To do this, modify the VertexInterpolants struct to include and additional vector holding the world space position.
```HLSL
struct VertexInterpolants {
    float4 vertex : SV_POSITION;
    float3 worldSpacePosition : TEXCOORD0;
};
```
<br/>

Next we need to modify our vertex shader to compute the world space position and set it in the VertexInterpolants. This is our new vertex shader:
```HLSL
VertexInterpolants vertexShader (VertexAttributes va) {
    VertexInterpolants vi;

    vi.worldSpacePosition = mul(unity_ObjectToWorld, va.vertex);
    vi.vertex = UnityWorldToClipPos(float4(vi.worldSpacePosition, 1.0));

    return vi;
}
```
<br/>

## Part 5 - Normal Raymarching
Now we are ready to implement a standard raymarcher. First thing's first we need to take in the standard raymarching parameters from the unity editor as properties: 
```HLSL
Properties {
    MAX_STEPS ("Max Raymarch Steps", Int) = 200
    THRESHOLD ("Scene Hit Threshold", Float) = 0.0001
    NORMAL_DIFFERENTIAL ("Normal Differential", Float) = 0.0001
    MAX_DISTANCE ("Max Raymarch Distance", Float) = 400.0
    TESSELLATION_FACTOR("Tessllation Factor (Int)", Int) = 1
}
```
<br/>

and make sure to define variables for each of the parameters we took in:
```HLSL
int MAX_STEPS;
float THRESHOLD;
float NORMAL_DIFFERENTIAL;
float MAX_DISTANCE;
int TESSELLATION_FACTOR;
```
<br/>

Next we will make a struct called SceneHit which will be the data type returned from the raymarching function: 
```HLSL
struct SceneHit {
    float3 position;
    float3 normal;
    float distanceTravelled;
    bool hit;
};
```
<br/>

and finally the raymarching funciton: 
```HLSL
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
```

We can now raymarch from the fragment shader: 
```HLSL
float4 fragmentShader (VertexInterpolants vi) : SV_Target {
    float4 color = float4(1.0, 0.0, 0.0, 1);    

    float3 rayOrigin = vi.worldSpacePosition;
    float3 rayDirection = normalize(vi.worldSpacePosition - _WorldSpaceCameraPos);

    SceneHit sceneHit = raymarch(rayOrigin, rayDirection);

    if(sceneHit.hit) {

    } else {
        discard;
    }

    return color;
}
```

So putting it all together you raymarching shader should now be: 
```HLSL
Shader "Unlit/Raymarch" {
    Properties {
        MAX_STEPS ("Max Raymarch Steps", Int) = 200
        THRESHOLD ("Scene Hit Threshold", Float) = 0.0001
        NORMAL_DIFFERENTIAL ("Normal Differential", Float) = 0.0001
        MAX_DISTANCE ("Max Raymarch Distance", Float) = 400.0
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

                } else {
                    discard;
                }

                return color;
            }
            
            ENDCG
        }
    }
}
```
<br/>
You should now be able to see your sdf.

![image](https://user-images.githubusercontent.com/80550270/161395022-1dc6fcf7-ae60-48c9-a403-2b3943563ade.png)

<br/>

**Note: if you can't see your sdf, make sure your cube is centered at (0, 0, 0) and is large enough to enclose the sdf.**

<br/>

## Part 6 - Basic Lighting
This is standard raymarching stuff so I won't explain it. Modify your fragment shader with this code and your sdf scene will be lit with Unity's directional light. I have added a property MATERIAL_COLOR to the shader so we may modify the sdf color from the inspector.
```HLSL
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
```
<br/>

I have applied gamma correction to the colors using 
```HLSL
float3 gammaCorrect(float3 color) {
    color = pow(color, float3(0.4545, 0.4545, 0.4545));
    return color;
}
```
```HLSL
float3 gammaCorrectInverse(float3 color) {
    color = pow(color, float3(2.2, 2.2, 2.2)); 
    return color;
}
```
<br/>
Your sdf should now be lit.

![image](https://user-images.githubusercontent.com/80550270/161395278-5ba7d917-ae1e-4ced-a707-4da154987603.png)

<br/>

## Part 7.1 - Marching Cubes Bounding Mesh
Unfortunately, the inverse of our deformations must be found once at the start of the non linear raymarch. The proposed solution is to replace our cube mesh with a mesh which closely bounds our signed distance field and then deform that mesh (or rather the space around it). See a paper for an explanation of how this uses the rasterizer to find the inverse starting point.

To find a bounding mesh for our signed distance field we can use a compute shader which executes a marching cubes algorithm. For this part I'll supply you with a slightly modified implementation from Sabastian Lague given at https://github.com/SebLague/Marching-Cubes.

Download the compute shaders (MarchingCubes.compute and MarchingTables.compute) and put them in your unity project. Now download MarchingCubes.cs and MarchingCubes_editor.cs. Ensure that MarchingCubes_editor.cs remains in a folder titled Editor.

Put MarchingCubes.cs on your cube and assign MarchingCubes.compute to the Compute Shader property on the cube's MarchingCubes component. You will need to click the Rebuild Mesh button on the component anytime you change your sdf in SceneDefinition.cginc.

<figure>
     <figcaption>The MarchingCubes component on the cube.</figcaption>
    <img src="https://user-images.githubusercontent.com/80550270/161432476-4f7fbf93-8fe3-4498-9d1a-b3821659cbb1.png">
</figure> 

Tweak the Cell Size and Cell Count Per Axis properties on the Marching Cubes component and rebuild the mesh until you can see that the generated mesh properly encloses your sdf.

<figure>
     <figcaption>An enclosing mesh for our signed distance field</figcaption>
    <img src="https://user-images.githubusercontent.com/80550270/161432723-f72d9b80-809c-4829-9fe3-0006d197f461.png">
</figure> 

<br/>

## Part 7.2 - Preparing for Nonlinear Sphere Tracing
We will need to prepare a few more thing in our raymarching shader that the the nonlinear sphere tracing algorithm will need.

Firstly, modify your VertexInterpolants struct to store an additional vector which will store the deformedWorldSpacePosition.
```HLSL
struct VertexInterpolants {
    float4 vertex : SV_POSITION;
    float3 worldSpacePosition : TEXCOORD0;
    float3 deformedWorldSpacePosition : TEXCOORD1;
};
```
<br/>

Now we can create a function to compute our deformation of choice. I have also a added a property to the shader called DEFORMATION_PARAMETER so that we can play with our deformation in the inspector panel. This is just a simple twist deformation but you can use any deformation you want.
```HLSL
float3 deform(float3 x) {
    float alpha = DEFORMATION_PARAMETER;
    return float3(x.x, x.y, (1.0 + 0.5*sin(alpha*x.x))*x.y*x.z);
}  
```
<br/>

Now that we have our deformation defined we can modify our vertex shader to use it.
```HLSL
VertexInterpolants vertexShader (VertexAttributes va) {
    VertexInterpolants vi;

    vi.worldSpacePosition = mul(unity_ObjectToWorld, va.vertex);
    vi.deformedWorldSpacePosition = deform(vi.worldSpacePosition);
    vi.vertex = UnityWorldToClipPos(float4(vi.deformedWorldSpacePosition, 1.0));

    return vi;
}
```
<br/>

We also need to specify the jacobian for the deformation. To make things easy for ourselves we can use a numerical jacobian approximation so that we dont need to do any additional math. 
```HLSL
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
```
<br/>

Next, we will need to implement the ode solver of our choice. I have chosen the second order Runge-Kutta method which you can read about on wikipedia https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods. Since the variable omega from the paper will be used in a few different places, I have placed it's calculation in a function as well. HLSL does not provide a built-in function for computing the inverse of matrices so we will need that too.
```HLSL
float3x3 inverse(float3x3 M) {
    float det = determinant(M);
    
    float3x3 inv = float3x3(
        M[1][1]*M[2][2] - M[1][2]*M[2][1], M[0][2]*M[2][1] - M[0][1]*M[2][2], M[0][1]*M[1][2] - M[0][2]*M[1][1],
        M[1][2]*M[2][0] - M[1][0]*M[2][2], M[0][0]*M[2][2] - M[0][2]*M[2][0], M[0][2]*M[1][0] - M[0][0]*M[1][2],
        M[1][0]*M[2][1] - M[1][1]*M[2][0], M[0][1]*M[2][0] - M[0][0]*M[2][1], M[0][0]*M[1][1] - M[0][1]*M[1][0]
    );
    
    return (1.0f/det)*transpose(inv);
}
```
```HLSL
float3 omega(float3 x, float3 omega0) {
    float3x3 J = jacobian(x);
    float3x3 Jinverse = inverse(J);

    return normalize(mul(Jinverse, omega0));
}
```
```HLSL
float3 rungeKutta(float3 x0, float3 omega0, float sd) {
    float h = sd;

    float3 k1 = omega(x0, omega0);
    float3 k2 = omega(x0 + 0.5f*h*k1, omega0);
    float3 k3 = omega(x0 + 0.5f*h*k2, omega0);
    float3 k4 = omega(x0 + h*k3, omega0);

    return x0 + (h/6.0f)*(k1 + 2.0f*k2 + 2.0f*k3 + k4);
}
```
<br/>

With all that we finally have everything we need to implement the nonlinear sphere tracing algorithm.
<br/>

## Part 8 - Nonlinear Raymarching
Now create the nonlinear raymarching function according to the method described in the paper. The paper does not explain how the normals are to be calculated on the deformed geometry but it turns out that they transform simply with the transpose of the jacobian so we can reuse our getNormal method from before.
```HLSL
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
```
<br/>

Now we can change our fragment shader to use the raymarchNonlinear method like so
```HLSL
float3 rayOrigin = vi.worldSpacePosition;
float3 rayDirection = normalize(vi.deformedWorldSpacePosition - _WorldSpaceCameraPos);

SceneHit sceneHit = raymarchNonlinear(rayOrigin, rayDirection);
```
<br/>

## Conclusion
That's it. If you did everything correctly, you will now have a functioning nonlinear sphere tracer.
![ezgif com-gif-maker](https://user-images.githubusercontent.com/80550270/161434514-51a19693-21bd-4364-972e-8b6adc534201.gif)

And here is the final shader.
```HLSL
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
```
