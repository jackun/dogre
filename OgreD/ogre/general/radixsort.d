module ogre.general.radixsort;

private
{
    import core.stdc.string : memset;
    import std.container;
    import std.range;
    
    import std.stdio : writeln;
    import std.range : repeat;
    import std.algorithm : equal;
}

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */
    
/** Class for performing a radix sort (fast comparison-less sort based on 
        byte value) on various standard STL containers. (Still fast in D?)
    @remarks
        A radix sort is a very fast sort algorithm. It doesn't use comparisons
        and thus is able to break the theoretical minimum O(N*logN) complexity. 
        Radix sort is complexity O(k*N), where k is a constant. Note that radix
        sorting is not in-place, it requires additional storage, so it trades
        memory for speed. The overhead of copying means that it is only faster
        for fairly large datasets, so you are advised to only use it for collections
        of at least a few hundred items.
    @par
        This is a template class to allow it to deal with a variety of containers, 
        and a variety of value types to sort on. In addition to providing the
        container and value type on construction, you also need to supply a 
        functor object which will retrieve the value to compare on for each item
        in the list. For example, if you had an std::vector of by-value instances
        of an object of class 'Bibble', and you wanted to sort on 
        Bibble::getDoobrie(), you'd have to firstly create a functor
        like this:
    @code
        struct BibbleSortFunctor
        {
            float opCall()(Bibble val)
            {
                return val.getDoobrie();
            }
        }
    @endcode
        Then, you need to declare a RadixSort class which names the container type, 
        the value type in the container, and the type of the value you want to 
        sort by. You can then call the sort function. E.g.
    @code
        RadixSort<BibbleList, Bibble, float> radixSorter;
        BibbleSortFunctor functor;

        radixSorter.sort(myBibbleList, functor);
    @endcode
        You should try to reuse RadixSort instances, since repeated allocation of the 
        internal storage is then avoided.
    @note
        Radix sorting is often associated with just unsigned integer values. Our
        implementation can handle both unsigned and signed integers, as well as
        floats (which are often not supported by other radix sorters). doubles
        are not supported; you will need to implement your functor object to convert
        to float if you wish to use this sort routine.
     @note
        Native D arrays and atleast std.container.Array should work.
        Well, as long as it supports indexing.
    */

class RadixSort(TContainer, TContainerValueType, TCompValueType)
{
public:
    //typedef typename TContainer::iterator ContainerIter;
    alias TContainerValueType ContainerIter; //Just an index to array element
protected:
    /// Alpha-pass counters of values (histogram)
    /// 4 of them so we can radix sort a maximum of a 32bit value
    int[256][4] mCounters;// Hm, row/col ordering, mCounters[0] returns int[256]
    /// Beta-pass offsets 
    int[256] mOffsets;
    /// Sort area size
    int mSortSize;
    /// Number of passes for this type
    int mNumPasses;
    
    struct SortEntry
    {
        TCompValueType key;
        ContainerIter iter; //TODO Try to reference and not copy (???)
        
        //hm, native arrays use ref
        this(ref TCompValueType k, ref ContainerIter it)
        {
            key = k; iter = it;
        }
        //butobjects don't "ref"
        this(TCompValueType k, ContainerIter it)
        {
            key = k; iter = it;
        }
    }
    
    /// Temp sort storage
    //typedef std::vector<SortEntry, STLAllocator<SortEntry, GeneralAllocPolicy> > SortVector; 
    //alias Array!SortEntry SortVector; 
    alias SortEntry[] SortVector; 
    SortVector mSortArea1;
    SortVector mSortArea2;
    SortVector *mSrc;
    SortVector *mDest;
    TContainer mTmpContainer; // initial copy
    
    
    void sortPass(int byteIndex)
    {
        // Calculate offsets
        // Basically this just leaves gaps for duplicate entries to fill
        mOffsets[0] = 0;
        for (int i = 1; i < 256; ++i)
        {
            mOffsets[i] = mOffsets[i-1] + mCounters[byteIndex][i-1];
        }
        
        // Sort pass
        for (int i = 0; i < mSortSize; ++i)
        {
            ubyte byteVal = getByte(byteIndex, (*mSrc)[i].key);
            (*mDest)[mOffsets[byteVal]++] = (*mSrc)[i];
        }
        
    }
    
