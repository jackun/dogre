module ogre.resources.resourcegroupmanager;

import core.sync.mutex;
debug import std.stdio;
import std.string;
import std.array;

public import ogre.sharedptr;
import ogre.singleton;
import ogre.general.common;
import ogre.compat;
import ogre.general.generals;
import ogre.scene.scenemanager;
import ogre.resources.datastream;
import ogre.exception;
import ogre.strings;
import ogre.resources.resource;
import ogre.resources.archive;
import ogre.resources.resourcemanager;
import ogre.general.log;

/** This abstract class defines an interface which is called back during
 resource group loading to indicate the progress of the load. 
 @remarks
 Resource group loading is in 2 phases - creating resources from 
 declarations (which includes parsing scripts), and loading
 resources. Note that you don't necessarily have to have both; it
 is quite possible to just parse all the scripts for a group (see
 ResourceGroupManager.initialiseResourceGroup, but not to 
 load the resource group. 
 The sequence of events is (* signifies a repeating item):
 <ul>
 <li>resourceGroupScriptingStarted</li>
 <li>scriptParseStarted (*)</li>
 <li>scriptParseEnded (*)</li>
 <li>resourceGroupScriptingEnded</li>
 <li>resourceGroupLoadStarted</li>
 <li>resourceLoadStarted (*)</li>
 <li>resourceLoadEnded (*)</li>
 <li>worldGeometryStageStarted (*)</li>
 <li>worldGeometryStageEnded (*)</li>
 <li>resourceGroupLoadEnded</li>
 <li>resourceGroupPrepareStarted</li>
 <li>resourcePrepareStarted (*)</li>
 <li>resourcePrepareEnded (*)</li>
 <li>resourceGroupPrepareEnded</li>
 </ul>
 @note
 If OGRE_THREAD_SUPPORT is 1, this class is thread-safe.

 */
class ResourceGroupListener
{
public:
    ~this() {}
    
    /** This event is fired when a resource group begins parsing scripts.
     @note
     Remember that if you are loading resources through ResourceBackgroundQueue,
     these callbacks will occur in the background thread, so you should
     not perform any thread-unsafe actions in this callback if that's the
     case (check the group name / script name).
     @param groupName The name of the group 
     @param scriptCount The number of scripts which will be parsed
     */
    abstract void resourceGroupScriptingStarted(string groupName, size_t scriptCount);
    /** This event is fired when a script is about to be parsed.
     @param scriptName Name of the to be parsed
     @param skipThisScript A boolean passed by reference which is by default set to 
     false. If the event sets this to true, the script will be skipped and not
     parsed. Note that in this case the scriptParseEnded event will not be raised
     for this script.
     */
    abstract void scriptParseStarted(string scriptName, ref bool skipThisScript);
    
    /** This event is fired when the script has been fully parsed.
     */
    abstract void scriptParseEnded(string scriptName, bool skipped);
    /** This event is fired when a resource group finished parsing scripts. */
    abstract void resourceGroupScriptingEnded(string groupName);
    
    /** This event is fired  when a resource group begins preparing.
     @param groupName The name of the group being prepared
     @param resourceCount The number of resources which will be prepared, including
     a number of stages required to prepare any linked world geometry
     */
    void resourceGroupPrepareStarted(string groupName, size_t resourceCount)
    { }
    
    /** This event is fired when a declared resource is about to be prepared. 
     @param resource Weak reference to the resource prepared.
     */
    void resourcePrepareStarted(SharedPtr!Resource resource)
    { }
    
    /** This event is fired when the resource has been prepared. 
     */
    void resourcePrepareEnded() {}
    /** This event is fired when a stage of preparing linked world geometry 
     is about to start. The number of stages required will have been 
     included in the resourceCount passed in resourceGroupLoadStarted.
     @param description Text description of what was just prepared
     */
    void worldGeometryPrepareStageStarted(string description)
    { }
    
    /** This event is fired when a stage of preparing linked world geometry 
     has been completed. The number of stages required will have been 
     included in the resourceCount passed in resourceGroupLoadStarted.
     */
    void worldGeometryPrepareStageEnded() {}
    /** This event is fired when a resource group finished preparing. */
    void resourceGroupPrepareEnded(string groupName)
    { }
    
    /** This event is fired  when a resource group begins loading.
     @param groupName The name of the group being loaded
     @param resourceCount The number of resources which will be loaded, including
     a number of stages required to load any linked world geometry
     */
    abstract void resourceGroupLoadStarted(string groupName, size_t resourceCount);
    /** This event is fired when a declared resource is about to be loaded. 
     @param resource Weak reference to the resource loaded.
     */
    abstract void resourceLoadStarted(SharedPtr!Resource resource);
    /** This event is fired when the resource has been loaded. 
     */
    abstract void resourceLoadEnded();
    /** This event is fired when a stage of loading linked world geometry 
     is about to start. The number of stages required will have been 
     included in the resourceCount passed in resourceGroupLoadStarted.
     @param description Text description of what was just loaded
     */
    abstract void worldGeometryStageStarted(string description);
    /** This event is fired when a stage of loading linked world geometry 
     has been completed. The number of stages required will have been 
     included in the resourceCount passed in resourceGroupLoadStarted.
     */
    abstract void worldGeometryStageEnded();
    /** This event is fired when a resource group finished loading. */
    abstract void resourceGroupLoadEnded(string groupName);
}

/**
 @remarks   This class allows users to override resource loading behavior.
 By overriding this class' methods, you can change how resources
 are loaded and the behavior for resource name collisions.
 */
class ResourceLoadingListener
{
public:
    ~this() {}
    
    /** This event is called when a resource beings loading. */
    abstract DataStreamPtr resourceLoading(string name, string group, ref Resource resource);
    
    /** This event is called when a resource stream has been opened, but not processed yet. 
     @remarks
     You may alter the stream if you wish or alter the incoming pointer to point at
     another stream if you wish.
     */
    abstract void resourceStreamOpened(string name, string group, Resource resource, ref DataStreamPtr dataStream);
    
    /** This event is called when a resource collides with another existing one in a resource manager
     */
    abstract bool resourceCollision(Resource resource, ResourceManager resourceManager);
}

/** This singleton class manages the list of resource groups, and notifying
 the various resource managers of their obligations to load / unload
 resources in a group. It also provides facilities to monitor resource
 loading per group (to do progress bars etc), provided the resources 
 that are required are pre-registered.
 @par
 Defining new resource groups,  and declaring the resources you intend to
 use in advance is optional, however it is a very useful feature. In addition, 
 if a ResourceManager supports the definition of resources through scripts, 
 then this is the class which drives the locating of the scripts and telling
 the ResourceManager to parse them. 
 @par
 There are several states that a resource can be in (the concept, not the
 object instance in this case):
 <ol>
 <li><b>Undefined</b>. Nobody knows about this resource yet. It might be
 in the filesystem, but Ogre is oblivious to it at the moment - there 
 is no Resource instance. This might be because it's never been declared
 (either in a script, or using ResourceGroupManager.declareResource), or
 it may have previously been a valid Resource instance but has been 
 removed, either individually through ResourceManager.remove or as a group
 through ResourceGroupManager.clearResourceGroup.</li>
 <li><b>Declared</b>. Ogre has some forewarning of this resource, either
 through calling ResourceGroupManager.declareResource, or by declaring
 the resource in a script file which is on one of the resource locations
 which has been defined for a group. There is still no instance of Resource,
 but Ogre will know to create this resource when 
 ResourceGroupManager.initialiseResourceGroup is called (which is automatic
 if you declare the resource group before Root.initialise).</li>
 <li><b>Unloaded</b>. There is now a Resource instance for this resource, 
 although it is not loaded. This means that code which looks for this
 named resource will find it, but the Resource is not using a lot of memory
 because it is in an unloaded state. A Resource can get into this state
 by having just been created by ResourceGroupManager.initialiseResourceGroup 
 (either from a script, or from a call to declareResource), by 
 being created directly from code (ResourceManager.create), or it may 
 have previously been loaded and has been unloaded, either individually
 through Resource.unload, or as a group through ResourceGroupManager.unloadResourceGroup.</li>
 <li><b>Loaded</b>The Resource instance is fully loaded. This may have
 happened implicitly because something used it, or it may have been 
 loaded as part of a group.</li>
 </ol>
 @see ResourceGroupManager.declareResource
 @see ResourceGroupManager.initialiseResourceGroup
 @see ResourceGroupManager.loadResourceGroup
 @see ResourceGroupManager.unloadResourceGroup
 @see ResourceGroupManager.clearResourceGroup
 */
class ResourceGroupManager //: public ResourceAlloc
{
    mixin Singleton!ResourceGroupManager;
    
public:
    //OGRE_AUTO_MUTEX // public to allow external locking
    Mutex mLock;
    /// Default resource group name
    immutable static string DEFAULT_RESOURCE_GROUP_NAME = "General";
    /// Internal resource group name (should be used by OGRE internal only)
    immutable static string INTERNAL_RESOURCE_GROUP_NAME = "Internal";
    /// Special resource group name which causes resource group to be automatically determined based on searching for the resource in all groups.
    immutable static string AUTODETECT_RESOURCE_GROUP_NAME = "Autodetect";
    /// The number of reference counts held per resource by the resource system
    immutable static size_t RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS = 3;
    /// Nested struct defining a resource declaration
    struct ResourceDeclaration
    {
        string resourceName;
        string resourceType;
        ManualResourceLoader loader;
        NameValuePairList parameters;
    }
    /// List of resource declarations
    //typedef list<ResourceDeclaration>.type ResourceDeclarationList;
    //typedef map<string, ResourceManager*>.type ResourceManagerMap;
    //typedef MapIterator<ResourceManagerMap> ResourceManagerIterator;
    
    alias ResourceDeclaration[] ResourceDeclarationList;
    alias ResourceManager[string] ResourceManagerMap;
    
    /// Resource location entry
    struct ResourceLocation
    {
        /// Pointer to the archive which is the destination
        Archive archive;
        /// Whether this location was added recursively
        bool recursive;
    }
    /// List of possible file locations
    //typedef list<ResourceLocation*>.type LocationList;
    alias ResourceLocation[] LocationList;
    
protected:
    /// Map of resource types (strings) to ResourceManagers, used to notify them to load / unload group contents
    ResourceManagerMap mResourceManagerMap;
    
