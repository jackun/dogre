module ogre.effects.particleaffector;

//import std.container;
import std.algorithm;
import std.range;
import ogre.effects.particlesystem;
import ogre.general.generals;
import ogre.general.common;
import ogre.effects.particle;
import ogre.compat;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Abstract class defining the interface to be implemented by particle affectors.
    @remarks
        Particle affectors modify particles in a particle system over their lifetime. They can be
        grouped into types, e.g. 'vector force' affectors, 'fader' affectors etc; each type will 
        modify particles in a different way, using different parameters.
    @par
        Because there are so many types of affectors you could use, OGRE chooses not to dictate
        the available types. It comes with some in-built, but allows plugins or applications to extend the affector types available.
        This is done by subclassing ParticleAffector to have the appropriate emission behaviour you want,
        and also creating a subclass of ParticleAffectorFactory which is responsible for creating instances 
        of your new affector type. You register this factory with the ParticleSystemManager using
        addAffectorFactory, and from then on affectors of this type can be created either from code or through
        text particle scripts by naming the type.
    @par
        This same approach is used for ParticleEmitters (which are the source of particles in a system).
        This means that OGRE is particularly flexible when it comes to creating particle system effects,
        with literally infinite combinations of affector and affector types, and parameters within those
        types.
    */
class ParticleAffector : StringInterface //, public FXAlloc
{
    mixin StringInterfaceTmpl;
protected:
    /// Name of the type of affector, MUST be initialised by subclasses
    string mType;
    
    /** Internal method for setting up the basic parameter definitions for a subclass. 
        @remarks
            Because StringInterface holds a dictionary of parameters per class, subclasses need to
            call this to ask the base class to add it's parameters to their dictionary as well.
            Can't do this in the constructor because that runs in a non-context.
        @par
            The subclass must have called it's own createParamDictionary before calling this method.
        */
    void addBaseParameters() { /* actually do nothing - for future possible use */ }
    
    ParticleSystem mParent;
public:
    this(ParticleSystem parent)
    {
        mParent = parent;
    }
    
    /** destructor essential. */
    ~this() {}
    
    /** Method called to allow the affector to initialize all newly created particles in the system.
        @remarks
            This is where the affector gets the chance to initialize it's effects to the particles of a system.
            The affector is expected to initialize some or all of the particles in the system
            passed to it, depending on the affector's approach.
        @param
            pParticle Pointer to a Particle to initialize.
        */
    void _initParticle(ref Particle pParticle)
    {
        /* by default do nothing */
    }
    
    /** Method called to allow the affector to 'do it's stuff' on all active particles in the system.
        @remarks
            This is where the affector gets the chance to apply it's effects to the particles of a system.
            The affector is expected to apply it's effect to some or all of the particles in the system
            passed to it, depending on the affector's approach.
        @param
            pSystem Pointer to a ParticleSystem to affect.
        @param
            timeElapsed The number of seconds which have elapsed since the last call.
        */
    abstract void _affectParticles(ref ParticleSystem pSystem, Real timeElapsed);
    
    /** Returns the name of the type of affector. 
        @remarks
            This property is useful for determining the type of affector procedurally so another
            can be created.
        */
   string getType(){ return mType; }
}

/** Abstract class defining the interface to be implemented by creators of ParticleAffector subclasses.
    @remarks
        Plugins or 3rd party applications can add new types of particle affectors to Ogre by creating
        subclasses of the ParticleAffector class. Because multiple instances of these affectors may be
        required, a factory class to manage the instances is also required. 
    @par
        ParticleAffectorFactory subclasses must allow the creation and destruction of ParticleAffector
        subclasses. They must also be registered with the ParticleSystemManager. All factories have
        a name which identifies them, examples might be 'force_vector', 'attractor', or 'fader', and these can be 
        also be used from particle system scripts.
    */
class ParticleAffectorFactory //: public FXAlloc
{
protected:
    //vector<ParticleAffector*>::type mAffectors;
    ParticleAffector[] mAffectors;
public:
    this() {}
    ~this()
    {
        // Destroy all affectors
        foreach (i; mAffectors)
        {
            destroy(i);
        }
        
        mAffectors.clear();
        
    }
    /** Returns the name of the factory, the name which identifies the particle affector type this factory creates. */
    abstract string getName();
    
    /** Creates a new affector instance.
        @remarks
            The subclass MUST add a pointer to the created instance to mAffectors.
        */
    abstract ref ParticleAffector createAffector(ref ParticleSystem psys);
    
    /** Destroys the affector pointed to by the parameter (for early clean up if required). */
    void destroyAffector(ref ParticleAffector e)
    {
        mAffectors.removeFromArray(e);
        destroy(e);
    }
}

/** @} */
/** @} */