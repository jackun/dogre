module ogre.general.windows.timer;
import std.algorithm;
import ogre.math.bitwise;
import core.stdc.time;

//TODO Import APIs

version(Windows) //Or set to not compile (?)
{
    import core.sys.windows.windows;
    //druntime seems to be missing these
    alias DWORD_PTR *PDWORD_PTR;
    extern(Windows)
    {
        BOOL GetProcessAffinityMask(HANDLE hProcess, PDWORD_PTR lpProcessAffinityMask, PDWORD_PTR lpSystemAffinityMask);
        DWORD_PTR SetThreadAffinityMask(HANDLE hThread, DWORD_PTR dwThreadAffinityMask);
    }

    class TimerWin32 //: public TimerAlloc
    {
    private:
        clock_t mZeroClock;
        /*alias uint HANDLE;
        alias uint DWORD;
        alias uint* DWORD_PTR;
        alias long LONGLONG;
        alias ulong LARGE_INTEGER;*/
        
        DWORD mStartTick;
        LONGLONG mLastTime;
        //LARGE_INTEGER mStartTime;
        //LARGE_INTEGER mFrequency;
        long mStartTime;
        long mFrequency;
        
        version(Win32)
            DWORD_PTR mTimerMask;
        else //WINRT
        DWORD GetTickCount() { return cast(DWORD)GetTickCount64(); }
                
    public:
        /** Timer constructor.  MUST be called on same thread that calls getMilliseconds() */
        this()
        {
            //version(Win32) mTimerMask = null;
            reset();
        }
        ~this(){}
        
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
        bool setOption(string strKey,void* pValue )
        {
            version(Win32){
                if ( strKey == "QueryAffinityMask" )
                {
                    // Telling timer what core to use for a timer read
                    DWORD newTimerMask = * (cast (DWORD *) ( pValue ));
                    
                    // Get the current process core mask
                    DWORD_PTR procMask;
                    DWORD_PTR sysMask;
                    GetProcessAffinityMask(GetCurrentProcess(), &procMask, &sysMask);
                    
                    // If new mask is 0, then set to default behavior, otherwise check
                    // to make sure new timer core mask overlaps with process core mask
                    // and that new timer core mask is a power of 2 (i.e. a single core)
                    if( ( newTimerMask == 0 ) ||
                       ( ( ( newTimerMask & procMask ) != 0 ) && Bitwise.isPO2( newTimerMask ) ) )
                    {
                        mTimerMask = newTimerMask;
                        return true;
                    }
                }
            }
            
            return false;
        }
        
        /** Resets timer */
        void reset()
        {
            version(Win32)
            {
                // Get the current process core mask
                DWORD_PTR procMask;
                DWORD_PTR sysMask;
                GetProcessAffinityMask(GetCurrentProcess(), &procMask, &sysMask);
                
                // If procMask is 0, consider there is only one core available
                // (using 0 as procMask will cause an infinite loop below)
                if (procMask == 0)
                    procMask = 1;
                
                // Find the lowest core that this process uses
                if( mTimerMask == 0 )
                {
                    mTimerMask = 1;
                    while( ( mTimerMask & procMask ) == 0 )
                    {
                        mTimerMask <<= 1;
                    }
                }
                
                HANDLE thread = GetCurrentThread();
                
                // Set affinity to the first core
                DWORD_PTR oldMask = SetThreadAffinityMask(thread, mTimerMask);
            }
            
            // Get theant frequency
            QueryPerformanceFrequency(&mFrequency);
            
            // Query the timer
            QueryPerformanceCounter(&mStartTime);
            mStartTick = GetTickCount();
            
            
            // Reset affinity
            version(Win32) SetThreadAffinityMask(thread, oldMask);
            
            mLastTime = 0;
            mZeroClock = clock();
        }

        
        /** Returns milliseconds since initialisation or last reset */
        ulong getMilliseconds()
        {
            //LARGE_INTEGER curTime;
            long curTime;
            
            version(Win32)
            {
                HANDLE thread = GetCurrentThread();
                
                // Set affinity to the first core
                DWORD_PTR oldMask = SetThreadAffinityMask(thread, mTimerMask);
            }
            
            // Query the timer
            QueryPerformanceCounter(&curTime);
            

            // Reset affinity
            version(Win32) SetThreadAffinityMask(thread, oldMask);
            
            LONGLONG newTime = curTime - mStartTime;
            
            // scale by 1000 for milliseconds
            ulong newTicks = cast(ulong) (1000 * newTime / mFrequency);
            
            // detect and compensate for performance counter leaps
            // (surprisingly common, see Microsoft KB: Q274323)
            ulong check = GetTickCount() - mStartTick;
            long msecOff = cast(long)(newTicks - check);
            if (msecOff < -100 || msecOff > 100)
            {
                // We must keep the timer running forward :)
                long adjust = std.algorithm.min(msecOff * mFrequency / 1000, newTime - mLastTime);
                mStartTime += adjust;
                newTime -= adjust;
                
                // Re-calculate milliseconds
                newTicks = cast(ulong) (1000 * newTime / mFrequency);
            }
            
            // Record last time for adjust
            mLastTime = newTime;
            
            return newTicks;
        }
        
        /** Returns microseconds since initialisation or last reset */
        ulong getMicroseconds()
        {
            //LARGE_INTEGER curTime;
            long curTime;
            
            version(Win32)
            {
                HANDLE thread = GetCurrentThread();
                
                // Set affinity to the first core
                DWORD_PTR oldMask = SetThreadAffinityMask(thread, mTimerMask);
            }
            
            // Query the timer
            QueryPerformanceCounter(&curTime);

            // Reset affinity
            version(Win32) SetThreadAffinityMask(thread, oldMask);
            
            long newTime = curTime - mStartTime;
            
            // get milliseconds to check against GetTickCount
            ulong newTicks = cast(ulong) (1000 * newTime / mFrequency);
            
            // detect and compensate for performance counter leaps
            // (surprisingly common, see Microsoft KB: Q274323)
            ulong check = GetTickCount() - mStartTick;
            long msecOff = cast(long)(newTicks - check);
            if (msecOff < -100 || msecOff > 100)
            {
                // We must keep the timer running forward :)
                long adjust = std.algorithm.min(msecOff * mFrequency / 1000, newTime - mLastTime);
                mStartTime += adjust;
                newTime -= adjust;
            }
            
            // Record last time for adjust
            mLastTime = newTime;
            
            // scale by 1000000 for microseconds
            long newMicro = cast(long) (1000000 * newTime / mFrequency);
            
            return newMicro;
        }
        
        /** Returns milliseconds since initialisation or last reset, only CPU time measured */
        ulong getMillisecondsCPU()
        {
            clock_t newClock = clock();
            return cast(ulong)( cast(float)( newClock - mZeroClock ) / ( cast(float)CLOCKS_PER_SEC / 1000.0 ) ) ;
        }
        
        /** Returns microseconds since initialisation or last reset, only CPU time measured */
        ulong getMicrosecondsCPU()
        {
            clock_t newClock = clock();
            return cast(ulong)( cast(float)( newClock - mZeroClock ) / ( cast(float)CLOCKS_PER_SEC / 1000000.0 ) ) ;
        }
    }

}