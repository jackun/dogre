module ogre.general.profiler;

//import std.container;
import std.algorithm;
import std.range;
import ogre.compat;
import ogre.config;
import ogre.singleton;
import ogre.general.timer;
import ogre.general.log;
import ogre.general.root;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */

///Generate switch block to return enum as a string
string EnumToStringGenerate(T /*,string templateVar = "T", string pre = ""*/)(string var){
    string res = "final switch(" ~ var ~ "){";
    foreach(m;__traits(allMembers,T)){
        res ~= "case T." ~ m ~ ": return \"" ~ T.stringof ~ "." ~ m ~ "\";";
    }
    res ~= "}";
    return res;
}

string EnumToString(T)(T value){
    mixin(EnumToStringGenerate!(T)("value"));
}

// NOTE: These OgreProfile* are mixins so use them as 
//    mixin(OgreProfile("myProfile"));

// You can escape strings with `\"` like 
//    mixin(OgreProfileBegin("Camera: \" ~ getName() ~ \""));
// to call functions etc. at runtime.

static if(OGRE_PROFILING)
{
    string OgreProfile( string a )
    { 
        return `auto _OgreProfileInstance` ~ a ~ ` = new Profile("` ~ a ~ `");`;
    }
    
    string OgreProfileBegin( string a )
    { 
        return `Profiler.getSingleton().beginProfile("` ~ a ~ `");`;
    }
    
    string OgreProfileEnd( string a ) 
    { 
        return `Profiler.getSingleton().endProfile("` ~ a ~ `");`;
    }
    
    string OgreProfileGroup( string a, ProfileGroupMask g )
    { 
        return `auto _OgreProfileInstance` ~ a ~ ` = new Profile("` ~ a ~ `",` ~ EnumToString(g) ~`);`;
    }
    
    string OgreProfileBeginGroup( string a, ProfileGroupMask g )
    { 
        return `Profiler.getSingleton().beginProfile("` ~ a ~ `",` ~ EnumToString(g) ~ `);`;
    }
    
    string OgreProfileEndGroup( string a, ProfileGroupMask g ) 
    { 
        return `Profiler.getSingleton().endProfile("` ~ a ~ `",` ~ EnumToString(g) ~ `);`;
    }
    
    string OgreProfileBeginGPUEvent( string g ) 
    { 
        return `Profiler.getSingleton().beginGPUEvent("` ~ g ~ `");`;
    }
    
    string OgreProfileEndGPUEvent( string e ) 
    { 
        return `Profiler.getSingleton().endGPUEvent("` ~ e ~ `");`;
    }
    
    string OgreProfileMarkGPUEvent( string e ) 
    { 
        return `Profiler.getSingleton().markGPUEvent("` ~ e ~ `");`;
    }
}
else
{
    string OgreProfile( string a ) { return ""; }
    string OgreProfileBegin( string a ) { return ""; }
    string OgreProfileEnd( string a ) { return ""; }
    string OgreProfileGroup( string a, ProfileGroupMask g ) { return ""; }
    string OgreProfileBeginGroup( string a, ProfileGroupMask g ) { return ""; }
    string OgreProfileEndGroup( string a, ProfileGroupMask g ) { return ""; }
    string OgreProfileBeginGPUEvent( string e ) { return ""; }
    string OgreProfileEndGPUEvent( string e ) { return ""; }
    string OgreProfileMarkGPUEvent( string e ) { return ""; }
}

/** List of reserved profiling masks
    */
enum ProfileGroupMask
{
    /// User default profile
    OGREPROF_USER_DEFAULT = 0x00000001,
    /// All in-built Ogre profiling will match this mask
    OGREPROF_ALL = 0xFF000000,
    /// General processing
    OGREPROF_GENERAL = 0x80000000,
    /// Culling
    OGREPROF_CULLING = 0x40000000,
    /// Rendering
    OGREPROF_RENDERING = 0x20000000
}

/** An individual profile that will be processed by the Profiler
        @remarks
            Use the macro OgreProfile(name) instead of instantiating this profile directly
        @remarks
            We use this Profile to allow scoping rules to signify the beginning and end of
            the profile. Use the Profiler singleton (through the macro OgreProfileBegin(name)
            and OgreProfileEnd(name)) directly if you want a profile to last
            outside of a scope (i.e. the main game loop).
        @author Amit Mathew (amitmathew (at) yahoo (dot) com)
    */
