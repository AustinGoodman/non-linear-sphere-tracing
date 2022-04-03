using UnityEngine;
using System.Collections;
using UnityEditor;

[CustomEditor(typeof(MarchingCubes))]
public class MarchingCubes_editor : Editor 
{
    public override void OnInspectorGUI() {
        MarchingCubes myTarget = (MarchingCubes)target;
        DrawDefaultInspector();

        if(GUILayout.Button("Rebuild Mesh")) {
            myTarget.BuildMesh();
        }
    }
}