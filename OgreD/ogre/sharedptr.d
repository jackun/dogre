module ogre.sharedptr;

import core.memory;
import core.sync.mutex;
debug import std.stdio;
import std.traits;
import ogre.resources.resource;
import ogre.compat;
import core.memory, core.stdc.stdlib;
import std.algorithm, std.conv, std.exception, std.string: indexOf;

///Something: https://github.com/Trass3r/cl4d/blob/master/opencl/wrapper.d

//debug=SHAREDPTRDBG;

/** 
    Basically std.typecons.RefCounted for classes with some casting sprinkled around
    @todo Check if works with GC on.
 */
struct SharedPtr_(T)
{
    /*invariant()
    {
        assert(mLock !is null);
        //assert(pUseCount !is null); //InvalidMem.Op.
    }*/
    ref Mutex mLock() @property
    {
        assert(_refCounted.isInitialized);
        return _refCounted._store._lock;
    }
    struct RefCounted
    {
        private struct Store
        {
            T _payload;
            size_t _count; //Delete at 0, then just return when underflows to gajillon
            //__gshared 
            Mutex _lock;
        }
        
        Store* _store = null;
            
        private void initialize(A...)(A args)
        {
            _store = cast(Store*) enforce(malloc(Store.sizeof));
            static if (hasIndirections!T)
                GC.addRange(&_store._payload, T.sizeof);
            emplace(&_store._payload, args);
            
            //_store = new Store;
            //static if(A.length == 1)
            //    _store._payload = cast(T)args[0];
            //else
            //    _store._payload = _store._payload.init;
            _store._count = 1;
            _store._lock = new Mutex;
        }
        
        /**
            Returns $(D true) if and only if the underlying store has been
            allocated and initialized.
        */
        @property nothrow @safe
        bool isInitialized() const
        {
            return _store !is null;
        }
        
        /**
            Returns underlying reference count if it is allocated and initialized
            (a positive integer), and $(D 0) otherwise.
        */
        @property nothrow @safe
        size_t refCount() const
        {
            return isInitialized ? _store._count : 0;
        }
        
        /**
            Makes sure the payload was properly initialized. Such a
            call is typically inserted before using the payload.
        */
        void ensureInitialized()
        {
            if (!isInitialized) initialize();
        }
    }
    
    
    //Store* _store;
    RefCounted _refCounted;
    
    /// Returns storage implementation struct.
    /*@property nothrow @safe
    ref inout(Store*) store() inout
    {
        return _store;
    }*/
    
    //__gshared int* pUseCount = null;
    //__gshared Mutex mLock;


    /// Public for AliasThis http://dlang.org/class.html#AliasThis
    //__gshared T pRep;

    //FIXME AliasThis is incomplete/kinda buggy and upcasting to derived SharedPtr returns null :/
    //XXX If used, you should cast to T, not to SharedPtr!T or its derivatives
    ///Alias so no need to use get() all the time
    //alias pRep this; 

    /** Constructor, does not initialise the SharedPtr.
     @remarks
     <b>Dangerous!</b> You have to call bind() before using the SharedPtr.
     */
    //static this() { mLock = new Mutex; }

    
    /**
        Constructor that tracks the reference count appropriately. If $(D
        !refCountedIsInitialized), does nothing.
    */
    this(this)
    {
        if (!_refCounted.isInitialized) return;
        ++_refCounted._store._count;
        debug(STDERR) std.stdio.stderr.writeln("this(this)@", _refCounted._store,
                                       " Refcount:", (_refCounted._store !is null? _refCounted._store._count: -1));
    }
    
    
    @property nothrow @safe
    ref inout(T) refCountedPayload() inout
    {
        assert(_refCounted.isInitialized);
        return _refCounted._store._payload;
    }
    
    alias refCountedPayload this;
    
    /**
        Returns a reference to the payload. If (autoInit ==
        RefCountedAutoInitialize.yes), calls $(D
        refCountedEnsureInitialized). Otherwise, just issues $(D
        assert(refCountedIsInitialized)).
    */
    //alias refCountedPayload this;
    
