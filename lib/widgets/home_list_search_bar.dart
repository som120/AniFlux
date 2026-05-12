import 'package:flutter/material.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/services.dart';

class HomeListSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback onClose;
  final String initialQuery;

  const HomeListSearchBar({
    super.key,
    required this.onSearch,
    required this.onClose,
    this.initialQuery = '',
    this.onFocus,
  });

  final VoidCallback? onFocus;

  @override
  State<HomeListSearchBar> createState() => _HomeListSearchBarState();
}

class _HomeListSearchBarState extends State<HomeListSearchBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode.addListener(_onFocusChange);
    // Request focus when the search bar is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.onFocus != null) {
      widget.onFocus!();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onSearch,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: "Search from list...",
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              _controller.clear();
              widget.onSearch('');
              widget.onClose();
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
