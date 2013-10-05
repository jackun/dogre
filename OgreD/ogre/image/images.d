module ogre.image.images;

//import std.container;
import core.stdc.string : memcpy;
import std.math;
import std.string;

import ogre.compat;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.resources.datastream;
import ogre.general.codec;
import ogre.math.bitwise;
import ogre.resources.resourcegroupmanager;
import ogre.image.pixelformat;
import ogre.math.maths;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Image
 *  @{
 */

/**
 * A record that describes a pixel format in detail.
 */
struct PixelFormatDescription {
    /* Name of the format, as in the enum */
    string name;
    /* Number of bytes one element (colour value) takes. */
    ubyte elemBytes;
    /* Pixel format flags, see enum PixelFormatFlags for the bit field
     * definitions
     */
    uint flags;
    /** Component type
     */
    PixelComponentType componentType;
    /** Component count
     */
    ubyte componentCount;
    /* Number of bits for red(or luminance), green, blue, alpha
     */
    ubyte rbits, gbits, bbits, abits; /*, ibits, dbits, ... */
    
    /* Masks and shifts as used by packers/unpackers */
    ulong rmask, gmask, bmask, amask;
    ubyte rshift, gshift, bshift, ashift;
}

/** Pixel format database */
immutable static PixelFormatDescription[PixelFormat.PF_COUNT] _pixelFormats = 
[
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_UNKNOWN",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       0,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 0,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_L8",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_LUMINANCE | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 0,
                       /* Masks and shifts */
                       0xFF, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_L16",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_LUMINANCE | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SHORT, 1,
                       /* rbits, gbits, bbits, abits */
                       16, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFF, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A8",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 8,
                       /* Masks and shifts */
                       0, 0, 0, 0xFF, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A4L4",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_LUMINANCE | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2,
                       /* rbits, gbits, bbits, abits */
                       4, 0, 0, 4,
                       /* Masks and shifts */
                       0x0F, 0, 0, 0xF0, 0, 0, 0, 4
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BYTE_LA",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_LUMINANCE,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 8,
                       /* Masks and shifts */
                       0,0,0,0,0,0,0,0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R5G6B5",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       5, 6, 5, 0,
                       /* Masks and shifts */
                       0xF800, 0x07E0, 0x001F, 0,
                       11, 5, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_B5G6R5",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       5, 6, 5, 0,
                       /* Masks and shifts */
                       0x001F, 0x07E0, 0xF800, 0,
                       0, 5, 11, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A4R4G4B4",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       4, 4, 4, 4,
                       /* Masks and shifts */
                       0x0F00, 0x00F0, 0x000F, 0xF000,
                       8, 4, 0, 12
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A1R5G5B5",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       5, 5, 5, 1,
                       /* Masks and shifts */
                       0x7C00, 0x03E0, 0x001F, 0x8000,
                       10, 5, 0, 15,
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8",
                       /* Bytes per element */
                       3,  // 24 bit integer -- special
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0xFF0000, 0x00FF00, 0x0000FF, 0,
                       16, 8, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_B8G8R8",
                       /* Bytes per element */
                       3,  // 24 bit integer -- special
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0x0000FF, 0x00FF00, 0xFF0000, 0,
                       0, 8, 16, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A8R8G8B8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000,
                       16, 8, 0, 24
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A8B8G8R8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000,
                       0, 8, 16, 24,
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_B8G8R8A8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0x0000FF00, 0x00FF0000, 0xFF000000, 0x000000FF,
                       8, 16, 24, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A2R10G10B10",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       10, 10, 10, 2,
                       /* Masks and shifts */
                       0x3FF00000, 0x000FFC00, 0x000003FF, 0xC0000000,
                       20, 10, 0, 30
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_A2B10G10R10",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       10, 10, 10, 2,
                       /* Masks and shifts */
                       0x000003FF, 0x000FFC00, 0x3FF00000, 0xC0000000,
                       0, 10, 20, 30
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DXT1",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3, // No alpha
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DXT2",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DXT3",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DXT4",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DXT5",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT16_RGB",
                       /* Bytes per element */
                       6,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT16, 3,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT16_RGBA",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT16, 4,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 16,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT32_RGB",
                       /* Bytes per element */
                       12,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 3,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT32_RGBA",
                       /* Bytes per element */
                       16,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 4,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 32,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_X8R8G8B8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000,
                       16, 8, 0, 24
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_X8B8G8R8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000,
                       0, 8, 16, 24
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8A8",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_DEPTH",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_DEPTH,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 1, // ?
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_SHORT_RGBA",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_SHORT, 4,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 16,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R3G3B2",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       3, 3, 2, 0,
                       /* Masks and shifts */
                       0xE0, 0x1C, 0x03, 0,
                       5, 2, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT16_R",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT16, 1,
                       /* rbits, gbits, bbits, abits */
                       16, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT32_R",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 1,
                       /* rbits, gbits, bbits, abits */
                       32, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_SHORT_GR",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SHORT, 2,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 0, 0,
                       /* Masks and shifts */
                       0x0000FFFF, 0xFFFF0000, 0, 0, 
                       0, 16, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT16_GR",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT16, 2,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_FLOAT32_GR",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 2,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_SHORT_RGB",
                       /* Bytes per element */
                       6,
                       /* Flags */
                       0,
                       /* Component type and count */
                       PixelComponentType.PCT_SHORT, 3,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC_RGB2",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC_RGBA2",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC_RGB4",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC_RGBA4",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC2_2BPP",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_PVRTC2_4BPP",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R11G11B10_FLOAT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_FLOAT | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_FLOAT32, 1,
                       /* rbits, gbits, bbits, abits */
                       11, 11, 10, 0,
                       /* Masks and shifts */
                       0xFFC00000, 0x03FF800, 0x000007FF, 0,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8_UINT",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 1,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 0,
                       /* Masks and shifts */
                       0xFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8_UINT",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 2,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 0, 0,
                       /* Masks and shifts */
                       0xFF00, 0x00FF, 0, 0,
                       8, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8_UINT",
                       /* Bytes per element */
                       3,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0xFF0000, 0x00FF00, 0x0000FF, 0,
                       16, 8, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8A8_UINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16_UINT",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 1,
                       /* rbits, gbits, bbits, abits */
                       16, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16_UINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 2,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 0, 0,
                       /* Masks and shifts */
                       0xFFFF0000, 0x0000FFFF, 0, 0,
                       16, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16_UINT",
                       /* Bytes per element */
                       6,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 3,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 0,
                       /* Masks and shifts */
                       0xFFFF00000000, 0x0000FFFF0000, 0x00000000FFFF, 0,
                       32, 16, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16A16_UINT",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 4,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 16,
                       /* Masks and shifts */
                       0xFFFF000000000000, 0x0000FFFF00000000, 0x00000000FFFF0000, 0x000000000000FFFF,
                       48, 32, 16, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32_UINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 1,
                       /* rbits, gbits, bbits, abits */
                       32, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFFFFFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32_UINT",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 2,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 0, 0,
                       /* Masks and shifts */
                       0xFFFFFFFF00000000, 0xFFFFFFFF, 0, 0,
                       32, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32B32_UINT",
                       /* Bytes per element */
                       12,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 3,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0,
                       64, 32, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32B32A32_UINT",
                       /* Bytes per element */
                       16,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_UINT, 4,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 32,
                       /* Masks and shifts */
                       0, 0, 0, 0,
                       96, 64, 32, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8_SINT",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 1,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 0,
                       /* Masks and shifts */
                       0xFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8_SINT",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 2,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 0, 0,
                       /* Masks and shifts */
                       0xFF00, 0x00FF, 0, 0,
                       8, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8_SINT",
                       /* Bytes per element */
                       3,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0xFF0000, 0x00FF00, 0x0000FF, 0,
                       16, 8, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8A8_SINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16_SINT",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 1,
                       /* rbits, gbits, bbits, abits */
                       16, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16_SINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 2,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 0, 0,
                       /* Masks and shifts */
                       0xFFFF0000, 0x0000FFFF, 0, 0,
                       16, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16_SINT",
                       /* Bytes per element */
                       6,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 3,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 0,
                       /* Masks and shifts */
                       0xFFFF00000000, 0x0000FFFF0000, 0x00000000FFFF, 0,
                       32, 16, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16A16_SINT",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 4,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 16,
                       /* Masks and shifts */
                       0xFFFF000000000000, 0x0000FFFF00000000, 0x00000000FFFF0000, 0x000000000000FFFF,
                       48, 32, 16, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32_SINT",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 1,
                       /* rbits, gbits, bbits, abits */
                       32, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFFFFFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32_SINT",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 2,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 0, 0,
                       /* Masks and shifts */
                       0xFFFFFFFF00000000, 0xFFFFFFFF, 0, 0,
                       32, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32B32_SINT",
                       /* Bytes per element */
                       12,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 3,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0,
                       64, 32, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R32G32B32A32_SINT",
                       /* Bytes per element */
                       16,
                       /* Flags */
                       PixelFormatFlags.PFF_INTEGER | PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_SINT, 4,
                       /* rbits, gbits, bbits, abits */
                       32, 32, 32, 32,
                       /* Masks and shifts */
                       0, 0, 0, 0,
                       96, 64, 32, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R9G9B9E5_SHAREDEXP",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       9, 9, 9, 0,
                       /* Masks and shifts */
                       0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC4_UNORM",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1, // Red only
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC4_SNORM",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1, // Red only
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC5_UNORM",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2, // Red-Green only
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC5_SNORM",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2, // Red-Green only
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC6H_UF16",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC6H_SF16",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC7_UNORM",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_BC7_UNORM_SRGB",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED | PixelFormatFlags.PFF_HASALPHA,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 0,
                       /* Masks and shifts */
                       0xFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_RG8",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 0, 0,
                       /* Masks and shifts */
                       0xFF0000, 0x00FF00, 0, 0,
                       8, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8_SNORM",
                       /* Bytes per element */
                       1,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1,
                       /* rbits, gbits, bbits, abits */
                       8, 0, 0, 0,
                       /* Masks and shifts */
                       0xFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8_SNORM",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 0, 0,
                       /* Masks and shifts */
                       0xFF00, 0x00FF, 0, 0,
                       8, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8_SNORM",
                       /* Bytes per element */
                       3,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 0,
                       /* Masks and shifts */
                       0xFF0000, 0x00FF00, 0x0000FF, 0,
                       16, 8, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R8G8B8A8_SNORM",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       8, 8, 8, 8,
                       /* Masks and shifts */
                       0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
                       24, 16, 8, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16_SNORM",
                       /* Bytes per element */
                       2,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 1,
                       /* rbits, gbits, bbits, abits */
                       16, 0, 0, 0,
                       /* Masks and shifts */
                       0xFFFF, 0, 0, 0,
                       0, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16_SNORM",
                       /* Bytes per element */
                       4,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 2,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 0, 0,
                       /* Masks and shifts */
                       0xFFFF0000, 0x0000FFFF, 0, 0,
                       16, 0, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16_SNORM",
                       /* Bytes per element */
                       6,
                       /* Flags */
                       PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 0,
                       /* Masks and shifts */
                       0xFFFF00000000, 0x0000FFFF0000, 0x00000000FFFF, 0,
                       32, 16, 0, 0
                       ),
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_R16G16B16A16_SNORM",
                       /* Bytes per element */
                       8,
                       /* Flags */
                       PixelFormatFlags.PFF_HASALPHA | PixelFormatFlags.PFF_NATIVEENDIAN,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 4,
                       /* rbits, gbits, bbits, abits */
                       16, 16, 16, 16,
                       /* Masks and shifts */
                       0xFFFF000000000000, 0x0000FFFF00000000, 0x00000000FFFF0000, 0x000000000000FFFF,
                       48, 32, 16, 0
                       ),
    
    //-----------------------------------------------------------------------
    PixelFormatDescription("PF_ETC1_RGB8",
                       /* Bytes per element */
                       0,
                       /* Flags */
                       PixelFormatFlags.PFF_COMPRESSED,
                       /* Component type and count */
                       PixelComponentType.PCT_BYTE, 3,
                       /* rbits, gbits, bbits, abits */
                       0, 0, 0, 0,
                       /* Masks and shifts */
                       0, 0, 0, 0, 0, 0, 0, 0
                       )
];

/** A primitive describing a volume (3D), image (2D) or line (1D) of pixels in memory.
 In case of a rectangle, depth must be 1. 
 Pixels are stored as a succession of "depth" slices, each containing "height" rows of 
 "width" pixels.
 */
class PixelBox : ogre.general.common.Box//, public ImageAlloc 
{
public:
    //For whatever reason
    alias ogre.general.common.Box Box;
    alias ogre.general.common.Rect Rect;
    
    /// Parameter constructor for setting the members manually
    this() {}
    ~this() {}
    /** Constructor providing extents in the form of a Box object. This constructor
     assumes the pixel data is laid out consecutively in memory. (this
     means row after row, slice after slice, with no space in between)
     @param extents      Extents of the region defined by data
     @param pixelFormat  Format of this buffer
     @param pixelData    Pointer to the actual data
     */
    this( Box extents, PixelFormat pixelFormat, void *pixelData=null)
    {
        super(extents);
        data = pixelData;
        format = pixelFormat;
        setConsecutive();
    }
    /** Constructor providing width, height and depth. This constructor
     assumes the pixel data is laid out consecutively in memory. (this
     means row after row, slice after slice, with no space in between)
     @param width        Width of the region
     @param height       Height of the region
     @param depth        Depth of the region
     @param pixelFormat  Format of this buffer
     @param pixelData    Pointer to the actual data
     */
    this(size_t width, size_t height, size_t depth, PixelFormat pixelFormat, void *pixelData=null)
    {
        super(0, 0, 0, width, height, depth);
        data = pixelData;
        format = pixelFormat;
        setConsecutive();
    }

