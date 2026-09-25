abstract final class SupabaseConstants {
  static const urlEnvironmentKey = 'SUPABASE_URL';
  static const anonKeyEnvironmentKey = 'SUPABASE_ANON_KEY';

  static const validateTicketFunction = 'validate-ticket';
  static const checkoutFunction = 'create-checkout';
  static const reportSummaryFunction = 'get-tenant-report-summary';

  static const profilesTable = 'profiles';
  static const tenantsTable = 'tenants';
  static const membershipsTable = 'tenant_memberships';
  static const notificationsTable = 'notifications';
  static const ticketsTable = 'tickets';
  static const ordersTable = 'orders';
  static const settlementsTable = 'settlements';
}
