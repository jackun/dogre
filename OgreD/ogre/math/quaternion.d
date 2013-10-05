module ogre.math.quaternion;

import ogre.compat;
import ogre.math.maths;
import ogre.math.angles;
import ogre.math.vector;
import ogre.math.matrix;


/** \addtogroup Core
*  @{
*/
/** \addtogroup Math
*  @{
*/
/** Implementation of a Quaternion, i.e. a rotation around an axis.
    For more information about Quaternions and the theory behind it, we recommend reading:
    http://www.ogre3d.org/tikiwiki/Quaternion+and+Rotation+Primer
    http://www.cprogramming.com/tutorial/3d/quaternions.html
    http://www.gamedev.net/page/resources/_/reference/programming/math-and-physics/
    quaternions/quaternion-powers-r1095
*/
struct Quaternion
{
public:
    Real w = 1, x = 0, y = 0, z = 0;
    /// Cutoff for sine near zero
    immutable static Real msEpsilon = 1e-03;
    immutable static Quaternion ZERO = Quaternion(0,0,0,0);
    immutable static Quaternion IDENTITY = Quaternion(1,0,0,0);
    
    /*static this()
    {
        ZERO = Quaternion(0,0,0,0);
        IDENTITY = Quaternion(1,0,0,0);
    }*/
    /// Default constructor, initializes to identity rotation (aka 0°)
    /*this ()
    {
        w = 1; x = 0; y = 0; z = 0;
    }*/
    /// Construct from an explicit list of values
    this (
        Real fW,
        Real fX, Real fY, Real fZ)
    {
        w = fW; x = fX; y = fY; z = fZ;
    }
    /// Construct a quaternion from a rotation matrix
    this (Matrix3 rot)
    {
        this.FromRotationMatrix(rot);
    }
    /// Construct a quaternion from an angle/axis
    this (Radian rfAngle, Vector3 rkAxis)
    {
        this.FromAngleAxis(rfAngle, rkAxis);
    }
    /// Construct a quaternion from 3 orthonormal local axes
    this (Vector3 xaxis, Vector3 yaxis, Vector3 zaxis)
    {
        this.FromAxes(xaxis, yaxis, zaxis);
    }
    /// Construct a quaternion from 3 orthonormal local axes
    this (Vector3[3] akAxis)
    {
        this.FromAxes(akAxis);
    }
    /// Construct a quaternion from 4 manual w/x/y/z values
    /*this (Real* valptr)
    {
        memcpy(&w, valptr, sizeof(Real)*4);
    }*/
    /** @todo D ever getting array unpacking?*/
    this (Real[4] v)
    {
        w = v[0]; x = v[1]; y = v[2]; z = v[3];
    }

    /** Exchange the contents of this quaternion with another. 
    */
    void swap(Quaternion other)
    {
        std.algorithm.swap(w, other.w);
        std.algorithm.swap(x, other.x);
        std.algorithm.swap(y, other.y);
        std.algorithm.swap(z, other.z);
    }

    /// Array accessor operator
    Real opIndex (size_t i )
    {
        assert( i < 4 );

        //return *(&w+i);
        return [w,x,y,z][i];
    }

    /// Array accessor operator
    /*Real& operator [] (size_t i )
    {
        assert( i < 4 );

        return *(&w+i);
    }*/

    /// Pointer accessor for direct copying
    /*Real* ptr()
    {
        return &w;
    }

    /// Pointer accessor for direct copying
   Real* ptr()
    {
        return &w;
    }*/

