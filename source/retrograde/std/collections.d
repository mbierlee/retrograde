/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.collections;

import retrograde.std.memory : malloc, realloc, free, allocateRaw, memset;
import retrograde.std.math : ceil;
import retrograde.std.option : Option, some, none;
import retrograde.std.hash : hashOf;

private enum defaultChunkSize = 8;

/**
 * A dynamic array that automatically resizes when needed.
 * Items are stored in a contiguous memory block.
 * This array implementation is not thread-safe.
 */
struct Array(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0;
    private size_t _capacity = 0;

    this(ref return scope inout typeof(this) other) {
        this(other.items[0 .. other._length]);
        _capacity = other._length;
    }

    this(scope inout T[] other) {
        items = cast(T*) malloc(T.sizeof * other.length);
        assert(items !is null, "Failed to allocate memory during assignment of array");

        if (items !is null) {
            memset(items, 0, T.sizeof * other.length);
            foreach (T item; other) {
                items[_length] = item;
                _length++;
            }

            _capacity = other.length;
        }
    }

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
     */
    void add(T item) {
        considerResize();

        if (items !is null) {
            items[_length] = item;
            _length++;
        }
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

    void opAssign(ref return scope inout typeof(this) other) {
        if (other._capacity == 0) {
            clear();
            return;
        }

        _length = other._length;
        _capacity = other._capacity;
        items = cast(T*) realloc(items, T.sizeof * other._length);
        assert(items !is null, "Failed to allocate memory during assignment of array");

        if (items !is null) {
            memset(items, 0, T.sizeof * other._length);
            for (size_t i = 0; i < _length; i++) {
                items[i] = other.items[i];
            }
        }
    }

    void opOpAssign(string op : "~")(T rhs) {
        add(rhs);
    }

    void opOpAssign(string op : "~")(ref typeof(this) rhs) {
        foreach (T item; rhs.items[0 .. rhs._length]) {
            add(item);
        }
    }

    typeof(this) opBinary(string op : "~")(ref typeof(this) rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    typeof(this) opBinary(string op : "~")(T rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    typeof(this) opBinary(string op : "~")(ref T rhs) {
        typeof(this) result = this;
        result ~= rhs;
        return result;
    }

    auto opIndex(size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return items[i];
    }

    T[] opIndex() {
        return items[0 .. _length];
    }

    size_t opDollar() {
        return _length;
    }

    T[] opSlice(size_t dim : 0)(size_t i, size_t j) {
        assert(i >= 0 && j >= 0 && i <= _length && j <= _length, "Index out of bounds");
        return items[i .. j];
    }

    T[] opIndex()(T[] slice) {
        return slice;
    }

    T opIndexAssign(T value, size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        items[i] = value;
        return value;
    }

    T opIndexAssign(T value) {
        for (size_t i = 0; i < _length; i++) {
            items[i] = value;
        }

        return value;
    }

    bool opEquals(const T[] other) const {
        return opEquals(other);
    }

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

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

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
     * Returns: the hash of the array.
     */
    ulong toHash() nothrow @trusted const {
        ulong hash = 0;
        for (size_t i = 0; i < _length; i++) {
            hash = hash * 33 + items[i].hashOf;
        }

        return hash;
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

    auto opIndex(size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        return get(i).value;
    }

    size_t opDollar() {
        return _length;
    }

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

    Array!T opIndex()(Array!T slice) {
        return slice;
    }

    T opIndexAssign(T value, size_t i) {
        assert(i >= 0 && i < _length, "Index out of bounds");
        NodePtr node = head;
        for (size_t k = 0; k < i; k++) {
            node = node.next;
        }

        node.value = value;
        return value;
    }

    T opIndexAssign(T value) {
        NodePtr node = head;
        while (node !is null) {
            node.value = value;
            node = node.next;
        }

        return value;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

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
        array.add(1);
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
