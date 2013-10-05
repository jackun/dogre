module ogre.effects.particlesystem;
import std.algorithm;
//import std.container;
import std.range;

import ogre.compat;
import ogre.scene.movableobject;
import ogre.general.log;
import ogre.general.generals;
import ogre.general.controller;
import ogre.resources.resourcegroupmanager;
import ogre.math.axisalignedbox;
import ogre.compat;
import ogre.general.common;
import ogre.materials.material;
import ogre.math.vector;
import ogre.effects.particle;
import ogre.scene.camera;
import ogre.scene.node;
import ogre.general.controllermanager;
import ogre.rendersystem.renderqueue;
import ogre.scene.renderable;
import ogre.general.radixsort;
import ogre.effects.particleemitter;
import ogre.effects.particleaffector;
import ogre.effects.particlesystemrenderer;
import ogre.general.root;
import ogre.effects.particlesystemmanager;
import ogre.materials.materialmanager;
import ogre.math.angles;
import ogre.math.maths;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */

// Local class for updating based on time
class ParticleSystemUpdateValue : ControllerValue!Real
{
protected:
    ParticleSystem mTarget;
public:
    this(ref ParticleSystem target)
    {
        mTarget = target;
    }
    
    override Real getValue(){ return 0; } // N/A
    
    override void setValue(Real value) { mTarget._update(value); }
}

/** Class defining particle system based special effects.
    @remarks
        Particle systems are special effects generators which are based on a 
        number of moving points to create the impression of things like like 
        sparkles, smoke, blood spurts, dust etc.
    @par
        This class simply manages a single collection of particles in world space
        with a shared local origin for emission. The visual aspect of the 
        particles is handled by a ParticleSystemRenderer instance.
    @par
        Particle systems are created using the SceneManager, never directly.
        In addition, like all subclasses of MovableObject, the ParticleSystem 
        will only be considered for rendering once it has been attached to a 
        SceneNode. 
    */
class ParticleSystem : MovableObject, StringInterface
{
    mixin StringInterfaceTmpl;

public:
    
