import 'dart:async';

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
  Timer? _debounce;
  int _limit = _pageSize;
  static const _pageSize = 50;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final canCreate = provider.canDo(AppPermission.createClient);

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
                            size: 48, color: AppTheme.subtext(context)),
                        const SizedBox(height: 12),
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
                  );
                }
                return ListView.separated(
                  controller: _scrollController,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
