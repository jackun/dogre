module ogre.effects.particlesystemmanager;

import core.sync.mutex;
//import std.container;
import std.string;

import ogre.compat;
import ogre.effects.billboardparticlerenderer;
import ogre.effects.particleaffector;
import ogre.effects.particleemitter;
import ogre.effects.particlesystem;
import ogre.effects.particlesystemrenderer;
import ogre.exception;
import ogre.general.common;
import ogre.general.generals : ScriptLoader;
import ogre.general.log;
import ogre.general.root;
import ogre.general.scriptcompiler;
import ogre.resources.datastream;
import ogre.resources.resourcegroupmanager;
import ogre.scene.movableobject;
import ogre.singleton;
import ogre.strings;


/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Manages particle systems, particle system scripts (templates) and the 
        available emitter & affector factories.
    @remarks
        This singleton class is responsible for creating and managing particle 
        systems. All particle systems must be created and destroyed using this 
        object, although the user interface to creating them is via
        SceneManager. Remember that like all other MovableObject
        subclasses, ParticleSystems do not get rendered until they are 
        attached to a SceneNode object.
    @par
        This class also manages factories for ParticleEmitter and 
        ParticleAffector classes. To enable easy extensions to the types of 
        emitters (particle sources) and affectors (particle modifiers), the
        ParticleSystemManager lets plugins or applications register factory 
        classes which submit new subclasses to ParticleEmitter and 
        ParticleAffector. Ogre comes with a number of them already provided,
        such as cone, sphere and box-shaped emitters, and simple affectors such
        as constant directional force and colour faders. However using this 
        registration process, a plugin can create any behaviour required.
    @par
        This class also manages the loading and parsing of particle system 
        scripts, which are text files describing named particle system 
        templates. Instances of particle systems using these templates can
        then be created easily through the createParticleSystem method.
    */
final class ParticleSystemManager: ScriptLoader//, public FXAlloc
{
    mixin Singleton!ParticleSystemManager;

    invariant()
    {
        assert(mLock !is null);
    }

    //friend class ParticleSystemFactory;
public:
    //typedef map<String, ref ParticleSystem>::type ParticleTemplateMap;
    //typedef map<String, ParticleAffectorFactory*>::type ParticleAffectorFactoryMap;
    //typedef map<String, ParticleEmitterFactory*>::type ParticleEmitterFactoryMap;
    //typedef map<String, ParticleSystemRendererFactory*>::type ParticleSystemRendererFactoryMap;

    alias ParticleSystem[string] ParticleTemplateMap;
    alias ParticleAffectorFactory[string] ParticleAffectorFactoryMap;
    alias ParticleEmitterFactory[string] ParticleEmitterFactoryMap;
    alias ParticleSystemRendererFactory[string] ParticleSystemRendererFactoryMap;
protected:

    // Shortcut to set up billboard particle renderer
    BillboardParticleRendererFactory mBillboardRendererFactory;

    //OGRE_AUTO_MUTEX
    Mutex mLock;
        
    /// Templates based on scripts
    ParticleTemplateMap mSystemTemplates;
    
    /// Factories for named emitter types (can be extended using plugins)
    ParticleEmitterFactoryMap mEmitterFactories;
    
    /// Factories for named affector types (can be extended using plugins)
    ParticleAffectorFactoryMap mAffectorFactories;
    
    /// Map of renderer types to factories
    ParticleSystemRendererFactoryMap mRendererFactories;
    
    StringVector mScriptPatterns;
    
    // Factory instance
    ParticleSystemFactory mFactory;
    
