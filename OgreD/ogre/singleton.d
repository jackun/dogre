module ogre.singleton;

//http://www.digitalmars.com/d/archives/digitalmars/D/Static_constructors_in_circularly_imported_modules_-_again_110518.html#N110527
//http://www.digitalmars.com/d/archives/digitalmars/D/The_singleton_design_pattern_in_D_C_and_Java_113474.html

//Thread safe assumably?
// Well, this can't be inherited.
/*class Singleton(T) {
 private:
 static bool initialized;  // Thread-local
 __gshared static T instance;

 this() {}

 public:

 static T getSingleton() {
 if(initialized) {
 return instance;
 }

 synchronized(SingletonT.classinfo) {
 scope(success) initialized = true;
 if(instance !is null) {
 return instance;
 }

 instance = new T;
 return instance;
 }
 }
 }*/

//Trying mixins
//Thread safe assumably
mixin template Singleton(T) //if(is(T == class))  //probably unneeded check
{
    private
    {
        __gshared static bool initialized;  // Thread-local
        //shared static T instance;
        __gshared  T instance; //or __gshared ,also haa issue #4419 aka lose the static
    }
    //or
    //static this() { ... }
    public
    {
        //static T opCall()
        //{
        //    return getInstance();
        //}

        /*  **** Example ****
            class Base{ mixin Singleton!Base; }
            class Derived : Base {}
            //Initialize somewhere
            Derived mDerived = Derived.getSingletonInit!Derived();
            FinalishClass mBase = FinalishClass.getSingleton(); //aka is not derived otherwise you get base class
            or
            Derived mDerived = Derived.getSingletonInit!(Derived)(someArg);
            Derived derived = Derived.getSingleton();
            Base base = Base.getSingleton();
            assert(cast(Derived)base !is null);
            assert(base == mDerived);
         */
        // Can has derived classes?
        // DT should be derived class type. Then BaseClass.getSingleton() should return the same instance of derived class.
        // Bit annoying though.
        static DT getSingletonInit(DT, Args...)(Args args) {
            if(initialized) {
                return cast(DT)instance;
            }
            
            synchronized(T.classinfo) {
                scope(success) initialized = true;
                if(instance !is null) {
                    return cast(DT)instance;
                }
                
                //instance = cast(shared DT)new DT(args); //Make shared
                instance = new DT(args);
                return cast(DT)instance;  //but cast away shared here
            }
        }
        
        static T getSingleton(Args...)(Args args) {
            
            if(initialized) {
                return instance;
            }

            //Allow creation if T is final
            synchronized(T.classinfo) {
                scope(success) initialized = true;
                if(instance !is null) {
                    return instance;
                }
                
                //instance = cast(shared T)new T(args);
                instance = new T(args);
                return instance;
            }

            //or just assert
            //assert(0, "Initialize singleton with getSingletonInit.");
        }

        /// Whole lot of places use Ptr() as boolean, so give them this.
        static bool getSingletonPtr() {
            return initialized;
        }
    }

    //Eh?
    //ogre/singleton.d(63): Error: outer function context of ogre.scene.scenemanager.SceneManagerEnumerator.Singleton!(SceneManagerEnumerator).__unittestL74_2104.A........
    /*unittest
    {
        {
            class A
            {
                mixin Singleton!A;
                int x;
            }
            class B
            {
                mixin Singleton!B;
                int x;
            }
            
            auto a0 = A.getSingleton();
            auto a1 = A.getSingleton();
            
            auto b0 = B.getSingleton();
            auto b1 = B.getSingleton();
            
            a0.x = 1234;
            b0.x = 9876;
            
            assert(a0.x == a1.x);
            assert(b0.x == b1.x);
            assert(a0.x != b0.x);
            assert(a1.x != b1.x);
        }
    }*/

}