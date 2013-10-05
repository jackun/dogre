module ogregl.glsl.programfactory;
import ogre.resources.highlevelgpuprogram;
import ogre.resources.resourcemanager;
import ogre.resources.resource;
import ogregl.glsl.linkprogrammanager;
import ogregl.glsl.program;

/** Factory class for GLSL programs. */
class GLSLProgramFactory : HighLevelGpuProgramFactory
{
protected:
    enum string sLanguageName = "glsl";
public:
    this()
    {
        mLinkProgramManager = new GLSLLinkProgramManager();
    }

    ~this()
    {
        if (mLinkProgramManager)
            destroy(mLinkProgramManager);
    }

    /// Get the name of the language this factory creates programs for
    const string getLanguage() const
    {
        return sLanguageName;
    }

    /// Create an instance of GLSLProgram
    HighLevelGpuProgram create(ResourceManager creator, 
                                string name, ResourceHandle handle,
                                string group, bool isManual, ManualResourceLoader loader)
    {
        return new GLSLProgram(creator, name, handle, group, isManual, loader);
    }

    void destroyObj(HighLevelGpuProgram prog)
    {
        destroy(prog);
    }
    
private:
    GLSLLinkProgramManager mLinkProgramManager;
}