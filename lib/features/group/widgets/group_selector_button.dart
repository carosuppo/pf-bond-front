import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GroupSelectorButton extends StatefulWidget {
  final String selectedGroupName;

  const GroupSelectorButton({super.key, required this.selectedGroupName});

  @override
  State<GroupSelectorButton> createState() => _GroupSelectorButtonState();
}

class _GroupSelectorButtonState extends State<GroupSelectorButton> {
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;

  bool get _isOpen => _overlayEntry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 52),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary, width: 1.2),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Selector de grupos',
                    style: TextStyle(color: AppColors.text),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);

    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Center(
        child: SizedBox(
          width: 280,
          child: FilledButton.icon(
            onPressed: _toggleOverlay,
            icon: Icon(
              _isOpen ? Icons.keyboard_arrow_up : Icons.groups_outlined,
              size: 20,
            ),
            label: Text(
              widget.selectedGroupName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
