module ogre.general.atomicwrappers;

import core.atomic;
import core.sync.mutex;

/** \addtogroup Core
*  @{
*/
/** \addtogroup General
*  @{
*/

struct AtomicScalar(T) {
    
    this (T initial)
    {
        mField = initial;
        //mField = new T();
        //*mField = initial;
    }
    
    this (AtomicScalar!T cousin)
    {
        mField = cousin.mField;
        //mField = new T();
        //*mField = cousin.mField;
    }
    
    //this (){ }
    
    void opAssign (AtomicScalar!T cousin)
    {
        set(cousin.mField);
    }
    
    T get ()
    {
        // no lock required here
        // since get will not interfere with set or cas
        // we may get a stale value, but this is ok
        return mField;
        //return atomicLoad(mField);
    }
    
    void set (T v)
    {
        atomicStore(mField, v);
        //atomicStore(*mField, v);
    }
    
    bool cas (T old,T nu)
    {
        return core.atomic.cas(&mField, old, nu);
    }
    
    T opUnary (string op)()
    {
        if (op == "++")
            return opAddAssign(cast(T)1);
        else if (op == "--")
            return opSubAssign(cast(T)1);
    }
    
    T opBinary (string op)(int i)
    {
        return mixin(`atomicOp!"`~ op ~ `"(mField, i)`);
    }
    
    T opAddAssign(T add)
    {
        return atomicOp!"+="(mField, add);
    }
    
    T opSubAssign(T sub)
    {
        return atomicOp!"-="(mField, sub);
    }
    
    protected:
        //volatile 
        shared T mField;
    
    // Use heap memory to ensure an optimizing
    // compiler doesn't put things in registers.
    //T *mField = new T();
    // but pointer stuff is used with atomicFence() ?
}

//class 
struct AtomicScalarWithMutex(T) {

public:

    this (T initial)
    {
        mLock = new Mutex;
        mField = initial;
    }

    this (AtomicScalar!T cousin)
    {
        mLock = new Mutex;
        mField = cousin.mField;
    }

    //this (){ }

    void opAssign (AtomicScalar!T cousin)
    {
        synchronized(mLock)
        {
            mField = cousin.mField;
        }
    }
    
    T get ()
    {
        // no lock required here
        // since get will not interfere with set or cas
        // we may get a stale value, but this is ok
        return mField;
    }
    
    void set (T v)
    {
        synchronized(mLock)
        {
            mField = v;
        }
    }
    
    bool cas (T old,T nu)
    {
        synchronized(mLock)
        {
            if (mField != old) return false;
                mField = nu;
            return true;
        }
    }
    
    T opUnary (string op)()
    {
        if(op == "++")
        {
            synchronized(mLock)
                return ++mField;
        }
        else if(op == "--")
        {
            synchronized(mLock)
                return --mField;
        }
    }
    
    T opUnary (string op)(int)
    {
        if(op == "++")
        {
            synchronized(mLock)
                return ++mField;
        }
        else if(op == "--")
        {
            synchronized(mLock)
                return --mField;
        }
    }
    
    T opAddAssign(T add)
    {
        synchronized(mLock)
        {
            mField += add;
            return mField;
        }
    }
    
    T opSubAssign(T sub)
    {
        synchronized(mLock)
        {
            mField -= sub;
            return mField;
        }
    }

protected:
    
    Mutex mLock;
    //volatile 
    T mField;

    invariant()
    {
        assert(mLock !is null);
    }
}
/** @} */
/** @} */