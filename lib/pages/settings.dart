import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/create_offer.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  final UserModel userModel;

  const Settings({super.key, required this.userModel});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    Car? car = null;
    if (widget.userModel.currentUser != null) {
      car = widget.userModel.currentUser!.auto != null
          ? Car.fromJson(widget.userModel.currentUser!.auto!)
          : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        backgroundColor: Colors.redAccent,
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: 12,
          ),
          child: Column(
            children: [
              // User Information Section
              _buildSectionCard(
                title: AppLocalizations.of(context)!.userInfo,
                content: Column(
                  children: [
                    _buildInfoRow(
                      label: AppLocalizations.of(context)!.name,
                      value: '${widget.userModel.currentUser?.name} ${widget.userModel.currentUser?.surname}',
                    ),
                    _buildInfoRow(
                      label: AppLocalizations.of(context)!.mail,
                      value: widget.userModel.currentUser?.mail ?? '',
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    _buildActionRow(
                      label: "Username: ${widget.userModel.currentUser?.username ?? "Not set"}",
                      button: ElevatedButton(
                        onPressed: () => _showUsernameDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Modify",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              // Car Information Section
              _buildSectionCard(
                title: AppLocalizations.of(context)!.car,
                content: _buildActionRow(
                  label: car == null 
                      ? "No registered car" 
                      : "Brand: ${car.brand}\nModel: ${car.model}",
                  button: ElevatedButton(
                    onPressed: () {
                      if (car != null) {
                        _showCarDialog(car);
                      } else {
                        final newCar = Car(brand: "", model: "");
                        _showCarDialog(newCar);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      car == null 
                          ? AppLocalizations.of(context)!.registerCar 
                          : AppLocalizations.of(context)!.modify,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              // Language Section - ADD THIS
              _buildSectionCard(
                title: "Language",
                content: Consumer<LocaleProvider>(
                  builder: (context, localeProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current language: ${localeProvider.locale.languageCode == 'it' ? 'Italiano' : 'English'}",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.03),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  localeProvider.setLocale(const Locale('en'));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: localeProvider.locale.languageCode == 'en' 
                                      ? Colors.blue 
                                      : Colors.grey,
                                ),
                                child: Text(
                                  'English',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  localeProvider.setLocale(const Locale('it'));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: localeProvider.locale.languageCode == 'it' 
                                      ? Colors.blue 
                                      : Colors.grey,
                                ),
                                child: Text(
                                  'Italiano',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              // Telegram Section
              _buildSectionCard(
                title: "Telegram",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      label: "Telegram Username",
                      value: widget.userModel.currentUser!.telegram_username ?? "Not set",
                    ),
                    if (widget.userModel.currentUser!.telegram_username != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: screenWidth * 0.03),
                        child: Text(
                          "Telegram is active",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showTelegramDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.userModel.currentUser!.telegram_username != null 
                                ? Colors.orange 
                                : Colors.blue,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.userModel.currentUser!.telegram_username != null 
                                ? "Modify" 
                                : "Set Telegram",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ),
                        if (widget.userModel.currentUser!.telegram_username != null)
                          ElevatedButton(
                            onPressed: _disableTelegram,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.disable,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              // Starred Routes Section
              _buildSectionCard(
                title: AppLocalizations.of(context)!.starred,
                content: _buildActionRow(
                  label: "Manage your favorite routes",
                  button: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/starred_routes');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "View",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              // Delete Account Section
              _buildSectionCard(
                title: "Account",
                content: Center(
                  child: SizedBox(
                    width: screenWidth * 0.7,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.035,
                          horizontal: screenWidth * 0.05,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        Icons.delete_forever, 
                        size: isSmallScreen ? 18 : 20
                      ),
                      label: Text(
                        AppLocalizations.of(context)!.deleteAccount,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: _showDeleteConfirmation,
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenWidth * 0.04),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSectionCard({required String title, required Widget content}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
              ),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({required String label, required Widget button}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
          ),
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: screenWidth * 0.03),
        Align(
          alignment: Alignment.centerRight,
          child: button,
        ),
      ],
    );
  }

  void _showCarDialog(Car? car) {
    final brandController = TextEditingController(text: car?.brand ?? "");
    final modelController = TextEditingController(text: car?.model ?? "");
    final screenWidth = MediaQuery.of(context).size.width;
  
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 20,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  car == null 
                      ? AppLocalizations.of(context)!.registerCar 
                      : "${AppLocalizations.of(context)!.modify} ${AppLocalizations.of(context)!.car}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                TextField(
                  controller: brandController,
                  decoration: InputDecoration(
                    labelText: "Car Brand",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(
                    labelText: "Car Model",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final brand = brandController.text.trim();
                        final model = modelController.text.trim();

                        if (brand.isEmpty || model.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.completeFields)),
                          );
                          return;
                        }

                        final url = Uri.parse(
                          "$apiBaseUrl/api/users/${widget.userModel.currentUser!.id}/patch_car",
                        );

                        try {
                          final response = await http.patch(
                            url,
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
                            },
                            body: jsonEncode({
                              "brand": brand,
                              "model": model,
                            }),
                          );

                          if (response.statusCode == 200) {
                            setState(() {
                              widget.userModel.currentUser!.auto = {
                                "brand": brand,
                                "model": model,
                              };
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Car updated successfully!")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed: ${response.body}")),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUsernameDialog() {
    final usernameController = TextEditingController(
      text: widget.userModel.currentUser?.username ?? ""
    );
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 20,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${AppLocalizations.of(context)!.modify} Username",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    hintText: "Enter your username",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final username = usernameController.text.trim();

                        if (username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a username")),
                          );
                          return;
                        }

                        final url = Uri.parse(
                          "$apiBaseUrl/api/patch_username/$username",
                        );

                        try {
                          final response = await http.patch(
                            url,
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
                            },
                          );

                          if (response.statusCode == 200) {
                            setState(() {
                              widget.userModel.currentUser!.username = username;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Username updated successfully!")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to update username: ${response.body}")),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTelegramDialog() {
    final telegramController = TextEditingController(
      text: widget.userModel.currentUser?.telegram_username ?? ""
    );
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 20,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Telegram Username",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: telegramController,
                  decoration: InputDecoration(
                    labelText: "Telegram Username",
                    hintText: "Enter your Telegram username (without @)",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final telegramUsername = telegramController.text.trim();

                        if (telegramUsername.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a Telegram username")),
                          );
                          return;
                        }

                        final url = Uri.parse(
                          "$apiBaseUrl/api/patch_telegram_username/$telegramUsername",
                        );

                        try {
                          final response = await http.patch(
                            url,
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
                            },
                          );

                          if (response.statusCode == 200) {
                            setState(() {
                              widget.userModel.currentUser!.telegram_username = telegramUsername;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Telegram username updated successfully!")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to update Telegram username: ${response.body}")),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _disableTelegram() async {
    final url = Uri.parse(
      "$apiBaseUrl/api/patch_telegram_username/",
    );

    try {
      final response = await http.patch(
        url,
        headers: {
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          widget.userModel.currentUser!.telegram_username = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Telegram disabled successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to disable Telegram: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _deleteUserInfo() async {
    final url = Uri.parse("$apiBaseUrl/api/delete_users_info");

    try {
      final response = await http.delete(
        url,
        headers: {"Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ User info deleted successfully")),
        );
        widget.userModel.logout();
        await Future.delayed(const Duration(milliseconds: 50));
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete user: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    }
  }

  void _showDeleteConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 20,
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Confirm Delete",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Are you sure you want to delete your account? This cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(AppLocalizations.of(context)!.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await _deleteUserInfo();
    }
  }
}