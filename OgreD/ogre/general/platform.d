module ogre.general.platform;

import core.cpuid;
import std.conv;
import ogre.general.generals;
import ogre.general.log;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */


/** Class which provides the run-time platform information Ogre runs on.
     @remarks
         Ogre is designed to be platform-independent, but some platform
         and run-time environment specific optimised functions are built-in
         to maximise performance, and those special optimised routines are
         need to determine run-time environment for select variant executing
         path.
     @par
        This class manages that provides a couple of functions to determine
        platform information of the run-time environment.
     @note
        This class is supposed to use by advanced user only.
        Assumes that it is run only on modern x86 / x86_64.
 */
class PlatformInformation
{
public:
    
    /// Enum describing the different CPU features we want to check for, platform-dependent
    enum CpuFeatures
    {
        //#if OGRE_CPU == OGRE_CPU_X86
        CPU_FEATURE_SSE         = 1 << 0,
        CPU_FEATURE_SSE2        = 1 << 1,
        CPU_FEATURE_SSE3        = 1 << 2,
        CPU_FEATURE_MMX         = 1 << 3,
        CPU_FEATURE_MMXEXT      = 1 << 4,
        CPU_FEATURE_3DNOW       = 1 << 5,
        CPU_FEATURE_3DNOWEXT    = 1 << 6,
        CPU_FEATURE_CMOV        = 1 << 7,
        CPU_FEATURE_TSC         = 1 << 8,
        CPU_FEATURE_FPU         = 1 << 9,
        CPU_FEATURE_PRO         = 1 << 10,
        CPU_FEATURE_HTT         = 1 << 11,
        //#elif OGRE_CPU == OGRE_CPU_ARM
        //        CPU_FEATURE_VFP         = 1 << 12,
        //        CPU_FEATURE_NEON        = 1 << 13,
        //#endif
        
        CPU_FEATURE_NONE        = 0
    }

    static int _isSupportCpuid()
    {
        return true;
    }

    static bool _checkOperatingSystemSupportSSE()
    {
        return true;
    }

    /** Gets a string of the CPU identifier.
     @note
     Actual detecting are performs in the first time call to this function,
     and then all future calls with return internal cached value.
     */
    static string getCpuIdentifier()
    {
        return vendor() ~ " " ~ processor();
    }
    
    /** Gets a or-masked of enum CpuFeatures that are supported by the CPU.
     @note
     Actual detecting are performs in the first time call to this function,
     and then all future calls with return internal cached value.
     */
    static uint getCpuFeatures()
    {
        uint feat = 0;
        if(sse)
            feat |= CpuFeatures.CPU_FEATURE_SSE;
        if(sse2)
            feat |= CpuFeatures.CPU_FEATURE_SSE2;
        if(sse3)
            feat |= CpuFeatures.CPU_FEATURE_SSE3;
        if(mmx)
            feat |= CpuFeatures.CPU_FEATURE_MMX;
        if(amdMmx) //TODO CPU_FEATURE_MMXEXT?
            feat |= CpuFeatures.CPU_FEATURE_MMXEXT;
        if(amd3dnow)
            feat |= CpuFeatures.CPU_FEATURE_3DNOW;
        if(amd3dnowExt)
            feat |= CpuFeatures.CPU_FEATURE_3DNOWEXT;
        if(hasCmov)
            feat |= CpuFeatures.CPU_FEATURE_CMOV;
        if(hasRdtsc)
            feat |= CpuFeatures.CPU_FEATURE_TSC;
        if(x87onChip)
            feat |= CpuFeatures.CPU_FEATURE_FPU;
        if(false)//TODO CPU_FEATURE_PRO?
            feat |= CpuFeatures.CPU_FEATURE_PRO;
        if(hyperThreading)//TODO CPU_FEATURE_HTT?
            feat |= CpuFeatures.CPU_FEATURE_HTT;

        uint sse_features = CpuFeatures.CPU_FEATURE_SSE |
            CpuFeatures.CPU_FEATURE_SSE2 | CpuFeatures.CPU_FEATURE_SSE3;

        if ((feat & sse_features) && !_checkOperatingSystemSupportSSE())
        {
            feat &= ~sse_features;
        }

        return feat;
    }
    
    /** Gets whether a specific feature is supported by the CPU.
     @note
     Actual detecting are performs in the first time call to this function,
     and then all future calls with return internal cached value.
     */
    static bool hasCpuFeature(CpuFeatures feature)
    {
        final switch(feature)
        {
            case CpuFeatures.CPU_FEATURE_SSE:
                return sse;
            case CpuFeatures.CPU_FEATURE_SSE2:
                return sse2;
            case CpuFeatures.CPU_FEATURE_SSE3:
                return sse3;
            case CpuFeatures.CPU_FEATURE_MMX:
                return mmx;
            case CpuFeatures.CPU_FEATURE_MMXEXT: //TODO CPU_FEATURE_MMXEXT?
                return amdMmx;
            case CpuFeatures.CPU_FEATURE_3DNOW:
                return amd3dnow;
            case CpuFeatures.CPU_FEATURE_3DNOWEXT:
                return amd3dnowExt;
            case CpuFeatures.CPU_FEATURE_CMOV:
                return hasCmov;
            case CpuFeatures.CPU_FEATURE_TSC:
                return hasRdtsc;
            case CpuFeatures.CPU_FEATURE_FPU:
                return x87onChip;
            case CpuFeatures.CPU_FEATURE_PRO: //TODO CPU_FEATURE_PRO?
                return false;
            case CpuFeatures.CPU_FEATURE_HTT: //TODO CPU_FEATURE_HTT?
                return hyperThreading;
            case CpuFeatures.CPU_FEATURE_NONE:
                return false;
        }
    }
    
    
    /** Write the CPU information to the passed in Log */
    static void log(ref Log pLog)
    {
        pLog.logMessage("CPU Identifier & Features");
        pLog.logMessage("-------------------------");
        pLog.logMessage(" *   CPU ID: " ~ getCpuIdentifier());
        //#if OGRE_CPU == OGRE_CPU_X86
        if(_isSupportCpuid())
        {
            pLog.logMessage(
                " *      SSE: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_SSE)));
            pLog.logMessage(
                " *     SSE2: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_SSE2)));
            pLog.logMessage(
                " *     SSE3: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_SSE3)));
            pLog.logMessage(
                " *      MMX: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_MMX)));
            pLog.logMessage(
                " *   MMXEXT: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_MMXEXT)));
            pLog.logMessage(
                " *    3DNOW: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_3DNOW)));
            pLog.logMessage(
                " * 3DNOWEXT: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_3DNOWEXT)));
            pLog.logMessage(
                " *     CMOV: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_CMOV)));
            pLog.logMessage(
                " *      TSC: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_TSC)));
            pLog.logMessage(
                " *      FPU: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_FPU)));
            pLog.logMessage(
                " *      PRO: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_PRO)));
            pLog.logMessage(
                " *       HT: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_HTT)));
        }
        //#elif OGRE_CPU == OGRE_CPU_ARM || OGRE_PLATFORM == OGRE_PLATFORM_ANDROID
        //pLog.logMessage(
        //        " *      VFP: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_VFP)));
        //pLog.logMessage(
        //        " *     NEON: " ~ std.conv.to!string(hasCpuFeature(CpuFeatures.CPU_FEATURE_NEON)));
        //#endif
        pLog.logMessage("-------------------------");
        
    }
    
}
/** @} */
/** @} */