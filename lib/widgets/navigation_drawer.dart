import 'package:flutter/material.dart';

class NavigationDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const NavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.black,
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology,
                    size: 50,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Local LLM Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    title: 'Чати',
                    icon: Icons.chat_bubble_outline,
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    title: 'Моделі',
                    icon: Icons.model_training,
                  ),
                  _buildNavItem(
                    context,
                    index: 2,
                    title: 'Налаштування',
                    icon: Icons.settings_outlined,
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    title: 'Про додаток',
                    icon: Icons.info_outline,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = selectedIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
        ),
      ),
      tileColor: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      onTap: () {
        onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }
}