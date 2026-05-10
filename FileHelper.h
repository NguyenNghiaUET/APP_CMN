#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>
#include <QString>

class FileHelper : public QObject
{
    Q_OBJECT

public:
    explicit FileHelper(QObject *parent = nullptr);

    Q_INVOKABLE bool writeTextFile(const QString &filePath, const QString &content);
    Q_INVOKABLE QString readTextFile(const QString &filePath) const;
    Q_INVOKABLE QString applicationDirPath() const; // Lấy đường dẫn folder chứa exe
    Q_INVOKABLE bool saveCalibrationMode(const QString &mode); // Lưu mode hiệu chuẩn đã chọn
    Q_INVOKABLE QString loadCalibrationMode() const; // Đọc mode hiệu chuẩn đã chọn

    // Lưu/Load Station Parameter
    Q_INVOKABLE bool saveStationConfig(const QString &jsonStr);
    Q_INVOKABLE QString loadStationConfig() const;

    // Xuất kết quả đo ra Excel (.xlsx)
    Q_INVOKABLE bool exportExcel(const QString &filePath,
                                  const QString &stationInfoJson,
                                  const QString &testResultsJson);

    // Lấy hostname máy tính
    Q_INVOKABLE QString computerName() const;

    // Kiểm tra file có tồn tại không
    Q_INVOKABLE bool fileExists(const QString &filePath) const;

    // Ghi log tới txt file runtime realtime
    Q_INVOKABLE void appendLogRealtime(const QString &category, const QString &action);
};

#endif // FILEHELPER_H
