cmake_minimum_required(VERSION 2.8.11)

set(OPENNI_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/OpenNI-Linux-x64-2.3/Include)
set(OPENNI_LIB_DIR  ${PROJECT_SOURCE_DIR}/OpenNI-Linux-x64-2.3/Redist)

include_directories(${DARKNET_WRAPPER_INCLUDE_DIR})
include_directories(${YOLO_INCLUDE_DIR})
include_directories(${CUDA_INCLUDE_DIRS})
include_directories(${OPENNI_INCLUDE_DIR})

find_package(PythonLibs 2.7 REQUIRED)
find_package(Boost COMPONENTS python REQUIRED)
include_directories(${PYTHON_INCLUDE_DIRS})
include_directories(${Boost_INCLUDE_DIR})

add_executable(astra_recognition darknet++.cpp )
target_link_libraries(
        astra_recognition
        ${DARKNET_CORE_LIBNAME}
        ${DARKNET_CUDA_LIBNAME}
        ${DARKNET_WRAPPER_LIBRARIES}
	python2.7
	${Boost_LIBRARIES}
        ${OpenCV_LIBRARIES}
        ${CUDA_LIBRARIES}
        ${CUDA_CUBLAS_LIBRARIES}
        ${CUDA_curand_LIBRARY}
        ${CMAKE_THREAD_LIBS_INIT}
	${OPENNI_LIB_DIR}/libOpenNI2.so
)
