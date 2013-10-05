module ogre.general.root;

import std.algorithm;
import std.stdio;
//import std.container;
import std.array;

import ogre.initstatics;
import ogre.animation.skeletonmanager;
import ogre.compat;
import ogre.config;
import ogre.effects.billboard;
import ogre.effects.billboardchain;
import ogre.effects.billboardset;
import ogre.effects.compositormanager;
import ogre.effects.particlesystemmanager;
import ogre.effects.ribbontrail;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.general.configdialog;
import ogre.general.configfile;
import ogre.general.controllermanager;
import ogre.general.dynlib;
import ogre.general.dynlibmanager;
import ogre.general.framelistener;
import ogre.general.generals;
import ogre.general.platform;
import ogre.general.plugin;
import ogre.general.profiler;
import ogre.general.scriptcompiler;
import ogre.general.timer;
import ogre.general.workqueue;
import ogre.lod.lodstrategymanager;
import ogre.materials.externaltexturesourcemanager;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.math.convexbody;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.renderwindow;
import ogre.rendersystem.windoweventutilities;
import ogre.resources.archive;
import ogre.resources.datastream;
import ogre.resources.highlevelgpuprogram;
import ogre.resources.meshmanager;
import ogre.resources.resourcebackgroundqueue;
import ogre.resources.resourcegroupmanager;
import ogre.resources.texturemanager;
import ogre.scene.entity;
import ogre.scene.light;
import ogre.scene.manualobject;
import ogre.scene.movableobject;
import ogre.scene.scenemanager;
import ogre.scene.shadowtexturemanager;
import ogre.scene.shadowvolumeextrudeprogram;
import ogre.singleton;
import ogre.strings;
import ogre.threading.defaultworkqueuestandard;
import ogre.general.log;
import ogre.image.freeimage;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */

//typedef vector<RenderSystem*>::type RenderSystemList;
alias RenderSystem[] RenderSystemList;

/** The root class of the Ogre system.
 @remarks
 The Ogre::Root class represents a starting point for the client
 application. From here, the application can gain access to the
 fundamentals of the system, namely the rendering systems
 available, management of saved configurations, logging, and
 access to other classes in the system. Acts as a hub from which
 all other objects may be reached. An instance of Root must be
 created before any other Ogre operations are called. Once an
 instance has been created, the same instance is accessible
 throughout the life of that object by using Root::getSingleton
 (as a reference) or Root::getSingletonPtr (as a pointer).
 */
final class Root //: public RootAlloc
{
    mixin Singleton!Root;

    // To allow update of active renderer if
    // RenderSystem::initialise is used directly
    //friend class RenderSystem;
protected:
    RenderSystemList mRenderers;
    __gshared RenderSystem mActiveRenderer;
    string mVersion;
    string mConfigFileName;
    bool mQueuedEnd;
    // In case multiple render windows are created, only once are the resources loaded.
    bool mFirstTimePostWindowInit;
    
    // Singletons
    LogManager          mLogManager;
    ControllerManager   mControllerManager;
    SceneManagerEnumerator mSceneManagerEnum;
    //typedef deque<SceneManager*>::type SceneManagerStack;
    //alias DList!SceneManager SceneManagerStack;
    alias SceneManager[] SceneManagerStack;

    SceneManagerStack   mSceneManagerStack;
    DynLibManager       mDynLibManager;
    ArchiveManager      mArchiveManager;
    MaterialManager     mMaterialManager;
    MeshManager         mMeshManager;
    ParticleSystemManager mParticleManager;
    SkeletonManager     mSkeletonManager;
    
    ArchiveFactory mZipArchiveFactory;
    ArchiveFactory mEmbeddedZipArchiveFactory;
    ArchiveFactory mFileSystemArchiveFactory;
    
    //#if OGRE_PLATFORM == OGRE_PLATFORM_ANDROID
    //    AndroidLogListener* mAndroidLogger;
    //#endif
    
    ResourceGroupManager    mResourceGroupManager;
    ResourceBackgroundQueue mResourceBackgroundQueue;
    ShadowTextureManager    mShadowTextureManager;
    RenderSystemCapabilitiesManager mRenderSystemCapabilitiesManager;
    ScriptCompilerManager   mCompilerManager;
    LodStrategyManager      mLodStrategyManager;
    PMWorker                mPMWorker;
    PMInjector              mPMInjector;
    
    Timer           mTimer;
    RenderWindow    mAutoWindow;
    Profiler        mProfiler;
    HighLevelGpuProgramManager      mHighLevelGpuProgramManager;
    ExternalTextureSourceManager    mExternalTextureSourceManager;
    CompositorManager               mCompositorManager;      
    ulong mNextFrame;
    Real mFrameSmoothingTime;
    bool mRemoveQueueStructuresOnClear;
    Real mDefaultMinPixelSize;
    
public:
    //TODO For now, i don't think D (as of 2.062) can do dynamic loading
    //typedef vector<DynLib*>::type PluginLibList;
    //typedef vector<Plugin*>::type PluginInstanceList;
    alias DynLib[] PluginLibList;
    alias Plugin[] PluginInstanceList;

protected:
    /// List of plugin DLLs loaded
    PluginLibList mPluginLibs;
    /// List of Plugin instances registered
    PluginInstanceList mPlugins;
    
    //typedef map<String, MovableObjectFactory*>::type MovableObjectFactoryMap;
    alias MovableObjectFactory[string] MovableObjectFactoryMap;
    MovableObjectFactoryMap mMovableObjectFactoryMap;
    uint mNextMovableObjectTypeFlag;
    // stock movable factories
    MovableObjectFactory mEntityFactory;
    MovableObjectFactory mLightFactory;
    MovableObjectFactory mBillboardSetFactory;
    MovableObjectFactory mManualObjectFactory;
    MovableObjectFactory mBillboardChainFactory;
    MovableObjectFactory mRibbonTrailFactory;
    
    //typedef map<String, RenderQueueInvocationSequence*>::type RenderQueueInvocationSequenceMap;
    alias RenderQueueInvocationSequence[string] RenderQueueInvocationSequenceMap;
    RenderQueueInvocationSequenceMap mRQSequenceMap;
    
    /// Are we initialised yet?
    bool mIsInitialised;
    
    WorkQueue mWorkQueue;
    
    ///Tells whether blend indices information needs to be passed to the GPU
    bool mIsBlendIndicesGpuRedundant;
    ///Tells whether blend weights information needs to be passed to the GPU
    bool mIsBlendWeightsGpuRedundant;
    
    /** Method reads a plugins configuration file and instantiates all
     plugins.
     @param
        pluginsfile The file that contains plugins information.
        Defaults to "plugins.cfg" in release and to "plugins_d.cfg"
        in debug build.
     */
    void loadPlugins(string pluginsfile = "plugins"~ OGRE_BUILD_SUFFIX ~".cfg" )
    {
        StringVector pluginList;
        string pluginDir;
        auto cfg = new ConfigFile;
        
        try {
            cfg.load( pluginsfile );
        }
        catch (Exception e)
        {
            LogManager.getSingleton().logMessage(pluginsfile ~ " not found, automatic plugin loading disabled.");
            return;
        }
        
        pluginDir = cfg.getSetting("PluginFolder"); // Ignored on Mac OS X, uses Resources/ directory
        pluginList = cfg.getMultiSetting("Plugin");
        
        if (pluginDir.length && pluginDir[$-1] != '/' && pluginDir[$-1] != '\\')
        {
            version(Windows) //|| OGRE_PLATFORM == OGRE_PLATFORM_WINRT
                pluginDir ~= "\\";
            else //version(Posix)
                pluginDir ~= "/";
        }
        
        foreach( it; pluginList[] )
        {
            loadPlugin(pluginDir ~ it);
        }
        
    }
    /** Initialise all loaded plugins - allows plugins to perform actions
     once the renderer is initialised.
     */
    void initialisePlugins()
    {
        foreach (i; mPlugins)
        {
            i.initialise();
        }
    }
    /** Shuts down all loaded plugins - allows things to be tidied up whilst
     all plugins are still loaded.
     */
    void shutdownPlugins()
    {
        // NB Shutdown plugins in reverse order to enforce dependencies
        foreach_reverse (i; mPlugins)
        {
            i.shutdown();
        }
    }
    
    /** Unloads all loaded plugins.
     */
    void unloadPlugins()
    {
        //#if OGRE_PLATFORM != OGRE_PLATFORM_NACL
        //TODO no dynamic loading yet, pretend we have
        // unload dynamic libs first
        foreach_reverse (i; mPluginLibs)
        {
            // Call plugin shutdown
            //DLL_STOP_PLUGIN pFunc = (cast(DLL_STOP_PLUGIN)i).getSymbol("dllStopPlugin");
            // this will call uninstallPlugin
            //pFunc();

            i.dllStopPlugin(); // Pretending
            // Unload library & destroy
            DynLibManager.getSingleton().unload(i);
            
        }
        mPluginLibs.clear();
        
        // now deal with any remaining plugins that were registered through other means
        foreach_reverse (i; mPlugins)
        {
            // Note this does NOT call uninstallPlugin - this shutdown is for the 
            // detail objects
            i.uninstall();
        }
        mPlugins.clear();
        //#endif
    }
    
    /// Internal method for one-time tasks after first window creation
    void oneTimePostWindowInit()
    {
        if (!mFirstTimePostWindowInit)
        {
            // Background loader
            mResourceBackgroundQueue.initialise();
            mWorkQueue.startup();
            // Initialise material manager
            mMaterialManager.initialise();
            // Init particle systems manager
            mParticleManager._initialise();
            // Init mesh manager
            MeshManager.getSingleton()._initialise();
            // Init plugins - after window creation so rsys resources available
            initialisePlugins();
            mFirstTimePostWindowInit = true;
        }
        
    }
    
