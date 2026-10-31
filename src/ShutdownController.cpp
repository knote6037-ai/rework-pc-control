#include "ShutdownController.h"
#include <QApplication>
#include <QDateTime>
#include <QDir>
#include <QHostInfo>
#include <QLocale>
#include <QMenu>
#include <QStandardPaths>
#include <QWindow>
#include <QDebug>
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <stdexcept>
#include <system_error>

namespace {
QString currentBootId() {
    // Read-only boot identifier. If unavailable, restoring a saved timer is disabled.
    struct BootInformation { GUID id; ULONG firmware; ULONGLONG flags; } info{};
    using Query = LONG(WINAPI*)(ULONG, PVOID, ULONG, PULONG);
    auto query = reinterpret_cast<Query>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQuerySystemInformation"));
    if (!query || query(90, &info, sizeof(info), nullptr) != 0) return {};
    return QString::fromLatin1(QByteArray(reinterpret_cast<const char*>(&info.id), sizeof(GUID)).toHex());
}

void requestWindowsShutdown() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token))
        throw std::system_error(GetLastError(), std::system_category());
    TOKEN_PRIVILEGES desired{}, previous{};
    DWORD length = sizeof(previous);
    bool adjusted = false;
    try {
        desired.PrivilegeCount = 1;
        desired.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        if (!LookupPrivilegeValueW(nullptr, L"SeShutdownPrivilege", &desired.Privileges[0].Luid))
            throw std::system_error(GetLastError(), std::system_category());
        SetLastError(ERROR_SUCCESS);
        if (!AdjustTokenPrivileges(token, FALSE, &desired, sizeof(previous), &previous, &length))
            throw std::system_error(GetLastError(), std::system_category());
        if (GetLastError() != ERROR_SUCCESS)
            throw std::system_error(GetLastError(), std::system_category());
        adjusted = true;
        // No FORCE or FORCEIFHUNG flags: Windows may protect unsaved documents.
        if (!ExitWindowsEx(EWX_POWEROFF, SHTDN_REASON_FLAG_PLANNED | SHTDN_REASON_MAJOR_OTHER))
            throw std::system_error(GetLastError(), std::system_category());
    } catch (...) {
        if (adjusted) AdjustTokenPrivileges(token, FALSE, &previous, 0, nullptr, nullptr);
        CloseHandle(token);
        throw;
    }
    if (adjusted) AdjustTokenPrivileges(token, FALSE, &previous, 0, nullptr, nullptr);
    CloseHandle(token);
}
}

qint64 AppClock::utcMs() const { return QDateTime::currentMSecsSinceEpoch(); }

ShutdownController::ShutdownController(bool demo, QObject* parent)
    : QObject(parent), model(clock, demo ? Rework::Shutdown([] {}) : Rework::Shutdown(requestWindowsShutdown), demo) {
    QString dataFolder = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
        + (demo ? "/Demo" : "/App");
    QDir().mkpath(dataFolder);
    settings = std::make_unique<QSettings>(dataFolder + "/settings.ini", QSettings::IniFormat);
    bootId = currentBootId();
    qInfo() << "Windows boot identifier available:" << !bootId.isEmpty();
    restoreState();
    tray.setIcon(QIcon(":/rework.ico"));
    QMenu* menu = new QMenu();
    menu->addAction(QStringLiteral("Открыть Rework PC Control"), this, &ShutdownController::showWindow);
    menu->addAction(QStringLiteral("Отменить выключение"), this, &ShutdownController::cancel);
    menu->addSeparator();
    menu->addAction(QStringLiteral("Выйти и отменить таймер"), this, &ShutdownController::quitApp);
    tray.setContextMenu(menu);
    connect(&tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::DoubleClick || reason == QSystemTrayIcon::Trigger) showWindow();
    });
    connect(&tray, &QSystemTrayIcon::messageClicked, this, &ShutdownController::showWindow);
    tray.show();
    timer.setInterval(100);
    timer.setTimerType(Qt::PreciseTimer);
    connect(&timer, &QTimer::timeout, this, &ShutdownController::tick);
    timer.start();
    qApp->installNativeEventFilter(this);
    updateTray();
}

ShutdownController::~ShutdownController() {
    qApp->removeNativeEventFilter(this);
    tray.hide();
    delete tray.contextMenu();
}

