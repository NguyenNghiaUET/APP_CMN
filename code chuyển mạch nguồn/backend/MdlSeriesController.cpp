#include "MdlSeriesController.h"
#include "ScpiTcpClient.h"

static constexpr int kPollIntervalMs = 2000;

const QStringList MdlSeriesController::kSourceNames = {
    "PUMP", "TELE", "MLĐ", "ERM", "PPA", "IGNITER"
};

MdlSeriesController::MdlSeriesController(QObject *parent)
    : QObject(parent)
    , m_client(new ScpiTcpClient(this))
    , m_pollTimer(new QTimer(this))
{
    m_channels.resize(kNumChannels);
    for (int i = 0; i < kNumChannels; ++i) {
        m_channels[i].index  = i + 1;
        m_channels[i].name   = QStringLiteral("LOAD_%1").arg(i + 1);
        m_channels[i].source = kSourceNames.value(i, "—");
    }

    m_pollTimer->setInterval(kPollIntervalMs);

    connect(m_client, &ScpiTcpClient::connectedChanged, this, [this](bool c) {
        if (c) {
            for (int i = 1; i <= kNumChannels; ++i) {
                m_client->sendCommand(QStringLiteral("INST CH%1").arg(i));
                m_client->sendCommand("FUNC CC");
            }
            m_pollTimer->start();
        } else {
            m_pollTimer->stop();
            m_pollActive = false;
            for (auto &ch : m_channels)
                ch.measCurrentA = ch.measVoltageV = 0.0;
            emit channelDataChanged();
        }
        emit connectedChanged(c);
    });

    connect(m_client, &ScpiTcpClient::queryResult,   this, &MdlSeriesController::onQueryResult);
    connect(m_client, &ScpiTcpClient::logMessage,    this, &MdlSeriesController::logMessage);
    connect(m_client, &ScpiTcpClient::errorOccurred, this, [this](const QString &e) {
        emit logMessage(QStringLiteral("[MDL ERROR] %1").arg(e));
    });
    connect(m_pollTimer, &QTimer::timeout, this, &MdlSeriesController::onPollTick);
}

bool MdlSeriesController::isConnected() const { return m_client->isConnected(); }

void MdlSeriesController::connectDevice(const QString &host, int port)
{
    m_client->connectToDevice(host, port);
}

void MdlSeriesController::disconnectDevice()
{
    m_client->disconnectFromDevice();
}

void MdlSeriesController::setChannelCurrent(int ch, double ampere)
{
    if (ch < 1 || ch > kNumChannels) return;
    m_channels[ch - 1].setCurrentA = ampere;
    emit channelDataChanged();
}

void MdlSeriesController::setChannelEnabled(int ch, bool enabled)
{
    if (ch < 1 || ch > kNumChannels) return;
    if (!isConnected()) { emit logMessage("[MDL] Not connected"); return; }
    m_channels[ch - 1].enabled = enabled;
    m_client->sendCommand(QStringLiteral("INST CH%1").arg(ch));
    m_client->sendCommand(enabled ? "INP ON" : "INP OFF");
    emit channelDataChanged();
    emit logMessage(QStringLiteral("[MDL] CH%1 (%2) → %3")
                    .arg(ch).arg(m_channels[ch-1].source).arg(enabled ? "ON" : "OFF"));
}

void MdlSeriesController::applyAll()
{
    if (!isConnected()) { emit logMessage("[MDL] Not connected"); return; }
    for (int i = 0; i < kNumChannels; ++i) {
        const auto &ch = m_channels[i];
        m_client->sendCommand(QStringLiteral("INST CH%1").arg(ch.index));
        m_client->sendCommand(QStringLiteral("CURR:STAT:L1 %1").arg(ch.setCurrentA, 0, 'f', 3));
        emit logMessage(QStringLiteral("[MDL] CH%1 (%2) set = %.3f A")
                        .arg(ch.index).arg(ch.source).arg(ch.setCurrentA));
    }
}

QVariantList MdlSeriesController::channelData() const
{
    QVariantList list;
    list.reserve(kNumChannels);
    for (const auto &ch : m_channels)
        list.append(channelToMap(ch));
    return list;
}

QVariantMap MdlSeriesController::channelToMap(const Channel &ch) const
{
    return {
        {"channel",      ch.index},
        {"name",         ch.name},
        {"source",       ch.source},
        {"setCurrentA",  ch.setCurrentA},
        {"measCurrentA", ch.measCurrentA},
        {"measVoltageV", ch.measVoltageV},
        {"enabled",      ch.enabled}
    };
}

void MdlSeriesController::onPollTick()
{
    if (m_pollActive) return;
    m_pollActive = true;
    m_pollCh     = 0;
    m_pollStep   = STEP_SELECT;
    advancePoll();
}

void MdlSeriesController::advancePoll()
{
    if (m_pollCh >= kNumChannels) {
        m_pollActive = false;
        emit channelDataChanged();
        return;
    }
    if (m_pollStep == STEP_SELECT) {
        m_client->sendCommand(QStringLiteral("INST CH%1").arg(m_pollCh + 1));
        m_pollStep = STEP_VOLT;
        m_client->sendQuery("MEAS:VOLT?");
    }
}

void MdlSeriesController::onQueryResult(const QString &result)
{
    bool ok = false;
    const double val = result.toDouble(&ok);
    if (!ok) { m_pollActive = false; return; }

    if (m_pollStep == STEP_VOLT) {
        m_channels[m_pollCh].measVoltageV = val;
        m_pollStep = STEP_CURR;
        m_client->sendQuery("MEAS:CURR?");
    } else if (m_pollStep == STEP_CURR) {
        m_channels[m_pollCh].measCurrentA = val;
        emit loadDataUpdated(m_channels[m_pollCh].index,
                             m_channels[m_pollCh].measVoltageV, val);
        m_pollCh++;
        m_pollStep = STEP_SELECT;
        advancePoll();
    }
}
