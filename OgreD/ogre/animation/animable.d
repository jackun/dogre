module ogre.animation.animable;

import std.variant;
//import std.c.string : memcpy; //well, if phobos uses this...
//import std.container;
public import ogre.sharedptr;
import ogre.compat;
import ogre.math.angles;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.general.colourvalue;
import ogre.exception;

/** \addtogroup Core
*  @{
*/

/** \addtogroup Animation
*  @{
*/

/** Defines an object property which is animable, i.e. may be keyframed.
@remarks
    Animable properties are those which can be altered over time by a 
    predefined keyframe sequence. They may be set directly, or they may
    be modified from their existing state (common if multiple animations
    are expected to apply at once). Implementors of this interface are
    expected to override the 'setValue', 'setCurrentStateAsBaseValue' and 
    'applyDeltaValue' methods appropriate to the type in question, and to 
    initialise the type.
@par
    AnimableValue instances are accessible through any class which extends
    AnimableObject in order to expose it's animable properties.
@note
    This class is an instance of the Adapter pattern, since it generalises
    access to a particular property. Whilst it could have been templated
    such that the type which was being referenced was compiled in, this would
    make it more difficult to aggregated generically, and since animations
    are often comprised of multiple properties it helps to be able to deal
    with all values through a single class.
*/
class AnimableValue// : public AnimableAlloc
{
public:
    /// The type of the value being animated
    enum ValueType
    {
        INT,
        REAL,
        VECTOR2,
        VECTOR3,
        VECTOR4,
        QUATERNION,
        COLOUR,
        RADIAN,
        DEGREE
    }
//protected:
public:
    /// Value type
    ValueType mType;

    /// Base value data
    union
    {
        int mBaseValueInt;
        Real[4] mBaseValueReal;
    }

    /// Internal method to set a value as base
    void setAsBaseValue(int val) { mBaseValueInt = val; }
    /// Internal method to set a value as base
    void setAsBaseValue(Real val) { mBaseValueReal[0] = val; }
    /// Internal method to set a value as base
    void setAsBaseValue(Vector2 val) 
    {   mBaseValueReal[0] = val.x; 
        mBaseValueReal[1] = val.y; }
    /// Internal method to set a value as base
    void setAsBaseValue(Vector3 val) 
    {   mBaseValueReal[0] = val.x; 
        mBaseValueReal[1] = val.y;
        mBaseValueReal[2] = val.z; }
    /// Internal method to set a value as base
    void setAsBaseValue(Vector4 val) 
    {   mBaseValueReal[0] = val.x; 
        mBaseValueReal[1] = val.y;
        mBaseValueReal[2] = val.z;
        mBaseValueReal[3] = val.w; }
    /// Internal method to set a value as base
    void setAsBaseValue(Quaternion val) 
    {   mBaseValueReal[0] = val.w;
        mBaseValueReal[1] = val.x; 
        mBaseValueReal[2] = val.y;
        mBaseValueReal[3] = val.z; }

    /// Internal method to set a value as base
    void setAsBaseValue(Variant val)
    {
        switch(mType)
        {
        case ValueType.INT:
                setAsBaseValue(val.get!int);
            break;
        case ValueType.REAL:
                setAsBaseValue(val.get!Real);
            break;
        case ValueType.VECTOR2:
                setAsBaseValue(val.get!Vector2);
            break;
        case ValueType.VECTOR3:
                setAsBaseValue(val.get!Vector3);
            break;
        case ValueType.VECTOR4:
                setAsBaseValue(val.get!Vector4);
            break;
        case ValueType.QUATERNION:
                setAsBaseValue(val.get!Quaternion);
            break;
        case ValueType.COLOUR:
                setAsBaseValue(val.get!ColourValue);
            break;
        case ValueType.DEGREE:
                setAsBaseValue(val.get!Degree);
            break;
        case ValueType.RADIAN:
                setAsBaseValue(val.get!Radian);
            break;
        default: 
            break;
        }
    }
    /// Internal method to set a value as base
    void setAsBaseValue(ColourValue val)
    { 
        mBaseValueReal[0] = val.r;
        mBaseValueReal[1] = val.g;
        mBaseValueReal[2] = val.b;
        mBaseValueReal[3] = val.a;
    }
    /// Internal method to set a value as base
    void setAsBaseValue(Radian val)
    { 
        mBaseValueReal[0] = val.valueRadians();
    }
    /// Internal method to set a value as base
    void setAsBaseValue(Degree val)
    { 
        mBaseValueReal[0] = val.valueRadians();
    }


public:
    this(ValueType t){ mType = t; }
    ~this() {}

