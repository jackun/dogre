module ogre.resources.resourcebackgroundqueue;

//import std.container;
import std.algorithm;
import std.range;

import ogre.general.workqueue;
import ogre.singleton;
import ogre.resources.resource;
import ogre.compat;
import ogre.config;
import ogre.general.root;
import ogre.general.common;
import ogre.resources.resourcegroupmanager;
import ogre.resources.resourcemanager;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */

/// Identifier of a background process
alias WorkQueue.RequestID BackgroundProcessTicket;

/** Encapsulates the result of a background queue request */
struct BackgroundProcessResult
{
    /// Whether an error occurred
    bool error = false;
    /// Any messages from the process
    string message;
}


/** This class is used to perform Resource operations in a
 background thread. 
 @remarks
 All these requests are now queued via Root::getWorkQueue in order
 to share the thread pool amongst all background tasks. You should Therefore
 ref er to that class for configuring the behaviour of the threads
 themselves, this class merely provides an interface that is specific
 to resource loading around this common functionality.
 @par
 The general approach here is that on requesting a background resource
 process, your request is placed on a queue ready for the background
 thread to be picked up, and you will get a 'ticket' back, identifying
 the request. Your call will then return and your thread can
 proceed, knowing that at some point in the background the operation will 
 be performed. In it's own thread, the resource operation will be 
 performed, and once finished the ticket will be marked as complete. 
 You can check the status of tickets by calling isProcessComplete() 
 from your queueing thread. 
 */
