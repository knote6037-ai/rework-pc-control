#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float phase;
};
float noise(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(1.0, resolution.y);
    vec2 p = (uv - .5) * vec2(aspect, 1.0);

    // Broad folded-silver caustics drift across the entire window, not just
    // inside a small glow. Integer phase multiples make the loop seamless.
    float foldA = uv.y - (.56 + .17 * sin(uv.x * 4.8 + phase)
        + .055 * sin(uv.x * 12.0 - phase * 2.0));
    float foldB = uv.y - (.25 + .19 * cos(uv.x * 3.2 - phase)
        + .06 * sin(uv.x * 9.0 + phase * 2.0));
    float foldC = uv.y - (.82 + .105 * sin(uv.x * 6.5 - phase * 2.0));
    float silk = .14 * exp(-foldA * foldA * 24.0)
        + .075 * exp(-foldB * foldB * 48.0);
    float caustic = .075 * exp(-foldA * foldA * 780.0)
        + .052 * exp(-foldB * foldB * 1100.0)
        + .040 * exp(-foldC * foldC * 1050.0);
    vec2 lightA = (uv - vec2(.66 + .20 * sin(phase), .22 + .12 * cos(phase))) * vec2(aspect, 1.0);
    vec2 lightB = (uv - vec2(.18 + .12 * cos(phase), .70 + .13 * sin(phase * 2.0))) * vec2(aspect, 1.0);
    float pools = .10 * exp(-dot(lightA, lightA) * 4.7)
        + .085 * exp(-dot(lightB, lightB) * 6.0);
    float luminance = .020 + silk + caustic + pools;
    luminance *= 1.0 - .22 * smoothstep(.45, 1.0, length(p));
    luminance += (noise(uv * resolution) - .5) * .003;
    vec3 c = vec3(luminance * .96, luminance * .98, luminance);
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
