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

alias ProcessorFunction = void delegate(EntityId);
alias EntityAddedHookFunction = void delegate(EntityId);
alias EntityRemovedHookFunction = void delegate(EntityId);

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
        hook(entityId);
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
                hook(entityId);
            }

            break;
        }
    }

    return success;
}

bool entityExists(EntityId entityId) {
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

bool entityExists(String entityName) {
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

bool entityExists(string entityName) {
    return entityExists(entityName.s);
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

void addEntityProcessor(ProcessorFunction processor) {
    processors.add(processor);
}

void updateEntities() {
    foreach (processor; processors) {
        foreach (ref entity; entities) {
            processor(entity.id);
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

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.std.stringid : sid;
import retrograde.std.memory : makeSharedVoid;
import retrograde.std.string : s;

void resetEcs() {
    nextId = 1;
    entities.clear();
    processors.clear();
    entityAddedHooks.clear();
    entityRemovedHooks.clear();
}

void runEntityTests() {
    writeSection("-- ECS tests --");

    test("Create entity and add component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        Component comp = Component("comp_test".sid);
        addComponent(entityId, comp);
        assert(hasComponent(entityId, comp.type));
    });

    test("Remove component from entity", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        addComponent(entityId, comp1);
        addComponent(entityId, comp2);
        addComponent(entityId, comp3);
        assert(hasComponent(entityId, comp1.type));
        assert(hasComponent(entityId, comp2.type));
        assert(hasComponent(entityId, comp3.type));

        removeComponent(entityId, comp2);
        assert(hasComponent(entityId, comp1.type));
        assert(!hasComponent(entityId, comp2.type));
        assert(hasComponent(entityId, comp3.type));
    });

    test("Remove component from entity by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        Component comp1 = Component("comp1_test".sid);
        Component comp2 = Component("comp2_test".sid);
        Component comp3 = Component("comp3_test".sid);
        addComponent(entityId, comp1);
        addComponent(entityId, comp2);
        addComponent(entityId, comp3);

        removeComponent(entityId, comp2.type);
        assert(hasComponent(entityId, comp1.type));
        assert(!hasComponent(entityId, comp2.type));
        assert(hasComponent(entityId, comp3.type));
    });

    test("Component of same type replaces existing component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        auto data1 = makeSharedVoid(1);
        auto data2 = makeSharedVoid(2);
        Component comp1 = Component("comp_test".sid, data1);
        Component comp2 = Component("comp_test".sid, data2);
        addComponent(entityId, comp1);
        addComponent(entityId, comp2);

        auto actualComponent = getComponent(entityId, comp2.type);
        assert(actualComponent.isDefined);
        assert(actualComponent.value.type == comp2.type);
        assert(*(cast(int*) actualComponent.value.data.ptr) == 2);
    });

    test("Check whether entity has a certain component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        Component comp = Component("comp_test".sid);
        addComponent(entityId, comp);

        assert(hasComponent(entityId, comp));
        assert(hasComponent(entityId, comp.type));
        assert(!hasComponent(entityId, "comp_donkey".sid));

        Component compNope = Component("comp_nope".sid);
        assert(!hasComponent(entityId, compNope));
    });

    test("Add component by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        addComponent(entityId, "comp_test".sid);
        assert(hasComponent(entityId, "comp_test".sid));
    });

    test("Get component by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        auto componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto expectedComponent = Component(
            componentType,
            data
        );

        addComponent(entityId, expectedComponent);
        auto actualComponentOption = getComponent(entityId, componentType);
        assert(actualComponentOption.isDefined);

        auto actualComponent = actualComponentOption.value;
        assert(actualComponent.type == componentType);
        assert(*(cast(int*)(actualComponent.data.ptr)) == 123);
    });

    test("Execute delegate with component by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        addComponent(entityId, component);
        static bool executedWithComponent = false;
        withComponent(entityId, componentType, (Component comp) {
            executedWithComponent =
            comp.type == componentType && *(cast(int*)(comp.data.ptr)) == 123;
        });

        assert(executedWithComponent);
    });

    test("Execute delegate with component by type directly on the data", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        addComponent(entityId, component);
        static bool executedWithComponent = false;
        withComponentData!int(entityId, componentType, (int* data) {
            executedWithComponent = *data == 123;
        });

        assert(executedWithComponent);
    });

    test("Directly get data of a component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeSharedVoid(123);
        auto component = Component(
            componentType,
            data
        );

        addComponent(entityId, component);

        auto actualData = getComponentData!int(entityId, componentType);

        assert(actualData.isDefined());
        assert(*actualData.value.ptr == 123);
    });

    test("Created entities are assigned an entity ID", {
        resetEcs();
        EntityId ent1 = createEntity("ent1_test".s);
        EntityId ent2 = createEntity("ent2_test".s);
        assert(ent1 == 1);
        assert(ent2 == 2);
        assert(entityExists(ent1));
        assert(entityExists(ent2));
    });

    test("Remove entity from entity manager by ID", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        assert(entityId == 1);
        assert(entityExists(entityId));
        removeEntity(entityId);
        assert(!entityExists(entityId));
    });

    test("Check whether entity manager has entity by ID", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        assert(entityExists(entityId));
        assert(!entityExists(999));
    });

    test("Check whether entity manager has entity by name", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        assert(entityExists("ent_test".s));
        assert(!entityExists("nonexistent".s));
    });

    test("Get entity by name", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        auto foundEntity = getEntityByName("ent_test".s);
        assert(foundEntity.isDefined);
        assert(foundEntity.value == entityId);

        auto notFound = getEntityByName("nonexistent".s);
        assert(!notFound.isDefined);
    });

    test("Add entity processor function", {
        resetEcs();
        ProcessorFunction processor = (EntityId) {};
        addEntityProcessor(processor);
        assert(processors.length == 1);
    });

    test("Updating entity manager invokes entity processor", {
        resetEcs();
        static EntityId processedEntityId = 0;
        addEntityProcessor((EntityId entityId) { processedEntityId = entityId; });

        EntityId entityId = createEntity("ent_test".s);
        updateEntities();
        assert(processedEntityId == entityId);
    });

    test("entityAdded hook is called when entity is created", {
        resetEcs();
        static EntityId hookedEntityId = 0;
        addEntityAddedHook((EntityId entityId) { hookedEntityId = entityId; });

        EntityId entityId = createEntity("ent_test".s);
        assert(hookedEntityId == entityId);
    });

    test("entityRemoved hook is called when entity is removed", {
        resetEcs();
        static EntityId hookedEntityId = 0;
        addEntityRemovedHook((EntityId entityId) { hookedEntityId = entityId; });

        EntityId entityId = createEntity("ent_test".s);
        removeEntity(entityId);
        assert(hookedEntityId == entityId);
    });

    test("Entity creation without name", {
        resetEcs();
        EntityId entityId = createEntity();
        assert(entityExists(entityId));
        assert(!entityExists("".s));
    });

    test("Entity creation with name of native string type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test");
        assert(entityExists(entityId));
        assert(entityExists("ent_test"));

        auto foundEntity = getEntityByName("ent_test");
        assert(foundEntity.isDefined);
        assert(foundEntity.value == entityId);
    });
}
