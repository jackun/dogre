module ogre.threading.defaultworkqueuestandard;

import core.sync.mutex;
import core.sync.rwmutex;
import core.sync.condition;
import core.thread;

import ogre.compat;
import ogre.config;
import ogre.general.workqueue;
import ogre.general.root;
import ogre.general.log;

/** Implementation of a general purpose request / response style background work queue
    using 'core' libraries.
 @remarks
 This default implementation of a work queue starts a thread pool and 
 provides queues to process requests. 
 */
class DefaultWorkQueue : DefaultWorkQueueBase
{
public:
    
    this(string name = null)
    {
        super(name);

        mInitMutex = new Mutex;
        mInitSync = new Condition(mInitMutex);
        mRequestCondition = new Condition(mRequestMutex);
    }

    ~this()
    {
        shutdown();
    }

    /// Main function for each thread spawned.
    override void _threadMain()
    {
        // default worker thread
        static if(OGRE_THREAD_SUPPORT > 0)
        {
            LogManager.getSingleton().stream() << 
                "DefaultWorkQueue('" << getName() << "')::WorkerFunc - thread "
                    << OGRE_THREAD_CURRENT_ID() << " starting.";
            
            // Initialise the thread for RS if necessary
            if (mWorkerRenderSystemAccess)
            {
                Root.getSingleton().getRenderSystem().registerThread();
                notifyThreadRegistered();
            }
            
            // Spin forever until we're told to shut down
            while (!isShuttingDown())
            {
                waitForNextRequest();
                _processNextRequest();
            }
            
            LogManager.getSingleton().stream() << 
                "DefaultWorkQueue('" << getName() << "')::WorkerFunc - thread " 
                    << OGRE_THREAD_CURRENT_ID << " stopped.";
        }
    }
    
    /// @copydoc WorkQueue::shutdown
    override void shutdown()
    {
        if( !mIsRunning )
            return;

        static if(OGRE_THREAD_SUPPORT)
            ulong threadId = OGRE_THREAD_CURRENT_ID();
        else
            string threadId = "main";

        
        LogManager.getSingleton().stream() <<
            "DefaultWorkQueue('" << mName << "') shutting down on thread " <<
                threadId
                << ".";
        
        mShuttingDown = true;
        abortAllRequests();
        static if(OGRE_THREAD_SUPPORT)
        {
            //TODO Needs synchronized?
            // wake all threads (they should check shutting down as first thing after wait)
            mRequestCondition.notifyAll();
            
            // all our threads should have been woken now, so join
            foreach (i; mWorkers)
            {
                i.join();
                //OGRE_THREAD_DESTROY(*i);
            }
            mWorkers.clear();
        }
        
        if (mWorkerFunc)
        {
            destroy(mWorkerFunc);
            mWorkerFunc = null;
        }

        mIsRunning = false;
    }
    
    /// @copydoc WorkQueue::startup
    override void startup(bool forceRestart = true)
    {
        if (mIsRunning)
        {
            if (forceRestart)
                shutdown();
            else
                return;
        }
        
        mShuttingDown = false;

        //TODO Hmm....uh?
        //mWorkerFunc = new WorkerFunc(this);

        static if(OGRE_THREAD_SUPPORT)
            ulong threadId = OGRE_THREAD_CURRENT_ID();
        else
            string threadId = "main";

        LogManager.getSingleton().stream() <<
            "DefaultWorkQueue('" << mName << "') initialising on thread " <<
                threadId
                << ".";
        
        static if(OGRE_THREAD_SUPPORT)
        {
            if (mWorkerRenderSystemAccess)
                Root.getSingleton().getRenderSystem().preExtraThreadsStarted();
            
            mNumThreadsRegisteredWithRS = 0;
            for (ubyte i = 0; i < mWorkerThreadCount; ++i)
            {
                //OGRE_THREAD_CREATE(t, *mWorkerFunc);
                //FIXME WorkerFunc is of Thread class so make mWorkerThreadCount of threads
                Thread t = new WorkerFunc(this);
                mWorkers.insert(t);
                t.start();
            }
            
            if (mWorkerRenderSystemAccess)
            {
                //OGRE_LOCK_MUTEX_NAMED(mInitMutex, initLock)
                synchronized(mInitSync.mutex)
                {
                    // have to wait until all threads are registered with the render system
                    while (mNumThreadsRegisteredWithRS < mWorkerThreadCount)
                    {
                        //OGRE_THREAD_WAIT(mInitSync, mInitMutex, initLock);
                        mInitSync.wait();
                    }
                    
                    Root.getSingleton().getRenderSystem().postExtraThreadsStarted();
                }
            }
        }
        
        mIsRunning = true;
    }
    
protected:
    /** To be called by a separate thread; will return immediately if there
     are items in the queue, or suspend the thread until new items are added
     otherwise.
     */
    void waitForNextRequest()
    {
        static if(OGRE_THREAD_SUPPORT)
        {
            // Lock; note that OGRE_THREAD_WAIT will free the lock
            //OGRE_LOCK_MUTEX_NAMED(mRequestMutex, queueLock);
            synchronized(mRequestCondition.mutex)
            {
                if (!mRequestQueue.length)
                {
                    // frees lock and suspends the thread
                    //OGRE_THREAD_WAIT(mRequestCondition, mRequestMutex, queueLock);
                    mRequestCondition.wait();
                }
            }
            // When we get back here, it's because we've been notified 
            // and thus the thread has been woken up. Lock has also been
            // re-acquired, but we won't use it. It's safe to try processing and fail
            // if another thread has got in first and grabbed the request
        }
        
    }
    
    /// Notify that a thread has registered itself with the render system
    void notifyThreadRegistered()
    {
        synchronized(mInitSync.mutex)
        {
            ++mNumThreadsRegisteredWithRS;
            
            // wake up main thread
            mInitSync.notifyAll();
        }
    }
    
    override void notifyWorkers()
    {
        //TODO Needs synchronized?
        // wake up waiting thread
        synchronized(mRequestCondition.mutex)
            mRequestCondition.notify();
    }
    
    shared size_t mNumThreadsRegisteredWithRS;

    //FIXME __gshared or just shared or nothing?
    /// Init notification mutex (must lock before waiting on initCondition)
    __gshared Mutex mInitMutex;
    /// Synchroniser token to wait / notify on thread init 
    __gshared Condition mInitSync;
    
    __gshared Condition mRequestCondition; //Uses mRequestMutex from super

    static if(OGRE_THREAD_SUPPORT)
    {
        //typedef vector<OGRE_THREAD_TYPE*>::type WorkerThreadList;
        alias Thread[] WorkerThreadList;
        WorkerThreadList mWorkers;
    }
    
}