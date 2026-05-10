#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QQueue>

class ScpiTcpClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)

public:
    explicit ScpiTcpClient(QObject *parent = nullptr);

    bool isConnected() const;

    Q_INVOKABLE void connectToDevice(const QString &host, int port = 5025);
    Q_INVOKABLE void disconnectFromDevice();

    // Fire-and-forget write (no response expected)
    void sendCommand(const QString &cmd);

    // Queue a query; result comes back via queryResult()
    void sendQuery(const QString &cmd);

signals:
    void connectedChanged(bool connected);
    void queryResult(const QString &result);
    void errorOccurred(const QString &msg);
    void logMessage(const QString &msg);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onSocketError(QAbstractSocket::SocketError err);
    void onQueryTimeout();

private:
    void processNextQuery();

    QTcpSocket  *m_socket;
    QTimer      *m_timeoutTimer;
    QByteArray   m_rxBuffer;
    QQueue<QString> m_queryQueue;
    bool         m_waitingResponse = false;
    bool         m_connected       = false;
};
