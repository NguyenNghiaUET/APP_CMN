# CMakeLists.txt for QXlsx Library

cmake_minimum_required(VERSION 3.16)

project(QXlsx
    VERSION 1.4.4
    LANGUAGES CXX
)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

if(NOT DEFINED QT_VERSION_MAJOR)
    find_package(QT NAMES Qt6 Qt5 COMPONENTS Core Gui REQUIRED)
endif()
find_package(Qt${QT_VERSION_MAJOR} 5.9 COMPONENTS Core Gui REQUIRED)
set(EXPORT_NAME QXlsxQt${QT_VERSION_MAJOR})

if (QT_VERSION_MAJOR EQUAL 6)
    set(CMAKE_CXX_STANDARD 17 CACHE STRING "")
else()
    set(CMAKE_CXX_STANDARD 11 CACHE STRING "")
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

if(NOT DEFINED ${QXLSX_PARENTPATH})
	set(QXLSX_PARENTPATH ${CMAKE_CURRENT_SOURCE_DIR}/../)
endif(NOT DEFINED ${QXLSX_PARENTPATH})

if(NOT DEFINED ${QXLSX_HEADERPATH})
	set(QXLSX_HEADERPATH ${CMAKE_CURRENT_SOURCE_DIR}/../QXlsx/header/)
endif(NOT DEFINED ${QXLSX_HEADERPATH})

if(NOT DEFINED ${QXLSX_SOURCEPATH})
	set(QXLSX_SOURCEPATH ${CMAKE_CURRENT_SOURCE_DIR}/../QXlsx/source/)
endif(NOT DEFINED ${QXLSX_SOURCEPATH})

message("Current Path of QXlsx")
message(${QXLSX_PARENTPATH})
message(${QXLSX_HEADERPATH})
message(${QXLSX_SOURCEPATH})

# Due historical reasons this value is kept off
option(BUILD_SHARED_LIBS "Build in shared lib mode" OFF)

set(SRC_FILES
    source/xlsxcellrange.cpp
    source/xlsxcellrange.cpp
    source/xlsxcontenttypes.cpp
    source/xlsxdrawinganchor.cpp
    source/xlsxrichstring.cpp
    source/xlsxworkbook.cpp
    source/xlsxabstractooxmlfile.cpp
    source/xlsxcellreference.cpp
    source/xlsxdatavalidation.cpp
    source/xlsxdrawing.cpp
    source/xlsxsharedstrings.cpp
    source/xlsxworksheet.cpp
    source/xlsxabstractsheet.cpp
    source/xlsxchart.cpp
    source/xlsxdatetype.cpp
    source/xlsxformat.cpp
    source/xlsxsimpleooxmlfile.cpp
    source/xlsxzipreader.cpp
    source/xlsxcell.cpp
    source/xlsxchartsheet.cpp
    source/xlsxdocpropsapp.cpp
    source/xlsxmediafile.cpp
    source/xlsxstyles.cpp
    source/xlsxzipwriter.cpp
    source/xlsxcellformula.cpp
    source/xlsxcolor.cpp
    source/xlsxdocpropscore.cpp
    source/xlsxnumformatparser.cpp
    source/xlsxtheme.cpp
    source/xlsxcelllocation.cpp
    source/xlsxconditionalformatting.cpp
    source/xlsxdocument.cpp
    source/xlsxrelationships.cpp
    source/xlsxutility.cpp
    header/xlsxabstractooxmlfile_p.h
    header/xlsxchartsheet_p.h
    header/xlsxdocpropsapp_p.h
    header/xlsxformat_p.h
    header/xlsxsharedstrings_p.h
    header/xlsxworkbook_p.h
    header/xlsxabstractsheet_p.h
    header/xlsxcolor_p.h
    header/xlsxdocpropscore_p.h
    header/xlsxmediafile_p.h
    header/xlsxsimpleooxmlfile_p.h
    header/xlsxworksheet_p.h
    header/xlsxcellformula_p.h
    header/xlsxconditionalformatting_p.h
    header/xlsxdocument_p.h
    header/xlsxnumformatparser_p.h
    header/xlsxstyles_p.h
    header/xlsxzipreader_p.h
    header/xlsxcell_p.h
    header/xlsxcontenttypes_p.h
    header/xlsxdrawinganchor_p.h
    header/xlsxrelationships_p.h
    header/xlsxtheme_p.h
    header/xlsxzipwriter_p.h
    header/xlsxchart_p.h
    header/xlsxdatavalidation_p.h
    header/xlsxdrawing_p.h
    header/xlsxrichstring_p.h
    header/xlsxutility_p.h
)

