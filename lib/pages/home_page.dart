import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/pages/logged_in_page.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../utils/jwt_utils.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _idController = TextEditingController();
  final JwtAuthService _authService = JwtAuthService();
  
  // Form controllers for create user
  final TextEditingController _createIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _mailController = TextEditingController();
  final TextEditingController _idadaController = TextEditingController();

  bool _isSSOLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _createIdController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _mailController.dispose();
    _idadaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var userModel = Provider.of<UserModel>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Login'),
        actions: [
          // Language Switcher Button - Add this
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return IconButton(
                  onPressed: () {
                    _showLanguageMenu(context, localeProvider);
                  },
                  icon: const Icon(Icons.language),
                  tooltip: 'Change Language',
                );
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // SAML SSO Login Button
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Single Sign-On',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Login with your organization account',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSSOLoading ? null : () => _handleSSOLogin(userModel),
                      icon: _isSSOLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isSSOLoading ? 'Signing In...' : 'SSO Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Divider with "OR"
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(AppLocalizations.of(context).orLetter),
                ),
                Expanded(child: Divider()),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Create User Form Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Demo User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _createIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID (int)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _nameController,
                      decoration:  InputDecoration(
                        labelText: AppLocalizations.of(context).name,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _surnameController,
                      decoration:  InputDecoration(
                        labelText: 'Surname',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _mailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:  InputDecoration(
                        labelText: AppLocalizations.of(context).mail,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _idadaController,
                      decoration: const InputDecoration(
                        labelText: 'IDADA',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Demo Login & Create User'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Manual ID Login Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _idController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enter User ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final id = _idController.text.trim();
                        if (id.isNotEmpty) {
                          final user = await userModel.fetchUserById(id);
                          if (user != null && mounted) {
                            userModel.login(user);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoggedInPage(userModel: userModel),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User not found')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a user ID')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Fetch User'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method for language menu
  void _showLanguageMenu(BuildContext context, LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('English'),
                trailing: localeProvider.locale.languageCode == 'en' 
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  localeProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Italiano'),
                trailing: localeProvider.locale.languageCode == 'it' 
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  localeProvider.setLocale(const Locale('it'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSSOLogin(UserModel userModel) async {
    setState(() {
      _isSSOLoading = true;
    });

    try {
      if (await _authService.isAuthenticated()) {
        if (mounted) {
          final token = await _authService.getAccessToken();
          final user_info = await _authService.getUserInfo(token!);
          userModel.currentUser = user_info!;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoggedInPage(userModel: userModel),
            ),
          );
        }
        return;
      }

      final authState = "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}";

      // Define callback URL scheme - adjust based on your app
      const callbackUrlScheme = 'com.example.app'; // Change to your app's scheme

      // Build the SSO URL
      final loginUrl = "$apiBaseUrl/api/auth/saml_handle";

      print("=== SSO DEBUG INFO ===");
      print("Starting SSO flow with URL: $loginUrl");
      print("Callback scheme: $callbackUrlScheme");
      print("======================");

      // Use flutter_web_auth_2 for cross-platform authentication
      final result = await FlutterWebAuth2.authenticate(
        url: loginUrl,
        callbackUrlScheme: callbackUrlScheme,
        options: const FlutterWebAuth2Options(
          useWebview: false, // Try setting this to true if false doesn't work
          preferEphemeral: false, 
        )
      );

      print("=== AUTH RESULT ===");
      print("Raw result: $result");
      print("===================");

      // Parse the result URL to extract token
      final resultUri = Uri.parse(result);
      final token = resultUri.queryParameters['token'];
      final userinfo = resultUri.queryParameters['userinfo'];
      final success = resultUri.queryParameters['success'];

      print("=== PARSED PARAMETERS ===");
      print("Success: $success");
      print("Token present: ${token != null && token.isNotEmpty}");
      print("Userinfo present: ${userinfo != null && userinfo.isNotEmpty}");
      print("All query params: ${resultUri.queryParameters}");
      print("=========================");

      if (success == 'true' && token != null && token.isNotEmpty) {
        await _authService.storeTokens(token);
        final decodedUserInfoString = Uri.decodeComponent(userinfo!);
        final Map<String, dynamic> userInfoJson = json.decode(decodedUserInfoString);
        final User user = User.fromJson(userInfoJson); 
        if (mounted) {
          userModel.login(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoggedInPage(userModel: userModel),
            ),
          );
        }
      } else {
        final error = resultUri.queryParameters['error'] ?? 'Authentication failed';
        throw Exception(error);
      }

    } on Exception catch (e) {
      print('SSO Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SSO Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSSOLoading = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
    final id = _createIdController.text.trim();
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final mail = _mailController.text.trim();
    final idada = _idadaController.text.trim();

    if (id.isEmpty || name.isEmpty || surname.isEmpty || mail.isEmpty || idada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final idInt = int.tryParse(id);
    if (idInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID must be a valid number')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': idInt,
          'name': name,
          'surname': surname,
          'mail': mail,
          'idada': idada,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully!')),
        );
        
        _createIdController.clear();
        _nameController.clear();
        _surnameController.clear();
        _mailController.clear();
        _idadaController.clear();
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating user: $e')),
      );
    }
  }
}