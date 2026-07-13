#undef SHADOW_VPS
#undef PIXELATED_SHADOWS
#undef SHADOW_COLOR

#define SHADOW

uniform sampler2D noisetex;
uniform int moonPhase;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;

#include "/include/utility/fast_math.glsl"
#include "/include/lighting/shadows/pcss.glsl"

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8;
uniform float eyeAltitude;

#include "/include/lighting/cloud_shadows.glsl"
#endif

bool is_in_shadow_at(vec3 scene_pos, vec3 geo_normal) {
    float distance_fade = 0f;
    float sss_depth = 0f;

    vec3 shadow = get_filtered_shadows(
        scene_pos,
        geo_normal,
        1.0f,
        0.0f,
        0.0f,
        distance_fade,
        sss_depth
    );

    return any(lessThan(shadow, vec3(1.0f)));
}
