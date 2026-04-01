#ifndef RUNNER_APP_SHARE_TEXT_CHANNEL_H_
#define RUNNER_APP_SHARE_TEXT_CHANNEL_H_

#include <Windows.h>
#include <ShObjIdl.h>
#include <roapi.h>
#include <windows.applicationmodel.datatransfer.h>
#include <windows.foundation.h>
#include <wrl.h>
#include <wrl/client.h>
#include <wrl/event.h>
#include <wrl/wrappers/corewrappers.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

#pragma comment(lib, "runtimeobject.lib")

namespace WRL = Microsoft::WRL;
namespace WindowsFoundation = ABI::Windows::Foundation;
namespace DataTransfer = ABI::Windows::ApplicationModel::DataTransfer;

class AppShareTextChannel {
 public:
  AppShareTextChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~AppShareTextChannel();

  AppShareTextChannel(const AppShareTextChannel&) = delete;
  AppShareTextChannel& operator=(const AppShareTextChannel&) = delete;

 private:
  static constexpr auto kChannelName = "costanorte/share_text";
  static constexpr auto kShareTextMethod = "shareText";

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  WRL::ComPtr<DataTransfer::IDataTransferManager> GetDataTransferManager();
  void RemoveDataRequestedHandler();
  static std::wstring Utf16FromUtf8(const std::string& value);
  static std::string GetStringArgument(const flutter::EncodableMap& arguments,
                                       const char* key);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  WRL::ComPtr<IDataTransferManagerInterop> data_transfer_manager_interop_;
  WRL::ComPtr<DataTransfer::IDataTransferManager> data_transfer_manager_;
  EventRegistrationToken data_transfer_manager_token_{};
  bool has_data_requested_handler_ = false;
};

#endif  // RUNNER_APP_SHARE_TEXT_CHANNEL_H_
