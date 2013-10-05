module ogre.general.generals;

import core.sync.mutex;

import ogre.compat;
import ogre.exception;
import ogre.singleton;
import ogre.sharedptr;

import ogre.math.vector;
import ogre.math.quaternion;
import ogre.resources.datastream;

//import ogre.general.common;
alias string[string] NameValuePairList; //FIXME From common, but loop-de-loop hang in compiling

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */

/** Abstract factory class. Does nothing by itself, but derived classes can add
 functionality.
 */
class FactoryObj(T)
{
public:
    ~this() {}
    
    /** Returns the factory type.
     @return
     The factory type.
     */
    abstract string getType();
    
    /** Creates a new object.
     @param name Name of the object to create
     @return
     An object created by the factory. The type of the object depends on
     the factory.
     */
    abstract T createInstance(string name);
    /** Destroys an object which was created by this factory.
     @param ptr Pointer to the object to destroy
     */
    abstract void destroyInstance(ref T ptr);
}

/// List of parameter types available
enum ParameterType
{
    PT_BOOL,
    PT_REAL,
    PT_INT,
    PT_UNSIGNED_INT,
    PT_SHORT,
    PT_UNSIGNED_SHORT,
    PT_LONG,
    PT_UNSIGNED_LONG,
    PT_STRING,
    PT_VECTOR3,
    PT_MATRIX3,
    PT_MATRIX4,
    PT_QUATERNION,
    PT_COLOURVALUE
}

/// Definition of a parameter supported by a StringInterface class, for introspection
class ParameterDef
{
public:
    string name;
    string description;
    ParameterType paramType;
    this(string newName,string newDescription, ParameterType newType)
    {
        name = newName;
        description = newDescription;
        paramType = newType;
    }
}
alias ParameterDef[] ParameterList;

/** Abstract class which is command object which gets/sets parameters.*/
//TODO D'ify ParamCommand someway?
interface ParamCommand
{
    string doGet(Object target);//void*
    void doSet(Object target,string val);
}

alias ParamCommand[string] ParamCommandMap;

/** Class to hold a dictionary of parameters for a single class. */
class ParamDictionary
{
    //friend class StringInterface;
//protected:
public: //FIXME for friends
    /// Definitions of parameters
    ParameterList mParamDefs;

    /// Command objects to get/set
    ParamCommandMap mParamCommands;

public:
    /** Retrieves the parameter command object for a named parameter. */
    ParamCommand getParamCommand(string name)
    {
        auto i = name in mParamCommands;
        if (i !is null)
        {
            return *i;
        }
        else
        {
            return null;
        }
    }
public:
    this()  {}
    /** Method for adding a parameter definition for this class. 
     @param paramDef A ParameterDef object defining the parameter
     @param paramCmd Pointer to a ParamCommand subclass to handle the getting / setting of this parameter.
     NB this class will not destroy this on shutdown, please ensure you do

     */
    void addParameter(ParameterDef paramDef, ParamCommand paramCmd)
    {
        mParamDefs.insert(paramDef);
        mParamCommands[paramDef.name] = paramCmd;
    }
    /** Retrieves a list of parameters valid for this object. 
     @return
     A reference to a static list of ParameterDef objects.

     */
    ref ParameterList getParameters()
    {
        return mParamDefs;
    }

}

alias ParamDictionary[string] ParamDictionaryMap;

/** Interface defining the common interface which classes can use to 
 present a reflection-style, self-defining parameter set to callers.
 Use template mixin StringInterfaceTmpl to implement.
 */
interface StringInterface
{
    ref ParamDictionary getParamDictionary();
    //ref const(ParamDictionary) getParamDictionary() const;
    ref ParameterList getParameters();
    bool setParameter(string name,string value);
    void setParameterList(NameValuePairList paramList);
    string getParameter(string name);
    void copyParametersTo(StringInterface dest);

