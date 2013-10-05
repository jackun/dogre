module ogre.resources.resource;

//NOTE: import ogre.resources.resource before ogre.resources.resourcemanager :S
//import std.container;
import core.sync.mutex;
import ogre.general.generals;
import ogre.general.atomicwrappers;
import ogre.sharedptr;
import ogre.general.common;
import ogre.exception;
import ogre.compat;
import ogre.resources.resourcemanager;
import ogre.resources.resourcegroupmanager;
import ogre.general.log;
public import ogre.sharedptr;

alias ulong ResourceHandle;

/** Abstract class representing a loadable resource (e.g. textures, sounds etc)
    @remarks
        Resources are data objects that must be loaded and managed throughout
        an application. A resource might be a mesh, a texture, or any other
        piece of data - the key thing is that they must be identified by 
        a name which is unique, must be loaded only once,
        must be managed efficiently in terms of retrieval, and they may
        also be unloadable to free memory up when they have not been used for
        a while and the memory budget is under stress.
    @par
        All Resource instances must be a member of a resource group; see
        ResourceGroupManager for full details.
    @par
        Subclasses must implement:
        <ol>
        <li>A constructor, overriding the same parameters as the constructor
            defined by this class. Subclasses are not allowed to define
            constructors with other parameters; other settings must be
            settable through accessor methods before loading.</li>
        <li>The loadImpl() and unloadImpl() methods - mSize must be set 
            after loadImpl()</li>
        <li>stringInterface ParamCommand and ParamDictionary setups
            in order to allow setting of core parameters (prior to load)
            through a generic interface.</li>
        </ol>
*/
class Resource : StringInterface//, public ResourceAlloc
{
    //Randomly ldc chokes on this. Something about overloading maybe.
    //mixin StringInterfaceTmpl;
    
private:
    /// Class name for this instance to be used as a lookup (must be initialised by subclasses)
    string mParamDictName;
    ParamDictionary mParamDict;
protected:
    /** Internal method for creating a parameter dictionary for the class, if it does not already exist.
     @remarks
     This method will check to see if a parameter dictionary exist for this class yet,
     and if not will create one. NB you must supply the name of the class (RTTI is not 
     used or performance).
     @param
     className the name of the class using the dictionary
     @return
     true if a new dictionary was created, false if it was already there
     */
    bool createParamDictionary(string className)
    {
        //OGRE_LOCK_MUTEX( msDictionaryMutex )
        synchronized(StringInterface.Dict.msDictionaryMutex)
        {
            auto it = className in StringInterface.Dict.msDictionary;
            
            if ( it is null )
            {
                //mParamDict = &msDictionary.insert( std::make_pair( className, ParamDictionary() ) ).first.second;
                mParamDict = new ParamDictionary;
                StringInterface.Dict.msDictionary[className] = mParamDict;
                mParamDictName = className;
                return true;
            }
            else
            {
                mParamDict = *it;
                mParamDictName = className;
                return false;
            }
        }
    }
    
public:
    
    /** Retrieves the parameter dictionary for this class. 
     @remarks
     Only valid to call this after createParamDictionary.
     @return
     Pointer to ParamDictionary shared by all instances of this class
     which you can add parameters to, retrieve parameters etc.
     */
    ref ParamDictionary getParamDictionary()
    {
        return mParamDict;
    }
    
    /*ref const(ParamDictionary) getParamDictionary() const
     {
     return mParamDict;
     }*/
    
    /** Retrieves a list of parameters valid for this object. 
     @return
     A reference to a static list of ParameterDef objects.

     */
    ref ParameterList getParameters()
    {
        static ParameterList emptyList;
        
        ParamDictionary dict = getParamDictionary();
        if (dict)
            return dict.getParameters();
        else
            return emptyList;
        
    }
    
