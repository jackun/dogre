module ogre.general.workqueue;

import core.sync.mutex;
import core.sync.rwmutex;
import core.thread;

//import std.container;
import std.algorithm;
import std.array;

import ogre.general.atomicwrappers;
import ogre.compat;
import ogre.config;
import ogre.general.log;
import ogre.general.root;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */

/** Interface to a general purpose request / response style background work queue.
 @remarks
 A work queue is a simple structure, where requests for work are placed
 onto the queue, then removed by a worker for processing, then finally
 a response is placed on the result queue for the originator to pick up
 at their leisure. The typical use for this is in a threaded environment, 
 although any kind of deferred processing could use this approach to 
 decouple and distribute work over a period of time even 
 if it was single threaded.
 @par
 WorkQueues also incorporate thread pools. One or more background worker threads
 can wait on the queue and be notified when a request is waiting to be
 processed. For maximal thread usage, a WorkQueue instance should be shared
 among many sources of work, rather than many work queues being created.
 This way, you can share a small number of hardware threads among a large 
 number of background tasks. This doesn't mean you have to implement all the
 request processing in one class, you can plug in many handlers in order to
 process the requests.
 @par
 This is an abstract interface definition; users can subclass this and 
 provide their own implementation if required to centralise task management
 in their own subsystems. We also provide a default implementation in the
 form of DefaultWorkQueue.
 */
class WorkQueue //: public UtilityAlloc
{
protected:
    //typedef std::map<String, ushort> ChannelMap;
    alias ushort[string] ChannelMap;

    ChannelMap mChannelMap;
    ushort mNextChannel;
    //OGRE_MUTEX(mChannelMapMutex)
    Mutex mChannelMapMutex;
public:
    /// Numeric identifier for a request
    //typedef unsigned long long int RequestID;
    alias ulong RequestID;
    
    /** General purpose request structure. 
     */
    static class Request //: public UtilityAlloc
    {
        //friend class WorkQueue;
    protected:
        /// The request channel, as an integer 
        ushort mChannel;
        /// The request type, as an integer within the channel (user can define enumerations on this)
        ushort mType;
        /// The details of the request (user defined)
        Any mData;
        /// Retry count - set this to non-zero to have the request try again on failure
        ubyte mRetryCount;
        /// Identifier (assigned by the system)
        RequestID mID;
        /// Abort Flag
        //mutable 
        bool mAborted;
        
    public:
        /// Constructor 
        this(ushort channel, ushort rtype,Any rData, ubyte retry, RequestID rid)
        {
            mChannel = channel;
            mType = rtype;
            mData = rData;
            mRetryCount = retry;
            mID = rid;
            mAborted = false;
        }
        ~this(){}
        /// Set the abort flag
        void abortRequest(){ mAborted = true; }
        /// Get the request channel (top level categorisation)
        ushort getChannel(){ return mChannel; }
        /// Get the type of this request within the given channel
        ushort getType(){ return mType; }
        /// Get the user details of this request
        Any getData(){ return mData; }
        /// Get the remaining retry count
        ubyte getRetryCount(){ return mRetryCount; }
        /// Get the identifier of this request
        RequestID getID(){ return mID; }
        /// Get the abort flag
        bool getAborted(){ return mAborted; }
    }
    
    /** General purpose response structure. 
     */
    //struct 
    //Make class so it can be nulled
    static class Response //: public UtilityAlloc
    {
        /// Pointer to the request that this response is in relation to
        //
        Request mRequest;
        /// Whether the work item succeeded or not
        bool mSuccess;
        /// Any diagnostic messages
        string mMessages;
        /// Data associated with the result of the process
        Any mData;
        
    public:
        this(Request rq, bool success,Any data,string msg = null)
        {
            mRequest = rq;
            mSuccess = success;
            mMessages = msg;
            mData = data;
        }
        ~this()
        {
            destroy(mRequest);
        }

        /// Get the request that this is a response to (NB destruction destroys this)
        ref Request getRequest(){ return mRequest; }
        /// Return whether this is a successful response
        bool succeeded(){ return mSuccess; }
        /// Get any diagnostic messages about the process
        string getMessages(){ return mMessages; }
        /// Return the response data (user defined, only valid on success)
        Any getData(){ return mData; }
        /// Abort the request
        void abortRequest()
        {
            mRequest.abortRequest();
            mData.destroy(); //TODO C++ Any has destroy(). Using D's builtin destroy() (or GC?)
            mData = null;    //D's destroy() leaves mData in undefined state, so also null it.
        }
    }
    