    /** Set of registered frame listeners */
    //set<FrameListener*>::type mFrameListeners;
    FrameListener[] mFrameListeners;
    
    /** Set of frame listeners marked for removal*/
    //set<FrameListener*>::type mRemovedFrameListeners;
    FrameListener[] mRemovedFrameListeners;
    
    /** Indicates the type of event to be considered by calculateEventTime(). */
    enum FrameEventTimeType {
        FETT_ANY = 0, 
        FETT_STARTED = 1, 
        FETT_QUEUED = 2, 
        FETT_ENDED = 3, 
        FETT_COUNT = 4
    }
    
    /// Contains the times of recently fired events
    //typedef deque<ulong>::type EventTimesQueue;
    //alias SList!ulong EventTimesQueue;
    //alias ulong[] EventTimesQueue;
    alias ulong[] EventTimesQueue; //XXX C/C++ long changes size (thanks!) behaves actually ike D's size_t. Otherwise use c_ulong.
    EventTimesQueue[FrameEventTimeType.FETT_COUNT] mEventTimes;
    
    /** Internal method for calculating the average time between recently fired events.
     @param now The current time in ms.
     @param type The type of event to be considered.
     */
    //FIXME Like, everything. Seems to tick somewhat correctly for now
    Real calculateEventTime(ulong now, FrameEventTimeType type)
    {
        // Calculate the average time passed between events of the given type
        // during the last mFrameSmoothingTime seconds.        
        EventTimesQueue* times = &mEventTimes[type];
        (*times).insert(now);
        
        if(times.length == 1)
            return 0;
        
        // Times up to mFrameSmoothingTime seconds old should be kept
        ulong discardThreshold = cast(ulong)(mFrameSmoothingTime * 1000.0f);
        
        // Find the oldest time to keep
        size_t it;
        for(it = 0; it < (times.length-2); )
        {
            if (now - (*times)[it] > discardThreshold)
                ++it;
            else
                break;
        }
        
        // Remove old times
        (*times).removeFromArrayIdx(0, it);
        
        //FIXME times.length-1? or check that length > 1
        Real result = cast(Real)((*times).back - (*times).front) / ((times.length>1 ? times.length-1 : 1) * 1000);
        return result;
    }
    
    /** Update a set of event times (note, progressive, only call once for each type per frame) */
    void populateFrameEvent(FrameEventTimeType type, ref FrameEvent evtToUpdate)
    {
        ulong now = mTimer.getMilliseconds();
        evtToUpdate.timeSinceLastEvent = calculateEventTime(now, FrameEventTimeType.FETT_ANY);
        evtToUpdate.timeSinceLastFrame = calculateEventTime(now, type);
    }
    
public:
    
    /** Constructor
     @param pluginFileName The file that contains plugins information.
            Defaults to "plugins.cfg" in release build and to "plugins_d.cfg"
            in debug build. May be left blank to ignore.
     @param configFileName The file that contains the configuration to be loaded.
            Defaults to "ogre.cfg", may be left blank to load nothing.
     @param logFileName The logfile to create, defaults to Ogre.log, may be 
            left blank if you've already set up LogManager & Log yourself
     */
    this(string pluginFileName = "plugins"~ OGRE_BUILD_SUFFIX ~".cfg", 
         string configFileName = "ogre.cfg", 
         string logFileName = "Ogre.log")
    {
        InitStatics.staticThis();
        mQueuedEnd = false;
        mLogManager = null;
        mRenderSystemCapabilitiesManager = null;
        mNextFrame = 0;
        mFrameSmoothingTime = 0.0f;
        mRemoveQueueStructuresOnClear = false;
        mDefaultMinPixelSize = 0;
        mNextMovableObjectTypeFlag = 1;
        mIsInitialised = false;
        mIsBlendIndicesGpuRedundant = true;
        mIsBlendWeightsGpuRedundant = true;

        // superclass will do singleton checking
        
        // Init
        mActiveRenderer = null;
        mVersion = std.conv.text(OGRE_VERSION_MAJOR, ".", OGRE_VERSION_MINOR, ".",
                                 OGRE_VERSION_PATCH, OGRE_VERSION_SUFFIX, " (", OGRE_VERSION_NAME, ")");
        mConfigFileName = configFileName;
        
        // Create log manager and default log file if there is no log manager yet
        if(!LogManager.getSingletonPtr())
        {
            mLogManager = LogManager.getSingleton(); //new LogManager();
            mLogManager.createLog(logFileName, true, true);
        }
        
        //scope(exit) initSubSystems();//eh fail
    }
    
    // FIXME Ok, this is in Root ctor, but getSingleton() creates cyclic dependencies.
    // So call this after we have full Root instance.
    void initSubSystems()
    {
        //version(Android) {
        //    mAndroidLogger = new AndroidLogListener();
        //    mLogManager.getDefaultLog().addListener(mAndroidLogger);
        //}
        
        // Dynamic library manager
        mDynLibManager = DynLibManager.getSingleton();
        
        mArchiveManager = ArchiveManager.getSingleton();
        
        // ResourceGroupManager
        mResourceGroupManager = ResourceGroupManager.getSingleton();
        
        // WorkQueue (note: users can replace this if they want) (or not?)
        DefaultWorkQueue defaultQ = new DefaultWorkQueue("Root");
        // never process responses in main thread for longer than 10ms by default
        defaultQ.setResponseProcessingTimeLimit(10);
        // match threads to hardware
        static if(OGRE_THREAD_SUPPORT)
        {
            uint threadCount = OGRE_THREAD_HARDWARE_CONCURRENCY;
            if (!threadCount)
                threadCount = 1;
            defaultQ.setWorkerThreadCount(threadCount);
        }
        // only allow workers to access rendersystem if threadsupport is 1
        static if(OGRE_THREAD_SUPPORT == 1)
            defaultQ.setWorkersCanAccessRenderSystem(true);
        else
            defaultQ.setWorkersCanAccessRenderSystem(false);

        mWorkQueue = defaultQ;
        
        // ResourceBackgroundQueue
        mResourceBackgroundQueue = new ResourceBackgroundQueue();

        //NOTE: Most of these are final classes. If still using that Singleton implementation then
        // if for some reason you want to make a derived class, 'unfinalize' it and
        // use .getSingletonInit!DerivedClass somewhere before creating Root.

        // Create SceneManager enumerator (note - will be managed by singleton)
        mSceneManagerEnum = SceneManagerEnumerator.getSingleton();
        
        mShadowTextureManager = ShadowTextureManager.getSingleton();
        
        mRenderSystemCapabilitiesManager = RenderSystemCapabilitiesManager.getSingleton();
        
        // ..material manager
        mMaterialManager = MaterialManager.getSingleton();
        
        // Mesh manager
        mMeshManager = MeshManager.getSingleton();
        
        // Skeleton manager
        mSkeletonManager = SkeletonManager.getSingleton();
        
        // ..particle system manager
        mParticleManager = ParticleSystemManager.getSingleton();
        
        // Compiler manager
        mCompilerManager = ScriptCompilerManager.getSingleton();
        
        mTimer = new Timer();
        
        // Lod strategy manager
        mLodStrategyManager = LodStrategyManager.getSingleton();
        
        // Queued Progressive Mesh Generator Worker
        mPMWorker = new PMWorker();
        
        // Queued Progressive Mesh Generator Injector
        mPMInjector = new PMInjector();
        
        static if(OGRE_PROFILING)
        {
            // Profiler
            mProfiler = Profiler.getSingleton();
            Profiler.getSingleton().setTimer(mTimer);
        }
        
        
        mFileSystemArchiveFactory = new FileSystemArchiveFactory();
        ArchiveManager.getSingleton().addArchiveFactory( mFileSystemArchiveFactory );
        static if(OGRE_ZIP_ARCHIVE)
        {
            mZipArchiveFactory = new ZipArchiveFactory();
            ArchiveManager.getSingleton().addArchiveFactory( mZipArchiveFactory );
            mEmbeddedZipArchiveFactory = new EmbeddedZipArchiveFactory();
            ArchiveManager.getSingleton().addArchiveFactory( mEmbeddedZipArchiveFactory );
        }

        // Register image codecs
        static if(OGRE_DDS_CODEC) 
            DDSCodec.startup();

        // Register image codecs
        static if(OGRE_FREEIMAGE)
            FreeImageCodec.startup();

        static if(OGRE_PVRTC_CODEC)
            PVRTCCodec.startup();

        static if(OGRE_ETC1_CODEC)
            ETC1Codec.startup();
        
        
        mHighLevelGpuProgramManager = HighLevelGpuProgramManager.getSingleton();
        
        mExternalTextureSourceManager = ExternalTextureSourceManager.getSingleton();
        mCompositorManager = CompositorManager.getSingleton();
                
        // Auto window
        mAutoWindow = null;
        
        // instantiate and register base movable factories
        mEntityFactory = new EntityFactory();
        addMovableObjectFactory(mEntityFactory);
        mLightFactory = new LightFactory();
        addMovableObjectFactory(mLightFactory);
        mBillboardSetFactory = new BillboardSetFactory();
        addMovableObjectFactory(mBillboardSetFactory);
        mManualObjectFactory = new ManualObjectFactory();
        addMovableObjectFactory(mManualObjectFactory);
        mBillboardChainFactory = new BillboardChainFactory();
        addMovableObjectFactory(mBillboardChainFactory);
        mRibbonTrailFactory = new RibbonTrailFactory();
        addMovableObjectFactory(mRibbonTrailFactory);

        version(D_NOW_HAS_DYNAMIC_LOADING)
        {
            // Load plugins
            if (pluginFileName !is null && pluginFileName.length)
                loadPlugins(pluginFileName);
        }

        LogManager.getSingleton().logMessage("*-*-* OGRE Initialising");
        string msg = "*-*-* Version " ~ mVersion;
        LogManager.getSingleton().logMessage(msg);
        
        // Can't create managers until initialised
        mControllerManager = null;
        
        mFirstTimePostWindowInit = false;
        
    }

