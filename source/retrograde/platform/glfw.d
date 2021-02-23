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

module retrograde.platform.glfw;

version (Have_glfw_d)
{
    import retrograde.platform.api;
    import retrograde.core.runtime;

    import glfw3.api;

    import poodinis;

    struct WindowData
    {
        int xpos;
        int ypos;
        int width;
        int height;

        void update(GLFWwindow* window)
        {
            glfwGetWindowPos(window, &this.xpos, &this.ypos);
            glfwGetWindowSize(window, &this.width, &this.height);
        }
    }

    /**
     * A GLFW-based platform for Desktop OSes.
     * To use, dependency glfw-d must be included in your project's dub project.
     */
    class GlfwPlatform : Platform
    {
        private @Autowire EngineRuntime runtime;

        private GLFWwindow* window;
        private WindowData windowData;

        void initialize(const PlatformSettings platformSettings = new PlatformSettings())
        {
            extern (C) @nogc nothrow void errorCallback(int error, const(char)* description)
            {
                //TODO: Replace with engine logger
                import core.stdc.stdio;

                fprintf(stderr, "Error: %s\n", description);
            }

            glfwSetErrorCallback(&errorCallback);

            if (!glfwInit())
            {
                //TODO: log
            }

            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);

            window = glfwCreateWindow(1920, 1080, //TODO: Make configurable
                    "Retrograde Engine" // TODO: Configurable
                    , null, null);

            if (!window)
            {
                glfwTerminate();
                //TODO: log
                return;
            }

            glfwSetWindowUserPointer(window, &windowData);
            glfwMakeContextCurrent(window);
            glfwSwapInterval(1); // V-sync stuff. TODO: Make configurable
        }

        void update()
        {
            if (glfwWindowShouldClose(window))
            {
                runtime.terminate();
            }
            else if (window)
            {
                glfwSwapBuffers(window);
                glfwPollEvents();
            }
        }

        void terminate()
        {
            if (window)
            {
                glfwDestroyWindow(window);
            }

            glfwTerminate();
        }
    }
}
