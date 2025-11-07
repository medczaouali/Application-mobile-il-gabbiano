import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../models/reservation.dart';
import '../../widgets/reservation_card.dart';
import '../../screens/client/reservation_screen.dart';
import '../../l10n/strings.dart';

class ManageReservationsScreen extends StatefulWidget {
  const ManageReservationsScreen({super.key});
  @override
  _ManageReservationsScreenState createState() => _ManageReservationsScreenState();
}

class _ManageReservationsScreenState extends State<ManageReservationsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.manageReservationsTitle)),
      body: Column(
        children: [
          // Filters by status
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('all', 'Toutes'),
                _buildFilterChip('pending', 'En attente'),
                _buildFilterChip('approved', 'Approuvées'),
                _buildFilterChip('rejected', 'Rejetées'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _dbHelper.getReservationsWithUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                var rows = snapshot.data!;
                if (_statusFilter != 'all') {
                  rows = rows.where((r) => (r['status'] as String) == _statusFilter).toList();
                }
                if (rows.isEmpty) {
                  return Center(child: Text('Aucune réservation'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final reservation = Reservation.fromMap(row);
                    final userName = row['user_name'] as String?;
                    final userImg = row['user_profile_image'] as String?;
                    final currentDate = row['date'] as String;
                    final previousDate = index > 0 ? rows[index - 1]['date'] as String : '';

                    final widgets = <Widget>[];
                    if (index == 0 || currentDate != previousDate) {
                      widgets.add(Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          currentDate,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                        ),
                      ));
                    }

                    widgets.add(
                      ReservationCard(
                        reservation: reservation,
                        userName: userName,
                        userProfileImage: userImg,
                        onEdit: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => ReservationScreen(reservation: reservation)))
                            .then((_) => setState(() {})),
                        onAction: (newStatus) async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text(Strings.confirmReservationChangeTitle),
                              content: Text(Strings.confirmReservationChangeMessage),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(Strings.cancel)),
                                ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(Strings.confirm)),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final previous = reservation.status;
                            await _dbHelper.updateReservationStatus(reservation.id!, newStatus);
                            setState(() {});

                            final snack = SnackBar(
                              content: Text(Strings.reservationUpdated),
                              action: SnackBarAction(
                                label: Strings.undo,
                                onPressed: () async {
                                  await _dbHelper.updateReservationStatus(reservation.id!, previous);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.reservationReverted)));
                                },
                              ),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(snack);
                          }
                        },
                      ),
                    );

                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _statusFilter == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: selected ? Icon(Icons.check, size: 18) : null,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}