    ~this()
    {
        if(mIsInitialised) shutdown();
        else
            return;
        stderr.writeln("********Root dtor*********");
        destroy (mSceneManagerEnum);
        destroy (mShadowTextureManager);
        destroy (mRenderSystemCapabilitiesManager);
        
        destroyAllRenderQueueInvocationSequences();
        destroy (mCompositorManager);
        destroy (mExternalTextureSourceManager);

        static if(OGRE_FREEIMAGE)
            FreeImageCodec.shutdown();
        static if(OGRE_DDS_CODEC)
            DDSCodec.shutdown();
        static if(OGRE_PVRTC_CODEC)
            PVRTCCodec.shutdown();
        static if(OGRE_ETC1_CODEC)
            ETC1Codec.shutdown();

        static if(OGRE_PROFILING)
            destroy (mProfiler);

        //FIXME fix dtors. Meshes crash in dtor
        //destroy (mLodStrategyManager);
        destroy (mPMWorker);
        destroy (mPMInjector);
        
        destroy (mArchiveManager);
        
        static if(OGRE_ZIP_ARCHIVE)
        {
            destroy (mZipArchiveFactory);
            destroy (mEmbeddedZipArchiveFactory);
        }
        destroy (mFileSystemArchiveFactory);
        
        destroy (mSkeletonManager);
        destroy (mMeshManager);
        destroy (mParticleManager);
        
        if( mControllerManager !is null)
            destroy (mControllerManager);
        if (mHighLevelGpuProgramManager !is null)
            destroy (mHighLevelGpuProgramManager);
        
        unloadPlugins();
        destroy (mMaterialManager);
        Pass.processPendingPassUpdates(); // make sure passes are cleaned
        destroy (mResourceBackgroundQueue);
        destroy (mResourceGroupManager);
        
        destroy (mEntityFactory);
        destroy (mLightFactory);
        destroy (mBillboardSetFactory);
        destroy (mManualObjectFactory);
        destroy (mBillboardChainFactory);
        destroy (mRibbonTrailFactory);
        
        destroy (mWorkQueue);
        
        destroy (mTimer);
        
        destroy (mDynLibManager);
        
        //version(Android)
        //{
        //    mLogManager.getDefaultLog().removeListener(mAndroidLogger);
        //    destroy (mAndroidLogger);
        //}
        
        destroy (mLogManager);
        
        destroy (mCompilerManager);
        
        mAutoWindow = null;
        mFirstTimePostWindowInit = false;
        
        
        StringInterface.Dict.cleanupDictionary ();
    }
    
    /** Saves the details of the current configuration
     @remarks
     Stores details of the current configuration so it may be
     restored later on.
     */
    void saveConfig()
    {
        //#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
        //    OGRE_EXCEPT(Exception::ERR_CANNOT_WRITE_TO_FILE, "saveConfig is not supported on NaCl",
        //            "Root::saveConfig");
        //#endif

        //FIXME IOS stuff
        //#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
        //    // Check the Documents directory within the application sandbox
        //    Ogre::String outBaseName, extension, configFileName;
        //    Ogre::StringUtil::splitFilename(mConfigFileName, outBaseName, extension);
        //    configFileName = macBundlePath() + "/../Documents/" + outBaseName;
        //    std::ofstream of(configFileName.c_str());
        //    if (of.is_open())
        //        mConfigFileName = configFileName;
        //    else
        //        mConfigFileName.clear();
        //#else
        if (mConfigFileName is null || !mConfigFileName.length)
            return;
        
        //std::ofstream of(mConfigFileName.c_str());
        auto of = File(mConfigFileName, "w");
        //#endif

        if (!of.isOpen())
            throw new CannotWriteToFileError("Cannot create settings file.",
                                             "Root.saveConfig");
        
        if (mActiveRenderer)
        {
            of.writeln("Render System=", mActiveRenderer.getName());
        }
        else
        {
            of.writeln("Render System=");
        }
        
        foreach (rs; getAvailableRenderers())
        {
            of.writeln("");
            of.writeln("[", rs.getName(), "]");
            ConfigOptionMap opts = rs.getConfigOptions();
            foreach (k,v; opts)
            {
                of.writeln(k, "=", v.currentValue);
            }
        }
        
        of.close();
        
    }
    
    /** Checks for saved video/sound/etc settings
     @remarks
     This method checks to see if there is a valid saved configuration
     from a previous run. If there is, the state of the system will
     be restored to that configuration.

     @return
     If a valid configuration was found, <b>true</b> is returned.
     @par
     If there is no saved configuration, or if the system failed
     with the last config settings, <b>false</b> is returned.
     */
    bool restoreConfig()
    {
        //#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
        //    OGRE_EXCEPT(Exception::ERR_CANNOT_WRITE_TO_FILE, "restoreConfig is not supported on NaCl",
        //                "Root::restoreConfig");
        //#endif

        //TODO IOS stuff
        /*#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
         // Read the config from Documents first(user config) if it exists on iOS.
         // If it doesn't exist or is invalid then use mConfigFileName
         
         Ogre::String outBaseName, extension, configFileName;
         Ogre::StringUtil::splitFilename(mConfigFileName, outBaseName, extension);
         configFileName = macBundlePath() + "/../Documents/" + outBaseName;
         
         std::ifstream fp;
         fp.open(configFileName.c_str(), std::ios::in);
         if(fp.is_open())
         {
         // A config file exists in the users Documents dir, we'll use it
         mConfigFileName = configFileName;
         }
         else
         {
         std::ifstream configFp;
         
         // This might be the first run because there is no config file in the
         // Documents directory.  It could also mean that a config file isn't being used at all
         
         // Try the path passed into initialise
         configFp.open(mConfigFileName.c_str(), std::ios::in);
         
         // If we can't open this file then we have no default config file to work with
         // Use the documents dir then. 
         if(!configFp.is_open())
         {
         // Check to see if one was included in the app bundle
         mConfigFileName = macBundlePath() + "/ogre.cfg";
         
         configFp.open(mConfigFileName.c_str(), std::ios::in);
         
         // If we can't open this file then we have no default config file to work with
         // Use the Documents dir then. 
         if(!configFp.is_open())
         mConfigFileName = configFileName;
         }
         
         configFp.close();
         }
         
         fp.close();
         #endif*/
        
        if (mConfigFileName is null || !mConfigFileName.length)
            return true;
        
        // Restores configuration from saved state
        // Returns true if a valid saved configuration is
        //   available, and false if no saved config is
        //   stored, or if there has been a problem
        auto cfg = new ConfigFile;
        
        try {
            // Don't trim whitespace
            cfg.load(mConfigFileName, "\t:=", false);
        }
        catch (FileNotFoundError e)
        {
            std.stdio.stderr.writeln(e.msg);
            return false;
        }
        
        debug std.stdio.writeln("Settings:");
        ConfigFile.SettingsBySection iSection = cfg.getSections();
        foreach ( renderSystem, settings; iSection)
        {
            debug std.stdio.writeln(renderSystem," : ", settings);
            //string renderSystem = iSection.peekNextKey();
            //ConfigFile.SettingsMultiMap settings = *iSection.getNext();
            
            RenderSystem rs = getRenderSystemByName(renderSystem);
            if (!rs)
            {
                // Unrecognised render system
                continue;
            }

            // MultiMap foreach iterates over all values for a given key
            // so only last read setting is effective.
            foreach (k,v; settings)
            {
                debug std.stdio.writeln(k,"=", v);
                rs.setConfigOption(k, v[$-1]);
            }
        }
        
        debug std.stdio.writeln("RenderSystem: ", cfg.getSetting("Render System"));
        RenderSystem rs = getRenderSystemByName(cfg.getSetting("Render System"));
        if (!rs)
        {
            // Unrecognised render system
            return false;
        }
        
        string err = rs.validateConfigOptions();
        if (err.length > 0)
            return false;
        
        setRenderSystem(rs);
        
        // Successful load
        return true;
        
    }
    
    /** Displays a dialog asking the user to choose system settings.
     @remarks
     This method displays the default dialog allowing the user to
     choose the rendering system, video mode etc. If there is are
     any settings saved already, they will be restored automatically
     before displaying the dialogue. When the user accepts a group of
     settings, this will automatically call Root::setRenderSystem,
     RenderSystem::setConfigOption and Root::saveConfig with the
     user's choices. This is the easiest way to get the system
     configured.
     @return
     If the user clicked 'Ok', <b>true</b> is returned.
     @par
     If they clicked 'Cancel' (in which case the app should
     strongly consider terminating), <b>false</b> is returned.
     */
    bool showConfigDialog()
    {
        //#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
        //OGRE_EXCEPT(Exception::ERR_CANNOT_WRITE_TO_FILE, "showConfigDialog is not supported on NaCl",
        //            "Root::showConfigDialog");
        //#endif
        
        // Displays the standard config dialog
        // Will use stored defaults if available
        auto dlg = new ConfigDialog;
        bool isOk;
        
        restoreConfig();
        
        dlg = new ConfigDialog;
        isOk = dlg.display();
        if (isOk)
            saveConfig();
        
        destroy(dlg);
        return isOk;
    }
    
