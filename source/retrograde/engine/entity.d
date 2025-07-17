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

module retrograde.engine.entity;

import retrograde.std.string : String, s;
import retrograde.std.stringid : StringId;
import retrograde.std.memory : SharedPtr;
import retrograde.std.collections : Array;
import retrograde.std.result : OperationResult, success, failure;
import retrograde.std.option : Option, some, none;
import retrograde.std.dlang : CopyConstructors;

alias EntityId = ulong;

private struct EntityEntry {
    EntityId id;
    String name;
    Array!Component components;

    mixin CopyConstructors!EntityEntry;
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

    mixin CopyConstructors!Component;
}

alias ProcessorFunction = void delegate(ref EntityManager, EntityId);
alias EntityAddedHookFunction = void delegate(ref EntityManager, EntityId);
alias EntityRemovedHookFunction = void delegate(ref EntityManager, EntityId);

struct EntityManager {
    private Array!EntityEntry entities;
    private ulong nextId = 1;

    private Array!ProcessorFunction processors;
    private Array!EntityAddedHookFunction entityAddedHooks;
    private Array!EntityRemovedHookFunction entityRemovedHooks;

    EntityId createEntity(String name = String()) {
        if (nextId == 0) {
            nextId = 1;
        }

        EntityId entityId = nextId++;
        EntityEntry entry;
        entry.id = entityId;
        entry.name = name;
        entities.add(entry);

        foreach (hook; entityAddedHooks) {
            hook(this, entityId);
        }

        return entityId;
    }

    EntityId createEntity(string name) {
        return createEntity(name.s);
    }

    OperationResult removeEntity(EntityId entityId) {
        if (entityId == 0) {
            return success;
        }

        for (size_t i = 0; i < entities.length; i++) {
            if (entities[i].id == entityId) {
                entities.remove(i);
                foreach (hook; entityRemovedHooks) {
                    hook(this, entityId);
                }

                break;
            }
        }

        return success;
    }

    bool hasEntity(EntityId entityId) {
        if (entityId <= 0) {
            return false;
        }

        foreach (entity; entities) {
            if (entity.id == entityId) {
                return true;
            }
        }

        return false;
    }

    bool hasEntity(String entityName) {
        if (entityName.length == 0) {
            return false;
        }

        foreach (ref entity; entities) {
            if (entity.name == entityName) {
                return true;
            }
        }

        return false;
    }

    bool hasEntity(string entityName) {
        return hasEntity(entityName.s);
    }

    Option!EntityId getEntityByName(String entityName) {
        foreach (ref entity; entities) {
            if (entity.name == entityName) {
                return some(entity.id);
            }
        }
        return none!EntityId;
    }

    Option!EntityId getEntityByName(string entityName) {
        return getEntityByName(entityName.s);
    }

    void addProcessor(ProcessorFunction processor) {
        processors.add(processor);
    }

    void update() {
        foreach (processor; processors) {
            foreach (ref entity; entities) {
                processor(this, entity.id);
            }
        }
    }

    void forEachEntity(scope void delegate(EntityId) fn) {
        foreach (entity; entities) {
            fn(entity.id);
        }
    }

    void addEntityAddedHook(EntityAddedHookFunction fn) {
        entityAddedHooks.add(fn);
    }

    void addEntityRemovedHook(EntityRemovedHookFunction fn) {
        entityRemovedHooks.add(fn);
    }

    void addComponent(EntityId entityId, Component component) {
        foreach (ref entity; entities) {
            if (entity.id == entityId) {
                foreach (ref comp; entity.components) {
                    if (comp.type == component.type) {
                        comp = component;
                        return;
                    }
                }
                entity.components.add(component);
                return;
            }
        }
    }

    void addComponent(EntityId entityId, StringId type) {
        addComponent(entityId, Component(type));
    }

    void removeComponent(EntityId entityId, const ref Component component) {
        removeComponent(entityId, component.type);
    }

    void removeComponent(EntityId entityId, StringId componentType) {
        foreach (ref entity; entities) {
            if (entity.id == entityId) {
                foreach (size_t j, ref comp; entity.components) {
                    if (comp.type == componentType) {
                        entity.components.remove(j);
                        return;
                    }
                }
                return;
            }
        }
    }

    bool hasComponent(EntityId entityId, const ref Component component) {
        return hasComponent(entityId, component.type);
    }

