import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/paywall_sheet.dart';
import 'bulk_offer_screen.dart';
import 'client_segmentation_screen.dart';
import 'client_profile_screen.dart';
import 'create_client_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/feature_guide_sheet.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  Timer? _debounce;
  int _limit = _pageSize;
  static const _pageSize = 50;
  final _scrollController = ScrollController();
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.clients);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() => _limit += _pageSize);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _search = value;
        _limit = _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canCreate = provider.canDo(AppPermission.createClient);
    final canEdit   = provider.canDo(AppPermission.editClient);
    final canDelete = provider.canDo(AppPermission.deleteClient);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clients),
        actions: [
          IconButton(
            tooltip: 'Client Segments',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ClientSegmentationScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Send Bulk Offer',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const BulkOfferScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l10n.searchClients}...',
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Client>>(
              stream: provider.db.clientsDao
                  .watchClients(search: _search, limit: _limit),
              builder: (context, snapshot) {
                final clients = snapshot.data ?? const <Client>[];
                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 56,
                            color: AppTheme.subtext(context)
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(l10n.noClientsYet,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onCard(context))),
                        const SizedBox(height: 4),
                        Text(l10n.addClient,
                            style: TextStyle(
                                color: AppTheme.subtext(context))),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: clients.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final client = clients[i];
                      return StaggeredEntry(
                        index: i,
                        controller: _enter,
                        child: Dismissible(
                        key: Key(client.id),
                        direction: canDelete
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.deleteClient),
                              content: Text(
                                  '${l10n.delete} ${client.displayName}?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: Text(l10n.cancel)),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: Text(l10n.delete,
                                        style: const TextStyle(
                                            color: AppTheme.error))),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) =>
                            provider.deleteClient(client.id),
                        child: Builder(builder: (context) {
                          final outstanding =
                              provider.clientOutstanding(client.id);
                          final limit = client.creditLimit;
                          final isOver =
                              limit != null && outstanding > limit;
                          final isNear = limit != null &&
                              !isOver &&
                              outstanding >= limit * 0.8;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  client.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(client.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (isOver)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('Over Limit',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.error)),
                                    )
                                  else if (isNear)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('Near Limit',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFF59E0B))),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(client.email,
                                      style:
                                          const TextStyle(fontSize: 12)),
                                  if (client.city.isNotEmpty)
                                    Text(
                                        '${client.city}, ${client.state}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppTheme.subtext(context))),
                                ],
                              ),
                              trailing: canEdit
                                  ? IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateClientScreen(
                                              client: client),
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClientProfileScreen(client: client),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      );
                    },
                  );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                final provider = context.read<AppProvider>();
                final limit = await provider.checkClientLimit();
                if (limit != null) {
                  if (!context.mounted) return;
                  final upgrade = await showPaywallSheet(context, limit);
                  if (upgrade && context.mounted) {
                    Navigator.pushNamed(context, '/plans');
                  }
                  return;
                }
                if (!context.mounted) return;
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CreateClientScreen()));
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
