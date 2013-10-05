module ogre.config;

version=OGRE_NO_PROFILING;
version=OGRE_NO_DDS_CODEC;
version=OGRE_NO_PVRTC_CODEC;
version=OGRE_NO_ETC1_CODEC;
version=OGRE_NO_ZIP_ARCHIVE;
//version=OGRE_NO_FREEIMAGE;
//version=RTSHADER_SYSTEM_BUILD_CORE_SHADERS;
//version=OGRE_PRETEND_TEXTURE_UNITS;
//version=OGRE_DOUBLE_PRECISION;
//version=OGRE_VIEWPORT_ORIENTATIONMODE;
//version=OGRE_DONT_USE_NEW_COMPILERS;
//version=OGRE_GTK;

enum OGRE_VERSION_MAJOR = 1;
enum OGRE_VERSION_MINOR = 9;
enum OGRE_VERSION_PATCH = 0;
enum OGRE_VERSION_SUFFIX = "unstable";
enum OGRE_VERSION_NAME = "Ghadamon";

@property
uint OGRE_VERSION()
{
    return ((OGRE_VERSION_MAJOR << 16) | (OGRE_VERSION_MINOR << 8) | OGRE_VERSION_PATCH);
}

version(Posix)
    enum OgrePosix = true;
else
    enum OgrePosix = false;

version(OSX)
    enum OgreOSX = true;
else
    enum OgreOSX = false;
    
version(linux)
    enum OgreLinux = true;
else
    enum OgreLinux = false;

version(Windows)
    enum OgreWindows = true;
else
    enum OgreWindows = false;

debug version=Debug;
version(Debug)
{
    enum OGRE_BUILD_SUFFIX = "_d";
    enum OGRE_DEBUG_MODE = true;
}
else
{
    enum OGRE_BUILD_SUFFIX = "";
    enum OGRE_DEBUG_MODE = false;
}

//pragma(msg, OGRE_BUILD_SUFFIX);

/** If set, profiling code will be included in the application. When you
    are deploying your application you will probably want to without */
version(OGRE_NO_PROFILING)
    enum OGRE_PROFILING = false;
else
    enum OGRE_PROFILING = true;

/** If set to true, Real is typedef'ed to double. Otherwise, Real is typedef'ed
    to float. Setting this allows you to perform mathematical operations in the
    CPU (Quaternion, Vector3 etc) with more precision, but bear in mind that the
    GPU still operates in single-precision mode.
*/
version(OGRE_DOUBLE_PRECISION)
    enum OGRE_DOUBLE_PRECISION = true;
else
    enum OGRE_DOUBLE_PRECISION = false;

/** If set to >0, OGRE will always 'think' that the graphics card only has the
    number of texture units specified. Very useful for testing multipass fallback.
    @note Use OGRE_PRETEND_TEXTURE_UNITS_COUNT to specify.
*/
version(OGRE_PRETEND_TEXTURE_UNITS)
    enum OGRE_PRETEND_TEXTURE_UNITS = true;
else
    enum OGRE_PRETEND_TEXTURE_UNITS = false;

