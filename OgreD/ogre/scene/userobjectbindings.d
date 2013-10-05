module ogre.scene.userobjectbindings;
import ogre.compat;

/** Class that provide convenient interface to establish a linkage between
custom user application objects and Ogre core classes.
Any instance of Ogre class that will derive from this class could be associated with custom 
application object using this class interface.
*/
class UserObjectBindings //: public GeneralAllocatedObject
{
public: 

    /** Class constructor. */
    this(){}
    
    /** Class destructor. */
    ~this(){ clear(); }
    
    /** Sets any kind of user object on this class instance.
    @remarks
    This method allows you to associate any user object you like with 
    this class. This can be a pointer back to one of your own
    classes for instance.
    @note This method is key less meaning that each call for it will override
    previous object that were set. If you need to associate multiple objects
    with this class use the extended version that takes key.
    */
    void setUserAny(Any anything)
    {
        // Allocate attributes on demand.
        if (mAttributes is null)
            mAttributes = new UserObjectBindings.Attributes;
        
        mAttributes.mKeylessAny = anything;
    }
    
    /** Retrieves the custom key less user object associated with this class.
    */
    ref Any getUserAny()
    {
        // Allocate attributes on demand.
        if (mAttributes is null)
            mAttributes = new UserObjectBindings.Attributes;
        
        return mAttributes.mKeylessAny;
    }
    
    /** Sets any kind of user object on this class instance.
    @remarks
    This method allows you to associate multiple object with this class. 
    This can be a pointer back to one of your own classes for instance.
    Use a unique key to distinguish between each of these objects. 
    @param key The key that this data is associate with.
    @param anything The data to associate with the given key.
    */
    void setUserAny(string key, ref Any anything)
    {
        // Allocate attributes on demand.
        if (mAttributes is null)
            mAttributes = new UserObjectBindings.Attributes;
        
        // Case map doesn't exists.
        //if (mAttributes.mUserObjectsMap is null)
        //    mAttributes.mUserObjectsMap = new UserObjectsMap;
        
        mAttributes.mUserObjectsMap[key] = anything;
    }
    
    /** Retrieves the custom user object associated with this class and key.
    @param key The key that the requested user object is associated with.
    @remarks
    In case no object associated with this key the returned Any object will be empty.
    */
    ref Any getUserAny(string key)
    {
        // Allocate attributes on demand.
        if (mAttributes is null)
            mAttributes = new UserObjectBindings.Attributes;
        
        // Case map doesn't exists.
        if (mAttributes.mUserObjectsMap is null)
            return msEmptyAny;
        
        auto it = key in mAttributes.mUserObjectsMap;
        
        // Case user data found.
        if (it !is null)
        {
            return *it;
        }
        
        return msEmptyAny;
    }
    
    /** Erase the custom user object associated with this class and key from this binding.
    @param key The key that the requested user object is associated with.       
    */
    void eraseUserAny(string key)
    {
        // Case attributes and map allocated.
        if (mAttributes !is null && mAttributes.mUserObjectsMap !is null)
        {
            auto it = key in mAttributes.mUserObjectsMap;
            
            // Case object found . erase it from the map.
            if (it !is null)
            {
                mAttributes.mUserObjectsMap.remove(key);
            }
        }
    }
    
    /** Clear all user objects from this binding.   */
    void clear()
    {
        if (mAttributes !is null)
        {           
            destroy(mAttributes);
            mAttributes = null;
        }
    }
    
    /** Returns empty user any object.
    */
    static Any getEmptyUserAny() { return msEmptyAny; } //TODO msEmptyAny - create new instance?
    
    // Types.
protected:      
    //typedef map<string, Any>.type          UserObjectsMap;
    //typedef UserObjectsMap.iterator        UserObjectsMapIterator;
    //typedef UserObjectsMap.const_iterator  UserObjectsMapConstIterator;
    
    alias Any[string]          UserObjectsMap;
    
    /** Internal class that uses as data storage container.
    */
    class Attributes //: public GeneralAllocatedObject
    {
    public:
        /** Attribute storage ctor. */
        this()
        {
            mUserObjectsMap = null;
        }
        
        /** Attribute storage dtor. */
        ~this()
        {
            if (mUserObjectsMap !is null)
            {
                destroy(mUserObjectsMap);
                mUserObjectsMap = null;
            }               
        }
        
        Any                 mKeylessAny;        // Will hold key less associated user object for fast access.   
        UserObjectsMap      mUserObjectsMap;    // Will hold a map between user keys to user objects.
    }
    
    // Attributes.
private:
    static Any              msEmptyAny;         // Shared empty any object.
    //mutable 
    Attributes              mAttributes;        // Class attributes - will be allocated on demand.
    
}