    void FromRotationMatrix (ref Matrix3 kRot)
    {
        // Algorithm in Ken Shoemake's article in 1987 SIGGRAPH course notes
        // article "Quaternion Calculus and Fast Animation".

        Real fTrace = kRot[0][0]+kRot[1][1]+kRot[2][2];
        Real fRoot;

        if ( fTrace > 0.0 )
        {
            // |w| > 1/2, may as well choose w > 1/2
            fRoot = Math.Sqrt(fTrace + 1.0f);  // 2w
            w = 0.5f*fRoot;
            fRoot = 0.5f/fRoot;  // 1/(4w)
            x = (kRot[2][1]-kRot[1][2])*fRoot;
            y = (kRot[0][2]-kRot[2][0])*fRoot;
            z = (kRot[1][0]-kRot[0][1])*fRoot;
        }
        else
        {
            // |w| <= 1/2
            static size_t s_iNext[3] = [ 1, 2, 0 ];
            size_t i = 0;
            if ( kRot[1][1] > kRot[0][0] )
                i = 1;
            if ( kRot[2][2] > kRot[i][i] )
                i = 2;
            size_t j = s_iNext[i];
            size_t k = s_iNext[j];

            fRoot = Math.Sqrt(kRot[i][i]-kRot[j][j]-kRot[k][k] + 1.0f);
            Real* apkQuat[3] = [ &x, &y, &z ];
            *apkQuat[i] = 0.5f*fRoot;
            fRoot = 0.5f/fRoot;
            w = (kRot[k][j]-kRot[j][k])*fRoot;
            *apkQuat[j] = (kRot[j][i]+kRot[i][j])*fRoot;
            *apkQuat[k] = (kRot[k][i]+kRot[i][k])*fRoot;
        }
    }

    void ToRotationMatrix (ref Matrix3 kRot)
    {
        Real fTx  = x+x;
        Real fTy  = y+y;
        Real fTz  = z+z;
        Real fTwx = fTx*w;
        Real fTwy = fTy*w;
        Real fTwz = fTz*w;
        Real fTxx = fTx*x;
        Real fTxy = fTy*x;
        Real fTxz = fTz*x;
        Real fTyy = fTy*y;
        Real fTyz = fTz*y;
        Real fTzz = fTz*z;

        kRot[0, 0] = 1.0f-(fTyy+fTzz);
        kRot[0, 1] = fTxy-fTwz;
        kRot[0, 2] = fTxz+fTwy;
        kRot[1, 0] = fTxy+fTwz;
        kRot[1, 1] = 1.0f-(fTxx+fTzz);
        kRot[1, 2] = fTyz-fTwx;
        kRot[2, 0] = fTxz-fTwy;
        kRot[2, 1] = fTyz+fTwx;
        kRot[2, 2] = 1.0f-(fTxx+fTyy);
    }

    /** Setups the quaternion using the supplied vector, and "roll" around
        that vector by the specified radians.
    */
    void FromAngleAxis (Radian rfAngle, Vector3 rkAxis) //const
    {
        // assert:  axis[] is unit length
        //
        // The quaternion representing the rotation is
        //   q = cos(A/2)+sin(A/2)*(x*i+y*j+z*k)

        Radian fHalfAngle = rfAngle*0.5f;
        Real fSin = Math.Sin(fHalfAngle);
        w = Math.Cos(fHalfAngle);
        x = fSin*rkAxis.x;
        y = fSin*rkAxis.y;
        z = fSin*rkAxis.z;
    }

    void ToAngleAxis (ref Radian rfAngle, ref Vector3 rkAxis)
    {
        // The quaternion representing the rotation is
        //   q = cos(A/2)+sin(A/2)*(x*i+y*j+z*k)

        Real fSqrLength = x*x+y*y+z*z;
        if ( fSqrLength > 0.0 )
        {
            rfAngle = 2.0*Math.ACos(w);
            Real fInvLength = Math.InvSqrt(fSqrLength);
            rkAxis.x = x*fInvLength;
            rkAxis.y = y*fInvLength;
            rkAxis.z = z*fInvLength;
        }
        else
        {
            // angle is 0 (mod 2*pi), so any axis will do
            rfAngle = Radian(0.0);
            rkAxis.x = 1.0;
            rkAxis.y = 0.0;
            rkAxis.z = 0.0;
        }
    }

    void ToAngleAxis (ref Degree dAngle, ref Vector3 rkAxis){
        Radian rAngle;
        ToAngleAxis ( rAngle, rkAxis );
        dAngle = rAngle;
    }
    /** Constructs the quaternion using 3 axes, the axes are assumed to be orthonormal
        @see FromAxes
    */
    void FromAxes (ref Vector3[3] akAxis)
    {
        Matrix3 kRot;

        for (size_t iCol = 0; iCol < 3; iCol++)
        {
            kRot[0][iCol] = akAxis[iCol].x;
            kRot[1][iCol] = akAxis[iCol].y;
            kRot[2][iCol] = akAxis[iCol].z;
        }

        FromRotationMatrix(kRot);
    }