    /// The data pointer 
    void *data;
    /// The pixel format 
    PixelFormat format;
    /** Number of elements between the leftmost pixel of one row and the left
     pixel of the next. This value must always be equal to getWidth() (consecutive) 
     for compressed formats.
     */
    size_t rowPitch;
    /** Number of elements between the top left pixel of one (depth) slice and 
     the top left pixel of the next. This can be a negative value. Must be a multiple of
     rowPitch. This value must always be equal to getWidth()*getHeight() (consecutive) 
     for compressed formats.
     */
    size_t slicePitch;
    
    /** Set the rowPitch and slicePitch so that the buffer is laid out consecutive 
     in memory.
     */        
    void setConsecutive()
    {
        rowPitch = getWidth();
        slicePitch = getWidth()*getHeight();
    }
    /** Get the number of elements between one past the rightmost pixel of 
     one row and the leftmost pixel of the next row. (IE this is zero if rows
     are consecutive).
     */
    size_t getRowSkip(){ return rowPitch - getWidth(); }
    /** Get the number of elements between one past the right bottom pixel of
     one slice and the left top pixel of the next slice. (IE this is zero if slices
     are consecutive).
     */
    size_t getSliceSkip(){ return slicePitch - (getHeight() * rowPitch); }
    
    /** Return whether this buffer is laid out consecutive in memory (ie the pitches
     are equal to the dimensions)
     */        
    bool isConsecutive() const
    { 
        return rowPitch == getWidth() && slicePitch == getWidth()*getHeight(); 
    }
    /** Return the size (in bytes) this image would take if it was
     laid out consecutive in memory
     */
    size_t getConsecutiveSize()
    {
        return PixelUtil.getMemorySize(getWidth(), getHeight(), getDepth(), format);
    }
    /** Return a subvolume of this PixelBox.
     @param def  Defines the bounds of the subregion to return
     @return A pixel box describing the region and the data in it
     @remarks    This function does not copy any data, it just returns
     a PixelBox object with a data pointer pointing somewhere inside 
     the data of object.
     @throws Exception(ERR_INVALIDPARAMS) if def is not fully contained
     */
    PixelBox getSubVolume(Box def)
    {
        if(PixelUtil.isCompressed(format))
        {
            if(def.left == left && def.top == top && def.front == front &&
               def.right == right && def.bottom == bottom && def.back == back)
            {
                // Entire buffer is being queried
                return this;
            }
            throw new InvalidParamsError("Cannot return subvolume of compressed PixelBuffer", "PixelBox::getSubVolume");
        }
        if(!contains(def))
            throw new InvalidParamsError("Bounds out of range", "PixelBox::getSubVolume");
        
        size_t elemSize = PixelUtil.getNumElemBytes(format);
        // Calculate new data origin
        // Notice how we do not propagate left/top/front from the incoming box, since
        // the returned pointer is already offset
        auto rval = new PixelBox(def.getWidth(), def.getHeight(), def.getDepth(), format, 
                                 (cast(ubyte*)data) + ((def.left-left)*elemSize)
                                 + ((def.top-top)*rowPitch*elemSize)
                                 + ((def.front-front)*slicePitch*elemSize)
                                 );
        
        rval.rowPitch = rowPitch;
        rval.slicePitch = slicePitch;
        rval.format = format;
        
        return rval;
    }
    
    /**
     * Get colour value from a certain location in the PixelBox. The z coordinate
     * is only valid for cubemaps and volume textures. This uses the first (largest)
     * mipmap.
     */
    ColourValue getColourAt(size_t x, size_t y, size_t z)
    {
        ColourValue cv;
        
        size_t pixelSize = PixelUtil.getNumElemBytes(format);
        size_t pixelOffset = pixelSize * (z * slicePitch + y * rowPitch + x);
        PixelUtil.unpackColour(cv, format, cast(ubyte*)data + pixelOffset);
        
        return cv;
    }
    
    /**
     * Set colour value at a certain location in the PixelBox. The z coordinate
     * is only valid for cubemaps and volume textures. This uses the first (largest)
     * mipmap.
     */
    void setColourAt(ColourValue cv, size_t x, size_t y, size_t z)
    {
        size_t pixelSize = PixelUtil.getNumElemBytes(format);
        size_t pixelOffset = pixelSize * (z * slicePitch + y * rowPitch + x);
        PixelUtil.packColour(cv, format, cast(ubyte*)data + pixelOffset);
    }
}


/**
 * Some utility functions for packing and unpacking pixel data
 */
class PixelUtil {
public:

    /**
     * Directly get the description record for provided pixel format. For debug builds,
     * this checks the bounds of fmt with an assertion.
     */
    static PixelFormatDescription getDescriptionFor(PixelFormat fmt)
    {
        int ord = cast(int)fmt;
        assert(ord>=0 && ord<PixelFormat.PF_COUNT);

        return _pixelFormats[ord];
    }

    /** Returns the size in bytes of an element of the given pixel format.
     @return
     The size in bytes of an element. See Remarks.
     @remarks
     Passing PF_UNKNOWN will result in returning a size of 0 bytes.
     */
    static size_t getNumElemBytes( PixelFormat format )
    {
        return getDescriptionFor(format).elemBytes;
    }
    
    /** Returns the size in bits of an element of the given pixel format.
     @return
     The size in bits of an element. See Remarks.
     @remarks
     Passing PF_UNKNOWN will result in returning a size of 0 bits.
     */
    static size_t getNumElemBits( PixelFormat format )
    {
        return getDescriptionFor(format).elemBytes * 8;
    }
    
    /** Returns the size in memory of a region with the given extents and pixel
     format with consecutive memory layout.
     @param width
     The width of the area
     @param height
     The height of the area
     @param depth
     The depth of the area
     @param format
     The format of the area
     @return
     The size in bytes
     @remarks
     In case that the format is non-compressed, this simply returns
     width*height*depth*PixelUtil.getNumElemBytes(format). In the compressed
     case, this does serious magic.
     */
    static size_t getMemorySize(size_t width, size_t height, size_t depth, PixelFormat format)
    {
        if(isCompressed(format))
        {
            switch(format)
            {
                // DXT formats work by dividing the image into 4x4 blocks, then encoding each
                // 4x4 block with a certain number of bytes. 
                case PixelFormat.PF_DXT1:
                    return ((width+3)/4)*((height+3)/4)*8 * depth;
                case PixelFormat.PF_DXT2:
                case PixelFormat.PF_DXT3:
                case PixelFormat.PF_DXT4:
                case PixelFormat.PF_DXT5:
                    return ((width+3)/4)*((height+3)/4)*16 * depth;
                    
                case PixelFormat.PF_BC4_SNORM:
                case PixelFormat.PF_BC4_UNORM:
                    return cast(size_t)(ceil(width/4.0f)*ceil(height/4.0f)*8.0f);
                case PixelFormat.PF_BC5_SNORM:
                case PixelFormat.PF_BC5_UNORM:
                case PixelFormat.PF_BC6H_SF16:
                case PixelFormat.PF_BC6H_UF16:
                case PixelFormat.PF_BC7_UNORM:
                case PixelFormat.PF_BC7_UNORM_SRGB:
                    return cast(size_t)(ceil(width/4.0f)*ceil(height/4.0f)*16.0f);
                    
                    // Size calculations from the PVRTC OpenGL extension spec
                    // http://www.khronos.org/registry/gles/extensions/IMG/IMG_texture_compression_pvrtc.txt
                    // Basically, 32 bytes is the minimum texture size.  Smaller textures are padded up to 32 bytes
                case PixelFormat.PF_PVRTC_RGB2:
                case PixelFormat.PF_PVRTC_RGBA2:
                case PixelFormat.PF_PVRTC2_2BPP:
                    return (std.algorithm.max(width, 16) * std.algorithm.max(height, 8) * 2 + 7) / 8;
                case PixelFormat.PF_PVRTC_RGB4:
                case PixelFormat.PF_PVRTC_RGBA4:
                case PixelFormat.PF_PVRTC2_4BPP:
                    return (std.algorithm.max(width, 8) * std.algorithm.max(height, 8) * 4 + 7) / 8;
                    
                case PixelFormat.PF_ETC1_RGB8:
                    return ((width * height) >> 1);
                    
                default:
                    throw new InvalidParamsError("Invalid compressed pixel format",
                                                 "PixelUtil.getMemorySize");
            }
        }
        else
        {
            return width*height*depth*getNumElemBytes(format);
        }
    }
    
    /** Returns the property flags for this pixel format
     @return
     A bitfield combination of PixelFormatFlags.PFF_HASALPHA, PixelFormatFlags.PFF_ISCOMPRESSED,
     PixelFormatFlags.PFF_FLOAT, PixelFormatFlags.PFF_DEPTH, PixelFormatFlags.PFF_NATIVEENDIAN, PixelFormatFlags.PFF_LUMINANCE
     @remarks
     This replaces the separate functions for formatHasAlpha, formatIsFloat, ...
     */
    static uint getFlags( PixelFormat format )
    {
        return getDescriptionFor(format).flags;
    }
    
