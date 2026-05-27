import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/paywall_sheet.dart';
import 'create_client_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final clients = provider.clients
        .where((c) =>
            _search.isEmpty ||
            c.displayName.toLowerCase().contains(_search.toLowerCase()) ||
            c.email.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: Icon(Icons.search, size: 20),
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
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('No clients yet',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        const Text('Add your first client',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
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
                        direction: DismissDirection.endToStart,
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
                              title: const Text('Delete Client'),
                              content: Text(
                                  'Delete ${client.displayName}?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Delete',
                                        style: TextStyle(
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
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateClientScreen(client: client),
                                ),
                              ),
                            ),
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
      floatingActionButton: FloatingActionButton(
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
              MaterialPageRoute(builder: (_) => const CreateClientScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
