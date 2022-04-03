using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MarchingCubes : MonoBehaviour {
    public ComputeShader computeShader;
    
    public float cellSize = 0.03f;
    public int cellCountPerAxis = 32;
    public float sdfPadding = 0.05f;
    public bool autoRemesh = false;
    
    public int threadCount = 8;

    private ComputeBuffer triangleBuffer;
    private ComputeBuffer triCountBuffer;
    
    public struct float3 {
        public float x;
        public float y;
        public float z;
    }
    public struct Triangle {
        public float3 p0;
        public float3 p1;
        public float3 p2;
    }
    
    public void BuildMesh() {
        int maxTriangleCount = 5*cellCountPerAxis*cellCountPerAxis*cellCountPerAxis;
        triangleBuffer = new ComputeBuffer(maxTriangleCount, 3*3*sizeof(float), ComputeBufferType.Append);
        triCountBuffer = new ComputeBuffer (1, sizeof (int), ComputeBufferType.Raw);

        triangleBuffer.SetCounterValue (0);
        computeShader.SetInt("cellCountPerAxis", cellCountPerAxis);
        computeShader.SetFloat("cellSize", cellSize);
        computeShader.SetFloat("sdfPadding", sdfPadding);
        computeShader.SetBuffer(0, "triangles", triangleBuffer);

        int dispatchCount = Mathf.CeilToInt (cellCountPerAxis / (float) threadCount);
        computeShader.Dispatch (0, dispatchCount, dispatchCount, dispatchCount);

        // Get number of triangles in the triangle buffer
        ComputeBuffer.CopyCount (triangleBuffer, triCountBuffer, 0);
        int[] triCountArray = { 0 };
        triCountBuffer.GetData (triCountArray);
        int numTris = triCountArray[0];

        // Get triangle data from shader
        Triangle[] tris = new Triangle[numTris];
        triangleBuffer.GetData (tris, 0, 0, numTris);

        triangleBuffer.Dispose();
        triCountBuffer.Dispose();

        Mesh mesh = new Mesh();
        mesh.name = "Generated Mesh";
        mesh.Clear ();

        var vertices = new Vector3[numTris * 3];
        var meshTriangles = new int[numTris * 3];

        for (int i = 0; i < numTris; i++) {
            for (int j = 0; j < 3; j++) {
                meshTriangles[i * 3 + j] = i * 3 + j;
                Vector3 vec;
                if(j == 0) {
                    float3 f3 = tris[i].p2;
                    vec = new Vector3(f3.x, f3.y, f3.z);
                } else if(j == 1) {
                    float3 f3 = tris[i].p1;
                    vec = new Vector3(f3.x, f3.y, f3.z);
                } else {
                    float3 f3 = tris[i].p0;
                    vec = new Vector3(f3.x, f3.y, f3.z);
                }
                 
                vertices[i * 3 + j] = vec;
            }
        }
        mesh.vertices = vertices;
        mesh.triangles = meshTriangles;
        mesh.RecalculateNormals();

        MeshFilter filter = transform.GetComponent<MeshFilter>();
        filter.mesh = mesh;

      //  mesh.RecalculateNormals ();
    }
}
