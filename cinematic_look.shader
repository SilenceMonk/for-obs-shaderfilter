// =========================================================================
//  Cinematic Look Shader for OBS Studio (HLSL - Final Bloom Fix)
//  Replaced array initializer with a compatible nested loop.
// =========================================================================

// --- Uniforms will create sliders in the OBS filter properties ---

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

// -- Bloom / Glow --
uniform float bloom_intensity<
    string label = "辉光强度 (Bloom Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 0.5;

uniform float bloom_threshold<
    string label = "辉光阈值 (Bloom Threshold)";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 1.0;
    float step = 0.01;
> = 0.8;

uniform float bloom_radius<
    string label = "辉光半径 (Bloom Radius)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 10.0;
    float step = 0.1;
> = 3.0;

// -- Texture --
uniform float grain_intensity<
    string label = "胶片颗粒强度 (Grain Intensity)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.2;
    float step = 0.005;
> = 0.04;

uniform string notes<
    string widget_type = "info";
> = "电影感调色滤镜 (最终版)\n- 包含调色、对比度、颗粒感和辉光效果。";

// --- Helper Function: Pseudo-random number generator ---
float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// --- Main Shader Function ---
float4 mainImage(VertData v_in) : TARGET
{
    // === PART 1: CINEMATIC COLOR GRADING ===
    float4 original_color = image.Sample(textureSampler, v_in.uv);
    float3 graded_color = original_color.rgb;
    
    graded_color = pow(graded_color, float3(contrast, contrast, contrast));

    float luma = dot(graded_color, float3(0.299, 0.587, 0.114));
    float3 teal_color = float3(0.7, 0.85, 1.0);
    float3 orange_color = float3(1.0, 0.9, 0.7);
    graded_color = lerp(graded_color, teal_color, smoothstep(0.5, 1.0, luma) * teal_amount);
    graded_color = lerp(graded_color, orange_color, smoothstep(0.4, 0.0, luma) * orange_amount);


    // === PART 2: CALCULATE BLOOM/GLOW EFFECT ===
    float3 bloom_color = float3(0,0,0);
    float2 pixel_size = uv_size;

    // THE FIX IS HERE: Replaced the incompatible array initializer with a nested loop.
    // This samples a 3x3 grid around the current pixel.
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float2 offset = float2(x, y);
            float2 sample_uv = v_in.uv + offset * pixel_size * bloom_radius;
            float3 sample_color = image.Sample(textureSampler, sample_uv).rgb;
            
            float sample_luma = dot(sample_color, float3(0.299, 0.587, 0.114));
            float bright_factor = smoothstep(bloom_threshold, 1.0, sample_luma);
            
            bloom_color += sample_color * bright_factor;
        }
    }

    // Average the blurred result (we took 9 samples)
    bloom_color /= 9.0;


    // === PART 3: COMBINE EVERYTHING ===
    float3 final_color = graded_color;
    final_color += bloom_color * bloom_intensity; // Add bloom
    
    float grain = (random(v_in.uv + frac(elapsed_time)) - 0.5) * 2.0;
    final_color += grain * grain_intensity; // Add grain
    
    return float4(clamp(final_color, 0.0, 1.0), original_color.a);
}

