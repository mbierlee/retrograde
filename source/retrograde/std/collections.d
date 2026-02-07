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

import retrograde.std.memory : malloc, realloc, free, allocateRaw, memset;
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
        _capacity = other._capacity;
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
    int serialNumber;
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
    private int* serials = null;
    private size_t _length = 0;
    private size_t _capacity = 0;
    private int nextSerial = 1;

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
        serials = cast(int*) malloc(int.sizeof * other._length);
        assert(items !is null && serials !is null, "Failed to allocate memory during copy construction");

        if (items !is null && serials !is null) {
            memset(items, 0, T.sizeof * other._length);
            memset(serials, 0, int.sizeof * other._length);
            
            T* mutableOtherItems = cast(T*) other.items;
            int* mutableOtherSerials = cast(int*) other.serials;
            
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
        items[index] = T.init;
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
        items[slot.index] = T.init;
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
            for (size_t i = newLength; i < _length; i++) {
                serials[i] = 0;
                items[i] = T.init;
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
                    items[readIndex] = T.init;
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
    size_t findIndexBySerial(int serial) const {
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
    Option!T findItemBySerial(int serial) const {
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
    Option!Slot findSlotBySerial(int serial) const {
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
    int getSerial(size_t index) const {
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
        int* newSerials = cast(int*) realloc(serials, int.sizeof * other._length);
        
        if (newItems is null || newSerials is null) {
            assert(0, "Failed to allocate memory during assignment of slot list");
            return;
        }

        memset(newItems, 0, T.sizeof * other._length);
        memset(newSerials, 0, int.sizeof * other._length);
        
        T* mutableOtherItems = cast(T*) other.items;
        int* mutableOtherSerials = cast(int*) other.serials;
        
        for (size_t i = 0; i < other._length; i++) {
            newItems[i] = mutableOtherItems[i];
            newSerials[i] = mutableOtherSerials[i];
        }

        items = newItems;
        serials = newSerials;
        _length = other._length;
        _capacity = other._capacity;
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
        serials = cast(int*) realloc(serials, int.sizeof * (_capacity + growSize));
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
    void removeWhere(bool function(const ref T) pred) {
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

    this(LinkedList!T* list) {
        this.list = list;
        this.node = list.head;
    }

    /** 
     * Returns: Whether there is another item in the list.
     */
    bool hasNext() {
        return node !is null;
    }

    /** 
     * Returns: Whether there is a previous item in the list.
     */
    bool hasPrevious() {
        return node !is null && node.prev !is null;
    }

    /**
     * Returns: The next item in the list, or none if there is no next item.
     */
    Option!T next() {
        if (node is null) {
            return none!T;
        }

        T value = node.value;
        node = node.next;
        return value.some;
    }

    /**
     * Returns: The previous item in the list, or none if there is no previous item.
     */
    Option!T previous() {
        if (node is null || node.prev is null) {
            return none!T;
        }

        node = node.prev;
        return node.value.some;
    }

    /** 
     * Reset the iterator to the start of the list.
     */
    void reset() {
        node = list.head;
    }

    /** 
     * Remove the item at the current position of the iterator and move forward.
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

        list._length--;

        free(node);
        node = next;
    }

    /** 
     * Insert an item at the current position of the iterator.
     *
     * Params:
     *   value = The value to insert.
     */
    void insert(T value) {
        NodePtr newNode = allocateRaw!(LinkedListNode!T);
        newNode.value = value;
        newNode.next = node;
        newNode.prev = node.prev;

        if (node.prev !is null) {
            node.prev.next = newNode;
        }

        if (node is list.head) {
            list.head = newNode;
        }

        node.prev = newNode;
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

version (UnitTesting)  :  ///

void runCollectionsTests() {
    runArrayTests();
    runSlotListTests();
    runLinkedListTests();
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

        i = 2;
        while (iterator.hasPrevious) {
            assert(iterator.previous.value == expected[i--]);
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

        int[3] expected = [1, 10, 3];
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
}