    /** Generic parameter setting method.
     @remarks
     Call this method with the name of a parameter and a string version of the value
     to set. The implementor will convert the string to a native type internally.
     If in doubt, check the parameter definition in the list returned from 
     StringInterface::getParameters.
     @param
     name The name of the parameter to set
     @param
     value string value. Must be in the right format for the type specified in the parameter definition.
     See the StringConverter class for more information.
     @return
     true if set was successful, false otherwise (NB no exceptions thrown - tolerant method)
     */
    bool setParameter(string name,string value)
    {
        // Get dictionary
        auto dict = getParamDictionary();
        
        if (dict)
        {
            // Look up command object
            auto cmd = dict.getParamCommand(name);
            if (cmd)
            {
                cmd.doSet(this, value);
                return true;
            }
        }
        // Fallback
        return false;
    }
    /** Generic multiple parameter setting method.
     @remarks
     Call this method with a list of name / value pairs
     to set. The implementor will convert the string to a native type internally.
     If in doubt, check the parameter definition in the list returned from 
     StringInterface::getParameters.
     @param
     paramList Name/value pair list
     */
    void setParameterList(NameValuePairList paramList)
    {
        foreach (k, v; paramList)
        {
            setParameter(k, v);
        }
    }
    /** Generic parameter retrieval method.
     @remarks
     Call this method with the name of a parameter to retrieve a string-format value of
     the parameter in question. If in doubt, check the parameter definition in the
     list returned from getParameters for the type of this parameter. If you
     like you can use StringConverter to convert this string back into a native type.
     @param
     name The name of the parameter to get
     @return
     string value of parameter, blank if not found
     */
    string getParameter(string name)
    {
        // Get dictionary
        auto dict = getParamDictionary();
        
        if (dict)
        {
            // Look up command object
            auto cmd = dict.getParamCommand(name);
            
            if (cmd)
            {
                return cmd.doGet(this);
            }
        }
        
        // Fallback
        return "";
    }
    /** Method for copying this object's parameters to another object.
     @remarks
     This method takes the values of all the object's parameters and tries to set the
     same values on the destination object. This provides a completely type independent
     way to copy parameters to other objects. Note that because of the string manipulation 
     involved, this should not be regarded as an efficient process and should be saved for
     times outside of the rendering loop.
     @par
     Any unrecognised parameters will be ignored as with setParameter method.
     @param dest Pointer to object to have it's parameters set the same as this object.

     */
    void copyParametersTo(StringInterface dest)
    {
        // Get dictionary
        auto dict = getParamDictionary();
        
        if (dict)
        {
            // Iterate through own parameters
            
            foreach (i; dict.mParamDefs)
            {
                dest.setParameter(i.name, getParameter(i.name));
            }
        }
    }
        
public:
    //OGRE_AUTO_MUTEX // public to allow external locking
    
    /// while loops use mutex to lock until resource is prepared/loaded
    /// synchronized(this) locks whole class and may result in deadlocks(?)
    Mutex mLock;
    
    invariant()
    {
        assert(mLock !is null);
    }
    
    
    template Resource_Listener_Impl()
    {
        void backgroundLoadingComplete(ref Resource r){}
        void backgroundPreparingComplete(ref Resource r){}
        void loadingComplete(ref Resource r){}
        void preparingComplete(ref Resource r){}
        void unloadingComplete(ref Resource r){}
    }
    
    interface Listener
    {
        /** Callback to indicate that background loading has completed.
        @deprecated
            Use loadingComplete instead.
        */
        void backgroundLoadingComplete(ref Resource r);
        
        /** Callback to indicate that background preparing has completed.
        @deprecated
            Use preparingComplete instead.
        */
        void backgroundPreparingComplete(ref Resource r);
        
        /** Called whenever the resource finishes loading. 
        @remarks
            If a Resource has been marked as background loaded (@see Resource.setBackgroundLoaded), 
            the call does not itself occur in the thread which is doing the loading;
            when loading is complete a response indicator is placed with the
            ResourceGroupManager, which will then be sent back to the 
            listener as part of the application's primary frame loop thread.
        */
        void loadingComplete(ref Resource r);
        
        
        /** called whenever the resource finishes preparing (paging into memory).
        @remarks
            If a Resource has been marked as background loaded (@see Resource.setBackgroundLoaded)
            the call does not itself occur in the thread which is doing the preparing;
            when preparing is complete a response indicator is placed with the
            ResourceGroupManager, which will then be sent back to the 
            listener as part of the application's primary frame loop thread.
        */
        void preparingComplete(ref Resource r);
        
