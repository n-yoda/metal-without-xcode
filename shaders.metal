#include <metal_stdlib>
#include <metal_texture>
#include <metal_matrix>
#include <metal_geometric>
#include <metal_math>
#include <metal_graphics>
#include "common.h"

using namespace metal;

struct VertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
};

typedef struct {
    float4 position [[position]];
    half4  color;
} ShaderInOut;

vertex ShaderInOut vert(VertexInput in [[stage_in]],
						constant FrameUniforms& frameUniforms [[buffer(FrameUniformBuffer)]]) {
    ShaderInOut out;
    float4 pos4 = float4(in.position, 1.0);
    out.position = frameUniforms.projectionViewModel * pos4;
    out.color = in.color;
    return out;
}

fragment half4 frag(ShaderInOut in [[stage_in]]) {
    return in.color;
}
