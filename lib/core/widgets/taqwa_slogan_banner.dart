import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';

class TaqwaSloganBanner extends StatelessWidget {
  const TaqwaSloganBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TaqwaColors.domeBlue.withOpacity(0.06),
            TaqwaColors.minaretGold.withOpacity(0.08),
            TaqwaColors.domeBlue.withOpacity(0.06),
          ],
        ),
      ),
      child: const Text(
        'إلهي أنت مقصودي ورضاك مطلوبي',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'ArefRuqaa',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: TaqwaColors.domeBlue,
          height: 1.8,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
