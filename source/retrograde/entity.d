/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.entity;

import retrograde.stringid;
import retrograde.option;
import retrograde.messaging;
import retrograde.stringid;

import std.string;
import std.exception;

import poodinis;

class Entity {
    private string _name;
    private bool _isFinalized;
    public uint id = 0;

    public Entity parent;

    private EntityComponent[StringId] _components;

    public @property name() {
        return _name;
    }

    public @property components() {
        return _components.values;
    }

    public @property isFinalized() {
        return _isFinalized;
    }

    this() {
        this("Undefined");
    }

    this(string name) {
        this._name = name;
    }

    private void enforceNonFinalized(string message) {
        if (isFinalized) {
            throw new EntityIsFinalizedException(this, message);
        }
    }

    public void addComponent(EntityComponent component) {
        enforce!Exception(component !is null, "Passed component reference is null.");
        enforceNonFinalized("Cannot add new component, entity is finalized. Entities will become finalized when they are added to the entity manager or by calling Entity.finalize().");
        auto type = component.getComponentType();
        _components[type] = component;
    }

    public void addComponent(EntityComponentType : EntityComponent)() {
        TypeInfo_Class typeInfo = typeid(EntityComponentType);
        auto component = cast(EntityComponentType) typeInfo.create();
        enforce!Exception(component !is null,
                format("Error creating component of type %s. Does the component have a default constructor?",
                    typeInfo));
        addComponent(component);
    }

    public void removeComponent(EntityComponent component) {
        enforce!Exception(component !is null, "Passed component reference is null.");
        auto type = component.getComponentType();
        removeComponent(type);
    }

    public void removeComponent(StringId componentType) {
        enforceNonFinalized("Cannot remove components, entity is finalized. Entities will become finalized when they are added to the entity manager or by calling Entity.finalize().");
        _components.remove(componentType);
    }

    public void removeComponent(EntityComponentType : EntityComponent)() {
        StringId componentType = EntityComponentType.componentType;
        removeComponent(componentType);
    }

    public bool hasComponent(EntityComponent component) {
        enforce!Exception(component !is null, "Passed component reference is null.");
        return hasComponent(component.getComponentType());
    }

    public bool hasComponent(EntityComponentType : EntityComponent)() {
        StringId componentType = EntityComponentType.componentType;
        return hasComponent(componentType);
    }

    public bool hasComponent(StringId componentType) {
        return (componentType in _components) !is null;
    }

    public void maybeWithComponent(EntityComponentType : EntityComponent)(
            void delegate(EntityComponentType) fn) {
        if (hasComponent!EntityComponentType) {
            withComponent(fn);
        }
    }

    public void withComponent(EntityComponentType : EntityComponent)(
            void delegate(EntityComponentType) fn) {
        fn(getComponent!EntityComponentType);
    }

    public ReturnType getFromComponent(EntityComponentType : EntityComponent, ReturnType)(
            ReturnType delegate(EntityComponentType) fn) {
        return fn(getComponent!EntityComponentType);
    }

    public ReturnType getFromComponent(EntityComponentType : EntityComponent, ReturnType)(
            ReturnType delegate(EntityComponentType) fn, lazy ReturnType defaultValue) {
        return hasComponent!EntityComponentType ? getFromComponent(fn) : defaultValue();
    }

    public EntityComponentType getComponent(EntityComponentType : EntityComponent)() {
        StringId componentType = EntityComponentType.componentType;
        return cast(EntityComponentType) getComponent(componentType);
    }

    public EntityComponent getComponent(StringId componentType) {
        auto component = componentType in _components;
        if (component is null) {
            throw new ComponentNotFoundException(componentType, this);
        }

        return *component;
    }

    public void clearComponents() {
        enforceNonFinalized("Cannot clear components.");
        _components.destroy();
    }

    public void finalize() {
        _isFinalized = true;
    }
}

class ComponentNotFoundException : Exception {
    this(StringId componentType, Entity sourceEntity) {
        super(format("Component of type %s not added to entity %s(%s)",
                componentType, sourceEntity.name, sourceEntity.id));
    }
}

class EntityIsFinalizedException : Exception {
    this(Entity entity, string additionalMessage) {
        super(format("Entity %s with id %s is finalized. %s", entity.name,
                entity.id, additionalMessage));
    }
}

interface EntityComponent {
    StringId getComponentType();
    string getComponentTypeString();
}

interface Snapshotable {
    string[string] getSnapshotData();
}

mixin template EntityComponentIdentity(string ComponentType) {
    import retrograde.stringid;

    public static const StringId componentType = sid(ComponentType);

    public StringId getComponentType() {
        return componentType;
    }

    public string getComponentTypeString() {
        return ComponentType;
    }
}

class HierarchialEntityCollection : EntityCollection {

    private Entity[][Entity] entityChildren;
    private Entity[uint] _rootEntities;

    private bool entityHierarchyChanged = false;

    public @property Entity[] rootEntities() {
        return _rootEntities.values;
    }