    //There should be only one msDictionary
    class Dict
    {
        //OGRE_STATIC_MUTEX( msDictionaryMutex )
        static Mutex msDictionaryMutex;
        /// Dictionary of parameters
        static ParamDictionaryMap msDictionary;
        
        //static this()
        static void staticThis()
        {
            msDictionaryMutex = new Mutex;
        }

        
        /** Cleans up the static 'msDictionary' required to reset Ogre,
         otherwise the containers are left with invalid pointers, which will lead to a crash
         as soon as one of the ResourceManager implementers (e.g. MaterialManager) initializes.*/
        static void cleanupDictionary ()
        {
            synchronized(msDictionaryMutex)
            {
                msDictionary.clear();
            }
        }
    }
}

/** Template mixin defining the common interface which classes can use to 
 present a reflection-style, self-defining parameter set to callers.
 @remarks
 This class also holds a static map of class name to parameter dictionaries
 for each subclass to use. See ParamDictionary for details. 
 @remarks
 In order to use this class, each subclass must call createParamDictionary in their constructors
 which will create a parameter dictionary for the class if it does not exist yet.

 import ogre.general.common;
 */

/*class StringInterface
 {
 //OGRE_STATIC_MUTEX( msDictionaryMutex )
 static Mutex msDictionaryMutex;
 /// Dictionary of parameters
 static ParamDictionaryMap msDictionary; //FIXME There should be only one msDictionary (?)

 static this()
 {
 msDictionaryMutex = new Mutex;
 }
 }*/

mixin template StringInterfaceTmpl()
{
private:
    /// Class name for this instance to be used as a lookup (must be initialised by subclasses)
    string mParamDictName;
    ParamDictionary mParamDict;
protected:
    /** Internal method for creating a parameter dictionary for the class, if it does not already exist.
     @remarks
     This method will check to see if a parameter dictionary exist for this class yet,
     and if not will create one. NB you must supply the name of the class (RTTI is not 
     used or performance).
     @param
     className the name of the class using the dictionary
     @return
     true if a new dictionary was created, false if it was already there
     */
    bool createParamDictionary(string className)
    {
        //OGRE_LOCK_MUTEX( msDictionaryMutex )
        synchronized(StringInterface.Dict.msDictionaryMutex)
        {
            auto it = className in StringInterface.Dict.msDictionary;
            
            if ( it is null )
            {
                //mParamDict = &msDictionary.insert( std::make_pair( className, ParamDictionary() ) ).first.second;
                mParamDict = new ParamDictionary;
                StringInterface.Dict.msDictionary[className] = mParamDict;
                mParamDictName = className;
                return true;
            }
            else
            {
                mParamDict = *it;
                mParamDictName = className;
                return false;
            }
        }
    }

public:

    /** Retrieves the parameter dictionary for this class. 
     @remarks
     Only valid to call this after createParamDictionary.
     @return
     Pointer to ParamDictionary shared by all instances of this class
     which you can add parameters to, retrieve parameters etc.
     */
    ref ParamDictionary getParamDictionary()
    {
        return mParamDict;
    }

    /*ref const(ParamDictionary) getParamDictionary() const
     {
     return mParamDict;
     }*/

    /** Retrieves a list of parameters valid for this object. 
     @return
     A reference to a static list of ParameterDef objects.

     */
    ref ParameterList getParameters()
    {
        static ParameterList emptyList;

        ParamDictionary dict = getParamDictionary();
        if (dict)
            return dict.getParameters();
        else
            return emptyList;

    }

    /** Generic parameter setting method.
     @remarks
     Call this method with the name of a parameter and a string version of the value
     to set. The implementor will convert the string to a native type internally.
     If in doubt, check the parameter definition in the list returned from 
     StringInterface::getParameters.
     @param
     name The name of the parameter to set
     @param
     value string value. Must be in the right format for the type specified in the parameter definition.
     See the StringConverter class for more information.
     @return
     true if set was successful, false otherwise (NB no exceptions thrown - tolerant method)
     */
    bool setParameter(string name,string value)
    {
        // Get dictionary
        auto dict = getParamDictionary();

        if (dict)
        {
            // Look up command object
            auto cmd = dict.getParamCommand(name);
            if (cmd)
            {
                cmd.doSet(this, value);
                return true;
            }
        }
        // Fallback
        return false;
    }
    /** Generic multiple parameter setting method.
     @remarks
     Call this method with a list of name / value pairs
     to set. The implementor will convert the string to a native type internally.
     If in doubt, check the parameter definition in the list returned from 
     StringInterface::getParameters.
     @param
     paramList Name/value pair list
     */
    void setParameterList(NameValuePairList paramList)
    {
        foreach (k, v; paramList)
        {
            setParameter(k, v);
        }
    }
    /** Generic parameter retrieval method.
     @remarks
     Call this method with the name of a parameter to retrieve a string-format value of
     the parameter in question. If in doubt, check the parameter definition in the
     list returned from getParameters for the type of this parameter. If you
     like you can use StringConverter to convert this string back into a native type.
     @param
     name The name of the parameter to get
     @return
     string value of parameter, blank if not found
     */
    string getParameter(string name)
    {
        // Get dictionary
        auto dict = getParamDictionary();

        if (dict)
        {
            // Look up command object
            auto cmd = dict.getParamCommand(name);

            if (cmd)
            {
                return cmd.doGet(this);
            }
        }

        // Fallback
        return "";
    }
    /** Method for copying this object's parameters to another object.
     @remarks
     This method takes the values of all the object's parameters and tries to set the
     same values on the destination object. This provides a completely type independent
     way to copy parameters to other objects. Note that because of the string manipulation 
     involved, this should not be regarded as an efficient process and should be saved for
     times outside of the rendering loop.
     @par
     Any unrecognised parameters will be ignored as with setParameter method.
     @param dest Pointer to object to have it's parameters set the same as this object.

     */
    void copyParametersTo(StringInterface dest)
    {
        // Get dictionary
        auto dict = getParamDictionary();

        if (dict)
        {
            // Iterate through own parameters
            
            foreach (i; dict.mParamDefs)
            {
                dest.setParameter(i.name, getParameter(i.name));
            }
        }
    }

}



