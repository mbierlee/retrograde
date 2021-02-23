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

module retrograde.core.entity;

import retrograde.core.stringid;

import std.exception;
import std.string;

alias EntityIdType = ulong;

/**
 * An entity, together with its components, encapsulates data and behavior for a
 * part of the engine's dynamics.
 */
class Entity
{
    private string _name;
    private bool _isFinalized;
    public EntityIdType id = 0;

    /**
     * An entity's parent is used for hierarchial organizational purposes.
     */
    public Entity parent;

    private EntityComponent[StringId] _components;

    /**
     * Human-readble name of this entity.
     * Mainly used for debugging purposes.
     */
    public @property name()
    {
        return _name;
    }

    /**
     * A collection of this entity's components.
     */
    public @property components()
    {
        return _components.values;
    }

    /**
     * Whether the current entity is modifiable or not.
     * See_Also:
     *  finalize
     */
    public @property isFinalized()
    {
        return _isFinalized;
    }

    this()
    {
        this("Undefined");
    }

    /**
     * Params:
     *  name = Human-readable name assigned to this entity.
     */
    this(string name)
    {
        this._name = name;
    }

    private void enforceNonFinalized(string message)
    {
        if (isFinalized)
        {
            throw new EntityIsFinalizedException(this, message);
        }
    }

    /**
     * Adds the given entity component to this entity.
     * Adding entity components is not allowed when the entity is finalized.
     * Params:
     *  component = Instance of an entity component to be added.
     * See_Also:
     *  removeComponent, finalize
     */
    public void addComponent(EntityComponent component)
    {
        enforce!Exception(component !is null, "Passed component reference is null.");
        enforceNonFinalized("Cannot add new component, entity is finalized. Entities will become finalized when they are added to the entity manager or by calling Entity.finalize().");
        auto typeId = component.getComponentTypeId();
        _components[typeId] = component;
    }

    /**
     * Adds an entity component of the given type to this entity.
     * The entity component of the given type is created and added.
     * Adding entity components is not allowed when the entity is finalized.
     * Params:
     *  EntityComponentType = Type of the entity component to be created and added.
     * See_Also:
     *  removeComponent, finalize
     */
    public void addComponent(EntityComponentType : EntityComponent)()
    {
        TypeInfo_Class typeInfo = typeid(EntityComponentType);
        auto component = cast(EntityComponentType) typeInfo.create();
        enforce!Exception(component !is null,
                format("Error creating component of type %s. Does the component have a default constructor?",
                    typeInfo));
        addComponent(component);
    }

    /**
     * Removes the given entity component from this entity.
     * Removing entity components is not allowed when the entity is finalized.
     * Params:
     *  component = Instance of an entity component to be removed.
     * See_Also:
     *  addComponent, finalize
     */
    public void removeComponent(EntityComponent component)
    {
        enforce!Exception(component !is null, "Passed component reference is null.");
        auto typeId = component.getComponentTypeId();
        removeComponent(typeId);
    }

    /**
     * Removes an entity identified by the given type from this entity.
     * Removing entity components is not allowed when the entity is finalized.
     * Params:
     *  componentType = Componenty type of the component to be removed.
     * See_Also:
     *  addComponent, finalize
     */
    public void removeComponent(StringId componentType)
    {
        enforceNonFinalized("Cannot remove components, entity is finalized. Entities will become finalized when they are added to the entity manager or by calling Entity.finalize().");
        _components.remove(componentType);
    }

    /**
     * Removes an entity component of the given type to this entity.
     * Removing entity components is not allowed when the entity is finalized.
     * Params:
     *  EntityComponentType = Type of the entity component to be created and added.
     * See_Also:
     *  removeComponent, finalize
     */
    public void removeComponent(EntityComponentType : EntityComponent)()
    {
        StringId componentType = EntityComponentType.componentTypeId;
        removeComponent(componentType);
    }

    /**
     * Returns whether this entity has the given entity component.
     * Params:
     *  component = Instance of an entity component to be checked.
     */
    public bool hasComponent(EntityComponent component)
    {
        enforce!Exception(component !is null, "Passed component reference is null.");
        return hasComponent(component.getComponentTypeId());
    }