    /** Internal script parsing method. */
    void parseNewEmitter(string type, ref DataStream stream, ref ParticleSystem sys)
    {
        // Create new emitter
        ParticleEmitter pEmit = sys.addEmitter(type);
        // Parse emitter details
        string line;
        
        while(!stream.eof())
        {
            line = stream.getLine();
            // Ignore comments & blanks
            if (!(line.length == 0 || line[0..2] == "//"))
            {
                if (line == "}")
                {
                    // Finished emitter
                    break;
                }
                else
                {
                    // Attribute
                    //StringUtil::toLowerCase(line);
                    parseEmitterAttrib(line.toLower(), pEmit);
                }
            }
        }
    }
    /** Internal script parsing method. */
    void parseNewAffector(string type, ref DataStream stream, ref ParticleSystem sys)
    {
        // Create new affector
        ParticleAffector pAff = sys.addAffector(type);
        // Parse affector details
        string line;
        
        while(!stream.eof())
        {
            line = stream.getLine();
            // Ignore comments & blanks
            if (!(line.length == 0 || line[0..2] == "//"))
            {
                if (line == "}")
                {
                    // Finished affector
                    break;
                }
                else
                {
                    // Attribute
                    parseAffectorAttrib(line.toLower(), pAff);
                }
            }
        }
    }
    /** Internal script parsing method. */
    void parseAttrib(string line, ref ParticleSystem sys)
    {
        // Split params on space
        auto vecparams = StringUtil.split(line, "\t ", 1);
        
        // Look up first param (command setting)
        if (!sys.setParameter(vecparams[0], vecparams[1]))
        {
            // Attribute not supported by particle system, try the renderer
            ParticleSystemRenderer renderer = sys.getRenderer();
            if (renderer)
            {
                if (!renderer.setParameter(vecparams[0], vecparams[1]))
                {
                    LogManager.getSingleton().logMessage("Bad particle system attribute line: '"
                                                         ~ line ~ "' in " ~ sys.getName() ~ " (tried renderer)");
                }
            }
            else
            {
                // BAD command. BAD!
                LogManager.getSingleton().logMessage("Bad particle system attribute line: '"
                                                     ~ line ~ "' in " ~ sys.getName() ~ " (no renderer)");
            }
        }
    }
    /** Internal script parsing method. */
    void parseEmitterAttrib(string line, ref ParticleEmitter emit)
    {
        // Split params on first space
        auto vecparams = StringUtil.split(line, "\t ", 1);
        
        // Look up first param (command setting)
        if (!emit.setParameter(vecparams[0], vecparams[1]))
        {
            // BAD command. BAD!
            LogManager.getSingleton().logMessage("Bad particle emitter attribute line: '"
                                                  ~ line ~ "' for emitter " ~ emit.getType());
        }
    }
    /** Internal script parsing method. */
    void parseAffectorAttrib(string line, ref ParticleAffector aff)
    {
        // Split params on space
        auto vecparams = StringUtil.split(line, "\t ", 1);
        
        // Look up first param (command setting)
        if (!aff.setParameter(vecparams[0], vecparams[1]))
        {
            // BAD command. BAD!
            LogManager.getSingleton().logMessage("Bad particle affector attribute line: '"
                                                 ~ line ~ "' for affector " ~ aff.getType());
        }
    }
    /** Internal script parsing method. */
    void skipToNextCloseBrace(ref DataStream stream)
    {
        string line;
        while (!stream.eof() && line != "}")
        {
            line = stream.getLine();
        }
    }
    /** Internal script parsing method. */
    void skipToNextOpenBrace(ref DataStream stream)
    {
        string line;
        while (!stream.eof() && line != "{")
        {
            line = stream.getLine();
        }
        
    }
    
    /// Internal implementation of createSystem
    ParticleSystem createSystemImpl(string name, size_t quota, 
                                   string resourceGroup)
    {
        ParticleSystem sys = new ParticleSystem(name, resourceGroup);
        sys.setParticleQuota(quota);
        return sys;
    }
    /// Internal implementation of createSystem
    ParticleSystem createSystemImpl(string name,string templateName)
    {
        // Look up template
        ParticleSystem pTemplate = getTemplate(templateName);
        if (!pTemplate)
        {
            throw new InvalidParamsError("Cannot find required template '" ~ templateName ~ "'", "ParticleSystemManager.createSystem");
        }
        
        ParticleSystem sys = createSystemImpl(name, pTemplate.getParticleQuota(), 
                                              pTemplate.getResourceGroupName());
        //TODO Copy template settings
        // Copy template settings
        //*sys = *pTemplate;
        sys.copyFrom(pTemplate);
        return sys;
        
    }
    /// Internal implementation of destroySystem
    void destroySystemImpl(ParticleSystem sys)
    {
        destroy(sys);
    }
    
    
public:
    
