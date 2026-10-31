#pragma once

#include <QObject>
#include <QTimer>
#include <QString>
#include <future>

// A deliberately narrow launcher. QML can select three installed assistants;
// it cannot supply an executable, URL, command line, or activation arguments.
class AssistantLauncher final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool chatGptAvailable READ chatGptAvailable NOTIFY stateChanged)
    Q_PROPERTY(bool claudeAvailable READ claudeAvailable NOTIFY stateChanged)
    Q_PROPERTY(bool deepSeekAvailable READ deepSeekAvailable NOTIFY stateChanged)
    Q_PROPERTY(QString message READ message NOTIFY stateChanged)
public:
    explicit AssistantLauncher(QObject* parent = nullptr);
    ~AssistantLauncher() override;
    bool chatGptAvailable() const { return chatGptAvailable_; }
    bool claudeAvailable() const { return claudeAvailable_; }
    bool deepSeekAvailable() const { return deepSeekAvailable_; }
    QString message() const { return message_; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launch(const QString& id);
signals:
    void stateChanged();
private:
    void finishLaunch();
    bool chatGptAvailable_ = false;
    bool claudeAvailable_ = false;
    bool deepSeekAvailable_ = false;
    QString deepSeekPath_;
    QString message_;
    QString launchingName_;
    QTimer finishTimer_;
    std::future<quint32> pendingLaunch_;
};
