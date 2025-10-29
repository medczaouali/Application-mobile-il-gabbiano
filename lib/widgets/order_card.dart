import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/l10n/strings.dart';

typedef StatusChangeCallback = Future<void> Function(String newStatus);

class OrderCard extends StatelessWidget {
  final Order order;
  final User? user;
  final StatusChangeCallback onChangeStatus;

  const OrderCard({Key? key, required this.order, required this.user, required this.onChangeStatus}) : super(key: key);

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'acceptée':
      case 'préparée':
      case 'prête':
      case 'livrée':
        return Colors.green;
      case 'refusée':
        return Colors.redAccent;
      case 'en attente':
      default:
        return Colors.orange;
    }
  }

  String _formatCurrency(double value) => '${value.toStringAsFixed(2)} €';

  String _formatPickupTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.inDays.abs() >= 1) return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inHours.abs() >= 1) return '${diff.inHours}h';
      if (diff.inMinutes.abs() >= 1) return '${diff.inMinutes}m';
      return 'maintenant';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: (() {
          final u = user;
          if (u != null && u.profileImage != null && u.profileImage!.isNotEmpty) {
            final img = u.profileImage!;
            return CircleAvatar(
              backgroundColor: Colors.transparent,
              backgroundImage: img.startsWith('http') ? CachedNetworkImageProvider(img) as ImageProvider : FileImage(File(img)),
            );
          }
          return CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text((u?.name ?? 'U')[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          );
  })(),
  title: Text('Commande #${order.id}', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(user?.name ?? 'Utilisateur inconnu'),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(order.status, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: _statusColor(order.status, context),
                  ),
                  Row(children: [Icon(Icons.payment, size: 16), SizedBox(width: 6), Text(order.paymentMethod)]),
                ],
              ),
              Text(_formatCurrency(order.total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Text('${Strings.pickupTime}: ${_formatPickupTime(order.pickupTime)}')),
          const SizedBox(height: 12),
          Divider(),
          ...order.items.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                trailing: Text('${item.price.toStringAsFixed(2)} €'),
              )),
          Divider(),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480; // wider threshold for medium phones
            final veryNarrow = constraints.maxWidth < 360; // icon-only mode
            final menu = PopupMenuButton<String>(
              onSelected: (value) => onChangeStatus(value),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'en attente', child: Text('en attente')),
                PopupMenuItem(value: 'acceptée', child: Text('acceptée')),
                PopupMenuItem(value: 'préparée', child: Text('préparée')),
                PopupMenuItem(value: 'prête', child: Text('prête')),
                PopupMenuItem(value: 'livrée', child: Text('livrée')),
                PopupMenuItem(value: 'refusée', child: Text('refusée')),
              ],
              // Use a simple non-interactive container so PopupMenuButton handles taps reliably
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Flexible(child: Text(Strings.modifyStatus, overflow: TextOverflow.ellipsis))]),
                ),
              ),
            );

            final acceptBtn = veryNarrow
                ? ElevatedButton(
                    onPressed: order.status == 'en attente' ? () => onChangeStatus('acceptée') : null,
                    child: Icon(Icons.check),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(44, 40)),
                  )
                : ElevatedButton.icon(
                    onPressed: order.status == 'en attente' ? () => onChangeStatus('acceptée') : null,
                    icon: Icon(Icons.check),
                    label: Text(Strings.accept),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(72, 40), padding: EdgeInsets.symmetric(horizontal: 8)),
                  );

            final refuseBtn = veryNarrow
                ? ElevatedButton(
                    onPressed: order.status == 'en attente' ? () => onChangeStatus('refusée') : null,
                    child: Icon(Icons.close),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: Size(44, 40)),
                  )
                : ElevatedButton.icon(
                    onPressed: order.status == 'en attente' ? () => onChangeStatus('refusée') : null,
                    icon: Icon(Icons.close),
                    label: Text(Strings.refuse),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: Size(72, 40), padding: EdgeInsets.symmetric(horizontal: 8)),
                  );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [menu, const SizedBox(width: 12), Expanded(child: SizedBox())]),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: acceptBtn), const SizedBox(width: 8), Expanded(child: refuseBtn)]),
                ],
              );
            }

            // For wider layouts, use Wrap so buttons will wrap to the next line instead of causing overflow
            return Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [menu, acceptBtn, refuseBtn]);
          })
        ],
      ),
    );
  }
}
