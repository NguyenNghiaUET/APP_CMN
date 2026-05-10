#include "ScpiTcpClient.h"
#include <QDebug>

static constexpr int kQueryTimeoutMs = 3000;

ScpiTcpClient::ScpiTcpClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QTcpSocket(this))
    , m_timeoutTimer(new QTimer(this))
{
    m_timeoutTimer->setSingleShot(true);
    m_timeoutTimer->setInterval(kQueryTimeoutMs);

    connect(m_socket, &QTcpSocket::connected,    this, &ScpiTcpClient::onConnected);
    connect(m_socket, &QTcpSocket::disconnected, this, &ScpiTcpClient::onDisconnected);
    connect(m_socket, &QTcpSocket::readyRead,    this, &ScpiTcpClient::onReadyRead);
    connect(m_socket, &QAbstractSocket::errorOccurred,
            this, &ScpiTcpClient::onSocketError);
    connect(m_timeoutTimer, &QTimer::timeout, this, &ScpiTcpClient::onQueryTimeout);
}

bool ScpiTcpClient::isConnected() const { return m_connected; }

void ScpiTcpClient::connectToDevice(const QString &host, int port)
{
    if (m_socket->state() != QAbstractSocket::UnconnectedState)
        m_socket->abort();
    emit logMessage(QStringLiteral("[TCP] Connecting to %1:%2 ...").arg(host).arg(port));
    m_socket->connectToHost(host, static_cast<quint16>(port));
}

void ScpiTcpClient::disconnectFromDevice()
{
    m_socket->disconnectFromHost();
}

void ScpiTcpClient::sendCommand(const QString &cmd)
{
    if (!m_connected) { emit errorOccurred("Not connected"); return; }
    m_socket->write((cmd + "\n").toUtf8());
    emit logMessage(QStringLiteral(">> %1").arg(cmd));
}

void ScpiTcpClient::sendQuery(const QString &cmd)
{
    if (!m_connected) { emit errorOccurred("Not connected"); return; }
    m_queryQueue.enqueue(cmd);
    if (!m_waitingResponse)
        processNextQuery();
}

void ScpiTcpClient::processNextQuery()
{
    if (m_queryQueue.isEmpty()) return;
    m_waitingResponse = true;
    const QString cmd = m_queryQueue.dequeue();
    m_socket->write((cmd + "\n").toUtf8());
    emit logMessage(QStringLiteral(">> %1").arg(cmd));
    m_timeoutTimer->start();
}

void ScpiTcpClient::onConnected()
{
    m_connected = true;
    emit connectedChanged(true);
    emit logMessage("[TCP] Connected.");
}

void ScpiTcpClient::onDisconnected()
{
    m_connected = false;
    m_waitingResponse = false;
    m_queryQueue.clear();
    m_rxBuffer.clear();
    emit connectedChanged(false);
    emit logMessage("[TCP] Disconnected.");
}

void ScpiTcpClient::onReadyRead()
{
    m_rxBuffer += m_socket->readAll();
    int idx;
    while ((idx = m_rxBuffer.indexOf('\n')) != -1) {
        const QString line = QString::fromUtf8(m_rxBuffer.left(idx)).trimmed();
        m_rxBuffer.remove(0, idx + 1);
        if (m_waitingResponse) {
            m_timeoutTimer->stop();
            m_waitingResponse = false;
            emit logMessage(QStringLiteral("<< %1").arg(line));
            emit queryResult(line);
            processNextQuery();
        }
    }
}

void ScpiTcpClient::onSocketError(QAbstractSocket::SocketError)
{
    const QString msg = m_socket->errorString();
    emit errorOccurred(msg);
    emit logMessage(QStringLiteral("[TCP ERROR] %1").arg(msg));
}

void ScpiTcpClient::onQueryTimeout()
{
    m_waitingResponse = false;
    emit errorOccurred("Query timeout");
    emit logMessage("[TIMEOUT] No response from instrument");
    processNextQuery();
}
