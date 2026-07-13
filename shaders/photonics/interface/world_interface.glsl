#if defined OVERWORLD
#define WORLD_OVERWORLD
#elif defined NETHER
#define WORLD_NETHER
#elif defined END
#define WORLD_END
#endif

#include "/include/global.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex1;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;


uniform float near;
uniform float far;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#include "/include/utility/space_conversion.glsl"
#include "/include/utility/encoding.glsl"

bool is_in_world() {
    return texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x <= 0.99999f;
}

bool is_hand_at() {
    return texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x < 0.56;
}

vec3 load_player_position() {
    vec2 view_coord = gl_FragCoord.xy * view_pixel_size;
    vec3 screen_pos = vec3(view_coord.xy * rcp(taau_render_scale), texture(depthtex1, view_coord).r);

    vec3 view_pos = screen_to_view_space(screen_pos, true);
    vec3 scene_pos = view_to_scene_space(view_pos);

    return scene_pos;
}


void load_fragment_data(
    out vec3 geometry_normal,
    out vec3 texture_normal
) {
    vec2 view_coord = gl_FragCoord.xy * view_pixel_size;

    vec4 gbuffer_data_0 = texture(colortex1, view_coord);
    geometry_normal = decode_unit_vector(unpack_unorm_2x8(gbuffer_data_0.z));

#if defined NORMAL_MAPPING
    vec4 gbuffer_data_1 = texture(colortex2, view_coord);
    texture_normal = decode_unit_vector(gbuffer_data_1.xy);
#else
    texture_normal = geometry_normal;
#endif
}

vec2 get_taa_jitter() {
#ifdef TAA

#ifdef TAAU
    return taa_offset * rcp(taau_render_scale);
#else
    return taa_offset * 0.66;
#endif

#else
    return vec2(0.0f);
#endif
}
