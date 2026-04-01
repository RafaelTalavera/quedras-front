#include "app_share_text_channel.h"

#include <flutter/encodable_value.h>

AppShareTextChannel::AppShareTextChannel(flutter::BinaryMessenger* messenger,
                                         HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

AppShareTextChannel::~AppShareTextChannel() { RemoveDataRequestedHandler(); }

void AppShareTextChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != kShareTextMethod) {
    result->NotImplemented();
    return;
  }

  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    result->Error("invalid_args", "Expected share arguments.");
    return;
  }

  const std::string text = GetStringArgument(*arguments, "text");
  const std::string subject = GetStringArgument(*arguments, "subject");
  const std::string title = GetStringArgument(*arguments, "title");

  if (text.empty()) {
    result->Error("invalid_args", "Text cannot be empty.");
    return;
  }

  auto data_transfer_manager = GetDataTransferManager();
  if (data_transfer_manager == nullptr || data_transfer_manager_interop_ == nullptr) {
    result->Error("share_unavailable", "Windows share UI is unavailable.");
    return;
  }

  RemoveDataRequestedHandler();

  const auto callback = WRL::Callback<WindowsFoundation::ITypedEventHandler<
      DataTransfer::DataTransferManager*, DataTransfer::DataRequestedEventArgs*>>(
      [text, subject, title](auto&&,
                             DataTransfer::IDataRequestedEventArgs* event_args) {
        using Microsoft::WRL::Wrappers::HStringReference;

        WRL::ComPtr<DataTransfer::IDataRequest> request;
        if (FAILED(event_args->get_Request(&request))) {
          return E_FAIL;
        }

        WRL::ComPtr<DataTransfer::IDataPackage> data;
        if (FAILED(request->get_Data(&data))) {
          return E_FAIL;
        }

        WRL::ComPtr<DataTransfer::IDataPackagePropertySet> properties;
        if (FAILED(data->get_Properties(&properties))) {
          return E_FAIL;
        }

        const std::string resolved_title =
            !title.empty() ? title : (!subject.empty() ? subject : text);
        const std::wstring wide_title = Utf16FromUtf8(
            resolved_title.empty() ? std::string("Compartilhar") : resolved_title);
        properties->put_Title(HStringReference(wide_title.c_str()).Get());

        const std::wstring wide_text = Utf16FromUtf8(text);
        properties->put_Description(HStringReference(wide_text.c_str()).Get());
        data->SetText(HStringReference(wide_text.c_str()).Get());

        return S_OK;
      });

  if (FAILED(data_transfer_manager->add_DataRequested(
          callback.Get(), &data_transfer_manager_token_))) {
    result->Error("share_unavailable", "Failed to register share callback.");
    return;
  }
  has_data_requested_handler_ = true;

  if (FAILED(
          data_transfer_manager_interop_->ShowShareUIForWindow(window_))) {
    RemoveDataRequestedHandler();
    result->Error("share_unavailable", "Failed to open Windows share UI.");
    return;
  }

  result->Success(flutter::EncodableValue(true));
}

WRL::ComPtr<DataTransfer::IDataTransferManager>
AppShareTextChannel::GetDataTransferManager() {
  using Microsoft::WRL::Wrappers::HStringReference;

  if (data_transfer_manager_interop_ == nullptr) {
    HRESULT activation_result = ::RoGetActivationFactory(
        HStringReference(
            RuntimeClass_Windows_ApplicationModel_DataTransfer_DataTransferManager)
            .Get(),
        IID_PPV_ARGS(&data_transfer_manager_interop_));
    if (FAILED(activation_result)) {
      return nullptr;
    }
  }

  if (data_transfer_manager_ == nullptr) {
    HRESULT interop_result = data_transfer_manager_interop_->GetForWindow(
        window_, IID_PPV_ARGS(&data_transfer_manager_));
    if (FAILED(interop_result)) {
      data_transfer_manager_.Reset();
      return nullptr;
    }
  }

  return data_transfer_manager_;
}

void AppShareTextChannel::RemoveDataRequestedHandler() {
  if (data_transfer_manager_ != nullptr && has_data_requested_handler_) {
    data_transfer_manager_->remove_DataRequested(data_transfer_manager_token_);
    has_data_requested_handler_ = false;
  }
}

std::wstring AppShareTextChannel::Utf16FromUtf8(const std::string& value) {
  int size_needed =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size_needed <= 0) {
    return std::wstring();
  }

  std::wstring result(size_needed, 0);
  int converted_length = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1,
                                             &result[0], size_needed);
  if (converted_length <= 0) {
    return std::wstring();
  }

  return result;
}

std::string AppShareTextChannel::GetStringArgument(
    const flutter::EncodableMap& arguments, const char* key) {
  auto iterator = arguments.find(flutter::EncodableValue(key));
  if (iterator == arguments.end()) {
    return std::string();
  }

  const auto* value = std::get_if<std::string>(&iterator->second);
  return value == nullptr ? std::string() : *value;
}
