import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _loading = true;

  List<Map<String, dynamic>> _appointments = [];

  double _totalReceived = 0;
  double _totalPending = 0;
  double _totalExpected = 0;
  double _totalCancelled = 0;

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  Future<void> _loadFinance() async {
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
            appointment_date,
            appointment_time,
            value,
            payment_status,
            clients (
              name
            ),
            services (
              name
            )
          ''')
          .eq('user_id', user.id)
          .order('appointment_date', ascending: false)
          .order('appointment_time', ascending: false);

      double received = 0;
      double pending = 0;
      double cancelled = 0;

      for (final appointment in data) {
        final value =
            double.tryParse(appointment['value']?.toString() ?? '0') ?? 0;

        final status =
            appointment['payment_status']?.toString().toLowerCase() ??
            'pending';

        if (status == 'paid') {
          received += value;
        } else if (status == 'cancelled') {
          cancelled += value;
        } else {
          pending += value;
        }
      }

      if (!mounted) return;

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(data);
        _totalReceived = received;
        _totalPending = pending;
        _totalCancelled = cancelled;
        _totalExpected = received + pending;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar o financeiro.'),
        ),
      );

      debugPrint('Erro ao carregar financeiro: $error');
    }
  }

  Future<void> _changePaymentStatus(Map<String, dynamic> appointment) async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final id = appointment['id'];

    final currentStatus =
        appointment['payment_status']?.toString().toLowerCase() ?? 'pending';

    String newStatus;

    if (currentStatus == 'paid') {
      newStatus = 'pending';
    } else {
      newStatus = 'paid';
    }

    try {
      await SupabaseService.client
          .from('appointments')
          .update({'payment_status': newStatus})
          .eq('id', id)
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'paid'
                ? 'Pagamento marcado como recebido.'
                : 'Pagamento marcado como pendente.',
          ),
        ),
      );

      await _loadFinance();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar o pagamento.'),
        ),
      );

      debugPrint('Erro ao atualizar pagamento: $error');
    }
  }

  Future<void> _cancelPayment(Map<String, dynamic> appointment) async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar pagamento?'),
          content: const Text(
            'Esse atendimento será marcado como cancelado e não entrará nos valores a receber.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await SupabaseService.client
          .from('appointments')
          .update({'payment_status': 'cancelled'})
          .eq('id', appointment['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento marcado como cancelado.')),
      );

      await _loadFinance();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível cancelar o atendimento.'),
        ),
      );

      debugPrint('Erro ao cancelar atendimento: $error');
    }
  }

  Future<void> _restoreCancelled(Map<String, dynamic> appointment) async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await SupabaseService.client
          .from('appointments')
          .update({'payment_status': 'pending'})
          .eq('id', appointment['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento voltou para pendente.')),
      );

      await _loadFinance();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível restaurar o atendimento.'),
        ),
      );

      debugPrint('Erro ao restaurar atendimento: $error');
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

  String _statusText(String status) {
    switch (status) {
      case 'paid':
        return 'Recebido';

      case 'cancelled':
        return 'Cancelado';

      default:
        return 'Pendente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green.shade700;

      case 'cancelled':
        return Colors.red.shade700;

      default:
        return Colors.orange.shade700;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.pending_actions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadFinance,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFinance,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Meu financeiro',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Acompanhe seus recebimentos.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 24),

                  _FinanceCard(
                    titulo: 'Total previsto',
                    valor: _formatValue(_totalExpected),
                    icone: Icons.account_balance_wallet_outlined,
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _FinanceCard(
                          titulo: 'Recebido',
                          valor: _formatValue(_totalReceived),
                          icone: Icons.check_circle_outline,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _FinanceCard(
                          titulo: 'Pendente',
                          valor: _formatValue(_totalPending),
                          icone: Icons.pending_actions,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _FinanceCard(
                    titulo: 'Cancelado',
                    valor: _formatValue(_totalCancelled),
                    icone: Icons.cancel_outlined,
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Movimentações',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (_appointments.isEmpty)
                    _buildEmptyState()
                  else
                    ..._appointments.map(
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

    final status =
        appointment['payment_status']?.toString().toLowerCase() ?? 'pending';

    final isPaid = status == 'paid';
    final isCancelled = status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(_statusIcon(status))),

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 17),

                const SizedBox(width: 8),

                Text(_formatDate(date)),

                const SizedBox(width: 16),

                const Icon(Icons.access_time, size: 17),

                const SizedBox(width: 8),

                Text(_formatTime(time)),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _statusColor(status).withOpacity(0.12),
                    ),
                    child: Text(
                      _statusText(status),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                if (isCancelled)
                  FilledButton.icon(
                    onPressed: () => _restoreCancelled(appointment),
                    icon: const Icon(Icons.undo),
                    label: const Text('Restaurar'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _changePaymentStatus(appointment),
                    icon: Icon(isPaid ? Icons.undo : Icons.check),
                    label: Text(isPaid ? 'Pendente' : 'Receber'),
                  ),
              ],
            ),

            if (!isCancelled) ...[
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _cancelPayment(appointment),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar atendimento'),
                ),
              ),
            ],
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
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            Text(
              'Nenhuma movimentação',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 8),

            Text(
              'Seus atendimentos aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _FinanceCard({
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
