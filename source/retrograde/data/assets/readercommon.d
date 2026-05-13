/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.data.assets.readercommon;

import retrograde.std.endian : toPlatformEndian, Endian;

/**
 * Reads a little-endian 32-bit unsigned integer from the given data buffer
 * at the given offset. The offset is not advanced; callers must increment it
 * by 4 after the read.
 */
uint readUInt(const(ubyte)[] data, ref size_t offset) {
    ubyte[4] bytes = data[offset .. offset + 4];
    return toPlatformEndian!uint(bytes, Endian.little);
}

/**
 * Reads a little-endian 16-bit unsigned integer from the given data buffer
 * at the given offset. The offset is not advanced; callers must increment it
 * by 2 after the read.
 */
ushort readUShort(const(ubyte)[] data, ref size_t offset) {
    ubyte[2] bytes = data[offset .. offset + 2];
    return toPlatformEndian!ushort(bytes, Endian.little);
}

/**
 * Reads a little-endian 32-bit IEEE 754 float from the given data buffer
 * at the given offset. The offset is not advanced; callers must increment it
 * by 4 after the read.
 */
float readFloat(const(ubyte)[] data, ref size_t offset) {
    ubyte[4] bytes = data[offset .. offset + 4];
    return toPlatformEndian!float(bytes, Endian.little);
}

/**
 * Reads a single unsigned byte from the given data buffer at the given offset.
 * The offset is not advanced; callers must increment it by 1 after the read.
 */
ubyte readUByte(const(ubyte)[] data, ref size_t offset) {
    return data[offset];
}
