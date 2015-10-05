#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "common.h"

@interface HelloMetalView : MTKView
@end

int main () {
	@autoreleasepool {
		// Application
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
		[NSApp activateIgnoringOtherApps:YES];

		// Menu
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

		// Window
		NSRect frame = NSMakeRect(0, 0, 256, 256);
		NSWindow* window = [[NSWindow alloc]
							   initWithContentRect:frame styleMask:NSTitledWindowMask
							   backing:NSBackingStoreBuffered defer:NO];
		[window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
		window.title = [[NSProcessInfo processInfo] processName];
		[window makeKeyAndOrderFront:nil];

		// Custom MTKView
		HelloMetalView* view = [[HelloMetalView alloc] initWithFrame:frame];
		window.contentView = view;

		// Run
		[NSApp run];
	}
    return 0;
}

@implementation HelloMetalView {
    dispatch_semaphore_t _semaphore;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _library;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    matrix_float4x4 _projectionMatrix;
    matrix_float4x4 _viewMatrix;
}

- (id)initWithFrame:(CGRect)frame {
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	self = [super initWithFrame:frame device:device];
	if (self) {
		[self setup];
	}
	return self;
}

- (void)setup {
	_commandQueue = [self.device newCommandQueue];
    NSError *error = nil;
	_library = [self.device newLibraryWithFile: @"shaders.metallib" error:&error];
	if (error) {
		NSLog(@"%@", [error localizedDescription]);
	}
	self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
	self.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    id <MTLFunction> fragFunc = [_library newFunctionWithName:@"frag"];
    id <MTLFunction> vertFunc = [_library newFunctionWithName:@"vert"];
    MTLVertexDescriptor *vertDesc = [MTLVertexDescriptor new];
}
@end
