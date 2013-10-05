module ogre.cityhash;

// Copyright (c) 2011 Google, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// CityHash, by Geoff Pike and Jyrki Alakuijala
//
// This file provides CityHash64() and related functions.
//
// It's probably possible to create even faster hash functions by
// writing a program that systematically explores some of the space of
// possible hash functions, by using SIMD instructions, or by
// compromising on hash quality.

// Annoying casts from size_t to uint.

import std.algorithm;
import core.bitop;
import core.stdc.string: memcpy,memset;  // for memcpy and memset
import ogre.compat;

/*struct pair(T, V)
{
    T first;
    V second;
}*/

alias pair!(ulong, ulong) uint128;

//Not sure about these
alias bitswap bswap_32;
ulong bswap_64(ulong i)
{
    union ULL
    {
        struct
        {
            uint a,b;
        }
        ulong x;
    }
    
    ULL ull;
    ull.x = i;
    ull.a = bitswap(ull.a);
    ull.b = bitswap(ull.b);
    std.algorithm.swap(ull.a, ull.b); // Do too?
    return ull.x;
}

static ulong UNALIGNED_LOAD64(const ubyte *p) {
    ulong result;
    memcpy(&result, p, result.sizeof);
    return result;
}

static uint UNALIGNED_LOAD32(const ubyte *p) {
    uint result;
    memcpy(&result, p, result.sizeof);
    return result;
}


version(BigEndian)
{
    uint uint_in_expected_order(uint x) { return bswap_32(x); }
    ulong ulong_in_expected_order(ulong x) { return bswap_64(x); }
}
else
{
    uint uint_in_expected_order(uint x) { return x; }
    ulong ulong_in_expected_order(ulong x) { return x; }
}

T LIKELY(T)(T x) { return x; }

static ulong Fetch64(const ubyte *p) {
    return ulong_in_expected_order(UNALIGNED_LOAD64(p));
}

static uint Fetch32(const ubyte *p) {
    return uint_in_expected_order(UNALIGNED_LOAD32(p));
}

// Some primes between 2^63 and 2^64 for various uses.
static const ulong k0 = 0xc3a5c85c97cb3127;
static const ulong k1 = 0xb492b66fbe98f273;
static const ulong k2 = 0x9ae16a3b2f90404f;

// Magic numbers for 32-bit hashing.  Copied from Murmur3.
static const uint c1 = 0xcc9e2d51;
static const uint c2 = 0x1b873593;

// A 32-bit to 32-bit integer hash copied from Murmur3.
static uint fmix(uint h)
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    return h;
}

static uint Rotate32(uint val, int shift) {
    // Avoid shifting by 32: doing so yields an undefined result.
    return shift == 0 ? val : ((val >> shift) | (val << (32 - shift)));
}

void PERMUTE3(T)(ref T a, ref T b, ref T c)
{ 
    std.algorithm.swap(a, b); 
    std.algorithm.swap(a, c); 
}

static uint Mur(uint a, uint h) {
    // Helper from Murmur3 for combining two 32-bit values.
    a *= c1;
    a = Rotate32(a, 17);
    a *= c2;
    h ^= a;
    h = Rotate32(h, 19);
    return h * 5 + 0xe6546b64;
}

static uint Hash32Len13to24(ubyte *s, size_t len) {
    uint a = Fetch32(s - 4 + (len >> 1));
    uint b = Fetch32(s + 4);
    uint c = Fetch32(s + len - 8);
    uint d = Fetch32(s + (len >> 1));
    uint e = Fetch32(s);
    uint f = Fetch32(s + len - 4);
    uint h = cast(uint)len; // size_t in C/C++ on 32bit is, well, 32bit
    
    return fmix(Mur(f, Mur(e, Mur(d, Mur(c, Mur(b, Mur(a, h)))))));
}

static uint Hash32Len0to4(ubyte *s, size_t len) {
    uint b = 0;
    uint c = 9;
    for (int i = 0; i < len; i++) {
        b = b * c1 + s[i];
        c ^= b;
    }
    return fmix(Mur(b, Mur(cast(uint)len, c)));
}