    /** Shortcut method to determine if the format has an alpha component */
    static bool hasAlpha(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_HASALPHA) > 0;
    }
    /** Shortcut method to determine if the format is floating point */
    static bool isFloatingPoint(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_FLOAT) > 0;
    }
    /** Shortcut method to determine if the format is integer */
    static bool isInteger(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_INTEGER) > 0;
    }
    /** Shortcut method to determine if the format is compressed */
    static bool isCompressed(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_COMPRESSED) > 0;
    }
    /** Shortcut method to determine if the format is a depth format. */
    static bool isDepth(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_DEPTH) > 0;
    }
    /** Shortcut method to determine if the format is in native endian format. */
    static bool isNativeEndian(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_NATIVEENDIAN) > 0;
    }
    /** Shortcut method to determine if the format is a luminance format. */
    static bool isLuminance(PixelFormat format)
    {
        return (PixelUtil.getFlags(format) & PixelFormatFlags.PFF_LUMINANCE) > 0;
    }
    
    /** Return wether a certain image extent is valid for this image format.
     @param width
     The width of the area
     @param height
     The height of the area
     @param depth
     The depth of the area
     @param format
     The format of the area
     @remarks For non-compressed formats, this is always true. For DXT formats,
     only sizes with a width and height multiple of 4 and depth 1 are allowed.
     */
    static bool isValidExtent(size_t width, size_t height, size_t depth, PixelFormat format)
    {
        if(isCompressed(format))
        {
            switch(format)
            {
                case PixelFormat.PF_DXT1:
                case PixelFormat.PF_DXT2:
                case PixelFormat.PF_DXT3:
                case PixelFormat.PF_DXT4:
                case PixelFormat.PF_DXT5:
                case PixelFormat.PF_BC4_SNORM:
                case PixelFormat.PF_BC4_UNORM:
                case PixelFormat.PF_BC5_SNORM:
                case PixelFormat.PF_BC5_UNORM:
                case PixelFormat.PF_BC6H_SF16:
                case PixelFormat.PF_BC6H_UF16:
                case PixelFormat.PF_BC7_UNORM:
                case PixelFormat.PF_BC7_UNORM_SRGB:
                    return ((width&3)==0 && (height&3)==0 && depth==1);
                default:
                    return true;
            }
        }
        else
        {
            return true;
        }
    }
    
    /** Gives the number of bits (RGBA) for a format. See remarks.          
     @remarks      For non-colour formats (dxt, depth) this returns [0,0,0,0].
     */
    static void getBitDepths(PixelFormat format, ref int[4] rgba)
    {
        PixelFormatDescription des = getDescriptionFor(format);
        rgba[0] = des.rbits;
        rgba[1] = des.gbits;
        rgba[2] = des.bbits;
        rgba[3] = des.abits;
    }
    
    /** Gives the masks for the R, G, B and A component
     @note         Only valid for native endian formats
     */
    static void getBitMasks(PixelFormat format, ref uint[4] rgba)
    {
        PixelFormatDescription des = getDescriptionFor(format);
        rgba[0] = cast(uint)des.rmask;
        rgba[1] = cast(uint)des.gmask;
        rgba[2] = cast(uint)des.bmask;
        rgba[3] = cast(uint)des.amask;
    }
    
    /** Gives the bit shifts for R, G, B and A component
     @note           Only valid for native endian formats
     */
    static void getBitShifts(PixelFormat format, ubyte[4] rgba)
    {
        PixelFormatDescription des = getDescriptionFor(format);
        rgba[0] = des.rshift;
        rgba[1] = des.gshift;
        rgba[2] = des.bshift;
        rgba[3] = des.ashift;
    }
    
    /** Gets the name of an image format
     */
    static string getFormatName(PixelFormat srcformat)
    {
        return getDescriptionFor(srcformat).name;
    }
    
    /** Returns wether the format can be packed or unpacked with the packColour()
     and unpackColour() functions. This is generally not true for compressed and
     depth formats as they are special. It can only be true for formats with a
     fixed element size.
     @return 
     true if yes, otherwise false
     */
    static bool isAccessible(PixelFormat srcformat)
    {
        if (srcformat == PixelFormat.PF_UNKNOWN)
            return false;
        uint flags = getFlags(srcformat);
        return !((flags & PixelFormatFlags.PFF_COMPRESSED) || (flags & PixelFormatFlags.PFF_DEPTH));
    }
    
    /** Returns the component type for a certain pixel format. Returns PixelComponentType.PCT_BYTE
     in case there is no clear component type like with compressed formats.
     This is one of PixelComponentType.PCT_BYTE, PixelComponentType.PCT_SHORT, PixelComponentType.PCT_FLOAT16, PixelComponentType.PCT_FLOAT32.
     */
    static PixelComponentType getComponentType(PixelFormat fmt)
    {
        PixelFormatDescription des = getDescriptionFor(fmt);
        return des.componentType;
    }
    
    /** Returns the component count for a certain pixel format. Returns 3(no alpha) or 
     4 (has alpha) in case there is no clear component type like with compressed formats.
     */
    static size_t getComponentCount(PixelFormat fmt)
    {
        PixelFormatDescription des = getDescriptionFor(fmt);
        return des.componentCount;
    }
    
    /** Gets the format from given name.
     @param  name            The string of format name
     @param  accessibleOnly  If true, non-accessible format will treat as invalid format,
     otherwise, all supported format are valid.
     @param  caseSensitive   Should be set true if string match should use case sensitivity.
     @return                The format match the format name, or PF_UNKNOWN if is invalid name.
     */
    static PixelFormat getFormatFromName(string name, bool accessibleOnly = false, bool caseSensitive = false)
    {
        string tmp = name;
        if (!caseSensitive)
        {
            // We are stored upper-case format names.
            tmp = tmp.toUpper();
        }
        
        foreach (i; 0..PixelFormat.PF_COUNT)
        {
            PixelFormat pf = cast(PixelFormat)(i);
            if (!accessibleOnly || isAccessible(pf))
            {
                if (tmp == getFormatName(pf))
                    return pf;
            }
        }
        return PixelFormat.PF_UNKNOWN;
    }
    
    /** Gets the BNF expression of the pixel-formats.
     @note                   The string returned by this function is intended to be used as a BNF expression
     to work with Compiler2Pass.
     @param  accessibleOnly  If true, only accessible pixel format will take into account, otherwise all
     pixel formats list in PixelFormat enumeration will being returned.
     @return                A string contains the BNF expression.
     */
    static string getBNFExpressionOfPixelFormats(bool accessibleOnly = false)
    {
        // Collect format names sorted by length, it's required by BNF compiler
        // that similar tokens need longer ones comes first.
        //typedef multimap<String::size_type, String>::type FormatNameMap;
        //alias MultiMap!(size_t, string) FormatNameMap;
        alias string[][size_t] FormatNameMap;
        FormatNameMap formatNames;
        foreach (i; 0..PixelFormat.PF_COUNT)
        {
            PixelFormat pf = cast(PixelFormat)(i);
            if (!accessibleOnly || isAccessible(pf))
            {
                string formatName = getFormatName(pf);
                formatNames.initAA(formatName.length);
                formatNames[formatName.length] ~= formatName;
            }
        }
        
        // Populate the BNF expression in reverse order
        string result;
        // Note: Stupid M$ VC7.1 can't dealing operator!= with FormatNameMap::const_reverse_iterator.
        foreach_reverse (k,vs; formatNames) //TODO Check the order.
        {
            foreach_reverse (v; vs) //TODO Check the order.
            {
                if (result !is null)
                    result ~= " | ";
                result ~= "'" ~ v ~ "'";
            }
            
        }
        
        return result;
    }
    
    /** Returns the similar format but acoording with given bit depths.
     @param fmt      The original foamt.
     @param integerBits Preferred bit depth (pixel bits) for integer pixel format.
     Available values: 0, 16 and 32, where 0 (the default) means as it is.
     @param floatBits Preferred bit depth (channel bits) for float pixel format.
     Available values: 0, 16 and 32, where 0 (the default) means as it is.
     @return        The format that similar original format with bit depth according
     with preferred bit depth, or original format if no conversion occurring.
     */
    static PixelFormat getFormatForBitDepths(PixelFormat fmt, ushort integerBits, ushort floatBits)
    {
        switch (integerBits)
        {
            case 16:
                switch (fmt)
                {
                    case PixelFormat.PF_R8G8B8:
                    case PixelFormat.PF_X8R8G8B8:
                        return PixelFormat.PF_R5G6B5;
                        
                    case PixelFormat.PF_B8G8R8:
                    case PixelFormat.PF_X8B8G8R8:
                        return PixelFormat.PF_B5G6R5;
                        
                    case PixelFormat.PF_A8R8G8B8:
                    case PixelFormat.PF_R8G8B8A8:
                    case PixelFormat.PF_A8B8G8R8:
                    case PixelFormat.PF_B8G8R8A8:
                        return PixelFormat.PF_A4R4G4B4;
                        
                    case PixelFormat.PF_A2R10G10B10:
                    case PixelFormat.PF_A2B10G10R10:
                        return PixelFormat.PF_A1R5G5B5;
                        
                    default:
                        // use original image format
                        break;
                }
                break;
                
            case 32:
                switch (fmt)
                {
                    case PixelFormat.PF_R5G6B5:
                        return PixelFormat.PF_X8R8G8B8;
                        
                    case PixelFormat.PF_B5G6R5:
                        return PixelFormat.PF_X8B8G8R8;
                        
                    case PixelFormat.PF_A4R4G4B4:
                        return PixelFormat.PF_A8R8G8B8;
                        
                    case PixelFormat.PF_A1R5G5B5:
                        return PixelFormat.PF_A2R10G10B10;
                        
                    default:
                        // use original image format
                        break;
                }
                break;
                
            default:
                // use original image format
                break;
        }
        
        switch (floatBits)
        {
            case 16:
                switch (fmt)
                {
                    case PixelFormat.PF_FLOAT32_R:
                        return PixelFormat.PF_FLOAT16_R;
                        
                    case PixelFormat.PF_FLOAT32_RGB:
                        return PixelFormat.PF_FLOAT16_RGB;
                        
                    case PixelFormat.PF_FLOAT32_RGBA:
                        return PixelFormat.PF_FLOAT16_RGBA;
                        
                    default:
                        // use original image format
                        break;
                }
                break;
                
            case 32:
                switch (fmt)
                {
                    case PixelFormat.PF_FLOAT16_R:
                        return PixelFormat.PF_FLOAT32_R;
                        
                    case PixelFormat.PF_FLOAT16_RGB:
                        return PixelFormat.PF_FLOAT32_RGB;
                        
                    case PixelFormat.PF_FLOAT16_RGBA:
                        return PixelFormat.PF_FLOAT32_RGBA;
                        
                    default:
                        // use original image format
                        break;
                }
                break;
                
            default:
                // use original image format
                break;
        }
        
        return fmt;
    }
    
    /** Pack a colour value to memory
     @param colour   The colour
     @param pf       Pixelformat in which to write the colour
     @param dest     Destination memory location
     */
    static void packColour(ColourValue colour,PixelFormat pf,  void* dest)
    {
        packColour(colour.r, colour.g, colour.b, colour.a, pf, dest);
    }
    /** Pack a colour value to memory
     @param r,g,b,a  The four colour components, range 0x00 to 0xFF
     @param pf       Pixelformat in which to write the colour
     @param dest     Destination memory location
     */
    static void packColour(ubyte r,ubyte g,ubyte b,ubyte a,PixelFormat pf,  void* dest)
    {
        PixelFormatDescription des = getDescriptionFor(pf);
        if(des.flags & PixelFormatFlags.PFF_NATIVEENDIAN) {
            // Shortcut for integer formats packing
            uint value = ((Bitwise.fixedToFixed(r, 8, des.rbits)<<des.rshift) & des.rmask) |
                ((Bitwise.fixedToFixed(g, 8, des.gbits)<<des.gshift) & des.gmask) |
                    ((Bitwise.fixedToFixed(b, 8, des.bbits)<<des.bshift) & des.bmask) |
                    ((Bitwise.fixedToFixed(a, 8, des.abits)<<des.ashift) & des.amask);
            // And write to memory
            Bitwise.intWrite(dest, des.elemBytes, value);
        } else {
            // Convert to float
            packColour(cast(float)r/255.0f,cast(float)g/255.0f,cast(float)b/255.0f,cast(float)a/255.0f, pf, dest);
        }
    }
    /** Pack a colour value to memory
     @param r,g,b,a  The four colour components, range 0.0f to 1.0f
     (an exception to this case exists for floating point pixel
     formats, which don't clamp to 0.0f..1.0f)
     @param pf       Pixelformat in which to write the colour
     @param dest     Destination memory location
     */
    static void packColour(float r,float g,float b,float a,PixelFormat pf,  void* dest)
    {
        // Catch-it-all here
        PixelFormatDescription des = getDescriptionFor(pf);
        if(des.flags & PixelFormatFlags.PFF_NATIVEENDIAN) {
            // Do the packing
            //import std.stdio;
            //writeln (dest, " ", r, " ", g, " ", b, " ", a);
            uint value = ((Bitwise.floatToFixed(r, des.rbits)<<des.rshift) & des.rmask) |
                ((Bitwise.floatToFixed(g, des.gbits)<<des.gshift) & des.gmask) |
                    ((Bitwise.floatToFixed(b, des.bbits)<<des.bshift) & des.bmask) |
                    ((Bitwise.floatToFixed(a, des.abits)<<des.ashift) & des.amask);
            // And write to memory
            Bitwise.intWrite(dest, des.elemBytes, value);
        } else {
            switch(pf)
            {
                case PixelFormat.PF_FLOAT32_R:
                    (cast(float*)dest)[0] = r;
                    break;
                case PixelFormat.PF_FLOAT32_GR:
                    (cast(float*)dest)[0] = g;
                    (cast(float*)dest)[1] = r;
                    break;
                case PixelFormat.PF_FLOAT32_RGB:
                    (cast(float*)dest)[0] = r;
                    (cast(float*)dest)[1] = g;
                    (cast(float*)dest)[2] = b;
                    break;
                case PixelFormat.PF_FLOAT32_RGBA:
                    (cast(float*)dest)[0] = r;
                    (cast(float*)dest)[1] = g;
                    (cast(float*)dest)[2] = b;
                    (cast(float*)dest)[3] = a;
                    break;
                case PixelFormat.PF_FLOAT16_R:
                    (cast(ushort*)dest)[0] = Bitwise.floatToHalf(r);
                    break;
                case PixelFormat.PF_FLOAT16_GR:
                    (cast(ushort*)dest)[0] = Bitwise.floatToHalf(g);
                    (cast(ushort*)dest)[1] = Bitwise.floatToHalf(r);
                    break;
                case PixelFormat.PF_FLOAT16_RGB:
                    (cast(ushort*)dest)[0] = Bitwise.floatToHalf(r);
                    (cast(ushort*)dest)[1] = Bitwise.floatToHalf(g);
                    (cast(ushort*)dest)[2] = Bitwise.floatToHalf(b);
                    break;
                case PixelFormat.PF_FLOAT16_RGBA:
                    (cast(ushort*)dest)[0] = Bitwise.floatToHalf(r);
                    (cast(ushort*)dest)[1] = Bitwise.floatToHalf(g);
                    (cast(ushort*)dest)[2] = Bitwise.floatToHalf(b);
                    (cast(ushort*)dest)[3] = Bitwise.floatToHalf(a);
                    break;
                case PixelFormat.PF_SHORT_RGB:
                    (cast(ushort*)dest)[0] = cast(ushort)Bitwise.floatToFixed(r, 16);
                    (cast(ushort*)dest)[1] = cast(ushort)Bitwise.floatToFixed(g, 16);
                    (cast(ushort*)dest)[2] = cast(ushort)Bitwise.floatToFixed(b, 16);
                    break;
                case PixelFormat.PF_SHORT_RGBA:
                    (cast(ushort*)dest)[0] = cast(ushort)Bitwise.floatToFixed(r, 16);
                    (cast(ushort*)dest)[1] = cast(ushort)Bitwise.floatToFixed(g, 16);
                    (cast(ushort*)dest)[2] = cast(ushort)Bitwise.floatToFixed(b, 16);
                    (cast(ushort*)dest)[3] = cast(ushort)Bitwise.floatToFixed(a, 16);
                    break;
                case PixelFormat.PF_BYTE_LA:
                    (cast(ubyte*)dest)[0] = cast(ubyte)Bitwise.floatToFixed(r, 8);
                    (cast(ubyte*)dest)[1] = cast(ubyte)Bitwise.floatToFixed(a, 8);
                    break;
                default:
                    // Not yet supported
                    throw new NotImplementedError(
                        "pack to "~getFormatName(pf)~" not implemented",
                        "PixelUtil.packColour");
                    break;
            }
        }
    }
    
    /** Unpack a colour value from memory
     @param colour   The colour is returned here
     @param pf       Pixelformat in which to read the colour
     @param src      Source memory location
     */
    //TODO Maybe needs forward!T
    static void unpackColour( ColourValue colour, PixelFormat pf, void* src)
    {
        unpackColour(colour.r, colour.g, colour.b, colour.a, pf, src);
    }
    /** Unpack a colour value from memory
     @param r,g,b,a  The colour is returned here (as byte)
     @param pf       Pixelformat in which to read the colour
     @param src      Source memory location
     @remarks    This function returns the colour components in 8 bit precision,
     this will lose precision when coming from PF_A2R10G10B10 or floating
     point formats.  
     */
    static void unpackColour( ubyte r, ref ubyte g, ref ubyte b, ref ubyte a, PixelFormat pf, void* src)
    {
        PixelFormatDescription des = getDescriptionFor(pf);
        if(des.flags & PixelFormatFlags.PFF_NATIVEENDIAN) {
            // Shortcut for integer formats unpacking
            uint value = Bitwise.intRead(src, des.elemBytes);
            if(des.flags & PixelFormatFlags.PFF_LUMINANCE)
            {
                // Luminance format -- only rbits used
                r = g = b = cast(ubyte)Bitwise.fixedToFixed(
                    (value & des.rmask)>>des.rshift, des.rbits, 8);
            }
            else
            {
                r = cast(ubyte)Bitwise.fixedToFixed((value & des.rmask)>>des.rshift, des.rbits, 8);
                g = cast(ubyte)Bitwise.fixedToFixed((value & des.gmask)>>des.gshift, des.gbits, 8);
                b = cast(ubyte)Bitwise.fixedToFixed((value & des.bmask)>>des.bshift, des.bbits, 8);
            }
            if(des.flags & PixelFormatFlags.PFF_HASALPHA)
            {
                a = cast(ubyte)Bitwise.fixedToFixed((value & des.amask)>>des.ashift, des.abits, 8);
            }
            else
            {
                a = 255; // No alpha, default a component to full
            }
        } else {
            // Do the operation with the more generic floating point
            float rr = 0, gg = 0, bb = 0, aa = 0;
            unpackColour(rr, gg, bb, aa, pf, src);
            r = cast(ubyte)Bitwise.floatToFixed(rr, 8);
            g = cast(ubyte)Bitwise.floatToFixed(gg, 8);
            b = cast(ubyte)Bitwise.floatToFixed(bb, 8);
            a = cast(ubyte)Bitwise.floatToFixed(aa, 8);
        }
    }
    /** Unpack a colour value from memory
     @param r,g,b,a  The colour is returned here (as float)
     @param pf       Pixelformat in which to read the colour
     @param src      Source memory location
     */
    static void unpackColour(ref float r, ref float g, ref float b, ref float a, PixelFormat pf, void* src)
    {
        PixelFormatDescription des = getDescriptionFor(pf);
        if(des.flags & PixelFormatFlags.PFF_NATIVEENDIAN) {
            // Shortcut for integer formats unpacking
            uint value = Bitwise.intRead(src, des.elemBytes);
            if(des.flags & PixelFormatFlags.PFF_LUMINANCE)
            {
                // Luminance format -- only rbits used
                r = g = b = Bitwise.fixedToFloat(
                    (value & des.rmask)>>des.rshift, des.rbits);
            }
            else
            {
                r = Bitwise.fixedToFloat((value & des.rmask)>>des.rshift, des.rbits);
                g = Bitwise.fixedToFloat((value & des.gmask)>>des.gshift, des.gbits);
                b = Bitwise.fixedToFloat((value & des.bmask)>>des.bshift, des.bbits);
            }
            if(des.flags & PixelFormatFlags.PFF_HASALPHA)
            {
                a = Bitwise.fixedToFloat((value & des.amask)>>des.ashift, des.abits);
            }
            else
            {
                a = 1.0f; // No alpha, default a component to full
            }
        } else {
            switch(pf)
            {
                case PixelFormat.PF_FLOAT32_R:
                    r = g = b = (cast(float*)src)[0];
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT32_GR:
                    g = (cast(float*)src)[0];
                    r = b = (cast(float*)src)[1];
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT32_RGB:
                    r = (cast(float*)src)[0];
                    g = (cast(float*)src)[1];
                    b = (cast(float*)src)[2];
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT32_RGBA:
                    r = (cast(float*)src)[0];
                    g = (cast(float*)src)[1];
                    b = (cast(float*)src)[2];
                    a = (cast(float*)src)[3];
                    break;
                case PixelFormat.PF_FLOAT16_R:
                    r = g = b = Bitwise.halfToFloat((cast(ushort*)src)[0]);
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT16_GR:
                    g = Bitwise.halfToFloat((cast(ushort*)src)[0]);
                    r = b = Bitwise.halfToFloat((cast(ushort*)src)[1]);
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT16_RGB:
                    r = Bitwise.halfToFloat((cast(ushort*)src)[0]);
                    g = Bitwise.halfToFloat((cast(ushort*)src)[1]);
                    b = Bitwise.halfToFloat((cast(ushort*)src)[2]);
                    a = 1.0f;
                    break;
                case PixelFormat.PF_FLOAT16_RGBA:
                    r = Bitwise.halfToFloat((cast(ushort*)src)[0]);
                    g = Bitwise.halfToFloat((cast(ushort*)src)[1]);
                    b = Bitwise.halfToFloat((cast(ushort*)src)[2]);
                    a = Bitwise.halfToFloat((cast(ushort*)src)[3]);
                    break;
                case PixelFormat.PF_SHORT_RGB:
                    r = Bitwise.fixedToFloat((cast(ushort*)src)[0], 16);
                    g = Bitwise.fixedToFloat((cast(ushort*)src)[1], 16);
                    b = Bitwise.fixedToFloat((cast(ushort*)src)[2], 16);
                    a = 1.0f;
                    break;
                case PixelFormat.PF_SHORT_RGBA:
                    r = Bitwise.fixedToFloat((cast(ushort*)src)[0], 16);
                    g = Bitwise.fixedToFloat((cast(ushort*)src)[1], 16);
                    b = Bitwise.fixedToFloat((cast(ushort*)src)[2], 16);
                    a = Bitwise.fixedToFloat((cast(ushort*)src)[3], 16);
                    break;
                case PixelFormat.PF_BYTE_LA:
                    r = g = b = Bitwise.fixedToFloat((cast(ubyte*)src)[0], 8);
                    a = Bitwise.fixedToFloat((cast(ubyte*)src)[1], 8);
                    break;
                default:
                    // Not yet supported
                    throw new NotImplementedError(
                        "unpack from "~getFormatName(pf)~" not implemented",
                        "PixelUtil.unpackColour");
                    break;
            }
        }
    }
    
    /** Convert consecutive pixels from one format to another. No dithering or filtering is being done. 
     Converting from RGB to luminance takes the R channel.  In case the source and destination format match,
     just a copy is done.
     @param  src         Pointer to source region
     @param  srcFormat   Pixel format of source region
     @param  dst         Pointer to destination region
     @param  dstFormat   Pixel format of destination region
     */
    static void bulkPixelConversion(void *srcp, PixelFormat srcFormat, void *destp, PixelFormat dstFormat, uint count)
    {
        auto src = new PixelBox(count, 1, 1, srcFormat, srcp);
        auto dst = new PixelBox(count, 1, 1, dstFormat, destp);
        
        bulkPixelConversion(src, dst);
    }
    
    /** Convert pixels from one format to another. No dithering or filtering is being done. Converting
     from RGB to luminance takes the R channel. 
     @param  src         PixelBox containing the source pixels, pitches and format
     @param  dst         PixelBox containing the destination pixels, pitches and format
     @remarks The source and destination boxes must have the same
     dimensions. In case the source and destination format match, a plain copy is done.
     */
    static void bulkPixelConversion(PixelBox src, ref PixelBox dst)
    {
        assert(src.getWidth() == dst.getWidth() &&
               src.getHeight() == dst.getHeight() &&
               src.getDepth() == dst.getDepth());

        // Check for compressed formats, we don't support decompression, compression or recoding
        if(PixelUtil.isCompressed(src.format) || PixelUtil.isCompressed(dst.format))
        {
            if(src.format == dst.format)
            {
                memcpy(dst.data, src.data, src.getConsecutiveSize());
                return;
            }
            else
            {
                throw new NotImplementedError(
                    "This method can not be used to compress or decompress images",
                    "PixelUtil.bulkPixelConversion");
            }
        }
        
        // The easy case
        if(src.format == dst.format) {
            // Everything consecutive?
            if(src.isConsecutive() && dst.isConsecutive())
            {
                memcpy(dst.data, src.data, src.getConsecutiveSize());
                return;
            }
            
            size_t srcPixelSize = PixelUtil.getNumElemBytes(src.format);
            size_t dstPixelSize = PixelUtil.getNumElemBytes(dst.format);
            ubyte *srcptr = cast(ubyte*)(src.data)
                + (src.left + src.top * src.rowPitch + src.front * src.slicePitch) * srcPixelSize;
            ubyte *dstptr = cast(ubyte*)(dst.data)
                + (dst.left + dst.top * dst.rowPitch + dst.front * dst.slicePitch) * dstPixelSize;
            
            // Calculate pitches+skips in bytes
            size_t srcRowPitchBytes = src.rowPitch*srcPixelSize;
            //size_t srcRowSkipBytes = src.getRowSkip()*srcPixelSize;
            size_t srcSliceSkipBytes = src.getSliceSkip()*srcPixelSize;
            
            size_t dstRowPitchBytes = dst.rowPitch*dstPixelSize;
            //size_t dstRowSkipBytes = dst.getRowSkip()*dstPixelSize;
            size_t dstSliceSkipBytes = dst.getSliceSkip()*dstPixelSize;
            
            // Otherwise, copy per row
            size_t rowSize = src.getWidth()*srcPixelSize;
            for(size_t z=src.front; z<src.back; z++)
            {
                for(size_t y=src.top; y<src.bottom; y++)
                {
                    memcpy(dstptr, srcptr, rowSize);
                    srcptr += srcRowPitchBytes;
                    dstptr += dstRowPitchBytes;
                }
                srcptr += srcSliceSkipBytes;
                dstptr += dstSliceSkipBytes;
            }
            return;
        }
        // Converting to PF_X8R8G8B8 is exactly the same as converting to
        // PF_A8R8G8B8. (same with PF_X8B8G8R8 and PF_A8B8G8R8)
        if(dst.format == PixelFormat.PF_X8R8G8B8 || dst.format == PixelFormat.PF_X8B8G8R8)
        {
            // Do the same conversion, with PF_A8R8G8B8, which has a lot of
            // optimized conversions
            PixelBox tempdst = dst;
            tempdst.format = dst.format==PixelFormat.PF_X8R8G8B8?PixelFormat.PF_A8R8G8B8:PixelFormat.PF_A8B8G8R8;
            bulkPixelConversion(src, tempdst);
            return;
        }
        // Converting from PF_X8R8G8B8 is exactly the same as converting from
        // PF_A8R8G8B8, given that the destination format does not have alpha.
        if((src.format == PixelFormat.PF_X8R8G8B8||src.format == PixelFormat.PF_X8B8G8R8) && !hasAlpha(dst.format))
        {
            // Do the same conversion, with PF_A8R8G8B8, which has a lot of
            // optimized conversions
            PixelBox tempsrc = cast(PixelBox)src;//TODO Temp copy?
            tempsrc.format = src.format==PixelFormat.PF_X8R8G8B8?PixelFormat.PF_A8R8G8B8:PixelFormat.PF_A8B8G8R8;
            bulkPixelConversion(tempsrc, dst);
            return;
        }
        
        // NB VC6 can't handle the templates required for optimised conversion, tough
        /*#if OGRE_COMPILER != OGRE_COMPILER_MSVC || OGRE_COMP_VER >= 1300
         // Is there a specialized, inlined, conversion?
         if(doOptimizedConversion(src, dst))
         {
         // If so, good
         return;
         }
         #endif*/

        size_t srcPixelSize = getNumElemBytes(src.format);
        size_t dstPixelSize = getNumElemBytes(dst.format);
        ubyte *srcptr = cast(ubyte*)(src.data)
            + (src.left + src.top * src.rowPitch + src.front * src.slicePitch) * srcPixelSize;
        ubyte *dstptr = cast(ubyte*)(dst.data)
            + (dst.left + dst.top * dst.rowPitch + dst.front * dst.slicePitch) * dstPixelSize;
        
        // Old way, not taking into account box dimensions
        //ubyte *srcptr = cast(ubyte*)(src.data), *dstptr = cast(ubyte*)(dst.data);
        
        // Calculate pitches+skips in bytes
        size_t srcRowSkipBytes = src.getRowSkip()*srcPixelSize;
        size_t srcSliceSkipBytes = src.getSliceSkip()*srcPixelSize;
        size_t dstRowSkipBytes = dst.getRowSkip()*dstPixelSize;
        size_t dstSliceSkipBytes = dst.getSliceSkip()*dstPixelSize;
        
        // The brute force fallback
        float r = 0, g = 0, b = 0, a = 1;
        for(size_t z=src.front; z<src.back; z++)
        {
            for(size_t y=src.top; y<src.bottom; y++)
            {
                for(size_t x=src.left; x<src.right; x++)
                {
                    unpackColour(r, g, b, a, src.format, srcptr);
                    packColour(r, g, b, a, dst.format, dstptr);
                    srcptr += srcPixelSize;
                    dstptr += dstPixelSize;
                }
                srcptr += srcRowSkipBytes;
                dstptr += dstRowSkipBytes;
            }
            srcptr += srcSliceSkipBytes;
            dstptr += dstSliceSkipBytes;
        }
    }
}