    void FromAxes (Vector3 xaxis,Vector3 yaxis,Vector3 zaxis)
    {
        FromAxes (xaxis, yaxis, zaxis);
    }

    void FromAxes (ref Vector3 xaxis,ref Vector3 yaxis,ref Vector3 zaxis)
    {
        Matrix3 kRot;

        kRot[0, 0] = xaxis.x;
        kRot[1, 0] = xaxis.y;
        kRot[2, 0] = xaxis.z;

        kRot[0, 1] = yaxis.x;
        kRot[1, 1] = yaxis.y;
        kRot[2, 1] = yaxis.z;

        kRot[0, 2] = zaxis.x;
        kRot[1, 2] = zaxis.y;
        kRot[2, 2] = zaxis.z;

        FromRotationMatrix(kRot);

    }

    /** Gets the 3 orthonormal axes defining the quaternion. @see FromAxes */
    void ToAxes (ref Vector3[3] akAxis)
    {
        Matrix3 kRot;

        ToRotationMatrix(kRot);

        for (size_t iCol = 0; iCol < 3; iCol++)
        {
            akAxis[iCol].x = kRot[0][iCol];
            akAxis[iCol].y = kRot[1][iCol];
            akAxis[iCol].z = kRot[2][iCol];
        }
    }

    void ToAxes (ref Vector3 xaxis, ref Vector3 yaxis, ref Vector3 zaxis)
    {
        Matrix3 kRot;

        ToRotationMatrix(kRot);

        xaxis.x = kRot[0][0];
        xaxis.y = kRot[1][0];
        xaxis.z = kRot[2][0];

        yaxis.x = kRot[0][1];
        yaxis.y = kRot[1][1];
        yaxis.z = kRot[2][1];

        zaxis.x = kRot[0][2];
        zaxis.y = kRot[1][2];
        zaxis.z = kRot[2][2];
    }


    Quaternion opAssign (Quaternion rkQ)
    {
        w = rkQ.w;
        x = rkQ.x;
        y = rkQ.y;
        z = rkQ.z;
        return this;
    }

    bool opEquals (Quaternion rhs) const
    {
        return (rhs.x == x) && (rhs.y == y) &&
            (rhs.z == z) && (rhs.w == w);
    }
    /*bool operator!= (Quaternion rhs)
    {
        return !operator==(rhs);
    }*/
    
    
    

    /// Check whether this quaternion contains valid values
    bool isNaN()
    {
        return Math.isNaN(x) || Math.isNaN(y) || Math.isNaN(z) || Math.isNaN(w);
    }

    /** Function for writing to a stream. Outputs "Quaternion(w, x, y, z)" with w,x,y,z
        being the member values of the quaternion.
    */
    string toString()
    {
        return std.conv.text("Quaternion(" ,w , ", ",x, ", " ,y, ", " ,z, ")");
    }

    /** Returns the X orthonormal axis defining the quaternion. Same as doing
        xAxis = Vector3::UNIT_X * this. Also called the local X-axis
    */
    Vector3 xAxis()
    {
        //Real fTx  = 2.0*x;
        Real fTy  = 2.0f*y;
        Real fTz  = 2.0f*z;
        Real fTwy = fTy*w;
        Real fTwz = fTz*w;
        Real fTxy = fTy*x;
        Real fTxz = fTz*x;
        Real fTyy = fTy*y;
        Real fTzz = fTz*z;

        return Vector3(1.0f-(fTyy+fTzz), fTxy+fTwz, fTxz-fTwy);
    }
    /** Returns the Y orthonormal axis defining the quaternion. Same as doing
        yAxis = Vector3::UNIT_Y * this. Also called the local Y-axis
    */
    Vector3 yAxis()
    {
        Real fTx  = 2.0f*x;
        Real fTy  = 2.0f*y;
        Real fTz  = 2.0f*z;
        Real fTwx = fTx*w;
        Real fTwz = fTz*w;
        Real fTxx = fTx*x;
        Real fTxy = fTy*x;
        Real fTyz = fTz*y;
        Real fTzz = fTz*z;

        return Vector3(fTxy-fTwz, 1.0f-(fTxx+fTzz), fTyz+fTwx);
    }
    
