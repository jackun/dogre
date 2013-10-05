module ogre.effects.particle;
import ogre.compat;
import ogre.math.angles;
import ogre.math.vector;
import ogre.general.colourvalue;
import ogre.effects.particlesystem; 

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Abstract class containing any additional data required to be associated
        with a particle to perform the required rendering. 
    @remarks
        Because you can specialise the way that particles are rendered by supplying
        custom ParticleSystemRenderer classes, you might well need some additional 
        data for your custom rendering routine which is not held on the default particle
        class. If that's the case, then you should define a subclass of this class, 
        andruct it when asked in your custom ParticleSystemRenderer class.
    */
class ParticleVisualData //: public FXAlloc
{
public:
    this() {}
    ~this() {}
}

/** Class representing a single particle instance. */
class Particle //: public FXAlloc
{
protected:
    /// Parent ParticleSystem
    ParticleSystem mParentSystem;
    /// Additional visual data you might want to associate with the Particle
    ParticleVisualData mVisual;
public:
    /// Type of particle
    enum ParticleType
    {
        Visual,
        Emitter
    }
    
    /// Does this particle have it's own dimensions?
    bool mOwnDimensions;
    /// Personal width if mOwnDimensions == true
    Real mWidth;
    /// Personal height if mOwnDimensions == true
    Real mHeight;
    /// Current rotation value
    Radian rotation;
    // Note the intentional public access to internal variables
    // Accessing via get/set would be too costly for 000's of particles
    /// World position
    Vector3 position;
    /// Direction (and speed) 
    Vector3 direction;
    /// Current colour
    ColourValue colour;
    /// Time to live, number of seconds left of particles natural life
    Real timeToLive;
    /// Total Time to live, number of seconds of particles natural life
    Real totalTimeToLive;
    /// Speed of rotation in radians/sec
    Radian rotationSpeed;
    /// Determines the type of particle.
    ParticleType particleType;
    
    this()
    { 
        mParentSystem = null;
        mVisual = null;
        mOwnDimensions = false;
        rotation = 0;
        position = Vector3.ZERO;
        direction = Vector3.ZERO;
        colour = ColourValue.White;
        timeToLive = 10;
        totalTimeToLive = 10;
        rotationSpeed = 0;
        particleType = ParticleType.Visual;
    }
    
    /** Sets the width and height for this particle.
        @remarks
        Note that it is most efficient for every particle in a ParticleSystem to have the same dimensions. If you
        choose to alter the dimensions of an individual particle the set will be less efficient. Do not call
        this method unless you really need to have different particle dimensions within the same set. Otherwise
        just call the ParticleSystem::setDefaultDimensions method instead.
        */
    void setDimensions(Real width, Real height)
    {
        mOwnDimensions = true;
        mWidth = width;
        mHeight = height;
        mParentSystem._notifyParticleResized();
    }
    
    /** Returns true if this particle deviates from the ParticleSystem's default dimensions (i.e. if the
        particle::setDimensions method has been called for this instance).
        @see
        particle::setDimensions
        */
    bool hasOwnDimensions(){ return mOwnDimensions; }
    
    /** Retrieves the particle's personal width, if hasOwnDimensions is true. */
    Real getOwnWidth(){ return mWidth; }
    
    /** Retrieves the particle's personal width, if hasOwnDimensions is true. */
    Real getOwnHeight(){ return mHeight; }
    
    /** Sets the current rotation */
    void setRotation(Radian rot)
    {
        rotation = rot;
        if (rotation != Radian(0))
            mParentSystem._notifyParticleRotated();
    }
    
   Radian getRotation(){ return rotation; }
    
    /** Internal method for notifying the particle of it's owner.
        */
    void _notifyOwner(ref ParticleSystem owner)
    {
        mParentSystem = owner;
    }
    
    /** Internal method for notifying the particle of it's optional visual data.
        */
    void _notifyVisualData(ParticleVisualData vis) { mVisual = vis; }
    
    /// Get the optional visual data associated with the class
    ref ParticleVisualData getVisualData(){ return mVisual; }
    
    /// Utility method to reset this particle
    void resetDimensions()
    {
        mOwnDimensions = false;
    }
}
/** @} */
/** @} */