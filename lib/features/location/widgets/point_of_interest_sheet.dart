import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../point_of_interest/models/point_of_interest.dart';
import '../../point_of_interest/models/point_of_interest_color.dart';
import '../../point_of_interest/models/point_of_interest_request.dart';
import '../../point_of_interest/widgets/point_of_interest_editor.dart';

class PointOfInterestSheet extends StatelessWidget {
  static const minChildSize = 0.12;
  static const maxChildSize = 0.58;

  static double minimumSize(BuildContext context, double availableHeight) {
    final title = TextPainter(
      text: const TextSpan(
        text: 'Punto de interés',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Handle (28), heading padding (8), at least a 48px button, and breathing room.
    final headerHeight = 28 + 8 + (title.height > 48 ? title.height : 48) + 8;
    title.dispose();
    if (availableHeight <= 0) return minChildSize;
    return (headerHeight / availableHeight).clamp(minChildSize, 1.0);
  }

  final DraggableScrollableController controller;
  final GlobalKey<PointOfInterestEditorState> editorKey;
  final PointOfInterest? editingPoint;
  final LatLng? draftLocation;
  final double draftRadius;
  final PointOfInterestColor draftColor;
  final Future<bool> Function(CreatePointOfInterestRequest request) onCreate;
  final Future<bool> Function(UpdatePointOfInterestRequest request) onUpdate;
  final ValueChanged<LatLng> onLocationChanged;
  final ValueChanged<PointOfInterestColor> onColorChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onClosed;
  final ValueChanged<ScrollController> onScrollControllerChanged;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  const PointOfInterestSheet({
    super.key,
    required this.controller,
    required this.editorKey,
    required this.editingPoint,
    required this.draftLocation,
    required this.draftRadius,
    required this.draftColor,
    required this.onCreate,
    required this.onUpdate,
    required this.onLocationChanged,
    required this.onColorChanged,
    required this.onRadiusChanged,
    required this.onClosed,
    required this.onScrollControllerChanged,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimum = minimumSize(context, constraints.maxHeight);
          final maximum = minimum > maxChildSize ? minimum : maxChildSize;
          return DraggableScrollableSheet(
            controller: controller,
            initialChildSize: maximum,
            minChildSize: minimum,
            maxChildSize: maximum,
            snap: true,

            builder: (context, scrollController) {
              onScrollControllerChanged(scrollController);

              return Material(
                color: AppColors.background,
                elevation: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: onDragUpdate,
                      onVerticalDragEnd: onDragEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 14),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.mutedText,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                editorKey.currentState?.requestClose(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const Icon(
                            Icons.flag_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Punto de interés',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PointOfInterestEditor(
                        key: editorKey,
                        scrollController: scrollController,
                        initial: editingPoint,
                        selectedLocation: draftLocation,
                        onLocationChanged: onLocationChanged,
                        onColorChanged: onColorChanged,
                        onRadiusChanged: onRadiusChanged,
                        onCreate: onCreate,
                        onUpdate: onUpdate,
                        onClosed: onClosed,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