    /** Command object for quota (see ParamCommand).*/
    static class CmdQuota : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getParticleQuota() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setParticleQuota(
                std.conv.to!uint(val));
        }
    }
    /** Command object for emittedEmitterQuota (see ParamCommand).*/
    static class CmdEmittedEmitterQuota : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getEmittedEmitterQuota() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setEmittedEmitterQuota(
                std.conv.to!uint(val));
        }
    }
    /** Command object for material (see ParamCommand).*/
    static class CmdMaterial : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return (cast(ParticleSystem)target).getMaterialName();
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setMaterialName(val);
        }
    }
    /** Command object for cull_each (see ParamCommand).*/
    static class CmdCull : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getCullIndividually() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setCullIndividually(
                std.conv.to!bool(val));
        }
    }
    /** Command object for particle_width (see ParamCommand).*/
    static class CmdWidth : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getDefaultWidth() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setDefaultWidth(
                std.conv.to!Real(val));
        }
    }
    /** Command object for particle_height (see ParamCommand).*/
    static class CmdHeight : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getDefaultHeight() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setDefaultHeight(
                std.conv.to!Real(val));
        }
    }
    /** Command object for renderer (see ParamCommand).*/
    static class CmdRenderer : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return (cast(ParticleSystem)target).getRendererName();
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setRenderer(val);
        }
    }
    /** Command object for sorting (see ParamCommand).*/
    static class CmdSorted : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getSortingEnabled());
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setSortingEnabled(
                std.conv.to!bool(val));
        }
    }
    /** Command object for local space (see ParamCommand).*/
    static class CmdLocalSpace : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getKeepParticlesInLocalSpace());
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setKeepParticlesInLocalSpace(
                std.conv.to!bool(val));
        }
    }
    /** Command object for iteration interval(see ParamCommand).*/
    static class CmdIterationInterval : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getIterationInterval());
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setIterationInterval(
                std.conv.to!Real(val));
        }
    }
    /** Command object for nonvisible timeout (see ParamCommand).*/
    static class CmdNonvisibleTimeout : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleSystem)target).getNonVisibleUpdateTimeout());
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleSystem)target).setNonVisibleUpdateTimeout(
                std.conv.to!Real(val));
        }
    }
    
    /// Default constructor required for STL creation in manager
    this()
    {
        //mAABB = ;
        mBoundingRadius = 1.0f;
        mBoundsAutoUpdate = true;
        mBoundsUpdateTime = 10.0f;
        mUpdateRemainTime = 0;
        //mWorldAABB = ;
        mResourceGroupName = ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME;
        mIsRendererConfigured = false;
        mSpeedFactor = 1.0f;
        mIterationInterval = 0;
        mIterationIntervalSet = false;
        mSorted = false;
        mLocalSpace = false;
        mNonvisibleTimeout = 0;
        mNonvisibleTimeoutSet = false;
        mTimeSinceLastVisible = 0;
        mLastVisibleFrame = 0;
        //mTimeController = null;
        mEmittedEmitterPoolInitialised = false;
        mIsEmitting = true;
        //mRenderer = null;
        mCullIndividual = false;
        mPoolSize = 0;
        mEmittedEmitterPoolSize = 0;

        initParameters();
        
        // Default to billboard renderer
        setRenderer("billboard");
        
    }
    /** Creates a particle system with no emitters or affectors.
        @remarks
            You should use the ParticleSystemManager to create particle systems rather than creating
            them directly.
        */
    this(string name,string resourceGroupName)
    {
        super(name);
        //mAABB = ;
        mBoundingRadius = 1.0f;
        mBoundsAutoUpdate = true;
        mBoundsUpdateTime = 10.0f;
        mUpdateRemainTime = 0;
        //mWorldAABB = ;
        mResourceGroupName = resourceGroupName;
        mIsRendererConfigured = false;
        mSpeedFactor = 1.0f;
        mIterationInterval = 0;
        mIterationIntervalSet = false;
        mSorted = false;
        mLocalSpace = false;
        mNonvisibleTimeout = 0;
        mNonvisibleTimeoutSet = false;
        mTimeSinceLastVisible = 0;
        mLastVisibleFrame = Root.getSingleton().getNextFrameNumber();
        //mTimeController = null;
        mEmittedEmitterPoolInitialised = false;
        mIsEmitting = true;
        //mRenderer = null;
        mCullIndividual = false;
        mPoolSize = 0;
        mEmittedEmitterPoolSize = 0;

        setDefaultDimensions( 100, 100 );
        setMaterialName( "BaseWhite" );
        // Default to 10 particles, expect app to specify (will only be increased, not decreased)
        setParticleQuota( 10 );
        setEmittedEmitterQuota( 3 );
        initParameters();
        
        // Default to billboard renderer
        setRenderer("billboard");
    }
    
    ~this()
    {
        if (mTimeController)
        {
            // Destroy controller
            ControllerManager.getSingleton().destroyController(mTimeController);
            mTimeController = null;
        }
        
        // Arrange for the deletion of emitters & affectors
        removeAllEmitters();
        removeAllEmittedEmitters();
        removeAllAffectors();
        
        // Deallocate all particles
        destroyVisualParticles(0, mParticlePool.length);
        // Free pool items
        foreach (i; mParticlePool)
        {
            destroy(i);
        }
        
        if (mRenderer)
        {
            ParticleSystemManager.getSingleton()._destroyRenderer(mRenderer);
            mRenderer = null;
        }
    }
    
    /** Sets the ParticleRenderer to be used to render this particle system.
        @remarks
            The main ParticleSystem just manages the creation and movement of 
            particles; they are rendered using functions in ParticleRenderer
            and the ParticleVisual instances they create.
        @param typeName string identifying the type of renderer to use; a new 
            instance of this type will be created; a factory must have been registered
            with ParticleSystemManager.
        */
    void setRenderer(string rendererName)
    {
        if (mRenderer)
        {
            // Destroy existing
            destroyVisualParticles(0, mParticlePool.length);
            ParticleSystemManager.getSingleton()._destroyRenderer(mRenderer);
            mRenderer = null;
        }
        
        if (rendererName !is null && rendererName != "")
        {
            mRenderer = ParticleSystemManager.getSingleton()._createRenderer(rendererName);
            mIsRendererConfigured = false;
        }
    }
    
    /** Gets the ParticleRenderer to be used to render this particle system. */
    ref ParticleSystemRenderer getRenderer()
    {
        return mRenderer;
    }

    /** Gets the name of the ParticleRenderer to be used to render this particle system. */
   string getRendererName()
    {
        if (mRenderer)
        {
            return mRenderer.getType();
        }
        else
        {
            return null;
        }
    }
    
    /** Adds an emitter to this particle system.
        @remarks
            Particles are created in a particle system by emitters - see the ParticleEmitter
            class for more details.
        @param 
            emitterType string identifying the emitter type to create. Emitter types are defined
            by registering new factories with the manager - see ParticleEmitterFactory for more details.
            Emitter types can be extended by OGRE, plugin authors or application developers.
        */
    ParticleEmitter addEmitter(string emitterType)
    {
        ParticleEmitter em = 
            ParticleSystemManager.getSingleton()._createEmitter(emitterType, this);
        mEmitters.insert(em);
        return em;
    }
    
    /** Retrieves an emitter by it's index (zero-based).
        @remarks
            Used to retrieve a pointer to an emitter for a particle system to procedurally change
            emission parameters etc.
            You should check how many emitters are registered against this system before calling
            this method with an arbitrary index using getNumEmitters.
        @param
            index Zero-based index of the emitter to retrieve.
        */
    ref ParticleEmitter getEmitter(ushort index)
    {
        assert(index < mEmitters.length, "Emitter index out of bounds!");
        return mEmitters[index];
    }
    
    /** Returns the number of emitters for this particle system. */
    ushort getNumEmitters()
    {
        return cast(ushort)( mEmitters.length );
    }
    
    /** Removes an emitter from the system.
        @remarks
            Drops the emitter with the index specified from this system.
            You should check how many emitters are registered against this system before calling
            this method with an arbitrary index using getNumEmitters.
        @param
            index Zero-based index of the emitter to retrieve.
        */
    void removeEmitter(ushort index)
    {
        assert(index < mEmitters.length, "Emitter index out of bounds!");
        auto ei = mEmitters[index];
        ParticleSystemManager.getSingleton()._destroyEmitter(ei);
        mEmitters.removeFromArrayIdx(index);
    }
    
    /** Removes all the emitters from this system. */
    void removeAllEmitters()
    {
        // C++: DON'T delete directly, we don't know what heap these have been created on
        foreach (ei; mEmitters)
        {
            ParticleSystemManager.getSingleton()._destroyEmitter(ei);
        }
        mEmitters.clear();
    }
    
    
    /** Adds an affector to this particle system.
        @remarks
            Particles are modified over time in a particle system by affectors - see the ParticleAffector
            class for more details.
        @param 
            affectorType string identifying the affector type to create. Affector types are defined
            by registering new factories with the manager - see ParticleAffectorFactory for more details.
            Affector types can be extended by OGRE, plugin authors or application developers.
        */
    ParticleAffector addAffector(string affectorType)
    {
        ParticleAffector af = 
            ParticleSystemManager.getSingleton()._createAffector(affectorType, this);
        mAffectors.insert(af);
        return af;
    }
    
    /** Retrieves an affector by it's index (zero-based).
        @remarks
            Used to retrieve a pointer to an affector for a particle system to procedurally change
            affector parameters etc.
            You should check how many affectors are registered against this system before calling
            this method with an arbitrary index using getNumAffectors.
        @param
            index Zero-based index of the affector to retrieve.
        */
    ref ParticleAffector getAffector(ushort index)
    {
        assert(index < mAffectors.length, "Affector index out of bounds!");
        return mAffectors[index];
    }
    
    /** Returns the number of affectors for this particle system. */
    ushort getNumAffectors()
    {
        return cast(ushort)( mAffectors.length );
    }
    
    /** Removes an affector from the system.
        @remarks
            Drops the affector with the index specified from this system.
            You should check how many affectors are registered against this system before calling
            this method with an arbitrary index using getNumAffectors.
        @param
            index Zero-based index of the affector to retrieve.
        */
    void removeAffector(ushort index)
    {
        assert(index < mAffectors.length, "Affector index out of bounds!");
        auto ai = mAffectors[index];
        ParticleSystemManager.getSingleton()._destroyAffector(ai);
        mAffectors.removeFromArrayIdx(index);
    }
    
    /** Removes all the affectors from this system. */
    void removeAllAffectors()
    {
        // C++: DON'T delete directly, we don't know what heap these have been created on
        foreach (ai; mAffectors)
        {
            ParticleSystemManager.getSingleton()._destroyAffector(ai);
        }
        mAffectors.clear();
    }
    
    /** Empties this set of all particles.
        */
    void clear()
    {
        // Notify renderer if exists
        if (mRenderer)
        {
            mRenderer._notifyParticleCleared(mActiveParticles);
        }
        
        // Move actives to free list
        //mFreeParticles.splice(mFreeParticles.end(), mActiveParticles);
        mFreeParticles.insert(mActiveParticles);
        mActiveParticles.clear();
        
        // Add active emitted emitters to free list
        addActiveEmittedEmittersToFreeList();
        
        // Remove all active emitted emitter instances
        mActiveEmittedEmitters.clear();
        
        // Reset update remain time
        mUpdateRemainTime = 0;
    }
    
    /** Gets the number of individual particles in the system right now.
        @remarks
            The number of particles active in a system at a point in time depends on 
            the number of emitters, their emission rates, the time-to-live (TTL) each particle is
            given on emission (and whether any affectors modify that TTL) and the maximum
            number of particles allowed in this system at once (particle quota).
        */
    size_t getNumParticles()
    {
        return mActiveParticles.length;
    }
    
    /** Manually add a particle to the system. 
        @remarks
            Instead of using an emitter, you can manually add a particle to the system.
            You must initialise the returned particle instance immediately with the
            'emission' state.
        @note
            There is no corresponding 'destroyParticle' method - if you want to dispose of a
            particle manually (say, if you've used setSpeedFactor(0) to make particles live forever)
            you should use getParticle() and modify it's timeToLive to zero, meaning that it will
            get cleaned up in the next update.
        */
    Particle createParticle()
    {
        Particle p;
        if (!mFreeParticles.empty())
        {
            // Fast creation (don't use superclass since emitter will init)
            p = mFreeParticles.front();
            //mActiveParticles.splice(mActiveParticles.end(), mFreeParticles, mFreeParticles.begin());
            mActiveParticles.insert(mFreeParticles[0]);
            mFreeParticles.removeFromArrayIdx(0);

            p._notifyOwner(this);
        }
        
        return p;
        
    }
    
    /** Manually add an emitter particle to the system. 
        @remarks
            The purpose of a particle emitter is to emit particles. Besides visual particles, also other other
            particle types can be emitted, other emitters for example. The emitted emitters have a double role;
            they behave as particles and can be influenced by affectors, but they are still emitters and capable 
            to emit other particles (or emitters). It is possible to create a chain of emitters - emitters 
            emitting other emitters, which also emit emitters.
        @param emitterName The name of a particle emitter that must be emitted.
        */
    Particle createEmitterParticle(string emitterName)
    {
        // Get the appropriate list and retrieve an emitter 
        Particle p;
        auto fee = findFreeEmittedEmitter(emitterName);
        if (fee !is null && !(*fee).empty())
        {
            p = (*fee).front();
            p.particleType = Particle.ParticleType.Emitter;
            //fee.pop_front();
            (*fee).removeFromArrayIdx(0);
            mActiveParticles.insert(p);
            
            // Also add to mActiveEmittedEmitters. This is needed to traverse through all active emitters
            // that are emitted. Don't use mActiveParticles for that (although they are added to
            // mActiveParticles also), because it would take too long to traverse.
            mActiveEmittedEmitters.insert(cast(ParticleEmitter)p);
            
            p._notifyOwner(this);
        }
        
        return p;
    }
    
    /** Retrieve a particle from the system for manual tweaking.
        @remarks
            Normally you use an affector to alter particles in flight, but
            for small manually controlled particle systems you might want to use
            this method.
        */
    ref Particle getParticle(size_t index)
    {
        assert (index < mActiveParticles.length, "Index out of bounds!");
        return mActiveParticles[index];
    }
    
    /** Returns the maximum number of particles this system is allowed to have active at once.
        @remarks
            See ParticleSystem::setParticleQuota for more info.
        */
    size_t getParticleQuota()
    {
        return mPoolSize;
    }
    
    /** Sets the maximum number of particles this system is allowed to have active at once.
        @remarks
            Particle systems all have a particle quota, i.e. a maximum number of particles they are 
            allowed to have active at a time. This allows the application to set a keep particle systems
            under control should they be affected by complex parameters which alter their emission rates
            etc. If a particle system reaches it's particle quota, none of the emitters will be able to 
            emit any more particles. As existing particles die, the spare capacity will be allocated
            equally across all emitters to be as consistent to the original particle system style as possible.
            The quota can be increased but not decreased after the system has been created.
        @param quota The maximum number of particles this system is allowed to have.
        */
    void setParticleQuota(size_t quota)
    {
        // Never shrink below size()
        size_t currSize = mParticlePool.length;
        
        if( currSize < quota )
        {
            // Will allocate particles on demand
            mPoolSize = quota;
            
        }
    }
    
    /** Returns the maximum number of emitted emitters this system is allowed to have active at once.
        @remarks
            See ParticleSystem::setEmittedEmitterQuota for more info.
        */
    size_t getEmittedEmitterQuota()
    {
        return mEmittedEmitterPoolSize;
    }
    
    /** Sets the maximum number of emitted emitters this system is allowed to have active at once.
        @remarks
            Particle systems can have - besides a particle quota - also an emitted emitter quota.
        @param quota The maximum number of emitted emitters this system is allowed to have.
        */
    void setEmittedEmitterQuota(size_t quota)
    {
        // Never shrink below size()
        size_t currSize = 0;
        foreach (k,v; mEmittedEmitterPool)
        {
            currSize += v.length;
        }
        
        if( currSize < quota )
        {
            // Will allocate emitted emitters on demand
            mEmittedEmitterPoolSize = quota;
        }
    }
    
    /** Assignment operator for copying.
        @remarks
            This operator deep copies all particle emitters and effectors, but not particles. The
            system's name is also not copied.
        */
    //ref ParticleSystem opAssign(ParticleSystem rhs)// Illegal and useless for class
    void copyFrom(ParticleSystem rhs)
    {
        // Blank this system's emitters & affectors
        removeAllEmitters();
        removeAllEmittedEmitters();
        removeAllAffectors();
        
        // Copy emitters
        foreach(ushort i; 0..rhs.getNumEmitters())
        {
            ParticleEmitter rhsEm = rhs.getEmitter(i);
            ParticleEmitter newEm = addEmitter(rhsEm.getType());
            rhsEm.copyParametersTo(newEm);
        }
        // Copy affectors
        foreach(ushort i; 0..rhs.getNumAffectors())
        {
            ParticleAffector rhsAf = rhs.getAffector(i);
            ParticleAffector newAf = addAffector(rhsAf.getType());
            rhsAf.copyParametersTo(newAf);
        }
        setParticleQuota(rhs.getParticleQuota());
        setEmittedEmitterQuota(rhs.getEmittedEmitterQuota());
        setMaterialName(rhs.mMaterialName);
        setDefaultDimensions(rhs.mDefaultWidth, rhs.mDefaultHeight);
        mCullIndividual = rhs.mCullIndividual;
        mSorted = rhs.mSorted;
        mLocalSpace = rhs.mLocalSpace;
        mIterationInterval = rhs.mIterationInterval;
        mIterationIntervalSet = rhs.mIterationIntervalSet;
        mNonvisibleTimeout = rhs.mNonvisibleTimeout;
        mNonvisibleTimeoutSet = rhs.mNonvisibleTimeoutSet;
        // last frame visible and time since last visible should be left default
        
        setRenderer(rhs.getRendererName());
        // Copy settings
        if (mRenderer && rhs.getRenderer())
        {
            rhs.getRenderer().copyParametersTo(mRenderer);
        }
        
        //return this;
    }
    
    /** Updates the particles in the system based on time elapsed.
        @remarks
            This is called automatically every frame by OGRE.
        @param
            timeElapsed The amount of time, in seconds, since the last frame.
        */
    void _update(Real timeElapsed)
    {
        // Only update if attached to a node
        if (!mParentNode)
            return;
        
        Real nonvisibleTimeout = mNonvisibleTimeoutSet ?
            mNonvisibleTimeout : msDefaultNonvisibleTimeout;
        
        if (nonvisibleTimeout > 0)
        {
            // Check whether it's been more than one frame (update is ahead of
            // camera notification by one frame because of the ordering)
            long frameDiff = Root.getSingleton().getNextFrameNumber() - mLastVisibleFrame;
            if (frameDiff > 1 || frameDiff < 0) // < 0 if wrap only
            {
                mTimeSinceLastVisible += timeElapsed;
                if (mTimeSinceLastVisible >= nonvisibleTimeout)
                {
                    // No update
                    return;
                }
            }
        }
        
        // Scale incoming speed for the rest of the calculation
        timeElapsed *= mSpeedFactor;
        
        // Init renderer if not done already
        configureRenderer();
        
        // Initialise emitted emitters list if not done already
        initialiseEmittedEmitters();
        
        Real iterationInterval = mIterationIntervalSet ? 
            mIterationInterval : msDefaultIterationInterval;
        if (iterationInterval > 0)
        {
            mUpdateRemainTime += timeElapsed;
            
            while (mUpdateRemainTime >= iterationInterval)
            {
                // Update existing particles
                _expire(iterationInterval);
                _triggerAffectors(iterationInterval);
                _applyMotion(iterationInterval);
                
                if(mIsEmitting)
                {
                    // Emit new particles
                    _triggerEmitters(iterationInterval);
                }
                
                mUpdateRemainTime -= iterationInterval;
            }
        }
        else
        {
            // Update existing particles
            _expire(timeElapsed);
            _triggerAffectors(timeElapsed);
            _applyMotion(timeElapsed);
            
            if(mIsEmitting)
            {
                // Emit new particles
                _triggerEmitters(timeElapsed);
            }
        }
        
        if (!mBoundsAutoUpdate && mBoundsUpdateTime > 0.0f)
            mBoundsUpdateTime -= timeElapsed; // count down 
        _updateBounds();
        
    }
    
    /** Returns an iterator for stepping through all particles in this system.
        @remarks
            This method is designed to be used by people providing new ParticleAffector subclasses,
            this is the easiest way to step through all the particles in a system and apply the
            changes the affector wants to make.
        */
    /*ParticleIterator _getIterator()
    {
        return ParticleIterator(mActiveParticles.begin(), mActiveParticles.end());
    }*/

    ref ActiveParticleList getParticles()
    {
        return mActiveParticles;
    }

    /** Sets the name of the material to be used for this billboard set.
            @param
                name The new name of the material to use for this set.
        */
    void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        mMaterialName = name;
        if (mIsRendererConfigured)
        {
            SharedPtr!Material mat = MaterialManager.getSingleton().load(
                mMaterialName, mResourceGroupName);
            mRenderer._setMaterial(mat);
        }
    }
    
    /** Sets the name of the material to be used for this billboard set.
            @return The name of the material that is used for this set.
        */
   string getMaterialName()
    {
        return mMaterialName;
    }
    
    /** Overridden from MovableObject
            @see
                MovableObject
        */
    override void _notifyCurrentCamera(Camera cam)
    {
        super._notifyCurrentCamera(cam);
        
        // Record visible
        if (isVisible())
        {           
            mLastVisibleFrame = Root.getSingleton().getNextFrameNumber();
            mTimeSinceLastVisible = 0.0f;
            
            if (mSorted)
            {
                _sortParticles(cam);
            }
            
            if (mRenderer)
            {
                if (!mIsRendererConfigured)
                    configureRenderer();
                
                mRenderer._notifyCurrentCamera(cam);
            }
        }
    }
    
    /** Overridden from MovableObject
        @see
        MovableObject
        */
    override void _notifyAttached(Node parent, bool isTagPoint = false)
    {
        super._notifyAttached(parent, isTagPoint);
        if (mRenderer && mIsRendererConfigured)
        {
            mRenderer._notifyAttached(parent, isTagPoint);
        }
        
        if (parent && !mTimeController)
        {
            // Assume visible
            mTimeSinceLastVisible = 0;
            mLastVisibleFrame = Root.getSingleton().getNextFrameNumber();
            
            // Create time controller when attached
            ControllerManager mgr = ControllerManager.getSingleton(); 
            auto updValue = ControllerValueRealPtr(new ParticleSystemUpdateValue(this));
            mTimeController = mgr.createFrameTimePassthroughController(updValue);
        }
        else if (!parent && mTimeController)
        {
            // Destroy controller
            ControllerManager.getSingleton().destroyController(mTimeController);
            mTimeController = null;
        }
    }
    
    /** Overridden from MovableObject
            @see
                MovableObject
        */
    override AxisAlignedBox getBoundingBox(){ return mAABB; }
    
    /** Overridden from MovableObject
            @see
                MovableObject
        */
    override Real getBoundingRadius(){ return mBoundingRadius; }
    
    /** Overridden from MovableObject
            @see
                MovableObject
        */
    override void _updateRenderQueue(RenderQueue queue)
    {
        if (mRenderer)
        {
            mRenderer._updateRenderQueue(queue, mActiveParticles, mCullIndividual);
        }
    }
    
    /// @copydoc MovableObject::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        if (mRenderer)
        {
            mRenderer.visitRenderables(visitor, debugRenderables);
        }
    }
    
    /** Fast-forwards this system by the required number of seconds.
        @remarks
            This method allows you to fast-forward a system so that it effectively looks like
            it has already been running for the time you specify. This is useful to avoid the
            'startup sequence' of a system, when you want the system to be fully populated right
            from the start.
        @param
            time The number of seconds to fast-forward by.
        @param
            interval The sampling interval used to generate particles, apply affectors etc. The lower this
            is the more realistic the fast-forward, but it takes more iterations to do it.
        */
    void fastForward(Real time, Real interval = 0.1)
    {
        // First make sure all transforms are up to date
        
        for (Real ftime = 0; ftime < time; ftime += interval)
        {
            _update(interval);
        }
    }
    
    /** Sets a 'speed factor' on this particle system, which means it scales the elapsed
            real time which has passed by this factor before passing it to the emitters, affectors,
            and the particle life calculation.
        @remarks
            An interesting side effect - if you want to create a completely manual particle system
            where you control the emission and life of particles yourself, you can set the speed
            factor to 0.0f, thus disabling normal particle emission, alteration, and death.
        */
    void setSpeedFactor(Real speedFactor) { mSpeedFactor = speedFactor; }
    
    /** Gets the 'speed factor' on this particle system.
        */
    Real getSpeedFactor(){ return mSpeedFactor; }
    
    /** Sets a 'iteration interval' on this particle system.
        @remarks
            The default Particle system update interval, based on elapsed frame time,
            will cause different behavior between low frame-rate and high frame-rate. 
            By using this option, you can make the particle system update at
            a fixed interval, keeping the behavior the same no matter what frame-rate 
            is.
        @par
            When iteration interval is set to zero, it means the update occurs based 
            on an elapsed frame time, otherwise each iteration will take place 
            at the given interval, repeating until it has used up all the elapsed 
            frame time.
        @param
            iterationInterval The iteration interval, default to zero.
        */
    void setIterationInterval(Real iterationInterval)
    {
        mIterationInterval = iterationInterval;
        mIterationIntervalSet = true;
    }
    
    /** Gets a 'iteration interval' on this particle system.
        */
    Real getIterationInterval(){ return mIterationInterval; }
    
    /** Set the default iteration interval for all ParticleSystem instances.
        */
    static void setDefaultIterationInterval(Real iterationInterval) { msDefaultIterationInterval = iterationInterval; }
    
    /** Get the default iteration interval for all ParticleSystem instances.
        */
    static Real getDefaultIterationInterval() { return msDefaultIterationInterval; }
    
    /** Sets when the particle system should stop updating after it hasn't been
            visible for a while.
        @remarks
            By default, visible particle systems update all the time, even when 
            not in view. This means that they are guaranteed to be consistent when 
            they do enter view. However, this comes at a cost, updating particle
            systems can be expensive, especially if they are perpetual.
        @par
            This option lets you set a 'timeout' on the particle system, so that
            if it isn't visible for this amount of time, it will stop updating
            until it is next visible.
        @param timeout The time after which the particle system will be disabled
            if it is no longer visible. 0 to disable the timeout and always update.
        */
    void setNonVisibleUpdateTimeout(Real timeout)
    {
        mNonvisibleTimeout = timeout;
        mNonvisibleTimeoutSet = true;
    }
    /** Gets when the particle system should stop updating after it hasn't been
            visible for a while.
        */
    Real getNonVisibleUpdateTimeout(){ return mNonvisibleTimeout; }
    
    /** Set the default nonvisible timeout for all ParticleSystem instances.
        */
    static void setDefaultNonVisibleUpdateTimeout(Real timeout) 
    { msDefaultNonvisibleTimeout = timeout; }
    
    /** Get the default nonvisible timeout for all ParticleSystem instances.
        */
    static Real getDefaultNonVisibleUpdateTimeout() { return msDefaultNonvisibleTimeout; }
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        return ParticleSystemFactory.FACTORY_TYPE_NAME;
    }
    
    /** Internal callback used by Particles to notify their parent that they have been resized.
        */
    void _notifyParticleResized()
    {
        if (mRenderer)
        {
            mRenderer._notifyParticleResized();
        }
    }
    /** Internal callback used by Particles to notify their parent that they have been rotated.
        */
    void _notifyParticleRotated()
    {
        if (mRenderer)
        {
            mRenderer._notifyParticleRotated();
        }
    }
    
    /** Sets the default dimensions of the particles in this set.
            @remarks
                All particles in a set are created with these default dimensions. The set will render most efficiently if
                all the particles in the set are the default size. It is possible to alter the size of individual
                particles at the expense of extra calculation. See the Particle class for more info.
            @param width
                The new default width for the particles in this set.
            @param height
                The new default height for the particles in this set.
        */
    void setDefaultDimensions(Real width, Real height)
    {
        mDefaultWidth = width;
        mDefaultHeight = height;
        if (mRenderer)
        {
            mRenderer._notifyDefaultDimensions(width, height);
        }
    }
    
    /** See setDefaultDimensions - this sets 1 component individually. */
    void setDefaultWidth(Real width)
    {
        mDefaultWidth = width;
        if (mRenderer)
        {
            mRenderer._notifyDefaultDimensions(mDefaultWidth, mDefaultHeight);
        }
    }
    /** See setDefaultDimensions - this gets 1 component individually. */
    Real getDefaultWidth()
    {
        return mDefaultWidth;
    }
    /** See setDefaultDimensions - this sets 1 component individually. */
    void setDefaultHeight(Real height)
    {
        mDefaultHeight = height;
        if (mRenderer)
        {
            mRenderer._notifyDefaultDimensions(mDefaultWidth, mDefaultHeight);
        }
    }
    /** See setDefaultDimensions - this gets 1 component individually. */
    Real getDefaultHeight()
    {
        return mDefaultHeight;
    }

    /** Returns whether or not particles in this are tested individually for culling. */
    bool getCullIndividually()
    {
        return mCullIndividual;
    }
    /** Sets whether culling tests particles in this individually as well as in a group.
        @remarks
            Particle sets are always culled as a whole group, based on a bounding box which 
            encloses all particles in the set. For fairly localised sets, this is enough. However, you
            can optionally tell the set to also cull individual particles in the set, i.e. to test
            each individual particle before rendering. The default is not to do this.
        @par
            This is useful when you have a large, fairly distributed set of particles, like maybe 
            trees on a landscape. You probably still want to group them into more than one
            set (maybe one set per section of landscape), which will be culled coarsely, but you also
            want to cull the particles individually because they are spread out. Whilst you could have
            lots of single-tree sets which are culled separately, this would be inefficient to render
            because each tree would be issued as it's own rendering operation.
        @par
            By calling this method with a parameter of true, you can have large particle sets which 
            are spaced out and so get the benefit of batch rendering and coarse culling, but also have
            fine-grained culling so unnecessary rendering is avoided.
        @param cullIndividual If true, each particle is tested before being sent to the pipeline as well 
            as the whole set having to pass the coarse group bounding test.
        */
    void setCullIndividually(bool cullIndividual)
    {
        mCullIndividual = cullIndividual;
    }

    /// Return the resource group to be used to load dependent resources
   string getResourceGroupName(){ return mResourceGroupName; }
    /** Get the origin of this particle system, e.g. a script file name.
        @remarks
            This property will only contain something if the creator of
            this particle system chose to populate it. Script loaders are advised
            to populate it.
        */
   string getOrigin(){ return mOrigin; }
    /// Notify this particle system of it's origin
    void _notifyOrigin(string origin) { mOrigin = origin; }
    
    /** @copydoc MovableObject::setRenderQueueGroup */
    override void setRenderQueueGroup(ubyte queueID)
    {
        super.setRenderQueueGroup(queueID);
        if (mRenderer)
        {
            mRenderer.setRenderQueueGroup(queueID);
        }
    }
    /** @copydoc MovableObject::setRenderQueueGroupAndPriority */
    override void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority)
    {
        super.setRenderQueueGroupAndPriority(queueID, priority);
        if (mRenderer)
        {
            mRenderer.setRenderQueueGroupAndPriority(queueID, priority);
        }
    }
    
    /** Set whether or not particles are sorted according to the camera.
        @remarks
            Enabling sorting alters the order particles are sent to the renderer.
            When enabled, particles are sent to the renderer in order of 
            furthest distance from the camera.
        */
    void setSortingEnabled(bool enabled) { mSorted = enabled; }
    /// Gets whether particles are sorted relative to the camera.
    bool getSortingEnabled(){ return mSorted; }
    
    /** Set the (initial) bounds of the particle system manually. 
        @remarks
            If you can, set the bounds of a particle system up-front and 
            call setBoundsAutoUpdated(false); this is the most efficient way to
            organise it. Otherwise, set an initial bounds and let the bounds increase
            for a little while (the default is 5 seconds), after which time the 
            AABB is fixed to save time.
        @param aabb Bounds in local space.
        */
    void setBounds(AxisAlignedBox aabb)
    {
        mAABB = aabb;
        mBoundingRadius = Math.boundingRadiusFromAABB(mAABB);
        
    }
    /** Sets whether the bounds will be automatically updated
            for the life of the particle system
        @remarks
            If you have a stationary particle system, it would be a good idea to
            call this method and set the value to 'false', since the maximum
            bounds of the particle system will eventually be static. If you do
            this, you can either set the bounds manually using the setBounds()
            method, or set the second parameter of this method to a positive
            number of seconds, so that the bounds are calculated for a few
            seconds and then frozen.
        @param autoUpdate If true (the default), the particle system will
            update it's bounds every frame. If false, the bounds update will 
            cease after the 'stopIn' number of seconds have passed.
        @param stopIn Only applicable if the first parameter is true, this is the
            number of seconds after which the automatic update will cease.
        */
    void setBoundsAutoUpdated(bool autoUpdate, Real stopIn = 0.0f)
    {
        mBoundsAutoUpdate = autoUpdate;
        mBoundsUpdateTime = stopIn;
    }
    
    /** Sets whether particles (and any affector effects) remain relative 
            to the node the particle system is attached to.
        @remarks
            By default particles are in world space once emitted, so they are not
            affected by movement in the parent node of the particle system. This
            makes the most sense when dealing with completely independent particles, 
            but if you want torain them to follow local motion too, you
            can set this to true.
        */
    void setKeepParticlesInLocalSpace(bool keepLocal)
    {
        mLocalSpace = keepLocal;
        if (mRenderer)
        {
            mRenderer.setKeepParticlesInLocalSpace(keepLocal);
        }
    }
    
    /** Gets whether particles (and any affector effects) remain relative 
            to the node the particle system is attached to.
        */
    bool getKeepParticlesInLocalSpace(){ return mLocalSpace; }
    
    /** Internal method for updating the bounds of the particle system.
        @remarks
            This is called automatically for a period of time after the system's
            creation (10 seconds by default, settable by setBoundsAutoUpdated) 
            to increase (and only increase) the bounds of the system according 
            to the emitted and affected particles. After this period, the 
            system is assumed to achieved its maximum size, and the bounds are
            no longer computed for efficiency. You can tweak the behaviour by 
            either setting the bounds manually (setBounds, preferred), or 
            changing the time over which the bounds are updated (performance cost).
            You can also call this method manually if you need to update the 
            bounds on an ad-hoc basis.
        */
    void _updateBounds()
    {
        
        if (mParentNode && (mBoundsAutoUpdate || mBoundsUpdateTime > 0.0f))
        {
            if (mActiveParticles.empty())
            {
                // No particles, reset to null if auto update bounds
                if (mBoundsAutoUpdate)
                {
                    mWorldAABB.setNull();
                }
            }
            else
            {
                Vector3 min;
                Vector3 max;
                if (!mBoundsAutoUpdate && mWorldAABB.isFinite())
                {
                    // We're on a limit, grow rather than reset each time
                    // so that we pick up the worst case scenario
                    min = mWorldAABB.getMinimum();
                    max = mWorldAABB.getMaximum();
                }
                else
                {
                    min.x = min.y = min.z = Math.POS_INFINITY;
                    max.x = max.y = max.z = Math.NEG_INFINITY;
                }

                Vector3 halfScale = Vector3.UNIT_SCALE * 0.5;
                Vector3 defaultPadding = 
                    halfScale * std.algorithm.max(mDefaultHeight, mDefaultWidth);
                foreach (p; mActiveParticles)
                {
                    if (p.mOwnDimensions)
                    {
                        Vector3 padding = 
                            halfScale * std.algorithm.max(p.mWidth, p.mHeight);
                        min.makeFloor(p.position - padding);
                        max.makeCeil(p.position + padding);
                    }
                    else
                    {
                        min.makeFloor(p.position - defaultPadding);
                        max.makeCeil(p.position + defaultPadding);
                    }
                }
                mWorldAABB.setExtents(min, max);
            }
            
            
            if (mLocalSpace)
            {
                // Merge calculated box with current AABB to preserve any user-set AABB
                mAABB.merge(mWorldAABB);
            }
            else
            {
                // We've already put particles in world space to decouple them from the
                // node transform, so reverse transform back since we're expected to 
                // provide a local AABB
                auto newAABB = AxisAlignedBox(mWorldAABB);
                newAABB.transformAffine(mParentNode._getFullTransform().inverseAffine());
                
                // Merge calculated box with current AABB to preserve any user-set AABB
                mAABB.merge(newAABB);
            }
            
            mParentNode.needUpdate();
        }
    }
    
    /** This is used to turn on or off particle emission for this system.
        @remarks
            By default particle system is always emitting particles (if a emitters exists)
            and this can be used to stop the emission for all emitters. To turn it on again, 
            call it passing true.

            Note that this does not detach the particle system from the scene node, it will 
            still use some CPU.
        */
    void setEmitting(bool v)
    {
        mIsEmitting = v;
    }
    
    /** Returns true if the particle system emitting flag is turned on.
        @remarks
            This function will not actually return whether the particles are being emitted.
            It only returns the value of emitting flag.
        */
    bool getEmitting()
    {
        return mIsEmitting;
    }
    
    /// Override to return specific type flag
    override uint getTypeFlags()
    {
        return SceneManager.FX_TYPE_MASK;
    }
