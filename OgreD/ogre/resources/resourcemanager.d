module ogre.resources.resourcemanager;

import core.sync.mutex;
import ogre.general.generals;
import ogre.general.common;
import ogre.compat;
import ogre.sharedptr;
import ogre.general.atomicwrappers;
import ogre.resources.resourcegroupmanager;
import ogre.exception;
import ogre.resources.resource;
import ogre.resources.datastream;

/** Defines a generic resource handler.
 @remarks
 A resource manager is responsible for managing a pool of
 resources of a particular type. It must index them, look
 them up, load and destroy them. It may also need to stay within
 a defined memory budget, and temporarily unload some resources
 if it needs to to stay within this budget.
 @par
 Resource managers use a priority system to determine what can
 be unloaded, and a Least Recently Used (LRU) policy within
 resources of the same priority.
 @par
 Resources can be loaded using the generalised load interface,
 and they can be unloaded and removed. In addition, each 
 subclass of ResourceManager will likely define custom 'load' methods
 which take explicit parameters depending on the kind of resource
 being created.
 @note
 Resources can be loaded and unloaded through the Resource class, 
 but they can only be removed (and thus eventually destroyed) using
 their parent ResourceManager.
 @note
 If OGRE_THREAD_SUPPORT is 1, this class is thread-safe.
 */
class ResourceManager : ScriptLoader//, public ResourceAlloc
{
    invariant()
    {
        assert(mLock !is null);
    }
    
public:
    //OGRE_AUTO_MUTEX // public to allow external locking
    Mutex mLock;
    this()
    {
        mNextHandle = 1; mMemoryUsage.set(0); mVerbose = true; mLoadOrder = 0;
        // Init memory limit & usage
        mMemoryBudget = size_t.max;//ulong
        mLock = new Mutex;
    }
    ~this()
    {
        destroyAllResourcePools();
        removeAll();
    }
    
    /** Creates a new blank resource, but does not immediately load it.
     @remarks
     Resource managers handle disparate types of resources, so if you want
     to get at the detailed interface of this resource, you'll have to 
     cast the result to the subclass you know you're creating. 
     @param name The unique name of the resource
     @param group The name of the resource group to attach this new resource to
     @param isManual Is this resource manually loaded? If so, you should really
     populate the loader parameter in order that the load process
     can call the loader back when loading is required. 
     @param loader Pointer to a ManualLoader implementation which will be called
     when the Resource wishes to load (should be supplied if you set
     isManual to true). You can in fact leave this parameter null 
     if you wish, but the Resource will never be able to reload if 
     anything ever causes it to unload. Therefore provision of a proper
     ManualLoader instance is strongly recommended.
     @param createParams If any parameters are required to create an instance,
     they should be supplied here as name / value pairs
     */
    SharedPtr!Resource create(string name, string group, 
                       bool isManual = false, ManualResourceLoader loader = null, 
                       NameValuePairList params = null)
    {
        // Call creation implementation
        SharedPtr!Resource ret = SharedPtr!Resource(
            createImpl(name, getNextHandle(), group, isManual, loader, params));
        //debug(STDERR) std.stdio.stderr.writeln(__FILE__,": ",__LINE__,":", ret, " ", ret.isNull());
        if (!params.emptyAA())
            ret.get().setParameterList(params);
        
        //if(!ret.isNull())
        //    debug(STDERR) std.stdio.stderr.writeln(__FILE__,": ",__LINE__,":", ret);
        addImpl(ret);
        // Tell resource group manager
        ResourceGroupManager.getSingleton()._notifyResourceCreated(ret);
        return ret;
        
    }
    
