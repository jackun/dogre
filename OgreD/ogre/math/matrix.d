module ogre.math.matrix;

import ogre.compat;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.math.maths;
import ogre.math.plane;
import ogre.math.angles;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Math
 *  @{
 */

/** A 3x3 matrix which can represent rotations around axes.
 @note
 <b>All the code is adapted from the Wild Magic 0.2 Matrix
 library (http://www.geometrictools.com/).</b>
 @par
 The coordinate system is assumed to be <b>right-handed</b>.
 @todo Some places may expect Matrix classes act like structs 
 ie post-blits / "this = oth;"
 */
struct Matrix3
{
    enum Real EPSILON = 1e-06;
    enum Matrix3 ZERO = Matrix3(0,0,0,0,0,0,0,0,0);
    enum Matrix3 IDENTITY = Matrix3(1,0,0,0,1,0,0,0,1);
    enum Real msSvdEpsilon = 1e-04;
    enum uint msSvdMaxIterations = 32;
    
protected:
    Real[3][3] m;

public:

    /** Default constructor.
     @note
     It does <b>NOT</b> initialize the matrix for efficiency.
     */
    //this () {}
    /*static this () 
     {
     ZERO = Matrix3(0,0,0,0,0,0,0,0,0);
     IDENTITY = Matrix3(1,0,0,0,1,0,0,0,1);
     }*/
    this (Real[3][3] arr)
    {
        //memcpy(m,arr,9*sizeof(Real));
        m = arr.dup;
    }
    this (ref Matrix3 rkMatrix)
    {
        //memcpy(m,rkMatrix.m,9*sizeof(Real));
        m = rkMatrix.m.dup;
    }
    this (Real fEntry00, Real fEntry01, Real fEntry02,
          Real fEntry10, Real fEntry11, Real fEntry12,
          Real fEntry20, Real fEntry21, Real fEntry22)
    {
        m[0][0] = fEntry00;
        m[0][1] = fEntry01;
        m[0][2] = fEntry02;
        m[1][0] = fEntry10;
        m[1][1] = fEntry11;
        m[1][2] = fEntry12;
        m[2][0] = fEntry20;
        m[2][1] = fEntry21;
        m[2][2] = fEntry22;
    }

    /** Exchange the contents of this matrix with another. 
     */
    void swap(ref Matrix3 other)
    {
        std.algorithm.swap(m[0][0], other.m[0][0]);
        std.algorithm.swap(m[0][1], other.m[0][1]);
        std.algorithm.swap(m[0][2], other.m[0][2]);
        std.algorithm.swap(m[1][0], other.m[1][0]);
        std.algorithm.swap(m[1][1], other.m[1][1]);
        std.algorithm.swap(m[1][2], other.m[1][2]);
        std.algorithm.swap(m[2][0], other.m[2][0]);
        std.algorithm.swap(m[2][1], other.m[2][1]);
        std.algorithm.swap(m[2][2], other.m[2][2]);
    }

    // member access, allows use ofruct mat[r][c]
    Real* opIndex (size_t iRow)
    {
        return cast(Real*)(m[iRow]);
    }
    
    
    //-----------------------------------------------------------------------
    Vector3 GetColumn (size_t iCol)
    {
        assert( iCol < 3 );
        return Vector3(m[0][iCol],m[1][iCol],
                       m[2][iCol]);
    }
    //-----------------------------------------------------------------------
    void SetColumn(size_t iCol,ref Vector3 vec)
    {
        assert( iCol < 3 );
        m[0][iCol] = vec.x;
        m[1][iCol] = vec.y;
        m[2][iCol] = vec.z;

    }
    //-----------------------------------------------------------------------
    void FromAxes(ref Vector3 xAxis,ref Vector3 yAxis,ref Vector3 zAxis)
    {
        SetColumn(0,xAxis);
        SetColumn(1,yAxis);
        SetColumn(2,zAxis);

    }

    // assignment and comparison
    Matrix3 opAssign (ref Matrix3 rkMatrix)
    {
        //memcpy(m,rkMatrix.m,9*sizeof(Real));
        m = rkMatrix.m.dup;
        return this;
    }

    Matrix3 opAssign (Matrix3 rkMatrix)
    {
        //memcpy(m,rkMatrix.m,9*sizeof(Real));
        m = rkMatrix.m.dup;
        return this;
    }
    
    Real opIndexAssign (Real val, size_t iRow, size_t iCol)
    {
        return (m[iRow][iCol] = val);
    }

    //-----------------------------------------------------------------------
    bool opEquals (Matrix3 rkMatrix)
    {
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
            {
                if ( m[iRow][iCol] != rkMatrix.m[iRow][iCol] )
                    return false;
            }
        }

        return true;
    }
    //-----------------------------------------------------------------------
    Matrix3 opAdd (Matrix3 rkMatrix)
    {
        Matrix3 kSum = Matrix3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
            {
                kSum.m[iRow][iCol] = m[iRow][iCol] +
                    rkMatrix.m[iRow][iCol];
            }
        }
        return kSum;
    }
    //-----------------------------------------------------------------------
    Matrix3 opSub (Matrix3 rkMatrix)
    {
        Matrix3 kDiff = Matrix3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
            {
                kDiff.m[iRow][iCol] = m[iRow][iCol] -
                    rkMatrix.m[iRow][iCol];
            }
        }
        return kDiff;
    }
    //-----------------------------------------------------------------------
    Matrix3 opMul (Matrix3 rkMatrix)
    {
        Matrix3 kProd = Matrix3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
            {
                kProd.m[iRow][iCol] =
                    m[iRow][0]*rkMatrix.m[0][iCol] +
                        m[iRow][1]*rkMatrix.m[1][iCol] +
                        m[iRow][2]*rkMatrix.m[2][iCol];
            }
        }
        return kProd;
    }
    //-----------------------------------------------------------------------
    Vector3 opMul (Vector3 rkPoint)
    {
        Vector3 kProd = Vector3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            kProd[iRow] =
                m[iRow][0]*rkPoint[0] +
                    m[iRow][1]*rkPoint[1] +
                    m[iRow][2]*rkPoint[2];
        }
        return kProd;
    }
    //-----------------------------------------------------------------------
    Vector3 opMul_r (Vector3 rkPoint /*,Matrix3 rkMatrix*/)
    {
        Vector3 kProd;
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            kProd[iRow] =
                rkPoint[0]* /*rkMatrix.*/m[0][iRow] +
                    rkPoint[1]*/*rkMatrix.*/m[1][iRow] +
                    rkPoint[2]*/*rkMatrix.*/m[2][iRow];
        }
        return kProd;
    }
    //-----------------------------------------------------------------------
    Matrix3 opUnary (string op)()
    {
        if(op == "-")
        {
            Matrix3 kNeg = Matrix3();
            for (size_t iRow = 0; iRow < 3; iRow++)
            {
                for (size_t iCol = 0; iCol < 3; iCol++)
                    kNeg[iRow][iCol] = -m[iRow][iCol];
            }
            return kNeg;
        }
        assert(0);
    }
    //-----------------------------------------------------------------------
    Matrix3 opMul (Real fScalar)
    {
        Matrix3 kProd = Matrix3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
                kProd[iRow][iCol] = fScalar*m[iRow][iCol];
        }
        return kProd;
    }
    //-----------------------------------------------------------------------
    Matrix3 opMul (Real fScalar,ref Matrix3 rkMatrix)
    {
        Matrix3 kProd = Matrix3();
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
                kProd[iRow][iCol] = fScalar*rkMatrix.m[iRow][iCol];
        }
        return kProd;
    }
    //-----------------------------------------------------------------------
    Matrix3 Transpose ()
    {
        Matrix3 kTranspose;
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
                kTranspose[iRow][iCol] = m[iCol][iRow];
        }
        return kTranspose;
    }
    //-----------------------------------------------------------------------
    bool Inverse (ref Matrix3 rkInverse, Real fTolerance = 1e-06)
    {
        // Invert a 3x3 using cofactors.  This is about 8 times faster than
        // the Numerical Recipes code which uses Gaussian elimination.

        rkInverse[0, 0] = m[1][1]*m[2][2] -
            m[1][2]*m[2][1];
        rkInverse[0, 1] = m[0][2]*m[2][1] -
            m[0][1]*m[2][2];
        rkInverse[0, 2] = m[0][1]*m[1][2] -
            m[0][2]*m[1][1];
        rkInverse[1, 0] = m[1][2]*m[2][0] -
            m[1][0]*m[2][2];
        rkInverse[1, 1] = m[0][0]*m[2][2] -
            m[0][2]*m[2][0];
        rkInverse[1, 2] = m[0][2]*m[1][0] -
            m[0][0]*m[1][2];
        rkInverse[2, 0] = m[1][0]*m[2][1] -
            m[1][1]*m[2][0];
        rkInverse[2, 1] = m[0][1]*m[2][0] -
            m[0][0]*m[2][1];
        rkInverse[2, 2] = m[0][0]*m[1][1] -
            m[0][1]*m[1][0];

        Real fDet =
            m[0][0]*rkInverse[0][0] +
                m[0][1]*rkInverse[1][0]+
                m[0][2]*rkInverse[2][0];

        if ( Math.Abs(fDet) <= fTolerance )
            return false;

        Real fInvDet = 1.0f/fDet;
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
                rkInverse[iRow][iCol] *= fInvDet;
        }

        return true;
    }
    //-----------------------------------------------------------------------
    Matrix3 Inverse (Real fTolerance = 1e-06)
    {
        Matrix3 kInverse;
        Inverse(kInverse,fTolerance);
        return kInverse;
    }
    //-----------------------------------------------------------------------
    Real Determinant ()
    {
        Real fCofactor00 = m[1][1]*m[2][2] -
            m[1][2]*m[2][1];
        Real fCofactor10 = m[1][2]*m[2][0] -
            m[1][0]*m[2][2];
        Real fCofactor20 = m[1][0]*m[2][1] -
            m[1][1]*m[2][0];

        Real fDet =
            m[0][0]*fCofactor00 +
                m[0][1]*fCofactor10 +
                m[0][2]*fCofactor20;

        return fDet;
    }
    //-----------------------------------------------------------------------
    void Bidiagonalize (ref Matrix3 kA, ref Matrix3 kL,
                        ref Matrix3 kR)
    {
        Real[3] afV, afW;
        Real fLength, fSign, fT1, fInvT1, fT2;
        bool bIdentity;

        // map first column to (*,0,0)
        fLength = Math.Sqrt(kA[0][0]*kA[0][0] + kA[1][0]*kA[1][0] +
                            kA[2][0]*kA[2][0]);
        if ( fLength > 0.0 )
        {
            fSign = (kA[0][0] > 0.0f ? 1.0f : -1.0f);
            fT1 = kA[0][0] + fSign*fLength;
            fInvT1 = 1.0f/fT1;
            afV[1] = kA[1][0]*fInvT1;
            afV[2] = kA[2][0]*fInvT1;

            fT2 = -2.0f/(1.0f+afV[1]*afV[1]+afV[2]*afV[2]);
            afW[0] = fT2*(kA[0][0]+kA[1][0]*afV[1]+kA[2][0]*afV[2]);
            afW[1] = fT2*(kA[0][1]+kA[1][1]*afV[1]+kA[2][1]*afV[2]);
            afW[2] = fT2*(kA[0][2]+kA[1][2]*afV[1]+kA[2][2]*afV[2]);
            kA[0][0] += afW[0];
            kA[0][1] += afW[1];
            kA[0][2] += afW[2];
            kA[1][1] += afV[1]*afW[1];
            kA[1][2] += afV[1]*afW[2];
            kA[2][1] += afV[2]*afW[1];
            kA[2][2] += afV[2]*afW[2];

            kL[0, 0] = 1.0f+fT2;
            kL[0, 1] = kL[1, 0] = fT2*afV[1];
            kL[0, 2] = kL[2, 0] = fT2*afV[2];
            kL[1, 1] = 1.0f+fT2*afV[1]*afV[1];
            kL[1, 2] = kL[2, 1] = fT2*afV[1]*afV[2];
            kL[2, 2] = 1.0f+fT2*afV[2]*afV[2];
            bIdentity = false;
        }
        else
        {
            kL = IDENTITY;
            bIdentity = true;
        }

        // map first row to (*,*,0)
        fLength = Math.Sqrt(kA[0][1]*kA[0][1]+kA[0][2]*kA[0][2]);
        if ( fLength > 0.0 )
        {
            fSign = (kA[0][1] > 0.0f ? 1.0f : -1.0f);
            fT1 = kA[0][1] + fSign*fLength;
            afV[2] = kA[0][2]/fT1;

            fT2 = -2.0f/(1.0f+afV[2]*afV[2]);
            afW[0] = fT2*(kA[0][1]+kA[0][2]*afV[2]);
            afW[1] = fT2*(kA[1][1]+kA[1][2]*afV[2]);
            afW[2] = fT2*(kA[2][1]+kA[2][2]*afV[2]);
            kA[0][1] += afW[0];
            kA[1][1] += afW[1];
            kA[1][2] += afW[1]*afV[2];
            kA[2][1] += afW[2];
            kA[2][2] += afW[2]*afV[2];

            kR[0, 0] = 1.0;
            kR[0, 1] = kR[1, 0] = 0.0;
            kR[0, 2] = kR[2, 0] = 0.0;
            kR[1, 1] = 1.0f+fT2;
            kR[1, 2] = kR[2, 1] = fT2*afV[2];
            kR[2, 2] = 1.0f+fT2*afV[2]*afV[2];
        }
        else
        {
            kR = IDENTITY;
        }

        // map second column to (*,*,0)
        fLength = Math.Sqrt(kA[1][1]*kA[1][1]+kA[2][1]*kA[2][1]);
        if ( fLength > 0.0 )
        {
            fSign = (kA[1][1] > 0.0f ? 1.0f : -1.0f);
            fT1 = kA[1][1] + fSign*fLength;
            afV[2] = kA[2][1]/fT1;

            fT2 = -2.0f/(1.0f+afV[2]*afV[2]);
            afW[1] = fT2*(kA[1][1]+kA[2][1]*afV[2]);
            afW[2] = fT2*(kA[1][2]+kA[2][2]*afV[2]);
            kA[1][1] += afW[1];
            kA[1][2] += afW[2];
            kA[2][2] += afV[2]*afW[2];

            Real fA = 1.0f+fT2;
            Real fB = fT2*afV[2];
            Real fC = 1.0f+fB*afV[2];

            if ( bIdentity )
            {
                kL[0, 0] = 1.0;
                kL[0, 1] = kL[1, 0] = 0.0;
                kL[0, 2] = kL[2, 0] = 0.0;
                kL[1, 1] = fA;
                kL[1, 2] = kL[2, 1] = fB;
                kL[2, 2] = fC;
            }
            else
            {
                for (int iRow = 0; iRow < 3; iRow++)
                {
                    Real fTmp0 = kL[iRow][1];
                    Real fTmp1 = kL[iRow][2];
                    kL[iRow][1] = fA*fTmp0+fB*fTmp1;
                    kL[iRow][2] = fB*fTmp0+fC*fTmp1;
                }
            }
        }
    }
    //-----------------------------------------------------------------------
    void GolubKahanStep (ref Matrix3 kA, ref Matrix3 kL,
                         ref Matrix3 kR)
    {
        Real fT11 = kA[0][1]*kA[0][1]+kA[1][1]*kA[1][1];
        Real fT22 = kA[1][2]*kA[1][2]+kA[2][2]*kA[2][2];
        Real fT12 = kA[1][1]*kA[1][2];
        Real fTrace = fT11+fT22;
        Real fDiff = fT11-fT22;
        Real fDiscr = Math.Sqrt(fDiff*fDiff+4.0f*fT12*fT12);
        Real fRoot1 = 0.5f*(fTrace+fDiscr);
        Real fRoot2 = 0.5f*(fTrace-fDiscr);

        // adjust right
        Real fY = kA[0][0] - (Math.Abs(fRoot1-fT22) <=
                              Math.Abs(fRoot2-fT22) ? fRoot1 : fRoot2);
        Real fZ = kA[0][1];
        Real fInvLength = Math.InvSqrt(fY*fY+fZ*fZ);
        Real fSin = fZ*fInvLength;
        Real fCos = -fY*fInvLength;

        Real fTmp0 = kA[0][0];
        Real fTmp1 = kA[0][1];
        kA[0, 0] = fCos*fTmp0-fSin*fTmp1;
        kA[0, 1] = fSin*fTmp0+fCos*fTmp1;
        kA[1, 0] = -fSin*kA[1][1];
        kA[1][1] *= fCos;

        size_t iRow;
        for (iRow = 0; iRow < 3; iRow++)
        {
            fTmp0 = kR[0][iRow];
            fTmp1 = kR[1][iRow];
            kR[0][iRow] = fCos*fTmp0-fSin*fTmp1;
            kR[1][iRow] = fSin*fTmp0+fCos*fTmp1;
        }

        // adjust left
        fY = kA[0][0];
        fZ = kA[1][0];
        fInvLength = Math.InvSqrt(fY*fY+fZ*fZ);
        fSin = fZ*fInvLength;
        fCos = -fY*fInvLength;

        kA[0, 0] = fCos*kA[0][0]-fSin*kA[1][0];
        fTmp0 = kA[0][1];
        fTmp1 = kA[1][1];
        kA[0, 1] = fCos*fTmp0-fSin*fTmp1;
        kA[1, 1] = fSin*fTmp0+fCos*fTmp1;
        kA[0, 2] = -fSin*kA[1][2];
        kA[1][2] *= fCos;

        size_t iCol;
        for (iCol = 0; iCol < 3; iCol++)
        {
            fTmp0 = kL[iCol][0];
            fTmp1 = kL[iCol][1];
            kL[iCol][0] = fCos*fTmp0-fSin*fTmp1;
            kL[iCol][1] = fSin*fTmp0+fCos*fTmp1;
        }

        // adjust right
        fY = kA[0][1];
        fZ = kA[0][2];
        fInvLength = Math.InvSqrt(fY*fY+fZ*fZ);
        fSin = fZ*fInvLength;
        fCos = -fY*fInvLength;

        kA[0, 1] = fCos*kA[0][1]-fSin*kA[0][2];
        fTmp0 = kA[1][1];
        fTmp1 = kA[1][2];
        kA[1, 1] = fCos*fTmp0-fSin*fTmp1;
        kA[1, 2] = fSin*fTmp0+fCos*fTmp1;
        kA[2, 1] = -fSin*kA[2][2];
        kA[2][2] *= fCos;

        for (iRow = 0; iRow < 3; iRow++)
        {
            fTmp0 = kR[1][iRow];
            fTmp1 = kR[2][iRow];
            kR[1][iRow] = fCos*fTmp0-fSin*fTmp1;
            kR[2][iRow] = fSin*fTmp0+fCos*fTmp1;
        }

        // adjust left
        fY = kA[1][1];
        fZ = kA[2][1];
        fInvLength = Math.InvSqrt(fY*fY+fZ*fZ);
        fSin = fZ*fInvLength;
        fCos = -fY*fInvLength;

        kA[1, 1] = fCos*kA[1][1]-fSin*kA[2][1];
        fTmp0 = kA[1][2];
        fTmp1 = kA[2][2];
        kA[1, 2] = fCos*fTmp0-fSin*fTmp1;
        kA[2, 2] = fSin*fTmp0+fCos*fTmp1;

        for (iCol = 0; iCol < 3; iCol++)
        {
            fTmp0 = kL[iCol][1];
            fTmp1 = kL[iCol][2];
            kL[iCol][1] = fCos*fTmp0-fSin*fTmp1;
            kL[iCol][2] = fSin*fTmp0+fCos*fTmp1;
        }
    }
    //-----------------------------------------------------------------------
    void SingularValueDecomposition (ref Matrix3 kL, ref Vector3 kS,
                                     ref Matrix3 kR)
    {
        // temas: currently unused
        //int iMax = 16;
        size_t iRow, iCol;

        Matrix3 kA = this.copy();
        Bidiagonalize(kA,kL,kR);

        for (uint i = 0; i < msSvdMaxIterations; i++)
        {
            Real fTmp, fTmp0, fTmp1;
            Real fSin0, fCos0, fTan0;
            Real fSin1, fCos1, fTan1;

            bool bTest1 = (Math.Abs(kA[0][1]) <=
                           msSvdEpsilon*(Math.Abs(kA[0][0])+Math.Abs(kA[1][1])));
            bool bTest2 = (Math.Abs(kA[1][2]) <=
                           msSvdEpsilon*(Math.Abs(kA[1][1])+Math.Abs(kA[2][2])));
            if ( bTest1 )
            {
                if ( bTest2 )
                {
                    kS[0] = kA[0][0];
                    kS[1] = kA[1][1];
                    kS[2] = kA[2][2];
                    break;
                }
                else
                {
                    // 2x2 closed form factorization
                    fTmp = (kA[1][1]*kA[1][1] - kA[2][2]*kA[2][2] +
                            kA[1][2]*kA[1][2])/(kA[1][2]*kA[2][2]);
                    fTan0 = 0.5f*(fTmp+Math.Sqrt(fTmp*fTmp + 4.0f));
                    fCos0 = Math.InvSqrt(1.0f+fTan0*fTan0);
                    fSin0 = fTan0*fCos0;

                    for (iCol = 0; iCol < 3; iCol++)
                    {
                        fTmp0 = kL[iCol][1];
                        fTmp1 = kL[iCol][2];
                        kL[iCol][1] = fCos0*fTmp0-fSin0*fTmp1;
                        kL[iCol][2] = fSin0*fTmp0+fCos0*fTmp1;
                    }

                    fTan1 = (kA[1][2]-kA[2][2]*fTan0)/kA[1][1];
                    fCos1 = Math.InvSqrt(1.0f+fTan1*fTan1);
                    fSin1 = -fTan1*fCos1;

                    for (iRow = 0; iRow < 3; iRow++)
                    {
                        fTmp0 = kR[1][iRow];
                        fTmp1 = kR[2][iRow];
                        kR[1][iRow] = fCos1*fTmp0-fSin1*fTmp1;
                        kR[2][iRow] = fSin1*fTmp0+fCos1*fTmp1;
                    }

                    kS[0] = kA[0][0];
                    kS[1] = fCos0*fCos1*kA[1][1] -
                        fSin1*(fCos0*kA[1][2]-fSin0*kA[2][2]);
                    kS[2] = fSin0*fSin1*kA[1][1] +
                        fCos1*(fSin0*kA[1][2]+fCos0*kA[2][2]);
                    break;
                }
            }
            else
            {
                if ( bTest2 )
                {
                    // 2x2 closed form factorization
                    fTmp = (kA[0][0]*kA[0][0] + kA[1][1]*kA[1][1] -
                            kA[0][1]*kA[0][1])/(kA[0][1]*kA[1][1]);
                    fTan0 = 0.5f*(-fTmp+Math.Sqrt(fTmp*fTmp + 4.0f));
                    fCos0 = Math.InvSqrt(1.0f+fTan0*fTan0);
                    fSin0 = fTan0*fCos0;

                    for (iCol = 0; iCol < 3; iCol++)
                    {
                        fTmp0 = kL[iCol][0];
                        fTmp1 = kL[iCol][1];
                        kL[iCol][0] = fCos0*fTmp0-fSin0*fTmp1;
                        kL[iCol][1] = fSin0*fTmp0+fCos0*fTmp1;
                    }

                    fTan1 = (kA[0][1]-kA[1][1]*fTan0)/kA[0][0];
                    fCos1 = Math.InvSqrt(1.0f+fTan1*fTan1);
                    fSin1 = -fTan1*fCos1;

                    for (iRow = 0; iRow < 3; iRow++)
                    {
                        fTmp0 = kR[0][iRow];
                        fTmp1 = kR[1][iRow];
                        kR[0][iRow] = fCos1*fTmp0-fSin1*fTmp1;
                        kR[1][iRow] = fSin1*fTmp0+fCos1*fTmp1;
                    }

                    kS[0] = fCos0*fCos1*kA[0][0] -
                        fSin1*(fCos0*kA[0][1]-fSin0*kA[1][1]);
                    kS[1] = fSin0*fSin1*kA[0][0] +
                        fCos1*(fSin0*kA[0][1]+fCos0*kA[1][1]);
                    kS[2] = kA[2][2];
                    break;
                }
                else
                {
                    GolubKahanStep(kA,kL,kR);
                }
            }
        }

        // positize diagonal
        for (iRow = 0; iRow < 3; iRow++)
        {
            if ( kS[iRow] < 0.0 )
            {
                kS[iRow] = -kS[iRow];
                for (iCol = 0; iCol < 3; iCol++)
                    kR[iRow][iCol] = -kR[iRow][iCol];
            }
        }
    }
    //-----------------------------------------------------------------------
    void SingularValueComposition (ref Matrix3 kL,
                                   ref Vector3 kS,ref Matrix3 kR)
    {
        size_t iRow, iCol;
        Matrix3 kTmp;

        // product S*R
        for (iRow = 0; iRow < 3; iRow++)
        {
            for (iCol = 0; iCol < 3; iCol++)
                kTmp[iRow][iCol] = kS[iRow]*kR[iRow][iCol];
        }

        // product L*S*R
        for (iRow = 0; iRow < 3; iRow++)
        {
            for (iCol = 0; iCol < 3; iCol++)
            {
                m[iRow][iCol] = 0.0;
                for (int iMid = 0; iMid < 3; iMid++)
                    m[iRow][iCol] += kL[iRow][iMid]*kTmp[iMid][iCol];
            }
        }
    }
    //-----------------------------------------------------------------------
    void Orthonormalize ()
    {
        // Algorithm uses Gram-Schmidt orthogonalization.  If 'this' matrix is
        // M = [m0|m1|m2], then orthonormal output matrix is Q = [q0|q1|q2],
        //
        //   q0 = m0/|m0|
        //   q1 = (m1-(q0*m1)q0)/|m1-(q0*m1)q0|
        //   q2 = (m2-(q0*m2)q0-(q1*m2)q1)/|m2-(q0*m2)q0-(q1*m2)q1|
        //
        // where |V| indicates length of vector V and A*B indicates dot
        // product of vectors A and B.

        // compute q0
        Real fInvLength = Math.InvSqrt(m[0][0]*m[0][0]
                                       + m[1][0]*m[1][0] +
                                       m[2][0]*m[2][0]);

        m[0][0] *= fInvLength;
        m[1][0] *= fInvLength;
        m[2][0] *= fInvLength;

        // compute q1
        Real fDot0 =
            m[0][0]*m[0][1] +
                m[1][0]*m[1][1] +
                m[2][0]*m[2][1];

        m[0][1] -= fDot0*m[0][0];
        m[1][1] -= fDot0*m[1][0];
        m[2][1] -= fDot0*m[2][0];

        fInvLength = Math.InvSqrt(m[0][1]*m[0][1] +
                                  m[1][1]*m[1][1] +
                                  m[2][1]*m[2][1]);

        m[0][1] *= fInvLength;
        m[1][1] *= fInvLength;
        m[2][1] *= fInvLength;

        // compute q2
        Real fDot1 =
            m[0][1]*m[0][2] +
                m[1][1]*m[1][2] +
                m[2][1]*m[2][2];

        fDot0 =
            m[0][0]*m[0][2] +
                m[1][0]*m[1][2] +
                m[2][0]*m[2][2];

        m[0][2] -= fDot0*m[0][0] + fDot1*m[0][1];
        m[1][2] -= fDot0*m[1][0] + fDot1*m[1][1];
        m[2][2] -= fDot0*m[2][0] + fDot1*m[2][1];

        fInvLength = Math.InvSqrt(m[0][2]*m[0][2] +
                                  m[1][2]*m[1][2] +
                                  m[2][2]*m[2][2]);

        m[0][2] *= fInvLength;
        m[1][2] *= fInvLength;
        m[2][2] *= fInvLength;
    }
    //-----------------------------------------------------------------------
    void QDUDecomposition (ref Matrix3 kQ,
                           ref Vector3 kD, ref Vector3 kU)
    {
        // Factor M = QR = QDU where Q is orthogonal, D is diagonal,
        // and U is upper triangular with ones on its diagonal.  Algorithm uses
        // Gram-Schmidt orthogonalization (the QR algorithm).
        //
        // If M = [ m0 | m1 | m2 ] and Q = [ q0 | q1 | q2 ], then
        //
        //   q0 = m0/|m0|
        //   q1 = (m1-(q0*m1)q0)/|m1-(q0*m1)q0|
        //   q2 = (m2-(q0*m2)q0-(q1*m2)q1)/|m2-(q0*m2)q0-(q1*m2)q1|
        //
        // where |V| indicates length of vector V and A*B indicates dot
        // product of vectors A and B.  The matrix R has entries
        //
        //   r00 = q0*m0  r01 = q0*m1  r02 = q0*m2
        //   r10 = 0      r11 = q1*m1  r12 = q1*m2
        //   r20 = 0      r21 = 0      r22 = q2*m2
        //
        // so D = diag(r00,r11,r22) and U has entries u01 = r01/r00,
        // u02 = r02/r00, and u12 = r12/r11.

        // Q = rotation
        // D = scaling
        // U = shear

        // D stores the three diagonal entries r00, r11, r22
        // U stores the entries U[0] = u01, U[1] = u02, U[2] = u12

        // build orthogonal matrix Q
        Real fInvLength = Math.InvSqrt(m[0][0]*m[0][0] + m[1][0]*m[1][0] + m[2][0]*m[2][0]);
        
        kQ[0, 0] = m[0][0]*fInvLength;
        kQ[1, 0] = m[1][0]*fInvLength;
        kQ[2, 0] = m[2][0]*fInvLength;

        Real fDot = kQ[0][0]*m[0][1] + kQ[1][0]*m[1][1] +
            kQ[2][0]*m[2][1];
        kQ[0, 1] = m[0][1]-fDot*kQ[0][0];
        kQ[1, 1] = m[1][1]-fDot*kQ[1][0];
        kQ[2, 1] = m[2][1]-fDot*kQ[2][0];
        fInvLength = Math.InvSqrt(kQ[0][1]*kQ[0][1] + kQ[1][1]*kQ[1][1] + kQ[2][1]*kQ[2][1]);
        
        kQ[0][1] *= fInvLength;
        kQ[1][1] *= fInvLength;
        kQ[2][1] *= fInvLength;

        fDot = kQ[0][0]*m[0][2] + kQ[1][0]*m[1][2] +
            kQ[2][0]*m[2][2];
        kQ[0, 2] = m[0][2]-fDot*kQ[0][0];
        kQ[1, 2] = m[1][2]-fDot*kQ[1][0];
        kQ[2, 2] = m[2][2]-fDot*kQ[2][0];
        fDot = kQ[0][1]*m[0][2] + kQ[1][1]*m[1][2] +
            kQ[2][1]*m[2][2];
        kQ[0][2] -= fDot*kQ[0][1];
        kQ[1][2] -= fDot*kQ[1][1];
        kQ[2][2] -= fDot*kQ[2][1];
        fInvLength = Math.InvSqrt(kQ[0][2]*kQ[0][2] + kQ[1][2]*kQ[1][2] + kQ[2][2]*kQ[2][2]);
        
        kQ[0][2] *= fInvLength;
        kQ[1][2] *= fInvLength;
        kQ[2][2] *= fInvLength;

        // guarantee that orthogonal matrix has determinant 1 (no reflections)
        Real fDet = kQ[0][0]*kQ[1][1]*kQ[2][2] + kQ[0][1]*kQ[1][2]*kQ[2][0] +
            kQ[0][2]*kQ[1][0]*kQ[2][1] - kQ[0][2]*kQ[1][1]*kQ[2][0] -
                kQ[0][1]*kQ[1][0]*kQ[2][2] - kQ[0][0]*kQ[1][2]*kQ[2][1];

        if ( fDet < 0.0 )
        {
            for (size_t iRow = 0; iRow < 3; iRow++)
                for (size_t iCol = 0; iCol < 3; iCol++)
                    kQ[iRow][iCol] = -kQ[iRow][iCol];
        }

        // build "right" matrix R
        Matrix3 kR;
        kR[0, 0] = kQ[0][0]*m[0][0] + kQ[1][0]*m[1][0] +
            kQ[2][0]*m[2][0];
        kR[0, 1] = kQ[0][0]*m[0][1] + kQ[1][0]*m[1][1] +
            kQ[2][0]*m[2][1];
        kR[1, 1] = kQ[0][1]*m[0][1] + kQ[1][1]*m[1][1] +
            kQ[2][1]*m[2][1];
        kR[0, 2] = kQ[0][0]*m[0][2] + kQ[1][0]*m[1][2] +
            kQ[2][0]*m[2][2];
        kR[1, 2] = kQ[0][1]*m[0][2] + kQ[1][1]*m[1][2] +
            kQ[2][1]*m[2][2];
        kR[2, 2] = kQ[0][2]*m[0][2] + kQ[1][2]*m[1][2] +
            kQ[2][2]*m[2][2];

        // the scaling component
        kD[0] = kR[0][0];
        kD[1] = kR[1][1];
        kD[2] = kR[2][2];

        // the shear component
        Real fInvD0 = 1.0f/kD[0];
        kU[0] = kR[0][1]*fInvD0;
        kU[1] = kR[0][2]*fInvD0;
        kU[2] = kR[1][2]/kD[1];
    }
    //-----------------------------------------------------------------------
    Real MaxCubicRoot (Real afCoeff[3])
    {
        // Spectral norm is for A^T*A, so characteristic polynomial
        // P(x) = c[0]+c[1]*x+c[2]*x^2+x^3 has three positive real roots.
        // This yields the assertions c[0] < 0 and c[2]*c[2] >= 3*c[1].

        // quick out for uniform scale (triple root)
        Real fOneThird = 1.0/3.0;
        Real fEpsilon = 1e-06;
        Real fDiscr = afCoeff[2]*afCoeff[2] - 3.0f*afCoeff[1];
        if ( fDiscr <= fEpsilon )
            return -fOneThird*afCoeff[2];

        // Compute an upper bound on roots of P(x).  This assumes that A^T*A
        // has been scaled by its largest entry.
        Real fX = 1.0;
        Real fPoly = afCoeff[0]+fX*(afCoeff[1]+fX*(afCoeff[2]+fX));
        if ( fPoly < 0.0 )
        {
            // uses a matrix norm to find an upper bound on maximum root
            fX = Math.Abs(afCoeff[0]);
            Real fTmp = 1.0f+Math.Abs(afCoeff[1]);
            if ( fTmp > fX )
                fX = fTmp;
            fTmp = 1.0f+Math.Abs(afCoeff[2]);
            if ( fTmp > fX )
                fX = fTmp;
        }

        // Newton's method to find root
        Real fTwoC2 = 2.0f*afCoeff[2];
        for (int i = 0; i < 16; i++)
        {
            fPoly = afCoeff[0]+fX*(afCoeff[1]+fX*(afCoeff[2]+fX));
            if ( Math.Abs(fPoly) <= fEpsilon )
                return fX;

            Real fDeriv = afCoeff[1]+fX*(fTwoC2+3.0f*fX);
            fX -= fPoly/fDeriv;
        }

        return fX;
    }
    //-----------------------------------------------------------------------
    Real SpectralNorm ()
    {
        Matrix3 kP;
        size_t iRow, iCol;
        Real fPmax = 0.0;
        for (iRow = 0; iRow < 3; iRow++)
        {
            for (iCol = 0; iCol < 3; iCol++)
            {
                kP[iRow][iCol] = 0.0;
                for (int iMid = 0; iMid < 3; iMid++)
                {
                    kP[iRow][iCol] +=
                        m[iMid][iRow]*m[iMid][iCol];
                }
                if ( kP[iRow][iCol] > fPmax )
                    fPmax = kP[iRow][iCol];
            }
        }

        Real fInvPmax = 1.0f/fPmax;
        for (iRow = 0; iRow < 3; iRow++)
        {
            for (iCol = 0; iCol < 3; iCol++)
                kP[iRow][iCol] *= fInvPmax;
        }

        Real afCoeff[3];
        afCoeff[0] = -(kP[0][0]*(kP[1][1]*kP[2][2]-kP[1][2]*kP[2][1]) +
                       kP[0][1]*(kP[2][0]*kP[1][2]-kP[1][0]*kP[2][2]) +
                       kP[0][2]*(kP[1][0]*kP[2][1]-kP[2][0]*kP[1][1]));
        afCoeff[1] = kP[0][0]*kP[1][1]-kP[0][1]*kP[1][0] +
            kP[0][0]*kP[2][2]-kP[0][2]*kP[2][0] +
                kP[1][1]*kP[2][2]-kP[1][2]*kP[2][1];
        afCoeff[2] = -(kP[0][0]+kP[1][1]+kP[2][2]);

        Real fRoot = MaxCubicRoot(afCoeff);
        Real fNorm = Math.Sqrt(fPmax*fRoot);
        return fNorm;
    }
    
    /** @todo Radian(0.0): make static*/
    void ToAngleAxis (ref Vector3 rkAxis, ref Radian rfRadians)
    {
        // Let (x,y,z) be the unit-length axis and let A be an angle of rotation.
        // The rotation matrix is R = I + sin(A)*P + (1-cos(A))*P^2 where
        // I is the identity and
        //
        //       +-        -+
        //   P = |  0 -z +y |
        //       | +z  0 -x |
        //       | -y +x  0 |
        //       +-        -+
        //
        // If A > 0, R represents a counterclockwise rotation about the axis in
        // the sense of looking from the tip of the axis vector towards the
        // origin.  Some algebra will show that
        //
        //   cos(A) = (trace(R)-1)/2  and  R - R^t = 2*sin(A)*P
        //
        // In the event that A = pi, R-R^t = 0 which prevents us from extracting
        // the axis through P.  Instead note that R = I+2*P^2 when A = pi, so
        // P^2 = (R-I)/2.  The diagonal entries of P^2 are x^2-1, y^2-1, and
        // z^2-1.  We can solve these for axis (x,y,z).  Because the angle is pi,
        // it does not matter which sign you choose on the square roots.

        Real fTrace = m[0][0] + m[1][1] + m[2][2];
        Real fCos = 0.5f*(fTrace-1.0f);
        rfRadians = Math.ACos(fCos);  // in [0,PI]

        if ( rfRadians > Radian(0.0) )
        {
            if ( rfRadians < Radian(Math.PI) )
            {
                rkAxis.x = m[2][1]-m[1][2];
                rkAxis.y = m[0][2]-m[2][0];
                rkAxis.z = m[1][0]-m[0][1];
                rkAxis.normalise();
            }
            else
            {
                // angle is PI
                float fHalfInverse;
                if ( m[0][0] >= m[1][1] )
                {
                    // r00 >= r11
                    if ( m[0][0] >= m[2][2] )
                    {
                        // r00 is maximum diagonal term
                        rkAxis.x = 0.5f*Math.Sqrt(m[0][0] -
                                                  m[1][1] - m[2][2] + 1.0f);
                        fHalfInverse = 0.5f/rkAxis.x;
                        rkAxis.y = fHalfInverse*m[0][1];
                        rkAxis.z = fHalfInverse*m[0][2];
                    }
                    else
                    {
                        // r22 is maximum diagonal term
                        rkAxis.z = 0.5f*Math.Sqrt(m[2][2] -
                                                  m[0][0] - m[1][1] + 1.0f);
                        fHalfInverse = 0.5f/rkAxis.z;
                        rkAxis.x = fHalfInverse*m[0][2];
                        rkAxis.y = fHalfInverse*m[1][2];
                    }
                }
                else
                {
                    // r11 > r00
                    if ( m[1][1] >= m[2][2] )
                    {
                        // r11 is maximum diagonal term
                        rkAxis.y = 0.5f*Math.Sqrt(m[1][1] -
                                                  m[0][0] - m[2][2] + 1.0f);
                        fHalfInverse  = 0.5f/rkAxis.y;
                        rkAxis.x = fHalfInverse*m[0][1];
                        rkAxis.z = fHalfInverse*m[1][2];
                    }
                    else
                    {
                        // r22 is maximum diagonal term
                        rkAxis.z = 0.5f*Math.Sqrt(m[2][2] -
                                                  m[0][0] - m[1][1] + 1.0f);
                        fHalfInverse = 0.5f/rkAxis.z;
                        rkAxis.x = fHalfInverse*m[0][2];
                        rkAxis.y = fHalfInverse*m[1][2];
                    }
                }
            }
        }
        else
        {
            // The angle is 0 and the matrix is the identity.  Any axis will
            // work, so just use the x-axis.
            rkAxis.x = 1.0;
            rkAxis.y = 0.0;
            rkAxis.z = 0.0;
        }
    }
    //-----------------------------------------------------------------------
    void FromAngleAxis (ref Vector3 rkAxis,ref Radian fRadians)
    {
        Real fCos = Math.Cos(fRadians);
        Real fSin = Math.Sin(fRadians);
        Real fOneMinusCos = 1.0f-fCos;
        Real fX2 = rkAxis.x*rkAxis.x;
        Real fY2 = rkAxis.y*rkAxis.y;
        Real fZ2 = rkAxis.z*rkAxis.z;
        Real fXYM = rkAxis.x*rkAxis.y*fOneMinusCos;
        Real fXZM = rkAxis.x*rkAxis.z*fOneMinusCos;
        Real fYZM = rkAxis.y*rkAxis.z*fOneMinusCos;
        Real fXSin = rkAxis.x*fSin;
        Real fYSin = rkAxis.y*fSin;
        Real fZSin = rkAxis.z*fSin;

        m[0][0] = fX2*fOneMinusCos+fCos;
        m[0][1] = fXYM-fZSin;
        m[0][2] = fXZM+fYSin;
        m[1][0] = fXYM+fZSin;
        m[1][1] = fY2*fOneMinusCos+fCos;
        m[1][2] = fYZM-fXSin;
        m[2][0] = fXZM-fYSin;
        m[2][1] = fYZM+fXSin;
        m[2][2] = fZ2*fOneMinusCos+fCos;
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesXYZ (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz          -cy*sz           sy
        //        cz*sx*sy+cx*sz  cx*cz-sx*sy*sz -cy*sx
        //       -cx*cz*sy+sx*sz  cz*sx+cx*sy*sz  cx*cy

        rfPAngle = Math.ASin(m[0][2]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(-m[1][2],m[2][2]);
                rfRAngle = Math.ATan2(-m[0][1],m[0][0]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(m[1][0],m[1][1]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(m[1][0],m[1][1]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesXZY (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz          -sz              cz*sy
        //        sx*sy+cx*cy*sz  cx*cz          -cy*sx+cx*sy*sz
        //       -cx*sy+cy*sx*sz  cz*sx           cx*cy+sx*sy*sz

        rfPAngle = Math.ASin(-m[0][1]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(m[2][1],m[1][1]);
                rfRAngle = Math.ATan2(m[0][2],m[0][0]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(-m[2][0],m[2][2]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(-m[2][0],m[2][2]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesYXZ (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz+sx*sy*sz  cz*sx*sy-cy*sz  cx*sy
        //        cx*sz           cx*cz          -sx
        //       -cz*sy+cy*sx*sz  cy*cz*sx+sy*sz  cx*cy

        rfPAngle = Math.ASin(-m[1][2]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(m[0][2],m[2][2]);
                rfRAngle = Math.ATan2(m[1][0],m[1][1]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(-m[0][1],m[0][0]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(-m[0][1],m[0][0]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesYZX (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz           sx*sy-cx*cy*sz  cx*sy+cy*sx*sz
        //        sz              cx*cz          -cz*sx
        //       -cz*sy           cy*sx+cx*sy*sz  cx*cy-sx*sy*sz

        rfPAngle = Math.ASin(m[1][0]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(-m[2][0],m[0][0]);
                rfRAngle = Math.ATan2(-m[1][2],m[1][1]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(m[2][1],m[2][2]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(m[2][1],m[2][2]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesZXY (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz-sx*sy*sz -cx*sz           cz*sy+cy*sx*sz
        //        cz*sx*sy+cy*sz  cx*cz          -cy*cz*sx+sy*sz
        //       -cx*sy           sx              cx*cy

        rfPAngle = Math.ASin(m[2][1]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(-m[0][1],m[1][1]);
                rfRAngle = Math.ATan2(-m[2][0],m[2][2]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(m[0][2],m[0][0]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(m[0][2],m[0][0]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    bool ToEulerAnglesZYX (ref Radian rfYAngle, ref Radian rfPAngle,
                           ref Radian rfRAngle)
    {
        // rot =  cy*cz           cz*sx*sy-cx*sz  cx*cz*sy+sx*sz
        //        cy*sz           cx*cz+sx*sy*sz -cz*sx+cx*sy*sz
        //       -sy              cy*sx           cx*cy

        rfPAngle = Math.ASin(-m[2][0]);
        if ( rfPAngle < Radian(Math.HALF_PI) )
        {
            if ( rfPAngle > Radian(-Math.HALF_PI) )
            {
                rfYAngle = Math.ATan2(m[1][0],m[0][0]);
                rfRAngle = Math.ATan2(m[2][1],m[2][2]);
                return true;
            }
            else
            {
                // WARNING.  Not a unique solution.
                Radian fRmY = Math.ATan2(-m[0][1],m[0][2]);
                rfRAngle = Radian(0.0);  // any angle works
                rfYAngle = rfRAngle - fRmY;
                return false;
            }
        }
        else
        {
            // WARNING.  Not a unique solution.
            Radian fRpY = Math.ATan2(-m[0][1],m[0][2]);
            rfRAngle = Radian(0.0);  // any angle works
            rfYAngle = fRpY - rfRAngle;
            return false;
        }
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesXYZ (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        this.opAssign(kXMat*(kYMat*kZMat));
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesXZY (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        this.opAssign(kXMat*(kZMat*kYMat));
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesYXZ (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        this.opAssign(kYMat*(kXMat*kZMat));
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesYZX (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        this.opAssign(kYMat*(kZMat*kXMat));
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesZXY (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        this.opAssign(kZMat*(kXMat*kYMat));
    }
    //-----------------------------------------------------------------------
    void FromEulerAnglesZYX (ref Radian fYAngle,ref Radian fPAngle,
                             ref Radian fRAngle)
    {
        Real fCos, fSin;

        fCos = Math.Cos(fYAngle);
        fSin = Math.Sin(fYAngle);
        Matrix3 kZMat = Matrix3(fCos,-fSin,0.0,fSin,fCos,0.0,0.0,0.0,1.0);

        fCos = Math.Cos(fPAngle);
        fSin = Math.Sin(fPAngle);
        Matrix3 kYMat = Matrix3(fCos,0.0,fSin,0.0,1.0,0.0,-fSin,0.0,fCos);

        fCos = Math.Cos(fRAngle);
        fSin = Math.Sin(fRAngle);
        Matrix3 kXMat = Matrix3(1.0,0.0,0.0,0.0,fCos,-fSin,0.0,fSin,fCos);

        this.opAssign(kZMat*(kYMat*kXMat));
    }
    //-----------------------------------------------------------------------
    void Tridiagonal (Real afDiag[3], Real afSubDiag[3])
    {
        // Householder reduction T = Q^t M Q
        //   Input:
        //     mat, symmetric 3x3 matrix M
        //   Output:
        //     mat, orthogonal matrix Q
        //     diag, diagonal entries of T
        //     subd, subdiagonal entries of T (T is symmetric)

        Real fA = m[0][0];
        Real fB = m[0][1];
        Real fC = m[0][2];
        Real fD = m[1][1];
        Real fE = m[1][2];
        Real fF = m[2][2];

        afDiag[0] = fA;
        afSubDiag[2] = 0.0;
        if ( Math.Abs(fC) >= EPSILON )
        {
            Real fLength = Math.Sqrt(fB*fB+fC*fC);
            Real fInvLength = 1.0f/fLength;
            fB *= fInvLength;
            fC *= fInvLength;
            Real fQ = 2.0f*fB*fE+fC*(fF-fD);
            afDiag[1] = fD+fC*fQ;
            afDiag[2] = fF-fC*fQ;
            afSubDiag[0] = fLength;
            afSubDiag[1] = fE-fB*fQ;
            m[0][0] = 1.0;
            m[0][1] = 0.0;
            m[0][2] = 0.0;
            m[1][0] = 0.0;
            m[1][1] = fB;
            m[1][2] = fC;
            m[2][0] = 0.0;
            m[2][1] = fC;
            m[2][2] = -fB;
        }
        else
        {
            afDiag[1] = fD;
            afDiag[2] = fF;
            afSubDiag[0] = fB;
            afSubDiag[1] = fE;
            m[0][0] = 1.0;
            m[0][1] = 0.0;
            m[0][2] = 0.0;
            m[1][0] = 0.0;
            m[1][1] = 1.0;
            m[1][2] = 0.0;
            m[2][0] = 0.0;
            m[2][1] = 0.0;
            m[2][2] = 1.0;
        }
    }
    //-----------------------------------------------------------------------
    bool QLAlgorithm (Real afDiag[3], Real afSubDiag[3])
    {
        // QL iteration with implicit shifting to reduce matrix from tridiagonal
        // to diagonal

        for (int i0 = 0; i0 < 3; i0++)
        {
            uint iMaxIter = 32;
            uint iIter;
            for (iIter = 0; iIter < iMaxIter; iIter++)
            {
                int i1;
                for (i1 = i0; i1 <= 1; i1++)
                {
                    Real fSum = Math.Abs(afDiag[i1]) +
                        Math.Abs(afDiag[i1+1]);
                    if ( Math.Abs(afSubDiag[i1]) + fSum == fSum )
                        break;
                }
                if ( i1 == i0 )
                    break;

                Real fTmp0 = (afDiag[i0+1]-afDiag[i0])/(2.0f*afSubDiag[i0]);
                Real fTmp1 = Math.Sqrt(fTmp0*fTmp0+1.0f);
                if ( fTmp0 < 0.0 )
                    fTmp0 = afDiag[i1]-afDiag[i0]+afSubDiag[i0]/(fTmp0-fTmp1);
                else
                    fTmp0 = afDiag[i1]-afDiag[i0]+afSubDiag[i0]/(fTmp0+fTmp1);
                Real fSin = 1.0;
                Real fCos = 1.0;
                Real fTmp2 = 0.0;
                for (int i2 = i1-1; i2 >= i0; i2--)
                {
                    Real fTmp3 = fSin*afSubDiag[i2];
                    Real fTmp4 = fCos*afSubDiag[i2];
                    if ( Math.Abs(fTmp3) >= Math.Abs(fTmp0) )
                    {
                        fCos = fTmp0/fTmp3;
                        fTmp1 = Math.Sqrt(fCos*fCos+1.0f);
                        afSubDiag[i2+1] = fTmp3*fTmp1;
                        fSin = 1.0f/fTmp1;
                        fCos *= fSin;
                    }
                    else
                    {
                        fSin = fTmp3/fTmp0;
                        fTmp1 = Math.Sqrt(fSin*fSin+1.0f);
                        afSubDiag[i2+1] = fTmp0*fTmp1;
                        fCos = 1.0f/fTmp1;
                        fSin *= fCos;
                    }
                    fTmp0 = afDiag[i2+1]-fTmp2;
                    fTmp1 = (afDiag[i2]-fTmp0)*fSin+2.0f*fTmp4*fCos;
                    fTmp2 = fSin*fTmp1;
                    afDiag[i2+1] = fTmp0+fTmp2;
                    fTmp0 = fCos*fTmp1-fTmp4;

                    for (int iRow = 0; iRow < 3; iRow++)
                    {
                        fTmp3 = m[iRow][i2+1];
                        m[iRow][i2+1] = fSin*m[iRow][i2] +
                            fCos*fTmp3;
                        m[iRow][i2] = fCos*m[iRow][i2] -
                            fSin*fTmp3;
                    }
                }
                afDiag[i0] -= fTmp2;
                afSubDiag[i0] = fTmp0;
                afSubDiag[i1] = 0.0;
            }

            if ( iIter == iMaxIter )
            {
                // should not get here under normal circumstances
                return false;
            }
        }

        return true;
    }
    //-----------------------------------------------------------------------
    void EigenSolveSymmetric (Real[3] afEigenvalue,
                              ref Vector3[3] akEigenvector)
    {
        Matrix3 kMatrix = this.copy();
        Real[3] afSubDiag;
        kMatrix.Tridiagonal(afEigenvalue,afSubDiag);
        kMatrix.QLAlgorithm(afEigenvalue,afSubDiag);

        for (size_t i = 0; i < 3; i++)
        {
            akEigenvector[i][0] = kMatrix[0][i];
            akEigenvector[i][1] = kMatrix[1][i];
            akEigenvector[i][2] = kMatrix[2][i];
        }

        // make eigenvectors form a right--handed system
        Vector3 kCross = akEigenvector[1].crossProduct(akEigenvector[2]);
        Real fDet = akEigenvector[0].dotProduct(kCross);
        if ( fDet < 0.0 )
        {
            akEigenvector[2][0] = - akEigenvector[2][0];
            akEigenvector[2][1] = - akEigenvector[2][1];
            akEigenvector[2][2] = - akEigenvector[2][2];
        }
    }
    //-----------------------------------------------------------------------
    void TensorProduct (ref Vector3 rkU,ref Vector3 rkV,
                        ref Matrix3 rkProduct)
    {
        for (size_t iRow = 0; iRow < 3; iRow++)
        {
            for (size_t iCol = 0; iCol < 3; iCol++)
                rkProduct[iRow][iCol] = rkU[iRow]*rkV[iCol];
        }
    }
    
    Matrix3 copy()
    {
        return Matrix3(this);
    }
}


/** Class encapsulating a standard 4x4 homogeneous matrix.
 @remarks
 OGRE uses column vectors when applying matrix multiplications,
 This means a vector is represented as a single column, 4-row
 matrix. This has the effect that the transformations implemented
 by the matrices happens right-to-left e.g. if vector V is to be
 transformed by M1 then M2 then M3, the calculation would be
 M3 * M2 * M1 * V. The order that matrices are concatenated is
 vital since matrix multiplication is not commutative, i.e. you
 can get a different result if you concatenate in the wrong order.
 @par
 The use of column vectors and right-to-left ordering is the
 standard in most mathematical texts, and is the same as used in
 OpenGL. It is, however, the opposite of Direct3D, which has
 inexplicably chosen to differ from the accepted standard and uses
 row vectors and left-to-right matrix multiplication.
 @par
 OGRE deals with the differences between D3D and OpenGL etc.
 internally when operating through different render systems. OGRE
 users only need to conform to standard maths conventions, i.e.
 right-to-left matrix multiplication, (OGRE transposes matrices it
 passes to D3D to compensate).
 @par
 The generic form M * V which shows the layout of the matrix 
 entries is shown below:
 <pre>
 [ m[0][0]  m[0][1]  m[0][2]  m[0][3] ]   {x}
 | m[1][0]  m[1][1]  m[1][2]  m[1][3] | * {y}
 | m[2][0]  m[2][1]  m[2][2]  m[2][3] |   {z}
 [ m[3][0]  m[3][1]  m[3][2]  m[3][3] ]   {1}
 </pre>
 */
struct Matrix4
{

protected:
    /// The matrix entries, indexed by [row][col].
    //union Mat {
    union {
        Real[4][4] m;
        //Real[16] _m; //TODO Overlapping unions not supported in CTFE (yet)
    }
    //Mat mat;
public:

    @property
    Real* ptr()
    {
        return &m[0][0];
    }

    enum Matrix4 ZERO = Matrix4(
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0 );
    enum Matrix4 ZEROAFFINE = Matrix4(
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 1 );
    
    //enum //FIXME something fishy
    immutable static Matrix4 IDENTITY = Matrix4(
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1 );
    /** Useful little matrix which takes 2D clipspace {-1, 1} to {0,1}
     and inverts the Y. */
    enum Matrix4 CLIPSPACE2DTOIMAGESPACE = Matrix4(
        0.5,    0,  0, 0.5, 
        0, -0.5,  0, 0.5, 
        0,    0,  1,   0,
        0,    0,  0,   1);

    /** Default constructor.
     @note
     It does <b>NOT</b> initialize the matrix for efficiency.
     */
    //@disable this();

    this(
        Real m00, Real m01, Real m02, Real m03,
        Real m10, Real m11, Real m12, Real m13,
        Real m20, Real m21, Real m22, Real m23,
        Real m30, Real m31, Real m32, Real m33 )
    {
        m[0][0] = m00;
        m[0][1] = m01;
        m[0][2] = m02;
        m[0][3] = m03;
        m[1][0] = m10;
        m[1][1] = m11;
        m[1][2] = m12;
        m[1][3] = m13;
        m[2][0] = m20;
        m[2][1] = m21;
        m[2][2] = m22;
        m[2][3] = m23;
        m[3][0] = m30;
        m[3][1] = m31;
        m[3][2] = m32;
        m[3][3] = m33;
    }

    /** Creates a standard 4x4 transformation matrix with a zero translation part from a rotation/scaling 3x3 matrix.
     */

    this(ref Matrix3 m3x3)
    {
        opAssign(IDENTITY);
        opAssign(m3x3);
    }

    /** Creates a standard 4x4 transformation matrix with a zero translation part from a rotation/scaling Quaternion.
     */
    
    this(ref Quaternion rot)
    {
        Matrix3 m3x3 = Matrix3();
        rot.ToRotationMatrix(m3x3);
        opAssign(IDENTITY);
        opAssign(m3x3);
    }
    

    /** Exchange the contents of this matrix with another. 
     */
    void swap(ref Matrix4 other)
    {
        std.algorithm.swap(m[0][0], other.m[0][0]);
        std.algorithm.swap(m[0][1], other.m[0][1]);
        std.algorithm.swap(m[0][2], other.m[0][2]);
        std.algorithm.swap(m[0][3], other.m[0][3]);
        std.algorithm.swap(m[1][0], other.m[1][0]);
        std.algorithm.swap(m[1][1], other.m[1][1]);
        std.algorithm.swap(m[1][2], other.m[1][2]);
        std.algorithm.swap(m[1][3], other.m[1][3]);
        std.algorithm.swap(m[2][0], other.m[2][0]);
        std.algorithm.swap(m[2][1], other.m[2][1]);
        std.algorithm.swap(m[2][2], other.m[2][2]);
        std.algorithm.swap(m[2][3], other.m[2][3]);
        std.algorithm.swap(m[3][0], other.m[3][0]);
        std.algorithm.swap(m[3][1], other.m[3][1]);
        std.algorithm.swap(m[3][2], other.m[3][2]);
        std.algorithm.swap(m[3][3], other.m[3][3]);
    }

    /*Real[] opIndex ( size_t iRow )
    {
        assert( iRow < 4 );
        return m[iRow];
    }*/

    const(Real[4]) opIndex ( size_t iRow ) const
    {
        assert( iRow < 4 );
        return m[iRow];
    }

    Real[4] opIndex ( size_t iRow )
    {
        assert( iRow < 4 );
        return m[iRow];
    }

    Real opIndex ( size_t iRow, size_t iCol ) const
    {
        assert( iRow < 4 && iCol < 4 );
        return m[iRow][iCol];
    }

    Real opIndex ( size_t iRow, size_t iCol )
    {
        assert( iRow < 4 && iCol < 4 );
        return m[iRow][iCol];
    }

    void opIndexAssign (Real val, size_t iRow, size_t iCol )
    {
        assert( iRow < 4 && iCol < 4 );
        m[iRow][iCol] = val;
    }

    Matrix4 concatenate(ref Matrix4 m2)
    {
        Matrix4 r;
        r.m[0][0] = m[0][0] * m2.m[0][0] + m[0][1] * m2.m[1][0] + m[0][2] * m2.m[2][0] + m[0][3] * m2.m[3][0];
        r.m[0][1] = m[0][0] * m2.m[0][1] + m[0][1] * m2.m[1][1] + m[0][2] * m2.m[2][1] + m[0][3] * m2.m[3][1];
        r.m[0][2] = m[0][0] * m2.m[0][2] + m[0][1] * m2.m[1][2] + m[0][2] * m2.m[2][2] + m[0][3] * m2.m[3][2];
        r.m[0][3] = m[0][0] * m2.m[0][3] + m[0][1] * m2.m[1][3] + m[0][2] * m2.m[2][3] + m[0][3] * m2.m[3][3];

        r.m[1][0] = m[1][0] * m2.m[0][0] + m[1][1] * m2.m[1][0] + m[1][2] * m2.m[2][0] + m[1][3] * m2.m[3][0];
        r.m[1][1] = m[1][0] * m2.m[0][1] + m[1][1] * m2.m[1][1] + m[1][2] * m2.m[2][1] + m[1][3] * m2.m[3][1];
        r.m[1][2] = m[1][0] * m2.m[0][2] + m[1][1] * m2.m[1][2] + m[1][2] * m2.m[2][2] + m[1][3] * m2.m[3][2];
        r.m[1][3] = m[1][0] * m2.m[0][3] + m[1][1] * m2.m[1][3] + m[1][2] * m2.m[2][3] + m[1][3] * m2.m[3][3];

        r.m[2][0] = m[2][0] * m2.m[0][0] + m[2][1] * m2.m[1][0] + m[2][2] * m2.m[2][0] + m[2][3] * m2.m[3][0];
        r.m[2][1] = m[2][0] * m2.m[0][1] + m[2][1] * m2.m[1][1] + m[2][2] * m2.m[2][1] + m[2][3] * m2.m[3][1];
        r.m[2][2] = m[2][0] * m2.m[0][2] + m[2][1] * m2.m[1][2] + m[2][2] * m2.m[2][2] + m[2][3] * m2.m[3][2];
        r.m[2][3] = m[2][0] * m2.m[0][3] + m[2][1] * m2.m[1][3] + m[2][2] * m2.m[2][3] + m[2][3] * m2.m[3][3];

        r.m[3][0] = m[3][0] * m2.m[0][0] + m[3][1] * m2.m[1][0] + m[3][2] * m2.m[2][0] + m[3][3] * m2.m[3][0];
        r.m[3][1] = m[3][0] * m2.m[0][1] + m[3][1] * m2.m[1][1] + m[3][2] * m2.m[2][1] + m[3][3] * m2.m[3][1];
        r.m[3][2] = m[3][0] * m2.m[0][2] + m[3][1] * m2.m[1][2] + m[3][2] * m2.m[2][2] + m[3][3] * m2.m[3][2];
        r.m[3][3] = m[3][0] * m2.m[0][3] + m[3][1] * m2.m[1][3] + m[3][2] * m2.m[2][3] + m[3][3] * m2.m[3][3];

        return r;
    }

    /** Matrix concatenation using '*'.
     */
    Matrix4 opMul (Matrix4 m2 )
    {
        return concatenate( m2 );
    }

    /** Vector transformation using '*'.
     @remarks
     Transforms the given 3-D vector by the matrix, projecting the 
     result back into <i>w</i> = 1.
     @note
     This means that the initial <i>w</i> is considered to be 1.0,
     and then all the tree elements of the resulting 3-D vector are
     divided by the resulting <i>w</i>.
     */
    Vector3 opMul (Vector3 v )
    {
        Vector3 r = Vector3();

        Real fInvW = 1.0f / ( m[3][0] * v.x + m[3][1] * v.y + m[3][2] * v.z + m[3][3] );

        r.x = ( m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3] ) * fInvW;
        r.y = ( m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3] ) * fInvW;
        r.z = ( m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3] ) * fInvW;

        return r;
    }
    Vector4 opMul (Vector4 v)
    {
        return Vector4(
            m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3] * v.w, 
            m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3] * v.w,
            m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3] * v.w,
            m[3][0] * v.x + m[3][1] * v.y + m[3][2] * v.z + m[3][3] * v.w
            );
    }

    //inline Vector4 operator * (const Vector4& v, const Matrix4& mat)
    Vector4 opMul_r (Vector4 v)
    {
        return Vector4(
            v.x*m[0][0] + v.y*m[1][0] + v.z*m[2][0] + v.w*m[3][0],
            v.x*m[0][1] + v.y*m[1][1] + v.z*m[2][1] + v.w*m[3][1],
            v.x*m[0][2] + v.y*m[1][2] + v.z*m[2][2] + v.w*m[3][2],
            v.x*m[0][3] + v.y*m[1][3] + v.z*m[2][3] + v.w*m[3][3]
            );
    }

    Plane opMul (ref Plane p)
    {
        Plane ret = new Plane;
        Matrix4 invTrans = inverse().transpose();
        Vector4 v4 = Vector4( p.normal.x, p.normal.y, p.normal.z, p.d );
        v4 = invTrans * v4;
        ret.normal.x = v4.x; 
        ret.normal.y = v4.y; 
        ret.normal.z = v4.z;
        ret.d = v4.w / ret.normal.normalise();

        return ret;
    }

    
    /** Matrix addition.
     */
    Matrix4 opAdd (Matrix4 m2 )
    {
        Matrix4 r = Matrix4();

        r.m[0][0] = m[0][0] + m2.m[0][0];
        r.m[0][1] = m[0][1] + m2.m[0][1];
        r.m[0][2] = m[0][2] + m2.m[0][2];
        r.m[0][3] = m[0][3] + m2.m[0][3];

        r.m[1][0] = m[1][0] + m2.m[1][0];
        r.m[1][1] = m[1][1] + m2.m[1][1];
        r.m[1][2] = m[1][2] + m2.m[1][2];
        r.m[1][3] = m[1][3] + m2.m[1][3];

        r.m[2][0] = m[2][0] + m2.m[2][0];
        r.m[2][1] = m[2][1] + m2.m[2][1];
        r.m[2][2] = m[2][2] + m2.m[2][2];
        r.m[2][3] = m[2][3] + m2.m[2][3];

        r.m[3][0] = m[3][0] + m2.m[3][0];
        r.m[3][1] = m[3][1] + m2.m[3][1];
        r.m[3][2] = m[3][2] + m2.m[3][2];
        r.m[3][3] = m[3][3] + m2.m[3][3];

        return r;
    }

    /** Matrix subtraction.
     */
    Matrix4 opSub (Matrix4 m2 )
    {
        Matrix4 r = Matrix4();
        r.m[0][0] = m[0][0] - m2.m[0][0];
        r.m[0][1] = m[0][1] - m2.m[0][1];
        r.m[0][2] = m[0][2] - m2.m[0][2];
        r.m[0][3] = m[0][3] - m2.m[0][3];

        r.m[1][0] = m[1][0] - m2.m[1][0];
        r.m[1][1] = m[1][1] - m2.m[1][1];
        r.m[1][2] = m[1][2] - m2.m[1][2];
        r.m[1][3] = m[1][3] - m2.m[1][3];

        r.m[2][0] = m[2][0] - m2.m[2][0];
        r.m[2][1] = m[2][1] - m2.m[2][1];
        r.m[2][2] = m[2][2] - m2.m[2][2];
        r.m[2][3] = m[2][3] - m2.m[2][3];

        r.m[3][0] = m[3][0] - m2.m[3][0];
        r.m[3][1] = m[3][1] - m2.m[3][1];
        r.m[3][2] = m[3][2] - m2.m[3][2];
        r.m[3][3] = m[3][3] - m2.m[3][3];

        return r;
    }

    /** Tests 2 matrices for equality.
     */
    bool opEquals ( Matrix4 m2 )
    {
        if( 
           m[0][0] != m2.m[0][0] || m[0][1] != m2.m[0][1] || m[0][2] != m2.m[0][2] || m[0][3] != m2.m[0][3] ||
           m[1][0] != m2.m[1][0] || m[1][1] != m2.m[1][1] || m[1][2] != m2.m[1][2] || m[1][3] != m2.m[1][3] ||
           m[2][0] != m2.m[2][0] || m[2][1] != m2.m[2][1] || m[2][2] != m2.m[2][2] || m[2][3] != m2.m[2][3] ||
           m[3][0] != m2.m[3][0] || m[3][1] != m2.m[3][1] || m[3][2] != m2.m[3][2] || m[3][3] != m2.m[3][3] )
            return false;
        return true;
    }

    /** Tests 2 matrices for inequality.
     */
    /*bool operator != (Matrix4& m2 )
     {
     if( 
     m[0][0] != m2.m[0][0] || m[0][1] != m2.m[0][1] || m[0][2] != m2.m[0][2] || m[0][3] != m2.m[0][3] ||
     m[1][0] != m2.m[1][0] || m[1][1] != m2.m[1][1] || m[1][2] != m2.m[1][2] || m[1][3] != m2.m[1][3] ||
     m[2][0] != m2.m[2][0] || m[2][1] != m2.m[2][1] || m[2][2] != m2.m[2][2] || m[2][3] != m2.m[2][3] ||
     m[3][0] != m2.m[3][0] || m[3][1] != m2.m[3][1] || m[3][2] != m2.m[3][2] || m[3][3] != m2.m[3][3] )
     return true;
     return false;
     }*/
    /** Mat4 to Mat4*/
    Matrix4 opAssign (Matrix4 mat4 )
    {
        m = mat4.m.dup;
        return this;
    }
    /** Assignment from 3x3 matrix.
     */
    Matrix4 opAssign ( ref Matrix3 mat3 )
    {
        m[0][0] = mat3.m[0][0]; m[0][1] = mat3.m[0][1]; m[0][2] = mat3.m[0][2];
        m[1][0] = mat3.m[1][0]; m[1][1] = mat3.m[1][1]; m[1][2] = mat3.m[1][2];
        m[2][0] = mat3.m[2][0]; m[2][1] = mat3.m[2][1]; m[2][2] = mat3.m[2][2];
        return this;
    }

    Matrix4 transpose()
    {
        return Matrix4(m[0][0], m[1][0], m[2][0], m[3][0],
                       m[0][1], m[1][1], m[2][1], m[3][1],
                       m[0][2], m[1][2], m[2][2], m[3][2],
                       m[0][3], m[1][3], m[2][3], m[3][3]);
    }

    /*
     -----------------------------------------------------------------------
     Translation Transformation
     -----------------------------------------------------------------------
     */
    /** Sets the translation transformation part of the matrix.
     */
    void setTrans(Vector3 v )
    {
        m[0][3] = v.x;
        m[1][3] = v.y;
        m[2][3] = v.z;
    }

    /** Extracts the translation transformation part of the matrix.
     */
    Vector3 getTrans()
    {
        return Vector3(m[0][3], m[1][3], m[2][3]);
    }
    

    /** Builds a translation matrix
     */
    void makeTrans(ref Vector3 v )
    {
        m[0][0] = 1.0; m[0][1] = 0.0; m[0][2] = 0.0; m[0][3] = v.x;
        m[1][0] = 0.0; m[1][1] = 1.0; m[1][2] = 0.0; m[1][3] = v.y;
        m[2][0] = 0.0; m[2][1] = 0.0; m[2][2] = 1.0; m[2][3] = v.z;
        m[3][0] = 0.0; m[3][1] = 0.0; m[3][2] = 0.0; m[3][3] = 1.0;
    }

    void makeTrans( Real tx, Real ty, Real tz )
    {
        m[0][0] = 1.0; m[0][1] = 0.0; m[0][2] = 0.0; m[0][3] = tx;
        m[1][0] = 0.0; m[1][1] = 1.0; m[1][2] = 0.0; m[1][3] = ty;
        m[2][0] = 0.0; m[2][1] = 0.0; m[2][2] = 1.0; m[2][3] = tz;
        m[3][0] = 0.0; m[3][1] = 0.0; m[3][2] = 0.0; m[3][3] = 1.0;
    }

    /** Gets a translation matrix.
     */
    static Matrix4 getTrans(ref Vector3 v )
    {
        Matrix4 r = Matrix4();

        r.m[0][0] = 1.0; r.m[0][1] = 0.0; r.m[0][2] = 0.0; r.m[0][3] = v.x;
        r.m[1][0] = 0.0; r.m[1][1] = 1.0; r.m[1][2] = 0.0; r.m[1][3] = v.y;
        r.m[2][0] = 0.0; r.m[2][1] = 0.0; r.m[2][2] = 1.0; r.m[2][3] = v.z;
        r.m[3][0] = 0.0; r.m[3][1] = 0.0; r.m[3][2] = 0.0; r.m[3][3] = 1.0;

        return r;
    }

    /** Gets a translation matrix - variation for not using a vector.
     */
    static Matrix4 getTrans( Real t_x, Real t_y, Real t_z )
    {
        Matrix4 r = Matrix4();

        r.m[0][0] = 1.0; r.m[0][1] = 0.0; r.m[0][2] = 0.0; r.m[0][3] = t_x;
        r.m[1][0] = 0.0; r.m[1][1] = 1.0; r.m[1][2] = 0.0; r.m[1][3] = t_y;
        r.m[2][0] = 0.0; r.m[2][1] = 0.0; r.m[2][2] = 1.0; r.m[2][3] = t_z;
        r.m[3][0] = 0.0; r.m[3][1] = 0.0; r.m[3][2] = 0.0; r.m[3][3] = 1.0;

        return r;
    }

    /*
     -----------------------------------------------------------------------
     Scale Transformation
     -----------------------------------------------------------------------
     */
    /** Sets the scale part of the matrix.
     */
    void setScale(ref Vector3 v )
    {
        m[0][0] = v.x;
        m[1][1] = v.y;
        m[2][2] = v.z;
    }

    /** Gets a scale matrix.
     */
    static Matrix4 getScale(ref Vector3 v )
    {
        Matrix4 r = Matrix4();
        r.m[0][0] = v.x; r.m[0][1] = 0.0; r.m[0][2] = 0.0; r.m[0][3] = 0.0;
        r.m[1][0] = 0.0; r.m[1][1] = v.y; r.m[1][2] = 0.0; r.m[1][3] = 0.0;
        r.m[2][0] = 0.0; r.m[2][1] = 0.0; r.m[2][2] = v.z; r.m[2][3] = 0.0;
        r.m[3][0] = 0.0; r.m[3][1] = 0.0; r.m[3][2] = 0.0; r.m[3][3] = 1.0;

        return r;
    }

    /** Gets a scale matrix - variation for not using a vector.
     */
    static Matrix4 getScale( Real s_x, Real s_y, Real s_z )
    {
        Matrix4 r = Matrix4();
        r.m[0][0] = s_x; r.m[0][1] = 0.0; r.m[0][2] = 0.0; r.m[0][3] = 0.0;
        r.m[1][0] = 0.0; r.m[1][1] = s_y; r.m[1][2] = 0.0; r.m[1][3] = 0.0;
        r.m[2][0] = 0.0; r.m[2][1] = 0.0; r.m[2][2] = s_z; r.m[2][3] = 0.0;
        r.m[3][0] = 0.0; r.m[3][1] = 0.0; r.m[3][2] = 0.0; r.m[3][3] = 1.0;

        return r;
    }

    /** Extracts the rotation / scaling part of the Matrix as a 3x3 matrix. 
     @param m3x3 Destination Matrix3
     */
    void extract3x3Matrix(ref Matrix3 m3x3)
    {
        m3x3.m[0][0] = m[0][0];
        m3x3.m[0][1] = m[0][1];
        m3x3.m[0][2] = m[0][2];
        m3x3.m[1][0] = m[1][0];
        m3x3.m[1][1] = m[1][1];
        m3x3.m[1][2] = m[1][2];
        m3x3.m[2][0] = m[2][0];
        m3x3.m[2][1] = m[2][1];
        m3x3.m[2][2] = m[2][2];

    }

    /** Determines if this matrix involves a scaling. */
    bool hasScale()
    {
        // check magnitude of column vectors (==local axes)
        Real t = m[0][0] * m[0][0] + m[1][0] * m[1][0] + m[2][0] * m[2][0];
        if (!Math.RealEqual(t, 1.0, cast(Real)1e-04))
            return true;
        t = m[0][1] * m[0][1] + m[1][1] * m[1][1] + m[2][1] * m[2][1];
        if (!Math.RealEqual(t, 1.0, cast(Real)1e-04))
            return true;
        t = m[0][2] * m[0][2] + m[1][2] * m[1][2] + m[2][2] * m[2][2];
        if (!Math.RealEqual(t, 1.0, cast(Real)1e-04))
            return true;

        return false;
    }

    /** Determines if this matrix involves a negative scaling. */
    bool hasNegativeScale()
    {
        return determinant() < 0;
    }

    /** Extracts the rotation / scaling part as a quaternion from the Matrix.
     */
    Quaternion extractQuaternion()
    {
        Matrix3 m3x3 = Matrix3();
        extract3x3Matrix(m3x3);
        return Quaternion(m3x3);
    }

    Matrix4 opMul(Real scalar)
    {
        return Matrix4(
            scalar*m[0][0], scalar*m[0][1], scalar*m[0][2], scalar*m[0][3],
            scalar*m[1][0], scalar*m[1][1], scalar*m[1][2], scalar*m[1][3],
            scalar*m[2][0], scalar*m[2][1], scalar*m[2][2], scalar*m[2][3],
            scalar*m[3][0], scalar*m[3][1], scalar*m[3][2], scalar*m[3][3]);
    }

    /** Function for writing to a stream.
     */
    string toString()
    {
        string str = "Matrix4(";
        for (size_t i = 0; i < 4; ++i)
        {
            str ~= " row" ~ std.conv.to!string(i) ~ "{";
            for(size_t j = 0; j < 4; ++j)
            {
                str ~= std.conv.to!string(m[i][j]) ~ " ";
            }
            str ~= "}";
        }
        str ~= ")";
        return str;
    }
    
    /** Check whether or not the matrix is affine matrix.
     @remarks
     An affine matrix is a 4x4 matrix with row 3 equal to (0, 0, 0, 1),
     e.g. no projective coefficients.
     */
    bool isAffine()
    {
        return m[3][0] == 0 && m[3][1] == 0 && m[3][2] == 0 && m[3][3] == 1;
    }
    
    /** Concatenate two affine matrices.
     @note
     The matrices must be affine matrix. @see Matrix4::isAffine.
     */
    Matrix4 concatenateAffine(ref Matrix4 m2)
    {
        assert(isAffine() && m2.isAffine());

        return Matrix4(
            m[0][0] * m2.m[0][0] + m[0][1] * m2.m[1][0] + m[0][2] * m2.m[2][0],
            m[0][0] * m2.m[0][1] + m[0][1] * m2.m[1][1] + m[0][2] * m2.m[2][1],
            m[0][0] * m2.m[0][2] + m[0][1] * m2.m[1][2] + m[0][2] * m2.m[2][2],
            m[0][0] * m2.m[0][3] + m[0][1] * m2.m[1][3] + m[0][2] * m2.m[2][3] + m[0][3],

            m[1][0] * m2.m[0][0] + m[1][1] * m2.m[1][0] + m[1][2] * m2.m[2][0],
            m[1][0] * m2.m[0][1] + m[1][1] * m2.m[1][1] + m[1][2] * m2.m[2][1],
            m[1][0] * m2.m[0][2] + m[1][1] * m2.m[1][2] + m[1][2] * m2.m[2][2],
            m[1][0] * m2.m[0][3] + m[1][1] * m2.m[1][3] + m[1][2] * m2.m[2][3] + m[1][3],

            m[2][0] * m2.m[0][0] + m[2][1] * m2.m[1][0] + m[2][2] * m2.m[2][0],
            m[2][0] * m2.m[0][1] + m[2][1] * m2.m[1][1] + m[2][2] * m2.m[2][1],
            m[2][0] * m2.m[0][2] + m[2][1] * m2.m[1][2] + m[2][2] * m2.m[2][2],
            m[2][0] * m2.m[0][3] + m[2][1] * m2.m[1][3] + m[2][2] * m2.m[2][3] + m[2][3],

            0, 0, 0, 1);
    }

    /** 3-D Vector transformation specially for an affine matrix.
     @remarks
     Transforms the given 3-D vector by the matrix, projecting the 
     result back into <i>w</i> = 1.
     @note
     The matrix must be an affine matrix. @see Matrix4::isAffine.
     */
    Vector3 transformAffine(Vector3 v)
    {
        assert(isAffine());

        return Vector3(
            m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3], 
            m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3],
            m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3]);
    }

    /** 4-D Vector transformation specially for an affine matrix.
     @note
     The matrix must be an affine matrix. @see Matrix4::isAffine.
     */
    Vector4 transformAffine(Vector4 v)
    {
        assert(isAffine());

        return Vector4(
            m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3] * v.w, 
            m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3] * v.w,
            m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3] * v.w,
            v.w);
    }
    
    /* Removed from Vector4 and made a non-member here because otherwise
     OgreMatrix4.h and OgreVector4.h have to try to include and each 
     other, which frankly doesn't work ;)
     * @todo in D this is...what?
     */
    /*Vector4 opMul (Vector4 v, Matrix4 mat)
    {
        return Vector4(
            v.x*mat[0][0] + v.y*mat[1][0] + v.z*mat[2][0] + v.w*mat[3][0],
            v.x*mat[0][1] + v.y*mat[1][1] + v.z*mat[2][1] + v.w*mat[3][1],
            v.x*mat[0][2] + v.y*mat[1][2] + v.z*mat[2][2] + v.w*mat[3][2],
            v.x*mat[0][3] + v.y*mat[1][3] + v.z*mat[2][3] + v.w*mat[3][3]
            );
    }*/
    //-----------------------------------------------------------------------
    static Real
    MINOR(ref Matrix4 m,size_t r0,size_t r1,size_t r2, 
          size_t c0,size_t c1,size_t c2)
    {
        return m[r0][c0] * (m[r1][c1] * m[r2][c2] - m[r2][c1] * m[r1][c2]) -
            m[r0][c1] * (m[r1][c0] * m[r2][c2] - m[r2][c0] * m[r1][c2]) +
                m[r0][c2] * (m[r1][c0] * m[r2][c1] - m[r2][c0] * m[r1][c1]);
    }
    //-----------------------------------------------------------------------
    Matrix4 adjoint()
    {
        return Matrix4( MINOR(this, 1, 2, 3, 1, 2, 3),
                       -MINOR(this, 0, 2, 3, 1, 2, 3),
                       MINOR(this, 0, 1, 3, 1, 2, 3),
                       -MINOR(this, 0, 1, 2, 1, 2, 3),
                       
                       -MINOR(this, 1, 2, 3, 0, 2, 3),
                       MINOR(this, 0, 2, 3, 0, 2, 3),
                       -MINOR(this, 0, 1, 3, 0, 2, 3),
                       MINOR(this, 0, 1, 2, 0, 2, 3),
                       
                       MINOR(this, 1, 2, 3, 0, 1, 3),
                       -MINOR(this, 0, 2, 3, 0, 1, 3),
                       MINOR(this, 0, 1, 3, 0, 1, 3),
                       -MINOR(this, 0, 1, 2, 0, 1, 3),
                       
                       -MINOR(this, 1, 2, 3, 0, 1, 2),
                       MINOR(this, 0, 2, 3, 0, 1, 2),
                       -MINOR(this, 0, 1, 3, 0, 1, 2),
                       MINOR(this, 0, 1, 2, 0, 1, 2));
    }
    //-----------------------------------------------------------------------
    Real determinant()
    {
        return m[0][0] * MINOR(this, 1, 2, 3, 1, 2, 3) -
            m[0][1] * MINOR(this, 1, 2, 3, 0, 2, 3) +
                m[0][2] * MINOR(this, 1, 2, 3, 0, 1, 3) -
                m[0][3] * MINOR(this, 1, 2, 3, 0, 1, 2);
    }
    
    /** Returns the inverse of the affine matrix.
     @note
     The matrix must be an affine matrix. @see Matrix4::isAffine.
     */
    Matrix4 inverse()
    {
        Real m00 = m[0][0], m01 = m[0][1], m02 = m[0][2], m03 = m[0][3];
        Real m10 = m[1][0], m11 = m[1][1], m12 = m[1][2], m13 = m[1][3];
        Real m20 = m[2][0], m21 = m[2][1], m22 = m[2][2], m23 = m[2][3];
        Real m30 = m[3][0], m31 = m[3][1], m32 = m[3][2], m33 = m[3][3];
        
        Real v0 = m20 * m31 - m21 * m30;
        Real v1 = m20 * m32 - m22 * m30;
        Real v2 = m20 * m33 - m23 * m30;
        Real v3 = m21 * m32 - m22 * m31;
        Real v4 = m21 * m33 - m23 * m31;
        Real v5 = m22 * m33 - m23 * m32;
        
        Real t00 = + (v5 * m11 - v4 * m12 + v3 * m13);
        Real t10 = - (v5 * m10 - v2 * m12 + v1 * m13);
        Real t20 = + (v4 * m10 - v2 * m11 + v0 * m13);
        Real t30 = - (v3 * m10 - v1 * m11 + v0 * m12);
        
        Real invDet = 1 / (t00 * m00 + t10 * m01 + t20 * m02 + t30 * m03);
        
        Real d00 = t00 * invDet;
        Real d10 = t10 * invDet;
        Real d20 = t20 * invDet;
        Real d30 = t30 * invDet;
        
        Real d01 = - (v5 * m01 - v4 * m02 + v3 * m03) * invDet;
        Real d11 = + (v5 * m00 - v2 * m02 + v1 * m03) * invDet;
        Real d21 = - (v4 * m00 - v2 * m01 + v0 * m03) * invDet;
        Real d31 = + (v3 * m00 - v1 * m01 + v0 * m02) * invDet;
        
        v0 = m10 * m31 - m11 * m30;
        v1 = m10 * m32 - m12 * m30;
        v2 = m10 * m33 - m13 * m30;
        v3 = m11 * m32 - m12 * m31;
        v4 = m11 * m33 - m13 * m31;
        v5 = m12 * m33 - m13 * m32;
        
        Real d02 = + (v5 * m01 - v4 * m02 + v3 * m03) * invDet;
        Real d12 = - (v5 * m00 - v2 * m02 + v1 * m03) * invDet;
        Real d22 = + (v4 * m00 - v2 * m01 + v0 * m03) * invDet;
        Real d32 = - (v3 * m00 - v1 * m01 + v0 * m02) * invDet;
        
        v0 = m21 * m10 - m20 * m11;
        v1 = m22 * m10 - m20 * m12;
        v2 = m23 * m10 - m20 * m13;
        v3 = m22 * m11 - m21 * m12;
        v4 = m23 * m11 - m21 * m13;
        v5 = m23 * m12 - m22 * m13;
        
        Real d03 = - (v5 * m01 - v4 * m02 + v3 * m03) * invDet;
        Real d13 = + (v5 * m00 - v2 * m02 + v1 * m03) * invDet;
        Real d23 = - (v4 * m00 - v2 * m01 + v0 * m03) * invDet;
        Real d33 = + (v3 * m00 - v1 * m01 + v0 * m02) * invDet;
        
        return Matrix4(
            d00, d01, d02, d03,
            d10, d11, d12, d13,
            d20, d21, d22, d23,
            d30, d31, d32, d33);
    }
    //-----------------------------------------------------------------------
    Matrix4 inverseAffine()
    {
        assert(isAffine());
        
        Real m10 = m[1][0], m11 = m[1][1], m12 = m[1][2];
        Real m20 = m[2][0], m21 = m[2][1], m22 = m[2][2];
        
        Real t00 = m22 * m11 - m21 * m12;
        Real t10 = m20 * m12 - m22 * m10;
        Real t20 = m21 * m10 - m20 * m11;
        
        Real m00 = m[0][0], m01 = m[0][1], m02 = m[0][2];
        
        Real invDet = 1 / (m00 * t00 + m01 * t10 + m02 * t20);
        
        t00 *= invDet; t10 *= invDet; t20 *= invDet;
        
        m00 *= invDet; m01 *= invDet; m02 *= invDet;
        
        Real r00 = t00;
        Real r01 = m02 * m21 - m01 * m22;
        Real r02 = m01 * m12 - m02 * m11;
        
        Real r10 = t10;
        Real r11 = m00 * m22 - m02 * m20;
        Real r12 = m02 * m10 - m00 * m12;
        
        Real r20 = t20;
        Real r21 = m01 * m20 - m00 * m21;
        Real r22 = m00 * m11 - m01 * m10;
        
        Real m03 = m[0][3], m13 = m[1][3], m23 = m[2][3];
        
        Real r03 = - (r00 * m03 + r01 * m13 + r02 * m23);
        Real r13 = - (r10 * m03 + r11 * m13 + r12 * m23);
        Real r23 = - (r20 * m03 + r21 * m13 + r22 * m23);
        
        return Matrix4(
            r00, r01, r02, r03,
            r10, r11, r12, r13,
            r20, r21, r22, r23,
            0,   0,   0,   1);
    }
    
    /** Building a Matrix4 from orientation / scale / position.
     @remarks
     Transform is performed in the order scale, rotate, translation, i.e. translation is independent
     of orientation axes, scale does not affect size of translation, rotation and scaling are always
     centered on the origin.
     */
    void makeTransform(Vector3 position, Vector3 scale, Quaternion orientation)
    {
        // Ordering:
        //    1. Scale
        //    2. Rotate
        //    3. Translate
        
        Matrix3 rot3x3;// = Matrix3();
        orientation.ToRotationMatrix(rot3x3);
        
        // Set up final matrix with scale, rotation and translation
        m[0][0] = scale.x * rot3x3[0][0]; m[0][1] = scale.y * rot3x3[0][1]; m[0][2] = scale.z * rot3x3[0][2]; m[0][3] = position.x;
        m[1][0] = scale.x * rot3x3[1][0]; m[1][1] = scale.y * rot3x3[1][1]; m[1][2] = scale.z * rot3x3[1][2]; m[1][3] = position.y;
        m[2][0] = scale.x * rot3x3[2][0]; m[2][1] = scale.y * rot3x3[2][1]; m[2][2] = scale.z * rot3x3[2][2]; m[2][3] = position.z;
        
        // No projection term
        m[3][0] = 0; m[3][1] = 0; m[3][2] = 0; m[3][3] = 1;
    }
    
    /** Building an inverse Matrix4 from orientation / scale / position.
     @remarks
     As makeTransform except it build the inverse given the same data as makeTransform, so
     performing -translation, -rotate, 1/scale in that order.
     */
    void makeInverseTransform(Vector3 position,Vector3 scale,Quaternion orientation)
    {
        // Invert the parameters
        Vector3 invTranslate = -position;
        Vector3 invScale = Vector3(1 / scale.x, 1 / scale.y, 1 / scale.z);
        Quaternion invRot = orientation.Inverse();
        
        // Because we're inverting, order is translation, rotation, scale
        // So make translation relative to scale & rotation
        invTranslate = invRot * invTranslate; // rotate
        invTranslate *= invScale; // scale
        
        // Next, make a 3x3 rotation matrix
        Matrix3 rot3x3 = Matrix3();
        invRot.ToRotationMatrix(rot3x3);
        
        // Set up final matrix with scale, rotation and translation
        m[0][0] = invScale.x * rot3x3[0][0]; m[0][1] = invScale.x * rot3x3[0][1]; m[0][2] = invScale.x * rot3x3[0][2]; m[0][3] = invTranslate.x;
        m[1][0] = invScale.y * rot3x3[1][0]; m[1][1] = invScale.y * rot3x3[1][1]; m[1][2] = invScale.y * rot3x3[1][2]; m[1][3] = invTranslate.y;
        m[2][0] = invScale.z * rot3x3[2][0]; m[2][1] = invScale.z * rot3x3[2][1]; m[2][2] = invScale.z * rot3x3[2][2]; m[2][3] = invTranslate.z;        
        
        // No projection term
        m[3][0] = 0; m[3][1] = 0; m[3][2] = 0; m[3][3] = 1;
    }
    
    /** Decompose a Matrix4 to orientation / scale / position.
     */
    void decomposition(ref Vector3 position, ref Vector3 scale, ref Quaternion orientation)
    {
        assert(isAffine());
        
        Matrix3 m3x3 = Matrix3();
        extract3x3Matrix(m3x3);
        
        Matrix3 matQ;
        Vector3 vecU;
        m3x3.QDUDecomposition( matQ, scale, vecU ); 
        
        orientation = Quaternion( matQ );
        position = Vector3( m[0][3], m[1][3], m[2][3] );
    }

}

/** @} */
/** @} */
