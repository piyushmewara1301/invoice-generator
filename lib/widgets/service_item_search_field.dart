import 'dart:async';

import 'package:flutter/material.dart';

import '../data/db/app_database.dart';
import '../models/service_item.dart';
import '../utils/app_theme.dart';

/// A text field with a debounced, database-backed dropdown of matching
/// [ServiceItem]s.
///
/// Replaces Flutter's [Autocomplete] widget for item pickers: its
/// `optionsBuilder` is synchronous only, which forces callers to keep the
/// entire catalog in memory just to filter it on every keystroke. This
/// widget instead runs [ItemsDao.search] (an indexed, limited DB query) on a
/// short debounce, so item pickers stay fast no matter how large the catalog
/// gets.
class ServiceItemSearchField extends StatefulWidget {
  final AppDatabase db;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? hintText;
  final bool readOnly;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChangedText;
  final ValueChanged<ServiceItem> onSelected;
  final Widget Function(BuildContext context, ServiceItem item) itemBuilder;

  const ServiceItemSearchField({
    super.key,
    required this.db,
    required this.controller,
    this.focusNode,
    required this.labelText,
    this.hintText,
    this.readOnly = false,
    this.suffixIcon,
    this.onChangedText,
    required this.onSelected,
    required this.itemBuilder,
  });

  @override
  State<ServiceItemSearchField> createState() =>
      _ServiceItemSearchFieldState();
}

class _ServiceItemSearchFieldState extends State<ServiceItemSearchField> {
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;
  Timer? _debounce;
  List<ServiceItem> _results = [];
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    final node = widget.focusNode;
    if (node != null) {
      _focusNode = node;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.readOnly) return;
    if (_focusNode.hasFocus) {
      setState(() => _showResults = true);
      _search(widget.controller.text);
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await widget.db.itemsDao.search(query, limit: 20);
      if (!mounted) return;
      setState(() => _results = results);
    });
  }

  void _handleChanged(String value) {
    widget.onChangedText?.call(value);
    setState(() => _showResults = true);
    _search(value);
  }

  void _handleSelected(ServiceItem item) {
    _debounce?.cancel();
    setState(() {
      _results = [];
      _showResults = false;
    });
    _focusNode.unfocus();
    widget.onSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    final showDropdown =
        !widget.readOnly && _showResults && _results.isNotEmpty;
    return TapRegion(
      onTapOutside: (_) {
        if (_showResults) setState(() => _showResults = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            readOnly: widget.readOnly,
            onChanged: widget.readOnly ? null : _handleChanged,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              suffixIcon: widget.suffixIcon,
            ),
          ),
          if (showDropdown)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 220),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.card(context),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final item = _results[i];
                    return InkWell(
                      onTap: () => _handleSelected(item),
                      child: widget.itemBuilder(ctx, item),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