class Profile //: public ProfilerAlloc 
{
    
public:
    this(string profileName, ProfileGroupMask groupID = ProfileGroupMask.OGREPROF_USER_DEFAULT)
    {
        mName = profileName;
        mGroupID = groupID;
        Profiler.getSingleton().beginProfile(profileName, groupID);
    }
    ~this()
    {
        Profiler.getSingleton().endProfile(mName, mGroupID);
    }
    
protected:
    
    /// The name of this profile
    string mName;
    /// The group ID
    uint mGroupID;
}

/** Represents the total timing information of a profile
        since profiles can be called more than once each frame
    */
struct ProfileFrame 
{
    
    /// The total time this profile has taken this frame
    ulong   frameTime;
    
    /// The number of times this profile was called this frame
    uint    calls;
    
    /// The hierarchical level of this profile, 0 being the main loop
    uint    hierarchicalLvl;
    
}

/// Represents a history of each profile during the duration of the app
struct ProfileHistory 
{
    /// The current percentage of frame time this profile has taken
    Real    currentTimePercent; 
    /// The current frame time this profile has taken in milliseconds
    Real    currentTimeMillisecs;
    
    /// The maximum percentage of frame time this profile has taken
    Real    maxTimePercent; 
    /// The maximum frame time this profile has taken in milliseconds
    Real    maxTimeMillisecs; 
    
    /// The minimum percentage of frame time this profile has taken
    Real    minTimePercent; 
    /// The minimum frame time this profile has taken in milliseconds
    Real    minTimeMillisecs; 
    
    /// The number of times this profile has been called each frame
    uint    numCallsThisFrame;
    
    /// The total percentage of frame time this profile has taken
    Real    totalTimePercent;
    /// The total frame time this profile has taken in milliseconds
    Real    totalTimeMillisecs;
    
    /// The total number of times this profile was called
    /// (used to calculate average)
    ulong   totalCalls; 
    
    /// The hierarchical level of this profile, 0 being the root profile
    uint    hierarchicalLvl;
    
}

/// Represents an individual profile call
class ProfileInstance //: public ProfilerAlloc
{
    //friend class Profiler;
public:
    this()
    {
        parent = null;
        frameNumber = 0;
        accum = 0;
        hierarchicalLvl = 0;

        history.numCallsThisFrame = 0;
        history.totalTimePercent = 0;
        history.totalTimeMillisecs = 0;
        history.totalCalls = 0;
        history.maxTimePercent = 0;
        history.maxTimeMillisecs = 0;
        history.minTimePercent = 1;
        history.minTimeMillisecs = 100000;
        history.currentTimePercent = 0;
        history.currentTimeMillisecs = 0;
        
        frame.frameTime = 0;
        frame.calls = 0;
    }

    ~this()
    {                                        
        foreach(k,v; children)
        {
            destroy(v);
        }
        children.clear();
    }

    //typedef Ogre::map<String,ProfileInstance*>::type ProfileChildren;
    alias ProfileInstance[string] ProfileChildren;
    
    void logResults()
    {
        // create an indent that represents the hierarchical order of the profile
        string indent = "";
        for (uint i = 0; i < hierarchicalLvl; ++i) 
        {
            indent = indent ~ "\t";
        }
        
        LogManager.getSingleton().logMessage(
            std.conv.text(indent, "Name ", name, 
                      " | Min ", history.minTimePercent,
                      " | Max ", history.maxTimePercent,
                      " | Avg ", history.totalTimePercent / history.totalCalls));   
        
        foreach(k,v; children)
        {
            v.logResults();
        }
    }

    void reset()
    {
        history.currentTimePercent = history.maxTimePercent = history.totalTimePercent = 0;
        history.currentTimeMillisecs = history.maxTimeMillisecs = history.totalTimeMillisecs = 0;
        history.numCallsThisFrame = 0; history.totalCalls = 0;
        
        history.minTimePercent = 1;
        history.minTimeMillisecs = 100000;
        foreach(k,v; children)
        {
            v.reset();
        }
    }
    
