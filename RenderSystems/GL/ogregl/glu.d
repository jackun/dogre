module ogregl.glu;
import derelict.opengl3.gl;

alias derelict.opengl3.constants.GL_RGBA GL_RGBA;

//http://cgit.freedesktop.org/nouveau/mesa/tree/src/glu/mesa/mipmap.c
enum GLU_INVALID_ENUM                   = 100900;
enum GLU_INVALID_VALUE                  = 100901;
enum GLU_OUT_OF_MEMORY                  = 100902;
enum GLU_INCOMPATIBLE_GL_VERSION        = 100903;
enum GLU_INVALID_OPERATION              = 100904;
enum GLU_ERROR                          = 100103;



int CEILING( int A, int B ) { return ( A % B == 0 ? A/B : A/B+1 ); }

GLint gluScaleImage(GLenum format,
                    GLsizei widthin, GLsizei heightin,
                    GLenum typein, void *datain,
                    GLsizei widthout, GLsizei heightout,
                    GLenum typeout, void *dataout)
{
    GLint components, i, j, k;
    GLfloat[] tempin, tempout;
    GLfloat sx, sy;
    GLint unpackrowlength, unpackalignment, unpackskiprows, unpackskippixels;
    GLint packrowlength, packalignment, packskiprows, packskippixels;
    GLint sizein, sizeout;
    GLint rowstride, rowlen;
    
    
    /* Determine number of components per pixel */
    switch (format) {
        case GL_COLOR_INDEX:
        case GL_STENCIL_INDEX:
        case GL_DEPTH_COMPONENT:
        case GL_RED:
        case GL_GREEN:
        case GL_BLUE:
        case GL_ALPHA:
        case GL_LUMINANCE:
            components = 1;
            break;
        case GL_LUMINANCE_ALPHA:
            components = 2;
            break;
        case GL_RGB:
        case GL_BGR:
            components = 3;
            break;
        case GL_RGBA:
        case GL_BGRA:
            //#ifdef GL_EXT_abgr
            //        case GL_ABGR_EXT:
            //#endif
            components = 4;
            break;
        default:
            return GLU_INVALID_ENUM;
    }
    
    /* Determine bytes per input datum */
    switch (typein) {
        case GL_UNSIGNED_BYTE:
            sizein = GLubyte.sizeof;
            break;
        case GL_BYTE:
            sizein = GLbyte.sizeof;
            break;
        case GL_UNSIGNED_SHORT:
            sizein = GLushort.sizeof;
            break;
        case GL_SHORT:
            sizein = GLshort.sizeof;
            break;
        case GL_UNSIGNED_INT:
            sizein = GLuint.sizeof;
            break;
        case GL_INT:
            sizein = GLint.sizeof;
            break;
        case GL_FLOAT:
            sizein = GLfloat.sizeof;
            break;
        case GL_BITMAP:
            /* not implemented yet */
        default:
            return GL_INVALID_ENUM;
    }
    
    /* Determine bytes per output datum */
    switch (typeout) {
        case GL_UNSIGNED_BYTE:
            sizeout = GLubyte.sizeof;
            break;
        case GL_BYTE:
            sizeout = GLbyte.sizeof;
            break;
        case GL_UNSIGNED_SHORT:
            sizeout = GLushort.sizeof;
            break;
        case GL_SHORT:
            sizeout = GLshort.sizeof;
            break;
        case GL_UNSIGNED_INT:
            sizeout = GLuint.sizeof;
            break;
        case GL_INT:
            sizeout = GLint.sizeof;
            break;
        case GL_FLOAT:
            sizeout = GLfloat.sizeof;
            break;
        case GL_BITMAP:
            /* not implemented yet */
        default:
            return GL_INVALID_ENUM;
    }
    
    /* Get glPixelStore state */
    glGetIntegerv(GL_UNPACK_ROW_LENGTH, &unpackrowlength);
    glGetIntegerv(GL_UNPACK_ALIGNMENT, &unpackalignment);
    glGetIntegerv(GL_UNPACK_SKIP_ROWS, &unpackskiprows);
    glGetIntegerv(GL_UNPACK_SKIP_PIXELS, &unpackskippixels);
    glGetIntegerv(GL_PACK_ROW_LENGTH, &packrowlength);
    glGetIntegerv(GL_PACK_ALIGNMENT, &packalignment);
    glGetIntegerv(GL_PACK_SKIP_ROWS, &packskiprows);
    glGetIntegerv(GL_PACK_SKIP_PIXELS, &packskippixels);
    
    /* Allocate storage for intermediate images */
    tempin = new GLfloat[widthin * heightin
                         * components * GLfloat.sizeof];
    if (!tempin) {
        return GLU_OUT_OF_MEMORY;
    }
    tempout = new GLfloat[widthout * heightout
                          * components * GLfloat.sizeof];
    if (tempout is null) {
        destroy(tempin);
        return GLU_OUT_OF_MEMORY;
    }
    
    
    /*
     * Unpack the pixel data and convert to floating point
     */
    
    if (unpackrowlength > 0) {
        rowlen = unpackrowlength;
    }
    else {
        rowlen = widthin;
    }
    if (sizein >= unpackalignment) {
        rowstride = components * rowlen;
    }
    else {
        rowstride = unpackalignment / sizein
            * CEILING(components * rowlen * sizein, unpackalignment);
    }
    
    switch (typein) {
        case GL_UNSIGNED_BYTE:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLubyte *ubptr = cast(GLubyte *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * ubptr++;
                }
            }
            break;
        case GL_BYTE:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLbyte *bptr = cast(GLbyte *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * bptr++;
                }
            }
            break;
        case GL_UNSIGNED_SHORT:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLushort *usptr = cast(GLushort *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * usptr++;
                }
            }
            break;
        case GL_SHORT:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLshort *sptr = cast(GLshort *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * sptr++;
                }
            }
            break;
        case GL_UNSIGNED_INT:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLuint *uiptr = cast(GLuint *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * uiptr++;
                }
            }
            break;
        case GL_INT:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLint *iptr = cast(GLint *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = cast(GLfloat) * iptr++;
                }
            }
            break;
        case GL_FLOAT:
            k = 0;
            for (i = 0; i < heightin; i++) {
                GLfloat *fptr = cast(GLfloat *) datain
                    + i * rowstride
                        + unpackskiprows * rowstride + unpackskippixels * components;
                for (j = 0; j < widthin * components; j++) {
                    
                    tempin[k++] = *fptr++;
                }
            }
            break;
        default:
            return GLU_INVALID_ENUM;
    }
    
    
    /*
     * Scale the image!
     */
    
    if (widthout > 1)
        sx = cast(GLfloat) (widthin - 1) / cast(GLfloat) (widthout - 1);
    else
        sx = cast(GLfloat) (widthin - 1);
    if (heightout > 1)
        sy = cast(GLfloat) (heightin - 1) / cast(GLfloat) (heightout - 1);
    else
        sy = cast(GLfloat) (heightin - 1);
    
    /*#define POINT_SAMPLE*/
    version(POINT_SAMPLE)
    {
        for (i = 0; i < heightout; i++) {
            GLint ii = i * sy;
            for (j = 0; j < widthout; j++) {
                GLint jj = j * sx;
                
                GLfloat *src = tempin + (ii * widthin + jj) * components;
                GLfloat *dst = tempout + (i * widthout + j) * components;
                
                for (k = 0; k < components; k++) {
                    *dst++ = *src++;
                }
            }
        }
    }
    else
    {
        if (sx < 1.0 && sy < 1.0) {
            /* magnify both width and height:  use weighted sample of 4 pixels */
            GLint i0, i1, j0, j1;
            GLfloat alpha, beta;
            GLfloat *src00, src01, src10, src11;
            GLfloat s1, s2;
            GLfloat *dst;
            
            for (i = 0; i < heightout; i++) {
                i0 = cast(int)(i * sy);
                i1 = i0 + 1;
                if (i1 >= heightin)
                    i1 = heightin - 1;
                /*   i1 = (i+1) * sy - EPSILON;*/
                alpha = i * sy - i0;
                for (j = 0; j < widthout; j++) {
                    j0 = cast(int)(j * sx);
                    j1 = j0 + 1;
                    if (j1 >= widthin)
                        j1 = widthin - 1;
                    /*      j1 = (j+1) * sx - EPSILON; */
                    beta = j * sx - j0;
                    
                    /* compute weighted average of pixels in rect (i0,j0)-(i1,j1) */
                    src00 = tempin.ptr + (i0 * widthin + j0) * components;
                    src01 = tempin.ptr + (i0 * widthin + j1) * components;
                    src10 = tempin.ptr + (i1 * widthin + j0) * components;
                    src11 = tempin.ptr + (i1 * widthin + j1) * components;
                    
                    dst = tempout.ptr + (i * widthout + j) * components;
                    
                    for (k = 0; k < components; k++) {
                        s1 = *src00++ * (1.0 - beta) + *src01++ * beta;
                        s2 = *src10++ * (1.0 - beta) + *src11++ * beta;
                        *dst++ = s1 * (1.0 - alpha) + s2 * alpha;
                    }
                }
            }
        }
        else 
        {
            /* shrink width and/or height:  use an unweighted box filter */
            GLint i0, i1;
            GLint j0, j1;
            GLint ii, jj;
            GLfloat sum;
            GLfloat *dst;
            
            for (i = 0; i < heightout; i++) {
                i0 = cast(int)(i * sy);
                i1 = i0 + 1;
                if (i1 >= heightin)
                    i1 = heightin - 1;
                /*   i1 = (i+1) * sy - EPSILON; */
                for (j = 0; j < widthout; j++) {
                    j0 = cast(int)(j * sx);
                    j1 = j0 + 1;
                    if (j1 >= widthin)
                        j1 = widthin - 1;
                    /*      j1 = (j+1) * sx - EPSILON; */
                    
                    dst = tempout.ptr + (i * widthout + j) * components;
                    
                    /* compute average of pixels in the rectangle (i0,j0)-(i1,j1) */
                    for (k = 0; k < components; k++) {
                        sum = 0.0;
                        for (ii = i0; ii <= i1; ii++) {
                            for (jj = j0; jj <= j1; jj++) {
                                sum += *(tempin.ptr + (ii * widthin + jj) * components + k);
                            }
                        }
                        sum /= (j1 - j0 + 1) * (i1 - i0 + 1);
                        *dst++ = sum;
                    }
                }
            }
        }
    }
    
    
    /*
     * Return output image
     */
    
    if (packrowlength > 0) {
        rowlen = packrowlength;
    }
    else {
        rowlen = widthout;
    }
    if (sizeout >= packalignment) {
        rowstride = components * rowlen;
    }
    else {
        rowstride = packalignment / sizeout
            * CEILING(components * rowlen * sizeout, packalignment);
    }
    
    switch (typeout) {
        case GL_UNSIGNED_BYTE:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLubyte *ubptr = cast(GLubyte *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *ubptr++ = cast(GLubyte) tempout[k++];
                }
            }
            break;
        case GL_BYTE:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLbyte *bptr = cast(GLbyte *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *bptr++ = cast(GLbyte) tempout[k++];
                }
            }
            break;
        case GL_UNSIGNED_SHORT:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLushort *usptr = cast(GLushort *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *usptr++ = cast(GLushort) tempout[k++];
                }
            }
            break;
        case GL_SHORT:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLshort *sptr = cast(GLshort *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *sptr++ = cast(GLshort) tempout[k++];
                }
            }
            break;
        case GL_UNSIGNED_INT:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLuint *uiptr = cast(GLuint *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *uiptr++ =cast (GLuint) tempout[k++];
                }
            }
            break;
        case GL_INT:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLint *iptr = cast(GLint *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *iptr++ = cast(GLint) tempout[k++];
                }
            }
            break;
        case GL_FLOAT:
            k = 0;
            for (i = 0; i < heightout; i++) {
                GLfloat *fptr = cast(GLfloat *) dataout
                    + i * rowstride
                        + packskiprows * rowstride + packskippixels * components;
                for (j = 0; j < widthout * components; j++) {
                    
                    *fptr++ = tempout[k++];
                }
            }
            break;
        default:
            return GLU_INVALID_ENUM;
    }
    
    
    /* free temporary image storage */
    destroy(tempin);
    destroy(tempout);
    
    return 0;
}

