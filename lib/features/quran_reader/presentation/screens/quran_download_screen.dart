import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import 'quran_page_viewer_screen.dart';

/// Info screen — Quran is fully offline, no download needed.
class QuranDownloadScreen extends StatelessWidget {
  const QuranDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('المصحف الشريف',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          backgroundColor: TaqwaColors.domeBlue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: TaqwaColors.islamicGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 48, color: TaqwaColors.islamicGreen),
                ),
                const SizedBox(height: 24),
                const Text('المصحف جاهز بدون إنترنت',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
                const SizedBox(height: 12),
                Text(
                  'القرآن الكريم كاملاً محفوظ على جهازك ويعمل بدون اتصال',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.6),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QuranPageViewerScreen()),
                      );
                    },
                    icon: const Icon(Icons.auto_stories, color: Colors.white),
                    label: const Text('فتح المصحف',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaqwaColors.domeBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