    bool hasComponent(EntityId entityId, StringId componentType) {
        for (size_t i = 0; i < entities.length; i++) {
            if (entities[i].id == entityId) {
                for (size_t j = 0; j < entities[i].components.length; j++) {
                    if (entities[i].components[j].type == componentType) {
                        return true;
                    }
                }
                return false;
            }
        }

        return false;
    }

    Option!Component getComponent(EntityId entityId, StringId componentType) {
        for (size_t i = 0; i < entities.length; i++) {
            if (entities[i].id == entityId) {
                for (size_t j = 0; j < entities[i].components.length; j++) {
                    if (entities[i].components[j].type == componentType) {
                        return some(entities[i].components[j]);
                    }
                }
                return none!Component;
            }
        }

        return none!Component;
    }

    Option!(SharedPtr!T) getComponentData(T)(EntityId entityId, StringId componentType) {
        auto maybeComponent = getComponent(entityId, componentType);
        if (maybeComponent.isDefined) {
            return some(maybeComponent.value.data.as!T);
        }

        return none!(SharedPtr!T);
    }

    void withComponent(EntityId entityId, StringId componentType, scope void delegate(Component) fn) {
        auto maybeComponent = getComponent(entityId, componentType);
        if (maybeComponent.isDefined) {
            fn(maybeComponent.value);
        }
    }

    void withComponentData(T)(EntityId entityId, StringId componentType, scope void delegate(T*) fn) {
        auto maybeComponent = getComponent(entityId, componentType);
        if (maybeComponent.isDefined) {
            fn(cast(T*) maybeComponent.value.data.ptr);
        }
    }
}

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.std.stringid : sid;
import retrograde.std.memory : makeSharedVoid;
import retrograde.std.string : s;

void runEntityTests() {
    runEcsTests();
    runEntityManagerTests();
}

void runEcsTests() {
    writeSection("-- Entity Component tests --");

    test("Create entity and add component", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        Component comp = Component("comp_test".sid);
        em.addComponent(entityId, comp);
        assert(em.hasComponent(entityId, comp.type));
    });

    test("Remove component from entity", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        em.addComponent(entityId, comp1);
        em.addComponent(entityId, comp2);
        em.addComponent(entityId, comp3);
        assert(em.hasComponent(entityId, comp1.type));
        assert(em.hasComponent(entityId, comp2.type));
        assert(em.hasComponent(entityId, comp3.type));

        em.removeComponent(entityId, comp2);
        assert(em.hasComponent(entityId, comp1.type));
        assert(!em.hasComponent(entityId, comp2.type));
        assert(em.hasComponent(entityId, comp3.type));
    });

    test("Remove component from entity by type", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        em.addComponent(entityId, comp1);
        em.addComponent(entityId, comp2);
        em.addComponent(entityId, comp3);

        em.removeComponent(entityId, comp2.type);
        assert(em.hasComponent(entityId, comp1.type));
        assert(!em.hasComponent(entityId, comp2.type));
        assert(em.hasComponent(entityId, comp3.type));
    });

    test("Component of same type replaces existing component", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        auto data1 = makeSharedVoid(1);
        auto data2 = makeSharedVoid(2);
        Component comp1 = Component("comp_test".sid, data1);
        Component comp2 = Component("comp_test".sid, data2);
        em.addComponent(entityId, comp1);
        em.addComponent(entityId, comp2);

        auto actualComponent = em.getComponent(entityId, comp2.type);
        assert(actualComponent.isDefined);
        assert(actualComponent.value.type == comp2.type);
        assert(*(cast(int*) actualComponent.value.data.ptr) == 2);
    });

    test("Check whether entity has a certain component", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        Component comp = Component("comp_test".sid);
        em.addComponent(entityId, comp);

        assert(em.hasComponent(entityId, comp));
        assert(em.hasComponent(entityId, comp.type));
        assert(!em.hasComponent(entityId, "comp_donkey".sid));

        Component compNope = Component("comp_nope".sid);
        assert(!em.hasComponent(entityId, compNope));
    });

    test("Add component by type", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        em.addComponent(entityId, "comp_test".sid);
        assert(em.hasComponent(entityId, "comp_test".sid));
    });

    test("Get component by type", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        auto componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto expectedComponent = Component(
            componentType,
            data
        );

        em.addComponent(entityId, expectedComponent);
        auto actualComponentOption = em.getComponent(entityId, componentType);
        assert(actualComponentOption.isDefined);

        auto actualComponent = actualComponentOption.value;
        assert(actualComponent.type == componentType);
        assert(*(cast(int*)(actualComponent.data.ptr)) == 123);
    });

    test("Execute delegate with component by type", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        em.addComponent(entityId, component);
        static bool executedWithComponent = false;
        em.withComponent(entityId, componentType, (Component comp) {
            executedWithComponent =
            comp.type == componentType && *(cast(int*)(comp.data.ptr)) == 123;
        });

        assert(executedWithComponent);
    });

    test("Execute delegate with component by type directly on the data", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        em.addComponent(entityId, component);
        static bool executedWithComponent = false;
        em.withComponentData!int(entityId, componentType, (int* data) {
            executedWithComponent = *data == 123;
        });

        assert(executedWithComponent);
    });

    test("Directly get data of a component", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        em.addComponent(entityId, component);

        auto actualData = em.getComponentData!int(entityId, componentType);

        assert(actualData.isDefined());
        assert(*actualData.value.ptr == 123);
    });
}

