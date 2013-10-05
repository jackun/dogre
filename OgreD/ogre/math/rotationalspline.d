module ogre.math.rotationalspline;

//import std.container;
import ogre.math.quaternion;
import ogre.compat;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Math
    *  @{
    */
/** This class interpolates orientations (rotations) along a spline using 
        derivatives of quaternions.
    @remarks
        Like the SimpleSpline class, this class is about interpolating values 
        smoothly over a spline. Whilst SimpleSpline deals with positions (the normal
        sense we think about splines), this class interpolates orientations. The
        theory is identical, except we're now in 4-dimensional space instead of 3.
    @par
        In positional splines, we use the points and tangents on those points to generate
        control points for the spline. In this case, we use quaternions and derivatives
        of the quaternions (i.e. the rate and direction of change at each point). This is the
        same as SimpleSpline since a tangent is a derivative of a position. We effectively 
        generate an extra quaternion in between each actual quaternion which when take with 
        the original quaternion forms the 'tangent' of that quaternion.
    */
class RotationalSpline
{
public:
    this(){}
    ~this(){}
    
    /** Adds a control point to the end of the spline. */
    void addPoint(Quaternion p)
    {
        mPoints.insert(p);
        if (mAutoCalc)
        {
            recalcTangents();
        }
    }
    
    /** Gets the detail of one of the control points of the spline. */
   Quaternion getPoint(ushort index)
    {
        assert (index < mPoints.length, "Point index is out of bounds!!");
        
        return mPoints[index];
    }
    
    /** Gets the number of control points in the spline. */
    ushort getNumPoints()
    {
        return cast(ushort)mPoints.length;
    }
    
    /** Clears all the points in the spline. */
    void clear()
    {
        mPoints.clear();
        mTangents.clear();
    }
    
    /** Updates a single point in the spline. 
        @remarks
            This point must already exist in the spline.
        */
    void updatePoint(ushort index,Quaternion value)
    {
        assert (index < mPoints.length, "Point index is out of bounds!!");
        
        mPoints[index] = value;
        if (mAutoCalc)
        {
            recalcTangents();
        }
    }
    
    /** Returns an interpolated point based on a parametric value over the whole series.
        @remarks
            Given a t value between 0 and 1 representing the parametric distance along the
            whole length of the spline, this method returns an interpolated point.
        @param t Parametric value.
        @param useShortestPath Defines if rotation should take the shortest possible path
        */
    Quaternion interpolate(Real t, bool useShortestPath=true)
    {
        // Work out which segment this is in
        Real fSeg = t * (mPoints.length - 1);
        uint segIdx = cast(uint)fSeg;
        // Apportion t 
        t = fSeg - segIdx;
        
        return interpolate(segIdx, t, useShortestPath);
        
    }
    
    /** Interpolates a single segment of the spline given a parametric value.
        @param fromIndex The point index to treat as t=0. fromIndex + 1 is deemed to be t=1
        @param t Parametric value
        @param useShortestPath Defines if rotation should take the shortest possible path
        */
    Quaternion interpolate(uint fromIndex, Real t, bool useShortestPath=true)
    {
        // Bounds check
        assert (fromIndex < mPoints.length,
                "fromIndex out of bounds");
        
        if ((fromIndex + 1) == mPoints.length)
        {
            // Duff request, cannot blend to nothing
            // Just return source
            return mPoints[fromIndex];
            
        }
        // Fast special cases
        if (t == 0.0f)
        {
            return mPoints[fromIndex];
        }
        else if(t == 1.0f)
        {
            return mPoints[fromIndex + 1];
        }
        
        // Real interpolation
        // Use squad using tangents we've already set up
        Quaternion p = mPoints[fromIndex];
        Quaternion q = mPoints[fromIndex+1];
        Quaternion a = mTangents[fromIndex];
        Quaternion b = mTangents[fromIndex+1];
        
        // NB interpolate to nearest rotation
        return Quaternion.Squad(t, p, a, b, q, useShortestPath);
        
    }
    
    /** Tells the spline whether it should automatically calculate tangents on demand
            as points are added.
        @remarks
            The spline calculates tangents at each point automatically based on the input points.
            Normally it does this every time a point changes. However, if you have a lot of points
            to add in one go, you probably don't want to incur this overhead and would prefer to 
            defer the calculation until you are finished setting all the points. You can do this
            by calling this method with a parameter of 'false'. Just remember to manually call 
            the recalcTangents method when you are done.
        @param autoCalc If true, tangents are calculated for you whenever a point changes. If false, 
            you must call reclacTangents to recalculate them when it best suits.
        */
    void setAutoCalculate(bool autoCalc)
    {
        mAutoCalc = autoCalc;
    }
    
    /** Recalculates the tangents associated with this spline. 
        @remarks
            If you tell the spline not to update on demand by calling setAutoCalculate(false)
            then you must call this after completing your updates to the spline points.
        */
    void recalcTangents()
    {
        // ShoeMake (1987) approach
        // Just like Catmull-Rom really, just more gnarly
        // And no, I don't understand how to derive this!
        //
        // let p = point[i], pInv = p.Inverse
        // tangent[i] = p * exp( -0.25 * ( log(pInv * point[i+1]) + log(pInv * point[i-1]) ) )
        //
        // Assume endpoint tangents are parallel with line with neighbour
        
        uint i, numPoints;
        bool isClosed;
        
        numPoints = cast(uint)mPoints.length;
        
        if (numPoints < 2)
        {
            // Can't do anything yet
            return;
        }
        
        mTangents.length = numPoints;
        
        if (mPoints[0] == mPoints[numPoints-1])
        {
            isClosed = true;
        }
        else
        {
            isClosed = false;
        }
        
        Quaternion invp, part1, part2, preExp;
        for(i = 0; i < numPoints; ++i)
        {
            Quaternion p = mPoints[i];
            invp = p.Inverse();
            
            if (i ==0)
            {
                // special case start
                part1 = (invp * mPoints[i+1]).Log();
                if (isClosed)
                {
                    // Use numPoints-2 since numPoints-1 == end == start == this one
                    part2 = (invp * mPoints[numPoints-2]).Log();
                }
                else
                {
                    part2 = (invp * p).Log();
                }
            }
            else if (i == numPoints-1)
            {
                // special case end
                if (isClosed)
                {
                    // Wrap to [1] (not [0], this is the same as end == this one)
                    part1 = (invp * mPoints[1]).Log();
                }
                else
                {
                    part1 = (invp * p).Log();
                }
                part2 = (invp * mPoints[i-1]).Log();
            }
            else
            {
                part1 = (invp * mPoints[i+1]).Log();
                part2 = (invp * mPoints[i-1]).Log();
            }
            
            preExp = -0.25 * (part1 + part2);
            mTangents[i] = p * preExp.Exp();   
        }
    }
    
protected:
    
    bool mAutoCalc = true;
    
    Quaternion[] mPoints;
    Quaternion[] mTangents;
    
}

/** @} */
/** @} */