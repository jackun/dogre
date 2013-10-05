module ogregl.glsl.gpuprogram;
import derelict.opengl3.gl;

import ogregl.gpuprogram;
import ogre.materials.gpuprogram;
import ogre.rendersystem.vertex;
import ogregl.glsl.program;
import ogregl.glsl.linkprogrammanager;
import ogregl.glsl.linkprogram;


/** GLSL low level compiled shader object - this class is used to get at the linked program object
        and provide an interface for GLRenderSystem calls.  GLSL does not provide access to the
        low level code of the shader so this class is really just a dummy place holder.
        GLSL uses a program object to represent the active vertex and fragment programs used
        but Ogre materials maintain separate instances of the active vertex and fragment programs
        which creates a small problem for GLSL integration.  The GLSLGpuProgram class provides the
        interface between the GLSLLinkProgramManager , GLRenderSystem, and the active GLSLProgram
        instances.
    */
class GLSLGpuProgram : GLGpuProgram
{
private:
    /// GL Handle for the shader object
    GLSLProgram mGLSLProgram;

    /// Keep track of the number of vertex shaders created
    static GLuint mVertexShaderCount;
    /// Keep track of the number of fragment shaders created
    static GLuint mFragmentShaderCount;
    /// keep track of the number of geometry shaders created
    static GLuint mGeometryShaderCount;

public:
    this(GLSLProgram parent)
    {
        super(parent.getCreator(), parent.getName(), parent.getHandle(),
              parent.getGroup(), false, null);
        mGLSLProgram = parent;

        mType = parent.getType();
        mSyntaxCode = "glsl";

        if (parent.getType() == GpuProgramType.GPT_VERTEX_PROGRAM)
        {
            mProgramID = ++mVertexShaderCount;
        }
        else if (parent.getType() == GpuProgramType.GPT_FRAGMENT_PROGRAM)
        {
            mProgramID = ++mFragmentShaderCount;
        }
        else
        {
            mProgramID = ++mGeometryShaderCount;
        }

        // transfer skeletal animation status from parent
        mSkeletalAnimation = mGLSLProgram.isSkeletalAnimationIncluded();
        // there is nothing to load
        mLoadFromFile = false;

    }

    ~this()
    {
        // have to call this here rather than in Resource destructor
        // since calling virtual methods in base destructors causes crash
        unload();
    }


    /// Execute the binding functions for this program
    override void bindProgram()
    {
        // Tell the Link Program Manager what shader is to become active
        switch (mType)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                GLSLLinkProgramManager.getSingleton().setActiveVertexShader( this );
                break;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                GLSLLinkProgramManager.getSingleton().setActiveFragmentShader( this );
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                GLSLLinkProgramManager.getSingleton().setActiveGeometryShader( this );
                break;
            default:
                break;
        }
    }

    /// Execute the unbinding functions for this program
    override void unbindProgram()
    {
        // Tell the Link Program Manager what shader is to become inactive
        if (mType == GpuProgramType.GPT_VERTEX_PROGRAM)
        {
            GLSLLinkProgramManager.getSingleton().setActiveVertexShader( null );
        }
        else if (mType == GpuProgramType.GPT_GEOMETRY_PROGRAM)
        {
            GLSLLinkProgramManager.getSingleton().setActiveGeometryShader( null );
        }
        else // its a fragment shader
        {
            GLSLLinkProgramManager.getSingleton().setActiveFragmentShader( null );
        }

    }

    /// Execute the param binding functions for this program
    override void bindProgramParameters(SharedPtr!GpuProgramParameters params, ushort mask)
    {
        // link can throw exceptions, ignore them at this point
        try
        {
            // activate the link program object
            GLSLLinkProgram linkProgram = GLSLLinkProgramManager.getSingleton().getActiveLinkProgram();
            // pass on parameters from params to program object uniforms
            linkProgram.updateUniforms(params, mask, mType);
        }
        catch (Exception e) {}

    }

    /// Execute the pass iteration param binding functions for this program
    override void bindProgramPassIterationParameters(SharedPtr!GpuProgramParameters params)
    {
        // activate the link program object
        GLSLLinkProgram linkProgram = GLSLLinkProgramManager.getSingleton().getActiveLinkProgram();
        // pass on parameters from params to program object uniforms
        linkProgram.updatePassIterationUniforms( params );

    }

    /// Get the assigned GL program id
    override GLuint getProgramID() const
    { return mProgramID; }

    /// Get the GLSLProgram for the shader object
    GLSLProgram getGLSLProgram() { return mGLSLProgram; }
    const(GLSLProgram) getGLSLProgram() const { return mGLSLProgram; }

    /// @copydoc GLGpuProgram::getAttributeIndex
    override GLuint getAttributeIndex(VertexElementSemantic semantic, uint index)
    {
        // get link program - only call this in the context of bound program
        GLSLLinkProgram linkProgram = GLSLLinkProgramManager.getSingleton().getActiveLinkProgram();

        if (linkProgram.isAttributeValid(semantic, index))
        {
            return linkProgram.getAttributeIndex(semantic, index);
        }
        else
        {
            // fall back to default implementation, allow default bindings
            return GLGpuProgram.getAttributeIndex(semantic, index);
        }

    }

    /// @copydoc GLGpuProgram::isAttributeValid
    override bool isAttributeValid(VertexElementSemantic semantic, uint index)
    {
        // get link program - only call this in the context of bound program
        GLSLLinkProgram linkProgram = GLSLLinkProgramManager.getSingleton().getActiveLinkProgram();

        if (linkProgram.isAttributeValid(semantic, index))
        {
            return true;
        }
        else
        {
            // fall back to default implementation, allow default bindings
            return GLGpuProgram.isAttributeValid(semantic, index);
        }
    }

protected:
    /// Overridden from GpuProgram
    override void loadFromSource()
    {
        // nothing to load
    }

    /// @copydoc Resource::unloadImpl
    override void unloadImpl()
    {
        // nothing to load
    }

    /// @copydoc Resource::loadImpl
    override void loadImpl()
    {
        // nothing to load
    }
}