import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:multi_user_flutter_app/utils/telegram_utils.dart';

class TelegramChatLauncher extends StatefulWidget {
  final int initiatorId;
  final int targetId;
  final String token;
  final String? initiatorUsername;
  final String? targetUsername;
  final String buttonText;
  final ButtonStyle? buttonStyle;
  final Widget? icon;

  const TelegramChatLauncher({
    Key? key,
    required this.initiatorId,
    required this.targetId,
    required this.token,
    this.initiatorUsername,
    this.targetUsername,
    this.buttonText = '💬 Chat on Telegram',
    this.buttonStyle,
    this.icon,
  }) : super(key: key);
  
  @override
  State<TelegramChatLauncher> createState() => _TelegramChatLauncherState();
}

class _TelegramChatLauncherState extends State<TelegramChatLauncher> {
  bool _isLoading = false;

  Future<void> _launchTelegramChat(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await TelegramApiService.initiateChat(
        ChatRequest(
          initiatorId: widget.initiatorId,
          targetId: widget.targetId,
          initiatorUsername: widget.initiatorUsername,
          targetUsername: widget.targetUsername,
          token: widget.token,
        ),
      );

      if (response.success && response.deepLink != null) {
        final uri = Uri.parse(response.deepLink!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showErrorDialog(context, 'Cannot open Telegram. Please make sure it is installed.');
        }
      } else {
        _showErrorDialog(context, response.message);
      }
    } catch (e) {
      _showErrorDialog(context, 'Failed to initiate chat: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _launchTelegramChat(context),
      style: widget.buttonStyle ?? ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0088CC),
        foregroundColor: Colors.white,
      ),
      icon: _isLoading 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : (widget.icon ?? const Icon(Icons.chat)),
      label: Text(_isLoading ? 'Connecting...' : widget.buttonText),
    );
  }
}