    this(A)(A t)
    {
        //This would be weird if _refCounted._store was not null
        //" Refcount:", (_refCounted._store !is null? _refCounted._store._count: -1));
       
        pragma(msg, A.stringof);
        //pragma(msg, typeof(this));
        //pragma(msg, is(A == typeof(this)));
        
        static if(is(A == typeof(this)))
        {
            //pragma(msg, is(A == typeof(this)));
            //_store = t._store;
            _refCounted = t._refCounted;
            ++_refCounted._store._count;
        }
        // SharedPtr!Resource where payload is derived from (or just is) Resource
        else static if(A.stringof.indexOf("SharedPtr")>-1) //TODO How to prettify?
        {
            //_refCounted.ensureInitialized();
            /*_store._count = t._store._count;
            _store._lock = t._store._lock;
            _store._payload = cast(T)t._store._payload;*/
            
            //FIXME both _stores should keep pointing to the same thing
            _refCounted._store = cast(_refCounted.Store*)t._refCounted._store;
            if(t._refCounted._store._payload !is null)
                assert(_refCounted._store._payload !is null, "Casting failed:" ~ to!string(typeid(t)) );
            ++_refCounted._store._count;
        }
        else
            _refCounted.initialize(cast(T)t);
        
        debug(STDERR) std.stdio.stderr.writeln("this(",typeid(t) ,")@", _refCounted._store);
        //debug(STDERR) std.stdio.stderr.writeln(__FILE__,":",__LINE__,":", typeid(t), 
        //                               " Refcount:", _refCounted._store._count);
    }

    /// Create new SharedPtr for new user and increase use count.
    /*this(typeof(this) rhs)
    {
        //pragma(msg, typeof(t));
        _store = rhs._store;
        ++_store._count;
    }*/
        
    ~this()
    {
        //release();
        if (!_refCounted.isInitialized) return;
        assert(_refCounted._store._count > 0);
        if (--_refCounted._store._count)
        {
            debug stderr.writeln("release@", _refCounted._store, " refcount: ", _refCounted._store._count);
            return;
        }
        // Done, deallocate
        .destroy(_refCounted._store._payload);
        static if (hasIndirections!T)
            GC.removeRange(&_refCounted._store._payload);
        free(_refCounted._store);
        _refCounted._store = null;
    }
    
    /**
        Assignment operators
    */
    void opAssign(typeof(this) rhs)
    {
        debug(STDERR) std.stdio.stderr.writeln("opAssign(this)@", _refCounted._store, " from ", rhs._refCounted._store, ": ",
                                (rhs._refCounted._store is null ? "rhs is null ":""),
                                (rhs._refCounted._store !is null ? rhs._refCounted._store._count : -666)
                                );
        swap(_refCounted._store, rhs._refCounted._store);
        rhs._refCounted._store = null;
        //_refCounted._store = rhs._refCounted._store;
        //++_refCounted._store._count;
    }
    
    static if(!is(T == Resource ))
    /// Ditto
    void opAssign(SharedPtr!Resource rhs) //FIXME ensure _payload of type T is derived class from Resource
    {
        //assert(isInitialized);
        //move(rhs._refCounted._store, _refCounted._store);
        _refCounted.ensureInitialized();
        _refCounted._store._payload = cast(T)rhs._refCounted._store._payload;
        _refCounted._store._lock = rhs._refCounted._store._lock;
        _refCounted._store._count = rhs._refCounted._store._count;
        
        //_refCounted._store = cast(_refCount.Store*)rhs._refCounted._store;
    }
    
    /*int* useCountPointer()
    {
        return pUseCount;
    }*/
    
    size_t useCount()
    {
        //return *pUseCount;
        if(_refCounted.isInitialized) return 0;
        return _refCounted._store._count;
    }
    