    /** Interface definition for a handler of requests. 
     @remarks
     User classes are expected to implement this interface in order to
     process requests on the queue. It's important to realise that
     the calls to this class may be in a separate thread to the main
     render context, and as such it may not be possible to make
     rendersystem or other GPU-dependent calls in this handler. You can only
     do so if the queue was created with 'workersCanAccessRenderSystem'
     set to true, and OGRE_THREAD_SUPPORT=1, but this puts extra strain
     on the thread safety of the render system and is not recommended.
     It is best to perform CPU-side work in these handlers and let the
     response handler transfer results to the GPU in the main render thread.
     */
    interface RequestHandler
    {
        /** Return whether this handler can process a given request. 
         @remarks
         Defaults to true, but if you wish to add several handlers each of
         which deal with different types of request, you can override
         this method. 
         Default
         return !req.getAborted();
         */
        bool canHandleRequest(Request req, WorkQueue srcQ);
        //{ (void)srcQ; return !req.getAborted(); }
        
        /** The handler method every subclass must implement. 
         If a failure is encountered, return a Response with a failure
         result rather than raise an exception.
         @param req The Request structure, which is effectively owned by the
         handler during this call. It must be attached to the returned
         Response regardless of success or failure.
         @param srcQ The work queue that this request originated from
         @return Pointer to a Response object - the caller is responsible
         for deleting the object.
         */
        Response handleRequest(Request req, WorkQueue srcQ);
    }
    
    /** Interface definition for a handler of responses. 
     @remarks
     User classes are expected to implement this interface in order to
     process responses from the queue. All calls to this class will be 
     in the main render thread and thus all GPU resources will be
     available. 
     */
    interface ResponseHandler
    {
        /** Return whether this handler can process a given response. 
         @remarks
         Defaults to true, but if you wish to add several handlers each of
         which deal with different types of response, you can override
         this method. 
         Default
         return !res.getRequest().getAborted();
         */
        bool canHandleResponse(Response res, WorkQueue srcQ);
        //{ (void)srcQ; return !res.getRequest().getAborted(); }
        
        /** The handler method every subclass must implement. 
         @param res The Response structure. The caller is responsible for
         deleting this after the call is made, none of the data contained
         (except pointers to structures in user Any data) will persist
         after this call is returned.
         @param srcQ The work queue that this request originated from
         */
        void handleResponse(Response res, WorkQueue srcQ);
    }
    
    this(){ mNextChannel = 0; mChannelMapMutex = new Mutex; }
    ~this() {}
    
    /** Start up the queue with the options that have been set.
     @param forceRestart If the queue is already running, whether to shut it
     down and restart.
     */
    abstract void startup(bool forceRestart = true);
    /** Add a request handler instance to the queue. 
     @remarks
     Every queue must have at least one request handler instance for each 
     channel in which requests are raised. If you 
     add more than one handler per channel, then you must implement canHandleRequest 
     differently in each if you wish them to respond to different requests.
     @param channel The channel for requests you want to handle
     @param rh Your handler
     */
    abstract void addRequestHandler(ushort channel, RequestHandler rh);
    /** Remove a request handler. */
    abstract void removeRequestHandler(ushort channel, RequestHandler rh);
    
    /** Add a response handler instance to the queue. 
     @remarks
     Every queue must have at least one response handler instance for each 
     channel in which requests are raised. If you add more than one, then you 
     must implement canHandleResponse differently in each if you wish them 
     to respond to different responses.
     @param channel The channel for responses you want to handle
     @param rh Your handler
     */
    abstract void addResponseHandler(ushort channel, ResponseHandler rh);
    /** Remove a Response handler. */
    abstract void removeResponseHandler(ushort channel, ResponseHandler rh);
    
    /** Add a new request to the queue.
     @param channel The channel this request will go into = 0; the channel is the top-level
     categorisation of the request
     @param requestType An identifier that's unique within this queue which
     identifies the type of the request (user decides the actual value)
     @param rData The data required by the request process. 
     @param retryCount The number of times the request should be retried
     if it fails.
     @param forceSynchronous Forces the request to be processed immediately
     even if threading is enabled.
     @param idleThread Request should be processed on the idle thread.
            Idle requests will be processed on a single worker thread. You should use this in the following situations:
            1. If a request handler can't process multiple requests in parallel.
            2. If you add lot of requests, but you want to keep the game fast.
            3. If you have lot of more important threads. (example: physics).
     @return The ID of the request that has been added
     */
    abstract RequestID addRequest(ushort channel, ushort requestType,Any rData, ubyte retryCount = 0, 
                                  bool forceSynchronous = false, bool idleThread = false);
    
    /** Abort a previously issued request.
     If the request is still waiting to be processed, it will be 
     removed from the queue.
     @param id The ID of the previously issued request.
     */
    abstract void abortRequest(RequestID id);
    