    bool watchForMax() { return history.currentTimePercent == history.maxTimePercent; }
    bool watchForMin() { return history.currentTimePercent == history.minTimePercent; }
    bool watchForLimit(Real limit, bool greaterThan = true)
    {
        if (greaterThan)
            return history.currentTimePercent > limit;
        else
            return history.currentTimePercent < limit;
    }
    
    bool watchForMax(string profileName)
    {
        foreach(k,child; children)
        {
            if( (child.name == profileName && child.watchForMax()) || child.watchForMax(profileName))
                return true;
        }
        return false;
    }

    bool watchForMin(string profileName)
    {
        foreach(k, child; children)
        {
            if( (child.name == profileName && child.watchForMin()) || child.watchForMin(profileName))
                return true;
        }
        return false;
    }

    bool watchForLimit(string profileName, Real limit, bool greaterThan = true)
    {
        foreach(k, child; children)
        {
            if( (child.name == profileName && child.watchForLimit(limit, greaterThan)) || 
               child.watchForLimit(profileName, limit, greaterThan))
                return true;
        }
        return false;
    }
    
    /// The name of the profile
    string          name;
    
    /// The name of the parent, null if root
    ProfileInstance parent;
    
    ProfileChildren children;
    
    ProfileFrame frame;
    ulong frameNumber;
    
    ProfileHistory history;
    
    /// The time this profile was started
    ulong           currTime;
    
    /// Represents the total time of all child profiles to subtract
    /// from this profile
    ulong           accum;
    
    /// The hierarchical level of this profile, 0 being the root profile
    uint            hierarchicalLvl;
}

/** ProfileSessionListener should be used to visualize profile results.
        Concrete impl. could be done using Overlay's but its not limited to 
        them you can also create a custom listener which sends the profile
        informtaion over a network.
    */
class ProfileSessionListener
{
public:
    enum DisplayMode
    {
        /// Display % frame usage on the overlay
        DISPLAY_PERCENTAGE,
        /// Display milliseconds on the overlay
        DISPLAY_MILLISECONDS
    }
    
    this() {}
    ~this() {}
    
    /// Create the internal resources
    abstract void initializeSession();
    
    /// All internal resources should be deleted here
    abstract void finializeSession();
    
    /** If the profiler disables this listener then it
            should hide its panels (if any exists) or stop
            sending data over the network
        */
    void changeEnableState(bool enabled) {}; 
    
    /// Here we get the real profiling information which we can use 
    void displayResults(ProfileInstance instance, ulong maxTotalFrameTime) {};
    
    /// Set the display mode for the overlay. 
    void setDisplayMode(DisplayMode d) { mDisplayMode = d; }
    
    /// Get the display mode for the overlay. 
    DisplayMode getDisplayMode(){ return mDisplayMode; }
    
protected:
    /// How to display the overlay
    DisplayMode mDisplayMode = DisplayMode.DISPLAY_MILLISECONDS;
}

/** The profiler allows you to measure the performance of your code
        @remarks
            Do not create profiles directly from this unless you want a profile to last
            outside of its scope (i.e. the main game loop). For most cases, use the macro
            OgreProfile(name) and braces to limit the scope. You must enable the Profile
            before you can used it with setEnabled(true). If you want to disable profiling
            in Ogre, simply set the macro OGRE_PROFILING to 0.
        @author Amit Mathew (amitmathew (at) yahoo (dot) com)
        @todo resolve artificial cap on number of profiles displayed
        @todo fix display ordering of profiles not called every frame
    */
final class Profiler //: public ProfilerAlloc
{
    mixin Singleton!Profiler;
public:
    this()
    {
        mCurrent = mRoot;         
        mLast = null;         
        //mRoot = ;         
        mInitialized = false;         
        mUpdateDisplayFrequency = 10;       
        mCurrentFrame = 0;      
        //mTimer = 0;
        mTotalFrameTime = 0;        
        mEnabled = false;       
        mNewEnableState = false;        
        mProfileMask = 0xFFFFFFFF;      
        mMaxTotalFrameTime = 0;         
        mAverageFrameTime = 0;      
        mResetExtents = false;
        mRoot.hierarchicalLvl = 0 - 1;
    }

    ~this()
    {
        if (!mRoot.children.emptyAA())
        {
            // log the results of our profiling before we quit
            logResults();
        }
        
        // clear all our lists
        mDisabledProfiles.clear();
    }
    
