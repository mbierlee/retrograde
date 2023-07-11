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
         */
        void start() {
            auto frequencyRes = QueryPerformanceFrequency(&frequency);
            assert(frequencyRes != 0, "QueryPerformanceFrequency failed");

            auto startTimeRes = QueryPerformanceCounter(&startTime);
            assert(startTimeRes != 0, "QueryPerformanceCounter failed");

            _isRunning = true;
        }

        /** 
         * Stops the timer and returns the elapsed time in milliseconds.
         */
        double stop() {
            if (!_isRunning) {
                return elapsedMs;
            }

            elapsedMs = peek();
            _isRunning = false;
            return elapsedMs;
        }

        /** 
         * Returns the elapsed time in milliseconds without stopping the timer.
         * If the timer is running, the elapsed time is the time since the timer was started.
         * If the timer is stopped, the elapsed time is the time between the start and stop calls.
         */
        double peek() {
            if (_isRunning) {
                LARGE_INTEGER peekTime;
                auto peekTimeRes = QueryPerformanceCounter(&peekTime);
                assert(peekTimeRes != 0, "QueryPerformanceCounter failed");

                double accumulatedMs = (peekTime.QuadPart - startTime.QuadPart) * 1000 / cast(
                    double) frequency.QuadPart;

                return elapsedMs + accumulatedMs;
            } else {
                return elapsedMs;
            }
        }

        /** 
         * Stops and resets the timer and returns the elapsed time in milliseconds.
         */
        double reset() {
            double elapsed = stop();
            elapsedMs = 0;
            return elapsed;
        }

        bool isRunning() {
            return _isRunning;
        }
    }
}
