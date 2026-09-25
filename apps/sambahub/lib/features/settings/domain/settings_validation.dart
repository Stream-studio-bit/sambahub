typedef SettingsValidator = String? Function(String? value);

abstract final class SettingsValidation {
  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field é obrigatório.';
    return null;
  }

  static String? name(String? value) {
    final requiredError = required(value, field: 'O nome');
    if (requiredError != null) return requiredError;
    if (value!.trim().length < 2)
      return 'O nome deve ter pelo menos 2 caracteres.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return valid ? null : 'Informe um e-mail válido.';
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? null : 'Informe um telefone válido.';
  }

  static String? timezone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe o fuso horário.';
    return value.contains('/') ? null : 'Informe um fuso horário válido.';
  }
}
