# volta_native_juce: header-only Volta look for JUCE plugins.
# Consumers must already have JUCE's juce_gui_basics available (it is linked here as an interface
# dependency, so add this directory after FetchContent_MakeAvailable(JUCE) or add_subdirectory(JUCE)).
add_library(volta_native_juce INTERFACE)
add_library(volta::juce ALIAS volta_native_juce)
target_include_directories(volta_native_juce INTERFACE
    "${CMAKE_CURRENT_LIST_DIR}/include"
    "${CMAKE_CURRENT_LIST_DIR}/../include")
target_link_libraries(volta_native_juce INTERFACE juce::juce_gui_basics)
target_compile_features(volta_native_juce INTERFACE cxx_std_17)