set(QXLSX_PUBLIC_HEADERS
    header/xlsxabstractooxmlfile.h
    header/xlsxabstractsheet.h
    header/xlsxabstractsheet_p.h
    header/xlsxcellformula.h
    header/xlsxcell.h
    header/xlsxcelllocation.h
    header/xlsxcellrange.h
    header/xlsxcellreference.h
    header/xlsxchart.h
    header/xlsxchartsheet.h
    header/xlsxconditionalformatting.h
    header/xlsxdatavalidation.h
    header/xlsxdatetype.h
    header/xlsxdocument.h
    header/xlsxformat.h
    header/xlsxglobal.h
    header/xlsxrichstring.h
    header/xlsxworkbook.h
    header/xlsxworksheet.h
)

add_library(QXlsx
    ${SRC_FILES}
    ${QXLSX_PUBLIC_HEADERS}
)

add_library(QXlsx::QXlsx ALIAS QXlsx)

target_compile_definitions(QXlsx PRIVATE
    QT_NO_KEYWORDS
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_ASCII
    QT_NO_URL_CAST_FROM_STRING
    QT_NO_CAST_FROM_BYTEARRAY
    QT_USE_QSTRINGBUILDER
    QT_NO_SIGNALS_SLOTS_KEYWORDS
    QT_USE_FAST_OPERATOR_PLUS
    QT_DISABLE_DEPRECATED_BEFORE=0x060200
)

if (NOT WIN32)
    # Strict iterators can't be used on Windows, they lead to a link error
    # when application code iterates over a QVector<QPoint> for instance, unless
    # Qt itself was also built with strict iterators.
    # See example at https://bugreports.qt.io/browse/AUTOSUITE-946
    target_compile_definitions(QXlsx PRIVATE QT_STRICT_ITERATORS)
endif()

target_compile_features(QXlsx INTERFACE cxx_std_11)

if (BUILD_SHARED_LIBS)
    target_compile_definitions(QXlsx PUBLIC QXlsx_SHAREDLIB)
endif()

# Core + Gui (public). CorePrivate for qzipreader_p.h / qzipwriter_p.h.
target_link_libraries(${PROJECT_NAME}
   Qt${QT_VERSION_MAJOR}::Core
   Qt${QT_VERSION_MAJOR}::Gui
)
if(TARGET Qt${QT_VERSION_MAJOR}::CorePrivate)
   target_link_libraries(${PROJECT_NAME} PRIVATE Qt${QT_VERSION_MAJOR}::CorePrivate)
endif()

