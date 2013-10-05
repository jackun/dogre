module ogre.effects.particleemitter;

import std.algorithm;
import std.range;
//import std.container;
import std.conv;
import std.string;

import ogre.math.vector;
import ogre.effects.particlesystem;
import ogre.compat;
import ogre.general.common;
import ogre.math.angles;
import ogre.math.maths;
import ogre.general.colourvalue;
import ogre.general.generals;
import ogre.effects.particle;
import ogre.strings;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */

class EmitterCommands
{
    /// Command object for ParticleEmitter  - see ParamCommand 
    static class CmdAngle : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getAngle() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setAngle(StringConverter.parseAngle(val,Radian(0)));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdColour : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getColour() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setColour(StringConverter.parseColourValue(val));
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdColourRangeStart : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getColourRangeStart() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setColourRangeStart(StringConverter.parseColourValue(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdColourRangeEnd : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getColourRangeEnd() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setColourRangeEnd(StringConverter.parseColourValue(val));
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdDirection : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getDirection() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setDirection(StringConverter.parseVector3(val));
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdUp : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getUp() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setUp(StringConverter.parseVector3(val));
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdDirPositionRef : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            auto val = Vector4( (cast(ParticleEmitter)target).getDirPositionReference() );
            val.w = (cast(ParticleEmitter)target).getDirPositionReferenceEnabled();
            return val.toString();
        }
        void doSet(Object target,string val)
        {
           Vector4 parsed = StringConverter.parseVector4(val);
            auto vPos = Vector3( parsed.x, parsed.y, parsed.z );
            (cast(ParticleEmitter)target).setDirPositionReference( vPos, parsed.w != 0 );
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdEmissionRate : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getEmissionRate() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setEmissionRate(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdVelocity : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getParticleVelocity() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setParticleVelocity(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMinVelocity : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMinParticleVelocity() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMinParticleVelocity(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMaxVelocity : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMaxParticleVelocity() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMaxParticleVelocity(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdTTL : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getTimeToLive() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setTimeToLive(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMinTTL : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMinTimeToLive() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMinTimeToLive(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMaxTTL : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMaxTimeToLive() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMaxTimeToLive(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdPosition : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getPosition() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setPosition(StringConverter.parseVector3(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdDuration : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getDuration() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setDuration(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMinDuration : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMinDuration() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMinDuration(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMaxDuration : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMaxDuration() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMaxDuration(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdRepeatDelay : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getRepeatDelay() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setRepeatDelay(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMinRepeatDelay : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMinRepeatDelay() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMinRepeatDelay(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdMaxRepeatDelay : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(ParticleEmitter)target).getMaxRepeatDelay() );
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setMaxRepeatDelay(std.conv.to!Real(val));
        }
    }
    /// Command object for particle emitter  - see ParamCommand
    static class CmdName : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return 
                (cast(ParticleEmitter)target).getName();
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setName(val);
        }
    }
    
    /// Command object for particle emitter  - see ParamCommand 
    static class CmdEmittedEmitter : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return 
                (cast(ParticleEmitter)target).getEmittedEmitter();
        }
        void doSet(Object target,string val)
        {
            (cast(ParticleEmitter)target).setEmittedEmitter(val);
        }
    }
}
    

/** Abstract class defining the interface to be implemented by particle emitters.
    @remarks
        Particle emitters are the sources of particles in a particle system. 
        This class defines the ParticleEmitter interface, and provides a basic implementation 
        for tasks which most emitters will do (these are of course overridable).
        Particle emitters can be  grouped into types, e.g. 'point' emitters, 'box' emitters etc; each type will 
        create particles with a different starting point, direction and velocity (although
        within the types you can configure the ranges of these parameters). 
    @par
        Because there are so many types of emitters you could use, OGRE chooses not to dictate
        the available types. It comes with some in-built, but allows plugins or applications to extend the emitter types available.
        This is done by subclassing ParticleEmitter to have the appropriate emission behaviour you want,
        and also creating a subclass of ParticleEmitterFactory which is responsible for creating instances 
        of your new emitter type. You register this factory with the ParticleSystemManager using
        addEmitterFactory, and from then on emitters of this type can be created either from code or through
        text particle scripts by naming the type.
    @par
        This same approach is used for ParticleAffectors (which modify existing particles per frame).
        This means that OGRE is particularly flexible when it comes to creating particle system effects,
        with literally infinite combinations of emitter and affector types, and parameters within those
        types.
    */
class ParticleEmitter : Particle, StringInterface
{
    mixin StringInterfaceTmpl;
protected:

    /*static string GenCmds()
    {
        string[] cmds = ["CmdAngle", "CmdColour", "CmdColourRangeStart", "CmdColourRangeEnd", "CmdDirection", "CmdUp", "CmdDirPositionRef", 
                         "CmdEmissionRate", "CmdMaxTTL", "CmdMaxVelocity", "CmdMinTTL", "CmdMinVelocity", "CmdPosition", "CmdTTL", 
                         "CmdVelocity", "CmdDuration", "CmdMinDuration", "CmdMaxDuration", "CmdRepeatDelay", "CmdMinRepeatDelay", 
                         "CmdMaxRepeatDelay", "CmdName", "CmdEmittedEmitter"];
        string cmdStr;
        foreach(cmd; cmds)
        {
            //static EmitterCommands.CmdAngle msAngleCmd = new EmitterCommands.CmdAngle;
            cmdStr ~= "static EmitterCommands." ~ cmd ~ " ms" ~ cmd[3..$] ~ " = new EmitterCommands." ~ cmd ~ ";";
        }
        return cmdStr;
    }*/

    //static this()
    package static void initCmds()
    {
        // Command object for setting / getting parameters
        //mixin(GenCmds());//XXX just a test
        
        msAngleCmd = new EmitterCommands.CmdAngle;
        msColourCmd = new EmitterCommands.CmdColour;
        msColourRangeStartCmd = new EmitterCommands.CmdColourRangeStart;
        msColourRangeEndCmd = new EmitterCommands.CmdColourRangeEnd;
        msDirectionCmd = new EmitterCommands.CmdDirection;
        msUpCmd = new EmitterCommands.CmdUp;
        msDirPositionRefCmd = new EmitterCommands.CmdDirPositionRef;
        msEmissionRateCmd = new EmitterCommands.CmdEmissionRate;
        msMaxTTLCmd = new EmitterCommands.CmdMaxTTL;
        msMaxVelocityCmd = new EmitterCommands.CmdMaxVelocity;
        msMinTTLCmd = new EmitterCommands.CmdMinTTL;
        msMinVelocityCmd = new EmitterCommands.CmdMinVelocity;
        msPositionCmd = new EmitterCommands.CmdPosition;
        msTTLCmd = new EmitterCommands.CmdTTL;
        msVelocityCmd = new EmitterCommands.CmdVelocity;
        msDurationCmd = new EmitterCommands.CmdDuration;
        msMinDurationCmd = new EmitterCommands.CmdMinDuration;
        msMaxDurationCmd = new EmitterCommands.CmdMaxDuration;
        msRepeatDelayCmd = new EmitterCommands.CmdRepeatDelay;
        msMinRepeatDelayCmd = new EmitterCommands.CmdMinRepeatDelay;
        msMaxRepeatDelayCmd = new EmitterCommands.CmdMaxRepeatDelay;
        msNameCmd = new EmitterCommands.CmdName;
        msEmittedEmitterCmd = new EmitterCommands.CmdEmittedEmitter;
    }
    
    static EmitterCommands.CmdAngle msAngleCmd;// = new EmitterCommands.CmdAngle;
    static EmitterCommands.CmdColour msColourCmd;// = new EmitterCommands.CmdColour;
    static EmitterCommands.CmdColourRangeStart msColourRangeStartCmd;// = new EmitterCommands.CmdColourRangeStart;
    static EmitterCommands.CmdColourRangeEnd msColourRangeEndCmd;// = new EmitterCommands.CmdColourRangeEnd;
    static EmitterCommands.CmdDirection msDirectionCmd;// = new EmitterCommands.CmdDirection;
    static EmitterCommands.CmdUp msUpCmd;// = new EmitterCommands.CmdUp;
    static EmitterCommands.CmdDirPositionRef msDirPositionRefCmd;// = new EmitterCommands.CmdDirPositionRef;
    static EmitterCommands.CmdEmissionRate msEmissionRateCmd;// = new EmitterCommands.CmdEmissionRate;
    static EmitterCommands.CmdMaxTTL msMaxTTLCmd;// = new EmitterCommands.CmdMaxTTL;
    static EmitterCommands.CmdMaxVelocity msMaxVelocityCmd;// = new EmitterCommands.CmdMaxVelocity;
    static EmitterCommands.CmdMinTTL msMinTTLCmd;// = new EmitterCommands.CmdMinTTL;
    static EmitterCommands.CmdMinVelocity msMinVelocityCmd;// = new EmitterCommands.CmdMinVelocity;
    static EmitterCommands.CmdPosition msPositionCmd;// = new EmitterCommands.CmdPosition;
    static EmitterCommands.CmdTTL msTTLCmd;// = new EmitterCommands.CmdTTL;
    static EmitterCommands.CmdVelocity msVelocityCmd;// = new EmitterCommands.CmdVelocity;
    static EmitterCommands.CmdDuration msDurationCmd;// = new EmitterCommands.CmdDuration;
    static EmitterCommands.CmdMinDuration msMinDurationCmd;// = new EmitterCommands.CmdMinDuration;
    static EmitterCommands.CmdMaxDuration msMaxDurationCmd;// = new EmitterCommands.CmdMaxDuration;
    static EmitterCommands.CmdRepeatDelay msRepeatDelayCmd;// = new EmitterCommands.CmdRepeatDelay;
    static EmitterCommands.CmdMinRepeatDelay msMinRepeatDelayCmd;// = new EmitterCommands.CmdMinRepeatDelay;
    static EmitterCommands.CmdMaxRepeatDelay msMaxRepeatDelayCmd;// = new EmitterCommands.CmdMaxRepeatDelay;
    static EmitterCommands.CmdName msNameCmd;// = new EmitterCommands.CmdName;
    static EmitterCommands.CmdEmittedEmitter msEmittedEmitterCmd;// = new EmitterCommands.CmdEmittedEmitter;
    
    
    /// Parent particle system
    ParticleSystem mParent;
    /// Position relative to the center of the ParticleSystem
    Vector3 mPosition;
    /// Rate in particles per second at which this emitter wishes to emit particles
    Real mEmissionRate;
    /// Name of the type of emitter, MUST be initialised by subclasses
    string mType;
    /// Base direction of the emitter, may not be used by some emitters
    Vector3 mDirection;
    // Notional up vector, used to speed up generation of variant directions, and also to orient some emitters.
    Vector3 mUp;
    // When true, mDirPositionRef is used instead of mDirection to generate particles
    bool mUseDirPositionRef;
    // Center position to tell in which direction will particles be emitted according to their position,
    // usefull for explosions & implosions, some emitters (i.e. point emitter) may not need it.
    Vector3 mDirPositionRef;
    /// Angle around direction which particles may be emitted, internally radians but angleunits for interface
    Radian mAngle;
    /// Min speed of particles
    Real mMinSpeed;
    /// Max speed of particles
    Real mMaxSpeed;
    /// Initial time-to-live of particles (min)
    Real mMinTTL;
    /// Initial time-to-live of particles (max)
    Real mMaxTTL;
    /// Initial colour of particles (range start)
    ColourValue mColourRangeStart;
    /// Initial colour of particles (range end)
    ColourValue mColourRangeEnd;
    
    /// Whether this emitter is currently enabled (defaults to true)
    bool mEnabled;
    
    /// Start time (in seconds from start of first call to ParticleSystem to update)
    Real mStartTime;
    /// Minimum length of time emitter will run for (0 = forever)
    Real mDurationMin;
    /// Maximum length of time the emitter will run for (0 = forever)
    Real mDurationMax;
    /// Current duration remainder
    Real mDurationRemain;
    
    /// Time between each repeat
    Real mRepeatDelayMin;
    Real mRepeatDelayMax;
    /// Repeat delay left
    Real mRepeatDelayRemain;
    
    // Fractions of particles wanted to be emitted last time
    Real mRemainder;
    
    /// The name of the emitter. The name is optional unless it is used as an emitter that is emitted itself.
    string mName;
    
    /// The name of the emitter to be emitted (optional)
    string mEmittedEmitter;
    
    // If 'true', this emitter is emitted by another emitter.
    // NB. That doesn't imply that the emitter itself emits other emitters (that could or could not be the case)
    bool mEmitted;
    
    // NB Method below here are to help out people implementing emitters by providing the
    // most commonly used approaches as piecemeal methods
    
    /** Internal utility method for generating particle exit direction
        @param destVector Reference to vector to complete with new direction (normalised)
        */
    void genEmissionDirection(ref Vector3 particlePos, ref Vector3 destVector )
    {
        if( mUseDirPositionRef )
        {
            Vector3 particleDir = particlePos - mDirPositionRef;
            particleDir.normalise();
            
            if (mAngle != Radian(0))
            {
                // Randomise angle
                Radian angle = Math.UnitRandom() * mAngle;
                
                // Randomise direction
                destVector = particleDir.randomDeviant( angle );
            }
            else
            {
                // Constant angle
                destVector = particleDir.normalisedCopy();
            }
        }
        else
        {
            if (mAngle != Radian(0))
            {
                // Randomise angle
                Radian angle = Math.UnitRandom() * mAngle;
                
                // Randomise direction
                destVector = mDirection.randomDeviant(angle, mUp);
            }
            else
            {
                // Constant angle
                destVector = mDirection;
            }
        }
        
        // Don't normalise, we can assume that it will still be a unit vector since
        // both direction and 'up' are.
    }
    
    /** Internal utility method to apply velocity to a particle direction.
        @param destVector The vector to scale by a randomly generated scale between min and max speed.
            Assumed normalised already, and likely already oriented in the right direction.
        */
    void genEmissionVelocity(ref Vector3 destVector)
    {
        Real scalar;
        if (mMinSpeed != mMaxSpeed)
        {
            scalar = mMinSpeed + (Math.UnitRandom() * (mMaxSpeed - mMinSpeed));
        }
        else
        {
            scalar = mMinSpeed;
        }
        
        destVector *= scalar;
    }
    
    /** Internal utility method for generating a time-to-live for a particle. */
    Real genEmissionTTL()
    {
        if (mMaxTTL != mMinTTL)
        {
            return mMinTTL + (Math.UnitRandom() * (mMaxTTL - mMinTTL));
        }
        else
        {
            return mMinTTL;
        }
    }
    
    /** Internal utility method for generating a colour for a particle. */
    void genEmissionColour(ref ColourValue destColour)
    {
        if (mColourRangeStart != mColourRangeEnd)
        {
            // Randomise
            //Real t = Math.UnitRandom();
            destColour.r = mColourRangeStart.r + (Math.UnitRandom() * (mColourRangeEnd.r - mColourRangeStart.r));
            destColour.g = mColourRangeStart.g + (Math.UnitRandom() * (mColourRangeEnd.g - mColourRangeStart.g));
            destColour.b = mColourRangeStart.b + (Math.UnitRandom() * (mColourRangeEnd.b - mColourRangeStart.b));
            destColour.a = mColourRangeStart.a + (Math.UnitRandom() * (mColourRangeEnd.a - mColourRangeStart.a));
        }
        else
        {
            destColour = mColourRangeStart;
        }
    }
    
    /** Internal utility method for generating an emission count based on a constant emission rate. */
    ushort genConstantEmissionCount(Real timeElapsed)
    {
        if (mEnabled)
        {
            // Keep fractions, otherwise a high frame rate will result in zero emissions!
            mRemainder += mEmissionRate * timeElapsed;
            ushort intRequest = cast(ushort)mRemainder;
            mRemainder -= intRequest;
            
            // Check duration
            if (mDurationMax)
            {
                mDurationRemain -= timeElapsed;
                if (mDurationRemain <= 0) 
                {
                    // Disable, duration is out (takes effect next time)
                    setEnabled(false);
                }
            }
            return intRequest;
        }
        else
        {
            // Check repeat
            if (mRepeatDelayMax)
            {
                mRepeatDelayRemain -= timeElapsed;
                if (mRepeatDelayRemain <= 0)
                {
                    // Enable, repeat delay is out (takes effect next time)
                    setEnabled(true);
                }
            }
            if(mStartTime)
            {
                mStartTime -= timeElapsed;
                if(mStartTime <= 0)
                {
                    setEnabled(true);
                    mStartTime = 0;
                }
            }
            return 0;
        }
        
    }
    
    /** Internal method for setting up the basic parameter definitions for a subclass. 
        @remarks
            Because stringInterface holds a dictionary of parameters per class, subclasses need to
            call this to ask the base class to add it's parameters to their dictionary as well.
            Can't do this in the constructor because that runs in a non-context.
        @par
            The subclass must have called it's own createParamDictionary before calling this method.
        */
    void addBaseParameters()
    {
        ParamDictionary dict = getParamDictionary();
        
        dict.addParameter(new ParameterDef("angle", 
                                        "The angle up to which particles may vary in their initial direction "
                                        "from the emitters direction, in degrees." , ParameterType.PT_REAL),
                           msAngleCmd);
        
        dict.addParameter(new ParameterDef("colour", 
                                        "The colour of emitted particles.", ParameterType.PT_COLOURVALUE),
                           msColourCmd);
        
        dict.addParameter(new ParameterDef("colour_range_start", 
                                        "The start of a range of colours to be assigned to emitted particles.", ParameterType.PT_COLOURVALUE),
                           msColourRangeStartCmd);
        
        dict.addParameter(new ParameterDef("colour_range_end", 
                                        "The end of a range of colours to be assigned to emitted particles.", ParameterType.PT_COLOURVALUE),
                           msColourRangeEndCmd);
        
        dict.addParameter(new ParameterDef("direction", 
                                        "The base direction of the emitter." , ParameterType.PT_VECTOR3),
                           msDirectionCmd);
        
        dict.addParameter(new ParameterDef("up", 
                                        "The up vector of the emitter." , ParameterType.PT_VECTOR3),
                           msUpCmd);
        
        dict.addParameter(new ParameterDef("direction_position_reference", 
                                        "The reference position to calculate the direction of emitted particles "
                                        "based on their position. Good for explosions and implosions (use negative velocity)" , ParameterType.PT_COLOURVALUE),
                           msDirPositionRefCmd);
        
        dict.addParameter(new ParameterDef("emission_rate", 
                                        "The number of particles emitted per second." , ParameterType.PT_REAL),
                           msEmissionRateCmd);
        
        dict.addParameter(new ParameterDef("position", 
                                        "The position of the emitter relative to the particle system center." , ParameterType.PT_VECTOR3),
                           msPositionCmd);
        
        dict.addParameter(new ParameterDef("velocity", 
                                        "The initial velocity to be assigned to every particle, in world units per second." , ParameterType.PT_REAL),
                           msVelocityCmd);
        
        dict.addParameter(new ParameterDef("velocity_min", 
                                        "The minimum initial velocity to be assigned to each particle." , ParameterType.PT_REAL),
                           msMinVelocityCmd);
        
        dict.addParameter(new ParameterDef("velocity_max", 
                                        "The maximum initial velocity to be assigned to each particle." , ParameterType.PT_REAL),
                           msMaxVelocityCmd);
        
        dict.addParameter(new ParameterDef("time_to_live", 
                                        "The lifetime of each particle in seconds." , ParameterType.PT_REAL),
                           msTTLCmd);
        
        dict.addParameter(new ParameterDef("time_to_live_min", 
                                        "The minimum lifetime of each particle in seconds." , ParameterType.PT_REAL),
                           msMinTTLCmd);
        
        dict.addParameter(new ParameterDef("time_to_live_max", 
                                        "The maximum lifetime of each particle in seconds." , ParameterType.PT_REAL),
                           msMaxTTLCmd);
        
        dict.addParameter(new ParameterDef("duration", 
                                        "The length of time in seconds which an emitter stays enabled for." , ParameterType.PT_REAL),
                           msDurationCmd);
        
        dict.addParameter(new ParameterDef("duration_min", 
                                        "The minimum length of time in seconds which an emitter stays enabled for." , ParameterType.PT_REAL),
                           msMinDurationCmd);
        
        dict.addParameter(new ParameterDef("duration_max", 
                                        "The maximum length of time in seconds which an emitter stays enabled for." , ParameterType.PT_REAL),
                           msMaxDurationCmd);
        
        dict.addParameter(new ParameterDef("repeat_delay", 
                                        "If set, after disabling an emitter will repeat (reenable) after this many seconds." , ParameterType.PT_REAL),
                           msRepeatDelayCmd);
        
        dict.addParameter(new ParameterDef("repeat_delay_min", 
                                        "If set, after disabling an emitter will repeat (reenable) after this minimum number of seconds." , ParameterType.PT_REAL),
                           msMinRepeatDelayCmd);
        
        dict.addParameter(new ParameterDef("repeat_delay_max", 
                                        "If set, after disabling an emitter will repeat (reenable) after this maximum number of seconds." , ParameterType.PT_REAL),
                           msMaxRepeatDelayCmd);
        
        dict.addParameter(new ParameterDef("name", 
                                        "This is the name of the emitter" , ParameterType.PT_STRING),
                           msNameCmd);
        
        dict.addParameter(new ParameterDef("emit_emitter", 
                                        "If set, this emitter will emit other emitters instead of visual particles" , ParameterType.PT_STRING),
                           msEmittedEmitterCmd);
    }
    
    /** Internal method for initialising the duration & repeat of an emitter. */
    void initDurationRepeat()
    {
        if (mEnabled)
        {
            if (mDurationMin == mDurationMax)
            {
                mDurationRemain = mDurationMin;
            }
            else
            {
                mDurationRemain = Math.RangeRandom(mDurationMin, mDurationMax);
            }
        }
        else
        {
            // Reset repeat
            if (mRepeatDelayMin == mRepeatDelayMax)
            {
                mRepeatDelayRemain = mRepeatDelayMin;
            }
            else
            {
                mRepeatDelayRemain = Math.RangeRandom(mRepeatDelayMax, mRepeatDelayMin);
            }
            
        }
    }
    
    
public:
    this(ParticleSystem psys)
    {
        //FIXME static ctor causes cyclic dependency error with ParticleSystem
        if(msAngleCmd is null)
            initCmds();

        mParent = psys;
        mUseDirPositionRef = false;
        mDirPositionRef = Vector3.ZERO;
        mStartTime = 0;
        mDurationMin = 0;
        mDurationMax = 0;
        mDurationRemain = 0;
        mRepeatDelayMin = 0;
        mRepeatDelayMax = 0;
        mRepeatDelayRemain = 0;

        // Reasonable defaults
        mAngle = 0;
        setDirection(Vector3.UNIT_X);
        mEmissionRate = 10;
        mMaxSpeed = mMinSpeed = 1;
        mMaxTTL = mMinTTL = 5;
        mPosition = Vector3.ZERO;
        mColourRangeStart = mColourRangeEnd = ColourValue.White;
        mEnabled = true;
        mRemainder = 0;
        mName = null;
        mEmittedEmitter = null;
        mEmitted = false;
    }
    /** destructor essential. */
    ~this() {}
    
    /** Sets the position of this emitter relative to the particle system center. */
    void setPosition(Vector3 pos)
    { 
        mPosition = pos; 
    }
    
    /** Returns the position of this emitter relative to the center of the particle system. */
   Vector3 getPosition()
    { 
        return mPosition; 
    }
    
    /** Sets the direction of the emitter.
        @remarks
            Most emitters will have a base direction in which they emit particles (those which
            emit in all directions will ignore this parameter). They may not emit exactly along this
            vector for every particle, many will introduce a random scatter around this vector using 
            the angle property.
        @note 
            This resets the up vector.
        @param direction
            The base direction for particles emitted.
        */
    void setDirection(Vector3 direction)
    { 
        mDirection = direction; 
        mDirection.normalise();
        // Generate a default up vector.
        mUp = mDirection.perpendicular();
        mUp.normalise();
    }
    
    /** Returns the base direction of the emitter. */
   Vector3 getDirection()
    { 
        return mDirection; 
    }
    
    /** Sets the notional up vector of the emitter
        @remarks
            Many emitters emit particles from within a region, and for some that region is not
            circularly symmetric about the emitter direction. The up vector allows such emitters
            to be orientated about the direction vector.
        @param up
            The base direction for particles emitted. It must be perpendicular to the direction vector.
        */
    void setUp(Vector3 up)
    {
        mUp = up; 
        mUp.normalise();
    }
    
    /** Returns the up vector of the emitter. */
   Vector3 getUp()
    { 
        return mUp; 
    }
    
    /** Sets the direction of the emitter.
            Some particle effects need to emit particles in many random directions, but still
            following some rules; like not having them collide against each other. Very useful
            for explosions and implosions (when velocity is negative)
        @note
            Although once enabled mDirPositionRef will supersede mDirection; calling setDirection()
            may still be needed to setup a custom up vector.
        @param position
            The reference position in which the direction of the particles will be calculated from,
            also taking into account the particle's position at the time of emission.
        @param enable
            True to use mDirPositionRef, false to use the default behaviour with mDirection
        */
    void setDirPositionReference(Vector3 position, bool enable )
    { 
        mUseDirPositionRef  = enable;
        mDirPositionRef     = position;
    }
    
    /** Returns the position reference to generate direction of emitted particles */
   Vector3 getDirPositionReference()
    {
        return mDirPositionRef;
    }
    
    /** Returns whether direction or position reference is used */
    bool getDirPositionReferenceEnabled()
    {
        return mUseDirPositionRef;
    }
    
    /** Sets the maximum angle away from the emitter direction which particle will be emitted.
        @remarks
            Whilst the direction property defines the general direction of emission for particles, 
            this property defines how far the emission angle can deviate away from this base direction.
            This allows you to create a scatter effect - if set to 0, all particles will be emitted
            exactly along the emitters direction vector, whereas if you set it to 180 degrees or more,
            particles will be emitted in a sphere, i.e. in all directions.
        @param angle
            Maximum angle which initial particle direction can deviate from the emitter base direction vector.
        */
    void setAngle(Radian angle)
    {
        // Store as radians for efficiency
        mAngle = angle;
    }
    
    /** Returns the maximum angle which the initial particle direction can deviate from the emitters base direction. */
   Radian getAngle()
    {
        return mAngle;
    }
    
    /** Sets the initial velocity of particles emitted.
        @remarks
            This method sets a constant speed for emitted particles. See the alternate version
            of this method which takes 2 parameters if you want a variable speed. 
        @param
            speed The initial speed in world units per second which every particle emitted starts with.
        */
    void setParticleVelocity(Real speed)
    {
        mMinSpeed = mMaxSpeed = speed;
    }
    
    
    /** Sets the initial velocity range of particles emitted.
        @remarks
            This method sets the range of starting speeds for emitted particles. 
            See the alternate version of this method which takes 1 parameter if you want a 
           ant speed. This emitter will randomly choose a speed between the minimum and 
            maximum for each particle.
        @param max The maximum speed in world units per second for the initial particle speed on emission.
        @param min The minimum speed in world units per second for the initial particle speed on emission.
        */
    void setParticleVelocity(Real min, Real max)
    {
        mMinSpeed = min;
        mMaxSpeed = max;
    }
    /** Returns the minimum particle velocity. */
    void setMinParticleVelocity(Real min)
    {
        mMinSpeed = min;
    }
    /** Returns the maximum particle velocity. */
    void setMaxParticleVelocity(Real max)
    {
        mMaxSpeed = max;
    }
    
    /** Returns the initial velocity of particles emitted. */
    Real getParticleVelocity()
    {
        return mMinSpeed;
    }

    /** Returns the minimum particle velocity. */
    Real getMinParticleVelocity()
    {
        return mMinSpeed;
    }

    /** Returns the maximum particle velocity. */
    Real getMaxParticleVelocity()
    {
        return mMaxSpeed;
    }
    
    /** Sets the emission rate for this emitter.
        @remarks
            This method tells the emitter how many particles per second should be emitted. The emitter
            subclass does not have to emit these in a continuous burst - this is a relative parameter
            and the emitter may choose to emit all of the second's worth of particles every half-second
            for example. This is controlled by the emitter's getEmissionCount method.
        @par
            Also, if the ParticleSystem's particle quota is exceeded, not all the particles requested
            may be actually emitted.
        @param
            particlesPerSecond The number of particles to be emitted every second.
        */
    void setEmissionRate(Real particlesPerSecond)
    { 
        mEmissionRate = particlesPerSecond; 
    }
    
    /** Returns the emission rate set for this emitter. */
    Real getEmissionRate()
    { 
        return mEmissionRate; 
    }
    
    /** Sets the lifetime of all particles emitted.
        @remarks
            The emitter initialises particles with a time-to-live (TTL), the number of seconds a particle
            will exist before being destroyed. This method sets a constant TTL for all particles emitted.
            Note that affectors are able to modify the TTL of particles later.
        @par
            Also see the alternate version of this method which takes a min and max TTL in order to 
            have the TTL vary per particle.
        @param ttl The number of seconds each particle will live for.
        */
    void setTimeToLive(Real ttl)
    {
        mMinTTL = mMaxTTL = ttl;
    }
    /** Sets the range of lifetime for particles emitted.
        @remarks
            The emitter initialises particles with a time-to-live (TTL), the number of seconds a particle
            will exist before being destroyed. This method sets a range for the TTL for all particles emitted;
            the ttl may be randomised between these 2 extremes or will vary some other way depending on the
            emitter.
            Note that affectors are able to modify the TTL of particles later.
        @par
            Also see the alternate version of this method which takes a single TTL in order to 
            set a constant TTL for all particles.
        @param minTtl The minimum number of seconds each particle will live for.
        @param maxTtl The maximum number of seconds each particle will live for.
        */
    void setTimeToLive(Real minTtl, Real maxTtl)
    {
        mMinTTL = minTtl;
        mMaxTTL = maxTtl;
    }
    
    /** Sets the minimum time each particle will live for. */
    void setMinTimeToLive(Real min)
    {
        mMinTTL = min;
    }
    /** Sets the maximum time each particle will live for. */
    void setMaxTimeToLive(Real max)
    {
        mMaxTTL = max;
    }
    /** Gets the time each particle will live for. */
    Real getTimeToLive()
    {
        return mMinTTL;
    }
    
    /** Gets the minimum time each particle will live for. */
    Real getMinTimeToLive()
    {
        return mMinTTL;
    }
    /** Gets the maximum time each particle will live for. */
    Real getMaxTimeToLive()
    {
        return mMaxTTL;
    }
    
    /** Sets the initial colour of particles emitted.
        @remarks
            Particles have an initial colour on emission which the emitter sets. This method sets
            this colour. See the alternate version of this method which takes 2 colours in order to establish 
            a range of colours to be assigned to particles.
        @param colour The colour which all particles will be given on emission.
        */
    void setColour(ColourValue colour)
    {
        mColourRangeStart = mColourRangeEnd = colour;
    }
    /** Sets the range of colours for emitted particles.
        @remarks
            Particles have an initial colour on emission which the emitter sets. This method sets
            the range of this colour. See the alternate version of this method which takes a single colour
            in order to set a constant colour for all particles. Emitters may choose to randomly assign
            a colour in this range, or may use some other method to vary the colour.
        @param colourStart The start of the colour range
        @param colourEnd The end of the colour range
        */
    void setColour(ColourValue colourStart,ColourValue colourEnd)
    {
        mColourRangeStart = colourStart;
        mColourRangeEnd = colourEnd;
    }
    /** Sets the minimum colour of particles to be emitted. */
    void setColourRangeStart(ColourValue colour)
    {
        mColourRangeStart = colour;
    }
    /** Sets the maximum colour of particles to be emitted. */
    void setColourRangeEnd(ColourValue colour)
    {
        mColourRangeEnd = colour;
    }
    /** Gets the colour of particles to be emitted. */
   ColourValue getColour()
    {
        return mColourRangeStart;
    }
    /** Gets the minimum colour of particles to be emitted. */
   ColourValue getColourRangeStart()
    {
        return mColourRangeStart;
    }
    /** Gets the maximum colour of particles to be emitted. */
   ColourValue getColourRangeEnd()
    {
        return mColourRangeEnd;
    }
    
    /** Gets the number of particles which this emitter would like to emit based on the time elapsed.
        @remarks
            For efficiency the emitter does not actually create new Particle instances (these are reused
            by the ParticleSystem as existing particles 'die'). The implementation for this method must
            return the number of particles the emitter would like to emit given the number of seconds which
            have elapsed (passed in as a parameter).
        @par
            Based on the return value from this method, the ParticleSystem class will call 
            _initParticle once for each particle it chooses to allow to be emitted by this emitter.
            The emitter should not track these _initParticle calls, it should assume all emissions
            requested were made (even if they could not be because of particle quotas).
        */
    abstract ushort _getEmissionCount(Real timeElapsed);
    
    /** Initialises a particle based on the emitter's approach and parameters.
        @remarks
            See the _getEmissionCount method for details of why there is a separation between
            'requested' emissions and actual initialised particles.
        @param
            pParticle Pointer to a particle which must be initialised based on how this emitter
            starts particles. This is passed as a pointer rather than being created by the emitter so the
            ParticleSystem can reuse Particle instances, and can also set defaults itself.
        */
    void _initParticle(ref Particle pParticle) {
        // Initialise size in case it's been altered
        pParticle.resetDimensions();
    }
    
    
    /** Returns the name of the type of emitter. 
        @remarks
            This property is useful for determining the type of emitter procedurally so another
            can be created.
        */
   string getType(){ return mType; }
    
    /** Sets whether or not the emitter is enabled.
        @remarks
            You can turn an emitter off completely by setting this parameter to false.
        */
    void setEnabled(bool enabled)
    {
        mEnabled = enabled;
        // Reset duration & repeat
        initDurationRepeat();
    }
    
    /** Gets the flag indicating if this emitter is enabled or not. */
    bool getEnabled()
    {
        return mEnabled;
    }
    
    /** Sets the 'start time' of this emitter.
        @remarks
            By default an emitter starts straight away as soon as a ParticleSystem is first created,
            or also just after it is re-enabled. This parameter allows you to set a time delay so
            that the emitter does not 'kick in' until later.
        @param startTime The time in seconds from the creation or enabling of the emitter.
        */
    void setStartTime(Real startTime)
    {
        setEnabled(false);
        mStartTime = startTime;
    }

    /** Gets the start time of the emitter. */
    Real getStartTime()
    {
        return mStartTime;
    }
    
    /** Sets the duration of the emitter.
        @remarks
            By default emitters run indefinitely (unless you manually disable them). By setting this
            parameter, you can make an emitter turn off on it's own after a set number of seconds. It
            will then remain disabled until either setEnabled(true) is called, or if the 'repeatAfter' parameter
            has been set it will also repeat after a number of seconds.
        @par
            Also see the alternative version of this method which allows you to set a min and max duration for
            a random variable duration.
        @param duration The duration in seconds.
        */
    void setDuration(Real duration)
    {
        setDuration(duration, duration);
    }
    
    /** Gets the duration of the emitter from when it is created or re-enabled. */
    Real getDuration()
    {
        return mDurationMin;
    }
    
    /** Sets the range of random duration for this emitter. 
        @remarks
            By default emitters run indefinitely (unless you manually disable them). By setting this
            parameter, you can make an emitter turn off on it's own after a random number of seconds. It
            will then remain disabled until either setEnabled(true) is called, or if the 'repeatAfter' parameter
            has been set it will also repeat after a number of seconds.
        @par
            Also see the alternative version of this method which allows you to set a constant duration.
        @param min The minimum duration in seconds.
        @param max The minimum duration in seconds.
        */
    void setDuration(Real min, Real max)
    {
        mDurationMin = min;
        mDurationMax = max;
        initDurationRepeat();
    }
    /** Sets the minimum duration of this emitter in seconds (see setDuration for more details) */
    void setMinDuration(Real min)
    {
        mDurationMin = min;
        initDurationRepeat();
    }
    /** Sets the maximum duration of this emitter in seconds (see setDuration for more details) */
    void setMaxDuration(Real max)
    {
        mDurationMax = max;
        initDurationRepeat();
    }
    /** Gets the minimum duration of this emitter in seconds (see setDuration for more details) */
    Real getMinDuration()
    {
        return mDurationMin;
    }
    /** Gets the maximum duration of this emitter in seconds (see setDuration for more details) */
    Real getMaxDuration()
    {
        return mDurationMax;
    }
    
    /** Sets the time between repeats of the emitter.
        @remarks
            By default emitters run indefinitely (unless you manually disable them). However, if you manually
            disable the emitter (by calling setEnabled(false), or it's duration runs out, it will cease to emit
        @par
            Also see the alternative version of this method which allows you to set a min and max duration for
            a random variable duration.
        @param duration The duration in seconds.
        */
    void setRepeatDelay(Real delay)
    {
        setRepeatDelay(delay, delay);
    }
    
    /** Gets the duration of the emitter from when it is created or re-enabled. */
    Real getRepeatDelay()
    {
        return mRepeatDelayMin;
    }
    
    /** Sets the range of random duration for this emitter. 
        @remarks
            By default emitters run indefinitely (unless you manually disable them). By setting this
            parameter, you can make an emitter turn off on it's own after a random number of seconds. It
            will then remain disabled until either setEnabled(true) is called, or if the 'repeatAfter' parameter
            has been set it will also repeat after a number of seconds.
        @par
            Also see the alternative version of this method which allows you to set a constant duration.
        @param min The minimum duration in seconds.
        @param max The minimum duration in seconds.
        */
    void setRepeatDelay(Real min, Real max)
    {
        mRepeatDelayMin = min;
        mRepeatDelayMax = max;
        initDurationRepeat();
    }
    /** Sets the minimum duration of this emitter in seconds (see setRepeatDelay for more details) */
    void setMinRepeatDelay(Real min)
    {
        mRepeatDelayMin = min;
        initDurationRepeat();
    }
    /** Sets the maximum duration of this emitter in seconds (see setRepeatDelay for more details) */
    void setMaxRepeatDelay(Real max)
    {
        mRepeatDelayMax = max;
        initDurationRepeat();
    }
    /** Gets the minimum duration of this emitter in seconds (see setRepeatDelay for more details) */
    Real getMinRepeatDelay()
    {
        return mRepeatDelayMin;    
    }
    /** Gets the maximum duration of this emitter in seconds (see setRepeatDelay for more details) */
    Real getMaxRepeatDelay()
    {
        return mRepeatDelayMax;    
    }
    
    /** Returns the name of the emitter */
   string getName()
    {
        return mName;
    }
    
    /** Sets the name of the emitter */
    void setName(string newName)
    {
        mName = newName;
    }
    
    /** Returns the name of the emitter to be emitted */
   string getEmittedEmitter()
    {
        return mEmittedEmitter;
    }
    
    /** Sets the name of the emitter to be emitted*/
    void setEmittedEmitter(string emittedEmitter)
    {
        mEmittedEmitter = emittedEmitter;
    }
    
    /** Return true if the emitter is emitted by another emitter */
    bool isEmitted()
    {
        return mEmitted;
    }
    
    /** Set the indication (true/false) to indicate that the emitter is emitted by another emitter */
    void setEmitted(bool emitted)
    {
        mEmitted = emitted;
    }
}

/** Abstract class defining the interface to be implemented by creators of ParticleEmitter subclasses.
    @remarks
        Plugins or 3rd party applications can add new types of particle emitters to Ogre by creating
        subclasses of the ParticleEmitter class. Because multiple instances of these emitters may be
        required, a factory class to manage the instances is also required. 
    @par
        ParticleEmitterFactory subclasses must allow the creation and destruction of ParticleEmitter
        subclasses. They must also be registered with the ParticleSystemManager. All factories have
        a name which identifies them, examples might be 'point', 'cone', or 'box', and these can be 
        also be used from particle system scripts.
    */
class ParticleEmitterFactory //: public FXAlloc
{
protected:
    ParticleEmitter[] mEmitters;
public:
    this() {}
    ~this()
    {
        // Destroy all emitters
        foreach (i; mEmitters)
        {
            destroy(i);
        }
        
        mEmitters.clear();
        
    }
    
    /** Returns the name of the factory, the name which identifies the particle emitter type this factory creates. */
    abstract string getName();
    
    /** Creates a new emitter instance.
        @remarks
            The subclass MUST add a pointer to the created instance to mEmitters.
        */
    abstract ParticleEmitter createEmitter(ref ParticleSystem psys);
    
    /** Destroys the emitter pointed to by the parameter (for early clean up if required). */
    void destroyEmitter(ref ParticleEmitter e)
    {
        mEmitters.removeFromArray(e);
        destroy(e);
        /*foreach (i; mEmitters)
        {
            if (i == e)
            {
                mEmitters.erase(i);
                OGRE_DELETE e;
                break;
            }
        }*/
    }
}
/** @} */
/** @} */