    /**
     * Returns whether this entity has an entity component of the given type.
     * Params:
     *  EntityComponentType = Type of the entity component to be checked.
     */
    public bool hasComponent(EntityComponentType : EntityComponent)()
    {
        StringId componentType = EntityComponentType.componentTypeId;
        return hasComponent(componentType);
    }

    /**
     * Returns whether this entity has an entity component identified by the given component type.
     * Params:
     *  componentType = Componenty type of the component to be checked.
     */
    public bool hasComponent(StringId componentType)
    {
        return (componentType in _components) !is null;
    }

    /**
     * Execute the given delegate if this entity has a certain type of component.
     * The component is given to the delegate.
     * Params:
     *  EntityComponentType = Type of the entity component that has to be present.
     */
    public void maybeWithComponent(EntityComponentType : EntityComponent)(
            void delegate(EntityComponentType) fn)
    {
        if (hasComponent!EntityComponentType)
        {
            withComponent(fn);
        }
    }

    /**
     * Execute the given delegate on a component of the given type.
     * The component is given to the delegate.
     * Params:
     *  EntityComponentType = Type of the component that has to be present.
     * Throws:
     *  ComponentNotFoundException when the entity does not have a component of the given type.
     */
    public void withComponent(EntityComponentType : EntityComponent)(
            void delegate(EntityComponentType) fn)
    {
        fn(getComponent!EntityComponentType);
    }

    /** 
     * Returns data from a component of the given type.
     * The given delegate takes care of fetching the desired data.
     * Params:
     *  EntityComponentType = Type of the component that has to be present.
     *  ReturnType = Type of the data expected to be returned.
     * Throws:
     *  ComponentNotFoundException when the entity does not have a component of the given type.
     */
    public ReturnType getFromComponent(EntityComponentType : EntityComponent, ReturnType)(
            ReturnType delegate(EntityComponentType) fn)
    {
        return fn(getComponent!EntityComponentType);
    }

    /** 
     * Returns data from a component of the given type.
     * The given delegate takes care of fetching the desired data.
     * If the entity has no component of the given type, the default value is returned.
     * Params:
     *  EntityComponentType = Type of the component that has to be present.
     *  ReturnType = Type of the data expected to be returned.
     */
    public ReturnType getFromComponent(EntityComponentType : EntityComponent, ReturnType)(
            ReturnType delegate(EntityComponentType) fn, lazy ReturnType defaultValue)
    {
        return hasComponent!EntityComponentType ? getFromComponent(fn) : defaultValue();
    }

    /**
     * Returns an entity component of the given type.
     * Params:
     *  EntityComponentType = Type of the component to be returned.
     * Throws:
     *  ComponentNotFoundException when the entity does not have a component of the given type.
     */
    public EntityComponentType getComponent(EntityComponentType : EntityComponent)()
    {
        return cast(EntityComponentType) getComponent(EntityComponentType.componentTypeId);
    }

    /**
     * Returns an entity component of the given type.
     * Params:
     *  componentType = Type of the component to be returned.
     * Throws:
     *  ComponentNotFoundException when the entity does not have a component of the given type.
     */
    public EntityComponent getComponent(StringId componentType)
    {
        auto component = componentType in _components;
        if (component is null)
        {
            throw new ComponentNotFoundException(componentType, this);
        }

        return *component;
    }

    /**
     * Removes all componments from this entity.
     * Removing components is not allowed when the entity is finalized.
     * See_Also:
     *  finalize
     */
    public void clearComponents()
    {
        enforceNonFinalized("Cannot clear components.");
        _components.destroy();
    }

    /**
     * Finalizes the component.
     * A finalized component cannot be modified anymore; entity components
     * cannot be added or removed.
     */
    public void finalize()
    {
        _isFinalized = true;
    }
}

class ComponentNotFoundException : Exception
{
    this(StringId componentType, Entity sourceEntity)
    {
        super(format("Component of type %s not added to entity %s(%s)",
                componentType, sourceEntity.name, sourceEntity.id));
    }
}

