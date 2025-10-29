import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/reservation_screen.dart';
import '../../db/database_helper.dart';
import '../../models/reservation.dart';
import '../../services/session_manager.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class ReservationHistoryScreen extends StatefulWidget {
  @override
  _ReservationHistoryScreenState createState() => _ReservationHistoryScreenState();
}

class _ReservationHistoryScreenState extends State<ReservationHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = _getReservations();
  }

  Future<List<Reservation>> _getReservations() async {
    final session = await _sessionManager.getUserSession();
    if (session != null) {
      return _dbHelper.getUserReservations(session['id']);
    } else {
      return Future.value([]);
    }
  }

  void _navigateToEditScreen(Reservation reservation) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReservationScreen(reservation: reservation),
      ),
    );
    if (result == true) {
      setState(() {
        _reservationsFuture = _getReservations();
      });
    }
  }

  void _deleteReservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteReservation(id);
      setState(() {
        _reservationsFuture = _getReservations();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Réservation supprimée avec succès.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('reservation_history'))),
      body: FutureBuilder<List<Reservation>>(
        future: _reservationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context).t('no_reservations')));
          }
          final reservations = snapshot.data!;
          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              final canModify = reservation.status == 'pending';
              return ListTile(
                title: Text('${AppLocalizations.of(context).t('reservation_for')} ${reservation.people} personnes'),
                subtitle: Text(AppLocalizations.of(context).t('reservation_on_at').replaceFirst('{date}', reservation.date).replaceFirst('{time}', reservation.time)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reservation.status,
                      style: TextStyle(
                        color: reservation.status == 'approved'
                            ? Colors.green
                            : reservation.status == 'rejected'
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                    if (canModify) ...[
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _navigateToEditScreen(reservation),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteReservation(reservation.id!),
                      ),
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
