cmake_minimum_required(VERSION 3.16)

project(CMN_TESTING VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 LabsPlatform SerialPort Concurrent Network)

# QXlsx cho đọc file Excel .xlsx — đặt thư mục third_party/QXlsx (xem third_party/README_QXlsx.txt)
set(QXlsx_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/QXlsx")
set(HAVE_QXLSX FALSE)
if(EXISTS "${QXlsx_DIR}/CMakeLists.txt")
    set(QT_VERSION_MAJOR 6)
    add_subdirectory(${QXlsx_DIR} ${CMAKE_BINARY_DIR}/QXlsx)
    set(HAVE_QXLSX TRUE)
    message(STATUS "QXlsx: found at ${QXlsx_DIR} -> HAVE_QXLSX=ON")
else()
    message(STATUS "QXlsx: not found at ${QXlsx_DIR} -> HAVE_QXLSX=OFF (Excel .xlsx will not load)")
endif()

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appCMN_TESTING
    main.cpp
    # ── Cable test backend ──────────────────────────────────────
    CableListManager.cpp
    TestPlanManager.cpp
    McuSender.cpp
    Keithley2110.cpp
    FileHelper.cpp
    # ── Power switching backend ─────────────────────────────────
    AppController.cpp
    ControllerBox.cpp
    MrSeriesController.cpp
    MdlSeriesController.cpp
    ScpiTcpClient.cpp
    SignalMeasure.cpp
)

qt_add_qml_module(appCMN_TESTING
    URI CMN_TESTING
    QML_FILES
        Main.qml
        AutoTestWindow.qml
        MainContent.qml
        ManualTestView.qml
        AppConfigDialog.qml
        DeviceConfigDialog.qml
        CableListDialog.qml
        AutoTestPlanDialog.qml
        TestPlanListDialog.qml
        CalibrationDialog.qml
        CableCalibrationDialog.qml
        ManualReadDialog.qml
    RESOURCES
        logo.png
)

set_target_properties(appCMN_TESTING PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appCMN_TESTING
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::LabsPlatform
        Qt6::SerialPort
        Qt6::Concurrent
        Qt6::Network
)

if(HAVE_QXLSX)
    target_link_libraries(appCMN_TESTING PRIVATE QXlsx::QXlsx)
    target_include_directories(appCMN_TESTING PRIVATE ${QXlsx_DIR}/header)
    target_compile_definitions(appCMN_TESTING PRIVATE HAVE_QXLSX)
endif()

include(GNUInstallDirs)
install(TARGETS appCMN_TESTING
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
