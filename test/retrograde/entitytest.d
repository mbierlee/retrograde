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

import retrograde.entity;
import dunit;

import retrograde.stringid;
import retrograde.messaging;

import std.exception;

import poodinis;

class TestEntityComponent : EntityComponent {
    mixin EntityComponentIdentity!"TestEntityComponent";

    public int theAnswer = 42;
}

class LazySloth : NonlazySloth {
    this() {
        throw new Exception("The lazy default value was instantiated while it shouldn't be");
    }
}

class NonlazySloth {
}

class TestEntityFactory : EntityFactory {
    this() {
        super("ent_test_entity");
    }

    public Entity createdEntity = null;

    public override Entity createEntity(CreationParameters parameters) {
        createdEntity = createBlankEntity();
        return createdEntity;
    }
}

class TestCreationParameters : CreationParameters {
    public string someData;

    this(string someData) {
        this.someData = someData;
    }
}

class EntityTest {
    mixin UnitTest;

    @Test
    public void testSetEntityId() {
        auto idOne = "Spaceship";
        auto entity = new Entity(idOne);
        assertEquals(idOne, entity.name);
    }

    @Test
    public void testAddEntityComponent() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assertTrue(entity.hasComponent(component));
    }

    @Test
    public void testAddEntityComponentParameterized() {
        auto entity = new Entity();
        entity.addComponent!TestEntityComponent;
        assertTrue(entity.hasComponent!TestEntityComponent);
    }

    @Test
    public void testRemoveEntityComponent() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent(component);
        assertFalse(entity.hasComponent(component));
    }

    @Test
    public void testRemoveEntityComponentParameterized() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent!TestEntityComponent;
        assertFalse(entity.hasComponent!TestEntityComponent);
    }

    @Test
    public void testRemoveEntityComponentByType() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.removeComponent(component.getComponentType());
        assertFalse(entity.hasComponent(component));
    }

    @Test
    public void testClearComponents() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.clearComponents();
        assertFalse(entity.hasComponent(component));
    }

    @Test
    public void testGetComponent() {
        auto entity = new Entity();
        auto expectedComponent = new TestEntityComponent();
        entity.addComponent(expectedComponent);

        auto actualComponent = entity.getComponent(expectedComponent.getComponentType());

        assertSame(expectedComponent, actualComponent);
    }

    @Test
    public void testGetComponentParameterized() {
        auto entity = new Entity();
        auto expectedComponent = new TestEntityComponent();
        entity.addComponent(expectedComponent);

        auto actualComponent = entity.getComponent!TestEntityComponent;

        assertSame(expectedComponent, actualComponent);
    }

    @Test
    public void testGetComponentNonexisting() {
        auto entity = new Entity();
        assertThrown!ComponentNotFoundException(entity.getComponent(sid("dinkydoo")));
    }

    @Test
    public void testSetParent() {
        auto parentEntity = new Entity();
        auto childEntity = new Entity();

        childEntity.parent = parentEntity;

        assertSame(parentEntity, childEntity.parent);
    }

    @Test
    public void testHasComponentByComponentType() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assertTrue(entity.hasComponent(component.getComponentType()));
    }

    @Test
    public void testHasComponentParameterized() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        assertTrue(entity.hasComponent!TestEntityComponent);
    }

    @Test
    public void testWithComponent() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        auto executedTestFunction = false;

        entity.withComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assertTrue(executedTestFunction);
    }

    @Test
    public void testMaybeWithComponent() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        auto executedTestFunction = false;

        entity.maybeWithComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assertTrue(executedTestFunction);
    }

    @Test
    public void testMaybeWithComponentComponentNotPresent() {
        auto entity = new Entity();
        auto executedTestFunction = false;

        entity.maybeWithComponent!TestEntityComponent((component) {
            executedTestFunction = true;
        });

        assertFalse(executedTestFunction);
    }

    @Test
    public void testGetFromComponentNoDefault() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        auto theAnswer = entity.getFromComponent!TestEntityComponent(component => component.theAnswer);
        assertEquals(42, theAnswer);
    }

    @Test
    public void testGetFromComponentNoDefaultFails() {
        auto entity = new Entity();
        assertThrown!ComponentNotFoundException(entity.getFromComponent!TestEntityComponent(component => component.theAnswer));
    }

    @Test
    public void testGetFromComponentWithDefault() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        auto wrongAnswer = 88;
        auto theAnswer = entity.getFromComponent!TestEntityComponent(component => component.theAnswer, wrongAnswer);
        assertEquals(42, theAnswer);
    }

    @Test
    public void testGetFromComponentGetDefault() {
        auto entity = new Entity();
        auto expectedCodeword = "I am a fish";
        auto actualCodeword = entity.getFromComponent!TestEntityComponent(component => "Sharks r cool", expectedCodeword);
        assertEquals(expectedCodeword, actualCodeword);
    }

    @Test
    public void testGetFromComponentDefaultIsLazy() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);

        auto sloth = entity.getFromComponent!(TestEntityComponent, NonlazySloth)(component => new NonlazySloth(), new LazySloth());
    }

    @Test
    public void testEntitiesCanBeFinalized() {
        auto entity = new Entity();
        entity.finalize();
        assertTrue(entity.isFinalized);
    }

    @Test
    public void testCannotAddComponentsToFinalizedEntities() {
        auto entity = new Entity();
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.addComponent(new TestEntityComponent()));
        assertThrown!EntityIsFinalizedException(entity.addComponent!TestEntityComponent);
    }

    @Test
    public void testCannotRemoveComponentsFromFinalizedEntities() {
        auto entity = new Entity();
        auto component = new TestEntityComponent();
        entity.addComponent(component);
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.removeComponent(component));
        assertThrown!EntityIsFinalizedException(entity.removeComponent!TestEntityComponent);
        assertThrown!EntityIsFinalizedException(entity.removeComponent(component.getComponentType()));
    }

    @Test
    public void testCannotClearComponentsFromFinalizedEntities() {
        auto entity = new Entity();
        entity.finalize();
        assertThrown!EntityIsFinalizedException(entity.clearComponents());
    }
}