class EntityIsFinalizedException : Exception
{
    this(Entity entity, string additionalMessage)
    {
        super(format("Entity %s with id %s is finalized. %s", entity.name,
                entity.id, additionalMessage));
    }
}

/**
 * An entity component contains an entity's data or describes
 * specific behavior the entity should have.
 */
interface EntityComponent
{
    StringId getComponentTypeId();
}

/**
 * Convenience template for implemented a component's identity.
 * Params:
 *  ComponentType = Type of the component
 */
mixin template EntityComponentIdentity(string ComponentType)
{
    import retrograde.core.stringid;

    public static const StringId componentTypeId = sid(ComponentType);

    public StringId getComponentTypeId()
    {
        return componentTypeId;
    }
}

/**
 * Conveniently implements getters, setters and checkers for a collection of entities.
 */
class EntityCollection
{
    private Entity[EntityIdType] entities;

    public @property size_t length()
    {
        return entities.length;
    }

    public void add(Entity entity)
    {
        entities[entity.id] = entity;
    }

    public void remove(Entity entity)
    {
        remove(entity.id);
    }

    public void remove(EntityIdType entityId)
    {
        entities.remove(entityId);
    }

    public Entity get(EntityIdType entityId)
    {
        return this[entityId];
    }

    Entity opIndex(EntityIdType entityId)
    {
        return entities[entityId];
    }

    public void clearAll()
    {
        entities.destroy();
    }

    public bool hasEntity(Entity entity)
    {
        assert(entity !is null);
        if (hasEntity(entity.id))
        {
            auto myEntity = this[entity.id];
            return myEntity is entity;
        }

        return false;
    }

    public bool hasEntity(EntityIdType entityId)
    {
        Entity* entity = entityId in entities;
        return entity !is null;
    }

    public Entity[] getAll()
    {
        return entities.values;
    }
}

/**
 * Manages the lifecycle of entity processors and their entities.
 */
class EntityManager
{
    private EntityCollection _entities = new EntityCollection();
    private EntityProcessor[] _processors;
    private EntityIdType nextAvailableId = 1;

    public @property entities()
    {
        return _entities.getAll();
    }

    public @property processors()
    {
        return _processors;
    }

    /**
     * Adds the given entity to the manager.
     * Entities will be assigned an ID, are finalized when added
     * and finally will be assigned to entity processors that accept them.
     * Params:
     *  entity = Entity to be added.
     */
    public void addEntity(Entity entity)
    {
        if (!entity.isFinalized)
        {
            entity.finalize();
        }

        entity.id = nextAvailableId++;
        _entities.add(entity);
        foreach (processor; _processors)
        {
            processor.addEntity(entity);
        }
    }

    /**
     * Adds the given entity processors to the manager.
     * Params:
     *  processors: Entity processors to be added.
     */
    public void addEntityProcessors(EntityProcessor[] processors)
    {
        foreach (processor; processors)
        {
            addEntityProcessor(processor);
        }
    }

    /**
     * Adds the given entity processor to the manager.
     * Params:
     *  processor: Entity processor to be added.
     */
    public void addEntityProcessor(EntityProcessor processor)
    {
        _processors ~= processor;
        foreach (entity; _entities.getAll())
        {
            processor.addEntity(entity);
        }
    }

    /**
     * Calls the initialize method of each entity processor currently managed
     * by this manager.
     */
    public void initializeEntityProcessors()
    {
        foreach (processor; _processors)
        {
            processor.initialize();
        }
    }

    /**
     * Calls the cleanup method of each entity processor currently managed
     * by this manager.
     */
    public void cleanupEntityProcessors()
    {
        foreach (processor; _processors)
        {
            processor.cleanup();
        }
    }

    /**
     * Returns whether the current entity has an entity with the given entity ID.
     * Params:
     *  entityId = ID of the entity to check.
     */
    public bool hasEntity(EntityIdType entityId)
    {
        return _entities.hasEntity(entityId);
    }

