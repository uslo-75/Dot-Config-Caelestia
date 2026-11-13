#version 440

// Lecture d'une planche d'images (grille) : mélange l'image courante et la suivante.
// Compilé en strip.frag.qsb avec : qsb --qt6 -o strip.frag.qsb strip.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;   // colonnes, lignes de la planche
    vec2 cellA;  // colonne, ligne de l'image courante
    vec2 cellB;  // colonne, ligne de l'image suivante
    vec2 texel;  // taille d'un pixel de la planche, en coordonnées de texture
    float blend; // 0 = image courante, 1 = image suivante
};

layout(binding = 1) uniform sampler2D source;

vec4 cell(vec2 c) {
    // Demi-pixel de marge : le filtrage linéaire ne déborde pas sur les cases voisines.
    vec2 lo = c / grid + texel * 0.5;
    vec2 hi = (c + 1.0) / grid - texel * 0.5;
    return texture(source, clamp((c + qt_TexCoord0) / grid, lo, hi));
}

void main() {
    fragColor = mix(cell(cellA), cell(cellB), blend) * qt_Opacity;
}