        /** Called whenever the resource has been unloaded. */
        void unloadingComplete(ref Resource r);
    }
    
    /// Enum identifying the loading state of the resource
    enum LoadingState
    {
        /// Not loaded
        UNLOADED,
        /// Loading is in progress
        LOADING,
        /// Fully loaded
        LOADED,
        /// Currently unloading
        UNLOADING,
        /// Fully prepared
        PREPARED,
        /// Preparing is in progress
        PREPARING
    }
protected:
    /// Creator
    ResourceManager mCreator;
    /// Unique name of the resource
    string mName;
    /// The name of the resource group
    string mGroup;
    /// Numeric handle for more efficient look up than name
    ResourceHandle mHandle;
    /// Is the resource currently loaded?
    AtomicScalar!LoadingState mLoadingState;
    /// Is this resource going to be background loaded? Only applicable for multithreaded
    //volatile
    shared bool mIsBackgroundLoaded;
    /// The size of the resource in bytes
    size_t mSize;
    /// Is this file manually loaded?
    bool mIsManual;
    /// Origin of this resource (e.g. script name) - optional
    string mOrigin;
    /// Optional manual loader; if provided, data is loaded from here instead of a file
    ManualResourceLoader mLoader;
    /// State count, the number of times this resource has changed state
    size_t mStateCount;
    
    alias Listener[] ListenerList;
    ListenerList mListenerList;
    //OGRE_MUTEX(mListenerListMutex)
    Mutex mListenerListMutex;
    
    /** Protected unnamed constructor to prevent default construction
    */
    this() 
    {
        //mCreator = null; 
        mLoader = null;
        mHandle = 0; mLoadingState.set(LoadingState.UNLOADED);
        mIsBackgroundLoaded = false; mSize = 0; 
        mIsManual = false; 
        mLock = new Mutex;
        mListenerListMutex = new Mutex;
    }
    
    /** Internal hook to perform actions before the load process, but
        after the resource has been marked as 'loading'.
    @note Mutex will have already been acquired by the loading thread.
        Also, this call will occur even when using a ManualResourceLoader 
        (when loadImpl is not actually called)
    */
    void preLoadImpl() {}
    /** Internal hook to perform actions after the load process, but
        before the resource has been marked as fully loaded.
    @note Mutex will have already been acquired by the loading thread.
        Also, this call will occur even when using a ManualResourceLoader 
        (when loadImpl is not actually called)
    */
    void postLoadImpl() {}
    
    /** Internal hook to perform actions before the unload process.
    @note Mutex will have already been acquired by the unloading thread.
    */
    void preUnloadImpl() {}
    /** Internal hook to perform actions after the unload process, but
    before the resource has been marked as fully unloaded.
    @note Mutex will have already been acquired by the unloading thread.
    */
    void postUnloadImpl() {}
    
    /** Internal implementation of the meat of the 'prepare' action. 
    */
    void prepareImpl() {}
    /** Internal function for undoing the 'prepare' action.  Called when
        the load is completed, and when resources are unloaded when they
        are prepared but not yet loaded.
    */
    void unprepareImpl() {}
    /** Internal implementation of the meat of the 'load' action, only called if this 
        resource is not being loaded from a ManualResourceLoader. 
    */
    abstract void loadImpl();
    /** Internal implementation of the 'unload' action; called regardless of
        whether this resource is being loaded from a ManualResourceLoader. 
    */
    abstract void unloadImpl();
    
public:
       