    /** Sets the timer for the profiler */
    void setTimer(Timer t)
    {
        mTimer = t;
    }
    
    /** Retrieves the timer for the profiler */
    ref Timer getTimer()
    {
        assert(mTimer, "Timer not set!");
        return mTimer;
    }
    
    /** Begins a profile
            @remarks 
                Use the macro OgreProfileBegin(name) instead of calling this directly 
                so that profiling can be ignored in the release version of your app. 
            @remarks 
                You only use the macro (or this) if you want a profile to last outside
                of its scope (i.e. the main game loop). If you use this function, make sure you 
                use a corresponding OgreProfileEnd(name). Usually you would use the macro 
                OgreProfile(name). This function will be ignored for a profile that has been 
                disabled or if the profiler is disabled.
            @param profileName Must be unique and must not be an empty string
            @param groupID A profile group identifier, which can allow you to mask profiles
            */
    void beginProfile(string profileName, ProfileGroupMask groupID = ProfileGroupMask.OGREPROF_USER_DEFAULT)
    {
        // regardless of whether or not we are enabled, we need the application's root profile (ie the first profile started each frame)
        // we need this so bogus profiles don't show up when users enable profiling mid frame
        // so we check
        
        // if the profiler is enabled
        if (!mEnabled) 
            return;
        
        // mask groups
        if ((groupID & mProfileMask) == 0)
            return;
        
        // we only process this profile if isn't disabled
        if (!mDisabledProfiles.find(profileName).empty) 
            return;
        
        // empty string is reserved for the root
        // not really fatal anymore, however one shouldn't name one's profile as an empty string anyway.
        assert ((profileName != "") && (profileName !is null), "Profile name can't be an empty string");
        
        // this would be an internal error.
        assert (mCurrent);
        
        // need a timer to profile!
        assert (mTimer, "Timer not set!");
        
        ProfileInstance instance = mCurrent.children[profileName];
        if(instance)
        {   // found existing child.
            
            // Sanity check.
            assert(instance.name == profileName);
            
            if(instance.frameNumber != mCurrentFrame)
            {   // new frame, reset stats
                instance.frame.calls = 0;
                instance.frame.frameTime = 0;
                instance.frameNumber = mCurrentFrame;
            }
        }
        else
        {   // new child!
            instance = new ProfileInstance();
            instance.name = profileName;
            instance.parent = mCurrent;
            instance.hierarchicalLvl = mCurrent.hierarchicalLvl + 1;
        }
        
        instance.frameNumber = mCurrentFrame;
        
        mCurrent = instance;
        
        // we do this at the very end of the function to get the most
        // accurate timing results
        mCurrent.currTime = mTimer.getMicroseconds();
    }
    
