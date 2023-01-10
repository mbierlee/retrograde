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

module source.retrograde.test.sanity;

version (unittest) {

    // Basic truthy tests to make sure the test set-up is ok.
    @("Truthy")
    unittest {
        assert(true == true);
        assert(1 == 1);
        assert(2 > 1);
        // assert(true == false); // Enable to test whether the testrunner trips
    }

}
