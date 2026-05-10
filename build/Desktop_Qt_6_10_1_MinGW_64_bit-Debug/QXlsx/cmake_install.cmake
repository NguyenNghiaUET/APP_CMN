# Install script for directory: D:/code1/appppp-cmn1/third_party/QXlsx

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "C:/Program Files (x86)/CMN_TESTING")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Debug")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "C:/Qt/Tools/mingw1310_64/bin/objdump.exe")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "devel" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/libQXlsxQt6.a")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "devel" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/QXlsxQt6" TYPE FILE FILES
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxabstractooxmlfile.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxabstractsheet.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxabstractsheet_p.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxcellformula.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxcell.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxcelllocation.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxcellrange.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxcellreference.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxchart.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxchartsheet.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxconditionalformatting.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxdatavalidation.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxdatetype.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxdocument.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxformat.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxglobal.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxrichstring.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxworkbook.h"
    "D:/code1/appppp-cmn1/third_party/QXlsx/header/xlsxworksheet.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  include("D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/CMakeFiles/QXlsx.dir/install-cxx-module-bmi-Debug.cmake" OPTIONAL)
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "devel" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6/QXlsxQt6Targets.cmake")
    file(DIFFERENT _cmake_export_file_changed FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6/QXlsxQt6Targets.cmake"
         "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/CMakeFiles/Export/5e1a71f991ec0867fe453527b0963803/QXlsxQt6Targets.cmake")
    if(_cmake_export_file_changed)
      file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6/QXlsxQt6Targets-*.cmake")
      if(_cmake_old_config_files)
        string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6/QXlsxQt6Targets.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
        unset(_cmake_old_config_files_text)
        file(REMOVE ${_cmake_old_config_files})
      endif()
      unset(_cmake_old_config_files)
    endif()
    unset(_cmake_export_file_changed)
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6" TYPE FILE FILES "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/CMakeFiles/Export/5e1a71f991ec0867fe453527b0963803/QXlsxQt6Targets.cmake")
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6" TYPE FILE FILES "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/CMakeFiles/Export/5e1a71f991ec0867fe453527b0963803/QXlsxQt6Targets-debug.cmake")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/QXlsxQt6" TYPE FILE FILES
    "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/QXlsxQt6Config.cmake"
    "D:/code1/appppp-cmn1/build/Desktop_Qt_6_10_1_MinGW_64_bit-Debug/QXlsx/QXlsxQt6ConfigVersion.cmake"
    )
endif()

