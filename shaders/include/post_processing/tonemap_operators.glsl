#if !defined INCLUDE_MISC_TONEMAP_OPERATORS
#define INCLUDE_MISC_TONEMAP_OPERATORS

#include "/include/post_processing/aces/aces.glsl"
#include "/include/utility/color.glsl"

// ACES RRT and ODT
vec3 tonemap_aces_full(vec3 rgb) {
    rgb *= 1.6; // Match the exposure to the RRT

    rgb = rgb * rec2020_to_ap0;

    rgb = aces_rrt(rgb);
    rgb = aces_odt(rgb);

    return rgb * ap1_to_rec2020;
}

// ACES RRT and ODT approximation
vec3 tonemap_aces_fit(vec3 rgb) {
    rgb *= 1.6; // Match the exposure to the RRT

    rgb = rgb * rec2020_to_ap0;

    rgb = rrt_sweeteners(rgb);
    rgb = rrt_and_odt_fit(rgb);

    // Global desaturation
    vec3 grayscale = vec3(dot(rgb, luminance_weights));
    rgb = mix(grayscale, rgb, odt_sat_factor);

    return rgb * ap1_to_rec2020;
}

// from https://iolite-engine.com/blog_posts/minimal_agx_implementation
// MIT License
//
// Copyright (c) 2024 Missing Deadlines (Benjamin Wrensch)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// All values used to derive this implementation are sourced from Troy’s initial AgX implementation/OCIO config file available here:
//   https://github.com/sobotka/AgX

// Mean error^2: 3.6705141e-06
vec3 agxDefaultContrastApprox(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;

    return + 15.5     * x4 * x2
    - 40.14    * x4 * x
    + 31.96    * x4
    - 6.868    * x2 * x
    + 0.4298   * x2
    + 0.1191   * x
    - 0.00232;
}

vec3 agx(vec3 val) {
    const mat3 agx_mat = mat3(
            0.842479062253094, 0.0423282422610123, 0.0423756549057051,
            0.0784335999999992,  0.878468636469772,  0.0784336,
            0.0792237451477643, 0.0791661274605434, 0.879142973793104);

    const float min_ev = -12.47393f;
    const float max_ev = 4.026069f;

    // Input transform (inset)
    val = agx_mat * val;

    // Log2 space encoding
    val = clamp(log2(val), min_ev, max_ev);
    val = (val - min_ev) / (max_ev - min_ev);

    // Apply sigmoid function approximation
    val = agxDefaultContrastApprox(val);

    return val;
}

vec3 agxEotf(vec3 val) {
    const mat3 agx_mat_inv = mat3(
            1.19687900512017, -0.0528968517574562, -0.0529716355144438,
            -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
            -0.0990297440797205, -0.0989611768448433, 1.15107367264116);

    // Inverse input transform (outset)
    val = agx_mat_inv * val;

    // sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
    // NOTE: We're linearizing the output here. Comment/adjust when
    // *not* using a sRGB render target
    val = pow(val, vec3(2.2));

    return val;
}

vec3 agxLook(vec3 val) {
#if AGX_LOOK == 0
    // Default
    const vec3 offset = vec3(0.0);
    const vec3 slope = vec3(1.0);
    const vec3 power = vec3(1.0);
    const float sat = 1.0;
#elif AGX_LOOK == 1
    // Golden
    const vec3 offset = vec3(0.0);
    const vec3 slope = vec3(1.0, 0.9, 0.5);
    const vec3 power = vec3(0.8);
    const float sat = 0.8;
#elif AGX_LOOK == 2
    // Punchy
    const vec3 offset = vec3(0.0);
    const vec3 slope = vec3(1.0);
    const vec3 power = vec3(1.35, 1.35, 1.35);
    const float sat = 1.4;
#endif

    // ASC CDL
    val = pow(val * slope + offset, power);

    const vec3 lw = vec3(0.2126, 0.7152, 0.0722);
    float luma = dot(val, lw);

    return luma + sat * (val - luma);
}