    /// Gets the value type of this animable value
    ValueType getType(){ return mType; }

    /// Sets the current state as the 'base' value; used for delta animation
    void setCurrentStateAsBaseValue() { onNotImplementedError(); }

    /// Set value 
    void setValue(int) { onNotImplementedError(); }
    /// Set value 
    void setValue(Real) { onNotImplementedError(); }
    /// Set value 
    void setValue(Vector2) { onNotImplementedError(); }
    /// Set value 
    void setValue(Vector3) { onNotImplementedError(); }
    /// Set value 
    void setValue(Vector4) { onNotImplementedError(); }
    /// Set value 
    void setValue(Quaternion) { onNotImplementedError(); }
    /// Set value 
    void setValue(ColourValue) { onNotImplementedError(); }
    /// Set value 
    void setValue(Radian) { onNotImplementedError(); }
    /// Set value 
    void setValue(Degree) { onNotImplementedError(); }
    /// Set value 
    void setValue(Variant val)//TODO setValue with Variant
    {
        switch(mType)
        {
        case ValueType.INT:
                setValue(val.get!int);
            break;
        case ValueType.REAL:
                setValue(val.get!Real);
            break;
        case ValueType.VECTOR2:
                setValue(val.get!Vector2);
            break;
        case ValueType.VECTOR3:
                setValue(val.get!Vector3);
            break;
        case ValueType.VECTOR4:
                setValue(val.get!Vector4);
            break;
        case ValueType.QUATERNION:
                setValue(val.get!Quaternion);
            break;
        case ValueType.COLOUR:
                setValue(val.get!ColourValue);
            break;
        case ValueType.RADIAN:
                setValue(val.get!Radian);
            break;
        case ValueType.DEGREE:
                setValue(val.get!Degree);
            break;
        default: 
            break;
        }
    }
    // reset to base value
    void resetToBaseValue()
    {
        switch(mType)
        {
        case ValueType.INT:
            setValue(mBaseValueInt);
            break;
        case ValueType.REAL:
            setValue(mBaseValueReal[0]);
            break;
        case ValueType.VECTOR2:
            setValue(Vector2(mBaseValueReal));
            break;
        case ValueType.VECTOR3:
            setValue(Vector3(mBaseValueReal));
            break;
        case ValueType.VECTOR4:
            setValue(Vector4(mBaseValueReal));
            break;
        case ValueType.QUATERNION:
            setValue(Quaternion(mBaseValueReal));
            break;
        case ValueType.COLOUR:
            setValue(ColourValue(mBaseValueReal[0], mBaseValueReal[1], 
                mBaseValueReal[2], mBaseValueReal[3]));
            break;
        case ValueType.DEGREE:
            setValue(Degree(mBaseValueReal[0]));
            break;
        case ValueType.RADIAN:
            setValue(Radian(mBaseValueReal[0]));
            break;
        default: 
            break;
        }
    }

    /// Apply delta value
    void applyDeltaValue(int){ onNotImplementedError(); }
    /// Set value 
    void applyDeltaValue(Real) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Vector2) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Vector3) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Vector4) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Quaternion) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(ColourValue) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Degree) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Radian) { onNotImplementedError(); }
    /// Apply delta value 
    void applyDeltaValue(Variant val)
    {
        switch(mType)
        {
        case ValueType.INT:
            applyDeltaValue(val.get!int);
            break;
        case ValueType.REAL:
                applyDeltaValue(val.get!Real);
            break;
        case ValueType.VECTOR2:
                applyDeltaValue(val.get!Vector2);
            break;
        case ValueType.VECTOR3:
                applyDeltaValue(val.get!Vector3);
            break;
        case ValueType.VECTOR4:
                applyDeltaValue(val.get!Vector4);
            break;
        case ValueType.QUATERNION:
                applyDeltaValue(val.get!Quaternion);
            break;
        case ValueType.COLOUR:
                applyDeltaValue(val.get!ColourValue);
            break;
        case ValueType.DEGREE:
                applyDeltaValue(val.get!Degree);
            break;
        case ValueType.RADIAN:
                applyDeltaValue(val.get!Radian);
            break;
        default: 
            break;
        }
    }


}