    /** Returns the Z orthonormal axis defining the quaternion. Same as doing
        zAxis = Vector3::UNIT_Z * this. Also called the local Z-axis
    */
    Vector3 zAxis()
    {
        Real fTx  = 2.0f*x;
        Real fTy  = 2.0f*y;
        Real fTz  = 2.0f*z;
        Real fTwx = fTx*w;
        Real fTwy = fTy*w;
        Real fTxx = fTx*x;
        Real fTxz = fTz*x;
        Real fTyy = fTy*y;
        Real fTyz = fTz*y;

        return Vector3(fTxz+fTwy, fTyz-fTwx, 1.0f-(fTxx+fTyy));
    }


    //-----------------------------------------------------------------------
    Quaternion opAdd (Quaternion rkQ)
    {
        return Quaternion(w+rkQ.w,x+rkQ.x,y+rkQ.y,z+rkQ.z);
    }
    //-----------------------------------------------------------------------
    Quaternion opSub (Quaternion rkQ)
    {
        return Quaternion(w-rkQ.w,x-rkQ.x,y-rkQ.y,z-rkQ.z);
    }
    //-----------------------------------------------------------------------
    Quaternion opMul (Quaternion rkQ)
    {
        // NOTE:  Multiplication is not generally commutative, so in most
        // cases p*q != q*p.

        return Quaternion
        (
            w * rkQ.w - x * rkQ.x - y * rkQ.y - z * rkQ.z,
            w * rkQ.x + x * rkQ.w + y * rkQ.z - z * rkQ.y,
            w * rkQ.y + y * rkQ.w + z * rkQ.x - x * rkQ.z,
            w * rkQ.z + z * rkQ.w + x * rkQ.y - y * rkQ.x
        );
    }
    //-----------------------------------------------------------------------
    Quaternion opMul (Real fScalar)
    {
        return Quaternion(fScalar*w,fScalar*x,fScalar*y,fScalar*z);
    }
    Quaternion opMul_r (Real fScalar)
    {
        return Quaternion(fScalar*w,fScalar*x,fScalar*y,fScalar*z);
    }
    //-----------------------------------------------------------------------
    /*Quaternion opMul (Real fScalar,Quaternion rkQ)
    {
        return Quaternion(fScalar*rkQ.w,fScalar*rkQ.x,fScalar*rkQ.y,
            fScalar*rkQ.z);
    }*/
    //-----------------------------------------------------------------------
    Quaternion opUnary (string op)()
    {
        if (op == "-")
            return Quaternion(-w,-x,-y,-z);
        assert(0); //Need?
    }
    
    /// Returns the dot product of the quaternion
    Real Dot (Quaternion rkQ)
    {
        return w*rkQ.w+x*rkQ.x+y*rkQ.y+z*rkQ.z;
    }
    
    /* Returns the normal length of this quaternion.
        @note This does <b>not</b> alter any values.
    */
    Real Norm ()
    {
        return w*w+x*x+y*y+z*z;
    }
    // apply to non-zero quaternion
    Quaternion Inverse ()
    {
        Real fNorm = w*w+x*x+y*y+z*z;
        if ( fNorm > 0.0 )
        {
            Real fInvNorm = 1.0f/fNorm;
            return Quaternion(w*fInvNorm,-x*fInvNorm,-y*fInvNorm,-z*fInvNorm);
        }
        else
        {
            // return an invalid result to flag the error
            return ZERO;
        }
    }
    
