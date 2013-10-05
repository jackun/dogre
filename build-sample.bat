if not exists "Samples\Samples1\main.d" goto warn

set RENDERSYSTEMGL=RenderSystems\GL\ogregl\util.d ^
RenderSystems\GL\ogregl\pixelformat.d ^
RenderSystems\GL\ogregl\hardwareocclusionquery.d ^
RenderSystems\GL\ogregl\rendertovertexbuffer.d ^
RenderSystems\GL\ogregl\support.d ^
RenderSystems\GL\ogregl\windows\support.d ^
RenderSystems\GL\ogregl\windows\pbuffer.d ^
RenderSystems\GL\ogregl\windows\window.d ^
RenderSystems\GL\ogregl\windows\context.d ^
RenderSystems\GL\ogregl\texturemanager.d ^
RenderSystems\GL\ogregl\plugin.d ^
RenderSystems\GL\ogregl\depthbuffer.d ^
RenderSystems\GL\ogregl\hardwarevertexbuffer.d ^
RenderSystems\GL\ogregl\sdl\support.d ^
RenderSystems\GL\ogregl\sdl\window.d ^
RenderSystems\GL\ogregl\framebufferobject.d ^
RenderSystems\GL\ogregl\hardwareindexbuffer.d ^
RenderSystems\GL\ogregl\glx\support.d ^
RenderSystems\GL\ogregl\glx\pbuffer.d ^
RenderSystems\GL\ogregl\glx\window.d ^
RenderSystems\GL\ogregl\glx\context.d ^
RenderSystems\GL\ogregl\hardwarebuffermanager.d ^
RenderSystems\GL\ogregl\fborendertexture.d ^
RenderSystems\GL\ogregl\config.d ^
RenderSystems\GL\ogregl\hardwarepixelbuffer.d ^
RenderSystems\GL\ogregl\pbuffer.d ^
RenderSystems\GL\ogregl\glu.d ^
RenderSystems\GL\ogregl\gpuprogrammanager.d ^
RenderSystems\GL\ogregl\defaulthardwarebuffermanager.d ^
RenderSystems\GL\ogregl\rendertexture.d ^
RenderSystems\GL\ogregl\compat.d ^
RenderSystems\GL\ogregl\fbomultirendertarget.d ^
RenderSystems\GL\ogregl\pbrendertexture.d ^
RenderSystems\GL\ogregl\glew.d ^
RenderSystems\GL\ogregl\glsl\programfactory.d ^
RenderSystems\GL\ogregl\glsl\linkprogrammanager.d ^
RenderSystems\GL\ogregl\glsl\linkprogram.d ^
RenderSystems\GL\ogregl\glsl\program.d ^
RenderSystems\GL\ogregl\glsl\preprocessor.d ^
RenderSystems\GL\ogregl\glsl\extsupport.d ^
RenderSystems\GL\ogregl\glsl\gpuprogram.d ^
RenderSystems\GL\ogregl\gpuprogram.d ^
RenderSystems\GL\ogregl\context.d ^
RenderSystems\GL\ogregl\rendersystem.d ^
RenderSystems\GL\ogregl\texture.d


