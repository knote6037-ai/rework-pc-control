#include "ShutdownController.h"
#include "HardwareTelemetry.h"
#include "AssistantLauncher.h"
#include "AstraLimits.h"
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QLocalServer>
#include <QLocalSocket>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <QMessageBox>
#include <QStandardPaths>
#include <QTextStream>
#include <windows.h>

static QFile logFile;
static void logMessage(QtMsgType type, const QMessageLogContext&, const QString& text) {
    if (!logFile.isOpen()) return;
    QTextStream stream(&logFile);
    stream << QDateTime::currentDateTime().toString(Qt::ISODateWithMs) << " [" << type << "] " << text << '\n';
    stream.flush();
}

int main(int argc, char* argv[]) {
    QQuickWindow::setDefaultAlphaBuffer(true);
    QApplication app(argc, argv);
    app.setOrganizationName("Rework");
    app.setApplicationName("ReworkPCControl");
    app.setApplicationDisplayName("Rework PC Control");
    app.setApplicationVersion("4.0.0");
    app.setWindowIcon(QIcon(":/rework.ico"));
    app.setQuitOnLastWindowClosed(false);
    bool demo = app.arguments().contains("--demo");
    QString data = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(data);
    logFile.setFileName(data + (demo ? "/demo.log" : "/app.log"));
    if (logFile.size() > 1024 * 1024) logFile.remove();
    if (logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) qInstallMessageHandler(logMessage);

    DWORD session = 0;
    ProcessIdToSessionId(GetCurrentProcessId(), &session);
    QString serverName = QStringLiteral("ReworkPCControl.Qt.%1.%2").arg(session).arg(demo ? "Demo" : "Main");
    QLocalSocket existing;
    existing.connectToServer(serverName);
    if (existing.waitForConnected(300)) {
        existing.write("activate");
        existing.flush();
        existing.waitForBytesWritten(500);
        return 0;
    }
    QLocalServer server;
    server.setSocketOptions(QLocalServer::UserAccessOption);
    if (!server.listen(serverName)) {
        QMessageBox::warning(nullptr, QStringLiteral("Rework PC Control"), QStringLiteral("Приложение уже запущено или не удалось создать канал активации."));
        return 1;
    }
    ShutdownController control(demo);
    HardwareTelemetry telemetry;
    AssistantLauncher launcher;
    AstraLimits astra;
    QObject::connect(&server, &QLocalServer::newConnection, &app, [&] {
        while (server.hasPendingConnections()) {
            QLocalSocket* socket = server.nextPendingConnection();
            control.showWindow();
            socket->disconnectFromServer();
            socket->deleteLater();
        }
    });
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("control", &control);
    engine.rootContext()->setContextProperty("telemetry", &telemetry);
    engine.rootContext()->setContextProperty("launcher", &launcher);
    engine.rootContext()->setContextProperty("astra", &astra);
    engine.loadFromModule("Rework", "Main");
    if (engine.rootObjects().isEmpty()) {
        QMessageBox::critical(nullptr, "Rework PC Control", QStringLiteral("Не удалось загрузить интерфейс. Подробности в журнале:\n") + logFile.fileName());
        return 1;
    }
    auto window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (!window) return 1;
    control.setWindow(window);
    return app.exec();
}