    // apply to unit-length quaternion
    Quaternion UnitInverse ()
    {
        // assert:  'this' is unit length
        return Quaternion(w,-x,-y,-z);
    }
    //-----------------------------------------------------------------------
    Quaternion Exp ()
    {
        // If q = A*(x*i+y*j+z*k) where (x,y,z) is unit length, then
        // exp(q) = cos(A)+sin(A)*(x*i+y*j+z*k).  If sin(A) is near zero,
        // use exp(q) = cos(A)+A*(x*i+y*j+z*k) since A/sin(A) has limit 1.

        Radian fAngle = Radian ( Math.Sqrt(x*x+y*y+z*z) );
        Real fSin = Math.Sin(fAngle);

        Quaternion kResult;
        kResult.w = Math.Cos(fAngle);

        if ( Math.Abs(fSin) >= msEpsilon )
        {
            Real fCoeff = fSin/(fAngle.valueRadians());
            kResult.x = fCoeff*x;
            kResult.y = fCoeff*y;
            kResult.z = fCoeff*z;
        }
        else
        {
            kResult.x = x;
            kResult.y = y;
            kResult.z = z;
        }

        return kResult;
    }
    //-----------------------------------------------------------------------
    Quaternion Log ()
    {
        // If q = cos(A)+sin(A)*(x*i+y*j+z*k) where (x,y,z) is unit length, then
        // log(q) = A*(x*i+y*j+z*k).  If sin(A) is near zero, use log(q) =
        // sin(A)*(x*i+y*j+z*k) since sin(A)/A has limit 1.

        Quaternion kResult;
        kResult.w = 0.0;

        if ( Math.Abs(w) < 1.0 )
        {
            Radian fAngle = Math.ACos(w);
            Real fSin = Math.Sin(fAngle);
            if ( Math.Abs(fSin) >= msEpsilon )
            {
                Real fCoeff = fAngle.valueRadians()/fSin;
                kResult.x = fCoeff*x;
                kResult.y = fCoeff*y;
                kResult.z = fCoeff*z;
                return kResult;
            }
        }

        kResult.x = x;
        kResult.y = y;
        kResult.z = z;

        return kResult;
    }

    /// Rotation of a vector by a quaternion
   Vector3 opMul (Vector3 v)
    {
        // nVidia SDK implementation
        Vector3 uv, uuv;
        Vector3 qvec = Vector3(x, y, z);
        uv = qvec.crossProduct(v);
        uuv = qvec.crossProduct(uv);
        uv *= (2.0f * w);
        uuv *= 2.0f;

        return v + uv + uuv;
    }
    
    /// Equality with tolerance (tolerance is max angle difference)
    bool equals(Quaternion rhs, Radian tolerance) //const
    {
        Real fCos = Dot(rhs);
        Radian angle = Math.ACos(fCos);

        return (Math.Abs(angle.valueRadians()) <= tolerance.valueRadians())
            || Math.RealEqual(angle.valueRadians(), Math.PI, tolerance.valueRadians());


    }
    
    /** Performs Spherical linear interpolation between two quaternions, and returns the result.
        Slerp ( 0.0f, A, B ) = A
        Slerp ( 1.0f, A, B ) = B
        @return Interpolated quaternion
        @remarks
        Slerp has the proprieties of performing the interpolation atant
        velocity, and being torque-minimal (unless shortestPath=false).
        However, it's NOT commutative, which means
        Slerp ( 0.75f, A, B ) != Slerp ( 0.25f, B, A );
        Therefore be caref ul if your code relies in the order of the operands.
        This is specially important in IK animation.
    */
    static Quaternion Slerp (Real fT,Quaternion rkP,
       Quaternion rkQ, bool shortestPath = false)
    {
        Real fCos = rkP.Dot(rkQ);
        Quaternion rkT;

        // Do we need to invert rotation?
        if (fCos < 0.0f && shortestPath)
        {
            fCos = -fCos;
            rkT = -rkQ;
        }
        else
        {
            rkT = rkQ;
        }

        if (Math.Abs(fCos) < 1 - msEpsilon)
        {
            // Standard case (slerp)
            Real fSin = Math.Sqrt(1 - Math.Sqr(fCos));
            Radian fAngle = Math.ATan2(fSin, fCos);
            Real fInvSin = 1.0f / fSin;
            Real fCoeff0 = Math.Sin((1.0f - fT) * fAngle) * fInvSin;
            Real fCoeff1 = Math.Sin(fT * fAngle) * fInvSin;
            return fCoeff0 * rkP + fCoeff1 * rkT;
        }
        else
        {
            // There are two situations:
            // 1. "rkP" and "rkQ" are very close (fCos ~= +1), so we can do a linear
            //    interpolation safely.
            // 2. "rkP" and "rkQ" are almost inverse of each other (fCos ~= -1), there
            //    are an infinite number of possibilities interpolation. but we haven't
            //    have method to fix this case, so just use linear interpolation here.
            Quaternion t = (1.0f - fT) * rkP + fT * rkT;
            // taking the complement requires renormalisation
            t.normalise();
            return t;
        }
    }
    
