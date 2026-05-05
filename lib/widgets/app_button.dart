import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  const AppButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 320,
      height: 170,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF101720),
          disabledBackgroundColor: const Color(0xFF101720),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF566172),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: enabled ? const Color(0xFF243040) : const Color(0xFF1A2230),
              width: 1.2,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: enabled
                      ? accentColor.withValues(alpha: 0.13)
                      : const Color(0xFF1A2230),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: enabled
                        ? accentColor.withValues(alpha: 0.25)
                        : const Color(0xFF263142),
                  ),
                ),
                child: Icon(
                  icon,
                  color: enabled ? accentColor : const Color(0xFF566172),
                  size: 38,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? Colors.white : const Color(0xFF566172),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? const Color(0xFF9DA8B7)
                            : const Color(0xFF3A4554),
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}