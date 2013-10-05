module ogre.resources.highlevelgpuprogram;
debug import std.stdio;
import ogre.materials.gpuprogram;
import ogre.singleton;
import ogre.general.common;
import ogre.general.generals;
import ogre.exception;
import ogre.resources.unifiedhighlevelgpuprogram;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.resources.datastream;
import ogre.resources.resourcegroupmanager;
import ogre.general.log;
import ogre.sharedptr;

/** Abstract base class representing a high-level program (a vertex or
 fragment program).
 @remarks
 High-level programs are vertex and fragment programs written in a high-level
 language such as Cg or HLSL, and as such do not require you to write assembler code
 like GpuProgram does. However, the high-level program does eventually 
 get converted (compiled) into assembler and then eventually microcode which is
 what runs on the GPU. As well as the convenience, some high-level languages like Cg allow
 you to write a program which will operate under both Direct3D and OpenGL, something
 which you cannot do with just GpuProgram (which requires you to write 2 programs and
 use each in a Technique to provide cross-API compatibility). Ogre will be creating
 a GpuProgram for you based on the high-level program, which is compiled specifically 
 for the API being used at the time, but this process is transparent.
 @par
 You cannot create high-level programs direct - use HighLevelGpuProgramManager instead.
 Plugins can register new implementations of HighLevelGpuProgramFactory in order to add
 support for new languages without requiring changes to the core Ogre API. To allow 
 custom parameters to be set, this class extends StringInterface - the application
 can query on the available custom parameters and get/set them without having to 
 link specifically with it.
 */
class HighLevelGpuProgram : GpuProgram
{
public:

    //Cyclic static ctor
    static void initCmds()
    {
        UnifiedHighLevelGpuProgram.initCmds();
    }
    
protected:
    /// Whether the high-level program (and it's parameter defs) is loaded
    bool mHighLevelLoaded;
    /// The underlying assembler program
    SharedPtr!GpuProgram mAssemblerProgram;
    /// Have we built the name->index parameter map yet?
    //mutable 
    bool mConstantDefsBuilt;
    
    /// Internal load high-level portion if not loaded
    void loadHighLevel()
    {
        if (!mHighLevelLoaded)
        {
            try 
            {
                loadHighLevelImpl();
                mHighLevelLoaded = true;
                if (!mDefaultParams.isNull())
                {
                    // Keep a reference to old ones to copy
                    GpuProgramParametersPtr savedParams = mDefaultParams;
                    // reset params to stop them being referenced in the next create
                    mDefaultParams.setNull();
                    
                    // Create new params
                    mDefaultParams = createParameters();
                    
                    // Copy old (matching) values across
                    // Don't use copyConstantsFrom since program may be different
                    mDefaultParams.get().copyMatchingNamedConstantsFrom(savedParams.get());
                    
                }
                
            }
            catch (Exception e)
            {
                // will already have been logged
                LogManager.getSingleton().stream()
                    << "High-level program " << mName << " encountered an error "
                        << "during loading and is thus not supported.\n"
                        << e;//.getFullDescription();
                
                mCompileError = true;
            }
        }
    }
    
    /// Internal unload high-level portion if loaded
    void unloadHighLevel()
    {
        if (mHighLevelLoaded)
        {
            unloadHighLevelImpl();
            // Clear saved constant defs
            mConstantDefsBuilt = false;
            createParameterMappingStructures(true);
            
            mHighLevelLoaded = false;
        }
    }
    
    /** Internal load implementation, loads just the high-level portion, enough to 
     get parameters.
     */
    void loadHighLevelImpl()
    {
        if (mLoadFromFile)
        {
            // find & load source code
            DataStreamPtr stream = 
                ResourceGroupManager.getSingleton().openResource(
                    mFilename, mGroup, true, this);
            
            mSource = stream.getAsString();
        }
        
        loadFromSource();
    }
    
    /** Internal method for creating an appropriate low-level program from this
     high-level program, must be implemented by subclasses. */
    abstract void createLowLevelImpl();
    /// Internal unload implementation, must be implemented by subclasses
    abstract void unloadHighLevelImpl();
    /// Populate the passed parameters with name->index map
    void populateParameterNames(GpuProgramParametersPtr params)
    {
        getConstantDefinitions();
        params.get()._setNamedConstants(mConstantDefs);
        // also set logical / physical maps for programs which use this
        params.get()._setLogicalIndexes(mFloatLogicalToPhysical, mDoubleLogicalToPhysical, mIntLogicalToPhysical);
    }
    
    /** Build the constant definition map, must be overridden.
     @note The implementation must fill in the (inherited) mConstantDefs field at a minimum, 
     and if the program requires that parameters are bound using logical 
     parameter indexes then the mFloatLogicalToPhysical and mIntLogicalToPhysical
     maps must also be populated.
     */
    abstract void buildConstantDefinitions();
    
    /** @copydoc Resource::loadImpl */
    override void loadImpl()
    {
        if (isSupported())
        {
            // load self 
            loadHighLevel();
            
            // create low-level implementation
            createLowLevelImpl();
            // loadructed assembler program (if it exists)
            if (!mAssemblerProgram.isNull() && mAssemblerProgram.getPointer() != this)
            {
                mAssemblerProgram.get().load();
            }
            
        }
    }
    