    /**
     * Returns whether the current entity has the given entity.
     * Params:
     *  entity: Entity to check.
     */
    public bool hasEntity(Entity entity)
    {
        return hasEntity(entity.id);
    }

    /**
     * Removes an entity with the given entity ID from the manager.
     * Params:
     *  entityId = ID of the entity to be removed.
     */
    public void removeEntity(EntityIdType entityId)
    {
        _entities.remove(entityId);
        foreach (processor; _processors)
        {
            if (processor.hasEntity(entityId))
            {
                processor.removeEntity(entityId);
            }
        }
    }

    /**
     * Removes the given entity from the manager.
     * Params:
     *  entity = Entity to be removed.
     */
    public void removeEntity(Entity entity)
    {
        removeEntity(entity.id);
    }

    /**
     * Calls the update method of all processors managed by this manager.
     */
    public void update()
    {
        foreach (processor; _processors)
        {
            processor.update();
        }
    }

    /**
     * Calls the draw method of all processors managed by this manager.
     */
    public void draw()
    {
        foreach (processor; _processors)
        {
            processor.draw();
        }
    }
}

/**
 * An entity processor performs game logic with the given entities it has
 * been assigned by an entity manager.
 */
abstract class EntityProcessor
{
    protected EntityCollection _entities;

    /**
     * Whether the entity processor accepts the entity.
     * Entities are usually accepted or rejected based on the 
     * entity components they contain.
     */
    abstract public bool acceptsEntity(Entity entity);

    /**
     * Typically called when the game is starting up.
     */
    public void initialize()
    {
    }

    /**
     * Called on each game logic update cycle.
     */
    public void update()
    {
    }

    /**
     * Called on each render cycle.
     */
    public void draw()
    {
    }

    /**
     * Typically called when the game is cleaning up and shuttting down.
     */
    public void cleanup()
    {
    }

    /**
     * Amount of entities assigned to this processor.
     */
    public @property entityCount()
    {
        return _entities.length();
    }

    /**
     * Entities assigned to this processor.
     */
    public @property entities()
    {
        return _entities.getAll();
    }

    public this()
    {
        _entities = new EntityCollection();
    }

    /**
     * Adds the given entity to this processor, given is is accepted by it.
     * Throws:
     *  Exception when an unfinalized entity was added to entity processor
     */
    public void addEntity(Entity entity)
    {
        enforce!Exception(entity.isFinalized,
                "An unfinalized entity was added to entity processor. Finalize entities first using Entity.finalize()");

        if (!acceptsEntity(entity))
            return;

        _entities.add(entity);
        processAcceptedEntity(entity);
    }

    /**
     * Called when an entity is added and was accepted by this processor.
     * Params:
     *  entity = Entity that was accepted
     */
    protected void processAcceptedEntity(Entity entity)
    {
    }

    /**
     * Returns whether the current processor accepted an entity with the given entity ID.
     * Params:
     *  entityId = ID of the entity to be checked.
     */
    public bool hasEntity(EntityIdType entityId)
    {
        return _entities.hasEntity(entityId);
    }

    /**
     * Returns whether the current processor accepted the given entity.
     * Params:
     *  entity = Entity to be checked.
     */
    public bool hasEntity(Entity entity)
    {
        return hasEntity(entity.id);
    }

    /**
     * Removes an entity with the given entity ID.
     * Params:
     *  entityId = ID of the entity to be checked.
     */
    public void removeEntity(EntityIdType entityId)
    {
        if (hasEntity(entityId))
        {
            auto entity = _entities[entityId];
            _entities.remove(entityId);
            processRemovedEntity(entity);
        }
    }

    /**
     * Called when the given entity is removed.
     */
    protected void processRemovedEntity(Entity entity)
    {
    }
}

