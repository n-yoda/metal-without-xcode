#ifndef COMMON_H
#define COMMON_H

#include <simd/simd.h>

enum VertexAttributes {
    VertexAttributePosition = 0,
    VertexAttributeColor = 1,
};

enum BufferIndex  {
    MeshVertexBuffer = 0,
    FrameUniformBuffer = 1,
};

struct FrameUniforms {
    simd::float4x4 projectionViewModel;
};

#endif
