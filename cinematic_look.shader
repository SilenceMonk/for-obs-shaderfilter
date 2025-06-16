// =========================================================================
//  Cinematic Look Shader for OBS Studio (HLSL - Full Suite, Final Version)
//  Features: Color Grade, Contrast, Grain, Bloom, Halation, Secondary Glow, Camera Shake.
// =========================================================================

// --- Uniforms ---

// -- Color & Contrast --
uniform float contrast<
    string label = "对比度 (Contrast)";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 2.5;
    float step = 0.05;
> = 1.2;

uniform float teal_amount<
    string label = "高光青色量 (Teal Amount)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.2;

uniform float orange_amount<
    string label = "暗部橙色量 (Orange Amount)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.15;

// -- Bloom / White Glow --
uniform float bloom_intensity<
    string label = "[辉光] 强度 (Bloom Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 4.0;
    float step = 0.05;
> = 0.5;

uniform float bloom_threshold<
    string label = "[辉光] 阈值 (Bloom Threshold)";
    string widget_type = "slider";
    float minimum = 0.3;
    float maximum = 1.0;
    float step = 0.01;
> = 0.8;

uniform int bloom_radius<
    string label = "[辉光] 半径 (Bloom Radius)";
    string widget_type = "slider";
    int minimum = 1;
    int maximum = 5;
    int step = 1;
> = 2;

// -- Halation / Red-Orange Glow --
uniform float halation_intensity<
    string label = "[光晕环] 强度 (Halation Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 4.0;
    float step = 0.05;
> = 0.4;

uniform float halation_threshold<
    string label = "[光晕环] 阈值 (Halation Threshold)";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 1.0;
    float step = 0.01;
> = 0.95;

uniform int halation_radius<
    string label = "[光晕环] 半径 (Halation Radius)";
    string widget_type = "slider";
    int minimum = 2;
    int maximum = 8;
    int step = 1;
> = 4;

// -- Secondary Glow (Cool Tint) --
uniform float secondary_glow_intensity<
    string label = "[二次辉光] 强度 (Secondary Glow Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 3.0;
    float step = 0.05;
> = 0.3;

uniform float secondary_glow_threshold<
    string label = "[二次辉光] 阈值 (Secondary Glow Threshold)";
    string widget_type = "slider";
    float minimum = 0.3;
    float maximum = 1.0;
    float step = 0.01;
> = 0.75;

uniform int secondary_glow_radius<
    string label = "[二次辉光] 半径 (Secondary Glow Radius)";
    string widget_type = "slider";
    int minimum = 1;
    int maximum = 7;
    int step = 1;
> = 3;

// -- Texture --
uniform float grain_intensity<
    string label = "胶片颗粒强度 (Grain Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.2;
    float step = 0.005;
> = 0.04;

// -- Camera Shake --
uniform float shake_intensity<
    string label = "[镜头抖动] 强度 (Shake Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.02; // Small values are usually enough
    float step = 0.0005;
> = 0.002;

uniform float shake_speed<
    string label = "[镜头抖动] 速度 (Shake Speed)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 20.0;
    float step = 0.5;
> = 5.0;


uniform string notes<
    string widget_type = "info";
> = "电影感调色滤镜 (全功能最终版)\n- 辉光(Bloom)是白色柔光，光晕环(Halation)是红色辉光。\n- 新增二次辉光(Secondary Glow)，通常为冷色调辉光。\n- 新增镜头抖动效果。";


// --- Helper Functions ---
float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// Screen blend mode
float3 BlendScreen(float3 base, float3 blend)
{
    return 1.0 - ((1.0 - base) * (1.0 - blend));
}

