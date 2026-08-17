import 'package:flutter/material.dart';

enum OrderTab {
  all('All'),
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;

  const OrderTab(this.label);
}

class OrderHistoryTabRow extends StatelessWidget {
  final OrderTab selectedTab;
  final ValueChanged<OrderTab> onTabChanged;

  const OrderHistoryTabRow({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        children: OrderTab.values.map((tab) {
          final isSelected = selectedTab == tab;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF1B5546)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1B5546)
                        : const Color(0xFF7A9C91),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