enum ImageFlags
{
    IF_COMPRESSED = 0x00000001,
    IF_CUBEMAP    = 0x00000002,
    IF_3D_TEXTURE = 0x00000004
}
/** Class representing an image file.
 @remarks
 The Image class usually holds uncompressed image data and is the
 only object that can be loaded in a texture. Image  objects handle 
 image data decoding themselves by the means of locating the correct 
 Codec object for each data type.
 @par
 Typically, you would want to use an Image object to load a texture
 when extra processing needs to be done on an image before it is
 loaded or when you want to blit to an existing texture.
 */
class Image //: public ImageAlloc
{
public:
    //typedef Ogre::Box Box;
    //typedef Ogre::Rect Rect;
    alias ogre.general.common.Box Box;
    alias ogre.general.common.Rect Rect;
public:
    /** Standard constructor.
     */
    this()
    {
        mWidth = 0;
        mHeight = 0;
        mDepth = 0;
        mBufSize = 0;
        mNumMipmaps = 0;
        mFlags = 0;
        mFormat = PixelFormat.PF_UNKNOWN;
        mBuffer = null;
        mAutoDelete = true;
    }
    /** Copy-constructor - copies all the data from the target image.
     */
    this( /*const*/ Image img )
    {
        mBuffer = null;
        mAutoDelete = true;
        // call assignment operator
        copyFrom(img);
    }
    
    /** Standard destructor.
     */
    ~this()
    {
        freeMemory();
    }
    
    /** Assignment operator - copies all the data from the target image.
     */
    //Image & operator = (Image & img );
    ref Image copyFrom( /*const*/ Image img)
    {
        freeMemory();
        mWidth = img.mWidth;
        mHeight = img.mHeight;
        mDepth = img.mDepth;
        mFormat = img.mFormat;
        mBufSize = img.mBufSize;
        mFlags = img.mFlags;
        mPixelSize = img.mPixelSize;
        mNumMipmaps = img.mNumMipmaps;
        mAutoDelete = img.mAutoDelete;
        //Only create/copy when previous data was not dynamic data
        if( mAutoDelete )
        {
            mBuffer = new ubyte[mBufSize];
            memcpy( mBuffer.ptr, img.mBuffer.ptr, mBufSize );
        }
        else
        {
            mBuffer = cast(ubyte[])img.mBuffer;
            img.mBuffer = null;
        }
        
        return this;
    }
    
