// lib/screens/ratings/index.dart
//
// Screen "Mes notes" - Liste paginee des notes recues par le rider.
//
// Source : `ratingsProvider` (GET /v1/rider/ratings).
// Le provider expose : entries, summary (average_rating / total_ratings),
// pagination meta, loading, error, hasMore, loadMore().
//
// Skills appliques : zeet-design-system, zeet-pos-ergonomics,
// zeet-micro-copy (rider efficace), zeet-states-elae (4 etats ELOE).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/models/rating_model.dart';
import 'package:rider/providers/ratings_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class RatingsScreen extends ConsumerStatefulWidget {
  const RatingsScreen({super.key});

  @override
  ConsumerState<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends ConsumerState<RatingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ratingsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(ratingsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await ref.read(ratingsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ratingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
        title: Text(
          'Mes notes',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: _buildBody(
          state,
          textColor,
          textLightColor,
          surfaceColor,
          isDarkMode,
        ),
      ),
    );
  }

  Widget _buildBody(
    RatingsListState state,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    bool isDarkMode,
  ) {
    // Loading initial.
    if (state.isLoading && state.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 0.3.sh),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // Error sans fallback.
    if (state.errorMessage != null && state.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(24.w),
        children: [
          SizedBox(height: 0.15.sh),
          _buildErrorState(state.errorMessage!, textColor, textLightColor),
        ],
      );
    }

    // Empty : toujours afficher le header (summary) puis l'empty state.
    if (state.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSummaryHeader(
            state.summary,
            surfaceColor,
            textColor,
            textLightColor,
            isDarkMode,
          ),
          SizedBox(height: 24.h),
          _buildEmptyState(textColor, textLightColor),
        ],
      );
    }

    // Liste paginee.
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      itemCount: state.entries.length + 2, // +header +footer
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryHeader(
            state.summary,
            surfaceColor,
            textColor,
            textLightColor,
            isDarkMode,
          );
        }
        if (index == state.entries.length + 1) {
          if (state.isLoadingMore) {
            return Padding(
              padding: EdgeInsets.all(16.w),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }
          if (!state.hasMore && state.entries.length > 5) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Text(
                  'Fin de la liste',
                  style:
                      TextStyle(color: textLightColor, fontSize: 12.sp),
                ),
              ),
            );
          }
          return const SizedBox(height: 16);
        }
        final entry = state.entries[index - 1];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: _buildRatingTile(
            entry,
            surfaceColor,
            textColor,
            textLightColor,
            isDarkMode,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Summary header
  // ---------------------------------------------------------------------------

  Widget _buildSummaryHeader(
    RatingSummary summary,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final avg = summary.averageRating;
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note moyenne',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      '/ 5',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              _buildStarsRow(avg, size: 16, color: Colors.white),
              SizedBox(height: 6.h),
              Text(
                '${summary.totalRatings} avis recu${summary.totalRatings > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rating tile
  // ---------------------------------------------------------------------------

  Widget _buildRatingTile(
    RatingEntry entry,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final rater = entry.raterUser;
    final dateStr = entry.dateCreated == null
        ? ''
        : DateFormat('d MMM yyyy', 'fr_FR').format(entry.dateCreated!);
    final orderCode = entry.order?.code;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(rater),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rater?.displayName ?? 'Client',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (orderCode != null && orderCode.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        orderCode,
                        style: TextStyle(
                          color: textLightColor,
                          fontSize: 11.sp,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: TextStyle(color: textLightColor, fontSize: 11.sp),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildStarsRow(
            entry.score.toDouble(),
            size: 16,
            color: const Color(0xFFFFC107),
          ),
          if (entry.comment != null && entry.comment!.trim().isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              entry.comment!.trim(),
              style: TextStyle(
                color: textColor,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(RatingRaterUser? user) {
    final size = 40.w;
    if (user?.photo != null && user!.photo!.isNotEmpty) {
      return ZeetImage(
        url: user.photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(9999),
        errorWidget: _buildInitialsAvatar(user),
      );
    }
    return _buildInitialsAvatar(user);
  }

  Widget _buildInitialsAvatar(RatingRaterUser? user) {
    final size = 40.w;
    final initials = user?.initials ?? 'C';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stars row
  // ---------------------------------------------------------------------------

  Widget _buildStarsRow(
    double score, {
    required double size,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < score.round();
        return Padding(
          padding: EdgeInsets.only(right: i == 4 ? 0 : 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: color,
            size: size,
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty / Error states
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(Color textColor, Color textLightColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      child: Column(
        children: [
          IconManager.getIcon('star', color: textLightColor, size: 56),
          SizedBox(height: 16.h),
          Text(
            'Aucune note recue pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Vos premieres evaluations apparaitront ici apres vos prochaines livraisons.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textLightColor, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    String message,
    Color textColor,
    Color textLightColor,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconManager.getIcon('warning', color: textLightColor, size: 48),
        SizedBox(height: 16.h),
        Text(
          'Impossible de charger vos notes',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: textLightColor, fontSize: 13.sp),
        ),
        SizedBox(height: 16.h),
        TextButton(
          onPressed: _onRefresh,
          child: Text(
            'Reessayer',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