static uint Hash32Len5to12(ubyte *s, size_t len) {
    uint a = cast(uint)len, b = cast(uint)len * 5, c = 9, d = b;
    a += Fetch32(s);
    b += Fetch32(s + len - 4);
    c += Fetch32(s + ((len >> 1) & 4));
    return fmix(Mur(c, Mur(b, Mur(a, d))));
}

ulong Uint128Low64(uint128 x) { return x.first; }
ulong Uint128High64(uint128 x) { return x.second; }

// Hash 128 input bits down to 64 bits of output.
// This is intended to be a reasonably good hash function.
ulong Hash128to64(uint128 x) {
    // Murmur-inspired hashing.
    const ulong kMul = 0x9ddfea08eb382d69;
    ulong a = (Uint128Low64(x) ^ Uint128High64(x)) * kMul;
    a ^= (a >> 47);
    ulong b = (Uint128High64(x) ^ a) * kMul;
    b ^= (b >> 47);
    b *= kMul;
    return b;
}


uint CityHash32(ubyte *s, size_t len) {
    if (len <= 24) {
        return len <= 12 ?
            (len <= 4 ? Hash32Len0to4(s, len) : Hash32Len5to12(s, len)) :
            Hash32Len13to24(s, len);
    }
    
    // len > 24
    
    uint h = cast(uint)len, g = c1 * cast(uint)len, f = g;
    {
        uint a0 = Rotate32(Fetch32(s + len - 4) * c1, 17) * c2;
        uint a1 = Rotate32(Fetch32(s + len - 8) * c1, 17) * c2;
        uint a2 = Rotate32(Fetch32(s + len - 16) * c1, 17) * c2;
        uint a3 = Rotate32(Fetch32(s + len - 12) * c1, 17) * c2;
        uint a4 = Rotate32(Fetch32(s + len - 20) * c1, 17) * c2;
        h ^= a0;
        h = Rotate32(h, 19);
        h = h * 5 + 0xe6546b64;
        h ^= a2;
        h = Rotate32(h, 19);
        h = h * 5 + 0xe6546b64;
        g ^= a1;
        g = Rotate32(g, 19);
        g = g * 5 + 0xe6546b64;
        g ^= a3;
        g = Rotate32(g, 19);
        g = g * 5 + 0xe6546b64;
        f += a4;
        f = Rotate32(f, 19);
        f = f * 5 + 0xe6546b64;
    }
    
    size_t iters = (len - 1) / 20;
    do {
        uint a0 = Rotate32(Fetch32(s) * c1, 17) * c2;
        uint a1 = Fetch32(s + 4);
        uint a2 = Rotate32(Fetch32(s + 8) * c1, 17) * c2;
        uint a3 = Rotate32(Fetch32(s + 12) * c1, 17) * c2;
        uint a4 = Fetch32(s + 16);
        h ^= a0;
        h = Rotate32(h, 18);
        h = h * 5 + 0xe6546b64;
        f += a1;
        f = Rotate32(f, 19);
        f = f * c1;
        g += a2;
        g = Rotate32(g, 18);
        g = g * 5 + 0xe6546b64;
        h ^= a3 + a1;
        h = Rotate32(h, 19);
        h = h * 5 + 0xe6546b64;
        g ^= a4;
        g = bswap_32(g) * 5;
        h += a4 * 5;
        h = bswap_32(h);
        f += a0;
        PERMUTE3(f, h, g);
        s += 20;
    } while (--iters != 0);
    g = Rotate32(g, 11) * c1;
    g = Rotate32(g, 17) * c1;
    f = Rotate32(f, 11) * c1;
    f = Rotate32(f, 17) * c1;
    h = Rotate32(h + g, 19);
    h = h * 5 + 0xe6546b64;
    h = Rotate32(h, 17) * c1;
    h = Rotate32(h + f, 19);
    h = h * 5 + 0xe6546b64;
    h = Rotate32(h, 17) * c1;
    return h;
}

