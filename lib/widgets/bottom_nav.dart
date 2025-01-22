import 'package:flutter/material.dart';
import 'package:yaz/screens/profile_screen.dart';
import 'package:yaz/widgets/customer_list_widget.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'dart:ui';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const BottomNav({
    Key? key,
    required this.currentIndex,
    this.onTap,
  }) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomersProvider>().customers;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.4)
              : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDarkMode 
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                isSelected: widget.currentIndex == 0,
                onTap: () {
                  if (widget.currentIndex == 0) {
                    _playAnimation();
                  }
                  widget.onTap?.call(0);
                },
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                isSelected: widget.currentIndex == 1,
                onTap: () {
                  if (widget.currentIndex == 1) {
                    _playAnimation();
                  }
                  widget.onTap?.call(1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected
        ? (isDarkMode ? Colors.white : Theme.of(context).primaryColor)
        : (isDarkMode ? Colors.grey[400] : Colors.grey[600]);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? Colors.white.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}
