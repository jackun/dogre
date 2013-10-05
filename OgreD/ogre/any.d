module ogre.any;
//import std.variant;
//alias Variant Any;

//Fail at mapping C++-to-D 
/+class Any(ValueType)
{
public: // constructors

    this()
    {
        mContent = (0);
    }

    this(ValueType value)
    {
        mContent = holder!ValueType(value);
    }

    this(Any  other)
    {
        mContent = (other.mContent ? other.mContent.clone() : 0);
    }

    ~this()
    {
        destroy();
    }

public: // modifiers

    ref Any swap(ref Any  rhs)
    {
        //std::swap(mContent, rhs.mContent);
        assert(0);
        return this;
    }

    ref Any opAssign(ValueType rhs)
    {
        rhs.swap(this);
        return this;
    }

    ref Any opAssign(Any rhs)
    {
        rhs.swap(this);
        return this;
    }

public: // queries

    bool isEmpty()
    {
        return !mContent;
    }

    /*std::type_info& getType()
    {
        return mContent ? mContent.getType() : typeid();
    }*/

    void destroy()
    {
        //OGRE_DELETE_T(mContent, placeholder, MEMCATEGORY_GENERAL);
        mContent = null;
    }

protected: // types

    class placeholder 
    {
    public: // queries
        //std::type_info& getType(){}
        placeholder * clone(){}
    }

    
    class holder(ValueType) : placeholder
    {
    public: // structors

        this(ValueType  value)
        {
            held = (value);
        }

    public: // queries

       TypeInfo getType()
        {
            return typeid(ValueType);
        }

        placeholder * clone()
        {
            return new holder(held);
        }

    public: // representation

        ValueType held;

    }



protected: // representation
    placeholder * mContent;

    ValueType * any_cast(Any *);


public: 

    
    /*ValueType opCall()
    {
        if (!mContent) 
        {
            assert(0, "Bad cast from uninitialised Any");
        }
        else if(getType() == typeid(ValueType))
        {
            return (cast(Any.holder!ValueType)(mContent)).held;
        }
        else
        {
            assert(0, "Bad cast from type");
        }
    }*/

    ValueType get()
    {
        if (!mContent) 
        {
            assert(0, "Bad cast from uninitialised Any");
        }
        else if(getType() == typeid(ValueType))
        {
            return (cast(Any.holder!ValueType)(mContent)).held;
        }
        else
        {
            assert(0, "Bad cast from type");
        }
    }

}

unittest
{
    struct Test { int i;}
    Test i;
    Any any = new Any(i);

}+/