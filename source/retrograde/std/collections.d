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

import retrograde.std.memory : malloc, realloc, free, allocateRaw;
import retrograde.std.math : ceil;
import retrograde.std.option : Option, some, none;

private enum defaultChunkSize = 8;

/**
 * A dynamically sized first-in, first-out queue.
 *
 * Elements are managed in arrays and are contiguous in memory. When the queue is full, more memory is allocated.
 * When the queue is emptied, the allocated memory is not freed up. This is done to prevent unnecessary memory
 * allocations and deallocations. It is possible to compact the queue manually to free up memory.
 *
 * This queue implementation is not thread-safe.
 */
struct Queue(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0;
    private size_t _capacity = 0;
    private size_t front = 0;
    private size_t rear = 0;

    this(ref return scope typeof(this) other) {
        // Force a copy of the items array to be made to prevent the same items array from being shared with rhs.
        // Without this, this instance's items may be freed up on destruction of rhs.
        _length = other._length;
        items = other.createShuffledResizedQueue(_length);
        front = 0;
        rear = _length;
        _capacity = getCapacitySizeForItems(_length);
    }

    ~this() {
        if (items !is null) {
            free(items);
            items = null;
            _length = 0;
            _capacity = 0;
            front = 0;
            rear = 0;
        }
    }

    /**
     * Adds an item to the end of the queue.
     *
     * If the allocated space for the queue is insufficient, more memory will be allocated.
     */
    void enqueue(T item) {
        considerResize();

        if (items) {
            items[rear] = item;
            moveRear();
            _length++;
        }
    }

    /**
     * Removes and returns an item from the front of the queue.
     *
     * If the queue is empty, the default value of T is returned.
     * To check whether the queue is empty, use isEmpty().
     *
     * Allocated space is never freed up.
     */
    T dequeue() {
        if (!items || _length == 0) {
            return T.init;
        }

        auto item = items[front];
        moveFront();
        _length--;
        return item;
    }

    /**
     * Returns the item at the front of the queue without removing it.
     *
     * If the queue is empty, the default value of T is returned.
     * To check whether the queue is empty, use isEmpty().
     */
    T peek() {
        if (!items || _length == 0) {
            return T.init;
        }

        return items[front];
    }

    /**
     * Returns the amount of items currently in the queue.
     */
    size_t length() {
        return _length;
    }

    /**
     * Returns the allocated capacity of the queue in number of items.
     */
    size_t capacity() {
        return _capacity;
    }

    /**
     * Returns whether the queue is empty.
     */
    bool isEmpty() {
        return _length == 0;
    }

    /**
     * Clears all items currently in the queue.
     *
     * Items are not deallocated or nullified but stay in the queue as-is. However the queue will be virtually empty.
     */
    void clear() {
        front = rear = 0;
        _length = 0;
    }

    /**
     * Resizes the allocated memory to the optimal size of items in the queue.
     *
     * The queue's capacity will determined by how many chunks are needed for the current items in the queue.
     */
    void compact() {
        T* newQueue = createShuffledResizedQueue(_length);
        replaceQueue(newQueue);
        front = 0;
        rear = _length;
        _capacity = getCapacitySizeForItems(_length);
    }

    /**
     * Deallocates all claimed memory, effectively clearing the queue in the process.
     */
    void deallocate() {
        _length = 0;
        compact();
    }

    private void moveRear() {
        if (_length != _capacity && rear == _capacity - 1) {
            rear = 0;
        } else {
            rear++;
        }
    }

    private void moveFront() {
        if (_length != _capacity && front == _capacity - 1) {
            front = 0;
        } else {
            front++;
        }
    }

    private void considerResize() {
        if (items is null) {
            items = cast(T*) malloc(T.sizeof * chunkSize);
            if (items !is null) {
                _capacity = chunkSize;
            }
        } else if (_capacity == _length) {
            if (rear > front) {
                items = cast(T*) realloc(items, T.sizeof * (_capacity + chunkSize));
                _capacity += chunkSize;
            } else {
                T* newChunk = createShuffledResizedQueue(_capacity + chunkSize);
                replaceQueue(newChunk);
                _capacity += chunkSize;
                front = 0;
                rear = _length;
            }
        }
    }

    private void replaceQueue(T* newQueue) {
        if (items) {
            free(items);
        }

        items = newQueue;
    }

    private T* createShuffledResizedQueue(size_t newItemSize) {
        size_t newMemorySize = getCapacitySizeForItems(newItemSize) * T.sizeof;

        T* newQueue = cast(T*) malloc(newMemorySize);
        size_t readHead = front;
        size_t writeHead = 0;
        while (writeHead != _length) {
            newQueue[writeHead] = items[readHead];
            readHead++;
            if (readHead == capacity) {
                readHead = 0;
            }

            writeHead++;
        }

        return newQueue;
    }

    private size_t getCapacitySizeForItems(size_t itemSize) {
        return cast(size_t) ceil(cast(double) itemSize / chunkSize) * chunkSize;
    }
}

