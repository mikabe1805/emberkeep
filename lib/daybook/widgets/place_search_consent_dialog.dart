import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../widgets/glass.dart';
import '../../widgets/gold_surface.dart';
import '../services/place_search_access.dart';

Future<PlaceSearchConsentDecision?> showPlaceSearchConsentDialog(
  BuildContext context,
) => showDialog<PlaceSearchConsentDecision>(
  context: context,
  barrierColor: Palette.dialogBarrier,
  builder: (_) => const PlaceSearchConsentDialog(),
);

class PlaceSearchConsentDialog extends StatelessWidget {
  const PlaceSearchConsentDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height - 32,
      ),
      child: GlassPanel(
        tint: Palette.dialogSurface,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEARCH PLACES WITH GOOGLE',
                style: Type.label.copyWith(
                  fontSize: 12,
                  letterSpacing: 0.9,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(height: 12),
              for (final disclosure in const [
                'Through Room of Days, Google receives the query you type, a temporary search session token, and the app display language.',
                'If you choose a result, Room of Days sends Google its place ID once for confirmation.',
                'Your current device location is not requested or used.',
                'Room of Days creates or reuses a private Firebase identity for authenticated service access and abuse controls.',
                'Room of Days retains a private random install identifier for abuse and cost limits; it is not a hardware or device identifier.',
              ]) ...[
                Text(
                  disclosure,
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.38,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 9),
              ],
              Text(
                'Manual location entry stays available either way.',
                style: Type.body.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: Palette.textLo,
                ),
              ),
              const SizedBox(height: 15),
              Semantics(
                button: true,
                label: 'Use place search',
                child: InkWell(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(PlaceSearchConsentDecision.accept),
                  borderRadius: BorderRadius.circular(9),
                  child: GoldSurface(
                    cut: 9,
                    glow: false,
                    textured: false,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        'USE PLACE SEARCH',
                        textAlign: TextAlign.center,
                        style: Type.label.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          color: Palette.onHoney,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(PlaceSearchConsentDecision.decline),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: Palette.textMid,
                  ),
                  child: Text(
                    'KEEP TYPING MANUALLY',
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: Palette.textMid,
                    ),
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
