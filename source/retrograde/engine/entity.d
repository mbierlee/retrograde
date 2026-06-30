/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.entity;

import retrograde.std.string : String, s;
import retrograde.std.stringid : StringId;
import retrograde.std.memory : UniquePtr, free;
import retrograde.std.collections : Array, SlotList, Slot;
import retrograde.std.result : OperationResult, Result, success, failure;
import retrograde.std.option : Option, some, none;
import retrograde.std.dlang : CopyConstructors;

alias EntityId = uint;

private struct EntityEntry {
    String name;
    Array!Component components;

    mixin CopyConstructors!EntityEntry;
}

private struct Component {
    StringId type;
    void* data;
    void function(void*) destroyer; // null when there is no data
}

alias ProcessorFunction = void delegate(EntityId);
alias EntityAddedHookFunction = void delegate(EntityId);
alias EntityFinalizedHookFunction = void delegate(EntityId);
alias EntityRemovedHookFunction = void delegate(EntityId);

private SlotList!EntityEntry entities;

private Array!ProcessorFunction processors;
private Array!EntityAddedHookFunction entityAddedHooks;
private Array!EntityFinalizedHookFunction entityFinalizedHooks;
private Array!EntityRemovedHookFunction entityRemovedHooks;

Result!EntityId createEntity(String name = String()) {
    EntityEntry entry;
    entry.name = name;
    auto result = entities.add(entry);

    if (!result.isSuccessful) {
        return failure!EntityId(result.errorMessage);
    }

    EntityId entityId = result.value.serialNumber;

    foreach (hook; entityAddedHooks) {
        hook(entityId);
    }

    return success(entityId);
}

Result!EntityId createEntity(string name) {
    return createEntity(name.s);
}

/** 
 * Called when all components are added to an entity.
 */
void finalizeEntity(EntityId entityId) {
    //TODO: prevent double finalization
    //TODO: do not update non-finalized entities
    foreach (hook; entityFinalizedHooks) {
        hook(entityId);
    }
}

OperationResult removeEntity(EntityId entityId) {
    if (entityId == 0) {
        return success;
    }

    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            // Free all component data
            foreach (ref comp; entity.components) {
                if (comp.data !is null) {
                    if (comp.destroyer !is null) {
                        comp.destroyer(comp.data);
                    }

                    free(comp.data);
                }
            }

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
    if (entityId == 0) {
        return false;
    }

    return entities.findIndexBySerial(entityId) != -1;
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
    foreach (size_t i, ref entity; entities) {
        if (entity.name == entityName) {
            return some(entities.getSerial(i));
        }
    }
    return none!EntityId;
}

Option!EntityId getEntityByName(string entityName) {
    return getEntityByName(entityName.s);
}

Option!String getEntityName(EntityId entityId) {
    if (entityId == 0) {
        return none!String;
    }

    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            return some(entity.name);
        }
    }

    return none!String;
}

void addEntityProcessor(ProcessorFunction processor) {
    processors.add(processor);
}

void updateEntities() {
    foreach (processor; processors) {
        foreach (size_t i, ref entity; entities) {
            processor(entities.getSerial(i));
        }
    }
}

void forEachEntity(scope void delegate(EntityId) fn) {
    foreach (size_t i, ref entity; entities) {
        fn(entities.getSerial(i));
    }
}

void addEntityAddedHook(EntityAddedHookFunction fn) {
    entityAddedHooks.add(fn);
}

void addEntityFinalizedHook(EntityFinalizedHookFunction fn) {
    entityFinalizedHooks.add(fn);
}

void addEntityRemovedHook(EntityRemovedHookFunction fn) {
    entityRemovedHooks.add(fn);
}

void addComponent(EntityId entityId, StringId componentType) {
    addComponent(entityId, Component(componentType));
}

void addComponent(T)(EntityId entityId, StringId componentType, UniquePtr!T data) {
    static assert(!is(T == void),
        "addComponent requires a concrete component data type; UniquePtr!void is not allowed.");

    Component component;
    component.type = componentType;
    static if (is(T == struct) && __traits(hasMember, T, "__xdtor")) {
        static void destroyComponentData(void* p) {
            destroy(*cast(T*) p);
        }

        component.destroyer = &destroyComponentData;
    }

    component.data = cast(void*) data.release();
    addComponent(entityId, component);
}

