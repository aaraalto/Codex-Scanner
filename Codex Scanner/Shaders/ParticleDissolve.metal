//
//  ParticleDissolve.metal
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//
//  A graceful particle dissolution effect for SwiftUI.
//  Pixels gently float away with smooth, elegant motion.
//  Particles are contained within the thumbnail bounds.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Helper: Smooth noise function
float smoothNoise(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// Helper: Check if position is within rounded rectangle
float roundedRectSDF(float2 p, float2 size, float radius) {
    float2 q = abs(p) - size + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Helper: Smooth easing function (ease out cubic)
float easeOutCubic(float t) {
    return 1.0 - pow(1.0 - t, 3.0);
}

// Helper: Smooth easing function (ease in out sine)
float easeInOutSine(float t) {
    return -(cos(3.14159 * t) - 1.0) / 2.0;
}

/// Graceful particle dissolve effect - pixels gently float away
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
    
    // Layered noise for organic, flowing dissolve pattern
    float2 noiseCoord = uv * 20.0;
    float noise1 = smoothNoise(noiseCoord);
    float noise2 = smoothNoise(noiseCoord * 1.5 + 7.0);
    float noise3 = smoothNoise(noiseCoord * 0.7 + 13.0);
    float noise = (noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2);
    
    // Gentle dissolve from top-center outward
    float distFromTop = uv.y;
    float distFromCenter = abs(uv.x - 0.5) * 2.0;
    
    // Smooth threshold - creates a gentle wave of dissolution
    float threshold = noise * 0.5 + distFromTop * 0.3 + (1.0 - distFromCenter) * 0.2;
    
    // Very smooth progress curve
    float smoothProgress = easeInOutSine(progress);
    
    // Check if this pixel should be dissolved
    if (smoothProgress > threshold * 0.9) {
        // Calculate particle lifetime with smooth onset
        float rawLifetime = (smoothProgress - threshold * 0.9) / max(0.01, 1.0 - threshold * 0.9);
        float lifetime = easeOutCubic(clamp(rawLifetime, 0.0, 1.0));
        
        // === GRACEFUL FLOATING MOTION ===
        
        // Gentle upward drift - like leaves floating up
        float baseSpeed = 25.0 + noise * 15.0;
        float upwardDrift = -lifetime * baseSpeed;
        
        // Soft horizontal sway - sinusoidal motion
        float swayFreq = 2.0 + noise * 2.0;
        float swayAmp = 8.0 + noise2 * 6.0;
        float horizontalSway = sin(lifetime * swayFreq * 3.14159 + noise * 6.28) * swayAmp * lifetime;
        
        // Slight outward spread from center
        float spreadDir = sign(uv.x - 0.5);
        float spread = spreadDir * lifetime * 5.0 * (1.0 + noise);
        
        float2 drift = float2(
            horizontalSway + spread,
            upwardDrift
        );
        
        // === SOFT BOUNDS CONTAINMENT ===
        float2 newPos = position + drift;
        float2 newCentered = newPos - center;
        float margin = 4.0;
        float newSDF = roundedRectSDF(newCentered, center - margin, cornerRadius);
        
        // Soft fade at edges
        if (newSDF > -margin) {
            float edgeFade = smoothstep(0.0, -margin, newSDF);
            drift *= edgeFade;
            if (edgeFade < 0.05) {
                return half4(0.0);
            }
        }
        
        // Sample from drifted position
        float2 samplePos = position - drift * 0.3; // Subtle sampling offset
        samplePos = clamp(samplePos, float2(2.0), size - 2.0);
        
        half4 particleColor = layer.sample(samplePos);
        
        // === GRACEFUL FADE ===
        
        // Smooth S-curve fade out
        float fadeStart = 0.3;
        float alpha;
        if (lifetime < fadeStart) {
            alpha = 1.0;
        } else {
            float fadeProgress = (lifetime - fadeStart) / (1.0 - fadeStart);
            alpha = 1.0 - easeInOutSine(fadeProgress);
        }
        
        // Gentle brightness lift as particles fade
        float brightness = 1.0 + lifetime * 0.15;
        
        // Very soft final fade
        alpha *= smoothstep(1.0, 0.85, lifetime);
        
        if (alpha < 0.02) {
            return half4(0.0);
        }
        
        return half4(particleColor.rgb * brightness, particleColor.a * alpha);
    }
    
    // Pixel hasn't dissolved yet - return original
    return layer.sample(position);
}