// Bitwise right rotate.  Normally this will compile to a single
// instruction, especially if the shift is a manifest constant.
static ulong Rotate(ulong val, int shift) {
    // Avoid shifting by 64: doing so yields an undefined result.
    return shift == 0 ? val : ((val >> shift) | (val << (64 - shift)));
}

static ulong ShiftMix(ulong val) {
    return val ^ (val >> 47);
}

static ulong HashLen16(ulong u, ulong v) {
    return Hash128to64(uint128(u, v));
}

static ulong HashLen16(ulong u, ulong v, ulong mul) {
    // Murmur-inspired hashing.
    ulong a = (u ^ v) * mul;
    a ^= (a >> 47);
    ulong b = (v ^ a) * mul;
    b ^= (b >> 47);
    b *= mul;
    return b;
}

static ulong HashLen0to16(ubyte *s, size_t len) {
    if (len >= 8) {
        ulong mul = k2 + len * 2;
        ulong a = Fetch64(s) + k2;
        ulong b = Fetch64(s + len - 8);
        ulong c = Rotate(b, 37) * mul + a;
        ulong d = (Rotate(a, 25) + b) * mul;
        return HashLen16(c, d, mul);
    }
    if (len >= 4) {
        ulong mul = k2 + len * 2;
        ulong a = Fetch32(s);
        return HashLen16(len + (a << 3), Fetch32(s + len - 4), mul);
    }
    if (len > 0) {
        ubyte a = s[0];
        ubyte b = s[len >> 1];
        ubyte c = s[len - 1];
        uint y = cast(uint)(a) + (cast(uint)(b) << 8);
        uint z = cast(uint)len + (cast(uint)(c) << 2);
        return ShiftMix(y * k2 ^ z * k0) * k2;
    }
    return k2;
}

// This probably works well for 16-byte strings as well, but it may be overkill
// in that case.
static ulong HashLen17to32(ubyte *s, size_t len) {
    ulong mul = k2 + len * 2;
    ulong a = Fetch64(s) * k1;
    ulong b = Fetch64(s + 8);
    ulong c = Fetch64(s + len - 8) * mul;
    ulong d = Fetch64(s + len - 16) * k2;
    return HashLen16(Rotate(a + b, 43) + Rotate(c, 30) + d,
                     a + Rotate(b + k2, 18) + c, mul);
}

// Return a 16-byte hash for 48 bytes.  Quick and dirty.
// Callers do best to use "random-looking" values for a and b.
static pair!(ulong, ulong) WeakHashLen32WithSeeds(
    ulong w, ulong x, ulong y, ulong z, ulong a, ulong b) {
    a += w;
    b = Rotate(b + a + z, 21);
    ulong c = a;
    a += x;
    a += y;
    b += Rotate(a, 44);
    return uint128(a + z, b + c);
}

// Return a 16-byte hash for s[0] ... s[31], a, and b.  Quick and dirty.
static pair!(ulong, ulong) WeakHashLen32WithSeeds(
    const ubyte* s, ulong a, ulong b) {
    return WeakHashLen32WithSeeds(Fetch64(s),
                                  Fetch64(s + 8),
                                  Fetch64(s + 16),
                                  Fetch64(s + 24),
                                  a,
                                  b);
}

// Return an 8-byte hash for 33 to 64 bytes.
static ulong HashLen33to64(ubyte *s, size_t len) {
    ulong mul = k2 + len * 2;
    ulong a = Fetch64(s) * k2;
    ulong b = Fetch64(s + 8);
    ulong c = Fetch64(s + len - 24);
    ulong d = Fetch64(s + len - 32);
    ulong e = Fetch64(s + 16) * k2;
    ulong f = Fetch64(s + 24) * 9;
    ulong g = Fetch64(s + len - 8);
    ulong h = Fetch64(s + len - 16) * mul;
    ulong u = Rotate(a + g, 43) + (Rotate(b, 30) + c) * 9;
    ulong v = ((a + g) ^ d) + f + 1;
    ulong w = bswap_64((u + v) * mul) + h;
    ulong x = Rotate(e + f, 42) + c;
    ulong y = (bswap_64((v + w) * mul) + g) * mul;
    ulong z = e + f + c;
    a = bswap_64((x + z) * mul + y) + b;
    b = ShiftMix((z + a) * mul + d + h) * mul;
    return b + x;
}