    /** @see Slerp. It adds extra "spins" (i.e. rotates several times) specified
        by parameter 'iExtraSpins' while interpolating before arriving to the
        final values
    */
    static Quaternion SlerpExtraSpins (Real fT,
       Quaternion rkP,Quaternion rkQ, int iExtraSpins)
    {
        Real fCos = rkP.Dot(rkQ);
        Radian fAngle = Math.ACos(fCos);

        if ( Math.Abs(fAngle.valueRadians()) < msEpsilon )
            return rkP;

        Real fSin = Math.Sin(fAngle);
        Radian fPhase = Radian( Math.PI*iExtraSpins*fT );
        Real fInvSin = 1.0f/fSin;
        Real fCoeff0 = Math.Sin((1.0f-fT)*fAngle - fPhase)*fInvSin;
        Real fCoeff1 = Math.Sin(fT*fAngle + fPhase)*fInvSin;
        return fCoeff0*rkP + fCoeff1*rkQ;
    }
    
    // setup for spherical quadratic interpolation
    static void Intermediate (Quaternion rkQ0,
       Quaternion rkQ1,Quaternion rkQ2,
        Quaternion rkA, Quaternion rkB)
    {
        // assert:  q0, q1, q2 are unit quaternions

        Quaternion kQ0inv = rkQ0.UnitInverse();
        Quaternion kQ1inv = rkQ1.UnitInverse();
        Quaternion rkP0 = kQ0inv*rkQ1;
        Quaternion rkP1 = kQ1inv*rkQ2;
        Quaternion kArg = 0.25*(rkP0.Log()-rkP1.Log());
        Quaternion kMinusArg = -kArg;

        rkA = rkQ1*kArg.Exp();
        rkB = rkQ1*kMinusArg.Exp();
    }
    
    // spherical quadratic interpolation
    static Quaternion Squad (Real fT,
       Quaternion rkP,Quaternion rkA,
       Quaternion rkB,Quaternion rkQ, bool shortestPath)
    {
        Real fSlerpT = 2.0f*fT*(1.0f-fT);
        Quaternion kSlerpP = Slerp(fT, rkP, rkQ, shortestPath);
        Quaternion kSlerpQ = Slerp(fT, rkA, rkB);
        return Slerp(fSlerpT, kSlerpP ,kSlerpQ);
    }
    
    /// Normalises this quaternion, and returns the previous length
    Real normalise()
    {
        Real len = Norm();
        Real factor = 1.0f / Math.Sqrt(len);
        this = this * factor;
        return len;
    }
    
    /** Calculate the local roll element of this quaternion.
    @param reprojectAxis By default the method returns the 'intuitive' result
        that is, if you projected the local Y of the quaternion onto the X and
        Y axes, the angle between them is returned. If set to false though, the
        result is the actual yaw that will be used to implement the quaternion,
        which is the shortest possible path to get to the same orientation and 
         may involve less axial rotation.  The co-domain of the returned value is 
         from -180 to 180 degrees.
    */
    Radian getRoll(bool reprojectAxis)
    {
        if (reprojectAxis)
        {
            // roll = atan2(localx.y, localx.x)
            // pick parts of xAxis() implementation that we need
//          Real fTx  = 2.0*x;
            Real fTy  = 2.0f*y;
            Real fTz  = 2.0f*z;
            Real fTwz = fTz*w;
            Real fTxy = fTy*x;
            Real fTyy = fTy*y;
            Real fTzz = fTz*z;

            // Vector3(1.0-(fTyy+fTzz), fTxy+fTwz, fTxz-fTwy);

            return (Math.ATan2(fTxy+fTwz, 1.0f-(fTyy+fTzz)));

        }
        else
        {
            return (Math.ATan2(2*(x*y + w*z), w*w + x*x - y*y - z*z));
        }
    }
    
