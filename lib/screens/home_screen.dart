import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import 'room_designer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthController _authController;
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  void _loadCurrentUser() async {
    final user = await _authController.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _handleLogout() async {
    await _authController.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('3D Layout - ${_currentUser?.fullName ?? 'User'}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: const RoomDesignerScreen(),
    );
  }
}
