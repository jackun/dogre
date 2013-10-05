module ogre.math.simplespline;
//import std.container;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.compat;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */
/** A very simple spline class which implements the Catmull-Rom class of splines.
 @remarks
 Splines are bendy lines. You define a series of points, and the spline forms
 a smoother line between the points to eliminate the sharp angles.
 @par
 Catmull-Rom splines are a specialisation of the general Hermite spline. With
 a Hermite spline, you define the start and end point of the line, and 2 tangents,
 one at the start of the line and one at the end. The Catmull-Rom spline simplifies
 this by just asking you to define a series of points, and the tangents are 
 created for you. 
 */
class SimpleSpline
{
public:
    this()
    {
        // Set up matrix
        // Hermite polynomial
        mCoeffs[0, 0] = 2;
        mCoeffs[0, 1] = -2;
        mCoeffs[0, 2] = 1;
        mCoeffs[0, 3] = 1;
        mCoeffs[1, 0] = -3;
        mCoeffs[1, 1] = 3;
        mCoeffs[1, 2] = -2;
        mCoeffs[1, 3] = -1;
        mCoeffs[2, 0] = 0;
        mCoeffs[2, 1] = 0;
        mCoeffs[2, 2] = 1;
        mCoeffs[2, 3] = 0;
        mCoeffs[3, 0] = 1;
        mCoeffs[3, 1] = 0;
        mCoeffs[3, 2] = 0;
        mCoeffs[3, 3] = 0;
        
        mAutoCalc = true;
    }
    ~this(){}
    
    /** Adds a control point to the end of the spline. */
    void addPoint(Vector3 p)
    {
        mPoints.insert(p);
        if (mAutoCalc)
        {
            recalcTangents();
        }
    }
    
    /** Gets the detail of one of the control points of the spline. */
    Vector3 getPoint(ushort index)
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
    void updatePoint(ushort index,Vector3 value)
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
     */
    Vector3 interpolate(Real t)
    {
        // Currently assumes points are evenly spaced, will cause velocity
        // change where this is not the case
        // TODO: base on arclength?
        
        
        // Work out which segment this is in
        Real fSeg = t * (mPoints.length - 1);
        uint segIdx = cast(uint)fSeg;
        // Apportion t 
        t = fSeg - segIdx;
        
        return interpolate(segIdx, t);
        
    }
    
    /** Interpolates a single segment of the spline given a parametric value.
     @param fromIndex The point index to treat as t=0. fromIndex + 1 is deemed to be t=1
     @param t Parametric value
     */
    Vector3 interpolate(uint fromIndex, Real t)
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
        // Form a vector of powers of t
        Real t2, t3;
        t2 = t * t;
        t3 = t2 * t;
        auto powers = Vector4(t3, t2, t, 1);
        
        
        // Algorithm is ret = powers * mCoeffs * Matrix4(point1, point2, tangent1, tangent2)
        Vector3 point1 = mPoints[fromIndex];
        Vector3 point2 = mPoints[fromIndex+1];
        Vector3 tan1 = mTangents[fromIndex];
        Vector3 tan2 = mTangents[fromIndex+1];
        Matrix4 pt;
        
        pt[0, 0] = point1.x;
        pt[0, 1] = point1.y;
        pt[0, 2] = point1.z;
        pt[0, 3] = 1.0f;
        pt[1, 0] = point2.x;
        pt[1, 1] = point2.y;
        pt[1, 2] = point2.z;
        pt[1, 3] = 1.0f;
        pt[2, 0] = tan1.x;
        pt[2, 1] = tan1.y;
        pt[2, 2] = tan1.z;
        pt[2, 3] = 1.0f;
        pt[3, 0] = tan2.x;
        pt[3, 1] = tan2.y;
        pt[3, 2] = tan2.z;
        pt[3, 3] = 1.0f;
        
        Vector4 ret = powers * mCoeffs * pt;
        return Vector3(ret.x, ret.y, ret.z);
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
        // Catmull-Rom approach
        // 
        // tangent[i] = 0.5 * (point[i+1] - point[i-1])
        //
        // Assume endpoint tangents are parallel with line with neighbour
        
        size_t i, numPoints;
        bool isClosed;
        
        numPoints = mPoints.length;
        if (numPoints < 2)
        {
            // Can't do anything yet
            return;
        }
        
        // Closed or open?
        if (mPoints[0] == mPoints[numPoints-1])
        {
            isClosed = true;
        }
        else
        {
            isClosed = false;
        }
        
        mTangents.length = numPoints;

        for(i = 0; i < numPoints; ++i)
        {
            if (i ==0)
            {
                // Special case start
                if (isClosed)
                {
                    // Use numPoints-2 since numPoints-1 is the last point and == [0]
                    mTangents[i] = 0.5 * (mPoints[1] - mPoints[numPoints-2]);
                }
                else
                {
                    mTangents[i] = 0.5 * (mPoints[1] - mPoints[0]);
                }
            }
            else if (i == numPoints-1)
            {
                // Special case end
                if (isClosed)
                {
                    // Use same tangent as already calculated for [0]
                    mTangents[i] = mTangents[0];
                }
                else
                {
                    mTangents[i] = 0.5 * (mPoints[i] - mPoints[i-1]);
                }
            }
            else
            {
                mTangents[i] = 0.5 * (mPoints[i+1] - mPoints[i-1]);
            }
        }
    }

    
protected:
    
    bool mAutoCalc;
    
    Vector3[] mPoints;
    Vector3[] mTangents;
    
    /// Matrix of coefficients 
    Matrix4 mCoeffs;

}

/** @} */
/** @} */