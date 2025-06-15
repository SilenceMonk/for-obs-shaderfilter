// =========================================================================
//  Enhanced VHS/NTSC Shader for OBS Studio
//  Based on ntsc-rs implementation
//  Features: YIQ processing, advanced noise, head switching, tracking,
//            edge wave, chroma errors, and more accurate VHS simulation
// =========================================================================

// --- Uniforms ---

uniform float saturation<
    string label = "饱和度 (Saturation)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 1.2;

uniform float contrast<
    string label = "对比度 (Contrast)";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 2.0;
    float step = 0.05;
> = 1.1;

uniform float luma_smear<
    string label = "亮度拖尾 (Luma Smear)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.05;
> = 0.2;

uniform float chroma_delay<
    string label = "色彩延迟 (Chroma Delay)";
    string widget_type = "slider";
    float minimum = -0.01;
    float maximum = 0.01;
    float step = 0.0005;
> = 0.002;

uniform float chroma_phase_error<
    string label = "色相误差 (Chroma Phase Error)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.1;

uniform float composite_noise<
    string label = "复合信号噪声 (Composite Noise)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.3;
    float step = 0.01;
> = 0.05;

uniform float snow_intensity<
    string label = "雪花噪点 (Snow)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.1;
    float step = 0.005;
> = 0.01;

uniform float scanline_intensity<
    string label = "扫描线强度 (Scanline)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.15;

uniform float head_switch_height<
    string label = "磁头切换高度 (Head Switch Height)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.1;
    float step = 0.005;
> = 0.02;

uniform float tracking_noise_height<
    string label = "跟踪噪声高度 (Tracking Noise)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.2;
    float step = 0.01;
> = 0.05;

uniform float edge_wave_amount<
    string label = "边缘波动 (Edge Wave)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.02;
    float step = 0.001;
> = 0.005;

uniform float vignette_intensity<
    string label = "暗角强度 (Vignette)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.1;
> = 0.8;

uniform float tape_speed<
    string label = "磁带速度 (Tape Speed) 0=SP 0.5=LP 1=EP";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.5;
> = 0.5;

uniform string notes<
    string widget_type = "info";
> = "基于ntsc-rs的高级VHS/NTSC模拟滤镜";


// --- Color Space Conversion ---

// RGB to YIQ conversion matrix (NTSC standard)
float3 rgb_to_yiq(float3 rgb) {
    const float3x3 transform = float3x3(
        0.299,  0.587,  0.114,
        0.596, -0.275, -0.321,
        0.212, -0.523,  0.311
    );
    return mul(transform, rgb);
}

// YIQ to RGB conversion matrix
float3 yiq_to_rgb(float3 yiq) {
    const float3x3 transform = float3x3(
        1.0,  0.956,  0.619,
        1.0, -0.272, -0.647,
        1.0, -1.106,  1.703
    );
    return mul(transform, yiq);
}

// --- Noise Functions ---

float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// Simple 2D noise
float noise(float2 st) {
    float2 i = floor(st);
    float2 f = frac(st);
    
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian Motion
float fbm(float2 st, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(st * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// --- VHS Effects ---

// Simulate VHS head switching at bottom of frame
float2 head_switching(float2 uv, float time) {
    float switch_point = 1.0 - head_switch_height;
    if (uv.y > switch_point) {
        float intensity = pow((uv.y - switch_point) / head_switch_height, 1.5);
        float offset = sin(uv.y * 30.0 + time * 10.0) * 0.02 + random(float2(floor(time * 10.0), 0.0)) * 0.01;
        uv.x += offset * intensity;
    }
    return uv;
}

// Simulate tracking noise
float2 tracking_noise(float2 uv, float time) {
    float noise_start = 1.0 - tracking_noise_height;
    if (uv.y > noise_start) {
        float intensity = (uv.y - noise_start) / tracking_noise_height;
        float wave = fbm(float2(uv.y * 5.0, time * 2.0), 2) - 0.5;
        uv.x += wave * intensity * 0.02;
    }
    return uv;
}

// Edge wave distortion
float2 edge_wave(float2 uv, float time) {
    float wave = fbm(float2(uv.y * 10.0, time * 4.0), 2) - 0.5;
    return float2(uv.x + wave * edge_wave_amount, uv.y);
}

// --- Main Shader ---

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float time = elapsed_time;
    
    // Apply geometric distortions
    uv = edge_wave(uv, time);
    uv = tracking_noise(uv, time);
    uv = head_switching(uv, time);
    
    // Sample and convert to YIQ
    float3 col = image.Sample(textureSampler, uv).rgb;
    float3 yiq = rgb_to_yiq(col);
    
    // Luma processing
    float luma_noise = (fbm(uv * 200.0 + time * 100.0, 2) - 0.5) * composite_noise;
    yiq.x += luma_noise;
    
    // Simulate luma smear (lowpass filter approximation)
    float2 smear_uv = uv;
    smear_uv.x -= luma_smear * 0.002;
    float3 smear_col = image.Sample(textureSampler, smear_uv).rgb;
    float smear_luma = rgb_to_yiq(smear_col).x;
    yiq.x = lerp(yiq.x, smear_luma, luma_smear * 0.5);
    
    // Chroma processing
    float2 chroma_uv = uv + float2(chroma_delay, 0.0);
    float3 chroma_col = image.Sample(textureSampler, chroma_uv).rgb;
    float2 chroma = rgb_to_yiq(chroma_col).yz;
    
    // Chroma phase error (color shifting)
    float phase_shift = sin(uv.y * 200.0 + time) * chroma_phase_error;
    float2 rotated_chroma;
    rotated_chroma.x = chroma.x * cos(phase_shift) - chroma.y * sin(phase_shift);
    rotated_chroma.y = chroma.x * sin(phase_shift) + chroma.y * cos(phase_shift);
    yiq.yz = rotated_chroma;
    
    // Chroma noise
    float chroma_noise = (random(uv + time) - 0.5) * 0.1;
    yiq.yz += chroma_noise * tape_speed;
    
    // Tape speed degradation
    float quality_factor = 1.0 - tape_speed * 0.3;
    yiq *= quality_factor;
    
    // Convert back to RGB
    float3 final_color = yiq_to_rgb(yiq);
    
    // Apply saturation
    float gray = dot(final_color, float3(0.299, 0.587, 0.114));
    final_color = lerp(float3(gray, gray, gray), final_color, saturation);
    
    // Apply contrast
    final_color = pow(saturate(final_color), float3(contrast, contrast, contrast));
    
    // Scanlines
    float scanline = sin(uv.y * uv_size.y * 3.14159) * 0.5 + 0.5;
    scanline = lerp(1.0, scanline, scanline_intensity);
    final_color *= scanline;
    
    // Snow/speckle noise
    float snow = random(uv * 1000.0 + time * 1000.0);
    if (snow > 1.0 - snow_intensity) {
        final_color += (snow - (1.0 - snow_intensity)) * 10.0;
    }
    
    // Tracking noise visual artifacts
    if (uv.y > 1.0 - tracking_noise_height) {
        float tracking_intensity = (uv.y - (1.0 - tracking_noise_height)) / tracking_noise_height;
        float tracking_artifact = fbm(uv * 50.0 + time * 20.0, 3);
        final_color += tracking_artifact * tracking_intensity * 0.3;
    }
    
    // Vignette
    float2 center_dist = uv - float2(0.5, 0.5);
    float vignette = 1.0 - dot(center_dist, center_dist) * vignette_intensity;
    final_color *= vignette;
    
    // Output
    return float4(saturate(final_color), 1.0);
}