/*
 * Return the largest k such that 2^k <= n.
 */
static GLint
    ilog2(GLint n)
{
    GLint k;
    
    if (n <= 0)
        return 0;
    for (k = 0; n >>= 1; k++){}
    return k;
}

/*
 * Find the value nearest to n which is also a power of two.
 */
static GLint
    round2(GLint n)
{
    GLint m;
    
    for (m = 1; m < n; m *= 2){}
    
    /* m>=n */
    if (m - n <= n - m / 2) {
        return m;
    }
    else {
        return m / 2;
    }
}


/*
 * Given an pixel format and datatype, return the number of bytes to
 * store one pixel.
 */
static GLint
    bytes_per_pixel(GLenum format, GLenum type)
{
    GLint n, m;
    
    switch (format) {
        case GL_COLOR_INDEX:
        case GL_STENCIL_INDEX:
        case GL_DEPTH_COMPONENT:
        case GL_RED:
        case GL_GREEN:
        case GL_BLUE:
        case GL_ALPHA:
        case GL_LUMINANCE:
            n = 1;
            break;
        case GL_LUMINANCE_ALPHA:
            n = 2;
            break;
        case GL_RGB:
        case GL_BGR:
            n = 3;
            break;
        case GL_RGBA:
        case GL_BGRA:
//#ifdef GL_EXT_abgr
//        case GL_ABGR_EXT:
//#endif
            n = 4;
            break;
        default:
            n = 0;
    }
    
    switch (type) {
        case GL_UNSIGNED_BYTE:
            m = GLubyte.sizeof;
            break;
        case GL_BYTE:
            m = GLbyte.sizeof;
            break;
        case GL_BITMAP:
            m = 1;
            break;
        case GL_UNSIGNED_SHORT:
            m = GLushort.sizeof;
            break;
        case GL_SHORT:
            m = GLshort.sizeof;
            break;
        case GL_UNSIGNED_INT:
            m = GLuint.sizeof;
            break;
        case GL_INT:
            m = GLint.sizeof;
            break;
        case GL_FLOAT:
            m = GLfloat.sizeof;
            break;
        default:
            m = 0;
    }
    
    return n * m;
}
/*
 * WARNING: This function isn't finished and has never been tested!!!!
 */
