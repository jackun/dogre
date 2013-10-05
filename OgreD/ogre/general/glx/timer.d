module ogre.general.glx.timer;
import ogre.config;
import core.stdc.time;
debug import std.stdio;

//version(Posix)
version(linux)
{
    pragma(msg, "Using TimerGLX for Timer class");
    import core.sys.posix.sys.time;
    //struct timeval
    //{
    //    //long atleast on x86_64 linux
    //    long tv_sec;        /* Seconds.  */
    //    long tv_usec;   /* Microseconds.  */
    //}

    //extern (C) int gettimeofday (timeval * tv, void* __tz);
    //extern (C) clock_t clock ();
    //alias ulong clock_t;

    // Linux
    /** Timer class */
    class TimerGLX //: public TimerAlloc
    {
    private:
        timeval start;
        clock_t zeroClock;
    public:
        this(){ reset(); }
        ~this(){}
        
        /** Method for setting a specific option of the Timer. These options are usually
                specific for a certain implementation of the Timer class, and may (and probably
                will) not exist across different implementations.  reset() must be called after
                all setOption() calls.
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
        { return false; }
        
        /** Resets timer */
        void reset()
        {
            zeroClock = clock();
            void* nil = null;
            gettimeofday(&start, nil);
        }
        
        /** Returns milliseconds since initialisation or last reset */
        ulong getMilliseconds()
        {
            timeval now;
            void* nil = null;
            gettimeofday(&now, nil);
            //debug stderr.writeln(__FILE__,"@",__LINE__,": ", now);
            return (now.tv_sec-start.tv_sec)*1000+(now.tv_usec-start.tv_usec)/1000;
        }
        
        /** Returns microseconds since initialisation or last reset */
        ulong getMicroseconds()
        {
            timeval now;
            gettimeofday(&now, null);
            return (now.tv_sec-start.tv_sec)*1000000+(now.tv_usec-start.tv_usec);
        }
        
        /** Returns milliseconds since initialisation or last reset, only CPU time measured */  
        ulong getMillisecondsCPU()
        {
            clock_t newClock = clock();
            return cast(ulong)(cast(float)(newClock-zeroClock) / (cast(float)CLOCKS_PER_SEC/1000.0)) ;
        }
        
        /** Returns microseconds since initialisation or last reset, only CPU time measured */  
        ulong getMicrosecondsCPU()
        {
            clock_t newClock = clock();
            return cast(ulong)(cast(float)(newClock-zeroClock) / (cast(float)CLOCKS_PER_SEC/1000000.0)) ;
        }
    }
}