/** Abstract class defining the interface used by classes which wish 
 to perform script loading to define instances of whatever they manage.
 @remarks
 Typically classes of this type wish to either parse individual script files
 on demand, or be called with a group of files matching a certain pattern
 at the appropriate time. Normally this will coincide with resource loading,
 although the script use does not necessarily have to be a ResourceManager
 (which subclasses from this class), it may be simply a script loader which 
 manages non-resources but needs to be synchronised at the same loading points.
 @par
 Subclasses should add themselves to the ResourceGroupManager as a script loader
 if they wish to be called at the point a resource group is loaded, at which 
 point the parseScript method will be called with each file which matches a 
 the pattern returned from getScriptPatterns.
 */
interface ScriptLoader
{
    //public:
    //~this();
    /** Gets the file patterns which should be used to find scripts for this
     class.
     @remarks
     This method is called when a resource group is loaded if you use 
     ResourceGroupManager::_registerScriptLoader.
     @return
     A list of file patterns, in the order they should be searched in.
     */
    ref StringVector getScriptPatterns(); //TODO remove ref?

    /** Parse a script file.
     @param stream Weak reference to a data stream which is the source of the script
     @param groupName The name of a resource group which should be used if any resources
     are created during the parse of this script.
     */
    void parseScript(DataStreamPtr stream,string groupName);

    /** Gets the relative loading order of scripts of this type.
     @remarks
     There are dependencies between some kinds of scripts, and to enforce
     this all implementors of this interface must define a loading order. 
     @return A value representing the relative loading order of these scripts
     compared to other script users, where higher values load later.
     */
    Real getLoadingOrder();
}

/** @} */
/** @} */