    void finalPass(T)(int byteIndex, T val) //if(!is(T == int) && !is(T == float)) // idontknow
    {
        static if(is(T == int))
            finalPassI(byteIndex, val);
        static if(is(T == float))
            finalPassF(byteIndex, val);
        else
            // default is to do normal pass
            sortPass(byteIndex);
    }
    
    // special case signed int
    void finalPassI(int byteIndex, int val)
    {
        int numNeg = 0;
        // all negative values are in entries 128+ in most significant byte
        for (int i = 128; i < 256; ++i)
        {
            numNeg += mCounters[byteIndex][i];
        }
        // Calculate offsets - positive ones start at the number of negatives
        // do positive numbers
        mOffsets[0] = numNeg;
        for (int i = 1; i < 128; ++i)
        {
            mOffsets[i] = mOffsets[i-1] + mCounters[byteIndex][i-1];
        }
        // Do negative numbers (must start at zero)
        // No need to invert ordering, already correct (-1 is highest number)
        mOffsets[128] = 0;
        for (int i = 129; i < 256; ++i)
        {
            mOffsets[i] = mOffsets[i-1] + mCounters[byteIndex][i-1];
        }
        
        // Sort pass
        for (int i = 0; i < mSortSize; ++i)
        {
            ubyte byteVal = getByte(byteIndex, (*mSrc)[i].key);
            (*mDest)[mOffsets[byteVal]++] = (*mSrc)[i];
        }
    }
    
    
    // special case float
    void finalPassF(int byteIndex, float val) 
    {
        // floats need to be special cased since negative numbers will come
        // after positives (high bit = sign) and will be in reverse order
        // (no ones-complement of the +ve value)
        int numNeg = 0;
        // all negative values are in entries 128+ in most significant byte
        for (int i = 128; i < 256; ++i)
        {
            numNeg += mCounters[byteIndex][i];
        }
        // Calculate offsets - positive ones start at the number of negatives
        // do positive numbers normally
        mOffsets[0] = numNeg;
        for (int i = 1; i < 128; ++i)
        {
            mOffsets[i] = mOffsets[i-1] + mCounters[byteIndex][i-1];
        }
        // Do negative numbers (must start at zero)
        // Also need to invert ordering
        // In order to preserve the stability of the sort (essential since
        // we rely on previous bytes already being sorted) we have to count
        // backwards in our offsets from 
        mOffsets[255] = mCounters[byteIndex][255];
        for (int i = 254; i > 127; --i)
        {
            mOffsets[i] = mOffsets[i+1] + mCounters[byteIndex][i];
        }
        
        // Sort pass
        for (int i = 0; i < mSortSize; ++i)
        {
            ubyte byteVal = getByte(byteIndex, (*mSrc)[i].key);
            if (byteVal > 127)
            {
                // -ve; pre-decrement since offsets set to count
                (*mDest)[--mOffsets[byteVal]] = (*mSrc)[i];
            }
            else
            {
                // +ve
                (*mDest)[mOffsets[byteVal]++] = (*mSrc)[i];
            }
        }
    }
    
    ubyte getByte(int byteIndex, TCompValueType val)
    {
        version(LittleEndian)
            return (cast(ubyte*)(&val))[byteIndex];
        else
            return (cast(ubyte*)(&val))[mNumPasses - byteIndex - 1];
    }
    
public:
    
    this() {}
    ~this() {}
    