    alias pair!(SharedPtr!Resource, bool) ResourceCreateOrRetrieveResult;
    /** Create a new resource, or retrieve an existing one with the same
     name if it already exists.
     @remarks
     This method performs the same task as calling getByName() followed
     by create() if that returns null. The advantage is that it does it
     in one call so there are no race conditions if using multiple
     threads that could cause getByName() to return null, but create() to
     fail because another thread created a resource in between.
     @see ResourceManager.create
     @see ResourceManager.getByName
     @return A pair, the first element being the pointer, and the second being 
     an indicator specifying whether the resource was newly created.
     */
    ResourceCreateOrRetrieveResult createOrRetrieve(string name, 
                                                    string group, bool isManual = false, 
                                                    ManualResourceLoader loader = null, 
                                                    NameValuePairList createParams = null)
    {
        // Lock for the whole get / insert
        synchronized(mLock)
        {
            SharedPtr!Resource res = getByName(name, group);
            bool created = false;
            if (res.isNull())
            {
                created = true;
                res = create(name, group, isManual, loader, createParams);
            }
            
            return ResourceCreateOrRetrieveResult(res, created);
        }
    }
    
    /** Set a limit on the amount of memory this resource handler may use.
     @remarks
     If, when asked to load a new resource, the manager believes it will exceed this memory
     budget, it will temporarily unload a resource to make room for the new one. This unloading
     is not permanent and the Resource is not destroyed; it simply needs to be reloaded when
     next used.
     */
    void setMemoryBudget( size_t bytes)
    {
        // Update limit & check usage
        mMemoryBudget = bytes;
        checkUsage();
    }
    
    /** Get the limit on the amount of memory this resource handler may use.
     */
    size_t getMemoryBudget()
    {
        return mMemoryBudget;
    }
    
    /** Gets the current memory usage, in bytes. */
    size_t getMemoryUsage(){ return mMemoryUsage.get(); }
    
    /** Unloads a single resource by name.
     @remarks
     Unloaded resources are not removed, they simply free up their memory
     as much as they can and wait to be reloaded.
     @see ResourceGroupManager for unloading of resource groups.
     */
    void unload(string name)
    {
        SharedPtr!Resource res = getByName(name);
        
        if (!res.isNull())
        {
            // Unload resource
            res.get().unload();
            
        }
    }
    
    /** Unloads a single resource by handle.
     @remarks
     Unloaded resources are not removed, they simply free up their memory
     as much as they can and wait to be reloaded.
     @see ResourceGroupManager for unloading of resource groups.
     */
    void unload(ResourceHandle handle)
    {
        SharedPtr!Resource res = getByHandle(handle);
        
        if (!res.isNull())
        {
            // Unload resource
            res.get().unload();
            
        }
    }
    
    /** Unloads all resources.
     @remarks
     Unloaded resources are not removed, they simply free up their memory
     as much as they can and wait to be reloaded.
     @see ResourceGroupManager for unloading of resource groups.
     @param reloadableOnly If true (the default), only unload the resource that
     is reloadable. Because some resources isn't reloadable, they will be
     unloaded but can't load them later. Thus, you might not want to them
     unloaded. Or, you might unload all of them, and then populate them
     manually later.
     @see Resource.isReloadable for resource is reloadable.
     */
    void unloadAll(bool reloadableOnly = true)
    {
        synchronized(mLock)
        {
            foreach (k,v; mResources)
            {
                if (!reloadableOnly || v.get().isReloadable())
                {
                    v.get().unload();
                }
            }
        }
    }
    
    /** Caused all currently loaded resources to be reloaded.
     @remarks
     All resources currently being held in this manager which are also
     marked as currently loaded will be unloaded, then loaded again.
     @param reloadableOnly If true (the default), only reload the resource that
     is reloadable. Because some resources isn't reloadable, they will be
     unloaded but can't loaded again. Thus, you might not want to them
     unloaded. Or, you might unload all of them, and then populate them
     manually later.
     @see Resource.isReloadable for resource is reloadable.
     */
    void reloadAll(bool reloadableOnly = true)
    {
        synchronized(mLock)
        {
            foreach (k,v; mResources)
            {
                if (!reloadableOnly || v.get().isReloadable())
                {
                    v.get().reload();
                }
            }
        }
        
    }
    
