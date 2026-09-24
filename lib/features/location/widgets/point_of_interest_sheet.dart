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

  final DraggableScrollableController controller;
  final GlobalKey<PointOfInterestEditorState> editorKey;
  final PointOfInterest? editingPoint;
  final LatLng? draftLocation;
  final double draftRadius;
  final PointOfInterestColor draftColor;
  final String title;
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
    required this.title,
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
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: maxChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: const [minChildSize, maxChildSize],
        builder: (context, scrollController) {
          onScrollControllerChanged(scrollController);

          return Material(
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: onDragUpdate,
                  onVerticalDragEnd: onDragEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.mutedText,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
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
      ),
    );
  }
}
