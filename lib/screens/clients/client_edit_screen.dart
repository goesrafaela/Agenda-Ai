import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class ClientEditScreen extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientEditScreen({super.key, required this.client});

  @override
  State<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends State<ClientEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.client['name']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.client['phone']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: widget.client['email']?.toString() ?? '',
    );

    _notesController = TextEditingController(
      text: widget.client['notes']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _updateClient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await SupabaseService.client
          .from('clients')
          .update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'notes': _notesController.text.trim(),
          })
          .eq('id', widget.client['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente atualizado com sucesso!')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o cliente.')),
      );

      debugPrint('Erro ao atualizar cliente: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cliente?'),
          content: Text(
            'Tem certeza que deseja excluir '
            '${_nameController.text.trim()}?',
          ),
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

    setState(() {
      _saving = true;
    });

    try {
      await SupabaseService.client
          .from('clients')
          .delete()
          .eq('id', widget.client['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente excluído com sucesso!')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir o cliente.')),
      );

      debugPrint('Erro ao excluir cliente: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cliente')),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                const Text(
                  'Dados do cliente',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'Atualize as informações do cliente.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do cliente';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
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
                    onPressed: _saving ? null : _updateClient,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Salvando...' : 'Salvar alterações',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _deleteClient,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Excluir cliente',
                      style: TextStyle(fontSize: 16),
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
