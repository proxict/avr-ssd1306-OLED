cmake_minimum_required(VERSION 3.0)

# Setup our avr toolchain
find_program(AVR_CPP avr-g++)
find_program(AVR_CC avr-gcc)
find_program(AVR_STRIP avr-strip)
find_program(OBJ_COPY avr-objcopy)
find_program(AVR_SIZE avr-size)
find_program(AVRDUDE avrdude)

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_CXX_COMPILER ${AVR_CPP})
set(CMAKE_C_COMPILER ${AVR_CC})
set(CMAKE_ASM_COMPILER ${AVR_CC})

##########################################################################################
# Check required definitions of our hardware
##########################################################################################
if (NOT DEFINED MCU)
    message(STATUS "MCU not set, defaulting to atmega328p")
    set(MCU "atmega328p")
endif ()
if (NOT DEFINED F_CPU)
    message(STATUS "F_CPU not set, defaulting to 16000000L")
    set(F_CPU "16000000L")
endif ()
if (NOT DEFINED PROGRAMMER)
    message(STATUS "PROGRAMMER not set, defaulting to avrispmkII")
    set(PROGRAMMER "avrispmkII")
endif ()

set(COMPILER_FLAGS "-Os -Wall -Wextra -Wno-unknown-pragmas -ffunction-sections -fdata-sections -MMD -mmcu=${MCU}")
set(CMAKE_C_FLAGS "${COMPILER_FLAGS} -std=gnu99 -mcall-prologues")
set(CMAKE_CXX_FLAGS "${COMPILER_FLAGS} -std=c++11 -felide-constructors -fpermissive -fno-exceptions -fno-threadsafe-statics -fno-fat-lto-objects -flto -Wno-error=narrowing")
set(CMAKE_ASM_FLAGS "-x assembler-with-cpp ${COMPILER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--relax -Wl,--gc-sections -Wl,-u,vfscanf -lscanf_min -Wl,-u,vfprintf -fuse-linker-plugin -lprintf_min ${EXTRA_LIBS}")

