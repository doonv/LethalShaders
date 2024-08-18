#version 120

// Outline pass
//
// I couldn't figure out how to make a pixelated outline shader, 
// so I just used a normal outline shader and then let the final pass pixelate it.

#include "/settings.glsl"

uniform int isEyeInWater;
float fogDensity() {
    if (isEyeInWater == 2) {
        return CUSTOM_FOG_DENSITY_LAVA;
    } else if (isEyeInWater == 1) {
        return CUSTOM_FOG_DENSITY_WATER;
    } else {
        return CUSTOM_FOG_DENSITY;
    }
}

uniform sampler2D colortex0;
varying vec2 coord0;

uniform float far;
uniform float near;
uniform sampler2D depthtex0;
float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

uniform float viewWidth;
uniform float viewHeight;
vec2 view = vec2(viewWidth, viewHeight);

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
flat in vec3 upVec, sunVec;

vec2 darkOutlineOffsets[12] = vec2[12](
    vec2( 1.0, 0.0),
    vec2(-1.0, 1.0),
    vec2( 0.0, 1.0),
    vec2( 1.0, 1.0),
    vec2(-2.0, 2.0),
    vec2(-1.0, 2.0),
    vec2( 0.0, 2.0),
    vec2( 1.0, 2.0),
    vec2( 2.0, 2.0),
    vec2(-2.0, 1.0),
    vec2( 2.0, 1.0),
    vec2( 2.0, 0.0)
);
vec3 ViewToPlayer(vec3 pos) {
    return mat3(gbufferModelViewInverse) * pos + gbufferModelViewInverse[3].xyz;
}
void DoDarkOutline(inout vec3 color) {
    vec2 scale = vec2(1.0 / view);

    float z0 = texture2D(depthtex0, coord0).r;
    float linearZ0 = GetLinearDepth(z0);
    float outline = 1.0;
    float z = linearZ0 * far * 2.0;
    float minZ = 1.0, sampleZA = 0.0, sampleZB = 0.0;
    int sampleCount = 12;

    for (int i = 0; i < sampleCount; i++) {
        vec2 offset = scale * darkOutlineOffsets[i];
        sampleZA = texture2D(depthtex0, coord0 + offset).r;
        sampleZB = texture2D(depthtex0, coord0 - offset).r;
        float sampleZsum = GetLinearDepth(sampleZA) + GetLinearDepth(sampleZB);
        outline *= clamp(1.0 - (z - sampleZsum * far), 0.0, 1.0);
        minZ = min(minZ, min(sampleZA, sampleZB));
    }

    if (outline < 0.909091) {
        vec4 viewPos = gbufferProjectionInverse * (vec4(coord0, minZ, 1.0) * 2.0 - 1.0);
        viewPos /= viewPos.w;
        float lViewPos = length(viewPos.xyz);
        vec3 playerPos = ViewToPlayer(viewPos.xyz);
        vec3 nViewPos = normalize(viewPos.xyz);
        float VdotU = dot(nViewPos, upVec);
        float VdotS = dot(nViewPos, sunVec);

        vec3 newColor = vec3(0.0);

        vec3 color_with_outlines = mix(color, newColor, 1.0 - outline * 1.1);

        float depth = GetLinearDepth(texture2D(depthtex0, coord0).r) * fogDensity();
        color = mix(color_with_outlines, color, clamp(depth, 0.0, 1.0));
    }
}

void main() {
    vec4 color = texture2D(colortex0, coord0);
    #ifdef OUTLINE_ENABLED
        DoDarkOutline(color.rgb);
    #endif
    gl_FragData[0] = color;
}