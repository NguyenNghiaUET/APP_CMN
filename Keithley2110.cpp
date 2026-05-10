#include "Keithley2110.h"
#include <QDebug>
#include <QRegularExpression>
#include <QThread>

Keithley2110::Keithley2110(QObject *parent)
    : QObject(parent)
    , m_isReading(false)
{
    // Keithley 2110 USB virtual COM (USBTMC): 115200, 8N1
    m_serial.setBaudRate(QSerialPort::Baud115200);
    m_serial.setDataBits(QSerialPort::Data8);
    m_serial.setParity(QSerialPort::NoParity);
    m_serial.setStopBits(QSerialPort::OneStop);
    m_serial.setFlowControl(QSerialPort::NoFlowControl);

    m_readTimeoutTimer.setSingleShot(true);
    m_readTimeoutTimer.setInterval(READ_TIMEOUT_MS);
    connect(&m_readTimeoutTimer, &QTimer::timeout, this, &Keithley2110::onReadTimeout);
    connect(&m_serial, &QSerialPort::readyRead, this, &Keithley2110::onDataReceived);
}

Keithley2110::~Keithley2110()
{
    if (m_serial.isOpen()) {
        m_serial.close();
    }
}

void Keithley2110::setPortName(const QString &name)
{
    if (m_portName != name) {
        m_portName = name;
        emit portNameChanged();
    }
}

bool Keithley2110::openPort()
{
    if (m_portName.isEmpty()) {
        qDebug() << "[Keithley2110] Loi: Chua chon cong COM";
        emit errorOccurred(tr("Chua chon cong COM"));
        return false;
    }
    if (m_serial.isOpen()) {
        qDebug() << "[Keithley2110] Dong cong COM cu:" << m_serial.portName();
        m_serial.close();
        emit openChanged();
    }
    m_serial.setPortName(m_portName);
    qDebug() << "[Keithley2110] Dang mo cong COM:" << m_portName << "Baudrate: 115200, 8N1";
    if (!m_serial.open(QIODevice::ReadWrite)) {
        qDebug() << "[Keithley2110] Loi khi mo cong COM:" << m_serial.errorString();
        emit errorOccurred(m_serial.errorString());
        return false;
    }
    qDebug() << "[Keithley2110] Da mo cong COM thanh cong:" << m_portName;

    m_serial.clear();

    emit openChanged();
    return true;
}

void Keithley2110::closePort()
{
    if (m_serial.isOpen()) {
        m_serial.close();
        emit openChanged();
    }
}

bool Keithley2110::readResistance()
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }

    if (m_isReading) {
        emit errorOccurred(tr("Đang đọc giá trị, vui lòng đợi"));
        return false;
    }

    m_isReading = true;
    emit readingChanged();

    m_receivedData.clear();
    m_serial.clear();

    QByteArray oldData = m_serial.readAll();
    if (!oldData.isEmpty()) {
        qDebug() << "[Keithley2110] Xoa du lieu cu trong buffer:" << oldData.toHex() << "(" << QString::fromLatin1(oldData) << ")";
    }
  //  console.log("cmd:auto")
    QByteArray command = "READ?\r\n";
    qDebug() << "[Keithley2110] Gui lenh xuong may:" << command.toHex() << "(" << command << ")";

    qint64 written = m_serial.write(command);
    m_serial.flush();

    if (written != command.size()) {
        qDebug() << "[Keithley2110] Loi khi gui lenh:" << m_serial.errorString() << "written:" << written << "expected:" << command.size();
        m_isReading = false;
        emit readingChanged();
        emit errorOccurred(m_serial.errorString());
        return false;
    }

    qDebug() << "[Keithley2110] Da gui lenh thanh cong, doi phan hoi tu may...";
    m_readTimeoutTimer.start();

    return true;
}