    /** Unload all resources which are not referenced by any other object.
     @remarks
     This method behaves like unloadAll, except that it only unloads resources
     which are not in use, ie not referenced by other objects. This allows you
     to free up some memory selectively whilst still keeping the group around
     (and the resources present, just not using much memory).
     @par
     Some referenced resource may exists 'weak' pointer to their sub-components
     (e.g. Entity held pointer to SubMesh), in this case, unload or reload that
     resource will cause dangerous pointer access. Use this function instead of
     unloadAll allows you avoid fail in those situations.
     @param reloadableOnly If true (the default), only unloads resources
     which can be subsequently automatically reloaded.
     */
    void unloadUnreferencedResources(bool reloadableOnly = true)
    {
        synchronized(mLock)
        {
            foreach (k, v; mResources)
            {
                // A use count of 3 means that only RGM and RM have references
                // RGM has one (this one) and RM has 2 (by name and by handle)
                if (v.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS)
                {
                    auto res = v.get();
                    if (!reloadableOnly || res.isReloadable())
                    {
                        res.unload();
                    }
                }
            }
        }
    }
    
    /** Caused all currently loaded but not referenced by any other object
     resources to be reloaded.
     @remarks
     This method behaves like reloadAll, except that it only reloads resources
     which are not in use, i.e. not referenced by other objects.
     @par
     Some referenced resource may exists 'weak' pointer to their sub-components
     (e.g. Entity held pointer to SubMesh), in this case, unload or reload that
     resource will cause dangerous pointer access. Use this function instead of
     reloadAll allows you avoid fail in those situations.
     @param reloadableOnly If true (the default), only reloads resources
     which can be subsequently automatically reloaded.
     */
    void reloadUnreferencedResources(bool reloadableOnly = true)
    {
        synchronized(mLock)
        {
            foreach (k,v; mResources)
            {
                // A use count of 3 means that only RGM and RM have references
                // RGM has one (this one) and RM has 2 (by name and by handle)
                if (v.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS)
                {
                    auto res = v.get();
                    if (!reloadableOnly || res.isReloadable())
                    {
                        res.reload();
                    }
                }
            }
        }
    }
    
    /** Remove a single resource.
     @remarks
     Removes a single resource, meaning it will be removed from the list
     of valid resources in this manager, also causing it to be unloaded. 
     @note
     The word 'Destroy' is not used here, since
     if any other pointers are ref erring to this resource, it will persist
     until they have finished with it; however to all intents and purposes
     it no longer exists and will likely get destroyed imminently.
     @note
     If you do have shared pointers to resources hanging around after the 
     ResourceManager is destroyed, you may get problems on destruction of
     these resources if they were relying on the manager (especially if
     it is a plugin). If you find you get problems on shutdown in the
     destruction of resources, try making sure you release all your
     shared pointers before you shutdown OGRE.
     */
    void remove(ref SharedPtr!Resource r)
    {
        removeImpl(r);
    }
    
    /** Remove a single resource by name.
     @remarks
     Removes a single resource, meaning it will be removed from the list
     of valid resources in this manager, also causing it to be unloaded. 
     @note
     The word 'Destroy' is not used here, since
     if any other pointers are ref erring to this resource, it will persist
     until they have finished with it; however to all intents and purposes
     it no longer exists and will likely get destroyed imminently.
     @note
     If you do have shared pointers to resources hanging around after the 
     ResourceManager is destroyed, you may get problems on destruction of
     these resources if they were relying on the manager (especially if
     it is a plugin). If you find you get problems on shutdown in the
     destruction of resources, try making sure you release all your
     shared pointers before you shutdown OGRE.
     */
    void remove(string name)
    {
        SharedPtr!Resource res = getByName(name);
        
        if (!res.isNull())
        {
            removeImpl(res);
        }
    }
    
