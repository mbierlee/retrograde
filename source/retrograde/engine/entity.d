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
import retrograde.std.memory : SharedPtr, makeShared;
import retrograde.std.collections : Array;
import retrograde.std.result : OperationResult, success, failure;

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

    private ulong _id = 0;

    private Array!Component components;

    this(ref return scope inout typeof(this) other) {
        this.name = other.name;
        this._id = other._id;
        this.components = other.components;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.name = other.name;
        this._id = other._id;
        this.components = other.components;
    }

    /**
     * Returns: The unique ID of the entity.
     *
     * This is a number that is unique for each entity in the game.
     * It is used to identify the entity in the game world.
     * It is assigned by the EntityManager when the entity is created.
     */
    ulong id() const {
        return _id;
    }

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
     * Add a compontent to the entity with the given type. 
     *
     * It is assumed this component has no data. If the entity already has a component of the same type, 
     * the existing component is replaced.
     *
     * Params:
     *   type = Type of the component to add
     */
    void addComponent(StringId type) {
        addComponent(Component(type));
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

    this(ref return scope inout typeof(this) other) {
        this.type = other.type;
        this.data = other.data;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.type = other.type;
        this.data = other.data;
    }
}

alias ProcessorFunc = void delegate(SharedPtr!Entity);

struct EntityManager {
    private Array!(SharedPtr!Entity) entities;
    private ulong nextId = 1;
    private Array!ProcessorFunc processors;

    OperationResult addEntity(SharedPtr!Entity entity) {
        if (nextId == 0) {
            nextId = 1; // In case someone initializes the entity manager from a raw, zeroed pointer.
        }

        if (!entity.isDefined) {
            return failure("Shared pointer of entity is null.");
        }

        if (entity.ptr._id != 0) {
            return failure(
                "Entity already has an ID, it might already be added to the entity manager.");
        }

        entity.ptr._id = nextId++;
        entities.add(entity);
        return success;
    }

    OperationResult removeEntity(SharedPtr!Entity entity) {
        if (!entity.isDefined) {
            return failure("Shared pointer of entity is null.");
        }

        return removeEntity(entity.ptr.id);
    }

    OperationResult removeEntity(ulong entityId) {
        if (entityId == 0) {
            return success;
        }

        foreach (size_t i, entity; entities) {
            if (entity.ptr.id == entityId) {
                entities.remove(i);
                break;
            }
        }

        return success;
    }

    bool hasEntity(SharedPtr!Entity entity) {
        if (!entity.isDefined) {
            return false;
        }

        return hasEntity(entity.ptr.id);
    }

    bool hasEntity(ulong entityId) {
        if (entityId == 0) {
            return false;
        }

        foreach (size_t i, entity; entities) {
            if (entity.ptr.id == entityId) {
                return true;
            }
        }

        return false;
    }

    bool hasEntity(String entityName) {
        foreach (size_t i, entity; entities) {
            if (entity.ptr.name == entityName) {
                return true;
            }
        }

        return false;
    }

    void addProcessor(ProcessorFunc processor) {
        processors.add(processor);
    }

    void update() {
        foreach (processor; processors) {
            foreach (entity; entities) {
                if (entity.isDefined) {
                    processor(entity);
                }
            }
        }
    }

    void forEachEntity(void delegate(SharedPtr!Entity) fn) {
        foreach (entity; entities) {
            fn(entity);
        }
    }
}

SharedPtr!Entity makeEntity(string name) {
    return makeShared(Entity(name.s));
}

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.std.stringid : sid;
import retrograde.std.memory : makeSharedVoid;

void runEntityTests() {
    runEcsTests();
    runEntityManagerTests();
}

void runEcsTests() {
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

    test("Add component by type", {
        Entity ent = Entity("ent_test".s);
        ent.addComponent("comp_test".sid);
        assert(ent.hasComponent("comp_test".sid));
    });
}

void runEntityManagerTests() {
    writeSection("-- Entity Manager tests --");

    test("Added entities are assigned an entity ID", {
        EntityManager em;
        auto ent1 = makeEntity("ent1_test");
        auto ent2 = makeEntity("ent2_test");
        auto res1 = em.addEntity(ent1);
        auto res2 = em.addEntity(ent2);
        assert(ent1.id == 1);
        assert(ent2.id == 2);
        assert(res1.isSuccessful);
        assert(res2.isSuccessful);
    });

    test("Cannot add entities that already have an entity ID", {
        EntityManager em;
        auto ent = makeEntity("ent1_test");
        ent.ptr._id = 1;
        auto res = em.addEntity(ent);
        assert(ent.id == 1);
        assert(!res.isSuccessful);
    });

    test("Cannot add entities with undefined shared pointer", {
        EntityManager em;
        SharedPtr!Entity ent;
        auto res = em.addEntity(ent);
        assert(!res.isSuccessful);
    });

    test("Remove entity from entity manager", {
        EntityManager em;
        auto ent = makeEntity("ent_test");
        em.addEntity(ent);
        assert(em.entities.length == 1);
        em.removeEntity(ent);
        assert(em.entities.length == 0);
    });

    test("Remove entity from entity manager by ID", {
        EntityManager em;
        auto ent = makeEntity("ent_test");
        em.addEntity(ent);
        assert(em.entities.length == 1);
        em.removeEntity(ent.id);
        assert(em.entities.length == 0);
    });

    test("Check wheter entity manager has entity", {
        EntityManager em;
        auto ent = makeEntity("ent_test");
        em.addEntity(ent);
        assert(em.hasEntity(ent));
    });

    test("Check wheter entity manager has entity by ID", {
        EntityManager em;
        auto ent = makeEntity("ent_test");
        em.addEntity(ent);
        assert(em.hasEntity(ent.id));
    });

    test("Check wheter entity manager has entity by name", {
        EntityManager em;
        auto ent = makeEntity("ent_test");
        em.addEntity(ent);
        assert(em.hasEntity("ent_test".s));
    });

    test("Add entity processor function", {
        EntityManager em;
        ProcessorFunc processor = (SharedPtr!Entity ent) {};
        em.addProcessor(processor);
        assert(em.processors.length == 1);
    });

    test("Updating entity manager invokes entity processor", {
        EntityManager em;
        static bool testEntityProcessed = false;
        ProcessorFunc processor = (SharedPtr!Entity ent) {
            testEntityProcessed = testEntityProcessed || ent.ptr.name == "ent_test".s;
        };

        auto ent = makeEntity("ent_test");
        em.addEntity(ent);

        em.addProcessor(processor);
        em.update();
        assert(testEntityProcessed);
    });

}