void Keithley2110::onDataReceived()
{
    if (!m_isReading) {
        qDebug() << "[Keithley2110] Nhan du lieu nhung khong dang doc (m_isReading = false)";
        return;
    }

    QByteArray data = m_serial.readAll();

    qDebug() << "[Keithley2110] Nhan du lieu tu may" << data.toHex() << "(" << QString::fromLatin1(data) << ")";
    m_receivedData.append(data);
    qDebug() << "[Keithley2110] Tong du lieu da nhan:" << m_receivedData.toHex() << "(" << QString::fromLatin1(m_receivedData) << ")";

    if (m_receivedData.contains('\r') || m_receivedData.contains('\n')) {
        QString responseStr = QString::fromLatin1(m_receivedData).trimmed();
        responseStr = responseStr.replace(QRegularExpression("[\r\n]+"), "");

        if (responseStr.startsWith("READ?") || responseStr.startsWith(":READ?") ||
            responseStr.startsWith("MEAS") || responseStr.startsWith(":MEAS") ||
            responseStr.startsWith("FETC") || responseStr.startsWith(":FETC")) {
            qDebug() << "[Keithley2110] Nhan duoc echo cua lenh:" << responseStr << "- bo qua va tiep tuc doi phan hoi thuc su...";
            m_receivedData.clear();
            m_readTimeoutTimer.stop();
            m_readTimeoutTimer.start();
            return;
        }

        bool looksLikeNumber = false;
        QString trimmed = responseStr.trimmed();
        if (!trimmed.isEmpty()) {
            QChar firstChar = trimmed[0];
            if (firstChar.isDigit() || firstChar == '+' || firstChar == '-' || firstChar == ' ' ||
                trimmed.contains('E') || trimmed.contains('e') || trimmed.contains('.')) {
                looksLikeNumber = true;
            }
        }

        if (!looksLikeNumber) {
            if (trimmed.contains("ERROR") || trimmed.contains("error") ||
                trimmed.contains("INVALID") || trimmed.contains("NAK")) {
                qDebug() << "[Keithley2110] May tra ve loi:" << responseStr;
                m_readTimeoutTimer.stop();
                m_isReading = false;
                m_receivedData.clear();
                emit readingChanged();
                emit errorOccurred(tr("Máy đo trả về lỗi: %1").arg(responseStr));
                return;
            }
            qDebug() << "[Keithley2110] Du lieu khong giong so:" << responseStr << "- tiep tuc doi...";
            m_receivedData.clear();
            return;
        }

        qDebug() << "[Keithley2110] Da nhan du du lieu (co CR/LF), bat dau parse...";
        m_readTimeoutTimer.stop();
        m_isReading = false;
        emit readingChanged();

        double value = 0.0;
        if (parseNR3(m_receivedData, value)) {
            qDebug() << "[Keithley2110] Parse thanh cong! Gia tri dien tro:" << value << "Ω";
            emit resistanceRead(value);
        } else {
            qDebug() << "[Keithley2110] Parse that bai! Du lieu nhan duoc:" << QString::fromLatin1(m_receivedData);
            emit errorOccurred(tr("Khong the parse gia tri tu may: %1").arg(QString::fromLatin1(m_receivedData)));
        }
    } else {
        qDebug() << "[Keithley2110] Chua nhan du du lieu, tiep tuc doi...";
    }
}

void Keithley2110::onReadTimeout()
{
    if (m_isReading) {
        qDebug() << "[Keithley2110] TIMEOUT! Khong nhan duoc phan hoi tu may sau" << READ_TIMEOUT_MS << "ms";
        qDebug() << "[Keithley2110] Du lieu da nhan duoc (neu co):" << m_receivedData.toHex() << "(" << QString::fromLatin1(m_receivedData) << ")";
        m_isReading = false;
        emit readingChanged();
        emit errorOccurred(tr("Timeout khi doc gia tri tu may"));
    }
}

