module ogre.general.dynlibmanager;
import ogre.singleton;
import ogre.general.dynlib;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */
/** Manager for Dynamic-loading Libraries.
 @remarks
     This manager keeps a track of all the open dynamic-loading
     libraries, opens them and returns references to already-open
     libraries.
 */
class DynLibManager //: public DynLibAlloc
{
    mixin Singleton!DynLibManager;

protected:
    //typedef map<String, DynLib*>::type DynLibList;
    alias DynLib[string] DynLibList;
    DynLibList mLibList;
public:
    /** Default constructor.
     @note
         <br>Should never be called as the singleton is automatically
         created during the creation of the Root object.
     @see
        Root::Root
     */
    this() {}
    
    /** Default destructor.
     @see
     Root::~Root
     */
    ~this()
    {
        // Unload & delete resources in turn
        foreach( k,v; mLibList)
        {
            v.unload();
            destroy(v);
        }
        
        // Empty the list
        mLibList.clear();
    }
    
    /** Loads the passed library.
     @param filename
        The name of the library. The extension can be omitted.
     */
    ref DynLib load(string filename)
    {
        auto i = filename in mLibList;
        if (i is null)
        {
            DynLib pLib = new DynLib(filename);
            pLib.load();
            mLibList[filename] = pLib;
        }
        return mLibList[filename];
    }
    
    /** Unloads the passed library.
     @param lib
        The library.
     */
    void unload(ref DynLib lib)
    {
        auto i = lib.getName() in mLibList;
        if (i !is null)
        {
            mLibList.remove(lib.getName());
        }
        lib.unload();
        destroy(lib);
    }
}
/** @} */
/** @} */