    /// Map of loading order (Real) to ScriptLoader, used to order script parsing
    //typedef multimap<Real, ScriptLoader*>.type ScriptLoaderOrderMap;
    //typedef multimap<Real, ScriptLoader*>.type ScriptLoaderOrderMap;
    alias ScriptLoader[Real] ScriptLoaderOrderMap; //FIXME cause it's wrong
    ScriptLoaderOrderMap mScriptLoaderOrderMap;
    
    //typedef vector<ResourceGroupListener*>.type ResourceGroupListenerList;
    alias ResourceGroupListener[] ResourceGroupListenerList;
    ResourceGroupListenerList mResourceGroupListenerList;
    
    ResourceLoadingListener mLoadingListener;
    
    /// Resource index entry, resourcename.location 
    //typedef map<string, Archive*>.type ResourceLocationIndex;
    alias Archive[string] ResourceLocationIndex;
    
    /// List of resources which can be loaded / unloaded
    //typedef list<SharedPtr!Resource>.type LoadUnloadResourceList;
    alias SharedPtr!Resource[] LoadUnloadResourceList;
    /// Resource group entry
    //struct 
    static class ResourceGroup
    {
        invariant()
        {
            assert(mLock !is null);
        }
        
    public:
        enum Status
        {
            UNINITIALISED = 0,
            INITIALISING = 1,
            INITIALISED = 2,
            LOADING = 3,
            LOADED = 4
        }
        /// General mutex for dealing with group content
        //OGRE_AUTO_MUTEX
        Mutex mLock;
        /// Status-specific mutex, separate from content-changing mutex
        //OGRE_MUTEX(statusMutex)
        Mutex statusMutex;
        /// Group name
        string name;
        /// Group status
        Status groupStatus;
        /// List of possible locations to search
        LocationList locationList;
        /// Index of resource names to locations, built for speedy access (case sensitive archives)
        ResourceLocationIndex resourceIndexCaseSensitive;
        /// Index of resource names to locations, built for speedy access (case insensitive archives)
        ResourceLocationIndex resourceIndexCaseInsensitive;
        /// Pre-declared resources, ready to be created
        ResourceDeclarationList resourceDeclarations;
        /// Created resources which are ready to be loaded / unloaded
        // Group by loading order of the type (defined by ResourceManager)
        // (e.g. skeletons and materials before meshes)
        //typedef map<Real, LoadUnloadResourceList*>.type LoadResourceOrderMap;
        alias LoadUnloadResourceList[Real] LoadResourceOrderMap;
        LoadResourceOrderMap loadResourceOrderMap;
        /// Linked world geometry, as passed to setWorldGeometry
        string worldGeometry;
        /// Scene manager to use with linked world geometry
        SceneManager worldGeometrySceneManager;
        // in global pool flag - if true the resource will be loaded even a different   group was requested in the load method as a parameter.
        bool inGlobalPool;
        
        this()
        {
            mLock = new Mutex;
            statusMutex = new Mutex;
        }
        
        void addToIndex(string filename, Archive arch)
        {
            // internal, assumes mutex lock has already been obtained
            this.resourceIndexCaseSensitive[filename] = arch;
            
            if (!arch.isCaseSensitive())
            {
                string lcase = filename.toLower();
                this.resourceIndexCaseInsensitive[lcase] = arch;
            }
        }
        void removeFromIndex(string filename, Archive arch)
        {
            // internal, assumes mutex lock has already been obtained
            auto i = filename in this.resourceIndexCaseSensitive; //TODO substring search too?
            if ((i !is null) && *i == arch)
                this.resourceIndexCaseSensitive.remove(filename);
            
            if (!arch.isCaseSensitive())
            {
                string lcase = filename.toLower();
                i = lcase in this.resourceIndexCaseInsensitive; //TODO substring search too?
                if ((i !is null) && *i == arch)
                    this.resourceIndexCaseInsensitive.remove(lcase); 
            }
        }
        void removeFromIndex(Archive arch)
        {
            // Delete indexes
            foreach (k, v; this.resourceIndexCaseInsensitive)
            {
                if (v == arch)
                {
                    this.resourceIndexCaseInsensitive.remove(k);
                }
            }
            
            foreach (k ,v; this.resourceIndexCaseSensitive)
            {
                if (v == arch)
                {
                    this.resourceIndexCaseSensitive.remove(k);
                }
            }
            
        }
        
    }
    /// Map from resource group names to groups
    //typedef map<string, ResourceGroup*>::type ResourceGroupMap;
    alias ResourceGroup[string] ResourceGroupMap;
    ResourceGroupMap mResourceGroupMap;
    
    /// Group name for world resources
    string mWorldGroupName;
    
    /** Parses all the available scripts found in the resource locations
     for the given group, for all ResourceManagers.
     @remarks
     Called as part of initialiseResourceGroup
     */
    void parseResourceGroupScripts(ResourceGroup grp)
    {
        
        LogManager.getSingleton().logMessage(
            "Parsing scripts for resource group " ~ grp.name);
        
        // Count up the number of scripts we have to parse
        //typedef list<FileInfoList>.type FileListList;
        //typedef SharedPtr<FileListList> FileListListPtr;
        //typedef std.pair<ScriptLoader*, FileListListPtr> LoaderFileListPair;
        //typedef list<LoaderFileListPair>.type ScriptLoaderFileList;
        
        alias FileInfoList[]                 FileListList;
        //NO //alias SharedPtr!FileListList                FileListListPtr;
        //alias pair!(ScriptLoader, FileListListPtr)  LoaderFileListPair;
        alias pair!(ScriptLoader, FileListList)  LoaderFileListPair;
        alias LoaderFileListPair[]           ScriptLoaderFileList;
        
        ScriptLoaderFileList scriptLoaderFileList;
        size_t scriptCount = 0;
        // Iterate over script users in loading order and get streams
        //ScriptLoaderOrderMap.iterator oi;
        foreach (oik, su; mScriptLoaderOrderMap)
        {
            // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
            //FileListListPtr fileListList(OGRE_NEW_T(FileListList, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            //auto fileListList = FileListListPtr(new FileListList);
            FileListList fileListList;
            
            // Get all the patterns and search them
            auto patterns = su.getScriptPatterns();
            foreach (p; patterns)
            {
                FileInfoList fileList = findResourceFileInfo(grp.name, p);
                scriptCount += fileList.length;
                fileListList.insert(fileList);
            }
            scriptLoaderFileList.insert(LoaderFileListPair(su, fileListList));
        }
        // Fire scripting event
        fireResourceGroupScriptingStarted(grp.name, scriptCount);
        
        // Iterate over scripts and parse
        // Note we respect original ordering
        foreach (slfli; scriptLoaderFileList)
        {
            ScriptLoader su = slfli.first;
            // Iterate over each list
            foreach (flli; slfli.second)
            {
                // Iterate over each item in the list
                foreach (fii; flli)
                {
                    bool skipScript = false;
                    fireScriptStarted(fii.filename, skipScript);
                    if(skipScript)
                    {
                        LogManager.getSingleton().logMessage(
                            "Skipping script " ~ fii.filename);
                    }
                    else
                    {
                        LogManager.getSingleton().logMessage(
                            "Parsing script " ~ fii.filename);
                        DataStreamPtr stream = fii.archive.open(fii.filename);
                        //if (!stream.isNull())
                        if(stream !is null)
                        {
                            if (mLoadingListener)
                                mLoadingListener.resourceStreamOpened(fii.filename, grp.name, null, stream);
                            
                            if(fii.archive.getType() == "FileSystem" && stream.size() <= 1024 * 1024)
                            {
                                DataStreamPtr cachedCopy = new MemoryDataStream(stream.getName(), stream);
                                //cachedCopy.bind(new MemoryDataStream(stream.getName(), stream));
                                su.parseScript(cachedCopy, grp.name);
                            }
                            else
                                su.parseScript(stream, grp.name);
                        }
                    }
                    fireScriptEnded(fii.filename, skipScript);
                }
            }
        }
        
        fireResourceGroupScriptingEnded(grp.name);
        LogManager.getSingleton().logMessage(
            "Finished parsing scripts for resource group " ~ grp.name);
    }
    /** Create all the pre-declared resources.
     @remarks
     Called as part of initialiseResourceGroup
     */
    void createDeclaredResources(ResourceGroup grp)
    {
        
        foreach (dcl; grp.resourceDeclarations)
        {
            debug stderr.writeln("Create resource ", dcl.resourceName);
            // Retrieve the appropriate manager
            auto mgr = _getResourceManager(dcl.resourceType);
            // Create the resource
            auto res = mgr.create(dcl.resourceName, grp.name,
                                  dcl.loader !is null, dcl.loader, dcl.parameters);
            // Add resource to load list
            auto li = mgr.getLoadingOrder() in grp.loadResourceOrderMap;
            
            LoadUnloadResourceList* loadList;
            if (li is null)
            {
                //loadList = new LoadUnloadResourceList();
                grp.loadResourceOrderMap[mgr.getLoadingOrder()] = null; //loadList;
                loadList = &(grp.loadResourceOrderMap[mgr.getLoadingOrder()]);
            }
            else
            {
                loadList = li;
            }
            (*loadList).insert(res);
            
        }
        
    }
    /** Adds a created resource to a group. */
    void addCreatedResource(ref SharedPtr!Resource res, ResourceGroup grp)
    {
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME)
        synchronized(grp.mLock)
        {
            Real order = res.get().getCreator().getLoadingOrder();
            
            auto i = order in grp.loadResourceOrderMap;
            LoadUnloadResourceList* loadList;
            if (i is null)
            {
                //loadList = new LoadUnloadResourceList();
                grp.loadResourceOrderMap[order] = null;
                loadList = &(grp.loadResourceOrderMap[order]);
            }
            else
            {
                loadList = i;
            }
            (*loadList).insert(res);
        }
    }
    /** Get resource group */
    ResourceGroup getResourceGroup(string name)
    {
        synchronized(mLock)
        {
            auto i = name in mResourceGroupMap;
            if (i !is null)
            {
                return *i;
            }
        }
        return null;
    }
    /** Drops contents of a group, leave group there, notify ResourceManagers. */
    void dropGroupContents(ResourceGroup grp)
    {
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME)
        synchronized(grp.mLock)
        {
            
            bool groupSet = false;
            if (!mCurrentGroup)
            {
                // Set current group to indicate ignoring of notifications
                mCurrentGroup = grp;
                groupSet = true;
            }
            // delete all the load list entries
            foreach (key, j; grp.loadResourceOrderMap)
            {
                // Iterate over resources
                foreach (k; j)
                {
                    k.get().getCreator().remove(k.get().getHandle());
                }
                //OGRE_DELETE_T(j.second, LoadUnloadResourceList, MEMCATEGORY_RESOURCE);
                destroy(j);
            }
            grp.loadResourceOrderMap.clear();
            
            if (groupSet)
            {
                mCurrentGroup = null;
            }
        }
    }
    /** Delete a group for shutdown - don't notify ResourceManagers. */
    void deleteGroup(ResourceGroup grp)
    {
        {
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME)
            synchronized(grp.mLock)
            {
                // delete all the load list entries
                foreach (k, v; grp.loadResourceOrderMap)
                {
                    // Don't iterate over resources to drop with ResourceManager
                    // Assume this is being done anyway since this is a shutdown method
                    //OGRE_DELETE_T(j.second, LoadUnloadResourceList, MEMCATEGORY_RESOURCE);
                    destroy(v);
                }
                // Drop location list
                foreach (ll; grp.locationList)
                {
                    //OGRE_DELETE_T(*ll, ResourceLocation, MEMCATEGORY_RESOURCE);
                    destroy(ll);
                }
            }
        }
        
        // delete ResourceGroup
        //OGRE_DELETE_T(grp, ResourceGroup, MEMCATEGORY_RESOURCE);
        destroy(grp);
    }
    /// Internal find method for auto groups
    ResourceGroup findGroupContainingResourceImpl(string filename)
    {
        //synchronized(mLock)
        synchronized(mLock)
        {
            // Iterate over resource groups and find
            foreach (k, grp; mResourceGroupMap)
            {
                //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
                synchronized(grp.mLock)
                    if (resourceExists(grp, filename))
                        return grp;
            }
        }
        // Not found
        return null;
    }
    /// Internal event firing method
    void fireResourceGroupScriptingStarted(string groupName, size_t scriptCount)
    {
        //synchronized(mLock)
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.resourceGroupScriptingStarted(groupName, scriptCount);
            }
        }
    }
    /// Internal event firing method
    void fireScriptStarted(string scriptName, ref bool skipScript)
    {
        //synchronized(mLock)
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                bool temp = false;
                l.scriptParseStarted(scriptName, temp);
                if(temp)
                    skipScript = true;
            }
        }
    }
    /// Internal event firing method
    void fireScriptEnded(string scriptName, bool skipped)
    {
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.scriptParseEnded(scriptName, skipped);
            }
        }
    }
    /// Internal event firing method
    void fireResourceGroupScriptingEnded(string groupName)
    {
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.resourceGroupScriptingEnded(groupName);
            }
        }
    }
    /// Internal event firing method
    void fireResourceGroupLoadStarted(string groupName, size_t resourceCount)
    {
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.resourceGroupLoadStarted(groupName, resourceCount);
            }
        }
    }
    /// Internal event firing method
    void fireResourceLoadStarted(SharedPtr!Resource resource)
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourceLoadStarted(resource);
        }
    }
    /// Internal event firing method
    void fireResourceLoadEnded()
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourceLoadEnded();
        }
    }
    /// Internal event firing method
    void fireResourceGroupLoadEnded(string groupName)
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourceGroupLoadEnded(groupName);
        }
    }
    /// Internal event firing method
    void fireResourceGroupPrepareStarted(string groupName, size_t resourceCount)
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourceGroupPrepareStarted(groupName, resourceCount);
        }
    }
    /// Internal event firing method
    void fireResourcePrepareStarted(SharedPtr!Resource resource)
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourcePrepareStarted(resource);
        }
    }
    /// Internal event firing method
    void fireResourcePrepareEnded()
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourcePrepareEnded();
        }
    }
    /// Internal event firing method
    void fireResourceGroupPrepareEnded(string groupName)
    {
        synchronized(mLock)
            foreach (l; mResourceGroupListenerList)
        {
            l.resourceGroupPrepareEnded(groupName);
        }
    }
    
    /// Stored current group - optimisation for when bulk loading a group
    ResourceGroup mCurrentGroup;
