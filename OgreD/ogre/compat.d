module ogre.compat;
//import core.stdc.config : c_long, c_ulong;

///  NOTES
//  Breaking modules into multiple files: http://prowiki.org/wiki4d/wiki.cgi?LanguageDevel/DIPs/DIP16
//  
//  https://github.com/rejectedsoftware/vibe.d/blob/master/source/vibe/utils/memory.d
//  So 'ref'-ing is slow? http://stackoverflow.com/questions/5142366/how-fast-is-d-compared-to-c
//
//  "in" is faster in your case cause you are using dynamic arrays which are reference types. 
//  With ref you introduce another level of indirection (which is normally used to alter the array itself and not only the contents).
//  Vectors are usually implemented with structs where ref makes perfect sense.
//
//  ^ So Object -> no ref, struct -> ref?
//
//  -O -inline -release -noboundscheck

import std.container;
import std.algorithm;
import std.ascii;
import std.range;
import core.sync.mutex;
import core.thread;
import std.stdint;
import std.variant;
import ogre.hash;
import std.string : toStringz;

alias ulong uint64;
alias uint uint32;
alias ushort uint16;
alias ubyte uint8;

version(OGRE_REAL_PRECISION) //>=128b
    alias real Real;
else version(OGRE_DOUBLE_PRECISION) //64b
    alias double Real;
else
    alias float Real; //32b

//alias RedBlackTree Set; //But is a class, so it needs a 'new' somewhere...
//alias Array List;
//FIXME Fits as a substitute for std::hash?
alias MersennePrimeHash _StringHash;
alias size_t time_t;
//alias Array!string StringVector;
alias string[] StringVector;
alias Mutex OGRE_AUTO_MUTEX;
alias Variant Any;
//alias Thread OGRE_THREAD_TYPE;

/// string to stringz to be passed to C functions.
/// String literals have \0 appended already though and can be cast directly to char*
char* CSTR(string str)
{
    return cast(char*)std.string.toStringz(str);
}

/// std::pair
struct pair(T, V) //FIXME Can't deduce parameters by itself
{
    T first;
    V second;
}

alias pair!(string,string) StringPair;

// Does core.thread.Thread have a getID?
/// Return pointer address of the thread as id
ulong OGRE_THREAD_CURRENT_ID()
{
    auto t = Thread.getThis();
    ulong id = cast(ulong)&t; //TLS
    return id;
}

/// Init multi map AA at k with v if there is no k in aa
void initAA(AA, K, V)(ref AA aa, K k, V v)
{
    if((k in aa) is null)
        aa[k] = v;
}

/// Init multi map AA at k with null if there is no k in aa
void initAA(AA, K)(ref AA aa, K k)
{
    if((k in aa) is null)
        aa[k] = null;
}

/**
auto arr = new Array!A(A.init);

Array!string*[int] StrInt;

StrInt[8] = new Array!string([string.init]);
(*StrInt[8]).clear();

(*StrInt[8]).insert("lol");
writeln((*StrInt[8])[]-);
writeln( (*(*(8 in StrInt)))[] );

*/

/**
 * 
 * Array helper functions
 * 
 * */


bool inArray(T)(ref T[] array, T n)
{
    return !std.algorithm.find(array, n).empty;
}

bool inArray(T)(ref Array!T range, T n)
{
    return !std.algorithm.find(range[], n).empty;
}


/// Concatenate item to array
void insert(T)(ref T[] array, T value)
{
    array ~= value;
}

void insert(T)(ref T[] array, T[] value)
{
    array ~= value;
}

size_t count(T)(ref T[] array, T value)
{
    size_t count = 0;
    foreach(i; array)
        if(i == value)
            count ++;
    return count;
}


///Add before index
//Also arr.insertBeforeIdx(arr.length, 25); adds 25 at the end
void insertBeforeIdx(T)(ref T[] array, size_t idx, T value)
{
    assert(idx <= array.length, "Index is beyond array bounds.");

    array.length ++;
    foreach_reverse(i; idx .. array.length-1) //Move stuff further back
        array[i+1] = array[i];
    //array[idx+1..$] = array[idx..$-1].dup;
    
    array[idx] = value;
}