    /** Abort all previously issued requests in a given channel.
     Any requests still waiting to be processed of the given channel, will be 
     removed from the queue.
     Requests which are processed, but response handler is not called will also be removed.
     @param channel The type of request to be aborted
     */
    abstract void abortRequestsByChannel(ushort channel);
    
    /** Abort all previously issued requests in a given channel.
        Any requests still waiting to be processed of the given channel, will be 
        removed from the queue.
        It will not remove requests, where the request handler is already called.
        @param channel The type of request to be aborted
        */
    abstract void abortPendingRequestsByChannel(ushort channel);
    
    /** Abort all previously issued requests.
     Any requests still waiting to be processed will be removed from the queue.
     Any requests that are being processed will still complete.
     */
    abstract void abortAllRequests();
    
    /** Set whether to pause further processing of any requests. 
     If true, any further requests will simply be queued and not processed until
     setPaused(false) is called. Any requests which are in the process of being
     worked on already will still continue. 
     */
    abstract void setPaused(bool pause);
    /// Return whether the queue is paused ie not sending more work to workers
    abstract bool isPaused();
    
    /** Set whether to accept new requests or not. 
     If true, requests are added to the queue as usual. If false, requests
     are silently ignored until setRequestsAccepted(true) is called. 
     */
    abstract void setRequestsAccepted(bool accept);
    /// Returns whether requests are being accepted right now
    abstract bool getRequestsAccepted();
    
    /** Process the responses in the queue.
     @remarks
     This method is public, and must be called from the main render
     thread to 'pump' responses through the system. The method will usually
     try to clear all responses before returning = 0; however, you can specify
     a time limit on the response processing to limit the impact of
     spikes in demand by calling setResponseProcessingTimeLimit.
     */
    abstract void processResponses();
    
    /** Get the time limit imposed on the processing of responses in a
     single frame, in milliseconds (0 indicates no limit).
     */
    abstract ulong getResponseProcessingTimeLimit();
    
    /** Set the time limit imposed on the processing of responses in a
     single frame, in milliseconds (0 indicates no limit).
     This sets the maximum time that will be spent in processResponses() in 
     a single frame. The default is 8ms.
     */
    abstract void setResponseProcessingTimeLimit(ulong ms);
    
    /** Shut down the queue.
     */
    abstract void shutdown();
    
    /** Get a channel ID for a given channel name. 
     @remarks
     Channels are assigned on a first-come, first-served basis and are
     not persistent across application instances. This method allows 
     applications to not worry about channel clashes through manually
     assigned channel numbers.
     */
    ushort getChannel(string channelName)
    {
        synchronized(mChannelMapMutex)
        {
            auto i = channelName in mChannelMap;
            if (i is null)
            {
                mChannelMap[channelName] = mNextChannel++;
                return mNextChannel;
            }
            return *i;
        }
    }
    
}

/** Base for a general purpose request / response style background work queue.
 */
class DefaultWorkQueueBase : WorkQueue
{
public:
    
    /** Constructor.
     Call startup() to initialise.
     @param name Optional name, just helps to identify logging output
     */
    this(string name = null)
    {
        mName = name;
        mWorkerThreadCount = 1;
        mWorkerRenderSystemAccess = false;
        mIsRunning = false;
        mResposeTimeLimitMS = 8;
        mWorkerFunc = null;
        mRequestCount = 0;
        mPaused = false;
        mAcceptRequests = true;
        mIdleProcessed = null;

        mIdleMutex = new Mutex;
        mRequestMutex = new Mutex;
        mProcessMutex = new Mutex;
        mResponseMutex = new Mutex;
        mRequestHandlerMutex = new ReadWriteMutex;
    }
    ~this()
    {
        //shutdown(); // can't call here; abstract function
        
        foreach (i; mRequestQueue)
        {
            destroy(i);
        }
        mRequestQueue.clear();
        
        foreach (i; mResponseQueue)
        {
            destroy(i);
        }
        mResponseQueue.clear();
    }

    /// Get the name of the work queue
    string getName()
    {
        return mName;
    }

    /** Get the number of worker threads that this queue will start when 
     startup() is called. 
     */
    size_t getWorkerThreadCount()
    {
        return mWorkerThreadCount;
    }
    
    /** Set the number of worker threads that this queue will start
     when startup() is called (default 1).
     Calling this will have no effect unless the queue is shut down and
     restarted.
     */
    void setWorkerThreadCount(size_t c)
    {
        mWorkerThreadCount = c;
    }
    