class EntityCollectionTest {
    mixin UnitTest;

    @Test
    public void testAddEntity() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.addEntity(entity);
        assertTrue(entityCollection.hasEntity(entity));
    }

    @Test
    public void testRemoveEntity() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.addEntity(entity);
        entityCollection.removeEntity(entity);
        assertFalse(entityCollection.hasEntity(entity));
    }

    @Test
    public void testRemoveNotAddedEntitySucceeds() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.removeEntity(entity);
    }

    @Test
    public void testGetEntity() {
        auto entityCollection = new EntityCollection();
        auto expectedEntity = createTestEntity();
        entityCollection.addEntity(expectedEntity);
        auto actualEntity = entityCollection.getEntity(expectedEntity.id);
        assertSame(expectedEntity, actualEntity);
    }

    @Test
    public void testGetEntityThroughIndex() {
        auto entityCollection = new EntityCollection();
        auto expectedEntity = createTestEntity();
        entityCollection.addEntity(expectedEntity);
        auto actualEntity = entityCollection[expectedEntity.id];
        assertSame(expectedEntity, actualEntity);
    }

    @Test
    public void testHasEntityById() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.addEntity(entity);
        assertTrue(entityCollection.hasEntity(entity.id));
    }

    @Test
    public void testHasEntityByInstance() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.addEntity(entity);
        assertTrue(entityCollection.hasEntity(entity));
    }

    @Test
    public void testRemoveAllEntities() {
        auto entityCollection = new EntityCollection();
        auto entity = createTestEntity();
        entityCollection.addEntity(entity);
        entityCollection.clearEntities();
        assertFalse(entityCollection.hasEntity(entity));
    }

    @Test
    void testHasEntityWithSameIdButDifferentInstance() {
        auto entityCollection = new EntityCollection();
        auto entity1 = createTestEntity();
        auto entity2 = createTestEntity();
        entityCollection.addEntity(entity1);

        assertFalse(entityCollection.hasEntity(entity2));
    }
}

