import 'package:flutter/material.dart';

class SearchFilterBar<T> extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final T filterValue;
  final List<DropdownMenuItem<T>> filterItems;
  final ValueChanged<T?> onFilterChanged;

  const SearchFilterBar({
    super.key,
    required this.hintText,
    required this.onSearchChanged,
    required this.filterValue,
    required this.filterItems,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<T>(
          value: filterValue,
          items: filterItems,
          onChanged: onFilterChanged,
        ),
      ],
    );
  }
}