    /** Ends a profile
            @remarks 
                Use the macro OgreProfileEnd(name) instead of calling this directly so that
                profiling can be ignored in the release version of your app.
            @remarks
                This function is usually not called directly unless you want a profile to
                last outside of its scope. In most cases, using the macro OgreProfile(name) 
                which will call this function automatically when it goes out of scope. Make 
                sure the name of this profile matches its corresponding beginProfile name. 
                This function will be ignored for a profile that has been disabled or if the
                profiler is disabled.
            @param profileName Must be unique and must not be an empty string
            @param groupID A profile group identifier, which can allow you to mask profiles
            */
    void endProfile(string profileName, uint groupID = ProfileGroupMask.OGREPROF_USER_DEFAULT)
    {
        if(!mEnabled) 
        {
            // if the profiler received a request to be enabled or disabled
            if(mNewEnableState != mEnabled) 
            {   // note mNewEnableState == true to reach this.
                changeEnableState();
                
                // NOTE we will be in an 'error' state until the next begin. ie endProfile will likely get invoked using a profileName that was never started.
                // even then, we can't be sure that the next beginProfile will be the true start of a new frame
            }
            
            return;
        }
        else
        {
            if(mNewEnableState != mEnabled) 
            {   // note mNewEnableState == false to reach this.
                changeEnableState();
                
                // unwind the hierarchy, should be easy enough
                mCurrent = mRoot;
                mLast = null;
            }
            
            if(mRoot == mCurrent && mLast)
            {   // profiler was enabled this frame, but the first subsequent beginProfile was NOT the beinging of a new frame as we had hoped.
                // we have a bogus ProfileInstance in our hierarchy, we will need to remove it, then update the overlays so as not to confuse ze user
                
                // we could use mRoot.children.find() instead of this, except we'd be compairing strings instead of a pointer.
                // the string way could be faster, but i don't believe it would.
                foreach(k,child; mRoot.children)
                {
                    if(mLast == child)
                    {
                        mRoot.children.remove(k);
                        break;
                    }
                }
                
                // with mLast is null we won't reach this code, in case this isn't the end of the top level profile
                ProfileInstance last = mLast;
                mLast = null;
                destroy(last);
                
                processFrameStats();
                displayResults();
            }
        }
        
        if(mRoot == mCurrent)
            return;
        
        // mask groups
        if ((groupID & mProfileMask) == 0)
            return;
        
        // need a timer to profile!
        assert (mTimer, "Timer not set!");
        
        // get the end time of this profile
        // we do this as close the beginning of this function as possible
        // to get more accurate timing results
       ulong endTime = mTimer.getMicroseconds();
        
        // empty string is reserved for designating an empty parent
        assert ((profileName != "") && (profileName !is null), "Profile name can't be an empty string");
        
        // we only process this profile if isn't disabled
        // we check the current instance name against the provided profileName as a guard against disabling a profile name /after/ said profile began
        if(mCurrent.name != profileName && !mDisabledProfiles.find(profileName).empty) 
            return;
        
        // calculate the elapsed time of this profile
       ulong timeElapsed = endTime - mCurrent.currTime;
        
        // update parent's accumulator if it isn't the root
        if (mRoot != mCurrent.parent) 
        {
            // add this profile's time to the parent's accumlator
            mCurrent.parent.accum += timeElapsed;
        }
        
        mCurrent.frame.frameTime += timeElapsed;
        ++mCurrent.frame.calls;
        
        mLast = mCurrent;
        mCurrent = mCurrent.parent;
        
        if (mRoot == mCurrent) 
        {
            // the stack is empty and all the profiles have been completed
            // we have reached the end of the frame so process the frame statistics
            
            // we know that the time elapsed of the main loop is the total time the frame took
            mTotalFrameTime = timeElapsed;
            
            if(timeElapsed > mMaxTotalFrameTime)
                mMaxTotalFrameTime = timeElapsed;
            
            // we got all the information we need, so process the profiles
            // for this frame
            processFrameStats();
            
            // we display everything to the screen
            displayResults();
        }
    }
    
    /** Mark the beginning of a GPU event group
             @remarks Can be safely called in the middle of the profile.
             */
    void beginGPUEvent(string event)
    {
        Root.getSingleton().getRenderSystem().beginProfileEvent(event);
    }
    
    /** Mark the end of a GPU event group
             @remarks Can be safely called in the middle of the profile.
             */
    void endGPUEvent(string event)
    {
        Root.getSingleton().getRenderSystem().endProfileEvent();
    }
    
    /** Mark a specific, ungrouped, GPU event
             @remarks Can be safely called in the middle of the profile.
             */
    void markGPUEvent(string event)
    {
        Root.getSingleton().getRenderSystem().markProfileEvent(event);
    }
    
    /** Sets whether this profiler is enabled. Only takes effect after the
                the frame has ended.
                @remarks When this is called the first time with the parameter true,
                it initializes the GUI for the Profiler
            */
    void setEnabled(bool enabled)
    {
        if (!mInitialized && enabled) 
        {
            foreach( i; mListeners)
                i.initializeSession();
            
            mInitialized = true;
        }
        else
        {
            foreach( i; mListeners)
                i.finializeSession();
            
            mInitialized = false;
            mEnabled = false;
        }
        // We store this enable/disable request until the frame ends
        // (don't want to screw up any open profiles!)
        mNewEnableState = enabled;
    }
    
    /** Gets whether this profiler is enabled */
    bool getEnabled()
    {
        return mEnabled;
    }
    
    /** Enables a previously disabled profile 
            @remarks Can be safely called in the middle of the profile.
            */
    void enableProfile(string profileName)
    {
        mDisabledProfiles.removeFromArray(profileName);
    }
    
