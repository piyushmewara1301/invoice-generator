// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../models/business_info.dart';
// import '../../providers/app_provider.dart';
// import '../../utils/app_theme.dart';

// class BusinessesScreen extends StatelessWidget {
//   const BusinessesScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<AppProvider>();
//     // final businesses = provider.businesses;
//     // final activeId = provider.activeBusinessId;

//     return Scaffold(
//       appBar: AppBar(title: const Text('My Businesses')),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () => _showAddDialog(context),
//         icon: const Icon(Icons.add_business_outlined),
//         label: const Text('Add Business'),
//       ),
//       body: businesses.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
//               children: [
//                 _InfoBanner(),
//                 const SizedBox(height: 16),
//                 for (final biz in businesses) ...[
//                   _BusinessCard(
//                     info: biz,
//                     isActive: biz.id == activeId,
//                     canDelete: businesses.length > 1,
//                     onSwitch: () => _switchTo(context, biz),
//                     onRename: () => _showRenameDialog(context, biz),
//                     onDelete: () => _confirmDelete(context, biz),
//                   ),
//                   const SizedBox(height: 10),
//                 ],
//               ],
//             ),
//     );
//   }

//   // ── Actions ────────────────────────────────────────────────────────────────

//   Future<void> _switchTo(BuildContext context, BusinessInfo biz) async {
//     final provider = context.read<AppProvider>();
//     if (biz.id == provider.activeBusinessId) return;
//     await provider.switchBusiness(biz.id);
//     if (context.mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Switched to ${biz.name}'),
//           duration: const Duration(seconds: 2),
//         ),
//       );
//       // Defer pop to next frame so the rebuild triggered by switchBusiness
//       // completes before this widget is removed from the tree.
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (context.mounted) Navigator.pop(context);
//       });
//     }
//   }

//   Future<void> _showAddDialog(BuildContext context) async {
//     final ctrl = TextEditingController();
//     final name = await showDialog<String>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('New Business'),
//         content: TextField(
//           controller: ctrl,
//           autofocus: true,
//           textCapitalization: TextCapitalization.words,
//           decoration: const InputDecoration(
//             labelText: 'Business name',
//             hintText: 'e.g. My Second Shop',
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               final v = ctrl.text.trim();
//               if (v.isNotEmpty) Navigator.pop(context, v);
//             },
//             child: const Text('Create'),
//           ),
//         ],
//       ),
//     );
//     // Defer disposal to the next frame so the dialog's TextField can finish
//     // its own cleanup before the controller is gone.
//     WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());

//     if (name != null && context.mounted) {
//       final provider = context.read<AppProvider>();
//       final duplicate = provider.businesses.any(
//         (b) => b.name.toLowerCase() == name.toLowerCase(),
//       );
//       if (duplicate) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('A business named "$name" already exists.'),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//         return;
//       }
//       await provider.createBusiness(name);
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('$name created and switched'),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//         // Defer pop to next frame so the rebuild triggered by createBusiness
//         // completes before this widget is removed from the tree.
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (context.mounted) Navigator.pop(context);
//         });
//       }
//     }
//   }

//   Future<void> _showRenameDialog(BuildContext context, BusinessInfo biz) async {
//     final ctrl = TextEditingController(text: biz.name);
//     final name = await showDialog<String>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Rename Business'),
//         content: TextField(
//           controller: ctrl,
//           autofocus: true,
//           textCapitalization: TextCapitalization.words,
//           decoration: const InputDecoration(labelText: 'Business name'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               final v = ctrl.text.trim();
//               if (v.isNotEmpty) Navigator.pop(context, v);
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
//     if (name != null && context.mounted) {
//       final provider = context.read<AppProvider>();
//       final duplicate = provider.businesses.any(
//         (b) => b.id != biz.id && b.name.toLowerCase() == name.toLowerCase(),
//       );
//       if (duplicate) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('A business named "$name" already exists.'),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//         return;
//       }
//       // If this is the active business, update its profile name too
//       if (biz.id == provider.activeBusinessId) {
//         provider.profile.name = name;
//         await provider.updateProfile(provider.profile);
//       }
//       biz.name = name;
//     }
//   }

//   Future<void> _confirmDelete(BuildContext context, BusinessInfo biz) async {
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Delete business?'),
//         content: Text(
//           'All invoices, clients and settings for "${biz.name}" will be '
//           'permanently deleted. This cannot be undone.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Delete',
//                 style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//     if (ok == true && context.mounted) {
//       final deleted = await context.read<AppProvider>().deleteBusiness(biz.id);
//       if (context.mounted && deleted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('${biz.name} deleted'),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     }
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Business card
// // ─────────────────────────────────────────────────────────────────────────────

// class _BusinessCard extends StatelessWidget {
//   final BusinessInfo info;
//   final bool isActive;
//   final bool canDelete;
//   final VoidCallback onSwitch;
//   final VoidCallback onRename;
//   final VoidCallback onDelete;

//   const _BusinessCard({
//     required this.info,
//     required this.isActive,
//     required this.canDelete,
//     required this.onSwitch,
//     required this.onRename,
//     required this.onDelete,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = isActive ? AppTheme.primary : AppTheme.textSecondary;

//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isActive ? AppTheme.primary : AppTheme.divider,
//           width: isActive ? 2 : 1,
//         ),
//         boxShadow: isActive
//             ? [
//                 BoxShadow(
//                   color: AppTheme.primary.withValues(alpha: 0.12),
//                   blurRadius: 8,
//                   offset: const Offset(0, 3),
//                 )
//               ]
//             : [],
//       ),
//       child: InkWell(
//         onTap: isActive ? null : onSwitch,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Row(
//             children: [
//               // Avatar
//               CircleAvatar(
//                 radius: 22,
//                 backgroundColor: color.withValues(alpha: 0.12),
//                 child: Text(
//                   info.name.isNotEmpty ? info.name[0].toUpperCase() : '?',
//                   style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       color: color),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               // Name + active tag
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       info.name.isNotEmpty ? info.name : 'Unnamed Business',
//                       style: TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.w600,
//                           color: isActive ? AppTheme.primary : null),
//                     ),
//                     if (isActive)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 3),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: AppTheme.primary.withValues(alpha: 0.1),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: const Text('Active',
//                               style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w700,
//                                   color: AppTheme.primary)),
//                         ),
//                       )
//                     else
//                       const Text('Tap to switch',
//                           style: TextStyle(
//                               fontSize: 11,
//                               color: AppTheme.textSecondary)),
//                   ],
//                 ),
//               ),
//               // Actions
//               IconButton(
//                 icon: const Icon(Icons.edit_outlined, size: 18),
//                 color: AppTheme.textSecondary,
//                 tooltip: 'Rename',
//                 onPressed: onRename,
//                 visualDensity: VisualDensity.compact,
//               ),
//               if (canDelete)
//                 IconButton(
//                   icon: const Icon(Icons.delete_outline, size: 18),
//                   color: Colors.red,
//                   tooltip: 'Delete',
//                   onPressed: onDelete,
//                   visualDensity: VisualDensity.compact,
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────

// class _InfoBanner extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppTheme.primary.withValues(alpha: 0.06),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
//       ),
//       child: const Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               'Each business has its own invoices, clients and settings. '
//               'Tap a business to switch — all your data updates instantly.',
//               style: TextStyle(fontSize: 12, color: AppTheme.primary),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