ulong CityHash64(ubyte *s, size_t len) {
    if (len <= 32) {
        if (len <= 16) {
            return HashLen0to16(s, len);
        } else {
            return HashLen17to32(s, len);
        }
    } else if (len <= 64) {
        return HashLen33to64(s, len);
    }
    
    // For strings over 64 bytes we hash the end first, and then as we
    // loop we keep 56 bytes of state: v, w, x, y, and z.
    ulong x = Fetch64(s + len - 40);
    ulong y = Fetch64(s + len - 16) + Fetch64(s + len - 56);
    ulong z = HashLen16(Fetch64(s + len - 48) + len, Fetch64(s + len - 24));
    pair!(ulong, ulong) v = WeakHashLen32WithSeeds(s + len - 64, len, z);
    pair!(ulong, ulong) w = WeakHashLen32WithSeeds(s + len - 32, y + k1, x);
    x = x * k1 + Fetch64(s);
    
    // Decrease len to the nearest multiple of 64, and operate on 64-byte chunks.
    len = (len - 1) & ~cast(size_t)(63);
    do {
        x = Rotate(x + y + v.first + Fetch64(s + 8), 37) * k1;
        y = Rotate(y + v.second + Fetch64(s + 48), 42) * k1;
        x ^= w.second;
        y += v.first + Fetch64(s + 40);
        z = Rotate(z + w.first, 33) * k1;
        v = WeakHashLen32WithSeeds(s, v.second * k1, x + w.first);
        w = WeakHashLen32WithSeeds(s + 32, z + w.second, y + Fetch64(s + 16));
        std.algorithm.swap(z, x);
        s += 64;
        len -= 64;
    } while (len != 0);
    return HashLen16(HashLen16(v.first, w.first) + ShiftMix(y) * k1 + z,
                     HashLen16(v.second, w.second) + x);
}

ulong CityHash64WithSeed(ubyte *s, size_t len, ulong seed) {
    return CityHash64WithSeeds(s, len, k2, seed);
}

ulong CityHash64WithSeeds(ubyte *s, size_t len,
                          ulong seed0, ulong seed1) {
    return HashLen16(CityHash64(s, len) - seed0, seed1);
}


// A subroutine for CityHash128().  Returns a decent 128-bit hash for strings
// of any length representable in signed long.  Based on City and Murmur.
static uint128 CityMurmur(ubyte *s, size_t len, uint128 seed) {
    ulong a = Uint128Low64(seed);
    ulong b = Uint128High64(seed);
    ulong c = 0;
    ulong d = 0;
    long l = len - 16;
    if (l <= 0) {  // len <= 16
        a = ShiftMix(a * k1) * k1;
        c = b * k1 + HashLen0to16(s, len);
        d = ShiftMix(a + (len >= 8 ? Fetch64(s) : c));
    } else {  // len > 16
        c = HashLen16(Fetch64(s + len - 8) + k1, a);
        d = HashLen16(b + len, c + Fetch64(s + len - 16));
        a += d;
        do {
            a ^= ShiftMix(Fetch64(s) * k1) * k1;
            a *= k1;
            b ^= a;
            c ^= ShiftMix(Fetch64(s + 8) * k1) * k1;
            c *= k1;
            d ^= c;
            s += 16;
            l -= 16;
        } while (l > 0);
    }
    a = HashLen16(a, c);
    b = HashLen16(d, b);
    return uint128(a ^ b, HashLen16(b, a));
}