// --- Main Shader Function ---
float4 mainImage(VertData v_in) : TARGET
{
    // === PART 0: CAMERA SHAKE ===
    float2 shake_offset = float2(0.0, 0.0);
    if (shake_intensity > 0.0) {
        float time = elapsed_time * shake_speed;
        float shake_x = (sin(time * 1.3 + 0.5) + sin(time * 2.7 + 1.2)) * 0.5;
        float shake_y = (cos(time * 1.7 - 0.8) + cos(time * 3.1 - 0.3)) * 0.5;
        shake_offset = float2(shake_x, shake_y) * shake_intensity;
    }
    float2 shaken_uv = v_in.uv + shake_offset;


    // === PART 1: CINEMATIC COLOR GRADING ===
    float4 original_color = image.Sample(textureSampler, shaken_uv);
    float3 graded_color = original_color.rgb;
    
    graded_color = pow(graded_color, float3(contrast, contrast, contrast));
    float luma = dot(graded_color, float3(0.299, 0.587, 0.114));
    float3 teal_color = float3(0.7, 0.85, 1.0);
    float3 orange_color = float3(1.0, 0.9, 0.7);
    graded_color = lerp(graded_color, teal_color, smoothstep(0.5, 1.0, luma) * teal_amount);
    graded_color = lerp(graded_color, orange_color, smoothstep(0.4, 0.0, luma) * orange_amount);


    // === PART 2: CALCULATE EFFECTS (BLOOM, HALATION, SECONDARY GLOW) ===
    float3 bloom_accum = float3(0,0,0);
    float3 halation_accum = float3(0,0,0);
    float3 secondary_glow_accum = float3(0,0,0); // New: For secondary glow
    float2 pixel_size = uv_size; 
    
    int max_radius_for_loop = max(bloom_radius, halation_radius);
    max_radius_for_loop = max(max_radius_for_loop, secondary_glow_radius); // Determine overall max radius

    float bloom_sample_count = 0.0;
    float halation_sample_count = 0.0;
    float secondary_glow_sample_count = 0.0; // New

    [loop]
    for (int x = -max_radius_for_loop; x <= max_radius_for_loop; x++) {
        [loop]
        for (int y = -max_radius_for_loop; y <= max_radius_for_loop; y++) {
            float2 offset = float2(x, y);
            float2 sample_uv = shaken_uv + offset * pixel_size; 
            float3 sample_color = image.Sample(textureSampler, sample_uv).rgb;
            float sample_luma = dot(sample_color, float3(0.299, 0.587, 0.114));

            // -- Calculate Bloom --
            if (bloom_intensity > 0.0 && abs(x) <= bloom_radius && abs(y) <= bloom_radius) {
                float bright_factor = smoothstep(bloom_threshold, 1.0, sample_luma);
                bloom_accum += sample_color * bright_factor;
                bloom_sample_count += 1.0;
            }

            // -- Calculate Halation --
            if (halation_intensity > 0.0 && abs(x) <= halation_radius && abs(y) <= halation_radius) {
                float halation_bright_factor = smoothstep(halation_threshold, 1.0, sample_luma);
                float3 tinted_color = sample_color * float3(1.0, 0.2, 0.1); 
                halation_accum += tinted_color * halation_bright_factor;
                halation_sample_count += 1.0;
            }

            // -- Calculate Secondary Glow --
            if (secondary_glow_intensity > 0.0 && abs(x) <= secondary_glow_radius && abs(y) <= secondary_glow_radius) {
                float sg_bright_factor = smoothstep(secondary_glow_threshold, 1.0, sample_luma);
                float3 sg_tint = float3(0.6, 0.8, 1.0); // Cool cyan/blue tint
                secondary_glow_accum += (sample_color * sg_tint) * sg_bright_factor;
                secondary_glow_sample_count += 1.0;
            }
        }
    }

    if (bloom_sample_count > 0.0) { bloom_accum /= bloom_sample_count; }
    if (halation_sample_count > 0.0) { halation_accum /= halation_sample_count; }
    if (secondary_glow_sample_count > 0.0) { secondary_glow_accum /= secondary_glow_sample_count; }


    // === PART 3: COMBINE EVERYTHING ===
    float3 final_color = graded_color;
    
    // Additive blend for white bloom
    if (bloom_intensity > 0.0) {
        final_color += bloom_accum * bloom_intensity;
    }
    
    // Screen blend for colored halation
    if (halation_intensity > 0.0) {
        final_color = BlendScreen(final_color, halation_accum * halation_intensity);
    }

    // Screen blend for secondary glow (cool tint)
    if (secondary_glow_intensity > 0.0) {
        final_color = BlendScreen(final_color, secondary_glow_accum * secondary_glow_intensity);
    }
    
    // Add grain on top of everything
    float2 grain_seed_uv = shaken_uv + frac(elapsed_time); // Grain moves with image
    // To make grain an overlay that doesn3't shake with the image, use this instead:
    // float2 grain_seed_uv = v_in.uv + frac(elapsed_time); 
    
    float grain = (random(grain_seed_uv) - 0.5) * 2.0;
    final_color += grain * grain_intensity;
    
    return float4(clamp(final_color, 0.0, 1.0), original_color.a);
}