void insertBeforeIdx(T)(ref T[] array, size_t idx, T[] values)
{
    assert(idx <= array.length, "Index is beyond array bounds.");
    
    if(idx == 0) //special cases
    {
        array = values ~ array;//TODO Maybe dup values
    }
    else if(idx == array.length)
    {
        array ~= values;
    }
    else
    {
        T[] tmp = array[idx..$];
        //array.length += values.length;
        array.length = idx;

        array ~= values;
        array ~= tmp;
    }
}

//Mainly because getWorldTransforms()s
void insertOrReplace(T)(ref T[] arr, T item)
{
    if(arr.length)
        arr[0] = item;
    else
        arr ~= item;
}

void insertOrReplace(T)(ref T[] arr, T[] items)
{
    if(arr.length)
    {
        size_t i;
        if(arr.length < items.length)
        {
            for(i=0; i < arr.length; i++)
                arr[i] = items[i];

            arr ~= items[i..$];
        }
        else
        {
            for(i=0; i < items.length; i++)
                arr[i] = items[i];
        }
    }
    else
        arr ~= items;
}

///Remove item from array
void removeFromArray(T)(ref T[] array, T item)
{
    foreach( i; 0 .. array.length )
    if( array[i] is item ){
        removeFromArrayIdx(array, i);
        return;
    }
}

void removeFromArray(T)(ref shared(T[]) array, shared(T) item)
{
    foreach( i; 0 .. array.length )
    if( array[i] is item ){
        removeFromArrayIdx(array, i);
        return;
    }
}
///Remove array of items from array
void removeFromArray(T)(ref T[] array, T[] items)
{
    foreach( i; items)
        removeFromArray(forward!array, i);
}

///Remove item from array based on item's pointer
void removeFromArray(T)(ref T[] array, T* item)
{
    foreach( i; 0 .. array.length )
    if( &array[i] == item ){
        removeFromArrayIdx(array, i);
        return;
    }
}

unittest
{
    //mesh.d
    struct Weight
    {
        Real weight;
        int x;
    }
    Weight[][int] assignments;
    assignments[0] = [Weight(90f, 4), Weight(0.66f, 3),Weight(1.23f, 8),Weight(0.5f, 40),Weight(5f, 14)];
    size_t numToRemove = 2;
    
    Weight*[Real] weights;
    //can't foreach because pointer would be to a temporary
    for(size_t i=0; i < assignments[0].length; i++)
        weights[assignments[0][i].weight] = &assignments[0][i];
    
    auto keys = std.algorithm.sort(weights.keys);
    foreach(k; keys[0..numToRemove])
    {
        assignments[0].removeFromArray(weights[k]);
    }

    assert(assignments[0] == [Weight(90f, 4),Weight(1.23f, 8),Weight(5f, 14)]);
}

///Remove item at idx from array
void removeFromArrayIdx(T)(ref T[] array, size_t idx)
{
    foreach( j; idx+1 .. array.length)
        array[j-1] = array[j];
    array.length--;
}

///Remove item at idx from array
void removeFromArrayIdx(T)(ref shared(T[]) array, size_t idx)
{
    foreach( j; idx+1 .. array.length)
        array[j-1] = array[j];
    array.length--;
}

/**Remove range from array
    @param sidx 
        Start index
    @param eidx 
        End index, exclusive
*/
void removeFromArrayIdx(T)(ref T[] array, size_t sidx, size_t eidx)
{
    if(sidx==eidx) return;
    assert(sidx < eidx, "sidx < eidx");
    foreach( j; eidx .. array.length)
        array[sidx + (j - eidx)] = array[j];
    array.length -= (eidx-sidx);
}

/// Stuff for AssociativeArrays
//https://github.com/rejectedsoftware/vibe.d/blob/master/source/vibe/http/server.d#L832
/// From link: NOTE: AA.length is very slow so this helper function is used to determine if an AA is empty.
static bool emptyAA(AA)(AA aa) @property
{
    foreach( _; aa ) return false;
    return true;
}

//AssocArray linking problems. 
// compat.o probably needs to be linked as last too...or first. Depends if it's full moon tonight
@property
auto lengthAA(AA)(AA aa)
{
    //fake it til you make it
    //size_t i=0;
    //foreach(k,v; aa)
    //    i++;
    //return i;
    return aa.length();
}