    /** Remove a single resource by handle.
     @remarks
     Removes a single resource, meaning it will be removed from the list
     of valid resources in this manager, also causing it to be unloaded. 
     @note
     The word 'Destroy' is not used here, since
     if any other pointers are ref erring to this resource, it will persist
     until they have finished with it; however to all intents and purposes
     it no longer exists and will likely get destroyed imminently.
     @note
     If you do have shared pointers to resources hanging around after the 
     ResourceManager is destroyed, you may get problems on destruction of
     these resources if they were relying on the manager (especially if
     it is a plugin). If you find you get problems on shutdown in the
     destruction of resources, try making sure you release all your
     shared pointers before you shutdown OGRE.
     */
    void remove(ResourceHandle handle)
    {
        SharedPtr!Resource res = getByHandle(handle);
        
        if (!res.isNull())
        {
            removeImpl(res);
        }
    }
    /** Removes all resources.
     @note
     The word 'Destroy' is not used here, since
     if any other pointers are ref erring to these resources, they will persist
     until they have been finished with; however to all intents and purposes
     the resources no longer exist and will get destroyed imminently.
     @note
     If you do have shared pointers to resources hanging around after the 
     ResourceManager is destroyed, you may get problems on destruction of
     these resources if they were relying on the manager (especially if
     it is a plugin). If you find you get problems on shutdown in the
     destruction of resources, try making sure you release all your
     shared pointers before you shutdown OGRE.
     */
    void removeAll()
    {
        synchronized(mLock)
        {
            mResources.clear();
            mResourcesWithGroup.clear();
            mResourcesByHandle.clear();
            // Notify resource group manager
            ResourceGroupManager.getSingleton()._notifyAllResourcesRemoved(this);
        }
    }
    
    /** Remove all resources which are not referenced by any other object.
     @remarks
     This method behaves like removeAll, except that it only removes resources
     which are not in use, ie not referenced by other objects. This allows you
     to free up some memory selectively whilst still keeping the group around
     (and the resources present, just not using much memory).
     @par
     Some referenced resource may exists 'weak' pointer to their sub-components
     (e.g. Entity held pointer to SubMesh), in this case, remove or reload that
     resource will cause dangerous pointer access. Use this function instead of
     removeAll allows you avoid fail in those situations.
     @param reloadableOnly If true (the default), only removes resources
     which can be subsequently automatically reloaded.
     */
    void removeUnreferencedResources(bool reloadableOnly = true)
    {
        synchronized(mLock)
        {
            foreach (k,v; mResources)
            {
                // A use count of 3 means that only RGM and RM have references
                // RGM has one (this one) and RM has 2 (by name and by handle)
                if (v.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS)
                {
                    Resource res = v.get();
                    if (!reloadableOnly || res.isReloadable())
                    {
                        remove( res.getHandle() );
                    }
                }
            }
        }
    }
    
    /** Retrieves a pointer to a resource by name, or null if the resource does not exist.
     */
    SharedPtr!Resource getByName(string name, string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME)
    {       
        SharedPtr!Resource res;
        
        // if not in the global pool - get it from the grouped pool 
        if(!ResourceGroupManager.getSingleton().isResourceGroupInGlobalPool(groupName))
        {
            synchronized(mLock)
            {
                auto itGroup = groupName in mResourcesWithGroup;
                
                if( itGroup !is null)
                {
                    auto it = name in (*itGroup);
                    
                    if( it !is null)
                    {
                        res = *it;
                    }
                }
            }
        }
        
        // if didn't find it the grouped pool - get it from the global pool 
        if (res.isNull())
        {
            synchronized(mLock)
            {
                auto it = name in mResources;
                
                if( it !is null)
                {
                    res = *it;
                }
                else
                {
                    // this is the case when we need to search also in the grouped hash
                    if (groupName == ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME)
                    {
                        foreach (k, v; mResourcesWithGroup)
                        {
                            auto resMapIt = name in v;
                            
                            if( resMapIt !is null)
                            {
                                res = *resMapIt;
                                break;
                            }
                        }
                    }
                }
            }
        }
        
        return res;
    }
    /** Retrieves a pointer to a resource by handle, or null if the resource does not exist.
     */
    SharedPtr!Resource getByHandle(ResourceHandle handle)
    {
        synchronized(mLock)
        {
            auto it = handle in mResourcesByHandle;
            if (it is null)
            {
                return SharedPtr!Resource();
            }
            else
            {
                return *it;
            }
        }
    }
    
