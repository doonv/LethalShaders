#version 120

#include "/settings.glsl"

uniform sampler2D texture;

uniform float viewWidth;
uniform float viewHeight;
vec2 view = vec2(viewWidth, viewHeight);
uniform vec3 fogColor;
varying vec4 color;
varying vec2 coord0;

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

vec4 texture2DPixel(sampler2D tex, vec2 uv) {
    #if PIXEL_SIZE == 0
        return texture2D(tex, uv);
    #else
        vec2 viewPixellated = view / PIXEL_SIZE;
        return texture2D(tex, floor(uv * viewPixellated) / viewPixellated);
    #endif
}

uniform float far;
uniform float near;

vec3 generic_desaturate(vec3 color, float factor)
{
	vec3 lum = vec3(0.299, 0.587, 0.114);
	vec3 gray = vec3(dot(lum, color));
	return mix(color, gray, factor);
}

void posterize(inout vec3 color) {
    float greyscale = max(color.r, max(color.g, color.b));

    float lower     = floor(greyscale * POSTERIZATION_LEVELS) / POSTERIZATION_LEVELS;
    float lowerDiff = abs(greyscale - lower);

    float upper     = ceil(greyscale * POSTERIZATION_LEVELS) / POSTERIZATION_LEVELS;
    float upperDiff = abs(upper - greyscale);

    float level      = lowerDiff <= upperDiff ? lower : upper;
    float adjustment = level / greyscale;

    color.rgb = color.rgb * adjustment;
}
uniform sampler2D depthtex0;

float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
void main()
{
    vec4 final_color = color * texture2DPixel(texture, coord0);
    final_color.rgb = generic_desaturate(final_color.rgb, 1.0 - SATURATION);
    if (POSTERIZATION_LEVELS > 0) {
        posterize(final_color.rgb);
    }

    float depth = GetLinearDepth(texture2D(depthtex0, coord0).r) * fogDensity();
    final_color.rgb = mix(final_color.rgb, fogColor, clamp(depth, 0.0, 1.0));

    gl_FragData[0] = final_color;
}