class TestEntityProcessor : EntityProcessor {
    public int acceptsEntityCalls = 0;
    public int updateCalls = 0;
    public int drawCalls = 0;
    public int processAddCalls = 0;
    public int processRemoveCalls = 0;

    public override bool acceptsEntity(Entity entity) {
        acceptsEntityCalls++;
        return true;
    }

    protected override void processAcceptedEntity(Entity entity) {
        processAddCalls++;
    }

    protected override void processRemovedEntity(Entity entity) {
        processRemoveCalls++;
    }

    public override void update() {
        updateCalls++;
    }

    public override void draw() {
        drawCalls++;
    }
}

class EntityProcessorTest {
    mixin UnitTest;

    @Test
    void testAddAndHasEntity() {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);

        assertEquals(1, processor.acceptsEntityCalls);
        assertTrue(processor.hasEntity(entity.id));
    }

    @Test
    void testAddEntityRejectsNonFinalizedEntities() {
        auto entity = new Entity();
        auto processor = new TestEntityProcessor();
        assertThrown!Exception(processor.addEntity(entity));
        assertFalse(processor.hasEntity(entity.id));
    }

    @Test
    void testRemoveEntity() {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        processor.removeEntity(entity.id);

        assertFalse(processor.hasEntity(entity.id));
    }

    @Test
    void testProcessAcceptedEntity() {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        assertEquals(1, processor.processAddCalls);
    }

    @Test
    void testProcessRemovedEntity() {
        auto entity = createTestEntity();
        auto processor = new TestEntityProcessor();

        processor.addEntity(entity);
        processor.removeEntity(entity.id);

        assertEquals(1, processor.processRemoveCalls);
    }
}

class TestEntity : Entity {}

class EntityManagerTest {
    mixin UnitTest;

    @Test
    void testAddEntity() {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
    }

    @Test
    void testAddEntityFinalizesTheEntity() {
        auto manager = new EntityManager();
        auto entity = new Entity();
        assertFalse(entity.isFinalized);
        manager.addEntity(entity);
        assertTrue(entity.isFinalized);
    }

    @Test
    void testEntityIdSet() {
        auto manager = new EntityManager();
        auto entity = new Entity();

        manager.addEntity(entity);

        assertEquals(1, entity.id);
    }

    @Test
    void testAddEntityProcessor() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();

        manager.addEntityProcessor(processor);
    }

    @Test
    void testAddEntityProcessorWithPreExistingEntities() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();

        manager.addEntity(entity);
        manager.addEntityProcessor(processor);

        assertEquals(1, processor.entityCount);
    }

    @Test
    void testAddEntityWithExistingProcessor() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();

        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        assertEquals(1, processor.entityCount);
    }

    @Test
    void testUpdate() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new TestEntity();
        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        manager.update();

        assertEquals(1, processor.updateCalls);
    }

    @Test
    void testDraw() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        manager.addEntityProcessor(processor);

        manager.draw();

        assertEquals(1, processor.drawCalls);
    }

    @Test
    void testRemoveEntity() {
        auto manager = new EntityManager();
        auto processor = new TestEntityProcessor();
        auto entity = new Entity();
        manager.addEntityProcessor(processor);
        manager.addEntity(entity);

        manager.removeEntity(entity.id);

        assertFalse(manager.hasEntity(entity));
        assertFalse(processor.hasEntity(entity));
    }

    @Test
    void testHasEntityById() {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
        assertTrue(manager.hasEntity(entity.id));
    }

    @Test
    void testHasEntityByReference() {
        auto manager = new EntityManager();
        auto entity = new Entity();
        manager.addEntity(entity);
        assertTrue(manager.hasEntity(entity));
    }
}

Entity createTestEntity() {
    auto entity = new Entity();
    entity.finalize();
    entity.id = 1234;
    return entity;
}