    /** Adds a new rendering subsystem to the list of available renderers.
     @remarks
     Intended for use by advanced users and plugin writers only!
     Calling this method with a pointer to a valid RenderSystem
     (subclass) adds a rendering API implementation to the list of
     available ones. Typical examples would be an OpenGL
     implementation and a Direct3D implementation.
     @note
     <br>This should usually be called from the dllStartPlugin()
     function of an extension plug-in.
     */
    void addRenderSystem(RenderSystem newRend)
    {
        mRenderers ~= newRend;
    }
    
    /** Retrieve a list of the available render systems.
     @remarks
     Retrieves a pointer to the list of available renderers as a
     list of RenderSystem subclasses. Can be used to build a
     custom settings dialog.
     */
    RenderSystemList getAvailableRenderers()
    {
        // Returns a vector of renders
        return mRenderers;
    }
    
    /** Retrieve a pointer to the render system by the given name
     @param
     name Name of the render system intend to retrieve.
     @return
     A pointer to the render system, <b>NULL</b> if no found.
     */
    RenderSystem getRenderSystemByName(string name)
    {
        if (name is null)
        {
            // No render system
            return null;
        }

        foreach (ref rs; getAvailableRenderers())
        {
            if (rs.getName() == name)
                return rs;
        }
        
        // Unrecognised render system
        return null;
    }
    
    /** Sets the rendering subsystem to be used.
     @remarks
     This method indicates to OGRE which rendering system is to be
     used (e.g. Direct3D, OpenGL etc). This is called
     automatically by the default config dialog, and when settings
     are restored from a previous configuraion. If used manually
     it could be used to set the renderer from a custom settings
     dialog. Once this has been done, the renderer can be
     initialised using Root::initialise.
     @par
     This method is also called by render systems if they are
     initialised directly.
     @param
     system Pointer to the render system to use.
     @see
     RenderSystem
     */
    void setRenderSystem(RenderSystem system)
    {
        // Sets the active rendering system
        // Can be called direct or will be called by
        //   standard config dialog
        
        // Is there already an active renderer?
        // If so, disable it and init the new one
        if( mActiveRenderer && mActiveRenderer != system )
        {
            mActiveRenderer.shutdown();
        }
        debug std.stdio.writeln("Set renderer: ", system);
        mActiveRenderer = system;
        // Tell scene managers
        SceneManagerEnumerator.getSingleton().setRenderSystem(system);
    }
    
    /** Retrieve a pointer to the currently selected render system.
     */
    RenderSystem getRenderSystem()
    {
        // Gets the currently active renderer
        return mActiveRenderer;
    }
    
    /** Initialises the renderer.
     @remarks
     This method can only be called after a renderer has been
     selected with Root::setRenderSystem, and it will initialise
     the selected rendering system ready for use.
     @param
     autoCreateWindow If true, a rendering window will
     automatically be created (saving a call to
     Root::createRenderWindow). The window will be
     created based on the options currently set on the render
     system.
     @return
     A pointer to the automatically created window, if
     requested, otherwise <b>NULL</b>.
     */
    RenderWindow initialise(bool autoCreateWindow,string windowTitle = "OGRE Render Window",
                           string customCapabilitiesConfig = null)
    {
        if (!mActiveRenderer)
            throw new InvalidStateError(
                "Cannot initialise - no render " ~
                "system has been selected.", "Root.initialise");
        
        if (!mControllerManager)
            mControllerManager = ControllerManager.getSingleton();
        
        // .rendercaps manager
        RenderSystemCapabilitiesManager rscManager = RenderSystemCapabilitiesManager.getSingleton();
        // caller wants to load custom RenderSystemCapabilities form a config file
        if(customCapabilitiesConfig !is null)
        {
            auto cfg = new ConfigFile;
            cfg.load(customCapabilitiesConfig, "\t:=", false);
            
            // Capabilities Database setting must be in the same format as
            // resources.cfg in Ogre examples.
            foreach(archType, filenames; cfg.getSettings("Capabilities Database"))
            {                
                foreach(filename; filenames)
                    rscManager.parseCapabilitiesFromArchive(filename, archType, true);
            }
            
            string capsName = cfg.getSetting("Custom Capabilities");
            // The custom capabilities have been parsed, let's retrieve them
            RenderSystemCapabilities rsc = rscManager.loadParsedCapabilities(capsName);
            if(!rsc)
            {
                throw new ItemNotFoundError(
                    "Cannot load a RenderSystemCapability named " ~ capsName,
                    "Root.initialise");
            }
            
            // Tell RenderSystem to use the comon rsc
            useCustomRenderSystemCapabilities(rsc);
        }
        
        
        PlatformInformation.log(LogManager.getSingleton().getDefaultLog());
        mAutoWindow =  mActiveRenderer._initialise(autoCreateWindow, windowTitle);
        
        
        if (autoCreateWindow && !mFirstTimePostWindowInit)
        {
            oneTimePostWindowInit();
            mAutoWindow._setPrimary();
        }
        
        // Initialise timer
        mTimer.reset();
        
        // Init pools
        ConvexBody._initialisePool();
        
        mIsInitialised = true;
        
        return mAutoWindow;
        
    }
    
    /** Returns whether the system is initialised or not. */
    bool isInitialised(){ return mIsInitialised; }
    
    /** Requests active RenderSystem to use custom RenderSystemCapabilities
     @remarks
     This is useful for testing how the RenderSystem would behave on a machine with
     less advanced GPUs. This method MUST be called before creating the first RenderWindow
     */
    void useCustomRenderSystemCapabilities(RenderSystemCapabilities capabilities)
    {
        mActiveRenderer.useCustomRenderSystemCapabilities(capabilities);
    }
    
    /** Get whether the entire render queue structure should be emptied on clearing, 
     or whether just the objects themselves should be cleared.
     */
    bool getRemoveRenderQueueStructuresOnClear(){ return mRemoveQueueStructuresOnClear; }
    
    /** Set whether the entire render queue structure should be emptied on clearing, 
     or whether just the objects themselves should be cleared.
     */
    void setRemoveRenderQueueStructuresOnClear(bool r) { mRemoveQueueStructuresOnClear = r; }
    
    /** Register a new SceneManagerFactory, a factory object for creating instances
     of specific SceneManagers. 
     @remarks
     Plugins should call this to register as new SceneManager providers.
     */
    void addSceneManagerFactory(SceneManagerFactory fact)
    {
        mSceneManagerEnum.addFactory(fact);
    }
    
    /** Unregister a SceneManagerFactory.
     */
    void removeSceneManagerFactory(SceneManagerFactory fact)
    {
        mSceneManagerEnum.removeFactory(fact);
    }
    
    /** Get more information about a given type of SceneManager.
     @remarks
     The metadata returned tells you a few things about a given type 
     of SceneManager, which can be created using a factory that has been
     registered already. 
     @param typeName The type name of the SceneManager you want to enquire on.
     If you don't know the typeName already, you can iterate over the 
     metadata for all types using getMetaDataIterator.
     */
    SceneManagerMetaData getSceneManagerMetaData(string typeName)
    {
        return mSceneManagerEnum.getMetaData(typeName);
    }
    
    /** Iterate over all types of SceneManager available for construction, 
     providing some information about each one.
     */
    SceneManagerEnumerator.MetaDataList getSceneManagerMetaDataList()
    {
        return mSceneManagerEnum.getMetaDataList();
    }
    
    /** Create a SceneManager instance of a given type.
     @remarks
     You can use this method to create a SceneManager instance of a 
     given specific type. You may know this type already, or you may
     have discovered it by looking at the results from getMetaDataIterator.
     @note
     This method throws an exception if the named type is not found.
     @param typeName string identifying a unique SceneManager type
     @param instanceName Optional name to given the new instance that is
     created. If you leave this blank, an auto name will be assigned.
     */
    SceneManager createSceneManager(string typeName, 
                                   string instanceName = null)
    {
        return mSceneManagerEnum.createSceneManager(typeName, instanceName);
    }
    
    /** Create a SceneManager instance based on scene type support.
     @remarks
     Creates an instance of a SceneManager which supports the scene types
     identified in the parameter. If more than one type of SceneManager 
     has been registered as handling that combination of scene types, 
     in instance of the last one registered is returned.
     @note This method always succeeds, if a specific scene manager is not
     found, the default implementation is always returned.
     @param typeMask A mask containing one or more SceneType flags
     @param instanceName Optional name to given the new instance that is
     created. If you leave this blank, an auto name will be assigned.
     */
    SceneManager createSceneManager(SceneTypeMask typeMask, 
                                   string instanceName = null)
    {
        return mSceneManagerEnum.createSceneManager(typeMask, instanceName);
    }
    
    /** Destroy an instance of a SceneManager. */
    void destroySceneManager(SceneManager sm)
    {
        mSceneManagerEnum.destroySceneManager(sm);
    }
    
    /** Get an existing SceneManager instance that has already been created,
     identified by the instance name.
     @param instanceName The name of the instance to retrieve.
     */
    SceneManager getSceneManager(string instanceName)
    {
        return mSceneManagerEnum.getSceneManager(instanceName);
    }
    
    /** Determines if a given SceneManager already exists
     @param instanceName The name of the instance to retrieve.
     */
    bool hasSceneManager(string instanceName)
    {
        return mSceneManagerEnum.hasSceneManager(instanceName);
    }

    /** Get an iterator over all the existing SceneManager instances. */
    SceneManagerEnumerator.Instances getSceneManagers()
    {
        return mSceneManagerEnum.getSceneManagers();
    }

    /** Retrieves a reference to the current TextureManager.
     @remarks
     This performs the same function as
     TextureManager::getSingleton, but is provided for convenience
     particularly to scripting engines.
     @par
     Note that a TextureManager will NOT be available until the
     Ogre system has been initialised by selecting a RenderSystem,
     calling Root::initialise and a window having been created
     (this may have been done by initialise if required). This is
     because the exact runtime subclass which will be implementing
     the calls will differ depending on the rendering engine
     selected, and these typically require a window upon which to
     base texture format decisions.
     */
    TextureManager getTextureManager()
    {
        return TextureManager.getSingleton();
    }
    
