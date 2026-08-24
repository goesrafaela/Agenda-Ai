import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;

  int _todayAppointments = 0;
  double _todayReceived = 0;
  double _todayPending = 0;

  double _totalReceived = 0;
  double _totalPending = 0;
  double _totalExpected = 0;

  int _totalClients = 0;
  int _totalServices = 0;

  List<Map<String, dynamic>> _upcomingAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
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
      final now = DateTime.now();

      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      // =========================
      // CLIENTES
      // =========================

      final clientsData = await SupabaseService.client
          .from('clients')
          .select('id')
          .eq('user_id', user.id);

      // =========================
      // SERVIÇOS
      // =========================

      final servicesData = await SupabaseService.client
          .from('services')
          .select('id')
          .eq('user_id', user.id);

      // =========================
      // TODOS OS ATENDIMENTOS
      // IMPORTANTE:
      // usamos "status", igual à Agenda
      // =========================

      final appointmentsData = await SupabaseService.client
          .from('appointments')
          .select('''
            id,
            appointment_date,
            appointment_time,
            value,
            status,
            clients (
              name
            ),
            services (
              name
            )
          ''')
          .eq('user_id', user.id)
          .order('appointment_date')
          .order('appointment_time');

      double totalReceived = 0;
      double totalPending = 0;

      double todayReceived = 0;
      double todayPending = 0;

      int todayAppointments = 0;

      final upcoming = <Map<String, dynamic>>[];

      // =========================
      // CALCULAR FINANCEIRO
      // =========================

      for (final item in appointmentsData) {
        final appointment = Map<String, dynamic>.from(item);

        final value =
            double.tryParse(appointment['value']?.toString() ?? '0') ?? 0;

        final status = appointment['status']?.toString() ?? 'pending';

        final date = appointment['appointment_date']?.toString() ?? '';

        // -------------------------
        // TOTAL GERAL
        // -------------------------

        if (status == 'paid') {
          totalReceived += value;
        } else if (status == 'pending') {
          totalPending += value;
        }

        // -------------------------
        // ATENDIMENTOS DE HOJE
        // -------------------------

        if (date == today) {
          todayAppointments++;

          if (status == 'paid') {
            todayReceived += value;
          } else if (status == 'pending') {
            todayPending += value;
          }
        }

        // -------------------------
        // PRÓXIMOS ATENDIMENTOS
        // -------------------------

        if (date.compareTo(today) >= 0 && upcoming.length < 5) {
          upcoming.add(appointment);
        }
      }

      if (!mounted) return;

      setState(() {
        _totalClients = clientsData.length;
        _totalServices = servicesData.length;

        _todayAppointments = todayAppointments;
        _todayReceived = todayReceived;
        _todayPending = todayPending;

        _totalReceived = totalReceived;
        _totalPending = totalPending;
        _totalExpected = totalReceived + totalPending;

        _upcomingAppointments = upcoming;

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar o dashboard.')),
      );

      debugPrint('Erro ao carregar dashboard: $error');
    }
  }

  String _formatValue(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
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

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Bom dia! 👋';
    }

    if (hour < 18) {
      return 'Boa tarde! 👋';
    }

    return 'Boa noite! 👋';
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

  Future<void> _updateStatus(
    Map<String, dynamic> appointment,
    String newStatus,
  ) async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) return;

    final oldStatus = appointment['status']?.toString() ?? 'pending';

    try {
      await SupabaseService.client
          .from('appointments')
          .update({'status': newStatus})
          .eq('id', appointment['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status alterado para ${_statusLabel(newStatus)}.'),
        ),
      );

      // Recarrega TODOS os valores do dashboard
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível alterar o status.')),
      );

      debugPrint('Erro ao atualizar status: $error');
    }
  }

  Widget _buildStatusButton(Map<String, dynamic> appointment) {
    final status = appointment['status']?.toString() ?? 'pending';

    final color = _statusColor(status);

    return PopupMenuButton<String>(
      onSelected: (newStatus) {
        if (newStatus != status) {
          _updateStatus(appointment, newStatus);
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 'pending',
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange),
                SizedBox(width: 8),
                Text('Pendente'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'paid',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 8),
                Text('Recebido'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'cancelled',
            child: Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text('Cancelado'),
              ],
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
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
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Autônomos'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Aqui está o resumo do seu dia.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 24),

                  // =========================
                  // HOJE
                  // =========================
                  Row(
                    children: [
                      Expanded(
                        child: _ResumoCard(
                          titulo: 'Hoje',
                          valor: _todayAppointments.toString(),
                          icone: Icons.calendar_today,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _ResumoCard(
                          titulo: 'A receber hoje',
                          valor: _formatValue(_todayPending),
                          icone: Icons.pending_actions,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // RECEBIDO HOJE
                  // =========================
                  Row(
                    children: [
                      Expanded(
                        child: _ResumoCard(
                          titulo: 'Recebido hoje',
                          valor: _formatValue(_todayReceived),
                          icone: Icons.check_circle_outline,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _ResumoCard(
                          titulo: 'Clientes',
                          valor: _totalClients.toString(),
                          icone: Icons.people_outline,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // FINANCEIRO GERAL
                  // =========================
                  _ResumoCard(
                    titulo: 'Total a receber',
                    valor: _formatValue(_totalPending),
                    icone: Icons.account_balance_wallet_outlined,
                  ),

                  const SizedBox(height: 12),

                  _ResumoCard(
                    titulo: 'Total recebido',
                    valor: _formatValue(_totalReceived),
                    icone: Icons.attach_money,
                  ),

                  const SizedBox(height: 12),

                  _ResumoCard(
                    titulo: 'Total previsto',
                    valor: _formatValue(_totalExpected),
                    icone: Icons.account_balance_outlined,
                  ),

                  const SizedBox(height: 32),

                  // =========================
                  // PRÓXIMOS ATENDIMENTOS
                  // =========================
                  const Text(
                    'Próximos atendimentos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (_upcomingAppointments.isEmpty)
                    _buildEmptyState()
                  else
                    ..._upcomingAppointments.map(
                      (appointment) => _buildAppointmentCard(appointment),
                    ),
                ],
              ),
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

    final value = double.tryParse(appointment['value']?.toString() ?? '0') ?? 0;

    final status = appointment['status']?.toString() ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                          fontSize: 17,
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // STATUS
            _buildStatusButton(appointment),

            const Divider(height: 24),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 17),

                const SizedBox(width: 8),

                Text(_formatDate(date)),

                const SizedBox(width: 20),

                const Icon(Icons.access_time, size: 17),

                const SizedBox(width: 8),

                Text(_formatTime(time)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),

            const SizedBox(height: 16),

            Text(
              'Nenhum atendimento agendado',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 8),

            Text(
              'Seus próximos atendimentos aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _ResumoCard({
    required this.titulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 28),

            const SizedBox(height: 12),

            Text(titulo, style: const TextStyle(fontSize: 14)),

            const SizedBox(height: 4),

            Text(
              valor,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