    /** @copydoc Resource::unloadImpl */
    override void unloadImpl()
    {   
        if (!mAssemblerProgram.isNull() && mAssemblerProgram.getPointer() != this)
        {
            mAssemblerProgram.get().getCreator().remove(mAssemblerProgram.get().getHandle());
            mAssemblerProgram.setNull();
        }
        
        unloadHighLevel();
        resetCompileError();
    }
    
public:
    /** Constructor, should be used only by factory classes. */
    this(ref ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mHighLevelLoaded = false;
        mAssemblerProgram.setNull();// = null;
        mConstantDefsBuilt = false;
    }
    
    ~this()
    {
        // superclasses will trigger unload
    }
    
    override size_t calculateSize() //const
    {
        size_t memSize = 0;
        memSize += bool.sizeof;
        if(!mAssemblerProgram.isNull() && (mAssemblerProgram.getPointer() != this) )
            memSize += mAssemblerProgram.calculateSize();
        
        memSize += GpuProgram.calculateSize();
        
        return memSize;
    }
    
    /** Creates a new parameters object compatible with this program definition. 
     @remarks
     Unlike low-level assembly programs, parameters objects are specific to the
     program and Therefore must be created from it rather than by the 
     HighLevelGpuProgramManager. This method creates a new instance of a parameters
     object containing the definition of the parameters this program understands.
     */
    override GpuProgramParametersPtr createParameters()
    {
        // Lock mutex before allowing this since this is a top-level method
        // called outside of the load()
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(mLock)
        {
            // Make sure param defs are loaded
            GpuProgramParametersPtr params = GpuProgramManager.getSingleton().createParameters();
            // Only populate named parameters if we can support this program
            if (this.isSupported())
            {
                loadHighLevel();
                // Errors during load may have prevented compile
                if (this.isSupported())
                {
                    populateParameterNames(params);
                }
            }
            // Copy in default parameters if present
            if (!mDefaultParams.isNull())
                params.get().copyConstantsFrom(mDefaultParams.get());
            return params;
        }
    }
    /** @copydoc GpuProgram::_getBindingDelegate */
    override GpuProgram _getBindingDelegate() { return mAssemblerProgram.getAs(); }
    
    /** Get the full list of GpuConstantDefinition instances.
     @note
     Only available if this parameters object has named parameters.
     */
    override GpuNamedConstants* getConstantDefinitions()
    {
        if (!mConstantDefsBuilt)
        {
            buildConstantDefinitions();
            mConstantDefsBuilt = true;
        }
        return mConstantDefs.get();
        
    }
    
    /// Override GpuProgram::getNamedConstants to ensure built
    override GpuNamedConstants getNamedConstants(){ return *getConstantDefinitions(); }
    
}

/** Specialisation of SharedPtr to allow SharedPtr to be assigned to SharedPtr!HighLevelGpuProgram 
 @note Has to be a subclass since we need operator=.
 We could templatise this instead of repeating per Resource subclass, 
 except to do so requires a form VC6 does not support i.e.
 ResourceSubclassPtr<T> : public SharedPtr<T>
 */
//alias SharedPtr!r!HighLevelGpuProgram HighLevelSharedPtr;


/** Interface definition for factories of HighLevelGpuProgram. */
interface HighLevelGpuProgramFactory //: public FactoryAlloc
{
    /// Get the name of the language this factory creates programs for
    string getLanguage();
    HighLevelGpuProgram create(ResourceManager creator, 
                               string name, ResourceHandle handle,
                               string group, bool isManual, ManualResourceLoader loader);
    void destroyObj(HighLevelGpuProgram prog);
}

enum string sNullLang = "null";
class NullProgram : HighLevelGpuProgram
{
protected:
    /** Internal load implementation, must be implemented by subclasses.
     */
    override void loadFromSource() {}
    /** Internal method for creating an appropriate low-level program from this
     high-level program, must be implemented by subclasses. */
    override void createLowLevelImpl() {}
    /// Internal unload implementation, must be implemented by subclasses
    override void unloadHighLevelImpl() {}
    /// Populate the passed parameters with name->index map, must be overridden
    override void populateParameterNames(GpuProgramParametersPtr params)
    {
        // Skip the normal implementation
        // Ensure we don't complain about missing parameter names
        params.get().setIgnoreMissingParams(true);
        
    }
    override void buildConstantDefinitions()
    {
        // do nothing
    }
public:
    this(ref ResourceManager creator, 
         string name, ResourceHandle handle,string group, 
         bool isManual, ManualResourceLoader loader)
    {
        super(creator, name, handle, group, isManual, loader);
    }
    ~this() {}
    /// Overridden from GpuProgram - never supported
    override bool isSupported(){ return false; }
    /// Overridden from GpuProgram
    override string getLanguage(){ return sNullLang; }
    override size_t calculateSize() //const 
    { return 0; }
    