void runEntityManagerTests() {
    writeSection("-- Entity Manager tests --");

    test("Created entities are assigned an entity ID", {
        EntityManager em;
        EntityId ent1 = em.createEntity("ent1_test".s);
        EntityId ent2 = em.createEntity("ent2_test".s);
        assert(ent1 == 1);
        assert(ent2 == 2);
        assert(em.hasEntity(ent1));
        assert(em.hasEntity(ent2));
    });

    test("Remove entity from entity manager by ID", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        assert(em.hasEntity(entityId));
        em.removeEntity(entityId);
        assert(!em.hasEntity(entityId));
    });

    test("Check whether entity manager has entity by ID", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        assert(em.hasEntity(entityId));
        assert(!em.hasEntity(999));
    });

    test("Check whether entity manager has entity by name", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        assert(em.hasEntity("ent_test".s));
        assert(!em.hasEntity("nonexistent".s));
    });

    test("Get entity by name", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test".s);
        auto foundEntity = em.getEntityByName("ent_test".s);
        assert(foundEntity.isDefined);
        assert(foundEntity.value == entityId);

        auto notFound = em.getEntityByName("nonexistent".s);
        assert(!notFound.isDefined);
    });

    test("Add entity processor function", {
        EntityManager em;
        ProcessorFunction processor = (ref EntityManager, EntityId) {};
        em.addProcessor(processor);
        assert(em.processors.length == 1);
    });

    test("Updating entity manager invokes entity processor", {
        EntityManager em;
        static EntityId processedEntityId = 0;
        em.addProcessor((ref EntityManager entityManager, EntityId entityId) {
            processedEntityId = entityId;
        });

        EntityId entityId = em.createEntity("ent_test".s);
        em.update();
        assert(processedEntityId == entityId);
    });

    test("entityAdded hook is called when entity is created", {
        EntityManager em;
        static EntityId hookedEntityId = 0;
        em.addEntityAddedHook((ref EntityManager entityManager, EntityId entityId) {
            hookedEntityId = entityId;
        });

        EntityId entityId = em.createEntity("ent_test".s);
        assert(hookedEntityId == entityId);
    });

    test("entityRemoved hook is called when entity is removed", {
        EntityManager em;
        static EntityId hookedEntityId = 0;
        em.addEntityRemovedHook((ref EntityManager entityManager, EntityId entityId) {
            hookedEntityId = entityId;
        });

        EntityId entityId = em.createEntity("ent_test".s);
        em.removeEntity(entityId);
        assert(hookedEntityId == entityId);
    });

    test("Entity creation without name", {
        EntityManager em;
        EntityId entityId = em.createEntity();
        assert(em.hasEntity(entityId));
        assert(!em.hasEntity("".s));
    });

    test("Entity creation with name of native string type", {
        EntityManager em;
        EntityId entityId = em.createEntity("ent_test");
        assert(em.hasEntity(entityId));
        assert(em.hasEntity("ent_test"));

        auto foundEntity = em.getEntityByName("ent_test");
        assert(foundEntity.isDefined);
        assert(foundEntity.value == entityId);
    });
}
