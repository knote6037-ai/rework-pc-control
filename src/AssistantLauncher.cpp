#include "AssistantLauncher.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <windows.h>
#include <objbase.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <chrono>
#include <string>

namespace {
constexpr wchar_t ChatGptFamily[] = L"OpenAI.Codex_2p2nqsd0c76g0";
constexpr wchar_t ChatGptApplication[] = L"OpenAI.Codex_2p2nqsd0c76g0!App";
constexpr wchar_t ClaudeFamily[] = L"Claude_pzs8sxrjxfjjc";
constexpr wchar_t ClaudeApplication[] = L"Claude_pzs8sxrjxfjjc!Claude";

bool packageInstalled(const wchar_t* family) {
    // This query only describes packages registered to the current user. It
    // does not activate an app and is unaffected by Store version updates.
    using Query = LONG(WINAPI*)(PCWSTR, UINT32*, PWSTR*, UINT32*, WCHAR*);
    const auto query = reinterpret_cast<Query>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "GetPackagesByPackageFamily"));
    if (!query) return false;
    UINT32 count = 0, bufferLength = 0;
    const LONG status = query(family, &count, nullptr, &bufferLength, nullptr);
    return count > 0 && (status == ERROR_SUCCESS || status == ERROR_INSUFFICIENT_BUFFER);
}

class ComApartment final {
public:
    ComApartment() : status_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
    ~ComApartment() { if (SUCCEEDED(status_)) CoUninitialize(); }
    HRESULT status() const { return status_; }
private:
    HRESULT status_;
};

quint32 activatePackaged(const wchar_t* appId) {
    ComApartment apartment;
    if (FAILED(apartment.status())) return static_cast<quint32>(apartment.status());
    IApplicationActivationManager* manager = nullptr;
    HRESULT status = CoCreateInstance(CLSID_ApplicationActivationManager, nullptr, CLSCTX_LOCAL_SERVER,
        IID_IApplicationActivationManager, reinterpret_cast<void**>(&manager));
    if (FAILED(status)) return static_cast<quint32>(status);
    // A click normally grants foreground privilege. Failure to pass it to the
    // server must not prevent activation; Windows may simply flash the app.
    CoAllowSetForegroundWindow(manager, nullptr);
    DWORD processId = 0;
    status = manager->ActivateApplication(appId, nullptr, AO_NONE, &processId);
    manager->Release();
    return SUCCEEDED(status) ? 0 : static_cast<quint32>(status);
}

quint32 activateDesktop(const QString& path) {
    if (!QFileInfo(path).isFile()) return ERROR_FILE_NOT_FOUND;
    ComApartment apartment;
    if (FAILED(apartment.status())) return static_cast<quint32>(apartment.status());
    const std::wstring file = QDir::toNativeSeparators(path).toStdWString();
    const std::wstring directory = QDir::toNativeSeparators(QFileInfo(path).absolutePath()).toStdWString();
    SHELLEXECUTEINFOW execution{};
    execution.cbSize = sizeof(execution);
    execution.fMask = SEE_MASK_NOASYNC | SEE_MASK_FLAG_NO_UI;
    execution.lpVerb = L"open";
    execution.lpFile = file.c_str();
    execution.lpDirectory = directory.c_str();
    execution.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&execution)) return GetLastError();
    return 0;
}
}

AssistantLauncher::AssistantLauncher(QObject* parent) : QObject(parent) {
    finishTimer_.setInterval(80);
    connect(&finishTimer_, &QTimer::timeout, this, &AssistantLauncher::finishLaunch);
    refresh();
}

AssistantLauncher::~AssistantLauncher() {
    // The worker never captures this object or any UI state. Waiting here is
    // only relevant if the user quits during a Windows activation request.
    finishTimer_.stop();
    if (pendingLaunch_.valid()) pendingLaunch_.wait();
}

void AssistantLauncher::refresh() {
    chatGptAvailable_ = packageInstalled(ChatGptFamily);
    claudeAvailable_ = packageInstalled(ClaudeFamily);
    QString local = qEnvironmentVariable("LOCALAPPDATA");
    if (local.isEmpty()) local = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    deepSeekPath_ = QDir(local).filePath("Programs/DeepSeek Harness/DeepSeek Harness.exe");
    deepSeekAvailable_ = QFileInfo(deepSeekPath_).isFile();
    emit stateChanged();
}

void AssistantLauncher::launch(const QString& id) {
    if (pendingLaunch_.valid()) return;
    refresh();
    const wchar_t* packaged = nullptr;
    QString desktop;
    bool available = false;
    if (id == "chatgpt") { packaged = ChatGptApplication; launchingName_ = "Codex"; available = chatGptAvailable_; }
    else if (id == "claude") { packaged = ClaudeApplication; launchingName_ = "Claude"; available = claudeAvailable_; }
    else if (id == "deepseek") { desktop = deepSeekPath_; launchingName_ = "DeepSeek Harness"; available = deepSeekAvailable_; }
    else {
        message_ = QStringLiteral("Неизвестное приложение.");
        emit stateChanged();
        return;
    }
    if (!available) {
        message_ = QStringLiteral("%1 не установлен на этом компьютере.").arg(launchingName_);
        emit stateChanged();
        return;
    }
    message_ = QStringLiteral("Открываю %1…").arg(launchingName_);
    emit stateChanged();
    try {
        pendingLaunch_ = std::async(std::launch::async, [packaged, desktop] {
            return packaged ? activatePackaged(packaged) : activateDesktop(desktop);
        });
        finishTimer_.start();
    } catch (...) {
        message_ = QStringLiteral("Не удалось запустить %1. Попробуйте ещё раз.").arg(launchingName_);
        emit stateChanged();
    }
}

void AssistantLauncher::finishLaunch() {
    if (!pendingLaunch_.valid() || pendingLaunch_.wait_for(std::chrono::milliseconds(0)) != std::future_status::ready) return;
    finishTimer_.stop();
    quint32 error = ERROR_GEN_FAILURE;
    try { error = pendingLaunch_.get(); } catch (...) { }
    message_ = error == 0 ? QStringLiteral("%1 открыт.").arg(launchingName_)
        : QStringLiteral("Не удалось открыть %1. Код Windows: 0x%2.").arg(launchingName_).arg(error, 8, 16, QLatin1Char('0'));
    emit stateChanged();
}
