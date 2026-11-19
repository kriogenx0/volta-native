# Lets JUCE projects pull Volta-Native with FetchContent or add_subdirectory.
# Only the JUCE half is built by CMake; the Swift half is a Swift package (Package.swift).
cmake_minimum_required(VERSION 3.22)
project(VoltaNative LANGUAGES CXX)
add_subdirectory(juce)
