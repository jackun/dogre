compiler=dmd
linker=dmd

DFLAGS=-debug -g -I../../OgreD -I../../Deps/DerelictGL3 -I../../Deps/DerelictSDL2 -I../../Deps/DerelictFI -I../../Deps/DerelictUtil
target=bin/Debug/libRenderSystemGL.a
objects = obj/Debug/ogregl.config.o obj/Debug/ogregl.context.o obj/Debug/ogregl.plugin.o obj/Debug/ogregl.rendersystem.o obj/Debug/ogregl.compat.o obj/Debug/ogregl.glew.o obj/Debug/ogregl.support.o obj/Debug/ogregl.pbuffer.o obj/Debug/ogregl.pbrendertexture.o obj/Debug/ogregl.rendertexture.o obj/Debug/ogregl.hardwarebuffermanager.o obj/Debug/ogregl.pixelformat.o obj/Debug/ogregl.hardwarepixelbuffer.o obj/Debug/ogregl.gpuprogram.o obj/Debug/ogregl.gpuprogrammanager.o obj/Debug/ogregl.glsl.programfactory.o obj/Debug/ogregl.glsl.linkprogram.o obj/Debug/ogregl.glsl.gpuprogram.o obj/Debug/ogregl.glsl.program.o obj/Debug/ogregl.glsl.linkprogrammanager.o obj/Debug/ogregl.glsl.preprocessor.o obj/Debug/ogregl.sdl.window.o obj/Debug/ogregl.sdl.support.o obj/Debug/ogregl.hardwarevertexbuffer.o obj/Debug/ogregl.defaulthardwarebuffermanager.o obj/Debug/ogregl.hardwareindexbuffer.o obj/Debug/ogregl.depthbuffer.o obj/Debug/ogregl.texturemanager.o obj/Debug/ogregl.texture.o obj/Debug/ogregl.fborendertexture.o obj/Debug/ogregl.framebufferobject.o obj/Debug/ogregl.fbomultirendertarget.o obj/Debug/ogregl.hardwareocclusionquery.o obj/Debug/ogregl.rendertovertexbuffer.o obj/Debug/ogregl.glsl.extsupport.o obj/Debug/ogregl.glu.o \
obj/Debug/ogregl.glx.context.o  obj/Debug/ogregl.glx.pbuffer.o  obj/Debug/ogregl.glx.support.o  obj/Debug/ogregl.glx.window.o obj/Debug/ogregl.util.o

all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker) $(DFLAGS) -lib "-of$@" $(objects)

obj/Debug/ogregl.glx.context.o : ogregl/glx/context.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glx.pbuffer.o : ogregl/glx/pbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glx.support.o : ogregl/glx/support.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glx.window.o : ogregl/glx/window.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.util.o : ogregl/util.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.config.o : ogregl/config.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.context.o : ogregl/context.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.plugin.o : ogregl/plugin.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.rendersystem.o : ogregl/rendersystem.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.compat.o : ogregl/compat.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glew.o : ogregl/glew.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.support.o : ogregl/support.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.pbuffer.o : ogregl/pbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.pbrendertexture.o : ogregl/pbrendertexture.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.rendertexture.o : ogregl/rendertexture.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.hardwarebuffermanager.o : ogregl/hardwarebuffermanager.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.pixelformat.o : ogregl/pixelformat.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.hardwarepixelbuffer.o : ogregl/hardwarepixelbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.gpuprogram.o : ogregl/gpuprogram.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.gpuprogrammanager.o : ogregl/gpuprogrammanager.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.programfactory.o : ogregl/glsl/programfactory.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.linkprogram.o : ogregl/glsl/linkprogram.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.gpuprogram.o : ogregl/glsl/gpuprogram.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.program.o : ogregl/glsl/program.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.linkprogrammanager.o : ogregl/glsl/linkprogrammanager.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.preprocessor.o : ogregl/glsl/preprocessor.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.sdl.window.o : ogregl/sdl/window.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.sdl.support.o : ogregl/sdl/support.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.hardwarevertexbuffer.o : ogregl/hardwarevertexbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.defaulthardwarebuffermanager.o : ogregl/defaulthardwarebuffermanager.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.hardwareindexbuffer.o : ogregl/hardwareindexbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.depthbuffer.o : ogregl/depthbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.texturemanager.o : ogregl/texturemanager.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.texture.o : ogregl/texture.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.fborendertexture.o : ogregl/fborendertexture.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.framebufferobject.o : ogregl/framebufferobject.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.fbomultirendertarget.o : ogregl/fbomultirendertarget.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.hardwareocclusionquery.o : ogregl/hardwareocclusionquery.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.rendertovertexbuffer.o : ogregl/rendertovertexbuffer.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glsl.extsupport.o : ogregl/glsl/extsupport.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

obj/Debug/ogregl.glu.o : ogregl/glu.d
	$(compiler) $(DFLAGS) -c $? "-of$@" 

clean:
	$(RM) "$(target)" $(objects)
