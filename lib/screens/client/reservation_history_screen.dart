import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/reservation_screen.dart';
import '../../db/database_helper.dart';
import '../../models/reservation.dart';
import '../../services/session_manager.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';

class ReservationHistoryScreen extends StatefulWidget {
  const ReservationHistoryScreen({super.key});
  @override
  _ReservationHistoryScreenState createState() => _ReservationHistoryScreenState();
}

class _ReservationHistoryScreenState extends State<ReservationHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();
  late Future<List<Reservation>> _reservationsFuture;
  String _filter = 'all'; // all | pending | approved | rejected

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
          var reservations = snapshot.data!;
          if (_filter != 'all') {
            reservations = reservations.where((r) => r.status == _filter).toList();
          }
          return Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatusChip(label: 'Tous', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'En attente', selected: _filter == 'pending', onTap: () => setState(() => _filter = 'pending')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Approuvée', selected: _filter == 'approved', onTap: () => setState(() => _filter = 'approved')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Rejetée', selected: _filter == 'rejected', onTap: () => setState(() => _filter = 'rejected')),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: reservations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemBuilder: (context, index) {
                    final r = reservations[index];
                    final canModify = r.status == 'pending';
                    final dateLabel = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(DateTime.parse(r.date));
                    final timeLabel = r.time;
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: BrandPalette.reservationsGradient),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.event, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${AppLocalizations.of(context).t('reservation_for')} ${r.people} ${AppLocalizations.of(context).t('people')}',
                                          style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text('$dateLabel • $timeLabel', style: GoogleFonts.lato(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                _StatusPill(status: r.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if ((r.notes ?? '').isNotEmpty)
                              Text(r.notes!, style: GoogleFonts.lato(color: Colors.black87)),
                            if (canModify)
                              Column(
                                children: [
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.edit),
                                          label: Text(AppLocalizations.of(context).t('modify')),
                                          onPressed: () => _navigateToEditScreen(r),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.delete),
                                          label: Text(AppLocalizations.of(context).t('delete')),
                                          onPressed: () => _deleteReservation(r.id!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ],
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg = Colors.white;
    switch (status) {
      case 'approved':
        bg = Colors.green;
        break;
      case 'rejected':
        bg = Colors.redAccent;
        break;
      default:
        bg = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: selected ? Theme.of(context).colorScheme.primary : null, fontWeight: FontWeight.w700),
      shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
    );
  }
}
