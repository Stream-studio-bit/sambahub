enum SettingsPermission {
  view,
  editOrganization,
  editNotifications,
  editCheckin,
  manageMembers,
  deleteOrganization,
}

abstract final class SettingsPermissions {
  static const roles = <String>{
    'owner',
    'admin',
    'producer',
    'finance',
    'checkin',
    'group_manager',
    'viewer',
  };

  static bool can(String role, SettingsPermission permission) {
    switch (permission) {
      case SettingsPermission.view:
        return roles.contains(role);
      case SettingsPermission.editOrganization:
        return role == 'owner' || role == 'admin';
      case SettingsPermission.editNotifications:
        return role == 'owner' || role == 'admin' || role == 'producer';
      case SettingsPermission.editCheckin:
        return role == 'owner' || role == 'admin' || role == 'checkin';
      case SettingsPermission.manageMembers:
        return role == 'owner' || role == 'admin';
      case SettingsPermission.deleteOrganization:
        return role == 'owner';
    }
  }

  static bool isOwner(String role) => role == 'owner';

  static bool isAdmin(String role) => role == 'owner' || role == 'admin';
}
