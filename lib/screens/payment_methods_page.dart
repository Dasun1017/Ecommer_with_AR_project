import 'package:flutter/material.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final List<PaymentMethod> _paymentMethods = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Payment Methods')),
      body: _paymentMethods.isEmpty
          ? _buildEmptyState()
          : _buildPaymentMethodsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentMethodDialog,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Method'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.credit_card_off,
                  size: 68, color: Colors.blue.shade700),
              const SizedBox(height: 16),
              Text(
                'No Payment Methods',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a payment method to make checkout faster',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _showAddPaymentMethodDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Payment Method'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        return _buildPaymentMethodCard(_paymentMethods[index], index);
      },
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method, int index) {
    final icon = switch (method.type) {
      PaymentType.creditCard => Icons.credit_card,
      PaymentType.debitCard => Icons.payment,
      PaymentType.bankAccount => Icons.account_balance,
      PaymentType.digitalWallet => Icons.wallet,
    };
    final color = switch (method.type) {
      PaymentType.creditCard => Colors.blue,
      PaymentType.debitCard => Colors.teal,
      PaymentType.bankAccount => Colors.purple,
      PaymentType.digitalWallet => Colors.orange,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color),
        ),
        title: Text(
          method.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(method.maskedNumber),
            if (method.isDefault) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            if (!method.isDefault)
              const PopupMenuItem(
                value: 'default',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Set as Default'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'default':
                _setAsDefault(index);
                break;
              case 'edit':
                _showEditPaymentMethodDialog(method, index);
                break;
              case 'delete':
                _deletePaymentMethod(index);
                break;
            }
          },
        ),
      ),
    );
  }

  void _showAddPaymentMethodDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    PaymentType selectedType = PaymentType.creditCard;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDialogHeader(
                    icon: Icons.add_card_outlined,
                    title: 'Add Payment Method',
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<PaymentType>(
                    initialValue: selectedType,
                    decoration: _fieldDecoration('Payment Type'),
                    items: PaymentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getPaymentTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: _fieldDecoration('Name on Card/Account'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: numberController,
                    decoration: _fieldDecoration('Card/Account Number'),
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty ||
                            numberController.text.isEmpty) {
                          return;
                        }

                        setState(() {
                          _paymentMethods.add(
                            PaymentMethod(
                              type: selectedType,
                              name: nameController.text,
                              maskedNumber: _maskNumber(numberController.text),
                              isDefault: _paymentMethods.isEmpty,
                            ),
                          );
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment method added successfully'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPaymentMethodDialog(PaymentMethod method, int index) {
    final nameController = TextEditingController(text: method.name);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.edit_outlined,
                title: 'Edit Payment Method',
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                decoration: _fieldDecoration('Name on Card/Account'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) return;

                  setState(() {
                    _paymentMethods[index] = PaymentMethod(
                      type: method.type,
                      name: nameController.text,
                      maskedNumber: method.maskedNumber,
                      isDefault: method.isDefault,
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment method updated')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _setAsDefault(int index) {
    setState(() {
      for (var i = 0; i < _paymentMethods.length; i++) {
        _paymentMethods[i] = PaymentMethod(
          type: _paymentMethods[i].type,
          name: _paymentMethods[i].name,
          maskedNumber: _paymentMethods[i].maskedNumber,
          isDefault: i == index,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default payment method updated')),
    );
  }

  void _deletePaymentMethod(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.delete_outline,
                title: 'Delete Payment Method',
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to delete this payment method?',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final wasDefault = _paymentMethods[index].isDefault;
                    _paymentMethods.removeAt(index);

                    if (wasDefault && _paymentMethods.isNotEmpty) {
                      _paymentMethods[0] = PaymentMethod(
                        type: _paymentMethods[0].type,
                        name: _paymentMethods[0].name,
                        maskedNumber: _paymentMethods[0].maskedNumber,
                        isDefault: true,
                      );
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment method deleted')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskNumber(String number) {
    if (number.length <= 4) return number;
    final lastFour = number.substring(number.length - 4);
    return '**** **** **** $lastFour';
  }

  String _getPaymentTypeLabel(PaymentType type) {
    return switch (type) {
      PaymentType.creditCard => 'Credit Card',
      PaymentType.debitCard => 'Debit Card',
      PaymentType.bankAccount => 'Bank Account',
      PaymentType.digitalWallet => 'Digital Wallet',
    };
  }
}

enum PaymentType {
  creditCard,
  debitCard,
  bankAccount,
  digitalWallet,
}

class PaymentMethod {
  final PaymentType type;
  final String name;
  final String maskedNumber;
  final bool isDefault;

  PaymentMethod({
    required this.type,
    required this.name,
    required this.maskedNumber,
    this.isDefault = false,
  });
}
