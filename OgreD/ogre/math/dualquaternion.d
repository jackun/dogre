module ogre.math.dualquaternion;
import ogre.math.quaternion;
import ogre.math.matrix;
import ogre.math.vector;
import ogre.compat;
import ogre.math.maths;
/* dqconv.c

  Conversion routines between (regular quaternion, translation) and dual quaternion.

  Version 1.0.0, February 7th, 2007

  Copyright (C) 2006-2007 University of Dublin, Trinity College, All Rights 
  Reserved

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the author(s) be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Author: Ladislav Kavan, kavanl@cs.tcd.ie

*/

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Math
    *  @{
    */
/** Implementation of a dual quaternion, i.e. a rotation around an axis and a translation.
        This implementation may note be appropriate as a general implementation, but is intended for use with
        dual quaternion skinning.
    */
class DualQuaternion
{
public:
    /// Default constructor, initializes to identity rotation (aka 0°), and zero translation (0,0,0)
    this ()
    {
        w = 1; x = 0; y = 0; z = 0; dw = 1; dx = 0; dy = 0; dz = 0;
    }
    
    /// Construct from an explicit list of values
    this (Real fW, Real fX, Real fY, Real fZ, 
                           Real fdW, Real fdX, Real fdY, Real fdZ)
    {
        w = fW;
        x = fX;
        y = fY;
        z = fZ;
        dw = fdW;
        dx = fdX;
        dy = fdY;
        dz = fdZ;
    }
    
    /// Construct a dual quaternion from a transformation matrix
    this(Matrix4 rot)
    {
        this.fromTransformationMatrix(rot);
    }
    
    /// Construct a dual quaternion from a unit quaternion and a translation vector
    this(Quaternion q, Vector3 trans)
    {
        this.fromRotationTranslation(q, trans);
    }
    
    /// Construct a dual quaternion from 8 manual w/x/y/z/dw/dx/dy/dz values
    this(Real* valptr)
    {
        //memcpy(&w, valptr, sizeof(Real)*8);
        w = valptr[0];
        x = valptr[1];
        y = valptr[2];
        z = valptr[3];
        dw = valptr[4];
        dx = valptr[5];
        dy = valptr[6];
        dz = valptr[7];
    }
    
    /// Array accessor operator
    Real opIndex ( size_t i )
    {
        assert( i < 8 );
        
        return *(&w+i);//TODO pointer to class fields
    }
    
    /*DualQuaternion opAssign (DualQuaternion rkQ)
    {
        w = rkQ.w;
        x = rkQ.x;
        y = rkQ.y;
        z = rkQ.z;
        dw = rkQ.dw;
        dx = rkQ.dx;
        dy = rkQ.dy;
        dz = rkQ.dz;
        
        return this;
    }*/

    alias Object.opEquals opEquals;
    bool opEquals (DualQuaternion rhs)
    {
        return (rhs.w == w) && (rhs.x == x) && (rhs.y == y) && (rhs.z == z) && 
            (rhs.dw == dw) && (rhs.dx == dx) && (rhs.dy == dy) && (rhs.dz == dz);
    }
        
    /// Pointer accessor for direct copying
    Real* ptr()
    {
        return &w;
    }
    
    /// Pointer accessor for direct copying
    const (Real*) ptr() const
    {
        return &w;//TODO seems to work
    }
    
    /// Exchange the contents of this dual quaternion with another. 
    void swap(ref DualQuaternion other)
    {
        std.algorithm.swap(w, other.w);
        std.algorithm.swap(x, other.x);
        std.algorithm.swap(y, other.y);
        std.algorithm.swap(z, other.z);
        std.algorithm.swap(dw, other.dw);
        std.algorithm.swap(dx, other.dx);
        std.algorithm.swap(dy, other.dy);
        std.algorithm.swap(dz, other.dz);
    }
    
    /// Check whether this dual quaternion contains valid values
    bool isNaN()// const
    {
        return Math.isNaN(w) || Math.isNaN(x) || Math.isNaN(y) || Math.isNaN(z) ||  
            Math.isNaN(dw) || Math.isNaN(dx) || Math.isNaN(dy) || Math.isNaN(dz);
    }
    
    /// Construct a dual quaternion from a rotation described by a Quaternion and a translation described by a Vector3
    void fromRotationTranslation (Quaternion q, Vector3 trans)
    {
        // non-dual part (just copy the quaternion):
        w = q.w;
        x = q.x;
        y = q.y;
        z = q.z;
        
        // dual part:
        Real half = 0.5;
        dw = -half *  (trans.x * x + trans.y * y + trans.z * z ); 
        dx =  half *  (trans.x * w + trans.y * z - trans.z * y ); 
        dy =  half * (-trans.x * z + trans.y * w + trans.z * x ); 
        dz =  half *  (trans.x * y - trans.y * x + trans.z * w ); 
    }

    /// Convert a dual quaternion into its two components, a Quaternion representing the rotation and a Vector3 representing the translation
    void toRotationTranslation (out Quaternion q, out Vector3 translation) //const;
    {
        // regular quaternion (just copy the non-dual part):
        q.w = w;
        q.x = x;
        q.y = y;
        q.z = z;
        
        // translation vector:
        Real doub = 2.0;
        translation.x = doub * (-dw*x + dx*w - dy*z + dz*y);
        translation.y = doub * (-dw*y + dx*z + dy*w - dz*x);
        translation.z = doub * (-dw*z - dx*y + dy*x + dz*w);
    }
    
    /// Construct a dual quaternion from a 4x4 transformation matrix
    void fromTransformationMatrix (Matrix4 kTrans)
    {
        Vector3 pos;
        Vector3 scale;
        Quaternion rot;
        
        kTrans.decomposition(pos, scale, rot);
        fromRotationTranslation(rot, pos);
    }
    
    /// Convert a dual quaternion to a 4x4 transformation matrix
    void toTransformationMatrix (Matrix4 kTrans) //const;
    {
        Vector3 pos;
        Quaternion rot;
        toRotationTranslation(rot, pos);
        
        Vector3 scale = Vector3.UNIT_SCALE;
        kTrans.makeTransform(pos, scale, rot);
    }
    
    Real w, x, y, z, dw, dx, dy, dz;
    
    /** 
        Function for writing to a stream. Outputs "DualQuaternion(w, x, y, z, dw, dx, dy, dz)" with w, x, y, z, dw, dx, dy, dz
        being the member values of the dual quaternion.
        */
    override string toString()
    {
        string o = std.conv.text("DualQuaternion(", w, ", ", x, ", ", y, ", ", z, ", ", dw, ", ", dx, ", ", dy, ", ", dz, ")");
        return o;
    }
}
/** @} */
/** @} */