    /** Standard constructor.
    @param creator Pointer to the ResourceManager that is creating this resource
    @param name The unique name of the resource
    @param group The name of the resource group to which this resource belongs
    @param isManual Is this resource manually loaded? If so, you should really
        populate the loader parameter in order that the load process
        can call the loader back when loading is required. 
    @param loader Pointer to a ManualResourceLoader implementation which will be called
        when the Resource wishes to load (should be supplied if you set
        isManual to true). You can in fact leave this parameter null 
        if you wish, but the Resource will never be able to reload if 
        anything ever causes it to unload. Therefore provision of a proper
        ManualResourceLoader instance is strongly recommended.
    */
    this(ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, /+ref+/ ManualResourceLoader loader = null)
    {
        mCreator = creator; mName = name; mGroup = group; mHandle = handle; 
        mLoadingState.set(LoadingState.UNLOADED); 
        mIsBackgroundLoaded = false;
        mSize = 0; mIsManual = isManual; mLoader = loader; mStateCount = 0;
        mLock = new Mutex;
        mListenerListMutex = new Mutex;
    }
    
    /** destructor. Shouldn't need to be overloaded, as the resource
        deallocation code should reside in unload()
        @see
            Resource.unload()
    */
    ~this(){}
    
    /** Prepares the resource for load, if it is not already.  One can call prepare()
        before load(), but this is not required as load() will call prepare() 
        itself, if needed.  When OGRE_THREAD_SUPPORT==1 both load() and prepare() 
        are thread-safe.  When OGRE_THREAD_SUPPORT==2 however, only prepare() 
        is thread-safe.  The reason for this function is to allow a background 
        thread to do some of the loading work, without requiring the whole render
        system to be thread-safe.  The background thread would call
        prepare() while the main render loop would later call load().  So long as
        prepare() remains thread-safe, subclasses can arbitrarily split the work of
        loading a resource between load() and prepare().  It is best to try and
        do as much work in prepare(), however, since this will leave less work for
        the main render thread to do and thus increase FPS.
        @param backgroundThread Whether this is occurring in a background thread
    */
    void prepare(bool backgroundThread = false)
    {
        // quick check that avoids any synchronisation
        LoadingState old = mLoadingState.get();
        if (old != LoadingState.UNLOADED && old != LoadingState.PREPARING) return;
        
        // atomically do slower check to make absolutely sure,
        // and set the load state to PREPARING
        if (!mLoadingState.cas(LoadingState.UNLOADED,LoadingState.PREPARING))
        {
            synchronized(mLock)// aka mLock.lock();scope(exit) mLock.unlock();
            {
                while( mLoadingState.get() == LoadingState.PREPARING )//TODO Can it spin forever?
                {
                    //synchronized(mLock)
                }
            }
            
            LoadingState state = mLoadingState.get();
            if( state != LoadingState.PREPARED && state != LoadingState.LOADING && state != LoadingState.LOADED )
            {
                throw new InvalidParamsError( "Another thread failed in resource operation",
                                             "Resource.prepare");
            }
            return;
        }
        
        // Scope lock for actual loading
        try
        {
            
            //synchronized(mLock)
            synchronized(mLock)
            {
                if (mIsManual)
                {
                    if (mLoader)
                    {
                        mLoader.prepareResource(this);
                    }
                    else
                    {
                        // Warn that this resource is not reloadable
                        LogManager.getSingleton().stream(LML_TRIVIAL) 
                            << "WARNING: " << mCreator.getResourceType()  
                                << " instance '" << mName << "' was defined as manually "
                                << "loaded, but no manual loader was provided. This Resource "
                                << "will be lost if it has to be reloaded.";
                    }
                }
                else
                {
                    if (mGroup == ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME)
                    {
                        // Derive resource group
                        changeGroupOwnership(
                            ResourceGroupManager.getSingleton()
                            .findGroupContainingResource(mName));
                    }
                    prepareImpl();
                }
            }
        }
        catch(Exception e)
        {
            mLoadingState.set(LoadingState.UNLOADED);
            throw e;
        }
        
        mLoadingState.set(LoadingState.PREPARED);
        
        // Since we don't distinguish between GPU and CPU RAM, this
        // seems pointless
        //if(mCreator)
        //  mCreator._notifyResourcePrepared(this);
        
        // Fire events (if not background)
        if (!backgroundThread)
            _firePreparingComplete(false);
        
        
    }
    /** Loads the resource, if it is not already.
    @remarks
        If the resource is loaded from a file, loading is automatic. If not,
        if for example this resource gained it's data from procedural calls
        rather than loading from a file, then this resource will not reload 
        on it's own.
    @param backgroundThread Indicates whether the caller of this method is
        the background resource loading thread. 
        
    */
    void load(bool backgroundThread = false)
    {
        // Early-out without lock (mitigate perf cost of ensuring loaded)
        // Don't load if:
        // 1. We're already loaded
        // 2. Another thread is loading right now
        // 3. We're marked for background loading and this is not the background
        //    loading thread we're being called by
        
        if (mIsBackgroundLoaded && !backgroundThread) return;
        
        // This next section is to deal with cases where 2 threads are fighting over
        // who gets to prepare / load - this will only usually happen if loading is escalated
        bool keepChecking = true;
        LoadingState old = LoadingState.UNLOADED;
        while (keepChecking)
        {
            // quick check that avoids any synchronisation
            old = mLoadingState.get();
            
            if ( old == LoadingState.PREPARING )
            {
                synchronized(mLock)
                {
                    while( mLoadingState.get() == LoadingState.PREPARING )
                    {
                        //synchronized(mLock)
                    }
                }
                old = mLoadingState.get();
            }
            
            if (old!=LoadingState.UNLOADED && old!=LoadingState.PREPARED && old!=LoadingState.LOADING) return;
            
            // atomically do slower check to make absolutely sure,
            // and set the load state to LOADING
            if (old==LoadingState.LOADING || !mLoadingState.cas(old,LoadingState.LOADING))
            {
                synchronized(mLock)
                {
                    while( mLoadingState.get() == LoadingState.LOADING )
                    {
                        //synchronized(mLock)
                    }
                }
                
                LoadingState state = mLoadingState.get();
                if( state == LoadingState.PREPARED || state == LoadingState.PREPARING )
                {
                    // another thread is preparing, loop around
                    continue;
                }
                else if( state != LoadingState.LOADED )
                {
                    throw new InvalidParamsError( "Another thread failed in resource operation",
                                                 "Resource.load");
                }
                return;
            }
            keepChecking = false;
        }
        
        // Scope lock for actual loading
        try
        {
            
            //synchronized(mLock)
            synchronized(mLock)
            {
                if (mIsManual)
                {
                    preLoadImpl();
                    // Load from manual loader
                    if (mLoader)
                    {
                        debug(STDERR) std.stdio.stderr.writeln("Resource.load: manual loader by ", mLoader);
                        mLoader.loadResource(this);
                    }
                    else
                    {
                        // Warn that this resource is not reloadable
                        LogManager.getSingleton().stream(LML_TRIVIAL) 
                            << "WARNING: " << mCreator.getResourceType()  
                                << " instance '" << mName << "' was defined as manually "
                                << "loaded, but no manual loader was provided. This Resource "
                                << "will be lost if it has to be reloaded.";
                    }
                    postLoadImpl();
                }
                else
                {
                    
                    if (old==LoadingState.UNLOADED)
                        prepareImpl();
                    
                    preLoadImpl();
                    
                    if (mGroup == ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME)
                    {
                        // Derive resource group
                        changeGroupOwnership(
                            ResourceGroupManager.getSingleton()
                            .findGroupContainingResource(mName));
                    }
                    
                    loadImpl();
                    
                    postLoadImpl();
                }
                
                // Calculate resource size
                mSize = calculateSize();
            }
            
        }
        catch (Exception e)
        {
            // Reset loading in-progress flag, in case failed for some reason.
            // We reset it to UNLOADED because the only other case is when
            // old == PREPARED in which case the loadImpl should wipe out
            // any prepared data since it might be invalid.
            mLoadingState.set(LoadingState.UNLOADED);
            // Re-throw
            throw e;
        }
        
        mLoadingState.set(LoadingState.LOADED);
        _dirtyState();
        
        // Notify manager
        if(mCreator)
            mCreator._notifyResourceLoaded(this);
        
        // Fire events, if not background
        if (!backgroundThread)
            _fireLoadingComplete(false);
        
        
    }
    
