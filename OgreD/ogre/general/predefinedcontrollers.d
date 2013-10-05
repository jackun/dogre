module ogre.general.predefinedcontrollers;
import ogre.compat;
import ogre.general.framelistener;
import ogre.general.controller;
import ogre.general.root;
import ogre.materials.textureunitstate;
import ogre.math.matrix;
import ogre.math.maths;
import ogre.math.angles;
import ogre.materials.gpuprogram;
import ogre.math.vector;
import ogre.general.common;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */
//-----------------------------------------------------------------------
// Controller Values
//-----------------------------------------------------------------------
/** Predefined controller value for getting the latest frame time.
 */
class FrameTimeControllerValue : ControllerValue!Real, FrameListener
{
    mixin FrameListener.Impl;
protected:
    Real mFrameTime;
    Real mTimeFactor;
    Real mElapsedTime;
    Real mFrameDelay;
    
public:
    this()
    {
        // Register self
        Root.getSingleton().addFrameListener(this);
        mFrameTime = 0;
        mTimeFactor = 1;
        mFrameDelay = 0;
        mElapsedTime = 0;
        
    }

    override bool frameEnded(FrameEvent evt)
    {
        return true;
    }

    override bool frameStarted(FrameEvent evt)
    {
        if(mFrameDelay) 
        {
            // Fixed frame time
            mFrameTime = mFrameDelay;
            mTimeFactor =  mFrameDelay / evt.timeSinceLastFrame;
        }
        else 
        {
            // Save the time value after applying time factor
            mFrameTime = mTimeFactor * evt.timeSinceLastFrame;
        }
        // Accumulate the elapsed time
        mElapsedTime += mFrameTime;
        return true;
    }

    override Real getValue() //const
    {
        return mFrameTime;
    }

    override void setValue(Real value)
    {
        // Do nothing - value is set from frame listener
    }

    Real getTimeFactor() const
    {
        return mTimeFactor;
    }

    void setTimeFactor(Real tf)
    {
        if(tf >= 0) 
        {
            mTimeFactor = tf;
            mFrameDelay = 0;
        }
    }

    Real getFrameDelay() const
    {
        return mFrameDelay;
    }

    void setFrameDelay(Real fd)
    {
        mTimeFactor = 0;
        mFrameDelay = fd;
    }

    Real getElapsedTime() const
    {
        return mElapsedTime;
    }

    void setElapsedTime(Real elapsedTime)
    {
        mElapsedTime = elapsedTime;
    }
}

//-----------------------------------------------------------------------
/** Predefined controller value for getting / setting the frame number of a texture layer
 */
class TextureFrameControllerValue : ControllerValue!Real
{
protected:
    TextureUnitState mTextureLayer;
public:
    this(TextureUnitState t)
    {
        mTextureLayer = t;
    }
    
    /** Gets the frame number as a parametric value in the range [0,1]
     */
    override Real getValue() //const
    {
        int numFrames = mTextureLayer.getNumFrames();
        return (cast(Real)mTextureLayer.getCurrentFrame() / cast(Real)numFrames);
    }

    /** Sets the frame number as a parametric value in the range [0,1]; the actual frame number is value * (numFrames-1).
     */
    override void setValue(Real value)
    {
        int numFrames = mTextureLayer.getNumFrames();
        mTextureLayer.setCurrentFrame(cast(int)(value * numFrames) % numFrames);
    }
}
//-----------------------------------------------------------------------
/** Predefined controller value for getting / setting a texture coordinate modifications (scales and translates).
 @remarks
 Effects can be applied to the scale or the offset of the u or v coordinates, or both. If separate
 modifications are required to u and v then 2 instances are required to control both independently, or 4
 if you ant separate u and v scales as well as separate u and v offsets.
 @par
 Because of the nature of this value, it can accept values outside the 0..1 parametric range.
 */
class TexCoordModifierControllerValue : ControllerValue!Real
{
protected:
    bool mTransU, mTransV;
    bool mScaleU, mScaleV;
    bool mRotate;
    TextureUnitState mTextureLayer;
public:
    /** Constructor.
     @param
     t TextureUnitState to apply the modification to.
     @param
     translateU If true, the u coordinates will be translated by the modification.
     @param
     translateV If true, the v coordinates will be translated by the modification.
     @param
     scaleU If true, the u coordinates will be scaled by the modification.
     @param
     scaleV If true, the v coordinates will be scaled by the modification.
     @param
     rotate If true, the texture will be rotated by the modification.
     */
    this(TextureUnitState t, bool translateU = false, bool translateV = false,
         bool scaleU = false, bool scaleV = false, bool rotate = false )
    {
        mTextureLayer = t;
        mTransU = translateU;
        mTransV = translateV;
        mScaleU = scaleU;
        mScaleV = scaleV;
        mRotate = rotate;
    }
    
