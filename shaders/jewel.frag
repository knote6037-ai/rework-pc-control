#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lightTime;
    float movement;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec2 uv = qt_TexCoord0;
    vec4 jewel = texture(source, uv);
    float luminance = dot(jewel.rgb, vec3(.2126, .7152, .0722));
    // A broad moving studio softbox lifts individual bright facets without
    // laying an opaque stripe over the original engraved movement.
    float sweepPos = fract(lightTime * .19) * 1.9 - .45;
    float stripe = exp(-pow((uv.x + uv.y * .38 - sweepPos) / .10, 2.0));
    vec2 p = abs(uv - vec2(.49, .49));
    float bezel = smoothstep(.26, .39, max(p.x, p.y));
    float facets = smoothstep(.46, .94, luminance);
    float reflection = stripe * (.19 + .48 * bezel) * facets * movement;
    jewel.rgb += vec3(reflection) * jewel.a;
    fragColor = jewel * qt_Opacity;
}