    /** Reloads the resource, if it is already loaded.
    @remarks
        Calls unload() and then load() again, if the resource is already
        loaded. If it is not loaded already, then nothing happens.
    */
    void reload()
    { 
        //synchronized(mLock)
        synchronized(mLock)
        {
            if (mLoadingState.get() == LoadingState.LOADED)
            {
                unload();
                load();
            }
        }
    }
    
    /** Returns true if the Resource is reloadable, false otherwise.
    */
    bool isReloadable()
    {
        return !mIsManual || mLoader;
    }
    
    /** Is this resource manually loaded?
    */
    bool isManuallyLoaded()
    {
        return mIsManual;
    }
    
    /** Unloads the resource; this is not permanent, the resource can be
        reloaded later if required.
    */
    void unload()
    { 
        // Early-out without lock (mitigate perf cost of ensuring unloaded)
        LoadingState old = mLoadingState.get();
        if (old!=LoadingState.LOADED && old!=LoadingState.PREPARED) return;
        
        
        if (!mLoadingState.cas(old,LoadingState.UNLOADING)) return;
        
        // Scope lock for actual unload
        synchronized(mLock)
        {
            //synchronized(mLock)
            if (old==LoadingState.PREPARED) {
                unprepareImpl();
            } else {
                preUnloadImpl();
                unloadImpl();
                postUnloadImpl();
            }
        }
        
        mLoadingState.set(LoadingState.UNLOADED);
        
        // Notify manager
        // Note if we have gone from PREPARED to UNLOADED, then we haven't actually
        // unloaded, i.e. there is no memory freed on the GPU.
        if(old==LoadingState.LOADED && mCreator)
            mCreator._notifyResourceUnloaded(this);
        
        _fireUnloadingComplete();
        
        
    }
    