protected:

    static CmdCull msCullCmd;
    static CmdHeight msHeightCmd;
    static CmdMaterial msMaterialCmd;
    static CmdQuota msQuotaCmd;
    static CmdEmittedEmitterQuota msEmittedEmitterQuotaCmd;
    static CmdWidth msWidthCmd;
    static CmdRenderer msRendererCmd;
    static CmdSorted msSortedCmd;
    static CmdLocalSpace msLocalSpaceCmd;
    static CmdIterationInterval msIterationIntervalCmd;
    static CmdNonvisibleTimeout msNonvisibleTimeoutCmd;

    static this(){
    //this(){
        /// Command objects
        msCullCmd = new CmdCull;
        msHeightCmd = new CmdHeight;
        msMaterialCmd = new CmdMaterial;
        msQuotaCmd = new CmdQuota;
        msEmittedEmitterQuotaCmd = new CmdEmittedEmitterQuota;
        msWidthCmd = new CmdWidth;
        msRendererCmd = new CmdRenderer;
        msSortedCmd = new CmdSorted;
        msLocalSpaceCmd = new CmdLocalSpace;
        msIterationIntervalCmd = new CmdIterationInterval;
        msNonvisibleTimeoutCmd = new CmdNonvisibleTimeout;

        mRadixSorter = new RadixSort!(ActiveParticleList, Particle, float);
        //Cyclic dependency
        ParticleEmitter.initCmds();
    }
    
    AxisAlignedBox mAABB;
    Real mBoundingRadius;
    bool mBoundsAutoUpdate;
    Real mBoundsUpdateTime;
    Real mUpdateRemainTime;
    
    /// World AABB, only used to compare world-space positions to calc bounds
    AxisAlignedBox mWorldAABB;
    
    /// Name of the resource group to use to load materials
    string mResourceGroupName;
    /// Name of the material to use
    string mMaterialName;
    /// Have we set the material etc on the renderer?
    bool mIsRendererConfigured;
    /// Pointer to the material to use
    SharedPtr!Material mMaterial;
    /// Default width of each particle
    Real mDefaultWidth;
    /// Default height of each particle
    Real mDefaultHeight;
    /// Speed factor
    Real mSpeedFactor;
    /// Iteration interval
    Real mIterationInterval;
    /// Iteration interval set? Otherwise track default
    bool mIterationIntervalSet;
    /// Particles sorted according to camera?
    bool mSorted;
    /// Particles in local space?
    bool mLocalSpace;
    /// Update timeout when nonvisible (0 for no timeout)
    Real mNonvisibleTimeout;
    /// Update timeout when nonvisible set? Otherwise track default
    bool mNonvisibleTimeoutSet;
    /// Amount of time non-visible so far
    Real mTimeSinceLastVisible;
    /// Last frame in which known to be visible
    ulong mLastVisibleFrame;
    /// Controller for time update
    Controller!Real mTimeController;
    /// Indication whether the emitted emitter pool (= pool with particle emitters that are emitted) is initialised
    bool mEmittedEmitterPoolInitialised;
    /// Used to control if the particle system should emit particles or not.
    bool mIsEmitting;
    
    //typedef list<Particle*>::type ActiveParticleList;
    //typedef list<Particle*>::type FreeParticleList;
    //typedef vector<Particle*>::type ParticlePool;

    alias Particle[] ActiveParticleList;
    alias Particle[] FreeParticleList;
    alias Particle[] ParticlePool;
    /** Sort by direction functor */
    struct SortByDirectionFunctor
    {
        /// Direction to sort in
        Vector3 sortDir;
        
        this(Vector3 dir)
        {
            sortDir = dir;
        }
        float opCall(ref Particle p)
        {
            return sortDir.dotProduct(p.position);
        }
    }
    
    /** Sort by distance functor */
    struct SortByDistanceFunctor
    {
        /// Position to sort in
        Vector3 sortPos;
        
        this(Vector3 pos)
        {
            sortPos = pos;
        }
        float opCall(ref Particle p)
        {
            // Sort descending by squared distance
            return - (sortPos - p.position).squaredLength();
        }
    }
    
    static RadixSort!(ActiveParticleList, Particle, float) mRadixSorter;

    /** Active particle list.
            @remarks
                This is a linked list of pointers to particles in the particle pool.
            @par
                This allows very fast insertions and deletions from anywhere in 
                the list to activate / deactivate particles as well as reuse of 
                Particle instances in the pool without.keys) & destruction 
                which avoids memory thrashing.
        */
    ActiveParticleList mActiveParticles;
    
    /** Free particle queue.
            @remarks
                This contains a list of the particles free for use as new instances
                as required by the set. Particle instances are preconstructed up 
                to the estimated size in the mParticlePool vector and are 
                referenced on this deque at startup. As they get used this list
                reduces, as they get released back to to the set they get added
                back to the list.
        */
    FreeParticleList mFreeParticles;
    
    /** Pool of particle instances for use and reuse in the active particle list.
            @remarks
                This vector will be preallocated with the estimated size of the set,and will extend as required.
        */
    ParticlePool mParticlePool;
    
    //typedef list<ParticleEmitter*>::type FreeEmittedEmitterList;
    //typedef list<ParticleEmitter*>::type ActiveEmittedEmitterList;
    //typedef vector<ParticleEmitter*>::type EmittedEmitterList;
    //typedef map<string, FreeEmittedEmitterList>::type FreeEmittedEmitterMap;
    //typedef map<string, EmittedEmitterList>::type EmittedEmitterPool;

    alias ParticleEmitter[] FreeEmittedEmitterList;
    alias ParticleEmitter[] ActiveEmittedEmitterList;
    alias ParticleEmitter[] EmittedEmitterList;
    alias FreeEmittedEmitterList[string] FreeEmittedEmitterMap;
    alias EmittedEmitterList[string] EmittedEmitterPool;
    
    /** Pool of emitted emitters for use and reuse in the active emitted emitter list.
        @remarks
            The emitters in this pool act as particles and as emitters. The pool is a map containing lists 
            of emitters, identified by their name.
        @par
            The emitters in this pool are cloned using emitters that are kept in the main emitter list
            of the ParticleSystem.
        */
    EmittedEmitterPool mEmittedEmitterPool;
    
    /** Free emitted emitter list.
            @remarks
                This contains a list of the emitters free for use as new instances as required by the set.
        */
    FreeEmittedEmitterMap mFreeEmittedEmitters;
    
    /** Active emitted emitter list.
            @remarks
                This is a linked list of pointers to emitters in the emitted emitter pool.
                Emitters that are used are stored (their pointers) in both the list with active particles and in 
                the list with active emitted emitters.        */
    ActiveEmittedEmitterList mActiveEmittedEmitters;
    
    //typedef vector<ParticleEmitter*>::type ParticleEmitterList;
    //typedef vector<ParticleAffector*>::type ParticleAffectorList;

    alias ParticleEmitter[] ParticleEmitterList;
    alias ParticleAffector[] ParticleAffectorList;

    /// List of particle emitters, ie sources of particles
    ParticleEmitterList mEmitters;
    /// List of particle affectors, ie modifiers of particles
    ParticleAffectorList mAffectors;
    
    /// The renderer used to render this particle system
    ParticleSystemRenderer mRenderer;
    
    /// Do we cull each particle individually?
    bool mCullIndividual;
    
    /// The name of the type of renderer used to render this system
    string mRendererType;
    
    /// The number of particles in the pool.
    size_t mPoolSize;
    
    /// The number of emitted emitters in the pool.
    size_t mEmittedEmitterPoolSize;
    
    /// Optional origin of this particle system (eg script name)
    string mOrigin;
    
    /// Default iteration interval
    static Real msDefaultIterationInterval = 0;
    /// Default nonvisible update timeout
    static Real msDefaultNonvisibleTimeout = 0;
    
    /** Internal method used to expire dead particles. */
    void _expire(Real timeElapsed)
    {
        Particle pParticle;
        ParticleEmitter pParticleEmitter;

        for (size_t i = 0; i < mActiveParticles.length; /* nothing */)
        {
            pParticle = mActiveParticles[i];
            if (pParticle.timeToLive < timeElapsed)
            {
                // Notify renderer
                mRenderer._notifyParticleExpired(pParticle);
                
                // Identify the particle type
                if (pParticle.particleType == Particle.ParticleType.Visual)
                {
                    // Destroy this one
                    //mFreeParticles.splice(mFreeParticles.end(), mActiveParticles, i++);
                    mFreeParticles.insert(pParticle);
                    mActiveParticles.removeFromArrayIdx(i);
                }
                else
                {
                    // For now, it can only be an emitted emitter
                    pParticleEmitter = cast(ParticleEmitter)pParticle;
                    auto fee = findFreeEmittedEmitter(pParticleEmitter.getName());
                    (*fee).insert(pParticleEmitter);
                    
                    // Also erase from mActiveEmittedEmitters
                    removeFromActiveEmittedEmitters (pParticleEmitter);
                    
                    // And erase from mActiveParticles
                    //i = mActiveParticles.erase( i );
                    mActiveParticles.removeFromArrayIdx(i);
                }
            }
            else
            {
                // Decrement TTL
                pParticle.timeToLive -= timeElapsed;
                ++i;
            }
            
        }
    }
    
    /** Spawn new particles based on free quota and emitter requirements. */
    void _triggerEmitters(Real timeElapsed)
    {
        // Add up requests for emission
        //static vector<unsigned>::type requested;
        //static vector<unsigned>::type emittedRequested;
        static uint[] requested; //TODO statics in method, leave or move?
        static uint[] emittedRequested;
        
        if( requested.length != mEmitters.length )
            requested.length = mEmitters.length;
        if( emittedRequested.length != mEmittedEmitterPoolSize)
            emittedRequested.length = mEmittedEmitterPoolSize;
        
        size_t totalRequested, emitterCount, emittedEmitterCount, i, emissionAllowed;
        
        //iEmitEnd = mEmitters.end();
        emitterCount = mEmitters.length;
        emittedEmitterCount=mActiveEmittedEmitters.length;
        //itActiveEnd=mActiveEmittedEmitters.end();
        emissionAllowed = mFreeParticles.length;
        totalRequested = 0;
        
        // Count up total requested emissions for regular emitters (and exclude the ones that are used as
        // a template for emitted emitters)
        //for (itEmit = mEmitters.begin(), i = 0; itEmit != iEmitEnd; ++itEmit, ++i)
        i = 0;
        foreach (itEmit; mEmitters)
        {
            if (!itEmit.isEmitted())
            {
                requested[i] = itEmit._getEmissionCount(timeElapsed);
                totalRequested += requested[i];
            }
            i++;
        }
        
        // Add up total requested emissions for (active) emitted emitters
        //for (itActiveEmit = mActiveEmittedEmitters.begin(), i=0; itActiveEmit != itActiveEnd; ++itActiveEmit, ++i)
        i = 0;
        foreach (itActiveEmit; mActiveEmittedEmitters)
        {
            emittedRequested[i] = itActiveEmit._getEmissionCount(timeElapsed);
            totalRequested += emittedRequested[i];
            i++;
        }
        
        // Check if the quota will be exceeded, if so reduce demand
        Real ratio =  1.0f;
        if (totalRequested > emissionAllowed)
        {
            // Apportion down requested values to allotted values
            ratio =  cast(Real)emissionAllowed / cast(Real)totalRequested;
            for (i = 0; i < emitterCount; ++i)
            {
                requested[i] = cast(uint)(requested[i] * ratio);
            }
            for (i = 0; i < emittedEmitterCount; ++i)
            {
                emittedRequested[i] = cast(uint)(emittedRequested[i] * ratio);
            }
        }
        
        // Emit
        // For each emission, apply a subset of the motion for the frame
        // this ensures an even distribution of particles when many are
        // emitted in a single frame
        i = 0;
        //for (itEmit = mEmitters.begin(), i = 0; itEmit != iEmitEnd; ++itEmit, ++i)
        foreach (itEmit; mEmitters)
        {
            // Trigger the emitters, but exclude the emitters that are already in the emitted emitters list; 
            // they are handled in a separate loop
            if (!itEmit.isEmitted())
                _executeTriggerEmitters (itEmit, requested[i], timeElapsed);
            i++;
        }
        
        // Do the same with all active emitted emitters
        i = 0;
        //for (itActiveEmit = mActiveEmittedEmitters.begin(), i = 0; itActiveEmit != mActiveEmittedEmitters.end(); ++itActiveEmit, ++i)
        foreach (itActiveEmit; mActiveEmittedEmitters)
        {
            _executeTriggerEmitters (itActiveEmit, emittedRequested[i], timeElapsed);
            i++;
        }
    }
    
    /** Helper function that actually performs the emission of particles
        */
    void _executeTriggerEmitters(ref ParticleEmitter emitter, uint requested, Real timeElapsed)
    {
        Real timePoint = 0.0f;
        
        
        // avoid any divide by zero conditions
        if(!requested) 
            return;
        
        Real timeInc = timeElapsed / requested;
        
        for (uint j = 0; j < requested; ++j)
        {
            // Create a new particle & init using emitter
            // The particle is a visual particle if the emit_emitter property of the emitter isn't set 
            Particle p;
            string  emitterName = emitter.getEmittedEmitter();
            if (emitterName is null)
                p = createParticle();
            else
                p = createEmitterParticle(emitterName);
            
            // Only continue if the particle was really created (not null)
            if (!p)
                return;
            
            emitter._initParticle(p);
            
            // Translate position & direction into world space
            if (!mLocalSpace)
            {
                p.position  = 
                    (mParentNode._getDerivedOrientation() *
                     (mParentNode._getDerivedScale() * p.position))
                        + mParentNode._getDerivedPosition();
                p.direction = 
                    (mParentNode._getDerivedOrientation() * p.direction);
            }
            
            // apply partial frame motion to this particle
            p.position += (p.direction * timePoint);
            
            // apply particle initialization by the affectors
            foreach (itAff; mAffectors)
                itAff._initParticle(p);
            
            // Increment time fragment
            timePoint += timeInc;
            
            if (p.particleType == Particle.ParticleType.Emitter)
            {
                // If the particle is an emitter, the position on the emitter side must also be initialised
                // Note, that position of the emitter becomes a position in worldspace if mLocalSpace is set 
                // to false (will this become a problem?)
                ParticleEmitter pParticleEmitter = cast(ParticleEmitter)p;
                pParticleEmitter.setPosition(p.position);
            }
            
            // Notify renderer
            mRenderer._notifyParticleEmitted(p);
        }
    }
    
    /** Updates existing particle based on their momentum. */
    void _applyMotion(Real timeElapsed)
    {
        ParticleEmitter pParticleEmitter;

        foreach (pParticle; mActiveParticles)
        {
            pParticle.position += (pParticle.direction * timeElapsed);
            
            if (pParticle.particleType == Particle.ParticleType.Emitter)
            {
                // If it is an emitter, the emitter position must also be updated
                // Note, that position of the emitter becomes a position in worldspace if mLocalSpace is set 
                // to false (will this become a problem?)
                pParticleEmitter = cast(ParticleEmitter)pParticle;
                pParticleEmitter.setPosition(pParticle.position);
            }
        }
        
        // Notify renderer
        mRenderer._notifyParticleMoved(mActiveParticles);
    }
    
    /** Applies the effects of affectors. */
    void _triggerAffectors(Real timeElapsed)
    {
        foreach (i; mAffectors)
        {
            i._affectParticles(this, timeElapsed);
        }
    }
    
    /** Sort the particles in the system **/
    void _sortParticles(ref Camera cam)
    {
        if (mRenderer)
        {
            SortMode sortMode = mRenderer._getSortMode();
            if (sortMode == SortMode.SM_DIRECTION)
            {
                Vector3 camDir = cam.getDerivedDirection();
                if (mLocalSpace)
                {
                    // transform the camera direction into local space
                    camDir = mParentNode._getDerivedOrientation().UnitInverse() * camDir;
                }
                auto s = SortByDirectionFunctor(- camDir);
                mRadixSorter.sort(mActiveParticles, s);
            }
            else if (sortMode == SortMode.SM_DISTANCE)
            {
                Vector3 camPos = cam.getDerivedPosition();
                if (mLocalSpace)
                {
                    // transform the camera position into local space
                    camPos = mParentNode._getDerivedOrientation().UnitInverse() *
                        (camPos - mParentNode._getDerivedPosition()) / mParentNode._getDerivedScale();
                }
                auto s = SortByDistanceFunctor(camPos);
                mRadixSorter.sort(mActiveParticles, s);
            }
        }
    }
    
    /** Resize the internal pool of particles. */
    void increasePool(size_t size)
    {
        size_t oldSize = mParticlePool.length;
        
        // Increase size
        //mParticlePool.reserve(size);
        mParticlePool.length = size;
        
        // Create new particles
        for( size_t i = oldSize; i < size; i++ )
        {
            mParticlePool[i] = new Particle();
        }
        
        if (mIsRendererConfigured)
        {
            createVisualParticles(oldSize, size);
        }
    }
    
    /** Resize the internal pool of emitted emitters.
            @remarks
                The pool consists of multiple vectors containing pointers to particle emitters. Increasing the 
                pool with size implies that the vectors are equally increased. The quota of emitted emitters is 
                defined on a particle system level and not on a particle emitter level. This is to prevent that
                the number of created emitters becomes too high; the quota is shared amongst the emitted emitters.
        */
    void increaseEmittedEmitterPool(size_t size)
    {
        // Don't proceed if the pool doesn't contain any keys of emitted emitters
        if (mEmittedEmitterPool.emptyAA())
            return;

        ParticleEmitter emitter;
        ParticleEmitter clonedEmitter;
        string name = null;
        EmittedEmitterList e = EmittedEmitterList.init;//TODO Allocates? Turn into a pointer then
        size_t maxNumberOfEmitters = size / mEmittedEmitterPool.length; // equally distribute the number for each emitted emitter list
        size_t oldSize = 0;
        
        // Run through mEmittedEmitterPool and search for every key (=name) its corresponding emitter in mEmitters
        foreach (name, ref e; mEmittedEmitterPool)
        {            
            // Search the correct emitter in the mEmitters vector
            emitter = null;
            foreach (emitterIterator; mEmitters)
            {
                emitter = emitterIterator;
                if (emitter && 
                    name !is null && 
                    name == emitter.getName())
                {       
                    // Found the right emitter, clone each emitter a number of times
                    oldSize = e.length;
                    for (size_t t = oldSize; t < maxNumberOfEmitters; ++t)
                    {
                        clonedEmitter = ParticleSystemManager.getSingleton()._createEmitter(emitter.getType(), this);
                        emitter.copyParametersTo(clonedEmitter);
                        clonedEmitter.setEmitted(emitter.isEmitted()); // is always 'true' by the way, but just in case
                        
                        // Initially deactivate the emitted emitter if duration/repeat_delay are set
                        if (clonedEmitter.getDuration() > 0.0f && 
                            (clonedEmitter.getRepeatDelay() > 0.0f || clonedEmitter.getMinRepeatDelay() > 0.0f || clonedEmitter.getMinRepeatDelay() > 0.0f))
                            clonedEmitter.setEnabled(false);
                        
                        // Add cloned emitters to the pool
                        e.insert(clonedEmitter);
                    }
                }
            }
        }
    }
    
    /** Internal method for initialising string interface. */
    void initParameters()
    {
        if (createParamDictionary("ParticleSystem"))
        {
            ParamDictionary dict = getParamDictionary();
            
            dict.addParameter(new ParameterDef("quota", 
                                               "The maximum number of particles allowed at once in this system.",
                                               ParameterType.PT_UNSIGNED_INT),
                               msQuotaCmd);
            
            dict.addParameter(new ParameterDef("emit_emitter_quota", 
                                               "The maximum number of emitters to be emitted at once in this system.",
                                               ParameterType.PT_UNSIGNED_INT),
                               msEmittedEmitterQuotaCmd);
            
            dict.addParameter(new ParameterDef("material", 
                                               "The name of the material to be used to render all particles in this system.",
                                               ParameterType.PT_STRING),
                               msMaterialCmd);
            
            dict.addParameter(new ParameterDef("particle_width", 
                                               "The width of particles in world units.",
                                               ParameterType.PT_REAL),
                               msWidthCmd);
            
            dict.addParameter(new ParameterDef("particle_height", 
                                               "The height of particles in world units.",
                                               ParameterType.PT_REAL),
                               msHeightCmd);
            
            dict.addParameter(new ParameterDef("cull_each", 
                                               "If true, each particle is culled in it's own right. If false, the entire system is culled as a whole.",
                                               ParameterType.PT_BOOL),
                               msCullCmd);
            
            dict.addParameter(new ParameterDef("renderer", 
                                               "Sets the particle system renderer to use (default 'billboard').",
                                               ParameterType.PT_STRING),
                               msRendererCmd);
            
            dict.addParameter(new ParameterDef("sorted", 
                                               "Sets whether particles should be sorted relative to the camera. ",
                                               ParameterType.PT_BOOL),
                               msSortedCmd);
            
            dict.addParameter(new ParameterDef("local_space", 
                                               "Sets whether particles should be kept in local space rather than " ~
                                               "emitted into world space. ",
                                               ParameterType.PT_BOOL),
                               msLocalSpaceCmd);
            
            dict.addParameter(new ParameterDef("iteration_interval", 
                                               "Sets a fixed update interval for the system, or 0 for the frame rate. ",
                                               ParameterType.PT_REAL),
                               msIterationIntervalCmd);
            
            dict.addParameter(new ParameterDef("nonvisible_update_timeout", 
                                               "Sets a timeout on updates to the system if the system is not visible " ~
                                               "for the given number of seconds (0 to always update)",
                                               ParameterType.PT_REAL),
                               msNonvisibleTimeoutCmd);
            
        }
    }
    
    /** Internal method to configure the renderer. */
    void configureRenderer()
    {
        // Actual allocate particles
        size_t currSize = mParticlePool.length;
        size_t size = mPoolSize;
        if( currSize < size )
        {
            this.increasePool(size);
            
            for( size_t i = currSize; i < size; ++i )
            {
                // Add new items to the queue
                mFreeParticles.insert( mParticlePool[i] );
            }
            
            // Tell the renderer, if already configured
            if (mRenderer && mIsRendererConfigured)
            {
                mRenderer._notifyParticleQuota(size);
            }
        }
        
        if (mRenderer && !mIsRendererConfigured)
        {
            mRenderer._notifyParticleQuota(mParticlePool.length);
            mRenderer._notifyAttached(mParentNode, mParentIsTagPoint);
            mRenderer._notifyDefaultDimensions(mDefaultWidth, mDefaultHeight);
            createVisualParticles(0, mParticlePool.length);
            SharedPtr!Material mat = MaterialManager.getSingleton().load(
                mMaterialName, mResourceGroupName);
            mRenderer._setMaterial(mat);
            if (mRenderQueueIDSet)
                mRenderer.setRenderQueueGroup(mRenderQueueID);
            mRenderer.setKeepParticlesInLocalSpace(mLocalSpace);
            mIsRendererConfigured = true;
        }
    }
    
    /// Internal method for creating ParticleVisualData instances for the pool
    void createVisualParticles(size_t poolstart, size_t poolend)
    {
        //std::advance(i, poolstart);
        //std::advance(iend, poolend);
        foreach (i; mParticlePool[poolstart..poolend]) //TODO inclusive?
        {
            i._notifyVisualData(
                mRenderer._createVisualData());
        }
    }
    /// Internal method for destroying ParticleVisualData instances for the pool
    void destroyVisualParticles(size_t poolstart, size_t poolend)
    {
        foreach (i; mParticlePool[poolstart..poolend]) //TODO inclusive?
        {
            mRenderer._destroyVisualData(i.getVisualData());
            i._notifyVisualData(null);
        }
    }
    
    /** Create a pool of emitted emitters and assign them to the free emitter list.
            @remarks
                The emitters in the pool are grouped by name. This name is the name of the base emitter in the
                main list with particle emitters, which forms the template of the created emitted emitters.
        */
    void initialiseEmittedEmitters()
    {
        // Initialise the pool if needed
        size_t currSize = 0;
        if (mEmittedEmitterPool.emptyAA())
        {
            if (mEmittedEmitterPoolInitialised)
            {
                // It was already initialised, but apparently no emitted emitters were used
                return;
            }
            else
            {
                initialiseEmittedEmitterPool();
            }
        }
        else
        {
            foreach (k,v; mEmittedEmitterPool)
            {
                currSize += v.length;
            }
        }
        
        size_t size = mEmittedEmitterPoolSize;
        if( currSize < size && !mEmittedEmitterPool.emptyAA())
        {
            // Increase the pool. Equally distribute over all vectors in the map
            increaseEmittedEmitterPool(size);
            
            // Add new items to the free list
            addFreeEmittedEmitters();
        }
    }
    
    /** Determine which emitters in the Particle Systems main emitter become a template for creating an
            pool of emitters that can be emitted.
        */
    void initialiseEmittedEmitterPool()
    {
        if (mEmittedEmitterPoolInitialised)
            return;
        
        // Run through mEmitters and add keys to the pool
        //ParticleEmitter emitter = null;
        //ParticleEmitter emitterInner = null;
        foreach (emitter; mEmitters)
        {
            // Determine the names of all emitters that are emitted
            //emitter = *emitterIterator ;
            if (emitter && emitter.getEmittedEmitter() !is null)
            {
                // This one will be emitted, register its name and leave the vector empty!
                //EmittedEmitterList empty;
                mEmittedEmitterPool[emitter.getEmittedEmitter()] = null;
            }
            
            // Determine whether the emitter itself will be emitted and set the 'mEmitted' attribute
            foreach (emitterInner; mEmitters)
            {
                if (emitter && 
                    emitterInner && 
                    emitter.getName() !is null && 
                    emitter.getName() == emitterInner.getEmittedEmitter())
                {
                    emitter.setEmitted(true);
                    break;
                }
                else if(emitter)
                {
                    // Set explicitly to 'false' although the default value is already 'false'
                    emitter.setEmitted(false);
                }
            }
        }
        
        mEmittedEmitterPoolInitialised = true;
    }
    
    /** Add  emitters from the pool to the free emitted emitter queue. */
    void addFreeEmittedEmitters()
    {
        // Don't proceed if the EmittedEmitterPool is empty
        if (mEmittedEmitterPool.emptyAA())
            return;
        
        // Copy all pooled emitters to the free list
        EmittedEmitterList emittedEmitters;
        //list<ParticleEmitter*>::type* fee = 0;
        ParticleEmitter[]* fee;
        string name;
        
        // Run through the emittedEmitterPool map
        foreach (name, ref emittedEmitters; mEmittedEmitterPool)
        {
            fee = findFreeEmittedEmitter(name);
            
            // If its not in the map, create an empty one
            if (fee is null)
            {
                //FreeEmittedEmitterList empty;
                mFreeEmittedEmitters[name] = null;//use null to initalize AA
                fee = &mFreeEmittedEmitters[name];//findFreeEmittedEmitter(name);
            }
            
            // Check anyway if its ok now
            if (fee is null)
                return; // forget it!
            
            // Add all emitted emitters from the pool to the free list
            foreach(emittedEmitterIterator; emittedEmitters)
            {
                (*fee).insert(emittedEmitterIterator);
            }
        }
    }
    
    /** Removes all emitted emitters from this system.  */
    void removeAllEmittedEmitters()
    {
        foreach (k, e; mEmittedEmitterPool)
        {
            foreach (i; e)
            {
                ParticleSystemManager.getSingleton()._destroyEmitter(i);
            }
            //TODO just mEmittedEmitterPool.clear() probably enough
            mEmittedEmitterPool[k].clear();
        }
        
        // Don't leave any references behind
        mEmittedEmitterPool.clear();
        mFreeEmittedEmitters.clear();
        mActiveEmittedEmitters.clear();
    }
    
    /** Find the list with free emitted emitters.
            @param name The name that identifies the list with free emitted emitters.
        */
    FreeEmittedEmitterList *findFreeEmittedEmitter (string name)
    {
        auto it = name in mFreeEmittedEmitters;
        if (it !is null)
        {
            // Found it
            return it;
        }

        return null;
    }
    
    /** Removes an emitter from the active emitted emitter list.
            @remarks
                The emitter will not be destroyed!
            @param emitter Pointer to a particle emitter.
        */
    void removeFromActiveEmittedEmitters (ref ParticleEmitter emitter)
    {
        assert(emitter, "Emitter to be removed is 0!");

        foreach (itActiveEmit; mActiveEmittedEmitters)
        {
            if (emitter == itActiveEmit)
            {
                mActiveEmittedEmitters.removeFromArray(emitter);
                break;
            }
        }
    }
    
    /** Moves all emitted emitters from the active list to the free list
            @remarks
                The active emitted emitter list will not be cleared and still keeps references to the emitters!
        */
    void addActiveEmittedEmittersToFreeList ()
    {
        foreach (itActiveEmit; mActiveEmittedEmitters)
        {
            auto fee = findFreeEmittedEmitter (itActiveEmit.getName());
            if (fee !is null)
                (*fee).insert(itActiveEmit);
        }
    }
    
    /** This function clears all data structures that are used in combination with emitted emitters and
            sets the flag to indicate that the emitted emitter pool must be initialised again.
            @remarks
                This function should be called if new emitters are added to a ParticleSystem or deleted from a
                ParticleSystem. The emitted emitter data structures become out of sync and need to be build up
                again. The data structures are not reorganised in this function, but by setting a flag, 
                they are rebuild in the regular process flow.
        */
    void _notifyReorganiseEmittedEmitterData ()
    {
        removeAllEmittedEmitters();
        mEmittedEmitterPoolInitialised = false; // Don't rearrange immediately; it will be performed in the regular flow
    }
}
/** @} */
/** @} */