module ogre.resources.unifiedhighlevelgpuprogram;
import ogre.general.generals;
import ogre.resources.highlevelgpuprogram;
import ogre.compat;
import ogre.exception;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.materials.gpuprogram;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */
/** Specialisation of HighLevelGpuProgram which just delegates its implementation
 to one other high level program, allowing a single program definition
 to represent one supported program from a number of options
 @remarks
 Whilst you can use Technique to implement several ways to render an object
 depending on hardware support, if the only reason to need multiple paths is
 because of the high-level shader language supported, this can be 
 cumbersome. For example you might want to implement the same shader 
 in HLSL and GLSL for portability but apart from the implementation detail,
 the shaders do the same thing and take the same parameters. If the materials
 in question are complex, duplicating the techniques just to switch language
 is not optimal, so instead you can define high-level programs with a 
 syntax of 'unified', and list the actual implementations in order of
 preference via repeated use of the 'delegate' parameter, which just points
 at another program name. The first one which has a supported syntax 
 will be used.
 */
class UnifiedHighLevelGpuProgram : HighLevelGpuProgram
{
public:
    /// Command object for setting delegate (can set more than once)
    static class CmdDelegate : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            // Can't do this (not one delegate), shouldn't matter
            return null;
        }

        void doSet(Object target, string val)
        {
            (cast(UnifiedHighLevelGpuProgram)target).addDelegateProgram(val);
        }
    }
    
protected:
    static CmdDelegate msCmdDelegate;
    
    package static void initCmds()
    {
        msCmdDelegate = new CmdDelegate;
    }
    
    /// Ordered list of potential delegates
    StringVector mDelegateNames;
    /// The chosen delegate
    //mutable 
    SharedPtr!HighLevelGpuProgram mChosenDelegate;
    
    /// Choose the delegate to use
    void chooseDelegate()
    {
        synchronized(mLock)
        {
            mChosenDelegate.setNull();
            
            foreach (i; mDelegateNames)
            {
                SharedPtr!HighLevelGpuProgram deleg = 
                    HighLevelGpuProgramManager.getSingleton().getByName(i);
                
                // Silently ignore missing links
                if(!deleg.isNull()
                   && deleg.getAs().isSupported())
                {
                    mChosenDelegate = deleg;
                    break;
                }
                
            }
        }
        
    }
    
    override void createLowLevelImpl()
    {
        throw new NotImplementedError(
            "This method should never get called!",
            "UnifiedHighLevelGpuProgram.createLowLevelImpl");
    }

    override void unloadHighLevelImpl()
    {
        throw new NotImplementedError(
            "This method should never get called!",
            "UnifiedHighLevelGpuProgram.unloadHighLevelImpl");
    }

    override void buildConstantDefinitions() //const
    {
        throw new NotImplementedError(
            "This method should never get called!",
            "UnifiedHighLevelGpuProgram.buildConstantDefinitions");
    }

    override void loadFromSource()
    {
        throw new NotImplementedError(
            "This method should never get called!",
            "UnifiedHighLevelGpuProgram.loadFromSource");
    }
    
