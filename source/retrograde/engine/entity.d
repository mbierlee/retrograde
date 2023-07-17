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

/** 
 * An entity is a container for components. It is a logical object that can be
 * used to represent a player, a monster, a bullet, etc.
 */
struct Entity {
    /** 
     * The name of the entity. This is a human-readable name that can be used
     * to identify the entity debug output.
     */
    String name;

    /** 
     * The unique ID of the entity. This is a number that is unique for each
     * entity in the game. It is used to identify the entity in the game world.
     * It is assigned by the EntityManager when the entity is created.
     */
    ulong id = 0;

    private Array!Component components;

    /** 
     * Add a component to the entity. 
     *
     * If the entity already has a component of the same type, the existing
     * component is replaced by the new component.
     *
     * Params:
     *   component = The component to add to the entity.
     */
    void addComponent(Component component) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == component.type) {
                components[i] = component;
                return;
            }
        }

        components.add(component);
    }

    /** 
     * Remove a component from the entity.
     *
     * Params:
     *   component = The component to remove from the entity.
     */
    void removeComponent(const ref Component component) {
        removeComponent(component.type);
    }

    /** 
     * Remove a component from the entity.
     *
     * Params:
     *   componentType = The type of the component to remove from the entity.
     */
    void removeComponent(StringId componentType) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == componentType) {
                components.remove(i);
                return;
            }
        }
    }

    /** 
     * Check whether the entity has a certain component.
     *
     * Params:
     *   component = The component to check for.
     *
     * Returns:
     *   True if the entity has the component, false otherwise.
     */
    bool hasComponent(const ref Component component) {
        return hasComponent(component.type);
    }

    /** 
     * Check whether the entity has a certain component.
     *
     * Params:
     *   componentType = The type of the component to check for.
     *
     * Returns:
     *   True if the entity has the component, false otherwise.
     */
    bool hasComponent(StringId componentType) {
        for (size_t i = 0; i < components.length; i++) {
            if (components[i].type == componentType) {
                return true;
            }
        }

        return false;
    }
}

/** 
 * A component is a container for data. It is a logical object that can be used
 * to represent a position, a sprite, a health value, etc.
 * Components can also be without data, in which case they indicate certain behavior
 * of the entity, for example a component that indicates that the entity is flammable, 
 * destructible, etc.
 */
struct Component {
    /** 
     * The type of the component. 
     * 
     * This is a unique ID that is used to identify the component type.
     */
    StringId type;

    /** 
     * The data of the component. 
     * 
     * This is a smart pointer to the data that is stored in the component. The data
     * is stored as a SharedPtr!void, so it can be any type of data. When no data is
     * stored in the component, the component is regarded as a component that indicates
     * certain behavior of the entity.
     */
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