    /** Retrieves a reference to the current MeshManager.
     @remarks
     This performs the same function as MeshManager::getSingleton
     and is provided for convenience to scripting engines.
     */
    MeshManager getMeshManager()
    {
        return MeshManager.getSingleton();
    }
    
    /** Utility function for getting a better description of an error
     code.
     */
    string getErrorDescription(long errorNumber)
    {
        // Pass to render system
        if (mActiveRenderer)
            return mActiveRenderer.getErrorDescription(errorNumber);
        else
            return "";
    }
    
    /** Registers a FrameListener which will be called back every frame.
     @remarks
     A FrameListener is a class which implements methods which
     will be called every frame.
     @par
     See the FrameListener class for more details on the specifics
     It is imperitive that the instance passed to this method is
     not destroyed before either the rendering loop ends, or the
     class is removed from the listening list using
     removeFrameListener.
     @note
     <br>This method can only be called after Root::initialise has
     been called.
     @see
     FrameListener, Root::removeFrameListener
     */
    void addFrameListener(FrameListener newListener)
    {
        // Check if the specified listener is scheduled for removal
        auto i = mRemovedFrameListeners.find(newListener);
        
        // If yes, cancel the removal. Otherwise add it to other listeners.
        if (!i.empty)
            mRemovedFrameListeners.removeFromArray(i[0]);
        else if(!mFrameListeners.inArray(newListener))
            mFrameListeners.insert(newListener); // Insert, unique only (set)
    }
    
    /** Removes a FrameListener from the list of listening classes.
     @see
     FrameListener, Root::addFrameListener
     */
    void removeFrameListener(FrameListener oldListener)
    {
        // Remove, 1 only (set), and only when this listener was added before.
        if( !mFrameListeners.find( oldListener ).empty )
            mRemovedFrameListeners.insert(oldListener);
    }
    
    /** Queues the end of rendering.
     @remarks
     This method will do nothing unless startRendering() has
     been called, in which case before the next frame is rendered
     the rendering loop will bail out.
     @see
     Root, Root::startRendering
     */
    void queueEndRendering(bool state = true)
    {
        mQueuedEnd = state;
    }
    
    /** Check for planned end of rendering.
     @remarks
     This method return true if queueEndRendering() was called before.
     @see
     Root, Root::queueEndRendering, Root::startRendering
     */
    bool endRenderingQueued()
    {
        return mQueuedEnd;
    }
    
    /** Starts / restarts the automatic rendering cycle.
     @remarks
     This method begins the automatic rendering of the scene. It
     will <b>NOT</b> return until the rendering cycle is halted.
     @par
     During rendering, any FrameListener classes registered using
     addFrameListener will be called back for each frame that is
     to be rendered, These classes can tell OGRE to halt the
     rendering if required, which will cause this method to
     return.
     @note
     <br>Users of the OGRE library do not have to use this
     automatic rendering loop. It is there as a convenience and is
     most useful for high frame rate applications e.g. games. For
     applications that don't need toantly refresh the
     rendering targets (e.g. an editor utility), it is better to
     manually refresh each render target only when required by
     calling RenderTarget::update, or if you want to run your own
     render loop you can update all targets on demand using
     Root::renderOneFrame.
     @note
     This frees up the CPU to do other things in between
     refreshes, since in this case frame rate is less important.
     @note
     This method can only be called after Root::initialise has
     been called.
     */
    void startRendering()
    {
        assert(mActiveRenderer !is null);
        
        mActiveRenderer._initRenderTargets();
        
        // Clear event times
        clearEventTimes();
        
        // Infinite loop, until broken out of by frame listeners
        // or break out by calling queueEndRendering()
        mQueuedEnd = false;
        
        while( !mQueuedEnd )
        {
            //Pump messages in all registered RenderWindow windows
            WindowEventUtilities.messagePump();
            
            if (!renderOneFrame())
                break;
        }
    }
    
    /** Render one frame. 
     @remarks
     Updates all the render targets automatically and then returns,
     raising frame events before and after.
     */
    bool renderOneFrame()
    {
        if(!_fireFrameStarted())
            return false;
        
        if (!_updateAllRenderTargets())
            return false;
        
        return _fireFrameEnded();
    }
    
    /** Render one frame, with custom frame time information. 
     @remarks
     Updates all the render targets automatically and then returns,
     raising frame events before and after - all per-frame times are based on
     the time value you pass in.
     */
    bool renderOneFrame(Real timeSinceLastFrame)
    {
        FrameEvent evt;
        evt.timeSinceLastFrame = timeSinceLastFrame;
        
        ulong now = mTimer.getMilliseconds();
        evt.timeSinceLastEvent = calculateEventTime(now, FrameEventTimeType.FETT_ANY);
        
        if(!_fireFrameStarted(evt))
            return false;
        
        if (!_updateAllRenderTargets(evt))
            return false;
        
        now = mTimer.getMilliseconds();
        evt.timeSinceLastEvent = calculateEventTime(now, FrameEventTimeType.FETT_ANY);
        
        return _fireFrameEnded(evt);
    }
    
    /** Shuts down the system manually.
     @remarks
     This is normally done by Ogre automatically so don't think
     you have to call this yourself. However this is here for
     convenience, especially for dealing with unexpected errors or
     for systems which need to shut down Ogre on demand.
     */
    void shutdown()
    {
        if(mActiveRenderer)
            mActiveRenderer._setViewport(null);
        
        // Since background thread might be access resources,
        // ensure shutdown before destroying resource manager.
        mResourceBackgroundQueue.shutdown();
        mWorkQueue.shutdown();
        
        SceneManagerEnumerator.getSingleton().shutdownAll();
        shutdownPlugins();
        
        ShadowVolumeExtrudeProgram.shutdown();
        ResourceGroupManager.getSingleton().shutdownAll();
        
        // Destroy pools
        ConvexBody._destroyPool();
        
        
        mIsInitialised = false;
        
        LogManager.getSingleton().logMessage("*-*-* OGRE Shutdown");
    }
    
    /** Adds a location to the list of searchable locations for a
     Resource type.
     @remarks
     Resource files (textures, models etc) need to be loaded from
     specific locations. By calling this method, you add another 
     search location to the list. Locations added first are preferred
     over locations added later.
     @par
     Locations can be folders, compressed archives, even perhaps
     remote locations. Facilities for loading from different
     locations are provided by plugins which provide
     implementations of the Archive class.
     All the application user has to do is specify a 'loctype'
     string in order to indicate the type of location, which
     should map onto one of the provided plugins. Ogre comes
     configured with the 'FileSystem' (folders) and 'Zip' (archive
     compressed with the pkzip / WinZip etc utilities) types.
     @par
     You can also supply the name of a resource group which should
     have this location applied to it. The 
     ResourceGroupManager::DEFAULT_RESOURCE_GROUP_NAME group is the
     default, and one resource group which will always exist. You
     should consider defining resource groups for your more specific
     resources (e.g. per level) so that you can control loading /
     unloading better.
     @param
     name The name of the location, e.g. './data' or
     '/compressed/gamedata.zip'
     @param
     locType A string identifying the location type, e.g.
     'FileSystem' (for folders), 'Zip' etc. Must map to a
     registered plugin which deals with this type (FileSystem and
     Zip should always be available)
     @param
     groupName Type of name of the resource group which this location
     should apply to; defaults to the General group which applies to
     all non-specific resources.
     @param
     recursive If the resource location has a concept of recursive
     directory traversal, enabling this option will mean you can load
     resources in subdirectories using only their unqualified name.
     The default is to disable this so that resources in subdirectories
     with the same name are still unique.
     @see
     Archive
     */
    void addResourceLocation(string name,string locType, 
                            string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, 
                             bool recursive = false)
    {
        ResourceGroupManager.getSingleton().addResourceLocation(
            name, locType, groupName, recursive);
    }
    
    /** Removes a resource location from the list.
     @see addResourceLocation
     @param name The name of the resource location as specified in addResourceLocation
     @param groupName The name of the resource group to which this location 
     was assigned.
     */
    void removeResourceLocation(string name, 
                               string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME)
    {
        ResourceGroupManager.getSingleton().removeResourceLocation(
            name, groupName);
    }
    
    /** Helper method to assist you in creating writeable file streams.
     @remarks
     This is a high-level utility method which you can use to find a place to 
     save a file more easily. If the filename you specify is either an
     absolute or relative filename (ie it includes path separators), then
     the file will be created in the normal filesystem using that specification.
     If it doesn't, then the method will look for a writeable resource location
     via ResourceGroupManager::createResource using the other params provided.
     @param filename The name of the file to create. If it includes path separators, 
     the filesystem will be accessed direct. If no path separators are
     present the resource system is used, falling back on the raw filesystem after.
     @param groupName The name of the group in which to create the file, if the 
     resource system is used
     @param overwrite If true, an existing file will be overwritten, if false
     an error will occur if the file already exists
     @param locationPattern If the resource group contains multiple locations, 
     then usually the file will be created in the first writable location. If you 
     want to be more specific, you can include a location pattern here and 
     only locations which match that pattern (as determined by StringUtil::match)
     will be considered candidates for creation.
     */
    DataStream createFileStream(string filename,string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, 
                                bool overwrite = false,string locationPattern = null)
    {
        // Does this file include path specifiers?
        string path, basename;
        StringUtil.splitFilename(filename, basename, path);
        
        // no path elements, try the resource system first
        DataStream stream;
        if (!path || path.empty())
        {
            try
            {
                stream = ResourceGroupManager.getSingleton().createResource(
                    filename, groupName, overwrite, locationPattern);
            }
            catch {}
        }
        
        if (!stream)
        {
            // save direct in filesystem
            /*std::fstream* fs = OGRE_NEW_T(std::fstream, MEMCATEGORY_GENERAL);
             fs.open(filename.c_str(), std::ios::out | std::ios::binary);
             if (!*fs)
             {
             OGRE_DELETE_T(fs, basic_fstream, MEMCATEGORY_GENERAL);
             OGRE_EXCEPT(Exception::ERR_CANNOT_WRITE_TO_FILE, 
             "Can't open " + filename + " for writing", __FUNCTION__);
             }*/

            stream = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        }
        
        return stream;
        
    }
    
