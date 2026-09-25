abstract final class AppConstants {
  static const appName = 'SambaHub';
  static const appVersion = '0.1.0';
  static const supportEmail = 'suporte@sambahub.com.br';
  static const defaultCurrency = 'BRL';
  static const defaultTimezone = 'America/Sao_Paulo';
  static const defaultPageSize = 25;
  static const maxPageSize = 100;
  static const maxCampaignProducts = 50;
  static const maxUploadSizeBytes = 10 * 1024 * 1024;

  static const ticketStatuses = <String>{
    'issued',
    'checked_in',
    'cancelled',
    'refunded',
  };

  static const memberRoles = <String>{
    'owner',
    'admin',
    'producer',
    'finance',
    'checkin',
    'group_manager',
    'viewer',
  };
}
