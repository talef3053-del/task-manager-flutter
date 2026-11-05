import 'package:flutter/material.dart';

/// Gradient card at the top of the Today tab:
/// a greeting, a short message and a ring showing tasks done.
class SummaryHeader extends StatelessWidget {
  const SummaryHeader({super.key, required this.done, required this.total});

  final int done;
  final int total;

  String get _greeting {
    final h = DateTime
        .now()
        .hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌸';
    return 'Good evening 🌙';
  }

  String get _message {
    if (total == 0) {
      return 'Nothing planned today. Enjoy the free time!';
    }
    if (done == total) {
      return 'All done for today! 🎉';
    }
    if (done == 0) {
      return 'You have $total task${total == 1 ? '' : 's'} today. Let\'s start!';
    }
    return '${total - done} more to go. You\'re doing great!';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme
        .of(context)
        .colorScheme;
    final value = total == 0 ? 0.0 : done / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _message,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onPrimary.withAlpha(230),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: value),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) =>
                        CircularProgressIndicator(
                          value: v,
                          strokeWidth: 8,
                          backgroundColor: scheme.onPrimary.withAlpha(70),
                          valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                  ),
                ),
                Text(
                  '$done/$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}