void ShutdownController::setWindow(QQuickWindow* value) {
    window = value;
    HWND hwnd = reinterpret_cast<HWND>(window->winId());
    BOOL dark = TRUE;
    DwmSetWindowAttribute(hwnd, 20, &dark, sizeof(dark));
    int corners = 2; // DWMWCP_ROUND, Windows 11. Older Windows ignore unsupported attributes.
    DwmSetWindowAttribute(hwnd, 33, &corners, sizeof(corners));
    int acrylic = 3; // DWMSBT_TRANSIENTWINDOW / desktop Acrylic.
    HRESULT backdrop = DwmSetWindowAttribute(hwnd, 38, &acrylic, sizeof(acrylic));
    MARGINS margins = {-1, -1, -1, -1};
    DwmExtendFrameIntoClientArea(hwnd, &margins);
    COLORREF border = RGB(78, 80, 84);
    DwmSetWindowAttribute(hwnd, 34, &border, sizeof(border));
    qInfo() << "DWM desktop Acrylic:" << SUCCEEDED(backdrop);
    // Keep native resize/maximize semantics for a frameless Qt Quick window.
    LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    SetWindowLongPtrW(hwnd, GWL_STYLE, style | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
}

QString ShutdownController::machineName() const { return QHostInfo::localHostName(); }
QString ShutdownController::timeString() const { return QTime::currentTime().toString("HH:mm"); }
QString ShutdownController::dateString() const {
    return QLocale(QLocale::Russian).toString(QDate::currentDate(), QStringLiteral("dddd, d MMMM"));
}
qint64 ShutdownController::nowMs() const { return clock.utcMs(); }

void ShutdownController::mutate(const std::function<void()>& action) {
    try { action(); }
    catch (const std::exception& error) { model.setMessage(QString::fromUtf8(error.what())); }
    saveState();
    updateTray();
    emit stateChanged();
}
void ShutdownController::prepare(int minutes) { mutate([&] { model.prepare(minutes); }); }
void ShutdownController::confirm() {
    mutate([&] {
        model.confirm();
        if (model.mode() == "closed") { warned = false; emit started(model.remainingSeconds()); }
    });
}
void ShutdownController::dismiss() { mutate([&] { model.dismiss(); }); }
void ShutdownController::cancel() {
    const bool wasActive = model.totalSeconds() > 0 || model.mode() == "pending";
    mutate([&] { model.cancel(); warned = false; });
    if (wasActive && model.mode() == "open") emit cancelled();
}
void ShutdownController::setDuration(int minutes) { mutate([&] { model.setDuration(minutes); }); }

void ShutdownController::tick() {
    if (sleeping) return;
    const QString oldMode = model.mode();
    const int oldTotal = model.totalSeconds();
    model.tick();
    if (oldTotal > 0 && model.totalSeconds() == 0) { saveState(); emit finished(); }
    if (remainingSeconds() > 0 && remainingSeconds() <= 60 && !warned) {
        warned = true;
        tray.showMessage(QStringLiteral("Rework · Осталась минута"), QStringLiteral("Сохраните работу. Отменить выключение можно в окне или меню значка Rework."), QSystemTrayIcon::Warning, 10000);
    }
    updateTray();
    // The 100 ms poll keeps the countdown exact, but the window is repainted only
    // when something visible actually changed: a new clock second, a new countdown
    // value, or a mode transition. Idle ticks cost nothing.
    const int nowRemaining = remainingSeconds();
    const qint64 clockSecond = QTime::currentTime().msecsSinceStartOfDay() / 1000;
    const bool modeChanged = oldMode != model.mode();
    const bool remainingChanged = nowRemaining != lastEmittedRemaining_;
    const bool clockChanged = clockSecond != lastEmittedClockSecond_;
    if (!modeChanged && !remainingChanged && !clockChanged) return;
    lastEmittedRemaining_ = nowRemaining;
    lastEmittedClockSecond_ = clockSecond;
    emit stateChanged();
}

void ShutdownController::saveState() {
    settings->setValue("minutes", minutes());
    const bool active = model.totalSeconds() > 0 && model.deadlineMs() > clock.utcMs();
    settings->setValue("countdown/active", active);
    if (active) {
        settings->setValue("countdown/deadline", model.deadlineMs());
        // Boot-scoped elapsed time is authoritative even if the Windows clock changes
        // while this application is stopped. UTC above is for human-readable display.
        settings->setValue("countdown/uptimeDeadline", static_cast<qulonglong>(GetTickCount64())
            + static_cast<qulonglong>(model.remainingMilliseconds()));
        settings->setValue("countdown/totalSeconds", model.totalSeconds());
        settings->setValue("countdown/bootId", bootId);
    } else {
        settings->remove("countdown/deadline");
        settings->remove("countdown/uptimeDeadline");
        settings->remove("countdown/totalSeconds");
        settings->remove("countdown/bootId");
    }
    settings->sync();
}

void ShutdownController::restoreState() {
    const int preferred = settings->value("minutes", 10).toInt();
    try { model.setDuration(preferred); } catch (...) { model.setDuration(10); }
    if (!settings->value("countdown/active", false).toBool()) return;
    if (bootId.isEmpty() || settings->value("countdown/bootId").toString() != bootId) {
        model.setMessage(QStringLiteral("Прошлый таймер отменён после перезапуска Windows."));
        saveState();
        return;
    }
    try {
        const quint64 savedDue = settings->value("countdown/uptimeDeadline").toULongLong();
        const quint64 uptime = GetTickCount64();
        if (savedDue <= uptime || savedDue - uptime > 10800000)
            throw std::invalid_argument("Invalid or expired saved timer");
        model.restoreCountdown(clock.utcMs() + static_cast<qint64>(savedDue - uptime), settings->value("countdown/totalSeconds").toInt());
        model.setMessage(QStringLiteral("Подтверждённый таймер восстановлен. Его можно отменить."));
    } catch (...) {
        model.cancel();
        model.setMessage(QStringLiteral("Срок прошлого таймера истёк или данные повреждены. Компьютер остаётся включён."));
        saveState();
    }
}

void ShutdownController::updateTray() {
    QString text = QStringLiteral("Rework · Открыто");
    if (remainingSeconds() > 0) text = QStringLiteral("Rework · Выключение через %1:%2")
        .arg(remainingSeconds() / 60, 2, 10, QLatin1Char('0')).arg(remainingSeconds() % 60, 2, 10, QLatin1Char('0'));
    if (mode() == "shuttingDown") text = QStringLiteral("Rework · Запрос передан Windows");
    if (demo()) text += QStringLiteral(" · Демо");
    if (tray.toolTip() != text) tray.setToolTip(text);
}

void ShutdownController::showWindow() {
    if (!window) return;
    if (window->visibility() == QWindow::Minimized || window->visibility() == QWindow::Hidden) window->showNormal();
    else window->show();
    window->raise();
    window->requestActivate();
}
void ShutdownController::hideWindow() {
    if (!window) return;
    if (!QSystemTrayIcon::isSystemTrayAvailable()) { window->showMinimized(); return; }
    window->hide();
    if (!hidingTipShown) {
        hidingTipShown = true;
        tray.showMessage(QStringLiteral("Rework остаётся в трее"), QStringLiteral("Таймер продолжает работать. Нажмите значок, чтобы открыть окно; правая кнопка — отмена и выход."), QSystemTrayIcon::Information, 6000);
    }
}
void ShutdownController::quitApp() {
    quitRequested = true;
    cancel();
    tray.hide();
    QCoreApplication::quit();
}
void ShutdownController::cancelForSleep() {
    sleeping = true;
    mutate([&] { model.cancelForSleep(); warned = false; });
    emit cancelled();
}

bool ShutdownController::nativeEventFilter(const QByteArray&, void* message, qintptr* result) {
    MSG* msg = static_cast<MSG*>(message);
    if (msg->message == WM_POWERBROADCAST) {
        if (msg->wParam == PBT_APMSUSPEND) cancelForSleep();
        if (msg->wParam == PBT_APMRESUMEAUTOMATIC || msg->wParam == PBT_APMRESUMESUSPEND) {
            cancelForSleep();
            sleeping = false;
        }
    }
    if (msg->message == WM_ENDSESSION && msg->wParam == FALSE) {
        model.shutdownWasCancelled();
        sleeping = false;
        saveState();
        emit stateChanged();
    }
    if (!window || msg->hwnd != reinterpret_cast<HWND>(window->winId())) return false;
    if (msg->message == WM_NCCALCSIZE && msg->wParam != FALSE) { *result = 0; return true; }
    if (msg->message == WM_NCHITTEST && window->visibility() != QWindow::Maximized) {
        RECT rect;
        GetWindowRect(msg->hwnd, &rect);
        const int x = GET_X_LPARAM(msg->lParam), y = GET_Y_LPARAM(msg->lParam);
        const int edge = qMax(6, qRound(7 * window->devicePixelRatio()));
        bool left = x < rect.left + edge, right = x >= rect.right - edge;
        bool top = y < rect.top + edge, bottom = y >= rect.bottom - edge;
        if (left || right || top || bottom) {
            *result = top ? (left ? HTTOPLEFT : right ? HTTOPRIGHT : HTTOP)
                : bottom ? (left ? HTBOTTOMLEFT : right ? HTBOTTOMRIGHT : HTBOTTOM)
                : left ? HTLEFT : HTRIGHT;
            return true;
        }
    }
    return false;
}