    /** Flips (mirrors) the image around the Y-axis. 
     @remarks
     An example of an original and flipped image:
     <pre>                
     originalimg
     00000000000
     00000000000
     00000000000
     00000000000
     00000000000
     -----------. flip axis
     00000000000
     00000000000
     00000000000
     00000000000
     00000000000
     originalimg
     </pre>
     */
    ref Image flipAroundY()
    {
        if( !mBuffer )
        {
            throw new InternalError(
                "Can not flip an unitialized texture",
                "Image.flipAroundY" );
        }
        
        mNumMipmaps = 0; // Image operations lose precomputed mipmaps
        
        ubyte[]  pTempBuffer1;
        ushort[] pTempBuffer2;
        ubyte[]  pTempBuffer3;
        uint[]   pTempBuffer4;
        
        ubyte*   src1 = cast(ubyte *)mBuffer.ptr,  dst1 = null;
        ushort*  src2 = cast(ushort *)mBuffer.ptr, dst2 = null;
        ubyte*   src3 = cast(ubyte *)mBuffer.ptr,  dst3 = null;
        uint*    src4 = cast(uint *)mBuffer.ptr,   dst4 = null;
        
        ushort y;
        switch (mPixelSize)
        {
            case 1:
                pTempBuffer1 = new ubyte[mWidth * mHeight];
                for (y = 0; y < mHeight; y++)
                {
                    dst1 = (cast(ubyte *)pTempBuffer1.ptr + ((y * mWidth) + mWidth - 1));
                    for (ushort x = 0; x < mWidth; x++)
                        memcpy(dst1--, src1++, ubyte.sizeof);
                }
                
                memcpy(mBuffer.ptr, pTempBuffer1.ptr, mWidth * mHeight * ubyte.sizeof);
                destroy(pTempBuffer1);
                break;
                
            case 2:
                pTempBuffer2 = new ushort[mWidth * mHeight];
                for (y = 0; y < mHeight; y++)
                {
                    dst2 = (cast(ushort *)pTempBuffer2.ptr + ((y * mWidth) + mWidth - 1));
                    for (ushort x = 0; x < mWidth; x++)
                        memcpy(dst2--, src2++, ushort.sizeof);
                }
                
                memcpy(mBuffer.ptr, pTempBuffer2.ptr, mWidth * mHeight * ushort.sizeof);
                destroy(pTempBuffer2);
                break;
                
            case 3:
                pTempBuffer3 = new ubyte[mWidth * mHeight * 3];
                for (y = 0; y < mHeight; y++)
                {
                    size_t offset = ((y * mWidth) + (mWidth - 1)) * 3;
                    dst3 = cast(ubyte *)pTempBuffer3.ptr;
                    dst3 += offset;
                    for (size_t x = 0; x < mWidth; x++)
                    {
                        memcpy(dst3, src3, ubyte.sizeof * 3);
                        dst3 -= 3; src3 += 3;
                    }
                }
                
                memcpy(mBuffer.ptr, pTempBuffer3.ptr, mWidth * mHeight * ubyte.sizeof * 3);
                destroy(pTempBuffer3);
                break;
                
            case 4:
                pTempBuffer4 = new uint[mWidth * mHeight];
                for (y = 0; y < mHeight; y++)
                {
                    dst4 = (cast(uint *)pTempBuffer4.ptr + ((y * mWidth) + mWidth - 1));
                    for (ushort x = 0; x < mWidth; x++)
                        memcpy(dst4--, src4++, uint.sizeof);
                }
                
                memcpy(mBuffer.ptr, pTempBuffer4.ptr, mWidth * mHeight * uint.sizeof);
                destroy(pTempBuffer4);
                break;
                
            default:
                throw new InternalError(
                    "Unknown pixel depth",
                    "Image.flipAroundY" );
                break;
        }
        
        return this;
        
    }
    
    /** Flips (mirrors) the image around the X-axis.
     @remarks
     An example of an original and flipped image:
     <pre>
     flip axis
     |
     originalimg|gmilanigiro
     00000000000|00000000000
     00000000000|00000000000
     00000000000|00000000000
     00000000000|00000000000
     00000000000|00000000000
     </pre>
     */                 
    ref Image flipAroundX()
    {
        if( !mBuffer )
        {
            throw new InternalError(
                "Can not flip an unitialized texture",
                "Image.flipAroundX" );
        }
        
        mNumMipmaps = 0; // Image operations lose precomputed mipmaps
        
        size_t rowSpan = mWidth * mPixelSize;
        
        ubyte []pTempBuffer = new ubyte[rowSpan * mHeight];
        ubyte *ptr1 = mBuffer.ptr, ptr2 = pTempBuffer.ptr + ( ( mHeight - 1 ) * rowSpan );
        
        for( ushort i = 0; i < mHeight; i++ )
        {
            memcpy( ptr2, ptr1, rowSpan );
            ptr1 += rowSpan; ptr2 -= rowSpan;
        }
        
        memcpy( mBuffer.ptr, pTempBuffer.ptr, rowSpan * mHeight);
        
        destroy(pTempBuffer);
        
        return this;
    }
    
    /** Stores a pointer to raw data in memory. The pixel format has to be specified.
     @remarks
     This method loads an image into memory held in the object. The 
     pixel format will be either greyscale or RGB with an optional
     Alpha component.
     The type can be determined by calling getFormat().             
     @note
     Whilst typically your image is likely to be a simple 2D image,
     you can define complex images including cube maps, volume maps,
     and images including custom mip levels. The layout of the 
     internal memory should be:
     <ul><li>face 0, mip 0 (top), width x height (x depth)</li>
     <li>face 0, mip 1, width/2 x height/2 (x depth/2)</li>
     <li>face 0, mip 2, width/4 x height/4 (x depth/4)</li>
     <li>.. remaining mips for face 0 .. </li>
     <li>face 1, mip 0 (top), width x height (x depth)</li
     <li>.. and so on. </li>
     </ul>
     Of course, you will never have multiple faces (cube map) and
     depth too.
     @param data
     The data pointer
     @param width
     Width of image
     @param height
     Height of image
     @param depth
     Image Depth (in 3d images, numbers of layers, otherwise 1)
     @param format
     Pixel Format
     @param autoDelete
     If memory associated with this buffer is to be destroyed
     with the Image object. Note: it's important that if you set
     this option to true, that you allocated the memory using OGRE_ALLOC_T
     with a category of MEMCATEGORY_GENERAL to ensure the freeing of memory 
     matches up.
     @param numFaces
     The number of faces the image data has inside (6 for cubemaps, 1 otherwise)
     @param numMipMaps
     The number of mipmaps the image data has inside
     @note
     The memory associated with this buffer is NOT destroyed with the
     Image object, unless autoDelete is set to true.
     @remarks 
     The size of the buffer must be numFaces*PixelUtil.getMemorySize(width, height, depth, format)
     */
    ref Image loadDynamicImage( ubyte[] data, size_t width, size_t height, 
                               size_t depth,
                               PixelFormat format, bool autoDelete = false, 
                               size_t numFaces = 1, size_t numMipMaps = 0)
    {
        
        freeMemory();
        // Set image metadata
        mWidth = width;
        mHeight = height;
        mDepth = depth;
        mFormat = format;
        mPixelSize = cast(ubyte)(PixelUtil.getNumElemBytes( mFormat ));
        mNumMipmaps = numMipMaps;
        mFlags = 0;
        // Set flags
        if (PixelUtil.isCompressed(format))
            mFlags |= ImageFlags.IF_COMPRESSED;
        if (mDepth != 1)
            mFlags |= ImageFlags.IF_3D_TEXTURE;
        if(numFaces == 6)
            mFlags |= ImageFlags.IF_CUBEMAP;
        if(numFaces != 6 && numFaces != 1)
            throw new InvalidParamsError(
                "Number of faces currently must be 6 or 1.", 
                "Image.loadDynamicImage");
        
        mBufSize = calculateSize(numMipMaps, numFaces, width, height, depth, format);
        mBuffer = data;
        mAutoDelete = autoDelete;
        
        return this;
    }
    
    /** Stores a pointer to raw data in memory. The pixel format has to be specified.
     @remarks
     This method loads an image into memory held in the object. The 
     pixel format will be either greyscale or RGB with an optional
     Alpha component.
     The type can be determined by calling getFormat().             
     @note
     Whilst typically your image is likely to be a simple 2D image,
     you can define complex images including cube maps
     and images including custom mip levels. The layout of the 
     internal memory should be:
     <ul><li>face 0, mip 0 (top), width x height</li>
     <li>face 0, mip 1, width/2 x height/2 </li>
     <li>face 0, mip 2, width/4 x height/4 </li>
     <li>.. remaining mips for face 0 .. </li>
     <li>face 1, mip 0 (top), width x height (x depth)</li
     <li>.. and so on. </li>
     </ul>
     Of course, you will never have multiple faces (cube map) and
     depth too.
     @param data
     The data pointer
     @param width
     Width of image
     @param height
     Height of image
     @param format
     Pixel Format
     @note
     The memory associated with this buffer is NOT destroyed with the
     Image object.
     @remarks This function is deprecated; one should really use the
     Image::loadDynamicImage(data, width, height, depth, format, ...) to be compatible
     with future Ogre versions.
     */
    ref Image loadDynamicImage( ubyte[] data, size_t width,
                               size_t height, PixelFormat format)
    {
        return loadDynamicImage(data, width, height, 1, format);
    }
    /** Loads raw data from a stream. See the function
     loadDynamicImage for a description of the parameters.
     @remarks 
     The size of the buffer must be numFaces*PixelUtil.getMemorySize(width, height, depth, format)
     @note
     Whilst typically your image is likely to be a simple 2D image,
     you can define complex images including cube maps
     and images including custom mip levels. The layout of the 
     internal memory should be:
     <ul><li>face 0, mip 0 (top), width x height (x depth)</li>
     <li>face 0, mip 1, width/2 x height/2 (x depth/2)</li>
     <li>face 0, mip 2, width/4 x height/4 (x depth/4)</li>
     <li>.. remaining mips for face 0 .. </li>
     <li>face 1, mip 0 (top), width x height (x depth)</li
     <li>.. and so on. </li>
     </ul>
     Of course, you will never have multiple faces (cube map) and
     depth too.
     */
    ref Image loadRawData( 
                          DataStream stream, 
                          size_t uWidth, size_t uHeight, size_t uDepth,
                          PixelFormat eFormat,
                          size_t numFaces = 1, size_t numMipMaps = 0)
    {
        
        size_t size = calculateSize(numMipMaps, numFaces, uWidth, uHeight, uDepth, eFormat);
        if (size != stream.size())
        {
            throw new InvalidParamsError(
                "Stream size does not match calculated image size", 
                "Image.loadRawData");
        }
        
        ubyte[] buffer;// = new ubyte[size];
        stream.read(buffer, size);
        
        return loadDynamicImage(buffer,
                                uWidth, uHeight, uDepth,
                                eFormat, true, numFaces, numMipMaps);
        
    }
    /** Loads raw data from a stream. The pixel format has to be specified. 
     @remarks This function is deprecated; one should really use the
     Image::loadRawData(stream, width, height, depth, format, ...) to be compatible
     with future Ogre versions.
     @note
     Whilst typically your image is likely to be a simple 2D image,
     you can define complex images including cube maps
     and images including custom mip levels. The layout of the 
     internal memory should be:
     <ul><li>face 0, mip 0 (top), width x height</li>
     <li>face 0, mip 1, width/2 x height/2 </li>
     <li>face 0, mip 2, width/4 x height/4 </li>
     <li>.. remaining mips for face 0 .. </li>
     <li>face 1, mip 0 (top), width x height (x depth)</li
     <li>.. and so on. </li>
     </ul>
     Of course, you will never have multiple faces (cube map) and
     depth too.
     */
    ref Image loadRawData( 
                          DataStream stream, 
                          size_t width, size_t height, 
                          PixelFormat format )
    {
        return loadRawData(stream, width, height, 1, format);
    }
    
    /** Loads an image file.
     @remarks
     This method loads an image into memory. Any format for which 
     an associated ImageCodec is registered can be loaded. 
     This can include complex formats like DDS with embedded custom 
     mipmaps, cube faces and volume textures.
     The type can be determined by calling getFormat().             
     @param
     filename Name of an image file to load.
     @param
     groupName Name of the resource group to search for the image
     @note
     The memory associated with this buffer is destroyed with the
     Image object.
     */
    ref Image load(string filename,string group )
    {
        
        string strExt;
        
        size_t pos = filename.lastIndexOf(".");
        if( pos != -1 && pos < (filename.length - 1))
        {
            strExt = filename[pos+1 .. $];
        }
        
        DataStream encoded = ResourceGroupManager.getSingleton().openResource(filename, group);
        return load(encoded, strExt);
        
    }
    
