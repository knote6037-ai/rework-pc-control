#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QProcess>
#include <QTimer>
#include <QVariantList>

// Read-only hardware monitoring. No fan, voltage or power controls are exposed.
class HardwareTelemetry final : public QObject {
    Q_OBJECT
    Q_PROPERTY(double cpuTemperature READ cpuTemperature NOTIFY readingsChanged)
    Q_PROPERTY(double gpuTemperature READ gpuTemperature NOTIFY readingsChanged)
    Q_PROPERTY(double cpuLoad READ cpuLoad NOTIFY readingsChanged)
    Q_PROPERTY(double gpuLoad READ gpuLoad NOTIFY readingsChanged)
    Q_PROPERTY(QString cpuName READ cpuName NOTIFY readingsChanged)
    Q_PROPERTY(QString gpuName READ gpuName NOTIFY readingsChanged)
    Q_PROPERTY(QString cpuStatus READ cpuStatus NOTIFY readingsChanged)
    Q_PROPERTY(QString gpuStatus READ gpuStatus NOTIFY readingsChanged)
    Q_PROPERTY(QString updatedAt READ updatedAt NOTIFY readingsChanged)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY readingsChanged)
    Q_PROPERTY(QVariantList gpuHistory READ gpuHistory NOTIFY readingsChanged)
public:
    explicit HardwareTelemetry(QObject* parent = nullptr);
    ~HardwareTelemetry() override;
    double cpuTemperature() const { return cpuTemperature_; }
    double gpuTemperature() const { return gpuTemperature_; }
    double cpuLoad() const { return cpuLoad_; }
    double gpuLoad() const { return gpuLoad_; }
    QString cpuName() const { return cpuName_; }
    QString gpuName() const { return gpuName_; }
    QString cpuStatus() const { return cpuStatus_; }
    QString gpuStatus() const { return gpuStatus_; }
    QString updatedAt() const { return updatedAt_; }
    QVariantList cpuHistory() const { return cpuHistory_; }
    QVariantList gpuHistory() const { return gpuHistory_; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void connectCpuSensors();
signals:
    void readingsChanged();
private:
    void readCpuSnapshot();
    bool retainRecentCpuReading();
    void updateCpuLoad();
    void readGpuResult(int exitCode, QProcess::ExitStatus exitStatus);
    void gpuUnavailable(const QString& status);
    static bool validTemperature(double value);
    static void appendHistory(QVariantList& history, double value);
    bool pawnIoInstalled() const;
    QString sensorDirectory() const;
    QString snapshotPath() const;
    QTimer pollTimer_;
    QTimer gpuTimeout_;
    QProcess gpuProcess_;
    QString smiPath_;
    QString cpuName_;
    QString gpuName_ = QStringLiteral("Видеокарта");
    QString cpuStatus_ = QStringLiteral("Подключите датчик CPU");
    QString gpuStatus_ = QStringLiteral("Чтение датчика…");
    QString updatedAt_;
    double cpuTemperature_ = -1;
    double gpuTemperature_ = -1;
    double cpuLoad_ = -1;
    double gpuLoad_ = -1;
    QVariantList cpuHistory_;
    QVariantList gpuHistory_;
    QElapsedTimer cpuReadingAge_;
    qint64 lastCpuTimestamp_ = 0;
    double lastCpuTemperature_ = -1;
    QString lastCpuStatus_;
    quint64 lastIdle_ = 0;
    quint64 lastKernel_ = 0;
    quint64 lastUser_ = 0;
};