public:
    /** Constructor, should be used only by factory classes. */
    this(ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)

    {
        super(creator, name, handle, group, isManual, loader);
        if (createParamDictionary("UnifiedHighLevelGpuProgram"))
        {
            setupBaseParamDictionary();
            
            ParamDictionary dict = getParamDictionary();
            
            dict.addParameter(new ParameterDef("delegate", 
                                               "Additional delegate programs containing implementations.",
                                               ParameterType.PT_STRING), msCmdDelegate);
        }
        
    }

    ~this() {}
    
    
    /** Adds a new delegate program to the list.
     @remarks
     Delegates are tested in order so earlier ones are preferred.
     */
    void addDelegateProgram(string name)
    {
        synchronized(mLock)
        {
            mDelegateNames.insert(name);
            
            // reset chosen delegate
            mChosenDelegate.setNull();
        }
    }
    
    /// Remove all delegate programs
    void clearDelegatePrograms()
    {
        synchronized(mLock)
        {
            mDelegateNames.clear();
            mChosenDelegate.setNull();
        }
    }

    /// Get the chosen delegate
    //const 
    ref SharedPtr!HighLevelGpuProgram _getDelegate() //const;
    {
        if (mChosenDelegate.isNull())
        {
            chooseDelegate();
        }
        return mChosenDelegate;
    }

    override size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        memSize += HighLevelGpuProgram.calculateSize();
        
        // Delegate Names
        foreach (i; mDelegateNames)
            memSize += i.length * char.sizeof;
        
        return memSize;
    }
    
    enum string sLanguage = "unified";
    /** @copydoc GpuProgram::getLanguage */
    override string getLanguage() //const;
    {
        return sLanguage;
    }

    /** Creates a new parameters object compatible with this program definition. 
     @remarks
     Unlike low-level assembly programs, parameters objects are specific to the
     program and therefore must be created from it rather than by the 
     HighLevelGpuProgramManager. This method creates a new instance of a parameters
     object containing the definition of the parameters this program understands.
     */
    override GpuProgramParametersPtr createParameters()
    {
        if (isSupported())
        {
            return _getDelegate().getAs().createParameters();
        }
        else
        {
            // return a default set
            GpuProgramParametersPtr params = cast(GpuProgramParametersPtr)
                GpuProgramManager.getSingleton().createParameters();
            // avoid any errors on parameter names that don't exist
            params.get().setIgnoreMissingParams(true);
            return params;
        }
    }

    /** @copydoc GpuProgram::_getBindingDelegate */
    override GpuProgram _getBindingDelegate()
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs()._getBindingDelegate();
        else
            return null;
    }
    
    // All the following methods must delegate to the implementation
    
    /** @copydoc GpuProgram::isSupported */
    override bool isSupported() //const;
    {
        // Supported if one of the delegates is
        return !(_getDelegate().isNull());
    }

    /** @copydoc GpuProgram::isSkeletalAnimationIncluded */
    override bool isSkeletalAnimationIncluded()// const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isSkeletalAnimationIncluded();
        else
            return false;
    }

    override bool isMorphAnimationIncluded() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isMorphAnimationIncluded();
        else
            return false;
    }
    
    override bool isPoseAnimationIncluded() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isPoseAnimationIncluded();
        else
            return false;
    }

    override bool isVertexTextureFetchRequired() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isVertexTextureFetchRequired();
        else
            return false;
    }

    override GpuProgramParametersPtr getDefaultParameters()
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().getDefaultParameters();
        else
            return GpuProgramParametersPtr();
    }

    override bool hasDefaultParameters()// const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().hasDefaultParameters();
        else
            return false;
    }

    override bool getPassSurfaceAndLightStates() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().getPassSurfaceAndLightStates();
        else
            return HighLevelGpuProgram.getPassSurfaceAndLightStates();
    }

    override bool getPassFogStates() //const
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().getPassFogStates();
        else
            return HighLevelGpuProgram.getPassFogStates();
    }

    override bool getPassTransformStates() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().getPassTransformStates();
        else
            return HighLevelGpuProgram.getPassTransformStates();
    }

    override bool hasCompileError() //const;
    {
        if (_getDelegate().isNull())
        {
            return false;
        }
        else
        {
            return _getDelegate().getAs().hasCompileError();
        }
    }

    override void resetCompileError()
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().resetCompileError();
    }
    
    override void load(bool backgroundThread = false)
    {
        if (!_getDelegate().isNull())
            _getDelegate().get().load(backgroundThread);
    }

    override void reload()
    {
        if (!_getDelegate().isNull())
            _getDelegate().get().reload();
    }

    override bool isReloadable() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().get().isReloadable();
        else
            return true;
    }

    override bool isLoaded() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isLoaded();
        else
            return false;
    }

    override bool isLoading() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isLoading();
        else
            return false;
    }

    override LoadingState getLoadingState() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().get().getLoadingState();
        else
            return Resource.LoadingState.UNLOADED;
    }

    override void unload()
    {
        if (!_getDelegate().isNull())
            _getDelegate().get().unload();
    }

    override size_t getSize() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().get().getSize();
        else
            return 0;
    }

    override void touch()
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().touch();
    }

    override bool isBackgroundLoaded() //const;
    {
        if (!_getDelegate().isNull())
            return _getDelegate().getAs().isBackgroundLoaded();
        else
            return false;
    }

    override void setBackgroundLoaded(bool bl)
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().setBackgroundLoaded(bl);
    }

    override void escalateLoading()
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().escalateLoading();
    }

    override void addListener(Listener lis)
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().addListener(lis);
    }

    override void removeListener(Listener lis)
    {
        if (!_getDelegate().isNull())
            _getDelegate().getAs().removeListener(lis);
    }
}

/** Factory class for Unified programs. */
class UnifiedHighLevelGpuProgramFactory : HighLevelGpuProgramFactory
{
public:
    this(){}
    ~this(){}

    static const string sLanguage = "unified";

    /// Get the name of the language this factory creates programs for
    string getLanguage() //const
    {
        return sLanguage;
    }

    override HighLevelGpuProgram create(ResourceManager creator, 
                                string name, ResourceHandle handle,
                                string group, bool isManual, ManualResourceLoader loader)
    {
        return new UnifiedHighLevelGpuProgram(creator, name, handle, group, isManual, loader);
    }

    override void destroyObj(HighLevelGpuProgram prog)
    {
        destroy(prog);
    }
    
}

/** @} */
/** @} */