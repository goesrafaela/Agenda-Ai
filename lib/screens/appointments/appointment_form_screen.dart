import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class AppointmentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? appointment;

  const AppointmentFormScreen({super.key, this.appointment});

  bool get isEditing => appointment != null;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _services = [];

  String? _selectedClientId;
  String? _selectedServiceId;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _loadingData = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
      return;
    }

    try {
      final clientsData = await SupabaseService.client
          .from('clients')
          .select('id, name')
          .eq('user_id', user.id)
          .order('name');

      final servicesData = await SupabaseService.client
          .from('services')
          .select('id, name, price, duration_minutes')
          .eq('user_id', user.id)
          .order('name');

      if (!mounted) return;

      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsData);

        _services = List<Map<String, dynamic>>.from(servicesData);

        _loadingData = false;
      });

      _loadAppointmentData();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingData = false;
      });

      _showMessage('Não foi possível carregar os dados.');

      debugPrint('Erro ao carregar clientes e serviços: $error');
    }
  }

  void _loadAppointmentData() {
    final appointment = widget.appointment;

    if (appointment == null) {
      return;
    }

    final clientId = appointment['client_id']?.toString();

    final serviceId = appointment['service_id']?.toString();

    final dateString = appointment['appointment_date']?.toString();

    final timeString = appointment['appointment_time']?.toString();

    setState(() {
      _selectedClientId = clientId;
      _selectedServiceId = serviceId;

      if (dateString != null && dateString.isNotEmpty) {
        _selectedDate = DateTime.tryParse(dateString);
      }

      if (timeString != null && timeString.length >= 5) {
        final parts = timeString.substring(0, 5).split(':');

        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      _priceController.text = appointment['value']?.toString() ?? '';

      _notesController.text = appointment['notes']?.toString() ?? '';
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = selected;
      });
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (selected != null) {
      setState(() {
        _selectedTime = selected;
      });
    }
  }

  void _onServiceChanged(String? serviceId) {
    setState(() {
      _selectedServiceId = serviceId;
    });

    if (serviceId == null) {
      return;
    }

    final service = _services.firstWhere(
      (item) => item['id'].toString() == serviceId,
    );

    final price = service['price'];

    if (price != null) {
      _priceController.text = price.toString().replaceAll('.', ',');
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClientId == null) {
      _showMessage('Selecione um cliente.');
      return;
    }

    if (_selectedServiceId == null) {
      _showMessage('Selecione um serviço.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Selecione uma data.');
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Selecione um horário.');
      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      _showMessage('Usuário não autenticado.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final date =
          '${_selectedDate!.year.toString().padLeft(4, '0')}-'
          '${_selectedDate!.month.toString().padLeft(2, '0')}-'
          '${_selectedDate!.day.toString().padLeft(2, '0')}';

      final time =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final price = double.tryParse(
        _priceController.text.trim().replaceAll(',', '.'),
      );

      final data = {
        'client_id': _selectedClientId,
        'service_id': _selectedServiceId,
        'appointment_date': date,
        'appointment_time': time,
        'value': price ?? 0,
        'notes': _notesController.text.trim(),
      };

      if (widget.isEditing) {
        final appointmentId = widget.appointment!['id'];

        await SupabaseService.client
            .from('appointments')
            .update(data)
            .eq('id', appointmentId)
            .eq('user_id', user.id);
      } else {
        await SupabaseService.client.from('appointments').insert({
          ...data,
          'user_id': user.id,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Atendimento atualizado com sucesso!'
                : 'Atendimento salvo com sucesso!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        widget.isEditing
            ? 'Não foi possível atualizar o atendimento.'
            : 'Não foi possível salvar o atendimento.',
      );

      debugPrint('Erro ao salvar atendimento: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Editar atendimento' : 'Novo atendimento',
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                Text(
                  widget.isEditing ? 'Editar atendimento' : 'Novo atendimento',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.isEditing
                      ? 'Atualize os dados do atendimento.'
                      : 'Agende um atendimento para seu cliente.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 24),

                if (_loadingData)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClientId,

                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),

                    items: _clients.map((client) {
                      return DropdownMenuItem<String>(
                        value: client['id'].toString(),
                        child: Text(client['name']?.toString() ?? 'Sem nome'),
                      );
                    }).toList(),

                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedClientId = value;
                            });
                          },

                    validator: (value) {
                      if (value == null) {
                        return 'Selecione um cliente';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedServiceId,

                    decoration: const InputDecoration(
                      labelText: 'Serviço',
                      prefixIcon: Icon(Icons.work_outline),
                      border: OutlineInputBorder(),
                    ),

                    items: _services.map((service) {
                      final price = service['price'];

                      return DropdownMenuItem<String>(
                        value: service['id'].toString(),
                        child: Text(
                          '${service['name']}'
                          ' — R\$ ${price ?? 0}',
                        ),
                      );
                    }).toList(),

                    onChanged: _saving ? null : _onServiceChanged,

                    validator: (value) {
                      if (value == null) {
                        return 'Selecione um serviço';
                      }

                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),

                InkWell(
                  onTap: _saving ? null : _selectDate,

                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),

                    child: Text(
                      _selectedDate == null
                          ? 'Selecione a data'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.year}',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: _saving ? null : _selectTime,

                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Horário',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),

                    child: Text(
                      _selectedTime == null
                          ? 'Selecione o horário'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,

                  maxLines: 4,

                  textCapitalization: TextCapitalization.sentences,

                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,

                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAppointment,

                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),

                    label: Text(
                      _saving
                          ? 'Salvando...'
                          : widget.isEditing
                          ? 'Salvar alterações'
                          : 'Salvar atendimento',

                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
