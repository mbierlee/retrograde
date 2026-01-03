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
import retrograde.std.memory : UniquePtr, free;
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

private struct Component {
    StringId type;
    void* data;

    this(ref return scope const typeof(this) other) {
        type = other.type;
        data = cast(void*) other.data;
    }

    void opAssign(ref const typeof(this) other) {
        type = other.type;
        data = cast(void*) other.data;
    }
}

alias ProcessorFunction = void delegate(EntityId);
alias EntityAddedHookFunction = void delegate(EntityId);
alias EntityFinalizedHookFunction = void delegate(EntityId);
alias EntityRemovedHookFunction = void delegate(EntityId);

private Array!EntityEntry entities;
private ulong nextId = 1;

private Array!ProcessorFunction processors;
private Array!EntityAddedHookFunction entityAddedHooks;
private Array!EntityFinalizedHookFunction entityFinalizedHooks;
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

    for (size_t i = 0; i < entities.length; i++) {
        if (entities[i].id == entityId) {
            // Free all component data
            foreach (ref comp; entities[i].components) {
                if (comp.data !is null) {
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

void addEntityFinalizedHook(EntityFinalizedHookFunction fn) {
    entityFinalizedHooks.add(fn);
}

void addEntityRemovedHook(EntityRemovedHookFunction fn) {
    entityRemovedHooks.add(fn);
}

void addComponent(EntityId entityId, StringId componentType) {
    addComponent(entityId, Component(componentType));
}

void addComponent(EntityId entityId, StringId componentType, UniquePtr!void data) {
    Component component;
    component.type = componentType;
    component.data = data.release();
    addComponent(entityId, component);
}

private void addComponent(EntityId entityId, Component component) {
    foreach (ref entity; entities) {
        if (entity.id == entityId) {
            foreach (ref comp; entity.components) {
                if (comp.type == component.type) {
                    // Free old data
                    if (comp.data !is null) {
                        free(comp.data);
                    }
                    comp.data = component.data;
                    return;
                }
            }

            entity.components.add(component);
            return;
        }
    }
}

void removeComponent(EntityId entityId, StringId componentType) {
    foreach (ref entity; entities) {
        if (entity.id == entityId) {
            foreach (size_t j, ref comp; entity.components) {
                if (comp.type == componentType) {
                    // Free the component data
                    if (comp.data !is null) {
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

Option!(T*) getComponentData(T)(EntityId entityId, StringId componentType) {
    for (size_t i = 0; i < entities.length; i++) {
        if (entities[i].id == entityId) {
            for (size_t j = 0; j < entities[i].components.length; j++) {
                if (entities[i].components[j].type == componentType) {
                    return some(cast(T*) entities[i].components[j].data);
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
import retrograde.std.memory : makeUniqueVoid;
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
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType);
        assert(hasComponent(entityId, componentType));
    });

    test("Remove component from entity", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
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
        EntityId entityId = createEntity("ent_test".s);
        auto data1 = makeUniqueVoid(1);
        auto data2 = makeUniqueVoid(2);
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType, data1.move());
        addComponent(entityId, componentType, data2.move());

        auto actualData = getComponentData!int(entityId, componentType);
        assert(actualData.isDefined());
        assert(*actualData.value == 2);
    });

    test("Check whether entity has a certain component", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        auto componentType = "comp_test".sid;
        addComponent(entityId, componentType);

        assert(hasComponent(entityId, componentType));
        assert(!hasComponent(entityId, "comp_donkey".sid));
    });

    test("Add component by type", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        addComponent(entityId, "comp_test".sid);
        assert(hasComponent(entityId, "comp_test".sid));
    });

    test("Execute delegate with component by type directly on the data", {
        resetEcs();
        EntityId entityId = createEntity("ent_test".s);
        static StringId componentType = "comp_test".sid;
        auto data = makeUniqueVoid(123);

        addComponent(entityId, componentType, data.move());
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
        auto data = makeUniqueVoid(123);

        addComponent(entityId, componentType, data.move());

        auto actualData = getComponentData!int(entityId, componentType);

        assert(actualData.isDefined());
        assert(*actualData.value == 123);
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
        finalizeEntity(entityId);
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