    /** Loads an image file from a stream.
     @remarks
     This method works in the same way as the filename-based load 
     method except it loads the image from a DataStream object. 
     This DataStream is expected to contain the 
     encoded data as it would be held in a file. 
     Any format for which an associated ImageCodec is registered 
     can be loaded. 
     This can include complex formats like DDS with embedded custom 
     mipmaps, cube faces and volume textures.
     The type can be determined by calling getFormat().             
     @param
     stream The source data.
     @param
     type The type of the image. Used to decide what decompression
     codec to use. Can be left blank if the stream data includes
     a header to identify the data.
     @see
     Image::load(string filename )
     */
    ref Image load(DataStream stream, string type = null )
    {
        freeMemory();
        
        Codec pCodec = null;
        if (type !is null)
        {
            // use named codec
            pCodec = Codec.getCodec(type);
        }
        else
        {
            // derive from magic number
            // read the first 32 bytes or file size, if less
            size_t magicLen = std.algorithm.min(stream.size(), 32);
            //ubyte[32] magicBuf;
            ubyte[] magicBuf;
            stream.read(magicBuf, magicLen);
            // return to start
            stream.seek(0);
            pCodec = Codec.getCodec(magicBuf.ptr, magicLen);
            
            if( !pCodec )
                throw new InvalidParamsError(
                    "Unable to load image: Image format is unknown. Unable to identify codec. " ~
                    "Check it or specify format explicitly.",
                    "Image.load" );
        }
        
        Codec.DecodeResult res = pCodec.decode(stream);
        
        ImageCodec.ImageData pData = cast(ImageCodec.ImageData)res.second;
        
        mWidth = pData.width;
        mHeight = pData.height;
        mDepth = pData.depth;
        mBufSize = pData.size;
        mNumMipmaps = pData.num_mipmaps;
        mFlags = pData.flags;
        
        // Get the format and compute the pixel size
        mFormat = pData.format;
        mPixelSize = cast(ubyte)(PixelUtil.getNumElemBytes( mFormat ));
        // Just use internal buffer of returned memory stream
        mBuffer = res.first.getData();
        // Make sure stream does not delete
        res.first.setFreeOnClose(false);
        // make sure we delete
        mAutoDelete = true;
        
        return this;
    }
    
    /** Utility method to combine 2 separate images into this one, with the first
     image source supplying the RGB channels, and the second image supplying the 
     alpha channel (as luminance or separate alpha). 
     @param rgbFilename Filename of image supplying the RGB channels (any alpha is ignored)
     @param alphaFilename Filename of image supplying the alpha channel. If a luminance image the
     single channel is used directly, if an RGB image then the values are
     converted to greyscale.
     @param groupName The resource group from which to load the images
     @param format The destination format
     */
    ref Image loadTwoImagesAsRGBA(string rgbFilename,string alphaFilename,
                                  string groupName, PixelFormat fmt = PixelFormat.PF_BYTE_RGBA)
    {
        Image rgb = new Image, alpha = new Image;
        
        rgb.load(rgbFilename, groupName);
        alpha.load(alphaFilename, groupName);
        
        return combineTwoImagesAsRGBA(rgb, alpha, fmt);
        
    }
    
    /** Utility method to combine 2 separate images into this one, with the first
     image source supplying the RGB channels, and the second image supplying the 
     alpha channel (as luminance or separate alpha). 
     @param rgbStream Stream of image supplying the RGB channels (any alpha is ignored)
     @param alphaStream Stream of image supplying the alpha channel. If a luminance image the
     single channel is used directly, if an RGB image then the values are
     converted to greyscale.
     @param format The destination format
     @param rgbType The type of the RGB image. Used to decide what decompression
     codec to use. Can be left blank if the stream data includes
     a header to identify the data.
     @param alphaType The type of the alpha image. Used to decide what decompression
     codec to use. Can be left blank if the stream data includes
     a header to identify the data.
     */
    ref Image loadTwoImagesAsRGBA( DataStream rgbStream, ref DataStream alphaStream, PixelFormat fmt = PixelFormat.PF_BYTE_RGBA,
                                  string rgbType = null,string alphaType = null)
    {
        Image rgb = new Image, alpha = new Image;
        
        rgb.load(rgbStream, rgbType);
        alpha.load(alphaStream, alphaType);
        
        return combineTwoImagesAsRGBA(rgb, alpha, fmt);
        
    }
    
    /** Utility method to combine 2 separate images into this one, with the first
     image source supplying the RGB channels, and the second image supplying the 
     alpha channel (as luminance or separate alpha). 
     @param rgb Image supplying the RGB channels (any alpha is ignored)
     @param alpha Image supplying the alpha channel. If a luminance image the
     single channel is used directly, if an RGB image then the values are
     converted to greyscale.
     @param format The destination format
     */
    ref Image combineTwoImagesAsRGBA(Image rgb, ref Image alpha, PixelFormat fmt = PixelFormat.PF_BYTE_RGBA)
    {
        // the images should be the same size, have the same number of mipmaps
        if (rgb.getWidth() != alpha.getWidth() ||
            rgb.getHeight() != alpha.getHeight() ||
            rgb.getDepth() != alpha.getDepth())
        {
            throw new InvalidParamsError(
                "Images must be the same dimensions", "Image.combineTwoImagesAsRGBA");
        }
        if (rgb.getNumMipmaps() != alpha.getNumMipmaps() ||
            rgb.getNumFaces() != alpha.getNumFaces())
        {
            throw new InvalidParamsError(
                "Images must have the same number of surfaces (faces & mipmaps)", 
                "Image.combineTwoImagesAsRGBA");
        }
        // Format check
        if (PixelUtil.getComponentCount(fmt) != 4)
        {
            throw new InvalidParamsError(
                "Target format must have 4 components", 
                "Image.combineTwoImagesAsRGBA");
        }
        if (PixelUtil.isCompressed(fmt) || PixelUtil.isCompressed(rgb.getFormat()) 
            || PixelUtil.isCompressed(alpha.getFormat()))
        {
            throw new InvalidParamsError(
                "Compressed formats are not supported in this method", 
                "Image.combineTwoImagesAsRGBA");
        }
        
        freeMemory();
        
        mWidth = rgb.getWidth();
        mHeight = rgb.getHeight();
        mDepth = rgb.getDepth();
        mFormat = fmt;
        mNumMipmaps = rgb.getNumMipmaps();
        size_t numFaces = rgb.getNumFaces();
        
        // Set flags
        mFlags = 0;
        if (mDepth != 1)
            mFlags |= ImageFlags.IF_3D_TEXTURE;
        if(numFaces == 6)
            mFlags |= ImageFlags.IF_CUBEMAP;
        
        mBufSize = calculateSize(mNumMipmaps, numFaces, mWidth, mHeight, mDepth, mFormat);
        
        mPixelSize = cast(ubyte)(PixelUtil.getNumElemBytes( mFormat ));
        
        mBuffer = new ubyte[mBufSize];
        
        // make sure we delete
        mAutoDelete = true;
        
        
        for (size_t face = 0; face < numFaces; ++face)
        {
            for (size_t mip = 0; mip <= mNumMipmaps; ++mip)
            {
                // convert the RGB first
                PixelBox srcRGB = rgb.getPixelBox(face, mip);
                PixelBox dst = getPixelBox(face, mip);
                PixelUtil.bulkPixelConversion(srcRGB, dst);
                
                // now selectively add the alpha
                PixelBox srcAlpha = alpha.getPixelBox(face, mip);
                ubyte* psrcAlpha = cast(ubyte *)(srcAlpha.data);
                ubyte* pdst = cast(ubyte *)(dst.data);
                for (size_t d = 0; d < mDepth; ++d)
                {
                    for (size_t y = 0; y < mHeight; ++y)
                    {
                        for (size_t x = 0; x < mWidth; ++x)
                        {
                            ColourValue colRGBA, colA;
                            // read RGB back from dest to save having another pointer
                            PixelUtil.unpackColour(colRGBA, mFormat, pdst);
                            PixelUtil.unpackColour(colA, alpha.getFormat(), psrcAlpha);
                            
                            // combine RGB from alpha source texture
                            colRGBA.a = (colA.r + colA.g + colA.b) / 3.0f;
                            
                            PixelUtil.packColour(colRGBA, mFormat, pdst);
                            
                            psrcAlpha += PixelUtil.getNumElemBytes(alpha.getFormat());
                            pdst += PixelUtil.getNumElemBytes(mFormat);
                            
                        }
                    }
                }
                
                
            }
        }
        
        return this;
        
    }
    
    
    /** Save the image as a file. 
     @remarks
     Saving and loading are implemented by back end (sometimes third 
     party) codecs.  Implemented saving functionality is more limited
     than loading in some cases. Particularly DDS file format support 
     is currently limited to true colour or single channel float32, 
     square, power of two textures with no mipmaps.  Volumetric support
     is currently limited to DDS files.
     */
    void save(string filename)
    {
        if( !mBuffer )
        {
            throw new InvalidParamsError( "No image data loaded", 
                                         "Image.save");
        }
        
        size_t pos = filename.lastIndexOf(".");
        if( pos == -1 )
            throw new InvalidParamsError(
                "Unable to save image file '" ~ filename ~ "' - invalid extension.",
                "Image.save" );
        
        //while( pos != filename.length - 1 )
        //    strExt += filename[++pos];
        string strExt = filename[pos+1 .. $];
        
        Codec pCodec = Codec.getCodec(strExt);
        if( !pCodec )
            throw new InvalidParamsError(
                "Unable to save image file '" ~ filename ~ "' - invalid extension.",
                "Image.save" );
        
        ImageCodec.ImageData imgData = new ImageCodec.ImageData();
        imgData.format = mFormat;
        imgData.height = mHeight;
        imgData.width = mWidth;
        imgData.depth = mDepth;
        imgData.size = mBufSize;
        // Wrap in CodecDataPtr, this will delete
        //TODO just plain CodecData in D?
        auto codeDataPtr = cast(Codec.CodecData)imgData;//new Codec.CodecDataPtr(imgData);
        // Wrap memory, be sure not to delete when stream destroyed
        auto wrapper = new MemoryDataStream(mBuffer, false);
        
        pCodec.encodeToFile(wrapper, filename, codeDataPtr);
    }
    
    
    
    /** Encode the image and return a stream to the data. 
     @param formatextension An extension to identify the image format
     to encode into, e.g. "jpg" or "png"
     */
    DataStream encode(string formatextension)
    {
        if( !mBuffer )
        {
            throw new InvalidParamsError("No image data loaded", 
                                         "Image.encode");
        }
        
        Codec pCodec = Codec.getCodec(formatextension);
        if( !pCodec )
            throw new InvalidParamsError(
                "Unable to encode image data as '" ~ formatextension ~ "' - invalid extension.",
                "Image.encode" );
        
        ImageCodec.ImageData imgData = new ImageCodec.ImageData();
        imgData.format = mFormat;
        imgData.height = mHeight;
        imgData.width = mWidth;
        imgData.depth = mDepth;
        // Wrap in CodecDataPtr, this will delete
        //TODO just plain CodecData in D?
        auto codeDataPtr = cast(Codec.CodecData)imgData; //new Codec.CodecDataPtr(imgData);
        // Wrap memory, be sure not to delete when stream destroyed
        auto wrapper = new MemoryDataStream(mBuffer, false);
        
        return pCodec.encode(wrapper, codeDataPtr);
    }
    
    /** Returns a pointer to the internal image buffer.
     @remarks
     Be caref ul with this method. You will almost certainly
     prefer to use getPixelBox, especially with complex images
     which include many faces or custom mipmaps.
     */
    ubyte[] getData()
    {
        return mBuffer;
    }

    /** Returns apointer to the internal image buffer.
     @remarks
     Be caref ul with this method. You will almost certainly
     prefer to use getPixelBox, especially with complex images
     which include many faces or custom mipmaps.
     */
    /*ubyte * getData()
     {
     assert( mBuffer );
     return mBuffer;
     }*/
    
    /** Returns the size of the data buffer.
     */
    size_t getSize() const
    {
        return mBufSize;
    }
    
    /** Returns the number of mipmaps contained in the image.
     */
    size_t getNumMipmaps() const
    {
        return mNumMipmaps;
    }
    