@property
void lengthAA(AA, T)(AA aa, T l)
{
    aa.length(l);
}

@property
auto keysAA(AA)(AA aa)
{
    return aa.keys;
    //return __traits(getMember, aa, "keys");// errors on linking too
}

/// Convert function to delegate.
/** Mind the delegate memory layout! */
struct DG {
    Object instance;
    void* fn;
}

/// Loop through string and return index to first occured element
ptrdiff_t find_first_of(string str, string elems)
{
    ptrdiff_t pos = -1;
    foreach(el; elems)
    {
        ptrdiff_t p = std.string.indexOf(str, el);
        if(p > -1)
        {
            if(pos == -1) pos = p;
            else pos = std.algorithm.min(pos, p);
        }
    }
    return pos;
}

bool isDigits(string str)
{
    foreach(s; str)
        if(!isDigit(s))
            return false;
    return true;
}

/** Convert function into delegate with proper Object instance.
    std.functional.toDelegate doesn't seem to do the same thing.
*/
//Used in ogre.rendersystem
D toDelegate(D, F)(Object obj, F fn)
{
    DG dg;// = new DG;
    dg.instance = obj;
    dg.fn = cast(void*)fn;
    
    D real_dg = *(cast(D*) cast(void*)&dg);
    return real_dg;
}

unittest
{
    alias int function(int) MethodF;
    alias int delegate(int) MethodD;
    
    class C
    {
        int x;
        int someFunc(int i) { return x+i;}
    }
    
    C c = new C;
    c.x = 1234;
    MethodF fn = &C.someFunc; //Don't call fn directly or you seg. fault duh
    MethodD dg = toDelegate!MethodD(c, fn);
    
    assert( dg(4321) == 5555 );
}



/** 
    ldc2, dmd >2.062 chock on these templates randomly :(
*/

/**
    Assoc. array whose keys are sorted in opApply aka foreach.
*/
/*struct SortedMap(K,V)
{
    V[K] arr;
    
    void remove(K key)
    {
        arr.remove(key);
    }

    @property
    auto keys()
    {
        return sort(arr.keys);
    }

    @property
    size_t length()
    {
        return arr.length;
    }

    bool hasKey(K key)
    {
        return (key in arr) !is null;
    }

    //int opApply ( int delegate ( ref int x ) dg )
    int opApply ( scope int delegate(ref K key, ref V val) dg)
    {
        int res = 0;
        auto sorted = sort(arr.keys);
        foreach(sk; sorted) {
            res = dg(sk, arr[sk]);
            if (res) break;
        }
        return res;
    }

    int opApplyReverse ( scope int delegate(ref K key, ref V val) dg)
    {
        int res = 0;
        auto sorted = sort(arr.keys);
        foreach_reverse(sk; sorted) {
            res = dg(sk, arr[sk]);
            if (res) break;
        }
        return res;
    }

    V opIndexAssign(V val, K key)
    {
        return arr[key] = val;
    }

    ref V opIndex(K key)
    {
        return arr[key];
    }
}*/

