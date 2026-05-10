#include "FileHelper.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QStringConverter>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QHostInfo>
#include <QDateTime>

#ifdef HAVE_QXLSX
#include "xlsxdocument.h"
#include "xlsxformat.h"
#endif

FileHelper::FileHelper(QObject *parent)
    : QObject(parent)
{
}

bool FileHelper::writeTextFile(const QString &filePath, const QString &content)
{
    QFileInfo fi(filePath);
    QDir().mkpath(fi.absolutePath());

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Cannot open file for writing:" << filePath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << content;
    file.close();

    return true;
}

QString FileHelper::readTextFile(const QString &filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Cannot open file for reading:" << filePath;
        return QString();
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    file.close();

    return content;
}

QString FileHelper::applicationDirPath() const
{
    return QCoreApplication::applicationDirPath();
}

bool FileHelper::saveCalibrationMode(const QString &mode)
{
    QString appDir = QCoreApplication::applicationDirPath();
    QString configPath = appDir + "/calibration_mode.txt";
    return writeTextFile(configPath, mode);
}

QString FileHelper::loadCalibrationMode() const
{
    QString appDir = QCoreApplication::applicationDirPath();
    QString configPath = appDir + "/calibration_mode.txt";
    QString mode = readTextFile(configPath);
    return mode.trimmed();
    
}

bool FileHelper::saveStationConfig(const QString &jsonStr)
{
    QString appDir = QCoreApplication::applicationDirPath();
    QString configPath = appDir + "/station_config.json";
    return writeTextFile(configPath, jsonStr);
}

QString FileHelper::loadStationConfig() const
{
    QString appDir = QCoreApplication::applicationDirPath();
    QString configPath = appDir + "/station_config.json";
    if (!QFile::exists(configPath)) return QString();
    return readTextFile(configPath).trimmed();
}

QString FileHelper::computerName() const
{
    return QHostInfo::localHostName();
}