    public Entity[] getChildrenOfEntity(Entity entity) {
        auto children = entity in entityChildren;
        if (children) {
            return *children;
        }

        return [];
    }

    public override void addEntity(Entity entity) {
        entityHierarchyChanged = true;
        super.addEntity(entity);
    }

    public override void removeEntity(Entity entity) {
        entityHierarchyChanged = true;
        super.removeEntity(entity);
    }

    public override void removeEntity(uint entityId) {
        entityHierarchyChanged = true;
        super.removeEntity(entityId);
    }

    public void updateHierarchy() {
        if (entityHierarchyChanged) {
            recreateEntityHierarchy();
            entityHierarchyChanged = false;
        }
    }

    private void recreateEntityHierarchy() {
        _rootEntities.destroy();
        entityChildren.destroy();
        foreach (entity; getAll()) {
            if (entity.parent !is null) {
                entityChildren[entity.parent] ~= entity;
                if (entity.parent.parent is null) {
                    _rootEntities[entity.parent.id] = entity.parent;
                }
            } else {
                _rootEntities[entity.id] = entity;
            }
        }
    }

    public void forEachChild(void delegate(Entity entity) fn) {
        foreach (entity; _rootEntities.values) {
            forEachChild(entity, fn);
        }
    }

    private void forEachChild(Entity entity, void delegate(Entity entity) fn) {
        auto children = entity in entityChildren;
        if (children) {
            foreach (child; *children) {
                fn(child);
                forEachChild(child, fn);
            }
        }
    }

    public void forEachRootEntity(void delegate(Entity entity) fn) {
        foreach (entity; _rootEntities.values) {
            fn(entity);
        }
    }
}

class EntityCollection {
    private Entity[uint] entities;

    public @property uint length() {
        return entities.length;
    }

    public void addEntity(Entity entity) {
        assert(entity.id > 0, "Entity id has not been set (entity ids cannot be 0)");
        entities[entity.id] = entity;
    }

    public void removeEntity(Entity entity) {
        removeEntity(entity.id);
    }

    public void removeEntity(uint entityId) {
        entities.remove(entityId);
    }

    public Entity getEntity(uint entityId) {
        return this[entityId];
    }

    Entity opIndex(uint entityId) {
        return entities[entityId];
    }

    public void clearEntities() {
        entities.destroy();
    }

    public bool hasEntity(Entity entity) {
        assert(entity !is null);
        if (hasEntity(entity.id)) {
            auto myEntity = this[entity.id];
            return myEntity is entity;
        }

        return false;
    }

    public bool hasEntity(uint entityId) {
        Entity* entity = entityId in entities;
        return entity !is null;
    }

    public Entity[] getAll() {
        return entities.values;
    }
}

class EntityManager {
    private EntityCollection _entities = new EntityCollection();
    private EntityProcessor[] _processors;
    private uint nextAvailableId = 1;

    public @property entities() {
        return _entities.getAll();
    }

    public @property processors() {
        return _processors;
    }

    public void addEntity(Entity entity) {
        if (!entity.isFinalized) {
            entity.finalize();
        }

        entity.id = nextAvailableId++;
        _entities.addEntity(entity);
        foreach (processor; _processors) {
            processor.addEntity(entity);
        }
    }

    public void addEntityProcessors(EntityProcessor[] processors) {
        foreach (processor; processors) {
            addEntityProcessor(processor);
        }
    }

    public void addEntityProcessor(EntityProcessor processor) {
        _processors ~= processor;
        foreach (entity; _entities.getAll()) {
            processor.addEntity(entity);
        }
    }

    public void initializeEntityProcessors() {
        foreach (processor; _processors) {
            processor.initialize();
        }
    }

    public void cleanupEntityProcessors() {
        foreach (processor; _processors) {
            processor.cleanup();
        }
    }

    public bool hasEntity(uint entityId) {
        return _entities.hasEntity(entityId);
    }

    public bool hasEntity(Entity entity) {
        return hasEntity(entity.id);
    }

    public void removeEntity(uint entityId) {
        _entities.removeEntity(entityId);
        foreach (processor; _processors) {
            if (processor.hasEntity(entityId)) {
                processor.removeEntity(entityId);
            }
        }
    }

    public void removeEntity(Entity entity) {
        removeEntity(entity.id);
    }

    public void update() {
        foreach (processor; _processors) {
            processor.update();
        }
    }

    public void draw() {
        foreach (processor; _processors) {
            processor.draw();
        }
    }
}

abstract class EntityProcessor {
    protected EntityCollection _entities;

    abstract public bool acceptsEntity(Entity entity);

    public void initialize() {
    }

    public void update() {
    }

    public void draw() {
    }

    public void cleanup() {
    }

    public @property entityCount() {
        return _entities.length();
    }

    public @property entities() {
        return _entities.getAll();
    }

    public this() {
        _entities = new EntityCollection();
    }

