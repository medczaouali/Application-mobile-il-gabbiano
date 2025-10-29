import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _paymentMethod = 'Sur place';
  TimeOfDay _selectedTime = TimeOfDay.now();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final session = await _sessionManager.getUserSession();
    if (session == null) return;

    final order = Order(
      userId: session['id'],
      items: cart.items.map((cartItem) => cartItem.menuItem!).toList(),
      total: cart.totalPrice,
      pickupTime: _selectedTime.format(context),
      paymentMethod: _paymentMethod,
    );

    await _dbHelper.createOrder(order);
    await cart.clearCart();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande passée avec succès!')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('finalize_order'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).t('summary'), style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ...cart.items.map((item) => ListTile(
                          title: Text('${item.quantity}x ${item.menuItem!.name}'),
                          trailing: Text('${(item.menuItem!.price * item.quantity).toStringAsFixed(2)}€'),
                        )),
                    Divider(height: 1),
                    ListTile(
                      title: Text(AppLocalizations.of(context).t('total'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      trailing: Text('${cart.totalPrice.toStringAsFixed(2)}€', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(AppLocalizations.of(context).t('chosen_time'), style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('${AppLocalizations.of(context).t('chosen_time')}: ${_selectedTime.format(context)}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectTime(context),
                ),
              ),
              SizedBox(height: 20),
              Text(AppLocalizations.of(context).t('payment_method'), style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(AppLocalizations.of(context).t('pay_on_spot')),
                      value: 'Sur place',
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(AppLocalizations.of(context).t('credit_card_sim')),
                      value: 'Carte',
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.check_circle_outline),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _submitOrder,
                  label: Text(AppLocalizations.of(context).t('confirm_order')),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }
}
