#include <QtQml/qqmlprivate.h>
#include <QtCore/qdir.h>
#include <QtCore/qurl.h>
#include <QtCore/qhash.h>
#include <QtCore/qstring.h>

namespace QmlCacheGeneratedCode {
namespace _qt_qml_CMN_TESTING_Main_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_AutoTestWindow_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_MainContent_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_ManualTestView_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_AppConfigDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_DeviceConfigDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_CableListDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_AutoTestPlanDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_TestPlanListDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_CalibrationDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_CableCalibrationDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}
namespace _qt_qml_CMN_TESTING_ManualReadDialog_qml { 
    extern const unsigned char qmlData[];
    extern const QQmlPrivate::AOTCompiledFunction aotBuiltFunctions[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), &aotBuiltFunctions[0], nullptr
    };
}

}
namespace {
struct Registry {
    Registry();
    ~Registry();
    QHash<QString, const QQmlPrivate::CachedQmlUnit*> resourcePathToCachedUnit;
    static const QQmlPrivate::CachedQmlUnit *lookupCachedUnit(const QUrl &url);
};

Q_GLOBAL_STATIC(Registry, unitRegistry)


Registry::Registry() {
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/Main.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_Main_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/AutoTestWindow.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_AutoTestWindow_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/MainContent.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_MainContent_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/ManualTestView.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_ManualTestView_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/AppConfigDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_AppConfigDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/DeviceConfigDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_DeviceConfigDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/CableListDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_CableListDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/AutoTestPlanDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_AutoTestPlanDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/TestPlanListDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_TestPlanListDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/CalibrationDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_CalibrationDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/CableCalibrationDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_CableCalibrationDialog_qml::unit);
    resourcePathToCachedUnit.insert(QStringLiteral("/qt/qml/CMN_TESTING/ManualReadDialog.qml"), &QmlCacheGeneratedCode::_qt_qml_CMN_TESTING_ManualReadDialog_qml::unit);
    QQmlPrivate::RegisterQmlUnitCacheHook registration;
    registration.structVersion = 0;
    registration.lookupCachedQmlUnit = &lookupCachedUnit;
    QQmlPrivate::qmlregister(QQmlPrivate::QmlUnitCacheHookRegistration, &registration);
}

Registry::~Registry() {
    QQmlPrivate::qmlunregister(QQmlPrivate::QmlUnitCacheHookRegistration, quintptr(&lookupCachedUnit));
}

const QQmlPrivate::CachedQmlUnit *Registry::lookupCachedUnit(const QUrl &url) {
    if (url.scheme() != QLatin1String("qrc"))
        return nullptr;
    QString resourcePath = QDir::cleanPath(url.path());
    if (resourcePath.isEmpty())
        return nullptr;
    if (!resourcePath.startsWith(QLatin1Char('/')))
        resourcePath.prepend(QLatin1Char('/'));
    return unitRegistry()->resourcePathToCachedUnit.value(resourcePath, nullptr);
}
}
int QT_MANGLE_NAMESPACE(qInitResources_qmlcache_appCMN_TESTING)() {
    ::unitRegistry();
    return 1;
}
Q_CONSTRUCTOR_FUNCTION(QT_MANGLE_NAMESPACE(qInitResources_qmlcache_appCMN_TESTING))
int QT_MANGLE_NAMESPACE(qCleanupResources_qmlcache_appCMN_TESTING)() {
    return 1;
}
