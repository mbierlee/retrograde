/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2025 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.

 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.native.linux.time;

import retrograde.std.result : OperationResult, success, failure;

version (Posix) {
    import core.sys.posix.time : clock_gettime, timespec, CLOCK_MONOTONIC;

    /** 
     * A high resolution timer.
     */
    struct StopWatch {
        private bool _isRunning = false;
        private double elapsedMs = 0;
        private timespec startTime;

        /** 
         * Starts the timer.
         * 
         * Returns: OperationResult.success() if the timer was started successfully.
         */
        OperationResult start() {
            auto startTimeRes = clock_gettime(CLOCK_MONOTONIC, &startTime);
            if (startTimeRes != 0) {
                return failure("clock_gettime failed");
            }

            _isRunning = true;
            return success();
        }

        /** 
         * Stops the timer.
         *
         * Returns: The elapsed time in milliseconds.
         */
        double stop() {
            if (_isRunning) {
                elapsedMs = peek();
                _isRunning = false;
            }

            return elapsedMs;
        }

        /** 
         * Returns the elapsed time in milliseconds without stopping the timer.
         * If the timer is running, the elapsed time is the time since the timer was started.
         * If the timer is stopped, the elapsed time is the time between the start and stop calls.
         *
         * Returns: The elapsed time in milliseconds. If getting the time from the system failed, -1 is returned.
         */
        double peek() {
            if (_isRunning) {
                timespec peekTime;
                auto peekTimeRes = clock_gettime(CLOCK_MONOTONIC, &peekTime);
                if (peekTimeRes != 0) {
                    return -1;
                }

                double startTimeMs = startTime.tv_sec * 1000.0 + startTime.tv_nsec / 1_000_000.0;
                double peekTimeMs = peekTime.tv_sec * 1000.0 + peekTime.tv_nsec / 1_000_000.0;
                double accumulatedMs = peekTimeMs - startTimeMs;

                return elapsedMs + accumulatedMs;
            } else {
                return elapsedMs;
            }
        }

        /** 
         * Stops and resets.
         *
         * Returns: The elapsed time in milliseconds.
         */
        double reset() {
            double elapsed = stop();
            elapsedMs = 0;
            return elapsed;
        }

        /** 
         * Returns: whether the timer is running.
         */
        bool isRunning() {
            return _isRunning;
        }
    }
}