    /** Returns true if the image has the appropriate flag set.
     */
    bool hasFlag(ImageFlags imgFlag)
    {
        if(mFlags & imgFlag)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    
    /** Gets the width of the image in pixels.
     */
    size_t getWidth() const
    {
        return mWidth;
    }
    
    /** Gets the height of the image in pixels.
     */
    size_t getHeight() const
    {
        return mHeight;
    }
    /** Gets the depth of the image.
     */
    size_t getDepth() const
    {
        return mDepth;
    }
    
    /** Get the number of faces of the image. This is usually 6 for a cubemap, and
     1 for a normal image.
     */
    size_t getNumFaces()
    {
        if(hasFlag(ImageFlags.IF_CUBEMAP))
            return 6;
        return 1;
    }
    
    /** Gets the physical width in bytes of each row of pixels.
     */
    size_t getRowSpan() const
    {
        return mWidth * mPixelSize;
    }
    
    /** Returns the image format.
     */
    PixelFormat getFormat() const
    {
        return mFormat;
    }
    
    /** Returns the number of bits per pixel.
     */
    ubyte getBPP() const
    {
        return cast(ubyte)(mPixelSize * 8);
    }
    
    /** Returns true if the image has an alpha component.
     */
    bool getHasAlpha()
    {
        return PixelUtil.getFlags(mFormat) & PixelFormatFlags.PFF_HASALPHA;
    }
    
    /** Does gamma adjustment.
     @note
     Basic algo taken from Titan Engine, copyright (c) 2000 Ignacio 
     Castano Iguado
     */
    static void _applyGamma( ubyte []buffer, Real gamma, size_t size, ubyte bpp )
    {
        applyGamma(buffer.ptr, gamma, size, bpp);
    }

    /** Does gamma adjustment.
     @note
     Basic algo taken from Titan Engine, copyright (c) 2000 Ignacio 
     Castano Iguado
     */
    static void applyGamma( ubyte* buffer, Real gamma, size_t size, ubyte bpp )
    {
        if( gamma == 1.0f )
            return;
        
        //NB only 24/32-bit supported
        if( bpp != 24 && bpp != 32 ) return;
        
        uint stride = bpp >> 3;
        
        ubyte[256] gammaramp;
        Real exponent = 1.0f / gamma;
        for(int i = 0; i < 256; i++) {
            gammaramp[i] = cast(ubyte)(Math.Pow(i/255.0f, exponent)*255+0.5f);
        }
        
        for( size_t i = 0, j = size / stride; i < j; i++, buffer += stride )
        {
            buffer[0] = gammaramp[buffer[0]];
            buffer[1] = gammaramp[buffer[1]];
            buffer[2] = gammaramp[buffer[2]];
        }
    }
    
    /**
     * Get colour value from a certain location in the image. The z coordinate
     * is only valid for cubemaps and volume textures. This uses the first (largest)
     * mipmap.
     */
    ColourValue getColourAt(size_t x, size_t y, size_t z)
    {
        ColourValue rval;
        PixelUtil.unpackColour(rval, mFormat, &(cast(ubyte *)mBuffer.ptr)[mPixelSize * (z * mWidth * mHeight + mWidth * y + x)] );
        return rval;
    }
    
    /**
     * Set colour value at a certain location in the image. The z coordinate
     * is only valid for cubemaps and volume textures. This uses the first (largest)
     * mipmap.
     */
    void setColourAt( ColourValue cv, size_t x, size_t y, size_t z)
    {
        size_t pixelSize = PixelUtil.getNumElemBytes(getFormat());
        PixelUtil.packColour(cv, getFormat(), 
                             &(cast(ubyte *)getData().ptr)[pixelSize * (z * getWidth() * getHeight() + y * getWidth() + x)]);
    }
    
    /**
     * Get a PixelBox encapsulating the image data of a mipmap
     */
    PixelBox getPixelBox(size_t face = 0, size_t mipmap = 0)
    {
        // Image data is arranged as:
        // face 0, top level (mip 0)
        // face 0, mip 1
        // face 0, mip 2
        // face 1, top level (mip 0)
        // face 1, mip 1
        // face 1, mip 2
        // etc
        if(mipmap > getNumMipmaps())
            throw new NotImplementedError(
                "Mipmap index out of range",
                "Image.getPixelBox" ) ;
        if(face >= getNumFaces())
            throw new InvalidParamsError( "Face index out of range",
                                         "Image.getPixelBox");
        // Calculate mipmap offset and size
        ubyte *offset = cast(ubyte *)getData().ptr;
        // Base offset is number of full faces
        size_t width = getWidth(), height=getHeight(), depth=getDepth();
        size_t numMips = getNumMipmaps();
        
        // Figure out the offsets 
        size_t fullFaceSize = 0;
        size_t finalFaceSize = 0;
        size_t finalWidth = 0, finalHeight = 0, finalDepth = 0;
        for(size_t mip=0; mip <= numMips; ++mip)
        {
            if (mip == mipmap)
            {
                finalFaceSize = fullFaceSize;
                finalWidth = width;
                finalHeight = height;
                finalDepth = depth;
            }
            fullFaceSize += PixelUtil.getMemorySize(width, height, depth, getFormat());
            
            /// Half size in each dimension
            if(width!=1) width /= 2;
            if(height!=1) height /= 2;
            if(depth!=1) depth /= 2;
        }
        // Advance pointer by number of full faces, plus mip offset into
        offset += face * fullFaceSize;
        offset += finalFaceSize;
        // Return subface as pixelbox
        auto src = new PixelBox(finalWidth, finalHeight, finalDepth, getFormat(), offset);
        return src;
    }
    
    /// Delete all the memory held by this image, if owned by this image (not dynamic)
    void freeMemory()
    {
        //Only delete if this was not a dynamic image (meaning app holds & destroys buffer)
        if( mBuffer && mAutoDelete )
        {
            destroy(mBuffer);
            mBuffer = null;
        }
        
    }
    
    enum Filter
    {
        FILTER_NEAREST,
        FILTER_LINEAR,
        FILTER_BILINEAR,
        FILTER_BOX,
        FILTER_TRIANGLE,
        FILTER_BICUBIC
    }

    /** Scale a 1D, 2D or 3D image volume. 
     @param  src         PixelBox containing the source pointer, dimensions and format
     @param  dst         PixelBox containing the destination pointer, dimensions and format
     @param  filter      Which filter to use
     @remarks    This function can do pixel format conversion in the process.
     @note   dst and src can point to the same PixelBox object without any problem
     */
    //TODO ref'ing??
    static void scale(/*ref*/PixelBox src, /*ref*/ PixelBox dst, Filter filter = Filter.FILTER_BILINEAR)
    {
        assert(PixelUtil.isAccessible(src.format));
        assert(PixelUtil.isAccessible(dst.format));
        MemoryDataStream buf; // For auto-delete
        PixelBox temp = new PixelBox;
        switch (filter) 
        {
            default:
            case Filter.FILTER_NEAREST:
                if(src.format == dst.format) 
                {
                    // No intermediate buffer needed
                    temp = cast(PixelBox)dst;
                }
                else
                {
                    // Allocate temporary buffer of destination size in source format 
                    temp = new PixelBox(dst.getWidth(), dst.getHeight(), dst.getDepth(), src.format);
                    buf = new MemoryDataStream(temp.getConsecutiveSize());
                    temp.data = buf.getPtr();
                }
                // super-optimized: no conversion
                switch (PixelUtil.getNumElemBytes(src.format)) 
                {
                    case 1: NearestResampler!1.scale(src, temp); break;
                    case 2: NearestResampler!2.scale(src, temp); break;
                    case 3: NearestResampler!3.scale(src, temp); break;
                    case 4: NearestResampler!4.scale(src, temp); break;
                    case 6: NearestResampler!6.scale(src, temp); break;
                    case 8: NearestResampler!8.scale(src, temp); break;
                    case 12: NearestResampler!12.scale(src, temp); break;
                    case 16: NearestResampler!16.scale(src, temp); break;
                    default:
                        // never reached
                        assert(false);
                }
                if(temp.data != dst.data)
                {
                    // Blit temp buffer
                    PixelUtil.bulkPixelConversion(temp, dst);
                }
                break;
                
            case Filter.FILTER_LINEAR:
            case Filter.FILTER_BILINEAR:
                switch (src.format) 
                {
                    case PixelFormat.PF_L8: case PixelFormat.PF_A8: case PixelFormat.PF_BYTE_LA:
                    case PixelFormat.PF_R8G8B8: case PixelFormat.PF_B8G8R8:
                    case PixelFormat.PF_R8G8B8A8: case PixelFormat.PF_B8G8R8A8:
                    case PixelFormat.PF_A8B8G8R8: case PixelFormat.PF_A8R8G8B8:
                    case PixelFormat.PF_X8B8G8R8: case PixelFormat.PF_X8R8G8B8:
                        if(src.format == dst.format) 
                        {
                            // No intermediate buffer needed
                            temp = dst;
                        }
                        else
                        {
                            // Allocate temp buffer of destination size in source format 
                            temp = new PixelBox(dst.getWidth(), dst.getHeight(), dst.getDepth(), src.format);
                            buf = new MemoryDataStream(temp.getConsecutiveSize());
                            temp.data = buf.getPtr();
                        }
                        // super-optimized: byte-oriented math, no conversion
                        switch (PixelUtil.getNumElemBytes(src.format)) 
                        {
                            case 1: LinearResampler_Byte!1.scale(src, temp); break;
                            case 2: LinearResampler_Byte!2.scale(src, temp); break;
                            case 3: LinearResampler_Byte!3.scale(src, temp); break;
                            case 4: LinearResampler_Byte!4.scale(src, temp); break;
                            default:
                                // never reached
                                assert(false);
                        }
                        if(temp.data != dst.data)
                        {
                            // Blit temp buffer
                            PixelUtil.bulkPixelConversion(temp, dst);
                        }
                        break;
                    case PixelFormat.PF_FLOAT32_RGB:
                    case PixelFormat.PF_FLOAT32_RGBA:
                        if (dst.format == PixelFormat.PF_FLOAT32_RGB || 
                            dst.format == PixelFormat.PF_FLOAT32_RGBA)
                        {
                            // float32 to float32, avoid unpack/repack overhead
                            LinearResampler_Float32.scale(src, dst);
                            break;
                        }
                        // else, fall through
                    default:
                        // non-optimized: floating-point math, performs conversion but always works
                        LinearResampler.scale(src, dst);
                }
                break;
        }
    }
    
    /** Resize a 2D image, applying the appropriate filter. */
    void resize(ushort width, ushort height, Filter filter = Filter.FILTER_BILINEAR)
    {
        // resizing dynamic images is not supported
        assert(mAutoDelete);
        assert(mDepth == 1);
        
        // reassign buffer to temp image, make sure auto-delete is true
        Image temp = new Image;
        temp.loadDynamicImage(mBuffer, mWidth, mHeight, 1, mFormat, true);
        // do not delete[] mBuffer!  temp will destroy it
        
        // set new dimensions, allocate new buffer
        mWidth = width;
        mHeight = height;
        mBufSize = PixelUtil.getMemorySize(mWidth, mHeight, 1, mFormat);
        mBuffer = new ubyte[mBufSize];
        mNumMipmaps = 0; // Loses precomputed mipmaps
        
        // scale the image from temp into our resized buffer
        Image.scale(temp.getPixelBox(), getPixelBox(), filter);
    }
    
    // Static function to calculate size in bytes from the number of mipmaps, faces and the dimensions
    static size_t calculateSize(size_t mipmaps, size_t faces, size_t width, size_t height, size_t depth, PixelFormat format)
    {
        size_t size = 0;
        for(size_t mip=0; mip<=mipmaps; ++mip)
        {
            size += PixelUtil.getMemorySize(width, height, depth, format)*faces; 
            if(width!=1) width /= 2;
            if(height!=1) height /= 2;
            if(depth!=1) depth /= 2;
        }
        return size;
    }
    
    /// Static function to get an image type string from a stream via magic numbers
    static string getFileExtFromMagic(DataStream stream)
    {
        // read the first 32 bytes or file size, if less
        size_t magicLen = std.algorithm.min(stream.size(), 32);
        ubyte[/*32*/] magicBuf;
        stream.read(magicBuf, magicLen);
        // return to start
        stream.seek(0);
        Codec pCodec = Codec.getCodec(magicBuf/*, magicLen*/);
        
        if(pCodec)
            return pCodec.getType();
        else
            return null;
    }
    
protected:
    // The width of the image in pixels
    size_t mWidth;
    // The height of the image in pixels
    size_t mHeight;
    // The depth of the image
    size_t mDepth;
    // The size of the image buffer
    size_t mBufSize;
    // The number of mipmaps the image contains
    size_t mNumMipmaps;
    // Image specific flags.
    int mFlags;
    
    // The pixel format of the image
    PixelFormat mFormat;
    
    // The number of bytes per pixel
    ubyte mPixelSize;
    ubyte[] mBuffer;
    
    // A bool to determine if we delete the buffer or the calling app does
    bool mAutoDelete;
}

//typedef vector<Image*>::type ImagePtrList;
//typedef vector<Image*>::type ConstImagePtrList;

alias Image*[] ImagePtrList;
//alias Array!(Image) ConstImagePtrList;

/** Codec specialized in images.
 @remarks
 The users implementing subclasses of ImageCodec are required to return
 a valid pointer to a ImageData class from the decode(...) function.
 */
class ImageCodec : Codec
{
public:
    ~this() {}
    
    /** Codec return class for images. Has information about the size and the
     pixel format of the image. */
    static class ImageData : Codec.CodecData
    {
    public:
        this()
        {
            height = 0;
            width = 0;
            depth = 1;
            size = 0;
            num_mipmaps = 0;
            flags = 0;
            format = PixelFormat.PF_UNKNOWN;
        }
        size_t height;
        size_t width;
        size_t depth;
        size_t size;
        
        ushort num_mipmaps;
        uint flags;
        
        PixelFormat format;
        