class EntityFactoryTest {
    mixin UnitTest;

    Entity testEntity;

    class TestEntityFactory : EntityFactory {
        this() {
            super("TestEntity");
        }

        public override Entity createEntity(CreationParameters parameters = null) {
            return testEntity;
        }
    }

    @BeforeEach
    public void setup() {
        testEntity = createTestEntity();
    }

    @Test
    public void testCreateEntity() {
        auto factory = new TestEntityFactory();
        auto entity = factory.createEntity();
        assertSame(testEntity, entity);
    }

    @Test
    public void testCreatesEntity() {
        auto factory = new TestEntityFactory();
        assertTrue(factory.createsEntity("TestEntity"));
    }
}

class HierarchialEntityCollectionTest {
    mixin UnitTest;

    @Test
    public void testForEachChild() {
        auto rootEntity = new Entity();
        rootEntity.id = 1;
        auto childEntity = new Entity();
        childEntity.id = 2;
        childEntity.parent = rootEntity;

        auto container = new HierarchialEntityCollection();
        container.addEntity(rootEntity);
        container.addEntity(childEntity);

        container.updateHierarchy();

        auto entitiesTraversed = 0;

        container.forEachChild((e) {
            assertEquals(1, e.parent.id);
            assertEquals(2, e.id);
            entitiesTraversed += 1;
        });

        assertEquals(1, entitiesTraversed);
    }

    @Test
    public void testForEachChildWithChildren() {
        auto rootEntity = new Entity();
        rootEntity.id = 1;

        auto childEntity = new Entity();
        childEntity.id = 2;
        childEntity.parent = rootEntity;

        auto childOfChildEntity = new Entity();
        childOfChildEntity.id = 3;
        childOfChildEntity.parent = childEntity;

        auto container = new HierarchialEntityCollection();
        container.addEntity(rootEntity);
        container.addEntity(childEntity);
        container.addEntity(childOfChildEntity);

        container.updateHierarchy();

        auto entitiesTraversed = 0;

        container.forEachChild((e) {
            entitiesTraversed += 1;
        });

        assertEquals(2, entitiesTraversed);
    }

    @Test
    public void testForEachRootEntity() {
        auto rootEntity = new Entity();
        rootEntity.id = 1;
        auto childEntity = new Entity();
        childEntity.id = 2;
        childEntity.parent = rootEntity;

        auto container = new HierarchialEntityCollection();
        container.addEntity(rootEntity);
        container.addEntity(childEntity);

        container.updateHierarchy();

        auto entitiesTraversed = 0;

        container.forEachRootEntity((e) {
            assertEquals(1, e.id);
            entitiesTraversed += 1;
        });

        assertEquals(1, entitiesTraversed);
    }

    @Test
    public void testRootEntities() {
        auto rootEntity = new Entity();
        rootEntity.id = 1;
        auto childEntity = new Entity();
        childEntity.id = 2;
        childEntity.parent = rootEntity;

        auto container = new HierarchialEntityCollection();
        container.addEntity(rootEntity);
        container.addEntity(childEntity);

        container.updateHierarchy();

        assertEquals(1, container.rootEntities.length);
        assertEquals(rootEntity, container.rootEntities[0]);
    }

    @Test
    public void testGetChildrenOfEntity() {
        auto rootEntity = new Entity();
        rootEntity.id = 1;
        auto childEntity = new Entity();
        childEntity.id = 2;
        childEntity.parent = rootEntity;

        auto container = new HierarchialEntityCollection();
        container.addEntity(rootEntity);
        container.addEntity(childEntity);

        container.updateHierarchy();

        auto children = container.getChildrenOfEntity(rootEntity);

        assertEquals(1, children.length);
        assertEquals(childEntity, children[0]);
    }

}

class EntityChannelManagerTest {
    mixin UnitTest;

    private shared DependencyContainer dependencies;
    private EntityChannelManager channelManager;
    private EntityLifecycleEventChannel eventChannel;
    private EntityLifecycleCommandChannel commandChannel;
    private EntityManager entityManager;
    private bool emittedEvent;