public:
    this()
    {
        mLock = new Mutex;
        mLoadingListener = null;
        mCurrentGroup = null;
        // Create the 'General' group
        createResourceGroup(DEFAULT_RESOURCE_GROUP_NAME);
        // Create the 'Internal' group
        createResourceGroup(INTERNAL_RESOURCE_GROUP_NAME);
        // Create the 'Autodetect' group (only used for temp storage)
        createResourceGroup(AUTODETECT_RESOURCE_GROUP_NAME);
        // default world group to the default group
        mWorldGroupName = DEFAULT_RESOURCE_GROUP_NAME;
    }
    ~this()
    {
        // delete all resource groups
        foreach (k, v; mResourceGroupMap)
        {
            deleteGroup(v);
        }
        mResourceGroupMap.clear();
    }
    
    /** Create a resource group.
     @remarks
     A resource group allows you to define a set of resources that can 
     be loaded / unloaded as a unit. For example, it might be all the 
     resources used for the level of a game. There is always one predefined
     resource group called ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, 
     which is typically used to hold all resources which do not need to 
     be unloaded until shutdown. There is another predefined resource
     group called ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME too,
     which should be used by OGRE internal only, the resources created
     in this group aren't supposed to modify, unload or remove by user.
     You can create additional ones so that you can control the life of
     your resources in whichever way you wish.
     There is one other predefined value, 
     ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME; using this 
     causes the group name to be derived at load time by searching for 
     the resource in the resource locations of each group in turn.
     @par
     Once you have defined a resource group, resources which will be loaded
     as part of it are defined in one of 3 ways:
     <ol>
     <li>Manually through declareResource(); this is useful for scripted
     declarations since it is entirely generalised, and does not 
     create Resource instances right away</li>
     <li>Through the use of scripts; some ResourceManager subtypes have
     script formats (e.g. .material, .overlay) which can be used
     to declare resources</li>
     <li>By calling ResourceManager.create to create a resource manually.
     This resource will go on the list for it's group and will be loaded
     and unloaded with that group</li>
     </ol>
     You must remember to call initialiseResourceGroup if you intend to use
     the first 2 types.
     @param name The name to give the resource group.
     @param inGlobalPool if true the resource will be loaded even a different
     group was requested in the load method as a parameter.
     */
    void createResourceGroup(string name,bool inGlobalPool = true)
    {
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage("Creating resource group " ~ name);
            if (getResourceGroup(name))
            {
                throw new DuplicateItemError(
                    "Resource group with name '" ~ name ~ "' already exists!", 
                    "ResourceGroupManager.createResourceGroup");
            }
            auto grp = new ResourceGroup();
            grp.groupStatus = ResourceGroup.Status.UNINITIALISED;
            grp.name = name;
            grp.inGlobalPool = inGlobalPool;
            grp.worldGeometrySceneManager = null;
            mResourceGroupMap[name] = grp;
        }
    }
    
    
    /** Initialises a resource group.
     @remarks
     After creating a resource group, adding some resource locations, and
     perhaps pre-declaring some resources using declareResource(), but 
     before you need to use the resources in the group, you 
     should call this method to initialise the group. By calling this,
     you are triggering the following processes:
     <ol>
     <li>Scripts for all resource types which support scripting are
     parsed from the resource locations, and resources within them are
     created (but not loaded yet).</li>
     <li>Creates all the resources which have just pre-declared using
     declareResource (again, these are not loaded yet)</li>
     </ol>
     So what this essentially does is create a bunch of unloaded Resource entries
     in the respective ResourceManagers based on scripts, and resources
     you've pre-declared. That means that code looking for these resources
     will find them, but they won't be taking up much memory yet, until
     they are either used, or they are loaded in bulk using loadResourceGroup.
     Loading the resource group in bulk is entirely optional, but has the 
     advantage of coming with progress reporting as resources are loaded.
     @par
     Failure to call this method means that loadResourceGroup will do 
     nothing, and any resources you define in scripts will not be found.
     Similarly, once you have called this method you won't be able to
     pick up any new scripts or pre-declared resources, unless you
     call clearResourceGroup, set up declared resources, and call this
     method again.
     @note 
     When you call Root.initialise, all resource groups that have already been
     created are automatically initialised too. Therefore you do not need to 
     call this method for groups you define and set up before you call 
     Root.initialise. However, since one of the most useful features of 
     resource groups is to set them up after the main system initialisation
     has occurred (e.g. a group per game level), you must remember to call this
     method for the groups you create after this.

     @param name The name of the resource group to initialise
     */
    void initialiseResourceGroup(string name)
    {
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage("Initialising resource group " ~ name);
            auto grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.initialiseResourceGroup");
            }
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                if (grp.groupStatus == ResourceGroup.Status.UNINITIALISED)
                {
                    // in the process of initialising
                    grp.groupStatus = ResourceGroup.Status.INITIALISING;
                    // Set current group
                    parseResourceGroupScripts(grp);
                    mCurrentGroup = grp;
                    LogManager.getSingleton().logMessage("Creating resources for group " ~ name);
                    createDeclaredResources(grp);
                    grp.groupStatus = ResourceGroup.Status.INITIALISED;
                    LogManager.getSingleton().logMessage("All done");
                    // Reset current group
                    mCurrentGroup = null;
                }
            }
        }
    }
    
    /** Initialise all resource groups which are yet to be initialised.
     @see ResourceGroupManager.intialiseResourceGroup
     */
    void initialiseAllResourceGroups()
    {
        synchronized(mLock)
        {
            // Intialise all declared resource groups
            foreach (k, grp; mResourceGroupMap)
            {
                //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
                synchronized(grp.mLock)
                {
                    if (grp.groupStatus == ResourceGroup.Status.UNINITIALISED)
                    {
                        // in the process of initialising
                        grp.groupStatus = ResourceGroup.Status.INITIALISING;
                        // Set current group
                        mCurrentGroup = grp;
                        parseResourceGroupScripts(grp);
                        LogManager.getSingleton().logMessage("Creating resources for group " ~ k);
                        createDeclaredResources(grp);
                        grp.groupStatus = ResourceGroup.Status.INITIALISED;
                        LogManager.getSingleton().logMessage("All done");
                        // Reset current group
                        mCurrentGroup = null;
                    }
                }
            }
        }
    }
    
    /** Prepares a resource group.
     @remarks
     Prepares any created resources which are part of the named group.
     Note that resources must have already been created by calling
     ResourceManager.create, or declared using declareResource() or
     in a script (such as .material and .overlay). The latter requires
     that initialiseResourceGroup has been called. 
     
     When this method is called, this class will callback any ResourceGroupListeners
     which have been registered to update them on progress. 
     @param name The name of the resource group to prepare.
     @param prepareMainResources If true, prepares normal resources associated 
     with the group (you might want to set this to false if you wanted
     to just prepare world geometry in bulk)
     @param prepareWorldGeom If true, prepares any linked world geometry
     @see ResourceGroupManager.linkWorldGeometryToResourceGroup
     */
    void prepareResourceGroup(string name, bool prepareMainResources = true, 
                              bool prepareWorldGeom = true)
    {
        // Can only bulk-load one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            LogManager.getSingleton().stream()
                << "Preparing resource group '" << name << "' - Resources: "
                    << prepareMainResources << " World Geometry: " << prepareWorldGeom;
            // load all created resources
            auto grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.prepareResourceGroup");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex 
            synchronized(grp.mLock)
            {
                // Set current group
                mCurrentGroup = grp;
                
                // Count up resources for starting event
                //ResourceGroup.LoadResourceOrderMap.iterator oi;
                size_t resourceCount = 0;
                if (prepareMainResources)
                {
                    foreach (k, v; grp.loadResourceOrderMap)
                    {
                        resourceCount += v.length;
                    }
                }
                // Estimate world geometry size
                if (grp.worldGeometrySceneManager && prepareWorldGeom)
                {
                    resourceCount += 
                        grp.worldGeometrySceneManager.estimateWorldGeometry(
                            grp.worldGeometry);
                }
                
                fireResourceGroupPrepareStarted(name, resourceCount);
                
                // Now load for real
                if (prepareMainResources)
                {
                    foreach (k, v; grp.loadResourceOrderMap)
                    {
                        size_t n = 0;
                        //LoadUnloadResourceList.iterator l = oi.second.begin();
                        size_t l = 0;
                        //while (l != oi.second.end())
                        //foreach(l; v)
                        while (l < v.length) //FIXME while loop, iterator invalidation (?)
                        {
                            SharedPtr!Resource res = v[l];
                            
                            // Fire resource events no matter whether resource needs preparing
                            // or not. This ensures that the number of callbacks
                            // matches the number originally estimated, which is important
                            // for progress bars.
                            fireResourcePrepareStarted(res);
                            
                            // If preparing one of these resources cascade-prepares another resource, 
                            // the list will get longer! But these should be prepared immediately
                            // Call prepare regardless, already prepared or loaded resources will be skipped
                            res.get().prepare();
                            
                            fireResourcePrepareEnded();
                            
                            ++n;
                            
                            // Did the resource change group? if so, our iterator will have
                            // been invalidated
                            if (res.get().getGroup() != name)
                            {
                                //l = oi.second.begin();
                                //std.advance(l, n);
                                l = n;
                            }
                            else
                            {
                                ++l;
                            }
                        }
                    }
                }
                // Load World Geometry
                if (grp.worldGeometrySceneManager && prepareWorldGeom)
                {
                    grp.worldGeometrySceneManager.prepareWorldGeometry(
                        grp.worldGeometry);
                }
                fireResourceGroupPrepareEnded(name);
                
                // reset current group
                mCurrentGroup = null;
                
                LogManager.getSingleton().logMessage("Finished preparing resource group " ~ name);
            }
        }
    }
    
    /** Loads a resource group.
     @remarks
     Loads any created resources which are part of the named group.
     Note that resources must have already been created by calling
     ResourceManager.create, or declared using declareResource() or
     in a script (such as .material and .overlay). The latter requires
     that initialiseResourceGroup has been called. 
     
     When this method is called, this class will callback any ResourceGroupListeners
     which have been registered to update them on progress. 
     @param name The name of the resource group to load.
     @param loadMainResources If true, loads normal resources associated 
     with the group (you might want to set this to false if you wanted
     to just load world geometry in bulk)
     @param loadWorldGeom If true, loads any linked world geometry
     @see ResourceGroupManager.linkWorldGeometryToResourceGroup
     */
    void loadResourceGroup(string name, bool loadMainResources = true, 
                           bool loadWorldGeom = true)
    {
        // Can only bulk-load one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            LogManager.getSingleton().stream()
                << "Loading resource group '" << name << "' - Resources: "
                    << loadMainResources << " World Geometry: " << loadWorldGeom;
            // load all created resources
            ResourceGroup grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.loadResourceGroup");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex 
            synchronized(grp.mLock)
            {
                // Set current group
                mCurrentGroup = grp;
                
                // Count up resources for starting event
                //ResourceGroup.LoadResourceOrderMap.iterator oi;
                size_t resourceCount = 0;
                if (loadMainResources)
                {
                    foreach (k, v; grp.loadResourceOrderMap)
                    {
                        resourceCount += v.length;
                    }
                }
                // Estimate world geometry size
                if (grp.worldGeometrySceneManager && loadWorldGeom)
                {
                    resourceCount += 
                        grp.worldGeometrySceneManager.estimateWorldGeometry(
                            grp.worldGeometry);
                }
                
                fireResourceGroupLoadStarted(name, resourceCount);
                
                // Now load for real
                if (loadMainResources)
                {
                    foreach (k, v; grp.loadResourceOrderMap)
                    {
                        size_t n = 0;
                        //LoadUnloadResourceList.iterator l = oi.second.begin();
                        size_t l = 0;
                        while (l < v.length)
                        {
                            SharedPtr!Resource res = v[l];
                            
                            // Fire resource events no matter whether resource is already
                            // loaded or not. This ensures that the number of callbacks
                            // matches the number originally estimated, which is important
                            // for progress bars.
                            fireResourceLoadStarted(res);
                            
                            // If loading one of these resources cascade-loads another resource, 
                            // the list will get longer! But these should be loaded immediately
                            // Call load regardless, already loaded resources will be skipped
                            res.get().load();
                            
                            fireResourceLoadEnded();
                            
                            ++n;
                            
                            // Did the resource change group? if so, our iterator will have
                            // been invalidated
                            if (res.get().getGroup() != name)
                            {
                                //l = oi.second.begin();
                                //std.advance(l, n);
                                l = n;
                            }
                            else
                            {
                                ++l;
                            }
                        }
                    }
                }
                // Load World Geometry
                if (grp.worldGeometrySceneManager && loadWorldGeom)
                {
                    grp.worldGeometrySceneManager.setWorldGeometry(
                        grp.worldGeometry);
                }
                fireResourceGroupLoadEnded(name);
                
                // group is loaded
                grp.groupStatus = ResourceGroup.Status.LOADED;
                
                // reset current group
                mCurrentGroup = null;
                
                LogManager.getSingleton().logMessage("Finished loading resource group " ~ name);
            }
        }
    }
    
    /** Unloads a resource group.
     @remarks
     This method unloads all the resources that have been declared as
     being part of the named resource group. Note that these resources
     will still exist in their respective ResourceManager classes, but
     will be in an unloaded state. If you want to remove them entirely,
     you should use clearResourceGroup or destroyResourceGroup.
     @param name The name to of the resource group to unload.
     @param reloadableOnly If set to true, only unload the resource that is
     reloadable. Because some resources isn't reloadable, they will be
     unloaded but can't load them later. Thus, you might not want to them
     unloaded. Or, you might unload all of them, and then populate them
     manually later.
     @see Resource.isReloadable for resource is reloadable.
     */
    void unloadResourceGroup(string name, bool reloadableOnly = true)
    {
        // Can only bulk-unload one group at a time (reasonable limitation I think)
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage("Unloading resource group " ~ name);
            auto grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.unloadResourceGroup");
            }
            // Set current group
            mCurrentGroup = grp;
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex 
            synchronized(grp.mLock)
            {
                
                // Count up resources for starting event
                //ResourceGroup.LoadResourceOrderMap.reverse_iterator oi;
                // unload in reverse order
                //for (oi = grp.loadResourceOrderMap.rbegin(); oi != grp.loadResourceOrderMap.rend(); ++oi)
                //for( int i = grp.loadResourceOrderMap.keys.length-1; i >= 0; i--)
                foreach_reverse (k, v; grp.loadResourceOrderMap)
                {
                    //auto v = grp.loadResourceOrderMap[grp.loadResourceOrderMap.keys[i]];
                    foreach (l; v)
                    {
                        auto resource = l.get();
                        if (!reloadableOnly || resource.isReloadable())
                        {
                            resource.unload();
                        }
                    }
                }
                
                grp.groupStatus = ResourceGroup.Status.INITIALISED;
                
                // reset current group
                mCurrentGroup = null;
                LogManager.getSingleton().logMessage("Finished unloading resource group " ~ name);
            }
        }
    }
    
    /** Unload all resources which are not referenced by any other object.
     @remarks
     This method behaves like unloadResourceGroup, except that it only
     unloads resources in the group which are not in use, ie not referenced
     by other objects. This allows you to free up some memory selectively
     whilst still keeping the group around (and the resources present,
     just not using much memory).
     @param name The name of the group to check for unreferenced resources
     @param reloadableOnly If true (the default), only unloads resources
     which can be subsequently automatically reloaded
     */
    void unloadUnreferencedResourcesInGroup(string name, 
                                            bool reloadableOnly = true)
    {
        // Can only bulk-unload one group at a time (reasonable limitation I think)
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(mLock)
        {
            
            LogManager.getSingleton().logMessage(
                "Unloading unused resources in resource group " ~ name);
            auto grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.unloadUnreferencedResourcesInGroup");
            }
            // Set current group
            mCurrentGroup = grp;
            
            //ResourceGroup.LoadResourceOrderMap.reverse_iterator oi;
            // unload in reverse order
            //for (oi = grp.loadResourceOrderMap.rbegin(); oi != grp.loadResourceOrderMap.rend(); ++oi)
            //for( int i = grp.loadResourceOrderMap.keys.length-1; i >= 0; i--)
            foreach_reverse (k, v; grp.loadResourceOrderMap)
            {
                //auto v = grp.loadResourceOrderMap[grp.loadResourceOrderMap.keys[i]];
                
                foreach (l; v)
                {
                    // A use count of 3 means that only RGM and RM have references
                    // RGM has one (this one) and RM has 2 (by name and by handle)
                    if (l.useCount() == RESOURCE_SYSTEM_NUM_REFERENCE_COUNTS)
                    {
                        auto resource = l.get();
                        if (!reloadableOnly || resource.isReloadable())
                        {
                            resource.unload();
                        }
                    }
                }
            }
            
            grp.groupStatus = ResourceGroup.Status.INITIALISED;
            
            // reset current group
            mCurrentGroup = null;
            LogManager.getSingleton().logMessage(
                "Finished unloading unused resources in resource group " ~ name);
        }
    }
    /** Clears a resource group. 
     @remarks
     This method unloads all resources in the group, but in addition it
     removes all those resources from their ResourceManagers, and then 
     clears all the members from the list. That means after calling this
     method, there are no resources declared as part of the named group
     any more. Resource locations still persist though.
     @param name The name to of the resource group to clear.
     */
    void clearResourceGroup(string name)
    {
        // Can only bulk-clear one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage("Clearing resource group " ~ name);
            ResourceGroup grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.clearResourceGroup");
            }
            // set current group
            mCurrentGroup = grp;
            dropGroupContents(grp);
            // clear initialised flag
            grp.groupStatus = ResourceGroup.Status.UNINITIALISED;
            // reset current group
            mCurrentGroup = null;
            LogManager.getSingleton().logMessage("Finished clearing resource group " ~ name);
        }
    }
    
    /** Destroys a resource group, clearing it first, destroying the resources
     which are part of it, and then removing it from
     the list of resource groups. 
     @param name The name of the resource group to destroy.
     */
    void destroyResourceGroup(string name)
    {
        // Can only bulk-destroy one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage("Destroying resource group " ~ name);
            ResourceGroup grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.destroyResourceGroup");
            }
            // set current group
            mCurrentGroup = grp;
            unloadResourceGroup(name, false); // will throw an exception if name not valid
            dropGroupContents(grp);
            deleteGroup(grp);
            mResourceGroupMap.remove(name);
            // reset current group
            mCurrentGroup = null;
        }
    }
    
    /** Checks the status of a resource group.
     @remarks
     Looks at the state of a resource group.
     If initialiseResourceGroup has been called for the resource
     group return true, otherwise return false.
     @param name The name to of the resource group to access.
     */
    bool isResourceGroupInitialised(string name)
    {
        // Can only bulk-destroy one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            ResourceGroup grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.isResourceGroupInitialised");
            }
            return (grp.groupStatus != ResourceGroup.Status.UNINITIALISED &&
                    grp.groupStatus != ResourceGroup.Status.INITIALISING);
        }
    }
    
    /** Checks the status of a resource group.
     @remarks
     Looks at the state of a resource group.
     If loadResourceGroup has been called for the resource
     group return true, otherwise return false.
     @param name The name to of the resource group to access.
     */
    bool isResourceGroupLoaded(string name)
    {
        // Can only bulk-destroy one group at a time (reasonable limitation I think)
        synchronized(mLock)
        {
            ResourceGroup grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.isResourceGroupInitialised");
            }
            return (grp.groupStatus == ResourceGroup.Status.LOADED);
        }
    }
    
    /*** Verify if a resource group exists
     @param name The name of the resource group to look for
     */
    bool resourceGroupExists(string name)
    {
        return getResourceGroup(name) !is null ? true : false;
    }
    
    /** Method to add a resource location to for a given resource group. 
     @remarks
     Resource locations are places which are searched to load resource files.
     When you choose to load a file, or to search for valid files to load, 
     the resource locations are used.
     @param name The name of the resource location; probably a directory, zip file, URL etc.
     @param locType The codename for the resource type, which must correspond to the 
     Archive factory which is providing the implementation.
     @param resGroup The name of the resource group for which this location is
     to apply. ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME is the 
     default group which always exists, and can
     be used for resources which are unlikely to be unloaded until application
     shutdown. Otherwise it must be the name of a group; if it
     has not already been created with createResourceGroup then it is created
     automatically.
     @param recursive Whether subdirectories will be searched for files when using 
     a pattern match (such as *.material), and whether subdirectories will be
     indexed. This can slow down initial loading of the archive and searches.
     When opening a resource you still need to use the fully qualified name, 
     this allows duplicate names in alternate paths.
     */
    void addResourceLocation(string name, string locType, 
                             string resGroup = DEFAULT_RESOURCE_GROUP_NAME, bool recursive = false, bool readOnly = true)
    {
        ResourceGroup grp = getResourceGroup(resGroup);
        if (grp is null)
        {
            createResourceGroup(resGroup);
            grp = getResourceGroup(resGroup);
        }
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            // Get archive
            Archive pArch = ArchiveManager.getSingleton().load( name, locType, readOnly );
            // Add to location list
            ResourceLocation loc;// = new ResourceLocation();
            loc.archive = pArch;
            loc.recursive = recursive;
            grp.locationList.insert(loc);
            // Index resources
            auto vec = pArch.find("*", recursive);
            foreach(it; vec)
                grp.addToIndex(it, pArch);
            
            string msg =  "Added resource location '" ~ name ~ "' of type '" ~ locType
                ~ "' to resource group '" ~ resGroup ~ "'";
            if (recursive)
                msg ~= " with recursive option";
            LogManager.getSingleton().logMessage(msg);
        }
        
    }
    /** Removes a resource location from the search path. */ 
    void removeResourceLocation(string name, 
                                string resGroup = DEFAULT_RESOURCE_GROUP_NAME)
    {
        auto grp = getResourceGroup(resGroup);
        if (grp is null)
        {
            throw new ItemNotFoundError(
                "Cannot locate a resource group called '" ~ resGroup ~ "'", 
                "ResourceGroupManager.removeResourceLocation");
        }
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            
            // Remove from location list
            foreach (li; grp.locationList)
            {
                auto pArch = li.archive;
                if (pArch.getName() == name)
                {
                    grp.removeFromIndex(pArch);
                    // Erase list entry
                    //OGRE_DELETE_T(*li, ResourceLocation, MEMCATEGORY_RESOURCE);
                    grp.locationList.removeFromArray(li); // Because we break right after, 
                    destroy(li);                                                       // we can use linearRemove in foreach
                    
                    break;
                }
                
            }
        }
        
        LogManager.getSingleton().logMessage("Removed resource location " ~ name);
        
    }
    /** Verify if a resource location exists for the given group. */ 
    bool resourceLocationExists(string name, 
                                string resGroup = DEFAULT_RESOURCE_GROUP_NAME)
    {
        auto grp = getResourceGroup(resGroup);
        if (grp is null)
            return false;
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            foreach (li; grp.locationList)
            {
                auto pArch = li.archive;
                if (pArch.getName() == name)
                    // Delete indexes
                    return true;
            }
        }
        return false;
    }
    
    /** Declares a resource to be a part of a resource group, allowing you 
     to load and unload it as part of the group.
     @remarks
     By declaring resources before you attempt to use them, you can 
     more easily control the loading and unloading of those resources
     by their group. Declaring them also allows them to be enumerated, 
     which means events can be raised to indicate the loading progress
     (@see ResourceGroupListener). Note that another way of declaring
     resources is to use a script specific to the resource type, if
     available (e.g. .material).
     @par
     Declared resources are not created as Resource instances (and thus
     are not available through their ResourceManager) until initialiseResourceGroup
     is called, at which point all declared resources will become created 
     (but unloaded) Resource instances, along with any resources declared
     in scripts in resource locations associated with the group.
     @param name The resource name. 
     @param resourceType The type of the resource. Ogre comes preconfigured with 
     a number of resource types: 
     <ul>
     <li>Font</li>
     <li>GpuProgram</li>
     <li>HighLevelGpuProgram</li>
     <li>Material</li>
     <li>Mesh</li>
     <li>Skeleton</li>
     <li>Texture</li>
     </ul>
     .. but more can be added by plugin ResourceManager classes.
     @param groupName The name of the group to which it will belong.
     @param loadParameters A list of name / value pairs which supply custom
     parameters to the resource which will be required before it can 
     be loaded. These are specific to the resource type.
     */
    void declareResource(string name, string resourceType,
                         string groupName = DEFAULT_RESOURCE_GROUP_NAME,
                         /+ref+/NameValuePairList loadParameters = NameValuePairList.init)
    {
        declareResource(name, resourceType, groupName, null, loadParameters);
    }
    /** Declares a resource to be a part of a resource group, allowing you
     to load and unload it as part of the group.
     @remarks
     By declaring resources before you attempt to use them, you can
     more easily control the loading and unloading of those resources
     by their group. Declaring them also allows them to be enumerated,
     which means events can be raised to indicate the loading progress
     (@see ResourceGroupListener). Note that another way of declaring
     resources is to use a script specific to the resource type, if
     available (e.g. .material).
     @par
     Declared resources are not created as Resource instances (and thus
     are not available through their ResourceManager) until initialiseResourceGroup
     is called, at which point all declared resources will become created
     (but unloaded) Resource instances, along with any resources declared
     in scripts in resource locations associated with the group.
     @param name The resource name.
     @param resourceType The type of the resource. Ogre comes preconfigured with
     a number of resource types:
     <ul>
     <li>Font</li>
     <li>GpuProgram</li>
     <li>HighLevelGpuProgram</li>
     <li>Material</li>
     <li>Mesh</li>
     <li>Skeleton</li>
     <li>Texture</li>
     </ul>
     .. but more can be added by plugin ResourceManager classes.
     @param groupName The name of the group to which it will belong.
     @param loader Pointer to a ManualResourceLoader implementation which will
     be called when the Resource wishes to load. If supplied, the resource
     is manually loaded, otherwise it'll loading from file automatic.
     @note We don't support declare manually loaded resource without loader
     here, since it's meaningless.
     @param loadParameters A list of name / value pairs which supply custom
     parameters to the resource which will be required before it can
     be loaded. These are specific to the resource type.
     */
    void declareResource(string name, string resourceType,
                         string groupName, ManualResourceLoader loader,
                         ref NameValuePairList loadParameters)
    {
        auto grp = getResourceGroup(groupName);
        if (grp is null)
        {
            throw new ItemNotFoundError(
                "Cannot find a group named " ~ groupName, 
                "ResourceGroupManager.declareResource");
        }
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            ResourceDeclaration dcl;// = new ResourceDeclaration();
            dcl.loader = loader;
            dcl.parameters = loadParameters;
            dcl.resourceName = name;
            dcl.resourceType = resourceType;
            grp.resourceDeclarations.insert(dcl);
        }
        
    }
    /** Undeclare a resource.
     @remarks
     Note that this will not cause it to be unloaded
     if it is already loaded, nor will it destroy a resource which has 
     already been created if initialiseResourceGroup has been called already.
     Only unloadResourceGroup / clearResourceGroup / destroyResourceGroup 
     will do that. 
     @param name The name of the resource. 
     @param groupName The name of the group this resource was declared in. 
     */
    void undeclareResource(string name, string groupName)
    {
        auto grp = getResourceGroup(groupName);
        if (grp is null)
        {
            throw new ItemNotFoundError(
                "Cannot find a group named " ~ groupName, 
                "ResourceGroupManager.undeclareResource");
        }
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            
            foreach (i; grp.resourceDeclarations)
            {
                if (i.resourceName == name)
                {
                    grp.resourceDeclarations.removeFromArray(i);
                    break;
                }
            }
        }
    }
    
    /** Open a single resource by name and return a DataStream
     pointing at the source of the data.
     @param resourceName The name of the resource to locate.
     Even if resource locations are added recursively, you
     must provide a fully qualified name to this method. You 
     can find out the matching fully qualified names by using the
     find() method if you need to.
     @param groupName The name of the resource group; this determines which 
     locations are searched. 
     @param searchGroupsIfNotFound If true, if the resource is not found in 
     the group specified, other groups will be searched. If you're
     loading a real Resource using this option, you <strong>must</strong>
     also provide the resourceBeingLoaded parameter to enable the 
     group membership to be changed
     @param resourceBeingLoaded Optional pointer to the resource being 
     loaded, which you should supply if you want
     @return Shared pointer to data stream containing the data, will be
     destroyed automatically when no longer referenced
     */
    DataStreamPtr openResource(string resourceName, 
                               string groupName = DEFAULT_RESOURCE_GROUP_NAME,
                               bool searchGroupsIfNotFound = true, /+ref+/ Resource resourceBeingLoaded = null)
    {
        synchronized(mLock)
        {
            if(mLoadingListener)
            {
                DataStreamPtr stream = mLoadingListener.resourceLoading(resourceName, groupName, resourceBeingLoaded);
                //if(!stream.isNull())
                if(stream !is null)
                    return stream;
            }
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~
                    "' for resource '" ~ resourceName ~ "'" , 
                    "ResourceGroupManager.openResource");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                auto rit = resourceName in grp.resourceIndexCaseSensitive;
                if (rit !is null)
                {
                    // Found in the index
                    auto pArch = *rit;
                    DataStreamPtr stream = pArch.open(resourceName);
                    if (mLoadingListener)
                        mLoadingListener.resourceStreamOpened(resourceName, groupName, resourceBeingLoaded, stream);
                    return stream;
                }
                else 
                {
                    // try case insensitive
                    string lcResourceName = resourceName.toLower();
                    rit = lcResourceName in grp.resourceIndexCaseInsensitive;
                    if (rit !is null)
                    {
                        // Found in the index
                        auto pArch = *rit;
                        DataStreamPtr stream = pArch.open(resourceName);
                        if (mLoadingListener)
                            mLoadingListener.resourceStreamOpened(resourceName, groupName, resourceBeingLoaded, stream);
                        return stream;
                    }
                    else
                    {
                        // Search the hard way
                        foreach (li; grp.locationList)
                        {
                            auto arch = li.archive;
                            if (arch.exists(resourceName))
                            {
                                DataStreamPtr ptr = arch.open(resourceName);
                                if (mLoadingListener)
                                    mLoadingListener.resourceStreamOpened(resourceName, groupName, resourceBeingLoaded, ptr);
                                return ptr;
                            }
                        }
                        
                        //HACK (-ish) Didn't return in foreach, do substring search then
                        if(string fn = _findFile(grp, resourceName))
                        {
                            return openResource(fn, groupName, searchGroupsIfNotFound, resourceBeingLoaded);
                        }
                    }
                }
                
                
                // Not found
                if (searchGroupsIfNotFound)
                {
                    auto foundGrp = findGroupContainingResourceImpl(resourceName); 
                    if (foundGrp)
                    {
                        if (resourceBeingLoaded)
                        {
                            resourceBeingLoaded.changeGroupOwnership(foundGrp.name);
                        }
                        return openResource(resourceName, foundGrp.name, false);
                    }
                    else
                    {
                        throw new FileNotFoundError(
                            "Cannot locate resource " ~ resourceName ~ 
                            " in resource group " ~ groupName ~ " or any other group.", 
                            "ResourceGroupManager.openResource");
                    }
                }
            }
        }
        
        throw new FileNotFoundError( "Cannot locate resource " ~ 
                                    resourceName ~ " in resource group " ~ groupName ~ ".", 
                                    "ResourceGroupManager.openResource");
    }
    
    /** Open all resources matching a given pattern (which can contain
     the character '*' as a wildcard), and return a collection of 
     DataStream objects on them.
     @param pattern The pattern to look for. If resource locations have been
     added recursively, subdirectories will be searched too so this
     does not need to be fully qualified.
     @param groupName The resource group; this determines which locations
     are searched.
     @return Shared pointer to a data stream list , will be
     destroyed automatically when no longer referenced
     */
    DataStreamList openResources(string pattern, 
                                 string groupName = DEFAULT_RESOURCE_GROUP_NAME)
    {
        synchronized(mLock)
        {
            ResourceGroup grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.openResources");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                // Iterate through all the archives and build up a combined list of
                // streams
                // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
                //auto ret = new DataStreamList(new DataStreamList);
                DataStreamList ret;
                
                foreach (li; grp.locationList)
                {
                    auto arch = li.archive;
                    // Find all the names based on whether this archive is recursive
                    auto names = arch.find(pattern, li.recursive);
                    
                    // Iterate over the names and load a stream for each
                    foreach (ni; names)
                    {
                        DataStreamPtr ptr = arch.open(ni);
                        //if (!ptr.isNull())
                        if (ptr !is null)
                        {
                            ret.insert(ptr);
                        }
                    }
                }
                return ret;
            }
        }
    }
    
    /** List all file or directory names in a resource group.
     @note
     This method only returns filenames, you can also retrieve other
     information using listFileInfo.
     @param groupName The name of the group
     @param dirs If true, directory names will be returned instead of file names
     @return A list of filenames matching the criteria, all are fully qualified
     */
    StringVector listResourceNames(string groupName, bool dirs = false)
    {
        synchronized(mLock)
        {
            // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
            //StringVector vec(OGRE_NEW_T(StringVector, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            StringVector vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.listResourceNames");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    auto lst = i.archive.list(i.recursive, dirs);
                    vec.insert(lst);
                }
                
                return vec;
            }
        }
        
    }
    
    /** List all files in a resource group with accompanying information.
     @param groupName The name of the group
     @param dirs If true, directory names will be returned instead of file names
     @return A list of structures detailing quite a lot of information about
     all the files in the archive.
     */
    FileInfoList listResourceFileInfo(string groupName, bool dirs = false)
    {
        synchronized(mLock)
        {
            // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
            //FileInfoList vec(OGRE_NEW_T(FileInfoList, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            //auto  vec = new FileInfoList();
            FileInfoList vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.listResourceFileInfo");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    auto lst = i.archive.listFileInfo(i.recursive, dirs);
                    vec.insert(lst);
                }
                
                return vec;
            }
        }
    }
    
    /** Find all file or directory names matching a given pattern in a
     resource group.
     @note
     This method only returns filenames, you can also retrieve other
     information using findFileInfo.
     @param groupName The name of the group
     @param pattern The pattern to search for; wildcards (*) are allowed
     @param dirs Set to true if you want the directories to be listed
     instead of files
     @return A list of filenames matching the criteria, all are fully qualified
     */
    StringVector findResourceNames(string groupName, string pattern,
                                   bool dirs = false)
    {
        synchronized(mLock)
        {
            // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
            //StringVector vec(OGRE_NEW_T(StringVector, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            StringVector vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.findResourceNames");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    auto lst = i.archive.find(pattern, i.recursive, dirs);
                    vec.insert(lst);
                }
                
                return vec;
            }
        }
    }
    
    /** Find out if the named file exists in a group. 
     @param groupName The name of the resource group
     @param resourceName Fully qualified name of the file to test for
     */
    bool resourceExists(string groupName, string resourceName)
    {
        synchronized(mLock)
        {
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.resourceExists");
            }
            
            return resourceExists(grp, resourceName);
        }
    }
    
    // FIXME C++ version find() finds files with only basename too (?)
    private string _findFile(ResourceGroup grp, string fn)
    {
        foreach(k; grp.resourceIndexCaseSensitive.keys)
        {
            if(k.indexOf(fn) > -1)
                return k;
        }
        
        fn = fn.toLower();
        foreach(k; grp.resourceIndexCaseInsensitive.keys)
        {
            if(k.indexOf(fn) > -1)
                return k;
        }
        
        return null;
    }
    
    /** Find out if the named file exists in a group. 
     @param group Pointer to the resource group
     @param filename Fully qualified name of the file to test for
     */
    bool resourceExists(ResourceGroup grp, string resourceName)
    {
        
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            // Try indexes first
            auto rit = resourceName in grp.resourceIndexCaseSensitive;
            if (rit !is null)
            {
                // Found in the index
                return true;
            }
            else
            {
                // try case insensitive
                string lcResourceName = resourceName.toLower();
                rit = lcResourceName in grp.resourceIndexCaseInsensitive;
                if (rit !is null)
                {
                    // Found in the index
                    return true;
                }
                else
                {
                    // Search the hard way
                    foreach (li; grp.locationList)
                    {
                        auto arch = li.archive;
                        if (arch.exists(resourceName))
                        {
                            return true;
                        }
                    }
                    
                    //XXX kinda hacky, but probably no choice, do substring search
                    if(_findFile(grp, resourceName) !is null)
                    {
                        return true;
                    }
                }
            }
            
            return false;
        }
    }
    
    /** Find out if the named file exists in any group. 
     @param filename Fully qualified name of the file to test for
     */
    bool resourceExistsInAnyGroup(string filename)
    {
        auto grp = findGroupContainingResourceImpl(filename);
        if (grp is null)
            return false;
        return true;
    }
    
    /** Find the group in which a resource exists.
     @param filename Fully qualified name of the file the resource should be
     found as
     @return Name of the resource group the resource was found in. An
     exception is thrown if the group could not be determined.
     */
    string findGroupContainingResource(string filename)
    {
        auto grp = findGroupContainingResourceImpl(filename);
        if (grp is null)
        {
            throw new ItemNotFoundError(
                "Unable to derive resource group for " ~ 
                filename ~ " automatically since the resource was not "
                "found.", 
                "ResourceGroupManager.findGroupContainingResource");
        }
        return grp.name;
    }
    
    /** Find all files or directories matching a given pattern in a group
     and get some detailed information about them.
     @param group The name of the resource group
     @param pattern The pattern to search for; wildcards (*) are allowed
     @param dirs Set to true if you want the directories to be listed
     instead of files
     @return A list of file information structures for all files matching 
     the criteria.
     */
    FileInfoList findResourceFileInfo(string groupName, string pattern,
                                      bool dirs = false)
    {
        synchronized(mLock)
        {
            // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
            //FileInfoList vec(OGRE_NEW_T(FileInfoList, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            FileInfoList vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.findResourceFileInfo");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    auto lst = i.archive.findFileInfo(pattern, i.recursive, dirs);
                    vec.insert(lst);
                }
                
                return vec;
            }
        }
    }
    
    /** Retrieve the modification time of a given file */
    time_t resourceModifiedTime(string groupName, string resourceName)
    {
        synchronized(mLock)
        {
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.resourceModifiedTime");
            }
            
            return resourceModifiedTime(grp, resourceName);
        }
    }
    
    /** Retrieve the modification time of a given file */
    time_t resourceModifiedTime(ResourceGroup grp, string resourceName)
    {
        //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
        synchronized(grp.mLock)
        {
            // Try indexes first
            auto rit = resourceName in grp.resourceIndexCaseSensitive;
            if (rit !is null)
            {
                return (*rit).getModifiedTime(resourceName);
            }
            else 
            {
                // try case insensitive
                string lcResourceName = resourceName.toLower();
                rit = lcResourceName in grp.resourceIndexCaseInsensitive;
                if (rit !is null)
                {
                    return (*rit).getModifiedTime(resourceName);
                }
                else
                {
                    // Search the hard way
                    foreach (li; grp.locationList)
                    {
                        auto arch = li.archive;
                        time_t testTime = arch.getModifiedTime(resourceName);
                        
                        if (testTime > 0)
                        {
                            return testTime;
                        }
                    }
                }
            }
        }
        
        return 0;
    }
    
    /** List all resource locations in a resource group.
     @param groupName The name of the group
     @return A list of resource locations matching the criteria
     */
    StringVector listResourceLocations(string groupName)
    {
        synchronized(mLock)
        {
            //StringVector vec(OGRE_NEW_T(StringVector, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            StringVector vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.listResourceNames");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    vec.insert(i.archive.getName());
                }
            }
            return vec;
        }
    }
    
    /** Find all resource location names matching a given pattern in a
     resource group.
     @param groupName The name of the group
     @param pattern The pattern to search for; wildcards (*) are allowed
     @return A list of resource locations matching the criteria
     */
    StringVector findResourceLocation(string groupName, string pattern)
    {
        synchronized(mLock)
        {
            //StringVector vec(OGRE_NEW_T(StringVector, MEMCATEGORY_GENERAL)(), SPFM_DELETE_T);
            StringVector vec;
            
            // Try to find in resource index first
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.listResourceNames");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                // Iterate over the archives
                foreach (i; grp.locationList)
                {
                    string location = i.archive.getName();
                    // Search for the pattern
                    if(StringUtil.match(location, pattern))
                    {
                        vec.insert(location);
                    }
                }
            }
            return vec;
        }
    }
    
    
    /** Create a new resource file in a given group.
     @remarks
     This method creates a new file in a resource group and passes you back a 
     writeable stream. 
     @param filename The name of the file to create
     @param groupName The name of the group in which to create the file
     @param overwrite If true, an existing file will be overwritten, if false
     an error will occur if the file already exists
     @param locationPattern If the resource group contains multiple locations, 
     then usually the file will be created in the first writable location. If you 
     want to be more specific, you can include a location pattern here and 
     only locations which match that pattern (as determined by StringUtil.match)
     will be considered candidates for creation.
     */
    DataStreamPtr createResource(string filename, string groupName = DEFAULT_RESOURCE_GROUP_NAME, 
                                 bool overwrite = false, string locationPattern = "")
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.createResource");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                foreach (li; grp.locationList)
                {
                    auto arch = li.archive;
                    
                    if (!arch.isReadOnly() && 
                        (locationPattern.empty() || StringUtil.match(arch.getName(), locationPattern, false)))
                    {
                        if (!overwrite && arch.exists(filename))
                            throw new DuplicateItemError(
                                "Cannot overwrite existing file " ~ filename, 
                                "ResourceGroupManager.createResource");
                        
                        // create it
                        DataStreamPtr ret = arch.create(filename);
                        grp.addToIndex(filename, arch);
                        
                        return ret;
                    }
                }
            }
        }
        throw new ItemNotFoundError(
            "Cannot find a writable location in group " ~ groupName, 
            "ResourceGroupManager.createResource");
        
    }
    
    /** Delete a single resource file.
     @param filename The name of the file to delete. 
     @param groupName The name of the group in which to search
     @param locationPattern If the resource group contains multiple locations, 
     then usually first matching file found in any location will be deleted. If you 
     want to be more specific, you can include a location pattern here and 
     only locations which match that pattern (as determined by StringUtil.match)
     will be considered candidates for deletion.
     */
    void deleteResource(string filename, string groupName = DEFAULT_RESOURCE_GROUP_NAME, 
                        string locationPattern = "")
    {
        synchronized(mLock)
        {
            ResourceGroup grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.createResource");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                foreach (li; grp.locationList)
                {
                    auto arch = li.archive;
                    
                    if (!arch.isReadOnly() && 
                        (locationPattern.empty() || StringUtil.match(arch.getName(), locationPattern, false)))
                    {
                        if (arch.exists(filename))
                        {
                            arch.remove(filename);
                            grp.removeFromIndex(filename, arch);
                            
                            // only remove one file
                            break;
                        }
                    }
                }
            }
        }
    }
    
    /** Delete all matching resource files.
     @param filePattern The pattern (see StringUtil.match) of the files to delete. 
     @param groupName The name of the group in which to search
     @param locationPattern If the resource group contains multiple locations, 
     then usually all matching files in any location will be deleted. If you 
     want to be more specific, you can include a location pattern here and 
     only locations which match that pattern (as determined by StringUtil.match)
     will be considered candidates for deletion.
     */
    void deleteMatchingResources(string filePattern, string groupName = DEFAULT_RESOURCE_GROUP_NAME, 
                                 string locationPattern = "")
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.createResource");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                
                foreach (li; grp.locationList)
                {
                    auto arch = li.archive;
                    
                    if (!arch.isReadOnly() && 
                        (locationPattern.empty() || StringUtil.match(arch.getName(), locationPattern, false)))
                    {
                        auto matchingFiles = arch.find(filePattern);
                        foreach (f; matchingFiles)
                        {
                            arch.remove(f);
                            grp.removeFromIndex(f, arch);
                            
                        }
                    }
                }
            }
        }
    }
    
    /** Adds a ResourceGroupListener which will be called back during 
     resource loading events. 
     */
    void addResourceGroupListener(ResourceGroupListener l)
    {
        synchronized(mLock)
            mResourceGroupListenerList.insert(l);
    }
    /** Removes a ResourceGroupListener */
    void removeResourceGroupListener(ResourceGroupListener l)
    {
        synchronized(mLock)
        {
            foreach (i; mResourceGroupListenerList)
            {
                if (i == l)
                {
                    mResourceGroupListenerList.removeFromArray(i);
                    break;
                }
            }
        }
    }
    
    /** Sets the resource group that 'world' resources will use.
     @remarks
     This is the group which should be used by SceneManagers implementing
     world geometry when looking for their resources. Defaults to the 
     DEFAULT_RESOURCE_GROUP_NAME but this can be altered.
     */
    void setWorldResourceGroupName(string groupName) {mWorldGroupName = groupName;}
    
    /// Gets the resource group that 'world' resources will use.
    string getWorldResourceGroupName(){ return mWorldGroupName; }
    
    /** Associates some world geometry with a resource group, causing it to 
     be loaded / unloaded with the resource group.
     @remarks
     You would use this method to essentially defer a call to 
     SceneManager.setWorldGeometry to the time when the resource group
     is loaded. The advantage of this is that compatible scene managers 
     will include the estimate of the number of loading stages for that
     world geometry when the resource group begins loading, allowing you
     to include that in a loading progress report. 
     @param group The name of the resource group
     @param worldGeometry The parameter which should be passed to setWorldGeometry
     @param sceneManager The SceneManager which should be called
     */
    void linkWorldGeometryToResourceGroup(string group, 
                                          string worldGeometry, ref SceneManager sceneManager)
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(group);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ group ~ "'", 
                    "ResourceGroupManager.linkWorldGeometryToResourceGroup");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                grp.worldGeometry = worldGeometry;
                grp.worldGeometrySceneManager = sceneManager;
            }
        }
    }
    
    /** Clear any link to world geometry from a resource group.
     @remarks
     Basically undoes a previous call to linkWorldGeometryToResourceGroup.
     */
    void unlinkWorldGeometryFromResourceGroup(string group)
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(group);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ group ~ "'", 
                    "ResourceGroupManager.unlinkWorldGeometryFromResourceGroup");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                grp.worldGeometry = null;
                grp.worldGeometrySceneManager = null;
            }
        }
    }
    
    /** Checks the status of a resource group.
     @remarks
     Looks at the state of a resource group.
     If loadResourceGroup has been called for the resource
     group return true, otherwise return false.
     @param name The name to of the resource group to access.
     */
    bool isResourceGroupInGlobalPool(string name)
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(name);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot find a group named " ~ name, 
                    "ResourceGroupManager.isResourceGroupInitialised");
            }
            return grp.inGlobalPool;
        }
    }
    
    /** Shutdown all ResourceManagers, performed as part of clean-up. */
    void shutdownAll()
    {
        synchronized(mLock)
        {
            foreach (k, v; mResourceManagerMap)
            {
                v.removeAll();
            }
        }
    }
    
    
    /** Internal method for registering a ResourceManager (which should be
     a singleton). Creators of plugins can register new ResourceManagers
     this way if they wish.
     @remarks
     ResourceManagers that wish to parse scripts must also call 
     _registerScriptLoader.
     @param resourceType string identifying the resource type, must be unique.
     @param rm Pointer to the ResourceManager instance.
     */
    void _registerResourceManager(string resourceType, ResourceManager rm)
    {
        synchronized(mLock)
        {
            LogManager.getSingleton().logMessage(
                "Registering ResourceManager for type " ~ resourceType);
            mResourceManagerMap[resourceType] = rm;
        }
    }
    
    /** Internal method for unregistering a ResourceManager.
     @remarks
     ResourceManagers that wish to parse scripts must also call 
     _unregisterScriptLoader.
     @param resourceType string identifying the resource type.
     */
    void _unregisterResourceManager(string resourceType)
    {
        synchronized(mLock)
        {
            
            LogManager.getSingleton().logMessage(
                "Unregistering ResourceManager for type " ~ resourceType);
            
            auto i = resourceType in mResourceManagerMap;
            if (i !is null)
            {
                mResourceManagerMap.remove(resourceType);
            }
        }
    }
    
    /** Get an iterator over the registered resource managers.
     */
    //ResourceManagerIterator getResourceManagerIterator()
    //{ return ResourceManagerIterator(
    //        mResourceManagerMap.begin(), mResourceManagerMap.end()); }
    
    /** Internal method for registering a ScriptLoader.
     @remarks ScriptLoaders parse scripts when resource groups are initialised.
     @param su Pointer to the ScriptLoader instance.
     */
    void _registerScriptLoader(ScriptLoader su)
    {
        synchronized(mLock)
        {
            mScriptLoaderOrderMap[su.getLoadingOrder()] = su;
        }
    }
    
    /** Internal method for unregistering a ScriptLoader.
     @param su Pointer to the ScriptLoader instance.
     */
    void _unregisterScriptLoader(ScriptLoader su)
    {
        synchronized(mLock)
        {
            Real order = su.getLoadingOrder();
            foreach (k; mScriptLoaderOrderMap.keysAA )
            {
                auto v = mScriptLoaderOrderMap[k];
                if (k != order) continue; //break;
                if (v == su)
                {
                    // erase does not invalidate on multimap, except current
                    mScriptLoaderOrderMap.remove(k);
                }
            }
        }
    }
    
    /** Method used to directly query for registered script loaders.
     @param pattern The specific script pattern (e.g. *.material) the script loader handles
     */
    ScriptLoader _findScriptLoader(string pattern)
    {
        synchronized(mLock)
        {
            foreach (k, v; mScriptLoaderOrderMap)
            {
                auto patterns = v.getScriptPatterns();
                
                // Search for matches in the patterns
                foreach (p; patterns)
                {
                    if(p == pattern)
                        return v;
                }
            }
        }
        return null; // No loader was found
    }
    
    /** Internal method for getting a registered ResourceManager.
     @param resourceType string identifying the resource type.
     */
    ResourceManager _getResourceManager(string resourceType)
    {
        synchronized(mLock)
        {
            auto i = resourceType in mResourceManagerMap;
            if (i is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate resource manager for resource type '" ~
                    resourceType ~ "'", "ResourceGroupManager._getResourceManager");
            }
            return *i;
        }
    }
    
    /** Internal method called by ResourceManager when a resource is created.
     @param res Weak reference to resource
     */
    void _notifyResourceCreated(SharedPtr!Resource res)
    {
        debug std.stdio.writeln(__FILE__,": Resource: ", res.get()," (", (res.get() ? res.get().getName(): "null"),")");
        if (mCurrentGroup && res.get().getGroup() == mCurrentGroup.name)
        {
            // Use current group (batch loading)
            addCreatedResource(res, mCurrentGroup);
        }
        else
        {
            // Find group
            auto grp = getResourceGroup(res.get().getGroup());
            if (grp !is null)
            {
                addCreatedResource(res, grp);
            }
        }
    }
    
    /** Internal method called by ResourceManager when a resource is removed.
     @param res Weak reference to resource
     */
    void _notifyResourceRemoved(ref SharedPtr!Resource res)
    {
        if (mCurrentGroup)
        {
            // Do nothing - we're batch unloading so list will be cleared
        }
        else
        {
            // Find group
            ResourceGroup grp = getResourceGroup(res.get().getGroup());
            if (grp)
            {
                //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
                synchronized(grp.mLock)
                {
                    auto i = res.get().getCreator().getLoadingOrder() in grp.loadResourceOrderMap;
                    if (i !is null)
                    {
                        // Iterate over the resource list and remove
                        auto resList = *i;
                        foreach (l; resList)
                        {
                            if (l.get() == res.get())
                            {
                                // this is the one
                                (*i).removeFromArray(res);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    
    /** Internal method to notify the group manager that a resource has
     changed group (only applicable for autodetect group) */
    void _notifyResourceGroupChanged(string oldGroup, ref Resource res)
    {
        SharedPtr!Resource resPtr;
        
        // find old entry
        auto grp = getResourceGroup(oldGroup);
        
        if (grp)
        {
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                Real order = res.getCreator().getLoadingOrder();
                auto i = order in grp.loadResourceOrderMap;
                assert(i !is null);
                auto loadList = *i;
                foreach (l; loadList)
                {
                    if (l.get() == res)
                    {
                        resPtr = l;
                        (*i).removeFromArray(l);
                        break;
                    }
                }
            }
        }
        
        if (!resPtr.isNull())
        {
            // New group
            auto newGrp = getResourceGroup(res.getGroup());
            
            addCreatedResource(resPtr, newGrp);
        }
    }
    
    /** Internal method called by ResourceManager when all resources 
     for that manager are removed.
     @param manager Pointer to the manager for which all resources are being removed
     */
    void _notifyAllResourcesRemoved(ref ResourceManager manager)
    {
        synchronized(mLock)
        {
            // Iterate over all groups
            foreach (k, v; mResourceGroupMap)
            {
                //OGRE_LOCK_MUTEX(grpi.second.OGRE_AUTO_MUTEX_NAME)
                synchronized(v.mLock)
                {
                    // Iterate over all priorities
                    foreach (kk, ref LoadUnloadResourceList vv; v.loadResourceOrderMap) //FIXME ref works?
                    {
                        // Iterate over all resources
                        for (size_t i=0; i < vv.length;)
                        {
                            auto l = vv[i];
                            if (l.get().getCreator() == manager)
                            {
                                // Increment first since iterator will be invalidated
                                //LoadUnloadResourceList.iterator del = l++;
                                //oi.second.erase(del);
                                vv.removeFromArrayIdx(i);
                            }
                            else
                                i++;
                        }
                    }
                }
            }
        }
    }
    
    /** Notify this manager that one stage of world geometry loading has been 
     started.
     @remarks
     Custom SceneManagers which load custom world geometry should call this 
     method the number of times equal to the value they return from 
     SceneManager.estimateWorldGeometry while loading their geometry.
     */
    void _notifyWorldGeometryStageStarted(string description)
    {
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.worldGeometryStageStarted(description);
            }
        }
    }
    /** Notify this manager that one stage of world geometry loading has been 
     completed.
     @remarks
     Custom SceneManagers which load custom world geometry should call this 
     method the number of times equal to the value they return from 
     SceneManager.estimateWorldGeometry while loading their geometry.
     */
    void _notifyWorldGeometryStageEnded()
    {
        synchronized(mLock)
        {
            foreach (l; mResourceGroupListenerList)
            {
                l.worldGeometryStageEnded();
            }
        }
    }
    
    /** Get a list of the currently defined resource groups. 
     @note This method intentionally returns a copy rather than a reference in
     order to avoid any contention issues in multithreaded applications.
     @return A copy of list of currently defined groups.
     */
    StringVector getResourceGroups()
    {
        synchronized(mLock)
        {
            StringVector vec;
            foreach (k,v; mResourceGroupMap)
            {
                vec.insert(v.name);
            }
            return vec;
        }
    }
    /** Get the list of resource declarations for the specified group name. 
     @note This method intentionally returns a copy rather than a reference in
     order to avoid any contention issues in multithreaded applications.
     @param groupName The name of the group
     @return A copy of list of currently defined resources.
     */
    ResourceDeclarationList getResourceDeclarationList(string groupName)
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.getResourceDeclarationList");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                return grp.resourceDeclarations;
            }
        }
    }
    
    /** Get the list of resource locations for the specified group name.
     @param groupName The name of the group
     @return The list of resource locations associated with the given group.
     */      
    ref LocationList getResourceLocationList(string groupName)
    {
        synchronized(mLock)
        {
            auto grp = getResourceGroup(groupName);
            if (grp is null)
            {
                throw new ItemNotFoundError(
                    "Cannot locate a resource group called '" ~ groupName ~ "'", 
                    "ResourceGroupManager.getResourceLocationList");
            }
            
            //OGRE_LOCK_MUTEX(grp.OGRE_AUTO_MUTEX_NAME) // lock group mutex
            synchronized(grp.mLock)
            {
                return grp.locationList;
            }
        }
    }
    /// Sets a new loading listener
    void setLoadingListener(ref ResourceLoadingListener listener)
    {
        mLoadingListener = listener;
    }
    /// Returns the current loading listener
    ref ResourceLoadingListener getLoadingListener()
    {
        return mLoadingListener;
    }
    
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    //static ResourceGroupManager& getSingleton();
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    //static ResourceGroupManager* getSingletonPtr();
    
}