    /// Returns whether the named resource exists in this manager
    bool resourceExists(string name)
    {
        return !getByName(name).isNull();
    }
    /// Returns whether a resource with the given handle exists in this manager
    bool resourceExists(ResourceHandle handle)
    {
        return !getByHandle(handle).isNull();
    }
    
    /** Notify this manager that a resource which it manages has been 
     'touched', i.e. used. 
     */
    void _notifyResourceTouched(Resource res)
    {
        // TODO
    }
    
    /** Notify this manager that a resource which it manages has been 
     loaded. 
     */
    void _notifyResourceLoaded(Resource res)
    {
        mMemoryUsage += res.getSize();
        checkUsage();
    }
    
    /** Notify this manager that a resource which it manages has been 
     unloaded.
     */
    void _notifyResourceUnloaded(Resource res)
    {
        mMemoryUsage -= res.getSize();
    }
    
    /** Generic prepare method, used to create a Resource specific to this 
     ResourceManager without using one of the specialised 'prepare' methods
     (containing per-Resource-type parameters).
     @param name The name of the Resource
     @param group The resource group to which this resource will belong
     @param isManual Is the resource to be manually loaded? If so, you should
     provide a value for the loader parameter
     @param loader The manual loader which is to perform the required actions
     when this resource is loaded; only applicable when you specify true
     for the previous parameter
     @param loadParams Optional pointer to a list of name/value pairs 
     containing loading parameters for this type of resource.
     @param backgroundThread Optional boolean which lets the load routine know if it
     is being run on the background resource loading thread
     */
    SharedPtr!Resource prepare(string name, 
                        string group, bool isManual = false, 
                        ManualResourceLoader loader = null,NameValuePairList loadParams = null,
                        bool backgroundThread = false)
    {
        SharedPtr!Resource r = createOrRetrieve(name,group,isManual,loader,loadParams).first;
        // ensure prepared
        r.get().prepare(backgroundThread);
        return r;
    }
    
    /** Generic load method, used to create a Resource specific to this 
     ResourceManager without using one of the specialised 'load' methods
     (containing per-Resource-type parameters).
     @param name The name of the Resource
     @param group The resource group to which this resource will belong
     @param isManual Is the resource to be manually loaded? If so, you should
     provide a value for the loader parameter
     @param loader The manual loader which is to perform the required actions
     when this resource is loaded; only applicable when you specify true
     for the previous parameter
     @param loadParams Optional pointer to a list of name/value pairs 
     containing loading parameters for this type of resource.
     @param backgroundThread Optional boolean which lets the load routine know if it
     is being run on the background resource loading thread
     */
    SharedPtr!Resource load(string name, 
                     string group, bool isManual = false, 
                     ManualResourceLoader loader = null,NameValuePairList loadParams = null,
                     bool backgroundThread = false)
    {
        SharedPtr!Resource r = createOrRetrieve(name,group,isManual,loader,loadParams).first;
        // ensure loaded
        r.get().load(backgroundThread);
        return r;
    }
    
    /** Gets the file patterns which should be used to find scripts for this
     ResourceManager.
     @remarks
     Some resource managers can read script files in order to define
     resources ahead of time. These resources are added to the available
     list inside the manager, but none are loaded initially. This allows
     you to load the items that are used on demand, or to load them all 
     as a group if you wish (through ResourceGroupManager).
     @par
     This method lets you determine the file pattern which will be used
     to identify scripts intended for this manager.
     @return
     A list of file patterns, in the order they should be searched in.
     @see isScriptingSupported, parseScript
     */
    ref StringVector getScriptPatterns(){ return mScriptPatterns; }
    
