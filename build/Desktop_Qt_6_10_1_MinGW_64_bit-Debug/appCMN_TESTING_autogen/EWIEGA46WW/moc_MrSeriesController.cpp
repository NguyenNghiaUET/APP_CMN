/****************************************************************************
** Meta object code from reading C++ file 'MrSeriesController.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../MrSeriesController.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'MrSeriesController.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.10.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN18MrSeriesControllerE_t {};
} // unnamed namespace

template <> constexpr inline auto MrSeriesController::qt_create_metaobjectdata<qt_meta_tag_ZN18MrSeriesControllerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "MrSeriesController",
        "connectedChanged",
        "",
        "c",
        "setVoltageChanged",
        "setCurrentChanged",
        "setOCPChanged",
        "outputEnabledChanged",
        "measVoltageChanged",
        "measCurrentChanged",
        "measPowerChanged",
        "logMessage",
        "msg",
        "onQueryResult",
        "result",
        "onPollTick",
        "connectDevice",
        "host",
        "port",
        "disconnectDevice",
        "applySettings",
        "setOutput",
        "enabled",
        "connected",
        "setVoltage",
        "setCurrent",
        "setOCP",
        "outputEnabled",
        "measVoltage",
        "measCurrent",
        "measPower"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'connectedChanged'
        QtMocHelpers::SignalData<void(bool)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 3 },
        }}),
        // Signal 'setVoltageChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'setCurrentChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'setOCPChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'outputEnabledChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'measVoltageChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'measCurrentChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'measPowerChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'logMessage'
        QtMocHelpers::SignalData<void(const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Slot 'onQueryResult'
        QtMocHelpers::SlotData<void(const QString &)>(13, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 14 },
        }}),
        // Slot 'onPollTick'
        QtMocHelpers::SlotData<void()>(15, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'connectDevice'
        QtMocHelpers::MethodData<void(const QString &, int)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 }, { QMetaType::Int, 18 },
        }}),
        // Method 'connectDevice'
        QtMocHelpers::MethodData<void(const QString &)>(16, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 17 },
        }}),
        // Method 'disconnectDevice'
        QtMocHelpers::MethodData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'applySettings'
        QtMocHelpers::MethodData<void()>(20, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setOutput'
        QtMocHelpers::MethodData<void(bool)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 22 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'connected'
        QtMocHelpers::PropertyData<bool>(23, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'setVoltage'
        QtMocHelpers::PropertyData<double>(24, QMetaType::Double, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'setCurrent'
        QtMocHelpers::PropertyData<double>(25, QMetaType::Double, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'setOCP'
        QtMocHelpers::PropertyData<double>(26, QMetaType::Double, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'outputEnabled'
        QtMocHelpers::PropertyData<bool>(27, QMetaType::Bool, QMC::DefaultPropertyFlags, 4),
        // property 'measVoltage'
        QtMocHelpers::PropertyData<double>(28, QMetaType::Double, QMC::DefaultPropertyFlags, 5),
        // property 'measCurrent'
        QtMocHelpers::PropertyData<double>(29, QMetaType::Double, QMC::DefaultPropertyFlags, 6),
        // property 'measPower'
        QtMocHelpers::PropertyData<double>(30, QMetaType::Double, QMC::DefaultPropertyFlags, 7),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<MrSeriesController, qt_meta_tag_ZN18MrSeriesControllerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject MrSeriesController::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18MrSeriesControllerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18MrSeriesControllerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN18MrSeriesControllerE_t>.metaTypes,
    nullptr
} };

void MrSeriesController::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<MrSeriesController *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->connectedChanged((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 1: _t->setVoltageChanged(); break;
        case 2: _t->setCurrentChanged(); break;
        case 3: _t->setOCPChanged(); break;
        case 4: _t->outputEnabledChanged(); break;
        case 5: _t->measVoltageChanged(); break;
        case 6: _t->measCurrentChanged(); break;
        case 7: _t->measPowerChanged(); break;
        case 8: _t->logMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: _t->onQueryResult((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 10: _t->onPollTick(); break;
        case 11: _t->connectDevice((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 12: _t->connectDevice((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 13: _t->disconnectDevice(); break;
        case 14: _t->applySettings(); break;
        case 15: _t->setOutput((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)(bool )>(_a, &MrSeriesController::connectedChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::setVoltageChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::setCurrentChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::setOCPChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::outputEnabledChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::measVoltageChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::measCurrentChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)()>(_a, &MrSeriesController::measPowerChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (MrSeriesController::*)(const QString & )>(_a, &MrSeriesController::logMessage, 8))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->isConnected(); break;
        case 1: *reinterpret_cast<double*>(_v) = _t->setVoltage(); break;
        case 2: *reinterpret_cast<double*>(_v) = _t->setCurrent(); break;
        case 3: *reinterpret_cast<double*>(_v) = _t->setOCP(); break;
        case 4: *reinterpret_cast<bool*>(_v) = _t->outputEnabled(); break;
        case 5: *reinterpret_cast<double*>(_v) = _t->measVoltage(); break;
        case 6: *reinterpret_cast<double*>(_v) = _t->measCurrent(); break;
        case 7: *reinterpret_cast<double*>(_v) = _t->measPower(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 1: _t->setSetVoltage(*reinterpret_cast<double*>(_v)); break;
        case 2: _t->setSetCurrent(*reinterpret_cast<double*>(_v)); break;
        case 3: _t->setSetOCP(*reinterpret_cast<double*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *MrSeriesController::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MrSeriesController::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18MrSeriesControllerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int MrSeriesController::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 16)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 16;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 16)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 16;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    return _id;
}

// SIGNAL 0
void MrSeriesController::connectedChanged(bool _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void MrSeriesController::setVoltageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void MrSeriesController::setCurrentChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void MrSeriesController::setOCPChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void MrSeriesController::outputEnabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void MrSeriesController::measVoltageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void MrSeriesController::measCurrentChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void MrSeriesController::measPowerChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void MrSeriesController::logMessage(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}
QT_WARNING_POP
