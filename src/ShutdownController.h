#pragma once
#include "ControlModel.h"
#include <QObject>
#include <QElapsedTimer>
#include <QTimer>
#include <QSettings>
#include <QSystemTrayIcon>
#include <QAbstractNativeEventFilter>
#include <QQuickWindow>
#include <memory>

class AppClock final : public Rework::Clock {
public:
    AppClock() { elapsed.start(); }
    qint64 monotonicMs() const override { return elapsed.elapsed(); }
    qint64 utcMs() const override;
private:
    QElapsedTimer elapsed;
};

class ShutdownController final : public QObject, public QAbstractNativeEventFilter {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY stateChanged)
    Q_PROPERTY(QString previousMode READ previousMode NOTIFY stateChanged)
    Q_PROPERTY(int minutes READ minutes NOTIFY stateChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY stateChanged)
    Q_PROPERTY(int totalSeconds READ totalSeconds NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(qint64 deadlineMs READ deadlineMs NOTIFY stateChanged)
    Q_PROPERTY(bool demo READ demo CONSTANT)
    Q_PROPERTY(QString message READ message NOTIFY stateChanged)
    Q_PROPERTY(QString machineName READ machineName CONSTANT)
    Q_PROPERTY(QString timeString READ timeString NOTIFY stateChanged)
    Q_PROPERTY(QString dateString READ dateString NOTIFY stateChanged)
    Q_PROPERTY(qint64 nowMs READ nowMs NOTIFY stateChanged)
public:
    explicit ShutdownController(bool demo, QObject* parent = nullptr);
    ~ShutdownController() override;
    void setWindow(QQuickWindow* window);
    void showWindow();
    bool nativeEventFilter(const QByteArray&, void*, qintptr*) override;
    QString mode() const { return model.mode(); }
    QString previousMode() const { return model.previousMode(); }
    int minutes() const { return model.minutes(); }
    int remainingSeconds() const { return model.remainingSeconds(); }
    int totalSeconds() const { return model.totalSeconds(); }
    double progress() const { return model.progress(); }
    qint64 deadlineMs() const { return model.deadlineMs(); }
    bool demo() const { return model.demo(); }
    QString message() const { return model.message(); }
    QString machineName() const;
    QString timeString() const;
    QString dateString() const;
    qint64 nowMs() const;
    Q_INVOKABLE void prepare(int minutes);
    Q_INVOKABLE void confirm();
    Q_INVOKABLE void dismiss();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void setDuration(int minutes);
    Q_INVOKABLE void hideWindow();
    Q_INVOKABLE void quitApp();
signals:
    void stateChanged();
    void started(int secondsLeft);
    void cancelled();
    void finished();
private:
    void tick();
    void saveState();
    void restoreState();
    void updateTray();
    void mutate(const std::function<void()>& action);
    void cancelForSleep();
    AppClock clock;
    Rework::ControlModel model;
    std::unique_ptr<QSettings> settings;
    QQuickWindow* window = nullptr;
    QTimer timer;
    QSystemTrayIcon tray;
    QString bootId;
    bool hidingTipShown = false;
    bool warned = false;
    bool quitRequested = false;
    bool sleeping = false;
    int lastEmittedRemaining_ = -1;
    qint64 lastEmittedClockSecond_ = -1;
};