    /** Parse the definition of a set of resources from a script file.
     @remarks
     Some resource managers can read script files in order to define
     resources ahead of time. These resources are added to the available
     list inside the manager, but none are loaded initially. This allows
     you to load the items that are used on demand, or to load them all 
     as a group if you wish (through ResourceGroupManager).
     @param stream Weak reference to a data stream which is the source of the script
     @param groupName The name of the resource group that resources which are
     parsed are to become a member of. If this group is loaded or unloaded, 
     then the resources discovered in this script will be loaded / unloaded
     with it.
     */
    void parseScript(DataStreamPtr stream, string groupName) {}
    
    /** Gets the relative loading order of resources of this type.
     @remarks
     There are dependencies between some kinds of resource in terms of loading
     order, and this value enumerates that. Higher values load later during
     bulk loading tasks.
     */
    Real getLoadingOrder(){ return mLoadOrder; }
    
    /** Gets a string identifying the type of resource this manager handles. */
    string getResourceType(){ return mResourceType; }
    
    /** Sets whether this manager and its resources habitually produce log output */
    void setVerbose(bool v) { mVerbose = v; }
    
    /** Gets whether this manager and its resources habitually produce log output */
    bool getVerbose() { return mVerbose; }
    
    /** Definition of a pool of resources, which users can use to reuse similar
     resources many times without destroying and recreating them.
     @remarks
     This is a simple utility class which allows the reuse of resources
     between code which has a changing need for them. For example, 
     */
    class ResourcePool : Pool!(SharedPtr!Resource)//, public ResourceAlloc
    {
    protected:
        string mName;
    public:
        this(string name)
        {
            super();
            mName = name;
        }
        ~this(){}
        /// Get the name of the pool
        string getName()
        {
            return mName;
        }
        override void clear()
        {
            synchronized(mLock)
            {
                foreach (i; mItems)
                {
                    i.get().getCreator().remove(i.get().getHandle());
                }
                mItems.clear();
            }
        }
    }
    
    /// Create a resource pool, or reuse one that already exists
    ResourcePool getResourcePool(string name)
    {
        synchronized(mLock)
        {
            auto i = name in mResourcePoolMap;
            if (i is null)
            {
                auto r = new ResourcePool(name);
                mResourcePoolMap[name] = r;
                return mResourcePoolMap[name];
            }
            return *i;
        }
    }
    /// Destroy a resource pool
    void destroyResourcePool(ResourcePool pool)
    {
        synchronized(mLock)
        {
            auto i = pool.getName() in mResourcePoolMap;
            if (i !is null)
                mResourcePoolMap.remove(pool.getName());
            
            destroy(pool);
        }
    }
    /// Destroy a resource pool
    void destroyResourcePool(string name)
    {
        synchronized(mLock)
        {
            auto i = name in mResourcePoolMap;
            if (i !is null)
            {
                mResourcePoolMap.remove(name);
                destroy(*i);
            }
        }
        
    }
    /// destroy all pools
    void destroyAllResourcePools()
    {
        synchronized(mLock)
        {
            foreach (k, v; mResourcePoolMap)
                destroy(v);
            
            mResourcePoolMap.clear();
        }
        
    }
    
    
    
    
protected:
    
    /** Allocates the next handle. */
    ResourceHandle getNextHandle()
    {
        //TODO This is an atomic operation and hence needs no locking
        //synchronized(mLock)
        {
            return mNextHandle++;
        }
    }
    
