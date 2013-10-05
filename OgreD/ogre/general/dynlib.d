module ogre.general.dynlib;
import ogre.general.log;
import ogre.exception;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */

/** Resource holding data about a dynamic library.
    DOES NOTHING, for now.
 @remarks
     This class holds the data required to get symbols from
     libraries loaded at run-time (i.e. from DLL's for so's)
 @author
    Adrian Cearn„u (cearny@cearny.ro)
 @since
    27 January 2002
 @see
    Resource
 */
class DynLib //: public DynLibAlloc
{
protected:
    string mName;
    /// Gets the last loading error
    string dynlibError()
    {
        return "";
    }

public:
    /** Default constructor - used by DynLibManager.
     @warning
     Do not call directly
     */
    this(string name )
    {
        mName = name;
        //mInst = null;
    }
    
    /** Default destructor.
     */
    ~this(){}
    
    /** Load the library
     */
    void load()
    {
        LogManager.getSingleton().logMessage("Loading library " ~ mName);

        // Yadda-yadda find and load libraries

        if( mInst is null )
            throw new InternalError(
                "Could not load dynamic library " ~ mName ~ ".  System Error: " ~ dynlibError(),
                "DynLib.load" );
    }

    /** Unload the library
     */
    void unload()
    {
        // Log library unload
        LogManager.getSingleton().logMessage("Unloading library " ~ mName);
        
        if( false )
        {
            throw new InternalError(
                "Could not unload dynamic library " ~ mName ~
                ".  System Error: " ~ dynlibError(),
                "DynLib.unload");
        }
        
    }

    /// Get the name of the library
   string getName(){ return mName; }
    
    /**
        Returns the address of the given symbol from the loaded library.
     @param
        strName The name of the symbol to search for
     @return
         If the function succeeds, the returned value is a handle to
         the symbol.
     @par
        If the function fails, the returned value is <b>NULL</b>.

     */
    void* getSymbol(string strName )
    {
        assert(0, "Not supported yet.");
    }

    //FAKERS!
    void dllStopPlugin(){}
    void dllStartPlugin(){}
    
protected:

    alias ulong* DYNLIB_HANDLE;
    /// Handle to the loaded library.
    DYNLIB_HANDLE mInst = null;
}
/** @} */
/** @} */