    /** Get whether worker threads will be allowed to access render system
     resources. 
     Accessing render system resources from a separate thread can require that
     a context is maintained for that thread. Also, it requires that the
     render system is running in threadsafe mode, which only happens
     when OGRE_THREAD_SUPPORT=1. This option defaults to false, which means
     that threads can not use GPU resources, and the render system can 
     work in non-threadsafe mode, which is more efficient.
     */
    bool getWorkersCanAccessRenderSystem()
    {
        return mWorkerRenderSystemAccess;
    }
    
    
    /** Set whether worker threads will be allowed to access render system
     resources. 
     Accessing render system resources from a separate thread can require that
     a context is maintained for that thread. Also, it requires that the
     render system is running in threadsafe mode, which only happens
     when OGRE_THREAD_SUPPORT=1. This option defaults to false, which means
     that threads can not use GPU resources, and the render system can 
     work in non-threadsafe mode, which is more efficient.
     Calling this will have no effect unless the queue is shut down and
     restarted.
     */
    void setWorkersCanAccessRenderSystem(bool access)
    {
        mWorkerRenderSystemAccess = access;
    }
    
    /** Process the next request on the queue. 
     @remarks
     This method is public, but only intended for advanced users to call. 
     The only reason you would call this, is if you were using your 
     own thread to drive the worker processing. The thread calling this
     method will be the thread used to call the RequestHandler.
     */
    void _processNextRequest()
    {
        if(processIdleRequests()){
            // Found idle requests.
            return;
        }
        
        Request request = null;
        {
            // scoped to only lock while retrieving the next request
            //OGRE_LOCK_MUTEX(mProcessMutex)
            synchronized(mProcessMutex)
            {
                //OGRE_LOCK_MUTEX(mRequestMutex)
                synchronized(mRequestMutex)
                {
                    if (!mRequestQueue.empty())
                    {
                        request = mRequestQueue.front();
                        mRequestQueue = mRequestQueue[1..$];//.popFront();
                        mProcessQueue ~= request;//push_back
                    }
                }
            }
        }
        
        if (request)
        {
            processRequestResponse(cast(Request)request, false);
        }
    }
    
    /// Main function for each thread spawned.
    abstract void _threadMain();
    
    /** Returns whether the queue is trying to shut down. */
    bool isShuttingDown(){ return mShuttingDown; }
    