    /** Disables a profile
            @remarks Can be safely called in the middle of the profile.
            */
    void disableProfile(string profileName)
    {
        // even if we are in the middle of this profile, endProfile() will still end it.
        mDisabledProfiles.insert(profileName);
    }
    
    /** Set the mask which all profiles must pass to be enabled. 
            */
    void setProfileGroupMask(uint mask) { mProfileMask = mask; }
    /** Get the mask which all profiles must pass to be enabled. 
            */
    uint getProfileGroupMask(){ return mProfileMask; }
    
    /** Returns true if the specified profile reaches a new frame time maximum
            @remarks If this is called during a frame, it will be reading the results
            from the previous frame. Therefore, it is best to use this after the frame
            has ended.
            */
    bool watchForMax(string profileName)
    {
        assert ((profileName != "") && (profileName !is null),"Profile name can't be an empty string");
        
        return mRoot.watchForMax(profileName);
    }
    
    /** Returns true if the specified profile reaches a new frame time minimum
            @remarks If this is called during a frame, it will be reading the results
            from the previous frame. Therefore, it is best to use this after the frame
            has ended.
            */
    bool watchForMin(string profileName)
    {
        assert ((profileName != "") && (profileName !is null), "Profile name can't be an empty string");
        return mRoot.watchForMin(profileName);
    }
    
    /** Returns true if the specified profile goes over or under the given limit
                frame time
            @remarks If this is called during a frame, it will be reading the results
            from the previous frame. Therefore, it is best to use this after the frame
            has ended.
            @param limit A number between 0 and 1 representing the percentage of frame time
            @param greaterThan If true, this will return whether the limit is exceeded. Otherwise,
            it will return if the frame time has gone under this limit.
            */
    bool watchForLimit(string profileName, Real limit, bool greaterThan = true)
    {
        assert ((profileName != "") && (profileName !is null), "Profile name can't be an empty string");
        return mRoot.watchForLimit(profileName, limit, greaterThan);
    }
    
    /** Outputs current profile statistics to the log */
    void logResults()
    {
        LogManager.getSingleton().logMessage("----------------------Profiler Results----------------------");
        
        foreach(k,v; mRoot.children)
        {
            v.logResults();
        }
        
        LogManager.getSingleton().logMessage("------------------------------------------------------------");
    }
    
    /** Clears the profiler statistics */
    void reset()
    {
        mRoot.reset();
        mMaxTotalFrameTime = 0;
    }
    
    /** Sets the Profiler so the display of results are updated every n frames*/
    void setUpdateDisplayFrequency(uint freq)
    {
        mUpdateDisplayFrequency = freq;
    }
    
    /** Gets the frequency that the Profiler display is updated */
    uint getUpdateDisplayFrequency()
    {
        return mUpdateDisplayFrequency;
    }
    
    /**
            @remarks
                Register a ProfileSessionListener from the Profiler
            @param listener
                A valid listener derived class
            */
    void addListener(ref ProfileSessionListener listener)
    {
        mListeners.insert(listener);
    }
    
    /**
            @remarks
                Unregister a ProfileSessionListener from the Profiler
            @param listener
                A valid listener derived class
            */
    void removeListener(ref ProfileSessionListener listener)
    {
        mListeners.removeFromArray(listener);
    }
    

protected:
    //friend class ProfileInstance;
    
    //typedef vector<ProfileSessionListener*>::type TProfileSessionListener;
    alias ProfileSessionListener[] TProfileSessionListener;
    TProfileSessionListener mListeners;
    
    /** Initializes the profiler's GUI elements */
    void initialize() {}; //FIXME WTF is this, virtual? How does it even compile in c++
    
    void displayResults()
    {
        // if its time to update the display
        if (!(mCurrentFrame % mUpdateDisplayFrequency))
        {
            // ensure the root won't be culled
            mRoot.frame.calls = 1;
            
            foreach( i; mListeners)
                i.displayResults(mRoot, mMaxTotalFrameTime);
        }
        ++mCurrentFrame;
    }
    
