module ogre.general.log;

import core.sync.mutex;
import core.stdc.string: memcpy;
import std.algorithm;
import std.array;
import std.outbuffer;
import std.stdio;
import ogre.singleton;
import ogre.compat;
import ogre.exception;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */


// LogMessageLevel + LoggingLevel > OGRE_LOG_THRESHOLD = message logged
enum OGRE_LOG_THRESHOLD = 4;

/** The level of detail to which the log will go into.
 */
enum LoggingLevel
{
    LL_LOW = 1,
    LL_NORMAL = 2,
    LL_BOREME = 3
}

alias uint LogMessageLevel;
/** The importance of a logged message.
 */
enum : LogMessageLevel
{
    LML_TRIVIAL = 1,
    LML_NORMAL = 2,
    LML_CRITICAL = 3
}

/** @remarks Pure Abstract class, derive this class and register to the Log to listen to log messages */
interface LogListener
{
    /**
     @remarks
     This is called whenever the log receives a message and is about to write it out
     @param message
     The message to be logged
     @param lml
     The message level the log is using
     @param maskDebug
     If we are printing to the console or not
     @param logName
     The name of this log (so you can have several listeners for different logs, and identify them)
     @param skipThisMessage
     If set to true by the messageLogged() implementation message will not be logged
     */
    void messageLogged(string message, LogMessageLevel lml, bool maskDebug,string logName, ref bool skipThisMessage );
}

/// Someday maybe
//#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
//    pp::Instance* Log::mInstance = null;
//#endif

/**
 @remarks
 Log class for writing debug/log data to files.
 @note
 <br>Should not be used directly, but trough the LogManager class.
 */
class Log// : public LogAlloc
{
protected:
    File            mLog;
    LoggingLevel    mLogLevel;
    bool            mDebugOut;
    bool            mSuppressFile;
    bool            mTimeStamp;
    string          mLogName;
    
    alias LogListener[] mtLogListener;
    mtLogListener mListeners;
public:
    
    //class Stream;
    
    //OGRE_AUTO_MUTEX // public to allow external locking
    /**
     @remarks
     Usual constructor - called by LogManager.
     */
    this(string name, bool debugOutput = true, bool suppressFileOutput = false)
    {
        mLogLevel = LoggingLevel.LL_NORMAL;
        mDebugOut = debugOutput;
        mSuppressFile = suppressFileOutput;
        mTimeStamp = true;
        mLogName = name;
        if(!mSuppressFile)
            mLog = File(mLogName, "wb");
    }
    
    /**
     @remarks
     Default destructor.
     */
    ~this()
    {
        synchronized(this)
        {
            if (!mSuppressFile)
            {
                mLog.close();
            }
        }
    }
    
    /// Return the name of the log
    string getName(){ return mLogName; }
    /// Get whether debug output is enabled for this log
    bool isDebugOutputEnabled(){ return mDebugOut; }
    /// Get whether file output is suppressed for this log
    bool isFileOutputSuppressed(){ return mSuppressFile; }
    /// Get whether time stamps are printed for this log
    bool isTimeStampEnabled(){ return mTimeStamp; }
    
    /** Log a message to the debugger and to log file (the default is
     "<code>OGRE.log</code>"),
     */
    void logMessage(string message, LogMessageLevel lml = LML_NORMAL, bool maskDebug = false, bool newLine = true /*quick hack for stream*/ )
    {
        synchronized(this)
        {
            if ((mLogLevel + lml) >= OGRE_LOG_THRESHOLD)
            {
                bool skipThisMessage = false;
                foreach( i; mListeners)
                    i.messageLogged( message, lml, maskDebug, mLogName, skipThisMessage);
                
                if (!skipThisMessage)
                {
                    /*#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
                     if(mInstance !is null)
                     {
                     mInstance.PostMessage(message.c_str());
                     }
                     #else
                     if (mDebugOut && !maskDebug)
                     #   if _DEBUG && (OGRE_PLATFORM == OGRE_PLATFORM_WIN32 || OGRE_PLATFORM == OGRE_PLATFORM_WINRT)
                     {
                     String logMessageString(message);
                     logMessageString.append( "\n" );
                     Ogre_OutputCString( logMessageString.c_str());
                     }
                     #   else*/
                    if(newLine)
                        stderr.writeln(message);
                    else
                        stderr.write(message);
                    //#   endif
                    //#endif
                    
                    // Write time into log
                    if (!mSuppressFile)
                    {
                        /*if (mTimeStamp)
                         {
                         struct tm *pTime;
                         time_t ctTime; time(&ctTime);
                         pTime = localtime( &ctTime );
                         mLog << std::setw(2) << std::setfill('0') << pTime.tm_hour
                         << ":" << std::setw(2) << std::setfill('0') << pTime.tm_min
                         << ":" << std::setw(2) << std::setfill('0') << pTime.tm_sec
                         << ": ";
                         }*/
                        if(newLine)
                            mLog.writeln(message);
                        else
                            mLog.write(message);
                        
                        // Flush stcmdream to ensure it is written (incase of a crash, we need log to be up to date)
                        mLog.flush();
                    }
                }
            }
            
        }
    }
    /** Get a stream object targeting this log. */
    Stream stream(LogMessageLevel lml = LML_NORMAL, bool maskDebug = false)
    {
        return new Stream(this, lml, maskDebug); //TODO What if Log gets collected before Stream?
    }
    
    
    /**
     @remarks
     Enable or disable outputting log messages to the debugger.
     */
    void setDebugOutputEnabled(bool debugOutput)
    {
        synchronized(this)
        {
            mDebugOut = debugOutput;
        }
    }
    /**
     @remarks
     Sets the level of the log detail.
     */
    void setLogDetail(LoggingLevel ll)
    {
        synchronized(this)
        {
            mLogLevel = ll;
        }
    }
    /**
     @remarks
     Enable or disable time stamps.
     */
    void setTimeStampEnabled(bool timeStamp)
    {
        synchronized(this)
        {
            mTimeStamp = timeStamp;
        }
    }
    /** Gets the level of the log detail.
     */
    LoggingLevel getLogDetail(){ return mLogLevel; }
    /**
     @remarks
     Register a listener to this log
     @param listener
     A valid listener derived class
     */
    void addListener(LogListener listener)
    {
        synchronized(this) 
        {
            if(mListeners.find(listener).empty)
                mListeners.insert(listener); 
        }
    }
    
