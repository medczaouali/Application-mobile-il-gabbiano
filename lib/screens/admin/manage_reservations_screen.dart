import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../models/reservation.dart';
import '../../widgets/reservation_card.dart';
import '../../screens/client/reservation_screen.dart';
import '../../l10n/strings.dart';

class ManageReservationsScreen extends StatefulWidget {
  @override
  _ManageReservationsScreenState createState() => _ManageReservationsScreenState();
}

class _ManageReservationsScreenState extends State<ManageReservationsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.manageReservationsTitle)),
      body: FutureBuilder<List<Reservation>>(
        future: _dbHelper.getReservations(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final reservations = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              return ReservationCard(
                reservation: reservation,
                onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReservationScreen(reservation: reservation))).then((_) => setState(() {})),
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
              );
            },
          );
        },
      ),
    );
  }
}
