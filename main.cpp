#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QQmlContext>
#include <QSerialPortInfo>

// Cable test backend
#include "CableListManager.h"
#include "TestPlanManager.h"
#include "McuSender.h"
#include "Keithley2110.h"
#include "FileHelper.h"

// Power switching backend
#include "AppController.h"
#include "MrSeriesController.h"
#include "MdlSeriesController.h"
#include "ControllerBox.h"
#include "SignalMeasure.h"
#include "CmnAutoTestRunner.h"

int main(int argc, char *argv[])
{
    qputenv("QT_LOGGING_RULES", QByteArray("qt.qpa.mime.warning=false"));

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("CMN_TESTING"));
    app.setApplicationVersion("1.0");
    app.setWindowIcon(QIcon(":/qt/qml/CMN_TESTING/logo.png"));

    // ── Cable test objects ───────────────────────────────────────────────
    CableListManager cableListManager;
    TestPlanManager  testPlanManager;
    McuSender        mcuSender;
    Keithley2110     keithley2110;
    FileHelper       fileHelper;

    // ── Power switching objects ──────────────────────────────────────────
    auto *mrCtrl     = new MrSeriesController(&app);
    auto *mdlCtrl    = new MdlSeriesController(&app);
    auto *boxCtrl    = new ControllerBox(&app);
    auto *sigMeasure = new SignalMeasure(&app);
    auto *appCtrl      = new AppController(mrCtrl, mdlCtrl, boxCtrl, sigMeasure, &app);
    auto *cmnAutoRunner = new CmnAutoTestRunner(mrCtrl, mdlCtrl, boxCtrl, sigMeasure, &mcuSender, &app);

    // ── Available serial ports ───────────────────────────────────────────
    QStringList availablePorts;
    for (const auto &info : QSerialPortInfo::availablePorts())
        availablePorts.append(info.portName());

    // ── Register C++ types for QML ───────────────────────────────────────
    qmlRegisterType<Keithley2110>("CMN_TESTING", 1, 0, "Keithley2110");

    // ── QML engine setup ─────────────────────────────────────────────────
    QQmlApplicationEngine engine;
    QQmlContext *ctx = engine.rootContext();

    // Cable test context
    ctx->setContextProperty("cableListManager", &cableListManager);
    ctx->setContextProperty("testPlanManager",  &testPlanManager);
    ctx->setContextProperty("mcuSender",        &mcuSender);
    ctx->setContextProperty("keithley2110",       &keithley2110);
    ctx->setContextProperty("fileHelper",        &fileHelper);

    // Power switching context
    ctx->setContextProperty("mrController",   mrCtrl);
    ctx->setContextProperty("mdlController",  mdlCtrl);
    ctx->setContextProperty("controllerBox",  boxCtrl);
    ctx->setContextProperty("sigMeasure",     sigMeasure);
    ctx->setContextProperty("appController",  appCtrl);
    ctx->setContextProperty("cmnAutoRunner",  cmnAutoRunner);
    ctx->setContextProperty("availablePorts", availablePorts);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("CMN_TESTING", "Main");

    return app.exec();
}