    /** Create a new resource instance compatible with this manager (no custom 
     parameters are populated at this point). 
     @remarks
     Subclasses must override this method and create a subclass of Resource.
     @param name The unique name of the resource
     @param group The name of the resource group to attach this new resource to
     @param isManual Is this resource manually loaded? If so, you should really
     populate the loader parameter in order that the load process
     can call the loader back when loading is required. 
     @param loader Pointer to a ManualLoader implementation which will be called
     when the Resource wishes to load (should be supplied if you set
     isManual to true). You can in fact leave this parameter null 
     if you wish, but the Resource will never be able to reload if 
     anything ever causes it to unload. Therefore provision of a proper
     ManualLoader instance is strongly recommended.
     @param createParams If any parameters are required to create an instance,
     they should be supplied here as name / value pairs. These do not need 
     to be set on the instance (handled elsewhere), just used if required
     to differentiate which concrete class is created.

     */
    // ManualResourceLoader pointer so we can set default to null, because null is not lvalue
    abstract Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams);
    
    /** Add a newly created resource to the manager (note weak reference) */
    void addImpl( SharedPtr!Resource res )
    {
        synchronized(mLock)
        {
            //pair!(ResourceMap.iterator, bool) result;
            bool result = false;
            debug(STDERR) std.stdio.stderr.writeln(__FILE__,":",__LINE__,":",res.get());
            debug(STDERR) std.stdio.stderr.writeln(__FILE__,":",__LINE__,":",res.get().getGroup());
            
            if(ResourceGroupManager.getSingleton().isResourceGroupInGlobalPool(res.get().getGroup()))
            {
                if( (res.get().getName() in mResources) is null)
                {
                    mResources[res.get().getName()] = res;
                    result = true;
                }
                else
                    result = false; //Resource with same name exists, resolve collision below
            }
            else
            {
                auto itGroup = res.get().getGroup() in mResourcesWithGroup;
                
                // we will create the group if it doesn't exists in our list
                if( itGroup is null)
                {
                    ResourceMap dummy;
                    mResourcesWithGroup[res.get().getGroup()] = dummy;
                    itGroup = res.get().getGroup() in mResourcesWithGroup;
                }
                
                if( (res.get().getName() in mResourcesWithGroup[res.get().getGroup()]) is null)
                {
                    (*itGroup)[res.get().getName()] = res;
                    result = true;
                }
                else
                    result = false; //Resource with same name exists, resolve collision below
            }
            
            if (!result)
            {
                // Attempt to resolve the collision
                if(ResourceGroupManager.getSingleton().getLoadingListener())
                {
                    if(ResourceGroupManager.getSingleton().getLoadingListener().resourceCollision(res.get(), this))
                    {
                        // Try to do the addition again, no seconds attempts to resolve collisions are allowed
                        //std.pair<ResourceMap.iterator, bool> insertResult;
                        bool insertResult = false;
                        if(ResourceGroupManager.getSingleton().isResourceGroupInGlobalPool(res.get().getGroup()))
                        {
                            if((res.get().getName() in mResources) is null) 
                            {
                                mResources[res.get().getName()] = res;
                                insertResult = true;
                            }
                            else
                                insertResult = false;
                        }
                        else
                        {
                            auto itGroup = res.get().getGroup() in mResourcesWithGroup;
                            if((res.get().getName() in (*itGroup)) is null) 
                            {
                                (*itGroup)[res.get().getName()] = res;
                                insertResult = true;
                            }
                            else
                                insertResult = false;
                        }
                        if (!insertResult)
                        {
                            throw new DuplicateItemError( "Resource with the name " ~ res.get().getName() ~ 
                                                         " already exists.", "ResourceManager.add");
                        }
                        
                        bool resultHandle = true;
                        if((res.get().getHandle() in mResourcesByHandle) !is null)
                            resultHandle = false;
                        else
                            mResourcesByHandle[res.get().getHandle()] = res;
                        
                        if (!resultHandle)
                        {
                            throw new DuplicateItemError("Resource with the handle " ~
                                                         std.conv.to!string(res.get().getHandle()) ~ 
                                                         " already exists.", "ResourceManager.add");
                        }
                    }
                }
            }
            else
            {
                // Insert the handle
                //std.pair<ResourceHandleMap.iterator, bool> resultHandle = 
                //    mResourcesByHandle.insert( ResourceHandleMap.value_type( res.getHandle(), res ) );
                
                debug(STDERR) std.stdio.stderr.writeln("Resource is null: ", res.get() is null);
                debug(STDERR) std.stdio.stderr.writeln("Resource is : ", res.get());
                //mResourcesByHandle[res.get().getHandle()] = res;
                bool resultHandle = true;
                if((res.get().getHandle() in mResourcesByHandle) !is null)
                    resultHandle = false;
                if (!resultHandle)
                {
                    throw new DuplicateItemError("Resource with the handle " ~
                                                 std.conv.to!string(res.get().getHandle()) ~ 
                                                 " already exists.", "ResourceManager.add");
                }
                else
                    mResourcesByHandle[res.get().getHandle()] = res;
            }
        }
    }
    /** Remove a resource from this manager; remove it from the lists. */
    void removeImpl( ref SharedPtr!Resource res )
    {
        synchronized(mLock)
        {
            if(ResourceGroupManager.getSingleton().isResourceGroupInGlobalPool(res.get().getGroup()))
            {
                auto nameIt = res.get().getName() in mResources;
                if (nameIt !is null)
                {
                    mResources.remove(res.get().getName());
                }
            }
            else
            {
                auto groupIt = res.get().getGroup() in mResourcesWithGroup;
                if (groupIt !is null)
                {
                    auto nameIt = res.get().getName() in (*groupIt);
                    if (nameIt !is null)
                    {
                        (*groupIt).remove(res.get().getName());
                    }
                    
                    if ((*groupIt).length == 0)
                    {
                        mResourcesWithGroup.remove(res.get().getGroup());
                    }
                }
            }
            
            auto handleIt = res.get().getHandle() in mResourcesByHandle;
            if (handleIt !is null)
            {
                mResourcesByHandle.remove(res.get().getHandle());
            }
            // Tell resource group manager
            ResourceGroupManager.getSingleton()._notifyResourceRemoved(res);
        }
    }
    
    /** Checks memory usage and pages out if required.
     */
    void checkUsage()
    {
        //FIXME D version is inaccurate probably
        if (getMemoryUsage() > mMemoryBudget)
        {
            synchronized(mLock)
            {
                // unload unreferenced resources until we are within our budget again
                //const
                enum bool reloadableOnly = true;
                foreach (k, v; mResources)
                {
                    if(getMemoryUsage() < mMemoryBudget)
                        break;
                    
                    // FIXME Proper D version of ref counting
                    // A use count of 3 means that only RGM and RM have references
                    // RGM has one (this one) and RM has 2 (by name and by handle)
                    if (v.useCount() == ResourceGroupManager.RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS)
                    {
                        Resource res = v.get();
                        if (!reloadableOnly || res.isReloadable())
                        {
                            res.unload();
                        }
                    }
                }
            }
        }
    }
    
    