GLint gluBuild1DMipmaps(GLenum target, GLint components,
                        GLsizei width, GLenum format, GLenum type, void *data)
{
    //GLubyte *texture;
    ubyte[] texture;
    GLint levels, max_levels;
    GLint new_width, max_width;
    GLint i, j, k, l;
    
    if (width < 1)
        return GLU_INVALID_VALUE;
    
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_width);
    max_levels = ilog2(max_width) + 1;
    
    /* Compute how many mipmap images to make */
    levels = ilog2(width) + 1;
    if (levels > max_levels) {
        levels = max_levels;
    }
    
    new_width = 1 << (levels - 1);
    
    //texture = cast(GLubyte *) malloc(new_width * components);
    texture = new ubyte[new_width * components];
    if (texture !is null) {
        return GLU_OUT_OF_MEMORY;
    }
    
    if (width != new_width) {
        /* initial rescaling */
        switch (type) {
            case GL_UNSIGNED_BYTE:
            {
                GLubyte *ub_data = cast(GLubyte *) data;
                for (i = 0; i < new_width; i++) {
                    j = i * width / new_width;
                    for (k = 0; k < components; k++) {
                        texture[i * components + k] = ub_data[j * components + k];
                    }
                }
            }
                break;
            default:
                /* Not implemented */
                return GLU_ERROR;
        }
    }
    
    /* generate and load mipmap images */
    for (l = 0; l < levels; l++) {
        glTexImage1D(GL_TEXTURE_1D, l, components, new_width, 0,
                     format, GL_UNSIGNED_BYTE, texture.ptr);
        
        /* Scale image down to 1/2 size */
        new_width = new_width / 2;
        for (i = 0; i < new_width; i++) {
            for (k = 0; k < components; k++) {
                GLint sample1, sample2;
                sample1 = cast(GLint) texture[i * 2 * components + k];
                sample2 = cast(GLint) texture[(i * 2 + 1) * components + k];
                texture[i * components + k] = cast(GLubyte) ((sample1 + sample2) / 2);
            }
        }
    }
    
    destroy(texture);
    
    return 0;
}



