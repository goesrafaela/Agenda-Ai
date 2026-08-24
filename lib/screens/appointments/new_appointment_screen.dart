import 'package:flutter/material.dart';

class NewAppointmentScreen extends StatefulWidget {
  const NewAppointmentScreen({super.key});

  @override
  State<NewAppointmentScreen> createState() => _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends State<NewAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientController = TextEditingController();
  final _serviceController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _clientController.dispose();
    _serviceController.dispose();
    _valueController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _saveAppointment() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data e o horário.')),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atendimento preenchido com sucesso!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo atendimento')),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            TextFormField(
              controller: _clientController,
              decoration: const InputDecoration(
                labelText: 'Cliente',
                hintText: 'Nome do cliente',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o cliente';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _serviceController,
              decoration: const InputDecoration(
                labelText: 'Serviço',
                hintText: 'Ex.: Corte de cabelo',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o serviço';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor',
                hintText: 'Ex.: 80,00',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o valor';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,

              leading: const Icon(Icons.calendar_month),

              title: const Text('Data'),

              subtitle: Text(
                _selectedDate == null
                    ? 'Selecione a data'
                    : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                          '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                          '${_selectedDate!.year}',
              ),

              trailing: const Icon(Icons.chevron_right),

              onTap: _selectDate,
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,

              leading: const Icon(Icons.access_time),

              title: const Text('Horário'),

              subtitle: Text(
                _selectedTime == null
                    ? 'Selecione o horário'
                    : _selectedTime!.format(context),
              ),

              trailing: const Icon(Icons.chevron_right),

              onTap: _selectTime,
            ),

            const Divider(),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Alguma observação?',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,

              child: FilledButton.icon(
                onPressed: _saveAppointment,

                icon: const Icon(Icons.check),

                label: const Text(
                  'Salvar atendimento',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
