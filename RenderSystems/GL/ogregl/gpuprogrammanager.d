module ogregl.gpuprogrammanager;
import ogre.materials.gpuprogram;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.general.common;
import ogre.exception;
import ogre.resources.resourcegroupmanager;
import ogregl.gpuprogram;

class GLGpuProgramManager : GpuProgramManager
{
public:
    alias GpuProgram function(ResourceManager creator, 
                              string name, ResourceHandle handle, 
                              string group, bool isManual, ManualResourceLoader loader,
                              GpuProgramType gptype, string syntaxCode) CreateGpuProgramCallback;
    
private:
    //typedef map<String, CreateGpuProgramCallback>::type ProgramMap;
    alias CreateGpuProgramCallback[string] ProgramMap;
    ProgramMap mProgramMap;
    
protected:
    /// @copydoc ResourceManager::createImpl
    override Resource createImpl(string name, ResourceHandle handle, 
                         string group, bool isManual, ManualResourceLoader loader,
                         NameValuePairList params)
    {
        string* paramSyntax, paramType;
        
        if (params.length || (paramSyntax = "syntax" in params) is null ||
            (paramType = "type" in params) is null)
        {
            throw new InvalidParamsError(
                        "You must supply 'syntax' and 'type' parameters",
                        "GLGpuProgramManager.createImpl");
        }
        
        auto iter = *paramSyntax in mProgramMap;
        if(iter is null)
        {
            // No factory, this is an unsupported syntax code, probably for another rendersystem
            // Create a basic one, it doesn't matter what it is since it won't be used
            return new GLGpuProgram(this, name, handle, group, isManual, loader);
        }
        
        GpuProgramType gpt;
        if ((*paramType) == "vertex_program")
        {
            gpt = GpuProgramType.GPT_VERTEX_PROGRAM;
        }
        else if ((*paramType) == "geometry_program")
        {
            gpt = GpuProgramType.GPT_GEOMETRY_PROGRAM;
        }
        else
        {
            gpt = GpuProgramType.GPT_FRAGMENT_PROGRAM;
        }
        
        return (*iter)(this, name, handle, group, isManual, loader, gpt, *paramSyntax);
        
    }

    /// Specialised create method with specific parameters
    override Resource createImpl(string name, ResourceHandle handle, 
                         string group, bool isManual, ManualResourceLoader loader,
                         GpuProgramType gptype, string syntaxCode)
    {
        auto iter = syntaxCode in mProgramMap;
        if(iter is null)
        {
            // No factory, this is an unsupported syntax code, probably for another rendersystem
            // Create a basic one, it doesn't matter what it is since it won't be used
            return new GLGpuProgram(this, name, handle, group, isManual, loader);
        }
        
        return (*iter)(this, name, handle, group, isManual, loader, gptype, syntaxCode);
    }
    
public:
    this()
    {
        // Superclass sets up members 
        
        // Register with resource group manager
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
    }

    ~this()
    {
        // Unregister with resource group manager
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
    }

    bool registerProgramFactory(string syntaxCode, CreateGpuProgramCallback createFn)
    {
        //TODO Simulating std::map.insert(blah).first
        if( (syntaxCode in mProgramMap) !is null) return false;

        mProgramMap[syntaxCode] = createFn;
        return true;
    }

    bool unregisterProgramFactory(string syntaxCode)
    {
        mProgramMap.remove(syntaxCode);
        return true;
    }
}