// Entity tests
version (unittest)
{
    class TestEntityComponent : EntityComponent
    {
        mixin EntityComponentIdentity!"TestEntityComponent";
        public int theAnswer = 42;
    }

    class LazySloth : NonlazySloth
    {
        this()
        {
            throw new Exception("The lazy default value was instantiated while it shouldn't be");
        }
    }

    class NonlazySloth
    {
    }

    @("Set entity ID")
    unittest
    {
        auto idOne = "Spaceship";
        auto entity = new Entity(idOne);
        assert(idOne == entity.name);
    }

    @("Add entity component to entity")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assert(entity.hasComponent(component));
    }

    @("Add entity component of type to entity")
    unittest
    {
        auto entity = new Entity();
        entity.addComponent!TestEntityComponent;
        assert(entity.hasComponent!TestEntityComponent);
    }

    @("Remove entity component from entity")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent(component);
        assert(!entity.hasComponent(component));
    }

    @("Remove entity component of type from entity")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent!TestEntityComponent;
        assert(!entity.hasComponent!TestEntityComponent);
    }

    @("Remove entity component by type id from entity")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent(component.getComponentTypeId());
        assert(!entity.hasComponent(component));
    }

    @("Clear all components from entity")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.clearComponents();
        assert(!entity.hasComponent(component));
    }

    @("Get component from entity")
    unittest
    {
        auto entity = new Entity();
        auto expectedComponent = new TestEntityComponent();
        entity.addComponent(expectedComponent);

        auto const actualComponent = entity.getComponent(expectedComponent.getComponentTypeId());

        assert(expectedComponent is actualComponent);
    }

    @("Get component of type from entity")
    unittest
    {
        auto entity = new Entity();
        auto expectedComponent = new TestEntityComponent();
        entity.addComponent(expectedComponent);

        auto const actualComponent = entity.getComponent!TestEntityComponent;

        assert(expectedComponent is actualComponent);
    }

    @("Attempt to get component that does not exist from entity")
    unittest
    {
        auto entity = new Entity();
        assertThrown!ComponentNotFoundException(entity.getComponent(sid("dinkydoo")));
    }

    @("Check whether entity has component of type ID")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assert(entity.hasComponent(component.getComponentTypeId()));
    }

    @("Check whether entity has component of type")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assert(entity.hasComponent!TestEntityComponent);
    }

    @("Execute delegate on entity for specific component")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        auto executedTestFunction = false;

        entity.withComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assert(executedTestFunction);
    }

    @("Maybe execute delegate on entity for specific component")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        auto executedTestFunction = false;

        entity.maybeWithComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assert(executedTestFunction);
    }

    @(
            "Maybe execute delegate on entity for specific component when component is not added to entity")
    unittest
    {
        auto entity = new Entity();
        auto executedTestFunction = false;

        entity.maybeWithComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assert(!executedTestFunction);
    }

    @("Get from component of type without giving default value")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        auto theAnswer = entity.getFromComponent!TestEntityComponent(
                component => component.theAnswer);
        assert(42 == theAnswer);
    }

    @("Get from component without giving default value when entity doesn't have component of type")
    unittest
    {
        auto entity = new Entity();
        assertThrown!ComponentNotFoundException(
                entity.getFromComponent!TestEntityComponent(component => component.theAnswer));
    }

    @("Get from component of type with giving default value")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        auto wrongAnswer = 88;
        auto theAnswer = entity.getFromComponent!TestEntityComponent(
                component => component.theAnswer, wrongAnswer);
        assert(42 == theAnswer);
    }

    @(
            "Get from component of type with giving default value when entity doesn't have component of type")
    unittest
    {
        auto entity = new Entity();
        auto const expectedCodeword = "I am a fish";
        auto const actualCodeword = entity.getFromComponent!TestEntityComponent(
                component => "Sharks r cool", expectedCodeword);
        assert(expectedCodeword == actualCodeword);
    }

    @("Default value of get from component is lazy")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        entity.getFromComponent!(TestEntityComponent,
                NonlazySloth)(component => new NonlazySloth(), new LazySloth());
    }

    @("Finalization of entities")
    unittest
    {
        auto entity = new Entity();
        entity.finalize();
        assert(entity.isFinalized);
    }

    @("Cannot add components to finalized entities")
    unittest
    {
        auto entity = new Entity();
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.addComponent(new TestEntityComponent()));
        assertThrown!EntityIsFinalizedException(entity.addComponent!TestEntityComponent);
    }

    @("Cannot remove components from finalized entities")
    unittest
    {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.removeComponent(component));
        assertThrown!EntityIsFinalizedException(entity.removeComponent!TestEntityComponent);
        assertThrown!EntityIsFinalizedException(
                entity.removeComponent(component.getComponentTypeId()));
    }

    @("Cannot clear components from finalized entities")
    unittest
    {
        auto entity = new Entity();
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.clearComponents());
    }

}

