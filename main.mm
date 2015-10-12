#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>
#import "common.h"

@interface HelloMetalView : MTKView
@end

int main () {
    @autoreleasepool {
        // Application.
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];

        // Menu.
        NSMenu* bar = [NSMenu new];
        NSMenuItem * barItem = [NSMenuItem new];
        NSMenu* menu = [NSMenu new];
        NSMenuItem* quit = [[NSMenuItem alloc]
                               initWithTitle:@"Quit"
                               action:@selector(terminate:)
                               keyEquivalent:@"q"];
        [bar addItem:barItem];
        [barItem setSubmenu:menu];
        [menu addItem:quit];
        NSApp.mainMenu = bar;

        // Window.
        NSRect frame = NSMakeRect(0, 0, 256, 256);
        NSWindow* window = [[NSWindow alloc]
                               initWithContentRect:frame styleMask:NSTitledWindowMask
                               backing:NSBackingStoreBuffered defer:NO];
        [window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
        window.title = [[NSProcessInfo processInfo] processName];
        [window makeKeyAndOrderFront:nil];

        // Custom MTKView.
        HelloMetalView* view = [[HelloMetalView alloc] initWithFrame:frame];
        window.contentView = view;

        // Run.
        [NSApp run];
    }
    return 0;
}

// Vertex structure on CPU memory.
struct Vertex {
    float position[3];
    unsigned char color[4];
};

// For pipeline executing.
constexpr int uniformBufferCount = 3;

// The main view.
@implementation HelloMetalView {
    id <MTLLibrary> _library;
    id <MTLCommandQueue> _commandQueue;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    dispatch_semaphore_t _semaphore;
    id <MTLBuffer> _uniformBuffers[uniformBufferCount];
    id <MTLBuffer> _vertexBuffer;
    int uniformBufferIndex;
    long frame;
}

- (id)initWithFrame:(CGRect)inFrame {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self = [super initWithFrame:inFrame device:device];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    // Set view settings.
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;

    // Load shaders.
    NSError *error = nil;
    _library = [self.device newLibraryWithFile: @"shaders.metallib" error:&error];
    if (!_library) {
        NSLog(@"Failed to load library. error %@", error);
        exit(0);
    }
    id <MTLFunction> vertFunc = [_library newFunctionWithName:@"vert"];
    id <MTLFunction> fragFunc = [_library newFunctionWithName:@"frag"];

    // Create depth state.
    MTLDepthStencilDescriptor *depthDesc = [MTLDepthStencilDescriptor new];
    depthDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthDesc.depthWriteEnabled = YES;
    _depthState = [self.device newDepthStencilStateWithDescriptor:depthDesc];

    // Create vertex descriptor.
    MTLVertexDescriptor *vertDesc = [MTLVertexDescriptor new];
    vertDesc.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    vertDesc.attributes[VertexAttributePosition].offset = 0;
    vertDesc.attributes[VertexAttributePosition].bufferIndex = MeshVertexBuffer;
    vertDesc.attributes[VertexAttributeColor].format = MTLVertexFormatUChar4;
    vertDesc.attributes[VertexAttributeColor].offset = sizeof(Vertex::position);
    vertDesc.attributes[VertexAttributeColor].bufferIndex = MeshVertexBuffer;
    vertDesc.layouts[MeshVertexBuffer].stride = sizeof(Vertex);
    vertDesc.layouts[MeshVertexBuffer].stepRate = 1;
    vertDesc.layouts[MeshVertexBuffer].stepFunction = MTLVertexStepFunctionPerVertex;

    // Create pipeline state.
    MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
    pipelineDesc.sampleCount = self.sampleCount;
    pipelineDesc.vertexFunction = vertFunc;
    pipelineDesc.fragmentFunction = fragFunc;
    pipelineDesc.vertexDescriptor = vertDesc;
    pipelineDesc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    pipelineDesc.depthAttachmentPixelFormat = self.depthStencilPixelFormat;
    pipelineDesc.stencilAttachmentPixelFormat = self.depthStencilPixelFormat;
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to create pipeline state, error %@", error);
        exit(0);
    }

    // Create vertices.
    Vertex verts[] = {
        Vertex{{-0.5, -0.5, 0}, {255, 0, 0, 255}},
        Vertex{{0, 0.5, 0}, {0, 255, 0, 255}},
        Vertex{{0.5, -0.5, 0}, {0, 0, 255, 255}}
    };
    _vertexBuffer = [self.device newBufferWithBytes:verts
                                             length:sizeof(verts)
                                            options:MTLResourceStorageModePrivate];

    // Create uniform buffers.
    for (int i = 0; i < uniformBufferCount; i++) {
        _uniformBuffers[i] = [self.device newBufferWithLength:sizeof(FrameUniforms)
                                          options:MTLResourceCPUCacheModeWriteCombined];
    }
    frame = 0;

    // Create semaphore for each uniform buffer.
    _semaphore = dispatch_semaphore_create(uniformBufferCount);
    uniformBufferIndex = 0;

    // Create command queue
    _commandQueue = [self.device newCommandQueue];

}

- (void)drawRect:(CGRect)rect {
    // Wait for an available uniform buffer.
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    // Animation.
    frame++;
    float rad = frame * 0.01f;
    float sin = std::sin(rad), cos = std::cos(rad);
    simd::float4x4 rot(simd::float4{cos, -sin, 0, 0},
                       simd::float4{sin, cos, 0, 0},
                       simd::float4{0, -0, 1, 0},
                       simd::float4{0, 0, 0, 1});

    // Update the current uniform buffer.
    uniformBufferIndex = (uniformBufferIndex + 1) % uniformBufferCount;
    FrameUniforms *uniforms = (FrameUniforms *)[_uniformBuffers[uniformBufferIndex] contents];
    uniforms->projectionViewModel = rot;

    // Create a command buffer.
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    // Encode render command.
    id <MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:self.currentRenderPassDescriptor];
    [encoder setViewport:{0, 0, self.drawableSize.width, self.drawableSize.height, 0, 1}];
    [encoder setDepthStencilState:_depthState];
    [encoder setRenderPipelineState:_pipelineState];
    [encoder setVertexBuffer:_uniformBuffers[uniformBufferIndex]
                      offset:0 atIndex:FrameUniformBuffer];
    [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:MeshVertexBuffer];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    // Set callback for semaphore.
    __block dispatch_semaphore_t semaphore = _semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(semaphore);
    }];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];

    // Draw children.
    [super drawRect:rect];
}

@end
