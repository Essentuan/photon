uniform vec3 light_dir;
uniform float worldTime;

uniform sampler2D colortex4;

const float blocklight_scale = 6.0f;
const float rcp_blocklight_scale = 1.0f / blocklight_scale;

vec3 get_sun_direction() {
    return light_dir;
}

vec3 get_sky_color(vec3 player_pos, vec3 direction) {
#if defined WORLD_OVERWORLD
#ifdef SH_SKYLIGHT
    vec3 skylight = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
#else
    vec3 skylight = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
#endif
#else
    vec3 skylight = mix(texelFetch(colortex4, ivec2(191, 1), 0).rgb, vec3(1.0f), 0.5);
#endif

    return skylight * SKYLIGHT_I * rcp_blocklight_scale;
}

vec3 get_sun_color(vec3 player_pos, vec3 direction) {
    return texelFetch(colortex4, ivec2(191, 0), 0).rgb * BOUNCED_LIGHT_I * rcp_blocklight_scale;
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
