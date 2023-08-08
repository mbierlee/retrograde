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

module retrograde.engine.service;

import retrograde.engine.entity : EntityManager;

EntityManager entityManager;

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.engine.entity : Entity;
import retrograde.std.string : s;
import retrograde.std.memory : makeShared;

void runServiceTests() {
    writeSection("-- Service tests --");

    test("Use global entity manager", {
        auto ent = makeShared(Entity("ent_test".s));
        auto res = entityManager.addEntity(ent);
        assert(res.isSuccessful);
    });
}
