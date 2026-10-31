#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>
#include <QJsonObject>
class AstraLimits final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rows READ rows NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString plan READ plan NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool stale READ stale NOTIFY changed)
public:
    explicit AstraLimits(QObject* parent = nullptr);
    ~AstraLimits() override;
    QVariantList rows() const { return rows_; }
    QString status() const { return status_; }
    QString plan() const { return plan_; }
    bool busy() const { return busy_; }
    bool stale() const { return stale_; }
    Q_INVOKABLE void refresh();
    static QVariantList parseRows(const QJsonObject& result);
signals:
    void changed();
private:
    void receive();
    void fail(const QString& error);
    void stop();
    void send(const QJsonObject& message);
    QProcess process_;
    QTimer periodic_, timeout_;
    QByteArray buffer_;
    QVariantList rows_;
    QString status_ = QStringLiteral("Подключаем Codex…"), plan_;
    bool busy_ = false, stale_ = true;
};