    /** Processes frame stats for all of the mRoot's children */
    void processFrameStats()
    {
        Real maxFrameTime = 0;

        foreach(k,child; mRoot.children)
        {
            
            // we set the number of times each profile was called per frame to 0
            // because not all profiles are called every frame
            child.history.numCallsThisFrame = 0;
            
            if(child.frame.calls > 0)
            {
                processFrameStats(child, maxFrameTime);
            }
        }
        
        // Calculate whether the extents are now so out of date they need regenerating
        if (mCurrentFrame == 0)
            mAverageFrameTime = maxFrameTime;
        else
            mAverageFrameTime = (mAverageFrameTime + maxFrameTime) * 0.5f;
        
        if (cast(Real)mMaxTotalFrameTime > mAverageFrameTime * 4)
        {
            mResetExtents = true;
            mMaxTotalFrameTime = cast(ulong)mAverageFrameTime;
        }
        else
            mResetExtents = false;
    }

    /** Processes specific ProfileInstance and it's children recursively.*/
    void processFrameStats(ref ProfileInstance instance, ref Real maxFrameTime)
    {
        // calculate what percentage of frame time this profile took
       Real framePercentage = cast(Real) instance.frame.frameTime / cast(Real) mTotalFrameTime;
        
       Real frameTimeMillisecs = cast(Real) instance.frame.frameTime / 1000.0f;
        
        // update the profile stats
        instance.history.currentTimePercent = framePercentage;
        instance.history.currentTimeMillisecs = frameTimeMillisecs;
        if(mResetExtents)
        {
            instance.history.totalTimePercent = framePercentage;
            instance.history.totalTimeMillisecs = frameTimeMillisecs;
            instance.history.totalCalls = 1;
        }
        else
        {
            instance.history.totalTimePercent += framePercentage;
            instance.history.totalTimeMillisecs += frameTimeMillisecs;
            instance.history.totalCalls++;
        }
        instance.history.numCallsThisFrame = instance.frame.calls;
        
        // if we find a new minimum for this profile, update it
        if (frameTimeMillisecs < instance.history.minTimeMillisecs || mResetExtents)
        {
            instance.history.minTimePercent = framePercentage;
            instance.history.minTimeMillisecs = frameTimeMillisecs;
        }
        
        // if we find a new maximum for this profile, update it
        if (frameTimeMillisecs > instance.history.maxTimeMillisecs || mResetExtents)
        {
            instance.history.maxTimePercent = framePercentage;
            instance.history.maxTimeMillisecs = frameTimeMillisecs;
        }
        
        if(instance.frame.frameTime > maxFrameTime)
            maxFrameTime = cast(Real)instance.frame.frameTime;
        
        foreach(k,child; instance.children)
        {
            
            // we set the number of times each profile was called per frame to 0
            // because not all profiles are called every frame
            child.history.numCallsThisFrame = 0;
            
            if(child.frame.calls > 0)
            {
                processFrameStats(child, maxFrameTime);
            }
        }
    }
    
    /** Handles a change of the profiler's enabled state*/
    void changeEnableState()
    {
        foreach( i; mListeners)
            i.changeEnableState(mNewEnableState);
        
        mEnabled = mNewEnableState;
    }
    
    // lol. Uses typedef; put's original container type in name.
    //typedef set<String>::type DisabledProfileMap;
    alias string[] DisabledProfileMap;
    //typedef ProfileInstance::ProfileChildren ProfileChildren;
    alias ProfileInstance.ProfileChildren ProfileChildren;
    
    ProfileInstance mCurrent;
    ProfileInstance mLast;
    ProfileInstance mRoot;
    
    /// Holds the names of disabled profiles
    DisabledProfileMap mDisabledProfiles;
    
    /// Whether the GUI elements have been initialized
    bool mInitialized;
    
    /// The number of frames that must elapse before the current
    /// frame display is updated
    uint mUpdateDisplayFrequency;
    
    /// The number of elapsed frame, used with mUpdateDisplayFrequency
    uint mCurrentFrame;
    
    /// The timer used for profiling
    Timer mTimer;
    
    /// The total time each frame takes
    ulong mTotalFrameTime;
    
    /// Whether this profiler is enabled
    bool mEnabled;
    
    /// Keeps track of the new enabled/disabled state that the user has requested
    /// which will be applied after the frame ends
    bool mNewEnableState;
    
    /// Mask to decide whether a type of profile is enabled or not
    uint mProfileMask;
    
    /// The max frame time recorded
    ulong mMaxTotalFrameTime;
    
    /// Rolling average of millisecs
    Real mAverageFrameTime;
    bool mResetExtents;

}
/** @} */
/** @} */