//alias SharedPtr!AnimableValue AnimableValuePtr;

/** Defines an interface to classes which have one or more AnimableValue
    instances to expose.
    @note Use templates AnimableObject_Members and AnimableObject_Impl.
*/
interface AnimableObject
{

    //typedef map<String, StringVector>::type AnimableDictionaryMap;
    alias StringVector[string] AnimableDictionaryMap;
    
    /** Hack around lack of multiple class inheritance in D.
        @note Use as mixin to include members like
            mixin AnimableObject.AnimableObject_Members!();
    */
    template AnimableObject_Members()
    {
        protected {
            /// Static map of class name to list of animable value names
            static AnimableDictionaryMap msAnimableDictionary;
        }
    }
    
    /** Hack around lack of multiple class inheritance in D.
        @note Use as mixin to include default function implementations like
            mixin AnimableObject.AnimableObject_Impl!();
    */
    template AnimableObject_Impl()
    {
        protected {
           string getAnimableDictionaryName() 
            { return ""; }
            
            void createAnimableDictionary()
            {
                auto p = (getAnimableDictionaryName() in msAnimableDictionary);
                if (p is null)
                {
                    StringVector vec;
                    initialiseAnimableDictionary(vec);
                    msAnimableDictionary[getAnimableDictionaryName()] = vec;
                }
                
            }
            
            StringVector _getAnimableValueNames()
            {
                return msAnimableDictionary[getAnimableDictionaryName()];
                //        OGRE_EXCEPT(Exception::ERR_ITEM_NOT_FOUND, 
                //            "Animable value list not found for " + getAnimableDictionaryName(), 
                //            "AnimableObject::getapplyDeltaValueNames");
            }

            //Default, do nothing
            void initialiseAnimableDictionary(ref StringVector vec){}
        }
        
        public {
            ref StringVector getAnimableValueNames() //consts
            {
                createAnimableDictionary();
                return msAnimableDictionary[getAnimableDictionaryName()];
                // OGRE_EXCEPT(Exception::ERR_ITEM_NOT_FOUND, 
                //     "Animable value list not found for " + getAnimableDictionaryName(), 
                //     "AnimableObject::getAnimableValueNames");
            }
            
            SharedPtr!AnimableValue createAnimableValue(string valueName)
            {
                throw new ItemNotFoundError("No animable value named '" ~ valueName ~ "' present.", 
                                    "AnimableObject.createAnimableValue");
                return SharedPtr!AnimableValue();
                //OGRE_EXCEPT(Exception::ERR_ITEM_NOT_FOUND, 
                //    "No animable value named '" + valueName + "' present.", 
                //    "AnimableObject::createAnimableValue");
            }
        }
    }

    
    /** Get the name of the animable dictionary for this class.
    @remarks
        Subclasses must override this if they want to support animation of
        their values.
    */
   string getAnimableDictionaryName();
    /** Internal method for creating a dictionary of animable value names 
        for the class, if it does not already exist.
    */
    void createAnimableDictionary();

    /// Get an updateable reference to animable value list
    StringVector _getAnimableValueNames();

    /** Internal method for initialising dictionary; should be implemented by 
        subclasses wanting to expose animable parameters.
    */
    void initialiseAnimableDictionary(ref StringVector vec);


//public:
    //this() {}
    //~this() {}

    /** Gets a list of animable value names for this object. */
    ref StringVector getAnimableValueNames();

    /** Create a reference-counted SharedPtr!AnimableValue for the named value.
    @remarks
        You can use the returned object to animate a value on this object,
        using AnimationTrack. Subclasses must override this if they wish 
        to support animation of their values.
    */
    SharedPtr!AnimableValue createAnimableValue(string valueName);
}

/** @} */
/** @} */

unittest
{
    {
        //import std.stdio: writeln;
        auto av = new AnimableValue(AnimableValue.ValueType.VECTOR4);
        auto v = Vector4(21f,64f,36f,81f);
        av.setAsBaseValue(v);
        //writeln("Real[4]:", av.mBaseValueReal, ", Int:", av.mBaseValueInt);
        assert(av.mBaseValueInt == 1101529088);
    }

}