    public:
        override string dataType()
        {
            return "ImageData";
        }
    }
    
public:
    override string getDataType()
    {
        return "ImageData";
    }
}



// variable name hints:
// sx_48 = 16/48-bit fixed-point x-position in source
// stepx = difference between adjacent sx_48 values
// sx1 = lower-bound integer x-position in source
// sx2 = upper-bound integer x-position in source
// sxf = fractional weight between sx1 and sx2
// x,y,z = location of output pixel in destination

// nearest-neighbor resampler, does not convert formats.
// templated on bytes-per-pixel to allow compiler optimizations, such
// as simplifying memcpy() and replacing multiplies with bitshifts
struct NearestResampler(uint elemsize) {
    static void scale(PixelBox src,PixelBox dst) {
        // assert(src.format == dst.format);
        
        // srcdata stays at beginning, pdst is a moving pointer
        ubyte* srcdata = cast(ubyte*)src.data;
        ubyte* pdst = cast(ubyte*)dst.data;
        
        // sx_48,sy_48,sz_48 represent current position in source
        // using 16/48-bit fixed precision, incremented by steps
        uint64 stepx = (cast(uint64)src.getWidth() << 48) / dst.getWidth();
        uint64 stepy = (cast(uint64)src.getHeight() << 48) / dst.getHeight();
        uint64 stepz = (cast(uint64)src.getDepth() << 48) / dst.getDepth();
        
        // note: ((stepz>>1) - 1) is an extra half-step increment to adjust
        // for the center of the destination pixel, not the top-left corner
        uint64 sz_48 = (stepz >> 1) - 1;
        for (size_t z = dst.front; z < dst.back; z++, sz_48 += stepz) {
            size_t srczoff = cast(size_t)(sz_48 >> 48) * src.slicePitch;
            
            uint64 sy_48 = (stepy >> 1) - 1;
            for (size_t y = dst.top; y < dst.bottom; y++, sy_48 += stepy) {
                size_t srcyoff = cast(size_t)(sy_48 >> 48) * src.rowPitch;
                
                uint64 sx_48 = (stepx >> 1) - 1;
                for (size_t x = dst.left; x < dst.right; x++, sx_48 += stepx) {
                    ubyte* psrc = srcdata +
                        elemsize*(cast(size_t)(sx_48 >> 48) + srcyoff + srczoff);
                    memcpy(pdst, psrc, elemsize);
                    pdst += elemsize;
                }
                pdst += elemsize*dst.getRowSkip();
            }
            pdst += elemsize*dst.getSliceSkip();
        }
    }
};


// default floating-point linear resampler, does format conversion
struct LinearResampler {
    static void scale(PixelBox src,PixelBox dst) {
        size_t srcelemsize = PixelUtil.getNumElemBytes(src.format);
        size_t dstelemsize = PixelUtil.getNumElemBytes(dst.format);
        
        // srcdata stays at beginning, pdst is a moving pointer
        ubyte* srcdata = cast(ubyte*)src.data;
        ubyte* pdst = cast(ubyte*)dst.data;
        
        // sx_48,sy_48,sz_48 represent current position in source
        // using 16/48-bit fixed precision, incremented by steps
        uint64 stepx = (cast(uint64)src.getWidth() << 48) / dst.getWidth();
        uint64 stepy = (cast(uint64)src.getHeight() << 48) / dst.getHeight();
        uint64 stepz = (cast(uint64)src.getDepth() << 48) / dst.getDepth();
        
        // temp is 16/16 bit fixed precision, used to adjust a source
        // coordinate (x, y, or z) backwards by half a pixel so that the
        // integer bits represent the first sample (eg, sx1) and the
        // fractional bits are the blend weight of the second sample
        uint temp;
        
        // note: ((stepz>>1) - 1) is an extra half-step increment to adjust
        // for the center of the destination pixel, not the top-left corner
        uint64 sz_48 = (stepz >> 1) - 1;
        for (size_t z = dst.front; z < dst.back; z++, sz_48+=stepz) {
            temp = cast(uint)(sz_48 >> 32);
            temp = (temp > 0x8000)? temp - 0x8000 : 0;
            size_t sz1 = temp >> 16;                 // src z, sample #1
            size_t sz2 = std.algorithm.min(sz1+1,src.getDepth()-1);// src z, sample #2
            float szf = (temp & 0xFFFF) / 65536f; // weight of sample #2
            
            uint64 sy_48 = (stepy >> 1) - 1;
            for (size_t y = dst.top; y < dst.bottom; y++, sy_48+=stepy) {
                temp = cast(uint)(sy_48 >> 32);
                temp = (temp > 0x8000)? temp - 0x8000 : 0;
                size_t sy1 = temp >> 16;                    // src y #1
                size_t sy2 = std.algorithm.min(sy1+1,src.getHeight()-1);// src y #2
                float syf = (temp & 0xFFFF) / 65536f; // weight of #2
                
                uint64 sx_48 = (stepx >> 1) - 1;
                for (size_t x = dst.left; x < dst.right; x++, sx_48+=stepx) {
                    temp = cast(uint)(sx_48 >> 32);
                    temp = (temp > 0x8000)? temp - 0x8000 : 0;
                    size_t sx1 = temp >> 16;                    // src x #1
                    size_t sx2 = std.algorithm.min(sx1+1,src.getWidth()-1);// src x #2
                    float sxf = (temp & 0xFFFF) / 65536f; // weight of #2
                    
                    ColourValue x1y1z1, x2y1z1, x1y2z1, x2y2z1;
                    ColourValue x1y1z2, x2y1z2, x1y2z2, x2y2z2;
                    
                    void UNPACK( ColourValue dst, size_t x, size_t y, size_t z)
                    {
                        PixelUtil.unpackColour(dst, src.format,
                                               srcdata + srcelemsize*((x)+(y)*src.rowPitch+(z)*src.slicePitch));
                    }
                    
                    UNPACK(x1y1z1,sx1,sy1,sz1); UNPACK(x2y1z1,sx2,sy1,sz1);
                    UNPACK(x1y2z1,sx1,sy2,sz1); UNPACK(x2y2z1,sx2,sy2,sz1);
                    UNPACK(x1y1z2,sx1,sy1,sz2); UNPACK(x2y1z2,sx2,sy1,sz2);
                    UNPACK(x1y2z2,sx1,sy2,sz2); UNPACK(x2y2z2,sx2,sy2,sz2);
                    
                    ColourValue accum =
                        x1y1z1 * ((1.0f - sxf)*(1.0f - syf)*(1.0f - szf)) +
                            x2y1z1 * (        sxf *(1.0f - syf)*(1.0f - szf)) +
                            x1y2z1 * ((1.0f - sxf)*        syf *(1.0f - szf)) +
                            x2y2z1 * (        sxf *        syf *(1.0f - szf)) +
                            x1y1z2 * ((1.0f - sxf)*(1.0f - syf)*        szf ) +
                            x2y1z2 * (        sxf *(1.0f - syf)*        szf ) +
                            x1y2z2 * ((1.0f - sxf)*        syf *        szf ) +
                            x2y2z2 * (        sxf *        syf *        szf );
                    
                    PixelUtil.packColour(accum, dst.format, pdst);
                    
                    pdst += dstelemsize;
                }
                pdst += dstelemsize*dst.getRowSkip();
            }
            pdst += dstelemsize*dst.getSliceSkip();
        }
    }
};


// float32 linear resampler, converts FLOAT32_RGB/FLOAT32_RGBA only.
// avoids overhead of pixel unpack/repack function calls
struct LinearResampler_Float32 {
    static void scale(PixelBox src,PixelBox dst) {
        size_t srcchannels = PixelUtil.getNumElemBytes(src.format) / float.sizeof;
        size_t dstchannels = PixelUtil.getNumElemBytes(dst.format) / float.sizeof;
        // assert(srcchannels == 3 || srcchannels == 4);
        // assert(dstchannels == 3 || dstchannels == 4);
        
        // srcdata stays at beginning, pdst is a moving pointer
        float* srcdata = cast(float*)src.data;
        float* pdst = cast(float*)dst.data;
        
        // sx_48,sy_48,sz_48 represent current position in source
        // using 16/48-bit fixed precision, incremented by steps
        uint64 stepx = (cast(uint64)src.getWidth() << 48) / dst.getWidth();
        uint64 stepy = (cast(uint64)src.getHeight() << 48) / dst.getHeight();
        uint64 stepz = (cast(uint64)src.getDepth() << 48) / dst.getDepth();
        
        // temp is 16/16 bit fixed precision, used to adjust a source
        // coordinate (x, y, or z) backwards by half a pixel so that the
        // integer bits represent the first sample (eg, sx1) and the
        // fractional bits are the blend weight of the second sample
        uint temp;
        
        // note: ((stepz>>1) - 1) is an extra half-step increment to adjust
        // for the center of the destination pixel, not the top-left corner
        uint64 sz_48 = (stepz >> 1) - 1;
        for (size_t z = dst.front; z < dst.back; z++, sz_48+=stepz) {
            temp = cast(uint)(sz_48 >> 32);
            temp = (temp > 0x8000)? temp - 0x8000 : 0;
            size_t sz1 = temp >> 16;                 // src z, sample #1
            size_t sz2 = std.algorithm.min(sz1+1,src.getDepth()-1);// src z, sample #2
            float szf = (temp & 0xFFFF) / 65536f; // weight of sample #2
            
            uint64 sy_48 = (stepy >> 1) - 1;
            for (size_t y = dst.top; y < dst.bottom; y++, sy_48+=stepy) {
                temp = cast(uint)(sy_48 >> 32);
                temp = (temp > 0x8000)? temp - 0x8000 : 0;
                size_t sy1 = temp >> 16;                    // src y #1
                size_t sy2 = std.algorithm.min(sy1+1,src.getHeight()-1);// src y #2
                float syf = (temp & 0xFFFF) / 65536f; // weight of #2
                
                uint64 sx_48 = (stepx >> 1) - 1;
                for (size_t x = dst.left; x < dst.right; x++, sx_48+=stepx) {
                    temp = cast(uint)(sx_48 >> 32);
                    temp = (temp > 0x8000)? temp - 0x8000 : 0;
                    size_t sx1 = temp >> 16;                    // src x #1
                    size_t sx2 = std.algorithm.min(sx1+1,src.getWidth()-1);// src x #2
                    float sxf = (temp & 0xFFFF) / 65536f; // weight of #2
                    
                    // process R,G,B,A simultaneously for cache coherence?
                    float[4] accum = [ 0.0f, 0.0f, 0.0f, 0.0f];
                    
                    void ACCUM3(size_t x, size_t y, size_t z, float factor)
                    { 
                        float f = factor; 
                        size_t off = (x+y*src.rowPitch+z*src.slicePitch)*srcchannels; 
                        accum[0]+=srcdata[off+0]*f; accum[1]+=srcdata[off+1]*f; 
                        accum[2]+=srcdata[off+2]*f; 
                    }
                    
                    void ACCUM4(size_t x, size_t y, size_t z, float factor) 
                    {
                        float f = factor; 
                        size_t off = (x+y*src.rowPitch+z*src.slicePitch)*srcchannels; 
                        accum[0]+=srcdata[off+0]*f; accum[1]+=srcdata[off+1]*f; 
                        accum[2]+=srcdata[off+2]*f; accum[3]+=srcdata[off+3]*f; 
                    }
                    
                    if (srcchannels == 3 || dstchannels == 3) {
                        // RGB, no alpha
                        ACCUM3(sx1,sy1,sz1,(1.0f-sxf)*(1.0f-syf)*(1.0f-szf));
                        ACCUM3(sx2,sy1,sz1,      sxf *(1.0f-syf)*(1.0f-szf));
                        ACCUM3(sx1,sy2,sz1,(1.0f-sxf)*      syf *(1.0f-szf));
                        ACCUM3(sx2,sy2,sz1,      sxf *      syf *(1.0f-szf));
                        ACCUM3(sx1,sy1,sz2,(1.0f-sxf)*(1.0f-syf)*      szf );
                        ACCUM3(sx2,sy1,sz2,      sxf *(1.0f-syf)*      szf );
                        ACCUM3(sx1,sy2,sz2,(1.0f-sxf)*      syf *      szf );
                        ACCUM3(sx2,sy2,sz2,      sxf *      syf *      szf );
                        accum[3] = 1.0f;
                    } else {
                        // RGBA
                        ACCUM4(sx1,sy1,sz1,(1.0f-sxf)*(1.0f-syf)*(1.0f-szf));
                        ACCUM4(sx2,sy1,sz1,      sxf *(1.0f-syf)*(1.0f-szf));
                        ACCUM4(sx1,sy2,sz1,(1.0f-sxf)*      syf *(1.0f-szf));
                        ACCUM4(sx2,sy2,sz1,      sxf *      syf *(1.0f-szf));
                        ACCUM4(sx1,sy1,sz2,(1.0f-sxf)*(1.0f-syf)*      szf );
                        ACCUM4(sx2,sy1,sz2,      sxf *(1.0f-syf)*      szf );
                        ACCUM4(sx1,sy2,sz2,(1.0f-sxf)*      syf *      szf );
                        ACCUM4(sx2,sy2,sz2,      sxf *      syf *      szf );
                    }
                    
                    memcpy(pdst, accum.ptr, float.sizeof*dstchannels);
                    
                    
                    pdst += dstchannels;
                }
                pdst += dstchannels*dst.getRowSkip();
            }
            pdst += dstchannels*dst.getSliceSkip();
        }
    }
}



// byte linear resampler, does not do any format conversions.
// only handles pixel formats that use 1 byte per color channel.
// 2D only; punts 3D pixelboxes to default LinearResampler (slow).
// templated on bytes-per-pixel to allow compiler optimizations, such
// as unrolling loops and replacing multiplies with bitshifts
struct LinearResampler_Byte(uint channels) {
    static void scale(PixelBox src,PixelBox dst) {
        // assert(src.format == dst.format);
        
        // only optimized for 2D
        if (src.getDepth() > 1 || dst.getDepth() > 1) {
            LinearResampler.scale(src, dst);
            return;
        }
        
        // srcdata stays at beginning of slice, pdst is a moving pointer
        ubyte* srcdata = cast(ubyte*)src.data;
        ubyte* pdst = cast(ubyte*)dst.data;
        
        // sx_48,sy_48 represent current position in source
        // using 16/48-bit fixed precision, incremented by steps
        uint64 stepx = (cast(uint64)src.getWidth() << 48) / dst.getWidth();
        uint64 stepy = (cast(uint64)src.getHeight() << 48) / dst.getHeight();
        
        // bottom 28 bits of temp are 16/12 bit fixed precision, used to
        // adjust a source coordinate backwards by half a pixel so that the
        // integer bits represent the first sample (eg, sx1) and the
        // fractional bits are the blend weight of the second sample
        uint temp;
        
        uint64 sy_48 = (stepy >> 1) - 1;
        for (size_t y = dst.top; y < dst.bottom; y++, sy_48+=stepy) {
            temp = cast(uint)(sy_48 >> 36);
            temp = (temp > 0x800)? temp - 0x800: 0;
            uint syf = temp & 0xFFF;
            size_t sy1 = temp >> 12;
            size_t sy2 = std.algorithm.min(sy1+1, src.bottom-src.top-1);
            size_t syoff1 = sy1 * src.rowPitch;
            size_t syoff2 = sy2 * src.rowPitch;
            
            uint64 sx_48 = (stepx >> 1) - 1;
            for (size_t x = dst.left; x < dst.right; x++, sx_48+=stepx) {
                temp = cast(uint)(sx_48 >> 36);
                temp = (temp > 0x800)? temp - 0x800 : 0;
                uint sxf = temp & 0xFFF;
                size_t sx1 = temp >> 12;
                size_t sx2 = std.algorithm.min(sx1+1, src.right-src.left-1);
                
                uint sxfsyf = sxf*syf;
                for (uint k = 0; k < channels; k++) {
                    uint accum =
                        srcdata[(sx1 + syoff1)*channels+k]*(0x1000000-(sxf<<12)-(syf<<12)+sxfsyf) +
                            srcdata[(sx2 + syoff1)*channels+k]*((sxf<<12)-sxfsyf) +
                            srcdata[(sx1 + syoff2)*channels+k]*((syf<<12)-sxfsyf) +
                            srcdata[(sx2 + syoff2)*channels+k]*sxfsyf;
                    // accum is computed using 8/24-bit fixed-point math
                    // (maximum is 0xFF000000; rounding will not cause overflow)
                    *pdst++ = cast(ubyte)((accum + 0x800000) >> 24);
                }
            }
            pdst += channels*dst.getRowSkip();
        }
    }
}
/** @} */
/** @} */