    this()
    {
        synchronized(this.classinfo) //needed??
        {
            mLock = new Mutex;
            mFactory = new ParticleSystemFactory();
            Root.getSingleton().addMovableObjectFactory(mFactory);
        }
    }

    ~this()
    {
        synchronized(mLock)
        {
            // Destroy all templates
            foreach (k,v; mSystemTemplates)
            {
                destroy(v);
            }
            mSystemTemplates.clear();
            ResourceGroupManager.getSingleton()._unregisterScriptLoader(this);
            // delete billboard factory
            if (mBillboardRendererFactory)
            {
                destroy(mBillboardRendererFactory);
                mBillboardRendererFactory = null;
            }
            
            if (mFactory)
            {
                // delete particle system factory
                Root.getSingleton().removeMovableObjectFactory(mFactory);
                destroy(mFactory);
                mFactory = null;
            }
        }
    }
    
    /** Adds a new 'factory' object for emitters to the list of available emitter types.
        @remarks
            This method allows plugins etc to add new particle emitter types to Ogre. Particle emitters
            are sources of particles, and generate new particles with their start positions, colours and
            momentums appropriately. Plugins would create new subclasses of ParticleEmitter which 
            emit particles a certain way, and register a subclass of ParticleEmitterFactory to create them (since multiple 
            emitters can be created for different particle systems).
        @par
            All particle emitter factories have an assigned name which is used to identify the emitter
            type. This must be unique.
        @par
            Note that the object passed to this function will not be destroyed by the ParticleSystemManager,
            since it may have been allocated on a different heap in the case of plugins. The caller must
            destroy the object later on, probably on plugin shutdown.
        @param factory
            Pointer to a ParticleEmitterFactory subclass created by the plugin or application code.
        */
    void addEmitterFactory(ref ParticleEmitterFactory factory)
    {
        synchronized(mLock)
        {
            string name = factory.getName();
            mEmitterFactories[name] = factory;
            LogManager.getSingleton().logMessage("Particle Emitter Type '" ~ name ~ "' registered");
        }
    }
    
    /** Adds a new 'factory' object for affectors to the list of available affector types.
        @remarks
            This method allows plugins etc to add new particle affector types to Ogre. Particle
            affectors modify the particles in a system a certain way such as affecting their direction
            or changing their colour, lifespan etc. Plugins would
            create new subclasses of ParticleAffector which affect particles a certain way, and register
            a subclass of ParticleAffectorFactory to create them.
        @par
            All particle affector factories have an assigned name which is used to identify the affector
            type. This must be unique.
        @par
            Note that the object passed to this function will not be destroyed by the ParticleSystemManager,
            since it may have been allocated on a different heap in the case of plugins. The caller must
            destroy the object later on, probably on plugin shutdown.
        @param factory
            Pointer to a ParticleAffectorFactory subclass created by the plugin or application code.
        */
    void addAffectorFactory(ref ParticleAffectorFactory factory)
    {
        synchronized(mLock)
        {
            string name = factory.getName();
            mAffectorFactories[name] = factory;
            LogManager.getSingleton().logMessage("Particle Affector Type '" ~ name ~ "' registered");
        }
    }
    
    /** Registers a factory class for creating ParticleSystemRenderer instances. 
        @par
            Note that the object passed to this function will not be destroyed by the ParticleSystemManager,
            since it may have been allocated on a different heap in the case of plugins. The caller must
            destroy the object later on, probably on plugin shutdown.
        @param factory
            Pointer to a ParticleSystemRendererFactory subclass created by the plugin or application code.
        */
    void addRendererFactory(ParticleSystemRendererFactory factory)
    {
        synchronized(mLock)
        {
            string name = factory.getType();
            mRendererFactories[name] = factory;
            LogManager.getSingleton().logMessage("Particle Renderer Type '" ~ name ~ "' registered");
        }
    }
    