    /** Retrieves info about the size of the resource.
    */
    size_t getSize()
    { 
        return mSize; 
    }
    
    /** 'Touches' the resource to indicate it has been used.
    */
    void touch()
    {
        // make sure loaded
        load();
        
        if(mCreator)
            mCreator._notifyResourceTouched(this);
    }
    
    /** Gets resource name.
    */
    string getName()
    { 
        return mName; 
    }
    
    ResourceHandle getHandle()
    {
        return mHandle;
    }
    
    /** Returns true if the Resource has been prepared, false otherwise.
    */
    bool isPrepared()
    { 
        // No lock required to read this state since no modify
        return (mLoadingState.get() == LoadingState.PREPARED); 
    }
    
    /** Returns true if the Resource has been loaded, false otherwise.
    */
    bool isLoaded()
    { 
        // No lock required to read this state since no modify
        return (mLoadingState.get() == LoadingState.LOADED); 
    }
    
    /** Returns whether the resource is currently in the process of
        background loading.
    */
    bool isLoading()
    {
        return (mLoadingState.get() == LoadingState.LOADING);
    }
    
    /** Returns the current loading state.
    */
    LoadingState getLoadingState()
    {
        return mLoadingState.get();
    }
    
    
    
    /** Returns whether this Resource has been earmarked for background loading.
    @remarks
        This option only makes sense when you have built Ogre with 
        thread support (OGRE_THREAD_SUPPORT). If a resource has been marked
        for background loading, then it won't load on demand like normal
        when load() is called. Instead, it will ignore request to load()
        except if the caller indicates it is the background loader. Any
        other users of this resource should check isLoaded(), and if that
        returns false, don't use the resource and come back later.
    */
    bool isBackgroundLoaded(){ return mIsBackgroundLoaded; }
    
    /** Tells the resource whether it is background loaded or not.
    @remarks
        @see Resource.isBackgroundLoaded . Note that calling this only
        defers the normal on-demand loading behaviour of a resource, it
        does not actually set up a thread to make sure the resource gets
        loaded in the background. You should use ResourceBackgroundLoadingQueue
        to manage the actual loading (which will call this method itself).
    */
    void setBackgroundLoaded(bool bl) { mIsBackgroundLoaded = bl; }
    
