module ogregl.glew;
import std.conv: to, text;
import std.string: indexOf;

private import derelict.opengl3.gl;
private import derelict.opengl3.glx;
import ogre.general.log;
import ogregl.config;

@property
{
    //TODO Check for loadedVersion < GLVersion.GL31 ?
    bool GLEW_VERSION_1_1() { return DerelictGL.loadedVersion >= GLVersion.GL11 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_1_2() { return DerelictGL.loadedVersion >= GLVersion.GL12 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_1_3() { return DerelictGL.loadedVersion >= GLVersion.GL13 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_1_4() { return DerelictGL.loadedVersion >= GLVersion.GL14 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_1_5() { return DerelictGL.loadedVersion >= GLVersion.GL15 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_2_0() { return DerelictGL.loadedVersion >= GLVersion.GL20 && DerelictGL.loadedVersion < GLVersion.GL31; }
    bool GLEW_VERSION_2_1() { return DerelictGL.loadedVersion >= GLVersion.GL21 && DerelictGL.loadedVersion < GLVersion.GL31; }
    //Old stuff getting deprecated
    bool GLEW_VERSION_3_0() { return DerelictGL.loadedVersion >= GLVersion.GL30; }
    //Old stuff removed
    bool GLEW_VERSION_3_1() { return DerelictGL.loadedVersion >= GLVersion.GL31; }
    bool GLEW_VERSION_3_2() { return DerelictGL.loadedVersion >= GLVersion.GL32; }
    bool GLEW_VERSION_3_3() { return DerelictGL.loadedVersion >= GLVersion.GL33; }
    bool GLEW_VERSION_4_0() { return DerelictGL.loadedVersion >= GLVersion.GL40; }
    bool GLEW_VERSION_4_1() { return DerelictGL.loadedVersion >= GLVersion.GL41; }
    bool GLEW_VERSION_4_2() { return DerelictGL.loadedVersion >= GLVersion.GL42; }
    bool GLEW_VERSION_4_3() { return DerelictGL.loadedVersion >= GLVersion.GL43; }
}

enum : GLenum
{
    GLEW_OK  = 0,
    GLEW_NO_ERROR = 0,
    GLEW_ERROR_NO_GL_VERSION  = 1,  /* missing GL version */
    GLEW_ERROR_GL_VERSION_10_ONLY = 2,  /* Need at least OpenGL 1.1 */
    GLEW_ERROR_GLX_VERSION_11_ONLY = 3,  /* Need at least GLX 1.2 */
}

bool GLXEW_VERSION_1_2 = true;
bool GLXEW_VERSION_1_3 = true;
bool GLXEW_VERSION_1_4 = true;

static if(USE_GLX)
{
    GLenum glxewContextInit( /*GLXGLSupport sup, */ void * disp = null)
    {
        //Other stuff should be in derelict.opengl3.glx already
        int major, minor;
        
        /* initialize core GLX 1.2 */
        if(glXGetCurrentDisplay is null) //Derelict probably throws before?
        {
            GLXEW_VERSION_1_2 = false;
            return GLEW_ERROR_GLX_VERSION_11_ONLY;
        }
        
        /* query GLX version */
        if(disp is null)
            glXQueryVersion(glXGetCurrentDisplay(), &major, &minor);
        else
            glXQueryVersion(disp, &major, &minor);
        
        LogManager.getSingleton().logMessage(text("GLX version:", major,".", minor));
        
        if (major == 1 && minor <= 3)
        {
            switch (minor)
            {
                case 3:
                    GLXEW_VERSION_1_4 = false;
                    break;
                case 2:
                    GLXEW_VERSION_1_4 = false;
                    GLXEW_VERSION_1_3 = false;
                    break;
                default:
                    return GLEW_ERROR_GLX_VERSION_11_ONLY;
                    break;
            }
        }
        
        return GLEW_OK;
    }
}