uint128 CityHash128WithSeed(ubyte *s, size_t len, uint128 seed) {
    if (len < 128) {
        return CityMurmur(s, len, seed);
    }
    
    // We expect len >= 128 to be the common case.  Keep 56 bytes of state:
    // v, w, x, y, and z.
    pair!(ulong, ulong) v, w;
    ulong x = Uint128Low64(seed);
    ulong y = Uint128High64(seed);
    ulong z = len * k1;
    v.first = Rotate(y ^ k1, 49) * k1 + Fetch64(s);
    v.second = Rotate(v.first, 42) * k1 + Fetch64(s + 8);
    w.first = Rotate(y + z, 35) * k1 + x;
    w.second = Rotate(x + Fetch64(s + 88), 53) * k1;
    
    // This is the same inner loop as CityHash64(), manually unrolled.
    do {
        x = Rotate(x + y + v.first + Fetch64(s + 8), 37) * k1;
        y = Rotate(y + v.second + Fetch64(s + 48), 42) * k1;
        x ^= w.second;
        y += v.first + Fetch64(s + 40);
        z = Rotate(z + w.first, 33) * k1;
        v = WeakHashLen32WithSeeds(s, v.second * k1, x + w.first);
        w = WeakHashLen32WithSeeds(s + 32, z + w.second, y + Fetch64(s + 16));
        std.algorithm.swap(z, x);
        s += 64;
        x = Rotate(x + y + v.first + Fetch64(s + 8), 37) * k1;
        y = Rotate(y + v.second + Fetch64(s + 48), 42) * k1;
        x ^= w.second;
        y += v.first + Fetch64(s + 40);
        z = Rotate(z + w.first, 33) * k1;
        v = WeakHashLen32WithSeeds(s, v.second * k1, x + w.first);
        w = WeakHashLen32WithSeeds(s + 32, z + w.second, y + Fetch64(s + 16));
        std.algorithm.swap(z, x);
        s += 64;
        len -= 128;
    } while (LIKELY(len >= 128));
    x += Rotate(v.first + z, 49) * k0;
    y = y * k0 + Rotate(w.second, 37);
    z = z * k0 + Rotate(w.first, 27);
    w.first *= 9;
    v.first *= k0;
    // If 0 < len < 128, hash up to 4 chunks of 32 bytes each from the end of s.
    for (size_t tail_done = 0; tail_done < len; ) {
        tail_done += 32;
        y = Rotate(x + y, 42) * k0 + v.second;
        w.first += Fetch64(s + len - tail_done + 16);
        x = x * k0 + w.first;
        z += w.second + Fetch64(s + len - tail_done);
        w.second += v.first;
        v = WeakHashLen32WithSeeds(s + len - tail_done, v.first + z, v.second);
        v.first *= k0;
    }
    // At this point our 56 bytes of state should contain more than
    // enough information for a strong 128-bit hash.  We use two
    // different 56-byte-to-8-byte hashes to get a 16-byte final result.
    x = HashLen16(x, v.first);
    y = HashLen16(y + z, w.first);
    return uint128(HashLen16(x + v.second, w.second) + y,
                   HashLen16(x + w.second, y + v.second));
}


uint128 CityHash128(ubyte *s, size_t len) {
    return len >= 16 ?
        CityHash128WithSeed(s + 16, len - 16,
                            uint128(Fetch64(s), Fetch64(s + 8) + k0)) :
        CityHash128WithSeed(s, len, uint128(k0, k1));
}