    /** Helper method to assist you in accessing readable file streams.
     @remarks
     This is a high-level utility method which you can use to find a place to 
     open a file more easily. It checks the resource system first, and if
     that fails falls back on accessing the file system directly.
     @param filename The name of the file to open. 
     @param groupName The name of the group in which to create the file, if the 
     resource system is used
     @param locationPattern If the resource group contains multiple locations, 
     then usually the file will be created in the first writable location. If you 
     want to be more specific, you can include a location pattern here and 
     only locations which match that pattern (as determined by StringUtil::match)
     will be considered candidates for creation.
     */      
    DataStream openFileStream(string filename,string groupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, 
                             string locationPattern = null)
    {
        DataStream stream;
        if (ResourceGroupManager.getSingleton().resourceExists(
            groupName, filename))
        {
            stream = ResourceGroupManager.getSingleton().openResource(
                filename, groupName);
        }
        else
        {
            // try direct
            /*std::ifstream *ifs = OGRE_NEW_T(std::ifstream, MEMCATEGORY_GENERAL);
             ifs.open(filename.c_str(), std::ios::in | std::ios::binary);
             if(!*ifs)
             {
             OGRE_DELETE_T(ifs, basic_ifstream, MEMCATEGORY_GENERAL);
             OGRE_EXCEPT(
             Exception::ERR_FILE_NOT_FOUND, "'" + filename + "' file not found!", __FUNCTION__);
             }*/
            stream = new FileHandleDataStream(filename, DataStream.AccessMode.READ);
        }
        return stream;
    }
    
    /** Generates a packed data version of the passed in ColourValue suitable for
     use with the current RenderSystem.
     @remarks
     Since different render systems have different colour data formats (eg
     RGBA for GL, ARGB for D3D) this method allows you to use 1 method for all.
     @param colour The colour to convert
     @param pDest Pointer to location to put the result.
     */
    void convertColourValue(ColourValue colour, ref uint pDest)
    {
        assert(mActiveRenderer !is null);
        mActiveRenderer.convertColourValue(colour, pDest);
    }
    
    /** Retrieves a pointer to the window that was created automatically
     @remarks
     When Root is initialised an optional window is created. This
     method retrieves a pointer to that window.
     @note
     returns a null pointer when Root has not been initialised with
     the option of creating a window.
     */
    RenderWindow getAutoCreatedWindow()
    {
        return mAutoWindow;
    }
    