    @BeforeEach
    public void setup() {
        emittedEvent = false;
        dependencies = new shared DependencyContainer();
        dependencies.register!EntityChannelManager;
        dependencies.register!EntityLifecycleCommandChannel;
        dependencies.register!EntityLifecycleEventChannel;
        dependencies.register!EntityManager;
        dependencies.register!(EntityFactory, TestEntityFactory);

        channelManager = dependencies.resolve!EntityChannelManager;
        eventChannel = dependencies.resolve!EntityLifecycleEventChannel;
        commandChannel = dependencies.resolve!EntityLifecycleCommandChannel;
        entityManager = dependencies.resolve!EntityManager;
        channelManager.initialize();
    }

    private void addedEventHandler(const Event event) {
        emittedEvent = event.type == EntityLifecycleEvent.entityAdded;
    }

    private void removedEventHandler(const Event event) {
        emittedEvent = event.type == EntityLifecycleEvent.entityRemoved;
    }

    @Test
    public void testAddsEntityToEntityManager() {
        auto entity = new Entity();
        commandChannel.emit(Command(EntityLifecycleCommand.addEntity, 1, new EntityLifecycleMessageData(entity)));
        assertTrue(entityManager.hasEntity(entity));
    }

    @Test
    public void testAddsEntityToEntityManagerViaConvenienceMethod() {
        auto entity = new Entity();
        commandChannel.addEntity(entity);
        assertTrue(entityManager.hasEntity(entity));
    }

    @Test
    public void testEmitsEntityAddedEventWhenAdded() {
        eventChannel.connect(&addedEventHandler);
        auto entity = new Entity();
        commandChannel.emit(Command(EntityLifecycleCommand.addEntity, 1, new EntityLifecycleMessageData(entity)));
        assertTrue(emittedEvent);
    }

    @Test
    public void testRemovesEntityFromEntityManager() {
        auto entity = new Entity();
        entityManager.addEntity(entity);
        commandChannel.emit(Command(EntityLifecycleCommand.removeEntity, 1, new EntityLifecycleMessageData(entity)));
        assertFalse(entityManager.hasEntity(entity));
    }

    @Test
    public void testRemovesEntityFromEntityManagerViaConvenienceMethod() {
        auto entity = new Entity();
        entityManager.addEntity(entity);
        commandChannel.removeEntity(entity);
        assertFalse(entityManager.hasEntity(entity));
    }

    @Test
    public void testEmitsEntityRemovedEventWhenRemoved() {
        auto entity = new Entity();
        entityManager.addEntity(entity);
        eventChannel.connect(&removedEventHandler);
        commandChannel.emit(Command(EntityLifecycleCommand.removeEntity, 1, new EntityLifecycleMessageData(entity)));
        assertTrue(emittedEvent);
    }

    @Test
    public void testCreatesEntityFromEntityFactory() {
        auto entityFactory = dependencies.resolve!TestEntityFactory;
        commandChannel.emit(Command(EntityLifecycleCommand.createEntity, 1, new EntityCreationMessageData("ent_test_entity")));
        assertNotNull(entityFactory.createdEntity);
    }

    @Test
    public void testCreatesEntityFromEntityFactoryViaConvenienceMethod() {
        auto entityFactory = dependencies.resolve!TestEntityFactory;
        commandChannel.createEntity("ent_test_entity");
        assertNotNull(entityFactory.createdEntity);
    }

    @Test
    public void testAddsCreatedEntityToEntityManager() {
        eventChannel.connect(&addedEventHandler);
        auto entityFactory = dependencies.resolve!TestEntityFactory;
        commandChannel.emit(Command(EntityLifecycleCommand.createEntity, 1, new EntityCreationMessageData("ent_test_entity")));
        assertTrue(entityManager.hasEntity(entityFactory.createdEntity));
        assertTrue(emittedEvent);
    }
}