    /** Adds a new particle system template to the list of available templates. 
        @remarks
            Instances of particle systems in a scene are not normally unique - often you want to place the
            same effect in many places. This method allows you to register a ParticleSystem as a named template,
            which can subsequently be used to create instances using the createSystem method.
        @par
            Note that particle system templates can either be created programmatically by an application 
            and registered using this method, or they can be defined in a script file (*.particle) which is
            loaded by the engine at startup, very much like Material scripts.
        @param name
            The name of the template. Must be unique across all templates.
        @param sysTemplate
            A pointer to a particle system to be used as a template. The manager
            will take over ownership of this pointer.
            
        */
    void addTemplate(string name, ref ParticleSystem sysTemplate)
    {
        synchronized(mLock)
        {
            // check name
            if ((name in mSystemTemplates) !is null)
            {
                throw new DuplicateItemError(
                            "ParticleSystem template with name '" ~ name ~ "' already exists.", 
                            "ParticleSystemManager.addTemplate");
            }
            
            mSystemTemplates[name] = sysTemplate;
        }
    }
    
    /** Removes a specified template from the ParticleSystemManager.
        @remarks
            This method removes a given template from the particle system manager, optionally deleting
            the template if the deleteTemplate method is called.  Throws an exception if the template
            could not be found.
        @param name
            The name of the template to remove.
        @param deleteTemplate
            Whether or not to delete the template before removing it.
        */
    void removeTemplate(string name, bool deleteTemplate = true)
    {
        synchronized(mLock)
        {
            auto itr = name in mSystemTemplates;
            if (itr is null)
                throw new ItemNotFoundError(
                            "ParticleSystem template with name '" ~ name ~ "' cannot be found.",
                            "ParticleSystemManager.removeTemplate");
            
            if (deleteTemplate)
                destroy(*itr);
            
            mSystemTemplates.remove(name);
        }
    }
    
    /** Removes a specified template from the ParticleSystemManager.
        @remarks
            This method removes all templates from the ParticleSystemManager.
        @param deleteTemplate
            Whether or not to delete the templates before removing them.
        */
    void removeAllTemplates(bool deleteTemplate = true)
    {
        synchronized(mLock)
        {
            if (deleteTemplate)
            {
                foreach (k,v; mSystemTemplates)
                    destroy(v);
            }
            
            mSystemTemplates.clear();
        }
    }
    
    
    /** Removes all templates that belong to a secific Resource Group from the ParticleSystemManager.
        @remarks
            This method removes all templates that belong in a particular resource group from the ParticleSystemManager.
        @param resourceGroup
            Resource group to delete templates for
        */
    void removeTemplatesByResourceGroup(string resourceGroup)
    {
        synchronized(mLock)
        {
            foreach(k; mSystemTemplates.keys)
            {
                auto v = mSystemTemplates[k];
                if(v.getResourceGroupName() == resourceGroup)
                {
                    destroy(v);
                    mSystemTemplates.remove(k);
                }
            }
        }
    }
    
    /** Create a new particle system template. 
        @remarks
            This method is similar to the addTemplate method, except this just creates a new template
            and returns a pointer to it to be populated. Use this when you don't already have a system
            to add as a template and just want to create a new template which you will build up in-place.
        @param name
            The name of the template. Must be unique across all templates.
        @param resourceGroup
            The name of the resource group which will be used to 
            load any dependent resources.
            
        */
    ParticleSystem createTemplate(string name,string resourceGroup)
    {
        synchronized(mLock)
        {
            // check name
            if ((name in mSystemTemplates) !is null)
            {
                /*#if OGRE_PLATFORM == OGRE_PLATFORM_WINRT
                    LogManager::getSingleton().logMessage("ParticleSystem template with name '" ~ name ~ "' already exists.");
                        return NULL;
                #else*/
                throw new DuplicateItemError(
                            "ParticleSystem template with name '" ~ name ~ "' already exists.", 
                            "ParticleSystemManager.createTemplate");
                //#endif
            }
            
            ParticleSystem tpl = new ParticleSystem(name, resourceGroup);
            addTemplate(name, tpl);
            return tpl;
        }
    }
    