bool Keithley2110::parseNR3(const QByteArray &data, double &value)
{
    QString str = QString::fromLatin1(data).trimmed();
    qDebug() << "[Keithley2110] Parse NR3 - Chuoi goc:" << str;

    str = str.replace(QRegularExpression("[\r\n]+"), "");
    qDebug() << "[Keithley2110] Sau khi loai bo CR/LF:" << str;

    if (str.startsWith(' ')) {
        str = '+' + str.trimmed();
        qDebug() << "[Keithley2110] Sau khi thay space dau bang +:" << str;
    }

    bool ok = false;
    value = str.toDouble(&ok);

    if (ok) {
        qDebug() << "[Keithley2110] Parse thanh cong:" << str << "->" << value << "Ω";
    } else {
        qDebug() << "[Keithley2110] Parse that bai:" << str << "tu du lieu hex:" << data.toHex();
    }

    return ok;
}

bool Keithley2110::sendCommand(const QString &command)
{
    if (!m_serial.isOpen()) {
        qDebug() << "[Keithley2110] sendCommand: Cổng COM chưa mở";
        return false;
    }

    QByteArray cmd = command.toLatin1() + "\r\n";
    qDebug() << "[Keithley2110] Gửi lệnh:" << cmd.trimmed();
    qint64 written = m_serial.write(cmd);
    m_serial.flush();

    if (written != cmd.size()) {
        qDebug() << "[Keithley2110] Lỗi gửi lệnh:" << m_serial.errorString();
        return false;
    }

    m_serial.waitForReadyRead(200);
    QByteArray response = m_serial.readAll();
    if (!response.isEmpty()) {
        qDebug() << "[Keithley2110] Phản hồi:" << QString::fromLatin1(response).trimmed();
    }

    return true;
}

bool Keithley2110::configureRM3544(const QString &range, const QString &speed)
{
    if (!m_serial.isOpen()) {
        qDebug() << "[Keithley2110] configure: Cổng COM chưa mở";
        return false;
    }

    bool ok = true;
    ok = sendCommand("CONF:RES") && ok;

    QMap<QString, QString> rangeMap;
    rangeMap["RANGE_100Ω"]   = "100";
    rangeMap["RANGE_1KΩ"]    = "1000";
    rangeMap["RANGE_10KΩ"]   = "10000";
    rangeMap["RANGE_100KΩ"]  = "100000";
    rangeMap["RANGE_1MΩ"]    = "1000000";
    rangeMap["RANGE_10MΩ"]   = "10000000";
    rangeMap["RANGE_100MΩ"]  = "100000000";

    if (rangeMap.contains(range)) {
        ok = sendCommand("SENS:RES:RANG " + rangeMap[range]) && ok;
        qDebug() << "[Keithley2110] Set range:" << range << "->" << rangeMap[range] << "Ω";
    } else {
        ok = sendCommand("SENS:RES:RANG:AUTO 1") && ok;
        qDebug() << "[Keithley2110] Range khong khop:" << range << "- dung auto range";
    }

    QMap<QString, QString> nplcMap;
    nplcMap["FAST"]  = "0.1";
    nplcMap["MED"]   = "1";
    nplcMap["SLOW"]  = "10";
    nplcMap["SLOW2"] = "100";

    QString nplc = nplcMap.value(speed, "1");
    ok = sendCommand("SENS:RES:NPLC " + nplc) && ok;
    qDebug() << "[Keithley2110] Set NPLC:" << speed << "->" << nplc;

    qDebug() << "[Keithley2110] Cau hinh xong - range:" << range << "speed:" << speed;
    return ok;
}

bool Keithley2110::configureAverage(int count)
{
    if (!m_serial.isOpen()) {
        qDebug() << "[Keithley2110] configureAverage: Cổng COM chưa mở";
        return false;
    }

    bool ok = true;

    if (count >= 2 && count <= 100) {
        qDebug() << "[Keithley2110] Bat Average, count:" << count;
        ok = sendCommand("AVER:TCON REP") && ok;
        ok = sendCommand("AVER:COUN " + QString::number(count)) && ok;
        ok = sendCommand("AVER:STAT ON") && ok;
    } else {
        qDebug() << "[Keithley2110] Tat Average (count:" << count << ")";
        ok = sendCommand("AVER:STAT OFF") && ok;
    }

    return ok;
}