bool FileHelper::exportExcel(const QString &filePath,
                              const QString &stationInfoJson,
                              const QString &testResultsJson)
{
#ifndef HAVE_QXLSX
    qWarning() << "QXlsx not available, cannot export Excel";
    return false;
#else
    QXlsx::Document xlsx;

    // Parse JSON
    QJsonDocument stationDoc = QJsonDocument::fromJson(stationInfoJson.toUtf8());
    QJsonObject station = stationDoc.object();

    QJsonDocument resultsDoc = QJsonDocument::fromJson(testResultsJson.toUtf8());
    QJsonArray results = resultsDoc.array();

    // === Header format ===
    QXlsx::Format headerLabelFmt;
    headerLabelFmt.setFontBold(true);
    headerLabelFmt.setFontSize(11);

    QXlsx::Format headerValueFmt;
    headerValueFmt.setFontSize(11);

    // === Row 1-6: Station info ===
    xlsx.write("A1", QString::fromUtf8("Tên xí nghiệp:"), headerLabelFmt);
    xlsx.write("B1", station.value("companyName").toString(), headerValueFmt);

    xlsx.write("A2", QString::fromUtf8("Tên trạm đo:"), headerLabelFmt);
    xlsx.write("B2", station.value("stationName").toString(), headerValueFmt);

    xlsx.write("A3", QString::fromUtf8("Tên máy tính:"), headerLabelFmt);
    xlsx.write("B3", QHostInfo::localHostName(), headerValueFmt);

    xlsx.write("A4", QString::fromUtf8("Phiên bản phần mềm:"), headerLabelFmt);
    xlsx.write("B4", QStringLiteral("1,0,0,0"), headerValueFmt);

    xlsx.write("A5", QString::fromUtf8("Thời gian bắt đầu:"), headerLabelFmt);
    xlsx.write("B5", station.value("startTime").toString(
        QDateTime::currentDateTime().toString("M/d/yyyy h:mm:ss AP")), headerValueFmt);

    xlsx.write("A6", QString::fromUtf8("Thời gian kết thúc:"), headerLabelFmt);
    xlsx.write("B6", station.value("endTime").toString(
        QDateTime::currentDateTime().toString("M/d/yyyy h:mm:ss AP")), headerValueFmt);

    xlsx.write("A7", QString::fromUtf8("Serial sản phẩm:"), headerLabelFmt);
    xlsx.write("B7", station.value("serialNumber").toString("DEFAULTSN0001"), headerValueFmt);

    // === Row 8: Column headers ===
    QXlsx::Format colHeaderFmt;
    colHeaderFmt.setFontBold(true);
    colHeaderFmt.setFontSize(11);
    colHeaderFmt.setFontColor(QColor("#1565C0"));
    colHeaderFmt.setPatternBackgroundColor(QColor("#E3F2FD"));
    colHeaderFmt.setBorderStyle(QXlsx::Format::BorderThin);
    colHeaderFmt.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    xlsx.write("A8", QStringLiteral("STT"), colHeaderFmt);
    xlsx.write("B8", QString::fromUtf8("Tên chỉ tiêu"), colHeaderFmt);
    xlsx.write("C8", QString::fromUtf8("Giá trị nhỏ nhất"), colHeaderFmt);
    xlsx.write("D8", QString::fromUtf8("Giá trị đo"), colHeaderFmt);
    xlsx.write("E8", QString::fromUtf8("Giá trị lớn nhất"), colHeaderFmt);
    xlsx.write("F8", QString::fromUtf8("Thời gian đo"), colHeaderFmt);
    xlsx.write("G8", QString::fromUtf8("Kết quả"), colHeaderFmt);

    // === Column widths ===
    xlsx.setColumnWidth(1, 6);   // A: STT
    xlsx.setColumnWidth(2, 45);  // B: Tên chỉ tiêu
    xlsx.setColumnWidth(3, 18);  // C: Giá trị nhỏ nhất
    xlsx.setColumnWidth(4, 18);  // D: Giá trị đo
    xlsx.setColumnWidth(5, 18);  // E: Giá trị lớn nhất
    xlsx.setColumnWidth(6, 16);  // F: Thời gian đo
    xlsx.setColumnWidth(7, 12);  // G: Kết quả

    // === Data rows ===
    QXlsx::Format dataFmt;
    dataFmt.setFontSize(10);
    dataFmt.setBorderStyle(QXlsx::Format::BorderThin);

    QXlsx::Format passFmt;
    passFmt.setFontSize(10);
    passFmt.setFontBold(true);
    passFmt.setFontColor(QColor("#2E7D32"));
    passFmt.setBorderStyle(QXlsx::Format::BorderThin);
    passFmt.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format failFmt;
    failFmt.setFontSize(10);
    failFmt.setFontBold(true);
    failFmt.setFontColor(QColor("#D32F2F"));
    failFmt.setPatternBackgroundColor(QColor("#FFEBEE"));
    failFmt.setBorderStyle(QXlsx::Format::BorderThin);
    failFmt.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    int stt = 0;
    for (int i = 0; i < results.size(); i++) {
        QJsonObject item = results[i].toObject();
        QString scriptType = item.value("scriptType").toString();

        // Skip headers, notifications, system_init, relay, save_result
        if (scriptType.contains("_header") || scriptType == "notification"
            || scriptType == "system_init" || scriptType == "relay"
            || scriptType == "save_result") {
            continue;
        }

        stt++;
        int row = 8 + stt; // row 9, 10, ...

        QString displayText = item.value("displayText").toString();
        QString limitLowerStr = item.value("limitLower").toString();
        QString limitUpperStr = item.value("limitUpper").toString();
        QString measuredValue = item.value("measuredValue").toString();
        QString measureTime = item.value("measureTime").toString();
        QString result = item.value("result").toString();

        xlsx.write(row, 1, stt, dataFmt);           // A: STT
        xlsx.write(row, 2, displayText, dataFmt);    // B: Tên chỉ tiêu
        xlsx.write(row, 3, limitLowerStr, dataFmt);  // C: Giá trị nhỏ nhất
        xlsx.write(row, 4, measuredValue, dataFmt);  // D: Giá trị đo
        xlsx.write(row, 5, limitUpperStr, dataFmt);  // E: Giá trị lớn nhất
        xlsx.write(row, 6, measureTime, dataFmt);    // F: Thời gian đo

        // G: Kết quả với format màu
        if (result.toUpper() == "PASS") {
            xlsx.write(row, 7, "PASS", passFmt);
        } else if (result.toUpper() == "FAIL") {
            xlsx.write(row, 7, "FAIL", failFmt);
        } else {
            xlsx.write(row, 7, result, dataFmt);
        }
    }

    // Đảm bảo thư mục đích tồn tại
    QFileInfo fi(filePath);
    QDir().mkpath(fi.absolutePath());

    bool ok = xlsx.saveAs(filePath);
    if (ok) {
        qDebug() << "[ExportExcel] Saved:" << filePath << "with" << stt << "rows";
    } else {
        qWarning() << "[ExportExcel] FAILED to save:" << filePath;
    }
    return ok;
#endif
}

bool FileHelper::fileExists(const QString &filePath) const
{
    return QFile::exists(filePath);
}

void FileHelper::appendLogRealtime(const QString &category, const QString &action)
{


    
    // get the base path
    QString appDir = QCoreApplication::applicationDirPath();
    QString savePath = appDir + "/results";
    // Check station_config.json
    QString configPath = appDir + "/station_config.json";    // duong dan den file config station_config.json 
    if (QFile::exists(configPath)) {                         // Kiem tra xem file station_config.json co ton tai khong     
    QString jsonStr = readTextFile(configPath).trimmed();


        QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());     // bien doc de luu du lieu json 
        QJsonObject obj = doc.object();
        if (obj.contains("logPath")) {    // kiem tra xem co chua duong dan logPath ko 
            QString userPath = obj.value("logPath").toString();  //
            if (!userPath.isEmpty()) savePath = userPath;  // 
        }
    }
    
    // Ensure the folder exists
    QDir().mkpath(savePath);
    
    // Create/Append to a daily log file
    QString dateStr = QDateTime::currentDateTime().toString("yyyyMMdd");    // 
    QString logFile = savePath + "/system_runtime_" + dateStr + ".log";
    
    QFile file(logFile);
    if (file.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&file);
        out.setEncoding(QStringConverter::Utf8);
        
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    out << "[" << timestamp << "] [" << category << "] " << action << "\n";
    file.close();
    qDebug() << "[FileHelper] Reatime log saved to:" << logFile << "|" << category << "|" << action;
} else {
    qWarning() << "[FileHelper] ERROR opening realtime log:" << logFile;
}
}










