// lib/services/notification_preferences_service.dart
//
// Preferences notifications cote rider : opt-in granulaire par channel
// + heures silencieuses optionnelles.
//
// Skill `zeet-notification-strategy` §9 (Quiet hours & preferences user).
//
// IMPORTANT : ces preferences sont LOCALES. Elles filtrent uniquement les
// notifs affichees par `LocalNotificationService.show*()` cote app
// foreground/background handler. Les notifs envoyees par le backend en
// arriere-plan (FCM data-only avec wake-up) restent traversantes — c'est
// le backend qui doit aussi respecter ces prefs (TODO: sync server-side).
//
// Le channel `kIncomingDeliveryChannelId` (mission urgente) NE PEUT JAMAIS
// etre desactive (decision produit : un rider en service doit toujours
// recevoir une mission). Le DND ne s'applique pas non plus a ce channel.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationChannelPref {
  final String channelId;
  final String label;
  final String description;

  /// Si false, le channel ne peut pas etre desactive (mission critique).
  final bool toggleable;

  /// Si false, le DND ne s'applique pas (toujours sonore).
  final bool respectsQuietHours;

  const NotificationChannelPref({
    required this.channelId,
    required this.label,
    required this.description,
    this.toggleable = true,
    this.respectsQuietHours = true,
  });
}

class NotificationPreferencesService {
  NotificationPreferencesService._();

  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  // ─── Catalog des channels ─────────────────────────────────────────
  // (alignes sur lib/services/local_notification_service.dart)
  static const NotificationChannelPref incomingDelivery =
      NotificationChannelPref(
    channelId: 'zeet_rider_incoming_delivery',
    label: 'Nouvelles missions',
    description: 'Sonnerie prioritaire pour chaque nouvelle offre.',
    toggleable: false, // critique business
    respectsQuietHours: false,
  );

  static const NotificationChannelPref missionUpdates = NotificationChannelPref(
    channelId: 'zeet_rider_missions',
    label: 'Mises a jour mission',
    description: 'Changements d\'etat de tes courses en cours.',
    toggleable: false, // critique operationnel
    respectsQuietHours: false,
  );

  static const NotificationChannelPref zoneAlerts = NotificationChannelPref(
    channelId: 'zeet_rider_zone_alerts',
    label: 'Alertes zone',
    description: 'Forte demande, bonus, meteo.',
  );

  static const NotificationChannelPref stats = NotificationChannelPref(
    channelId: 'zeet_rider_stats',
    label: 'Recaps & stats',
    description: 'Synthese fin de journee, gains.',
  );

  static const NotificationChannelPref promo = NotificationChannelPref(
    channelId: 'zeet_rider_promo',
    label: 'Offres ZEET',
    description: 'Bonus, defis, nouveautes.',
  );

  static List<NotificationChannelPref> get allChannels => const [
        incomingDelivery,
        missionUpdates,
        zoneAlerts,
        stats,
        promo,
      ];

  // ─── Storage keys ─────────────────────────────────────────────────
  static String _kEnabledKey(String channelId) =>
      'notif_pref_enabled_$channelId';
  static const String _kQuietEnabledKey = 'notif_pref_quiet_enabled';
  static const String _kQuietStartKey = 'notif_pref_quiet_start_minutes';
  static const String _kQuietEndKey = 'notif_pref_quiet_end_minutes';

  // ─── Defaults ─────────────────────────────────────────────────────
  // Channels critiques toujours ON par defaut. Promo OFF par defaut.
  static bool _defaultEnabled(String channelId) {
    if (channelId == promo.channelId) return false;
    return true;
  }

  // ─── Public API ───────────────────────────────────────────────────

  /// Lit l'etat enabled d'un channel.
  Future<bool> isChannelEnabled(NotificationChannelPref channel) async {
    if (!channel.toggleable) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey(channel.channelId)) ??
        _defaultEnabled(channel.channelId);
  }

  Future<void> setChannelEnabled(
      NotificationChannelPref channel, bool enabled) async {
    if (!channel.toggleable) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey(channel.channelId), enabled);
  }

  /// Quiet hours : activees ou non.
  Future<bool> isQuietHoursEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kQuietEnabledKey) ?? false;
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kQuietEnabledKey, enabled);
  }

  /// Heure de debut quiet (defaut 22:00).
  Future<TimeOfDay> getQuietStart() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_kQuietStartKey) ?? (22 * 60);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> setQuietStart(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuietStartKey, t.hour * 60 + t.minute);
  }

  /// Heure de fin quiet (defaut 7:00).
  Future<TimeOfDay> getQuietEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_kQuietEndKey) ?? (7 * 60);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> setQuietEnd(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuietEndKey, t.hour * 60 + t.minute);
  }

  /// Vrai si on est actuellement dans la plage quiet hours configuree.
  /// Supporte les ranges qui croisent minuit (ex: 22h00 → 07h00).
  Future<bool> isInQuietHours({DateTime? now}) async {
    if (!await isQuietHoursEnabled()) return false;
    final start = await getQuietStart();
    final end = await getQuietEnd();
    final t = now ?? DateTime.now();
    final nowMin = t.hour * 60 + t.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (startMin == endMin) return false;
    if (startMin < endMin) {
      // Plage normale (ex: 13:00 → 14:00).
      return nowMin >= startMin && nowMin < endMin;
    }
    // Plage qui croise minuit (ex: 22:00 → 07:00).
    return nowMin >= startMin || nowMin < endMin;
  }

  /// Decision finale : doit-on afficher cette notif ?
  /// `false` si channel desactive ou quiet hours actives (sauf canaux
  /// critiques qui ne respectent pas le DND).
  Future<bool> shouldDeliver(String channelId) async {
    final channel = allChannels.firstWhere(
      (c) => c.channelId == channelId,
      orElse: () => incomingDelivery, // unknown → critique par defaut
    );
    final enabled = await isChannelEnabled(channel);
    if (!enabled) return false;
    if (channel.respectsQuietHours && await isInQuietHours()) return false;
    return true;
  }
}
