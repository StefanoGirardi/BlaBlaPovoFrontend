import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/models/history_models.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/history_widgets.dart';

class RequestHistoryPage extends StatefulWidget {
  final UserModel userModel;

  const RequestHistoryPage({
    super.key,
    required this.userModel,
  });

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  List<RequestRideHistory> history = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRequestHistory();
  }

  Future<void> _loadRequestHistory() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/history/requests/$id'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedHistory = data
            .map((jsonItem) => RequestRideHistory.fromJson(jsonItem))
            .toList();

        setState(() {
          history = loadedHistory;
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching request history: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Request History")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : history.isEmpty
                  ? const Center(child: Text("No request history available"))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final request = history[index];
                        return RequestHistoryCard(
                          history: request,
                          userModel: widget.userModel,
                          onTap: () {
                            // Navigate to detailed view if needed
                            // Navigator.pop(context);
                            // Navigator.pushNamed(
                            //   context,
                            //   '/request_history_details',
                            //   arguments: request,
                            // );
                          },
                        );
                      },
                    ),
    );
  }
}

class OfferHistoryPage extends StatefulWidget {
  final UserModel userModel;

  const OfferHistoryPage({
    super.key,
    required this.userModel,
  });

  @override
  State<OfferHistoryPage> createState() => _OfferHistoryPageState();
}

class _OfferHistoryPageState extends State<OfferHistoryPage> {
  List<OfferRideHistory> history = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOfferHistory();
  }

  Future<void> _loadOfferHistory() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/history/offers/$id'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedHistory = data
            .map((jsonItem) => OfferRideHistory.fromJson(jsonItem))
            .toList();

        setState(() {
          history = loadedHistory;
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching offer history: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offer History")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : history.isEmpty
                  ? const Center(child: Text("No offer history available"))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final offer = history[index];
                        return OfferHistoryCard(
                          history: offer,
                          userModel: widget.userModel,
                          onTap: () {
                            // Navigate to detailed view if needed
                            // Navigator.pushNamed(
                            //   context,
                            //   '/offer_history_details',
                            //   arguments: offer,
                            // );
                          },
                        );
                      },
                    ),
    );
  }
}