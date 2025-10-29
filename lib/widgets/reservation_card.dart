import 'package:flutter/material.dart';
import 'package:ilgabbiano/models/reservation.dart';
import 'package:ilgabbiano/l10n/strings.dart';

typedef ReservationAction = Future<void> Function(String newStatus);

class ReservationCard extends StatefulWidget {
  final Reservation reservation;
  final ReservationAction onAction;
  final VoidCallback? onEdit;

  const ReservationCard({Key? key, required this.reservation, required this.onAction, this.onEdit}) : super(key: key);

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard> with TickerProviderStateMixin {
  bool _expanded = false;
  bool _loading = false;

  Color _statusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.redAccent;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    return AnimatedSize(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedScale(
        duration: Duration(milliseconds: 180),
        scale: _expanded ? 1.01 : 1.0,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.event_note, color: Colors.white), backgroundColor: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${Strings.reservationFor} ${r.people} personnes', style: TextStyle(fontWeight: FontWeight.w600))),
                      Chip(label: Text(r.status), backgroundColor: _statusColor(r.status)),
                      const SizedBox(width: 8),
                      AnimatedRotation(duration: Duration(milliseconds: 180), turns: _expanded ? 0.5 : 0.0, child: Icon(Icons.expand_more)),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 8),
                    Text('Le ${r.date} à ${r.time}'),
                    if ((r.notes ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text(r.notes!)],
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final veryNarrow = maxWidth < 360;
                      final narrow = maxWidth < 480;

                      final menuWidget = PopupMenuButton<String>(
                        onSelected: (s) => _performAction(s),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'pending', child: Text('pending')),
                          PopupMenuItem(value: 'approved', child: Text('approved')),
                          PopupMenuItem(value: 'rejected', child: Text('rejected')),
                        ],
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 120),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_horiz, size: 18), SizedBox(width: 6), Flexible(child: Text('Modifier statut', overflow: TextOverflow.ellipsis))]),
                          ),
                        ),
                      );

                      Widget acceptBtn = veryNarrow
                          ? ElevatedButton(
                              onPressed: () => _performAction('approved'),
                              child: Icon(Icons.check),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(44, 40)),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _performAction('approved'),
                              icon: Icon(Icons.check),
                              label: Text(Strings.approve),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(72, 40)),
                            );

                      Widget rejectBtn = veryNarrow
                          ? ElevatedButton(
                              onPressed: () => _performAction('rejected'),
                              child: Icon(Icons.close),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: Size(44, 40)),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _performAction('rejected'),
                              icon: Icon(Icons.close),
                              label: Text(Strings.reject),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: Size(72, 40)),
                            );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [IconButton(onPressed: widget.onEdit, icon: Icon(Icons.edit_outlined)), SizedBox(width: 8), menuWidget, Spacer(), if (_loading) SizedBox(width: 24, height: 24, child: CircularProgressIndicator())]),
                            const SizedBox(height: 8),
                            Row(children: [Expanded(child: acceptBtn), const SizedBox(width: 8), Expanded(child: rejectBtn)]),
                          ],
                        );
                      }

                      // wide layout
                      return Row(children: [IconButton(onPressed: widget.onEdit, icon: Icon(Icons.edit_outlined)), const SizedBox(width: 8), menuWidget, Spacer(), if (_loading) SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) else ...[acceptBtn, const SizedBox(width: 8), rejectBtn]]);
                    })
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performAction(String status) async {
    setState(() => _loading = true);
    try {
      await widget.onAction(status);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
