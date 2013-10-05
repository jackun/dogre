module ogre.general.timer;

version(Windows)
{
    import ogre.general.windows.timer;
    alias TimerWin32 Timer;
}
else version(linux)
{
    public import ogre.general.glx.timer;
    alias TimerGLX Timer;
}
else
{
    /** NULL Timer class for now. Returns zeros and does nothing good. 
     @todo Use Phobos to implement.*/
    class Timer
    {
        /** Method for setting a specific option of the Timer. These options are usually
            specific for a certain implementation of the Timer class, and may (and probably
            will) not exist across different implementations.  reset() must be called after
            all setOption() calls.
            @par
            Current options supported are:
            <ul><li>"QueryAffinityMask" (DWORD): Set the thread affinity mask to be used
            to check the timer. If 'reset' has been called already this mask should
            overlap with the process mask that was in force at that point, and should
            be a power of two (a single core).</li></ul>
            @param
                strKey The name of the option to set
            @param
                pValue A pointer to the value - the size should be calculated by the timer
                based on the key
            @return
                On success, true is returned.
            @par
                On failure, false is returned.
        */
        bool setOption( string strKey,void* pValue ){ return false; }
        
        /** Resets timer */
        void reset(){}
        
        /** Returns milliseconds since initialisation or last reset */
        ulong getMilliseconds(){assert(0,"Not implemented."); return 0;}
        
        /** Returns microseconds since initialisation or last reset */
        ulong getMicroseconds(){return 0;}
        
        /** Returns milliseconds since initialisation or last reset, only CPU time measured */
        ulong getMillisecondsCPU(){return 0;}
        
        /** Returns microseconds since initialisation or last reset, only CPU time measured */
        ulong getMicrosecondsCPU(){return 0;}
    }
}