// Entity processor tests
version (unittest)
{
    Entity createTestEntity()
    {
        auto entity = new Entity();
        entity.finalize();
        entity.id = 1234;
        return entity;
    }

    class TestEntityProcessor : EntityProcessor
    {
        public int acceptsEntityCalls = 0;
        public int updateCalls = 0;
        public int drawCalls = 0;
        public int processAddCalls = 0;
        public int processRemoveCalls = 0;

        public override bool acceptsEntity(Entity entity)
        {
            acceptsEntityCalls++;
            return true;
        }

        protected override void processAcceptedEntity(Entity entity)
        {
            processAddCalls++;
        }

        protected override void processRemovedEntity(Entity entity)
        {
            processRemoveCalls++;
        }

        public override void update()
        {
            updateCalls++;
        }

        public override void draw()
        {
            drawCalls++;
        }
    }

    @("Add entity to entity processor")
    unittest
    {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);

        assert(1 == processor.acceptsEntityCalls);
        assert(processor.hasEntity(entity.id));
    }

    @("Add non-finalized entity to entity processor")
    unittest
    {
        auto entity = new Entity();
        auto processor = new TestEntityProcessor();
        assertThrown!Exception(processor.addEntity(entity));
        assert(!processor.hasEntity(entity.id));
    }

    @("Remove entity from entity processor")
    unittest
    {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        processor.removeEntity(entity.id);

        assert(!processor.hasEntity(entity.id));
    }

    @("Entity processor processes accepted entity")
    unittest
    {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        assert(1 == processor.processAddCalls);
    }

    @("Entity processor processes removed entity")
    unittest
    {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        processor.removeEntity(entity.id);

        assert(1 == processor.processRemoveCalls);
    }
}

// Entity Manager tests
version (unittest)
{
    class TestEntity : Entity
    {
    }

    @("Add entity to entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
    }

    @("Adding an entity to entity manager finalizes entity")
    unittest
    {
        auto manager = new EntityManager();
        auto entity = new Entity();
        assert(!entity.isFinalized);
        manager.addEntity(entity);
        assert(entity.isFinalized);
    }

    @("Adding an entity to entity manager sets entity's ID")
    unittest
    {
        auto manager = new EntityManager();
        auto entity = new Entity();

        manager.addEntity(entity);

        assert(1 == entity.id);
    }

    @("Add entity processor to entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();

        manager.addEntityProcessor(processor);
    }

    @("Add entity processor with pre-existing entities to entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();

        manager.addEntity(entity);
        manager.addEntityProcessor(processor);

        assert(1 == processor.entityCount);
    }

    @("Add entity processor and entities to entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();

        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        assert(1 == processor.entityCount);
    }

    @("Update entity processor by entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new TestEntity();
        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        manager.update();

        assert(1 == processor.updateCalls);
    }

    @("Draw entity processor by entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        manager.addEntityProcessor(processor);

        manager.draw();

        assert(1 == processor.drawCalls);
    }

    @("Remove entity processor from entity manager")
    unittest
    {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();
        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        manager.removeEntity(entity.id);

        assert(!manager.hasEntity(entity));
        assert(!processor.hasEntity(entity));
    }

    @("Entity manager has entity with id")
    unittest
    {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
        assert(manager.hasEntity(entity.id));
    }

    @("Entity manager has entity")
    unittest
    {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
        assert(manager.hasEntity(entity));
    }
}