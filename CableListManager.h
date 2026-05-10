#ifndef CABLELISTMANAGER_H
#define CABLELISTMANAGER_H

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QString>

class CableListManager : public QObject
{
    Q_OBJECT
public:
    explicit CableListManager(QObject *parent = nullptr);

    // Danh sách cáp: mỗi item là tên hiển thị (tên file không đường dẫn)
    Q_INVOKABLE QStringList cableNames() const;
    Q_INVOKABLE QString cablePath(int index) const;
    Q_INVOKABLE int cableCount() const;

    // Thêm file Excel/CSV (đường dẫn đầy đủ)
    Q_INVOKABLE bool addCableFile(const QString &filePath);

    // Xóa cáp tại index
    Q_INVOKABLE void removeCableFile(int index);

    // Lưu/Load danh sách cáp (persist)
    Q_INVOKABLE void saveCableList();
    Q_INVOKABLE void loadCableList();

    // Đọc dữ liệu bảng từ file (8 cột). Trả về danh sách dòng, mỗi dòng là mảng 8 chuỗi [cột0..cột7].
    Q_INVOKABLE QVariantList loadTableData(const QString &filePath);

signals:
    void cableListChanged();

private:
    QStringList m_paths;
    QStringList m_names;

    static QString baseNameFromPath(const QString &path);
    QVariantList parseCsvFile(const QString &filePath);
    QVariantList parseXlsxFile(const QString &filePath);
    QString cableListFilePath() const;
};

#endif // CABLELISTMANAGER_H
