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

module retrograde.std.collections;

import retrograde.std.memory : malloc, realloc, free, calloc, allocateRaw, memset, memcpy;
import retrograde.std.math : ceil;
import retrograde.std.option : Option, some, none;
import retrograde.std.hash : hashOf;
import retrograde.std.result : Result, success, failure;

private enum defaultChunkSize = 8;

/**
 * A dynamic array that automatically resizes when needed.
 * Items are stored in a contiguous memory block.
 * 
 * The array grows automatically by `chunkSize` elements when capacity is exceeded.
 * Memory is managed manually using malloc/realloc/free from retrograde.std.memory.
 * 
 * Key features:
 * - Automatic resizing with configurable chunk size
 * - Contiguous memory storage for cache efficiency
 * - Support for slicing, indexing, and iteration
 * - Copy and assignment operations with deep copy semantics
 * - No gaps - removing items shifts subsequent elements
 * 
 * This implementation is not thread-safe.
 * 
 * Template_Params:
 *  T = the type of elements stored in the array
 *  chunkSize = the number of elements to allocate when growing (default: 8)
 */
struct Array(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0;
    private size_t _capacity = 0;

    /**
     * Copy constructor.
     * Creates a deep copy of another array.
     *
     * Params:
     *  other = the array to copy from.
     */
    this(ref return scope inout typeof(this) other) {
        this(other.items[0 .. other._length]);
        _capacity = other._length;
    }

    /**
     * Constructor from a D array.
     * Creates a deep copy of the given array.
     *
     * Params:
     *  other = the D array to copy from.
     */
    this(scope inout T[] other) {
        if (other.length == 0) {
            return;
        }

        items = cast(T*) malloc(T.sizeof * other.length);
        assert(items !is null, "Failed to allocate memory during assignment of array");

        if (items !is null) {
            memset(items, 0, T.sizeof * other.length);
            // Cast away inout to allow assignment
            T[] mutableOther = cast(T[]) other;
            foreach (size_t i, ref T item; mutableOther) {
                items[i] = item;
            }
            _length = other.length;
            _capacity = other.length;
        }
    }

    /**
     * Destructor.
     * Automatically clears and deallocates all memory.
     */
    ~this() {
        clear();
    }

    /**
     * Returns: the amount of items currently in the array.
     */
    size_t length() const {
        return _length;
    }

    /**
     * Returns: the allocated capacity of the array in number of items.
     */
    size_t capacity() const {
        return _capacity;
    }

    /**
     * Change the capacity of the array.
     * This will allocate or deallocate memory as needed.
     *
     * Params: 
     *  newCapacity = the new capacity of the array.
     */
    void capacity(size_t newCapacity) {
        if (newCapacity == _capacity) {
            return;
        }

        if (newCapacity == 0) {
            clear();
            return;
        }

        resize(newCapacity - capacity);

        if (_length > _capacity) {
            _length = _capacity;
        }
    }

    /** 
     * Add an item to the end of the array.
     * Alternatively, you can use the ~= operator to add an item.
     *
     * Params:
     *  item = the item to add.
     * Returns: the index of the added item, or -1 if the operation failed.
     */
    size_t add(T item) {
        considerResize();

        if (items !is null) {
            size_t index = _length;
            items[index] = item;
            _length++;
            return index;
        }

        return -1;
    }

    /** 
     * Remove an item specified by index from the array.
     *
     * Params:
     *  index = the index of the item to remove.
     */
    void remove(size_t index) {
        if (index >= _length) {
            return;
        }

        if (index == _length - 1) {
            _length--;
            return;
        }

        for (size_t i = index; i < _length - 1; i++) {
            items[i] = items[i + 1];
        }

        _length--;
    }

    /**
     * Replace an item at the given index with a new item.
     * Alternatively, you can use the [] operator to replace an item.
     *
     * Params:
     *  index = the index of the item to replace.
     *  newItem = the new item to replace with.
     */
    void replace(size_t index, T newItem) {
        if (index >= _length) {
            return;
        }

        items[index] = newItem;
    }

    /**
     * Clear all items in the array.
     * Calls destructors on all items and deallocates memory.
     * After calling this, length and capacity will both be 0.
     */
    void clear() {
        if (items !is null) {
            for (size_t i = 0; i < _length; i++) {
                items[i].destroy();
            }

            free(items);
            items = null;
        }

        _length = 0;
        _capacity = 0;
    }

    /**
     * Truncate the array to the given length.
     * Allocated memory will not be deallocated.
     * If the new length is greater than the current length, nothing will happen.
     *
     * Params:
     *  newLength = the new length of the array.
     */
    void truncate(size_t newLength) {
        if (newLength < _length) {
            _length = newLength;
        }
    }

    /** 
     * Find the index of the first item that matches the given value.
     *
     * Params:
     *  value = the value to search for.
     * Returns: the index of the first item that matches the given value. -1 if no item is found.
     */
    size_t find(T value) const {
        for (size_t i = 0; i < _length; i++) {
            if (items[i] == value) {
                return i;
            }
        }

        return -1;
    }

    /** 
     * Returns: Whether the given item exists in the array.
     */
    bool exists(T value) const {
        return find(value) != -1;
    }

    /**
     * Get a D array slice of the array's items.
     * The returned slice directly references the internal memory buffer.
     * The slice becomes invalid if the array is modified in a way that reallocates memory.
     *
     * Returns: A D array slice containing all items in the array.
     */
    T[] arr() {
        return items[0 .. _length];
    }

    /**
     * Assignment operator for copying another Array.
     * Creates a deep copy of the other array.
     *
     * Params:
     *  other = the array to copy from.
     */
    void opAssign(ref return scope inout typeof(this) other) {
        if (this is other) {
            return;
        }

        if (other._capacity == 0) {
            clear();
            return;
        }

        T* newItems = cast(T*) realloc(items, T.sizeof * other._length);
        if (newItems is null) {
            assert(0, "Failed to allocate memory during assignment of array");
            return;
        }

        memset(newItems, 0, T.sizeof * other._length);
        // Cast away inout to allow assignment
        T* mutableOtherItems = cast(T*) other.items;
        for (size_t i = 0; i < other._length; i++) {
            newItems[i] = mutableOtherItems[i];
        }

        items = newItems;
        _length = other._length;

        // Only other._length slots were allocated above, so capacity must match
        // that allocation (as the copy constructor does) — not other._capacity,
        // which would let a later add() write past the buffer.
        _capacity = other._length;
    }

    /**
     * Assignment operator for copying a D array.
     * Creates a deep copy of the given array.
     *
     * Params:
     *  other = the D array to copy from.
     */
    void opAssign(scope inout T[] other) {
        if (other.length == 0) {
            clear();
            return;
        }

        T* newItems = cast(T*) realloc(items, T.sizeof * other.length);
        if (newItems is null) {
            assert(0, "Failed to allocate memory during assignment of array");
            return;
        }

        memset(newItems, 0, T.sizeof * other.length);
        // Cast away inout to allow assignment
        T[] mutableOther = cast(T[]) other;
        for (size_t i = 0; i < other.length; i++) {
            newItems[i] = mutableOther[i];
        }

        items = newItems;
        _length = other.length;
        _capacity = other.length;
    }

    /**
     * Append operator (~=) for adding a single item.
     * Equivalent to calling add().
     *
     * Params:
     *  rhs = the item to append.
     */
    void opOpAssign(string op : "~")(T rhs) {
        add(rhs);
    }

    /**
     * Append operator (~=) for concatenating another array.
     * Adds all items from the other array to this array.
     *
     * Params:
     *  rhs = the array to append.
     */
    void opOpAssign(string op : "~")(ref typeof(this) rhs) {
        foreach (T item; rhs.items[0 .. rhs._length]) {
            add(item);
        }
    }

    /**
     * Binary concatenation operator (~) for creating a new array.
     * Creates a new array containing items from both arrays.
     *
     * Params:
     *  rhs = the array to concatenate.
     * Returns: a new array containing all items from both arrays.
     */
    typeof(this) opBinary(string op : "~")(ref typeof(this) rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    /**
     * Binary concatenation operator (~) for adding an item.
     * Creates a new array with the item appended.
     *
     * Params:
     *  rhs = the item to append.
     * Returns: a new array with the item added at the end.
     */
    typeof(this) opBinary(string op : "~")(T rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    /**
     * Binary concatenation operator (~) for adding an item by reference.
     * Creates a new array with the item appended.
     *
     * Params:
     *  rhs = the item to append.
     * Returns: a new array with the item added at the end.
     */
    typeof(this) opBinary(string op : "~")(ref T rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    /**
     * Index operator for read access (const version).
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) const {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return items[i];
    }

    /**
     * Index operator for read/write access.
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) { // TODO: maybe get rid and fix const correctness
        assert(i >= 0 && i < _length, "Index out of bounds");
        return items[i];
    }

    /**
     * Full slice operator [].
     * Returns a slice of all items in the array.
     *
     * Returns: a D array slice containing all items.
     */
    T[] opIndex() {
        return items[0 .. _length];
    }

    /**
     * Dollar operator for slice expressions.
     * Allows usage like array[0 .. $].
     *
     * Returns: the length of the array.
     */
    size_t opDollar() {
        return _length;
    }

    /**
     * Slice operator for read/write access.
     *
     * Params:
     *  i = the starting index.
     *  j = the ending index (exclusive).
     * Returns: a D array slice of the specified range.
     */
    auto opSlice(size_t i, size_t j) { // TODO: maybe get rid and fix const correctness
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    /// Idem
    auto opSlice(size_t i, size_t j) const {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    /**
     * Multidimensional slice operator.
     * Provides slice support for dimension 0.
     *
     * Params:
     *  i = the starting index.
     *  j = the ending index (exclusive).
     * Returns: a D array slice of the specified range.
     */
    T[] opSlice(size_t dim : 0)(size_t i, size_t j) {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    /**
     * Identity operator for slices.
     * Returns the slice as-is.
     *
     * Params:
     *  slice = the slice to return.
     * Returns: the same slice.
     */
    T[] opIndex()(T[] slice) {
        return slice;
    }

    /**
     * Index assignment operator for setting a single element.
     * Allows usage like array[i] = value.
     *
     * Params:
     *  value = the value to assign.
     *  i = the index to assign to.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value, size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        items[i] = value;
        return value;
    }

    /**
     * Array-wide assignment operator.
     * Assigns the same value to all elements in the array.
     * Allows usage like array[] = value.
     *
     * Params:
     *  value = the value to assign to all elements.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value) {
        for (size_t i = 0; i < _length; i++) {
            items[i] = value;
        }

        return value;
    }

    /**
     * Equality comparison operator (const D array by value).
     *
     * Params:
     *  other = the D array to compare with.
     * Returns: true if arrays have the same length and all elements are equal.
     */
    bool opEquals(const T[] other) const {
        return opEquals(other);
    }

    /**
     * Equality comparison operator (const D array by reference).
     * Compares element-by-element.
     *
     * Params:
     *  other = the D array to compare with.
     * Returns: true if arrays have the same length and all elements are equal.
     */
    bool opEquals(ref const T[] other) const {
        if (other.length != _length) {
            return false;
        }

        for (size_t i = 0; i < _length; i++) {
            if (items[i] != other[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * Equality comparison operator (const Array by value).
     *
     * Params:
     *  other = the array to compare with.
     * Returns: true if arrays have the same length and all elements are equal.
     */
    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    /**
     * Equality comparison operator (const Array by reference).
     * Compares element-by-element.
     *
     * Params:
     *  other = the array to compare with.
     * Returns: true if arrays have the same length and all elements are equal.
     */
    bool opEquals(ref const typeof(this) other) const {
        if (other.length != _length) {
            return false;
        }

        for (size_t i = 0; i < _length; i++) {
            if (items[i] != other.items[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * Compute a hash of the array.
     * Uses a polynomial rolling hash over all elements.
     *
     * Returns: the hash value of the array.
     */
    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        for (size_t i = 0; i < _length; i++) {
            hash = hash * 33 + items[i].hashOf;
        }

        return hash;
    }

    /**
     * Foreach iteration support.
     * Allows iteration with `foreach (item; array)`.
     *
     * Params:
     *  dg = the delegate to call for each item.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            auto result = dg(items[i]);
            if (result) {
                return result;
            }
        }

        return 0;
    }

    /**
     * Foreach iteration support with index.
     * Allows iteration with `foreach (i, item; array)`.
     *
     * Params:
     *  dg = the delegate to call for each item with its index.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(size_t, ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            auto result = dg(i, items[i]);
            if (result) {
                return result;
            }
        }

        return 0;
    }

    private void considerResize() {
        if (items is null || _capacity == length) {
            resize();
        }
    }

    private void resize(size_t growSize = chunkSize) {
        items = cast(T*) realloc(items, T.sizeof * (_capacity + growSize));
        assert(items !is null, "Failed to allocate memory during resizing of array");
        _capacity += growSize;

        if (growSize > 0) {
            for (size_t i = _capacity - growSize; i < _capacity; i++) {
                memset(&items[i], 0, T.sizeof);
                auto init = T.init;
                items[i] = init;
            }
        }
    }
}

struct Slot {
    size_t index;
    uint serialNumber;
}

/** 
 * A dynamic sparse array that tracks item validity using serial numbers.
 * Items are stored in a contiguous memory block alongside their serial numbers.
 * 
 * Each slot has an associated serial number:
 * - Serial numbers start at 1 and increment with each addition
 * - A serial number of 0 indicates an empty/unused slot
 * - Items can be removed without shifting the array (creating gaps)
 * - Compact can be called to defragment and reclaim space
 *
 * This implementation is not thread-safe.
 */
struct SlotList(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private uint* serials = null;
    private size_t _length = 0;
    private size_t _capacity = 0;
    private uint nextSerial = 1;

    /**
     * Copy constructor.
     * Creates a deep copy of another slot list.
     *
     * Params:
     *  other = the slot list to copy from.
     */
    this(ref return scope inout typeof(this) other) {
        if (other._length == 0) {
            return;
        }

        items = cast(T*) malloc(T.sizeof * other._length);
        serials = cast(uint*) malloc(uint.sizeof * other._length);
        assert(items !is null && serials !is null, "Failed to allocate memory during copy construction");

        if (items !is null && serials !is null) {
            memset(items, 0, T.sizeof * other._length);
            memset(serials, 0, uint.sizeof * other._length);
            
            T* mutableOtherItems = cast(T*) other.items;
            uint* mutableOtherSerials = cast(uint*) other.serials;
            
            for (size_t i = 0; i < other._length; i++) {
                items[i] = mutableOtherItems[i];
                serials[i] = mutableOtherSerials[i];
            }
            
            _length = other._length;
            _capacity = other._length;
            nextSerial = other.nextSerial;
        }
    }

    /**
     * Destructor.
     * Automatically clears and deallocates all memory.
     */
    ~this() {
        clear();
    }

    /**
     * Returns: the number of non-empty items in the slot list.
     */
    size_t length() const {
        size_t c = 0;
        for (size_t i = 0; i < _length; i++) {
            if (serials[i] != 0) {
                c++;
            }
        }

        return c;
    }

    /**
     * Returns: the physical length of the slot list (including empty slots).
     */
    size_t physicalLength() const {
        return _length;
    }

    /**
     * Returns: the allocated capacity of the slot list in number of slots.
     */
    size_t capacity() const {
        return _capacity;
    }

    /**
     * Change the capacity of the slot list.
     * This will allocate or deallocate memory as needed.
     *
     * Params: 
     *  newCapacity = the new capacity of the slot list.
     */
    void capacity(size_t newCapacity) {
        if (newCapacity == _capacity) {
            return;
        }

        if (newCapacity == 0) {
            clear();
            return;
        }

        resize(newCapacity - _capacity);

        if (_length > _capacity) {
            _length = _capacity;
        }
    }

    /** 
     * Add an item to the slot list.
     * The item will receive a new serial number.
     *
     * Params:
     *  item = the item to add.
     * Returns: a Result containing the Slot referencing the added item, or a failure if the operation failed.
     */
    Result!Slot add(T item) {
        if (nextSerial == 0) {
            return failure!Slot("SlotList serial number overflow: maximum number of additions reached");
        }

        // First try to find an empty slot
        for (size_t i = 0; i < _length; i++) {
            if (serials[i] == 0) {
                items[i] = item;
                serials[i] = nextSerial++;
                return success(Slot(i, serials[i]));
            }
        }

        // No empty slot found, add at the end
        considerResize();

        if (items !is null && serials !is null) {
            size_t index = _length;
            items[index] = item;
            serials[index] = nextSerial++;
            _length++;
            return success(Slot(index, serials[index]));
        }

        return failure!Slot("Failed to allocate memory for slot list");
    }

    /** 
     * Remove an item at the specified index.
     * This marks the slot as empty but doesn't shift other items.
     *
     * Params:
     *  index = the index of the item to remove.
     */
    void remove(size_t index) {
        if (index >= _length) {
            return;
        }

        serials[index] = 0;
        auto init = T.init;
        items[index] = init;
    }

    /** 
     * Remove an item at the specified slot.
     * This marks the slot as empty but doesn't shift other items.
     * If the slot's serial number doesn't match, this does nothing.
     *
     * Params:
     *  slot = the slot of the item to remove.
     */
    void remove(Slot slot) {
        if (slot.index >= _length || serials[slot.index] != slot.serialNumber) {
            return;
        }

        serials[slot.index] = 0;
        auto init = T.init;
        items[slot.index] = init;
    }

    /**
     * Replace an item at the given index with a new item.
     * The serial number remains unchanged.
     * If the slot is empty, this does nothing.
     *
     * Params:
     *  index = the index of the item to replace.
     *  newItem = the new item to replace with.
     */
    void replace(size_t index, T newItem) {
        if (index >= _length || serials[index] == 0) {
            return;
        }

        items[index] = newItem;
    }

    /**
     * Replace an item at the given slot with a new item.
     * The serial number remains unchanged.
     * If the slot's serial number doesn't match, this does nothing.
     *
     * Params:
     *  slot = the slot of the item to replace.
     *  newItem = the new item to replace with.
     */
    void replace(Slot slot, T newItem) {
        if (slot.index >= _length || serials[slot.index] != slot.serialNumber) {
            return;
        }

        items[slot.index] = newItem;
    }

    /** 
     * Clear all items in the slot list.
     * Allocated memory will be deallocated.
     */
    void clear() {
        if (items !is null) {
            for (size_t i = 0; i < _length; i++) {
                items[i].destroy();
            }
            free(items);
            items = null;
        }

        if (serials !is null) {
            free(serials);
            serials = null;
        }

        _length = 0;
        _capacity = 0;
        nextSerial = 1;
    }

    /**
     * Truncate the slot list to the given length.
     * Allocated memory will not be deallocated.
     * If the new length is greater than the current length, nothing will happen.
     *
     * Params:
     *  newLength = the new length of the slot list.
     */
    void truncate(size_t newLength) {
        if (newLength < _length) {
            // Clear the truncated slots
            auto init = T.init;
            for (size_t i = newLength; i < _length; i++) {
                serials[i] = 0;
                items[i] = init;
            }
            _length = newLength;
        }
    }

    /**
     * Defragment the slot list by moving all valid items to the front
     * and truncating the list to remove empty slots at the end.
     * 
     * WARNING: After calling compact(), previously returned indices are no longer valid!
     * The physical positions of items will have changed.
     */
    void compact() {
        if (_length == 0) {
            return;
        }

        size_t writeIndex = 0;
        for (size_t readIndex = 0; readIndex < _length; readIndex++) {
            if (serials[readIndex] != 0) {
                if (writeIndex != readIndex) {
                    items[writeIndex] = items[readIndex];
                    serials[writeIndex] = serials[readIndex];
                    auto init = T.init;
                    items[readIndex] = init;
                    serials[readIndex] = 0;
                }
                writeIndex++;
            }
        }

        _length = writeIndex;
    }

    /** 
     * Find the slot of the first item that matches the given value.
     * Only searches non-empty slots.
     *
     * Params:
     *  value = the value to search for.
     * Returns: a Result containing the Slot of the first matching item, or a failure if not found.
     */
    Result!Slot find(T value) const {
        for (size_t i = 0; i < _length; i++) {
            if (serials[i] != 0 && items[i] == value) {
                return success(Slot(i, serials[i]));
            }
        }

        return failure!Slot("Item not found");
    }

    /** 
     * Find the index of the item with the given serial number.
     *
     * Params:
     *  serial = the serial number to search for.
     * Returns: the index of the item with the given serial number. -1 if not found.
     */
    size_t findIndexBySerial(uint serial) const {
        if (serial == 0) {
            return -1;
        }

        for (size_t i = 0; i < _length; i++) {
            if (serials[i] == serial) {
                return i;
            }
        }

        return -1;
    }

    /** 
     * Find the item with the given serial number.
     *
     * Params:
     *  serial = the serial number to search for.
     * Returns: the item with the given serial number, or none if not found.
     */
    Option!T findItemBySerial(uint serial) const {
        size_t index = findIndexBySerial(serial);
        if (index == -1) {
            return none!T;
        }

        return some(cast(T) items[index]);
    }

    /** 
     * Find the slot with the given serial number.
     *
     * Params:
     *  serial = the serial number to search for.
     * Returns: the slot with the given serial number, or none if not found.
     */
    Option!Slot findSlotBySerial(uint serial) const {
        size_t index = findIndexBySerial(serial);
        if (index == -1) {
            return none!Slot;
        }

        return some(Slot(index, serials[index]));
    }

    /** 
     * Find the slot at the given index.
     * This validates that the index is in range and not empty.
     *
     * Params:
     *  index = the index to look up.
     * Returns: the slot at the given index, or none if index is out of range or empty.
     */
    Option!Slot findSlotByIndex(size_t index) const {
        if (index >= _length || serials[index] == 0) {
            return none!Slot;
        }

        return some(Slot(index, serials[index]));
    }

    /** 
     * Returns: Whether the given item exists in the slot list (in a non-empty slot).
     */
    bool exists(T value) const {
        return find(value).isSuccessful;
    }

    /**
     * Get the item at the given slot.
     * This performs a serial number check to ensure the slot is still valid.
     *
     * Params:
     *  slot = the slot to retrieve.
     * Returns: the item at the slot, or none if the slot is invalid or serial doesn't match.
     */
    Option!T get(Slot slot) const {
        if (slot.index >= _length || serials[slot.index] != slot.serialNumber) {
            return none!T;
        }

        return some(cast(T) items[slot.index]);
    }

    /**
     * Check if a slot is still valid.
     * This verifies both that the index is in range and the serial number matches.
     *
     * Params:
     *  slot = the slot to check.
     * Returns: true if the slot is valid and its serial matches.
     */
    bool isValid(Slot slot) const {
        if (slot.index >= _length) {
            return false;
        }
        return serials[slot.index] == slot.serialNumber;
    }

    /** 
     * Get the serial number at the given index.
     *
     * Params:
     *  index = the index to query.
     * Returns: the serial number at the index, or 0 if index is out of bounds.
     */
    uint getSerial(size_t index) const {
        if (index >= _length) {
            return 0;
        }
        
        return serials[index];
    }

    /** 
     * Check if a slot is empty.
     *
     * Params:
     *  index = the index to check.
     * Returns: true if the slot is empty (serial is 0), false otherwise.
     */
    bool isEmpty(size_t index) const {
        if (index >= _length) {
            return true;
        }

        return serials[index] == 0;
    }

    /**
     * Assignment operator for copying another SlotList.
     * Creates a deep copy of the other slot list.
     *
     * Params:
     *  other = the slot list to copy from.
     */
    void opAssign(ref return scope inout typeof(this) other) {
        if (this is other) {
            return;
        }

        if (other._length == 0) {
            clear();
            return;
        }

        T* newItems = cast(T*) realloc(items, T.sizeof * other._length);
        uint* newSerials = cast(uint*) realloc(serials, uint.sizeof * other._length);
        
        if (newItems is null || newSerials is null) {
            assert(0, "Failed to allocate memory during assignment of slot list");
            return;
        }

        memset(newItems, 0, T.sizeof * other._length);
        memset(newSerials, 0, uint.sizeof * other._length);
        
        T* mutableOtherItems = cast(T*) other.items;
        uint* mutableOtherSerials = cast(uint*) other.serials;
        
        for (size_t i = 0; i < other._length; i++) {
            newItems[i] = mutableOtherItems[i];
            newSerials[i] = mutableOtherSerials[i];
        }

        items = newItems;
        serials = newSerials;
        _length = other._length;
        
        // Only other._length slots were allocated above, so capacity must match
        // that allocation (as the copy constructor does) — not other._capacity,
        // which would let a later add() write past the buffer.
        _capacity = other._length;
        nextSerial = other.nextSerial;
    }

    /**
     * Index operator for read access (const version).
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) const {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return items[i];
    }

    /**
     * Index operator for read/write access.
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return items[i];
    }

    /**
     * Dollar operator for slice expressions.
     * Allows usage like slotList[0 .. $].
     *
     * Returns: the physical length of the slot list.
     */
    size_t opDollar() {
        return _length;
    }

    /**
     * Slice operator for read/write access.
     * The returned slice directly references the internal memory buffer.
     * The slice becomes invalid if the slot list is modified in a way that reallocates memory.
     *
     * Params:
     *  i = the starting index.
     *  j = the ending index (exclusive).
     * Returns: a D array slice of the specified range.
     */
    auto opSlice(size_t i, size_t j) {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    /**
     * Slice operator for read access (const version).
     * The returned slice directly references the internal memory buffer.
     * The slice becomes invalid if the slot list is modified in a way that reallocates memory.
     *
     * Params:
     *  i = the starting index.
     *  j = the ending index (exclusive).
     * Returns: a D array slice of the specified range.
     */
    auto opSlice(size_t i, size_t j) const {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    /**
     * Index assignment operator for setting a single element.
     * Allows usage like slotList[i] = value.
     * Note: This does not affect serial numbers.
     *
     * Params:
     *  value = the value to assign.
     *  i = the index to assign to.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value, size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        items[i] = value;
        return value;
    }

    /**
     * Equality comparison operator (const SlotList by value).
     *
     * Params:
     *  other = the slot list to compare with.
     * Returns: true if slot lists have the same length, items, and serial numbers.
     */
    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    /**
     * Equality comparison operator (const SlotList by reference).
     * Compares both items and serial numbers element-by-element.
     *
     * Params:
     *  other = the slot list to compare with.
     * Returns: true if slot lists have the same length, items, and serial numbers.
     */
    bool opEquals(ref const typeof(this) other) const {
        if (other._length != _length) {
            return false;
        }

        for (size_t i = 0; i < _length; i++) {
            if (serials[i] != other.serials[i] || items[i] != other.items[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * Compute a hash of the slot list.
     * Uses a polynomial rolling hash over all non-empty items and their serial numbers.
     *
     * Returns: the hash value of the slot list.
     */
    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        for (size_t i = 0; i < _length; i++) {
            if (serials[i] != 0) {
                hash = hash * 33 + items[i].hashOf;
                hash = hash * 33 + serials[i];
            }
        }

        return hash;
    }

    /**
     * Foreach iteration support.
     * Allows iteration with `foreach (item; array)`.
     *
     * Params:
     *  dg = the delegate to call for each item.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            if (serials[i] != 0) {
                auto result = dg(items[i]);
                if (result) {
                    return result;
                }
            }
        }

        return 0;
    }

    /**
     * Foreach iteration support with index.
     * Allows iteration with `foreach (i, item; array)`.
     *
     * Params:
     *  dg = the delegate to call for each item with its index.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(size_t, ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            if (serials[i] != 0) {
                auto result = dg(i, items[i]);
                if (result) {
                    return result;
                }
            }
        }

        return 0;
    }

    private void considerResize() {
        if (items is null || serials is null || _capacity == _length) {
            resize();
        }
    }

    private void resize(size_t growSize = chunkSize) {
        items = cast(T*) realloc(items, T.sizeof * (_capacity + growSize));
        serials = cast(uint*) realloc(serials, uint.sizeof * (_capacity + growSize));
        assert(items !is null && serials !is null, "Failed to allocate memory during resizing of slot list");
        _capacity += growSize;

        if (growSize > 0) {
            for (size_t i = _capacity - growSize; i < _capacity; i++) {
                memset(&items[i], 0, T.sizeof);
                auto init = T.init;
                items[i] = init;
                serials[i] = 0;
            }
        }
    }
}

/** 
 * A doubly linked list.
 * This implementation is not thread-safe.
 */
struct LinkedList(T) {
    private alias NodePtr = LinkedListNode!T*;

    private NodePtr head;
    private NodePtr tail;

    private size_t _length;

    ~this() {
        NodePtr node = head;
        while (node !is null) {
            NodePtr next = node.next;
            node.value.destroy();
            free(node);
            node = next;
        }
    }

    /** 
     * Returns: the number of items in the list.
     */
    size_t length() const {
        return _length;
    }

    /** 
     * Add an item to the end of the list.
     *
     * Params:
     *   item = the item to add.
     */
    void add(T item) {
        NodePtr node = allocateRaw!(LinkedListNode!T);
        node.next = null;
        node.prev = null;
        node.value = item;

        if (head is null) {
            head = node;
            tail = node;
        } else {
            tail.next = node;
            node.prev = tail;
            tail = node;
        }

        _length++;
    }

    /** 
     * Remove the first item from the list.
     */
    void removeFirst() {
        if (head is null) {
            return;
        }

        NodePtr node = head;
        head = head.next;
        if (head is null) {
            tail = null;
        } else {
            head.prev = null;
        }

        free(node);
        _length--;
    }

    /** 
     * Remove the last item from the list.
     */
    void removeLast() {
        if (tail is null) {
            return;
        }

        NodePtr node = tail;
        tail = tail.prev;
        if (tail is null) {
            head = null;
        } else {
            tail.next = null;
        }

        free(node);
        _length--;
    }

    /** 
     * Remove all items from the list.
     */
    void removeAll(const T item) {
        removeItems(item, false);
    }

    /** 
     * Remove all items that satisfy the given predicate from the list.
     * Params:
     *   pred = the predicate to use.
     */
    void removeWhere(Fn)(scope Fn pred) if (!is(T == void)) {
        NodePtr node = head;
        while (node !is null) {
            NodePtr next = node.next;
            if (pred(node.value)) {
                if (node.prev is null) {
                    head = node.next;
                } else {
                    node.prev.next = node.next;
                }

                if (node.next is null) {
                    tail = node.prev;
                } else {
                    node.next.prev = node.prev;
                }

                free(node);
                _length--;
            }

            node = next;
        }
    }

    /** 
     * Remove the first item that satisfies the value equality check.
     * Params:
     *   value = the value to remove.
     */
    void removeFirst(T item) {
        removeItems(item, true);
    }

    /** 
     * Remove all items from the list.
     */
    void clear() {
        NodePtr node = head;
        while (node !is null) {
            NodePtr next = node.next;
            free(node);
            node = next;
        }

        head = null;
        tail = null;
        _length = 0;
    }

    /** 
     * Get the first item in the list.
     *
     * Returns: The first item in the list, or none if the list is empty.
     */
    Option!T first() {
        if (head is null) {
            return none!T;
        }

        return head.value.some;
    }

    /** 
     * Get the last item in the list.
     *
     * Returns: The last item in the list, or none if the list is empty.
     */
    Option!T last() {
        if (tail is null) {
            return none!T;
        }

        return tail.value.some;
    }

    /** 
     * Get the item at the given index.
     *
     * Params:
     *   index = the index of the item to get.
     * Returns: The item at the given index, or none if the index is out of bounds.
     */
    Option!T get(size_t index) {
        if (index >= _length) {
            return none!T;
        }

        NodePtr node = head;
        for (size_t i = 0; i < index; i++) {
            node = node.next;
        }

        return node.value.some;
    }

    /** 
     * Returns: An iterator over the list.
     */
    LinkedListIterator!T iterator() {
        return LinkedListIterator!T(&this);
    }

    /** 
     * Find the index of the first item with the given value.
     *
     * Params:
     *   value = the value to find.
     * Returns: The index of the first item with the given value, or -1 if the item is not found.
     */
    size_t find(T value) const {
        NodePtr node = cast(NodePtr) head;
        size_t index = 0;
        while (node !is null) {
            if (node.value == value) {
                return index;
            }

            node = node.next;
            index++;
        }

        return -1;
    }

    /**
     * Assignment operator for copying another LinkedList.
     * Creates a deep copy of the other list.
     *
     * Params:
     *  other = the list to copy from.
     */
    void opAssign(ref return scope inout typeof(this) other) {
        NodePtr node = head;
        while (node !is null) {
            NodePtr next = node.next;
            free(node);
            node = next;
        }

        _length = 0;
        node = cast(NodePtr) other.head;
        while (node !is null) {
            add(node.value);
            node = node.next;
        }
    }

    /**
     * Index operator for read access.
     * Traverses the list from the head to the specified index.
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return get(i).value;
    }

    /**
     * Dollar operator for slice expressions.
     * Allows usage like list[0 .. $].
     *
     * Returns: the length of the list.
     */
    size_t opDollar() {
        return _length;
    }

    /**
     * Slice operator.
     * Creates a new Array containing the elements in the specified range.
     * Note: This traverses the list and copies elements into an Array, not a zero-copy view.
     *
     * Params:
     *  i = the starting index.
     *  j = the ending index (exclusive).
     * Returns: a new Array containing the elements in the specified range.
     */
    Array!T opSlice(size_t dim : 0)(size_t i, size_t j) {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        assert(i <= j, "Invalid slice");

        Array!T result;
        result.capacity = j - i;
        NodePtr node = head;
        for (size_t k = 0; k < i; k++) {
            node = node.next;
        }

        for (size_t k = 0; k < result.capacity; k++) {
            result.add(node.value);
            node = node.next;
        }

        return result;
    }

    /**
     * Identity operator for slices.
     * Returns the slice as-is.
     *
     * Params:
     *  slice = the slice to return.
     * Returns: the same slice.
     */
    Array!T opIndex()(Array!T slice) {
        return slice;
    }

    /**
     * Index assignment operator for setting a single element.
     * Allows usage like list[i] = value.
     *
     * Params:
     *  value = the value to assign.
     *  i = the index to assign to.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value, size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        NodePtr node = head;
        for (size_t k = 0; k < i; k++) {
            node = node.next;
        }

        node.value = value;
        return value;
    }

    /**
     * List-wide assignment operator.
     * Assigns the same value to all elements in the list.
     * Allows usage like list[] = value.
     *
     * Params:
     *  value = the value to assign to all elements.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value) {
        NodePtr node = head;
        while (node !is null) {
            node.value = value;
            node = node.next;
        }

        return value;
    }

    /**
     * Equality comparison operator (const LinkedList by value).
     *
     * Params:
     *  other = the list to compare with.
     * Returns: true if lists have the same length and all elements are equal.
     */
    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    /**
     * Equality comparison operator (const LinkedList by reference).
     * Compares element-by-element.
     *
     * Params:
     *  other = the list to compare with.
     * Returns: true if lists have the same length and all elements are equal.
     */
    bool opEquals(ref const typeof(this) other) const {
        if (other.length != _length) {
            return false;
        }

        NodePtr node = cast(NodePtr) head;
        NodePtr otherNode = cast(NodePtr) other.head;
        while (node !is null) {
            if (node.value != otherNode.value) {
                return false;
            }

            node = node.next;
            otherNode = otherNode.next;
        }

        return true;
    }

    /** 
     * Returns: A hash of the list.
     */
    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        NodePtr node = cast(NodePtr) head;
        while (node !is null) {
            hash = hash * 33 + node.value.hashOf;
            node = node.next;
        }

        return hash;
    }

    private void removeItems(T item, bool onlyRemoveFirst) {
        NodePtr node = head;
        while (node !is null) {
            NodePtr next = node.next;
            if (node.value == item) {
                if (node.prev is null) {
                    head = node.next;
                } else {
                    node.prev.next = node.next;
                }

                if (node.next is null) {
                    tail = node.prev;
                } else {
                    node.next.prev = node.prev;
                }

                free(node);
                _length--;

                if (onlyRemoveFirst) {
                    return;
                }
            }

            node = next;
        }
    }
}

private struct LinkedListNode(T) {
    T value;
    LinkedListNode!T* next;
    LinkedListNode!T* prev;
}

/** 
 * An iterator that more efficiently allows for linear traversal
 * of a linked list.
 *
 * Each access to a LinkedList by index will start seeking from the
 * start. This iterator instead will pick up where it left off.
 *
 * This iterator is not safe to use if the list is modified while
 * iterating. It is not thread safe.
 *
 * This iterator becomes invalid when the linked list is destroyed.
 * Make sure to not use it anymore.
 *
 * Modifying the list while iterating over it using this iterator
 * can lead to undefined behavior. Be sure to finish any iteration 
 * before modifying the list and only use this iterator for modification.
 */
struct LinkedListIterator(T) {
    private alias NodePtr = LinkedListNode!T*;

    private LinkedList!T* list;

    private NodePtr node;

    // Distinguishes the "before start" position (where next() should yield
    // the head) from being positioned on a node.
    private bool beforeStart;

    this(LinkedList!T* list) {
        this.list = list;
        this.node = null;
        this.beforeStart = true;
    }

    /**
     * Returns: Whether there is another item after the current position.
     */
    bool hasNext() {
        if (beforeStart) {
            return list.head !is null;
        }

        return node !is null && node.next !is null;
    }

    /**
     * Returns: Whether there is an item before the current position.
     */
    bool hasPrevious() {
        return !beforeStart && node !is null && node.prev !is null;
    }

    /**
     * Advance to the next item and return it.
     *
     * Returns: The next item in the list, or none if there is no next item.
     */
    Option!T next() {
        if (beforeStart) {
            beforeStart = false;
            node = list.head;
        } else if (node !is null) {
            node = node.next;
        }

        if (node is null) {
            return none!T;
        }

        return node.value.some;
    }

    /**
     * Move back to the previous item and return it.
     *
     * Returns: The previous item in the list, or none if there is no previous item.
     */
    Option!T previous() {
        if (beforeStart || node is null || node.prev is null) {
            return none!T;
        }

        node = node.prev;
        return node.value.some;
    }

    /**
     * Reset the iterator to before the start of the list.
     */
    void reset() {
        node = null;
        beforeStart = true;
    }

    /**
     * Remove the item at the current position of the iterator.
     *
     * After removal the iterator is repositioned so that the next call to
     * next() yields the item that followed the removed one.
     */
    void remove() {
        if (node is null) {
            return;
        }

        NodePtr next = node.next;
        NodePtr prev = node.prev;
        if (prev !is null) {
            prev.next = next;
        }

        if (next !is null) {
            next.prev = prev;
        }

        if (list.head is node) {
            list.head = next;
        }

        if (list.tail is node) {
            list.tail = prev;
        }

        list._length--;

        free(node);

        // Reposition onto the predecessor so that next() lands on the
        // successor of the removed node. If there was no predecessor the
        // removed node was the head, so fall back to the before-start state.
        node = prev;
        if (prev is null) {
            beforeStart = true;
        }
    }

    /**
     * Insert an item directly after the current position of the iterator.
     *
     * If the iterator is positioned before the start of the list (no call to
     * next() yet), the item is inserted at the head. The cursor is not moved,
     * so the inserted item is returned by the following call to next().
     *
     * Params:
     *   value = The value to insert.
     */
    void insert(T value) {
        NodePtr newNode = allocateRaw!(LinkedListNode!T);
        newNode.value = value;

        if (node is null) {
            newNode.prev = null;
            newNode.next = list.head;
            if (list.head !is null) {
                list.head.prev = newNode;
            } else {
                list.tail = newNode;
            }

            list.head = newNode;
        } else {
            newNode.prev = node;
            newNode.next = node.next;
            if (node.next !is null) {
                node.next.prev = newNode;
            } else {
                list.tail = newNode;
            }

            node.next = newNode;
        }

        list._length++;
    }

    /**
     * Replace the item at the current position of the iterator.
     *
     * Params:
     *   value = The value to replace with.
     */
    void replace(T value) {
        if (node is null) {
            return;
        }

        node.value = value;
    }
}

private enum defaultHashMapBucketCount = 16;

private struct BucketNode(K, V) {
    K key;
    V value;
    BucketNode!(K, V)* next;
}

/**
 * A hash map that maps keys to values using separate chaining for collision
 * resolution.
 *
 * Keys must support equality comparison (==).
 * Keys with a toHash() method will have it used for hashing;
 * all other types fall back to hashOf() which hashes raw bytes.
 */
struct HashMap(K, V) {
    private alias Node = BucketNode!(K, V);
    private Node** buckets = null;
    private size_t _length = 0;
    private size_t _bucketCount = 0;

    this(ref return scope inout typeof(this) other) {
        auto mutableOther = cast(typeof(this)*) &other;
        copyFrom(*mutableOther);
    }

    ~this() {
        clear();
    }

    void opAssign(ref return scope inout typeof(this) other) {
        clear();
        auto mutableOther = cast(typeof(this)*) &other;
        copyFrom(*mutableOther);
    }

    /**
     * Insert or overwrite a key-value pair.
     * If the key already exists, its value is overwritten.
     *
     * Params:
     *   key = The key.
     *   value = The value to associate with the key.
     */
    void put(K key, V value) {
        ensureBuckets();
        auto bucketIndex = computeBucketIndex(key);
        auto node = buckets[bucketIndex];
        while (node !is null) {
            if (node.key == key) {
                node.value = value;
                return;
            }

            node = node.next;
        }

        auto newNode = cast(Node*) calloc(1, Node.sizeof);
        newNode.key = key;
        newNode.value = value;
        newNode.next = buckets[bucketIndex];
        buckets[bucketIndex] = newNode;
        _length++;
        considerRehash();
    }

    /**
     * Attempt to add a key-value pair only if the key does not already exist.
     *
     * Params:
     *   key = The key.
     *   value = The value to associate with the key.
     * Returns: true if the pair was added, false if the key already existed
     *          (value is left unchanged).
     */
    bool tryAdd(K key, V value) {
        if (contains(key)) {
            return false;
        }

        put(key, value);
        return true;
    }

    /**
     * Retrieve the value associated with a key.
     *
     * Params:
     *   key = The key to look up.
     * Returns: some(value) if the key exists, none!V otherwise.
     */
    Option!V get(K key) const {
        if (buckets is null) {
            return none!V;
        }

        auto bucketIndex = computeBucketIndex(key);
        auto node = cast(Node*) buckets[bucketIndex];
        while (node !is null) {
            if (node.key == key) {
                return some(node.value);
            }

            node = node.next;
        }

        return none!V;
    }

    /**
     * Retrieve a pointer to the value associated with a key.
     * The value can be read and modified in place through it, avoiding the
     * copy that get() makes.
     *
     * The pointer stays valid until the entry is removed or the map is
     * cleared; rehashing moves nodes between buckets but not in memory,
     * so inserting other keys does not invalidate it.
     *
     * Params:
     *   key = The key to look up.
     * Returns: some(pointer to value) if the key exists, none!(V*) otherwise.
     */
    Option!(V*) getRef(K key) {
        if (buckets is null) {
            return none!(V*);
        }

        auto bucketIndex = computeBucketIndex(key);
        auto node = buckets[bucketIndex];
        while (node !is null) {
            if (node.key == key) {
                return some(&node.value);
            }

            node = node.next;
        }

        return none!(V*);
    }

    /**
     * Retrieve the value associated with a key via an out parameter.
     *
     * Params:
     *   key = The key to look up.
     *   value = Receives the associated value if the key exists.
     * Returns: true if the key exists, false otherwise.
     */
    bool tryGet(K key, out V value) {
        auto result = get(key);
        if (result.isDefined) {
            value = result.value;
            return true;
        }

        return false;
    }

    /**
     * Remove the entry with the given key.
     *
     * Params:
     *   key = The key to remove.
     * Returns: true if the key was found and removed, false otherwise.
     */
    bool remove(K key) {
        if (buckets is null) {
            return false;
        }

        auto bucketIndex = computeBucketIndex(key);
        Node* prev = null;
        auto node = buckets[bucketIndex];
        while (node !is null) {
            if (node.key == key) {
                if (prev is null) {
                    buckets[bucketIndex] = node.next;
                } else {
                    prev.next = node.next;
                }

                node.key.destroy();
                node.value.destroy();
                free(node);
                _length--;
                return true;
            }

            prev = node;
            node = node.next;
        }

        return false;
    }

    /**
     * Returns: true if the given key exists in this map.
     */
    bool contains(K key) {
        if (buckets is null) {
            return false;
        }

        auto bucketIndex = computeBucketIndex(key);
        auto node = buckets[bucketIndex];
        while (node !is null) {
            if (node.key == key) {
                return true;
            }

            node = node.next;
        }

        return false;
    }

    /**
     * Returns: The number of key-value pairs in this map.
     */
    size_t length() const {
        return _length;
    }

    /**
     * Remove all key-value pairs, free all nodes, and free the bucket array.
     */
    void clear() {
        freeNodes();
        if (buckets !is null) {
            free(buckets);
            buckets = null;
        }

        _length = 0;
        _bucketCount = 0;
    }

    /**
     * Returns: An Array containing all keys in this map.
     */
    Array!K keys() {
        Array!K result;
        if (buckets is null) {
            return result;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                result.add(node.key);
                node = node.next;
            }
        }

        return result;
    }

    /**
     * Returns: An Array containing all values in this map.
     */
    Array!V values() {
        Array!V result;
        if (buckets is null) {
            return result;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                result.add(node.value);
                node = node.next;
            }
        }

        return result;
    }

    /**
     * Get the value at the given key.
     * Asserts if the key does not exist. Use get() for safe retrieval.
     */
    V opIndex(K key) {
        auto result = get(key);
        assert(result.isDefined, "Key not found in HashMap.");
        return result.value;
    }

    /**
     * Insert or overwrite a key-value pair.
     * Equivalent to put(key, value).
     */
    void opIndexAssign(V value, K key) {
        put(key, value);
    }

    /**
     * Iterate over all key-value pairs.
     * Usage: foreach (key, value; map) { ... }
     */
    int opApply(int delegate(ref K, ref V) dg) {
        if (buckets is null) {
            return 0;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                int result = dg(node.key, node.value);
                if (result) {
                    return result;
                }

                node = node.next;
            }
        }

        return 0;
    }

    /**
     * Iterate over all values.
     * Usage: foreach (value; map) { ... }
     */
    int opApply(int delegate(ref V) dg) {
        if (buckets is null) {
            return 0;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                int result = dg(node.value);
                if (result) {
                    return result;
                }

                node = node.next;
            }
        }

        return 0;
    }

    bool opEquals(ref const typeof(this) other) const {
        if (_length != other._length) {
            return false;
        }

        if (buckets is null) {
            return true;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = cast(Node*) buckets[i];
            while (node !is null) {
                auto otherValue = other.get(node.key);
                if (!otherValue.isDefined || otherValue.value != node.value) {
                    return false;
                }

                node = node.next;
            }
        }

        return true;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        if (buckets is null) {
            return hash;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = cast(Node*) buckets[i];
            while (node !is null) {
                ulong pairHash;
                static if (__traits(compiles, node.key.toHash())) {
                    pairHash = node.key.toHash();
                } else {
                    pairHash = hashOf(node.key);
                }

                static if (__traits(compiles, node.value.toHash())) {
                    pairHash = pairHash * 33 + node.value.toHash();
                } else {
                    pairHash = pairHash * 33 + hashOf(node.value);
                }

                hash ^= pairHash;
                node = node.next;
            }
        }

        return hash;
    }

    private void ensureBuckets() {
        if (buckets is null) {
            _bucketCount = defaultHashMapBucketCount;
            buckets = cast(Node**) calloc(_bucketCount, (Node*).sizeof);
        }
    }

    private size_t computeBucketIndex(K key) const {
        ulong hash;
        static if (__traits(hasMember, K, "toHash")) {
            hash = key.toHash();
        } else {
            hash = hashOf(key);
        }

        return cast(size_t)(hash % _bucketCount);
    }

    private void considerRehash() {
        if (_length * 4 > _bucketCount * 3) {
            rehash(_bucketCount * 2);
        }
    }

    private void rehash(size_t newBucketCount) {
        auto newBuckets = cast(Node**) calloc(newBucketCount, (Node*).sizeof);
        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                auto next = node.next;
                ulong hash;
                static if (__traits(hasMember, K, "toHash")) {
                    hash = node.key.toHash();
                } else {
                    hash = hashOf(node.key);
                }

                size_t newIndex = cast(size_t)(hash % newBucketCount);
                node.next = newBuckets[newIndex];
                newBuckets[newIndex] = node;
                node = next;
            }
        }

        free(buckets);
        buckets = newBuckets;
        _bucketCount = newBucketCount;
    }

    private void freeNodes() {
        if (buckets is null) {
            return;
        }

        for (size_t i = 0; i < _bucketCount; i++) {
            auto node = buckets[i];
            while (node !is null) {
                auto next = node.next;
                node.key.destroy();
                node.value.destroy();
                free(node);
                node = next;
            }

            buckets[i] = null;
        }
    }

    private void copyFrom(ref typeof(this) other) {
        if (other.buckets is null) {
            return;
        }

        _bucketCount = other._bucketCount;
        buckets = cast(Node**) calloc(_bucketCount, (Node*).sizeof);
        for (size_t i = 0; i < _bucketCount; i++) {
            auto srcNode = other.buckets[i];
            Node* lastNewNode = null;
            while (srcNode !is null) {
                auto newNode = cast(Node*) calloc(1, Node.sizeof);
                newNode.key = srcNode.key;
                newNode.value = srcNode.value;
                newNode.next = null;
                if (lastNewNode is null) {
                    buckets[i] = newNode;
                } else {
                    lastNewNode.next = newNode;
                }

                lastNewNode = newNode;
                srcNode = srcNode.next;
            }
        }

        _length = other._length;
    }
}

/**
 * A first-in-first-out queue backed by a circular buffer.
 * Items are stored in a contiguous memory block that wraps around, so
 * enqueueing and dequeueing never shift the remaining items.
 *
 * The queue grows automatically by `chunkSize` elements when capacity is
 * exceeded. When it grows, the items are laid out again from the start of
 * the new buffer. Memory is managed manually using malloc/free from
 * retrograde.std.memory.
 *
 * Key features:
 * - Constant time enqueue, dequeue and peek
 * - Direct indexed access to items without dequeueing them, where index 0 is the front
 * - Automatic resizing with configurable chunk size
 * - Copy and assignment operations with deep copy semantics
 *
 * This implementation is not thread-safe.
 *
 * Template_Params:
 *  T = the type of elements stored in the queue
 *  chunkSize = the number of elements to allocate when growing (default: 8)
 */
struct Queue(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0;
    private size_t _capacity = 0;
    private size_t head = 0;

    /**
     * Copy constructor.
     * Creates a deep copy of another queue. Items retain their order.
     *
     * Params:
     *  other = the queue to copy from.
     */
    this(ref return scope inout typeof(this) other) {
        copyFrom(other);
    }

    /**
     * Constructor from a D array.
     * Creates a deep copy of the given array, where the first element of the
     * array becomes the front of the queue.
     *
     * Params:
     *  other = the D array to copy from.
     */
    this(scope inout T[] other) {
        copyFrom(other);
    }

    /**
     * Destructor.
     * Automatically clears and deallocates all memory.
     */
    ~this() {
        clear();
    }

    /**
     * Returns: the amount of items currently in the queue.
     */
    size_t length() const {
        return _length;
    }

    /**
     * Returns: the allocated capacity of the queue in number of items.
     */
    size_t capacity() const {
        return _capacity;
    }

    /**
     * Returns: whether the queue contains no items.
     */
    bool isEmpty() const {
        return _length == 0;
    }

    /**
     * Add an item to the back of the queue.
     * Alternatively, you can use the ~= operator to enqueue an item.
     *
     * Params:
     *  item = the item to add.
     */
    void enqueue(T item) {
        considerResize();

        if (items is null) {
            return;
        }

        items[slotIndex(_length)] = item;
        _length++;
    }

    /**
     * Remove the item at the front of the queue and return it.
     * The queue no longer owns the returned item.
     *
     * Returns: a successful result with the dequeued item, or a failure when the queue is empty.
     */
    Result!T dequeue() {
        if (_length == 0) {
            return failure!T("Cannot dequeue from an empty queue");
        }

        size_t index = head;
        T item = items[index];
        items[index].destroy();
        head = slotIndex(1);
        _length--;
        return success(item);
    }

    /**
     * Remove the item at the front of the queue, if there is any.
     * The queue no longer owns the returned item.
     *
     * Params:
     *  item = out parameter that receives the dequeued item. Left at its initial value when the queue is empty.
     * Returns: true when an item was dequeued, false when the queue is empty.
     */
    bool tryDequeue(out T item) {
        auto result = dequeue();
        if (result.isFailure) {
            return false;
        }

        // Assigned via a local because types with a copy-assignment operator
        // cannot be assigned from the rvalue that value() returns.
        auto value = result.value;
        item = value;
        return true;
    }

    /**
     * Look at the item at the front of the queue without removing it.
     *
     * Returns: a successful result with the item at the front, or a failure when the queue is empty.
     */
    Result!T peek() {
        if (_length == 0) {
            return failure!T("Cannot peek into an empty queue");
        }

        return success(items[head]);
    }

    /**
     * Clear all items in the queue.
     * Calls destructors on all items and deallocates memory.
     * After calling this, length and capacity will both be 0.
     */
    void clear() {
        if (items !is null) {
            for (size_t i = 0; i < _length; i++) {
                items[slotIndex(i)].destroy();
            }

            free(items);
            items = null;
        }

        _length = 0;
        _capacity = 0;
        head = 0;
    }

    /**
     * Assignment operator for copying another Queue.
     * Creates a deep copy of the other queue.
     *
     * Params:
     *  other = the queue to copy from.
     */
    void opAssign(ref return scope inout typeof(this) other) {
        if (this is other) {
            return;
        }

        clear();
        copyFrom(other);
    }

    /**
     * Assignment operator for copying a D array.
     * Creates a deep copy of the given array, where the first element of the
     * array becomes the front of the queue.
     *
     * Params:
     *  other = the D array to copy from.
     */
    void opAssign(scope inout T[] other) {
        clear();
        copyFrom(other);
    }

    /**
     * Append operator (~=) for enqueueing a single item.
     * Equivalent to calling enqueue().
     *
     * Params:
     *  rhs = the item to enqueue.
     */
    void opOpAssign(string op : "~")(T rhs) {
        enqueue(rhs);
    }

    /**
     * Index operator for read access.
     * Index 0 is the item at the front of the queue, the one that would be dequeued next.
     * Accessing an item does not remove it from the queue.
     *
     * Params:
     *  i = the index of the item to access.
     * Returns: the item at the given index.
     */
    auto opIndex(size_t i) {
        assert(i < _length, "Index out of bounds");
        return items[slotIndex(i)];
    }

    /// Idem
    auto opIndex(size_t i) const {
        assert(i < _length, "Index out of bounds");
        return items[slotIndex(i)];
    }

    /**
     * Dollar operator for index expressions.
     * Allows usage like queue[$ - 1].
     *
     * Returns: the length of the queue.
     */
    size_t opDollar() const {
        return _length;
    }

    /**
     * Index assignment operator for replacing a single item.
     * Index 0 is the item at the front of the queue.
     *
     * Params:
     *  value = the value to assign.
     *  i = the index to assign to.
     * Returns: the assigned value.
     */
    T opIndexAssign(T value, size_t i) {
        assert(i < _length, "Index out of bounds");
        items[slotIndex(i)] = value;
        return value;
    }

    /**
     * Equality comparison operator (const D array by reference).
     * Compares element-by-element, from the front of the queue to the back.
     *
     * Params:
     *  other = the D array to compare with.
     * Returns: true if the queue and array have the same length and all elements are equal.
     */
    bool opEquals(ref const T[] other) const {
        return equalsArray(other);
    }

    /**
     * Equality comparison operator (const D array by value).
     *
     * Params:
     *  other = the D array to compare with.
     * Returns: true if the queue and array have the same length and all elements are equal.
     */
    bool opEquals(const T[] other) const {
        return equalsArray(other);
    }

    /**
     * Equality comparison operator (const Queue by reference).
     * Compares element-by-element, from the front of the queue to the back.
     *
     * Params:
     *  other = the queue to compare with.
     * Returns: true if both queues have the same length and all elements are equal.
     */
    bool opEquals(ref const typeof(this) other) const {
        return equalsQueue(other);
    }

    /**
     * Equality comparison operator (const Queue by value).
     *
     * Params:
     *  other = the queue to compare with.
     * Returns: true if both queues have the same length and all elements are equal.
     */
    bool opEquals(const typeof(this) other) const {
        return equalsQueue(other);
    }

    /**
     * Compute a hash of the queue.
     * Uses a polynomial rolling hash over all elements, from front to back.
     *
     * Returns: the hash value of the queue.
     */
    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        for (size_t i = 0; i < _length; i++) {
            hash = hash * 33 + items[slotIndex(i)].hashOf;
        }

        return hash;
    }

    /**
     * Foreach iteration support.
     * Iterates from the front of the queue to the back without dequeueing.
     *
     * Params:
     *  dg = the delegate to call for each item.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            auto result = dg(items[slotIndex(i)]);
            if (result) {
                return result;
            }
        }

        return 0;
    }

    /**
     * Foreach iteration support with index.
     * Iterates from the front of the queue to the back without dequeueing.
     *
     * Params:
     *  dg = the delegate to call for each item with its index.
     * Returns: non-zero if iteration was stopped early, 0 otherwise.
     */
    int opApply(int delegate(size_t, ref T) dg) {
        foreach (size_t i; 0 .. _length) {
            auto result = dg(i, items[slotIndex(i)]);
            if (result) {
                return result;
            }
        }

        return 0;
    }

    private bool equalsArray(const T[] other) const {
        if (other.length != _length) {
            return false;
        }

        for (size_t i = 0; i < _length; i++) {
            if (items[slotIndex(i)] != other[i]) {
                return false;
            }
        }

        return true;
    }

    private bool equalsQueue(ref const typeof(this) other) const {
        if (other._length != _length) {
            return false;
        }

        for (size_t i = 0; i < _length; i++) {
            if (items[slotIndex(i)] != other.items[other.slotIndex(i)]) {
                return false;
            }
        }

        return true;
    }

    private size_t slotIndex(size_t i) const {
        assert(_capacity > 0, "Queue has no capacity");

        // head is always below the capacity and i never exceeds the length, so
        // the sum wraps around the buffer at most once. A conditional
        // subtraction is therefore enough and avoids a division.
        size_t index = head + i;
        return index >= _capacity ? index - _capacity : index;
    }

    private void considerResize() {
        if (items is null || _length == _capacity) {
            resize(chunkSize);
        }
    }

    private void resize(size_t growSize) {
        size_t newCapacity = _capacity + growSize;
        T* newItems = cast(T*) malloc(T.sizeof * newCapacity);
        assert(newItems !is null, "Failed to allocate memory during resizing of queue");
        if (newItems is null) {
            return;
        }

        memset(newItems, 0, T.sizeof * newCapacity);

        // Items are moved to the front of the new buffer as raw memory so that
        // they are relocated instead of copied; the old buffer is abandoned
        // without destructing them.
        for (size_t i = 0; i < _length; i++) {
            memcpy(&newItems[i], &items[slotIndex(i)], T.sizeof);
        }

        for (size_t i = _length; i < newCapacity; i++) {
            auto init = T.init;
            newItems[i] = init;
        }

        if (items !is null) {
            free(items);
        }

        items = newItems;
        _capacity = newCapacity;
        head = 0;
    }

    private void copyFrom(ref inout typeof(this) other) {
        if (other._length == 0) {
            return;
        }

        items = cast(T*) malloc(T.sizeof * other._length);
        assert(items !is null, "Failed to allocate memory during copy of queue");
        if (items is null) {
            return;
        }

        memset(items, 0, T.sizeof * other._length);
        // Cast away inout to allow assignment
        T* mutableOtherItems = cast(T*) other.items;
        for (size_t i = 0; i < other._length; i++) {
            items[i] = mutableOtherItems[other.slotIndex(i)];
        }

        _length = other._length;
        _capacity = other._length;
        head = 0;
    }

    private void copyFrom(scope inout T[] other) {
        if (other.length == 0) {
            return;
        }

        items = cast(T*) malloc(T.sizeof * other.length);
        assert(items !is null, "Failed to allocate memory during copy of queue");
        if (items is null) {
            return;
        }

        memset(items, 0, T.sizeof * other.length);
        // Cast away inout to allow assignment
        T[] mutableOther = cast(T[]) other;
        for (size_t i = 0; i < other.length; i++) {
            items[i] = mutableOther[i];
        }

        _length = other.length;
        _capacity = other.length;
        head = 0;
    }
}

version (UnitTesting)  :  ///

import retrograde.std.dlang : CopyConstructors;

private struct InnerArrayOwner {
    Array!int values;
    int tag;

    mixin CopyConstructors!InnerArrayOwner;
}

void runCollectionsTests() {
    runArrayTests();
    runSlotListTests();
    runLinkedListTests();
    runHashMapTests();
    runQueueTests();
}

void runArrayTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Array tests --");

    test("Create an Array", () {
        Array!int array;
        assert(array.length == 0);
        assert(array.capacity == 0);
    });

    test("Add item to an Array", () {
        Array!int array;
        auto index = array.add(1);
        assert(index == 0);
        assert(array.length == 1);
        assert(array.capacity == defaultChunkSize);
        assert(array[0] == 1);
    });

    test("Add item to an Array with concat operator", () {
        Array!int array;
        array ~= 1;
        assert(array.length == 1);
        assert(array.capacity == defaultChunkSize);
        assert(array[0] == 1);
    });

    test("Make a copy of array through assignment", () {
        Array!int array;
        array.add(1);
        array.add(2);
        array.add(3);
        auto array2 = array;
        array.add(4);
        array2.add(5);
        assert(array.length == 4);
        assert(array2.length == 4);
        assert(array.capacity == defaultChunkSize);
        assert(array2.capacity == defaultChunkSize + 3);
        assert(array[0 .. 4] == [1, 2, 3, 4]);
        assert(array2[0 .. 4] == [1, 2, 3, 5]);
    });

    test("Assign Array element through index", () {
        Array!int array;
        array.add(1);
        array.add(2);
        array.add(3);
        array[1] = 5;
        assert(array[1] == 5);
        assert(array[0 .. 3] == [1, 5, 3]);
    });

    test("Opdollar points to last element", () {
        Array!int array;
        array.add(1);
        array.add(2);
        array.add(5);
        assert(array.opDollar == 3);
        assert(array[$ - 1] == 5);
    });

    test("Slice of Array", () {
        Array!int array;
        array.add(1);
        array.add(2);
        array.add(3);
        array.add(4);
        array.add(5);
        assert(array[1 .. 4] == [2, 3, 4]);
    });

    test("Assign all values of Array", () {
        Array!int array;
        array.add(1);
        array.add(2);
        array.add(3);
        array[] = 5;
        assert(array[0 .. 3] == [5, 5, 5]);
    });

    test("Initialize Array through static assignment", () {
        Array!int array = [1, 2, 3, 4, 5];
        assert(array.length == 5);
        assert(array.capacity == 5);
        assert(array[0 .. 5] == [1, 2, 3, 4, 5]);
    });

    test("Concat two Arrays", () {
        Array!int array = [1, 2, 3];
        Array!int array2 = [4, 5, 6];
        array ~= array2;
        assert(array[0 .. 6] == [1, 2, 3, 4, 5, 6]);
        assert(array._length == 6);
        assert(array._capacity == defaultChunkSize + 3);
    });

    test("Create new Array by concatting two Arrays in binary manner", () {
        Array!int array = [1, 2, 3];
        Array!int array2 = [4, 5, 6];
        auto array3 = array ~ array2;
        assert(array3[0 .. 6] == [1, 2, 3, 4, 5, 6]);
    });

    test("Create new Array by concatting an Array and element", () {
        Array!int array = [1, 2, 3];
        auto array2 = array ~ 4;
        assert(array2[0 .. 4] == [1, 2, 3, 4]);
    });

    test("Clear an Array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.clear();
        assert(array.length == 0);
        assert(array.capacity == 0);
        assert(array.items is null);
    });

    test("Truncate an Array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.truncate(3);
        assert(array.length == 3);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [1, 2, 3]);
    });

    test("Increase Array capacity", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.capacity = 10;
        assert(array.length == 5);
        assert(array.capacity == 10);
        assert(array[0 .. $] == [1, 2, 3, 4, 5]);
    });

    test("Set Array capacity to zero", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.capacity = 0;
        assert(array.length == 0);
        assert(array.capacity == 0);
    });

    test("Reduce Array by reducing capacity", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.capacity = 3;
        assert(array.length == 3);
        assert(array.capacity == 3);
        assert(array[0 .. $] == [1, 2, 3]);
    });

    test("Remove an item from the middle of the array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.remove(1);
        assert(array.length == 4);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [1, 3, 4, 5]);
    });

    test("Remove an item from the start of the array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.remove(0);
        assert(array.length == 4);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [2, 3, 4, 5]);
    });

    test("Remove an item from the end of the array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.remove(4);
        assert(array.length == 4);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [1, 2, 3, 4]);
    });

    test("Replace an item in the middle of the array", () {
        Array!int array = [1, 2, 3, 4, 5];
        array.replace(1, 10);
        assert(array.length == 5);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [1, 10, 3, 4, 5]);
    });

    test("Compare two Arrays for equality", () {
        Array!int array = [1, 2, 3, 4, 5];
        Array!int array2 = [1, 2, 3, 4, 5];
        assert(array == array2);
    });

    test("Find item in Array", () {
        Array!int array = [1, 2, 3, 4, 5];
        assert(array.find(3) == 2);
    });

    test("Exists returns whether items exist in the Array", () {
        Array!int array = [1, 2, 3, 4, 5];
        assert(array.exists(4));
        assert(!array.exists(6));
    });

    test("Find item in Array returns -1 when not found", () {
        Array!int array = [1, 2, 3, 4, 5];
        assert(array.find(10) == -1);
    });

    test("Compare two Arrays by hash", () {
        Array!int array = [1, 2, 3, 4, 5];
        Array!int array2 = [1, 2, 3, 4, 5];
        assert(array.toHash() == array2.toHash());
    });

    test("Assign an array to another array", () {
        Array!int array = [1, 2, 3, 4, 5];
        Array!int array2 = [6, 7, 8, 9, 10];
        array = array2;
        assert(array.length == 5);
        assert(array.capacity == 5);
        assert(array[0 .. $] == [6, 7, 8, 9, 10]);
    });

    test("Assigning a chunk-grown array keeps capacity in sync with its allocation", () {
        // Regression: opAssign allocates other._length slots but used to set
        // _capacity = other._capacity. When the source grew via add() (so
        // capacity > length), the destination claimed spare capacity it never
        // allocated, and the next add() wrote one slot past the buffer.
        Array!int source;
        source.add(1);
        assert(source.length == 1);
        assert(source.capacity == defaultChunkSize);

        Array!int dest;
        dest = source;
        assert(dest.length == 1);
        assert(dest.capacity == 1); // Must match the slots actually allocated.

        // Before the fix this landed one slot past the buffer (heap overflow).
        dest.add(2);
        dest.add(3);
        assert(dest.length == 3);
        assert(dest[0 .. $] == [1, 2, 3]);
    });

    test("Indexing an Array of structs with inner Arrays by value is safe", () {
        // Regression: structs that own inner Arrays (via CopyConstructors) were
        // suspected of driving Array.opAssign with an uninitialized `this` when
        // opIndex returned them by value. The by-value copy is construction (the
        // copy constructor allocates fresh), not opAssign, so the pattern is
        // safe. Iterate by value repeatedly to guard against regressions.
        // InnerArrayOwner must stay at module scope; declaring it in this
        // lambda traps on WASM — see docs/wasm-pitfalls.md.
        Array!InnerArrayOwner items;
        for (int i = 0; i < 8; i++) {
            InnerArrayOwner inner;
            inner.values.add(i);
            inner.values.add(i * 2);
            inner.tag = 100 + i;
            items.add(inner);
        }

        long acc = 0;
        for (int iter = 0; iter < 50; iter++) {
            for (size_t i = 0; i < items.length; i++) {
                acc += items[i].tag; // by-value InnerArrayOwner copy
                acc += items[i].values.length; // by-value InnerArrayOwner copy again
            }
        }

        assert(items.length == 8);
        assert(acc == 42_200); // 50 * (sum(100..107) + 8 * 2)
    });

    test("Copy empty array", () {
        Array!int empty1;
        auto empty2 = empty1;
        assert(empty1.length == 0);
        assert(empty2.length == 0);
    });

    test("Assign filled array to empty array", () {
        Array!ubyte empty;
        Array!ubyte filled = [0x1, 0x2, 0x3];
        empty = filled;
        assert(empty.length == 3);
        assert(filled.length == 3);
    });

    test("Assign static array to array", () {
        Array!int array;
        array = [0x1, 0x2, 0x3];
        assert(array.length == 3);
        assert(array[0 .. $] == [0x1, 0x2, 0x3]);
    });

    test("Add returns correct index", () {
        Array!int array;
        assert(array.add(10) == 0);
        assert(array.add(20) == 1);
        assert(array.add(30) == 2);
        assert(array[0] == 10);
        assert(array[1] == 20);
        assert(array[2] == 30);
    });

    test("Continuously growing array", () {
        // To test memory reallocation

        Array!int array;
        for (int i = 0; i < 128; i++) {
            auto index = array.add(i);
            assert(index == i);
        }

        assert(array[0 .. $] == [
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
                19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
                36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
                53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
                70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86,
                87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102,
                103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115,
                116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127
            ]);
    });
}

void runLinkedListTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- LinkedList tests --");

    test("Add items to LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        assert(list.length == 2);
        assert(list.first.value == 1);
        assert(list.last.value == 2);
    });

    test("Remove first item from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.removeFirst();
        assert(list.length == 1);
        assert(list.first.value == 2);
        assert(list.last.value == 2);
        assert(list.first is list.last);
    });

    test("Remove last item from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.removeLast();
        assert(list.length == 1);
        assert(list.first.value == 1);
        assert(list.last.value == 1);
        assert(list.first is list.last);
    });

    test("Clear all items from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.clear();
        assert(list.length == 0);
        assert(list.first.isEmpty);
        assert(list.last.isEmpty);
    });

    test("Remove all items with specified value from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.removeAll(1);
        assert(list.length == 3);
        assert(list.first.value == 2);
        assert(list.last.value == 2);
    });

    test("Remove all items that match the given predicate from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.removeWhere((const ref int value) => value == 1);
        assert(list.length == 3);
        assert(list.first.value == 2);
        assert(list.last.value == 2);
    });

    test("Remove the first item with specified value from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.add(1);
        list.add(2);
        list.removeFirst(1);
        assert(list.length == 5);
        assert(list.first.value == 2);
        assert(list.last.value == 2);
    });

    test("Access LinkedList element by using get", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        assert(list.get(0).value == 1);
        assert(list.get(1).value == 2);
        assert(list.get(2).value == 3);
        assert(list.get(3) == none!int);
    });

    test("Access LinkedList element by index", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        assert(list[0] == 1);
        assert(list[1] == 2);
        assert(list[$ - 1] == 3);
    });

    test("Get slice from LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        list.add(4);
        list.add(5);
        int[5] expected = [1, 2, 3, 4, 5];

        assert(list[0 .. 1] == expected[0 .. 1]);
        assert(list[0 .. 2] == expected[0 .. 2]);
        assert(list[0 .. 3] == expected[0 .. 3]);
        assert(list[0 .. 4] == expected[0 .. 4]);
        assert(list[0 .. $] == expected);
        assert(list[1 .. 2] == expected[1 .. 2]);
        assert(list[3 .. $] == expected[3 .. $]);
    });

    test("Assign different value to item in LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        list[1] = 10;
        assert(list[0] == 1);
        assert(list[1] == 10);
        assert(list[2] == 3);
    });

    test("Assign different value to all items in LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        list[] = 10;
        assert(list[0] == 10);
        assert(list[1] == 10);
        assert(list[2] == 10);
    });

    test("Compare two LinkedLists for equality", () {
        LinkedList!int list1;
        LinkedList!int list2;
        list1.add(1);
        list1.add(2);
        list1.add(3);
        list2.add(1);
        list2.add(2);
        list2.add(3);
        assert(list1 == list2);
    });

    test("Iterate over a LinkedList using a LinkedListIterator", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        int[3] expected = [1, 2, 3];
        auto iterator = list.iterator;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Iterate over a LinkedList using a LinkedListIterator and then back", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        int[3] expected = [1, 2, 3];
        auto iterator = list.iterator;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }

        // The cursor rests on the last item (3); stepping back visits 2 then 1.
        int[2] expectedBack = [2, 1];
        i = 0;
        while (iterator.hasPrevious) {
            assert(iterator.previous.value == expectedBack[i++]);
        }
    });

    test("Iterate over a LinkedList using a LinkedListIterator and then reset it", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        int[3] expected = [1, 2, 3];
        auto iterator = list.iterator;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }

        iterator.reset;
        i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Remove item in LinkedListIterator", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        auto iterator = list.iterator;
        iterator.next;
        iterator.remove;
        assert(list.length == 2);

        int[2] expected = [2, 3];
        iterator.reset;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Remove every item while iterating in a single pass", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        auto iterator = list.iterator;
        while (iterator.hasNext) {
            iterator.next;
            iterator.remove;
        }

        assert(list.length == 0);
    });

    test("Remove only matching items while iterating in a single pass", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        list.add(4);
        auto iterator = list.iterator;
        while (iterator.hasNext) {
            if (iterator.next.value % 2 == 0) {
                iterator.remove;
            }
        }

        assert(list.length == 2);

        int[2] expected = [1, 3];
        iterator.reset;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Remove the tail item via the iterator keeps add working", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        auto iterator = list.iterator;
        iterator.next;
        iterator.next;
        iterator.remove; // removes tail (2)
        assert(list.length == 1);

        list.add(3); // must append correctly after tail was removed

        int[2] expected = [1, 3];
        iterator.reset;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Insert item in LinkedListIterator", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        auto iterator = list.iterator;
        iterator.next;
        iterator.insert(10);
        assert(list.length == 4);

        int[4] expected = [1, 10, 2, 3];
        iterator.reset;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Replace item in LinkedListIterator", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        auto iterator = list.iterator;
        iterator.next;
        iterator.replace(10);
        assert(list.length == 3);

        int[3] expected = [10, 2, 3];
        iterator.reset;
        int i = 0;
        while (iterator.hasNext) {
            assert(iterator.next.value == expected[i++]);
        }
    });

    test("Using get on an empty list returns none", () {
        LinkedList!int list;
        assert(list.get(0) == none!int);
    });

    test("Removing items in an empty list does nothing", () {
        LinkedList!int list;
        list.removeFirst();
        list.removeLast();
        list.removeAll(0);
        list.removeWhere((const ref int i) => i == 0);
        assert(list.length == 0);
    });

    test("Getting first from empty list returns none", () {
        LinkedList!int list;
        assert(list.first == none!int);
    });

    test("Getting last from empty list returns none", () {
        LinkedList!int list;
        assert(list.last == none!int);
    });

    test("Getting iterator from empty list returns none on next", () {
        LinkedList!int list;
        auto iterator = list.iterator;
        assert(iterator.next == none!int);
    });

    test("Empty lists are equal when compared", () {
        LinkedList!int list1;
        LinkedList!int list2;
        assert(list1 == list2);
    });

    test("Find item in LinkedList", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        assert(list.find(2) == 1);
    });

    test("Find item in LinkedList returns -1 when not found", () {
        LinkedList!int list;
        list.add(1);
        list.add(2);
        list.add(3);
        assert(list.find(4) == -1);
    });

    test("Compare two LinkedLists by hash", () {
        LinkedList!int list1;
        LinkedList!int list2;
        list1.add(1);
        list1.add(2);
        list1.add(3);
        list2.add(1);
        list2.add(2);
        list2.add(3);
        assert(list1.toHash() == list2.toHash());
    });

    test("Assing LinkedList to another LinkedList", () {
        LinkedList!int list1;
        LinkedList!int list2;
        list1.add(1);
        list1.add(2);
        list1.add(3);
        list2 = list1;
        assert(list1 == list2);
    });
}

void runSlotListTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- SlotList tests --");

    test("Create a SlotList", () {
        SlotList!int list;
        assert(list.length == 0);
        assert(list.physicalLength == 0);
        assert(list.capacity == 0);
    });

    test("Add item to a SlotList", () {
        SlotList!int list;
        auto result = list.add(42);
        assert(result.isSuccessful);
        auto slot = result.value;
        assert(slot.index == 0);
        assert(slot.serialNumber == 1);
        assert(list.length == 1);
        assert(list.physicalLength == 1);
        assert(list.capacity == defaultChunkSize);
        assert(list[0] == 42);
        assert(list.getSerial(0) == 1);
    });

    test("Add multiple items to SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        assert(list.length == 3);
        assert(list.physicalLength == 3);
        assert(list[0] == 10);
        assert(list[1] == 20);
        assert(list[2] == 30);
        assert(list.getSerial(0) == 1);
        assert(list.getSerial(1) == 2);
        assert(list.getSerial(2) == 3);
    });

    test("Remove item from SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.remove(1);
        assert(list.length == 2); // Non-empty count
        assert(list.physicalLength == 3); // Physical length unchanged
        assert(list[0] == 10);
        assert(list[2] == 30);
        assert(list.getSerial(0) == 1);
        assert(list.getSerial(1) == 0); // Serial is 0 for removed item
        assert(list.getSerial(2) == 3);
        assert(list.isEmpty(1));
        assert(!list.isEmpty(0));
        assert(!list.isEmpty(2));
    });

    test("Add item to slot after removal", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.remove(1);
        auto result = list.add(99);
        assert(result.isSuccessful);
        auto slot = result.value;
        assert(slot.index == 1); // Reuses the empty slot
        assert(slot.serialNumber == 4); // New serial number
        assert(list.length == 3);
        assert(list.physicalLength == 3);
        assert(list[1] == 99);
        assert(list.getSerial(1) == 4);
    });

    test("Replace item in SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.replace(1, 99);
        assert(list[1] == 99);
        assert(list.getSerial(1) == 2); // Serial unchanged
    });

    test("Replace item in empty slot does nothing", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.remove(1);
        list.replace(1, 99);
        assert(list.getSerial(1) == 0); // Still empty
        assert(list.isEmpty(1));
    });

    test("Find item in SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        auto result = list.find(20);
        assert(result.isSuccessful);
        assert(result.value.index == 1);
        assert(!list.find(99).isSuccessful);
    });

    test("Find skips empty slots", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(10);
        list.remove(0);
        auto result = list.find(10);
        assert(result.isSuccessful);
        assert(result.value.index == 2); // Finds the second 10, not the removed one
    });

    test("Exists checks for item in SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        assert(list.exists(10));
        assert(list.exists(20));
        assert(!list.exists(99));
    });

    test("FindItemBySerial returns item with given serial", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        auto item = list.findItemBySerial(2);
        assert(item.isDefined);
        assert(item.value == 20);
    });

    test("FindItemBySerial returns none for non-existent serial", () {
        SlotList!int list;
        list.add(10);
        auto item = list.findItemBySerial(99);
        assert(item.isEmpty);
    });

    test("FindIndexBySerial returns index of item with given serial", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        assert(list.findIndexBySerial(1) == 0);
        assert(list.findIndexBySerial(2) == 1);
        assert(list.findIndexBySerial(3) == 2);
        assert(list.findIndexBySerial(99) == -1);
    });

    test("FindIndexBySerial works after removal", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        auto serial2 = list.getSerial(1);
        list.remove(1);
        assert(list.findIndexBySerial(serial2) == -1); // Removed item not found
        assert(list.findIndexBySerial(3) == 2); // Other items still found
    });

    test("FindSlotBySerial returns slot with given serial", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        auto slot = list.findSlotBySerial(2);
        assert(slot.isDefined);
        assert(slot.value.index == 1);
        assert(slot.value.serialNumber == 2);
    });

    test("FindSlotBySerial returns none for non-existent serial", () {
        SlotList!int list;
        list.add(10);
        auto slot = list.findSlotBySerial(99);
        assert(slot.isEmpty);
    });

    test("FindSlotByIndex returns slot for valid index", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        auto slot = list.findSlotByIndex(1);
        assert(slot.isDefined);
        assert(slot.value.index == 1);
        assert(slot.value.serialNumber == 2);
    });

    test("FindSlotByIndex returns none for empty slot", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.remove(1);
        auto slot = list.findSlotByIndex(1);
        assert(slot.isEmpty);
    });

    test("FindSlotByIndex returns none for out of range index", () {
        SlotList!int list;
        list.add(10);
        auto slot = list.findSlotByIndex(99);
        assert(slot.isEmpty);
    });

    test("Compact defragments SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.add(40);
        list.add(50);
        auto serial2 = list.getSerial(1);
        auto serial4 = list.getSerial(3);
        list.remove(1);
        list.remove(3);
        
        assert(list.length == 3); // Non-empty count
        assert(list.physicalLength == 5); // Physical length before compact
        
        list.compact();
        
        assert(list.length == 3); // Still 3 items
        assert(list.physicalLength == 3); // Physical length now matches
        assert(list[0] == 10);
        assert(list[1] == 30);
        assert(list[2] == 50);
        assert(list.getSerial(0) == 1);
        assert(list.getSerial(1) == 3);
        assert(list.getSerial(2) == 5);
        
        // Old serials can still be found at new indices
        assert(list.findIndexBySerial(serial2) == -1); // Removed serials not found
        assert(list.findIndexBySerial(serial4) == -1);
    });

    test("Clear SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.clear();
        assert(list.length == 0);
        assert(list.physicalLength == 0);
        assert(list.capacity == 0);
    });

    test("Truncate SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.add(40);
        list.add(50);
        list.truncate(3);
        assert(list.length == 3);
        assert(list.physicalLength == 3);
        assert(list[0] == 10);
        assert(list[1] == 20);
        assert(list[2] == 30);
    });

    test("Increase SlotList capacity", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.capacity = 20;
        assert(list.length == 2);
        assert(list.physicalLength == 2);
        assert(list.capacity == 20);
    });

    test("Set SlotList capacity to zero", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.capacity = 0;
        assert(list.length == 0);
        assert(list.capacity == 0);
    });

    test("Compare two SlotLists for equality", () {
        SlotList!int list1;
        SlotList!int list2;
        list1.add(10);
        list1.add(20);
        list1.add(30);
        list2.add(10);
        list2.add(20);
        list2.add(30);
        assert(list1 == list2);
    });

    test("SlotLists with different serials are not equal", () {
        SlotList!int list1;
        SlotList!int list2;
        list1.add(10);
        list1.add(20);
        list2.add(99); // Different serial sequence
        list2.remove(0);
        list2.add(10);
        list2.add(20);
        assert(list1 != list2); // Same values but different serials
    });

    test("Hash of SlotList", () {
        SlotList!int list1;
        SlotList!int list2;
        list1.add(10);
        list1.add(20);
        list1.add(30);
        list2.add(10);
        list2.add(20);
        list2.add(30);
        assert(list1.toHash() == list2.toHash());
    });

    test("Assign SlotList to another SlotList", () {
        SlotList!int list1;
        SlotList!int list2;
        list1.add(10);
        list1.add(20);
        list1.add(30);
        list2 = list1;
        assert(list1 == list2);
        assert(list2[0] == 10);
        assert(list2[1] == 20);
        assert(list2[2] == 30);
    });

    test("Assigning a chunk-grown SlotList keeps capacity in sync with its allocation", () {
        // Regression: like Array.opAssign, SlotList.opAssign allocates
        // other._length slots but used to set _capacity = other._capacity, so a
        // later add() could append past the items/serials buffers.
        SlotList!int source;
        source.add(1);
        assert(source.physicalLength == 1);
        assert(source.capacity == defaultChunkSize);

        SlotList!int dest;
        dest = source;
        assert(dest.physicalLength == 1);
        assert(dest.capacity == 1); // Must match the slots actually allocated.

        // Before the fix these appends landed past the buffers (heap overflow).
        dest.add(2);
        dest.add(3);
        assert(dest.physicalLength == 3);
        assert(dest[0] == 1);
        assert(dest[1] == 2);
        assert(dest[2] == 3);
    });

    test("Copy constructor creates independent copy", () {
        SlotList!int list1;
        list1.add(10);
        list1.add(20);
        auto list2 = list1;
        list1.add(30);
        list2.add(40);
        assert(list1.length == 3);
        assert(list2.length == 3);
        assert(list1[2] == 30);
        assert(list2[2] == 40);
    });

    test("OpDollar points to last slot", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        assert(list.opDollar == 3);
        assert(list[$ - 1] == 30);
    });

    test("Slice of SlotList", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.add(40);
        list.add(50);
        assert(list[1 .. 4] == [20, 30, 40]);
    });

    test("Assign value by index", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list[1] = 99;
        assert(list[1] == 99);
        assert(list.getSerial(1) == 2); // Serial unchanged
    });

    test("Iterate over SlotList with opApply", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.remove(1);
        
        int sum = 0;
        foreach (item; list) {
            sum += item;
        }
        assert(sum == 40); // Only non-empty slots
    });

    test("Iterate over SlotList with index", () {
        SlotList!int list;
        list.add(10);
        list.add(20);
        list.add(30);
        list.remove(1);
        
        size_t count = 0;
        size_t lastIndex = 0;
        foreach (index, item; list) {
            if (count == 0) {
                assert(index == 0);
                assert(item == 10);
            } else if (count == 1) {
                assert(index == 2); // Index 1 was skipped
                assert(item == 30);
            }
            lastIndex = index;
            count++;
        }
        assert(count == 2);
        assert(lastIndex == 2);
    });

    test("Continuously growing SlotList", () {
        SlotList!int list;
        for (int i = 0; i < 64; i++) {
            auto result = list.add(i);
            assert(result.isSuccessful);
            auto slot = result.value;
            assert(slot.index == i);
            assert(slot.serialNumber == i + 1);
        }
        assert(list.length == 64);
        assert(list.physicalLength == 64);
        for (int i = 0; i < 64; i++) {
            assert(list[i] == i);
            assert(list.getSerial(i) == i + 1);
        }
    });

    test("Empty SlotList operations", () {
        SlotList!int list;
        assert(!list.find(10).isSuccessful);
        assert(!list.exists(10));
        assert(list.findItemBySerial(1).isEmpty);
        assert(list.findIndexBySerial(1) == -1);
        assert(list.getSerial(0) == 0);
        assert(list.isEmpty(0));
        list.remove(0); // Should not crash
        list.replace(0, 10); // Should not crash
        list.compact(); // Should not crash
    });

    test("Get item by Slot validates serial number", () {
        SlotList!int list;
        auto slot1 = list.add(10).value;
        auto slot2 = list.add(20).value;
        auto slot3 = list.add(30).value;
        
        // Valid slots should return items
        assert(list.get(slot1).isDefined);
        assert(list.get(slot1).value == 10);
        assert(list.get(slot2).value == 20);
        assert(list.get(slot3).value == 30);
        
        // After removal, slot becomes invalid
        list.remove(1);
        assert(list.get(slot2).isEmpty); // Serial number no longer matches
        
        // Other slots still valid
        assert(list.get(slot1).isDefined);
        assert(list.get(slot3).isDefined);
    });

    test("Remove by Slot validates serial number", () {
        SlotList!int list;
        auto slot1 = list.add(10).value;
        auto slot2 = list.add(20).value;
        auto slot3 = list.add(30).value;
        
        list.remove(slot2);
        assert(list.length == 2);
        assert(list.isEmpty(1));
        
        // Trying to remove again with same slot does nothing (serial mismatch)
        list.remove(slot2);
        assert(list.length == 2);
        
        // After slot is reused, old slot reference is invalid
        auto slot4 = list.add(99).value;
        assert(slot4.index == 1); // Reused slot 1
        list.remove(slot2); // Old slot2 reference, different serial
        assert(list.get(slot4).isDefined); // Still there
        assert(list.get(slot4).value == 99);
    });

    test("Replace by Slot validates serial number", () {
        SlotList!int list;
        auto slot1 = list.add(10).value;
        auto slot2 = list.add(20).value;
        
        list.replace(slot2, 99);
        assert(list.get(slot2).value == 99);
        
        list.remove(slot2);
        list.replace(slot2, 77); // Should do nothing, serial mismatch
        assert(list.isEmpty(1));
    });

    test("IsValid checks slot validity", () {
        SlotList!int list;
        auto slot1 = list.add(10).value;
        auto slot2 = list.add(20).value;
        
        assert(list.isValid(slot1));
        assert(list.isValid(slot2));
        
        list.remove(slot1);
        assert(!list.isValid(slot1)); // No longer valid
        assert(list.isValid(slot2)); // Still valid
        
        // After compact, slots may become invalid
        list.add(30);
        list.compact();
        // slot2's index may have changed
    });

    test("Add fails when serial number overflows", () {
        SlotList!int list;
        list.nextSerial = uint.max;
        auto result = list.add(1);
        assert(result.isSuccessful);
        assert(result.value.serialNumber == uint.max);
        // nextSerial has now wrapped to 0
        assert(list.nextSerial == 0);
        auto overflowResult = list.add(2);
        assert(!overflowResult.isSuccessful);
    });
}

void runHashMapTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.string : String, s;

    writeSection("-- HashMap tests --");

    test("Create an empty HashMap", {
        HashMap!(int, int) map;
        assert(map.length == 0);
    });

    test("Put and get a value", {
        HashMap!(int, int) map;
        map.put(1, 42);
        auto result = map.get(1);
        assert(result.isDefined);
        assert(result.value == 42);
    });

    test("put overwrites existing key", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(1, 20);
        assert(map.length == 1);
        assert(map.get(1).value == 20);
    });

    test("get returns none for missing key", {
        HashMap!(int, int) map;
        map.put(1, 42);
        auto result = map.get(2);
        assert(result.isEmpty);
    });

    test("getRef returns a pointer to the stored value", {
        HashMap!(int, int) map;
        map.put(1, 42);
        auto result = map.getRef(1);
        assert(result.isDefined);
        assert(*result.value == 42);
    });

    test("getRef returns none for missing key", {
        HashMap!(int, int) map;
        map.put(1, 42);
        assert(map.getRef(2).isEmpty);

        HashMap!(int, int) emptyMap;
        assert(emptyMap.getRef(1).isEmpty);
    });

    test("values modified through getRef are stored in the map", {
        HashMap!(int, int) map;
        map.put(1, 42);
        *map.getRef(1).value = 84;
        assert(map.get(1).value == 84);
        assert(map.length == 1);
    });

    test("getRef pointers survive a rehash", {
        HashMap!(int, int) map;
        map.put(1, 42);
        auto valuePtr = map.getRef(1).value;
        for (int i = 2; i < 100; i++) {
            map.put(i, i);
        }

        *valuePtr = 84;
        assert(map.get(1).value == 84);
    });

    test("getRef gives access to a collection value without copying it", {
        HashMap!(int, Array!int) map;
        Array!int values;
        values.add(1);
        map.put(1, values);

        map.getRef(1).value.add(2);
        assert(map.get(1).value.length == 2);
        assert(map.get(1).value[1] == 2);
        assert(values.length == 1);
    });

    test("tryGet returns true and value for existing key", {
        HashMap!(int, int) map;
        map.put(1, 42);
        int value;
        bool found = map.tryGet(1, value);
        assert(found);
        assert(value == 42);
    });

    test("tryGet returns false for missing key", {
        HashMap!(int, int) map;
        int value;
        bool found = map.tryGet(99, value);
        assert(!found);
    });

    test("tryAdd returns true for new key", {
        HashMap!(int, int) map;
        bool added = map.tryAdd(1, 42);
        assert(added);
        assert(map.length == 1);
    });

    test("tryAdd returns false for existing key and leaves value unchanged", {
        HashMap!(int, int) map;
        map.put(1, 42);
        bool added = map.tryAdd(1, 99);
        assert(!added);
        assert(map.get(1).value == 42);
    });

    test("remove existing key", {
        HashMap!(int, int) map;
        map.put(1, 42);
        bool removed = map.remove(1);
        assert(removed);
        assert(map.length == 0);
        assert(map.get(1).isEmpty);
    });

    test("remove nonexistent key returns false", {
        HashMap!(int, int) map;
        bool removed = map.remove(99);
        assert(!removed);
    });

    test("contains returns correct results", {
        HashMap!(int, int) map;
        map.put(5, 500);
        assert(map.contains(5));
        assert(!map.contains(6));
    });

    test("opIndex retrieves value", {
        HashMap!(int, int) map;
        map.put(3, 30);
        assert(map[3] == 30);
    });

    test("opIndexAssign inserts or overwrites", {
        HashMap!(int, int) map;
        map[7] = 70;
        assert(map[7] == 70);
        map[7] = 700;
        assert(map[7] == 700);
    });

    test("keys returns all keys", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        map.put(3, 30);
        auto k = map.keys();
        assert(k.length == 3);
        assert(k.exists(1));
        assert(k.exists(2));
        assert(k.exists(3));
    });

    test("values returns all values", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        map.put(3, 30);
        auto v = map.values();
        assert(v.length == 3);
        assert(v.exists(10));
        assert(v.exists(20));
        assert(v.exists(30));
    });

    test("foreach key-value iteration", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        map.put(3, 30);
        int sum = 0;
        foreach (k, v; map) {
            sum += v;
        }

        assert(sum == 60);
    });

    test("foreach value iteration", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        map.put(3, 30);
        int sum = 0;
        foreach (v; map) {
            sum += v;
        }

        assert(sum == 60);
    });

    test("clear empties the map", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        map.clear();
        assert(map.length == 0);
        assert(!map.contains(1));
    });

    test("copy constructor makes an independent copy", {
        HashMap!(int, int) map;
        map.put(1, 10);
        map.put(2, 20);
        auto map2 = map;
        map2.put(3, 30);
        map2[1] = 100;
        assert(map.length == 2);
        assert(map[1] == 10);
        assert(!map.contains(3));
        assert(map2.length == 3);
        assert(map2[1] == 100);
    });

    test("two identical HashMaps are equal", {
        HashMap!(int, int) map1;
        map1.put(1, 10);
        map1.put(2, 20);
        HashMap!(int, int) map2;
        map2.put(1, 10);
        map2.put(2, 20);
        assert(map1 == map2);
    });

    test("two different HashMaps are not equal", {
        HashMap!(int, int) map1;
        map1.put(1, 10);
        HashMap!(int, int) map2;
        map2.put(1, 99);
        assert(map1 != map2);
    });

    test("identical HashMaps have the same hash", {
        HashMap!(int, int) map1;
        map1.put(1, 10);
        map1.put(2, 20);
        HashMap!(int, int) map2;
        map2.put(1, 10);
        map2.put(2, 20);
        assert(map1.toHash() == map2.toHash());
    });

    test("different HashMaps have different hashes", {
        HashMap!(int, int) map1;
        map1.put(1, 10);
        HashMap!(int, int) map2;
        map2.put(1, 99);
        assert(map1.toHash() != map2.toHash());
    });

    test("HashMap with String keys", {
        HashMap!(String, int) map;
        map.put("hello".s, 1);
        map.put("world".s, 2);
        assert(map.length == 2);
        assert(map.get("hello".s).value == 1);
        assert(map.get("world".s).value == 2);
        assert(map.get("foo".s).isEmpty);
    });

    test("HashMap with String values", {
        HashMap!(int, String) map;
        map.put(1, "one".s);
        map.put(2, "two".s);
        assert(map.get(1).value == "one".s);
        assert(map.get(2).value == "two".s);
    });

    test("HashMap rehashes when load factor is exceeded", {
        HashMap!(int, int) map;
        for (int i = 0; i < 20; i++) {
            map.put(i, i * 10);
        }

        assert(map.length == 20);
        for (int i = 0; i < 20; i++) {
            assert(map.get(i).value == i * 10);
        }
    });
}

void runQueueTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.string : String, s;

    writeSection("-- Queue tests --");

    test("Create a Queue", {
        Queue!int queue;
        assert(queue.length == 0);
        assert(queue.capacity == 0);
        assert(queue.isEmpty);
    });

    test("Enqueue items into a Queue", {
        Queue!int queue;
        queue.enqueue(1);
        assert(queue.length == 1);
        assert(queue.capacity == defaultChunkSize);
        assert(!queue.isEmpty);

        queue.enqueue(2);
        assert(queue.length == 2);
        assert(queue.capacity == defaultChunkSize);
    });

    test("Enqueue item into a Queue with concat operator", {
        Queue!int queue;
        queue ~= 1;
        queue ~= 2;
        assert(queue.length == 2);
        assert(queue[0] == 1);
        assert(queue[1] == 2);
    });

    test("Dequeue items from a Queue in FIFO order", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);

        auto first = queue.dequeue();
        assert(first.isSuccessful);
        assert(first.value == 1);
        assert(queue.length == 2);

        assert(queue.dequeue().value == 2);
        assert(queue.dequeue().value == 3);
        assert(queue.length == 0);
        assert(queue.isEmpty);
    });

    test("Dequeue from an empty Queue fails", {
        Queue!int queue;
        auto result = queue.dequeue();
        assert(result.isFailure);
        assert(result.errorMessage == "Cannot dequeue from an empty queue");
    });

    test("Dequeueing does not deallocate the Queue's memory", {
        Queue!int queue;
        queue.enqueue(1);
        queue.dequeue();
        assert(queue.length == 0);
        assert(queue.capacity == defaultChunkSize);
    });

    test("tryDequeue returns the item and true when the Queue has items", {
        Queue!int queue;
        queue.enqueue(42);
        queue.enqueue(66);

        int item;
        assert(queue.tryDequeue(item));
        assert(item == 42);
        assert(queue.length == 1);

        assert(queue.tryDequeue(item));
        assert(item == 66);
        assert(queue.isEmpty);
    });

    test("tryDequeue returns false when the Queue is empty", {
        Queue!int queue;
        int item = 33;
        assert(!queue.tryDequeue(item));
        assert(item == 0);
    });

    test("Peek at the front of a Queue without dequeueing", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);

        auto result = queue.peek();
        assert(result.isSuccessful);
        assert(result.value == 1);
        assert(queue.length == 2);
        assert(queue.peek().value == 1);
    });

    test("Peek into an empty Queue fails", {
        Queue!int queue;
        auto result = queue.peek();
        assert(result.isFailure);
        assert(result.errorMessage == "Cannot peek into an empty queue");
    });

    test("Access Queue items by index without dequeueing", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);

        assert(queue[0] == 1);
        assert(queue[1] == 2);
        assert(queue[2] == 3);
        assert(queue.opDollar == 3);
        assert(queue[$ - 1] == 3);
        assert(queue.length == 3);
    });

    test("Indexed access of a Queue is relative to its front", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.dequeue();

        assert(queue[0] == 2);
        assert(queue[1] == 3);
    });

    test("Assign Queue item through index", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue[1] = 5;
        assert(queue[1] == 5);
        assert(queue.dequeue().value == 1);
        assert(queue.dequeue().value == 5);
    });

    test("Clear a Queue", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.clear();

        assert(queue.length == 0);
        assert(queue.capacity == 0);
        assert(queue.isEmpty);
        assert(queue.dequeue().isFailure);

        queue.enqueue(3);
        assert(queue.length == 1);
        assert(queue[0] == 3);
    });

    test("Queue wraps around its buffer", {
        Queue!(int, 4) queue;
        for (int i = 1; i <= 4; i++) {
            queue.enqueue(i);
        }

        assert(queue.capacity == 4);
        assert(queue.dequeue().value == 1);
        assert(queue.dequeue().value == 2);

        // These wrap around to the start of the buffer.
        queue.enqueue(5);
        queue.enqueue(6);
        assert(queue.length == 4);
        assert(queue.capacity == 4);

        assert(queue[0] == 3);
        assert(queue[3] == 6);
        assert(queue.dequeue().value == 3);
        assert(queue.dequeue().value == 4);
        assert(queue.dequeue().value == 5);
        assert(queue.dequeue().value == 6);
        assert(queue.isEmpty);
    });

    test("Queue grows while wrapped around and retains order", {
        Queue!(int, 4) queue;
        for (int i = 1; i <= 4; i++) {
            queue.enqueue(i);
        }

        queue.dequeue();
        queue.dequeue();
        queue.enqueue(5);
        queue.enqueue(6);

        // Buffer is full and wrapped: this grows it.
        queue.enqueue(7);
        assert(queue.length == 5);
        assert(queue.capacity == 8);

        for (int i = 3; i <= 7; i++) {
            assert(queue.dequeue().value == i);
        }

        assert(queue.isEmpty);
    });

    test("Initialize a Queue through static assignment", {
        Queue!int queue = [1, 2, 3];
        assert(queue.length == 3);
        assert(queue.capacity == 3);
        assert(queue.dequeue().value == 1);
        assert(queue.dequeue().value == 2);
        assert(queue.dequeue().value == 3);
    });

    test("Assign a D array to a Queue", {
        Queue!int queue;
        queue.enqueue(9);
        queue = [1, 2];
        assert(queue.length == 2);
        assert(queue[0] == 1);
        assert(queue[1] == 2);
    });

    test("Make a copy of a Queue through assignment", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.dequeue();

        auto queue2 = queue;
        assert(queue2.length == 2);
        assert(queue2[0] == 2);
        assert(queue2[1] == 3);

        queue.enqueue(4);
        queue2.enqueue(5);
        assert(queue.length == 3);
        assert(queue2.length == 3);
        assert(queue[2] == 4);
        assert(queue2[2] == 5);
    });

    test("Compare a Queue with a D array", {
        Queue!(int, 4) queue;
        for (int i = 1; i <= 4; i++) {
            queue.enqueue(i);
        }

        queue.dequeue();
        queue.enqueue(5);

        static immutable int[4] sameItems = [2, 3, 4, 5];
        static immutable int[3] tooFewItems = [2, 3, 4];
        static immutable int[4] reversedItems = [5, 4, 3, 2];

        assert(queue == sameItems[]);
        assert(queue != tooFewItems[]);
        assert(queue != reversedItems[]);
    });

    test("Compare two Queues", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);

        Queue!int queue2;
        queue2.enqueue(1);
        queue2.enqueue(2);

        assert(queue == queue2);

        queue2.dequeue();
        assert(queue != queue2);
    });

    test("Iterate over a Queue", {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.dequeue();
        queue.enqueue(4);

        int sum = 0;
        foreach (item; queue) {
            sum += item;
        }

        assert(sum == 9);
        assert(queue.length == 3);

        int indexSum = 0;
        int valueAtIndexOne = 0;
        foreach (index, item; queue) {
            indexSum += cast(int) index;
            if (index == 1) {
                valueAtIndexOne = item;
            }
        }

        assert(indexSum == 3);
        assert(valueAtIndexOne == 3);
    });

    test("Queue of Strings", {
        Queue!String queue;
        queue.enqueue("hello".s);
        queue.enqueue("world".s);

        assert(queue[0] == "hello");
        assert(queue.dequeue().value == "hello");
        assert(queue.peek().value == "world");
        assert(queue.length == 1);
    });

    test("Dequeued item of a Queue is no longer owned by the Queue", {
        InnerArrayOwner owner;
        owner.values ~= 1;
        owner.values ~= 2;
        owner.tag = 7;

        Queue!InnerArrayOwner queue;
        queue.enqueue(owner);

        auto dequeued = queue.dequeue();
        assert(dequeued.isSuccessful);

        queue.clear();

        auto item = dequeued.value;
        assert(item.tag == 7);
        assert(item.values.length == 2);
        assert(item.values[0] == 1);
        assert(item.values[1] == 2);
    });

    test("Queue of pointers does not own what they point at", {
        int* first = cast(int*) malloc(int.sizeof);
        int* second = cast(int*) malloc(int.sizeof);
        *first = 42;
        *second = 66;

        Queue!(int*) queue;
        queue.enqueue(first);
        queue.enqueue(second);

        auto dequeued = queue.dequeue();
        assert(dequeued.isSuccessful);
        assert(dequeued.value is first);
        assert(*dequeued.value == 42);

        // Clearing only releases the queue's own storage; the pointees remain
        // the caller's responsibility.
        queue.clear();
        assert(*first == 42);
        assert(*second == 66);

        free(first);
        free(second);
    });
}
