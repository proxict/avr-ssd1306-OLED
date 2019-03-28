cmake_minimum_required(VERSION 3.0)

include(config.cmake)
set(CMAKE_TOOLCHAIN_FILE cmake/arduino.cmake)
project(oled C CXX ASM)

add_executable_avr(oled
    src/main.cpp
)

target_link_arduino_library(oled u8g2 external/u8g2/csrc external/u8g2/cppsrc)

# Function add_executable_avr will build arduino-core, hence we can easily link it
target_link_libraries(oled
    arduino-core
    SPI
    Wire
)

