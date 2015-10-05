default: main shaders.metallib

main: main.mm common.h
	clang++ -framework Cocoa -framework Metal -framework MetalKit -fobjc-arc $< -o $@

%.air: %.metal common.h
	metal -O2 -std=osx-metal1.1 -o $@ $<

%.metal-ar: %.air
	metal-ar r $@ $<

%.metallib: %.metal-ar
	metallib -o $@ $<

clean:
	rm -f main *.metallib *.metal-ar *.air
