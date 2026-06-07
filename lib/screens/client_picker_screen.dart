import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import 'create_client_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';

class ClientPickerScreen extends StatefulWidget {
  const ClientPickerScreen({super.key});

  @override
  State<ClientPickerScreen> createState() => _ClientPickerScreenState();
}

class _ClientPickerScreenState extends State<ClientPickerScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canCreate = provider.canDo(AppPermission.createClient);
    final q = _search.toLowerCase();
    final clients = provider
        .clients
        .where((c) =>
            q.isEmpty ||
            c.displayName.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectClient),
        actions: [
          if (canCreate)
            TextButton.icon(
              onPressed: () async {
                final client = await Navigator.push<Client>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateClientScreen()),
                );
                if (client != null && context.mounted) {
                  Navigator.pop(context, client);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.add),
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
                            size: 48, color: AppTheme.subtext(context)),
                        SizedBox(height: 12),
                        Text(l10n.noClientsYet,
                            style: TextStyle(
                                color: AppTheme.subtext(context))),
                        const SizedBox(height: 16),
                        if (canCreate)
                          ElevatedButton(
                            onPressed: () async {
                              final client = await Navigator.push<Client>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateClientScreen()),
                              );
                              if (client != null && context.mounted) {
                                Navigator.pop(context, client);
                              }
                            },
                            child: Text(l10n.addClient),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: clients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              c.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(c.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(c.email),
                          onTap: () => Navigator.pop(context, c),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
