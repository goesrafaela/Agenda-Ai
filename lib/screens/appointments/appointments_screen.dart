import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import 'appointment_form_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final data = await SupabaseService.client
          .from('appointments')
          .select('''
            id,
            client_id,
            service_id,
            appointment_date,
            appointment_time,
            value,
            notes,
            status,
            clients (
              name,
              phone
            ),
            services (
              name,
              duration_minutes
            )
          ''')
          .eq('user_id', user.id)
          .order('appointment_date')
          .order('appointment_time');

      if (!mounted) return;

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os atendimentos.'),
        ),
      );

      debugPrint('Erro ao carregar atendimentos: $error');
    }
  }

  String _formatDate(String date) {
    final parsed = DateTime.parse(date);

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  String _formatTime(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }

    return time;
  }

  String _formatValue(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    return 'R\$ ${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  bool _isToday(String date) {
    final appointmentDate = DateTime.parse(date);
    final now = DateTime.now();

    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  bool _isTomorrow(String date) {
    final appointmentDate = DateTime.parse(date);
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return appointmentDate.year == tomorrow.year &&
        appointmentDate.month == tomorrow.month &&
        appointmentDate.day == tomorrow.day;
  }

  String _dateTitle(String date) {
    if (_isToday(date)) {
      return 'Hoje';
    }

    if (_isTomorrow(date)) {
      return 'Amanhã';
    }

    return _formatDate(date);
  }

  Future<void> _editAppointment(Map<String, dynamic> appointment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentFormScreen(appointment: appointment),
      ),
    );

    _loadAppointments();
  }

  Future<void> _deleteAppointment(Map<String, dynamic> appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir atendimento?'),
          content: const Text('Essa ação não poderá ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await SupabaseService.client
          .from('appointments')
          .delete()
          .eq('id', appointment['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento excluído com sucesso!')),
      );

      _loadAppointments();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível excluir o atendimento.'),
        ),
      );

      debugPrint('Erro ao excluir atendimento: $error');
    }
  }

  Future<void> _openWhatsApp(Map<String, dynamic> appointment) async {
    final client = appointment['clients'] as Map<String, dynamic>?;

    final service = appointment['services'] as Map<String, dynamic>?;

    final clientName = client?['name']?.toString() ?? 'Cliente';

    final phone = client?['phone']?.toString().trim() ?? '';

    final serviceName = service?['name']?.toString() ?? 'atendimento';

    final date = appointment['appointment_date']?.toString() ?? '';

    final time = appointment['appointment_time']?.toString() ?? '';

    if (phone.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente não possui telefone cadastrado.'),
        ),
      );

      return;
    }

    // Remove espaços, parênteses, traços e outros caracteres.
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove zero inicial caso exista.
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Adiciona o código do Brasil.
    if (!cleanPhone.startsWith('55')) {
      cleanPhone = '55$cleanPhone';
    }

    final formattedDate = date.isNotEmpty ? _formatDate(date) : '';

    final formattedTime = time.isNotEmpty ? _formatTime(time) : '';

    final message =
        'Olá, $clientName! 👋\n\n'
        'Passando para lembrar do seu atendimento.\n\n'
        'Data: $formattedDate\n'
        'Horário: $formattedTime\n'
        'Serviço: $serviceName\n\n'
        'Até lá! 😊';

    final encodedMessage = Uri.encodeComponent(message);

    // IMPORTANTE:
    // Esta é a URL correta do WhatsApp.
    final whatsappUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );

    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );

      debugPrint('Erro ao abrir WhatsApp: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Minha agenda',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Seus próximos atendimentos',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _appointments.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _appointments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final appointment = _appointments[index];

                          return _buildAppointmentCard(appointment);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppointmentFormScreen(),
            ),
          );

          _loadAppointments();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo atendimento'),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final client = appointment['clients'] as Map<String, dynamic>?;

    final service = appointment['services'] as Map<String, dynamic>?;

    final clientName = client?['name']?.toString() ?? 'Cliente';

    final serviceName = service?['name']?.toString() ?? 'Serviço';

    final date = appointment['appointment_date']?.toString() ?? '';

    final time = appointment['appointment_time']?.toString() ?? '';

    final value = appointment['value'];

    final phone = client?['phone']?.toString().trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.person)),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        serviceName,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                Text(
                  _formatValue(value),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editAppointment(appointment);
                    }

                    if (value == 'delete') {
                      _deleteAppointment(appointment);
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 8),
                            Text('Excluir'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),

                const SizedBox(width: 8),

                Text(
                  _dateTitle(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(width: 20),

                const Icon(Icons.access_time, size: 18),

                const SizedBox(width: 8),

                Text(_formatTime(time)),
              ],
            ),

            if (appointment['notes']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 12),

              Text(
                appointment['notes'].toString(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: phone.isEmpty
                    ? null
                    : () => _openWhatsApp(appointment),
                icon: const Icon(Icons.chat),
                label: Text(
                  phone.isEmpty
                      ? 'WhatsApp sem telefone'
                      : 'Enviar lembrete no WhatsApp',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 72, color: Colors.grey.shade400),

          const SizedBox(height: 16),

          Text(
            'Nenhum atendimento cadastrado',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 8),

          Text(
            'Adicione seu primeiro atendimento.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