    /** Escalates the loading of a background loaded resource. 
    @remarks
        If a resource is set to load in the background, but something needs
        it before it's been loaded, there could be a problem. If the user
        of this resource really can't wait, they can escalate the loading
        which basically pulls the loading into the current thread immediately.
        If the resource is already being loaded but just hasn't quite finished
        then this method will simply wait until the background load is complete.
    */
    void escalateLoading()
    {
        // Just call load as if this is the background thread, locking on
        // load status will prevent race conditions
        load(true);
        _fireLoadingComplete(true);
    }
    
    /** Register a listener on this resource.
        @see Resource.Listener
    */
    void addListener(Listener lis)
    {
        //OGRE_LOCK_MUTEX(mListenerListMutex)
        synchronized(mListenerListMutex)
        {
            mListenerList.insert(lis);
        }
    }
    
    /** Remove a listener on this resource.
        @see Resource.Listener
    */
    void removeListener(Listener lis)
    {
        // O(n) but not called very often
        //OGRE_LOCK_MUTEX(mListenerListMutex)
        synchronized(mListenerListMutex)
        {
            mListenerList.removeFromArray(lis);
        }
    }
    
    /// Gets the group which this resource is a member of
    string getGroup(){ return mGroup; }
    
    /** Change the resource group ownership of a Resource.
    @remarks
        This method is generally reserved for internal use, although
        if you really know what you're doing you can use it to move
        this resource from one group to another.
    @param newGroup Name of the new group
    */
    void changeGroupOwnership(string newGroup)
    {
        if (mGroup != newGroup)
        {
            string oldGroup = mGroup;
            mGroup = newGroup;
            ResourceGroupManager.getSingleton()
                ._notifyResourceGroupChanged(oldGroup, this);
        }
    }
    
    /// Gets the manager which created this resource
    ref ResourceManager getCreator() { return mCreator; }
    /** Get the origin of this resource, e.g. a script file name.
    @remarks
        This property will only contain something if the creator of
        this resource chose to populate it. Script loaders are advised
        to populate it.
    */
    string getOrigin(){ return mOrigin; }
    /// Notify this resource of it's origin
    void _notifyOrigin(string origin) { mOrigin = origin; }
    
    /** Returns the number of times this resource has changed state, which 
        generally means the number of times it has been loaded. Objects that 
        build derived data based on the resource can check this value against 
        a copy they kept last time they built this derived data, in order to
        know whether it needs rebuilding. This is a nice way of monitoring
        changes without having a tightly-bound callback.
    */
    size_t getStateCount(){ return mStateCount; }
    
    /** Manually mark the state of this resource as having been changed.
    @remarks
        You only need to call this from outside if you explicitly want derived
        objects to think this object has changed. @see getStateCount.
    */
    void _dirtyState()
    {
        // don't worry about threading here, count only ever increases so 
        // doesn't matter if we get a lost increment (one is enough)
        ++mStateCount;  
    }
    
    
    /** Firing of loading complete event
    @remarks
        You should call this from the thread that runs the main frame loop 
        to avoid having to make the receivers of this event thread-safe.
        If you use Ogre's built in frame loop you don't need to call this
        yourself.
        @param wasBackgroundLoaded Whether this was a background loaded event
    */
    void _fireLoadingComplete(bool wasBackgroundLoaded)
    {
        // Lock the listener list
        //OGRE_LOCK_MUTEX(mListenerListMutex)
        synchronized(mListenerListMutex)
        {
            foreach (i; mListenerList)
            {
                // deprecated call
                if (wasBackgroundLoaded)
                    i.backgroundLoadingComplete(this);
                
                i.loadingComplete(this);
            }
        }
    }
    
    /** Firing of preparing complete event
    @remarks
        You should call this from the thread that runs the main frame loop 
        to avoid having to make the receivers of this event thread-safe.
        If you use Ogre's built in frame loop you don't need to call this
        yourself.
        @param wasBackgroundLoaded Whether this was a background loaded event
    */
    void _firePreparingComplete(bool wasBackgroundLoaded)
    {
        // Lock the listener list
        //OGRE_LOCK_MUTEX(mListenerListMutex)
        synchronized(mListenerListMutex)
        {
            foreach (i; mListenerList)
            {
                // deprecated call
                if (wasBackgroundLoaded)
                    i.backgroundPreparingComplete(this);
                
                i.preparingComplete(this);
                
            }
        }
    }
    
