module ogre.hash;

import std.traits;

struct MersennePrimeHash
{
    /// For basic types
    size_t opCall(T)( T t ) const
    if(is(T == int) || is(T == size_t) ||
       is(T == uint) || is(T == long) ||
       is(T == ulong) ||
       is(T == immutable(char)) ||
       is(T == char))
    {
        size_t result = 2166136261;
        ubyte* s = cast(ubyte*)&t;
        
        foreach ( i; 0..t.sizeof)
        {
            result = 127 * result + s[i];
        }
        return result ;
    }

    //for arrays, recursively
    size_t opCall(T)( T s ) const 
    if(isArray!T && !is(T ==void)) // && !is(T: string[]))
    {
        size_t result = 2166136261;
        foreach ( c; s)
        {
            static if(is(typeof(c) == string))
                foreach ( i; c)
            {
                result = 127 * result + cast(ubyte)i;
            }
            else
                result = 127 * result + opCall(c); //TODO totally random multiplier
        }
        return result ;
    }

    /// For structs and classes
    size_t opCall(T)( T t ) const
    if(is(T == class) || is(T == struct))
    {
        size_t result = 0;
        foreach ( i; __traits(allMembers, T))
        {
            // Ignore functions
            static if(!is(typeof(__traits(getMember, t, i)) == function))
                result = 127 * result + opCall(__traits(getMember, t, i)); //TODO totally random multiplier
        }
        return result ;
    }
}

struct FNVHash
{
    size_t opCall(T)( T s ) const if(isArray!T)
    {
        size_t result = 2166136261;
        foreach ( c; s)
        {
            result = (16777619 * result)
                ^ cast(ubyte)(c);
        }
        return result ;
    }
}