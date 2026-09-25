enum SettingsStatus {
  initial,
  loading,
  editing,
  saving,
  saved,
  error,
  permissionDenied,
  offline,
}

class SettingsState<T> {
  const SettingsState({
    required this.status,
    this.data,
    this.message,
  });

  const SettingsState.initial() : this(status: SettingsStatus.initial);

  const SettingsState.loading() : this(status: SettingsStatus.loading);

  const SettingsState.editing(T data)
      : this(status: SettingsStatus.editing, data: data);

  const SettingsState.saving(T data)
      : this(status: SettingsStatus.saving, data: data);

  const SettingsState.saved(T data)
      : this(status: SettingsStatus.saved, data: data);

  const SettingsState.error(String message, {T? data})
      : this(status: SettingsStatus.error, data: data, message: message);

  const SettingsState.permissionDenied([String? message])
      : this(
          status: SettingsStatus.permissionDenied,
          message: message ??
              'Você não tem permissão para alterar estas configurações.',
        );

  const SettingsState.offline([String? message])
      : this(
          status: SettingsStatus.offline,
          message:
              message ?? 'Sem conexão. Tente novamente quando estiver online.',
        );

  final SettingsStatus status;
  final T? data;
  final String? message;

  bool get isBusy =>
      status == SettingsStatus.loading || status == SettingsStatus.saving;
  bool get hasError =>
      status == SettingsStatus.error || status == SettingsStatus.offline;
  bool get isSuccess => status == SettingsStatus.saved;

  SettingsState<T> copyWith({
    SettingsStatus? status,
    T? data,
    String? message,
  }) {
    return SettingsState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: message ?? this.message,
    );
  }
}
