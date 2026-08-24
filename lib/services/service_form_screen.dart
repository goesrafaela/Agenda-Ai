import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../screens/services/service_form_screen.dart';
import 'service_form_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
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
          .from('services')
          .select()
          .eq('user_id', user.id)
          .order('name');

      if (!mounted) return;

      setState(() {
        _services = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os serviços.')),
      );

      debugPrint('Erro ao carregar serviços: $error');
    }
  }

  Future<void> _openNewService() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServiceFormScreen()),
    );

    _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Serviços')),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Meus serviços',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Cadastre os serviços que você oferece.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _services.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: _services.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final service = _services[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.work_outline),
                            ),
                            title: Text(
                              service['name']?.toString() ?? 'Sem nome',
                            ),
                            subtitle: Text(
                              '${service['duration_minutes'] ?? 0} minutos',
                            ),
                            trailing: Text(
                              'R\$ ${service['price'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewService,
        icon: const Icon(Icons.add),
        label: const Text('Novo serviço'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 72, color: Colors.grey.shade400),

          const SizedBox(height: 16),

          Text(
            'Nenhum serviço cadastrado',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 8),

          Text(
            'Adicione seu primeiro serviço.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
