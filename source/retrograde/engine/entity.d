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

module retrograde.engine.entity;

import retrograde.std.string : String, s;
import retrograde.std.stringid : StringId;
import retrograde.std.memory : SharedPtr;
import retrograde.std.collections : Array;

struct Entity {
    String name;
    ulong id = 0;
    private Array!Component components;

    void addComponent(Component component) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == component.type) {
                components[i] = component;
                return;
            }
        }

        components.add(component);
    }

    void removeComponent(const ref Component component) {
        removeComponent(component.type);
    }

    void removeComponent(StringId componentType) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == componentType) {
                components.remove(i);
                return;
            }
        }
    }

    bool hasComponent(const ref Component component) {
        return hasComponent(component.type);
    }

    bool hasComponent(StringId componentType) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == componentType) {
                return true;
            }
        }

        return false;
    }
}

struct Component {
    StringId type;
    SharedPtr!void data;
}

version (UnitTesting)  :  ///

void runEntityTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.stringid : sid;
    import retrograde.std.memory : makeSharedVoid;

    writeSection("-- Entity tests --");

    test("Create entity and add component", {
        Entity ent = Entity("ent_test".s);
        Component comp = Component("comp_test".sid);
        ent.addComponent(comp);
        assert(ent.components.length == 1);
        assert(ent.components[0].type == comp.type);
    });

    test("Remove component from entity", {
        Entity ent = Entity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        ent.addComponent(comp1);
        ent.addComponent(comp2);
        ent.addComponent(comp3);
        assert(ent.components.length == 3);

        ent.removeComponent(comp2);
        assert(ent.components.length == 2);
        assert(ent.components[0].type == comp1.type);
        assert(ent.components[1].type == comp3.type);
    });

    test("Remove component from entity by type", {
        Entity ent = Entity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        ent.addComponent(comp1);
        ent.addComponent(comp2);
        ent.addComponent(comp3);
        assert(ent.components.length == 3);

        ent.removeComponent(comp2.type);
        assert(ent.components.length == 2);
        assert(ent.components[0].type == comp1.type);
        assert(ent.components[1].type == comp3.type);
    });

    test("Component of same type replaces existing component", {
        Entity ent = Entity("ent_test".s);
        auto data1 = makeSharedVoid(1);
        auto data2 = makeSharedVoid(2);
        Component comp1 = Component("comp_test".sid, data1);
        Component comp2 = Component("comp_test".sid, data2);
        ent.addComponent(comp1);
        ent.addComponent(comp2);
        assert(ent.components.length == 1);
        assert(ent.components[0].type == comp2.type);
        assert(*(cast(int*) ent.components[0].data.ptr) == 2);
    });

    test("Check whether entity has a certain component", {
        Entity ent = Entity("ent_test".s);
        Component comp = Component("comp_test".sid);
        ent.addComponent(comp);

        assert(ent.hasComponent(comp));
        assert(ent.hasComponent(comp.type));
        assert(!ent.hasComponent("comp_donkey".sid));

        Component compNope = Component("comp_nope".sid);
        assert(!ent.hasComponent(compNope));
    });
}
