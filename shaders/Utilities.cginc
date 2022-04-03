#define mod(x, y) (x - y * floor(x / y))

float3 gammaCorrect(float3 color) {
    color = pow(color, float3(0.4545, 0.4545, 0.4545));
    return color;
}

float3 gammaCorrectInverse(float3 color) {
    color = pow(color, float3(2.2, 2.2, 2.2)); 
    return color;
}

float3x3 inverse(float3x3 M) {
    float det = determinant(M);
    
    float3x3 inv = float3x3(
        M[1][1]*M[2][2] - M[1][2]*M[2][1], M[0][2]*M[2][1] - M[0][1]*M[2][2], M[0][1]*M[1][2] - M[0][2]*M[1][1],
        M[1][2]*M[2][0] - M[1][0]*M[2][2], M[0][0]*M[2][2] - M[0][2]*M[2][0], M[0][2]*M[1][0] - M[0][0]*M[1][2],
        M[1][0]*M[2][1] - M[1][1]*M[2][0], M[0][1]*M[2][0] - M[0][0]*M[2][1], M[0][0]*M[1][1] - M[0][1]*M[1][0]
    );
    
    return (1.0f/det)*transpose(inv);
}