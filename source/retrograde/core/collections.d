/**
 * Retrograde Engine
 *
 * This package contains dynamically-sized collections that do not make use of the garbage collector. 
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.collections;

import core.stdc.stdlib : malloc, realloc, free;
import std.math : ceil;

enum defaultChunkSize = 8;

/**
 * An implementation of a dynamically sized first-in, first-out queue that does not use the
 * garbage collector.
 *
 * This queue is not thread-safe.
 */
struct Queue(T, size_t chunkSize = defaultChunkSize) {
    private T* items = null;
    private size_t _length = 0, _capacity = 0, front = 0, rear = 0;

    /**
     * Adds an item to the end of the queue.
     *
     * If the allocated space for the queue is insufficient, more memory will be allocated.
     */
    void enqueue(T item) nothrow @nogc {
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
     * Allocated space is never freed up.
     */
    T dequeue() nothrow @nogc {
        if (!items || length == 0) {
            return T.init;
        }

        auto item = items[front];
        moveFront();
        _length--;
        return item;
    }

    /**
     * Returns the amount of items currently in the queue.
     */
    size_t length() nothrow @nogc {
        return _length;
    }

    /**
     * Returns the allocated capacity of the queue in number of queue items.
     */
    size_t capacity() nothrow @nogc {
        return _capacity;
    }

    /**
     * Returns an exact copy of the internal queue array.
     *
     * Params:
     *  len = Desired length of the returned queue. Make it equal to the queue's capacity to return the complete queue.
     */
    T[len] getArrayCopy(size_t len)() nothrow @nogc {
        T[len] itemsCopy;
        foreach (i; 0 .. len) {
            itemsCopy[i] = (items) ? items[i] : T.init;
        }

        return itemsCopy;
    }

    /**
     * Clears all items currently in the queue.
     *
     * Items are not deallocated or nullified but stay in the queue as-is. However the queue will be virtually empty.
     */
    void clear() nothrow @nogc {
        front = rear = 0;
        _length = 0;
    }

    /**
     * Resizes the allocated memory to the optimal size of items in the queue.
     *
     * The queue's capacity will determined by how many chunks are needed for the current items in the queue.
     */
    void compact() nothrow @nogc {
        T* newQueue = createShuffledResizedQueue(length);
        replaceQueue(newQueue);
        front = 0;
        rear = length;
        _capacity = getCapacitySizeForItems(length);
    }

    /**
     * Deallocates all claimed memory, effectively clearing the queue in the process.
     */
    void deallocate() nothrow @nogc {
        _length = 0;
        compact();
    }

    this(ref return scope Queue!T rhs) {
        // Force a copy of the items array to be made to prevent the same items array from being shared with rhs.
        // Without this, this instance's items may be freed up on destruction of rhs.
        _length = rhs.length;
        items = rhs.createShuffledResizedQueue(length);
        front = 0;
        rear = length;
        _capacity = getCapacitySizeForItems(length);
    }

    ~this() nothrow @nogc {
        if (items) {
            free(items);
            items = null;
        }
    }

    private void moveRear() nothrow @nogc {
        if (length != capacity && rear == capacity - 1) {
            rear = 0;
        } else {
            rear++;
        }
    }

    private void moveFront() nothrow @nogc {
        if (length != capacity && front == capacity - 1) {
            front = 0;
        } else {
            front++;
        }
    }

    private void considerResize() nothrow @nogc {
        if (!items) {
            items = cast(T*) malloc(T.sizeof * chunkSize);
            if (items) {
                _capacity = chunkSize;
            }
        } else if (capacity == length) {
            if (rear > front) {
                items = cast(T*) realloc(items, T.sizeof * (capacity + chunkSize));
                _capacity += chunkSize;
            } else {
                T* newBlock = createShuffledResizedQueue(capacity + chunkSize);
                replaceQueue(newBlock);
                _capacity += chunkSize;
                front = 0;
                rear = length;
            }
        }
    }

    private void replaceQueue(T* newQueue) nothrow @nogc {
        if (items) {
            free(items);
        }

        items = newQueue;
    }

    private T* createShuffledResizedQueue(size_t newItemSize) nothrow @nogc {
        size_t newMemorySize = getCapacitySizeForItems(newItemSize) * T.sizeof;

        T* newQueue = cast(T*) malloc(newMemorySize);
        size_t readHead = front;
        size_t writeHead = 0;
        while (writeHead != length) {
            newQueue[writeHead] = items[readHead];
            readHead++;
            if (readHead == capacity) {
                readHead = 0;
            }

            writeHead++;
        }

        return newQueue;
    }

    private size_t getCapacitySizeForItems(size_t itemSize) nothrow @nogc {
        return cast(size_t) ceil(cast(double) itemSize / chunkSize) * chunkSize;
    }
}

// Queue tests
version (unittest) {
    @("Queue initialization")
    unittest {
        Queue!int queue;
    }

    @("Enqueue item")
    unittest {
        Queue!int queue;
        queue.enqueue(1);
        assert(queue.length == 1);
    }

    @("Dequeue item")
    unittest {
        Queue!int queue;
        queue.enqueue(44);
        assert(queue.length == 1);

        auto item = queue.dequeue();
        assert(queue.length == 0);
        assert(item == 44);
    }

    @("Dequeue item from empty queue")
    unittest {
        Queue!int queue;
        auto item = queue.dequeue();
        assert(item == int.init);
    }

    @("Dequeue items beyond what was filled")
    unittest {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.dequeue();
        queue.dequeue();
        auto item = queue.dequeue();
        assert(item == int.init);
    }

    @("Filling queue beyond initial capacity")
    unittest {
        Queue!(int, 16) queue;
        foreach (i; 0 .. 128) {
            queue.enqueue(i);
        }

        assert(queue.length == 128);
        assert(queue.capacity == 128);
    }

    @("Looping queue front/rear")
    unittest {
        Queue!(int, 4) queue;

        // Memory marked as X is dirty and can contain anything, since the claimed memory is not cleaned beforehand.
        // Memory marked as _ used to be enqueued but is not anymore.

        queue.enqueue(1); // [1, X, X ,X]
        assert(queue.getArrayCopy!1 == [1]);
        queue.enqueue(2); // [1, 2, X, X]
        assert(queue.getArrayCopy!2 == [1, 2]);
        queue.enqueue(3); // [1, 2, 3, X]
        assert(queue.getArrayCopy!3 == [1, 2, 3]);
        queue.enqueue(4); // [1, 2, 3, 4]
        assert(queue.getArrayCopy!4 == [1, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);
        assert(queue.dequeue() == 1); // [_, 2, 3, 4]
        assert(queue.getArrayCopy!4 == [1, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 3);

        queue.enqueue(5); // [5, 2, 3, 4]
        assert(queue.getArrayCopy!4 == [5, 2, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);
        assert(queue.dequeue() == 2); // [5, _, 3, 4]
        assert(queue.getArrayCopy!4 == [5, 2, 3, 4]);
        assert(queue.dequeue() == 3); // [5, _, _, 4]
        assert(queue.getArrayCopy!4 == [5, 2, 3, 4]);
        assert(queue.dequeue() == 4); // [5, _, _, _]
        assert(queue.getArrayCopy!4 == [5, 2, 3, 4]);
        assert(queue.dequeue() == 5); // [_, _, _, _]
        assert(queue.getArrayCopy!4 == [5, 2, 3, 4]);

        queue.enqueue(6); // [_, 6, _, _]
        assert(queue.getArrayCopy!4 == [5, 6, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 1);

        assert(queue.dequeue() == 6); // [_, _, _, _]
        assert(queue.getArrayCopy!4 == [5, 6, 3, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 0);

        queue.enqueue(7); // [_, _, 7, _]
        assert(queue.getArrayCopy!4 == [5, 6, 7, 4]);
        assert(queue.capacity == 4);
        assert(queue.length == 1);

        queue.enqueue(8); // [_, _, 7, 8]
        assert(queue.getArrayCopy!4 == [5, 6, 7, 8]);
        queue.enqueue(9); // [9, _, 7, 8]
        assert(queue.getArrayCopy!4 == [9, 6, 7, 8]);
        queue.enqueue(10); // [9, 10, 7, 8]
        assert(queue.getArrayCopy!4 == [9, 10, 7, 8]);
        assert(queue.capacity == 4);
        assert(queue.length == 4);

        // Resize queue that has looped around
        queue.enqueue(11); // [7, 8, 9, 10, 11, X, X, X]
        assert(queue.getArrayCopy!5 == [7, 8, 9, 10, 11]);

        assert(queue.capacity == 8);
        assert(queue.length == 5);

        assert(queue.dequeue() == 7); // [_, 8, 9, 10, 11, X, X, X]
        assert(queue.getArrayCopy!5 == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 8); // [_ ,_, 9, 10, 11, X, X, X]
        assert(queue.getArrayCopy!5 == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 9); // [_, _, _, 10, 11, X, X, X]
        assert(queue.getArrayCopy!5 == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 10); // [_, _, _, _, 11, X, X, X]
        assert(queue.getArrayCopy!5 == [7, 8, 9, 10, 11]);
        assert(queue.dequeue() == 11); // [_, _, _, _, _, X, X, X]
        assert(queue.capacity == 8);
        assert(queue.length == 0);
    }

    @("Clear the queue")
    unittest {
        Queue!(int, 2) queue;
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.clear();
        assert(queue.length == 0);
        assert(queue.capacity == 4);
        assert(queue.dequeue() == int.init);
    }

    @("Compact the queue")
    unittest {
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
    }

    @("Deallocate the queue")
    unittest {
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
    }

    @("Queue item array is copied when queue is copied")
    unittest {
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
    }

    @("Get array copy")
    unittest {
        Queue!int queue;
        queue.enqueue(1);
        queue.enqueue(2);
        assert(queue.getArrayCopy!2 == [1, 2]);

        Queue!int queue2;
        assert(queue2.getArrayCopy!2 == [int.init, int.init]);
    }
}
