#include "MrSeriesController.h"
#include "ScpiTcpClient.h"

static constexpr int kPollIntervalMs = 1000;

MrSeriesController::MrSeriesController(QObject *parent)
    : QObject(parent)
    , m_client(new ScpiTcpClient(this))
    , m_pollTimer(new QTimer(this))
{
    m_pollTimer->setInterval(kPollIntervalMs);

    connect(m_client, &ScpiTcpClient::connectedChanged, this, [this](bool c) {
        if (c) {
            m_pollTimer->start();
        } else {
            m_pollTimer->stop();
            m_pollActive = false;
            m_measVoltage = m_measCurrent = m_measPower = 0.0;
            emit measVoltageChanged();
            emit measCurrentChanged();
            emit measPowerChanged();
        }
        emit connectedChanged(c);
    });

    connect(m_client, &ScpiTcpClient::queryResult, this, &MrSeriesController::onQueryResult);
    connect(m_client, &ScpiTcpClient::logMessage,  this, &MrSeriesController::logMessage);
    connect(m_client, &ScpiTcpClient::errorOccurred, this, [this](const QString &e) {
        emit logMessage(QStringLiteral("[MR3K ERROR] %1").arg(e));
    });

    connect(m_pollTimer, &QTimer::timeout, this, &MrSeriesController::onPollTick);
}

void MrSeriesController::connectDevice(const QString &host, int port)
{
    m_client->connectToDevice(host, port);
}

void MrSeriesController::disconnectDevice()
{
    m_client->disconnectFromDevice();
}

bool MrSeriesController::isConnected() const
{
    return m_client->isConnected();
}

void MrSeriesController::setSetVoltage(double v)
{
    if (qFuzzyCompare(v, m_setVoltage)) return;
    m_setVoltage = v;
    emit setVoltageChanged();
}

void MrSeriesController::setSetCurrent(double a)
{
    if (qFuzzyCompare(a, m_setCurrent)) return;
    m_setCurrent = a;
    emit setCurrentChanged();
}

void MrSeriesController::setSetOCP(double a)
{
    if (qFuzzyCompare(a, m_setOCP)) return;
    m_setOCP = a;
    emit setOCPChanged();
}

void MrSeriesController::applySettings()
{
    if (!isConnected()) { emit logMessage("[MR3K] Not connected"); return; }
    m_client->sendCommand(QStringLiteral("VOLT %1").arg(m_setVoltage, 0, 'f', 2));
    m_client->sendCommand(QStringLiteral("CURR %1").arg(m_setCurrent, 0, 'f', 3));
    m_client->sendCommand(QStringLiteral("CURR:PROT %1").arg(m_setOCP, 0, 'f', 3));
    emit logMessage(QStringLiteral("[MR3K] Settings applied: V=%.2fV  I=%.3fA  OCP=%.3fA")
                    .arg(m_setVoltage).arg(m_setCurrent).arg(m_setOCP));
}

void MrSeriesController::setOutput(bool enabled)
{
    if (!isConnected()) { emit logMessage("[MR3K] Not connected"); return; }
    m_outputEnabled = enabled;
    m_client->sendCommand(enabled ? "OUTP ON" : "OUTP OFF");
    emit outputEnabledChanged();
    emit logMessage(QStringLiteral("[MR3K] Output %1").arg(enabled ? "ON" : "OFF"));
}

void MrSeriesController::onPollTick()
{
    if (m_pollActive) return; // previous poll not done yet
    m_pollActive = true;
    m_pollStep   = POLL_VOLT;
    m_client->sendQuery("MEAS:VOLT?");
}

void MrSeriesController::onQueryResult(const QString &result)
{
    bool ok = false;
    const double val = result.toDouble(&ok);
    if (!ok) { m_pollActive = false; return; }

    switch (m_pollStep) {
    case POLL_VOLT:
        m_measVoltage = val;
        emit measVoltageChanged();
        m_pollStep = POLL_CURR;
        m_client->sendQuery("MEAS:CURR?");
        break;
    case POLL_CURR:
        m_measCurrent = val;
        emit measCurrentChanged();
        m_pollStep = POLL_POW;
        m_client->sendQuery("MEAS:POW?");
        break;
    case POLL_POW:
        m_measPower = val;
        emit measPowerChanged();
        m_pollActive = false;
        break;
    }
}