    /// Overridden from StringInterface
    override bool setParameter(string name,string value)
    {
        // always silently ignore all parameters so as not to report errors on
        // unsupported platforms
        return true;
    }
    
}

class NullProgramFactory : HighLevelGpuProgramFactory
{
public:
    this() {}
    ~this() {}
    /// Get the name of the language this factory creates programs for
    string getLanguage()
    { 
        return sNullLang;
    }
    HighLevelGpuProgram create(ResourceManager creator, 
                               string name, ResourceHandle handle,
                               string group, bool isManual, ManualResourceLoader loader)
    {
        return new NullProgram(creator, name, handle, group, isManual, loader);
    }
    void destroyObj(HighLevelGpuProgram prog)
    {
        destroy(prog);
    }
    
}
/** This ResourceManager manages high-level vertex and fragment programs. 
 @remarks
 High-level vertex and fragment programs can be used instead of assembler programs
 as managed by GpuProgramManager; however they typically result in a GpuProgram
 being created as a derivative of the high-level program. High-level programs are
 easier to write, and can often be API-independent, unlike assembler programs. 
 @par
 This class not only manages the programs themselves, it also manages the factory
 classes which allow the creation of high-level programs using a variety of high-level
 syntaxes. Plugins can be created which register themselves as high-level program
 factories and as such the engine can be extended to accept virtually any kind of
 program provided a plugin is written.
 */
class HighLevelGpuProgramManager : ResourceManager
{
    mixin Singleton!HighLevelGpuProgramManager;
    
public:
    //typedef map<String, HighLevelGpuProgramFactory*>::type FactoryMap;
    alias HighLevelGpuProgramFactory[string] FactoryMap;
protected:
    /// Factories capable of creating HighLevelGpuProgram instances
    FactoryMap mFactories;
    
    /// Factory for dealing with programs for languages we can't create
    HighLevelGpuProgramFactory mNullFactory;
    /// Factory for unified high-level programs
    HighLevelGpuProgramFactory mUnifiedFactory;
    
    ref HighLevelGpuProgramFactory getFactory(string language)
    {
        auto i = language in mFactories;
        
        if (i is null)
        {
            // use the null factory to create programs that will never be supported
            i = sNullLang in mFactories;
        }
        return *i;
    }
    
    /// @copydoc ResourceManager::createImpl
    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams)
    {
        string *ptr;
        
        if (createParams is null || (ptr = "language" in createParams) is null)
        {
            throw new InvalidParamsError(
                "You must supply a 'language' parameter",
                "HighLevelGpuProgramManager.createImpl");
        }
        
        return getFactory(*ptr).create(this, name, getNextHandle(), 
                                       group, isManual, loader);
    }
public:
    this()
    {
        // Loading order
        mLoadOrder = 50.0f;
        // Resource type
        mResourceType = "HighLevelGpuProgram";
        
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);    
        
        mNullFactory = new NullProgramFactory();
        addFactory(mNullFactory);
        mUnifiedFactory = new UnifiedHighLevelGpuProgramFactory();
        addFactory(mUnifiedFactory);
    }
    
    ~this()
    {
        destroy(mUnifiedFactory);
        destroy(mNullFactory);
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);    
    }
    
    /** Add a new factory object for high-level programs of a given language. */
    void addFactory(HighLevelGpuProgramFactory factory)
    {
        // deliberately allow later plugins to override earlier ones
        mFactories[factory.getLanguage()] = factory;
    }
    
    /** Remove a factory object for high-level programs of a given language. */
    void removeFactory(HighLevelGpuProgramFactory factory)
    {
        // Remove only if equal to registered one, since it might overridden
        // by other plugins
        auto it = factory.getLanguage() in mFactories;
        if (it !is null && *it == factory)
        {
            mFactories.remove(factory.getLanguage());
        }
    }
    
    /** Returns whether a given high-level language is supported. */
    bool isLanguageSupported(string lang)
    {
        return (lang in mFactories) !is null;
    }
    
    
    /** Create a new, unloaded HighLevelGpuProgram. 
     @par
     This method creates a new program of the type specified as the second and third parameters.
     You will have to call further methods on the returned program in order to 
     define the program fully before you can load it.
     @param name The identifying name of the program
     @param groupName The name of the resource group which this program is
     to be a member of
     @param language Code of the language to use (e.g. "cg")
     @param gptype The type of program to create
     */
    SharedPtr!HighLevelGpuProgram createProgram(
        string name,string groupName, 
        string language, GpuProgramType gptype)
    {
        //SharedPtr!Resource prg = SharedPtr!Resource(
        SharedPtr!HighLevelGpuProgram prg = SharedPtr!HighLevelGpuProgram(
            getFactory(language).create(this, name, getNextHandle(), 
                                    groupName, false, null));

        SharedPtr!Resource ret = prg;
        //SharedPtr!HighLevelGpuProgram prg = ret;
        prg.getAs().setType(gptype);
        prg.getAs().setSyntaxCode(language);
        
        addImpl(ret);
        // Tell resource group manager
        ResourceGroupManager.getSingleton()._notifyResourceCreated(ret);
        return prg;
    }
    
}