add_definitions(-DMCU=\"${MCU}\")
add_definitions(-DF_CPU=${F_CPU})

##########################################################################################
# Function to compile arduino-core library
##########################################################################################
if (DEFINED ENV{ARDUINO_SDK_PATH})
    set(ARDUINO_SDK_PATH "$ENV{ARDUINO_SDK_PATH}" CACHE PATH "Arduino SDK Path" FORCE)
endif ()

set(ARDUINO_CORE_LIBS "")
function(compile_arduino_core)
    if (DEFINED ARDUINO_SDK_PATH AND IS_DIRECTORY ${ARDUINO_SDK_PATH} AND NOT (TARGET arduino-core))
        # Set the paths
        set(ARDUINO_CORES_PATH ${ARDUINO_SDK_PATH}/hardware/arduino/avr/cores/arduino)
        set(ARDUINO_VARIANTS_PATH ${ARDUINO_SDK_PATH}/hardware/arduino/avr/variants/standard)
        set(ARDUINO_LIBRARIES_PATH ${ARDUINO_SDK_PATH}/hardware/arduino/avr/libraries)

        add_definitions(-DARDUINO=10809)
        add_definitions(-DARDUINO_AVR_UNO)
        add_definitions(-DARDUINO_ARCH_AVR)

        # Find arduino-core sources
        file(GLOB_RECURSE ARDUINO_CORE_SRCS ${ARDUINO_CORES_PATH}/*.S ${ARDUINO_CORES_PATH}/*.c ${ARDUINO_CORES_PATH}/*.cpp)

        # Setup the main arduino core target
        add_library(arduino-core ${ARDUINO_CORE_SRCS})
        target_include_directories(arduino-core PUBLIC ${ARDUINO_CORES_PATH})
        target_include_directories(arduino-core PUBLIC ${ARDUINO_VARIANTS_PATH})

        # Compile and link all the additional libraries in the core
        file(GLOB CORE_DIRS ${ARDUINO_LIBRARIES_PATH}/*)
        foreach (libdir ${CORE_DIRS})
            get_filename_component(libname ${libdir} NAME)
            if (IS_DIRECTORY ${libdir})
                file(GLOB_RECURSE sources ${libdir}/*.cpp ${libdir}/*.S ${libdir}/*.c)
                string(REGEX REPLACE "examples/.*" "" sources "${sources}")
                if (sources)
                    if (NOT TARGET ${libname})
                        message(STATUS "Adding Arduino core library: ${libname}")
                        add_library(${libname} ${sources})
                    endif ()
                    target_link_libraries(${libname} arduino-core)
                    foreach (src ${sources})
                        get_filename_component(dir ${src} PATH)
                        target_include_directories(${libname} PUBLIC ${dir})
                    endforeach ()
                    list(APPEND ARDUINO_CORE_LIBS ${libname})
                    set(ARDUINO_CORE_LIBS ${ARDUINO_CORE_LIBS})
                endif ()
                include_directories(SYSTEM ${libdir}/src)
            endif ()
        endforeach ()
    endif ()
endfunction()

##########################################################################################
# Function for adding AVR programs
##########################################################################################
function(add_executable_avr NAME)
    compile_arduino_core()
    add_executable(${NAME} ${ARGN})
    set_target_properties(${NAME} PROPERTIES OUTPUT_NAME "${NAME}.elf")
    set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${NAME}.hex;${NAME}.eep;${NAME}.lst")

    # Create hex file
    add_custom_command(
        OUTPUT ${NAME}.hex
        COMMAND ${AVR_STRIP} "${NAME}.elf"
        COMMAND ${OBJ_COPY} -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0 "${NAME}.elf" "${NAME}.eep"
        COMMAND ${OBJ_COPY} -O ihex -R .eeprom "${NAME}.elf" "${NAME}.hex"
        COMMAND ${AVR_SIZE} --mcu=${MCU} -C --format=avr "${NAME}.elf"
        DEPENDS ${NAME}
    )

    add_custom_target(
        upload-${NAME}
        COMMAND ${AVRDUDE} -p${MCU} -P usb -c${PROGRAMMER} -U flash:w:${NAME}.hex:i
        DEPENDS ${NAME}.hex
    )
endfunction(add_executable_avr)

##########################################################################################
# Function to link arduino libraries to our project
##########################################################################################
function(target_link_arduino_library TARGET NAME)
    compile_arduino_core()
    if (NOT TARGET ${NAME})
        # Find all the source files from this library
        set(libsources "")
        foreach (paths ${ARGN})
            file(GLOB_RECURSE srcfiles FOLLOW_SYMLINKS ${paths}/*.S ${paths}/*.c ${paths}/*.cpp)
            set(libsources "${libsources};${srcfiles}")
        endforeach ()

        # We only want sources which are not part of library's examples
        foreach (file ${libsources})
            STRING(REGEX MATCH "/examples/" example ${file})
            if (NOT example)
                list(APPEND sources ${file})
            endif ()
        endforeach ()

        # If there is something to compile, create a library from that and link it to our target
        if (sources)
            message(STATUS "Adding external library: ${NAME}")
            add_library(${NAME} ${sources})
            target_link_libraries(${NAME} ${ARDUINO_CORE_LIBS})
            foreach (src ${sources})
                get_filename_component(dir ${src} PATH)
                list(APPEND includes ${dir})
            endforeach ()
            list(REMOVE_DUPLICATES includes)
            target_include_directories(${NAME} PUBLIC ${includes})

            # Also give this library arduino-core include directories
            get_target_property(incdirs arduino-core INCLUDE_DIRECTORIES)
            target_include_directories(${NAME} PUBLIC ${incdirs} ${ARGN})
            target_link_libraries(${TARGET} ${NAME})
        endif ()
    else ()
        target_link_libraries(${TARGET} ${NAME})
    endif ()
endfunction()