    /** Main sort function
        @param container A container of the type you declared when declaring
        @param func A functor which returns the value for comparison when given
            a container value
        */
    void sort(TFunction)(ref TContainer container, TFunction func)
    {
        if (container.empty())
            return;
        
        // Set up the sort areas
        mSortSize = cast(int)(container.length);
        mSortArea1.clear();
        mSortArea2.clear();
        mSortArea1.length = container.length;
        mSortArea2.length = container.length;

        //mSortArea1.insert(repeat(SortEntry.init, container.length));
        //mSortArea2.insert(repeat(SortEntry.init, container.length));
        
        // Copy data now (we need constant iterators for sorting)
        //mTmpContainer = container;
        mTmpContainer = container;//.dup; //TODO no need to dup?
        
        mNumPasses = TCompValueType.sizeof;
        
        // Counter pass
        // Initialise the counts
        foreach (p; 0..mNumPasses)
            memset(mCounters[p].ptr, 0, int.sizeof * 256);
        
        // Perform alpha pass to count
        //ContainerIter i = mTmpContainer.begin();
        TCompValueType prevValue = func(mTmpContainer[0]); 
        bool needsSorting = false;
        for (int i = 0; i < mTmpContainer.length; ++i)
        {
            // get sort value
            TCompValueType val = func(mTmpContainer[i]);
            // cheap check to see if needs sorting (temporal coherence)
            if (!needsSorting && val < prevValue)
                needsSorting = true;

            // Create a sort entry
            //mSortArea1[u].key = val;
            //mSortArea1[u].iter = mTmpContainer[i]; //hm, SortEntry gets post-blitted (or whatever you cal it) back to zero
            auto v = mTmpContainer[i]; // Get element from std.container.Array. If container is native array then there's no need to.
            mSortArea1[i] = SortEntry(val, v); //XXX v gets ref fed now.
            //mSortArea1[u] = SortEntry(val, mTmpContainer[i]); //TODO by value? std.container.Array
            
            // increase counters
            foreach (p; 0..mNumPasses)
            {
                ubyte byteVal = getByte(p, val);
                mCounters[p][byteVal]++;
            }
            
            prevValue = val;
            
        }
        
        // early exit if already sorted
        if (!needsSorting)
            return;
        
        
        // Sort passes
        mSrc = &mSortArea1;
        mDest = &mSortArea2;
        
        foreach (p; 0..mNumPasses - 1)
        {
            sortPass(p);
            // flip src/dst
            SortVector* tmp = mSrc;
            mSrc = mDest;
            mDest = tmp;
            //std.algorithm.swap(mSrc, mDest);
        }
        
        // Final pass may differ, make polymorphic
        finalPass(mNumPasses-1, prevValue);
        
        // Copy everything back
        //int c = 0;
        foreach (i; 0..container.length)
        {
            //container[i] = *((*mDest)[c].iter);
            container[i] = (*mDest)[i].iter;
        }
        
    }
    
}

/** @} */
/** @} */

unittest
{
    
    struct RadixSortFunctorInt
    {
        int mod = 3;
        int opCall(int p)
        {
            return p % mod;
        }
        this(int m)
        {
            mod = m;
        }
    }
    
    struct RadixSortFunctorFloat
    {
        float opCall(float p)
        {
            return p;
        }
    }
    
    class Test
    {
        int X;
        this(int x)
        {
            X = x;
        }
        
        override string toString()
        {
            return std.conv.text("Test(", X, ")");
        }
    }
    
    struct RadixSortFunctorTest
    {
        int opCall(Test p)
        {
            return p.X;
        }
    }
    
    int sortTest(Test p)
    {
        return p.X;
    }
    
    {
        auto arr = [4,3,8,9,3,7,5,0];
        
        arr ~= repeat(7,5).array;
        //writeln(arr);
        auto radix = new RadixSort!(int[], int, int);
        auto s = RadixSortFunctorInt(3);
        radix.sort(arr, s); //Pass struct so you can specify more members and do more advanced calculations in opCall.
        //writeln("Ints: ",arr);
        //assert(equal(arr[], [0, 3, 3, 4, 5, 7, 7, 7, 7, 7, 7, 8, 9]));
        assert(equal(arr, [3, 9, 3, 0, 4, 7, 7, 7, 7, 7, 7, 8, 5])); //Sorted by modulo 3
    }
    
    {
        auto arr = [4f,3f,8f,9f,3f,7f,5f,0f];
        
        arr ~= repeat(7f, 5).array;
        //writeln(arr);
        auto radix = new RadixSort!(float[], float, float);
        RadixSortFunctorFloat s;
        radix.sort(arr, s);
        //writeln("Floats:", arr);
        assert(equal(arr, [0f, 3f, 3f, 4f, 5f, 7f, 7f, 7f, 7f, 7f, 7f, 8f, 9f]));
    }
    
    {
        auto arr = [new Test(4),new Test(3),new Test(8),new Test(9),new Test(3),new Test(7),new Test(5),new Test(0)];
        auto correct = [0, 3, 3, 4, 5, 7, 8, 9];
        auto radix = new RadixSort!(Test[], Test, int);
        
        radix.sort(arr, &sortTest); //Pass simple function
        //writeln("Test: ",arr);
        foreach(i; 0 .. arr.length)
            assert( correct[i] == arr[i].X );
    }
}