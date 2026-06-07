import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/paywall_sheet.dart';
import 'bulk_offer_screen.dart';
import 'create_client_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../widgets/feature_guide_sheet.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.clients);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canCreate = provider.canDo(AppPermission.createClient);
    final canEdit   = provider.canDo(AppPermission.editClient);
    final canDelete = provider.canDo(AppPermission.deleteClient);
    final q = _search.toLowerCase();
    final clients = provider.clients
        .where((c) =>
            q.isEmpty ||
            c.displayName.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clients),
        actions: [
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
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? Center(
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: clients.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final client = clients[i];
                      return Dismissible(
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
                        child: Card(
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
                            title: Text(client.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(client.email,
                                    style: const TextStyle(fontSize: 12)),
                                if (client.city.isNotEmpty)
                                  Text(
                                      '${client.city}, ${client.state}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.subtext(context))),
                              ],
                            ),
                            trailing: canEdit
                                ? IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateClientScreen(client: client),
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateClientScreen(client: client),
                              ),
                            ),
                          ),
                        ),
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
                final limit = provider.checkClientLimit();
                if (limit != null) {
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