    /** @copydoc RenderSystem::_createRenderWindow
     */
    RenderWindow createRenderWindow(string name, uint width, uint height, 
                                    bool fullScreen,NameValuePairList miscParams = NameValuePairList.init)
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot create window - no render system has been selected.", 
                "Root.createRenderWindow");
        }
        RenderWindow ret;
        ret = mActiveRenderer._createRenderWindow(name, width, height, fullScreen, miscParams);
        
        // Initialisation for classes dependent on first window created
        if(!mFirstTimePostWindowInit)
        {
            oneTimePostWindowInit();
            ret._setPrimary();
        }
        
        return ret;
        
    }
    
    /** @copydoc RenderSystem::_createRenderWindows
     */
    bool createRenderWindows(RenderWindowDescriptionList renderWindowDescriptions,
                             ref RenderWindowList createdWindows)
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot create render windows - no render system has been selected.", 
                "Root.createRenderWindows");
        }
        
        bool success;
        
        success = mActiveRenderer._createRenderWindows(renderWindowDescriptions, createdWindows);      
        if(success && !mFirstTimePostWindowInit)
        {
            oneTimePostWindowInit();
            createdWindows[0]._setPrimary();
        }
        
        return success;
    }   
    
    /** Detaches a RenderTarget from the active render system
     and returns a pointer to it.
     @note
     If the render target cannot be found, NULL is returned.
     */
    RenderTarget detachRenderTarget( RenderTarget target )
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot detach target - no render system has been selected.", 
                "Root.detachRenderTarget");
        }
        
        return mActiveRenderer.detachRenderTarget( target.getName() );
    }
    
    /** Detaches a named RenderTarget from the active render system
     and returns a pointer to it.
     @note
     If the render target cannot be found, NULL is returned.
     */
    RenderTarget detachRenderTarget(string  name )
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot detach target - no render system has been selected.", 
                "Root.detachRenderTarget");
        }
        
        return mActiveRenderer.detachRenderTarget( name );
    }
    
    /** Destroys the given RenderTarget.
     */
    void destroyRenderTarget(RenderTarget target)
    {
        detachRenderTarget(target);
        destroy(target);
    }
    
    /** Destroys the given named RenderTarget.
     */
    void destroyRenderTarget(string name)
    {
        RenderTarget target = getRenderTarget(name);
        destroyRenderTarget(target);
    }
    
    /** Retrieves a pointer to a named render target.
     */
    RenderTarget getRenderTarget(string name)
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot detach target - no render system has been selected.", 
                "Root.detachRenderTarget");
        }
        
        return mActiveRenderer.getRenderTarget(name);
    }
    
    /** Manually load a Plugin contained in a DLL / DSO.
     @remarks
         Plugins embedded in DLLs can be loaded at startup using the plugin 
         configuration file specified when you create Root.
         This method allows you to load plugin DLLs directly in code.
         The DLL in question is expected to implement a dllStartPlugin 
         method which instantiates a Plugin subclass and calls Root::installPlugin.
         It should also implement dllStopPlugin (see Root::unloadPlugin)
     @param pluginName Name of the plugin library to load
     */
    //FIXME loadPlugin: No dynamic loading in D yet. Simulating.
    void loadPlugin(string pluginName)
    {
        //#if OGRE_PLATFORM != OGRE_PLATFORM_NACL

        // Plan for now is that static plugins register themselves with DynLib
        // and we fake load them here with hope for future support.

        // Load plugin library
        DynLib lib = DynLibManager.getSingleton().load( pluginName );
        // Store for later unload
        // Check for existence, because if called 2+ times DynLibManager returns existing entry
        if (mPluginLibs.find(lib).empty)
        {
            mPluginLibs ~= lib;
            
            // Call startup function
            //DLL_START_PLUGIN pFunc = (DLL_START_PLUGIN)lib.getSymbol("dllStartPlugin");
            lib.dllStartPlugin();

            //if (!pFunc)
            //    throw new ItemNotFoundError("Cannot find symbol dllStartPlugin in library " ~ pluginName,
            //                "Root.loadPlugin");
            
            // This must call installPlugin
            //pFunc();
        }
        //#endif
    }
    
    /** Manually unloads a Plugin contained in a DLL / DSO.
     @remarks
     Plugin DLLs are unloaded at shutdown automatically. This method 
     allows you to unload plugins in code, but make sure their 
     dependencies are decoupled first. This method will call the 
     dllStopPlugin method defined in the DLL, which in turn should call
     Root::uninstallPlugin.
     @param pluginName Name of the plugin library to unload
     */
    //FIXME unloadPlugin: No dynamic loading in D yet. Simulating.
    void unloadPlugin(string pluginName)
    {
        //#if OGRE_PLATFORM != OGRE_PLATFORM_NACL
        
        foreach (i; mPluginLibs)
        {
            if (i.getName() == pluginName)
            {
                // Call plugin shutdown
                //DLL_STOP_PLUGIN pFunc = (DLL_STOP_PLUGIN)(*i).getSymbol("dllStopPlugin");
                // Faking it
                i.dllStopPlugin();

                // this must call uninstallPlugin
                //pFunc();
                // Unload library (destroyed by DynLibManager)
                //DynLibManager.getSingleton().unload(i);
                //mPluginLibs.removeFromArray(mPluginLibs.find(i).takeOne);
                mPluginLibs.removeFromArray(i);
                return;
            }
        }
        //#endif
    }
    
    /** Install a new plugin.
     @remarks
     This installs a new extension to OGRE. The plugin itself may be loaded
     from a DLL / DSO, or it might be statically linked into your own 
     application. Either way, something has to call this method to get
     it registered and functioning. You should only call this method directly
     if your plugin is not in a DLL that could otherwise be loaded with 
     loadPlugin, since the DLL function dllStartPlugin should call this
     method when the DLL is loaded. 
     */
    void installPlugin(Plugin plugin)
    {
        LogManager.getSingleton().logMessage("Installing plugin: " ~ plugin.getName());
        
        mPlugins ~= plugin;
        plugin.install();
        
        // if rendersystem is already initialised, call rendersystem init too
        if (mIsInitialised)
        {
            plugin.initialise();
        }
        
        LogManager.getSingleton().logMessage("Plugin successfully installed");
    }

    /** Uninstall an existing plugin.
     @remarks
     This uninstalls an extension to OGRE. Plugins are automatically 
     uninstalled at shutdown but this lets you remove them early. 
     If the plugin was loaded from a DLL / DSO you should call unloadPlugin
     which should result in this method getting called anyway (if the DLL
     is well behaved).
     */
    void uninstallPlugin(Plugin plugin)
    {
        LogManager.getSingleton().logMessage("Uninstalling plugin: " ~ plugin.getName());
        //auto i = mPlugins.find(plugin).takeOne;
        //if (!i.empty)
        {
            if (mIsInitialised)
                plugin.shutdown();
            plugin.uninstall();
            mPlugins.removeFromArray(plugin);
        }
        LogManager.getSingleton().logMessage("Plugin successfully uninstalled");
        
    }
    
    /** Gets a read-only list of the currently installed plugins. */
    PluginInstanceList getInstalledPlugins(){ return mPlugins; }
    
    /** Gets a pointer to the central timer used for all OGRE timings */
    Timer getTimer()
    {
        return mTimer;
    }
    
    /** Method for raising frame started events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you should call this method to ensure that FrameListener objects are notified
     of frame events; processes like texture animation and particle systems rely on 
     this.
     @par
     Calling this method also increments the frame number, which is
     important for keeping some elements of the engine up to date.
     @note
     This method takes an event object as a parameter, so you can specify the times
     yourself. If you are happy for OGRE to automatically calculate the frame time
     for you, then call the other version of this method with no parameters.
     @param evt Event object which includes all the timing information which you have 
     calculated for yourself
     @return False if one or more frame listeners elected that the rendering loop should
     be terminated, true otherwise.
     */
    bool _fireFrameStarted(FrameEvent evt)
    {
        mixin(OgreProfileBeginGroup("Frame", ProfileGroupMask.OGREPROF_GENERAL));
        
        // Remove all marked listeners
        foreach (i; mRemovedFrameListeners)
        {
            mFrameListeners.removeFromArray(i);
        }
        mRemovedFrameListeners.clear();
        
        // Tell all listeners
        foreach (i; mFrameListeners)
        {
            if (!i.frameStarted(evt))
                return false;
        }
        
        return true;
        
    }
    /** Method for raising frame rendering queued events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you should call this method too, to ensure that all state is updated
     correctly. You should call it after the windows have been updated
     but before the buffers are swapped, or if you are not separating the
     update and buffer swap, then after the update just before _fireFrameEnded.
     */
    bool _fireFrameRenderingQueued(FrameEvent evt)
    {
        // Increment next frame number
        ++mNextFrame;
        
        // Remove all marked listeners
        foreach (i; mRemovedFrameListeners)
        {
            mFrameListeners.removeFromArray(i);
        }
        mRemovedFrameListeners.clear();
        
        // Tell all listeners
        foreach (i; mFrameListeners)
        {
            if (!i.frameRenderingQueued(evt))
                return false;
        }
        
        return true;
        
    }
    
    /** Method for raising frame ended events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you should call this method to ensure that FrameListener objects are notified
     of frame events; processes like texture animation and particle systems rely on 
     this.
     @note
     This method takes an event object as a parameter, so you can specify the times
     yourself. If you are happy for OGRE to automatically calculate the frame time
     for you, then call the other version of this method with no parameters.
     @param evt Event object which includes all the timing information which you have 
     calculated for yourself
     @return False if one or more frame listeners elected that the rendering loop should
     be terminated, true otherwise.
     */
    bool _fireFrameEnded(FrameEvent evt)
    {
        // Remove all marked listeners
        foreach (i; mRemovedFrameListeners)
        {
            mFrameListeners.removeFromArray(i);
        }
        mRemovedFrameListeners.clear();
        
        // Tell all listeners
        bool ret = true;
        foreach (i; mFrameListeners)
        {
            if (!i.frameEnded(evt))
            {
                ret = false;
                break;
            }
        }
        
        // Tell buffer manager to free temp buffers used this frame
        if (HardwareBufferManager.getSingletonPtr())
            HardwareBufferManager.getSingleton()._releaseBufferCopies();
        
        // Tell the queue to process responses
        mWorkQueue.processResponses();
        
        mixin(OgreProfileEndGroup("Frame", ProfileGroupMask.OGREPROF_GENERAL));
        
        return ret;
    }
    /** Method for raising frame started events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you should call this method to ensure that FrameListener objects are notified
     of frame events; processes like texture animation and particle systems rely on 
     this.
     @par
     Calling this method also increments the frame number, which is
     important for keeping some elements of the engine up to date.
     @note
     This method calculates the frame timing information for you based on the elapsed
     time. If you want to specify elapsed times yourself you should call the other 
     version of this method which takes event details as a parameter.
     @return False if one or more frame listeners elected that the rendering loop should
     be terminated, true otherwise.
     */
    bool _fireFrameStarted()
    {
        FrameEvent evt;
        populateFrameEvent(FrameEventTimeType.FETT_STARTED, evt);
        
        return _fireFrameStarted(evt);
    }

    /** Method for raising frame rendering queued events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you you may want to call this method too, although nothing in OGRE relies on this
     particular event. Really if you're running your own rendering loop at
     this level of detail then you can get the same effect as doing your
     updates in a frameRenderingQueued callback by just calling 
     RenderWindow::update with the 'swapBuffers' option set to false. 
     */
    bool _fireFrameRenderingQueued()
    {
        FrameEvent evt;
        populateFrameEvent(FrameEventTimeType.FETT_QUEUED, evt);
        
        return _fireFrameRenderingQueued(evt);
    }
    /** Method for raising frame ended events. 
     @remarks
     This method is only for internal use when you use OGRE's inbuilt rendering
     loop (Root::startRendering). However, if you run your own rendering loop then
     you should call this method to ensure that FrameListener objects are notified
     of frame events; processes like texture animation and particle systems rely on 
     this.
     @note
     This method calculates the frame timing information for you based on the elapsed
     time. If you want to specify elapsed times yourself you should call the other 
     version of this method which takes event details as a parameter.
     @return False if one or more frame listeners elected that the rendering loop should
     be terminated, true otherwise.
     */
    bool _fireFrameEnded()
    {
        FrameEvent evt;
        populateFrameEvent(FrameEventTimeType.FETT_ENDED, evt);
        return _fireFrameEnded(evt);
    }
    
    /** Gets the number of the next frame to be rendered. 
     @remarks
     Note that this is 'next frame' rather than 'current frame' because
     it indicates the frame number that current changes made to the scene
     will take effect. It is incremented after all rendering commands for
     the current frame have been queued, thus reflecting that if you 
     start performing changes then, you will actually see them in the 
     next frame. */
    ulong getNextFrameNumber(){ return mNextFrame; }
    
    /** Returns the scene manager currently being used to render a frame.
     @remarks
     This is only intended for internal use; it is only valid during the
     rendering of a frame.
     */
    SceneManager _getCurrentSceneManager()
    {
        if (mSceneManagerStack.empty())
            return null;
        else
            return mSceneManagerStack.back();
    }

    /** Pushes the scene manager currently being used to render.
     @remarks
     This is only intended for internal use.
     */
    void _pushCurrentSceneManager(SceneManager sm)
    {
        mSceneManagerStack.insert(sm);
    }

    /** Pops the scene manager currently being used to render.
     @remarks
     This is only intended for internal use.
     */
    void _popCurrentSceneManager(SceneManager sm)
    {
        assert (_getCurrentSceneManager() == sm, "Mismatched push/pop of SceneManager");
        
        mSceneManagerStack.popBack();
    }
    
    /** Internal method used for updating all RenderTarget objects (windows, 
     renderable textures etc) which are set to auto-update.
     @remarks
     You don't need to use this method if you're using Ogre's own internal
     rendering loop (Root::startRendering). If you're running your own loop
     you may wish to call it to update all the render targets which are
     set to auto update (RenderTarget::setAutoUpdated). You can also update
     individual RenderTarget instances using their own update() method.
     @return false if a FrameListener indicated it wishes to exit the render loop
     */
    bool _updateAllRenderTargets()
    {
        // update all targets but don't swap buffers
        mActiveRenderer._updateAllRenderTargets(false);
        // give client app opportunity to use queued GPU time
        bool ret = _fireFrameRenderingQueued();
        // block for final swap
        mActiveRenderer._swapAllRenderTargetBuffers(mActiveRenderer.getWaitForVerticalBlank());
        
        // This belongs here, as all render targets must be updated before events are
        // triggered, otherwise targets could be mismatched.  This could produce artifacts,
        // for instance, with shadows.
        foreach (it; getSceneManagers())
            it._handleLodEvents();
        
        return ret;
    }
    
    /** Internal method used for updating all RenderTarget objects (windows, 
     renderable textures etc) which are set to auto-update, with a custom time
     passed to the frameRenderingQueued events.
     @remarks
     You don't need to use this method if you're using Ogre's own internal
     rendering loop (Root::startRendering). If you're running your own loop
     you may wish to call it to update all the render targets which are
     set to auto update (RenderTarget::setAutoUpdated). You can also update
     individual RenderTarget instances using their own update() method.
     @return false if a FrameListener indicated it wishes to exit the render loop
     */
    bool _updateAllRenderTargets(FrameEvent evt)
    {
        // update all targets but don't swap buffers
        mActiveRenderer._updateAllRenderTargets(false);
        // give client app opportunity to use queued GPU time
        bool ret = _fireFrameRenderingQueued(evt);
        // block for final swap
        mActiveRenderer._swapAllRenderTargetBuffers(mActiveRenderer.getWaitForVerticalBlank());
        
        // This belongs here, as all render targets must be updated before events are
        // triggered, otherwise targets could be mismatched.  This could produce artifacts,
        // for instance, with shadows.
        foreach (it; getSceneManagers())
            it._handleLodEvents();
        
        return ret;
    }
    
    /** Create a new RenderQueueInvocationSequence, useful for linking to
     Viewport instances to perform custom rendering.
     @param name The name to give the new sequence
     */
    RenderQueueInvocationSequence createRenderQueueInvocationSequence(string name)
    {
        auto i = name in mRQSequenceMap;
        if (i !is null)
        {
            throw new DuplicateItemError(
                "RenderQueueInvocationSequence with the name " ~ name ~
                " already exists.",
                "Root.createRenderQueueInvocationSequence");
        }
        RenderQueueInvocationSequence ret = new RenderQueueInvocationSequence(name);
        mRQSequenceMap[name] = ret;
        return mRQSequenceMap[name];
    }
    
    /** Get a RenderQueueInvocationSequence. 
     @param name The name to identify the sequence
     */
    RenderQueueInvocationSequence getRenderQueueInvocationSequence(
       string name)
    {
        auto i = name in mRQSequenceMap;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "RenderQueueInvocationSequence with the name " ~ name ~
                " not found.",
                "Root.getRenderQueueInvocationSequence");
        }
        return *i;
    }
    /** Destroy a RenderQueueInvocationSequence. 
     @remarks
     You must ensure that no Viewports are using this sequence.
     @param name The name to identify the sequence
     */
    void destroyRenderQueueInvocationSequence(
       string name)
    {
        auto i = name in mRQSequenceMap;
        if (i !is null)
        {
            destroy(*i);
            mRQSequenceMap.remove(name);
        }
    }
    
    /** Destroy all RenderQueueInvocationSequences. 
     @remarks
     You must ensure that no Viewports are using custom sequences.
     */
    void destroyAllRenderQueueInvocationSequences()
    {
        foreach (k,v; mRQSequenceMap)
        {
            destroy(v);
        }
        mRQSequenceMap.clear();
    }
    

    
    /** Clears the history of all event times. 
     @remarks
     OGRE stores a history of the last few event times in order to smooth
     out any inaccuracies and temporary fluctuations. However, if you 
     pause or don't render for a little while this can cause a lurch, so
     if you're resuming rendering after a break, call this method to reset
     the stored times
     */
    void clearEventTimes()
    {
        // Clear event times
        for(int i=0; i<FrameEventTimeType.FETT_COUNT; ++i)
            mEventTimes[i].clear();
    }
    
    /** Sets the period over which OGRE smooths out fluctuations in frame times.
     @remarks
     OGRE by default gives you the raw frame time, but can optionally
     smooths it out over several frames, in order to reduce the 
     noticeable effect of occasional hiccups in framerate.
     These smoothed values are passed back as parameters to FrameListener
     calls.
     @par
     This method allow you to tweak the smoothing period, and is expressed
     in seconds. Setting it to 0 will result in completely unsmoothed
     frame times (the default).
     */
    void setFrameSmoothingPeriod(Real period) { mFrameSmoothingTime = period; }
    /** Gets the period over which OGRE smooths out fluctuations in frame times. */
    Real getFrameSmoothingPeriod(){ return mFrameSmoothingTime; }
    
    /** Register a new MovableObjectFactory which will create new MovableObject
     instances of a particular type, as identified by the getType() method.
     @remarks
     Plugin creators can create subclasses of MovableObjectFactory which 
     construct custom subclasses of MovableObject for insertion in the 
     scene. This is the primary way that plugins can make custom objects
     available.
     @param fact Pointer to the factory instance
     @param overrideExisting Set this to true to override any existing 
     factories which are registered for the same type. You should only
     change this if you are very sure you know what you're doing. 
     */
    void addMovableObjectFactory(MovableObjectFactory fact, 
                                 bool overrideExisting = false)
    {
        auto facti = fact.getType() in mMovableObjectFactoryMap;
        if (!overrideExisting && facti !is null)
        {
            throw new DuplicateItemError(
                "A factory of type '" ~ fact.getType() ~ "' already exists.",
                "Root.addMovableObjectFactory");
        }
        
        if (fact.requestTypeFlags())
        {
            if (facti !is null && facti.requestTypeFlags())
            {
                // Copy type flags from the factory we're replacing
                fact._notifyTypeFlags(facti.getTypeFlags());
            }
            else
            {
                // Allocate new
                fact._notifyTypeFlags(_allocateNextMovableObjectTypeFlag());
            }
        }
        
        // Save
        mMovableObjectFactoryMap[fact.getType()] = fact;
        
        LogManager.getSingleton().logMessage("MovableObjectFactory for type '" ~
                                             fact.getType() ~ "' registered.");
        
    }
    /** Removes a previously registered MovableObjectFactory.
     @remarks
     All instances of objects created by this factory will be destroyed
     before removing the factory (by calling back the factories 
     'destroyInstance' method). The plugin writer is responsible for actually
     destroying the factory.
     */
    void removeMovableObjectFactory(MovableObjectFactory fact)
    {
        //No need to check (?)
        //auto i = fact.getType() in mMovableObjectFactoryMap;
        //if (i !is null)
        {
            mMovableObjectFactoryMap.remove(fact.getType());
        }
    }

    /// Checks whether a factory is registered for a given MovableObject type
    bool hasMovableObjectFactory(string typeName)
    {
        return (typeName in mMovableObjectFactoryMap) !is null;
    }

    /// Get a MovableObjectFactory for the given type
    MovableObjectFactory getMovableObjectFactory(string typeName)
    {
        auto i = typeName in mMovableObjectFactoryMap;
        if (i is null)
        {
            throw new ItemNotFoundError(
                "MovableObjectFactory of type " ~ typeName ~ " does not exist",
                "Root.getMovableObjectFactory");
        }
        return *i;
    }

    /** Allocate the next MovableObject type flag.
     @remarks
     This is done automatically if MovableObjectFactory::requestTypeFlags
     returns true; don't call this manually unless you're sure you need to.
     */
    uint _allocateNextMovableObjectTypeFlag()
    {
        if (mNextMovableObjectTypeFlag == SceneManager.USER_TYPE_MASK_LIMIT)
        {
            throw new DuplicateItemError(
                "Cannot allocate a type flag since " ~
                "all the available flags have been used.",
                "Root._allocateNextMovableObjectTypeFlag");
            
        }
        uint ret = mNextMovableObjectTypeFlag;
        mNextMovableObjectTypeFlag <<= 1;
        return ret;
    }
    
    //typedef ConstMapIterator<MovableObjectFactoryMap> MovableObjectFactoryIterator;
    /** Return an iterator over all the MovableObjectFactory instances currently
     registered.
     */
    /*MovableObjectFactoryIterator getMovableObjectFactoryIterator()
     {
     return MovableObjectFactoryIterator(mMovableObjectFactoryMap.begin(),
     mMovableObjectFactoryMap.end());
     }*/

    MovableObjectFactoryMap getMovableObjectFactories()
    {
        return mMovableObjectFactoryMap;
    }
    
    /**
     * Gets the number of display monitors.
     */
    uint getDisplayMonitorCount()
    {
        if (!mActiveRenderer)
        {
            throw new InvalidStateError(
                "Cannot get display monitor count " ~
                "No render system has been selected.", "Root.getDisplayMonitorCount");
        }
        
        return mActiveRenderer.getDisplayMonitorCount();
    }
    
    /** Get the WorkQueue for processing background tasks.
     You are free to add new requests and handlers to this queue to
     process your custom background tasks using the shared thread pool. 
     However, you must remember to assign yourself a new channel through 
     which to process your tasks.
     */
    WorkQueue getWorkQueue(){ return mWorkQueue; }
    
    /** Replace the current work queue with an alternative. 
     You can use this method to replace the internal implementation of
     WorkQueue with  your own, e.g. to externalise the processing of 
     background events. Doing so will delete the existing queue and
     replace it with this one. 
     @param queue The new WorkQueue instance. Root will delete this work queue
     at shutdown, so do not destroy it yourself.
     */
    void setWorkQueue(WorkQueue queue)
    {
        if (mWorkQueue != queue)
        {
            // delete old one (will shut down)
            destroy(mWorkQueue);
            
            mWorkQueue = queue;
            if (mIsInitialised)
                mWorkQueue.startup();
            
        }
    }
    
    /** Sets whether blend indices information needs to be passed to the GPU.
     When entities use software animation they remove blend information such as
     indices and weights from the vertex buffers sent to the graphic card. This function
     can be used to limit which information is removed.
     @param redundant Set to true to remove blend indices information.
     */
    void setBlendIndicesGpuRedundant(bool redundant) {  mIsBlendIndicesGpuRedundant = redundant; }
    /** Returns whether blend indices information needs to be passed to the GPU
     see setBlendIndicesGpuRedundant() for more information
     */
    bool isBlendIndicesGpuRedundant(){ return mIsBlendIndicesGpuRedundant; }
    
    /** Sets whether blend weights information needs to be passed to the GPU.
     When entities use software animation they remove blend information such as
     indices and weights from the vertex buffers sent to the graphic card. This function
     can be used to limit which information is removed.
     @param redundant Set to true to remove blend weights information.
     */
    void setBlendWeightsGpuRedundant(bool redundant) {  mIsBlendWeightsGpuRedundant = redundant; }
    /** Returns whether blend weights information needs to be passed to the GPU
     see setBlendWeightsGpuRedundant() for more information
     */
    bool isBlendWeightsGpuRedundant(){ return mIsBlendWeightsGpuRedundant; }
    
    /** Set the default minimum pixel size for object to be rendered by
     @note
     To use this feature see Camera::setUseMinPixelSize()
     */
    void setDefaultMinPixelSize(Real pixelSize) { mDefaultMinPixelSize = pixelSize; }
    
    /** Get the default minimum pixel size for object to be rendered by
     */
    Real getDefaultMinPixelSize() { return mDefaultMinPixelSize; }
    
    
}
/** @} */
/** @} */
