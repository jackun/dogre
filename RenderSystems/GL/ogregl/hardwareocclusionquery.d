module ogregl.hardwareocclusionquery;
import derelict.opengl3.gl;
import ogre.rendersystem.hardware;
import ogre.exception;
import ogregl.glew;
import ogregl.compat;

// If you use multiple rendering passes you can test only the first pass and all other passes don't have to be rendered 
// if the first pass result has too few pixels visible.

// Be sure to render all occluder first and whats out so the RenderQue don't switch places on 
// the occluding objects and the tested objects because it thinks it's more effective..


/**
  * This is a class that is the base class of the query class for 
  * hardware occlusion.
  *
  * @author Lee Sandberg email: lee@abcmedia.se
  * Updated on 13/9/2005 by Tuan Kuranes email: tuan.kuranes@free.fr
  */

class GLHardwareOcclusionQuery : HardwareOcclusionQuery
{
    //----------------------------------------------------------------------
    // Public methods
    //--
public:
    /**
      * Default object constructor
      * 
      */
    this()
    { 
        // Check for hardware occlusion support
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glGenQueries(1, &mQueryID ); 
        }
        /*else if (NV_occlusion_query)
        {
            glGenOcclusionQueriesNV(1, &mQueryID);
        }*/
        else
        {
            throw new InternalError(
                        "Cannot allocate a Hardware query. This video card doesn't support it, sorry.", 
                        "GLHardwareOcclusionQuery.GLHardwareOcclusionQuery" );
        }
        
    }
    /**
      * Object destructor
      */
    ~this()
    { 
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glDeleteQueries(1, &mQueryID);  
        }
        /*else if (NV_occlusion_query)
        {
            glDeleteOcclusionQueriesNV(1, &mQueryID);  
        }*/
    }
    
    //------------------------------------------------------------------
    // Occlusion query functions (see base class documentation for this)
    //--
    override void beginOcclusionQuery()
    { 
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glBeginQuery(GL_SAMPLES_PASSED, mQueryID);
        }
        /*else if (GLEW_NV_occlusion_query)
        {
            glBeginOcclusionQueryNV(mQueryID);
        }*/
    }
    
    override void endOcclusionQuery()
    { 
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glEndQuery(GL_SAMPLES_PASSED);
        }
        /*else if (GLEW_NV_occlusion_query)
        {
            glEndOcclusionQueryNV();
        }*/
    }
    
    override bool pullOcclusionQuery( uint* NumOfFragments)
    {
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glGetQueryObjectuiv(mQueryID, GL_QUERY_RESULT, cast(GLuint*)NumOfFragments);
            mPixelCount = *NumOfFragments;
            return true;
        }
        /*else if (GLEW_NV_occlusion_query)
        {
            glGetOcclusionQueryuivNV(mQueryID, GL_PIXEL_COUNT_NV, (GLuint*)NumOfFragments);
            mPixelCount = *NumOfFragments;
            return true;
        }*/
        
        return false;
    }
    
    override bool isStillOutstanding()
    {    
        GLuint available = GL_FALSE;
        
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            glGetQueryObjectuiv(mQueryID, GL_QUERY_RESULT_AVAILABLE, &available);
        }
        /*else if (GLEW_NV_occlusion_query)
        {
            glGetOcclusionQueryuivNV(mQueryID, GL_PIXEL_COUNT_AVAILABLE_NV, &available);
        }*/
        
        // GL_TRUE means a wait would occur
        return !(available == GL_TRUE);  
    } 
    
    
    //----------------------------------------------------------------------
    // private members
    //--
private:
    
    GLuint          mQueryID;
}