# Private headers (qzipreader_p.h, qzipwriter_p.h) for Qt6
if(QT_VERSION_MAJOR EQUAL 6)
   set(_qxlsx_private_inc "")
   if(DEFINED Qt6Core_PRIVATE_INCLUDE_DIRS)
      list(GET Qt6Core_PRIVATE_INCLUDE_DIRS 0 _qxlsx_private_inc)
   endif()
   if(NOT _qxlsx_private_inc OR NOT EXISTS "${_qxlsx_private_inc}/private/qzipreader_p.h")
      set(_qxlsx_private_inc "")
      # Try Qt6_DIR: .../lib/cmake/Qt6 -> prefix = .../../..
      if(DEFINED Qt6_DIR)
         get_filename_component(_qt6_prefix "${Qt6_DIR}/../.." ABSOLUTE)
         set(_ver_list "6.10.1" "6.10" "6.9")
         if(Qt6Core_VERSION)
            list(INSERT _ver_list 0 "${Qt6Core_VERSION}")
         endif()
         if(Qt6_VERSION)
            list(INSERT _ver_list 0 "${Qt6_VERSION}")
         endif()
         foreach(_ver ${_ver_list})
            if(EXISTS "${_qt6_prefix}/include/QtCore/${_ver}/QtCore/private/qzipreader_p.h")
               set(_qxlsx_private_inc "${_qt6_prefix}/include/QtCore/${_ver}/QtCore")
               break()
            endif()
         endforeach()
      endif()
   endif()
   if(NOT _qxlsx_private_inc AND CMAKE_PREFIX_PATH)
      # Try each CMAKE_PREFIX_PATH entry (e.g. C:/Qt/6.10.1/mingw_64)
      foreach(_p ${CMAKE_PREFIX_PATH})
         get_filename_component(_p_abs "${_p}" ABSOLUTE)
         if(EXISTS "${_p_abs}/include/QtCore/6.10.1/QtCore/private/qzipreader_p.h")
            set(_qxlsx_private_inc "${_p_abs}/include/QtCore/6.10.1/QtCore")
            break()
         endif()
         if(EXISTS "${_p_abs}/include/QtCore/private/qzipreader_p.h")
            set(_qxlsx_private_inc "${_p_abs}/include/QtCore")
            break()
         endif()
      endforeach()
   endif()
   if(_qxlsx_private_inc AND EXISTS "${_qxlsx_private_inc}/private/qzipreader_p.h")
      # Need both: .../QtCore/<ver>/QtCore (for <private/qzipreader_p.h>) and .../QtCore/<ver> (for <QtCore/private/qglobal_p.h>)
      get_filename_component(_qxlsx_qtcore_ver "${_qxlsx_private_inc}/.." ABSOLUTE)
      target_include_directories(QXlsx PRIVATE "${_qxlsx_private_inc}" "${_qxlsx_qtcore_ver}")
      message(STATUS "QXlsx: using Qt6 private includes: ${_qxlsx_private_inc} ; ${_qxlsx_qtcore_ver}")
   else()
      message(FATAL_ERROR "QXlsx: could not find Qt6 private headers (qzipreader_p.h). "
         "Prebuilt Qt SDK may not include private headers. "
         "Install Qt Source (qtbase) or use a Qt build that ships private includes.")
   endif()
   unset(_qxlsx_private_inc)
   unset(_qxlsx_qtcore_ver)
   unset(_qt6_prefix)
   unset(_p_abs)
endif()

target_include_directories(QXlsx
PRIVATE
    ${QXLSX_HEADERPATH}
PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/header>
    $<INSTALL_INTERFACE:include/QXlsx>
)

set_target_properties(QXlsx PROPERTIES
    OUTPUT_NAME ${EXPORT_NAME}
    VERSION ${PROJECT_VERSION}
    SOVERSION 0.${PROJECT_VERSION}
    PUBLIC_HEADER "${QXLSX_PUBLIC_HEADERS}"
)

install(TARGETS QXlsx
    EXPORT ${EXPORT_NAME}Targets DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT runtime
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT devel
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/QXlsxQt${QT_VERSION_MAJOR} COMPONENT devel
)

install(EXPORT ${EXPORT_NAME}Targets
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${EXPORT_NAME}/
    FILE ${EXPORT_NAME}Targets.cmake
    NAMESPACE QXlsx::
    COMPONENT devel
)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/qxlsx-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_NAME}Config.cmake
    @ONLY
)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/qxlsx-config-version.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_NAME}ConfigVersion.cmake
    @ONLY
)
install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_NAME}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_NAME}ConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${EXPORT_NAME}/
)
include(CPackConfig)