/*
#ifdef __SSE4_2__
#include <citycrc.h>
#include <nmmintrin.h>

// Requires len >= 240.
static void CityHashCrc256Long(const ubyte *s, size_t len,
                               uint seed, ulong *result) {
    ulong a = Fetch64(s + 56) + k0;
    ulong b = Fetch64(s + 96) + k0;
    ulong c = result[0] = HashLen16(b, len);
    ulong d = result[1] = Fetch64(s + 120) * k0 + len;
    ulong e = Fetch64(s + 184) + seed;
    ulong f = 0;
    ulong g = 0;
    ulong h = c + d;
    ulong x = seed;
    ulong y = 0;
    ulong z = 0;
    
    // 240 bytes of input per iter.
    size_t iters = len / 240;
    len -= iters * 240;
    do {
#undef CHUNK
#define CHUNK(r)                                \
PERMUTE3(x, z, y);                          \
b += Fetch64(s);                            \
c += Fetch64(s + 8);                        \
d += Fetch64(s + 16);                       \
e += Fetch64(s + 24);                       \
f += Fetch64(s + 32);                       \
a += b;                                     \
h += f;                                     \
b += c;                                     \
f += d;                                     \
g += e;                                     \
e += z;                                     \
g += x;                                     \
z = _mm_crc32_u64(z, b + g);                \
y = _mm_crc32_u64(y, e + h);                \
x = _mm_crc32_u64(x, f + a);                \
e = Rotate(e, r);                           \
c += e;                                     \
s += 40
        
        CHUNK(0); PERMUTE3(a, h, c);
        CHUNK(33); PERMUTE3(a, h, f);
        CHUNK(0); PERMUTE3(b, h, f);
        CHUNK(42); PERMUTE3(b, h, d);
        CHUNK(0); PERMUTE3(b, h, e);
        CHUNK(33); PERMUTE3(a, h, e);
    } while (--iters > 0);
    
    while (len >= 40) {
        CHUNK(29);
        e ^= Rotate(a, 20);
        h += Rotate(b, 30);
        g ^= Rotate(c, 40);
        f += Rotate(d, 34);
        PERMUTE3(c, h, g);
        len -= 40;
    }
    if (len > 0) {
        s = s + len - 40;
        CHUNK(33);
        e ^= Rotate(a, 43);
        h += Rotate(b, 42);
        g ^= Rotate(c, 41);
        f += Rotate(d, 40);
    }
    result[0] ^= h;
    result[1] ^= g;
    g += h;
    a = HashLen16(a, g + z);
    x += y << 32;
    b += x;
    c = HashLen16(c, z) + h;
    d = HashLen16(d, e + result[0]);
    g += e;
    h += HashLen16(x, f);
    e = HashLen16(a, d) + g;
    z = HashLen16(b, c) + a;
    y = HashLen16(g, h) + c;
    result[0] = e + z + y + x;
    a = ShiftMix((a + y) * k0) * k0 + b;
    result[1] += a + result[0];
    a = ShiftMix(a * k0) * k0 + c;
    result[2] = a + result[1];
    a = ShiftMix((a + e) * k0) * k0;
    result[3] = a + result[2];
}

// Requires len < 240.
static void CityHashCrc256Short(const ubyte *s, size_t len, ulong *result) {
    ubyte buf[240];
    memcpy(buf, s, len);
    memset(buf + len, 0, 240 - len);
    CityHashCrc256Long(buf, 240, ~cast(uint)(len), result);
}

void CityHashCrc256(const ubyte *s, size_t len, ulong *result) {
    if (LIKELY(len >= 240)) {
        CityHashCrc256Long(s, len, 0, result);
    } else {
        CityHashCrc256Short(s, len, result);
    }
}

uint128 CityHashCrc128WithSeed(const ubyte *s, size_t len, uint128 seed) {
    if (len <= 900) {
        return CityHash128WithSeed(s, len, seed);
    } else {
        ulong result[4];
        CityHashCrc256(s, len, result);
        ulong u = Uint128High64(seed) + result[0];
        ulong v = Uint128Low64(seed) + result[1];
        return uint128(HashLen16(u, v + result[2]),
                       HashLen16(Rotate(v, 32), u * k0 + result[3]));
    }
}

uint128 CityHashCrc128(const ubyte *s, size_t len) {
    if (len <= 900) {
        return CityHash128(s, len);
    } else {
        ulong result[4];
        CityHashCrc256(s, len, result);
        return uint128(result[2], result[3]);
    }
}

#endif*/

