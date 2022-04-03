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