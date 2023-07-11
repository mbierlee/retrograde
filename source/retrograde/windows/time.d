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

module retrograde.windows.time;

import retrograde.std.result : OperationResult, success, failure;

version (Windows) {
    import core.sys.windows.windows : QueryPerformanceCounter, QueryPerformanceFrequency, LARGE_INTEGER;

    /** 
     * A high resolution timer.
     */
    struct StopWatch {
        private bool _isRunning = false;
        private double elapsedMs = 0;
        private LARGE_INTEGER startTime;
        private LARGE_INTEGER frequency;

        /** 
         * Starts the timer.
         * 
         * Returns:
         *  OperationResult.success() if the timer was started successfully.
         */
        OperationResult start() {
            auto frequencyRes = QueryPerformanceFrequency(&frequency);
            if (frequencyRes == 0) {
                return failure("QueryPerformanceFrequency failed");
            }

            auto startTimeRes = QueryPerformanceCounter(&startTime);
            if (startTimeRes == 0) {
                return failure("QueryPerformanceCounter failed");
            }

            _isRunning = true;
            return success();
        }

        /** 
         * Stops the timer.
         *
         * Returns: 
         *  The elapsed time in milliseconds.
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
         * Returns:
         *  The elapsed time in milliseconds. If getting the time from the system failed, -1 is returned.
         */
        double peek() {
            if (_isRunning) {
                LARGE_INTEGER peekTime;
                auto peekTimeRes = QueryPerformanceCounter(&peekTime);
                if (peekTimeRes == 0) {
                    return -1;
                }

                double accumulatedMs = (peekTime.QuadPart - startTime.QuadPart) * 1000 / cast(
                    double) frequency.QuadPart;

                return elapsedMs + accumulatedMs;
            } else {
                return elapsedMs;
            }
        }

        /** 
         * Stops and resets.
         *
         * Returns:
         *  The elapsed time in milliseconds.
         */
        double reset() {
            double elapsed = stop();
            elapsedMs = 0;
            return elapsed;
        }

        /** 
         * Returns whether the timer is running.
         */
        bool isRunning() {
            return _isRunning;
        }
    }
}
