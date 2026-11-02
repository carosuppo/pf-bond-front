import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../group/providers/group_provider.dart';
import '../../group/widgets/group_selector_button.dart';
import 'documentation_screen.dart';

/// Uses the same active group as the other main destinations.
class DocumentationGroupScreen extends StatefulWidget {
  final bool isActive;
  final VoidCallback onExit;
  const DocumentationGroupScreen({
    super.key,
    required this.isActive,
    required this.onExit,
  });

  @override
  State<DocumentationGroupScreen> createState() =>
      _DocumentationGroupScreenState();
}

class _DocumentationGroupScreenState extends State<DocumentationGroupScreen> {
  bool _menuOpen = false;
  int? _displayedGroupId;

  @override
  void didUpdateWidget(DocumentationGroupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) _menuOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final GroupProvider groups = context.watch<GroupProvider>();
    if (_displayedGroupId != groups.activeGroup?.id) {
      _displayedGroupId = groups.activeGroup?.id;
      _menuOpen = false;
    }
    final Widget selector = widget.isActive
        ? GroupSelectorButton(
            onMenuVisibilityChanged: (bool open) =>
                setState(() => _menuOpen = open),
          )
        : const SizedBox.shrink();
    final bool handlesBack = widget.isActive && !_menuOpen;
    final int? groupId = groups.activeGroup?.id;
    if (groupId == null) {
      return PopScope<void>(
        canPop: !handlesBack,
        onPopInvokedWithResult: (bool didPop, void result) {
          if (!didPop && handlesBack) widget.onExit();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Documentación'),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: <Widget>[
              Padding(padding: const EdgeInsets.all(16), child: selector),
              const Expanded(
                child: Center(
                  child: Text('Seleccioná un grupo para ver sus documentos.'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DocumentationScreen(
      groupId: groupId,
      groupName: groups.activeGroup!.name,
      groupSelector: selector,
      handlesSystemBack: handlesBack,
      onExit: widget.onExit,
    );
  }
}