private void addComponent(EntityId entityId, Component component) {
    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            foreach (ref comp; entity.components) {
                if (comp.type == component.type) {
                    // Free old data
                    if (comp.data !is null) {
                        if (comp.destroyer !is null) {
                            comp.destroyer(comp.data);
                        }
                        free(comp.data);
                    }

                    comp.data = component.data;
                    comp.destroyer = component.destroyer;
                    return;
                }
            }

            entity.components.add(component);
            return;
        }
    }
}

void removeComponent(EntityId entityId, StringId componentType) {
    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            foreach (size_t j, ref comp; entity.components) {
                if (comp.type == componentType) {
                    // Free the component data
                    if (comp.data !is null) {
                        if (comp.destroyer !is null) {
                            comp.destroyer(comp.data);
                        }

                        free(comp.data);
                    }

                    entity.components.remove(j);
                    return;
                }
            }

            return;
        }
    }
}

bool hasComponent(EntityId entityId, StringId componentType) {
    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            for (size_t j = 0; j < entity.components.length; j++) {
                if (entity.components[j].type == componentType) {
                    return true;
                }
            }

            return false;
        }
    }

    return false;
}

Option!(T*) getComponentData(T)(EntityId entityId, StringId componentType) {
    foreach (size_t i, ref entity; entities) {
        if (entities.getSerial(i) == entityId) {
            for (size_t j = 0; j < entity.components.length; j++) {
                if (entity.components[j].type == componentType) {
                    return some(cast(T*) entity.components[j].data);
                }
            }

            return none!(T*);
        }
    }

    return none!(T*);
}

void withComponentData(T)(EntityId entityId, StringId componentType, scope void delegate(T*) fn) {
    auto maybeData = getComponentData!T(entityId, componentType);
    if (maybeData.isDefined) {
        fn(maybeData.value);
    }
}

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.std.stringid : sid;
import retrograde.std.memory : makeUnique;
import retrograde.std.string : s;

private __gshared uint destructorCallCount = 0;

private struct DestructorTrackingComponent {
    int value;

    ~this() {
        destructorCallCount++;
    }
}

void resetEcs() {
    entities.clear();
    processors.clear();
    entityAddedHooks.clear();
    entityFinalizedHooks.clear();
    entityRemovedHooks.clear();
}