    /** Calculate the local pitch element of this quaternion
    @param reprojectAxis By default the method returns the 'intuitive' result
        that is, if you projected the local Z of the quaternion onto the X and
        Y axes, the angle between them is returned. If set to true though, the
        result is the actual yaw that will be used to implement the quaternion,
        which is the shortest possible path to get to the same orientation and 
        may involve less axial rotation.  The co-domain of the returned value is 
        from -180 to 180 degrees.
    */
    Radian getPitch(bool reprojectAxis)
    {
        if (reprojectAxis)
        {
            // pitch = atan2(localy.z, localy.y)
            // pick parts of yAxis() implementation that we need
            Real fTx  = 2.0f*x;
//          Real fTy  = 2.0f*y;
            Real fTz  = 2.0f*z;
            Real fTwx = fTx*w;
            Real fTxx = fTx*x;
            Real fTyz = fTz*y;
            Real fTzz = fTz*z;

            // Vector3(fTxy-fTwz, 1.0-(fTxx+fTzz), fTyz+fTwx);
            return (Math.ATan2(fTyz+fTwx, 1.0f-(fTxx+fTzz)));
        }
        else
        {
            // internal version
            return (Math.ATan2(2*(y*z + w*x), w*w - x*x - y*y + z*z));
        }
    }
    
    /** Calculate the local yaw element of this quaternion
    @param reprojectAxis By default the method returns the 'intuitive' result
        that is, if you projected the local Y of the quaternion onto the X and
        Z axes, the angle between them is returned. If set to true though, the
        result is the actual yaw that will be used to implement the quaternion,
        which is the shortest possible path to get to the same orientation and 
        may involve less axial rotation. The co-domain of the returned value is 
        from -180 to 180 degrees.
    */
    Radian getYaw(bool reprojectAxis)
    {
        if (reprojectAxis)
        {
            // yaw = atan2(localz.x, localz.z)
            // pick parts of zAxis() implementation that we need
            Real fTx  = 2.0f*x;
            Real fTy  = 2.0f*y;
            Real fTz  = 2.0f*z;
            Real fTwy = fTy*w;
            Real fTxx = fTx*x;
            Real fTxz = fTz*x;
            Real fTyy = fTy*y;

            // Vector3(fTxz+fTwy, fTyz-fTwx, 1.0-(fTxx+fTyy));

            return (Math.ATan2(fTxz+fTwy, 1.0f-(fTxx+fTyy)));

        }
        else
        {
            // internal version
            return Math.ASin(-2*(x*z - w*y));
        }
    }
    
    /** Performs Normalised linear interpolation between two quaternions, and returns the result.
        nlerp ( 0.0f, A, B ) = A
        nlerp ( 1.0f, A, B ) = B
        @remarks
        Nlerp is faster than Slerp.
        Nlerp has the proprieties of being commutative (@see Slerp;
        commutativity is desired in certain places, like IK animation), and
        being torque-minimal (unless shortestPath=false). However, it's performing
        the interpolation at non-constant velocity; sometimes this is desired,
        sometimes it is not. Having a non-constant velocity can produce a more
        natural rotation feeling without the need of tweaking the weights; however
        if your scene relies on the timing of the rotation or assumes it will point
        at a specific angle at a specific weight value, Slerp is a better choice.
    */
    static Quaternion nlerp(Real fT,Quaternion rkP,
       Quaternion rkQ, bool shortestPath)
    {
        Quaternion result;
        Real fCos = rkP.Dot(rkQ);
        if (fCos < 0.0f && shortestPath)
        {
            result = rkP + fT * ((-rkQ) - rkP);
        }
        else
        {
            result = rkP + fT * (rkQ - rkP);
        }
        result.normalise();
        return result;
    }
}
/** @} */
/** @} */