    /** Retrieves a particle system template for possible modification. 
        @remarks
            Modifying a template does not affect the settings on any ParticleSystems already created
            from this template.
        */
    ParticleSystem getTemplate(string name)
    {
        synchronized(mLock)
        {
            auto i = name in mSystemTemplates;
            if (i !is null)
            {
                return *i;
            }
            else
            {
                return null;
            }
        }
    }
    
    /** Internal method for creating a new emitter from a factory.
        @remarks
            Used internally by the engine to create new ParticleEmitter instances from named
            factories. Applications should use the ParticleSystem::addEmitter method instead, 
            which calls this method to create an instance.
        @param emitterType
            String name of the emitter type to be created. A factory of this type must have been registered.
        @param psys
            The particle system this is being created for
        */
    ParticleEmitter _createEmitter(string emitterType, ref ParticleSystem psys)
    {
        synchronized(mLock)
        {
            // Locate emitter type
            auto pFact = emitterType in mEmitterFactories;
            
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find requested emitter type: " ~ emitterType, 
                                             "ParticleSystemManager._createEmitter");
            }
            
            return pFact.createEmitter(psys);
        }
    }
    
    /** Internal method for destroying an emitter.
        @remarks
            Because emitters are created by factories which may allocate memory from separate heaps,
            the memory allocated must be freed from the same place. This method is used to ask the factory
            to destroy the instance passed in as a pointer.
        @param emitter
            Pointer to emitter to be destroyed. On return this pointer will point to invalid (freed) memory.
        */
    void _destroyEmitter(ref ParticleEmitter emitter)
    {
        synchronized(mLock)
        {
            // Destroy using the factory which created it
            auto pFact = emitter.getType() in mEmitterFactories;
            
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find emitter factory to destroy emitter.", 
                            "ParticleSystemManager._destroyEmitter");
            }
            
            pFact.destroyEmitter(emitter);
        }
    }
    
    /** Internal method for creating a new affector from a factory.
        @remarks
            Used internally by the engine to create new ParticleAffector instances from named
            factories. Applications should use the ParticleSystem::addAffector method instead, 
            which calls this method to create an instance.
        @param affectorType
            String name of the affector type to be created. A factory of this type must have been registered.
        @param psys
            The particle system it is being created for
        */
    ParticleAffector _createAffector(string affectorType, ref ParticleSystem psys)
    {
        synchronized(mLock)
        {
            // Locate affector type
            auto pFact = affectorType in mAffectorFactories;
            
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find requested affector type.", 
                            "ParticleSystemManager._createAffector");
            }
        
            return pFact.createAffector(psys);
        }
    }
    
    /** Internal method for destroying an affector.
        @remarks
            Because affectors are created by factories which may allocate memory from separate heaps,
            the memory allocated must be freed from the same place. This method is used to ask the factory
            to destroy the instance passed in as a pointer.
        @param affector
            Pointer to affector to be destroyed. On return this pointer will point to invalid (freed) memory.
        */
    void _destroyAffector(ref ParticleAffector affector)
    {
        synchronized(mLock)
        {
            // Destroy using the factory which created it
            auto pFact = affector.getType() in mAffectorFactories;
        
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find affector factory to destroy affector.", 
                            "ParticleSystemManager._destroyAffector");
            }
        
            pFact.destroyAffector(affector);
        }
    }
    
    /** Internal method for creating a new renderer from a factory.
        @remarks
            Used internally by the engine to create new ParticleSystemRenderer instances from named
            factories. Applications should use the ParticleSystem::setRenderer method instead, 
            which calls this method to create an instance.
        @param rendererType
            String name of the renderer type to be created. A factory of this type must have been registered.
        */
    ParticleSystemRenderer _createRenderer(string rendererType)
    {
        synchronized(mLock)
        {
            // Locate affector type
            auto pFact = rendererType in mRendererFactories;
        
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find requested renderer type.", 
                            "ParticleSystemManager._createRenderer");
            }
            
            return pFact.createInstance(rendererType);
        }
    }
    
    /** Internal method for destroying a renderer.
        @remarks
            Because renderer are created by factories which may allocate memory from separate heaps,
            the memory allocated must be freed from the same place. This method is used to ask the factory
            to destroy the instance passed in as a pointer.
        @param renderer
            Pointer to renderer to be destroyed. On return this pointer will point to invalid (freed) memory.
        */
    void _destroyRenderer(ref ParticleSystemRenderer renderer)
    {
        synchronized(mLock)
        {
            // Destroy using the factory which created it
            auto pFact = renderer.getType() in mRendererFactories;
        
            if (pFact is null)
            {
                throw new InvalidParamsError("Cannot find renderer factory to destroy renderer.", 
                            "ParticleSystemManager._destroyRenderer");
            }
        
            pFact.destroyInstance(renderer);
        }
    }
    
    
    /** Init method to be called by OGRE system.
        @remarks
            Due to dependencies between various objects certain initialisation tasks cannot be done
            on construction. OGRE will call this method when the rendering subsystem is initialised.
        */
    void _initialise()
    {
        synchronized(mLock)
        {
            // Create Billboard renderer factory
            mBillboardRendererFactory = new BillboardParticleRendererFactory();
            addRendererFactory(mBillboardRendererFactory);
        }
    }
    
    /// @copydoc ScriptLoader::getScriptPatterns
    ref StringVector getScriptPatterns()
    {
        return mScriptPatterns;
    }

    /// @copydoc ScriptLoader::parseScript
    void parseScript(DataStream stream,string groupName)
    {
        ScriptCompilerManager.getSingleton().parseScript(stream, groupName);
    }
    /// @copydoc ScriptLoader::getLoadingOrder
    Real getLoadingOrder()
    {
        /// Load late
        return 1000.0f;
    }
    
    //typedef MapIterator<ParticleAffectorFactoryMap> ParticleAffectorFactoryIterator;
    //typedef MapIterator<ParticleEmitterFactoryMap> ParticleEmitterFactoryIterator;
    //typedef MapIterator<ParticleSystemRendererFactoryMap> ParticleRendererFactoryIterator;

    /** Return an iterator over the affector factories currently registered */
    ref ParticleAffectorFactoryMap getAffectorFactories()
    {
        return mAffectorFactories;
    }

    /** Return an iterator over the emitter factories currently registered */
    ref ParticleEmitterFactoryMap getEmitterFactories()
    {
        return mEmitterFactories;
    }

    /** Return an iterator over the renderer factories currently registered */
    ref ParticleSystemRendererFactoryMap getRendererFactories()
    {
        return mRendererFactories;
    }
    
    //typedef MapIterator<ParticleTemplateMap> ParticleSystemTemplateIterator;
    /** Gets an iterator over the list of particle system templates. */
    ref ParticleTemplateMap getSystemTemplates()
    {
        return mSystemTemplates;
    }
    
    /** Get an instance of ParticleSystemFactory (internal use). */
    ref ParticleSystemFactory _getFactory() { return mFactory; }

}

/** Factory object for creating ParticleSystem instances */
class ParticleSystemFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params = null)
    {
        if (!params.emptyAA)
        {
            auto ni = "templateName" in params;
            if (ni !is null)
            {
                string templateName = *ni;
                // create using manager
                return ParticleSystemManager.getSingleton().createSystemImpl(
                    name, templateName);
            }
        }

        // Not template based, look for quota & resource name
        size_t quota = 500;
        string resourceGroup = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME;
        if (!params.emptyAA)
        {
            auto ni = "quota" in params;
            if (ni !is null)
            {
                quota = std.conv.to!uint(*ni);
            }
            ni = "resourceGroup" in params;
            if (ni !is null)
            {
                resourceGroup = *ni;
            }
        }
        // create using manager
        return ParticleSystemManager.getSingleton().createSystemImpl(
            name, quota, resourceGroup);
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "ParticleSystem";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }

    override void destroyInstance( ref MovableObject obj)
    {
        // use manager
        ParticleSystemManager.getSingleton().destroySystemImpl(cast(ParticleSystem)obj);
        
    }
    
}
/** @} */
/** @} */