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

  String _searchText = '';
  String _statusFilter = 'all';

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

  List<Map<String, dynamic>> get _filteredAppointments {
    return _appointments.where((appointment) {
      final client = appointment['clients'] as Map<String, dynamic>?;

      final service = appointment['services'] as Map<String, dynamic>?;

      final clientName = client?['name']?.toString().toLowerCase() ?? '';

      final serviceName = service?['name']?.toString().toLowerCase() ?? '';

      final search = _searchText.trim().toLowerCase();

      final matchesSearch =
          search.isEmpty ||
          clientName.contains(search) ||
          serviceName.contains(search);

      final status = appointment['status']?.toString() ?? 'pending';

      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
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

    final clientName = client?['name']?.toString() ?? 'Cliente';

    final phone = client?['phone']?.toString().trim() ?? '';

    final service = appointment['services'] as Map<String, dynamic>?;

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

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    if (!cleanPhone.startsWith('55')) {
      cleanPhone = '55$cleanPhone';
    }

    final formattedDate = date.isNotEmpty ? _formatDate(date) : '';

    final formattedTime = time.isNotEmpty ? _formatTime(time) : '';

    final message =
        'Olá, $clientName! 👋\n\n'
        'Passando para lembrar do seu atendimento.\n\n'
        '📅 Data: $formattedDate\n'
        '🕐 Horário: $formattedTime\n'
        '✂️ Serviço: $serviceName\n\n'
        'Até lá! 😊';

    final encodedMessage = Uri.encodeComponent(message);

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

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Recebido';
      case 'cancelled':
        return 'Cancelado';
      case 'pending':
      default:
        return 'Pendente';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _statusFilter == value;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
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

    final status = appointment['status']?.toString() ?? 'pending';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatValue(value),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
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

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateTitle(date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 18),
                  Icon(
                    Icons.access_time_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(_formatTime(time)),
                  const Spacer(),
                  _buildStatusChip(status),
                ],
              ),
            ),

            if (appointment['notes']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment['notes'].toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: phone.isEmpty
                    ? null
                    : () => _openWhatsApp(appointment),
                icon: const Icon(Icons.chat_outlined),
                label: Text(
                  phone.isEmpty
                      ? 'Cliente sem telefone'
                      : 'Enviar lembrete pelo WhatsApp',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchText.isNotEmpty || _statusFilter != 'all';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.calendar_month_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasFilters
                  ? 'Nenhum atendimento encontrado'
                  : 'Nenhum atendimento cadastrado',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Tente alterar a busca ou o filtro.'
                  : 'Adicione seu primeiro atendimento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppointments = _filteredAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  const Text(
                    'Minha agenda',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Organize seus próximos atendimentos.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente ou serviço...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  _searchText = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Todos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('pending', 'Pendentes'),
                        const SizedBox(width: 8),
                        _buildFilterChip('paid', 'Recebidos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('cancelled', 'Cancelados'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (filteredAppointments.isEmpty)
                    SizedBox(height: 420, child: _buildEmptyState())
                  else
                    ...filteredAppointments.map(
                      (appointment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAppointmentCard(appointment),
                      ),
                    ),
                ],
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
}
