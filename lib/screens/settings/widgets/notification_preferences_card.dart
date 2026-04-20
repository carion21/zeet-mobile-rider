// lib/screens/settings/widgets/notification_preferences_card.dart
//
// Section "Notifications" du Settings : opt-in granulaire par channel
// + heures silencieuses. Persiste les preferences via
// `NotificationPreferencesService` (SharedPreferences).
//
// Skill `zeet-notification-strategy` §9 (Quiet hours & preferences user)
// + `zeet-pos-ergonomics` (toggles larges, time pickers natifs).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/services/notification_preferences_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class NotificationPreferencesCard extends StatefulWidget {
  const NotificationPreferencesCard({super.key});

  @override
  State<NotificationPreferencesCard> createState() =>
      _NotificationPreferencesCardState();
}

class _NotificationPreferencesCardState
    extends State<NotificationPreferencesCard> {
  final _service = NotificationPreferencesService.instance;

  bool _loading = true;
  final Map<String, bool> _enabled = <String, bool>{};
  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final futures = NotificationPreferencesService.allChannels
        .map((c) => _service.isChannelEnabled(c).then((v) =>
            MapEntry<String, bool>(c.channelId, v)))
        .toList();
    final results = await Future.wait<MapEntry<String, bool>>(futures);
    final quietEnabled = await _service.isQuietHoursEnabled();
    final quietStart = await _service.getQuietStart();
    final quietEnd = await _service.getQuietEnd();
    if (!mounted) return;
    setState(() {
      _enabled
        ..clear()
        ..addEntries(results);
      _quietEnabled = quietEnabled;
      _quietStart = quietStart;
      _quietEnd = quietEnd;
      _loading = false;
    });
  }

  Future<void> _toggleChannel(
      NotificationChannelPref channel, bool value) async {
    if (!channel.toggleable) return;
    setState(() => _enabled[channel.channelId] = value);
    await _service.setChannelEnabled(channel, value);
  }

  Future<void> _toggleQuiet(bool value) async {
    setState(() => _quietEnabled = value);
    await _service.setQuietHoursEnabled(value);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Début silence' : 'Fin silence',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
    });
    if (isStart) {
      await _service.setQuietStart(picked);
    } else {
      await _service.setQuietEnd(picked);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    if (_loading) {
      return _Card(
        surfaceColor: surfaceColor,
        isDarkMode: isDarkMode,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ],
      );
    }

    final channels = NotificationPreferencesService.allChannels;
    return _Card(
      surfaceColor: surfaceColor,
      isDarkMode: isDarkMode,
      children: [
        for (int i = 0; i < channels.length; i++) ...<Widget>[
          if (i > 0)
            Divider(
                height: 1, color: textLightColor.withValues(alpha: 0.1)),
          _ChannelTile(
            channel: channels[i],
            enabled: _enabled[channels[i].channelId] ?? true,
            onChanged: (v) => _toggleChannel(channels[i], v),
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ],

        // ─── Quiet hours ─────────────────────────────────────────────
        Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
        _QuietHoursToggle(
          enabled: _quietEnabled,
          onChanged: _toggleQuiet,
          textColor: textColor,
          textLightColor: textLightColor,
        ),
        if (_quietEnabled) ...<Widget>[
          Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
          _QuietHoursRange(
            start: _quietStart,
            end: _quietEnd,
            onTapStart: () => _pickTime(isStart: true),
            onTapEnd: () => _pickTime(isStart: false),
            formatter: _formatTime,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.surfaceColor,
    required this.isDarkMode,
    required this.children,
  });

  final Color surfaceColor;
  final bool isDarkMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.enabled,
    required this.onChanged,
    required this.textColor,
    required this.textLightColor,
  });

  final NotificationChannelPref channel;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        channel.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!channel.toggleable) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: ZeetColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'requis',
                          style: TextStyle(
                            color: ZeetColors.primary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  channel.description,
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Switch(
            value: enabled,
            onChanged: channel.toggleable ? onChanged : null,
            activeThumbColor: ZeetColors.primary,
          ),
        ],
      ),
    );
  }
}

class _QuietHoursToggle extends StatelessWidget {
  const _QuietHoursToggle({
    required this.enabled,
    required this.onChanged,
    required this.textColor,
    required this.textLightColor,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, color: ZeetColors.primary, size: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heures silencieuses',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Coupe les notifs non critiques sur la plage choisie.',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: ZeetColors.primary,
          ),
        ],
      ),
    );
  }
}

class _QuietHoursRange extends StatelessWidget {
  const _QuietHoursRange({
    required this.start,
    required this.end,
    required this.onTapStart,
    required this.onTapEnd,
    required this.formatter,
    required this.textColor,
    required this.textLightColor,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;
  final String Function(TimeOfDay) formatter;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Expanded(
            child: _TimeButton(
              label: 'De',
              value: formatter(start),
              onTap: onTapStart,
              textColor: textColor,
              textLightColor: textLightColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _TimeButton(
              label: 'À',
              value: formatter(end),
              onTap: onTapEnd,
              textColor: textColor,
              textLightColor: textLightColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
    required this.textColor,
    required this.textLightColor,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: ZeetColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ZeetColors.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textLightColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
