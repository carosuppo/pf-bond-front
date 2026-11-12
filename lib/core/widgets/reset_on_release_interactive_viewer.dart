import 'dart:async';

import 'package:flutter/material.dart';

/// InteractiveViewer que, al soltar el gesto (mover o hacer zoom),
/// vuelve animado al centro de la pantalla y a escala 1.
///
/// Espera a que la transformación deje de cambiar (incluida la inercia
/// posterior al gesto) antes de recentrar, para no pelear con animaciones
/// internas del InteractiveViewer.
class ResetOnReleaseInteractiveViewer extends StatefulWidget {
  const ResetOnReleaseInteractiveViewer({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 5,
    this.boundaryMargin = const EdgeInsets.all(80),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final EdgeInsets boundaryMargin;

  @override
  State<ResetOnReleaseInteractiveViewer> createState() =>
      _ResetOnReleaseInteractiveViewerState();
}

class _ResetOnReleaseInteractiveViewerState
    extends State<ResetOnReleaseInteractiveViewer>
    with SingleTickerProviderStateMixin {
  static const Duration _resetDuration = Duration(milliseconds: 250);
  static const Duration _stabilityDelay = Duration(milliseconds: 150);

  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _resetController;
  late Animation<Matrix4> _resetAnimation;
  Timer? _stabilityTimer;
  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: _resetDuration,
    );
    _resetController.addListener(() {
      _transformationController.value = _resetAnimation.value;
    });
    _transformationController.addListener(_scheduleResetWhenIdle);
  }

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _transformationController.removeListener(_scheduleResetWhenIdle);
    _resetController.dispose();
    _transformationController.dispose();

    super.dispose();
  }

  /// Reprograma el recentrado cada vez que la transformación cambia sin
  /// gesto activo; el reset se ejecuta cuando queda estable.
  void _scheduleResetWhenIdle() {
    if (_activePointers > 0) {
      return;
    }

    _stabilityTimer?.cancel();
    _stabilityTimer = Timer(_stabilityDelay, _resetIfMoved);
  }

  void _resetIfMoved() {
    if (!mounted || _activePointers > 0) {
      return;
    }

    if (_transformationController.value.isIdentity()) {
      return;
    }

    _resetAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
        );

    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        _activePointers++;
        _stabilityTimer?.cancel();
        _resetController.stop();
      },
      onPointerUp: (_) {
        _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
        _scheduleResetWhenIdle();
      },
      onPointerCancel: (_) {
        _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
        _scheduleResetWhenIdle();
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        boundaryMargin: widget.boundaryMargin,
        child: Center(child: widget.child),
      ),
    );
  }
}