    /** not really a pointer*/
    T getPointer()
    {
        //return pRep;
        return get();
    }

    /** C++ automagically redirects calls to pRep
        but in D you need to call get() everytime.
        Alternatively could use 'alias pRep this;'
        but this kills the casting.
     */
    ref T get()
    {
        assert(_refCounted.isInitialized);
        debug if(_refCounted._store._payload is null)
            std.stdio.stderr.writeln("Payload @",_refCounted._store, " is null with refcount ", _refCounted._store._count); //The hell...maybe GC?
        return _refCounted._store._payload;
    }

    const(T) get() const
    {
        assert(_refCounted.isInitialized);
        debug if(_refCounted._store._payload is null)
            std.stdio.stderr.writeln("Payload @",_refCounted._store, " is null with refcount ", _refCounted._store._count); //The hell...maybe GC?
        return _refCounted._store._payload;
    }
    
    ref T getAs()
    {
        return get();
    }

    // Because stuff like *(&mConstantDefs.get()) = namedConstants;
    void copyToPtr(T rep)
    {
        assert(_refCounted.isInitialized);
        static if(is(T == T*))
        {
            *_refCounted._store._payload = *rep;
        }

    }

    /*T* get()
    {
        return &pRep;
    }*/

    bool unique(){ return _refCounted._store._count == 1; }
    
    bool isNull(){ return !_refCounted.isInitialized; }
    
    void setNull()
    {
        if(_refCounted.isInitialized)
        {
            // destroy leaves undefined
            release();
            _refCounted._store = null;
            //pUseCount = null; 
        }
    }

    void bind(T rep)
    {
        //assert(!pRep && !pUseCount);
        assert(_refCounted.isInitialized);
        synchronized(_refCounted._store._lock)
        {
            //pUseCount = new int;
            _refCounted._store._count = 1;
            _refCounted._store._payload = rep;
        }
    }

    /*SharedPtr!T opAssign(T t)
     {
     pRep = t;
     return this;
     }*/

    // class version stuff is commented out
    //override 
    bool opEquals(Object obj)
    {
        if(!_refCounted.isInitialized) return false;
        if(is(typeof(obj) == typeof(_refCounted._store._payload))
           //&& (cast(SharedPtr!T)obj).get() == get()
           )
            return true;//opEquals(cast(SharedPtr!T) obj);
        
        return false;//super.opEquals (obj);
    }

    bool opEquals(SharedPtr!T t)
    {
        return get() == t.get();
    }
    
    //FIXME 
    /*C opCast(C)() const
    {
        C c;
        c.pRep = cast(typeof(c.pRep))pRep;
        c.pUseCount = pUseCount;
        c.mLock = mLock;
        ++(*c.pUs)Count);
        assert(c.pRep !is null, "pRep not a instance of " ~ typeid(C).toString());
        return c;
    }*/
    
    void release()
    {
        if(_refCounted._store is null )
            //|| _refCounted._store._payload is null) //then something is fishy or setNull
        {
            //if(pRep !is null) //is there a change?
            //debug(STDERR) std.stdio.stderr.writeln("WARNING: mLock is null, pRep might not be released ", typeid(this), " @ ", &this, " = ", pRep);
            return; //FIXME probably not inited anyway
        }
        synchronized(_refCounted._store._lock)
        {
            if(--_refCounted._store._count > 0)
            {
                writeln("release@", _refCounted._store, " refcount: ", _refCounted._store._count);
                return;
            }
                
            debug //(SHAREDPTRDBG)
                writeln("Finalized ", typeid(T), "@", _refCounted._store, " ", _refCounted._store._count);
            destroy(_refCounted._store._payload); //Recursive alias declaration ???
            _refCounted._store._payload = null;
            //destroy(pUseCount);
            //pUseCount = null;
            _refCounted._store = null;
            
        }
    }
}

struct SharedPtr(T)
{
    struct RefCounted
    {
        private struct Impl
        {
            T _payload;
            size_t _count;
        }
        Impl _store;
        
