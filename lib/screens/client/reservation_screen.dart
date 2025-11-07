import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database_helper.dart';
import '../../models/reservation.dart';
import '../../services/session_manager.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';

class ReservationScreen extends StatefulWidget {
  final Reservation? reservation;

  const ReservationScreen({super.key, this.reservation});

  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _peopleController = TextEditingController();
  final _notesController = TextEditingController();
  int _people = 2;
  final _dbHelper = DatabaseHelper();
  final _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    if (widget.reservation != null) {
      final reservation = widget.reservation!;
      _selectedDate = DateFormat('yyyy-MM-dd').parse(reservation.date);
      final timeParts = reservation.time.split(':');
      _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      _people = reservation.people;
      _peopleController.text = reservation.people.toString();
      _notesController.text = reservation.notes ?? '';
    }
    // initialize people controller when creating new reservation
    if (_peopleController.text.isEmpty) {
      _peopleController.text = _people.toString();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitReservation() async {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedTime != null) {
      final session = await _sessionManager.getUserSession();
      if (session != null) {
        final reservation = Reservation(
          id: widget.reservation?.id,
          userId: session['id'],
          date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
          time: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
          people: int.parse(_peopleController.text),
          notes: _notesController.text,
        );
        if (widget.reservation != null) {
          await _dbHelper.updateReservation(reservation);
          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Réservation modifiée avec succès !')),
          );
        } else {
          await _dbHelper.createReservation(reservation);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Réservation envoyée avec succès !')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Veuillez remplir tous les champs, y compris la date et l\'heure.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reservation != null;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDateLabel = _selectedDate == null
        ? AppLocalizations.of(context).t('choose_date')
        : DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(_selectedDate!);
    final selectedTimeLabel = _selectedTime == null
        ? AppLocalizations.of(context).t('choose_time')
        : _selectedTime!.format(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: isEditing
            ? AppLocalizations.of(context).t('modify')
            : AppLocalizations.of(context).t('reserve_action'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern gradient header with a quick summary
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandPalette.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).t('reservation_details'),
                          style: GoogleFonts.lato(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        _HeaderChip(icon: Icons.calendar_today, label: selectedDateLabel),
                        _HeaderChip(icon: Icons.access_time, label: selectedTimeLabel),
                        _HeaderChip(icon: Icons.people, label: '$_people ${AppLocalizations.of(context).t('people')}'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Time pickers styled as glass cards
                    Row(
                      children: [
                        Expanded(child: _GlassButton(icon: Icons.calendar_today, label: selectedDateLabel, onTap: () => _selectDate(context))),
                        const SizedBox(width: 12),
                        Expanded(child: _GlassButton(icon: Icons.access_time, label: selectedTimeLabel, onTap: () => _pickTime(context))),
                      ],
                    ),
                    if (_selectedDate == null || _selectedTime == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(AppLocalizations.of(context).t('select_date_time'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).t('number_of_people'), style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() { if (_people > 1) _people--; _peopleController.text = _people.toString(); });
                            },
                            icon: Icon(Icons.remove_circle_outline, color: colorScheme.primary),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _peopleController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(border: InputBorder.none),
                              validator: (value) => value == null || value.isEmpty ? AppLocalizations.of(context).t('required_field') : null,
                              onChanged: (v) { final parsed = int.tryParse(v) ?? 1; setState(() { _people = parsed; }); },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() { _people++; _peopleController.text = _people.toString(); });
                            },
                            icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).t('notes_optional'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(isEditing ? Icons.edit : Icons.check),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text(isEditing ? AppLocalizations.of(context).t('modify') : AppLocalizations.of(context).t('reserve_action')),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () { FocusScope.of(context).unfocus(); _submitReservation(); },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.lato(color: Colors.white)),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
