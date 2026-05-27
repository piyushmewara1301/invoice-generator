import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import 'create_client_screen.dart';

class ClientPickerScreen extends StatefulWidget {
  const ClientPickerScreen({super.key});

  @override
  State<ClientPickerScreen> createState() => _ClientPickerScreenState();
}

class _ClientPickerScreenState extends State<ClientPickerScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clients = context
        .watch<AppProvider>()
        .clients
        .where((c) =>
            _search.isEmpty ||
            c.displayName.toLowerCase().contains(_search.toLowerCase()) ||
            c.email.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Client'),
        actions: [
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
            label: const Text('New'),
          ),
        ],
      ),
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
                        const Icon(Icons.people_outline,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        const Text('No clients found',
                            style:
                                TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateClientScreen()),
                          ),
                          child: const Text('Add Client'),
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