        size_t refCount() @property
        {
            return 1;
        }
    }
    
    RefCounted _refCounted;
    T pRep;
    alias pRep this;
    
    this(A)(A t)
    {
        static if(is(A == typeof(this)))
        {
            pRep = t.pRep;
        }
        // SharedPtr!Resource where payload is derived from (or just is) Resource
        else static if(A.stringof.indexOf("SharedPtr")>-1) //TODO How to prettify?
        {
            pRep = cast(T)t.pRep;
        }
        else
            pRep = cast(T)t;
            
       //_refCounted._store._payload = pRep;
    }
    
    /*~this()
    {
        pRep = null;
    }*/
    
    bool isNull(){ return pRep is null; }
    void setNull(){ pRep = null; }
    ref T get()
    {
        return pRep;
    }
    
    ref T getAs()
    {
        return pRep;
    }
    
    ref T getPointer()
    {
        return pRep;
    }
    
    size_t useCount()
    {
        return 1;
    }
    
    static if(!is(T == Resource ) && 
        is(T == class)) //ignore structs
    void opAssign(SharedPtr!Resource rhs) //FIXME ensure _payload of type T is derived class from Resource
    {
        pRep = cast(T) rhs.pRep;
    }
    
    void opAssign(typeof(this) rhs)
    {
        pRep = rhs.pRep;
    }
    void copyToPtr(T rep)
    {
        static if(is(T == T*))
        {
            *pRep = *rep;
        }
    }
}

//Mess with these if linking problems
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.hardware;
alias SharedPtr!HardwareVertexBuffer HardwareVertexBufferPtr;
alias SharedPtr!HardwareIndexBuffer HardwareIndexBufferPtr;
alias SharedPtr!HardwarePixelBuffer HardwarePixelBufferPtr;
alias SharedPtr!HardwareUniformBuffer HardwareUniformBufferPtr;
alias SharedPtr!RenderToVertexBuffer RenderToVertexBufferPtr;
//HardwareVertexBufferPtr _HardwareVertexBufferPtr;

import ogre.general.controller;
alias SharedPtr!(ControllerValue!Real) ControllerValueRealPtr;
alias SharedPtr!(ControllerFunction!Real) ControllerFunctionRealPtr;

//ControllerValueRealPtr _ControllerValueRealPtr;
//ControllerFunctionRealPtr _ControllerFunctionRealPtr;


import ogre.lod.patchmesh;
alias SharedPtr!PatchMesh PatchMeshPtr;

import ogre.materials.material;
alias SharedPtr!Material MaterialPtr;

import ogre.materials.gpuprogram;
alias SharedPtr!(GpuNamedConstants*) GpuNamedConstantsPtr;
alias SharedPtr!GpuLogicalBufferStruct GpuLogicalBufferStructPtr;
alias SharedPtr!GpuSharedParameters GpuSharedParametersPtr;
alias SharedPtr!GpuProgramParameters GpuProgramParametersPtr;
alias SharedPtr!GpuProgram GpuProgramPtr;

import ogre.scene.shadowtexturemanager;
alias SharedPtr!(Texture)[] ShadowTextureListPtr;

import ogre.resources.mesh;
alias SharedPtr!Mesh MeshPtr;

import ogre.resources.resource;
alias SharedPtr!Resource ResourcePtr;

import ogre.resources.highlevelgpuprogram;
alias SharedPtr!HighLevelGpuProgram HighLevelSharedPtr;

import ogre.resources.texture;
alias SharedPtr!Texture TexturePtr;

import ogre.effects.compositor;
alias SharedPtr!Compositor CompositorPtr;

import ogre.animation.animable;
alias SharedPtr!AnimableValue AnimableValuePtr;

import ogre.animation.animations;
alias SharedPtr!Skeleton SkeletonPtr;

//import ogre.resources.resourcegroupmanager;
//NO alias SharedPtr!Resource[] LoadUnloadResourceList;