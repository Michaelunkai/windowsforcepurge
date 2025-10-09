cmake_minimum_required(VERSION 3.10)
project(AfterRebootRunner)

set(CMAKE_CXX_STANDARD 17)

# Find required packages
find_package(Threads REQUIRED)

# Create executable
add_executable(AfterRebootRunner main.cpp utils.cpp)

# Add Windows specific libraries
if(WIN32)
    target_link_libraries(AfterRebootRunner ${CMAKE_CURRENT_SOURCE_DIR}/taskschd.lib)
endif()

# Set Windows subsystem for GUI application if needed
# set_target_properties(AfterRebootRunner PROPERTIES WIN32_EXECUTABLE TRUE)