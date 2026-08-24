import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import 'client_form_screen.dart';
import 'client_edit_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
    });

    try {
      final user = SupabaseService.client.auth.currentUser;

      if (user == null) {
        return;
      }

      final data = await SupabaseService.client
          .from('clients')
          .select()
          .eq('user_id', user.id)
          .order('name');

      if (!mounted) return;

      setState(() {
        _clients = List<Map<String, dynamic>>.from(data);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os clientes.')),
      );

      debugPrint('Erro ao carregar clientes: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNewClient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientFormScreen()),
    );

    _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),

      body: RefreshIndicator(
        onRefresh: _loadClients,

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'Meus clientes',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Gerencie seus clientes',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewClient,
        icon: const Icon(Icons.add),
        label: const Text('Novo cliente'),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clients.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height: 300,

            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.people_outline,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Nenhum cliente cadastrado',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Adicione seu primeiro cliente.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),

      itemCount: _clients.length,

      separatorBuilder: (context, index) {
        return const SizedBox(height: 8);
      },

      itemBuilder: (context, index) {
        final client = _clients[index];

        final name = client['name']?.toString() ?? '';

        final phone = client['phone']?.toString() ?? '';

        final email = client['email']?.toString() ?? '';

        return Card(
          child: ListTile(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientEditScreen(client: client),
                ),
              );

              _loadClients();
            },

            leading: CircleAvatar(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),

            title: Text(
              name.isEmpty ? 'Cliente sem nome' : name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            subtitle: _buildSubtitle(phone, email),

            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(String phone, String email) {
    if (phone.isEmpty && email.isEmpty) {
      return const Text('Sem telefone ou e-mail');
    }

    if (phone.isNotEmpty && email.isNotEmpty) {
      return Text('$phone\n$email');
    }

    if (phone.isNotEmpty) {
      return Text(phone);
    }

    return Text(email);
  }
}
