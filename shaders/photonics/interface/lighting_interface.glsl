uniform vec3 light_dir;
uniform float worldTime;

uniform sampler2D colortex4;

#include "/include/sky/projection.glsl"
#include "/include/utility/bicubic.glsl"

const float blocklight_scale = 6.0f;
const float rcp_blocklight_scale = 1.0f /blocklight_scale;

vec3 get_sun_direction() {
    return light_dir;
}

vec3 get_light_color() {
#if defined OVERWORLD
#ifdef SH_SKYLIGHT
    return texelFetch(colortex4, ivec2(191, 11), 0).rgb * rcp_blocklight_scale;
#else
    return texelFetch(colortex4, ivec2(191, 1), 0).rgb * rcp_blocklight_scale;
#endif
#else
    return mix(texelFetch(colortex4, ivec2(191, 1), 0).rgb, vec3(1.0f), 0.5) * rcp_blocklight_scale;
#endif
}

vec3 get_sky_color(vec3 player_pos, vec3 direction) {
    const float sun_inverse = 1.0f / SUN_I;
    return bicubic_filter(colortex4, project_sky(direction)).rgb * sun_inverse *  SKYLIGHT_I;
}

vec3 get_sun_color(vec3 player_pos, vec3 directioin) {
    return get_light_color() * BOUNCED_LIGHT_I * 4.0f;
}

#if defined OVERWORLD

#define WORLD_OVERWORLD
#include "/photonics/interface/is_in_shadow.glsl"

#elif defined END

#define WORLD_END
#include "/photonics/interface/is_in_shadow.glsl"

#else
bool is_in_shadow_at(vec3 scene_pos, vec3 geo_normal) {
    return false;
}
#endif

bool sample_sun_color(vec3 scene_pos, vec3 geo_normal, inout vec3 sun_color) {
    return is_in_shadow_at(scene_pos, geo_normal);
}
