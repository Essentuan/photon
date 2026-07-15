uniform vec3 light_dir;
uniform float worldTime;

uniform sampler2D colortex4;

#include "/include/sky/projection.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
#include "/photonics/interface/is_in_shadow.glsl"
#else
bool is_in_shadow_at(vec3 scene_pos, vec3 geo_normal) {
    return false;
}
#endif

const float blocklight_scale = 6.0f;
const float rcp_blocklight_scale = 1.0f /blocklight_scale;

vec3 get_sun_direction() {
    return light_dir;
}

vec3 get_sky_color(vec3 player_pos, vec3 direction) {
    return bicubic_filter(colortex4, project_sky(direction)).rgb * SKYLIGHT_I * rcp_blocklight_scale;
}

vec3 get_sun_color(vec3 player_pos, vec3 d) {
    vec3 sun_color = texelFetch(colortex4, ivec2(191, 0), 0).rgb * rcp_blocklight_scale;

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
    float cloud_shadows = get_cloud_shadows(colortex8, player_pos);
#else
    const float cloud_shadows = 1.0;
#endif

    return sun_color * BOUNCED_LIGHT_I * cloud_shadows;
}

bool sample_sun_color(vec3 scene_pos, vec3 geo_normal, inout vec3 sun_color) {
    return is_in_shadow_at(scene_pos, geo_normal);
}