/**
    Assoc. array with another Array to keep track of insertion order.
    @note Use opIndex for ordered foreach.
*/
/*struct OrderedMap(K,V)
{
    V[K] hashmap;
    Array!K keys;
    
    @property size_t length()
    {
        return keys.length;
    }
    
    int opApply ( scope int delegate(ref K key, ref V value) dg)
    {
        int res = 0;
        foreach(k,v; hashmap) {
            res = dg(k, v);
            if (res) break;
        }
        return res;
    }
    
    int opApplyReverse ( scope int delegate(ref K key, ref V value) dg)
    {
        int res = 0;
        foreach_reverse(k,v; hashmap) {
            res = dg(k, v);
            if (res) break;
        }
        return res;
    }
    
    bool _hasKey(K index)
    {
        return !std.algorithm.find(keys[], index).empty();
    }
    
    / ** If key exists, returns pointer to the element. * /
    V* hasKey(K key)
    {
        auto ptr = key in hashmap;
        //assert(ptr !is null, "No such key: " ~ std.conv.to!string(key));
        return ptr;
    }
    
    V opIndexAssign(V val, K index)
    {
        if(!_hasKey(index)) keys.insertBack(index);
        return hashmap[index] = val;
    }
    
    V opIndex(K idx)
    {
        return hashmap[idx];
    }
    
    / *V opIndex(size_t idx)
    {
        return hashmap[keys[idx]];
    }* /
    
    void remove(K key)
    {
        hashmap.remove(key);
        keys.linearRemove(keys[].find(key).takeOne);
    }
    
    V removeAt(size_t idx)
    {
        V v = hashmap[keys[idx]];
        this.remove(keys[idx]);
        return v;
    }
    
    unittest
    {
        import std.stdio;
        OrderedMap!(string, int) om;
        om["E"] = 10;
        om["A"] = 20;
        om["C"] = 30;
        om["B"] = 40;
        om["D"] = 50;
        foreach(k,v; om)
            writeln(k, " = ", v); //Probably DEABC

        foreach(k; 0 .. om.length)
            writeln(om.keys[k], " = ", om[k]); //EACBD
        om.removeAt(2);
        assert(std.algorithm.equal(om.keys[], ["E", "A", "B", "D"]));
    }
}*/

/* struct MultiMap(K, V, alias less = "a < b")
{
    //Array!(V)*[K] hashmap;
    V[][K] hashmap;
    
    @property size_t length()
    {
        return hashmap.length;
    }

    @property
    K[] keys()
    {
        return hashmap.keys;
    }

    /// foreach iterates through Array too. 
    int opApply ( scope int delegate(ref K key, ref V value) dg)
    {
        int res = 0;
        //std::multimap sorts its keys
        auto keys = std.algorithm.sort!less(hashmap.keys);
        //foreach(k,v; hashmap) {
        foreach(k; keys) {
            foreach(vv; hashmap[k]) {
                res = dg(k, vv);
                if (res) break;
            }
            if (res) break;
        }
        return res;
    }
    
    /// foreach_reverse iterates through Array too.
    int opApplyReverse ( scope int delegate(ref K key, ref V value) dg)
    {
        int res = 0;
        auto keys = std.algorithm.sort!less(hashmap.keys);
        //foreach(k,v; hashmap) {
        foreach_reverse(k; keys) {
            foreach_reverse(vv; hashmap[k]) {
                res = dg(k, vv);
                if (res) break;
            }
            if (res) break;
        }
        return res;
    }
    
    bool hasKey(K key)
    {
        return (key in hashmap) !is null;
    }
    
    //Array!V* getVal(K key)
    V[]* getVal(K key)
    {
        auto ptr = key in hashmap;
        //assert(ptr !is null, "No such key: " ~ std.conv.to!string(key));
        if(ptr is null) return null;
        return ptr;
    }
    
    //Array!V opIndexAssign(V val, K key)
    V opIndexAssign(V val, K key)
    {
        if(!hasKey(key))
        {
            hashmap[key] = null;//= new Array!V([V.init]);//Compiler bug?
            //destroy(hashmap[key]); // assert: null this
            //hashmap[key].clear();
        }
        
        hashmap[key].insert(val);
        
        return hashmap[key].back;
    }
    
    //Array!V opIndex(K idx)
    ref V[] opIndex(K idx)
    {
        return hashmap[idx];
    }
    
    V opIndex(K key, size_t idx)
    {
        return hashmap[key][idx];
    }
    
    void remove(K key)
    {
        hashmap.remove(key);
    }

    void removeFromArrayIdx(K key, size_t idx)
    {
        //Array!V* arr = hashmap[key];
        //(*arr).linearRemove((*arr)[idx..idx+1]);
        hashmap[key].removeFromArrayIdx(idx);
    }

    unittest
    {
        import std.algorithm;
        MultiMap!(string, int) mm;
        
        mm["fives"] = 5;
        mm["fives"] = 15;
        mm["fives"] = 45;
        mm["threes"] = 3;
        mm["threes"] = 43;
        mm["threes"] = 63;
        mm["threes"] = 13;
        
        //mm["threes"].linearRemove(mm["threes"][2..3]);
        mm["threes"].removeFromArray(mm["threes"][2..3]);
        
        //assert(mm.getVal("threes").empty == false);
        assert(mm.getVal("muffin") is null);
        assert(std.algorithm.equal(mm["threes"][], [3, 43, 13]));
        assert(mm["fives"][2] == 45);
        
        /* foreach(k,v; mm)
        {
            writeln(k , ",", v);
        }* /

    }
}*/

