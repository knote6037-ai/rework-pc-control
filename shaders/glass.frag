#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    vec2 sceneSize;
    vec2 scenePosition;
    float cornerRadius;
    float hoverAmount;
    vec2 hoverPosition;
};
layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * panelSize;
    vec2 p = px - panelSize * .5;
    float d = roundedBox(p, panelSize * .5, cornerRadius);
    float mask = 1.0 - smoothstep(-.75, .75, d);
    float edge = exp(-max(0.0, -d) / 12.0);
    vec2 n = normalize(vec2(
        roundedBox(p + vec2(1, 0), panelSize * .5, cornerRadius) - roundedBox(p - vec2(1, 0), panelSize * .5, cornerRadius),
        roundedBox(p + vec2(0, 1), panelSize * .5, cornerRadius) - roundedBox(p - vec2(0, 1), panelSize * .5, cornerRadius)) + vec2(.0001));
    vec2 refractUV = (scenePosition + px + n * edge * 11.0) / max(sceneSize, vec2(1.0));
    vec2 blur = vec2(4.0) / max(sceneSize, vec2(1.0));
    vec3 background = texture(source, refractUV).rgb * .24;
    background += texture(source, refractUV + vec2(blur.x, 0)).rgb * .12;
    background += texture(source, refractUV - vec2(blur.x, 0)).rgb * .12;
    background += texture(source, refractUV + vec2(0, blur.y)).rgb * .12;
    background += texture(source, refractUV - vec2(0, blur.y)).rgb * .12;
    background += texture(source, refractUV + blur).rgb * .07;
    background += texture(source, refractUV - blur).rgb * .07;
    background += texture(source, refractUV + vec2(blur.x, -blur.y)).rgb * .07;
    background += texture(source, refractUV + vec2(-blur.x, blur.y)).rgb * .07;
    float topLight = pow(1.0 - uv.y, 2.5) * .065;
    float mouseLight = exp(-length(px - hoverPosition) / 150.0) * hoverAmount * .035;
    float rim = edge * (.035 + max(0.0, dot(n, normalize(vec2(-.5, -1)))) * .1);
    vec3 color = background * .72 + vec3(.055, .060, .069) + vec3(.91, .94, 1.0) * (topLight + mouseLight + rim);
    fragColor = vec4(color * mask, mask) * qt_Opacity;
}