GLint gluBuild2DMipmaps(GLenum target, GLint components,
                        GLsizei width, GLsizei height, GLenum format,
                        GLenum type, void *data)
{
    GLint w, h, maxsize;
    ubyte[] _image;
    void* image;
    ubyte[] newimage;
    GLint neww, newh, level, bpp;
    int error;
    GLboolean done;
    GLint retval = 0;
    GLint unpackrowlength, unpackalignment, unpackskiprows, unpackskippixels;
    GLint packrowlength, packalignment, packskiprows, packskippixels;
    
    if (width < 1 || height < 1)
        return GLU_INVALID_VALUE;
    
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxsize);
    
    w = round2(width);
    if (w > maxsize) {
        w = maxsize;
    }
    h = round2(height);
    if (h > maxsize) {
        h = maxsize;
    }
    
    bpp = bytes_per_pixel(format, type);
    if (bpp == 0) {
        /* probably a bad format or type enum */
        return GLU_INVALID_ENUM;
    }
    
    /* Get current glPixelStore values */
    glGetIntegerv(GL_UNPACK_ROW_LENGTH, &unpackrowlength);
    glGetIntegerv(GL_UNPACK_ALIGNMENT, &unpackalignment);
    glGetIntegerv(GL_UNPACK_SKIP_ROWS, &unpackskiprows);
    glGetIntegerv(GL_UNPACK_SKIP_PIXELS, &unpackskippixels);
    glGetIntegerv(GL_PACK_ROW_LENGTH, &packrowlength);
    glGetIntegerv(GL_PACK_ALIGNMENT, &packalignment);
    glGetIntegerv(GL_PACK_SKIP_ROWS, &packskiprows);
    glGetIntegerv(GL_PACK_SKIP_PIXELS, &packskippixels);
    
    /* set pixel packing */
    glPixelStorei(GL_PACK_ROW_LENGTH, 0);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glPixelStorei(GL_PACK_SKIP_ROWS, 0);
    glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
    
    done = GL_FALSE;
    
    if (w != width || h != height) {
        /* must rescale image to get "top" mipmap texture image */
        _image = new ubyte[((w + 4) * h * bpp)];
        if (_image is null) {
            return GLU_OUT_OF_MEMORY;
        }
        image = _image.ptr;
        error = gluScaleImage(format, width, height, type, data,
                              w, h, type, image);
        if (error) {
            retval = error;
            done = GL_TRUE;
        }
    }
    else {
        image = cast(void *) data;
    }
    
    level = 0;
    while (!done) {
        if (image != data) {
            /* set pixel unpacking */
            glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
            glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
        }
        
        glTexImage2D(target, level, components, w, h, 0, format, type, image);
        
        if (w == 1 && h == 1)
            break;
        
        neww = (w < 2) ? 1 : w / 2;
        newh = (h < 2) ? 1 : h / 2;
        newimage = new ubyte[(neww + 4) * newh * bpp];//malloc((neww + 4) * newh * bpp);
        if (newimage is null) {
            return GLU_OUT_OF_MEMORY;
        }
        
        error = gluScaleImage(format, w, h, type, image,
                              neww, newh, type, newimage.ptr);
        if (error) {
            retval = error;
            done = GL_TRUE;
        }
        
        if (image != data) {
            destroy(image);
        }
        image = newimage.ptr;
        
        w = neww;
        h = newh;
        level++;
    }
    
    if (image != data) {
        destroy(image);
    }
    
    /* Restore original glPixelStore state */
    glPixelStorei(GL_UNPACK_ROW_LENGTH, unpackrowlength);
    glPixelStorei(GL_UNPACK_ALIGNMENT, unpackalignment);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, unpackskiprows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, unpackskippixels);
    glPixelStorei(GL_PACK_ROW_LENGTH, packrowlength);
    glPixelStorei(GL_PACK_ALIGNMENT, packalignment);
    glPixelStorei(GL_PACK_SKIP_ROWS, packskiprows);
    glPixelStorei(GL_PACK_SKIP_PIXELS, packskippixels);
    
    return retval;
}