    override Real getValue() //const
    {
        Matrix4 pMat = mTextureLayer.getTextureTransform();
        if (mTransU)
        {
            return pMat[0][3];
        }
        else if (mTransV)
        {
            return pMat[1][3];
        }
        else if (mScaleU)
        {
            return pMat[0][0];
        }
        else if (mScaleV)
        {
            return pMat[1][1];
        }
        // Shouldn't get here
        return 0;
    }
    
    override void setValue(Real value)
    {
        if (mTransU)
        {
            mTextureLayer.setTextureUScroll(value);
        }
        if (mTransV)
        {
            mTextureLayer.setTextureVScroll(value);
        }
        if (mScaleU)
        {
            mTextureLayer.setTextureUScale(value);
        }
        if (mScaleV)
        {
            mTextureLayer.setTextureVScale(value);
        }
        if (mRotate)
        {
            mTextureLayer.setTextureRotate(Radian(value * Math.TWO_PI));
        }
    }
    
}

//-----------------------------------------------------------------------
/** Predefined controller value for setting a single floating-
 point value in a constant parameter of a vertex or fragment program.
 @remarks
 Any value is accepted, it is propagated into the 'x'
 component of the constant register identified by the index. If you
 need to use named parameters, retrieve the index from the param
 object before setting this controller up.
 @note
 Retrieving a value from the program parameters is not currently 
 supported, therefore do not use this controller value as a source,
 only as a target.
 */
class FloatGpuParameterControllerValue : ControllerValue!Real
{
protected:
    /// The parameters to access
    GpuProgramParametersPtr mParams;
    /// The index of the parameter to e read or set
    size_t mParamIndex;
public:
    /** Constructor.
     @param
     params The parameters object to access
     @param
     index The index of the parameter to be set
     */
    this(GpuProgramParametersPtr params,
         size_t index )
    {
        mParams = params; mParamIndex = index;
    }
    
    ~this() {}
    
    override Real getValue() //const
    {
        // do nothing, reading from a set of params not supported
        return 0.0f;
    }

    override void setValue(Real value)
    {
        Vector4 v4 = Vector4(0,0,0,0);
        v4.x = value;
        mParams.get().setConstant(mParamIndex, v4);
    }
}
//-----------------------------------------------------------------------
// Controller functions
//-----------------------------------------------------------------------

/** Predefined controller function which just passes through the original source
 directly to dest.
 */
class PassthroughControllerFunction : ControllerFunction!Real
{
public:
    /** Constructor.
     @param
     sequenceTime The amount of time in seconds it takes to loop through the whole animation sequence.
     @param
     timeOffset The offset in seconds at which to start (default is start at 0)
     */
    this(bool deltaInput = false)
    {
        super(deltaInput);
    }
    
    /** Overriden function.
     */
    override Real calculate(Real source)
    {
        return getAdjustedInput(source);
    }
}

/** Predefined controller function for dealing with animation.
 */
class AnimationControllerFunction : ControllerFunction!Real
{
protected:
    Real mSeqTime;
    Real mTime;
public:
    /** Constructor.
     @param
     sequenceTime The amount of time in seconds it takes to loop through the whole animation sequence.
     @param
     timeOffset The offset in seconds at which to start (default is start at 0)
     */
    this(Real sequenceTime, Real timeOffset = 0.0f)
    {
        super(false);
        mSeqTime = sequenceTime;
        mTime = timeOffset;
    }
    
    /** Overridden function.
     */
    override Real calculate(Real source)
    {
        // Assume source is time since last update
        mTime += source;
        // Wrap
        while (mTime >= mSeqTime) mTime -= mSeqTime;
        while (mTime < 0) mTime += mSeqTime;
        
        // Return parametric
        return mTime / mSeqTime;
    }
    
    /** Set the time value manually. */
    void setTime(Real timeVal)
    {
        mTime = timeVal;
    }

    /** Set the sequence duration value manually. */
    void setSequenceTime(Real seqVal)
    {
        mSeqTime = seqVal;
    }
}

//-----------------------------------------------------------------------
/** Predefined controller function which simply scales an input to an output value.
 */
