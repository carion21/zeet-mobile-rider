// lib/screens/support/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/navigation_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Liste des FAQ pour les livreurs
  final List<Map<String, String>> _faqList = [
    {
      'question': 'Comment accepter une livraison ?',
      'answer':
          'Lorsqu\'une nouvelle livraison est disponible, vous recevez une notification. Appuyez sur "Accepter" pour commencer la course. Assurez-vous d\'être proche du restaurant pour optimiser le temps de livraison.',
    },
    {
      'question': 'Comment fonctionne le système de paiement ?',
      'answer':
          'Vos gains sont calculés automatiquement en fonction des livraisons effectuées. Vous pouvez consulter vos revenus dans l\'onglet "Gains". Les paiements sont effectués chaque semaine sur votre compte mobile money.',
    },
    {
      'question': 'Que faire si le client ne répond pas ?',
      'answer':
          'Essayez d\'appeler le client via l\'application. Si après 3 tentatives il ne répond pas, contactez le support. Nous vous indiquerons la procédure à suivre pour finaliser la commande.',
    },
    {
      'question': 'Comment gérer une commande annulée ?',
      'answer':
          'Si une commande est annulée avant le retrait au restaurant, vous ne serez pas pénalisé. Si l\'annulation intervient après le retrait, vous recevrez une compensation partielle selon nos conditions.',
    },
    {
      'question': 'Puis-je refuser une livraison ?',
      'answer':
          'Oui, mais attention : un taux de refus élevé peut affecter votre priorité dans l\'attribution des courses. Nous recommandons de n\'accepter que les livraisons que vous pouvez honorer.',
    },
    {
      'question': 'Comment signaler un problème avec un restaurant ?',
      'answer':
          'Si vous rencontrez un problème au restaurant (commande pas prête, article manquant), contactez immédiatement le support via l\'application. Nous contacterons le restaurant pour résoudre le problème.',
    },
    {
      'question': 'Que faire en cas d\'accident ou de panne ?',
      'answer':
          'Votre sécurité est prioritaire. En cas d\'accident ou de panne, contactez immédiatement le support d\'urgence. Nous réattribuerons la commande et vous assisterons dans les démarches.',
    },
    {
      'question': 'Comment améliorer mon classement ?',
      'answer':
          'Votre classement dépend de votre taux d\'acceptation, votre ponctualité et les avis clients. Soyez rapide, courtois et professionnel pour obtenir les meilleures notes et plus de courses.',
    },
    {
      'question': 'Les frais de carburant sont-ils couverts ?',
      'answer':
          'Vos gains incluent une compensation pour les frais de carburant et d\'entretien. Le montant varie selon la distance parcourue pour chaque livraison.',
    },
    {
      'question': 'Comment retirer mes gains ?',
      'answer':
          'Accédez à la section "Gains", appuyez sur "Retirer" et choisissez votre mode de paiement (Wave, Orange Money, MTN, Moov). Les retraits sont traités sous 24-48h.',
    },
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupportTicketDialog(context),
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.support_agent, color: Colors.white, size: 20.sp),
        label: Text(
          'Contacter le support',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  IconButton(
                    icon: IconManager.getIcon('arrow_back', color: textColor, size: 24.sp),
                    onPressed: () => Routes.goBack(),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Aide et support',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Section d'information
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconManager.getIcon(
                      'info',
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Besoin d\'aide pendant une course ? Consultez notre FAQ ou contactez-nous.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // FAQ Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Questions fréquentes',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // FAQ List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: _faqList.length,
                itemBuilder: (context, index) {
                  final faq = _faqList[index];
                  final isExpanded = _expandedIndex == index;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 4.h,
                        ),
                        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                        leading: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.help_outline,
                            color: AppColors.primary,
                            size: 20.sp,
                          ),
                        ),
                        title: Text(
                          faq['question']!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        trailing: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: textColor,
                          size: 24.sp,
                        ),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedIndex = expanded ? index : null;
                          });
                        },
                        children: [
                          Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: textLightColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportTicketDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    final List<Map<String, dynamic>> ticketTypes = [
      {
        'title': 'Problème avec une livraison',
        'icon': Icons.delivery_dining,
      },
      {
        'title': 'Problème de paiement',
        'icon': Icons.payment,
      },
      {
        'title': 'Problème avec un restaurant',
        'icon': Icons.restaurant,
      },
      {
        'title': 'Problème avec un client',
        'icon': Icons.person_outline,
      },
      {
        'title': 'Problème technique',
        'icon': Icons.bug_report,
      },
      {
        'title': 'Accident ou urgence',
        'icon': Icons.emergency,
      },
      {
        'title': 'Autre',
        'icon': Icons.more_horiz,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Title
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
                child: Column(
                  children: [
                    Text(
                      'Comment pouvons-nous vous aider ?',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Sélectionnez le type de problème rencontré',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: textLightColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Ticket types list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                itemCount: ticketTypes.length,
                separatorBuilder: (context, index) => Divider(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                  height: 1.h,
                ),
                itemBuilder: (context, index) {
                  final type = ticketTypes[index];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _createTicket(type['title']);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Row(
                        children: [
                          Icon(
                            type['icon'],
                            color: AppColors.primary,
                            size: 22.sp,
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            type['title'],
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  void _createTicket(String ticketType) {
    // TODO: Implémenter la création du ticket avec API
    AppToast.showSuccess(
      context: context,
      message: 'Demande de support "$ticketType" envoyée avec succès',
    );
  }
}