class ResourceBackgroundQueue : WorkQueue.RequestHandler, WorkQueue.ResponseHandler
    //public ResourceAlloc
{
    mixin Singleton!ResourceBackgroundQueue;
public:
    /** This abstract listener interface lets you get notifications of
     completed background processes instead of having to poll ticket 
     statuses.
     @note
     For simplicity, these callbacks are not issued direct from the background
     loading thread, they are queued themselves to be sent from the main thread
     so that you don't have to be concerned about thread safety. 
     */
    interface Listener
    {
        /** Called when a requested operation completes, queued into main thread. 
         @note
         For simplicity, this callback is not issued direct from the background
         loading thread, it is queued to be sent from the main thread
         so that you don't have to be concerned about thread safety. 
         */
        void operationCompleted(BackgroundProcessTicket ticket,BackgroundProcessResult result);
    }
    
protected:
    
    ushort mWorkQueueChannel;
    /** Enumerates the type of requests */
    enum RequestType
    {
        RT_INITIALISE_GROUP = 0,
        RT_INITIALISE_ALL_GROUPS = 1,
        RT_PREPARE_GROUP = 2,
        RT_PREPARE_RESOURCE = 3,
        RT_LOAD_GROUP = 4,
        RT_LOAD_RESOURCE = 5,
        RT_UNLOAD_GROUP = 6,
        RT_UNLOAD_RESOURCE = 7
    }
    /** Encapsulates a queued request for the background queue */
    struct ResourceRequest
    {
        RequestType type;
        string resourceName;
        ResourceHandle resourceHandle;
        string resourceType;
        string groupName;
        bool isManual; 
        ManualResourceLoader loader;
        NameValuePairList loadParams;
        Listener listener;
        BackgroundProcessResult result;
    }
    
    //typedef set<BackgroundProcessTicket>::type OutstandingRequestSet;   
    alias BackgroundProcessTicket[] OutstandingRequestSet;   
    OutstandingRequestSet mOutstandingRequestSet;
    
    /// Struct that holds details of queued notifications
    //struct 
    class ResourceResponse //TODO ResourceResponse into class for Variant
    {
        this(SharedPtr!Resource r,ResourceRequest req)
        {
            resource = r;
            request = req;
        }
        
        SharedPtr!Resource resource;
        ResourceRequest request;
    }
    
    BackgroundProcessTicket addRequest(ResourceRequest req)
    {
        WorkQueue queue = Root.getSingleton().getWorkQueue();
        
        auto data = Any(req);
        
        WorkQueue.RequestID requestID = 
            queue.addRequest(mWorkQueueChannel, cast(ushort)req.type, data);

        mOutstandingRequestSet.insert(requestID);
        
        return requestID;
    }
    
public:
    this(){}

    ~this()
    {
        shutdown();
    }
    
    /** Initialise the background queue system. 
     @note Called automatically by Root::initialise.
     */
    void initialise()
    {
        WorkQueue wq = Root.getSingleton().getWorkQueue();
        mWorkQueueChannel = wq.getChannel("Ogre/ResourceBGQ");
        wq.addResponseHandler(mWorkQueueChannel, this);
        wq.addRequestHandler(mWorkQueueChannel, this);
    }
    
    /** Shut down the background queue system. 
     @note Called automatically by Root::shutdown.
     */
    void shutdown()
    {
        WorkQueue wq = Root.getSingleton().getWorkQueue();
        wq.abortRequestsByChannel(mWorkQueueChannel);
        wq.removeRequestHandler(mWorkQueueChannel, this);
        wq.removeResponseHandler(mWorkQueueChannel, this);
    }
    
    /** Initialise a resource group in the background.
     @see ResourceGroupManager.initialiseResourceGroup
     @param name The name of the resource group to initialise
     @param listener Optional callback interface, take note of warnings in 
     the header and only use if you understand them.
     @return Ticket identifying the request, use isProcessComplete() to 
     determine if completed if not using listener
     */
    BackgroundProcessTicket initialiseResourceGroup(
       string name, Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_INITIALISE_GROUP;
            req.groupName = name;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceGroupManager.getSingleton().initialiseResourceGroup(name);
            return 0; 
        }
    }
    /** Initialise all resource groups which are yet to be initialised in 
     the background.
     @see ResourceGroupManager.intialiseResourceGroup
     @param listener Optional callback interface, take note of warnings in 
     the header and only use if you understand them.
     @return Ticket identifying the request, use isProcessComplete() to 
     determine if completed if not using listener
     */
    BackgroundProcessTicket initialiseAllResourceGroups(Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_INITIALISE_ALL_GROUPS;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceGroupManager.getSingleton().initialiseAllResourceGroups();
            return 0; 
        }
    }
    /** Prepares a resource group in the background.
     @see ResourceGroupManager.prepareResourceGroup
     @param name The name of the resource group to prepare
     @param listener Optional callback interface, take note of warnings in 
     the header and only use if you understand them.
     @return Ticket identifying the request, use isProcessComplete() to 
     determine if completed if not using listener
     */
    BackgroundProcessTicket prepareResourceGroup(string name, 
                                                 Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_PREPARE_GROUP;
            req.groupName = name;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceGroupManager.getSingleton().prepareResourceGroup(name);
            return 0; 
        }
    }
    
    /** Loads a resource group in the background.
     @see ResourceGroupManager.loadResourceGroup
     @param name The name of the resource group to load
     @param listener Optional callback interface, take note of warnings in 
     the header and only use if you understand them.
     @return Ticket identifying the request, use isProcessComplete() to 
     determine if completed if not using listener
     */
    BackgroundProcessTicket loadResourceGroup(string name, 
                                              Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_LOAD_GROUP;
            req.groupName = name;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceGroupManager.getSingleton().loadResourceGroup(name);
            return 0; 
        }
    }
    
    
    /** Unload a single resource in the background. 
     @see ResourceManager::unload
     @param resType The type of the resource 
     (from ResourceManager::getResourceType())
     @param name The name of the Resource
     */
    BackgroundProcessTicket unload(
       string resType,string name, 
        Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_UNLOAD_RESOURCE;
            req.resourceType = resType;
            req.resourceName = name;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceManager rm = 
                ResourceGroupManager.getSingleton()._getResourceManager(resType);
            rm.unload(name);
            return 0; 
        }
        
    }
    /** Unload a single resource in the background. 
     @see ResourceManager::unload
     @param resType The type of the resource 
     (from ResourceManager::getResourceType())
     @param handle Handle to the resource 
     */
    BackgroundProcessTicket unload(
       string resType, ResourceHandle handle, 
        Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_UNLOAD_RESOURCE;
            req.resourceType = resType;
            req.resourceHandle = handle;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceManager rm = 
                ResourceGroupManager.getSingleton()._getResourceManager(resType);
            rm.unload(handle);
            return 0; 
        }
        
    }
    /** Unloads a resource group in the background.
     @see ResourceGroupManager.unloadResourceGroup
     @param name The name of the resource group to load
     @return Ticket identifying the request, use isProcessComplete() to 
     determine if completed if not using listener
     */
    BackgroundProcessTicket unloadResourceGroup(string name, 
                                                Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_UNLOAD_GROUP;
            req.groupName = name;
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceGroupManager.getSingleton().unloadResourceGroup(name);
            return 0; 
        }
    }
    
    
    /** Prepare a single resource in the background. 
     @see ResourceManager::prepare
     @param resType The type of the resource 
     (from ResourceManager::getResourceType())
     @param name The name of the Resource
     @param group The resource group to which this resource will belong
     @param isManual Is the resource to be manually loaded? If so, you should
     provide a value for the loader parameter
     @param loader The manual loader which is to perform the required actions
     when this resource is loaded; only applicable when you specify true
     for the previous parameter. NOTE: must be thread safe!!
     @param loadParams Optional pointer to a list of name/value pairs 
     containing loading parameters for this type of resource. Remember 
     that this must have a lifespan longer than the return of this call!
     */
    BackgroundProcessTicket prepare(
       string resType,string name, 
       string group, bool isManual = false, 
        ManualResourceLoader loader = null, 
       NameValuePairList loadParams = NameValuePairList.init, 
        Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_PREPARE_RESOURCE;
            req.resourceType = resType;
            req.resourceName = name;
            req.groupName = group;
            req.isManual = isManual;
            req.loader = loader;
            // Make instance copy of loadParams for thread independence
            req.loadParams = loadParams.dup; //( loadParams ? OGRE_NEW_T(NameValuePairList, MEMCATEGORY_GENERAL)( *loadParams ) : 0 );
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceManager rm = 
                ResourceGroupManager.getSingleton()._getResourceManager(resType);
            rm.prepare(name, group, isManual, loader, loadParams);
            return 0; 
        }
    }

    /** Load a single resource in the background. 
     @see ResourceManager::load
     @param resType The type of the resource 
     (from ResourceManager::getResourceType())
     @param name The name of the Resource
     @param group The resource group to which this resource will belong
     @param isManual Is the resource to be manually loaded? If so, you should
     provide a value for the loader parameter
     @param loader The manual loader which is to perform the required actions
     when this resource is loaded; only applicable when you specify true
     for the previous parameter. NOTE: must be thread safe!!
     @param loadParams Optional pointer to a list of name/value pairs 
     containing loading parameters for this type of resource. Remember 
     that this must have a lifespan longer than the return of this call!
     */
    BackgroundProcessTicket load(
       string resType,string name, 
       string group, bool isManual = false, 
        ManualResourceLoader loader = null, 
       NameValuePairList loadParams = NameValuePairList.init, 
        Listener listener = null)
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // queue a request
            ResourceRequest req;
            req.type = RequestType.RT_LOAD_RESOURCE;
            req.resourceType = resType;
            req.resourceName = name;
            req.groupName = group;
            req.isManual = isManual;
            req.loader = loader;
            // Make instance copy of loadParams for thread independence
            req.loadParams = loadParams.dup;//( loadParams ? OGRE_NEW_T(NameValuePairList, MEMCATEGORY_GENERAL)( *loadParams ) : 0 );
            req.listener = listener;
            return addRequest(req);
        }
        else
        {
            // synchronous
            ResourceManager rm = 
                ResourceGroupManager.getSingleton()._getResourceManager(resType);
            rm.load(name, group, isManual, loader, loadParams);
            return 0; 
        }
    }
    /** Returns whether a previously queued process has completed or not. 
     @remarks
     This method of checking that a background process has completed is
     the 'polling' approach. Each queued method takes an optional listener
     parameter to allow you to register a callback instead, which is
     arguably more efficient.
     @param ticket The ticket which was returned when the process was queued
     @return true if process has completed (or if the ticket is 
     unrecognised), false otherwise
     @note Tickets are not stored once complete so do not accumulate over 
     time.
     This is why a non-existent ticket will return 'true'.
     */
    bool isProcessComplete(BackgroundProcessTicket ticket)
    {
        return mOutstandingRequestSet[].find(ticket).empty;
    }

    /** Aborts background process.
     */
    void abortRequest( BackgroundProcessTicket ticket )
    {
        WorkQueue queue = Root.getSingleton().getWorkQueue();
        
        queue.abortRequest( ticket );
    }
    
    /// Implementation for WorkQueue::RequestHandler
    bool canHandleRequest(WorkQueue.Request req, WorkQueue srcQ)
    {
        return true;
    }

    /// Implementation for WorkQueue::RequestHandler
    WorkQueue.Response handleRequest(WorkQueue.Request req, WorkQueue srcQ)
    {
        
        ResourceRequest resreq = req.getData().get!ResourceRequest;
        
        if( req.getAborted() )
        {
            if( resreq.type == RequestType.RT_PREPARE_RESOURCE || resreq.type == RequestType.RT_LOAD_RESOURCE )
            {
                //OGRE_DELETE_T(resreq.loadParams, NameValuePairList, MEMCATEGORY_GENERAL);
                //resreq.loadParams = 0;
                //TODO As NameValuePairList is assoc. array, can't exactly delete it
                resreq.loadParams.clear();
            }
            resreq.result.error = false;
            
            auto resresp = new ResourceResponse(SharedPtr!Resource(), resreq);
            return new WorkQueue.Response(req, true, Any(resresp));
        }
        
        ResourceManager rm;
        SharedPtr!Resource resource;
        try
        {
            
            final switch (resreq.type)
            {
                case RequestType.RT_INITIALISE_GROUP:
                    ResourceGroupManager.getSingleton().initialiseResourceGroup(
                        resreq.groupName);
                    break;
                case RequestType.RT_INITIALISE_ALL_GROUPS:
                    ResourceGroupManager.getSingleton().initialiseAllResourceGroups();
                    break;
                case RequestType.RT_PREPARE_GROUP:
                    ResourceGroupManager.getSingleton().prepareResourceGroup(
                        resreq.groupName);
                    break;
                case RequestType.RT_LOAD_GROUP:
                    static if(OGRE_THREAD_SUPPORT == 2)
                        ResourceGroupManager.getSingleton().prepareResourceGroup(
                            resreq.groupName);
                    else
                        ResourceGroupManager.getSingleton().loadResourceGroup(
                            resreq.groupName);

                    break;
                case RequestType.RT_UNLOAD_GROUP:
                    ResourceGroupManager.getSingleton().unloadResourceGroup(
                        resreq.groupName);
                    break;
                case RequestType.RT_PREPARE_RESOURCE:
                    rm = ResourceGroupManager.getSingleton()._getResourceManager(
                        resreq.resourceType);
                    resource = rm.prepare(resreq.resourceName, resreq.groupName, resreq.isManual, 
                                          resreq.loader, resreq.loadParams, true);
                    break;
                case RequestType.RT_LOAD_RESOURCE:
                    rm = ResourceGroupManager.getSingleton()._getResourceManager(
                        resreq.resourceType);
                    static if(OGRE_THREAD_SUPPORT == 2)
                        resource = rm.prepare(resreq.resourceName, resreq.groupName, resreq.isManual, 
                                              resreq.loader, resreq.loadParams, true);
                    else
                        resource = rm.load(resreq.resourceName, resreq.groupName, resreq.isManual, 
                                           resreq.loader, resreq.loadParams, true);

                    break;
                case RequestType.RT_UNLOAD_RESOURCE:
                    rm = ResourceGroupManager.getSingleton()._getResourceManager(
                        resreq.resourceType);
                    if (resreq.resourceName is null || resreq.resourceName.empty())
                        rm.unload(resreq.resourceHandle);
                    else
                        rm.unload(resreq.resourceName);
                    break;
            }
        }
        catch (Exception e)
        {
            if( resreq.type == RequestType.RT_PREPARE_RESOURCE || resreq.type == RequestType.RT_LOAD_RESOURCE )
            {
                //OGRE_DELETE_T(resreq.loadParams, NameValuePairList, MEMCATEGORY_GENERAL);
                //resreq.loadParams = 0;
                resreq.loadParams.clear();
            }
            resreq.result.error = true;
            resreq.result.message = e.msg;
            
            // return error response
            auto resresp = new ResourceResponse(resource, resreq);
            return new WorkQueue.Response(req, false, Any(resresp), e.msg);
        }
        
        
        // success
        if( resreq.type == RequestType.RT_PREPARE_RESOURCE || resreq.type == RequestType.RT_LOAD_RESOURCE )
        {
            //OGRE_DELETE_T(resreq.loadParams, NameValuePairList, MEMCATEGORY_GENERAL);
            //resreq.loadParams = 0;
            resreq.loadParams.clear();
        }
        resreq.result.error = false;
        auto resresp = new ResourceResponse(resource, resreq);
        return new WorkQueue.Response(req, true, Any(resresp));
        
    }

    /// Implementation for WorkQueue::ResponseHandler
    bool canHandleResponse(WorkQueue.Response res, WorkQueue srcQ)
    {
        return true;
    }

    /// Implementation for WorkQueue::ResponseHandler
    void handleResponse(WorkQueue.Response res, WorkQueue srcQ)
    {
        if( res.getRequest().getAborted() )
        {
            mOutstandingRequestSet.removeFromArray(res.getRequest().getID());
            return ;
        }
        
        
        ResourceResponse resresp = res.getData().get!ResourceResponse;
        
        // Complete full loading in main thread if semithreading
        ResourceRequest req = resresp.request;
            
        if (res.succeeded())
        {
            static if(OGRE_THREAD_SUPPORT == 2)
            {
                // These load commands would have been downgraded to prepare() for the background
                if (req.type == RequestType.RT_LOAD_RESOURCE)
                {
                    ResourceManager rm = ResourceGroupManager.getSingleton()
                        ._getResourceManager(req.resourceType);
                    rm.load(req.resourceName, req.groupName, req.isManual, req.loader, req.loadParams, true);
                } 
                else if (req.type == RequestType.RT_LOAD_GROUP)
                {
                    ResourceGroupManager.getSingleton().loadResourceGroup(req.groupName);
                }
            }

            mOutstandingRequestSet.removeFromArray(res.getRequest().getID());
            
            // Call resource listener
            if (!resresp.resource.isNull()) 
            {
                
                if (req.type == RequestType.RT_LOAD_RESOURCE) 
                {
                    resresp.resource.get()._fireLoadingComplete( true );
                } 
                else 
                {
                    resresp.resource.get()._firePreparingComplete( true );
                }
            } 
        }
        // Call queue listener
        if (req.listener)
            req.listener.operationCompleted(res.getRequest().getID(), req.result);
    }

}

/** @} */
/** @} */