    /** Firing of unloading complete event
    @remarks
    You should call this from the thread that runs the main frame loop 
    to avoid having to make the receivers of this event thread-safe.
    If you use Ogre's built in frame loop you don't need to call this
    yourself.
    */
    void _fireUnloadingComplete()
    {
        // Lock the listener list
        //OGRE_LOCK_MUTEX(mListenerListMutex)
        synchronized(mListenerListMutex)
        {
            foreach (i; mListenerList)
            {
                
                i.unloadingComplete(this);
                
            }
        }
    }
    
    /** Calculate the size of a resource; this will only be called after 'load' */
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        memSize += ResourceManager.sizeof;//FIXME well, always 4/8 bytes
        memSize += ManualResourceLoader.sizeof;
        memSize += ResourceHandle.sizeof;
        memSize += mName.length * char.sizeof;
        memSize += mGroup.length * char.sizeof;
        memSize += mOrigin.length * char.sizeof;
        memSize += size_t.sizeof * 2;
        memSize += bool.sizeof * 2;
        memSize += Listener.sizeof * mListenerList.length;
        memSize += (AtomicScalar!LoadingState).sizeof;
        
        return memSize;
    }
}

/** Shared pointer to a Resource.
@remarks
    This shared pointer allows many references to a resource to be held, and
    when the final reference is removed, the resource will be destroyed. 
    Note that the ResourceManager which created this Resource will be holding
    at least one reference, so this resource will not get destroyed until 
    someone removes the resource from the manager - this at least gives you
    strong control over when resources are freed. But the nature of the 
    shared pointer means that if anyone ref ers to the removed resource in the
    meantime, the resource will remain valid.
@par
    You may well see references to SharedPtr!Resource (i.e. SharedPtr!Resource&) being passed 
    around internally within Ogre. These are 'weak references' ie they do 
    not increment the reference count on the Resource. This is done for 
    efficiency in temporary operations that shouldn't need to incur the 
    overhead of maintaining the reference count; however we don't recommend 
    you do it yourself since these references are not guaranteed to remain valid.
*/

//alias SharedPtr!Resource ResourcePtr;
//alias Resource SharedPtr!Resource;

/** Interface describing a manual resource loader.
@remarks
    Resources are usually loaded from files; however in some cases you
    want to be able to set the data up manually instead. This provides
    some problems, such as how to reload a Resource if it becomes
    unloaded for some reason, either because of memoryraints, or
    because a device fails and some or all of the data is lost.
@par
    This interface should be implemented by all classes which wish to
    provide manual data to a resource. They provide a pointer to themselves
    when defining the resource (via the appropriate ResourceManager), 
    and will be called when the Resource tries to load. 
    They should implement the loadResource method such that the Resource 
    is in the end set up exactly as if it had loaded from a file, 
    although the implementations will likely differ between subclasses 
    of Resource, which is why no generic algorithm can be stated here. 
@note
    The loader must remain valid for the entire life of the resource,
    so that if need be it can be called upon to re-load the resource
    at any time.
*/
interface ManualResourceLoader
{
    template Impl()
    {
        void prepareResource(ref Resource resource){}
        void loadResource(ref Resource resource){}
    }
    /** Called when a resource wishes to load.  Note that this could get
     * called in a background thread even in just a semithreaded ogre
     * (OGRE_THREAD_SUPPORT==2).  Thus, you must not access the rendersystem from
     * this callback.  Do that stuff in loadResource.
    @param resource The resource which wishes to load
    */
    void prepareResource(ref Resource resource);
    
    /** Called when a resource wishes to prepare.
    @param resource The resource which wishes to prepare
    */
    void loadResource(ref Resource resource);
}


//alias SharedPtr ResourceSubclassPtr;