vec3 tonemap_agx(vec3 rgb) {
    rgb = agx(rgb);
    rgb = agxLook(rgb);
    rgb = agxEotf(rgb);
    return rgb;
}

vec3 tonemap_hejl_2015(vec3 rgb) {
    const float white_point = 5.0;

    vec4 vh = vec4(rgb, white_point);
    vec4 va = (1.425 * vh) + 0.05; // eval filmic curve
    vec4 vf = ((vh * va + 0.004) / ((vh * (va + 0.55) + 0.0491))) - 0.0821;

    return vf.rgb / vf.www; // white point correction
}

// Filmic tonemapping operator made by Jim Hejl and Richard Burgess
// Modified by Tech to not lose color information below 0.004
vec3 tonemap_hejl_burgess(vec3 rgb) {
    rgb = rgb * min(vec3(1.0), 1.0 - 0.8 * exp(rcp(-0.004) * rgb));
    rgb = (rgb * (6.2 * rgb + 0.5)) / (rgb * (6.2 * rgb + 1.7) + 0.06);
    return srgb_eotf_inv(rgb); // Revert built-in sRGB conversion
}

// Timothy Lottes 2016, "Advanced Techniques and Optimization of HDR Color
// Pipelines" https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
vec3 tonemap_lottes(vec3 rgb) {
    const vec3 a = vec3(1.5); // Contrast
    const vec3 d = vec3(0.91); // Shoulder contrast
    const vec3 hdr_max = vec3(8.0); // White point
    const vec3 mid_in = vec3(0.26); // Fixed midpoint x
    const vec3 mid_out = vec3(0.32); // Fixed midput y

    const vec3 b = (-pow(mid_in, a) + pow(hdr_max, a) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);
    const vec3 c = (pow(hdr_max, a * d) * pow(mid_in, a)
                    - pow(hdr_max, a) * pow(mid_in, a * d) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);

    return pow(rgb, a) / (pow(rgb, a * d) * b + c);
}

// Filmic tonemapping operator made by John Hable for Uncharted 2
vec3 tonemap_uncharted_2_partial(vec3 rgb) {
    const float a = 0.15;
    const float b = 0.50;
    const float c = 0.10;
    const float d = 0.20;
    const float e = 0.02;
    const float f = 0.30;

    return ((rgb * (a * rgb + (c * b)) + (d * e))
            / (rgb * (a * rgb + b) + d * f))
        - e / f;
}

vec3 tonemap_uncharted_2(vec3 rgb) {
    const float exposure_bias = 2.0;
    const vec3 w = vec3(11.2);

    vec3 curr = tonemap_uncharted_2_partial(rgb * exposure_bias);
    vec3 white_scale = vec3(1.0) / tonemap_uncharted_2_partial(w);
    return curr * white_scale;
}

// Tone mapping operator made by Tech for his shader pack Lux
vec3 tonemap_tech(vec3 rgb) {
    vec3 a = rgb * min(vec3(1.0), 1.0 - exp(-1.0 / 0.038 * rgb));
    a = mix(a, rgb, rgb * rgb);
    return a / (a + 0.6);
}

// Tonemapping operator made by Zombye for his old shader pack Ozius
// It was given to me by Jessie
vec3 tonemap_ozius(vec3 rgb) {
    const vec3 a = vec3(0.46, 0.46, 0.46);
    const vec3 b = vec3(0.60, 0.60, 0.60);

    rgb *= 1.6;

    vec3 cr = mix(vec3(dot(rgb, luminance_weights_ap1)), rgb, 0.5) + 1.0;

    rgb = pow(rgb / (1.0 + rgb), a);
    return pow(rgb * rgb * (-2.0 * rgb + 3.0), cr / b);
}

vec3 tonemap_reinhard(vec3 rgb) { return rgb / (rgb + 1.0); }

vec3 tonemap_reinhard_jodie(vec3 rgb) {
    vec3 reinhard = rgb / (rgb + 1.0);
    return mix(rgb / (dot(rgb, luminance_weights) + 1.0), reinhard, reinhard);
}

#endif // INCLUDE_MISC_TONEMAP_OPERATORS