    /// @copydoc WorkQueue::addRequestHandler
    override void addRequestHandler(ushort channel, RequestHandler rh)
    {
        //OGRE_LOCK_RW_MUTEX_WRITE(mRequestHandlerMutex);
        synchronized(mRequestHandlerMutex)
        {
            
            auto i = channel in mRequestHandlers;
            if (i is null)
            {
                mRequestHandlers[channel] = null;
                i = &mRequestHandlers[channel];
            }

            RequestHandlerList handlers = *i;
            bool duplicate = false;
            foreach (j; handlers)
            {
                if (j.getHandler() == rh)
                {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate)
                handlers.insert(new RequestHandlerHolder(rh)); //RequestHandlerHolderPtr
        }
    }

    /// @copydoc WorkQueue::removeRequestHandler
    override void removeRequestHandler(ushort channel, RequestHandler rh)
    {
        //OGRE_LOCK_RW_MUTEX_WRITE(mRequestHandlerMutex);
        synchronized(mRequestHandlerMutex)
        {
            auto i = channel in mRequestHandlers;
            if (i !is null)
            {
                RequestHandlerList handlers = *i;
                foreach (j; handlers)
                {
                    if (j.getHandler() == rh)
                    {
                        // Disconnect - this will make it safe across copies of the list
                        // this is threadsafe and will wait for existing processes to finish
                        j.disconnectHandler();
                        handlers.removeFromArray(j);
                        break;
                    }
                }
                
            }
        }
        
    }

    /// @copydoc WorkQueue::addResponseHandler
    override void addResponseHandler(ushort channel, ResponseHandler rh)
    {
        auto i = channel in mResponseHandlers;
        if (i is null)
        {
            mResponseHandlers[channel] = null;
            i = &mResponseHandlers[channel];
        }

        ResponseHandlerList handlers = *i;
        if (handlers.find(rh).empty)
            handlers ~= rh;
    }

    /// @copydoc WorkQueue::removeResponseHandler
    override void removeResponseHandler(ushort channel, ResponseHandler rh)
    {
        auto i = channel in mResponseHandlers;
        if (i !is null)
        {
            ResponseHandlerList handlers = *i;
            handlers.removeFromArray(rh);
        }
    }
    
    /// @copydoc WorkQueue::addRequest
    override RequestID addRequest(ushort channel, ushort requestType,Any rData, ubyte retryCount = 0, 
                                  bool forceSynchronous = false, bool idleThread = false)
    {
        Request req;
        RequestID rid = 0;

        synchronized(mRequestMutex)
        {
            // lock to acquire rid and push request to the queue
            //OGRE_LOCK_MUTEX(mRequestMutex)
            
            if (!mAcceptRequests || mShuttingDown)
                return 0;
            
            rid = ++mRequestCount;
            req = new Request(channel, requestType, rData, retryCount, rid);

            static if(OGRE_THREAD_SUPPORT)
                string strThread = std.conv.to!string(OGRE_THREAD_CURRENT_ID());
            else
                string strThread = "main";

            LogManager.getSingleton().stream(LML_TRIVIAL) << 
                "DefaultWorkQueueBase('" << mName << "') - QUEUED(thread:" <<
                    strThread
                    << "): ID=" << rid
                    << " channel=" << channel << " requestType=" << requestType;
            static if(OGRE_THREAD_SUPPORT)
            {
                if (!forceSynchronous && !idleThread)
                {
                    mRequestQueue ~= req;
                    notifyWorkers();
                    return rid;
                }
            }
        }

        if(idleThread)
        {
            synchronized(mIdleMutex)
            {
                mIdleRequestQueue ~= req;
                if(!mIdleThreadRunning)
                {
                    notifyWorkers();
                }
            }
        } else { //forceSynchronous
            processRequestResponse(req, true);
        }
        
        return rid;
        
    }
    /// @copydoc WorkQueue::abortRequest
    override void abortRequest(RequestID id)
    {
        synchronized(mProcessMutex)
        {
            // NOTE: Pending requests are exist any of RequestQueue, ProcessQueue and
            // ResponseQueue when keeping ProcessMutex, so we check all of these queues.
            
            foreach (i; mProcessQueue)
            {
                auto r = cast(Request)i;
                if (r.getID() == id)
                {
                    r.abortRequest();
                    break;
                }
            }

            synchronized(mRequestMutex)
            {
                foreach (i; mRequestQueue)
                {
                    auto r = cast(Request)i;
                    if (r.getID() == id)
                    {
                        r.abortRequest();
                        break;
                    }
                }
            }

            {
                if(mIdleProcessed)
                {
                    mIdleProcessed.abortRequest();
                }
                
                synchronized(mIdleMutex)
                {
                    foreach (i; mIdleRequestQueue)
                    {
                        i.abortRequest();
                    }
                }
            }
            
            synchronized(mResponseMutex)
            {
                foreach (i; mResponseQueue)
                {
                    auto r = cast(Response)i;
                    if( r.getRequest().getID() == id )
                    {
                        r.abortRequest();
                        break;
                    }
                }
            }
        }
    }

    /// @copydoc WorkQueue::abortRequestsByChannel
    override void abortRequestsByChannel(ushort channel)
    {
        synchronized(mProcessMutex)
        {
            foreach (i; mProcessQueue)
            {
                auto r = cast(Request)i;
                if (r.getChannel() == channel)
                {
                    r.abortRequest();
                }
            }

            synchronized(mRequestMutex)
            {
                foreach (i; mRequestQueue)
                {
                    auto r = cast(Request)i;
                    if (r.getChannel() == channel)
                    {
                        r.abortRequest();
                    }
                }
            }

            {
                if (mIdleProcessed && mIdleProcessed.getChannel() == channel)
                {
                    mIdleProcessed.abortRequest();
                }
                
                synchronized(mIdleMutex)
                {
                    foreach (i; mIdleRequestQueue)
                    {
                        if (i.getChannel() == channel)
                        {
                            i.abortRequest();
                        }
                    }
                }
            }
            
            synchronized(mResponseMutex)
            {
                foreach (i; mResponseQueue)
                {
                    auto r = cast(Response)i;
                    if( r.getRequest().getChannel() == channel )
                    {
                        r.abortRequest();
                    }
                }
            }
        }
    }
    
    override void abortPendingRequestsByChannel(ushort channel)
    {
        synchronized(mRequestMutex)
        {
            foreach (i; mRequestQueue)
            {
                if (i.getChannel() == channel)
                {
                    i.abortRequest();
                }
            }
        }
        synchronized(mIdleMutex)
        {
            foreach (i; mIdleRequestQueue)
            {
                if (i.getChannel() == channel)
                {
                    i.abortRequest();
                }
            }
        }
    }
    
    /// @copydoc WorkQueue::abortAllRequests
    override void abortAllRequests()
    {
        synchronized(mProcessMutex) //TODO check scope
        {
            foreach (i; mProcessQueue)
            {
                (cast(Request)i).abortRequest();
            }
        
        
            synchronized(mRequestMutex)
            {
                foreach (i; mRequestQueue)
                {
                    (cast(Request)i).abortRequest();
                }
            }
    
            {
                if(mIdleProcessed)
                {
                    mIdleProcessed.abortRequest();
                }
                
                synchronized(mIdleMutex)
                {
                    foreach (i; mIdleRequestQueue)
                    {
                        i.abortRequest();
                    }
                }
            }
            
            synchronized(mResponseMutex)
            {
                foreach (i; mResponseQueue)
                {
                    (cast(Response)i).abortRequest();
                }
            }
        }
    }
    /// @copydoc WorkQueue::setPaused
    override void setPaused(bool pause)
    {
        synchronized(mRequestMutex)
            mPaused = pause;
    }

    /// @copydoc WorkQueue::isPaused
    override bool isPaused()
    {
        return mPaused;
    }

    /// @copydoc WorkQueue::setRequestsAccepted
    override void setRequestsAccepted(bool accept)
    {
        synchronized(mRequestMutex)
            mAcceptRequests = accept;
    }

    /// @copydoc WorkQueue::getRequestsAccepted
    override bool getRequestsAccepted()
    {
        return mAcceptRequests;
    }

    /// @copydoc WorkQueue::processResponses
    override void processResponses()
    {
        ulong msStart = Root.getSingleton().getTimer().getMilliseconds();
        ulong msCurrent = 0;
        
        // keep going until we run out of responses or out of time
        while(true)
        {
            Response response;
            synchronized(mResponseMutex)
            {
                if (mResponseQueue.empty())
                    break; // exit loop
                else
                {
                    response = mResponseQueue.front();
                    mResponseQueue.popFront();
                }
            }
            
            if (response)
            {
                processResponse(response);
                destroy(response);
            }
            
            // time limit
            if (mResposeTimeLimitMS)
            {
                msCurrent = Root.getSingleton().getTimer().getMilliseconds();
                if (msCurrent - msStart > mResposeTimeLimitMS)
                    break;
            }
        }
    }

    /// @copydoc WorkQueue::getResponseProcessingTimeLimit
    override ulong getResponseProcessingTimeLimit(){ return mResposeTimeLimitMS; }
    /// @copydoc WorkQueue::setResponseProcessingTimeLimit
    override void setResponseProcessingTimeLimit(ulong ms) { mResposeTimeLimitMS = ms; }

protected:

    //__gshared , shared or nothing?
    __gshared string mName;
    __gshared size_t mWorkerThreadCount;
    __gshared bool mWorkerRenderSystemAccess;
    __gshared bool mIsRunning;
    __gshared ulong mResposeTimeLimitMS;
    
    //typedef deque<Request*>::type RequestQueue;
    //typedef deque<Response*>::type ResponseQueue;
    //alias DList!Request  RequestQueue;
    //alias DList!Response ResponseQueue;
    alias Request[]  RequestQueue;
    alias Response[] ResponseQueue;

    __gshared RequestQueue mRequestQueue; // Guarded by mRequestMutex
    __gshared RequestQueue mProcessQueue; // Guarded by mProcessMutex
    __gshared ResponseQueue mResponseQueue; // Guarded by mResponseMutex
    
    /// Thread function
    class WorkerFunc : Thread
    {
        DefaultWorkQueueBase mQueue;
        
        this(DefaultWorkQueueBase q) 
        {
            super(&run);
            mQueue = q;
        }

        void opCall()
        {
            mQueue._threadMain();
        }
        
        void run()
        {
            mQueue._threadMain();
        }
    }

    WorkerFunc mWorkerFunc;
    
    /** Intermediate structure to hold a pointer to a request handler which 
     provides insurance against the handler itself being disconnected
     while the list remains unchanged.
     */
    static class RequestHandlerHolder //: public UtilityAlloc
    {
    protected:
        //OGRE_RW_MUTEX(mRWMutex)
        ReadWriteMutex mRWMutex;
        RequestHandler mHandler;
    public:
        this(ref RequestHandler handler)
        {
            mRWMutex = new ReadWriteMutex;
            mHandler = handler;
        }
        
        // Disconnect the handler to allow it to be destroyed
        void disconnectHandler()
        {
            // write lock - must wait for all requests to finish
            synchronized(mRWMutex.writer)
                mHandler = null;
        }
        
        /** Get handler pointer - note, only use this for == comparison or similar,
         do not attempt to call it as it is not thread safe. 
         */
        ref RequestHandler getHandler() { return mHandler; }
        
        /** Process a request if possible.
         @return Valid response if processed, null otherwise
         */
        Response handleRequest(Request req, WorkQueue srcQ)
        {
            // Read mutex so that multiple requests can be processed by the
            // same handler in parallel if required
            synchronized(mRWMutex.reader)
            {
                Response response;
                if (mHandler)
                {
                    if (mHandler.canHandleRequest(req, srcQ))
                    {
                        response = mHandler.handleRequest(req, srcQ);
                    }
                }
                return response;
            }
        }
        
    }
    // Hold these by shared pointer so they can be copied keeping same instance
    //NO //alias SharedPtr!RequestHandlerHolder RequestHandlerHolderPtr; //FIXME probably should be SharedPtr
    alias RequestHandlerHolder RequestHandlerHolderPtr;
    
    //typedef list<RequestHandlerHolderPtr>::type RequestHandlerList;
    //typedef list<ResponseHandler*>::type ResponseHandlerList;
    //typedef map<ushort, RequestHandlerList>::type RequestHandlerListByChannel;
    //typedef map<ushort, ResponseHandlerList>::type ResponseHandlerListByChannel;

    alias RequestHandlerHolderPtr[] RequestHandlerList;
    alias ResponseHandler[]         ResponseHandlerList;
    alias RequestHandlerList[ushort]  RequestHandlerListByChannel;
    alias ResponseHandlerList[ushort] ResponseHandlerListByChannel;

    //FIXME __gshared or just shared or nothing?
    //TODO Maybe more things have to be __gshared too

    __gshared RequestHandlerListByChannel  mRequestHandlers;
    __gshared ResponseHandlerListByChannel mResponseHandlers;
    __gshared RequestID                    mRequestCount;// Guarded by mRequestMutex
    __gshared bool mPaused;
    __gshared bool mAcceptRequests;
    __gshared bool mShuttingDown;

    //NOTE: If you lock multiple mutexes at the same time, the order is important!
    // For example if threadA locks mIdleMutex first then tries to lock mProcessMutex,
    // and threadB locks mProcessMutex first, then mIdleMutex. In this case you can get livelock and the system is dead!
    //RULE: Lock mProcessMutex before other mutex, to prevent livelocks
    __gshared Mutex mIdleMutex;
    __gshared Mutex mRequestMutex;
    __gshared Mutex mProcessMutex;
    __gshared Mutex mResponseMutex;
    __gshared ReadWriteMutex mRequestHandlerMutex;
    
    
    void processRequestResponse(Request r, bool synchronous)
    {
        Response response = processRequest(r);
        
        synchronized(mProcessMutex)
        {
            foreach( it; mProcessQueue)
            {
                if( it == r )
                {
                    mProcessQueue.removeFromArray(it);
                    break;
                }
            }
            
            if( mIdleProcessed == r )
            {
                mIdleProcessed = null;
            }
            
            if (response)
            {
                if (!response.succeeded())
                {
                    // Failed, should we retry?
                    Request req = response.getRequest();
                    if (req.getRetryCount())
                    {
                        addRequestWithRID(req.getID(), req.getChannel(), req.getType(), req.getData(), 
                                          cast(ubyte)(req.getRetryCount() - 1));
                        // discard response (this also deletes request(?))
                        destroy(response);
                        return;
                    }
                }
                if (synchronous)
                {
                    processResponse(response);
                    destroy(response);
                }
                else
                {
                    if( response.getRequest().getAborted() )
                    {
                        // destroy response user data
                        response.abortRequest();
                    }
                    // Queue response
                    synchronized(mResponseMutex)
                        mResponseQueue ~= response;
                    // no need to wake thread, this is processed by the main thread
                }
                
            }
            else
            {
                // no response, delete request
                LogManager.getSingleton().stream() << 
                    "DefaultWorkQueueBase('" << mName << "') warning: no handler processed request "
                        << r.getID() << ", channel " << r.getChannel()
                        << ", type " << r.getType();
                destroy(r);
            }
        }
    }

    Response processRequest(Request r)
    {
        RequestHandlerListByChannel handlerListCopy;
        synchronized(mRequestHandlerMutex.reader)
        {
            // lock the list only to make a copy of it, to maximise parallelism
            //OGRE_LOCK_RW_MUTEX_READ(mRequestHandlerMutex);
            handlerListCopy = mRequestHandlers;
        }
        
        Response response;

        string dbgMsg;

        static if(OGRE_THREAD_SUPPORT)
            dbgMsg = std.conv.to!string(OGRE_THREAD_CURRENT_ID());
        else
            dbgMsg = "main";

        dbgMsg ~=
            std.conv.text("): ID=", r.getID(), " channel=", r.getChannel(),
                          " requestType=", r.getType());
        
        LogManager.getSingleton().stream(LML_TRIVIAL) << 
            "DefaultWorkQueueBase('" << mName << "') - PROCESS_REQUEST_START(" << dbgMsg;
        
        auto i = r.getChannel() in handlerListCopy;
        if (i !is null)
        {
            RequestHandlerList handlers = cast(RequestHandlerList)*i;
            foreach_reverse (j; handlers)
            {
                // threadsafe call which tests canHandleRequest and calls it if so 
                response = j.handleRequest(r, this);
                
                if (response)
                    break;
            }
        }
        
        LogManager.getSingleton().stream(LML_TRIVIAL) << 
            "DefaultWorkQueueBase('" << mName << "') - PROCESS_REQUEST_END(" << dbgMsg
                << " processed=" << (response !is null);
        
        return response;
        
    }

    void processResponse(Response r)
    {
        string dbgMsg = "thread:";
        static if(OGRE_THREAD_SUPPORT)
            dbgMsg ~= std.conv.to!string(OGRE_THREAD_CURRENT_ID());
        else
            dbgMsg ~= "main";

        dbgMsg ~= std.conv.text("): ID=", r.getRequest().getID(), 
                                " success=", r.succeeded(), " messages=[", r.getMessages(), "] channel=",
                                r.getRequest().getChannel(), " requestType=", r.getRequest().getType());
        
        LogManager.getSingleton().stream(LML_TRIVIAL) << 
            "DefaultWorkQueueBase('" << mName << "') - PROCESS_RESPONSE_START(" << dbgMsg;
        
        auto i = r.getRequest().getChannel() in mResponseHandlers;
        if (i !is null)
        {
            ResponseHandlerList handlers = cast(ResponseHandlerList)*i;
            foreach_reverse (j; handlers)
            {
                if (j.canHandleResponse(r, this))
                {
                    j.handleResponse(r, this);
                }
            }
        }
        LogManager.getSingleton().stream(LML_TRIVIAL) << 
            "DefaultWorkQueueBase('" << mName << "') - PROCESS_RESPONSE_END(" << dbgMsg;
        
    }

    /// Notify workers about a new request. 
    abstract void notifyWorkers();

    /// Put a Request on the queue with a specific RequestID.
    void addRequestWithRID(RequestID rid, ushort channel, ushort requestType,Any rData, ubyte retryCount)
    {
        // lock to push request to the queue
        synchronized(mRequestMutex)
        {
            if (mShuttingDown)
                return;
            
            Request req = new Request(channel, requestType, rData, retryCount, rid);
            
            static if(OGRE_THREAD_SUPPORT)
                ulong threadId = OGRE_THREAD_CURRENT_ID();
            else
                string threadId = "main";

            LogManager.getSingleton().stream(LML_TRIVIAL) << 
                "DefaultWorkQueueBase('" << mName << "') - REQUEUED(thread:" <<
                    threadId << "): ID=" << rid
                    << " channel=" << channel << " requestType=" << requestType;

            static if(OGRE_THREAD_SUPPORT)
            {
                mRequestQueue ~= req;
                notifyWorkers();
            }
            else
                processRequestResponse(req, true);

        }
    }
    
    RequestQueue mIdleRequestQueue; // Guarded by mIdleMutex
    bool mIdleThreadRunning; // Guarded by mIdleMutex
    Request mIdleProcessed; // Guarded by mProcessMutex
    
    bool processIdleRequests()
    {
        synchronized(mIdleMutex)
        {
            if(mIdleRequestQueue.empty() || mIdleThreadRunning){
                return false;
            } else {
                mIdleThreadRunning = true;
            }
        }
        
        try {
            while(true){
                synchronized(mProcessMutex) // mProcessMutex needs to be the top mutex to prevent livelocks
                {
                    synchronized(mIdleMutex)
                    {
                        if(!mIdleRequestQueue.empty()){
                            mIdleProcessed = mIdleRequestQueue.front;
                            mIdleRequestQueue.popFront();
                        } else {
                            mIdleProcessed = null;
                            mIdleThreadRunning = false;
                            return true;
                        }
                    }
                }
                processRequestResponse(mIdleProcessed, false);
            }
        } catch { // Normally this should not happen.
            {
                // It is very important to clean up or the idle thread will be locked forever!
                synchronized(mProcessMutex)
                {
                    synchronized(mIdleMutex)
                    {
                        if(mIdleProcessed){
                            mIdleProcessed.abortRequest();
                        }
                        mIdleProcessed = 0;
                        mIdleThreadRunning = false;
                    }
                }
            }
            LogManager.getSingleton().stream() << "Exception caught in top of worker thread!\n";
            
            return true;
        }
    }
    
    
}

/** @} */
/** @} */