mkdir  Samples\Sample1\bin\Debug
REM gdb -d \src\dmd2-git\src\dmd-build\src --args ^
dmd -debug -gc -ofSamples\Sample1\bin\Debug\Sample1_d.exe ^
Samples\Sample1\main.d ^
OgreD\ogre\animation\animable.d ^
OgreD\ogre\animation\animations.d ^
OgreD\ogre\animation\skeletonmanager.d ^
OgreD\ogre\animation\skeletonserializer.d ^
OgreD\ogre\any.d ^
OgreD\ogre\backdrop.d ^
OgreD\ogre\bindings\mini_win32.d ^
OgreD\ogre\bindings\mini_x11.d ^
OgreD\ogre\bindings\mini_xaw.d ^
OgreD\ogre\cityhash.d ^
OgreD\ogre\compat.d ^
OgreD\ogre\config.d ^
OgreD\ogre\effects\billboardchain.d ^
OgreD\ogre\effects\billboard.d ^
OgreD\ogre\effects\billboardparticlerenderer.d ^
OgreD\ogre\effects\billboardset.d ^
OgreD\ogre\effects\compositionpass.d ^
OgreD\ogre\effects\compositiontargetpass.d ^
OgreD\ogre\effects\compositiontechnique.d ^
OgreD\ogre\effects\compositor.d ^
OgreD\ogre\effects\compositorlogic.d ^
OgreD\ogre\effects\compositormanager.d ^
OgreD\ogre\effects\customcompositionpass.d ^
OgreD\ogre\effects\particleaffector.d ^
OgreD\ogre\effects\particle.d ^
OgreD\ogre\effects\particleemitter.d ^
OgreD\ogre\effects\particlesystem.d ^
OgreD\ogre\effects\particlesystemmanager.d ^
OgreD\ogre\effects\particlesystemrenderer.d ^
OgreD\ogre\effects\ribbontrail.d ^
OgreD\ogre\exception.d ^
OgreD\ogre\general\atomicwrappers.d ^
OgreD\ogre\general\codec.d ^
OgreD\ogre\general\colourvalue.d ^
OgreD\ogre\general\common.d ^
OgreD\ogre\general\configdialog.d ^
OgreD\ogre\general\configfile.d ^
OgreD\ogre\general\controller.d ^
OgreD\ogre\general\controllermanager.d ^
OgreD\ogre\general\dynlib.d ^
OgreD\ogre\general\dynlibmanager.d ^
OgreD\ogre\general\errordialog.d ^
OgreD\ogre\general\framelistener.d ^
OgreD\ogre\general\generals.d ^
OgreD\ogre\general\glx\configdialog.d ^
OgreD\ogre\general\glx\errordialog.d ^
OgreD\ogre\general\glx\timer.d ^
OgreD\ogre\general\gtk\configdialog.d ^
OgreD\ogre\general\gtk\errordialog.d ^
OgreD\ogre\general\log.d ^
OgreD\ogre\general\platform.d ^
OgreD\ogre\general\plugin.d ^
OgreD\ogre\general\predefinedcontrollers.d ^
OgreD\ogre\general\profiler.d ^
OgreD\ogre\general\radixsort.d ^
OgreD\ogre\general\root.d ^
OgreD\ogre\general\scriptcompiler.d ^
OgreD\ogre\general\scriptlexer.d ^
OgreD\ogre\general\scriptparser.d ^
OgreD\ogre\general\scripttranslator.d ^
OgreD\ogre\general\serializer.d ^
OgreD\ogre\general\timer.d ^
OgreD\ogre\general\windows\configdialog.d ^
OgreD\ogre\general\windows\timer.d ^
OgreD\ogre\general\workqueue.d ^
OgreD\ogre\hash.d ^
OgreD\ogre\image\freeimage.d ^
OgreD\ogre\image\images.d ^
OgreD\ogre\image\pixelformat.d ^
OgreD\ogre\initstatics.d ^
OgreD\ogre\lod\distancelodstrategy.d ^
OgreD\ogre\lod\lodstrategy.d ^
OgreD\ogre\lod\lodstrategymanager.d ^
OgreD\ogre\lod\patchmesh.d ^
OgreD\ogre\lod\patchsurface.d ^
OgreD\ogre\lod\pixelcountlodstrategy.d ^
OgreD\ogre\materials\autoparamdatasource.d ^
OgreD\ogre\materials\blendmode.d ^
OgreD\ogre\materials\externaltexturesource.d ^
OgreD\ogre\materials\externaltexturesourcemanager.d ^
OgreD\ogre\materials\gpuprogram.d ^
OgreD\ogre\materials\material.d ^
OgreD\ogre\materials\materialmanager.d ^
OgreD\ogre\materials\materialserializer.d ^
OgreD\ogre\materials\pass.d ^
OgreD\ogre\materials\technique.d ^
OgreD\ogre\materials\textureunitstate.d ^
OgreD\ogre\math\angles.d ^
OgreD\ogre\math\axisalignedbox.d ^
OgreD\ogre\math\bitwise.d ^
OgreD\ogre\math\convexbody.d ^
OgreD\ogre\math\dualquaternion.d ^
OgreD\ogre\math\edgedata.d ^
OgreD\ogre\math\frustum.d ^
OgreD\ogre\math\maths.d ^
OgreD\ogre\math\matrix.d ^
OgreD\ogre\math\optimisedutil.d ^
OgreD\ogre\math\plane.d ^
OgreD\ogre\math\polygon.d ^
OgreD\ogre\math\quaternion.d ^
OgreD\ogre\math\ray.d ^
OgreD\ogre\math\rotationalspline.d ^
OgreD\ogre\math\simplespline.d ^
OgreD\ogre\math\sphere.d ^
OgreD\ogre\math\tangentspacecalc.d ^
OgreD\ogre\math\vector.d ^
OgreD\ogre\rendersystem\glx\windoweventutilities.d ^
OgreD\ogre\rendersystem\hardware.d ^
OgreD\ogre\rendersystem\renderoperation.d ^
OgreD\ogre\rendersystem\renderqueue.d ^
OgreD\ogre\rendersystem\renderqueuesortinggrouping.d ^
OgreD\ogre\rendersystem\rendersystem.d ^
OgreD\ogre\rendersystem\rendertarget.d ^
OgreD\ogre\rendersystem\rendertargetlistener.d ^
OgreD\ogre\rendersystem\rendertexture.d ^
OgreD\ogre\rendersystem\renderwindow.d ^
OgreD\ogre\rendersystem\vertex.d ^
OgreD\ogre\rendersystem\viewport.d ^
OgreD\ogre\rendersystem\windoweventutilities.d ^
OgreD\ogre\rendersystem\windows\windoweventutilities.d ^
OgreD\ogre\resources\archive.d ^
OgreD\ogre\resources\datastream.d ^
OgreD\ogre\resources\highlevelgpuprogram.d ^
OgreD\ogre\resources\mesh.d ^
OgreD\ogre\resources\meshfileformat.d ^
OgreD\ogre\resources\meshmanager.d ^
OgreD\ogre\resources\meshserializer.d ^
OgreD\ogre\resources\prefabfactory.d ^
OgreD\ogre\resources\resourcebackgroundqueue.d ^
OgreD\ogre\resources\resource.d ^
OgreD\ogre\resources\resourcegroupmanager.d ^
OgreD\ogre\resources\resourcemanager.d ^
OgreD\ogre\resources\texture.d ^
OgreD\ogre\resources\texturemanager.d ^
OgreD\ogre\resources\unifiedhighlevelgpuprogram.d ^
OgreD\ogre\scene\camera.d ^
OgreD\ogre\scene\entity.d ^
OgreD\ogre\scene\instancedentity.d ^
OgreD\ogre\scene\instancedgeometry.d ^
OgreD\ogre\scene\instancemanager.d ^
OgreD\ogre\scene\light.d ^
OgreD\ogre\scene\manualobject.d ^
OgreD\ogre\scene\movableobject.d ^
OgreD\ogre\scene\movableplane.d ^
OgreD\ogre\scene\node.d ^
OgreD\ogre\scene\rectangle2d.d ^
OgreD\ogre\scene\renderable.d ^
OgreD\ogre\scene\scenemanager.d ^
OgreD\ogre\scene\scenenode.d ^
OgreD\ogre\scene\scenequery.d ^
OgreD\ogre\scene\shadowcamera.d ^
OgreD\ogre\scene\shadowcaster.d ^
OgreD\ogre\scene\shadowtexturemanager.d ^
OgreD\ogre\scene\shadowvolumeextrudeprogram.d ^
OgreD\ogre\scene\simplerenderable.d ^
OgreD\ogre\scene\skeletoninstance.d ^
OgreD\ogre\scene\staticgeometry.d ^
OgreD\ogre\scene\userobjectbindings.d ^
OgreD\ogre\scene\wireboundingbox.d ^
OgreD\ogre\sharedptr.d ^
OgreD\ogre\singleton.d ^
OgreD\ogre\spotshadowfadepng.d ^
OgreD\ogre\strings.d ^
OgreD\ogre\threading\defaultworkqueuestandard.d ^
%RENDERSYSTEMGL% ^
-version=OGRE_NO_ZIP_ARCHIVE -version=OGRE_NO_VIEWPORT_ORIENTATIONMODE ^
        -I.\Deps\DerelictFI -I.\Deps\DerelictUtil -I.\Deps\DerelictGL3 ^
		-I.\RenderSystems\GL -I.\OgreD ^
		.\Deps\DerelictFI\bin\Debug\libDerelictFI.lib ^
        .\Deps\DerelictUtil\bin\Debug\libDerelictUtil.lib ^
		.\Deps\DerelictGL3\bin\Debug\libDerelictGL3.lib 

REM		-I.\Deps\DerelictSDL2 ^
REM		.\Deps\DerelictSDL2\bin\Debug\libDerelictSDL2.lib ^

REM Pragma works?
REM	-L-lX11 -L-ldl -L-lXaw -L-lXt

REM Not yet, easier to debug single threaded :P
REM -version=OGRE_THREAD_SUPPORT_STD 

goto quit
:warn
echo needs to be in topdir
:quit