    /**
     @remarks
     Unregister a listener from this log
     @param listener
     A valid listener derived class
     */
    void removeListener(LogListener listener)
    {
        synchronized(this)
        { 
            mListeners.removeFromArray(listener); 
        }
    }
    
    /** Stream object which targets a log.
     @remarks
     A stream logger object makes it simpler to send various things to 
     a log. You can just use the operator<< implementation to stream 
     anything to the log, which is cached until a Stream::Flush is
     encountered, or the stream itself is destroyed, at which point the 
     cached contents are sent to the underlying log. You can use Log::stream()
     directly without assigning it to a local variable and as soon as the
     streaming is finished, the object will be destroyed and the message
     logged.
     @par
     C++ only:
     You can stream control operations to this object too, such as 
     std::setw() and std::setfill() to control formatting.
     @note
     Each Stream object is not thread safe, so do not pass it between
     threads. Multiple threads can hold their own Stream instances pointing
     at the same Log though and that is threadsafe.
     */
    class Stream
    {
        /*invariant()
        {
            assert(mCache !is null);
        }*/
        
    protected:
        Log mTarget;
        LogMessageLevel mLevel;
        bool mMaskDebug;
        //typedef StringUtil::StrStreamType BaseStream;
        //BaseStream mCache;
        //string mCache;
        OutBuffer mCache ;//= new OutBuffer; //But maybe might as well use string
        
        
    public:
        version(Windows)
            enum endl = "\r\n";
        else
            enum endl = "\n";
        
        /// Simple type to indicate a flush of the stream to the log
        struct Flush
        {
            Stream opBinary(string op) (Flush v)
            {
                if(op == "<<")
                {
                    
                    return this;
                }
            }
        }
        
        this(ref Log target, LogMessageLevel lml, bool maskDebug)
        {
            mTarget = target; mLevel = lml;
            mMaskDebug = maskDebug;
            //mCache = new OutBuffer;
        }
        // copy constructor
        this(Stream rhs) 
        {
            //mCache = new OutBuffer;
            mTarget = rhs.mTarget;
            mLevel = rhs.mLevel;
            mMaskDebug = rhs.mMaskDebug;
            // explicit copy of stream required, gcc doesn't like implicit
            //mCache.str(rhs.mCache.str());
            //mCache.write(rhs.mCache);
        } 
        ~this()
        {
            // flush on destroy
            /*if (mCache.tellp() > 0)
             {
             mTarget.logMessage(mCache.str(), mLevel, mMaskDebug);
             }*/
            //if(mCache.data.length && mTarget !is null)
            //    mTarget.logMessage(mCache.toString(), mLevel, mMaskDebug);
        }
        
        
        Stream opBinary(string op, T) (T v) if(!is(T == Flush))
        {
            if(op == "<<")
            {
                //mCache << v;
                //mCache.write(std.conv.to!string(v));
                mTarget.logMessage(std.conv.to!string(v), mLevel, mMaskDebug, false);
                return this;
            }
        }
        
        ///No std.conv for string
        /+Stream opBinary(string op) (string v)
         {
             if(op == "<<")
             {
                 mCache.write(v);
                 return this;
             }
         }+/
        
        Stream opBinary(string op) (const(Flush) v)
        {
            if(op == "<<")
            {
                //mCache << v;
                /*if(mCache.data.length)
                {
                    mTarget.logMessage(mCache.toString(), mLevel, mMaskDebug);
                    mCache.data.length = 0;
                    mCache.offset = 0;
                }*/
                return this;
            }
        }
        
    }
    
    /*#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
     protected:
     static pp::Instance* mInstance;
     public:
     static void setInstance(pp::Instance* instance) {mInstance = instance;};
     #endif*/
    
}