class ScaleControllerFunction : ControllerFunction!Real
{
protected:
    Real mScale;
public:
    /** Constructor, requires a scale factor.
     @param
     scalefactor The multiplier applied to the input to produce the output.
     @param
     deltaInput If true, signifies that the input will be a delta value such that the function should
     add it to an internal counter before calculating the output.
     */
    this(Real scalefactor, bool deltaInput)
    {
        super(deltaInput);
        mScale = scalefactor;
    }
    
    /** Overridden method.
     */
    override Real calculate(Real source)
    {
        return getAdjustedInput(source * mScale);
    }
}

//-----------------------------------------------------------------------
/** Predefined controller function based on a waveform.
 @remarks
 A waveform function translates parametric input to parametric output based on a wave. The factors
 affecting the function are:
 - wave type - the shape of the wave
 - base - the base value of the output from the wave
 - frequency - the speed of the wave in cycles per second
 - phase - the offset of the start of the wave, e.g. 0.5 to start half-way through the wave
 - amplitude - scales the output so that instead of lying within [0,1] it lies within [0,1] * amplitude
 - duty cycle - the active width of a PWM signal
 @par
 Note that for simplicity of integration with the rest of the controller insfrastructure, the output of
 the wave is parametric i.e. 0..1, rather than the typical wave output of [-1,1]. To compensate for this, the
 traditional output of the wave is scaled by the following function before output:
 @par
 output = (waveoutput + 1) * 0.5
 @par
 Hence a wave output of -1 becomes 0, a wave ouput of 1 becomes 1, and a wave output of 0 becomes 0.5.
 */
class WaveformControllerFunction : ControllerFunction!Real
{
protected:
    WaveformType mWaveType;
    Real mBase;
    Real mFrequency;
    Real mPhase;
    Real mAmplitude;
    Real mDutyCycle;
    
    /** Overridden from ControllerFunction. */
    override Real getAdjustedInput(Real input)
    {
        Real adjusted = super.getAdjustedInput(input);
        
        // If not delta, adjust by phase here
        // (delta inputs have it adjusted at initialisation)
        if (!mDeltaInput)
        {
            adjusted += mPhase;
        }
        
        return adjusted;
    }
    
public:
    /** Default constructor, requires at least a wave type, other parameters can be defaulted unless required.
     @param
     deltaInput If true, signifies that the input will be a delta value such that the function should
     add it to an internal counter before calculating the output.
     @param
     dutyCycle Used in PWM mode to specify the pulse width.
     */
    this(WaveformType wType, Real base = 0, Real frequency = 1, Real phase = 0, 
         Real amplitude = 1, bool deltaInput = true, Real dutyCycle = 0.5)
    {
        super(deltaInput);
        mWaveType = wType;
        mBase = base;
        mFrequency = frequency;
        mPhase = phase;
        mAmplitude = amplitude;
        mDeltaCount = phase;
        mDutyCycle = dutyCycle;
    }
    
    /** Overridden function.
     */
    override Real calculate(Real source) 
    {
        Real input = getAdjustedInput(source * mFrequency);
        Real output = 0;
        // For simplicity, factor input down to {0,1)
        // Use looped subtract rather than divide / round
        while (input >= 1.0)
            input -= 1.0;
        while (input < 0.0)
            input += 1.0;
        
        // Calculate output in -1..1 range
        final switch (mWaveType)
        {
            case WaveformType.WFT_SINE:
                output = Math.Sin(Radian(input * Math.TWO_PI));
                break;
            case WaveformType.WFT_TRIANGLE:
                if (input < 0.25)
                    output = input * 4;
                else if (input >= 0.25 && input < 0.75)
                    output = 1.0f - ((input - 0.25f) * 4.0f);
                else
                    output = ((input - 0.75f) * 4.0f) - 1.0f;
                
                break;
            case WaveformType.WFT_SQUARE:
                if (input <= 0.5f)
                    output = 1.0f;
                else
                    output = -1.0f;
                break;
            case WaveformType.WFT_SAWTOOTH:
                output = (input * 2.0f) - 1.0f;
                break;
            case WaveformType.WFT_INVERSE_SAWTOOTH:
                output = -((input * 2.0f) - 1.0f);
                break;
            case WaveformType.WFT_PWM:
                if( input <= mDutyCycle )
                    output = 1.0f;
                else
                    output = -1.0f;
                break;
        }
        
        // Scale output into 0..1 range and then by base + amplitude
        return mBase + ((output + 1.0f) * 0.5f * mAmplitude);
    }
    
}

ControllerValue!Real sControllerValueReal;
ControllerFunction!Real sControllerFunctionReal;
/** @} */
/** @} */