    public void addEntity(Entity entity) {
        enforce!Exception(entity.isFinalized,
                "An unfinalized entity was added to entity processor. Finalize entities first using Entity.finalize()");
        if (!acceptsEntity(entity))
            return;

        _entities.addEntity(entity);
        processAcceptedEntity(entity);
    }

    protected void processAcceptedEntity(Entity entity) {
    }

    public bool hasEntity(uint entityId) {
        return _entities.hasEntity(entityId);
    }

    public bool hasEntity(Entity entity) {
        return hasEntity(entity.id);
    }

    public void removeEntity(uint entityId) {
        auto entity = _entities[entityId];
        _entities.removeEntity(entityId);
        processRemovedEntity(entity);
    }

    protected void processRemovedEntity(Entity entity) {
    }
}

interface CreationParameters {
}

abstract class EntityFactory {
    private string _entityName;

    public @property entityName() {
        return this._entityName;
    }

    this(string entityName) {
        this._entityName = entityName;
    }

    protected Entity createBlankEntity() {
        return new Entity(entityName);
    }

    public bool createsEntity(string entityName) {
        return entityName == this.entityName;
    }

    public abstract Entity createEntity(CreationParameters parameters);
}

class EntityLifecycleMessageData : MessageData {
    private Entity _entity;

    public @property Entity entity() {
        return _entity;
    }

    this(Entity entity) {
        this._entity = entity;
    }
}

class EntityCreationMessageData : MessageData {
    private CreationParameters _creationParameters;
    private string _entityName;

    public @property creationParameters() {
        return this._creationParameters;
    }

    public @property entityName() {
        return this._entityName;
    }

    this(string entityName, CreationParameters creationParameters = null) {
        this._entityName = entityName;
        this._creationParameters = creationParameters;
    }
}

class EntityLifecycleCommandChannel : CommandChannel {
    public void createEntity(string entityName, CreationParameters creationParameters = null) {
        emit(Command(EntityLifecycleCommand.createEntity, 0,
                new EntityCreationMessageData(entityName, creationParameters)));
    }

    public void addEntity(Entity entity) {
        emit(Command(EntityLifecycleCommand.addEntity, 0, new EntityLifecycleMessageData(entity)));
    }

    public void removeEntity(Entity entity) {
        emit(Command(EntityLifecycleCommand.removeEntity, 0,
                new EntityLifecycleMessageData(entity)));
    }
}

class EntityLifecycleEventChannel : EventChannel {
}

enum EntityLifecycleCommand : StringId {
    addEntity = sid("cmd_add_entity"),
    removeEntity = sid("cmd_remove_entity"),
    createEntity = sid("cmd_create_entity")
}

enum EntityLifecycleEvent : StringId {
    entityAdded = sid("ev_entity_added"),
    entityRemoved = sid("ev_entity_removed")
}

public void registerLifecycleDebugSids(SidMap sidMap) {
    sidMap.add("cmd_add_entity");
    sidMap.add("cmd_remove_entity");
    sidMap.add("cmd_create_entity");
    sidMap.add("ev_entity_added");
    sidMap.add("ev_entity_removed");
}

class EntityChannelManager : MessageProcessor {
    @Autowire private EntityLifecycleEventChannel eventChannel;

    @Autowire private EntityManager entityManager;

    @Autowire @OptionalDependency private EntityFactory[] entitityFactories;

    private EntityFactory[string] entitityFactoriesByName;

    this(EntityLifecycleCommandChannel sourceChannel) {
        super(sourceChannel);
    }

    public override void initialize() {
        super.initialize();
        foreach (entityFactory; entitityFactories) {
            entitityFactoriesByName[entityFactory.entityName] = entityFactory;
        }
        entitityFactories.destroy();
    }

    protected override void handleMessage(const Command command) {
        switch (command.type) {
        case EntityLifecycleCommand.addEntity:
            auto data = cast(EntityLifecycleMessageData) command.data;
            if (data is null || data.entity is null) {
                return;
            }

            entityManager.addEntity(data.entity);
            eventChannel.emit(Event(EntityLifecycleEvent.entityAdded, 1, data));
            break;

        case EntityLifecycleCommand.removeEntity:
            auto data = cast(EntityLifecycleMessageData) command.data;
            if (data is null || data.entity is null) {
                return;
            }

            entityManager.removeEntity(data.entity);
            eventChannel.emit(Event(EntityLifecycleEvent.entityRemoved, 1, data));
            break;

        case EntityLifecycleCommand.createEntity:
            auto data = cast(EntityCreationMessageData) command.data;
            if (data is null || data.entityName is null) {
                return;
            }

            auto factory = data.entityName in entitityFactoriesByName;
            if (!factory) {
                return;
            }

            auto entity = factory.createEntity(data.creationParameters);
            entityManager.addEntity(entity);
            eventChannel.emit(Event(EntityLifecycleEvent.entityAdded, 1,
                    new EntityLifecycleMessageData(entity)));
            break;

        default:
            break;
        }
    }
}
