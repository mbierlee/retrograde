#pragma once

#include "irrlicht.h"

#include <Hypodermic/IContainer.h>

/**
 * Upfront creation of all sub-systems and injection of these sub-systems into each other.
 * Don't create and inject systems which have to be deleted and recreated in order to reset
 * to default state.
 *
 * @param deviceParams Irrlicht device parameters needed to configure the irrlicht device.
 *
 * @return std::shared_ptr<Hypodermic::IContainer> Concrete type container used for resolving types.
 */
std::shared_ptr<Hypodermic::IContainer> SetupDependencies(irr::SIrrlichtCreationParameters& deviceParams);