//TODO Move to RTShader system config
version(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
    enum RTSHADER_SYSTEM_BUILD_CORE_SHADERS = true;
else
    enum RTSHADER_SYSTEM_BUILD_CORE_SHADERS = false;

/** Support for multithreading, there are 3 options
    EVERYTHING IS SUBJECT TO CHANGE, ALSO EXPLOSIONS AND LOUD NOISES.
    OGRE_THREAD_SUPPORT = 0
        No support for threading.       
    OGRE_THREAD_SUPPORT = 1
        Thread support for background loading, by both loading andructing resources
        in a background thread. Resource management and SharedPtr handling becomes
        thread-safe, and resources may be completely loaded in the background. 
        The places where threading is available are clearly
        marked, you should assume state is NOT thread safe unless otherwise
        stated in relation to this flag.
    OGRE_THREAD_SUPPORT = 2
        Thread support for background resource preparation. This means that resource
        data can streamed into memory in the background, but the final resource
        construction (including RenderSystem dependencies) is still done in the primary
        thread. Has a lower synchronisation primitive overhead than full threading
        while still allowing the major blocking aspects of resource management (I/O)
        to be done in the background.
*/
//version=OGRE_THREAD_SUPPORT; //Also enable if anything but _NONE is defined
version=OGRE_THREAD_SUPPORT_NONE; // aka OGRE_THREAD_SUPPORT 0
//version=OGRE_THREAD_SUPPORT_STD; // aka OGRE_THREAD_SUPPORT 1
//version=OGRE_THREAD_SUPPORT_ALT; // aka OGRE_THREAD_SUPPORT 2

version(OGRE_THREAD_SUPPORT_STD)
    enum OGRE_THREAD_SUPPORT = 1;
else
    enum OGRE_THREAD_SUPPORT = 0;

enum OGRE_THREAD_HARDWARE_CONCURRENCY = 2; //TODO core should have some cpuid stuff for this

/// Probably not applicable to D, but for completeness sake.
//version=OGRE_THREAD_PROVIDER_NONE;
version=OGRE_THREAD_PROVIDER_D;
//version=OGRE_THREAD_PROVIDER_BOOST;
//version=OGRE_THREAD_PROVIDER_POCO;
//version=OGRE_THREAD_PROVIDER_TBB;

/** Enables use of the FreeImage image library for loading images.
    WARNING: Use only when you want to provide your own image loading code via codecs.
*/
version(OGRE_NO_FREEIMAGE)
    enum OGRE_FREEIMAGE = false;
else
    enum OGRE_FREEIMAGE = true;

/** Enables use of the internal image codec for loading DDS files.
    WARNING: Use only when you want to provide your own image loading code via codecs.
*/
version(OGRE_NO_DDS_CODEC)
    enum OGRE_DDS_CODEC = false;
else
    enum OGRE_DDS_CODEC = true;

version(OGRE_NO_PVRTC_CODEC)
    enum OGRE_PVRTC_CODEC = false;
else
    enum OGRE_PVRTC_CODEC = true;

version(OGRE_NO_ETC1_CODEC)
    enum OGRE_ETC1_CODEC = false;
else
    enum OGRE_ETC1_CODEC = true;

/** Enables use of the ZIP archive support.
    WARNING: Disabling this will make the samples unusable.
*/
version(OGRE_NO_ZIP_ARCHIVE)
    enum OGRE_ZIP_ARCHIVE = false;
else
    enum OGRE_ZIP_ARCHIVE = true;

// #define OGRE_NO_VIEWPORT_ORIENTATIONMODE   0
//version=OGRE_NO_VIEWPORT_ORIENTATIONMODE_0; //TODO Fix the way this gets used.
version(OGRE_VIEWPORT_ORIENTATIONMODE)
    enum OGRE_NO_VIEWPORT_ORIENTATIONMODE = false;
else
    enum OGRE_NO_VIEWPORT_ORIENTATIONMODE = true;

/** Enables the use of the new script compilers when Ogre compiles resource scripts.
*/
version(OGRE_DONT_USE_NEW_COMPILERS)
    enum OGRE_USE_NEW_COMPILERS = false;
else
    enum OGRE_USE_NEW_COMPILERS = true;

/** Use gtk for dialogs.
 */
version(OGRE_GTK)
    enum OGRE_GTK = true;
else
    enum OGRE_GTK = false;

version(OGRE_GTK2)
    enum OGRE_GTK_LIB = "gtk-x11-2.0";
else
    enum OGRE_GTK_LIB = "gtk-3";

// Someday...
//version=D_NOW_HAS_DYNAMIC_LOADING;

enum {
    OGRE_PRETEND_TEXTURE_UNITS_COUNT = 4, //random
    /** Define number of texture coordinate sets allowed per vertex.
    */
    OGRE_MAX_TEXTURE_COORD_SETS = 8,
    /** Define max number of texture layers allowed per pass on any card.
    */
    OGRE_MAX_TEXTURE_LAYERS = 16,
    /** Define max number of lights allowed per pass.
    */
    OGRE_MAX_SIMULTANEOUS_LIGHTS = 8,
    /** Define max number of blending weights allowed per vertex.
    */
    OGRE_MAX_BLEND_WEIGHTS = 4,
    /** Define max number of multiple render targets (MRTs) to render to at once.
    */
    OGRE_MAX_MULTIPLE_RENDER_TARGETS = 8,
}


/* Define the number of priority groups for the render system's render targets. */
//#ifndef OGRE_NUM_RENDERTARGET_GROUPS
enum : uint //OgreRenderTarget.h
{
    OGRE_NUM_RENDERTARGET_GROUPS = 10,
    OGRE_DEFAULT_RT_GROUP = 4,
    OGRE_REND_TO_TEX_RT_GROUP = 2,
}
//#endif