/**
 * A dynamic array that automatically resizes when needed.
 * Items are stored in a contiguous memory block.
 * This array implementation is not thread-safe.
 */
struct Array(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0;
    private size_t _capacity = 0;

    this(ref return scope typeof(this) other) {
        this(other.items[0 .. other._length]);
        _capacity = other._length;
    }

    this(scope T[] other) {
        items = cast(T*) malloc(T.sizeof * other.length);
        if (items !is null) {
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
     * Returns the amount of items currently in the array.
     */
    size_t length() const {
        return _length;
    }

    /**
     * Returns the allocated capacity of the array in number of items.
     */
    size_t capacity() const {
        return _capacity;
    }

    /**
     * Change the capacity of the array.
     * This will allocate or deallocate memory as needed.
     */
    void capacity(size_t newCapacity) {
        if (newCapacity == _capacity) {
            return;
        }

        if (newCapacity == 0) {
            clear();
            return;
        }

        if (items is null) {
            items = cast(T*) malloc(T.sizeof * newCapacity);
        } else {
            items = cast(T*) realloc(items, T.sizeof * newCapacity);
        }

        _capacity = newCapacity;

        if (_length > _capacity) {
            _length = _capacity;
        }
    }

    /** 
     * Add an item to the end of the array.
     * Alternatively, you can use the ~= operator to add an item.
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
        _length = 0;
        _capacity = 0;
        if (items !is null) {
            free(items);
            items = null;
        }
    }

    /**
     * Truncate the array to the given length.
     * Allocated memory will not be deallocated.
     */
    void truncate(size_t newLength) {
        if (newLength < _length) {
            _length = newLength;
        }
    }

    /** 
     * Find the index of the first item that matches the given value.
     * Returns -1 if no item is found.
     */
    size_t find(T value) const {
        for (size_t i = 0; i < _length; i++) {
            if (items[i] == value) {
                return i;
            }
        }

        return -1;
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

    T opIndexAssign(const T value, size_t i) {
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

    private void considerResize() {
        if (items is null) {
            items = cast(T*) malloc(T.sizeof * chunkSize);
            if (items !is null) {
                _capacity = chunkSize;
            }
        } else if (_capacity == length) {
            items = cast(T*) realloc(items, T.sizeof * (_capacity + chunkSize));
            _capacity += chunkSize;
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
            free(node);
            node = next;
        }
    }

    /// The number of items in the list.
    size_t length() const {
        return _length;
    }

    /// Add an item to the end of the list.
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

    /// Remove the first item from the list.
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

    /// Remove the last item from the list.
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

    /// Remove all items with the given value from the list.
    void removeAll(const T item) {
        removeItems(item, false);
    }

    /// Remove all items that satisfy the given predicate from the list.
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

    // Remove the first item with the given value from the list.
    void removeFirst(T item) {
        removeItems(item, true);
    }

    /// Remove all items from the list.
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

    /// Get first item in the list.
    Option!T first() {
        if (head is null) {
            return none!T;
        }

        return head.value.some;
    }

    /// Get last item in the list.
    Option!T last() {
        if (tail is null) {
            return none!T;
        }

        return tail.value.some;
    }

    /// Get the item at the given index as Option.
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

    /// Create a new iterator for the list.
    LinkedListIterator!T iterator() {
        return LinkedListIterator!T(&this);
    }

    /** 
     * Find the index of the first item with the given value.
     * Returns -1 if the item is not found.
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

    bool hasNext() {
        return node !is null;
    }

    bool hasPrevious() {
        return node !is null && node.prev !is null;
    }

    /// Get the next item in the list and move the iterator forward.
    Option!T next() {
        if (node is null) {
            return none!T;
        }

        T value = node.value;
        node = node.next;
        return value.some;
    }

    /// Get the previous item in the list and move the iterator back.
    Option!T previous() {
        if (node is null || node.prev is null) {
            return none!T;
        }

        node = node.prev;
        return node.value.some;
    }

    /// Reset the iterator to the start of the list.
    void reset() {
        node = list.head;
    }

    /// Remove the item at the current position of the iterator and move forward.
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

    /// Insert an item at the current position of the iterator.
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

    /// Replace the item at the current position of the iterator.
    void replace(T value) {
        if (node is null) {
            return;
        }

        node.value = value;
    }
}

///  --- Tests ---

void runCollectionsTests() {
    runQueueTests();
    runArrayTests();
    runLinkedListTests();
}

void runQueueTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Queue tests --");

    test("Queue initialization", () { Queue!int queue; });

    test("Enqueue item", () {
        Queue!int queue;
        queue.enqueue(1);
        assert(queue.length == 1);
        assert(queue.capacity == defaultChunkSize);
    });

    test("Dequeue item", () {
        Queue!int queue;
        queue.enqueue(44);
        assert(queue.length == 1);

        auto item = queue.dequeue();
        assert(queue.length == 0);
        assert(queue.capacity == defaultChunkSize);
        assert(item == 44);
    });

    test("Dequeue item from empty queue", () {
        Queue!int queue;
        auto item = queue.dequeue();
        assert(item == int.init);
    });

    test("Dequeue items beyond what was filled", () {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.dequeue();
        queue.dequeue();
        auto item = queue.dequeue();
        assert(item == int.init);
    });

    test("Dequeue items beyond what was filled and then enqueue", () {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.dequeue();
        queue.dequeue();
        queue.enqueue(3);
        auto item = queue.dequeue();
        assert(item == 3);
    });

    test("Filling queue beyond initial capacity", () {
        Queue!(int, 16) queue;
        foreach (i; 0 .. 128) {
            queue.enqueue(i);
        }

        assert(queue.length == 128);
        assert(queue.capacity == 128);
    });

    test("Looping queue front/rear", () {
        Queue!(int, 4) queue;

        // Memory marked as X is dirty and can contain anything, since the claimed memory is not cleaned beforehand.
        // Memory marked as _ used to be enqueued but is not anymore.

        queue.enqueue(1); // [1, X, X ,X]
        assert(queue.items[0] == 1);
        queue.enqueue(2); // [1, 2, X, X]
        assert(queue.items[0 .. 2] == [1, 2]);
        queue.enqueue(3); // [1, 2, 3, X]
        assert(queue.items[0 .. 3] == [1, 2, 3]);
        queue.enqueue(4); // [1, 2, 3, 4]
        assert(queue.items[0 .. 4] == [1, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);
        assert(queue.dequeue() == 1); // [_, 2, 3, 4]
        assert(queue.items[0 .. 4] == [1, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 3);

        queue.enqueue(5); // [5, 2, 3, 4]
        assert(queue.items[0 .. 4] == [5, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);
        assert(queue.dequeue() == 2); // [5, _, 3, 4]
        assert(queue.items[0 .. 4] == [5, 2, 3, 4]);
        assert(queue.dequeue() == 3); // [5, _, _, 4]
        assert(queue.items[0 .. 4] == [5, 2, 3, 4]);
        assert(queue.dequeue() == 4); // [5, _, _, _]
        assert(queue.items[0 .. 4] == [5, 2, 3, 4]);
        assert(queue.dequeue() == 5); // [_, _, _, _]
        assert(queue.items[0 .. 4] == [5, 2, 3, 4]);

        queue.enqueue(6); // [_, 6, _, _]
        assert(queue.items[0 .. 4] == [5, 6, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 1);

        assert(queue.dequeue() == 6); // [_, _, _, _]
        assert(queue.items[0 .. 4] == [5, 6, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 0);

        queue.enqueue(7); // [_, _, 7, _]
        assert(queue.items[0 .. 4] == [5, 6, 7, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 1);

        queue.enqueue(8); // [_, _, 7, 8]
        assert(queue.items[0 .. 4] == [5, 6, 7, 8]);
        queue.enqueue(9); // [9, _, 7, 8]
        assert(queue.items[0 .. 4] == [9, 6, 7, 8]);
        queue.enqueue(10); // [9, 10, 7, 8]
        assert(queue.items[0 .. 4] == [9, 10, 7, 8]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);

        // Resize queue that has looped around
        queue.enqueue(11); // [7, 8, 9, 10, 11, X, X, X]
        assert(queue.items[0 .. 5] == [7, 8, 9, 10, 11]);

        assert(queue.capacity == 8);
        assert(queue.length == 5);

        assert(queue.dequeue() == 7); // [_, 8, 9, 10, 11, X, X, X]
        assert(queue.items[0 .. 5] == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 8); // [_ ,_, 9, 10, 11, X, X, X]
        assert(queue.items[0 .. 5] == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 9); // [_, _, _, 10, 11, X, X, X]
        assert(queue.items[0 .. 5] == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 10); // [_, _, _, _, 11, X, X, X]
        assert(queue.items[0 .. 5] == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 11); // [_, _, _, _, _, X, X, X]
        assert(queue.capacity == 8);
        assert(queue.length == 0);
    });

    test("Clear the queue", () {
        Queue!(int, 2) queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.clear();
        assert(queue.length == 0);
        assert(queue.capacity == 4);
        assert(queue.dequeue() == int.init);
    });

    test("Compact the queue", () {
        Queue!(int, 2) queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.enqueue(4);
        queue.dequeue();
        queue.dequeue();
        queue.dequeue();
        assert(queue.length == 1);
        assert(queue.capacity == 4);

        queue.compact();
        assert(queue.length == 1);
        assert(queue.capacity == 2);

        queue.dequeue();
        queue.compact();
        assert(queue.length == 0);
        assert(queue.capacity == 0);
    });

    test("Deallocate the queue", () {
        Queue!(int, 4) queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.enqueue(4);
        queue.deallocate();
        assert(queue.length == 0);
        assert(queue.capacity == 0);

        queue.enqueue(1);
        assert(queue.length == 1);
        assert(queue.capacity == 4);
    });

    test("Queue item array is copied when queue is copied", () {
        ///

        {
            Queue!int queue;
            queue.enqueue(1);
            {
                auto newQueue = queue;
            }
            // Here newQueue will be destroyed because it goes out of stack-scope

        }
        // Here queue will be destroyed. This should go fine since newQueue should be a deep copy.
        // If not the program will crash at this point since the same items array will be freed up again.
        // If you see something like "Program exited with code -1073740940" this test failed!
    });

    test("Reassignment of a Queue copies it", () {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        auto queue2 = queue;
        queue.enqueue(0);
        queue2.enqueue(3);

        assert(queue.items[0 .. 3] == [1, 2, 0]);
        assert(queue2.items[0 .. 3] == [1, 2, 3]);
    });

    test("Check queue for emptyness", () {
        Queue!int queue;
        assert(queue.isEmpty);
        queue.enqueue(1);
        assert(!queue.isEmpty);
        queue.dequeue();
        assert(queue.isEmpty);
    });

    test("Queue can be peeked", () {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        assert(queue.peek == 1);
        assert(queue.length == 3);
    });
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
}
