#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSerialPortInfo>

#include "backend/MrSeriesController.h"
#include "backend/MdlSeriesController.h"
#include "backend/ControllerBox.h"
#include "backend/SignalMeasure.h"
#include "backend/AppController.h"
#include "example_code_excel/CableListManager.h"
#include "example_code_excel/TestPlanManager.h"
#include "example_code_excel/McuSender.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("CMN_TESTING");
    app.setApplicationVersion("1.0");

    auto *mrCtrl     = new MrSeriesController(&app);
    auto *mdlCtrl    = new MdlSeriesController(&app);
    auto *boxCtrl    = new ControllerBox(&app);
    auto *sigMeasure = new SignalMeasure(&app);
    auto *appCtrl    = new AppController(mrCtrl, mdlCtrl, boxCtrl, sigMeasure, &app);
    auto *cableListManager = new CableListManager(&app);
    auto *testPlanManager = new TestPlanManager(&app);
    auto *mcuSender = new McuSender(&app);

    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts())
        ports.append(info.portName());

    QQmlApplicationEngine engine;
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("mrController",  mrCtrl);
    ctx->setContextProperty("mdlController", mdlCtrl);
    ctx->setContextProperty("controllerBox", boxCtrl);
    ctx->setContextProperty("sigMeasure",    sigMeasure);
    ctx->setContextProperty("appController", appCtrl);
    ctx->setContextProperty("availablePorts", ports);
    ctx->setContextProperty("cableListManager", cableListManager);
    ctx->setContextProperty("testPlanManager", testPlanManager);
    ctx->setContextProperty("mcuSender", mcuSender);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("CMN_TESTING", "Main");
    return app.exec();
}