public:
    //typedef HashMap< string, SharedPtr!Resource > ResourceMap;
    alias SharedPtr!Resource[string] ResourceMap;
    //typedef HashMap< string, ResourceMap > ResourceWithGroupMap;
    alias ResourceMap[string] ResourceWithGroupMap;
    //typedef map<ResourceHandle, SharedPtr!Resource>.type ResourceHandleMap;
    alias SharedPtr!Resource[ResourceHandle] ResourceHandleMap;
protected:
    ResourceHandleMap mResourcesByHandle;
    ResourceMap mResources;
    ResourceWithGroupMap mResourcesWithGroup;
    ResourceHandle mNextHandle;
    size_t mMemoryBudget; // In bytes
    AtomicScalar!size_t mMemoryUsage; // In bytes
    
    bool mVerbose;
    
    // IMPORTANT - all subclasses must populate the fields below
    
    /// Patterns to use to look for scripts if supported (e.g. *.overlay)
    StringVector mScriptPatterns; 
    /// Loading order relative to other managers, higher is later
    Real mLoadOrder; 
    /// string identifying the resource type this manager handles
    string mResourceType; 
    
public:
    //typedef MapIterator<ResourceHandleMap> ResourceMapIterator;
    /** Returns an iterator over all resources in this manager. 
     @note
     Use of this iterator is NOT thread safe!
     */
    /*ResourceMapIterator getResourceIterator() 
     {
     return ResourceMapIterator(mResourcesByHandle.begin(), mResourcesByHandle.end());
     }*/
    
protected:
    //typedef map<string, ResourcePool*>.type ResourcePoolMap;
    alias ResourcePool[string] ResourcePoolMap;
    ResourcePoolMap mResourcePoolMap;
    
}