void runEntityTests() {
    writeSection("-- ECS tests --");

    test("Create entity and add component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType);
        assert(hasComponent(entityId, componentType));
    });

    test("Remove component from entity", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto comp1Type = "comp1_test".sid;
        auto comp2Type = "comp2_test".sid;
        auto comp3Type = "comp3_test".sid;
        addComponent(entityId, comp1Type);
        addComponent(entityId, comp2Type);
        addComponent(entityId, comp3Type);
        assert(hasComponent(entityId, comp1Type));
        assert(hasComponent(entityId, comp2Type));
        assert(hasComponent(entityId, comp3Type));

        removeComponent(entityId, comp2Type);
        assert(hasComponent(entityId, comp1Type));
        assert(!hasComponent(entityId, comp2Type));
        assert(hasComponent(entityId, comp3Type));
    });

    test("Component of same type replaces existing component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto data1 = makeUnique(1);
        auto data2 = makeUnique(2);
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType, data1.move());
        addComponent(entityId, componentType, data2.move());

        auto actualData = getComponentData!int(entityId, componentType);
        assert(actualData.isDefined());
        assert(*actualData.value == 2);
    });

    test("Check whether entity has a certain component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType);

        assert(hasComponent(entityId, componentType));
        assert(!hasComponent(entityId, "comp_donkey".sid));
    });

    test("Add component by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        addComponent(entityId, "comp_test".sid);
        assert(hasComponent(entityId, "comp_test".sid));
    });

    test("Execute delegate with component by type directly on the data", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        static StringId componentType = "comp_test".sid;
        auto data = makeUnique(123);

        addComponent(entityId, componentType, data.move());
        static bool executedWithComponent = false;
        withComponentData!int(entityId, componentType, (int* data) {
            executedWithComponent = *data == 123;
        });

        assert(executedWithComponent);
    });

    test("Directly get data of a component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        static StringId componentType = "comp_test".sid;
        auto data = makeUnique(123);

        addComponent(entityId, componentType, data.move());

        auto actualData = getComponentData!int(entityId, componentType);

        assert(actualData.isDefined());
        assert(*actualData.value == 123);
    });

    test("Created entities are assigned an entity ID", {
        resetEcs();
        EntityId ent1 = createEntity("ent1_test".s).value;
        EntityId ent2 = createEntity("ent2_test".s).value;
        assert(ent1 == 1);
        assert(ent2 == 2);
        assert(entityExists(ent1));
        assert(entityExists(ent2));
    });

    test("Remove entity from entity manager by ID", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        assert(entityId == 1);
        assert(entityExists(entityId));
        removeEntity(entityId);
        assert(!entityExists(entityId));
    });

    test("Check whether entity manager has entity by ID", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        assert(entityExists(entityId));
        assert(!entityExists(999));
    });

    test("Check whether entity manager has entity by name", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        assert(entityExists("ent_test".s));
        assert(!entityExists("nonexistent".s));
    });

    test("Get entity by name", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
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

        EntityId entityId = createEntity("ent_test".s).value;
        updateEntities();
        assert(processedEntityId == entityId);
    });

    test("entityAdded hook is called when entity is created", {
        resetEcs();
        static EntityId hookedEntityId = 0;
        addEntityAddedHook((EntityId entityId) { hookedEntityId = entityId; });

        EntityId entityId = createEntity("ent_test".s).value;
        finalizeEntity(entityId);
        assert(hookedEntityId == entityId);
    });

    test("entityRemoved hook is called when entity is removed", {
        resetEcs();
        static EntityId hookedEntityId = 0;
        addEntityRemovedHook((EntityId entityId) { hookedEntityId = entityId; });

        EntityId entityId = createEntity("ent_test".s).value;
        removeEntity(entityId);
        assert(hookedEntityId == entityId);
    });

    test("Entity creation without name", {
        resetEcs();
        EntityId entityId = createEntity().value;
        assert(entityExists(entityId));
        assert(!entityExists("".s));
    });

    test("Entity creation with name of native string type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test").value;
        assert(entityExists(entityId));
        assert(entityExists("ent_test"));

        auto foundEntity = getEntityByName("ent_test");
        assert(foundEntity.isDefined);
        assert(foundEntity.value == entityId);
    });

    test("Get entity name by ID", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto name = getEntityName(entityId);
        assert(name.isDefined);
        assert(name.value == "ent_test".s);
    });

    test("Get entity name for non-existent entity returns none", {
        resetEcs();
        auto name = getEntityName(999);
        assert(!name.isDefined);
    });

    test("Get entity name for entity ID 0 returns none", {
        resetEcs();
        auto name = getEntityName(0);
        assert(!name.isDefined);
    });

    test("Get entity name for entity without name", {
        resetEcs();
        EntityId entityId = createEntity().value;
        auto name = getEntityName(entityId);
        assert(name.isDefined);
        assert(name.value.length == 0);
    });

    test("Component destructor is invoked on removeEntity", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto componentType = "comp_destructor_test".sid;
        addComponent(entityId, componentType, makeUnique(DestructorTrackingComponent(7)));

        destructorCallCount = 0;
        removeEntity(entityId);
        assert(destructorCallCount == 1);
    });

    test("Component destructor is invoked on removeComponent", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto componentType = "comp_destructor_test".sid;
        addComponent(entityId, componentType, makeUnique(DestructorTrackingComponent(7)));

        destructorCallCount = 0;
        removeComponent(entityId, componentType);
        assert(destructorCallCount == 1);
    });

    test("Component destructor is invoked when component data is replaced", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s).value;
        auto componentType = "comp_destructor_test".sid;
        addComponent(entityId, componentType, makeUnique(DestructorTrackingComponent(1)));
        auto newData = makeUnique(DestructorTrackingComponent(2));

        destructorCallCount = 0;
        addComponent(entityId, componentType, newData.move());
        assert(destructorCallCount == 1);

        removeEntity(entityId);
        assert(destructorCallCount == 2);
    });

    test("addComponent cannot be instantiated with UniquePtr!void", {
        EntityId entityId = 1;
        StringId componentType = "comp_void_test".sid;
        assert(!__traits(compiles, addComponent(entityId, componentType, UniquePtr!void.init)));
    });
}
