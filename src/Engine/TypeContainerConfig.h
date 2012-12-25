#pragma once

#include "irrlicht.h"

#include <Hypodermic/IContainer.h>

/**
 * Type container referring to a type builder.
 * Used for on-demand creation of instances managed by the IoC configuration.
 */
extern std::shared_ptr<Hypodermic::IContainer> typeContainer;

/**
 * Upfront creation of all sub-systems and injection of these sub-systems into each other.
 * Don't create and inject systems which have to be deleted and recreated in order to reset
 * to default state.
 *
 * @param deviceParams Irrlicht device parameters needed to configure the irrlicht device.
 */
void SetupTypeContainer(irr::SIrrlichtCreationParameters& deviceParams);