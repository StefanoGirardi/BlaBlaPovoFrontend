import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/history_pages.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';

class HistoryPage extends StatefulWidget {
  final UserModel userModel;

  const HistoryPage({
    super.key,
    required this.userModel,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).history}"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "${AppLocalizations.of(context).requests}"),
            Tab(text: "${AppLocalizations.of(context).offers}"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RequestHistoryPage(userModel: widget.userModel),
          OfferHistoryPage(userModel: widget.userModel),
        ],
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
    );
  }
}