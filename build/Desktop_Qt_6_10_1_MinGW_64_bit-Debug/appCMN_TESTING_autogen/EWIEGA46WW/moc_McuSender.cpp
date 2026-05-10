/****************************************************************************
** Meta object code from reading C++ file 'McuSender.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../McuSender.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'McuSender.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN9McuSenderE_t {};
} // unnamed namespace

template <> constexpr inline auto McuSender::qt_create_metaobjectdata<qt_meta_tag_ZN9McuSenderE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "McuSender",
        "portNameChanged",
        "",
        "baudRateChanged",
        "openChanged",
        "queueChanged",
        "sent",
        "count",
        "errorOccurred",
        "message",
        "dataReceived",
        "QVariantMap",
        "measurementData",
        "mcuAckReceived",
        "mcuNakReceived",
        "errCode",
        "mcuNakSkipped",
        "seq",
        "allPacketsSent",
        "onReadyRead",
        "sendNextQueuedPacket",
        "getAvailablePorts",
        "sendPinPairs",
        "QVariantList",
        "pairs",
        "sendTestScripts",
        "scripts",
        "isCalibration",
        "openPort",
        "closePort",
        "sendTestPacket",
        "debugHexPacket",
        "hexString",
        "cancelQueue",
        "sendNextScript",
        "portName",
        "baudRate",
        "isOpen",
        "queuedPacketCount",
        "currentPacketIndex",
        "isSendingQueue"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'portNameChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'baudRateChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'openChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'queueChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sent'
        QtMocHelpers::SignalData<void(int)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 7 },
        }}),
        // Signal 'errorOccurred'
        QtMocHelpers::SignalData<void(const QString &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 },
        }}),
        // Signal 'dataReceived'
        QtMocHelpers::SignalData<void(const QVariantMap &)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Signal 'mcuAckReceived'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'mcuNakReceived'
        QtMocHelpers::SignalData<void(int)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 15 },
        }}),
        // Signal 'mcuNakSkipped'
        QtMocHelpers::SignalData<void(int)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 17 },
        }}),
        // Signal 'allPacketsSent'
        QtMocHelpers::SignalData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onReadyRead'
        QtMocHelpers::SlotData<void()>(19, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'sendNextQueuedPacket'
        QtMocHelpers::SlotData<void()>(20, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'getAvailablePorts'
        QtMocHelpers::MethodData<QStringList() const>(21, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'sendPinPairs'
        QtMocHelpers::MethodData<bool(const QVariantList &)>(22, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 23, 24 },
        }}),
        // Method 'sendTestScripts'
        QtMocHelpers::MethodData<bool(const QVariantList &, bool)>(25, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 23, 26 }, { QMetaType::Bool, 27 },
        }}),
        // Method 'sendTestScripts'
        QtMocHelpers::MethodData<bool(const QVariantList &)>(25, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { 0x80000000 | 23, 26 },
        }}),
        // Method 'openPort'
        QtMocHelpers::MethodData<bool()>(28, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'closePort'
        QtMocHelpers::MethodData<void()>(29, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendTestPacket'
        QtMocHelpers::MethodData<bool()>(30, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'debugHexPacket'
        QtMocHelpers::MethodData<void(const QString &)>(31, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 32 },
        }}),
        // Method 'cancelQueue'
        QtMocHelpers::MethodData<void()>(33, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendNextScript'
        QtMocHelpers::MethodData<void()>(34, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'portName'
        QtMocHelpers::PropertyData<QString>(35, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'baudRate'
        QtMocHelpers::PropertyData<int>(36, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'isOpen'
        QtMocHelpers::PropertyData<bool>(37, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'queuedPacketCount'
        QtMocHelpers::PropertyData<int>(38, QMetaType::Int, QMC::DefaultPropertyFlags, 3),
        // property 'currentPacketIndex'
        QtMocHelpers::PropertyData<int>(39, QMetaType::Int, QMC::DefaultPropertyFlags, 3),
        // property 'isSendingQueue'
        QtMocHelpers::PropertyData<bool>(40, QMetaType::Bool, QMC::DefaultPropertyFlags, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<McuSender, qt_meta_tag_ZN9McuSenderE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject McuSender::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN9McuSenderE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN9McuSenderE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN9McuSenderE_t>.metaTypes,
    nullptr
} };

void McuSender::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<McuSender *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->portNameChanged(); break;
        case 1: _t->baudRateChanged(); break;
        case 2: _t->openChanged(); break;
        case 3: _t->queueChanged(); break;
        case 4: _t->sent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 5: _t->errorOccurred((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 6: _t->dataReceived((*reinterpret_cast<std::add_pointer_t<QVariantMap>>(_a[1]))); break;
        case 7: _t->mcuAckReceived(); break;
        case 8: _t->mcuNakReceived((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 9: _t->mcuNakSkipped((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 10: _t->allPacketsSent(); break;
        case 11: _t->onReadyRead(); break;
        case 12: _t->sendNextQueuedPacket(); break;
        case 13: { QStringList _r = _t->getAvailablePorts();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 14: { bool _r = _t->sendPinPairs((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 15: { bool _r = _t->sendTestScripts((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 16: { bool _r = _t->sendTestScripts((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 17: { bool _r = _t->openPort();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 18: _t->closePort(); break;
        case 19: { bool _r = _t->sendTestPacket();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 20: _t->debugHexPacket((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 21: _t->cancelQueue(); break;
        case 22: _t->sendNextScript(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::portNameChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::baudRateChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::openChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::queueChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)(int )>(_a, &McuSender::sent, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)(const QString & )>(_a, &McuSender::errorOccurred, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)(const QVariantMap & )>(_a, &McuSender::dataReceived, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::mcuAckReceived, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)(int )>(_a, &McuSender::mcuNakReceived, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)(int )>(_a, &McuSender::mcuNakSkipped, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuSender::*)()>(_a, &McuSender::allPacketsSent, 10))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->portName(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->baudRate(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->isOpen(); break;
        case 3: *reinterpret_cast<int*>(_v) = _t->queuedPacketCount(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->currentPacketIndex(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->isSendingQueue(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setPortName(*reinterpret_cast<QString*>(_v)); break;
        case 1: _t->setBaudRate(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *McuSender::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *McuSender::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN9McuSenderE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int McuSender::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 23)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 23;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 23)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 23;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void McuSender::portNameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void McuSender::baudRateChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void McuSender::openChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void McuSender::queueChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void McuSender::sent(int _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1);
}

// SIGNAL 5
void McuSender::errorOccurred(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1);
}

// SIGNAL 6
void McuSender::dataReceived(const QVariantMap & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1);
}

// SIGNAL 7
void McuSender::mcuAckReceived()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void McuSender::mcuNakReceived(int _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}

// SIGNAL 9
void McuSender::mcuNakSkipped(int _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 9, nullptr, _t1);
}

// SIGNAL 10
void McuSender::allPacketsSent()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}
QT_WARNING_POP