/** The log manager handles the creation and retrieval of logs for the
 application.
 @remarks
 This class will create new log files and will retrieve instances
 of existing ones. Other classes wishing to log output can either
 create a fresh log or retrieve an existing one to output to.
 One log is the default log, and is the one written to when the
 logging methods of this class are called.
 @par
 By default, Root will instantiate a LogManager (which becomes the 
 Singleton instance) on construction, and will create a default log
 based on the Root constructor parameters. If you want more control,
 for example redirecting log output right from the start or suppressing
 debug output, you need to create a LogManager yourself before creating
 a Root instance, then create a default log. Root will detect that 
 you've created one yourself and won't create one of its own, thus
 using all your logging preferences from the first instance.
 */
class LogManager //: public LogAlloc
{
    mixin Singleton!LogManager;
protected:
    //typedef map<String, Log*>::type LogList;
    alias Log[string] LogList;
    
    /// A list of all the logs the manager can access
    LogList mLogs;
    
    /// The default log to which output is done
    Log mDefaultLog;
    
    invariant()
    {
        assert(mLock !is null);
    }
    
public:
    //OGRE_AUTO_MUTEX // public to allow external locking
    Mutex mLock;
    
    this() 
    {
        mLock = new Mutex;
    }
    ~this()
    {
        synchronized(mLock)
        {
            // Destroy all logs
            foreach (k,v; mLogs)
            {
                destroy(v);
            }
        }
    }
    
    /** Creates a new log with the given name.
     @param
     name The name to give the log e.g. 'Ogre.log'
     @param
     defaultLog If true, this is the default log output will be
     sent to if the generic logging methods on this class are
     used. The first log created is always the default log unless
     this parameter is set.
     @param
     debuggerOutput If true, output to this log will also be
     routed to the debugger's output window.
     @param
     suppressFileOutput If true, this is a logical rather than a physical
     log and no file output will be written. If you do this you should
     register a LogListener so log output is not lost.
     */
    Log createLog(string name, bool defaultLog = false, bool debuggerOutput = true, 
                  bool suppressFileOutput = false)
    {
        synchronized(mLock)
        {    
            Log newLog = new Log(name, debuggerOutput, suppressFileOutput);
            
            if( !mDefaultLog || defaultLog )
            {
                mDefaultLog = newLog;
            }
            
            mLogs[name] = newLog;
            
            return newLog;
        }
    }
    
    /** Retrieves a log managed by this class.
     */
    ref Log getLog(string name)
    {
        synchronized(mLock)
        {
            auto i = name in mLogs;
            if (i !is null)
                return *i;
            else
                throw new InvalidParamsError("Log not found. ", "LogManager.getLog");
        }
    }
    
    /** Returns a pointer to the default log.
     */
    ref Log getDefaultLog()
    {
        synchronized(mLock)
        {
            return mDefaultLog;
        }
    }
    
    /** Closes and removes a named log. */
    void destroyLog(string name)
    {
        auto i = name in mLogs;
        if (i !is null)
        {
            if (mDefaultLog == *i)
            {
                mDefaultLog = null;
            }
            destroy(*i);
            mLogs.remove(name);
        }
        
        // Set another default log if this one removed
        if (!mDefaultLog && !mLogs.emptyAA())
        {
            mDefaultLog = mLogs[mLogs.keysAA[0]]; //TODO mLogs.begin()
        }
    }
    
    /** Closes and removes a log. */
    void destroyLog(ref Log log)
    {
        destroyLog(log.getName());
    }
    
    /** Sets the passed in log as the default log.
     @return The previous default log.
     */
    Log setDefaultLog(ref Log newLog)
    {
        synchronized(mLock)
        {
            Log oldLog = mDefaultLog;
            mDefaultLog = newLog;
            return oldLog;
        }
    }
    
    /** Log a message to the default log.
     */
    void logMessage(string message, LogMessageLevel lml = LML_NORMAL, 
                    bool maskDebug = false)
    {
        synchronized(mLock)
        {
            if (mDefaultLog)
            {
                mDefaultLog.logMessage(message, lml, maskDebug);
            }
        }
    }
    
    /** Log a message to the default log (signature for backward compatibility).
     */
    void logMessage( LogMessageLevel lml,string message,  
                    bool maskDebug = false) { logMessage(message, lml, maskDebug); }
    
    /** Get a stream on the default log. */
    Log.Stream stream(LogMessageLevel lml = LML_NORMAL, 
                      bool maskDebug = false)
    {
        synchronized(mLock)
        {
            if (mDefaultLog)
                return mDefaultLog.stream(lml, maskDebug);
            else
                throw new InvalidParamsError("Default log not found. ", "LogManager.stream");
        }
    }
    
    /** Sets the level of detail of the default log.
     */
    void setLogDetail(LoggingLevel ll)
    {
        synchronized(mLock)
        {
            if (mDefaultLog)
            {
                mDefaultLog.setLogDetail(ll);
            }
        }
    }
}

/** @} */
/** @} */