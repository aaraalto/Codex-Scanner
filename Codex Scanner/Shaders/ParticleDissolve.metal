//
//  ParticleDissolve.metal
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//
//  A "Thanos snap" style particle dissolution effect for SwiftUI.
//  Pixels break apart and scatter/drift away based on procedural noise.
//  Particles are contained within the thumbnail bounds.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Helper: Check if position is within rounded rectangle
float roundedRectSDF(float2 p, float2 size, float radius) {
    float2 q = abs(p) - size + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

/// Particle dissolve effect - pixels break apart and scatter away
/// Contained within the thumbnail's rounded rectangle bounds
/// @param position Current pixel position
/// @param layer The SwiftUI layer to sample from
/// @param progress Animation progress from 0.0 (intact) to 1.0 (fully dissolved)
/// @param size The size of the view being dissolved
[[ stitchable ]] half4 particleDissolve(
    float2 position,
    SwiftUI::Layer layer,
    float progress,
    float2 size
) {
    // Early exit if no dissolution yet
    if (progress <= 0.0) {
        return layer.sample(position);
    }
    
    // Center coordinates for bounds checking
    float2 center = size * 0.5;
    float2 centered = position - center;
    float cornerRadius = 12.0;
    
    // Check if outside rounded rectangle
    float sdf = roundedRectSDF(centered, center, cornerRadius);
    if (sdf > 0.0) {
        return half4(0.0);
    }
    
    // Normalize position to 0-1 range
    float2 uv = position / size;
    
    // Multi-octave noise for organic dissolve pattern
    float2 noiseCoord = uv * 30.0;
    float noise1 = fract(sin(dot(noiseCoord, float2(12.9898, 78.233))) * 43758.5453);
    float noise2 = fract(sin(dot(noiseCoord * 2.0, float2(39.346, 11.135))) * 43758.5453);
    float noise = (noise1 + noise2) * 0.5;
    
    // Add some variation based on position - dissolve from edges and top first
    float edgeFactor = min(uv.x, 1.0 - uv.x) * min(uv.y, 1.0 - uv.y) * 4.0;
    float topBias = 1.0 - uv.y * 0.4; // Top dissolves slightly earlier
    
    // Calculate threshold - when progress exceeds this, the pixel dissolves
    float threshold = noise * 0.7 + edgeFactor * 0.2 + topBias * 0.1;
    
    // Smooth the progress curve for more pleasing animation
    float smoothProgress = progress * progress * (3.0 - 2.0 * progress); // Smoothstep
    
    // Check if this pixel should be dissolved
    if (smoothProgress > threshold) {
        // Calculate how far into dissolution this particle is (0 to 1)
        float lifetime = (smoothProgress - threshold) / max(0.001, 1.0 - threshold);
        lifetime = min(1.0, lifetime * 1.5); // Speed up individual particle fade
        
        // Particle physics - drift direction based on noise
        float angle = noise * 6.28318 + position.x * 0.01;
        float speed = 20.0 + noise * 40.0;
        
        // Drift: outward scatter + upward float
        float2 drift = float2(
            cos(angle) * lifetime * speed,
            -lifetime * 50.0 - sin(noise * 3.14159) * 30.0 * lifetime
        );
        
        // Add some turbulence/wiggle
        drift.x += sin(lifetime * 10.0 + noise * 6.28) * 5.0 * lifetime;
        
        // === CONTAIN WITHIN BOUNDS ===
        float2 newPos = position + drift;
        float2 newCentered = newPos - center;
        float newSDF = roundedRectSDF(newCentered, center - 2.0, cornerRadius);
        
        // If particle would exit bounds, fade it out instead
        if (newSDF > -2.0) {
            float edgeFade = 1.0 - smoothstep(-4.0, 0.0, newSDF);
            if (edgeFade < 0.01) {
                return half4(0.0);
            }
            // Reduce drift to keep particle visible longer at edge
            drift *= edgeFade;
        }
        
        // Sample from the drifted position (particle carries its original color)
        float2 samplePos = position - drift;
        samplePos = clamp(samplePos, float2(0.0), size);
        
        half4 particleColor = layer.sample(samplePos);
        
        // Fade out as particle drifts
        float alpha = max(0.0, 1.0 - lifetime);
        alpha = alpha * alpha; // Quadratic falloff for snappier disappearance
        
        // Slight brightness increase as particles "burn out"
        float brightness = 1.0 + lifetime * 0.3;
        
        // If particle has faded completely, return transparent
        if (alpha < 0.01) {
            return half4(0.0);
        }
        
        return half4(particleColor.rgb * brightness, particleColor.a * alpha);
    }
    
    // Pixel hasn't dissolved yet - return original
    return layer.sample(position);
}