/**
 * A bitset is a special container class that is designed to store bits 
 * (elements with only two possible values: 0 or 1, true or false, ...).
 * Sort of like std::bitset.
 * */
//care about endianness? Otherwise bits are from left to right
struct Bitset(size_t _size)
        //(Args...) if (Args.length == 1) // in case of compiler bug, use Args
{
private:
    alias uint inner_type;
    /// sizeof in bits
    size_t inner_type_sizeof = inner_type.sizeof * 8;
    //keep size atleast 1
    inner_type[(_size / (inner_type.sizeof * 8)) + 1] mBits;
    /// bit count
    size_t mSize = _size; //Args[0];
    
public:

    // If using template arguments then no need for ctor
    /*this( size_t size)
    {
        //mBits.length = size;
        mBits = new inner_type[ (size / inner_type_sizeof) + 1];
        mSize = size;
    }*/
    
    /// How many bits we hold
    size_t size()
    {
        return mSize; //mBits.length * inner_type.sizeof;
    }

    /// How many bits we hold
    @property size_t length()
    {
        return mSize;
    }
    
    /// Are any bits set?
    @property
    bool any()
    {
        foreach(i; mBits)
            if(i) return true;
        return false;
    }

    @property
    bool none()
    {
        return !any();
    }
    
    // may count trailing bits
    @property
    size_t count()
    {
        size_t c = 0;
        /*size_t off = 0;
        foreach(i; mBits)
        {
            foreach(j; 0..inner_type_sizeof)
            {
                if( i & (1<<j) ) c++;
                off++;
                if(off >= mSize) return c;
            }
        }*/

        foreach(i; 0..mSize)
            if(test(i)) c++;

        return c;
    }
    
    void set(size_t pos, bool val = true)
    {
        assert(pos < mSize, "out of range");
        size_t div = pos / inner_type_sizeof;
        
        if(val)
            mBits[ div ] |= 1 << (pos % inner_type_sizeof); //(pos - div*inner_type_sizeof); 
        else
            mBits[ div ] &= mBits[ div ] ^ (1 << (pos % inner_type_sizeof)); //(pos - div*inner_type_sizeof));
    }
    
    void reset(size_t pos)
    {
        set(pos, false);
    }
    
    void reset()
    {
        foreach(i; 0..mBits.length)
            mBits[i] = 0;
    }
    
    void flip()
    {
        foreach(i; 0..mBits.length)
            mBits[i] = ~mBits[i];
    }

    void flip(size_t pos)
    {
        assert(pos < mSize, "out of range");
        size_t div = pos / inner_type_sizeof;
        mBits[ div ] ^= (1 << (pos % inner_type_sizeof));
    }
    
    bool test(size_t pos)
    {
        assert(pos < mSize, "out of range");
        size_t div = pos / inner_type_sizeof;
        return (mBits[ div ] & (1 << (pos % inner_type_sizeof))) != 0;
    }
    
    bool opIndex(size_t pos)
    {
        return test(pos);
    }
    
    //override 
    //string toString()
    string asString()
    {
        string str;
        size_t off = 0;
        foreach(i; mBits)
        {
            foreach(j; 0..inner_type_sizeof)
            {
                if(i & (1<<j))
                    str ~= "1";
                else
                    str ~= "0";
                
                off++;
                if(off >= mSize) return str;
            }
        }
        //str.length = mSize;
        return str;
    }

    //ulong to_ulong();//uh

    /// Get inner container for bits
    inner_type[] getBits()
    {
        return mBits;
    }

    unittest
    {
        {
            Bitset!32 b;
            b.set(3);
            b.flip(7);
            b.set(7, false);
            b.set(15);
            assert(b.any());
            assert(b.count() == 2);
            assert(b.asString() == "00010000000000010000000000000000");
        }

    }
}
